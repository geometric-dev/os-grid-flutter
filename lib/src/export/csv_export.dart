import '../columns/os_column_def.dart';
import '../params/value_formatter_params.dart';
import '../params/value_getter_params.dart';

/// Which rows to include in the export.
enum ExportedRows {
  /// Export all rows regardless of current filter/sort state.
  all,

  /// Export only rows that pass the current filter, in the current sort order.
  /// This is the default — it exports what the user sees on screen.
  filteredAndSorted,
}

/// Parameters for CSV export.
///
/// All options are optional and have sensible defaults matching OS Grid's
/// TypeScript behaviour.
///
/// ```dart
/// final csv = controller.exportCsv(
///   params: OsCsvExportParams(
///     columnSeparator: ',',
///     exportedRows: ExportedRows.filteredAndSorted,
///     processCellCallback: (params) => params.value?.toString() ?? '',
///   ),
/// );
/// ```
class OsCsvExportParams {
  const OsCsvExportParams({
    this.fileName,
    this.columnSeparator = ',',
    this.suppressQuotes = false,
    this.skipColumnHeaders = false,
    this.allColumns = false,
    this.columnKeys,
    this.exportedRows = ExportedRows.filteredAndSorted,
    this.onlySelected = false,
    this.shouldRowBeSkipped,
    this.processCellCallback,
    this.processHeaderCallback,
    this.prependContent,
    this.appendContent,
    this.sanitizeFormulas = false,
  });

  /// File name for the exported CSV. Defaults to 'export.csv'.
  final String? fileName;

  /// Delimiter between cell values. Defaults to comma.
  final String columnSeparator;

  /// When `true`, cell values are not wrapped in double quotes.
  /// It is then your responsibility to ensure no values contain the
  /// [columnSeparator] character.
  final bool suppressQuotes;

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
  final String Function(ProcessCellForExportParams)? processCellCallback;

  /// Callback invoked once per column header. Return a string to use
  /// as the header name in the export.
  final String Function(ProcessHeaderForExportParams)? processHeaderCallback;

  /// Content to prepend before the data rows (raw CSV string).
  final String? prependContent;

  /// Content to append after the data rows (raw CSV string).
  final String? appendContent;

  /// When `true`, data cell values that a spreadsheet application could
  /// interpret as formulas are neutralised by prefixing them with a single
  /// quote (`'`) — the standard CSV formula-injection (CSV injection,
  /// CWE-1236) guard.
  ///
  /// A cell is treated as formula-like when its exported string form starts
  /// with `=`, `+`, `-` or `@`, or with tab/CR characters followed by one of
  /// those characters.
  ///
  /// Sanitisation applies to the final exported cell text, i.e. **after**
  /// [processCellCallback] output (and after `valueFormatter` formatting),
  /// so callbacks cannot re-introduce an unsafe prefix.
  ///
  /// AG Grid analog: AG Grid has no dedicated flag for this and documents
  /// the same protection as a manual `processCellCallback` recipe; this
  /// option packages that behaviour behind a switch. It is off by default
  /// to preserve byte-exact output for existing exports.
  final bool sanitizeFormulas;
}

/// Parameters passed to [OsCsvExportParams.shouldRowBeSkipped].
class ShouldRowBeSkippedParams<TData> {
  const ShouldRowBeSkippedParams({required this.data, required this.rowIndex});

  /// The row data object.
  final TData data;

  /// The row's index in the export output (zero-based, excluding headers).
  final int rowIndex;
}

/// Parameters passed to [OsCsvExportParams.processCellCallback].
class ProcessCellForExportParams<TData> {
  const ProcessCellForExportParams({
    required this.value,
    required this.rowIndex,
    required this.data,
    required this.colDef,
    required this.formatValue,
  });

  /// The raw cell value (before formatting).
  final dynamic value;

  /// The row's index in the export output (zero-based, excluding headers).
  final int rowIndex;

  /// The full row data object.
  final TData data;

  /// The column definition for this cell.
  final OsColumnDef colDef;

  /// Utility function: formats the value using the column's valueFormatter.
  /// Returns the formatted string, or `value.toString()` if no formatter.
  final String Function(dynamic value) formatValue;
}

/// Parameters passed to [OsCsvExportParams.processHeaderCallback].
class ProcessHeaderForExportParams {
  const ProcessHeaderForExportParams({required this.colDef});

  /// The column definition whose header is being exported.
  final OsColumnDef colDef;
}

/// UTF-8 BOM character for Excel compatibility.
const String csvBom = '\ufeff';

/// Line separator used in CSV output (Windows/Excel compatible).
const String csvLineSeparator = '\r\n';

/// Generates a CSV string from grid data.
///
/// This is the core export engine, separated from the controller for
/// testability and single responsibility.
class CsvSerializer<TData> {
  const CsvSerializer({
    required this.params,
    required this.columns,
    required this.rows,
  });

  /// Export configuration.
  final OsCsvExportParams params;

  /// The columns to export (already filtered for visibility/keys).
  final List<OsColumnDef> columns;

  /// The rows to export (already filtered for selection/exportedRows).
  final List<TData> rows;

  /// Generate the CSV string.
  ///
  /// The output includes a UTF-8 BOM prefix and uses `\r\n` line endings
  /// for Excel compatibility.
  String serialize() {
    final sep = params.columnSeparator;
    final parts = <String>[];

    // BOM prefix for Excel compatibility
    parts.add(csvBom);

    // Prepend content
    if (params.prependContent != null && params.prependContent!.isNotEmpty) {
      parts.add(params.prependContent!);
      parts.add(csvLineSeparator);
    }

    // Header row
    if (!params.skipColumnHeaders) {
      final headers = <String>[];
      for (final col in columns) {
        String headerValue;
        if (params.processHeaderCallback != null) {
          headerValue = params.processHeaderCallback!(
            ProcessHeaderForExportParams(colDef: col),
          );
        } else {
          headerValue = col.effectiveHeaderName;
        }
        headers.add(_quoteValue(headerValue, sep));
      }
      parts.add(headers.join(sep));
      parts.add(csvLineSeparator);
    }

    // Data rows
    int exportRowIndex = 0;
    for (final row in rows) {
      // Check shouldRowBeSkipped
      if (params.shouldRowBeSkipped != null) {
        final shouldSkip = params.shouldRowBeSkipped!(
          ShouldRowBeSkippedParams(data: row, rowIndex: exportRowIndex),
        );
        if (shouldSkip) continue;
      }

      final cells = <String>[];
      for (final col in columns) {
        final rawValue = _extractRawValue(col, row, exportRowIndex);
        String cellValue;

        if (params.processCellCallback != null) {
          cellValue = params.processCellCallback!(
            ProcessCellForExportParams(
              value: rawValue,
              rowIndex: exportRowIndex,
              data: row,
              colDef: col,
              formatValue: (v) => _formatValue(col, v, exportRowIndex),
            ),
          );
        } else {
          // Apply valueFormatter by default (matching TypeScript behaviour)
          cellValue = _formatValue(col, rawValue, exportRowIndex);
        }

        // Formula-injection guard runs on the final cell text (post-callback)
        if (params.sanitizeFormulas) {
          cellValue = _sanitizeFormula(cellValue);
        }

        cells.add(_quoteValue(cellValue, sep));
      }
      parts.add(cells.join(sep));
      parts.add(csvLineSeparator);
      exportRowIndex++;
    }

    // Remove trailing line separator if we have data rows
    // (TypeScript does not add a trailing newline)
    if (parts.isNotEmpty && parts.last == csvLineSeparator) {
      parts.removeLast();
    }

    // Append content
    if (params.appendContent != null && params.appendContent!.isNotEmpty) {
      parts.add(csvLineSeparator);
      parts.add(params.appendContent!);
    }

    return parts.join();
  }

  /// Extract the raw value from a row for a given column.
  dynamic _extractRawValue(OsColumnDef col, TData row, int rowIndex) {
    // Try valueGetter first.
    // We use getValueGetterAsFunction() to avoid Dart's contravariance issue
    // when OsColumnDef<Person> is stored in a List<OsColumnDef<dynamic>>.
    final getter = col.getValueGetterAsFunction();
    if (getter != null) {
      return Function.apply(getter, [
        ValueGetterParams<TData>(data: row, rowIndex: rowIndex),
      ]);
    }

    // Fall back to field lookup on Map data
    if (col.field != null && row is Map<String, dynamic>) {
      return row[col.field];
    }

    return null;
  }

  /// Format a value using the column's valueFormatter, or toString().
  String _formatValue(OsColumnDef col, dynamic value, int rowIndex) {
    if (value == null) return '';

    if (col.valueFormatter != null) {
      return col.valueFormatter!(
        ValueFormatterParams(value: value, rowIndex: rowIndex),
      );
    }

    return value.toString();
  }

  /// Quote a value for CSV output.
  ///
  /// When [OsCsvExportParams.suppressQuotes] is true, returns the value as-is.
  /// Otherwise wraps in double quotes and escapes internal double quotes.
  String _quoteValue(String value, String separator) {
    if (params.suppressQuotes) {
      return value;
    }

    // Always quote values (matching TypeScript's putInQuotes behaviour)
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }

  /// Prefixes formula-like cell text with a single quote.
  ///
  /// A value is formula-like when it starts with `=`, `+`, `-` or `@`, or
  /// when leading tab/CR characters are followed by one of those characters
  /// (spreadsheets evaluate such cells as formulas when the CSV is opened).
  String _sanitizeFormula(String value) {
    if (!_startsLikeFormula(value)) return value;
    return "'$value";
  }

  /// Whether [value] would be interpreted as a spreadsheet formula.
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
