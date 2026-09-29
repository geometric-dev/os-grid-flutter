import 'dart:async';

import '../columns/os_column_pin.dart';
import '../events/column_events.dart';
import '../events/grid_state_events.dart';
import '../os_grid_controller.dart';
import '../selection/cell_range.dart';
import 'grid_state.dart';

/// Service that manages grid state save/restore operations.
///
/// This service reads the current state from the controller and applies
/// saved state back. It also monitors state changes and emits debounced
/// [OsStateUpdatedEvent]s.
///
/// The service is created and managed by the grid widget state, not by
/// the controller directly.
class GridStateService<TData> {
  GridStateService({
    required OsGridController<TData> controller,
    required double Function() getScrollTop,
    required double Function() getScrollLeft,
    required void Function(double top, double left) setScrollPosition,
  }) : _controller = controller,
       _getScrollTop = getScrollTop,
       _getScrollLeft = getScrollLeft,
       _setScrollPosition = setScrollPosition;

  /// The live controller. Mutable only for runtime controller swaps —
  /// see [rebind].
  OsGridController<TData> _controller;

  /// Re-points the service at [controller] after a runtime controller swap.
  /// State capture/restore only queries the controller (its request hooks
  /// are wired by the owning state, which re-binds them itself), so
  /// reassigning the reference is sufficient.
  void rebind(OsGridController<TData> controller) {
    _controller = controller;
  }

  final double Function() _getScrollTop;
  final double Function() _getScrollLeft;
  final void Function(double top, double left) _setScrollPosition;

  final StreamController<OsStateUpdatedEvent> _onStateUpdated =
      StreamController<OsStateUpdatedEvent>.broadcast();

  /// Stream of state update events (debounced).
  Stream<OsStateUpdatedEvent> get onStateUpdated => _onStateUpdated.stream;

  Timer? _debounceTimer;
  final Set<String> _pendingSources = {};
  bool _suppressEvents = false;

  /// Get a snapshot of the current grid state.
  OsGridState getState() {
    return OsGridState(
      sort: _getSortState(),
      filter: _getFilterState(),
      columnPinning: _getColumnPinningState(),
      columnVisibility: _getColumnVisibilityState(),
      columnSizing: _getColumnSizingState(),
      columnOrder: _getColumnOrderState(),
      pagination: _getPaginationState(),
      rowSelection: _getRowSelectionState(),
      cellSelection: _getCellSelectionState(),
      scroll: _getScrollState(),
    );
  }

  /// Apply a saved state to the grid.
  ///
  /// Only the non-null properties in [state] are applied. Properties
  /// listed in [propertiesToIgnore] are skipped.
  ///
  /// Events are suppressed during restoration to avoid feedback loops.
  void setState(OsGridState state, {List<String>? propertiesToIgnore}) {
    final ignoreSet = propertiesToIgnore?.toSet() ?? <String>{};

    _suppressEvents = true;

    try {
      if (state.sort != null && !ignoreSet.contains('sort')) {
        _setSortState(state.sort!);
      }
      if (state.filter != null && !ignoreSet.contains('filter')) {
        _setFilterState(state.filter!);
      }
      if (state.columnPinning != null && !ignoreSet.contains('columnPinning')) {
        _setColumnPinningState(state.columnPinning!);
      }
      if (state.columnVisibility != null &&
          !ignoreSet.contains('columnVisibility')) {
        _setColumnVisibilityState(state.columnVisibility!);
      }
      if (state.columnSizing != null && !ignoreSet.contains('columnSizing')) {
        _setColumnSizingState(state.columnSizing!);
      }
      if (state.columnOrder != null && !ignoreSet.contains('columnOrder')) {
        _setColumnOrderState(state.columnOrder!);
      }
      if (state.pagination != null && !ignoreSet.contains('pagination')) {
        _setPaginationState(state.pagination!);
      }
      if (state.rowSelection != null && !ignoreSet.contains('rowSelection')) {
        _setRowSelectionState(state.rowSelection!);
      }
      if (state.cellSelection != null && !ignoreSet.contains('cellSelection')) {
        _setCellSelectionState(state.cellSelection!);
      }
      if (state.scroll != null && !ignoreSet.contains('scroll')) {
        _setScrollState(state.scroll!);
      }
    } finally {
      _suppressEvents = false;
    }
  }

  /// Notify the service that a state property has changed.
  ///
  /// Called by the grid widget when sort, filter, columns, pagination,
  /// selection, or scroll changes. The event is debounced — multiple
  /// rapid changes are batched into a single [OsStateUpdatedEvent].
  void notifyStateChanged(String source) {
    // Suppress during setState-restore; events fired after dispose (late
    // listener callbacks, post-frame work) must neither schedule a timer
    // nor touch the closed stream.
    if (_suppressEvents || _onStateUpdated.isClosed) return;

    _pendingSources.add(source);
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 50), () {
      _flushStateUpdate();
    });
  }

  void _flushStateUpdate() {
    if (_pendingSources.isEmpty || _onStateUpdated.isClosed) return;

    final sources = List<String>.from(_pendingSources);
    _pendingSources.clear();

    _onStateUpdated.add(
      OsStateUpdatedEvent(state: getState(), sources: sources),
    );
  }

  /// Clean up resources.
  void dispose() {
    _debounceTimer?.cancel();
    _onStateUpdated.close();
  }

  // --- Get sub-states ---

  SortState? _getSortState() {
    final sortModel = _controller.getSortModel();
    if (sortModel.isEmpty) return null;
    return SortState(sortModel: sortModel);
  }

  FilterState? _getFilterState() {
    final filterModel = _controller.getFilterModel();
    if (filterModel == null || filterModel.isEmpty) return null;
    return FilterState(filterModel: filterModel);
  }

  ColumnPinningState? _getColumnPinningState() {
    final leftCols = _controller.getDisplayedLeftColumns();
    final rightCols = _controller.getDisplayedRightColumns();
    if (leftCols.isEmpty && rightCols.isEmpty) return null;
    return ColumnPinningState(
      leftColIds: leftCols.map((c) => c.effectiveColId).toList(),
      rightColIds: rightCols.map((c) => c.effectiveColId).toList(),
    );
  }

  ColumnVisibilityState? _getColumnVisibilityState() {
    final allCols = _controller.getColumns();
    final displayedCols = _controller.getAllDisplayedColumns();
    final displayedIds = displayedCols.map((c) => c.effectiveColId).toSet();
    final hiddenIds = allCols
        .where((c) => !displayedIds.contains(c.effectiveColId))
        .map((c) => c.effectiveColId)
        .toList();
    if (hiddenIds.isEmpty) return null;
    return ColumnVisibilityState(hiddenColIds: hiddenIds);
  }

  ColumnSizingState? _getColumnSizingState() {
    final columnState = _controller.getColumnState();
    final entries = <ColumnSizeEntry>[];
    for (final cs in columnState) {
      if (cs.width != null || cs.flex != null) {
        entries.add(
          ColumnSizeEntry(
            colId: cs.colId,
            width: cs.width,
            flex: cs.flex?.toDouble(),
          ),
        );
      }
    }
    if (entries.isEmpty) return null;
    return ColumnSizingState(columnSizingModel: entries);
  }

  ColumnOrderState? _getColumnOrderState() {
    final displayedCols = _controller.getAllDisplayedColumns();
    final allCols = _controller.getColumns();
    // Include all columns (visible and hidden) in order
    final orderedIds = <String>[];
    // Start with displayed columns in order
    for (final col in displayedCols) {
      orderedIds.add(col.effectiveColId);
    }
    // Append hidden columns at the end
    for (final col in allCols) {
      if (!orderedIds.contains(col.effectiveColId)) {
        orderedIds.add(col.effectiveColId);
      }
    }
    if (orderedIds.isEmpty) return null;
    return ColumnOrderState(orderedColIds: orderedIds);
  }

  PaginationState? _getPaginationState() {
    final page = _controller.paginationGetCurrentPage();
    final pageSize = _controller.paginationGetPageSize();
    if (page == 0 && pageSize == 100) return null;
    return PaginationState(
      page: page > 0 ? page : null,
      pageSize: pageSize != 100 ? pageSize : null,
    );
  }

  RowSelectionState? _getRowSelectionState() {
    final selectedIds = _controller.getSelectedIds();
    if (selectedIds.isEmpty) return null;
    return RowSelectionState(selectedRowIds: selectedIds.toList());
  }

  CellSelectionState? _getCellSelectionState() {
    final ranges = _controller.getCellRanges();
    if (ranges.isEmpty) return null;
    return CellSelectionState(
      cellRanges: ranges
          .map(
            (r) => CellSelectionCellState(
              startRow: r.startRow,
              endRow: r.endRow,
              startColumn: r.startColumn,
              endColumn: r.endColumn,
            ),
          )
          .toList(),
    );
  }

  ScrollState? _getScrollState() {
    final top = _getScrollTop();
    final left = _getScrollLeft();
    if (top == 0 && left == 0) return null;
    return ScrollState(top: top, left: left);
  }

  // --- Set sub-states ---

  void _setSortState(SortState sortState) {
    _controller.setSortModel(sortState.sortModel);
  }

  void _setFilterState(FilterState filterState) {
    _controller.setFilterModel(filterState.filterModel);
  }

  void _setColumnPinningState(ColumnPinningState pinningState) {
    // Unpin all first, then apply new pins
    final allCols = _controller.getColumns();
    final allIds = allCols.map((c) => c.effectiveColId).toList();
    _controller.setColumnsPinned(allIds, null);

    if (pinningState.leftColIds.isNotEmpty) {
      _controller.setColumnsPinned(pinningState.leftColIds, OsColumnPin.left);
    }
    if (pinningState.rightColIds.isNotEmpty) {
      _controller.setColumnsPinned(pinningState.rightColIds, OsColumnPin.right);
    }
  }

  void _setColumnVisibilityState(ColumnVisibilityState visibilityState) {
    // Show all columns first, then hide the specified ones
    final allCols = _controller.getColumns();
    final allIds = allCols.map((c) => c.effectiveColId).toList();
    _controller.setColumnsVisible(allIds, true);

    if (visibilityState.hiddenColIds.isNotEmpty) {
      _controller.setColumnsVisible(visibilityState.hiddenColIds, false);
    }
  }

  void _setColumnSizingState(ColumnSizingState sizingState) {
    final widths = sizingState.columnSizingModel
        .where((e) => e.width != null)
        .map((e) => ColumnWidthEntry(colId: e.colId, newWidth: e.width!))
        .toList();
    if (widths.isNotEmpty) {
      _controller.setColumnWidths(widths);
    }
  }

  void _setColumnOrderState(ColumnOrderState orderState) {
    if (orderState.orderedColIds.isEmpty) return;
    // Apply column order by moving each column to its target position
    for (int i = 0; i < orderState.orderedColIds.length; i++) {
      _controller.moveColumns([orderState.orderedColIds[i]], i);
    }
  }

  void _setPaginationState(PaginationState paginationState) {
    if (paginationState.pageSize != null) {
      _controller.paginationSetPageSize(paginationState.pageSize!);
    }
    if (paginationState.page != null) {
      _controller.paginationGoToPage(paginationState.page!);
    }
  }

  void _setRowSelectionState(RowSelectionState selectionState) {
    _controller.deselectAll();
    if (selectionState.selectedRowIds.isNotEmpty) {
      _controller.selectRowsById(selectionState.selectedRowIds);
    }
  }

  void _setCellSelectionState(CellSelectionState cellSelectionState) {
    _controller.clearRangeSelection();
    for (final range in cellSelectionState.cellRanges) {
      _controller.addCellRange(
        CellRangeParams(
          rowStartIndex: range.startRow,
          rowEndIndex: range.endRow,
          columnStartIndex: range.startColumn,
          columnEndIndex: range.endColumn,
        ),
      );
    }
  }

  void _setScrollState(ScrollState scrollState) {
    _setScrollPosition(scrollState.top, scrollState.left);
  }
}
