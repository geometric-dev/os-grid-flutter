import 'package:os_grid_flutter/os_grid_flutter.dart' show OsGridController;
import 'package:os_grid_flutter/src/os_grid_controller.dart'
    show OsGridController;

/// A transaction to apply to the grid's row data.
///
/// Allows adding, removing, and updating rows without replacing the entire
/// dataset. More efficient than [OsGridController.setRowData] for incremental
/// changes.
///
/// ```dart
/// controller.applyTransaction(OsRowTransaction(
///   add: [newAthlete],
///   remove: [deletedAthlete],
/// ));
/// ```
class OsRowTransaction<TData> {
  const OsRowTransaction({this.add, this.remove, this.update, this.addIndex});

  /// Rows to add to the grid.
  final List<TData>? add;

  /// Rows to remove from the grid (matched by identity or row ID).
  final List<TData>? remove;

  /// Rows to update in place (matched by row ID).
  final List<TData>? update;

  /// Index at which to insert added rows. If null, adds to the end.
  final int? addIndex;
}
