/// Data model for cell spanning.
library;

/// Represents a vertical span of merged cells in a single column.
///
/// A [RowSpanGroup] covers rows from [firstRowIndex] to [lastRowIndex]
/// inclusive. The cell is rendered at the first row's position with a height
/// spanning all rows in the group.
class RowSpanGroup {
  RowSpanGroup({
    required this.firstRowIndex,
    required this.lastRowIndex,
    required this.colId,
  });

  /// The first (topmost) row index in this span group.
  final int firstRowIndex;

  /// The last (bottommost) row index in this span group.
  final int lastRowIndex;

  /// The column identifier for this span.
  final String colId;

  /// The number of rows this span covers.
  int get rowCount => lastRowIndex - firstRowIndex + 1;

  /// Whether the given [rowIndex] is within this span but is NOT the first row.
  ///
  /// Cells at these positions should be skipped during painting — the first
  /// row's cell is painted with extended height instead.
  bool isConsumedRow(int rowIndex) =>
      rowIndex > firstRowIndex && rowIndex <= lastRowIndex;

  /// Whether the given [rowIndex] is the head (first row) of this span.
  bool isHead(int rowIndex) => rowIndex == firstRowIndex;

  /// Whether the given [rowIndex] falls within this span (head or consumed).
  bool contains(int rowIndex) =>
      rowIndex >= firstRowIndex && rowIndex <= lastRowIndex;
}
