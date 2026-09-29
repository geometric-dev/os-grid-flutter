import 'package:os_grid_flutter/os_grid_flutter.dart' show OsGridController;
import 'package:os_grid_flutter/src/os_grid_controller.dart'
    show OsGridController;

/// A command to change the focused cell in the virtualised grid.
///
/// Emitted by [OsGridController] (via `setFocusedCell` / `clearFocusedCell`)
/// and consumed by the virtualised grid widget, which resets the notifier
/// to null after executing.
sealed class FocusCommand {
  const FocusCommand();
}

/// Command to move the cell focus ring to a specific cell.
class SetFocusedCellCommand extends FocusCommand {
  const SetFocusedCellCommand({
    required this.rowIndex,
    required this.columnIndex,
  });

  /// Display index of the row to focus. Clamped to grid bounds by the grid.
  final int rowIndex;

  /// Index of the column to focus in the flat columns list. Clamped to
  /// grid bounds by the grid.
  final int columnIndex;
}

/// Command to park the visual cell focus ring.
///
/// The focused-cell API value is cleared by the controller; the grid only
/// stops highlighting a cell.
class ClearFocusedCellCommand extends FocusCommand {
  const ClearFocusedCellCommand();
}
