import 'package:flutter/material.dart';

import 'drag_and_drop_config.dart';
import 'drag_and_drop_events.dart';

/// Manages external drag and drop interactions for the grid.
///
/// This service handles two distinct capabilities:
/// - **Drag-out**: Detecting when a row drag exits the grid bounds and
///   providing the row data to external [DragTarget] widgets.
/// - **Drop-in**: Accepting external [Draggable] items dropped onto the
///   grid and computing the target row index from the drop position.
///
/// This is separate from the internal row drag reordering which is handled
/// by the grid's own gesture system.
class DragAndDropService {
  DragAndDropService({
    required this.config,
    required this.rowHeight,
    required this.headerHeight,
    required this.floatingFilterHeight,
    required this.hasGroupHeaders,
  });

  /// The drag and drop configuration.
  final OsDragAndDrop config;

  /// Row height in logical pixels.
  final double rowHeight;

  /// Header height in logical pixels.
  final double headerHeight;

  /// Floating filter height (0 if disabled).
  final double floatingFilterHeight;

  /// Whether group headers are present.
  final bool hasGroupHeaders;

  /// Whether an external drag is currently hovering over the grid.
  bool _isExternalDragOver = false;

  /// The current target row index during an external drag hover.
  int? _dropTargetIndex;

  /// Whether an external drag is currently hovering over the grid.
  bool get isExternalDragOver => _isExternalDragOver;

  /// The current target row index during an external drag hover.
  ///
  /// Returns `null` when no external drag is hovering.
  int? get dropTargetIndex => _dropTargetIndex;

  /// Computes the top of the data area (below headers and floating filter).
  double get _dataAreaTop {
    final groupHeaderOffset = hasGroupHeaders ? 36.0 : 0.0;
    return headerHeight + groupHeaderOffset + floatingFilterHeight;
  }

  /// Computes the target row index from a local Y position within the grid.
  ///
  /// [localY] is the Y coordinate relative to the grid's top-left corner.
  /// [rowCount] is the total number of visible rows.
  /// [scrollOffsetY] is the current vertical scroll offset.
  int computeTargetRowIndex(
    double localY,
    int rowCount, {
    double scrollOffsetY = 0.0,
  }) {
    final dataTop = _dataAreaTop;
    if (localY < dataTop) return 0;

    final relativeY = localY - dataTop + scrollOffsetY;
    final targetIndex = (relativeY / rowHeight).floor();
    return targetIndex.clamp(0, rowCount);
  }

  /// Called when an external drag enters the grid area.
  ///
  /// Returns `true` if the grid accepts this drag (i.e. drop-in is enabled).
  bool onExternalDragEnter() {
    if (!config.enableDropIn) return false;
    _isExternalDragOver = true;
    return true;
  }

  /// Called when an external drag moves over the grid.
  ///
  /// Updates the [dropTargetIndex] based on the pointer position.
  void onExternalDragUpdate(
    Offset localPosition,
    int rowCount, {
    double scrollOffsetY = 0.0,
  }) {
    if (!config.enableDropIn || !_isExternalDragOver) return;
    _dropTargetIndex = computeTargetRowIndex(
      localPosition.dy,
      rowCount,
      scrollOffsetY: scrollOffsetY,
    );
  }

  /// Called when an external drag leaves the grid area.
  void onExternalDragLeave() {
    _isExternalDragOver = false;
    _dropTargetIndex = null;
  }

  /// Called when an external item is dropped onto the grid.
  ///
  /// Returns an [OsExternalDropEvent] with the computed target row index
  /// and the drag data, or `null` if drop-in is not enabled.
  OsExternalDropEvent? onExternalDrop(
    dynamic dragData,
    Offset localPosition,
    int rowCount, {
    double scrollOffsetY = 0.0,
  }) {
    if (!config.enableDropIn) return null;

    final targetIndex = computeTargetRowIndex(
      localPosition.dy,
      rowCount,
      scrollOffsetY: scrollOffsetY,
    );

    _isExternalDragOver = false;
    _dropTargetIndex = null;

    return OsExternalDropEvent(targetRowIndex: targetIndex, dragData: dragData);
  }

  /// Determines whether a row drag has exited the grid bounds.
  ///
  /// [pointerGlobalPosition] is the pointer's global position.
  /// [gridRect] is the grid's bounding rectangle in global coordinates.
  ///
  /// Returns `true` if the pointer is outside the grid bounds.
  bool isPointerOutsideGrid(Offset pointerGlobalPosition, Rect gridRect) {
    return !gridRect.contains(pointerGlobalPosition);
  }

  /// Creates an [OsRowDragOutEvent] for a row being dragged outside the grid.
  OsRowDragOutEvent<TData> createDragOutEvent<TData>({
    required TData data,
    required int rowIndex,
    required Offset globalPosition,
  }) {
    return OsRowDragOutEvent<TData>(
      data: data,
      rowIndex: rowIndex,
      globalPosition: globalPosition,
    );
  }

  /// Resets the service state (e.g. when the grid is disposed or rebuilt).
  void reset() {
    _isExternalDragOver = false;
    _dropTargetIndex = null;
  }
}
