/// Parameter types for cell span callbacks.
library;

/// Parameters passed to the `colSpan` callback on a column definition.
///
/// The callback should return the number of columns this cell spans (1 = normal).
class ColSpanParams<TData> {
  const ColSpanParams({
    required this.data,
    required this.rowIndex,
    required this.column,
  });

  /// The row data for this cell.
  final TData data;

  /// The display row index.
  final int rowIndex;

  /// The column field name (or colId).
  final String column;
}

/// Parameters passed to the `rowSpan` callback on a column definition.
///
/// The callback should return the number of rows this cell spans (1 = normal).
class RowSpanParams<TData> {
  const RowSpanParams({
    required this.data,
    required this.rowIndex,
    required this.column,
  });

  /// The row data for this cell.
  final TData data;

  /// The display row index.
  final int rowIndex;

  /// The column field name (or colId).
  final String column;
}

/// Parameters passed to the `spanRows` callback on a column definition when
/// using a custom comparison function.
///
/// The callback should return `true` if the two values should be merged
/// (i.e., the span should continue), or `false` to break the span.
class SpanRowsParams<TData> {
  const SpanRowsParams({
    required this.valueA,
    required this.nodeA,
    required this.valueB,
    required this.nodeB,
    required this.column,
  });

  /// The value of the first row (span head).
  final dynamic valueA;

  /// The row data of the first row (span head).
  final TData? nodeA;

  /// The value of the next row being tested.
  final dynamic valueB;

  /// The row data of the next row being tested.
  final TData? nodeB;

  /// The column field name (or colId).
  final String column;
}
