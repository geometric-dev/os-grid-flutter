import 'dart:convert';

import '../columns/os_column_def.dart';
import '../params/value_formatter_params.dart';
import '../params/value_getter_params.dart';
import 'csv_export.dart';
import 'zip_writer.dart';

/// Parameters for Excel (.xlsx) export.
///
/// Mirrors [OsCsvExportParams] for the options that are meaningful to a
/// spreadsheet export (the CSV-only text options — separator, quoting and
/// prepended/appended content — do not apply). Column and row resolution
/// semantics are identical to CSV export.
///
/// ```dart
/// final bytes = controller.exportXlsx(
///   params: OsXlsxExportParams(
///     exportedRows: ExportedRows.filteredAndSorted,
///     processCellCallback: (params) => params.value?.toString() ?? '',
///   ),
/// );
/// ```
class OsXlsxExportParams {
  const OsXlsxExportParams({
    this.fileName,
    this.sheetName = 'Sheet1',
    this.skipColumnHeaders = false,
    this.allColumns = false,
    this.columnKeys,
    this.exportedRows = ExportedRows.filteredAndSorted,
    this.onlySelected = false,
    this.shouldRowBeSkipped,
    this.processCellCallback,
    this.processHeaderCallback,
    this.sanitizeFormulas = false,
  });

  /// File name for the exported workbook. Defaults to 'export.xlsx'.
  final String? fileName;

  /// Name of the single worksheet in the workbook. Defaults to 'Sheet1'.
  ///
  /// Invalid characters (`: \ / ? * [ ]`) are replaced with `_` and names
  /// longer than 31 characters are truncated, per Excel's limits.
  final String sheetName;

  /// When `true`, the column header row is not included in the output.
  final bool skipColumnHeaders;

  /// When `true`, export all columns regardless of visibility.
  /// When `false` (default), only visible columns are exported.
  final bool allColumns;

  /// Specific column IDs/fields to export. When provided, only these
  /// columns are exported (in the order specified), regardless of
  /// [allColumns] or visibility state.
  final List<String>? columnKeys;

  /// Which rows to include in the export.
  /// Defaults to [ExportedRows.filteredAndSorted] — exports what the user
  /// sees on screen (respecting current filter and sort state).
  final ExportedRows exportedRows;

  /// When `true`, only export currently selected rows.
  /// Takes precedence over [exportedRows].
  final bool onlySelected;

  /// Callback invoked once per row. Return `true` to skip the row.
  final bool Function(ShouldRowBeSkippedParams)? shouldRowBeSkipped;

  /// Callback invoked once per cell. Return a string to use as the
  /// exported cell value. Overrides `valueFormatter` when provided.
  /// Callback output is exported as a text cell.
  final String Function(ProcessCellForExportParams)? processCellCallback;

  /// Callback invoked once per column header. Return a string to use
  /// as the header name in the export.
  final String Function(ProcessHeaderForExportParams)? processHeaderCallback;

  /// When `true`, text cell values that a spreadsheet application could
  /// interpret as formulas are neutralised by prefixing them with a single
  /// quote (`'`) — the same formula-injection guard as
  /// [OsCsvExportParams.sanitizeFormulas].
  ///
  /// A value is treated as formula-like when its exported string form starts
  /// with `=`, `+`, `-` or `@`, or with tab/CR characters followed by one of
  /// those characters. Sanitisation applies to the final cell text, i.e.
  /// **after** [processCellCallback] output (and after `valueFormatter`
  /// formatting), so callbacks cannot re-introduce an unsafe prefix.
  /// Numeric and boolean cells are never sanitised.
  ///
  /// It is off by default to preserve byte-exact output for existing
  /// exports.
  final bool sanitizeFormulas;
}

/// Generates the bytes of a single-sheet `.xlsx` workbook from grid data.
///
/// This is the core export engine, mirroring [CsvSerializer]: the
/// controller resolves columns and rows, and the serializer turns them
/// into OOXML. The workbook is a ZIP package built by [ZipWriter]
/// containing `[Content_Types].xml`, the package relationships,
/// `xl/workbook.xml`, its relationships and `xl/worksheets/sheet1.xml`.
///
/// Cell types are inferred from the raw value:
/// - `num` values become numeric cells (unless a `valueFormatter` or
///   [OsXlsxExportParams.processCellCallback] produces text — formatted
///   output is what the user sees, so it wins and is exported as text);
/// - `bool` values become boolean cells (`t="b"`);
/// - everything else (and `null`, which produces an omitted cell) becomes
///   inline-string text.
class XlsxSerializer<TData> {
  const XlsxSerializer({
    required this.params,
    required this.columns,
    required this.rows,
    this.columnWidths = const <String, double>{},
  });

  /// Export configuration.
  final OsXlsxExportParams params;

  /// The columns to export (already filtered for visibility/keys).
  final List<OsColumnDef> columns;

  /// The rows to export (already filtered for selection/exportedRows).
  final List<TData> rows;

  /// Current display widths keyed by colId, used for the `<cols>` element.
  /// Falls back to the column definition width, then the grid default
  /// (150 logical pixels).
  final Map<String, double> columnWidths;

  /// Generate the workbook bytes.
  List<int> serialize() {
    final zip = ZipWriter()
      ..add('[Content_Types].xml', utf8.encode(_contentTypesXml))
      ..add('_rels/.rels', utf8.encode(_rootRelationshipsXml))
      ..add('xl/workbook.xml', utf8.encode(_buildWorkbookXml()))
      ..add(
        'xl/_rels/workbook.xml.rels',
        utf8.encode(_workbookRelationshipsXml),
      )
      ..add('xl/worksheets/sheet1.xml', utf8.encode(_buildSheetXml()));
    return zip.build();
  }

  // --- Worksheet ---

  String _buildSheetXml() {
    final buffer = StringBuffer()
      ..write(_xmlDeclaration)
      ..write(
        '<worksheet xmlns="http://schemas.openxmlformats.org/'
        'spreadsheetml/2006/main">',
      )
      ..write(_buildColsXml())
      ..write('<sheetData>');

    var sheetRowNumber = 1;
    if (!params.skipColumnHeaders) {
      _buildRowXml(buffer, sheetRowNumber, (colIndex) => _headerCell(colIndex));
      sheetRowNumber++;
    }

    var exportRowIndex = 0;
    for (final row in rows) {
      if (params.shouldRowBeSkipped != null) {
        final shouldSkip = params.shouldRowBeSkipped!(
          ShouldRowBeSkippedParams(data: row, rowIndex: exportRowIndex),
        );
        if (shouldSkip) continue;
      }
      _buildRowXml(
        buffer,
        sheetRowNumber,
        (colIndex) => _dataCell(columns[colIndex], row, exportRowIndex),
      );
      sheetRowNumber++;
      exportRowIndex++;
    }

    buffer
      ..write('</sheetData>')
      ..write('</worksheet>');
    return buffer.toString();
  }

  /// Writes one `<row>` element, invoking [cellAt] for every exported
  /// column. Columns whose resolved cell is `null` are omitted, matching
  /// how empty spreadsheet cells behave.
  void _buildRowXml(
    StringBuffer buffer,
    int sheetRowNumber,
    _CellValue? Function(int colIndex) cellAt,
  ) {
    buffer.write('<row r="$sheetRowNumber">');
    for (var colIndex = 0; colIndex < columns.length; colIndex++) {
      final cell = cellAt(colIndex);
      if (cell == null) continue;
      _writeCellXml(buffer, colIndex, sheetRowNumber, cell);
    }
    buffer.write('</row>');
  }

  void _writeCellXml(
    StringBuffer buffer,
    int colIndex,
    int sheetRowNumber,
    _CellValue cell,
  ) {
    final reference = '${columnName(colIndex)}$sheetRowNumber';
    switch (cell) {
      case _StringCell(:final text):
        buffer.write(
          '<c r="$reference" t="inlineStr"><is><t xml:space="preserve">'
          '${escapeXml(text)}</t></is></c>',
        );
      case _NumberCell(:final value):
        buffer.write('<c r="$reference"><v>$value</v></c>');
      case _BoolCell(:final value):
        buffer.write('<c r="$reference" t="b"><v>${value ? 1 : 0}</v></c>');
    }
  }

  _CellValue? _headerCell(int colIndex) {
    final col = columns[colIndex];
    final headerValue = params.processHeaderCallback != null
        ? params.processHeaderCallback!(
            ProcessHeaderForExportParams(colDef: col),
          )
        : col.effectiveHeaderName;
    return _StringCell(headerValue);
  }

  _CellValue? _dataCell(OsColumnDef col, TData row, int exportRowIndex) {
    final rawValue = _extractRawValue(col, row, exportRowIndex);

    if (params.processCellCallback != null) {
      final text = params.processCellCallback!(
        ProcessCellForExportParams(
          value: rawValue,
          rowIndex: exportRowIndex,
          data: row,
          colDef: col,
          formatValue: (v) => _formatValue(col, v, exportRowIndex),
        ),
      );
      return _StringCell(_maybeSanitize(text));
    }

    if (rawValue == null) return null;

    // Formatted output is the display form — export it as text (mirrors
    // CSV, which applies valueFormatter by default).
    if (col.valueFormatter != null) {
      return _StringCell(
        _maybeSanitize(_formatValue(col, rawValue, exportRowIndex)),
      );
    }

    if (rawValue is bool) return _BoolCell(rawValue);

    if (rawValue is num) {
      // NaN/Infinity have no OOXML numeric representation.
      if (rawValue.isNaN || rawValue.isInfinite) {
        return _StringCell(_maybeSanitize(rawValue.toString()));
      }
      return _NumberCell(rawValue);
    }

    return _StringCell(_maybeSanitize(rawValue.toString()));
  }

  String _maybeSanitize(String text) =>
      params.sanitizeFormulas ? _sanitizeFormula(text) : text;

  /// Builds the `<cols>` element with Excel character widths converted
  /// from the current logical-pixel display widths
  /// (`width = (pixels - 5) / 7`, the Calibri 11 mapping).
  String _buildColsXml() {
    if (columns.isEmpty) return '';
    final buffer = StringBuffer()..write('<cols>');
    for (var colIndex = 0; colIndex < columns.length; colIndex++) {
      final col = columns[colIndex];
      final displayWidth =
          columnWidths[col.effectiveColId] ?? col.width ?? _defaultColumnWidth;
      final excelWidth = ((displayWidth - 5) / 7).clamp(1.0, 255.0);
      buffer.write(
        '<col min="${colIndex + 1}" max="${colIndex + 1}" '
        'width="${excelWidth.toStringAsFixed(2)}" customWidth="1"/>',
      );
    }
    buffer.write('</cols>');
    return buffer.toString();
  }

  // --- Workbook parts ---

  String _buildWorkbookXml() {
    return '$_xmlDeclaration'
        '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/'
        '2006/main" xmlns:r="http://schemas.openxmlformats.org/'
        'officeDocument/2006/relationships"><sheets><sheet '
        'name="${escapeXml(_sanitizeSheetName(params.sheetName))}" '
        'sheetId="1" r:id="rId1"/></sheets></workbook>';
  }

  String _sanitizeSheetName(String name) {
    var sanitized = name.replaceAll(RegExp(r'[:\\/?*\[\]]'), '_');
    if (sanitized.length > 31) sanitized = sanitized.substring(0, 31);
    if (sanitized.isEmpty) sanitized = 'Sheet1';
    return sanitized;
  }

  // --- Value resolution (mirrors CsvSerializer) ---

  dynamic _extractRawValue(OsColumnDef col, TData row, int rowIndex) {
    // Try valueGetter first. getValueGetterAsFunction() avoids Dart's
    // contravariance issue when OsColumnDef<T> is stored in a
    // List<OsColumnDef<dynamic>>.
    final getter = col.getValueGetterAsFunction();
    if (getter != null) {
      return Function.apply(getter, [
        ValueGetterParams<TData>(data: row, rowIndex: rowIndex),
      ]);
    }

    if (col.field != null && row is Map<String, dynamic>) {
      return row[col.field];
    }

    return null;
  }

  String _formatValue(OsColumnDef col, dynamic value, int rowIndex) {
    if (value == null) return '';

    if (col.valueFormatter != null) {
      return col.valueFormatter!(
        ValueFormatterParams(value: value, rowIndex: rowIndex),
      );
    }

    return value.toString();
  }

  /// Prefixes formula-like cell text with a single quote. Mirrors the CSV
  /// export guard: a value is formula-like when it starts with `=`, `+`,
  /// `-` or `@`, or when leading tab/CR characters are followed by one of
  /// those characters.
  String _sanitizeFormula(String value) {
    if (!_startsLikeFormula(value)) return value;
    return "'$value";
  }

  bool _startsLikeFormula(String value) {
    var i = 0;
    while (i < value.length &&
        (value.codeUnitAt(i) == 0x09 || value.codeUnitAt(i) == 0x0D)) {
      i++;
    }
    if (i >= value.length) return false;
    switch (value[i]) {
      case '=':
      case '+':
      case '-':
      case '@':
        return true;
      default:
        return false;
    }
  }
}

/// Resolved cell value for one export cell. `null` results are omitted
/// from the sheet entirely.
sealed class _CellValue {
  const _CellValue();
}

final class _StringCell extends _CellValue {
  const _StringCell(this.text);

  final String text;
}

final class _NumberCell extends _CellValue {
  const _NumberCell(this.value);

  final num value;
}

final class _BoolCell extends _CellValue {
  const _BoolCell(this.value);

  final bool value;
}

// --- OOXML constants and helpers ---

const String _xmlDeclaration =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>';

const double _defaultColumnWidth = 150.0;

const String _contentTypesXml =
    '$_xmlDeclaration'
    '<Types xmlns="http://schemas.openxmlformats.org/package/2006/'
    'content-types">'
    '<Default Extension="rels" ContentType="application/vnd.'
    'openxmlformats-package.relationships+xml"/>'
    '<Default Extension="xml" ContentType="application/xml"/>'
    '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.'
    'openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
    '<Override PartName="/xl/worksheets/sheet1.xml" ContentType='
    '"application/vnd.openxmlformats-officedocument.spreadsheetml.'
    'worksheet+xml"/>'
    '</Types>';

const String _rootRelationshipsXml =
    '$_xmlDeclaration'
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/'
    'relationships"><Relationship Id="rId1" Type="http://schemas.'
    'openxmlformats.org/officeDocument/2006/relationships/officeDocument" '
    'Target="xl/workbook.xml"/></Relationships>';

const String _workbookRelationshipsXml =
    '$_xmlDeclaration'
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/'
    'relationships"><Relationship Id="rId1" Type="http://schemas.'
    'openxmlformats.org/officeDocument/2006/relationships/worksheet" '
    'Target="worksheets/sheet1.xml"/></Relationships>';

/// Converts a zero-based column index to its spreadsheet reference letters
/// (`0` → `A`, `25` → `Z`, `26` → `AA`, ...).
String columnName(int index) {
  var n = index + 1;
  final letters = <int>[];
  while (n > 0) {
    letters.add(65 + ((n - 1) % 26));
    n = (n - 1) ~/ 26;
  }
  return String.fromCharCodes(letters.reversed);
}

/// Escapes XML special characters and strips control characters that are
/// invalid in XML 1.0 documents (tab, newline and carriage return are
/// preserved).
String escapeXml(String value) {
  final buffer = StringBuffer();
  for (final codeUnit in value.codeUnits) {
    switch (codeUnit) {
      case 0x26:
        buffer.write('&amp;');
      case 0x3C:
        buffer.write('&lt;');
      case 0x3E:
        buffer.write('&gt;');
      case 0x22:
        buffer.write('&quot;');
      case 0x27:
        buffer.write('&apos;');
      case 0x09:
      case 0x0A:
      case 0x0D:
        buffer.writeCharCode(codeUnit);
      default:
        if (codeUnit >= 0x20) buffer.writeCharCode(codeUnit);
    }
  }
  return buffer.toString();
}
