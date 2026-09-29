import 'dart:ui';

import 'package:flutter/cupertino.dart' show Draggable;

import 'package:flutter/material.dart' show Draggable;

import 'package:flutter/widgets.dart' show Draggable;

import 'package:os_grid_flutter/os_grid_flutter.dart'
    show OsDragAndDrop, OsGridController;

import '../events/os_grid_event.dart';

/// Emitted when a row is dragged outside the grid bounds.
///
/// This event fires when [OsDragAndDrop.enableDragOut] is `true` and the
/// user drags a row beyond the grid's render area. The event provides the
/// row data, its original index, and the global position where the drag
/// exited the grid.
///
/// ```dart
/// OsGrid(
///   onRowDragOut: (event) {
///     print('Dragged row ${event.rowIndex}: ${event.data}');
///     print('Exited at: ${event.globalPosition}');
///   },
/// )
/// ```
class OsRowDragOutEvent<TData> extends OsGridEvent {
  const OsRowDragOutEvent({
    required this.data,
    required this.rowIndex,
    required this.globalPosition,
  });

  /// The row data being dragged out of the grid.
  final TData data;

  /// The display index of the row being dragged (in the current
  /// filtered/sorted/paginated view).
  final int rowIndex;

  /// The global position (in logical pixels) where the drag exited
  /// the grid bounds.
  ///
  /// This can be used to position a drag feedback widget or to determine
  /// which external drop target the pointer is over.
  final Offset globalPosition;
}

/// Emitted when an external item is dropped onto the grid.
///
/// This event fires when [OsDragAndDrop.enableDropIn] is `true` and the
/// user drops a [Draggable] item onto the grid. The event provides the
/// target row index (determined by the vertical drop position) and the
/// data from the draggable.
///
/// The grid does NOT automatically insert the dropped data — the caller
/// is responsible for updating the row data (e.g. via
/// [OsGridController.applyTransaction] or [OsGridController.setRowData]).
///
/// ```dart
/// OsGrid(
///   onExternalDrop: (event) {
///     final newRow = {'name': event.dragData, 'age': 0};
///     controller.applyTransaction(OsRowTransaction(add: [newRow]));
///   },
/// )
/// ```
class OsExternalDropEvent extends OsGridEvent {
  const OsExternalDropEvent({
    required this.targetRowIndex,
    required this.dragData,
  });

  /// The row index where the item was dropped.
  ///
  /// Determined by the vertical position of the drop relative to the
  /// grid's data area. If dropped below all rows, this equals the
  /// current row count (i.e. "append" position).
  final int targetRowIndex;

  /// The data from the external [Draggable] widget.
  ///
  /// This is whatever value was passed to the [Draggable.data] property
  /// of the widget being dragged into the grid.
  final dynamic dragData;
}
