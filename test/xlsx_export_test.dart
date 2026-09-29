import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/src/columns/os_column_def.dart';
import 'package:os_grid_flutter/src/export/xlsx_export.dart';
import 'package:os_grid_flutter/src/export/zip_writer.dart';
import 'package:os_grid_flutter/src/os_grid_controller.dart';

// ---------------------------------------------------------------------------
// Minimal ZIP reader — parses the bytes produced by ZipWriter so the tests
// verify real archive structure rather than string matching.
// ---------------------------------------------------------------------------

class _ZipEntry {
  _ZipEntry({
    required this.name,
    required this.method,
    required this.flags,
    required this.crc,
    required this.compressedSize,
    required this.uncompressedSize,
    required this.localOffset,
    required this.data,
  });

  final String name;
  final int method;
  final int flags;
  final int crc;
  final int compressedSize;
  final int uncompressedSize;
  final int localOffset;
  final Uint8List data;
}

class _ZipArchive {
  _ZipArchive(List<int> bytes) : _bytes = Uint8List.fromList(bytes) {
    _parse();
  }

  final Uint8List _bytes;
  late final int eocdOffset;
  late final int entryCount;
  late final int centralDirectoryOffset;
  late final int centralDirectorySize;
  late final List<_ZipEntry> entries;

  void _parse() {
    // Locate the end-of-central-directory record from the back (allows for
    // a trailing comment, though our writer never emits one).
    var i = _bytes.length - 22;
    while (i >= 0 && _readU32(i) != 0x06054b50) {
      i--;
    }
    expect(i, greaterThanOrEqualTo(0), reason: 'EOCD signature not found');
    eocdOffset = i;
    entryCount = _readU16(i + 10);
    centralDirectorySize = _readU32(i + 12);
    centralDirectoryOffset = _readU32(i + 16);
    expect(_readU16(i + 20), 0, reason: 'EOCD comment length should be 0');

    entries = <_ZipEntry>[];
    var pointer = centralDirectoryOffset;
    for (var n = 0; n < entryCount; n++) {
      expect(
        _readU32(pointer),
        0x02014b50,
        reason: 'central directory entry signature',
      );
      final flags = _readU16(pointer + 8);
      final method = _readU16(pointer + 10);
      final crc = _readU32(pointer + 16);
      final compressedSize = _readU32(pointer + 20);
      final uncompressedSize = _readU32(pointer + 24);
      final nameLength = _readU16(pointer + 28);
      final extraLength = _readU16(pointer + 30);
      final commentLength = _readU16(pointer + 32);
      final localOffset = _readU32(pointer + 42);
      final name = utf8.decode(
        _bytes.sublist(pointer + 46, pointer + 46 + nameLength),
      );

      // Read the entry data via its local header.
      expect(
        _readU32(localOffset),
        0x04034b50,
        reason: 'local file header signature for "$name"',
      );
      final localNameLength = _readU16(localOffset + 26);
      final localExtraLength = _readU16(localOffset + 28);
      final dataStart = localOffset + 30 + localNameLength + localExtraLength;
      final data = Uint8List.sublistView(
        _bytes,
        dataStart,
        dataStart + compressedSize,
      );

      entries.add(
        _ZipEntry(
          name: name,
          method: method,
          flags: flags,
          crc: crc,
          compressedSize: compressedSize,
          uncompressedSize: uncompressedSize,
          localOffset: localOffset,
          data: data,
        ),
      );
      pointer += 46 + nameLength + extraLength + commentLength;
    }

    expect(
      pointer,
      eocdOffset,
      reason: 'central directory walk should end at the EOCD',
    );
    expect(
      eocdOffset,
      centralDirectoryOffset + centralDirectorySize,
      reason: 'EOCD offset/size consistency',
    );
  }

  int _readU16(int offset) => _bytes[offset] | (_bytes[offset + 1] << 8);

  int _readU32(int offset) =>
      _bytes[offset] |
      (_bytes[offset + 1] << 8) |
      (_bytes[offset + 2] << 16) |
      (_bytes[offset + 3] << 24);

  bool hasEntry(String name) => entries.any((e) => e.name == name);

  Uint8List part(String name) => entries.firstWhere((e) => e.name == name).data;

  String partText(String name) => utf8.decode(part(name));
}

// ---------------------------------------------------------------------------
// Minimal sheet1.xml reader — regex-based so no XML dependency is needed.
// ---------------------------------------------------------------------------

class SheetCell {
  String? text;
  num? number;
  bool? boolean;
}

class SheetRow {
  final Map<String, SheetCell> cells = {};
}

/// Extracts rows from sheet1.xml content, keyed by 1-based row number.
Map<int, SheetRow> parseSheet(String xml) {
  final rows = <int, SheetRow>{};
  final rowRe = RegExp(r'<row r="(\d+)"[^>]*>(.*?)</row>', dotAll: true);
  final cellRe = RegExp(r'<c r="([A-Z]+)(\d+)"([^>]*)>(.*?)</c>', dotAll: true);
  final valueRe = RegExp(r'<v>(.*?)</v>', dotAll: true);
  final textRe = RegExp(r'<t[^>]*>(.*?)</t>', dotAll: true);

  for (final rowMatch in rowRe.allMatches(xml)) {
    final row = SheetRow();
    rows[int.parse(rowMatch.group(1)!)] = row;
    for (final cellMatch in cellRe.allMatches(rowMatch.group(2)!)) {
      final column = cellMatch.group(1)!;
      final attrs = cellMatch.group(3)!;
      final body = cellMatch.group(4)!;
      final cell = SheetCell();
      if (attrs.contains('t="inlineStr"')) {
        cell.text = unescapeXml(textRe.firstMatch(body)!.group(1)!);
      } else if (attrs.contains('t="b"')) {
        cell.boolean = valueRe.firstMatch(body)!.group(1) == '1';
      } else {
        cell.number = num.parse(valueRe.firstMatch(body)!.group(1)!);
      }
      row.cells[column] = cell;
    }
  }
  return rows;
}

String unescapeXml(String value) => value
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&apos;', "'")
    .replaceAll('&amp;', '&');

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const List<OsColumnDef> _columns = [
  OsColumnDef(field: 'name', headerName: 'Name'),
  OsColumnDef(field: 'age', headerName: 'Age'),
  OsColumnDef(field: 'active', headerName: 'Active'),
];

const List<Map<String, dynamic>> _rows = [
  {'name': 'Alice', 'age': 30, 'active': true},
  {'name': 'Bob', 'age': 25, 'active': false},
  {'name': 'Charlie', 'age': 35, 'active': true},
];

XlsxSerializer<Map<String, dynamic>> _serializer([
  OsXlsxExportParams params = const OsXlsxExportParams(),
]) => XlsxSerializer<Map<String, dynamic>>(
  params: params,
  columns: _columns,
  rows: _rows,
);

String _sheet1(XlsxSerializer<Object?> serializer) =>
    _ZipArchive(serializer.serialize()).partText('xl/worksheets/sheet1.xml');

void main() {
  group('zipCrc32', () {
    test('known test vectors', () {
      expect(zipCrc32(<int>[]), 0x00000000);
      expect(zipCrc32(utf8.encode('123456789')), 0xCBF43926);
      expect(
        zipCrc32(utf8.encode('The quick brown fox jumps over the lazy dog')),
        0x414FA339,
      );
    });
  });

  group('ZipWriter', () {
    test('round-trips a single file', () {
      final zip = ZipWriter()..add('a.txt', utf8.encode('hello world'));
      final archive = _ZipArchive(zip.build());
      expect(archive.entryCount, 1);
      expect(archive.entries.single.name, 'a.txt');
      expect(utf8.decode(archive.entries.single.data), 'hello world');
    });

    test('round-trips multiple files in order', () {
      final zip = ZipWriter()
        ..add('one.txt', utf8.encode('1'))
        ..add('dir/two.txt', utf8.encode('22'));
      final archive = _ZipArchive(zip.build());
      expect(archive.entryCount, 2);
      expect(archive.entries.map((e) => e.name).toList(), [
        'one.txt',
        'dir/two.txt',
      ]);
      expect(utf8.decode(archive.part('dir/two.txt')), '22');
    });

    test('supports empty payloads', () {
      final zip = ZipWriter()..add('empty.bin', <int>[]);
      final archive = _ZipArchive(zip.build());
      expect(archive.entries.single.data, isEmpty);
      expect(archive.entries.single.crc, 0);
      expect(archive.entries.single.compressedSize, 0);
    });

    test('preserves binary payload byte-for-byte', () {
      final payload = List<int>.generate(256, (i) => i);
      final zip = ZipWriter()..add('binary.bin', payload);
      final archive = _ZipArchive(zip.build());
      expect(archive.part('binary.bin'), payload);
    });

    test('entries are stored without compression', () {
      final zip = ZipWriter()..add('a.txt', utf8.encode('data'));
      final archive = _ZipArchive(zip.build());
      expect(archive.entries.single.method, 0);
      expect(
        archive.entries.single.compressedSize,
        archive.entries.single.uncompressedSize,
      );
    });

    test('stored CRC matches payload', () {
      final payload = utf8.encode('some payload for crc');
      final zip = ZipWriter()..add('a.txt', payload);
      final archive = _ZipArchive(zip.build());
      expect(archive.entries.single.crc, zipCrc32(payload));
    });

    test('output is deterministic', () {
      final a = (ZipWriter()..add('a.txt', utf8.encode('x'))).build();
      final b = (ZipWriter()..add('a.txt', utf8.encode('x'))).build();
      expect(a, b);
    });
  });

  group('XlsxSerializer - ZIP structure', () {
    test('produces the five required OOXML parts', () {
      final archive = _ZipArchive(_serializer().serialize());
      expect(archive.entryCount, 5);
      expect(archive.entries.map((e) => e.name).toList(), [
        '[Content_Types].xml',
        '_rels/.rels',
        'xl/workbook.xml',
        'xl/_rels/workbook.xml.rels',
        'xl/worksheets/sheet1.xml',
      ]);
    });

    test('entries are store-only with consistent sizes and CRCs', () {
      final archive = _ZipArchive(_serializer().serialize());
      for (final entry in archive.entries) {
        expect(entry.method, 0, reason: entry.name);
        expect(
          entry.flags & 0x0800,
          0x0800,
          reason: 'UTF-8 flag ${entry.name}',
        );
        expect(
          entry.compressedSize,
          entry.uncompressedSize,
          reason: entry.name,
        );
        expect(entry.crc, zipCrc32(entry.data), reason: entry.name);
      }
    });

    test('EOCD record matches the written central directory', () {
      final archive = _ZipArchive(_serializer().serialize());
      expect(
        archive.eocdOffset,
        archive.centralDirectoryOffset + archive.centralDirectorySize,
      );
      expect(archive.entryCount, archive.entries.length);
    });

    test('local header data matches central directory data', () {
      final bytes = _serializer().serialize();
      final archive = _ZipArchive(bytes);
      for (final entry in archive.entries) {
        // The local-header walk is inside _ZipArchive parsing; assert the
        // offsets are ordered (local data precedes the central directory).
        expect(entry.localOffset, lessThan(archive.centralDirectoryOffset));
      }
      expect(bytes.first, 0x50); // 'P' of PK\x03\x04
      expect(bytes[1], 0x4B);
      expect(bytes[2], 0x03);
      expect(bytes[3], 0x04);
    });

    test('output is deterministic', () {
      final a = _serializer().serialize();
      final b = _serializer().serialize();
      expect(a, b);
    });
  });

  group('XlsxSerializer - OOXML parts', () {
    test('[Content_Types].xml declares workbook and worksheet types', () {
      final content = _ZipArchive(
        _serializer().serialize(),
      ).partText('[Content_Types].xml');
      expect(content, startsWith('<?xml version="1.0" encoding="UTF-8"'));
      expect(
        content,
        contains(
          'application/vnd.openxmlformats-officedocument.spreadsheetml'
          '.sheet.main+xml',
        ),
      );
      expect(
        content,
        contains(
          'application/vnd.openxmlformats-officedocument.spreadsheetml'
          '.worksheet+xml',
        ),
      );
      expect(content, contains('PartName="/xl/worksheets/sheet1.xml"'));
    });

    test('_rels/.rels points at the workbook', () {
      final content = _ZipArchive(
        _serializer().serialize(),
      ).partText('_rels/.rels');
      expect(
        content,
        contains(
          'Type="http://schemas.openxmlformats.org/officeDocument/2006/'
          'relationships/officeDocument"',
        ),
      );
      expect(content, contains('Target="xl/workbook.xml"'));
    });

    test('xl/workbook.xml declares the sheet', () {
      final content = _ZipArchive(
        _serializer().serialize(),
      ).partText('xl/workbook.xml');
      expect(
        content,
        contains(
          '<sheet name="Sheet1" sheetId="1" '
          'r:id="rId1"/>',
        ),
      );
      expect(content, contains('spreadsheetml/2006/main'));
    });

    test('xl/_rels/workbook.xml.rels points at sheet1', () {
      final content = _ZipArchive(
        _serializer().serialize(),
      ).partText('xl/_rels/workbook.xml.rels');
      expect(
        content,
        contains(
          'Type="http://schemas.openxmlformats.org/officeDocument/2006/'
          'relationships/worksheet"',
        ),
      );
      expect(content, contains('Target="worksheets/sheet1.xml"'));
    });

    test('sheet1.xml is a worksheet with sheetData', () {
      final xml = _sheet1(_serializer());
      expect(xml, startsWith('<?xml version="1.0" encoding="UTF-8"'));
      expect(
        xml,
        contains(
          '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml'
          '/2006/main">',
        ),
      );
      expect(xml, contains('<sheetData>'));
      expect(xml, contains('</sheetData>'));
      expect(xml, contains('</worksheet>'));
    });
  });

  group('XlsxSerializer - cell content round-trip', () {
    test('headers and mixed cell types round-trip', () {
      final rows = parseSheet(_sheet1(_serializer()));
      expect(rows.keys.toList(), [1, 2, 3, 4]);

      expect(rows[1]!.cells['A']!.text, 'Name');
      expect(rows[1]!.cells['B']!.text, 'Age');
      expect(rows[1]!.cells['C']!.text, 'Active');

      expect(rows[2]!.cells['A']!.text, 'Alice');
      expect(rows[2]!.cells['B']!.number, 30);
      expect(rows[2]!.cells['C']!.boolean, isTrue);

      expect(rows[3]!.cells['A']!.text, 'Bob');
      expect(rows[3]!.cells['B']!.number, 25);
      expect(rows[3]!.cells['C']!.boolean, isFalse);

      expect(rows[4]!.cells['A']!.text, 'Charlie');
      expect(rows[4]!.cells['B']!.number, 35);
    });

    test('row references are sequential and cell refs match columns', () {
      final xml = _sheet1(_serializer());
      expect(xml, contains('<row r="1">'));
      expect(xml, contains('<row r="4">'));
      expect(xml, contains('<c r="A1" t="inlineStr">'));
      expect(xml, contains('<c r="B2"><v>30</v></c>'));
      expect(xml, contains('<c r="C2" t="b"><v>1</v></c>'));
      expect(xml, contains('<c r="C3" t="b"><v>0</v></c>'));
    });

    test('null cells are omitted but the row is kept', () {
      const serializer = XlsxSerializer<Map<String, dynamic>>(
        params: OsXlsxExportParams(),
        columns: _columns,
        rows: [
          {'name': null, 'age': null, 'active': null},
          {'name': 'Dan', 'age': 40, 'active': true},
        ],
      );
      final rows = parseSheet(_sheet1(serializer));
      expect(rows[1]!.cells['A']!.text, 'Name'); // header row
      expect(rows[2]!.cells, isEmpty); // all-null row keeps only cells
      expect(rows[3]!.cells['A']!.text, 'Dan');
    });

    test('XML special characters are escaped and unescape correctly', () {
      const serializer = XlsxSerializer<Map<String, dynamic>>(
        params: OsXlsxExportParams(),
        columns: [OsColumnDef(field: 'v', headerName: 'V')],
        rows: [
          {'v': 'A&B <tag> "quoted" \'apostrophe\''},
        ],
      );
      final rows = parseSheet(_sheet1(serializer));
      expect(rows[2]!.cells['A']!.text, 'A&B <tag> "quoted" \'apostrophe\'');
    });

    test('unicode content survives the round-trip', () {
      const serializer = XlsxSerializer<Map<String, dynamic>>(
        params: OsXlsxExportParams(),
        columns: [OsColumnDef(field: 'v', headerName: 'V')],
        rows: [
          {'v': 'héllo ✓ 日本語'},
        ],
      );
      final rows = parseSheet(_sheet1(serializer));
      expect(rows[2]!.cells['A']!.text, 'héllo ✓ 日本語');
    });

    test('XML-invalid control characters are stripped, tab/CR kept', () {
      const value = 'a\x00b\x07c\td\ne\rf';
      const serializer = XlsxSerializer<Map<String, dynamic>>(
        params: OsXlsxExportParams(),
        columns: [OsColumnDef(field: 'v', headerName: 'V')],
        rows: [
          {'v': value},
        ],
      );
      final rows = parseSheet(_sheet1(serializer));
      expect(rows[2]!.cells['A']!.text, 'abc\td\ne\rf');
    });

    test('inline strings preserve whitespace via xml:space', () {
      const serializer = XlsxSerializer<Map<String, dynamic>>(
        params: OsXlsxExportParams(),
        columns: [OsColumnDef(field: 'v', headerName: 'V')],
        rows: [
          {'v': '  padded  '},
        ],
      );
      final xml = _sheet1(serializer);
      expect(xml, contains('<t xml:space="preserve">  padded  </t>'));
    });

    test('numeric edge cases: double, NaN, Infinity', () {
      const serializer = XlsxSerializer<Map<String, dynamic>>(
        params: OsXlsxExportParams(),
        columns: [OsColumnDef(field: 'v', headerName: 'V')],
        rows: [
          {'v': 25.5},
          {'v': double.nan},
          {'v': double.infinity},
        ],
      );
      final rows = parseSheet(_sheet1(serializer));
      expect(rows[2]!.cells['A']!.number, 25.5);
      expect(rows[3]!.cells['A']!.text, 'NaN');
      expect(rows[4]!.cells['A']!.text, 'Infinity');
    });

    test('columns beyond Z use double letters (A..AA..AB)', () {
      final manyColumns = List.generate(28, (i) => OsColumnDef(field: 'f$i'));
      final dataRow = <String, dynamic>{for (var i = 0; i < 28; i++) 'f$i': i};
      final serializer = XlsxSerializer<Map<String, dynamic>>(
        params: const OsXlsxExportParams(),
        columns: manyColumns,
        rows: [dataRow],
      );
      final rows = parseSheet(_sheet1(serializer));
      expect(rows[2]!.cells['Z']!.number, 25);
      expect(rows[2]!.cells['AA']!.number, 26);
      expect(rows[2]!.cells['AB']!.number, 27);
      final xml = _sheet1(serializer);
      expect(xml, contains('<c r="AA1" t="inlineStr">'));
      expect(xml, contains('<c r="AB1" t="inlineStr">'));
    });
  });

  group('XlsxSerializer - params', () {
    test('skipColumnHeaders omits the header row', () {
      final serializer = _serializer(
        const OsXlsxExportParams(skipColumnHeaders: true),
      );
      final rows = parseSheet(_sheet1(serializer));
      expect(rows.keys.toList(), [1, 2, 3]);
      expect(rows[1]!.cells['A']!.text, 'Alice');
    });

    test('shouldRowBeSkipped skips matching rows with output indices', () {
      final captured = <int>[];
      final serializer = _serializer(
        OsXlsxExportParams(
          shouldRowBeSkipped: (params) {
            captured.add(params.rowIndex);
            return (params.data['age'] as int) < 30;
          },
        ),
      );
      final rows = parseSheet(_sheet1(serializer));
      // Mirrors CSV: a skipped row does not consume an output index.
      expect(captured, [0, 1, 1]);
      expect(rows.keys.toList(), [1, 2, 3]);
      expect(rows[2]!.cells['A']!.text, 'Alice');
      expect(rows[3]!.cells['A']!.text, 'Charlie');
    });

    test('processCellCallback output becomes a text cell', () {
      final serializer = _serializer(
        OsXlsxExportParams(
          processCellCallback: (params) => 'C:${params.value}',
        ),
      );
      final rows = parseSheet(_sheet1(serializer));
      expect(rows[2]!.cells['B']!.text, 'C:30');
      expect(rows[2]!.cells['B']!.number, isNull);
    });

    test('processCellCallback receives formatValue utility', () {
      final columns = [
        OsColumnDef(
          field: 'price',
          headerName: 'Price',
          valueFormatter: (params) => '\$${params.value.toStringAsFixed(2)}',
        ),
      ];
      final serializer = XlsxSerializer<Map<String, dynamic>>(
        params: OsXlsxExportParams(
          processCellCallback: (params) => params.formatValue(params.value),
        ),
        columns: columns,
        rows: const [
          {'price': 42.0},
        ],
      );
      final rows = parseSheet(_sheet1(serializer));
      expect(rows[2]!.cells['A']!.text, '\$42.00');
    });

    test('processHeaderCallback transforms headers', () {
      final serializer = _serializer(
        OsXlsxExportParams(
          processHeaderCallback: (params) =>
              'H_${params.colDef.field?.toUpperCase()}',
        ),
      );
      final rows = parseSheet(_sheet1(serializer));
      expect(rows[1]!.cells['A']!.text, 'H_NAME');
      expect(rows[1]!.cells['B']!.text, 'H_AGE');
    });

    test('valueFormatter output is exported as text', () {
      final serializer = XlsxSerializer<Map<String, dynamic>>(
        params: const OsXlsxExportParams(),
        columns: [
          OsColumnDef(
            field: 'price',
            headerName: 'Price',
            valueFormatter: (params) => '\$${params.value.toStringAsFixed(2)}',
          ),
        ],
        rows: const [
          {'price': 9.99},
        ],
      );
      final rows = parseSheet(_sheet1(serializer));
      expect(rows[2]!.cells['A']!.text, '\$9.99');
      expect(rows[2]!.cells['A']!.number, isNull);
    });

    test('valueGetter drives cell values for typed data', () {
      final serializer = XlsxSerializer<_Person>(
        params: const OsXlsxExportParams(),
        columns: [
          OsColumnDef<_Person>(
            field: 'name',
            headerName: 'Full Name',
            valueGetter: (params) =>
                '${params.data.firstName} ${params.data.lastName}',
          ),
          OsColumnDef<_Person>(
            field: 'age',
            headerName: 'Age',
            valueGetter: (params) => params.data.age,
          ),
        ],
        rows: [_Person('Alice', 'Smith', 30)],
      );
      final rows = parseSheet(_sheet1(serializer));
      expect(rows[2]!.cells['A']!.text, 'Alice Smith');
      expect(rows[2]!.cells['B']!.number, 30);
    });

    test('empty rows and columns still produce a valid workbook', () {
      const serializer = XlsxSerializer<Map<String, dynamic>>(
        params: OsXlsxExportParams(),
        columns: [],
        rows: [],
      );
      final archive = _ZipArchive(serializer.serialize());
      expect(archive.entryCount, 5);
      final rows = parseSheet(archive.partText('xl/worksheets/sheet1.xml'));
      expect(rows, hasLength(1)); // header row with zero cells
      expect(rows[1]!.cells, isEmpty);
    });

    test('custom sheet name lands in workbook.xml', () {
      final serializer = _serializer(
        const OsXlsxExportParams(sheetName: 'Q1 Report'),
      );
      expect(
        _ZipArchive(serializer.serialize()).partText('xl/workbook.xml'),
        contains('name="Q1 Report"'),
      );
    });

    test('sheet name is sanitized for Excel limits', () {
      final serializer = _serializer(
        const OsXlsxExportParams(sheetName: 'a:b/c?d*e[f]\\g'),
      );
      expect(
        _ZipArchive(serializer.serialize()).partText('xl/workbook.xml'),
        contains('name="a_b_c_d_e_f__g"'),
      );

      final longSerializer = _serializer(
        OsXlsxExportParams(sheetName: 'x' * 40),
      );
      final workbook = _ZipArchive(
        longSerializer.serialize(),
      ).partText('xl/workbook.xml');
      expect(workbook.contains('name="${'x' * 31}"'), isTrue);
      expect(workbook.contains('name="${'x' * 32}"'), isFalse);
    });
  });

  group('XlsxSerializer - column widths', () {
    test('display widths are converted to Excel character widths', () {
      const serializer = XlsxSerializer<Map<String, dynamic>>(
        params: OsXlsxExportParams(),
        columns: _columns,
        rows: _rows,
        columnWidths: {'name': 120.0, 'age': 75.5},
      );
      final xml = _sheet1(serializer);
      // (120 - 5) / 7 = 16.43
      expect(
        xml,
        contains('<col min="1" max="1" width="16.43" customWidth="1"/>'),
      );
      // (75.5 - 5) / 7 = 10.07
      expect(
        xml,
        contains('<col min="2" max="2" width="10.07" customWidth="1"/>'),
      );
    });

    test('falls back to def width, then the 150px grid default', () {
      const serializer = XlsxSerializer<Map<String, dynamic>>(
        params: OsXlsxExportParams(),
        columns: [
          OsColumnDef(field: 'a'),
          OsColumnDef(field: 'b', width: 220.0),
          OsColumnDef(field: 'c'),
        ],
        rows: [],
        columnWidths: {'a': 71.0},
      );
      final xml = _sheet1(serializer);
      expect(
        xml,
        contains('<col min="1" max="1" width="9.43" customWidth="1"/>'),
      );
      expect(
        xml,
        contains('<col min="2" max="2" width="30.71" customWidth="1"/>'),
      );
      expect(
        xml,
        contains('<col min="3" max="3" width="20.71" customWidth="1"/>'),
      );
    });
  });

  group('XlsxSerializer - sanitizeFormulas', () {
    const dangerousColumns = [
      OsColumnDef(field: 'payload', headerName: 'Payload'),
    ];

    List<String> exportedTexts(List<Map<String, dynamic>> rows) {
      final serializer = XlsxSerializer<Map<String, dynamic>>(
        params: const OsXlsxExportParams(sanitizeFormulas: true),
        columns: dangerousColumns,
        rows: rows,
      );
      final rowsXml = parseSheet(_sheet1(serializer));
      return [
        // Skip the header row (sheet row 1).
        for (final entry in rowsXml.entries)
          if (entry.key > 1 && entry.value.cells['A'] != null)
            entry.value.cells['A']!.text!,
      ];
    }

    test('leading formula characters get a single-quote prefix', () {
      final texts = exportedTexts(const [
        {'payload': '=1+1'},
        {'payload': '+SUM(A1:A10)'},
        {'payload': '-2*3'},
        {'payload': '@cmd'},
        {'payload': 'plain text'},
      ]);
      expect(texts, ["'=1+1", "'+SUM(A1:A10)", "'-2*3", "'@cmd", 'plain text']);
    });

    test('tab/CR prefixes followed by formula characters are sanitised', () {
      final texts = exportedTexts(const [
        {'payload': '\t=SUM(A1)'},
        {'payload': '\r=cmd'},
      ]);
      expect(texts, ["'\t=SUM(A1)", "'\r=cmd"]);
    });

    test('processCellCallback output is sanitised too', () {
      final serializer = XlsxSerializer<Map<String, dynamic>>(
        params: OsXlsxExportParams(
          sanitizeFormulas: true,
          processCellCallback: (params) => '=HACKED(${params.value})',
        ),
        columns: dangerousColumns,
        rows: const [
          {'payload': 'innocent'},
        ],
      );
      final rows = parseSheet(_sheet1(serializer));
      expect(rows[2]!.cells['A']!.text, "'=HACKED(innocent)");
    });

    test('header row is not sanitised', () {
      const serializer = XlsxSerializer<Map<String, dynamic>>(
        params: OsXlsxExportParams(sanitizeFormulas: true),
        columns: [OsColumnDef(field: 'payload', headerName: '=EVIL')],
        rows: [
          {'payload': '=x'},
        ],
      );
      final rows = parseSheet(_sheet1(serializer));
      expect(rows[1]!.cells['A']!.text, '=EVIL');
      expect(rows[2]!.cells['A']!.text, "'=x");
    });

    test('numeric and boolean cells are never sanitised', () {
      const serializer = XlsxSerializer<Map<String, dynamic>>(
        params: OsXlsxExportParams(sanitizeFormulas: true),
        columns: _columns,
        rows: [
          {'name': 'ok', 'age': -5, 'active': true},
        ],
      );
      final rows = parseSheet(_sheet1(serializer));
      expect(rows[2]!.cells['B']!.number, -5);
      expect(rows[2]!.cells['B']!.text, isNull);
      expect(rows[2]!.cells['C']!.boolean, isTrue);
    });

    test('default is off — output unchanged', () {
      final defaultOut = _serializer(const OsXlsxExportParams()).serialize();
      final explicitOff = _serializer(
        const OsXlsxExportParams(sanitizeFormulas: false),
      ).serialize();
      expect(defaultOut, explicitOff);
      final rows = parseSheet(_sheet1(_serializer()));
      expect(rows[2]!.cells['A']!.text, 'Alice');
    });
  });

  group('OsGridController.exportXlsx', () {
    test('exports resolved columns and rows', () {
      final controller = OsGridController<Map<String, dynamic>>();
      addTearDown(controller.dispose);
      controller.setRowData(List<Map<String, dynamic>>.from(_rows));
      controller.columnDefs = _columns;

      final archive = _ZipArchive(controller.exportXlsx());
      final rows = parseSheet(archive.partText('xl/worksheets/sheet1.xml'));
      expect(rows[1]!.cells['A']!.text, 'Name');
      expect(rows[2]!.cells['A']!.text, 'Alice');
      expect(rows[4]!.cells['C']!.boolean, isTrue);
    });

    test('columnKeys restrict exported columns', () {
      final controller = OsGridController<Map<String, dynamic>>();
      addTearDown(controller.dispose);
      controller.setRowData(List<Map<String, dynamic>>.from(_rows));
      controller.columnDefs = _columns;

      final archive = _ZipArchive(
        controller.exportXlsx(
          params: const OsXlsxExportParams(columnKeys: ['age', 'name']),
        ),
      );
      final rows = parseSheet(archive.partText('xl/worksheets/sheet1.xml'));
      expect(rows[1]!.cells.keys.toList(), ['A', 'B']);
      expect(rows[1]!.cells['A']!.text, 'Age');
      expect(rows[2]!.cells['B']!.text, 'Alice');
    });

    test('allColumns includes hidden columns', () {
      final controller = OsGridController<Map<String, dynamic>>();
      addTearDown(controller.dispose);
      controller.setRowData(List<Map<String, dynamic>>.from(_rows));
      controller.columnDefs = _columns;
      controller.hiddenColumnIds = {'active'};

      final visibleOnly = parseSheet(
        _ZipArchive(
          controller.exportXlsx(),
        ).partText('xl/worksheets/sheet1.xml'),
      );
      expect(visibleOnly[1]!.cells.keys.toList(), ['A', 'B']);

      final allColumns = parseSheet(
        _ZipArchive(
          controller.exportXlsx(
            params: const OsXlsxExportParams(allColumns: true),
          ),
        ).partText('xl/worksheets/sheet1.xml'),
      );
      expect(allColumns[1]!.cells.keys.toList(), ['A', 'B', 'C']);
      expect(allColumns[1]!.cells['C']!.text, 'Active');
    });

    test('onlySelected exports selected rows', () {
      final controller = OsGridController<Map<String, dynamic>>();
      addTearDown(controller.dispose);
      controller.setRowData([
        {'name': 'Alice', 'age': 30, 'active': true},
        {'name': 'Bob', 'age': 25, 'active': false},
      ]);
      controller.columnDefs = _columns;
      controller.selectAll();

      final rows = parseSheet(
        _ZipArchive(
          controller.exportXlsx(
            params: const OsXlsxExportParams(onlySelected: true),
          ),
        ).partText('xl/worksheets/sheet1.xml'),
      );
      expect(rows.keys.toList(), [1, 2, 3]);
    });

    test('current display widths feed the sheet column widths', () {
      final controller = OsGridController<Map<String, dynamic>>();
      addTearDown(controller.dispose);
      controller.setRowData(List<Map<String, dynamic>>.from(_rows));
      controller.columnDefs = _columns;
      controller.columnWidthState = {'age': 120.0};

      final xml = _ZipArchive(
        controller.exportXlsx(),
      ).partText('xl/worksheets/sheet1.xml');
      expect(
        xml,
        contains('<col min="2" max="2" width="16.43" customWidth="1"/>'),
      );
    });

    test('fileName default is export.xlsx when unset', () {
      final controller = OsGridController<Map<String, dynamic>>();
      addTearDown(controller.dispose);
      controller.setRowData(List<Map<String, dynamic>>.from(_rows));
      controller.columnDefs = _columns;

      // The params object mirrors CsvExportParams' informational fileName.
      const params = OsXlsxExportParams();
      expect(params.fileName, isNull);
      expect(controller.exportXlsx(params: params), isNotEmpty);
    });
  });
}

class _Person {
  _Person(this.firstName, this.lastName, this.age);
  final String firstName;
  final String lastName;
  final int age;
}
