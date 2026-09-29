import 'package:flutter/material.dart';

import 'os_grid_event.dart';

/// Emitted when a right-click (context menu) occurs on a data cell.
///
/// This event fires before the context menu is shown. If [preventDefault]
/// is called, the default context menu is suppressed.
///
/// ```dart
/// controller.onCellContextMenu.listen((event) {
///   print('context menu at row ${event.rowIndex}');
/// });
/// ```
class OsCellContextMenuEvent<TData> extends OsGridEvent {
  OsCellContextMenuEvent({
    required this.rowIndex,
    required this.colId,
    required this.value,
    required this.data,
    required this.globalPosition,
  });

  /// The row index of the right-clicked cell.
  final int rowIndex;

  /// The column ID of the right-clicked cell.
  final String colId;

  /// The value of the right-clicked cell.
  final dynamic value;

  /// The row data for the right-clicked cell.
  final TData data;

  /// The global position of the right-click (screen coordinates).
  final Offset globalPosition;

  /// Whether the default context menu has been suppressed.
  bool get isDefaultPrevented => _defaultPrevented;
  bool _defaultPrevented = false;

  /// Call this to suppress the default context menu from showing.
  void preventDefault() {
    _defaultPrevented = true;
  }
}
