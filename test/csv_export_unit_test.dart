// Standalone unit test for CSV export that doesn't depend on the full widget.
// This avoids pre-existing compilation errors in os_grid.dart.
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/src/columns/os_column_def.dart';
import 'package:os_grid_flutter/src/export/csv_export.dart';

void main() {
  group('CsvSerializer', () {
    final columns = [
      const OsColumnDef(field: 'name', headerName: 'Name'),
      const OsColumnDef(field: 'age', headerName: 'Age'),
      const OsColumnDef(field: 'city', headerName: 'City'),
    ];

    final rows = <Map<String, dynamic>>[
      {'name': 'Alice', 'age': 30, 'city': 'London'},
      {'name': 'Bob', 'age': 25, 'city': 'Paris'},
      {'name': 'Charlie', 'age': 35, 'city': 'Berlin'},
    ];

    test('basic export with headers and data', () {
      final serializer = CsvSerializer<Map<String, dynamic>>(
        params: const OsCsvExportParams(),
        columns: columns,
        rows: rows,
      );

      final csv = serializer.serialize();

      // Should start with BOM
      expect(csv.startsWith('\ufeff'), isTrue);

      // Should use \r\n line endings
      expect(csv.contains('\r\n'), isTrue);

      // Should contain headers
      expect(csv.contains('"Name"'), isTrue);
      expect(csv.contains('"Age"'), isTrue);
      expect(csv.contains('"City"'), isTrue);

      // Should contain data
      expect(csv.contains('"Alice"'), isTrue);
      expect(csv.contains('"30"'), isTrue);
      expect(csv.contains('"London"'), isTrue);
    });

    test('uses CRLF line endings throughout', () {
      final serializer = CsvSerializer<Map<String, dynamic>>(
        params: const OsCsvExportParams(),
        columns: columns,
        rows: rows,
      );

      final csv = serializer.serialize();
      // Remove BOM for easier testing
      final content = csv.substring(1);

      // Split on \r\n — should give us header + 3 data rows
      final lines = content.split('\r\n');
      expect(lines.length, 4); // header + 3 rows (no trailing empty)
    });

    test('no trailing newline', () {
      final serializer = CsvSerializer<Map<String, dynamic>>(
        params: const OsCsvExportParams(),
        columns: columns,
        rows: rows,
      );

      final csv = serializer.serialize();
      expect(csv.endsWith('\r\n'), isFalse);
    });

    test('skipColumnHeaders omits header row', () {
      final serializer = CsvSerializer<Map<String, dynamic>>(
        params: const OsCsvExportParams(skipColumnHeaders: true),
        columns: columns,
        rows: rows,
      );

      final csv = serializer.serialize();
      expect(csv.contains('"Name"'), isFalse);
      expect(csv.contains('"Age"'), isFalse);
      // Data should still be present
      expect(csv.contains('"Alice"'), isTrue);
    });

    test('custom column separator', () {
      final serializer = CsvSerializer<Map<String, dynamic>>(
        params: const OsCsvExportParams(columnSeparator: ';'),
        columns: columns,
        rows: rows,
      );

      final csv = serializer.serialize();
      // Headers should be separated by ;
      expect(csv.contains('"Name";"Age";"City"'), isTrue);
    });

    test('suppressQuotes outputs raw values', () {
      final serializer = CsvSerializer<Map<String, dynamic>>(
        params: const OsCsvExportParams(suppressQuotes: true),
        columns: columns,
        rows: rows,
      );

      final csv = serializer.serialize();
      // Values should NOT be wrapped in quotes
      expect(csv.contains('Alice'), isTrue);
      expect(csv.contains('"Alice"'), isFalse);
    });

    test('double quotes in values are escaped', () {
      final rowsWithQuotes = <Map<String, dynamic>>[
        {'name': 'She said "hello"', 'age': 30, 'city': 'London'},
      ];

      final serializer = CsvSerializer<Map<String, dynamic>>(
        params: const OsCsvExportParams(),
        columns: columns,
        rows: rowsWithQuotes,
      );

      final csv = serializer.serialize();
      // Double quotes should be escaped as ""
      expect(csv.contains('"She said ""hello"""'), isTrue);
    });

    test('null values exported as empty string', () {
      final rowsWithNull = <Map<String, dynamic>>[
        {'name': null, 'age': 30, 'city': 'London'},
      ];

      final serializer = CsvSerializer<Map<String, dynamic>>(
        params: const OsCsvExportParams(),
        columns: columns,
        rows: rowsWithNull,
      );

      final csv = serializer.serialize();
      // Null should become empty quoted string
      expect(csv.contains('""'), isTrue);
    });

    test('values containing separator are properly quoted', () {
      final rowsWithSep = <Map<String, dynamic>>[
        {'name': 'Last, First', 'age': 30, 'city': 'London'},
      ];

      final serializer = CsvSerializer<Map<String, dynamic>>(
        params: const OsCsvExportParams(),
        columns: columns,
        rows: rowsWithSep,
      );

      final csv = serializer.serialize();
      // Value with comma should be quoted (it always is)
      expect(csv.contains('"Last, First"'), isTrue);
    });

    test('values containing newlines are properly quoted', () {
      final rowsWithNewline = <Map<String, dynamic>>[
        {'name': 'Line1\nLine2', 'age': 30, 'city': 'London'},
      ];

      final serializer = CsvSerializer<Map<String, dynamic>>(
        params: const OsCsvExportParams(),
        columns: columns,
        rows: rowsWithNewline,
      );

      final csv = serializer.serialize();
      expect(csv.contains('"Line1\nLine2"'), isTrue);
    });
  });

  group('CsvSerializer - valueFormatter', () {
    test('applies valueFormatter by default', () {
      final columns = [
        OsColumnDef(
          field: 'price',
          headerName: 'Price',
          valueFormatter: (params) => '\$${params.value.toStringAsFixed(2)}',
        ),
      ];

      final rows = <Map<String, dynamic>>[
        {'price': 9.99},
        {'price': 100.5},
      ];

      final serializer = CsvSerializer<Map<String, dynamic>>(
        params: const OsCsvExportParams(),
        columns: columns,
        rows: rows,
      );

      final csv = serializer.serialize();
      expect(csv.contains('"\$9.99"'), isTrue);
      expect(csv.contains('"\$100.50"'), isTrue);
    });

    test('processCellCallback overrides valueFormatter', () {
      final columns = [
        OsColumnDef(
          field: 'price',
          headerName: 'Price',
          valueFormatter: (params) => '\$${params.value}',
        ),
      ];

      final rows = <Map<String, dynamic>>[
        {'price': 9.99},
      ];

      final serializer = CsvSerializer<Map<String, dynamic>>(
        params: OsCsvExportParams(
          processCellCallback: (params) => 'CUSTOM:${params.value}',
        ),
        columns: columns,
        rows: rows,
      );

      final csv = serializer.serialize();
      expect(csv.contains('"CUSTOM:9.99"'), isTrue);
      expect(csv.contains('"\$9.99"'), isFalse);
    });

    test('processCellCallback receives formatValue utility', () {
      final columns = [
        OsColumnDef(
          field: 'price',
          headerName: 'Price',
          valueFormatter: (params) => '\$${params.value.toStringAsFixed(2)}',
        ),
      ];

      final rows = <Map<String, dynamic>>[
        {'price': 42.0},
      ];

      String? capturedFormatted;
      final serializer = CsvSerializer<Map<String, dynamic>>(
        params: OsCsvExportParams(
          processCellCallback: (params) {
            capturedFormatted = params.formatValue(params.value);
            return capturedFormatted!;
          },
        ),
        columns: columns,
        rows: rows,
      );

      serializer.serialize();
      expect(capturedFormatted, '\$42.00');
    });
  });

  group('CsvSerializer - valueGetter', () {
    test('uses valueGetter for typed data', () {
      final columns = [
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
      ];

      final rows = [_Person('Alice', 'Smith', 30), _Person('Bob', 'Jones', 25)];

      final serializer = CsvSerializer<_Person>(
        params: const OsCsvExportParams(),
        columns: columns,
        rows: rows,
      );

      final csv = serializer.serialize();
      expect(csv.contains('"Alice Smith"'), isTrue);
      expect(csv.contains('"Bob Jones"'), isTrue);
      expect(csv.contains('"30"'), isTrue);
      expect(csv.contains('"25"'), isTrue);
    });
  });

  group('CsvSerializer - processHeaderCallback', () {
    test('transforms header names', () {
      final columns = [
        const OsColumnDef(field: 'name', headerName: 'Name'),
        const OsColumnDef(field: 'age', headerName: 'Age'),
      ];

      final rows = <Map<String, dynamic>>[
        {'name': 'Alice', 'age': 30},
      ];

      final serializer = CsvSerializer<Map<String, dynamic>>(
        params: OsCsvExportParams(
          processHeaderCallback: (params) =>
              'HEADER_${params.colDef.field?.toUpperCase()}',
        ),
        columns: columns,
        rows: rows,
      );

      final csv = serializer.serialize();
      expect(csv.contains('"HEADER_NAME"'), isTrue);
      expect(csv.contains('"HEADER_AGE"'), isTrue);
    });
  });

  group('CsvSerializer - shouldRowBeSkipped', () {
    test('skips rows when callback returns true', () {
      final columns = [
        const OsColumnDef(field: 'name', headerName: 'Name'),
        const OsColumnDef(field: 'age', headerName: 'Age'),
      ];

      final rows = <Map<String, dynamic>>[
        {'name': 'Alice', 'age': 30},
        {'name': 'Bob', 'age': 25},
        {'name': 'Charlie', 'age': 35},
      ];

      final serializer = CsvSerializer<Map<String, dynamic>>(
        params: OsCsvExportParams(
          shouldRowBeSkipped: (params) {
            final data = params.data as Map<String, dynamic>;
            return (data['age'] as int) < 30;
          },
        ),
        columns: columns,
        rows: rows,
      );

      final csv = serializer.serialize();
      expect(csv.contains('"Alice"'), isTrue);
      expect(csv.contains('"Bob"'), isFalse); // age 25 < 30, skipped
      expect(csv.contains('"Charlie"'), isTrue);
    });

    test('rowIndex in shouldRowBeSkipped is output index', () {
      final columns = [const OsColumnDef(field: 'name', headerName: 'Name')];

      final rows = <Map<String, dynamic>>[
        {'name': 'Alice'},
        {'name': 'Bob'},
        {'name': 'Charlie'},
      ];

      final capturedIndices = <int>[];
      final serializer = CsvSerializer<Map<String, dynamic>>(
        params: OsCsvExportParams(
          shouldRowBeSkipped: (params) {
            capturedIndices.add(params.rowIndex);
            return false;
          },
        ),
        columns: columns,
        rows: rows,
      );

      serializer.serialize();
      expect(capturedIndices, [0, 1, 2]);
    });
  });

  group('CsvSerializer - prependContent and appendContent', () {
    test('prepends content before headers', () {
      final columns = [const OsColumnDef(field: 'name', headerName: 'Name')];

      final rows = <Map<String, dynamic>>[
        {'name': 'Alice'},
      ];

      final serializer = CsvSerializer<Map<String, dynamic>>(
        params: const OsCsvExportParams(prependContent: 'Report Title'),
        columns: columns,
        rows: rows,
      );

      final csv = serializer.serialize();
      // BOM + prepend content should come before headers
      final withoutBom = csv.substring(1);
      expect(withoutBom.startsWith('Report Title\r\n'), isTrue);
    });

    test('appends content after data', () {
      final columns = [const OsColumnDef(field: 'name', headerName: 'Name')];

      final rows = <Map<String, dynamic>>[
        {'name': 'Alice'},
      ];

      final serializer = CsvSerializer<Map<String, dynamic>>(
        params: const OsCsvExportParams(appendContent: 'End of Report'),
        columns: columns,
        rows: rows,
      );

      final csv = serializer.serialize();
      expect(csv.endsWith('End of Report'), isTrue);
    });
  });

  group('CsvSerializer - edge cases', () {
    test('empty string values are quoted', () {
      final columns = [const OsColumnDef(field: 'name', headerName: 'Name')];

      final rows = <Map<String, dynamic>>[
        {'name': ''},
      ];

      final serializer = CsvSerializer<Map<String, dynamic>>(
        params: const OsCsvExportParams(),
        columns: columns,
        rows: rows,
      );

      final csv = serializer.serialize();
      // After BOM and header, the data row should have ""
      final withoutBom = csv.substring(1);
      final lines = withoutBom.split('\r\n');
      expect(lines[1], '""'); // empty string quoted
    });

    test('missing field in map returns empty', () {
      final columns = [
        const OsColumnDef(field: 'name', headerName: 'Name'),
        const OsColumnDef(field: 'missing', headerName: 'Missing'),
      ];

      final rows = <Map<String, dynamic>>[
        {'name': 'Alice'},
      ];

      final serializer = CsvSerializer<Map<String, dynamic>>(
        params: const OsCsvExportParams(),
        columns: columns,
        rows: rows,
      );

      final csv = serializer.serialize();
      // Missing field should produce empty quoted value
      final withoutBom = csv.substring(1);
      final lines = withoutBom.split('\r\n');
      expect(lines[1], '"Alice",""');
    });

    test('boolean values are stringified', () {
      final columns = [
        const OsColumnDef(field: 'active', headerName: 'Active'),
      ];

      final rows = <Map<String, dynamic>>[
        {'active': true},
        {'active': false},
      ];

      final serializer = CsvSerializer<Map<String, dynamic>>(
        params: const OsCsvExportParams(),
        columns: columns,
        rows: rows,
      );

      final csv = serializer.serialize();
      expect(csv.contains('"true"'), isTrue);
      expect(csv.contains('"false"'), isTrue);
    });

    test('large numbers are not truncated', () {
      final columns = [const OsColumnDef(field: 'id', headerName: 'ID')];

      final rows = <Map<String, dynamic>>[
        {'id': 9007199254740992}, // 2^53
      ];

      final serializer = CsvSerializer<Map<String, dynamic>>(
        params: const OsCsvExportParams(),
        columns: columns,
        rows: rows,
      );

      final csv = serializer.serialize();
      expect(csv.contains('"9007199254740992"'), isTrue);
    });

    test('empty rows produces only headers', () {
      final columns = [
        const OsColumnDef(field: 'name', headerName: 'Name'),
        const OsColumnDef(field: 'age', headerName: 'Age'),
      ];

      final serializer = CsvSerializer<Map<String, dynamic>>(
        params: const OsCsvExportParams(),
        columns: <OsColumnDef>[columns[0], columns[1]],
        rows: <Map<String, dynamic>>[],
      );

      final csv = serializer.serialize();
      // BOM + header row only
      expect(csv, '\ufeff"Name","Age"');
    });

    test('empty rows with skipColumnHeaders produces only BOM', () {
      final columns = [const OsColumnDef(field: 'name', headerName: 'Name')];

      final serializer = CsvSerializer<Map<String, dynamic>>(
        params: const OsCsvExportParams(skipColumnHeaders: true),
        columns: columns,
        rows: <Map<String, dynamic>>[],
      );

      final csv = serializer.serialize();
      // Only BOM
      expect(csv, '\ufeff');
    });

    test('valueGetter with valueFormatter combined', () {
      final columns = [
        OsColumnDef<_Person>(
          field: 'fullName',
          headerName: 'Name',
          valueGetter: (params) =>
              '${params.data.firstName} ${params.data.lastName}',
          valueFormatter: (params) => (params.value as String).toUpperCase(),
        ),
      ];

      final rows = [_Person('Alice', 'Smith', 30)];

      final serializer = CsvSerializer<_Person>(
        params: const OsCsvExportParams(),
        columns: columns,
        rows: rows,
      );

      final csv = serializer.serialize();
      // valueGetter extracts "Alice Smith", valueFormatter uppercases it
      expect(csv.contains('"ALICE SMITH"'), isTrue);
    });

    test('processCellCallback receives correct colDef', () {
      const col1 = OsColumnDef(field: 'name', headerName: 'Name');
      const col2 = OsColumnDef(field: 'age', headerName: 'Age');

      final capturedFields = <String?>[];
      final serializer = CsvSerializer<Map<String, dynamic>>(
        params: OsCsvExportParams(
          processCellCallback: (params) {
            capturedFields.add(params.colDef.field);
            return params.value?.toString() ?? '';
          },
        ),
        columns: [col1, col2],
        rows: <Map<String, dynamic>>[
          {'name': 'Alice', 'age': 30},
        ],
      );

      serializer.serialize();
      expect(capturedFields, ['name', 'age']);
    });

    test('processCellCallback receives correct rowIndex', () {
      final columns = [const OsColumnDef(field: 'name', headerName: 'Name')];

      final capturedIndices = <int>[];
      final serializer = CsvSerializer<Map<String, dynamic>>(
        params: OsCsvExportParams(
          processCellCallback: (params) {
            capturedIndices.add(params.rowIndex);
            return params.value?.toString() ?? '';
          },
        ),
        columns: columns,
        rows: <Map<String, dynamic>>[
          {'name': 'Alice'},
          {'name': 'Bob'},
          {'name': 'Charlie'},
        ],
      );

      serializer.serialize();
      expect(capturedIndices, [0, 1, 2]);
    });
  });

  group('CsvSerializer - sanitizeFormulas', () {
    final dangerousColumns = [
      const OsColumnDef(field: 'payload', headerName: 'Payload'),
    ];

    test('default is off and output bytes are unchanged', () {
      final rows = <Map<String, dynamic>>[
        {'payload': '=1+1'},
        {'payload': '+SUM(A1)'},
        {'payload': '-2*3'},
        {'payload': '@cmd'},
        {'payload': 'plain text'},
      ];

      final defaultParams = CsvSerializer<Map<String, dynamic>>(
        params: const OsCsvExportParams(),
        columns: dangerousColumns,
        rows: rows,
      ).serialize();

      final explicitOff = CsvSerializer<Map<String, dynamic>>(
        params: const OsCsvExportParams(sanitizeFormulas: false),
        columns: dangerousColumns,
        rows: rows,
      ).serialize();

      expect(defaultParams, explicitOff);
      // Exact byte preservation when the guard is off.
      expect(
        defaultParams,
        '\ufeff"Payload"\r\n"=1+1"\r\n"+SUM(A1)"\r\n"-2*3"\r\n"@cmd"\r\n'
        '"plain text"',
      );
    });

    test('leading formula characters get a single-quote prefix', () {
      final rows = <Map<String, dynamic>>[
        {'payload': '=1+1'},
        {'payload': '+SUM(A1:A10)'},
        {'payload': '-2*3'},
        {'payload': '@cmd|calc'},
      ];

      final csv = CsvSerializer<Map<String, dynamic>>(
        params: const OsCsvExportParams(sanitizeFormulas: true),
        columns: dangerousColumns,
        rows: rows,
      ).serialize();

      expect(csv.contains('"\'=1+1"'), isTrue);
      expect(csv.contains('"\'+SUM(A1:A10)"'), isTrue);
      expect(csv.contains('"\'-2*3"'), isTrue);
      expect(csv.contains('"\'@cmd|calc"'), isTrue);

      final withoutBom = csv.substring(1);
      expect(withoutBom.contains('"=1+1"'), isFalse);
    });

    test('tab/CR prefixes followed by formula characters are sanitised', () {
      final rows = <Map<String, dynamic>>[
        {'payload': '\t=SUM(A1)'},
        {'payload': '\r=cmd'},
      ];

      final csv = CsvSerializer<Map<String, dynamic>>(
        params: const OsCsvExportParams(sanitizeFormulas: true),
        columns: dangerousColumns,
        rows: rows,
      ).serialize();

      expect(csv.contains('"\'\t=SUM(A1)"'), isTrue);
      expect(csv.contains('"\'\r=cmd"'), isTrue);
    });

    test('safe values are left untouched', () {
      final rows = <Map<String, dynamic>>[
        {'payload': 'plain text'},
        {'payload': '2-3'},
        {'payload': ''},
      ];
      final nullRows = <Map<String, dynamic>>[
        {'payload': null},
      ];

      final csv = CsvSerializer<Map<String, dynamic>>(
        params: const OsCsvExportParams(sanitizeFormulas: true),
        columns: dangerousColumns,
        rows: rows,
      ).serialize();
      final nullCsv = CsvSerializer<Map<String, dynamic>>(
        params: const OsCsvExportParams(sanitizeFormulas: true),
        columns: dangerousColumns,
        rows: nullRows,
      ).serialize();

      expect(csv.contains('"plain text"'), isTrue);
      expect(csv.contains('"2-3"'), isTrue);
      expect(csv, isNot(contains("'")));
      expect(nullCsv.contains('""'), isTrue);
    });

    test('processCellCallback output is sanitised too', () {
      final rows = <Map<String, dynamic>>[
        {'payload': 'innocent'},
      ];

      final csv = CsvSerializer<Map<String, dynamic>>(
        params: OsCsvExportParams(
          sanitizeFormulas: true,
          processCellCallback: (params) => '=HACKED(${params.value})',
        ),
        columns: dangerousColumns,
        rows: rows,
      ).serialize();

      expect(csv.contains('"\'=HACKED(innocent)"'), isTrue);
      expect(csv.contains('"=HACKED'), isFalse);
    });

    test('without the flag, callback output stays as-is', () {
      final rows = <Map<String, dynamic>>[
        {'payload': 'innocent'},
      ];

      final csv = CsvSerializer<Map<String, dynamic>>(
        params: OsCsvExportParams(
          processCellCallback: (params) => '=HACKED(${params.value})',
        ),
        columns: dangerousColumns,
        rows: rows,
      ).serialize();

      expect(csv.contains('"=HACKED(innocent)"'), isTrue);
    });

    test('headers are data cells only — header row is not sanitised', () {
      final evilHeaderColumns = [
        const OsColumnDef(field: 'payload', headerName: '=EVIL'),
      ];
      final rows = <Map<String, dynamic>>[
        {'payload': '=x'},
      ];

      final csv = CsvSerializer<Map<String, dynamic>>(
        params: const OsCsvExportParams(sanitizeFormulas: true),
        columns: evilHeaderColumns,
        rows: rows,
      ).serialize();

      expect(csv.startsWith('\ufeff"=EVIL"'), isTrue);
      expect(csv.contains('"\'=x"'), isTrue);
    });
  });
}

/// Test helper class for typed data tests.
class _Person {
  _Person(this.firstName, this.lastName, this.age);
  final String firstName;
  final String lastName;
  final int age;
}
