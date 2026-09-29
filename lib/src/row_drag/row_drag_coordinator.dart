import 'package:flutter/material.dart';

import '../columns/os_column_def.dart';
import '../columns/os_column_group.dart';
import '../drag_and_drop/drag_and_drop_config.dart';
import '../drag_and_drop/drag_and_drop_events.dart';
import '../os_grid_controller.dart';
import '../theming/os_grid_theme.dart';
import 'row_drag_event.dart';

/// Owns the row drag-to-reorder interaction for the grid.
///
/// Extracted from `_OsGridState`. The coordinator owns the active drag state
/// (source row index, pointer Y, direction, drop target) plus the overlay
/// showing the drop indicator line, and fires the row-drag event stream
/// (enter/move/out/end) through both widget callbacks and the controller.
///
/// All grid-owned collaborators are supplied as closures/getters so they
/// always read live state from the owning `State`.
class RowDragCoordinator<TData> {
  /// Creates a coordinator.
  ///
  /// The `onRowDragXxx` getters supply the current widget callbacks so
  /// `didUpdateWidget` replacements are honoured. [mutate] wraps the owning
  /// State's `setState`; [reprocessData] re-runs the data pipeline after a
  /// managed reorder; [managedRowData] supplies the mutable row list used by
  /// managed reorder.
  RowDragCoordinator({
    required OsGridController<TData> controller,
    required List<TData>? Function() resolveRows,
    required List<TData>? Function() managedRowData,
    required void Function(VoidCallback) mutate,
    required void Function() reprocessData,
    required bool Function() rowDragManaged,
    required bool Function() floatingFilter,
    required double Function() floatingFilterHeight,
    required List<OsColumnDefBase> Function() columnDefs,
    required double Function() effectiveHeaderHeight,
    required double Function() effectiveRowHeight,
    required OsGridTheme? Function() theme,
    required OsDragAndDrop? Function() dragAndDrop,
    required double Function()? scrollY,
    required void Function(OsRowDragEnterEvent<TData>)? onRowDragEnter,
    required void Function(OsRowDragMoveEvent<TData>)? onRowDragMove,
    required void Function(OsRowDragOutEvent<TData>)? onRowDragOut,
    required void Function(OsRowDragEndEvent<TData>)? onRowDragEnd,
    required BuildContext Function() context,
  }) : _controller = controller,
       _resolveRows = resolveRows,
       _managedRowData = managedRowData,
       _mutate = mutate,
       _reprocessData = reprocessData,
       _rowDragManaged = rowDragManaged,
       _floatingFilter = floatingFilter,
       _floatingFilterHeight = floatingFilterHeight,
       _columnDefs = columnDefs,
       _effectiveHeaderHeight = effectiveHeaderHeight,
       _effectiveRowHeight = effectiveRowHeight,
       _theme = theme,
       _dragAndDrop = dragAndDrop,
       _scrollY = scrollY,
       _onRowDragEnter = onRowDragEnter,
       _onRowDragMove = onRowDragMove,
       _onRowDragOut = onRowDragOut,
       _onRowDragEnd = onRowDragEnd,
       _context = context;

  /// The live controller. Mutable only for runtime controller swaps —
  /// see [rebind].
  OsGridController<TData> _controller;

  /// Re-points the coordinator at [controller] after a runtime controller
  /// swap. Row-drag flow only emits events on the controller (its request
  /// hooks, if any, are wired by the owning state), so reassigning the
  /// reference is sufficient.
  void rebind(OsGridController<TData> controller) {
    _controller = controller;
  }

  final List<TData>? Function() _resolveRows;
  final List<TData>? Function() _managedRowData;
  final void Function(VoidCallback) _mutate;
  final void Function() _reprocessData;
  final bool Function() _rowDragManaged;
  final bool Function() _floatingFilter;
  final double Function() _floatingFilterHeight;
  final List<OsColumnDefBase> Function() _columnDefs;
  final double Function() _effectiveHeaderHeight;
  final double Function() _effectiveRowHeight;
  final OsGridTheme? Function() _theme;
  final OsDragAndDrop? Function() _dragAndDrop;

  /// Live vertical scroll offset of the grid, so the drop target and the
  /// indicator line stay correct while the grid is scrolled (and while the
  /// row-drag edge auto-scroll moves content under a stationary pointer).
  final double Function()? _scrollY;
  final void Function(OsRowDragEnterEvent<TData>)? _onRowDragEnter;
  final void Function(OsRowDragMoveEvent<TData>)? _onRowDragMove;
  final void Function(OsRowDragOutEvent<TData>)? _onRowDragOut;
  final void Function(OsRowDragEndEvent<TData>)? _onRowDragEnd;
  final BuildContext Function() _context;

  /// The row index being dragged.
  int? _rowDragFromIndex;

  /// The current position of the drag pointer (local to grid).
  Offset _rowDragCurrentPosition = Offset.zero;

  /// The target row index where the drop indicator is shown.
  int? _rowDragDropTargetIndex;

  /// Overlay entry for the row drag visual feedback.
  OverlayEntry? _rowDragOverlayEntry;

  /// The last vertical direction of the drag.
  OsRowDragDirection? _rowDragDirection;

  /// The previous Y position for computing direction.
  double _rowDragPreviousY = 0.0;

  /// Whether the row being dragged has already exited the grid bounds.
  /// Used to fire onRowDragOut only once per exit.
  bool _rowDragHasExitedGrid = false;

  void handleRowDragStart(int rowIndex, Offset startPosition) {
    _rowDragFromIndex = rowIndex;
    _rowDragCurrentPosition = startPosition;
    _rowDragPreviousY = startPosition.dy;
    _rowDragDropTargetIndex = null;
    _rowDragDirection = null;
    _rowDragHasExitedGrid = false;
    _showRowDragOverlay();

    // Fire enter event
    final effectiveData = _resolveRows();
    if (effectiveData != null && rowIndex < effectiveData.length) {
      final event = OsRowDragEnterEvent<TData>(
        node: effectiveData[rowIndex],
        overIndex: rowIndex,
        y: startPosition.dy,
      );
      _onRowDragEnter?.call(event);
      _controller.emitRowDragEnter(event);
    }
  }

  void handleRowDragUpdate(Offset position) {
    // Compute direction
    if (position.dy > _rowDragPreviousY) {
      _rowDragDirection = OsRowDragDirection.down;
    } else if (position.dy < _rowDragPreviousY) {
      _rowDragDirection = OsRowDragDirection.up;
    }
    _rowDragPreviousY = position.dy;
    _rowDragCurrentPosition = position;

    // Detect drag-out: if enableDragOut is true and the pointer has exited
    // the grid bounds on ANY edge, fire the onRowDragOut event. Dragging a
    // row onto an external side panel exits horizontally — checking only
    // the vertical edges (the old behaviour) missed the primary use case.
    if (_dragAndDrop()?.enableDragOut == true && !_rowDragHasExitedGrid) {
      final renderBox = _context().findRenderObject() as RenderBox?;
      if (renderBox != null) {
        final gridRect = Offset.zero & renderBox.size;
        if (!gridRect.contains(position)) {
          _rowDragHasExitedGrid = true;
          final effectiveData = _resolveRows();
          if (effectiveData != null &&
              _rowDragFromIndex != null &&
              _rowDragFromIndex! < effectiveData.length) {
            final event = OsRowDragOutEvent<TData>(
              data: effectiveData[_rowDragFromIndex!],
              rowIndex: _rowDragFromIndex!,
              globalPosition: renderBox.localToGlobal(position),
            );
            _onRowDragOut?.call(event);
            _controller.emitRowDragOut(event);
          }
        }
      }
    }

    // Calculate the target row index based on cursor Y position
    final headerHeight = _effectiveHeaderHeight();
    final hasGroupHeaders = _columnDefs().any((d) => d is OsColumnGroup);
    final groupHeaderOffset = hasGroupHeaders ? 36.0 : 0.0;
    final floatingFilterOffset = _floatingFilter()
        ? _floatingFilterHeight()
        : 0.0;
    final dataAreaTop = headerHeight + groupHeaderOffset + floatingFilterOffset;

    // The VirtualisedGrid passes local Y coordinates, so we need to account
    // for the header area and scroll offset. The currentY is in local coords.
    final effectiveData = _resolveRows();
    final rowCount = effectiveData?.length ?? 0;

    final currentY = position.dy;
    if (currentY < dataAreaTop) {
      _rowDragDropTargetIndex = 0;
    } else {
      // Estimate which content row the cursor is over: convert the
      // viewport-local Y to content space by adding the scroll offset.
      final relativeY = currentY - dataAreaTop + (_scrollY?.call() ?? 0.0);
      final targetIndex = (relativeY / _effectiveRowHeight()).floor();
      _rowDragDropTargetIndex = targetIndex.clamp(0, rowCount);
    }

    _rowDragOverlayEntry?.markNeedsBuild();

    // Fire move event
    if (effectiveData != null &&
        _rowDragFromIndex != null &&
        _rowDragFromIndex! < effectiveData.length) {
      final overIndex = (_rowDragDropTargetIndex ?? -1).clamp(0, rowCount - 1);
      final event = OsRowDragMoveEvent<TData>(
        node: effectiveData[_rowDragFromIndex!],
        overIndex: overIndex,
        y: currentY,
        vDirection: _rowDragDirection,
      );
      _onRowDragMove?.call(event);
      _controller.emitRowDragMove(event);
    }
  }

  void handleRowDragEnd() {
    final fromIndex = _rowDragFromIndex;
    var toIndex = _rowDragDropTargetIndex;

    removeRowDragOverlay();

    if (fromIndex == null || toIndex == null) {
      _rowDragFromIndex = null;
      _rowDragDropTargetIndex = null;
      return;
    }

    final effectiveData = _resolveRows();
    if (effectiveData == null || fromIndex >= effectiveData.length) {
      _rowDragFromIndex = null;
      _rowDragDropTargetIndex = null;
      return;
    }

    // Clamp toIndex to valid range
    toIndex = toIndex.clamp(0, effectiveData.length);

    // Adjust toIndex: if dragging down, the target shifts after removal
    final adjustedToIndex = toIndex > fromIndex ? toIndex - 1 : toIndex;

    // Perform the reorder if managed and indices differ
    if (_rowDragManaged() && adjustedToIndex != fromIndex) {
      _mutate(() {
        final data = _managedRowData();
        if (data != null) {
          final item = data.removeAt(fromIndex);
          data.insert(adjustedToIndex, item);
        }
        _reprocessData();
      });
    }

    // Fire end event
    final event = OsRowDragEndEvent<TData>(
      node: effectiveData[fromIndex],
      overIndex: toIndex.clamp(0, effectiveData.length - 1),
      fromIndex: fromIndex,
      toIndex: adjustedToIndex,
      y: _rowDragCurrentPosition.dy,
      vDirection: _rowDragDirection,
    );
    _onRowDragEnd?.call(event);
    _controller.emitRowDragEnd(event);

    _rowDragFromIndex = null;
    _rowDragDropTargetIndex = null;
    _rowDragDirection = null;
  }

  void _showRowDragOverlay() {
    removeRowDragOverlay();
    _rowDragOverlayEntry = OverlayEntry(
      builder: (context) => _buildRowDragOverlayContent(),
    );
    Overlay.of(_context()).insert(_rowDragOverlayEntry!);
  }

  /// Removes the row drag overlay if shown. Call from the owning State's dispose.
  void removeRowDragOverlay() {
    _rowDragOverlayEntry?.remove();
    _rowDragOverlayEntry = null;
  }

  /// Releases overlay resources owned by this coordinator.
  void dispose() {
    removeRowDragOverlay();
  }

  Widget _buildRowDragOverlayContent() {
    if (_rowDragFromIndex == null || _rowDragDropTargetIndex == null) {
      return const SizedBox.shrink();
    }

    final renderBox = _context().findRenderObject() as RenderBox?;
    if (renderBox == null) return const SizedBox.shrink();
    final gridTopLeft = renderBox.localToGlobal(Offset.zero);
    final gridSize = renderBox.size;

    final accentColor = _theme()?.accentColor ?? Colors.blue;
    final headerHeight = _effectiveHeaderHeight();
    final hasGroupHeaders = _columnDefs().any((d) => d is OsColumnGroup);
    final groupHeaderOffset = hasGroupHeaders ? 36.0 : 0.0;
    final floatingFilterOffset = _floatingFilter()
        ? _floatingFilterHeight()
        : 0.0;
    final dataAreaTop =
        gridTopLeft.dy +
        headerHeight +
        groupHeaderOffset +
        floatingFilterOffset;

    // Calculate the Y position of the drop indicator line (viewport space:
    // content-space row position minus the current scroll offset).
    final dropIndex = _rowDragDropTargetIndex!;
    final indicatorY =
        dataAreaTop +
        dropIndex * _effectiveRowHeight() -
        (_scrollY?.call() ?? 0.0);

    return Stack(
      children: [
        // Drop indicator line (2px accent-coloured horizontal line)
        Positioned(
          left: gridTopLeft.dx,
          top: indicatorY - 1,
          width: gridSize.width,
          height: 2,
          child: IgnorePointer(child: ColoredBox(color: accentColor)),
        ),
      ],
    );
  }
}
