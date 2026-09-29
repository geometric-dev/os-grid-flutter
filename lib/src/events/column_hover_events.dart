import 'package:os_grid_flutter/os_grid_flutter.dart' show OsGrid;

import 'package:os_grid_flutter/src/os_grid.dart' show OsGrid;

import 'os_grid_event.dart';

/// Emitted when the hovered column changes.
///
/// Fired when the pointer moves to a different column or leaves the grid
/// entirely (in which case [column] is `null`).
///
/// Only emitted when [OsGrid.columnHoverHighlight] is `true`.
///
/// ```dart
/// controller.onColumnHoverChanged.listen((event) {
///   print(event.column ?? 'left the grid');
/// });
/// ```
class OsColumnHoverChangedEvent extends OsGridEvent {
  const OsColumnHoverChangedEvent({this.column});

  /// The column ID currently being hovered, or `null` if no column is hovered.
  final String? column;
}
