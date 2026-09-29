import 'package:os_grid_flutter/os_grid_flutter.dart' show OsGridController;
import 'package:os_grid_flutter/src/os_grid_controller.dart'
    show OsGridController;

/// Position options for horizontal scrolling (ensureColumnVisible).
enum ColumnScrollPosition {
  /// Only scroll if the column is outside the viewport. If already visible,
  /// no scroll occurs.
  auto,

  /// Align the column's left edge with the viewport's left edge.
  start,

  /// Centre the column horizontally within the viewport.
  middle,

  /// Align the column's right edge with the viewport's right edge.
  end,
}

/// Position options for vertical scrolling (ensureIndexVisible).
enum RowScrollPosition {
  /// Align the row with the top of the data area.
  top,

  /// Centre the row vertically within the data area.
  middle,

  /// Align the row with the bottom of the data area.
  bottom,
}

/// A command to scroll the grid to make a specific column or row visible.
///
/// Emitted by [OsGridController] and consumed by the virtualised grid widget.
sealed class ScrollCommand {
  const ScrollCommand();
}

/// Command to scroll horizontally to make a column visible.
class EnsureColumnVisibleCommand extends ScrollCommand {
  const EnsureColumnVisibleCommand({
    required this.columnIndex,
    this.position = ColumnScrollPosition.auto,
  });

  /// The index of the column in the flat columns list.
  final int columnIndex;

  /// Where to position the column within the viewport.
  final ColumnScrollPosition position;
}

/// Command to set the horizontal scroll offset to an absolute value.
///
/// Used by the aligned grids service to synchronise horizontal scroll
/// between grids sharing the same group ID.
class SetHorizontalScrollCommand extends ScrollCommand {
  const SetHorizontalScrollCommand({required this.offset});

  /// The absolute horizontal scroll offset in logical pixels.
  final double offset;
}

/// Command to scroll vertically to make a row visible.
class EnsureIndexVisibleCommand extends ScrollCommand {
  const EnsureIndexVisibleCommand({required this.rowIndex, this.position});

  /// The display index of the row to scroll to.
  final int rowIndex;

  /// Where to position the row within the viewport.
  /// When null, behaves like 'auto' — only scrolls if the row is not visible.
  final RowScrollPosition? position;
}
