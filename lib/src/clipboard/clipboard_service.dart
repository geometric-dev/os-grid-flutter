import '../columns/os_column_def.dart';
import '../params/value_formatter_params.dart';
import '../params/value_getter_params.dart';

/// Parameters passed to `processCellForClipboard` callbacks.
///
/// Allows transforming cell values before they are written to the clipboard.
class ProcessCellForClipboardParams<TData> {
  const ProcessCellForClipboardParams({
    required this.value,
    required this.rowIndex,
    required this.data,
    required this.colDef,
    required this.formatValue,
  });

  /// The raw cell value (before formatting).
  final dynamic value;

  /// The row's index in the processed (filtered/sorted) data.
  final int rowIndex;

  /// The full row data object.
  final TData data;

  /// The column definition for this cell.
  final OsColumnDef colDef;

  /// Utility function: formats the value using the column's valueFormatter.
  /// Returns the formatted string, or `value.toString()` if no formatter.
  final String Function(dynamic value) formatValue;
}

/// Parameters passed to `processHeaderForClipboard` callbacks.
///
/// Allows transforming header names before they are written to the clipboard.
class ProcessHeaderForClipboardParams {
  const ProcessHeaderForClipboardParams({required this.colDef});

  /// The column definition whose header is being copied.
  final OsColumnDef colDef;
}

/// Parameters passed to `processCellFromClipboard` callbacks.
///
/// Allows transforming pasted values before they are applied to cells.
class ProcessCellFromClipboardParams<TData> {
  const ProcessCellFromClipboardParams({
    required this.value,
    required this.rowIndex,
    required this.data,
    required this.colDef,
  });

  /// The raw string value from the clipboard.
  final String value;

  /// The target row index.
  final int rowIndex;

  /// The target row data object.
  final TData data;

  /// The column definition for the target cell.
  final OsColumnDef colDef;
}

/// Serialises grid cell data to TSV format for clipboard copy.
///
/// Produces tab-separated values with newline-separated rows, which is
/// the standard format expected by Excel and Google Sheets.
class ClipboardSerializer<TData> {
  const ClipboardSerializer({
    required this.columns,
    required this.rows,
    required this.rowStartIndex,
    this.delimiter = '\t',
    this.includeHeaders = false,
    this.processCellForClipboard,
    this.processHeaderForClipboard,
  });

  /// The columns to include in the copy (in display order).
  final List<OsColumnDef> columns;

  /// The rows to copy.
  final List<TData> rows;

  /// The starting row index in the processed data (for callback params).
  final int rowStartIndex;

  /// Delimiter between cell values. Defaults to tab.
  final String delimiter;

  /// Whether to include column headers as the first row.
  final bool includeHeaders;

  /// Optional callback to transform cell values before copy.
  final String Function(ProcessCellForClipboardParams<TData>)?
  processCellForClipboard;

  /// Optional callback to transform header names before copy.
  final String Function(ProcessHeaderForClipboardParams)?
  processHeaderForClipboard;

  /// Generate the TSV string for the clipboard.
  String serialize() {
    final lines = <String>[];

    // Header row
    if (includeHeaders) {
      final headers = <String>[];
      for (final col in columns) {
        if (processHeaderForClipboard != null) {
          headers.add(
            processHeaderForClipboard!(
              ProcessHeaderForClipboardParams(colDef: col),
            ),
          );
        } else {
          headers.add(col.effectiveHeaderName);
        }
      }
      lines.add(headers.join(delimiter));
    }

    // Data rows
    for (int i = 0; i < rows.length; i++) {
      final row = rows[i];
      final rowIndex = rowStartIndex + i;
      final cells = <String>[];

      for (final col in columns) {
        final rawValue = _extractRawValue(col, row, rowIndex);

        if (processCellForClipboard != null) {
          cells.add(
            processCellForClipboard!(
              ProcessCellForClipboardParams<TData>(
                value: rawValue,
                rowIndex: rowIndex,
                data: row,
                colDef: col,
                formatValue: (v) => _formatValue(col, v, rowIndex),
              ),
            ),
          );
        } else {
          // Apply valueFormatter by default (matching TypeScript behaviour)
          cells.add(_formatValue(col, rawValue, rowIndex));
        }
      }
      lines.add(cells.join(delimiter));
    }

    return lines.join('\n');
  }

  /// Extract the raw value from a row for a given column.
  dynamic _extractRawValue(OsColumnDef col, TData row, int rowIndex) {
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
}

/// Parses TSV clipboard content into a 2D grid of string values.
///
/// Handles tab-separated columns and newline-separated rows.
/// Supports both `\n` and `\r\n` line endings.
class ClipboardParser {
  const ClipboardParser({this.delimiter = '\t'});

  /// The delimiter between cell values.
  final String delimiter;

  /// Parse clipboard text into a 2D list of cell values.
  ///
  /// Returns a list of rows, where each row is a list of cell strings.
  /// Empty trailing rows are removed.
  List<List<String>> parse(String text) {
    if (text.isEmpty) return [];

    // Normalise line endings
    final normalised = text.replaceAll('\r\n', '\n');

    // Split into rows, removing trailing empty row (common with copy)
    var rows = normalised.split('\n');
    if (rows.isNotEmpty && rows.last.isEmpty) {
      rows = rows.sublist(0, rows.length - 1);
    }

    // Split each row into cells
    return rows.map((row) => row.split(delimiter)).toList();
  }
}

/// Result of a paste operation for a single cell.
class PasteCellResult {
  const PasteCellResult({
    required this.rowIndex,
    required this.columnId,
    required this.oldValue,
    required this.newValue,
    required this.data,
    required this.colDef,
  });

  /// The row index of the pasted cell.
  final int rowIndex;

  /// The column ID of the pasted cell.
  final String columnId;

  /// The value before paste.
  final dynamic oldValue;

  /// The value after paste.
  final dynamic newValue;

  /// The row data object.
  final dynamic data;

  /// The column definition.
  final OsColumnDef colDef;
}
