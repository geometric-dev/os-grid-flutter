import 'package:flutter/cupertino.dart' show DragTarget, Draggable;
import 'package:flutter/material.dart' show DragTarget, Draggable;
import 'package:flutter/widgets.dart' show DragTarget, Draggable;
import '../os_grid.dart' show OsGrid;

/// Configuration for external drag and drop on the grid.
///
/// This enables dragging rows OUT of the grid to external drop targets,
/// and/or dropping external items INTO the grid.
///
/// This is separate from `rowDrag` which handles reordering rows within
/// the grid itself.
///
/// ```dart
/// OsGrid(
///   dragAndDrop: const OsDragAndDrop(
///     enableDragOut: true,
///     enableDropIn: true,
///   ),
///   onRowDragOut: (event) {
///     print('Row ${event.rowIndex} dragged out');
///   },
///   onExternalDrop: (event) {
///     print('Item dropped at row ${event.targetRowIndex}');
///   },
/// )
/// ```
class OsDragAndDrop {
  /// Creates a drag and drop configuration.
  const OsDragAndDrop({this.enableDragOut = false, this.enableDropIn = false});

  /// Whether rows can be dragged out of the grid to external targets.
  ///
  /// When `true`, the grid detects when a drag gesture exits the grid
  /// bounds and fires [OsGrid.onRowDragOut] with the row data and position.
  ///
  /// The external drop target should use Flutter's [DragTarget] widget
  /// to receive the dragged data.
  final bool enableDragOut;

  /// Whether external items can be dropped into the grid.
  ///
  /// When `true`, the grid wraps itself with a [DragTarget] that accepts
  /// external [Draggable] items. On drop, [OsGrid.onExternalDrop] fires
  /// with the target row index (determined by drop position) and the
  /// drag data from the draggable.
  final bool enableDropIn;

  /// Whether any drag and drop feature is enabled.
  bool get isEnabled => enableDragOut || enableDropIn;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OsDragAndDrop &&
          runtimeType == other.runtimeType &&
          enableDragOut == other.enableDragOut &&
          enableDropIn == other.enableDropIn;

  @override
  int get hashCode => Object.hash(enableDragOut, enableDropIn);
}
