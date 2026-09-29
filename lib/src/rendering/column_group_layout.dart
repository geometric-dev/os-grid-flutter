/// Describes a column group span for rendering the group header row.
///
/// Each entry represents one group header cell that spans multiple leaf columns.
class ColumnGroupSpan {
  const ColumnGroupSpan({
    required this.headerName,
    required this.startIndex,
    required this.endIndex,
  });

  /// Display name for the group header.
  final String headerName;

  /// First leaf column index (inclusive) in this group.
  final int startIndex;

  /// Last leaf column index (inclusive) in this group.
  final int endIndex;

  /// Number of leaf columns this group spans.
  int get span => endIndex - startIndex + 1;
}
