import '../events/os_grid_event.dart';

/// Direction of vertical drag movement.
enum OsRowDragDirection {
  /// Dragging upward.
  up,

  /// Dragging downward.
  down,
}

/// Emitted when a row drag operation enters the grid area.
class OsRowDragEnterEvent<TData> extends OsGridEvent {
  const OsRowDragEnterEvent({
    required this.node,
    required this.overIndex,
    required this.y,
    this.vDirection,
  });

  /// The row data being dragged.
  final TData node;

  /// The row index the pointer is currently over, or -1 if past the last row.
  final int overIndex;

  /// The vertical pixel position of the pointer relative to the grid data area.
  final double y;

  /// The vertical direction of the drag movement.
  final OsRowDragDirection? vDirection;
}

/// Emitted while a row is being dragged over the grid.
class OsRowDragMoveEvent<TData> extends OsGridEvent {
  const OsRowDragMoveEvent({
    required this.node,
    required this.overIndex,
    required this.y,
    this.vDirection,
  });

  /// The row data being dragged.
  final TData node;

  /// The row index the pointer is currently over, or -1 if past the last row.
  final int overIndex;

  /// The vertical pixel position of the pointer relative to the grid data area.
  final double y;

  /// The vertical direction of the drag movement.
  final OsRowDragDirection? vDirection;
}

/// Emitted when a row drag operation ends (the row is dropped).
class OsRowDragEndEvent<TData> extends OsGridEvent {
  const OsRowDragEndEvent({
    required this.node,
    required this.overIndex,
    required this.fromIndex,
    required this.toIndex,
    required this.y,
    this.vDirection,
  });

  /// The row data that was dragged.
  final TData node;

  /// The row index the pointer was over when dropped, or -1 if past the last row.
  final int overIndex;

  /// The original index of the dragged row (before the drag).
  final int fromIndex;

  /// The target index where the row was dropped.
  ///
  /// When `rowDragManaged` is true, the grid has already moved the row to this
  /// index before firing this event.
  final int toIndex;

  /// The vertical pixel position of the pointer when dropped.
  final double y;

  /// The vertical direction of the drag movement at the time of drop.
  final OsRowDragDirection? vDirection;
}

/// Emitted when a row drag operation leaves the grid area.
class OsRowDragLeaveEvent<TData> extends OsGridEvent {
  const OsRowDragLeaveEvent({
    required this.node,
    required this.overIndex,
    required this.y,
    this.vDirection,
  });

  /// The row data being dragged.
  final TData node;

  /// The row index the pointer was over when leaving.
  final int overIndex;

  /// The vertical pixel position of the pointer when leaving.
  final double y;

  /// The vertical direction of the drag movement.
  final OsRowDragDirection? vDirection;
}
