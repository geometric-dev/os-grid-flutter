import 'dart:async';

import 'package:flutter/cupertino.dart' show ScrollController;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ScrollController;
import 'package:flutter/widgets.dart' show ScrollController;

import 'charts/chart_definition.dart';
import 'columns/column_state.dart';
import 'columns/os_column_def.dart';
import 'columns/os_column_pin.dart';
import 'controller/pagination_coordinator.dart';
import 'controller/quick_filter_coordinator.dart';
import 'controller/state_persistence_coordinator.dart';
import 'drag_and_drop/drag_and_drop_config.dart' show OsDragAndDrop;
import 'drag_and_drop/drag_and_drop_events.dart';
import 'events/cell_events.dart';
import 'events/cell_focus_events.dart';
import 'events/chart_events.dart';
import 'events/clipboard_events.dart';
import 'events/column_events.dart';
import 'events/column_hover_events.dart';
import 'events/context_menu_events.dart';
import 'events/editing_events.dart';
import 'events/expand_collapse_events.dart';
import 'events/filter_events.dart';
import 'events/grid_event_bus.dart';
import 'events/grid_state_events.dart';
import 'events/infinite_row_model_events.dart';
import 'events/lifecycle_events.dart';
import 'events/os_grid_event.dart';
import 'events/pagination_events.dart';
import 'events/pinned_row_events.dart';
import 'events/pivot_events.dart';
import 'events/row_data_events.dart';
import 'events/row_events.dart';
import 'events/row_group_events.dart';
import 'events/selection_events.dart';
import 'events/side_bar_events.dart';
import 'events/sort_events.dart';
import 'events/tooltip_events.dart';
import 'events/undo_redo_events.dart';
import 'export/csv_export.dart';
import 'export/xlsx_export.dart';
import 'grid_state/grid_state.dart';
import 'infinite_row_model/infinite_row_model.dart' show OsInfiniteRowModel;
import 'locale/os_locale_text.dart';
import 'os_grid.dart' show OsGrid;
import 'params/value_getter_params.dart';
import 'render_api/cell_flash.dart';
import 'rendering/focus_command.dart';
import 'row_drag/row_drag_event.dart';
import 'row_model/row_node.dart';
import 'row_model/row_transaction.dart';
import 'scrolling/scroll_command.dart';
import 'selection/cell_range.dart';
import 'selection/os_row_selection.dart';
import 'side_bar/os_side_bar_def.dart';
import 'sorting/sort_direction.dart';
import 'sorting/sort_model.dart';
import 'utils/grid_diagnostics.dart';
import 'utils/grid_error.dart';

/// Which full-body overlay an [OsGrid] should currently display.
///
/// Resolved by the grid in priority order: an explicit override set via
/// [OsGridController.showLoadingOverlay] / [OsGridController.showNoRowsOverlay]
/// wins over everything; otherwise the [OsGrid.loading] parameter applies;
/// otherwise automatic heuristics (infinite-cache loading, empty row set).
enum OsGridOverlay {
  /// No overlay — grid content is fully interactive.
  none,

  /// The loading overlay ([OsGrid.loadingOverlay] or a localised default).
  loading,

  /// The no-rows overlay ([OsGrid.noRowsOverlay] or a localised default).
  noRows,
}

/// Controller for imperative interaction with an [OsGrid] instance.
///
/// Follows Flutter's controller pattern (like [ScrollController]).
/// Provides methods for data manipulation, selection, scrolling,
/// and exposes event streams.
///
/// ```dart
/// final controller = OsGridController<MyData>();
///
/// // Later...
/// controller.selectAll();
/// controller.exportCsv();
/// controller.dispose();
/// ```
class OsGridController<TData> extends ChangeNotifier {
  /// Creates a controller.
  ///
  /// The controller registers itself as a structured-diagnostic sink:
  /// while it is alive (until [dispose]) every [GridDiagnostic] raised
  /// through the central diagnostics helper is re-emitted on
  /// [onDiagnostic].
  OsGridController() {
    GridDiagnostics.addListener(_emitDiagnostic);
  }

  // --- Internal state (populated by _OsGridState) ---

  List<TData> _rowData = [];

  /// @internal — Provides read access to the raw row data for the widget.
  /// Used by _OsGridState when reprocessing after a transaction.
  List<TData> get rawRowData => _rowData;

  /// Selected row IDs. Selection is tracked by stable row identity,
  /// not by display index, so it survives sort/filter operations.
  final Set<String> _selectedIds = {};

  /// Row nodes keyed by stable row ID. Rebuilt whenever the raw row data
  /// changes; surviving IDs reuse their existing [OsRowNode] instance.
  final Map<String, OsRowNode<TData>> _nodesById = {};

  /// Number of times the node layer has been rebuilt from raw row data.
  /// Incremented by [_rebuildNodesFromRaw]; exposed via [nodeRebuildCount]
  /// for the frame-budget bench to profile node allocation per scenario.
  int _nodeRebuildCount = 0;

  /// Row nodes aligned 1:1 with [_rowData] (raw data order).
  List<OsRowNode<TData>> _rawNodes = const [];

  /// Row nodes currently displayed (post filter/sort), in display order.
  List<OsRowNode<TData>> _renderedNodes = const [];

  /// The shift-range anchor for row selection: the stable ID of the last
  /// non-shift clicked row. Shift+click selects the range between this row
  /// and the clicked row.
  ///
  /// Stored as a row ID (not an index) so the anchor survives sort and
  /// filter — [selectRange] re-finds its current display index on demand.
  ///
  /// Reset only on explicit [deselectAll] and on page changes; data
  /// replacement ([setRowData]) also clears it since the dataset — and
  /// possibly every row ID — is swapped.
  String? _lastSelectedId;

  /// Last pagination page synced from the widget via
  /// [updatePaginationState]. Used to detect page transitions so the
  /// shift-range anchor can be reset (null until the first sync).
  int? _syncedPaginationPage;

  /// Function to derive a stable row ID from row data.
  /// Set by the OsGrid widget from its `getRowId` parameter.
  /// When null, falls back to `hashCode.toString()`.
  String Function(TData data)? _getRowId;

  /// The current processed (filtered/sorted) data.
  /// Set by _OsGridState so the controller can resolve IDs ↔ indices.
  List<TData> _processedData = [];

  /// The current page data (subset of processed data when paginated).
  /// Set by _OsGridState for page-scoped operations.
  List<TData> _pageData = [];

  /// The row selection configuration. Set by _OsGridState.
  OsRowSelection? _rowSelection;

  /// Whether client-side pagination is active. Synced by _OsGridState so
  /// [getDisplayedRowCount] returns the current page slice when paginated.
  bool _isPaginated = false;

  /// Whether the infinite row model is active. Synced by _OsGridState.
  bool _infiniteModeEnabled = false;

  // --- Event bus ---

  /// Typed publish/subscribe bus backing every event stream getter and
  /// `emitXxx` method below. One broadcast controller per event type is
  /// created lazily on first use; [dispose] closes them all.
  final GridEventBus _bus = GridEventBus();

  // --- Event streams ---

  /// Emitted when the grid is fully initialised.
  Stream<OsGridReadyEvent> get onGridReady => _bus.on<OsGridReadyEvent>();

  /// Emitted when the selection changes.
  Stream<OsSelectionChangedEvent<TData>> get onSelectionChanged =>
      _bus.on<OsSelectionChangedEvent<TData>>();

  /// Emitted when a cell is clicked.
  Stream<OsCellClickedEvent<TData>> get onCellClicked =>
      _bus.on<OsCellClickedEvent<TData>>();

  /// Emitted when a cell value changes via editing.
  Stream<OsCellValueChangedEvent<TData>> get onCellValueChanged =>
      _bus.on<OsCellValueChangedEvent<TData>>();

  /// Emitted when the sort model changes.
  Stream<OsSortChangedEvent> get onSortChanged => _bus.on<OsSortChangedEvent>();

  /// Emitted when the filter model changes.
  Stream<OsFilterChangedEvent> get onFilterChanged =>
      _bus.on<OsFilterChangedEvent>();

  /// Emitted when a row is double-clicked.
  Stream<OsRowDoubleClickedEvent<TData>> get onRowDoubleClicked =>
      _bus.on<OsRowDoubleClickedEvent<TData>>();

  /// Emitted when a row is clicked (any cell in the row is tapped).
  Stream<OsRowClickedEvent<TData>> get onRowClicked =>
      _bus.on<OsRowClickedEvent<TData>>();

  /// Emitted when pagination state changes (page or page size).
  Stream<OsPaginationChangedEvent> get onPaginationChanged =>
      _bus.on<OsPaginationChangedEvent>();

  /// Emitted when row data is updated via [setRowData] or [applyTransaction].
  Stream<OsRowDataUpdatedEvent<TData>> get onRowDataUpdated =>
      _bus.on<OsRowDataUpdatedEvent<TData>>();

  /// Emitted when batched async transactions are flushed.
  ///
  /// Only fires when [OsGrid.asyncTransactionWaitMillis] is set and
  /// transactions have been batched via [applyTransactionAsync].
  Stream<OsAsyncTransactionsFlushedEvent<TData>>
  get onAsyncTransactionsFlushed =>
      _bus.on<OsAsyncTransactionsFlushedEvent<TData>>();

  /// @internal — Used by _OsGridState to emit async transactions flushed event.
  void emitAsyncTransactionsFlushed(
    OsAsyncTransactionsFlushedEvent<TData> event,
  ) {
    _bus.emit(event);
  }

  /// Emitted when the cell range selection changes.
  Stream<OsRangeSelectionChangedEvent> get onRangeSelectionChanged =>
      _bus.on<OsRangeSelectionChangedEvent>();

  /// Emitted when the focused cell changes (keyboard navigation,
  /// pointer-down focus, or [setFocusedCell]).
  ///
  /// Delivered via a post-frame callback — listeners never run during
  /// build or layout. Clearing the focus via [clearFocusedCell] does not
  /// emit this event.
  Stream<OsCellFocusedEvent> get onCellFocused => _bus.on<OsCellFocusedEvent>();

  /// Emitted when a printable or navigation key is pressed while a cell is
  /// focused and the grid is not editing.
  ///
  /// Fires before the grid's built-in key handling; listeners are
  /// informational and cannot consume the event.
  Stream<OsCellKeyDownEvent> get onCellKeyDown => _bus.on<OsCellKeyDownEvent>();

  /// Emitted once after the first render with non-empty processed data.
  ///
  /// Delivered via a post-frame callback — listeners never run during
  /// build or layout.
  Stream<OsFirstDataRenderedEvent> get onFirstDataRendered =>
      _bus.on<OsFirstDataRenderedEvent>();

  /// Emitted when the grid's rendered size changes.
  Stream<OsGridSizeChangedEvent> get onGridSizeChanged =>
      _bus.on<OsGridSizeChangedEvent>();

  /// Emitted when the client-side row model is reprocessed (filter, sort,
  /// transactions) and when the pagination page changes.
  ///
  /// Coalesced per frame; re-entrancy guarded so listeners that trigger
  /// further reprocessing cannot recurse.
  Stream<OsModelUpdatedEvent> get onModelUpdated =>
      _bus.on<OsModelUpdatedEvent>();

  /// Emitted when the raw rowData list reference changes, before the
  /// filter/sort pipeline processes the new data.
  Stream<OsRowDataChangedEvent<TData>> get onRowDataChanged =>
      _bus.on<OsRowDataChangedEvent<TData>>();

  /// Emitted when columns are shown or hidden.
  Stream<OsColumnVisibleEvent> get onColumnVisible =>
      _bus.on<OsColumnVisibleEvent>();

  /// Emitted when columns are pinned or unpinned.
  Stream<OsColumnPinnedEvent> get onColumnPinned =>
      _bus.on<OsColumnPinnedEvent>();

  /// Emitted when columns are resized.
  Stream<OsColumnResizedEvent> get onColumnResized =>
      _bus.on<OsColumnResizedEvent>();

  /// Emitted when columns are moved (reordered).
  Stream<OsColumnMovedEvent> get onColumnMoved => _bus.on<OsColumnMovedEvent>();

  /// Emitted when cell editing starts.
  Stream<OsCellEditingStartedEvent<TData>> get onCellEditingStarted =>
      _bus.on<OsCellEditingStartedEvent<TData>>();

  /// Emitted when cell editing stops (committed or cancelled).
  Stream<OsCellEditingStoppedEvent<TData>> get onCellEditingStopped =>
      _bus.on<OsCellEditingStoppedEvent<TData>>();

  /// Emitted when `readOnlyEdit` is enabled and the user commits an edit.
  ///
  /// The application should handle the data update externally and refresh
  /// the grid data (e.g. via [setRowData] or [applyTransaction]).
  Stream<OsCellEditRequestEvent<TData>> get onCellEditRequest =>
      _bus.on<OsCellEditRequestEvent<TData>>();

  /// Emitted when a row drag operation enters the grid.
  Stream<OsRowDragEnterEvent<TData>> get onRowDragEnter =>
      _bus.on<OsRowDragEnterEvent<TData>>();

  /// Emitted while a row is being dragged over the grid.
  Stream<OsRowDragMoveEvent<TData>> get onRowDragMove =>
      _bus.on<OsRowDragMoveEvent<TData>>();

  /// Emitted when a row drag operation ends (the row is dropped).
  Stream<OsRowDragEndEvent<TData>> get onRowDragEnd =>
      _bus.on<OsRowDragEndEvent<TData>>();

  /// Emitted when a row drag operation leaves the grid area.
  Stream<OsRowDragLeaveEvent<TData>> get onRowDragLeave =>
      _bus.on<OsRowDragLeaveEvent<TData>>();

  /// Emitted when a row is dragged outside the grid bounds.
  ///
  /// Only fires when [OsDragAndDrop.enableDragOut] is `true`.
  Stream<OsRowDragOutEvent<TData>> get onRowDragOut =>
      _bus.on<OsRowDragOutEvent<TData>>();

  /// Emitted when an external item is dropped onto the grid.
  ///
  /// Only fires when [OsDragAndDrop.enableDropIn] is `true`.
  Stream<OsExternalDropEvent> get onExternalDrop =>
      _bus.on<OsExternalDropEvent>();

  /// Emitted when pinned row data changes (top or bottom).
  Stream<OsPinnedRowDataChangedEvent> get onPinnedRowDataChanged =>
      _bus.on<OsPinnedRowDataChangedEvent>();

  /// Emitted before an undo operation is applied.
  Stream<OsUndoStartedEvent> get onUndoStarted => _bus.on<OsUndoStartedEvent>();

  /// Emitted after an undo operation completes.
  Stream<OsUndoEndedEvent> get onUndoEnded => _bus.on<OsUndoEndedEvent>();

  /// Emitted before a redo operation is applied.
  Stream<OsRedoStartedEvent> get onRedoStarted => _bus.on<OsRedoStartedEvent>();

  /// Emitted after a redo operation completes.
  Stream<OsRedoEndedEvent> get onRedoEnded => _bus.on<OsRedoEndedEvent>();

  /// Emitted when a clipboard copy operation completes.
  Stream<OsClipboardCopyEvent> get onClipboardCopy =>
      _bus.on<OsClipboardCopyEvent>();

  /// Emitted when a clipboard paste operation completes.
  Stream<OsClipboardPasteEvent> get onClipboardPaste =>
      _bus.on<OsClipboardPasteEvent>();

  /// Emitted when a clipboard cut operation completes.
  Stream<OsClipboardCutEvent> get onClipboardCut =>
      _bus.on<OsClipboardCutEvent>();

  /// Emitted when a right-click (context menu) occurs on a data cell.
  Stream<OsCellContextMenuEvent<TData>> get onCellContextMenu =>
      _bus.on<OsCellContextMenuEvent<TData>>();

  /// Emits structured diagnostics raised by grid internals: configuration
  /// problems found at validation time, user callbacks that threw and were
  /// safely recovered (comparators, value getters, agg funcs), unknown
  /// column type names and columns missing both `field` and `valueGetter`.
  ///
  /// Each [GridDiagnostic] carries a machine-readable [GridErrorCode] in
  /// addition to the human-readable message printed via `debugPrint`, so
  /// hosts can log, surface or gate on failure classes without parsing
  /// text. Broadcast — multiple listeners are allowed. Only populated in
  /// debug builds; the diagnostics pipeline is a release-mode no-op.
  Stream<GridDiagnostic> get onDiagnostic => _bus.on<GridDiagnostic>();

  /// @internal — Used by _OsGridState to emit context menu event.
  void emitCellContextMenu(OsCellContextMenuEvent<TData> event) {
    _bus.emit(event);
  }

  /// @internal — Used by _OsGridState to emit clipboard copy event.
  void emitClipboardCopy(OsClipboardCopyEvent event) {
    _bus.emit(event);
  }

  /// @internal — Used by _OsGridState to emit clipboard paste event.
  void emitClipboardPaste(OsClipboardPasteEvent event) {
    _bus.emit(event);
  }

  /// @internal — Used by _OsGridState to emit clipboard cut event.
  void emitClipboardCut(OsClipboardCutEvent event) {
    _bus.emit(event);
  }

  // --- Row data ---

  /// The current number of rows (after filtering).
  int get rowCount => _rowData.length;

  /// Replace the entire row dataset.
  void setRowData(List<TData> data) {
    _rowData = List.of(data);
    _selectedIds.clear();
    _lastSelectedId = null;
    _rebuildNodesFromRaw();
    notifyListeners();
    _bus.emit(
      OsRowDataUpdatedEvent<TData>(
        rowData: List.unmodifiable(_rowData),
        rowCount: _rowData.length,
      ),
    );
  }

  /// Apply a transaction (add, remove, update rows) without replacing all data.
  ///
  /// Returns the set of rows that were actually added or updated (the
  /// "touched" rows), which can be used by delta sort to avoid re-sorting
  /// the entire dataset.
  Set<TData> applyTransaction(OsRowTransaction<TData> transaction) {
    final touched = <TData>{};

    if (transaction.add != null) {
      if (transaction.addIndex != null &&
          transaction.addIndex! >= 0 &&
          transaction.addIndex! <= _rowData.length) {
        _rowData.insertAll(transaction.addIndex!, transaction.add!);
      } else {
        _rowData.addAll(transaction.add!);
      }
      touched.addAll(transaction.add!);
    }
    if (transaction.remove != null) {
      // Remove from selection any rows being removed
      for (final row in transaction.remove!) {
        _selectedIds.remove(_resolveRowId(row));
      }
      // Match by resolved row ID (subsumes object identity): rows
      // reconstructed as equal-but-not-identical instances — the standard
      // immutable-data pattern — are still removed when getRowId is
      // configured. Set-based for O(n+m) instead of the previous O(n·m).
      final removalIds = <String>{
        for (final row in transaction.remove!) _resolveRowId(row),
      };
      _rowData.removeWhere((row) => removalIds.contains(_resolveRowId(row)));
    }
    if (transaction.update != null && _getRowId != null) {
      for (final updatedRow in transaction.update!) {
        final updatedId = _resolveRowId(updatedRow);
        final index = _rowData.indexWhere(
          (row) => _resolveRowId(row) == updatedId,
        );
        if (index != -1) {
          _rowData[index] = updatedRow;
          touched.add(updatedRow);
        }
      }
    }
    _rebuildNodesFromRaw();
    notifyListeners();
    _bus.emit(
      OsRowDataUpdatedEvent<TData>(
        rowData: List.unmodifiable(_rowData),
        rowCount: _rowData.length,
      ),
    );
    _onTransactionApplied?.call(touched);
    return touched;
  }

  /// Apply a transaction asynchronously, batching it with other transactions
  /// that arrive within the configured `asyncTransactionWaitMillis` window.
  ///
  /// The `callback` (if provided) is invoked after the batch is flushed.
  ///
  /// Requires `asyncTransactionWaitMillis` to be set on the [OsGrid] widget.
  /// If async transactions are not configured, this falls back to a
  /// synchronous [applyTransaction].
  ///
  /// ```dart
  /// controller.applyTransactionAsync(
  ///   OsRowTransaction(add: [newRow]),
  ///   callback: (tx) => print('Batch applied: ${tx.add?.length} adds'),
  /// );
  /// ```
  void applyTransactionAsync(
    OsRowTransaction<TData> transaction, {
    void Function(OsRowTransaction<TData>)? callback,
  }) {
    if (_onApplyTransactionAsyncRequested != null) {
      _onApplyTransactionAsyncRequested!(transaction, callback);
    } else {
      // Fallback: apply synchronously if async not configured.
      applyTransaction(transaction);
      callback?.call(transaction);
    }
  }

  /// Immediately flush all pending async transactions without waiting for
  /// the timer to expire.
  ///
  /// This is a no-op if there are no pending transactions.
  ///
  /// ```dart
  /// controller.flushAsyncTransactions();
  /// ```
  void flushAsyncTransactions() {
    _onFlushAsyncTransactionsRequested?.call();
  }

  /// Force a refresh of the client-side row model pipeline.
  ///
  /// Re-runs filtering and sorting on the current data. This is useful after
  /// programmatic changes that affect filter/sort evaluation (e.g. modifying
  /// a custom comparator or filter function externally).
  ///
  /// ```dart
  /// controller.refreshClientSideRowModel();
  /// ```
  void refreshClientSideRowModel() {
    _onRefreshClientSideRowModelRequested?.call();
  }

  /// @internal — Callback set by _OsGridState to handle refreshClientSideRowModel.
  void Function()? _onRefreshClientSideRowModelRequested;

  /// @internal — Used by _OsGridState to register refreshClientSideRowModel callback.
  set onRefreshClientSideRowModelRequested(void Function()? fn) =>
      _onRefreshClientSideRowModelRequested = fn;

  /// @internal — Callback set by _OsGridState to handle applyTransactionAsync.
  void Function(
    OsRowTransaction<TData>,
    void Function(OsRowTransaction<TData>)?,
  )?
  _onApplyTransactionAsyncRequested;

  /// @internal — Callback set by _OsGridState to handle flushAsyncTransactions.
  void Function()? _onFlushAsyncTransactionsRequested;

  /// @internal — Used by _OsGridState to register applyTransactionAsync callback.
  set onApplyTransactionAsyncRequested(
    void Function(
      OsRowTransaction<TData>,
      void Function(OsRowTransaction<TData>)?,
    )?
    fn,
  ) => _onApplyTransactionAsyncRequested = fn;

  /// @internal — Used by _OsGridState to register flushAsyncTransactions callback.
  set onFlushAsyncTransactionsRequested(void Function()? fn) =>
      _onFlushAsyncTransactionsRequested = fn;

  /// @internal — Callback invoked when applyTransaction completes with touched rows.
  /// Used by the widget to track touched rows for delta sort.
  void Function(Set<TData>)? _onTransactionApplied;

  /// @internal — Used by _OsGridState to register transaction applied callback.
  set onTransactionApplied(void Function(Set<TData>)? fn) =>
      _onTransactionApplied = fn;

  /// Get the row data at a specific index, or null if out of bounds.
  TData? getRowAtIndex(int index) {
    if (index < 0 || index >= _rowData.length) return null;
    return _rowData[index];
  }

  /// Whether the row data is empty.
  bool isRowDataEmpty() => _rowData.isEmpty;

  // --- Cell API ---

  /// Get the value of a specific cell by row index and column ID.
  ///
  /// Resolves the value using the column's [OsColumnDef.valueGetter] if
  /// available, otherwise falls back to field lookup on Map-based data.
  ///
  /// The [rowIndex] refers to the current processed (filtered/sorted) data.
  /// Returns `null` if the row index is out of bounds or the column is not found.
  ///
  /// ```dart
  /// final price = controller.getCellValue(rowIndex: 2, colId: 'price');
  /// ```
  dynamic getCellValue({required int rowIndex, required String colId}) {
    final source = _processedData.isNotEmpty ? _processedData : _rowData;
    if (rowIndex < 0 || rowIndex >= source.length) return null;

    final col = _columnDefs?.cast<OsColumnDef?>().firstWhere(
      (c) => c!.effectiveColId == colId || c.field == colId,
      orElse: () => null,
    );
    if (col == null) return null;

    return _resolveColumnValue(col, source[rowIndex], rowIndex);
  }

  /// Get a cell value from a data object for a given column ID.
  ///
  /// Uses the column's [OsColumnDef.valueGetter] if available, otherwise
  /// falls back to field lookup on Map-based data. This is useful when you
  /// have a data object but not its display index.
  ///
  /// Returns `null` if the column is not found.
  ///
  /// ```dart
  /// final name = controller.getValue(myRowData, 'name');
  /// ```
  dynamic getValue(TData data, String colId) {
    final col = _columnDefs?.cast<OsColumnDef?>().firstWhere(
      (c) => c!.effectiveColId == colId || c.field == colId,
      orElse: () => null,
    );
    if (col == null) return null;

    // Use index 0 as a fallback since we don't know the display index.
    return _resolveColumnValue(col, data, 0);
  }

  /// Resolves the raw value for a column from a row data object.
  ///
  /// Tries [OsColumnDef.valueGetter] first, then falls back to field lookup.
  dynamic _resolveColumnValue(OsColumnDef col, TData row, int rowIndex) {
    // Try valueGetter first.
    // Use getValueGetterAsFunction() to avoid Dart's contravariance issue
    // when OsColumnDef<Person> is stored in a List<OsColumnDef<dynamic>>.
    final getter = col.getValueGetterAsFunction();
    if (getter != null) {
      return Function.apply(getter, [
        ValueGetterParams<TData>(data: row, rowIndex: rowIndex),
      ]);
    }

    // Fall back to field lookup on Map data.
    if (col.field != null && row is Map<String, dynamic>) {
      return row[col.field];
    }

    return null;
  }

  /// Iterate over all leaf row nodes (all rows in the dataset).
  ///
  /// The callback receives each row's data and its index in the raw data list.
  void forEachNode(void Function(TData data, int index) callback) {
    for (int i = 0; i < _rowData.length; i++) {
      callback(_rowData[i], i);
    }
  }

  /// Iterate over all leaf row nodes (all rows in the dataset).
  ///
  /// For flat data (no row grouping), this is identical to [forEachNode].
  /// When row grouping is implemented, this will iterate only leaf rows
  /// (excluding group rows).
  void forEachLeafNode(void Function(TData data, int index) callback) {
    forEachNode(callback);
  }

  /// Iterate over all rows that pass the current filter.
  ///
  /// The callback receives each row's data and its index in the filtered list.
  void forEachNodeAfterFilter(void Function(TData data, int index) callback) {
    final source = _processedData.isNotEmpty ? _processedData : _rowData;
    for (int i = 0; i < source.length; i++) {
      callback(source[i], i);
    }
  }

  /// Iterate over all rows after filter and sort have been applied.
  ///
  /// This is equivalent to [forEachNodeAfterFilter] since the processed data
  /// is already filtered and sorted.
  void forEachNodeAfterFilterAndSort(
    void Function(TData data, int index) callback,
  ) {
    forEachNodeAfterFilter(callback);
  }

  // --- Row nodes ---

  /// Get a row node by its stable ID, or `null` if no such row exists.
  ///
  /// ```dart
  /// final node = controller.getNode('row-1');
  /// if (node != null) print(node.data);
  /// ```
  OsRowNode<TData>? getNode(String id) => _nodesById[id];

  /// All currently displayed row nodes (after filter + sort), in display
  /// order.
  Iterable<OsRowNode<TData>> getRenderedNodes() =>
      List.unmodifiable(_renderedNodes);

  /// Get the currently selected rows as [OsRowNode]s.
  ///
  /// Mirrors [getSelectedRows]: results are in display order and only
  /// include rows present in the current display list.
  List<OsRowNode<TData>> getSelectedNodes() {
    final source = _renderedNodes.isNotEmpty ? _renderedNodes : _rawNodes;
    return [
      for (final node in source)
        if (node.selected) node,
    ];
  }

  /// Whether [node]'s row is currently selected.
  bool isNodeSelected(OsRowNode<TData> node) => _selectedIds.contains(node.id);

  /// Iterate over all row nodes in raw data order.
  ///
  /// Unlike the data-based [forEachNode], the callback receives the
  /// [OsRowNode] wrapper (with id, display index and selection state).
  /// Every raw row is visited exactly once.
  void forEachRowNode(void Function(OsRowNode<TData> node) callback) {
    for (final node in _rawNodes) {
      callback(node);
    }
  }

  /// Number of row nodes currently retained by the controller's node pool
  /// (the internal `_nodesById` map).
  ///
  /// After a full `setRowData` replacement this equals the size of the new
  /// dataset: nodes whose IDs disappeared are dropped from the map in the
  /// same rebuild and become GC-eligible. See [OsRowNode] for the full
  /// retention contract.
  @visibleForTesting
  int get nodePoolSize => _nodesById.length;

  /// How many times the node layer has been rebuilt from raw row data
  /// (`setRowData`, `applyTransaction`, and `getRowId` swaps each trigger
  /// exactly one rebuild). Exposed for the frame-budget bench to profile
  /// node allocation per scenario.
  @visibleForTesting
  int get nodeRebuildCount => _nodeRebuildCount;

  /// Rebuilds the node layer from [_rowData], reusing existing node
  /// instances for surviving IDs so node identity is stable across data
  /// updates.
  void _rebuildNodesFromRaw() {
    _nodeRebuildCount++;
    final previousById = Map<String, OsRowNode<TData>>.of(_nodesById);
    _nodesById.clear();
    final rawNodes = <OsRowNode<TData>>[];
    final seenIds = <String>{};
    for (int i = 0; i < _rowData.length; i++) {
      final row = _rowData[i];
      final id = _resolveRowId(row);
      // Reuse the previous instance for the first occurrence of a
      // surviving ID; duplicate IDs get fresh nodes (last one wins the map).
      OsRowNode<TData>? node = seenIds.add(id) ? previousById[id] : null;
      if (node != null) {
        node
          ..data = row
          ..rowIndex = -1;
      } else {
        node = OsRowNode<TData>(data: row, id: id);
      }
      rawNodes.add(node);
      _nodesById[id] = node;
    }
    _rawNodes = rawNodes;
    _refreshDisplayedNodeState();
  }

  /// Syncs display state (rowIndex, rendered order, selection flags)
  /// from the current processed data.
  void _refreshDisplayedNodeState() {
    for (final node in _rawNodes) {
      node.rowIndex = -1;
      node.selected = _selectedIds.contains(node.id);
    }
    final source = _processedData.isNotEmpty ? _processedData : _rowData;
    final rendered = <OsRowNode<TData>>[];
    final seen = <OsRowNode<TData>>{};
    for (int i = 0; i < source.length; i++) {
      final node = _nodesById[_resolveRowId(source[i])];
      if (node == null || !seen.add(node)) continue;
      node.rowIndex = i;
      rendered.add(node);
    }
    _renderedNodes = rendered;
  }

  // --- Selection ---

  /// Get all currently selected rows.
  ///
  /// Returns the data objects for all rows whose IDs are in the selection set.
  /// The order matches the current display order (processed data).
  List<TData> getSelectedRows() {
    if (_selectedIds.isEmpty) return [];
    final result = <TData>[];
    // Prefer processed data order if available, fall back to raw data
    final source = _processedData.isNotEmpty ? _processedData : _rowData;
    for (final row in source) {
      if (_selectedIds.contains(_resolveRowId(row))) {
        result.add(row);
      }
    }
    return result;
  }

  /// Get the set of currently selected row IDs.
  Set<String> getSelectedIds() => Set.unmodifiable(_selectedIds);

  /// Select all rows.
  ///
  /// Respects the [OsRowSelection.selectAll] mode and `isRowSelectable` callback.
  void selectAll() {
    final mode = _rowSelection?.selectAll ?? SelectAllMode.all;
    _selectAllForMode(mode);
  }

  /// Select all rows that pass the current filter.
  ///
  /// Only selects rows in [_processedData] (the filtered/sorted dataset).
  void selectAllFiltered() {
    _selectAllForMode(SelectAllMode.filtered);
  }

  /// Deselect all rows that pass the current filter.
  ///
  /// Only deselects rows in [_processedData]; rows hidden by the filter
  /// remain in their current selection state.
  void deselectAllFiltered() {
    for (final row in _processedData) {
      _selectedIds.remove(_resolveRowId(row));
    }
    notifyListeners();
    _emitSelectionChanged();
  }

  /// Select all rows on the current page.
  ///
  /// Only selects rows in [_pageData].
  void selectAllOnCurrentPage() {
    _selectAllForMode(SelectAllMode.currentPage);
  }

  /// Deselect all rows on the current page.
  ///
  /// Only deselects rows in [_pageData]; rows on other pages
  /// remain in their current selection state.
  void deselectAllOnCurrentPage() {
    for (final row in _pageData) {
      _selectedIds.remove(_resolveRowId(row));
    }
    notifyListeners();
    _emitSelectionChanged();
  }

  /// Deselect all rows.
  void deselectAll() {
    if (_selectedIds.isEmpty) return;
    _selectedIds.clear();
    _lastSelectedId = null;
    notifyListeners();
    _emitSelectionChanged();
  }

  /// Select rows by their IDs.
  void selectRowsById(List<String> ids) {
    _selectedIds.addAll(ids);
    notifyListeners();
    _emitSelectionChanged();
  }

  /// Deselect specific rows by their IDs.
  ///
  /// Removes the given IDs from the selection set. IDs that are not
  /// currently selected are silently ignored.
  ///
  /// ```dart
  /// controller.deselectRowsById({'row-1', 'row-3'});
  /// ```
  void deselectRowsById(Set<String> ids) {
    if (ids.isEmpty) return;
    _selectedIds.removeAll(ids);
    // Note: the shift-range anchor is intentionally preserved — it only
    // resets on explicit deselectAll or a page change, so shift+click can
    // still extend from the last clicked row after an API deselection.
    notifyListeners();
    _emitSelectionChanged();
  }

  /// Select rows at the given display indices (resolved to IDs internally).
  ///
  /// This is a convenience method for backward compatibility.
  void selectRows(List<int> indices) {
    final source = _processedData.isNotEmpty ? _processedData : _rowData;
    for (final i in indices) {
      if (i >= 0 && i < source.length) {
        final id = _resolveRowId(source[i]);
        if (_isRowSelectable(source[i])) {
          _selectedIds.add(id);
        }
      }
    }
    notifyListeners();
    _emitSelectionChanged();
  }

  /// Whether the row at [index] is selected.
  ///
  /// Resolves the display index to a row ID and checks the selection set.
  /// This method is used by the painter for rendering selected row backgrounds.
  bool isRowSelected(int index) {
    final source = _processedData.isNotEmpty ? _processedData : _rowData;
    if (index < 0 || index >= source.length) return false;
    return _selectedIds.contains(_resolveRowId(source[index]));
  }

  // --- Editing ---

  /// Whether any cell is currently being edited.
  bool get isEditing => _isEditing;

  /// @internal — Set by _OsGridState when editing starts/stops.
  bool _isEditing = false;

  /// Programmatically start editing a cell.
  ///
  /// The cell must be editable (via `editable: true` or `editableCallback`).
  /// If another cell is already being edited, it will be committed first.
  ///
  /// ```dart
  /// controller.startEditingCell(rowIndex: 0, colId: 'name');
  /// ```
  void startEditingCell({required int rowIndex, required String colId}) {
    _onStartEditingCellRequested?.call(rowIndex, colId);
  }

  /// Programmatically stop editing.
  ///
  /// When [cancel] is `true`, the edit is reverted to the original value.
  /// When [cancel] is `false` (default), the edit is committed.
  ///
  /// ```dart
  /// controller.stopEditing(); // commit
  /// controller.stopEditing(cancel: true); // cancel/revert
  /// ```
  void stopEditing({bool cancel = false}) {
    _onStopEditingRequested?.call(cancel);
  }

  /// @internal — Callback set by _OsGridState to handle startEditingCell.
  void Function(int rowIndex, String colId)? _onStartEditingCellRequested;

  /// @internal — Callback set by _OsGridState to handle stopEditing.
  void Function(bool cancel)? _onStopEditingRequested;

  /// @internal — Used by _OsGridState to register startEditingCell callback.
  set onStartEditingCellRequested(void Function(int, String)? fn) =>
      _onStartEditingCellRequested = fn;

  /// @internal — Used by _OsGridState to register stopEditing callback.
  set onStopEditingRequested(void Function(bool)? fn) =>
      _onStopEditingRequested = fn;

  // --- Undo/Redo ---

  /// Undo the last cell edit.
  ///
  /// Reverts the most recent edit and pushes it to the redo stack.
  /// Fires [onUndoStarted] before and [onUndoEnded] after the operation.
  ///
  /// ```dart
  /// controller.undoCellEditing();
  /// ```
  void undoCellEditing() {
    _onUndoCellEditingRequested?.call();
  }

  /// Redo the last undone cell edit.
  ///
  /// Reapplies the most recently undone edit and pushes it to the undo stack.
  /// Fires [onRedoStarted] before and [onRedoEnded] after the operation.
  ///
  /// ```dart
  /// controller.redoCellEditing();
  /// ```
  void redoCellEditing() {
    _onRedoCellEditingRequested?.call();
  }

  /// Get the current number of actions on the undo stack.
  ///
  /// Returns 0 if undo/redo is not enabled.
  int getCurrentUndoSize() {
    return _onGetCurrentUndoSizeRequested?.call() ?? 0;
  }

  /// Get the current number of actions on the redo stack.
  ///
  /// Returns 0 if undo/redo is not enabled.
  int getCurrentRedoSize() {
    return _onGetCurrentRedoSizeRequested?.call() ?? 0;
  }

  /// @internal — Callback set by _OsGridState to handle undoCellEditing.
  void Function()? _onUndoCellEditingRequested;

  /// @internal — Callback set by _OsGridState to handle redoCellEditing.
  void Function()? _onRedoCellEditingRequested;

  /// @internal — Callback set by _OsGridState to get undo stack size.
  int Function()? _onGetCurrentUndoSizeRequested;

  /// @internal — Callback set by _OsGridState to get redo stack size.
  int Function()? _onGetCurrentRedoSizeRequested;

  /// @internal — Used by _OsGridState to register undo callback.
  set onUndoCellEditingRequested(void Function()? fn) =>
      _onUndoCellEditingRequested = fn;

  /// @internal — Used by _OsGridState to register redo callback.
  set onRedoCellEditingRequested(void Function()? fn) =>
      _onRedoCellEditingRequested = fn;

  /// @internal — Used by _OsGridState to register undo size callback.
  set onGetCurrentUndoSizeRequested(int Function()? fn) =>
      _onGetCurrentUndoSizeRequested = fn;

  /// @internal — Used by _OsGridState to register redo size callback.
  set onGetCurrentRedoSizeRequested(int Function()? fn) =>
      _onGetCurrentRedoSizeRequested = fn;

  /// @internal — Used by _OsGridState to emit undo started event.
  void emitUndoStarted(OsUndoStartedEvent event) {
    _bus.emit(event);
  }

  /// @internal — Used by _OsGridState to emit undo ended event.
  void emitUndoEnded(OsUndoEndedEvent event) {
    _bus.emit(event);
  }

  /// @internal — Used by _OsGridState to emit redo started event.
  void emitRedoStarted(OsRedoStartedEvent event) {
    _bus.emit(event);
  }

  /// @internal — Used by _OsGridState to emit redo ended event.
  void emitRedoEnded(OsRedoEndedEvent event) {
    _bus.emit(event);
  }

  /// Emitted when a tooltip is shown.
  Stream<OsTooltipShowEvent> get onTooltipShow => _bus.on<OsTooltipShowEvent>();

  /// Emitted when a tooltip is hidden.
  Stream<OsTooltipHideEvent> get onTooltipHide => _bus.on<OsTooltipHideEvent>();

  /// @internal — Used by _OsGridState to emit tooltip show event.
  void emitTooltipShow(OsTooltipShowEvent event) {
    _bus.emit(event);
  }

  /// @internal — Used by _OsGridState to emit tooltip hide event.
  void emitTooltipHide(OsTooltipHideEvent event) {
    _bus.emit(event);
  }

  // --- Column hover ---

  /// The column ID currently being hovered, or `null` if no column is hovered.
  ///
  /// Only tracked when `columnHoverHighlight` is enabled on the grid.
  String? _hoveredColumnId;

  /// Emitted when the hovered column changes.
  ///
  /// Only fires when [OsGrid.columnHoverHighlight] is `true`.
  Stream<OsColumnHoverChangedEvent> get onColumnHoverChanged =>
      _bus.on<OsColumnHoverChangedEvent>();

  /// Returns `true` if the given column is currently being hovered.
  ///
  /// Always returns `false` if `columnHoverHighlight` is not enabled.
  bool isColumnHovered(String colId) => _hoveredColumnId == colId;

  /// @internal — Used by _OsGridState to emit column hover changed event.
  void emitColumnHoverChanged(OsColumnHoverChangedEvent event) {
    _hoveredColumnId = event.column;
    _bus.emit(event);
  }

  // --- Columns ---

  /// Replaces the grid's column definitions at runtime.
  ///
  /// The new definitions take effect immediately, without rebuilding the
  /// host widget. Column *state* is keyed by colId and survives the swap for
  /// columns that are still defined — a width set by the user, a pin, a
  /// hidden flag or a custom order all carry over. State for columns that
  /// the new definitions drop is discarded, so it can never resurface on a
  /// later column reusing the same colId. A definition change therefore does
  /// not re-apply a new `width` on a column whose state carries an override;
  /// call [setColumnWidths] or [resetColumnState] afterwards if that is what
  /// you want.
  ///
  /// Passing new definitions to the `OsGrid` widget's `columnDefs` property
  /// takes precedence: a host rebuild with a different list discards an
  /// override installed here.
  ///
  /// Has no effect before the grid is mounted, or after [dispose].
  void setColumnDefs(List<OsColumnDefBase> defs) {
    _onSetColumnDefsRequested?.call(List<OsColumnDefBase>.unmodifiable(defs));
  }

  /// Sizes columns to fit their content.
  ///
  /// Measures the widest rendered value in each column with a
  /// `TextPainter` and sets the width to the widest measurement plus the
  /// grid's cell padding, sort-indicator and menu-icon allowances, clamped
  /// to each column's `minWidth`/`maxWidth`.
  ///
  /// [colIds] restricts the operation to the named columns; when null every
  /// displayed column is measured in a single pass over the rows. Hidden
  /// columns and columns without a `field` are skipped. Set [skipHeader] to
  /// true to size columns to their cell content alone, ignoring the header
  /// text.
  ///
  /// Requires mounted row data to measure; with no rows the header (unless
  /// skipped) still sizes each column. Call after [onGridReady] if you need
  /// the measured result synchronously — the call itself is safe from
  /// `initState`, but `MediaQuery`-derived text scaling is only readable
  /// once the first frame has been laid out.
  void autoSizeColumns({List<String>? colIds, bool skipHeader = false}) {
    _onAutoSizeColumnsRequested?.call(
      colIds == null ? null : Set<String>.unmodifiable(colIds),
      skipHeader,
    );
  }

  /// Distributes the grid's available width across its unpinned columns.
  ///
  /// The displayed centre columns are scaled proportionally to their current
  /// widths so they exactly fill the centre viewport, then clamped to each
  /// column's `minWidth`/`maxWidth`; slack left by clamped columns is
  /// redistributed over the columns that can still move. Pinned (left and
  /// right) and hidden columns keep their widths — they do not share the
  /// centre viewport.
  ///
  /// If the grid has not been laid out yet (for example when called from
  /// `onGridReady`), the sizing is deferred to the first frame that has a
  /// viewport width.
  void sizeColumnsToFit() {
    _onSizeColumnsToFitRequested?.call();
  }

  // --- Row Redraw ---

  /// Forces a repaint of all rows.
  ///
  /// Useful when external state that affects [OsGrid.getRowStyle] has
  /// changed and the grid needs to recalculate row styles.
  ///
  /// ```dart
  /// // External state changed that affects row styling
  /// _highlightedIds.add(newId);
  /// controller.redrawRows();
  /// ```
  void redrawRows() {
    notifyListeners();
  }

  // --- Render API ---

  /// Force a repaint of specified cells.
  ///
  /// In the canvas-based Flutter grid, the painter always reads current
  /// values on every frame, so "refreshing" simply triggers a repaint.
  /// The primary use case is to trigger flash effects on specific cells
  /// after a programmatic data update.
  ///
  /// When [params] is null or [RefreshCellsParams.suppressFlash] is false,
  /// the affected cells will flash briefly to indicate the change.
  ///
  /// ```dart
  /// // Refresh specific cells with flash
  /// controller.refreshCells(RefreshCellsParams(
  ///   rowIndices: [0, 1, 2],
  ///   columns: ['price', 'volume'],
  /// ));
  ///
  /// // Refresh without flash
  /// controller.refreshCells(RefreshCellsParams(suppressFlash: true));
  /// ```
  void refreshCells([RefreshCellsParams? params]) {
    final p = params ?? const RefreshCellsParams();
    if (!p.suppressFlash) {
      _onFlashCellsRequested?.call(
        FlashCellsParams(rowIndices: p.rowIndices, columns: p.columns),
      );
    }
    notifyListeners();
  }

  /// Temporarily highlight cells with a flash-then-fade animation.
  ///
  /// The flash effect paints a semi-transparent highlight over the cell
  /// background at full opacity for [FlashCellsParams.flashDuration] ms,
  /// then fades to transparent over [FlashCellsParams.fadeDuration] ms.
  ///
  /// If a cell is already flashing, the flash restarts from the beginning.
  ///
  /// ```dart
  /// // Flash specific cells
  /// controller.flashCells(FlashCellsParams(
  ///   rowIndices: [0, 1],
  ///   columns: ['price'],
  ///   flashDuration: 300,
  ///   fadeDuration: 600,
  /// ));
  ///
  /// // Flash all visible cells with defaults
  /// controller.flashCells();
  /// ```
  void flashCells([FlashCellsParams? params]) {
    _onFlashCellsRequested?.call(params ?? const FlashCellsParams());
  }

  /// Force a repaint of the column headers.
  ///
  /// Useful after programmatic changes to column definitions that affect
  /// header display (e.g. changing headerName).
  void refreshHeader() {
    notifyListeners();
  }

  /// @internal — Callback set by _OsGridState to handle flashCells requests.
  void Function(FlashCellsParams params)? _onFlashCellsRequested;

  /// @internal — Used by _OsGridState to register flash cells callback.
  set onFlashCellsRequested(void Function(FlashCellsParams)? fn) =>
      _onFlashCellsRequested = fn;

  // --- Pinned Rows ---

  /// Internal pinned row data (synced from widget).
  List<TData> _pinnedTopRowData = [];
  List<TData> _pinnedBottomRowData = [];

  /// Get the number of rows pinned to the top.
  int getPinnedTopRowCount() => _pinnedTopRowData.length;

  /// Get the number of rows pinned to the bottom.
  int getPinnedBottomRowCount() => _pinnedBottomRowData.length;

  /// Get the data for a pinned top row by index.
  ///
  /// Returns null if [index] is out of bounds.
  TData? getPinnedTopRow(int index) {
    if (index < 0 || index >= _pinnedTopRowData.length) return null;
    return _pinnedTopRowData[index];
  }

  /// Get the data for a pinned bottom row by index.
  ///
  /// Returns null if [index] is out of bounds.
  TData? getPinnedBottomRow(int index) {
    if (index < 0 || index >= _pinnedBottomRowData.length) return null;
    return _pinnedBottomRowData[index];
  }

  /// @internal — Used by _OsGridState to sync pinned row data.
  set pinnedTopRowData(List<TData> data) => _pinnedTopRowData = data;

  /// @internal — Used by _OsGridState to sync pinned row data.
  set pinnedBottomRowData(List<TData> data) => _pinnedBottomRowData = data;

  /// @internal — Used by _OsGridState to emit pinned row data changed event.
  void emitPinnedRowDataChanged(OsPinnedRowDataChangedEvent event) {
    _bus.emit(event);
  }

  // --- Column Visibility ---

  /// Show or hide columns by their IDs.
  ///
  /// ```dart
  /// controller.setColumnsVisible(['age', 'email'], false); // hide
  /// controller.setColumnsVisible(['age'], true); // show
  /// ```
  void setColumnsVisible(List<String> colIds, bool visible) {
    _onSetColumnsVisibleRequested?.call(colIds, visible);
  }

  // --- Column Pinning (programmatic) ---

  /// Pin or unpin columns by their IDs.
  ///
  /// ```dart
  /// controller.setColumnsPinned(['name'], OsColumnPin.left);
  /// controller.setColumnsPinned(['name'], null); // unpin
  /// ```
  void setColumnsPinned(List<String> colIds, OsColumnPin? pinned) {
    _onSetColumnsPinnedRequested?.call(colIds, pinned);
  }

  /// Whether any columns are currently pinned (left or right).
  bool isPinning() => isPinningLeft() || isPinningRight();

  /// Whether any columns are currently pinned to the left.
  bool isPinningLeft() {
    if (_columnDefs == null) return false;
    final hiddenIds = _hiddenColumnIds;
    final pinOverrides = _columnPinOverrides;
    for (final col in _columnDefs!) {
      final colId = col.effectiveColId;
      if (hiddenIds.contains(colId)) continue;
      final pin = pinOverrides[colId] ?? col.pinned;
      if (pin == OsColumnPin.left) return true;
    }
    return false;
  }

  /// Whether any columns are currently pinned to the right.
  bool isPinningRight() {
    if (_columnDefs == null) return false;
    final hiddenIds = _hiddenColumnIds;
    final pinOverrides = _columnPinOverrides;
    for (final col in _columnDefs!) {
      final colId = col.effectiveColId;
      if (hiddenIds.contains(colId)) continue;
      final pin = pinOverrides[colId] ?? col.pinned;
      if (pin == OsColumnPin.right) return true;
    }
    return false;
  }

  // --- Column State ---

  /// Get a snapshot of all column states (visibility, width, pinning, order, sort).
  ///
  /// The returned list can be serialised and later restored via [applyColumnState].
  List<ColumnState> getColumnState() {
    if (_columnDefs == null) return [];

    final orderedColIds =
        _columnOrder ?? _columnDefs!.map((c) => c.effectiveColId).toList();
    final result = <ColumnState>[];

    // Get the current sort model to include sort state per column
    final currentSortModel = onGetSortModelRequested?.call() ?? [];

    for (final colId in orderedColIds) {
      final col = _columnDefs!.cast<OsColumnDef?>().firstWhere(
        (c) => c!.effectiveColId == colId,
        orElse: () => null,
      );
      if (col == null) continue;

      // Resolve sort state from the sort model
      OsSortDirection? sortDirection;
      int? sortIdx;
      for (int i = 0; i < currentSortModel.length; i++) {
        if (currentSortModel[i].colId == colId) {
          sortDirection = currentSortModel[i].sort;
          sortIdx = i;
          break;
        }
      }

      result.add(
        ColumnState(
          colId: colId,
          hide: _hiddenColumnIds.contains(colId)
              ? true
              : (col.hide == true ? true : null),
          width: _columnWidths[colId] ?? col.width,
          flex: col.flex,
          pinned: _columnPinOverrides[colId] ?? col.pinned,
          sort: sortDirection,
          sortIndex: sortIdx,
        ),
      );
    }

    return result;
  }

  /// Apply a previously saved column state.
  ///
  /// Returns `true` if all state entries were matched to columns,
  /// `false` if any entries could not be matched.
  ///
  /// By default the given state is MERGED into the current state: only
  /// fields explicitly set on each [ColumnState] entry change. Set
  /// [ApplyColumnStateParams.purge] to true to first remove ALL existing
  /// state (widths, pins, visibility, order, sort) — equivalent to
  /// [resetColumnState] followed by applying only the provided subset —
  /// so columns absent from the state list fall back to their definition
  /// values.
  ///
  /// ```dart
  /// final state = controller.getColumnState();
  /// // ... later ...
  /// controller.applyColumnState(ApplyColumnStateParams(state: state));
  /// ```
  bool applyColumnState(ApplyColumnStateParams params) {
    return _onApplyColumnStateRequested?.call(params) ?? false;
  }

  /// Reset all column state to the original column definitions.
  ///
  /// Clears all width overrides, pin overrides, visibility overrides,
  /// and column order.
  void resetColumnState() {
    _onResetColumnStateRequested?.call();
  }

  // --- Column Widths ---

  /// Set column widths programmatically.
  ///
  /// ```dart
  /// controller.setColumnWidths([
  ///   ColumnWidthEntry(colId: 'name', newWidth: 200),
  ///   ColumnWidthEntry(colId: 'age', newWidth: 80),
  /// ]);
  /// ```
  void setColumnWidths(List<ColumnWidthEntry> widths, {bool finished = true}) {
    _onSetColumnWidthsRequested?.call(widths, finished);
  }

  // --- Column Move ---

  /// Move a column from one display index to another.
  void moveColumnByIndex(int fromIndex, int toIndex) {
    _onMoveColumnByIndexRequested?.call(fromIndex, toIndex);
  }

  /// Move columns (by ID) to a target display index.
  void moveColumns(List<String> colIds, int toIndex) {
    _onMoveColumnsRequested?.call(colIds, toIndex);
  }

  // --- Column Query ---

  /// Get a column definition by its ID.
  ///
  /// Returns null if no column with the given ID exists.
  OsColumnDef? getColumnDef(String colId) {
    return _columnDefs?.cast<OsColumnDef?>().firstWhere(
      (c) => c!.effectiveColId == colId,
      orElse: () => null,
    );
  }

  /// Get all column definitions (regardless of visibility).
  List<OsColumnDef> getColumns() {
    return List.unmodifiable(_columnDefs ?? []);
  }

  /// Get all currently displayed (visible) columns in display order.
  ///
  /// Excludes hidden columns. Respects column order overrides.
  List<OsColumnDef> getAllDisplayedColumns() {
    if (_columnDefs == null) return [];
    final orderedColIds =
        _columnOrder ?? _columnDefs!.map((c) => c.effectiveColId).toList();
    return orderedColIds
        .where((id) => !_hiddenColumnIds.contains(id))
        .map(
          (id) => _columnDefs!.cast<OsColumnDef?>().firstWhere(
            (c) => c!.effectiveColId == id,
            orElse: () => null,
          ),
        )
        .whereType<OsColumnDef>()
        .toList();
  }

  /// Get all currently displayed columns pinned to the left.
  List<OsColumnDef> getDisplayedLeftColumns() {
    return getAllDisplayedColumns().where((col) {
      final pin = _columnPinOverrides[col.effectiveColId] ?? col.pinned;
      return pin == OsColumnPin.left;
    }).toList();
  }

  /// Get all currently displayed columns in the centre (unpinned).
  List<OsColumnDef> getDisplayedCenterColumns() {
    return getAllDisplayedColumns().where((col) {
      final pin = _columnPinOverrides[col.effectiveColId] ?? col.pinned;
      return pin == null;
    }).toList();
  }

  /// Get all currently displayed columns pinned to the right.
  List<OsColumnDef> getDisplayedRightColumns() {
    return getAllDisplayedColumns().where((col) {
      final pin = _columnPinOverrides[col.effectiveColId] ?? col.pinned;
      return pin == OsColumnPin.right;
    }).toList();
  }

  /// Get the displayed column immediately after [colId], or `null` when
  /// [colId] is not displayed or is already the last displayed column.
  ///
  /// Neighbours are resolved over the flattened display order — left
  /// pinned section, centre section, right pinned section, each in current
  /// order with hidden columns excluded — so the result crosses
  /// pin-section boundaries (the last left-pinned column's neighbour is
  /// the first centre column). This mirrors AG Grid's
  /// `getDisplayedColAfter`.
  ///
  /// Returns `null` before the grid attaches (no widget bound).
  OsColumnDef? getDisplayedColAfter(String colId) =>
      _onGetDisplayedColAfterRequested?.call(colId);

  /// Get the displayed column immediately before [colId], or `null` when
  /// [colId] is not displayed or is already the first displayed column.
  ///
  /// See [getDisplayedColAfter] for ordering semantics. Mirrors AG Grid's
  /// `getDisplayedColBefore`.
  OsColumnDef? getDisplayedColBefore(String colId) =>
      _onGetDisplayedColBeforeRequested?.call(colId);

  // --- Sort & Filter ---

  /// Callback invoked by the widget state when setSortModel is called.
  void Function(List<OsSortModel> model)? onSetSortModelRequested;

  /// Returns the current sort model.
  ///
  /// The returned list is ordered by sort priority (index 0 = primary sort).
  List<OsSortModel> Function()? onGetSortModelRequested;

  /// Get the current sort model.
  ///
  /// Returns an ordered list of sort entries (primary sort first).
  List<OsSortModel> getSortModel() {
    return onGetSortModelRequested?.call() ?? [];
  }

  /// Set the sort model programmatically.
  ///
  /// Replaces the current sort state with the provided model and triggers
  /// a re-sort of the data.
  void setSortModel(List<OsSortModel> model) {
    onSetSortModelRequested?.call(model);
    notifyListeners();
  }

  /// Set the filter model programmatically.
  ///
  /// The model is a map of column IDs to filter model maps. Each entry
  /// follows the OS Grid filter model format:
  /// ```dart
  /// controller.setFilterModel({
  ///   'name': {
  ///     'filterType': 'text',
  ///     'type': 'contains',
  ///     'filter': 'alice',
  ///   },
  ///   'age': {
  ///     'filterType': 'number',
  ///     'type': 'greaterThan',
  ///     'filter': 30,
  ///   },
  /// });
  /// ```
  void setFilterModel(Map<String, dynamic>? model) {
    _filterModel = model;
    notifyListeners();
  }

  /// Get the current filter model.
  ///
  /// Returns a map of column IDs to their filter model maps, or null
  /// if no filters are active.
  Map<String, dynamic>? getFilterModel() => _filterModel;

  /// @internal — Used by OsGrid widget to update the filter model.
  set filterModel(Map<String, dynamic>? model) => _filterModel = model;

  /// @internal — Current filter model state.
  Map<String, dynamic>? _filterModel;

  // --- Quick Filter ---

  /// Quick filter text state and cache invalidation hooks.
  final QuickFilterCoordinator _quickFilter = QuickFilterCoordinator();

  /// Set the quick filter text (searches visible columns).
  ///
  /// Splits the text on whitespace — all parts must match at least one
  /// column value (AND logic between parts, OR logic between columns).
  /// Pass `null` or an empty string to clear the quick filter.
  void setQuickFilter(String? text) => _quickFilter.setText(text);

  /// Returns `true` if a quick filter is currently active.
  bool isQuickFilterPresent() => _quickFilter.isPresent;

  /// Returns the current quick filter text, or `null` if none is set.
  String? getQuickFilter() => _quickFilter.text;

  /// Resets any cached quick filter state, forcing re-evaluation on the
  /// next filter pass. Delegates to [clearQuickFilterCache].
  void resetQuickFilter() {
    clearQuickFilterCache();
  }

  /// Notify the grid that external filter state has changed.
  ///
  /// Call this when the state driving [OsGrid.isExternalFilterPresent] or
  /// [OsGrid.doesExternalFilterPass] changes. The grid will re-evaluate
  /// all rows against the external filter and emit [onFilterChanged].
  ///
  /// ```dart
  /// // In your external filter bar:
  /// void _onCategoryChanged(String? category) {
  ///   setState(() => _selectedCategory = category);
  ///   gridController.onExternalFilterChanged();
  /// }
  /// ```
  void onExternalFilterChanged() {
    _onExternalFilterChangedRequested?.call();
  }

  /// @internal — Callback set by _OsGridState to handle external filter changes.
  void Function()? _onExternalFilterChangedRequested;

  /// @internal — Used by _OsGridState to register external filter callback.
  set onExternalFilterChangedRequested(void Function()? fn) =>
      _onExternalFilterChangedRequested = fn;

  // --- Value Cache ---

  /// Manually invalidate the value cache.
  ///
  /// When `valueCacheEnabled` is `true` on the grid, this clears all
  /// cached valueGetter results. The cache will be lazily repopulated
  /// on the next access.
  ///
  /// The cache is also automatically invalidated on data changes
  /// (setRowData, applyTransaction, column definition changes), so
  /// manual expiry is only needed when external state that affects
  /// valueGetter results has changed without a data update.
  ///
  /// ```dart
  /// // External lookup table changed — expire cached derived values
  /// controller.expireValueCache();
  /// ```
  void expireValueCache() {
    _onExpireValueCacheRequested?.call();
  }

  /// @internal — Callback set by _OsGridState to handle value cache expiry.
  void Function()? _onExpireValueCacheRequested;

  /// @internal — Used by _OsGridState to register value cache expiry callback.
  set onExpireValueCacheRequested(void Function()? fn) =>
      _onExpireValueCacheRequested = fn;

  // --- Quick Filter Cache ---

  /// Manually invalidate the quick-filter cache.
  ///
  /// When `cacheQuickFilter` is `true` on the grid, this clears the
  /// per-row aggregate/getter text cache so the next quick-filter pass
  /// recomputes every cell text. The cache repopulates lazily.
  ///
  /// The cache is automatically invalidated when the row data source
  /// changes (setRowData, applyTransaction, reprocess-from-controller)
  /// or when hidden columns change, so manual clearing is only needed
  /// when row objects were mutated externally without a data update.
  ///
  /// ```dart
  /// // Rows mutated in place — refresh cached quick-filter texts
  /// controller.clearQuickFilterCache();
  /// controller.setQuickFilter(controller.getQuickFilter());
  /// ```
  void clearQuickFilterCache() => _quickFilter.clearCache();

  /// @internal — Used by _OsGridState to register quick-filter cache clear callback.
  set onClearQuickFilterCacheRequested(void Function()? fn) =>
      _quickFilter.onClearQuickFilterCacheRequested = fn;

  /// @internal — Used by _OsGridState to register quick filter callback.
  set onSetQuickFilterRequested(void Function(String?)? fn) =>
      _quickFilter.onSetQuickFilterRequested = fn;

  /// @internal — Used by _OsGridState to sync the quick filter text from the widget prop.
  set quickFilterText(String? text) => _quickFilter.text = text;

  // --- Range Selection ---

  /// Get all currently active cell ranges.
  ///
  /// Returns an empty list if no ranges are selected.
  List<CellRange> getCellRanges() => List.unmodifiable(_cellRanges);

  /// Add a cell range programmatically.
  ///
  /// The range is defined by start/end row and column indices.
  /// Emits [onRangeSelectionChanged].
  void addCellRange(CellRangeParams params) {
    final range = CellRange(
      startRow: params.rowStartIndex,
      endRow: params.rowEndIndex,
      startColumn: params.columnStartIndex,
      endColumn: params.columnEndIndex,
    );
    _cellRanges.add(range);
    notifyListeners();
    _emitRangeSelectionChanged(finished: true);
  }

  /// Remove all cell ranges (clear the range selection).
  ///
  /// Emits [onRangeSelectionChanged] with an empty ranges list.
  void clearRangeSelection() {
    if (_cellRanges.isEmpty) return;
    _cellRanges.clear();
    notifyListeners();
    _emitRangeSelectionChanged(finished: true);
  }

  // --- Integrated Charts ---

  /// Creates a chart definition from a cell range selection.
  ///
  /// Extracts the data under [range] (or the most recent range selection
  /// when omitted) into an [OsChartDefinition] of [type], emits
  /// [onChartRangeCreated] and fires the [OsGrid.onChartRangeCreated]
  /// widget callback. Render the definition with an [OsChartRenderer]
  /// (see the `os_grid_flutter_charts` companion package for fl_chart and
  /// graphic backends).
  ///
  /// With [transpose], rows become series and column headers become the
  /// category axis. [seriesLayout] controls how multiple series are
  /// arranged (grouped/stacked/normalized). Returns null when there is no
  /// range selection or the range holds no chartable data.
  ///
  /// ```dart
  /// controller.createChartRange(
  ///   type: OsChartType.bar,
  ///   seriesLayout: OsChartSeriesLayout.stacked,
  /// );
  /// ```
  OsChartDefinition? createChartRange({
    OsChartType type = OsChartType.line,
    CellRange? range,
    bool transpose = false,
    OsChartSeriesLayout seriesLayout = OsChartSeriesLayout.grouped,
  }) {
    final handler = _onCreateChartRangeRequested;
    if (handler == null) return null;
    return handler(
      type: type,
      range: range,
      transpose: transpose,
      seriesLayout: seriesLayout,
    );
  }

  /// Emitted when a chart definition is created from a range selection.
  Stream<OsChartRangeCreatedEvent> get onChartRangeCreated =>
      _bus.on<OsChartRangeCreatedEvent>();

  /// Emits [onChartRangeCreated].
  void emitChartRangeCreated(OsChartRangeCreatedEvent event) {
    _bus.emit(event);
  }

  /// @internal — Callback set by _OsGridState to extract chart data from
  /// the displayed model.
  OsChartDefinition? Function({
    required OsChartType type,
    CellRange? range,
    required bool transpose,
    required OsChartSeriesLayout seriesLayout,
  })?
  _onCreateChartRangeRequested;

  /// @internal — Called by _OsGridState during init.
  set onCreateChartRangeRequested(
    OsChartDefinition? Function({
      required OsChartType type,
      CellRange? range,
      required bool transpose,
      required OsChartSeriesLayout seriesLayout,
    })?
    fn,
  ) {
    _onCreateChartRangeRequested = fn;
  }

  // --- Range Selection internal state ---

  final List<CellRange> _cellRanges = [];

  /// @internal — Used by OsGrid widget to set ranges directly.
  set cellRanges(List<CellRange> ranges) {
    _cellRanges.clear();
    _cellRanges.addAll(ranges);
  }

  void _emitRangeSelectionChanged({
    bool started = false,
    bool finished = true,
  }) {
    _bus.emit(
      OsRangeSelectionChangedEvent(
        ranges: List.unmodifiable(_cellRanges),
        started: started,
        finished: finished,
      ),
    );
  }

  // --- Pagination ---

  /// Client-side pagination state and navigation.
  late final PaginationCoordinator _pagination = PaginationCoordinator(
    onStateChanged: notifyListeners,
  );

  /// Get the current page size.
  int paginationGetPageSize() => _pagination.getPageSize();

  /// Get the current page (0-indexed).
  int paginationGetCurrentPage() => _pagination.getCurrentPage();

  /// Get the total number of pages.
  int paginationGetTotalPages() => _pagination.getTotalPages();

  /// Get the total row count (after filtering).
  int paginationGetRowCount() => _pagination.getRowCount();

  /// Get the total number of rows the paginator is paging over.
  ///
  /// Alias for [paginationGetRowCount], mirroring AG Grid's
  /// `paginationGetTotalRows`. The count reflects the rows remaining
  /// AFTER the active filters are applied — it shrinks when filters
  /// exclude rows and grows back when they are cleared — but it is NOT
  /// reduced by pagination itself.
  int paginationGetTotalRows() => paginationGetRowCount();

  /// Navigate to the next page.
  ///
  /// Does nothing if already on the last page.
  void paginationGoToNextPage() => _pagination.goToNextPage();

  /// Navigate to the previous page.
  ///
  /// Does nothing if already on the first page.
  void paginationGoToPreviousPage() => _pagination.goToPreviousPage();

  /// Navigate to the first page.
  void paginationGoToFirstPage() => _pagination.goToFirstPage();

  /// Navigate to the last page.
  void paginationGoToLastPage() => _pagination.goToLastPage();

  /// Navigate to a specific page (0-indexed).
  ///
  /// The page is clamped to valid bounds [0, totalPages - 1].
  void paginationGoToPage(int page) => _pagination.goToPage(page);

  /// Set the page size programmatically.
  ///
  /// Resets to page 0 after changing the page size.
  void paginationSetPageSize(int pageSize) => _pagination.setPageSize(pageSize);

  /// @internal — Used by _OsGridState to sync pagination state to the controller.
  void updatePaginationState({
    required int currentPage,
    required int pageSize,
    required int totalPages,
    required int totalRows,
    bool isPaginated = false,
  }) {
    _pagination.updateState(
      currentPage: currentPage,
      pageSize: pageSize,
      totalPages: totalPages,
      totalRows: totalRows,
    );
    _isPaginated = isPaginated;

    // Shift-range anchor lifecycle: reset when the displayed page changes.
    // Every page transition — pagination bar navigation, programmatic
    // goToPage, page-size reset, and the clamp applied when filters shrink
    // the dataset — ends in a rebuild that re-syncs the page here, making
    // this the single choke point for page-change anchor resets. Sort and
    // filter alone re-sync the same page and therefore never reset it.
    if (_syncedPaginationPage != null && currentPage != _syncedPaginationPage) {
      _lastSelectedId = null;
    }
    _syncedPaginationPage = currentPage;
  }

  /// @internal — Used by _OsGridState to register page change callback.
  set onPageChangeRequested(void Function(int page)? fn) =>
      _pagination.onPageChangeRequested = fn;

  /// @internal — Used by _OsGridState to register page size change callback.
  set onPageSizeChangeRequested(void Function(int pageSize)? fn) =>
      _pagination.onPageSizeChangeRequested = fn;

  // --- Displayed row accessors ---

  /// The number of rows currently displayed after filter + sort, taking
  /// the active pagination slice into account.
  ///
  /// Returns `_pageData` when pagination is active, otherwise
  /// `_processedData` (the full filtered + sorted result).
  ///
  /// ```dart
  /// final count = controller.getDisplayedRowCount();
  /// ```
  int getDisplayedRowCount() =>
      _isPaginated ? _pageData.length : _processedData.length;

  /// Returns the row displayed at [index] (after filter + sort and the
  /// current pagination slice), or `null` when out of range.
  ///
  /// ```dart
  /// final firstRowOnPage = controller.getDisplayedRowAtIndex(0);
  /// ```
  TData? getDisplayedRowAtIndex(int index) {
    final rows = _isPaginated ? _pageData : _processedData;
    if (index < 0 || index >= rows.length) return null;
    return rows[index];
  }

  /// The total number of rows the grid believes exist.
  ///
  /// In infinite row model mode this is the datasource-driven virtual row
  /// count (possibly an estimate until the last row is known). Otherwise
  /// this equals [getDisplayedRowCount].
  int getVirtualRowCount() {
    if (_infiniteModeEnabled) {
      return getInfiniteRowCount() ?? 0;
    }
    return getDisplayedRowCount();
  }

  /// Whether the infinite row model knows the exact total row count.
  ///
  /// Always `false` outside infinite row model mode. Inside it, becomes
  /// `true` once the datasource reports `lastRow` in a success callback.
  bool isLastRowFound() {
    if (!_infiniteModeEnabled) return false;
    return _onIsLastRowKnownRequested?.call() ?? false;
  }

  /// @internal — Callback set by _OsGridState to query block-cache
  /// last-row knowledge.
  bool Function()? _onIsLastRowKnownRequested;

  /// @internal — Used by _OsGridState to register the isLastRowKnown callback.
  set onIsLastRowKnownRequested(bool Function()? fn) =>
      _onIsLastRowKnownRequested = fn;

  // --- Scrolling ---

  /// Notifier used to send scroll commands to the virtualised grid.
  ///
  /// The grid widget listens to this and executes the command, then resets
  /// the value to null. This avoids the need for a GlobalKey or direct
  /// state access.
  final ValueNotifier<ScrollCommand?> scrollCommandNotifier =
      ValueNotifier<ScrollCommand?>(null);

  /// Scroll to make the row at [index] visible.
  ///
  /// [position] controls where the row is placed within the viewport:
  /// - `null` (default): only scrolls if the row is outside the viewport
  ///   (equivalent to 'auto' — brings into view with minimal scroll).
  /// - [RowScrollPosition.top]: aligns the row with the top of the data area.
  /// - [RowScrollPosition.middle]: centres the row vertically.
  /// - [RowScrollPosition.bottom]: aligns the row with the bottom of the data area.
  ///
  /// If [index] is out of bounds, this is a no-op.
  void ensureIndexVisible(int index, {RowScrollPosition? position}) {
    final totalRows = _processedData.isNotEmpty
        ? _processedData.length
        : _rowData.length;
    if (index < 0 || index >= totalRows) return;

    scrollCommandNotifier.value = EnsureIndexVisibleCommand(
      rowIndex: index,
      position: position,
    );
  }

  /// Scroll to make the column with [colId] visible.
  ///
  /// [position] controls where the column is placed within the viewport:
  /// - [ColumnScrollPosition.auto] (default): only scrolls if the column is
  ///   outside the viewport.
  /// - [ColumnScrollPosition.start]: aligns the column's left edge with the
  ///   viewport's left edge.
  /// - [ColumnScrollPosition.middle]: centres the column horizontally.
  /// - [ColumnScrollPosition.end]: aligns the column's right edge with the
  ///   viewport's right edge.
  ///
  /// Pinned columns are always visible, so this is a no-op for them.
  /// If [colId] does not match any displayed column, this is a no-op.
  void ensureColumnVisible(
    String colId, {
    ColumnScrollPosition position = ColumnScrollPosition.auto,
  }) {
    if (_columnDefs == null) return;

    // Resolve colId to a column index in the displayed columns list.
    final displayedCols = getAllDisplayedColumns();
    int? columnIndex;
    for (int i = 0; i < displayedCols.length; i++) {
      if (displayedCols[i].effectiveColId == colId ||
          displayedCols[i].field == colId) {
        columnIndex = i;
        break;
      }
    }
    if (columnIndex == null) return;

    // Check if the column is pinned — pinned columns are always visible.
    final col = displayedCols[columnIndex];
    final pin = _columnPinOverrides[col.effectiveColId] ?? col.pinned;
    if (pin != null) return;

    scrollCommandNotifier.value = EnsureColumnVisibleCommand(
      columnIndex: columnIndex,
      position: position,
    );
  }

  // --- Focus API ---

  /// Notifier used to send focus commands to the virtualised grid.
  ///
  /// The grid widget listens to this and executes the command, then resets
  /// the value to null. This mirrors [scrollCommandNotifier].
  final ValueNotifier<FocusCommand?> focusCommandNotifier =
      ValueNotifier<FocusCommand?>(null);

  /// Returns the currently focused cell, or null when nothing is focused.
  ///
  /// A cell becomes focused through keyboard navigation, clicking a data
  /// cell, or [setFocusedCell]. Nothing is focused before the first such
  /// interaction or after [clearFocusedCell].
  ({int rowIndex, int columnIndex})? getFocusedCell() =>
      _onGetFocusedCellRequested?.call();

  /// Moves the cell focus to the given position and scrolls it into view.
  ///
  /// Out-of-bounds positions are clamped to the grid bounds by the grid.
  void setFocusedCell({required int rowIndex, required int columnIndex}) =>
      _onSetFocusedCellRequested?.call(rowIndex, columnIndex);

  /// Clears the focused cell.
  ///
  /// [getFocusedCell] returns null afterwards and the visual focus ring is
  /// parked until the next focus change. Does not emit `onCellFocused`.
  void clearFocusedCell() => _onClearFocusedCellRequested?.call();

  /// @internal — Callback set by _OsGridState to report the focused cell.
  ({int rowIndex, int columnIndex})? Function()? _onGetFocusedCellRequested;

  /// @internal — Callback set by _OsGridState to apply a focus change.
  void Function(int rowIndex, int columnIndex)? _onSetFocusedCellRequested;

  /// @internal — Callback set by _OsGridState to clear the focused cell.
  void Function()? _onClearFocusedCellRequested;

  /// @internal — Used by _OsGridState to register the get-focused-cell callback.
  set onGetFocusedCellRequested(
    ({int rowIndex, int columnIndex})? Function()? fn,
  ) => _onGetFocusedCellRequested = fn;

  /// @internal — Used by _OsGridState to register the set-focused-cell callback.
  set onSetFocusedCellRequested(void Function(int, int)? fn) =>
      _onSetFocusedCellRequested = fn;

  /// @internal — Used by _OsGridState to register the clear-focused-cell callback.
  set onClearFocusedCellRequested(void Function()? fn) =>
      _onClearFocusedCellRequested = fn;

  // --- Export ---

  /// Export grid data as a CSV string.
  ///
  /// By default, exports the filtered and sorted data (what the user sees),
  /// applies `valueFormatter` for display values, and respects column
  /// visibility. The output includes a UTF-8 BOM and uses `\r\n` line
  /// endings for Excel compatibility.
  ///
  /// ```dart
  /// final csv = controller.exportCsv(
  ///   params: OsCsvExportParams(
  ///     exportedRows: ExportedRows.filteredAndSorted,
  ///     processCellCallback: (params) => params.value?.toString() ?? 'N/A',
  ///   ),
  /// );
  /// ```
  String exportCsv({OsCsvExportParams? params}) {
    final p = params ?? const OsCsvExportParams();

    // Determine columns to export
    final columns = _resolveExportColumns(p);

    // Determine rows to export
    final rows = _resolveExportRows(p);

    // Delegate to the serializer
    final serializer = CsvSerializer<TData>(
      params: p,
      columns: columns,
      rows: rows,
    );

    return serializer.serialize();
  }

  /// Export grid data as an Excel (.xlsx) workbook.
  ///
  /// By default, exports the filtered and sorted data (what the user sees)
  /// and respects column visibility, using the same column/row resolution
  /// as [exportCsv]. Returns the raw workbook bytes.
  ///
  /// Cell types are inferred from the raw value: `num` values are exported
  /// as numeric cells, `bool` values as boolean cells, everything else as
  /// inline-string text. Column widths are taken from the current display
  /// widths.
  ///
  /// ```dart
  /// final bytes = controller.exportXlsx(
  ///   params: OsXlsxExportParams(
  ///     exportedRows: ExportedRows.filteredAndSorted,
  ///     processCellCallback: (params) => params.value?.toString() ?? 'N/A',
  ///   ),
  /// );
  /// ```
  List<int> exportXlsx({OsXlsxExportParams? params}) {
    final p = params ?? const OsXlsxExportParams();

    // Reuse the CSV column/row resolution semantics.
    final resolutionParams = OsCsvExportParams(
      allColumns: p.allColumns,
      columnKeys: p.columnKeys,
      exportedRows: p.exportedRows,
      onlySelected: p.onlySelected,
      shouldRowBeSkipped: p.shouldRowBeSkipped,
    );

    // Determine columns to export
    final columns = _resolveExportColumns(resolutionParams);

    // Determine rows to export
    final rows = _resolveExportRows(resolutionParams);

    // Delegate to the serializer
    final serializer = XlsxSerializer<TData>(
      params: p,
      columns: columns,
      rows: rows,
      columnWidths: _columnWidths,
    );

    return serializer.serialize();
  }

  /// Resolves which columns to include in the export based on params.
  List<OsColumnDef> _resolveExportColumns(OsCsvExportParams params) {
    if (_columnDefs == null) return [];

    // If specific column keys are provided, use those in order
    if (params.columnKeys != null && params.columnKeys!.isNotEmpty) {
      final result = <OsColumnDef>[];
      for (final key in params.columnKeys!) {
        final col = _columnDefs!.cast<OsColumnDef?>().firstWhere(
          (c) => c!.effectiveColId == key || c.field == key,
          orElse: () => null,
        );
        if (col != null) result.add(col);
      }
      return result;
    }

    // If allColumns is true, export all columns in definition/display order
    if (params.allColumns) {
      final orderedColIds =
          _columnOrder ?? _columnDefs!.map((c) => c.effectiveColId).toList();
      return orderedColIds
          .map(
            (id) => _columnDefs!.cast<OsColumnDef?>().firstWhere(
              (c) => c!.effectiveColId == id,
              orElse: () => null,
            ),
          )
          .whereType<OsColumnDef>()
          .toList();
    }

    // Default: only visible columns in display order
    return getAllDisplayedColumns();
  }

  /// Resolves which rows to include in the export based on params.
  List<TData> _resolveExportRows(OsCsvExportParams params) {
    if (params.onlySelected) {
      return getSelectedRows();
    }

    switch (params.exportedRows) {
      case ExportedRows.all:
        return List.unmodifiable(_rowData);
      case ExportedRows.filteredAndSorted:
        // Use processed data if available, otherwise raw data
        return _processedData.isNotEmpty
            ? List.unmodifiable(_processedData)
            : List.unmodifiable(_rowData);
    }
  }

  // Column defs reference (set by OsGrid widget)
  List<OsColumnDef>? _columnDefs;

  /// @internal — Used by OsGrid widget to set column defs for export.
  set columnDefs(List<OsColumnDef>? defs) => _columnDefs = defs;

  // --- Column state (synced from _OsGridState) ---

  /// Column width overrides keyed by colId.
  Map<String, double> _columnWidths = {};

  /// Column pin overrides keyed by colId.
  Map<String, OsColumnPin?> _columnPinOverrides = {};

  /// Set of hidden column IDs.
  Set<String> _hiddenColumnIds = {};

  /// Column display order (list of colIds). Null means original definition order.
  List<String>? _columnOrder;

  /// @internal — Used by _OsGridState to sync column width state.
  set columnWidthState(Map<String, double> widths) => _columnWidths = widths;

  /// @internal — Used by _OsGridState to sync column pin state.
  set columnPinState(Map<String, OsColumnPin?> pins) =>
      _columnPinOverrides = pins;

  /// @internal — Used by _OsGridState to sync hidden column IDs.
  set hiddenColumnIds(Set<String> ids) => _hiddenColumnIds = ids;

  /// @internal — Used by _OsGridState to sync column order.
  set columnOrder(List<String>? order) => _columnOrder = order;

  // --- Column API callbacks (set by _OsGridState) ---

  void Function(List<String> colIds, bool visible)?
  _onSetColumnsVisibleRequested;
  void Function(List<String> colIds, OsColumnPin? pinned)?
  _onSetColumnsPinnedRequested;
  bool Function(ApplyColumnStateParams params)? _onApplyColumnStateRequested;
  void Function()? _onResetColumnStateRequested;
  void Function(List<ColumnWidthEntry> widths, bool finished)?
  _onSetColumnWidthsRequested;
  void Function(Set<String>? colIds, bool skipHeader)?
  _onAutoSizeColumnsRequested;
  void Function(List<OsColumnDefBase> defs)? _onSetColumnDefsRequested;
  void Function()? _onSizeColumnsToFitRequested;
  void Function(int fromIndex, int toIndex)? _onMoveColumnByIndexRequested;
  void Function(List<String> colIds, int toIndex)? _onMoveColumnsRequested;
  OsColumnDef? Function(String colId)? _onGetDisplayedColAfterRequested;
  OsColumnDef? Function(String colId)? _onGetDisplayedColBeforeRequested;

  /// @internal — Used by _OsGridState to register column visibility callback.
  set onSetColumnsVisibleRequested(void Function(List<String>, bool)? fn) =>
      _onSetColumnsVisibleRequested = fn;

  /// @internal — Used by _OsGridState to register column pinning callback.
  set onSetColumnsPinnedRequested(
    void Function(List<String>, OsColumnPin?)? fn,
  ) => _onSetColumnsPinnedRequested = fn;

  /// @internal — Used by _OsGridState to register apply column state callback.
  set onApplyColumnStateRequested(bool Function(ApplyColumnStateParams)? fn) =>
      _onApplyColumnStateRequested = fn;

  /// @internal — Used by _OsGridState to register reset column state callback.
  set onResetColumnStateRequested(void Function()? fn) =>
      _onResetColumnStateRequested = fn;

  /// @internal — Used by _OsGridState to register set column widths callback.
  set onSetColumnWidthsRequested(
    void Function(List<ColumnWidthEntry>, bool)? fn,
  ) => _onSetColumnWidthsRequested = fn;

  /// @internal — Used by the column coordinator to register the auto-size
  /// callback.
  set onAutoSizeColumnsRequested(void Function(Set<String>?, bool)? fn) =>
      _onAutoSizeColumnsRequested = fn;

  /// @internal — Used by _OsGridState to register the set column defs
  /// callback.
  set onSetColumnDefsRequested(void Function(List<OsColumnDefBase>)? fn) =>
      _onSetColumnDefsRequested = fn;

  /// @internal — Used by _OsGridState to register the size-columns-to-fit
  /// callback.
  set onSizeColumnsToFitRequested(void Function()? fn) =>
      _onSizeColumnsToFitRequested = fn;

  /// @internal — Used by _OsGridState to register move column by index callback.
  set onMoveColumnByIndexRequested(void Function(int, int)? fn) =>
      _onMoveColumnByIndexRequested = fn;

  /// @internal — Used by _OsGridState to register move columns callback.
  set onMoveColumnsRequested(void Function(List<String>, int)? fn) =>
      _onMoveColumnsRequested = fn;

  /// @internal — Used by _OsGridState to register displayed-col-after callback.
  set onGetDisplayedColAfterRequested(OsColumnDef? Function(String)? fn) =>
      _onGetDisplayedColAfterRequested = fn;

  /// @internal — Used by _OsGridState to register displayed-col-before callback.
  set onGetDisplayedColBeforeRequested(OsColumnDef? Function(String)? fn) =>
      _onGetDisplayedColBeforeRequested = fn;

  // --- Internal event emission ---

  void _emitSelectionChanged() {
    _syncSelectedFlags();
    _bus.emit(OsSelectionChangedEvent<TData>(selectedRows: getSelectedRows()));
  }

  /// Syncs each node's `selected` flag from the ID-based selection set.
  void _syncSelectedFlags() {
    for (final node in _rawNodes) {
      node.selected = _selectedIds.contains(node.id);
    }
  }

  // --- Internal selection helpers ---

  /// Resolves a row data object to its stable ID.
  String _resolveRowId(TData data) {
    if (_getRowId != null) {
      return _getRowId!(data);
    }
    // Fallback: use object hashCode as string identity
    return data.hashCode.toString();
  }

  /// Checks whether a row is selectable based on the isRowSelectable callback.
  bool _isRowSelectable(TData data) {
    final callback = _rowSelection?.isRowSelectable;
    if (callback == null) return true;
    return callback(data);
  }

  /// Internal helper for scoped selectAll.
  void _selectAllForMode(SelectAllMode mode) {
    final List<TData> source;
    switch (mode) {
      case SelectAllMode.all:
        source = _rowData;
      case SelectAllMode.filtered:
        source = _processedData;
      case SelectAllMode.currentPage:
        source = _pageData;
    }

    for (final row in source) {
      if (_isRowSelectable(row)) {
        _selectedIds.add(_resolveRowId(row));
      }
    }
    notifyListeners();
    _emitSelectionChanged();
  }

  // --- Internal API (used by _OsGridState, not for public use) ---

  /// @internal — Computes the set of display indices that are selected.
  ///
  /// Used by the grid widget to pass to the painter. Converts the ID-based
  /// selection into display indices based on the current processed data.
  Set<int> get selectedIndices {
    if (_selectedIds.isEmpty) return const {};
    final source = _processedData.isNotEmpty ? _processedData : _rowData;
    final indices = <int>{};
    for (int i = 0; i < source.length; i++) {
      if (_selectedIds.contains(_resolveRowId(source[i]))) {
        indices.add(i);
      }
    }
    return indices;
  }

  /// @internal — Used by OsGrid widget to set the getRowId function.
  ///
  /// Rebuilds the node layer since row IDs are derived from this function.
  set getRowId(String Function(TData data)? fn) {
    if (identical(fn, _getRowId)) return;
    _getRowId = fn;
    if (_rowData.isNotEmpty) _rebuildNodesFromRaw();
  }

  /// Resolves the stable row identity for [data] — the configured
  /// [getRowId] when present, otherwise the object's identity hash.
  ///
  /// Exposed so collaborators that record row-keyed state outside the node
  /// layer (undo/redo change records, clipboard change records) key rows by
  /// the same identity selection and transactions use. Identity-hash IDs
  /// are valid for the lifetime of the row object in the current session.
  String rowIdFor(TData data) => _resolveRowId(data);

  /// @internal — Used by OsGrid widget to update processed data reference.
  ///
  /// Refreshes node display state (rowIndex, rendered order, selection
  /// flags) at the cheapest sync point after the pipeline runs.
  set processedData(List<TData> data) {
    _processedData = data;
    _refreshDisplayedNodeState();
  }

  /// @internal — Used by OsGrid widget to update page data reference.
  set pageData(List<TData> data) => _pageData = data;

  /// @internal — Used by OsGrid widget to set row selection config.
  set rowSelection(OsRowSelection? selection) => _rowSelection = selection;

  /// @internal — Used by OsGrid widget to toggle selection by display index.
  ///
  /// Resolves the index to a row ID and toggles its selection state.
  /// Respects `isRowSelectable`.
  void toggleSelection(int index) {
    final source = _processedData.isNotEmpty ? _processedData : _rowData;
    if (index < 0 || index >= source.length) return;

    final row = source[index];
    if (!_isRowSelectable(row)) return;

    final id = _resolveRowId(row);
    if (_selectedIds.contains(id)) {
      _selectedIds.remove(id);
    } else {
      _selectedIds.add(id);
    }
    _lastSelectedId = id;
    notifyListeners();
    _emitSelectionChanged();
  }

  /// @internal — Used by OsGrid widget to set single selection by display index.
  ///
  /// Clears all other selections and selects only the row at [index].
  /// Respects `isRowSelectable`.
  void setSingleSelection(int index) {
    final source = _processedData.isNotEmpty ? _processedData : _rowData;
    if (index < 0 || index >= source.length) return;

    final row = source[index];
    if (!_isRowSelectable(row)) return;

    final id = _resolveRowId(row);
    _selectedIds.clear();
    _selectedIds.add(id);
    _lastSelectedId = id;
    notifyListeners();
    _emitSelectionChanged();
  }

  /// @internal — Used by OsGrid widget for shift+click range selection.
  ///
  /// Selects all rows between the range anchor ([_lastSelectedId], the last
  /// non-shift clicked row) and the row at [index].
  ///
  /// [extend] mirrors the AG Grid modifier matrix:
  /// - `false` (plain Shift+click): the selection is REPLACED with the
  ///   anchor→clicked range — rows selected outside the range are deselected.
  /// - `true` (Ctrl/Cmd+Shift+click): the range is ADDED to the existing
  ///   selection ("extend") — rows outside the range keep their state.
  ///
  /// If no anchor exists, or the anchor row is no longer in the displayed
  /// data, the call falls back to [toggleSelection].
  ///
  /// The anchor is NOT moved by range selection — only non-shift clicks
  /// update it — so repeated shift+clicks keep extending from the same
  /// anchor row.
  void selectRange(int index, {bool extend = false}) {
    final source = _processedData.isNotEmpty ? _processedData : _rowData;
    if (index < 0 || index >= source.length) return;

    final row = source[index];
    if (!_isRowSelectable(row)) return;

    if (_lastSelectedId == null) {
      // No anchor — just select this row
      toggleSelection(index);
      return;
    }

    // Re-find the anchor's index in the current display order. The anchor
    // is stored as a stable row ID (via getRowId), so it resolves to the
    // row's NEW index after sort/filter — persistence across pipeline
    // changes follows from the ID lookup.
    int? anchorIndex;
    for (int i = 0; i < source.length; i++) {
      if (_resolveRowId(source[i]) == _lastSelectedId) {
        anchorIndex = i;
        break;
      }
    }

    if (anchorIndex == null) {
      // Anchor row no longer displayed (filtered out / removed) — just
      // select this row
      toggleSelection(index);
      return;
    }

    // Select all rows in the range [anchorIndex, index] inclusive
    final start = anchorIndex < index ? anchorIndex : index;
    final end = anchorIndex < index ? index : anchorIndex;

    // Plain Shift+click replaces the selection with the range; the
    // Ctrl/Cmd+Shift extension preserves rows selected outside the range.
    if (!extend) _selectedIds.clear();

    for (int i = start; i <= end; i++) {
      final rangeRow = source[i];
      if (_isRowSelectable(rangeRow)) {
        _selectedIds.add(_resolveRowId(rangeRow));
      }
    }

    notifyListeners();
    _emitSelectionChanged();
  }

  /// @internal — Used by OsGrid widget to emit grid ready.
  void emitGridReady() {
    _bus.emit(const OsGridReadyEvent());
  }

  /// @internal — Used by OsGrid widget to emit cell clicked.
  void emitCellClicked(OsCellClickedEvent<TData> event) {
    _bus.emit(event);
  }

  /// @internal — Used by OsGrid widget to emit row double clicked.
  void emitRowDoubleClicked(OsRowDoubleClickedEvent<TData> event) {
    _bus.emit(event);
  }

  /// @internal — Used by OsGrid widget to emit row clicked.
  void emitRowClicked(OsRowClickedEvent<TData> event) {
    _bus.emit(event);
  }

  /// @internal — Used by OsGrid widget to emit sort changed.
  void emitSortChanged(OsSortChangedEvent event) {
    _bus.emit(event);
  }

  /// @internal — Used by OsGrid widget to emit filter changed.
  void emitFilterChanged(OsFilterChangedEvent event) {
    _bus.emit(event);
  }

  /// @internal — Used by OsGrid widget to emit cell value changed.
  void emitCellValueChanged(OsCellValueChangedEvent<TData> event) {
    _bus.emit(event);
  }

  /// @internal — Used by OsGrid widget to emit pagination changed.
  void emitPaginationChanged(OsPaginationChangedEvent event) {
    _bus.emit(event);
  }

  /// @internal — Used by OsGrid widget to emit range selection changed.
  void emitRangeSelectionChanged(OsRangeSelectionChangedEvent event) {
    _bus.emit(event);
  }

  /// @internal — Used by OsGrid widget to emit cell focused event.
  void emitCellFocused(OsCellFocusedEvent event) {
    _bus.emit(event);
  }

  /// @internal — Used by OsGrid widget to emit cell key down event.
  void emitCellKeyDown(OsCellKeyDownEvent event) {
    _bus.emit(event);
  }

  /// @internal — Used by _OsGridState to emit first data rendered.
  /// Only adds to the stream; never notifies grid listeners synchronously.
  void emitFirstDataRendered(OsFirstDataRenderedEvent event) {
    _bus.emit(event);
  }

  /// @internal — Used by _OsGridState to emit grid size changed.
  void emitGridSizeChanged(OsGridSizeChangedEvent event) {
    _bus.emit(event);
  }

  /// @internal — Used by _OsGridState to emit model updated. Only adds to
  /// the stream (no [notifyListeners]) to prevent rebuild feedback loops.
  void emitModelUpdated(OsModelUpdatedEvent event) {
    _bus.emit(event);
  }

  /// @internal — Used by _OsGridState to emit row data changed before the
  /// pipeline runs. Only adds to the stream (no [notifyListeners]).
  void emitRowDataChanged(OsRowDataChangedEvent<TData> event) {
    _bus.emit(event);
  }

  /// @internal — Used by OsGrid widget to emit column visible event.
  void emitColumnVisible(OsColumnVisibleEvent event) {
    _bus.emit(event);
  }

  /// @internal — Used by OsGrid widget to emit column pinned event.
  void emitColumnPinned(OsColumnPinnedEvent event) {
    _bus.emit(event);
  }

  /// @internal — Used by OsGrid widget to emit column resized event.
  void emitColumnResized(OsColumnResizedEvent event) {
    _bus.emit(event);
  }

  /// @internal — Used by OsGrid widget to emit column moved event.
  void emitColumnMoved(OsColumnMovedEvent event) {
    _bus.emit(event);
  }

  /// @internal — Used by OsGrid widget to emit cell editing started event.
  void emitCellEditingStarted(OsCellEditingStartedEvent<TData> event) {
    _isEditing = true;
    _bus.emit(event);
  }

  /// @internal — Used by OsGrid widget to emit cell editing stopped event.
  void emitCellEditingStopped(OsCellEditingStoppedEvent<TData> event) {
    _isEditing = false;
    _bus.emit(event);
  }

  /// @internal — Used by OsGrid widget to emit cell edit request event.
  void emitCellEditRequest(OsCellEditRequestEvent<TData> event) {
    _bus.emit(event);
  }

  /// @internal — Used by OsGrid widget to emit row drag enter event.
  void emitRowDragEnter(OsRowDragEnterEvent<TData> event) {
    _bus.emit(event);
  }

  /// @internal — Used by OsGrid widget to emit row drag move event.
  void emitRowDragMove(OsRowDragMoveEvent<TData> event) {
    _bus.emit(event);
  }

  /// @internal — Used by OsGrid widget to emit row drag end event.
  void emitRowDragEnd(OsRowDragEndEvent<TData> event) {
    _bus.emit(event);
  }

  /// @internal — Used by OsGrid widget to emit row drag leave event.
  void emitRowDragLeave(OsRowDragLeaveEvent<TData> event) {
    _bus.emit(event);
  }

  // --- Grid State ---

  // --- Locale ---

  /// The locale text instance used for resolving translated strings.
  ///
  /// Set by the OsGrid widget from its [OsGrid.localeText] property.
  /// Falls back to [OsLocaleText.defaultLocale] when not set.
  OsLocaleText _localeText = OsLocaleText.defaultLocale;

  /// Optional dynamic locale callback.
  ///
  /// Set by the OsGrid widget from its [OsGrid.getLocaleText] property.
  String Function(String key, String defaultValue)? _getLocaleTextCallback;

  /// @internal — Used by OsGrid widget to set the locale text.
  set localeText(OsLocaleText? locale) {
    _localeText = locale ?? OsLocaleText.defaultLocale;
  }

  /// @internal — Used by OsGrid widget to set the getLocaleText callback.
  set getLocaleTextCallback(
    String Function(String key, String defaultValue)? fn,
  ) => _getLocaleTextCallback = fn;

  /// Resolves a locale key to its translated value.
  ///
  /// Resolution order:
  /// 1. If [OsGrid.getLocaleText] callback is set, call it with the key
  ///    and the value from [localeText] (or English default).
  /// 2. Otherwise, return the value from [localeText] (or English default).
  ///
  /// This is the primary method for grid components to obtain translated text.
  ///
  /// ```dart
  /// final label = controller.getLocaleText('noRowsToShow', 'No Rows To Show');
  /// ```
  String getLocaleText(String key, String defaultValue) {
    final localeValue = _localeText.getLocaleText(key, defaultValue);
    if (_getLocaleTextCallback != null) {
      return _getLocaleTextCallback!(key, localeValue);
    }
    return localeValue;
  }

  // --- Grid State (continued) ---

  /// Grid-state persistence wiring ([getState] / [setState]).
  final StatePersistenceCoordinator _statePersistence =
      StatePersistenceCoordinator();

  /// Emitted when the grid state changes (debounced).
  ///
  /// The event includes the full state snapshot and a list of which
  /// properties triggered the update.
  Stream<OsStateUpdatedEvent> get onStateUpdated =>
      _bus.on<OsStateUpdatedEvent>();

  /// Get a snapshot of the current grid state.
  ///
  /// The returned [OsGridState] captures sort, filter, column state,
  /// pagination, selection, cell ranges, and scroll position.
  ///
  /// ```dart
  /// final state = controller.getState();
  /// // Serialise for persistence
  /// final json = state.toJson();
  /// ```
  OsGridState getState() => _statePersistence.getState();

  /// Restore a previously saved grid state.
  ///
  /// Only the non-null properties in [state] are applied. Properties
  /// listed in [propertiesToIgnore] are skipped.
  ///
  /// Events are suppressed during restoration to avoid feedback loops.
  ///
  /// ```dart
  /// // Restore full state
  /// controller.setState(savedState);
  ///
  /// // Restore only sort and filter, ignore the rest
  /// controller.setState(
  ///   savedState,
  ///   propertiesToIgnore: ['pagination', 'scroll'],
  /// );
  /// ```
  void setState(OsGridState state, {List<String>? propertiesToIgnore}) =>
      _statePersistence.setState(state, propertiesToIgnore: propertiesToIgnore);

  /// @internal — Used by _OsGridState to register getState callback.
  set onGetStateRequested(OsGridState Function()? fn) =>
      _statePersistence.onGetStateRequested = fn;

  /// @internal — Used by _OsGridState to register setState callback.
  set onSetStateRequested(void Function(OsGridState, List<String>?)? fn) =>
      _statePersistence.onSetStateRequested = fn;

  /// @internal — Used by GridStateService to emit state updated event.
  void emitStateUpdated(OsStateUpdatedEvent event) {
    _bus.emit(event);
  }

  // --- External drag and drop ---

  /// @internal — Used by _OsGridState to emit row drag out event.
  void emitRowDragOut(OsRowDragOutEvent<TData> event) {
    _bus.emit(event);
  }

  /// @internal — Used by _OsGridState to emit external drop event.
  void emitExternalDrop(OsExternalDropEvent event) {
    _bus.emit(event);
  }

  // --- Overlay ---

  /// Explicit overlay requested via [showLoadingOverlay] /
  /// [showNoRowsOverlay], or `null` when no explicit request is active.
  OsGridOverlay? _overlayOverride;

  /// The current explicit overlay override.
  ///
  /// `null` means the grid resolves its overlay automatically (from the
  /// [OsGrid.loading] parameter and heuristics). A non-null value takes
  /// precedence over every automatic source and persists until
  /// [hideOverlay] is called — even across rowData changes — mirroring
  /// AG Grid, which keeps manual overlays up until `hideOverlay`.
  OsGridOverlay? get overlayOverride => _overlayOverride;

  /// Show the loading overlay over the grid body.
  ///
  /// The override wins over the [OsGrid.loading] parameter, the infinite
  /// cache auto-loading heuristic and the no-rows heuristic. It stays
  /// visible until [hideOverlay] is called; setting new rowData does NOT
  /// clear it automatically (AG Grid parity).
  ///
  /// ```dart
  /// controller.showLoadingOverlay();
  /// final data = await api.fetchRows();
  /// controller.hideOverlay();
  /// ```
  void showLoadingOverlay() => _setOverlayOverride(OsGridOverlay.loading);

  /// Show the no-rows overlay over the grid body, regardless of how many
  /// rows are currently displayed.
  ///
  /// Same precedence and persistence rules as [showLoadingOverlay].
  void showNoRowsOverlay() => _setOverlayOverride(OsGridOverlay.noRows);

  /// Hide any explicitly requested overlay and return to automatic
  /// overlay resolution ([OsGrid.loading] parameter + heuristics).
  ///
  /// No-op when no explicit overlay is active. Note that after hiding,
  /// automatic sources apply again — e.g. an in-flight infinite-cache
  /// fetch may immediately re-show the loading overlay.
  void hideOverlay() {
    if (_overlayOverride == null) return;
    _overlayOverride = null;
    notifyListeners();
  }

  void _setOverlayOverride(OsGridOverlay overlay) {
    if (_overlayOverride == overlay) return;
    _overlayOverride = overlay;
    notifyListeners();
  }

  // --- Infinite Row Model ---

  /// Emitted when the infinite row model's virtual row count changes.
  ///
  /// Only fires when the grid is using the infinite row model
  /// (i.e. [OsGrid.infiniteRowModel] is set).
  Stream<OsInfiniteRowCountChangedEvent> get onInfiniteRowCountChanged =>
      _bus.on<OsInfiniteRowCountChangedEvent>();

  /// @internal — Used by _OsGridState to emit row count changed event.
  void emitInfiniteRowCountChanged(OsInfiniteRowCountChangedEvent event) {
    _bus.emit(event);
  }

  /// Refresh the infinite cache: re-fetch all loaded blocks.
  ///
  /// Use this after a server-side data mutation to get fresh data.
  /// The grid keeps its current scroll position and re-requests all
  /// blocks that were previously loaded.
  ///
  /// No-op if the grid is not using the infinite row model.
  ///
  /// ```dart
  /// // After updating data on the server
  /// await api.updateRecord(id, newData);
  /// controller.refreshInfiniteCache();
  /// ```
  void refreshInfiniteCache() {
    _onRefreshInfiniteCacheRequested?.call();
  }

  /// Purge the infinite cache: discard all blocks and reset.
  ///
  /// The virtual row count resets to [OsInfiniteRowModel.infiniteInitialRowCount]
  /// and the grid will re-request blocks as the user scrolls. Use this when
  /// the server-side dataset has fundamentally changed (e.g. different query).
  ///
  /// No-op if the grid is not using the infinite row model.
  ///
  /// ```dart
  /// // Dataset has changed completely
  /// controller.purgeInfiniteCache();
  /// ```
  void purgeInfiniteCache() {
    _onPurgeInfiniteCacheRequested?.call();
  }

  /// Get the current virtual row count from the infinite cache.
  ///
  /// Returns the number of rows the grid believes exist. This may be
  /// an estimate until the datasource reports the exact count via
  /// the `lastRow` parameter in the success callback.
  ///
  /// Returns `null` if the grid is not using the infinite row model.
  int? getInfiniteRowCount() {
    return _onGetInfiniteRowCountRequested?.call();
  }

  /// Whether any block of the infinite row model cache is currently being
  /// fetched from the datasource.
  ///
  /// True between a block request being dispatched and its success/failure
  /// callback arriving — including blocks re-requested after
  /// [refreshInfiniteCache] or [purgeInfiniteCache]. Use this to surface
  /// cache refreshes that would otherwise swap rows in silently.
  ///
  /// Returns `false` when the grid is not using the infinite row model.
  bool get isInfiniteCacheLoading =>
      _onIsInfiniteCacheLoadingRequested?.call() ?? false;

  /// @internal — Callback set by _OsGridState to probe the block cache.
  bool Function()? _onIsInfiniteCacheLoadingRequested;

  /// Change the datasource at runtime.
  ///
  /// The current cache is purged and the grid starts fetching from the
  /// new datasource. This is equivalent to setting a new datasource
  /// on the widget.
  ///
  /// No-op if the grid is not using the infinite row model.
  void setDatasource(dynamic datasource) {
    _onSetDatasourceRequested?.call(datasource);
  }

  /// @internal — Callback set by _OsGridState to handle refreshInfiniteCache.
  void Function()? _onRefreshInfiniteCacheRequested;

  /// @internal — Callback set by _OsGridState to handle purgeInfiniteCache.
  void Function()? _onPurgeInfiniteCacheRequested;

  /// @internal — Callback set by _OsGridState to handle getInfiniteRowCount.
  int? Function()? _onGetInfiniteRowCountRequested;

  /// @internal — Callback set by _OsGridState to handle setDatasource.
  void Function(dynamic datasource)? _onSetDatasourceRequested;

  /// @internal — Used by _OsGridState to register refreshInfiniteCache callback.
  set onRefreshInfiniteCacheRequested(void Function()? fn) =>
      _onRefreshInfiniteCacheRequested = fn;

  /// @internal — Used by _OsGridState to register purgeInfiniteCache callback.
  set onPurgeInfiniteCacheRequested(void Function()? fn) =>
      _onPurgeInfiniteCacheRequested = fn;

  /// @internal — Used by _OsGridState to register getInfiniteRowCount callback.
  set onGetInfiniteRowCountRequested(int? Function()? fn) =>
      _onGetInfiniteRowCountRequested = fn;

  /// @internal — Used by _OsGridState to register the cache-loading probe.
  set onIsInfiniteCacheLoadingRequested(bool Function()? fn) =>
      _onIsInfiniteCacheLoadingRequested = fn;

  /// @internal — Synced by _OsGridState so [getVirtualRowCount] and
  /// [isLastRowFound] know whether the infinite row model is active.
  set infiniteModeEnabled(bool value) => _infiniteModeEnabled = value;

  /// @internal — Used by _OsGridState to register setDatasource callback.
  set onSetDatasourceRequested(void Function(dynamic)? fn) =>
      _onSetDatasourceRequested = fn;

  // --- Server-Side Row Model ---

  /// Refresh the server-side row model cache.
  ///
  /// With [groupKeys] set, discards the cached blocks for that group level
  /// and all deeper levels; the level is re-requested as it becomes
  /// visible again. Without [groupKeys], all levels are discarded.
  ///
  /// Failed block requests are also retried by this call.
  ///
  /// No-op if the grid is not using the server-side row model.
  ///
  /// ```dart
  /// // After a server-side mutation under group ['Europe', 'UK']
  /// controller.refreshServerSide(groupKeys: ['Europe', 'UK']);
  /// ```
  void refreshServerSide({List<String>? groupKeys}) {
    _onRefreshServerSideRequested?.call(groupKeys);
  }

  /// Get the current virtual row count for a server-side level.
  ///
  /// [groupKeys] identifies the level (the root level when omitted). The
  /// count is server-reported (via the `lastRow` parameter or a short
  /// block) once loaded, and an estimate before that.
  ///
  /// Returns `null` if the grid is not using the server-side row model.
  int? getServerSideRowCount([List<String>? groupKeys]) {
    return _onGetServerSideRowCountRequested?.call(groupKeys);
  }

  /// @internal — Callback set by _OsGridState to handle refreshServerSide.
  void Function(List<String>? groupKeys)? _onRefreshServerSideRequested;

  /// @internal — Callback set by _OsGridState to handle getServerSideRowCount.
  int? Function(List<String>? groupKeys)? _onGetServerSideRowCountRequested;

  /// @internal — Used by _OsGridState to register refreshServerSide callback.
  set onRefreshServerSideRequested(void Function(List<String>?)? fn) =>
      _onRefreshServerSideRequested = fn;

  /// @internal — Used by _OsGridState to register getServerSideRowCount callback.
  set onGetServerSideRowCountRequested(int? Function(List<String>?)? fn) =>
      _onGetServerSideRowCountRequested = fn;

  // --- Expand / Collapse (Tree Data & Row Grouping) ---

  /// Emitted when [expandAll] or [collapseAll] is called.
  ///
  /// Fires regardless of whether any rows actually changed state. When tree
  /// data or row grouping is not configured, the event still fires but no
  /// rows are affected.
  Stream<OsExpandOrCollapseAllEvent> get onExpandOrCollapseAll =>
      _bus.on<OsExpandOrCollapseAllEvent>();

  /// Emitted when a single group row is expanded or collapsed.
  Stream<OsRowGroupOpenedEvent> get onRowGroupOpened =>
      _bus.on<OsRowGroupOpenedEvent>();

  /// Expand all row groups and tree nodes.
  ///
  /// When row grouping is configured, this expands every collapsible
  /// group in the grid. When not configured, this is a no-op.
  ///
  /// ```dart
  /// controller.expandAll();
  /// ```
  void expandAll() {
    if (_onExpandAllRequested != null) {
      _onExpandAllRequested!();
    } else {
      debugPrint(
        '[OS Grid] expandAll called but no row grouping is configured.',
      );
    }
    const event = OsExpandOrCollapseAllEvent(source: 'api', expandedAll: true);
    _onExpandOrCollapseAllCallback?.call(event);
    _bus.emit(event);
  }

  /// Collapse all row groups and tree nodes.
  ///
  /// When row grouping is configured, this collapses every collapsible
  /// group in the grid. When not configured, this is a no-op.
  ///
  /// ```dart
  /// controller.collapseAll();
  /// ```
  void collapseAll() {
    if (_onCollapseAllRequested != null) {
      _onCollapseAllRequested!();
    } else {
      debugPrint(
        '[OS Grid] collapseAll called but no row grouping is configured.',
      );
    }
    const event = OsExpandOrCollapseAllEvent(source: 'api', expandedAll: false);
    _onExpandOrCollapseAllCallback?.call(event);
    _bus.emit(event);
  }

  /// @internal — Widget callback for expand/collapse all events.
  ValueChanged<OsExpandOrCollapseAllEvent>? _onExpandOrCollapseAllCallback;

  /// @internal — Used by _OsGridState to register the widget callback.
  set onExpandOrCollapseAllCallback(
    ValueChanged<OsExpandOrCollapseAllEvent>? fn,
  ) => _onExpandOrCollapseAllCallback = fn;

  /// @internal — Callback set by _OsGridState to handle expandAll.
  void Function()? _onExpandAllRequested;

  /// @internal — Callback set by _OsGridState to handle collapseAll.
  void Function()? _onCollapseAllRequested;

  /// @internal — Callback set by _OsGridState to handle setRowExpanded.
  void Function(String nodeId, bool expanded)? _onSetRowExpandedRequested;

  /// @internal — Callback set by _OsGridState to check isRowExpanded.
  bool Function(String nodeId)? _isRowExpandedCallback;

  /// @internal — Used by _OsGridState to register expand all callback.
  set onExpandAllRequested(void Function()? fn) => _onExpandAllRequested = fn;

  /// @internal — Used by _OsGridState to register collapse all callback.
  set onCollapseAllRequested(void Function()? fn) =>
      _onCollapseAllRequested = fn;

  /// @internal — Used by _OsGridState to register setRowExpanded callback.
  set onSetRowExpandedRequested(void Function(String, bool)? fn) =>
      _onSetRowExpandedRequested = fn;

  /// @internal — Used by _OsGridState to register isRowExpanded callback.
  set isRowExpandedCallback(bool Function(String)? fn) =>
      _isRowExpandedCallback = fn;

  /// Returns whether a specific row group or tree node is expanded.
  ///
  /// ```dart
  /// final expanded = controller.isRowExpanded('row-group-country-UK');
  /// ```
  bool isRowExpanded(String nodeId) {
    return _isRowExpandedCallback?.call(nodeId) ?? false;
  }

  /// Expand or collapse a specific group row by its node ID.
  ///
  /// ```dart
  /// controller.setRowExpanded('row-group-country-UK', true);
  /// ```
  void setRowExpanded(String nodeId, {required bool expanded}) {
    _onSetRowExpandedRequested?.call(nodeId, expanded);
  }

  // --- Master / Detail ---

  /// Expands the detail area of the master row at [rowIndex].
  ///
  /// [rowIndex] is the current display index of the master row (detail
  /// rows inserted for other masters shift indices below them). No-op when
  /// the row is not a master row or master/detail is not configured.
  ///
  /// ```dart
  /// controller.expandDetailRow(0);
  /// ```
  void expandDetailRow(int rowIndex) =>
      _onExpandDetailRowRequested?.call(rowIndex);

  /// Collapses the detail area of the master row at [rowIndex].
  ///
  /// [rowIndex] is the current display index of the master row. No-op when
  /// the row is not a master row or master/detail is not configured.
  ///
  /// ```dart
  /// controller.collapseDetailRow(0);
  /// ```
  void collapseDetailRow(int rowIndex) =>
      _onCollapseDetailRowRequested?.call(rowIndex);

  /// Returns whether the master row at [rowIndex] currently has its detail
  /// area expanded. Returns `false` for non-master rows, out-of-range
  /// indices, or when master/detail is not configured.
  ///
  /// ```dart
  /// final open = controller.isDetailRowExpanded(0);
  /// ```
  bool isDetailRowExpanded(int rowIndex) =>
      _isDetailRowExpandedCallback?.call(rowIndex) ?? false;

  /// @internal — Callback set by _OsGridState to handle expandDetailRow.
  void Function(int rowIndex)? _onExpandDetailRowRequested;

  /// @internal — Callback set by _OsGridState to handle collapseDetailRow.
  void Function(int rowIndex)? _onCollapseDetailRowRequested;

  /// @internal — Callback set by _OsGridState to handle isDetailRowExpanded.
  bool Function(int rowIndex)? _isDetailRowExpandedCallback;

  /// @internal — Used by _OsGridState to register expandDetailRow callback.
  set onExpandDetailRowRequested(void Function(int rowIndex)? fn) =>
      _onExpandDetailRowRequested = fn;

  /// @internal — Used by _OsGridState to register collapseDetailRow callback.
  set onCollapseDetailRowRequested(void Function(int rowIndex)? fn) =>
      _onCollapseDetailRowRequested = fn;

  /// @internal — Used by _OsGridState to register isDetailRowExpanded callback.
  set isDetailRowExpandedCallback(bool Function(int rowIndex)? fn) =>
      _isDetailRowExpandedCallback = fn;

  /// Set which columns are used for row grouping.
  ///
  /// Pass an empty list to remove grouping. The column IDs must match
  /// `OsColumnDef.effectiveColId` values in the current column definitions.
  ///
  /// ```dart
  /// controller.setRowGroupColumns(['country', 'city']);
  /// ```
  void setRowGroupColumns(List<String> colIds) {
    _onSetRowGroupColumnsRequested?.call(colIds);
  }

  /// Add a column to the row group columns list.
  void addRowGroupColumn(String colId, [int? index]) {
    final cols = getRowGroupColumns().toList();
    if (cols.contains(colId)) return;

    if (index != null && index >= 0 && index <= cols.length) {
      cols.insert(index, colId);
      _onSetRowGroupColumnsRequested?.call(cols);
    } else {
      _onSetRowGroupColumnsRequested?.call([...cols, colId]);
    }
  }

  /// Remove a column from the row group columns list.
  void removeRowGroupColumn(String colId) {
    final cols = getRowGroupColumns();
    if (!cols.contains(colId)) return;
    _onSetRowGroupColumnsRequested?.call(
      cols.where((id) => id != colId).toList(),
    );
  }

  /// Move a row group column from one index to another.
  void moveRowGroupColumn(int fromIndex, int toIndex) {
    final cols = getRowGroupColumns().toList();
    if (fromIndex < 0 ||
        fromIndex >= cols.length ||
        toIndex < 0 ||
        toIndex > cols.length) {
      return;
    }
    final col = cols.removeAt(fromIndex);
    if (toIndex > cols.length) toIndex = cols.length;
    cols.insert(toIndex, col);
    _onSetRowGroupColumnsRequested?.call(cols);
  }

  /// @internal — Callback set by _OsGridState to handle setRowGroupColumns.
  void Function(List<String>)? _onSetRowGroupColumnsRequested;

  /// @internal — Used by _OsGridState to register setRowGroupColumns callback.
  set onSetRowGroupColumnsRequested(void Function(List<String>)? fn) =>
      _onSetRowGroupColumnsRequested = fn;

  /// Get the current list of column IDs used for row grouping.
  ///
  /// Returns an empty list if no grouping is active.
  List<String> getRowGroupColumns() {
    return _getRowGroupColumnsCallback?.call() ?? [];
  }

  /// @internal — Callback set by _OsGridState.
  List<String> Function()? _getRowGroupColumnsCallback;

  /// @internal — Used by _OsGridState to register getRowGroupColumns callback.
  set getRowGroupColumnsCallback(List<String> Function()? fn) =>
      _getRowGroupColumnsCallback = fn;

  /// @internal — Emit a row group opened event.
  void emitRowGroupOpened(OsRowGroupOpenedEvent event) {
    _bus.emit(event);
  }

  // --- Aggregation ---

  /// Set which columns are used as value columns (aggregation).
  ///
  /// Value columns compute aggregate values (sum, avg, count, etc.) for
  /// group rows. The aggFunc for each column is taken from [OsColumnDef.aggFunc].
  ///
  /// ```dart
  /// controller.setValueColumns(['sales', 'profit']);
  /// ```
  void setValueColumns(List<String> colIds) {
    _onSetValueColumnsRequested?.call(colIds);
  }

  /// @internal — Callback set by _OsGridState to handle setValueColumns.
  void Function(List<String>)? _onSetValueColumnsRequested;

  /// @internal — Used by _OsGridState to register setValueColumns callback.
  set onSetValueColumnsRequested(void Function(List<String>)? fn) =>
      _onSetValueColumnsRequested = fn;

  /// Get the current list of value column IDs (columns with aggregation).
  ///
  /// Returns column IDs that have an aggFunc configured (either via
  /// [OsColumnDef.aggFunc] or programmatically via [setValueColumns]).
  List<String> getValueColumns() {
    return _getValueColumnsCallback?.call() ?? [];
  }

  /// @internal — Callback set by _OsGridState.
  List<String> Function()? _getValueColumnsCallback;

  /// @internal — Used by _OsGridState to register getValueColumns callback.
  set getValueColumnsCallback(List<String> Function()? fn) =>
      _getValueColumnsCallback = fn;

  /// Set the aggregation function for a specific column.
  ///
  /// [colId] — the column identifier.
  /// [aggFunc] — the aggregation function name ('sum', 'avg', 'count',
  /// 'min', 'max', 'first', 'last') or `null` to clear.
  ///
  /// Note: This only takes effect if the column is already a value column
  /// (via [OsColumnDef.aggFunc] or [setValueColumns]).
  ///
  /// ```dart
  /// controller.setColumnAggFunc('sales', 'avg');
  /// ```
  void setColumnAggFunc(String colId, String? aggFunc) {
    _onSetColumnAggFuncRequested?.call(colId, aggFunc);
  }

  /// @internal — Callback set by _OsGridState to handle setColumnAggFunc.
  void Function(String, String?)? _onSetColumnAggFuncRequested;

  /// @internal — Used by _OsGridState to register setColumnAggFunc callback.
  set onSetColumnAggFuncRequested(void Function(String, String?)? fn) =>
      _onSetColumnAggFuncRequested = fn;

  // --- Pivot Mode ---

  /// Emitted when pivot mode is toggled on or off.
  Stream<OsPivotModeChangedEvent> get onPivotModeChanged =>
      _bus.on<OsPivotModeChangedEvent>();

  /// Enable or disable pivot mode.
  ///
  /// When pivot mode is active, the grid generates dynamic columns from
  /// the unique values of pivot columns and displays aggregated data at
  /// the intersection of row groups and pivot values.
  ///
  /// ```dart
  /// controller.setPivotMode(true);
  /// ```
  void setPivotMode(bool enabled) {
    _onSetPivotModeRequested?.call(enabled);
  }

  /// @internal — Callback set by _OsGridState to handle setPivotMode.
  void Function(bool)? _onSetPivotModeRequested;

  /// @internal — Used by _OsGridState to register setPivotMode callback.
  set onSetPivotModeRequested(void Function(bool)? fn) =>
      _onSetPivotModeRequested = fn;

  /// Returns whether pivot mode is currently active.
  bool isPivotMode() {
    return _isPivotModeCallback?.call() ?? false;
  }

  /// @internal — Callback set by _OsGridState.
  bool Function()? _isPivotModeCallback;

  /// @internal — Used by _OsGridState to register isPivotMode callback.
  set isPivotModeCallback(bool Function()? fn) => _isPivotModeCallback = fn;

  /// Set which columns are used as pivot columns.
  ///
  /// Pivot columns define the dynamic column headers generated from
  /// unique values. Only effective when pivot mode is active.
  ///
  /// ```dart
  /// controller.setPivotColumns(['year', 'quarter']);
  /// ```
  void setPivotColumns(List<String> colIds) {
    _onSetPivotColumnsRequested?.call(colIds);
  }

  /// @internal — Callback set by _OsGridState to handle setPivotColumns.
  void Function(List<String>)? _onSetPivotColumnsRequested;

  /// @internal — Used by _OsGridState to register setPivotColumns callback.
  set onSetPivotColumnsRequested(void Function(List<String>)? fn) =>
      _onSetPivotColumnsRequested = fn;

  /// Get the current list of column IDs used as pivot columns.
  ///
  /// Returns an empty list if no pivot columns are configured or
  /// pivot mode is not active.
  List<String> getPivotColumns() {
    return _getPivotColumnsCallback?.call() ?? [];
  }

  /// @internal — Callback set by _OsGridState.
  List<String> Function()? _getPivotColumnsCallback;

  /// @internal — Used by _OsGridState to register getPivotColumns callback.
  set getPivotColumnsCallback(List<String> Function()? fn) =>
      _getPivotColumnsCallback = fn;

  /// Get the column IDs of the dynamically generated pivot result columns.
  ///
  /// These are the columns created from unique pivot values crossed with
  /// value columns. Returns an empty list if pivot mode is not active
  /// or no pivot columns are generated.
  List<String> getPivotResultColumns() {
    return _getPivotResultColumnsCallback?.call() ?? [];
  }

  /// @internal — Callback set by _OsGridState.
  List<String> Function()? _getPivotResultColumnsCallback;

  /// @internal — Used by _OsGridState to register getPivotResultColumns callback.
  set getPivotResultColumnsCallback(List<String> Function()? fn) =>
      _getPivotResultColumnsCallback = fn;

  /// @internal — Emit a pivot mode changed event.
  void emitPivotModeChanged(OsPivotModeChangedEvent event) {
    _bus.emit(event);
  }

  // Legacy stubs preserved for backward compatibility.
  /// @deprecated Use [isRowExpanded] instead.
  bool isRowGroupExpanded(String rowId) => isRowExpanded(rowId);

  /// @deprecated Use [setRowExpanded] instead.
  void setRowNodeExpanded(String rowId, bool expanded) {
    setRowExpanded(rowId, expanded: expanded);
  }

  // --- Clipboard ---

  /// Copy the current selection to the clipboard.
  ///
  /// Copies cell range selection if active, otherwise selected rows,
  /// otherwise the focused cell value.
  ///
  /// ```dart
  /// controller.copyToClipboard();
  /// ```
  void copyToClipboard() {
    _onCopyToClipboardRequested?.call();
  }

  /// Paste clipboard content at the current focused cell.
  ///
  /// Parses TSV format and fills cells starting from the focused cell.
  /// Respects `editable` — skips non-editable cells.
  ///
  /// ```dart
  /// controller.pasteFromClipboard();
  /// ```
  void pasteFromClipboard() {
    _onPasteFromClipboardRequested?.call();
  }

  /// Cut the current selection to the clipboard.
  ///
  /// Same as copy, but also clears editable cells in the selection.
  ///
  /// ```dart
  /// controller.cutToClipboard();
  /// ```
  void cutToClipboard() {
    _onCutToClipboardRequested?.call();
  }

  /// @internal — Callback set by _OsGridState to handle copyToClipboard.
  void Function()? _onCopyToClipboardRequested;

  /// @internal — Callback set by _OsGridState to handle pasteFromClipboard.
  void Function()? _onPasteFromClipboardRequested;

  /// @internal — Callback set by _OsGridState to handle cutToClipboard.
  void Function()? _onCutToClipboardRequested;

  /// @internal — Used by _OsGridState to register clipboard callbacks.
  set onCopyToClipboardRequested(void Function()? fn) =>
      _onCopyToClipboardRequested = fn;

  /// @internal — Used by _OsGridState to register clipboard callbacks.
  set onPasteFromClipboardRequested(void Function()? fn) =>
      _onPasteFromClipboardRequested = fn;

  /// @internal — Used by _OsGridState to register clipboard callbacks.
  set onCutToClipboardRequested(void Function()? fn) =>
      _onCutToClipboardRequested = fn;

  // --- Side Bar ---

  /// Emitted when a tool panel's visibility changes (opened or closed).
  Stream<OsToolPanelVisibleChangedEvent> get onToolPanelVisibleChanged =>
      _bus.on<OsToolPanelVisibleChangedEvent>();

  /// Emitted when the side bar state is updated (visibility, position, panel open/close).
  Stream<OsSideBarUpdatedEvent> get onSideBarUpdated =>
      _bus.on<OsSideBarUpdatedEvent>();

  /// @internal — Current side bar visibility state.
  bool _sideBarVisible = true;

  /// @internal — Currently open tool panel ID.
  String? _openToolPanelId;

  /// @internal — Callbacks set by _OsGridState for side bar control.
  void Function(bool visible)? _onSetSideBarVisible;
  void Function(String key)? _onOpenToolPanel;
  void Function()? _onCloseToolPanel;
  void Function(OsSideBarPosition position)? _onSetSideBarPosition;

  /// @internal — Used by _OsGridState to update sidebar visibility state.
  set sideBarVisibleState(bool value) => _sideBarVisible = value;

  /// @internal — Used by _OsGridState to update open tool panel ID.
  set openToolPanelIdState(String? value) => _openToolPanelId = value;

  /// @internal — Used by _OsGridState to register sidebar callbacks.
  set onSetSideBarVisibleCallback(void Function(bool visible)? fn) =>
      _onSetSideBarVisible = fn;

  /// @internal — Used by _OsGridState to register sidebar callbacks.
  set onOpenToolPanelCallback(void Function(String key)? fn) =>
      _onOpenToolPanel = fn;

  /// @internal — Used by _OsGridState to register sidebar callbacks.
  set onCloseToolPanelCallback(void Function()? fn) => _onCloseToolPanel = fn;

  /// @internal — Used by _OsGridState to register sidebar callbacks.
  set onSetSideBarPositionCallback(
    void Function(OsSideBarPosition position)? fn,
  ) => _onSetSideBarPosition = fn;

  /// @internal — Used by _OsGridState to emit tool panel visible events.
  StreamController<OsToolPanelVisibleChangedEvent>
  get toolPanelVisibleChangedController =>
      _bus.controller<OsToolPanelVisibleChangedEvent>();

  /// @internal — Used by _OsGridState to emit sidebar updated events.
  StreamController<OsSideBarUpdatedEvent> get sideBarUpdatedController =>
      _bus.controller<OsSideBarUpdatedEvent>();

  /// Returns whether the side bar is currently visible.
  bool isSideBarVisible() => _sideBarVisible;

  /// Shows or hides the side bar.
  ///
  /// ```dart
  /// controller.setSideBarVisible(true);
  /// ```
  void setSideBarVisible(bool visible) {
    _onSetSideBarVisible?.call(visible);
  }

  /// Opens the specified tool panel by its ID.
  ///
  /// ```dart
  /// controller.openToolPanel('columns');
  /// controller.openToolPanel('filters');
  /// ```
  void openToolPanel(String key) {
    _onOpenToolPanel?.call(key);
  }

  /// Closes any currently open tool panel.
  ///
  /// The side bar buttons remain visible but no panel content is shown.
  ///
  /// ```dart
  /// controller.closeToolPanel();
  /// ```
  void closeToolPanel() {
    _onCloseToolPanel?.call();
  }

  /// Returns the ID of the currently open tool panel, or `null` if none is open.
  ///
  /// ```dart
  /// final panelId = controller.getOpenedToolPanel();
  /// if (panelId == 'columns') { ... }
  /// ```
  String? getOpenedToolPanel() => _openToolPanelId;

  /// Returns whether any tool panel is currently showing.
  bool isToolPanelShowing() => _openToolPanelId != null;

  /// Sets the side bar position (left or right).
  ///
  /// Note: This is primarily for programmatic state changes. The initial
  /// position is set via [OsSideBarDef.position].
  void setSideBarPosition(OsSideBarPosition position) {
    _onSetSideBarPosition?.call(position);
  }

  /// Forwards a [GridDiagnostic] raised via the central diagnostics
  /// helper onto the event bus (exposed via [onDiagnostic]). Registered
  /// in the constructor and removed in [dispose].
  void _emitDiagnostic(GridDiagnostic diagnostic) {
    if (!_bus.isClosed) {
      _bus.emit(diagnostic);
    }
  }

  // --- Lifecycle ---

  @override
  void dispose() {
    GridDiagnostics.removeListener(_emitDiagnostic);
    scrollCommandNotifier.dispose();
    focusCommandNotifier.dispose();
    _bus.dispose();
    super.dispose();
  }
}
