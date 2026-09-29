import '../columns/os_column_def.dart';
import '../columns/os_column_pin.dart';

/// Splits columns into pinned-left, center (scrollable), and pinned-right groups.
/// Mirrors OS Grid's VisibleColsService.buildTrees() pattern.
class ColumnLayout {
  ColumnLayout({
    required List<OsColumnDef> columns,
    required List<double> widths,
  }) {
    for (int i = 0; i < columns.length; i++) {
      final col = columns[i];
      final width = widths[i];
      final entry = ColumnLayoutEntry(index: i, column: col, width: width);

      if (col.pinned == OsColumnPin.left) {
        leftCols.add(entry);
        leftWidth += width;
      } else if (col.pinned == OsColumnPin.right) {
        rightCols.add(entry);
        rightWidth += width;
      } else {
        centerCols.add(entry);
        centerWidth += width;
      }
    }
  }

  /// Columns pinned to the left (rendered at fixed position, not scrolled).
  final List<ColumnLayoutEntry> leftCols = [];

  /// Scrollable center columns.
  final List<ColumnLayoutEntry> centerCols = [];

  /// Columns pinned to the right (rendered at fixed position on right edge).
  final List<ColumnLayoutEntry> rightCols = [];

  /// Total width of left-pinned columns.
  double leftWidth = 0;

  /// Total width of center (scrollable) columns.
  double centerWidth = 0;

  /// Total width of right-pinned columns.
  double rightWidth = 0;

  /// Whether there are any pinned columns.
  bool get hasPinnedColumns => leftCols.isNotEmpty || rightCols.isNotEmpty;

  /// Returns the range of center column indices that are visible within the
  /// current horizontal scroll viewport, plus a buffer on each side.
  ///
  /// [scrollOffset] is the current horizontal scroll position.
  /// [viewportWidth] is the width of the center (scrollable) viewport.
  /// [buffer] is the number of extra columns to include on each side to
  /// prevent flicker during fast scrolling (defaults to 2).
  ///
  /// Returns a record of (firstIndex, lastIndex) into [centerCols].
  /// Both indices are inclusive. Returns null if there are no center columns.
  ({int first, int last})? getVisibleColumnRange(
    double scrollOffset,
    double viewportWidth, {
    int buffer = 2,
  }) {
    if (centerCols.isEmpty) return null;

    final scrollRight = scrollOffset + viewportWidth;
    int firstVisible = -1;
    int lastVisible = -1;

    double x = 0;
    for (int i = 0; i < centerCols.length; i++) {
      final colRight = x + centerCols[i].width;
      if (colRight > scrollOffset && firstVisible == -1) {
        firstVisible = i;
      }
      if (x < scrollRight) {
        lastVisible = i;
      }
      if (x >= scrollRight) break;
      x = colRight;
    }

    if (firstVisible == -1) {
      // All columns are to the left of the viewport
      firstVisible = centerCols.length - 1;
      lastVisible = centerCols.length - 1;
    }
    if (lastVisible == -1) {
      lastVisible = centerCols.length - 1;
    }

    // Apply buffer
    firstVisible = (firstVisible - buffer).clamp(0, centerCols.length - 1);
    lastVisible = (lastVisible + buffer).clamp(0, centerCols.length - 1);

    return (first: firstVisible, last: lastVisible);
  }
}

/// A column with its resolved index and width.
class ColumnLayoutEntry {
  const ColumnLayoutEntry({
    required this.index,
    required this.column,
    required this.width,
  });

  /// Original index in the full columns list.
  final int index;

  /// The column definition.
  final OsColumnDef column;

  /// Resolved width for this column.
  final double width;
}
