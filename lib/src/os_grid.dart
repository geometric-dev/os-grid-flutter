import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'accessibility/grid_live_region.dart';
import 'aligned_grids/aligned_grid_coordinator.dart';
import 'aligned_grids/os_aligned_grid.dart';
import 'cache/value_cache.dart';
import 'cache/value_prefetcher.dart';
import 'cell_span/cell_span_service.dart';
import 'charts/chart_definition.dart';
import 'charts/chart_palette_popup.dart';
import 'charts/chart_range_service.dart';
import 'clipboard/clipboard_coordinator.dart';
import 'clipboard/clipboard_service.dart';
import 'columns/column_api_coordinator.dart';
import 'columns/column_def_resolver.dart';
import 'columns/column_drag_coordinator.dart';
import 'columns/os_column_def.dart';
import 'columns/os_column_group.dart';
import 'columns/os_column_pin.dart';
import 'context_menu/context_menu_popup.dart';
import 'context_menu/context_menu_types.dart';
import 'data/data_pipeline_coordinator.dart';
import 'debug/grid_inspector.dart';
import 'drag_and_drop/drag_and_drop_config.dart';
import 'drag_and_drop/drag_and_drop_events.dart';
import 'editing/editing_coordinator.dart';
import 'editing/os_checkbox_cell_editor.dart';
import 'editing/undo_redo_coordinator.dart';
import 'editing/undo_redo_service.dart';
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
import 'events/grid_state_events.dart';
import 'events/infinite_row_model_events.dart';
import 'events/lifecycle_events.dart';
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
import 'filtering/filter_model.dart';
import 'filtering/filter_popup.dart';
import 'filtering/os_custom_filter.dart';
import 'filtering/os_set_filter.dart';
import 'grid_state/grid_state.dart';
import 'grid_state/grid_state_service.dart';
import 'infinite_row_model/block_cache.dart';
import 'infinite_row_model/infinite_datasource.dart';
import 'infinite_row_model/infinite_row_model.dart';
import 'locale/os_locale_text.dart';
import 'menu/column_menu_popup.dart';
import 'menu/os_column_menu_def.dart';
import 'modules/clipboard_module.dart';
import 'modules/editing_module.dart';
import 'modules/os_module.dart';
import 'modules/set_filter_module.dart';
import 'modules/sparkline_module.dart';
import 'modules/tree_data_module.dart';
import 'os_grid_controller.dart';
import 'pagination/os_pagination.dart';
import 'params/cell_renderer_params.dart';
import 'params/navigation_params.dart';
import 'params/value_formatter_params.dart';
import 'params/value_getter_params.dart';
import 'params/value_setter_params.dart';
import 'pivot/pivot_service.dart';
import 'popup/popup_ui_coordinator.dart';
import 'render_api/cell_flash_coordinator.dart';
import 'rendering/column_group_layout.dart';
import 'rendering/focus_command.dart';
import 'rendering/grid_hit_test.dart';
import 'rendering/grid_model_resolver.dart';
import 'rendering/master_detail.dart';
import 'rendering/special_columns.dart';
import 'rendering/text_painter_cache.dart';
import 'rendering/virtualised_grid.dart';
import 'row_auto_height/auto_height_calculator.dart';
import 'row_auto_height/row_height_layout.dart';
import 'row_drag/row_drag_coordinator.dart';
import 'row_drag/row_drag_event.dart';
import 'row_grouping/row_group_panel.dart';
import 'row_grouping/row_group_panel_visibility.dart';
import 'row_grouping/row_group_service.dart';
import 'row_grouping/row_group_state.dart';
import 'row_grouping/tree_data_service.dart';
import 'row_model/async_transaction_service.dart';
import 'row_model/delta_sort_service.dart';
import 'row_model/immutable_data_service.dart';
import 'row_model/row_transaction.dart';
import 'row_model/server_side_datasource.dart';
import 'row_model/server_side_row_model.dart';
import 'selection/cell_range.dart';
import 'selection/os_row_selection.dart';
import 'side_bar/os_side_bar.dart';
import 'side_bar/os_side_bar_def.dart';
import 'sorting/sort_direction.dart';
import 'sorting/sort_indicator_info.dart';
import 'sorting/sort_model.dart';
import 'sorting/sort_service.dart';
import 'status_bar/status_bar.dart';
import 'theming/os_grid_theme.dart';
import 'theming/os_row_style.dart';
import 'theming/resolved_grid_theme.dart';
import 'tooltip/tooltip_overlay.dart';
import 'tooltip/tooltip_params.dart';
import 'tooltip/tooltip_service.dart';
import 'utils/grid_diagnostics.dart';
import 'validation/grid_validator.dart';

/// A high-performance data grid widget.
///
/// [OsGrid] renders tabular data with support for sorting, filtering,
/// selection, editing, and virtualised scrolling for large datasets.
///
/// ```dart
/// OsGrid(
///   columnDefs: [
///     OsColumnDef(field: 'name', headerName: 'Name'),
///     OsColumnDef(field: 'age', headerName: 'Age'),
///   ],
///   rowData: [
///     {'name': 'Alice', 'age': 32},
///     {'name': 'Bob', 'age': 28},
///   ],
/// )
/// ```
class OsGrid<TData> extends StatefulWidget {
  /// Creates an OS Grid widget.
  const OsGrid({
    super.key,
    required this.columnDefs,
    this.defaultColDef,
    this.columnTypes,
    this.defaultColGroupDef,
    this.rowData,
    this.controller,
    this.getRowId,
    this.modules,
    this.rowSelection,
    this.cellSelection,
    this.enableIntegratedCharts = false,
    this.pagination,
    this.theme,
    this.quickFilterText,
    this.includeHiddenColumnsInQuickFilter = false,
    this.cacheQuickFilter = false,
    this.quickFilterParser,
    this.quickFilterMatcher,
    this.isExternalFilterPresent,
    this.doesExternalFilterPass,
    this.initialSort,
    this.multiSortKey = OsMultiSortKey.shift,
    this.alwaysMultiSort = false,
    this.suppressMultiSort = false,
    this.accentedSort = false,
    this.deltaSort = false,
    this.postSortRows,
    this.immutableData,
    this.asyncTransactionWaitMillis,
    this.onAsyncTransactionsFlushed,
    this.pinnedTopRowData,
    this.pinnedBottomRowData,
    this.rowHeight = 42.0,
    this.getRowHeight,
    this.headerHeight = 48.0,
    this.isMasterRow,
    this.detailWidgetBuilder,
    this.detailRowHeight,
    this.rowStyle,
    this.getRowStyle,
    this.rowNumbers = false,
    this.rowDrag = false,
    this.rowDragManaged = true,
    this.dragAndDrop,
    this.onRowDragOut,
    this.onExternalDrop,
    this.statusBar = false,
    this.statusBarConfig,
    this.floatingFilter = false,
    this.floatingFilterHeight = 32.0,
    this.singleClickEdit = false,
    this.stopEditingWhenCellsLoseFocus = true,
    this.enterNavigatesVertically = false,
    this.enterNavigatesVerticallyAfterEdit = false,
    this.navigateToNextCell,
    this.tabToNextCell,
    this.suppressClickEdit = false,
    this.readOnlyEdit = false,
    this.enableCellEditingOnBackspace = false,
    this.undoRedoCellEditing = false,
    this.undoRedoCellEditingLimit = 10,
    this.copyHeadersToClipboard = false,
    this.suppressClipboardPaste = false,
    this.clipboardDelimiter = '\t',
    this.processCellForClipboard,
    this.processHeaderForClipboard,
    this.processCellFromClipboard,
    this.tooltipShowDelay = 2000,
    this.tooltipHideDelay = 10000,
    this.tooltipMouseTrack = false,
    this.enableCellSpan = false,
    this.columnHoverHighlight = false,
    this.suppressColumnVirtualisation = false,
    this.valueCacheEnabled = false,
    this.prefetchEnabled = false,
    this.localeText,
    this.getLocaleText,
    this.onGridReady,
    this.onRowSelected,
    this.onRowDoubleClicked,
    this.onRowClicked,
    this.onCellClicked,
    this.onCellFocused,
    this.onCellKeyDown,
    this.onCellDoubleClicked,
    this.onCellValueChanged,
    this.onCellEditingStarted,
    this.onCellEditingStopped,
    this.onCellEditRequest,
    this.onSelectionChanged,
    this.onSortChanged,
    this.onFilterChanged,
    this.onPaginationChanged,
    this.onRowDataUpdated,
    this.onRangeSelectionChanged,
    this.onChartRangeCreated,
    this.onColumnVisible,
    this.onColumnPinned,
    this.onColumnResized,
    this.onColumnMoved,
    this.onRowDragEnter,
    this.onRowDragMove,
    this.onRowDragEnd,
    this.onRowDragLeave,
    this.onPinnedRowDataChanged,
    this.onUndoStarted,
    this.onUndoEnded,
    this.onRedoStarted,
    this.onRedoEnded,
    this.onClipboardCopy,
    this.onClipboardPaste,
    this.onClipboardCut,
    this.onTooltipShow,
    this.onTooltipHide,
    this.onColumnHoverChanged,
    this.onStateUpdated,
    this.initialState,
    this.alignedGrids,
    this.infiniteRowModel,
    this.datasource,
    this.serverSideDatasource,
    this.onInfiniteRowCountChanged,
    this.onExpandOrCollapseAll,
    this.groupBy,
    this.groupDefaultExpanded,
    this.onRowGroupOpened,
    this.rowGroupPanelVisibility = OsRowGroupPanelVisibility.never,
    this.onRowGroupColumnsChanged,
    this.treeData = false,
    this.getDataPath,
    this.pivotMode = false,
    this.onPivotModeChanged,
    this.suppressContextMenu = false,
    this.suppressRowClickSelection = false,
    this.suppressCellFocus = false,
    this.getContextMenuItems,
    this.onCellContextMenu,
    this.suppressGridOptionsValidation = false,
    this.columnMenu,
    this.sideBar,
    this.onToolPanelVisibleChanged,
    this.onSideBarUpdated,
    this.loading,
    this.loadingOverlay,
    this.noRowsOverlay,
    this.showInspector = false,
    this.onFirstDataRendered,
    this.onGridSizeChanged,
    this.onModelUpdated,
    this.onRowDataChanged,
  });

  // --- Data ---

  /// Column definitions describing each column in the grid.
  ///
  /// ```dart
  /// columnDefs: [
  ///   OsColumnDef(field: 'name', headerName: 'Name', width: 180),
  ///   OsColumnDef(field: 'age', headerName: 'Age'),
  /// ],
  /// ```
  final List<OsColumnDefBase> columnDefs;

  /// Defaults applied to every data column for fields the column leaves
  /// null. Precedence per field: explicit colDef > [columnTypes] >
  /// [defaultColDef] > built-in defaults.
  ///
  /// Non-nullable convenience flags (`sortable`, `resizable`, `autoHeight`,
  /// `wrapText`) cannot participate — their defaults are baked into every
  /// definition instance.
  ///
  /// ```dart
  /// defaultColDef: const OsColumnDef<dynamic>(width: 140),
  /// ```
  final OsColumnDef<dynamic>? defaultColDef;

  /// Named column pseudo-types referenced from a colDef's `type` field
  /// (single name or list). Merged in listed order between [defaultColDef]
  /// and explicit colDef fields. Unknown names warn once in debug output.
  final Map<String, OsColumnDef<dynamic>>? columnTypes;

  /// Reserved: partial defaults applied to column groups. Not applied yet —
  /// see [OsColumnGroupDefaults].
  final OsColumnGroupDefaults? defaultColGroupDef;

  /// The row data to display. Each item represents one row.
  ///
  /// For untyped usage, use `List<Map<String, dynamic>>`.
  /// For typed usage, provide a `List<TData>` with corresponding
  /// [OsColumnDef.valueGetter] on each column.
  ///
  /// ```dart
  /// rowData: [
  ///   {'name': 'Alice', 'age': 32},
  ///   {'name': 'Bob', 'age': 28},
  /// ],
  /// ```
  final List<TData>? rowData;

  // --- Row ID ---

  /// Callback to derive a stable unique ID for each row.
  ///
  /// When provided, selection is tracked by this ID and survives
  /// sort/filter operations. When null, falls back to `hashCode`.
  ///
  /// ```dart
  /// OsGrid(
  ///   getRowId: (data) => data['id'].toString(),
  ///   // ...
  /// )
  /// ```
  final String Function(TData data)? getRowId;

  // --- Controller ---

  /// Optional controller for imperative grid operations.
  ///
  /// If not provided, the grid manages its own internal state.
  /// Provide a controller to access the [OsGridController] API
  /// (selection, scrolling, export, etc.).
  final OsGridController<TData>? controller;

  // --- Modules ---

  /// Modules to register with this grid instance.
  ///
  /// Modules provide optional features like clipboard, editing, set filter,
  /// tree data and sparklines. Can also be registered globally via
  /// [OsGrid.registerModules].
  ///
  /// When this list (combined with the global registry) is non-empty it is
  /// the authoritative feature registry: features whose module is absent
  /// are disabled and their related parameters are ignored with a
  /// debug-mode warning. When omitted or empty, all features are enabled.
  final List<OsModule>? modules;

  // --- Selection ---

  /// Row selection configuration.
  ///
  /// Use [OsRowSelection.single] or [OsRowSelection.multiple] to enable
  /// row selection with optional checkbox support.
  ///
  /// ```dart
  /// rowSelection: OsRowSelection.multiple(checkboxes: true),
  /// ```
  final OsRowSelection? rowSelection;

  /// Cell/range selection configuration.
  ///
  /// When provided, enables range selection: click and drag across cells
  /// to select a rectangular region. The selected range is highlighted
  /// with a semi-transparent fill and a solid border.
  ///
  /// ```dart
  /// OsGrid(
  ///   cellSelection: const OsCellSelection(),
  ///   // ...
  /// )
  /// ```
  final OsCellSelection? cellSelection;

  /// Whether the integrated-charts palette button is drawn at the active
  /// cell range selection (requires [cellSelection]).
  ///
  /// Tapping the button opens the chart-type palette; choosing a type
  /// extracts the range into an [OsChartDefinition] and fires
  /// [onChartRangeCreated] / `controller.onChartRangeCreated`. Rendering
  /// the chart itself is left to the application (see
  /// `os_grid_flutter_charts`).
  final bool enableIntegratedCharts;

  // --- Pagination ---

  /// Pagination configuration. If null, all rows are displayed.
  ///
  /// ```dart
  /// pagination: const OsPagination(pageSize: 50),
  /// ```
  final OsPagination? pagination;

  // --- Theming ---

  /// Theme configuration for the grid's visual appearance.
  ///
  /// If null, uses default styling that adapts to the ambient Flutter theme.
  ///
  /// ```dart
  /// theme: OsGridTheme.quartzDark(),
  /// ```
  final OsGridTheme? theme;

  // --- Filtering ---

  /// Quick filter text applied across all columns.
  ///
  /// ```dart
  /// quickFilterText: 'alice',
  /// ```
  final String? quickFilterText;

  /// Whether hidden columns are included in the quick filter search.
  ///
  /// When `false` (default), only visible columns are searched.
  /// When `true`, all columns with a `field` are searched regardless
  /// of visibility.
  final bool includeHiddenColumnsInQuickFilter;

  /// Whether to cache each row's quick-filter text across filter runs.
  ///
  /// When `true`, the grid caches the per-row aggregate/getter text used
  /// for quick-filter matching (keyed by row identity and column). On
  /// subsequent quick-filter passes over unchanged data the cached text
  /// is reused instead of re-invoking [OsColumnDef.valueGetter] /
  /// [OsColumnDef.getQuickFilterText] for every cell — a significant win
  /// when the user types successive quick-filter terms over a large
  /// dataset.
  ///
  /// The cache is invalidated automatically whenever the row-data source
  /// changes ([OsGridController.setRowData],
  /// [OsGridController.applyTransaction], reprocess-from-controller) or
  /// when hidden columns change, so results always reflect current data.
  /// Use [OsGridController.clearQuickFilterCache] to force invalidation
  /// after external in-place mutations of row objects. Changing the quick
  /// filter text itself never invalidates the cache.
  ///
  /// Defaults to `false`.
  final bool cacheQuickFilter;

  /// Custom function to split the quick filter text into search terms.
  ///
  /// By default, the filter text is split on whitespace. Provide a custom
  /// parser to change how the text is tokenised:
  /// ```dart
  /// quickFilterParser: (text) => text.split(','),
  /// ```
  final List<String> Function(String quickFilter)? quickFilterParser;

  /// Custom function to determine if a row passes the quick filter.
  ///
  /// When provided, this replaces the default matching logic entirely.
  /// The function receives the parsed filter parts and the row's aggregate
  /// text (all column values concatenated with newlines):
  /// ```dart
  /// quickFilterMatcher: (parts, rowText) =>
  ///     parts.every((part) => rowText.contains(part)),
  /// ```
  final bool Function(
    List<String> quickFilterParts,
    String rowQuickFilterAggregateText,
  )?
  quickFilterMatcher;

  /// Callback that returns `true` when an external filter is active.
  ///
  /// When this returns `true`, [doesExternalFilterPass] is called for each
  /// row during filtering. Use this to drive filtering from components
  /// outside the grid (e.g. an external filter bar or sidebar controls).
  ///
  /// Call [OsGridController.onExternalFilterChanged] when the external
  /// filter state changes to trigger re-evaluation.
  ///
  /// ```dart
  /// OsGrid(
  ///   isExternalFilterPresent: () => _selectedCategory != null,
  ///   doesExternalFilterPass: (row) => row['category'] == _selectedCategory,
  /// )
  /// ```
  final bool Function()? isExternalFilterPresent;

  /// Callback that returns `true` if the given row passes the external filter.
  ///
  /// Only called when [isExternalFilterPresent] returns `true`.
  /// Receives the row data and should return `true` to include the row,
  /// `false` to exclude it.
  final bool Function(TData data)? doesExternalFilterPass;

  // --- Sorting ---

  /// Initial sort state applied when the grid first renders.
  final List<OsSortModel>? initialSort;

  /// Which modifier key triggers multi-column sort on header click.
  ///
  /// Defaults to [OsMultiSortKey.shift] (hold Shift and click to add
  /// a column to the sort). Set to [OsMultiSortKey.ctrl] to use
  /// Ctrl (or Cmd on macOS) instead.
  final OsMultiSortKey multiSortKey;

  /// When `true`, every header click adds to the sort model (as if the
  /// multi-sort modifier key were always held). Defaults to `false`.
  final bool alwaysMultiSort;

  /// When `true`, multi-column sort is disabled entirely. Only one column
  /// can be sorted at a time regardless of modifier keys. Defaults to `false`.
  final bool suppressMultiSort;

  /// When `true`, string comparisons use locale-sensitive ordering to
  /// correctly handle accented characters (é, ñ, ü, etc.).
  ///
  /// This is slower than the default binary comparison. Defaults to `false`.
  final bool accentedSort;

  /// When `true`, enables delta sorting for transactions.
  ///
  /// Instead of re-sorting the entire dataset after a transaction, only the
  /// added/updated rows are sorted and merged into their correct position.
  /// This is a performance optimisation for large datasets with frequent
  /// small updates.
  ///
  /// Defaults to `false`.
  final bool deltaSort;

  /// Callback to post-process sorted rows before they are displayed.
  ///
  /// Receives a mutable copy of the sorted row list. Return the reordered
  /// list. This is useful for pinning certain rows to the top/bottom
  /// regardless of sort state, or for custom secondary ordering.
  ///
  /// Note: when [postSortRows] is configured, [deltaSort] is ignored
  /// (falls back to full sort) since the callback may reorder rows in ways
  /// that invalidate the delta sort baseline.
  ///
  /// ```dart
  /// OsGrid(
  ///   postSortRows: (rows) {
  ///     // Pin 'priority' rows to the top
  ///     final priority = rows.where((r) => r['priority'] == true).toList();
  ///     final rest = rows.where((r) => r['priority'] != true).toList();
  ///     return [...priority, ...rest];
  ///   },
  /// )
  /// ```
  final List<TData> Function(List<TData> rows)? postSortRows;

  /// Enables immutable data mode.
  ///
  /// When `true` (or when `getRowId` is provided and this is not explicitly
  /// set to `false`), the grid compares new [rowData] with existing data
  /// using [getRowId] to automatically determine adds, removes, and updates
  /// without needing explicit [OsGridController.applyTransaction] calls.
  ///
  /// When [rowData] changes, the grid diffs by ID and applies the minimal
  /// transaction internally.
  ///
  /// Defaults to `null`, which means immutable mode is implicitly enabled
  /// when [getRowId] is provided.
  final bool? immutableData;

  /// The number of milliseconds to batch async transactions.
  ///
  /// When set, [OsGridController.applyTransactionAsync] collects transactions
  /// for this duration before applying them all at once. Useful when receiving
  /// rapid-fire updates (e.g. from a WebSocket).
  ///
  /// When `null`, async transactions are not available and
  /// `applyTransactionAsync` falls back to synchronous `applyTransaction`.
  final int? asyncTransactionWaitMillis;

  /// Callback invoked when batched async transactions are flushed.
  final void Function(OsAsyncTransactionsFlushedEvent<TData>)?
  onAsyncTransactionsFlushed;

  // --- Pinned rows ---

  /// Rows pinned to the top of the grid (always visible above scrollable area).
  final List<TData>? pinnedTopRowData;

  /// Rows pinned to the bottom of the grid (always visible below scrollable area).
  final List<TData>? pinnedBottomRowData;

  // --- Sizing ---

  /// Height of each data row in logical pixels. Defaults to 42.
  final double rowHeight;

  /// Callback to determine the height of each row individually.
  ///
  /// When provided, this takes precedence over [rowHeight] for rows where
  /// the callback returns a non-null value. Return `null` to use the
  /// default [rowHeight].
  ///
  /// ```dart
  /// OsGrid(
  ///   getRowHeight: (params) {
  ///     final data = params.data as Map<String, dynamic>;
  ///     return data['expanded'] == true ? 84.0 : null;
  ///   },
  ///   // ...
  /// )
  /// ```
  final double? Function(RowHeightParams<TData> params)? getRowHeight;

  /// Height of the header row in logical pixels. Defaults to 48.
  final double headerHeight;

  // --- Master / Detail ---

  /// Returns `true` for rows that can expand a detail area (quality
  /// program v3 item 4, mirroring AG Grid's master/detail rows).
  ///
  /// Consulted once per display row on every build. Rows that return
  /// `true` toggle their detail area when tapped, and the detail area is
  /// rendered directly below the master row in the display order.
  ///
  /// Master/detail requires the client-side row model (flat [rowData]);
  /// it is ignored — with a debug-mode warning — when row grouping, tree
  /// data, the infinite row model or the server-side row model is active.
  ///
  /// Requires [detailWidgetBuilder] to be set; both callbacks must be
  /// present for the feature to activate.
  ///
  /// ```dart
  /// isMasterRow: (data) => data['isParent'] == true,
  /// ```
  final bool Function(TData data)? isMasterRow;

  /// Builds the content of a master row's detail area.
  ///
  /// Called for every VISIBLE expanded master row on each build/scroll
  /// frame; the returned widget is positioned over the detail row's rect
  /// in an overlay above the canvas. `rowIndex` is the display index of
  /// the master row that owns the detail area.
  ///
  /// ```dart
  /// detailWidgetBuilder: (data, rowIndex) => Text('Details for $data'),
  /// ```
  final Widget Function(TData data, int rowIndex)? detailWidgetBuilder;

  /// Returns the height (logical pixels) of the detail area for a master
  /// row. Defaults to [kDefaultDetailRowHeight] (300).
  ///
  /// ```dart
  /// detailRowHeight: (data) => data['childCount'] * 42.0,
  /// ```
  final double Function(TData data)? detailRowHeight;

  // --- Row styling ---

  /// Static style applied to all data rows.
  ///
  /// When both [rowStyle] and [getRowStyle] are provided, the callback
  /// result is merged on top of the static style (callback values override
  /// static values for the same property).
  ///
  /// ```dart
  /// OsGrid(
  ///   rowStyle: const OsRowStyle(fontWeight: FontWeight.w500),
  ///   // ...
  /// )
  /// ```
  final OsRowStyle? rowStyle;

  /// Callback to compute per-row style based on data.
  ///
  /// Called for each visible row during painting. Return `null` to use
  /// the default styling (or [rowStyle] if set).
  ///
  /// ```dart
  /// OsGrid(
  ///   getRowStyle: (params) {
  ///     final data = params.data as Map<String, dynamic>;
  ///     if (data['status'] == 'overdue') {
  ///       return OsRowStyle(backgroundColor: Colors.red.shade50);
  ///     }
  ///     return null;
  ///   },
  ///   // ...
  /// )
  /// ```
  final OsRowStyle? Function(RowStyleParams<TData> params)? getRowStyle;

  // --- Row numbers ---

  /// Whether to show a row number column as the first column.
  /// Mirrors OS Grid's `rowNumbers` option.
  final bool rowNumbers;

  // --- Row drag ---

  /// Whether to show a drag handle column for row reordering.
  ///
  /// When `true`, a drag handle column (⠿) is prepended as the first column
  /// (pinned left). Users can grab the handle to drag rows up/down.
  ///
  /// See also [rowDragManaged] to control whether the grid automatically
  /// reorders rows on drop.
  final bool rowDrag;

  /// Whether the grid should automatically reorder rows when dragged.
  ///
  /// When `true` (default when [rowDrag] is enabled), the grid moves the
  /// row data to the new position on drop. When `false`, the grid only
  /// fires events and the caller is responsible for reordering.
  ///
  /// Only relevant when [rowDrag] is `true`.
  final bool rowDragManaged;

  // --- External drag and drop ---

  /// Configuration for external drag and drop.
  ///
  /// When provided, enables dragging rows out of the grid and/or dropping
  /// external items into the grid. This is separate from [rowDrag] which
  /// handles reordering rows within the grid.
  ///
  /// ```dart
  /// OsGrid(
  ///   dragAndDrop: const OsDragAndDrop(
  ///     enableDragOut: true,
  ///     enableDropIn: true,
  ///   ),
  ///   onRowDragOut: (event) => print('Row dragged out'),
  ///   onExternalDrop: (event) => print('Item dropped in'),
  /// )
  /// ```
  final OsDragAndDrop? dragAndDrop;

  /// Called when a row is dragged outside the grid bounds.
  ///
  /// Only fires when [dragAndDrop] is provided with `enableDragOut: true`.
  final ValueChanged<OsRowDragOutEvent<TData>>? onRowDragOut;

  /// Called when an external item is dropped onto the grid.
  ///
  /// Only fires when [dragAndDrop] is provided with `enableDropIn: true`.
  /// The grid does NOT automatically insert the dropped data — the caller
  /// is responsible for updating the row data.
  final ValueChanged<OsExternalDropEvent>? onExternalDrop;

  // --- Status bar ---

  /// Whether to show a status bar below the grid with row counts.
  final bool statusBar;

  /// Optional rich status bar configuration with aggregation panels.
  ///
  /// Each panel in [OsStatusBarConfig.statusPanels] computes a built-in
  /// aggregate (`sum`, `avg`, `min`, `max`, `count`) over the currently
  /// visible page rows (post filter/sort/page) for one column and renders
  /// it as a compact chip.
  ///
  /// When provided, this takes precedence over [statusBar]: the legacy
  /// row-count display is replaced by the configured panels.
  ///
  /// ```dart
  /// OsGrid(
  ///   statusBarConfig: const OsStatusBarConfig(
  ///     statusPanels: [
  ///       OsStatusPanelDef(aggregationFunc: 'sum', valueColId: 'price'),
  ///     ],
  ///   ),
  ///   ...
  /// )
  /// ```
  final OsStatusBarConfig? statusBarConfig;

  // --- Overlays ---

  /// Whether the grid is in a loading state.
  ///
  /// When `true`, an ignore-pointer overlay is shown above the grid using
  /// [loadingOverlay] (or a default localized 'Loading...' panel).
  ///
  /// When `null` or `false` and the displayed row count is zero, the
  /// [noRowsOverlay] (or a default localized 'No Rows To Show' panel) is
  /// shown instead.
  ///
  /// ```dart
  /// loading: isFetching,
  /// ```
  final bool? loading;

  /// Custom widget shown over the grid while [loading] is `true`.
  ///
  /// Defaults to a centered panel with the localized `loadingOoo` text.
  final Widget? loadingOverlay;

  /// Custom widget shown over the grid when there are no displayed rows
  /// and [loading] is not `true`.
  ///
  /// Defaults to a centered panel with the localized `noRowsToShow` text.
  final Widget? noRowsOverlay;

  // --- Debug ---

  /// Shows the [GridInspector] debug overlay above all grid overlays.
  ///
  /// The inspector is a collapsible developer panel displaying live model
  /// statistics: displayed/total row counts, pagination state, selection
  /// (with a sample of selected IDs), focused cell, quick filter state,
  /// column visibility counts, infinite row model state and the explicit
  /// overlay override.
  ///
  /// Intended for development and diagnostics; leave `false` (the default)
  /// in production builds. Section headers use the theme's
  /// [OsGridTheme.accentColor] when a [theme] is configured.
  ///
  /// ```dart
  /// OsGrid(
  ///   showInspector: true,
  ///   // ...
  /// )
  /// ```
  final bool showInspector;

  // --- Lifecycle events ---

  /// Called once, post-frame, after the first build with non-empty
  /// processed data (after filter + sort).
  final ValueChanged<OsFirstDataRenderedEvent>? onFirstDataRendered;

  /// Called when the grid's rendered size changes. The first layout does
  /// not fire this — only subsequent actual size changes do.
  final ValueChanged<OsGridSizeChangedEvent>? onGridSizeChanged;

  /// Called after the client-side row model has been reprocessed and when
  /// the pagination page changes.
  ///
  /// Emissions are deferred to a post-frame callback and re-entrancy
  /// guarded so listeners that trigger further processing are safe.
  final ValueChanged<OsModelUpdatedEvent>? onModelUpdated;

  /// Called in didUpdateWidget when the raw [rowData] list reference
  /// changes, before the filter/sort pipeline processes the new data.
  ///
  /// The callback runs during the widget build phase — do not call
  /// setState synchronously from it; use the matching controller stream
  /// ([OsGridController.onRowDataChanged]) for async-safe delivery.
  final ValueChanged<OsRowDataChangedEvent<TData>>? onRowDataChanged;

  // --- Floating filter ---

  /// Whether to show a floating filter row below the column headers.
  ///
  /// When enabled, a compact row of filter input placeholders is rendered
  /// between the column headers and the data rows. Each column with a
  /// [OsColumnDef.filter] set gets an input box.
  final bool floatingFilter;

  /// Height of the floating filter row in logical pixels. Defaults to 32.
  ///
  /// Only used when [floatingFilter] is true.
  final double floatingFilterHeight;

  // --- Editing options ---

  /// Whether single-click starts editing on editable cells.
  ///
  /// When `true`, a single click on an editable cell starts editing
  /// (instead of requiring a double-click). Defaults to `false`.
  ///
  /// Can be overridden per-column via [OsColumnDef.singleClickEdit].
  final bool singleClickEdit;

  /// Whether editing stops when cells lose focus.
  ///
  /// When `true` (default, matching AG Grid), any focus loss — clicking
  /// another cell or outside the grid — commits the current edit.
  ///
  /// When `false`, editing persists until the user explicitly commits
  /// (Enter/Tab) or cancels (Escape).
  final bool stopEditingWhenCellsLoseFocus;

  /// When true, pressing Enter navigates vertically instead of starting editing.
  ///
  /// When not editing: Enter moves focus to the cell below (Shift+Enter → above).
  /// This prevents Enter from starting editing — only F2, printable chars, or
  /// API can initiate editing.
  final bool enterNavigatesVertically;

  /// When true, after committing an edit with Enter, navigate to the cell below.
  ///
  /// Shift+Enter navigates to the cell above. This provides Excel-style
  /// data entry behaviour where Enter moves down through a column.
  final bool enterNavigatesVerticallyAfterEdit;

  /// Optional callback to customise keyboard cell-to-cell navigation.
  ///
  /// Consulted for every keyboard navigation move (arrow keys,
  /// PageUp/PageDown, Home/End). Receives [NavigateToNextCellParams] with
  /// the previous cell, the default next cell, the key name and whether
  /// Shift was held. Return a [NavCellPosition] to move focus there (it is
  /// clamped to the grid bounds), or return `null` to keep default movement:
  /// ```dart
  /// OsGrid(
  ///   navigateToNextCell: (params) {
  ///     // Example: ArrowDown jumps two rows instead of one
  ///     if (params.key == 'arrowdown') {
  ///       return NavCellPosition(
  ///         rowIndex: params.previousCell.rowIndex + 2,
  ///         columnIndex: params.previousCell.columnIndex,
  ///       );
  ///     }
  ///     return null; // default movement
  ///   },
  /// )
  /// ```
  final NavCellPosition? Function(NavigateToNextCellParams params)?
  navigateToNextCell;

  /// Optional callback to customise Tab / Shift+Tab focus navigation.
  ///
  /// When set, Tab no longer leaves the grid via Flutter's focus traversal;
  /// instead this callback decides where focus moves next. It is consulted
  /// during non-editing navigation AND after committing an edit with Tab
  /// (the next edit target follows the returned position). Return `null` to
  /// keep default behaviour (one column right, or left with Shift).
  final NavCellPosition? Function(TabToNextCellParams params)? tabToNextCell;

  /// When true, neither single nor double click starts editing.
  ///
  /// Only keyboard triggers (Enter, F2, printable char) or the
  /// `startEditingCell` API can initiate editing.
  final bool suppressClickEdit;

  /// When true, the editing UI works normally but instead of writing the
  /// value to data, a [onCellEditRequest] event is fired.
  ///
  /// The application is responsible for updating the data externally
  /// (e.g. via an API call) and then calling [OsGridController.setRowData]
  /// or [OsGridController.applyTransaction] to refresh the grid.
  ///
  /// This is useful for server-side persistence patterns where the grid
  /// should not mutate data directly.
  final bool readOnlyEdit;

  /// When true, pressing Backspace starts editing with an empty value
  /// instead of clearing the cell value directly.
  ///
  /// This matches macOS behaviour where Backspace (the only "delete" key
  /// on Mac keyboards) should initiate editing rather than immediately
  /// clearing the cell.
  ///
  /// When false (default), Backspace clears the cell value directly
  /// (same as the Delete key).
  final bool enableCellEditingOnBackspace;

  /// Whether undo/redo is enabled for cell edits.
  ///
  /// When `true`, cell edits can be undone with Ctrl+Z (Cmd+Z on macOS)
  /// and redone with Ctrl+Y (Cmd+Y on macOS). The controller also exposes
  /// [OsGridController.undoCellEditing] and [OsGridController.redoCellEditing].
  ///
  /// Defaults to `false`.
  final bool undoRedoCellEditing;

  /// Maximum number of undo actions to keep in the stack.
  ///
  /// When the stack reaches this limit, the oldest action is discarded.
  /// Only relevant when [undoRedoCellEditing] is `true`.
  ///
  /// Set to 0 or negative to disable undo/redo entirely (even if
  /// [undoRedoCellEditing] is `true`). Defaults to 10.
  final int undoRedoCellEditingLimit;

  // --- Clipboard options ---

  /// Whether to include column headers as the first row when copying.
  ///
  /// Defaults to `false`.
  final bool copyHeadersToClipboard;

  /// Whether to suppress clipboard paste operations.
  ///
  /// When `true`, Ctrl+V and [OsGridController.pasteFromClipboard] are no-ops.
  /// Defaults to `false`.
  final bool suppressClipboardPaste;

  /// Delimiter between cell values in clipboard text.
  ///
  /// Defaults to tab (`'\t'`), which is the standard format for Excel
  /// and Google Sheets.
  final String clipboardDelimiter;

  /// Callback to transform cell values before they are copied to clipboard.
  ///
  /// When provided, this is called for each cell in the copy range.
  /// Return the string to place in the clipboard for that cell.
  final String Function(ProcessCellForClipboardParams<TData>)?
  processCellForClipboard;

  /// Callback to transform header names before they are copied to clipboard.
  ///
  /// Only called when [copyHeadersToClipboard] is `true`.
  final String Function(ProcessHeaderForClipboardParams)?
  processHeaderForClipboard;

  /// Callback to transform pasted values before they are applied to cells.
  ///
  /// When provided, this is called for each cell being pasted into.
  /// Return the string value to apply to the cell.
  final String Function(ProcessCellFromClipboardParams<TData>)?
  processCellFromClipboard;

  // --- Tooltip options ---

  /// Delay in milliseconds before showing a tooltip after hover starts.
  ///
  /// The tooltip will not appear until the pointer has remained stationary
  /// over a tooltip-enabled cell/header for this duration.
  ///
  /// Minimum effective value is 200ms (values below are clamped).
  /// Defaults to 2000ms (matching OS Grid TypeScript).
  final int tooltipShowDelay;

  /// Delay in milliseconds before auto-hiding a visible tooltip.
  ///
  /// After the tooltip appears, it will automatically hide after this
  /// duration even if the pointer remains over the cell.
  ///
  /// Minimum effective value is 200ms (values below are clamped).
  /// Defaults to 10000ms.
  final int tooltipHideDelay;

  /// Whether tooltips follow the cursor position while shown.
  ///
  /// When `true`, the tooltip repositions to follow the pointer as it
  /// moves within the same cell. When `false` (default), the tooltip
  /// stays anchored at the initial hover position.
  final bool tooltipMouseTrack;

  // --- Cell Spanning ---

  /// When `true`, enables the cell span feature allowing the use of
  /// `colSpan`, `rowSpan`, and `spanRows` on column definitions.
  ///
  /// Defaults to `false`. When disabled, span properties on columns are ignored.
  final bool enableCellSpan;

  // --- Column Hover ---

  /// Whether to highlight the entire column when the pointer hovers over
  /// any cell in that column.
  ///
  /// When `true`, a semi-transparent highlight is painted over all visible
  /// cells in the hovered column (including header and floating filter).
  /// The highlight colour is controlled by [OsGridTheme.columnHoverColor].
  ///
  /// Mirrors OS Grid's `columnHoverHighlight` grid option.
  ///
  /// Defaults to `false`.
  final bool columnHoverHighlight;

  // --- Column Virtualisation ---

  /// When `true`, disables column virtualisation and paints all columns
  /// regardless of horizontal scroll position.
  ///
  /// Column virtualisation skips painting cells for columns that are
  /// entirely off-screen horizontally, improving paint performance for
  /// grids with many columns. A small buffer (2 columns on each side)
  /// prevents flicker during fast scrolling.
  ///
  /// Set this to `true` for debugging or when custom painting logic
  /// requires all columns to be painted.
  ///
  /// Defaults to `false` (virtualisation enabled).
  final bool suppressColumnVirtualisation;

  // --- Value Cache ---

  /// Whether to cache the results of valueGetter calls.
  ///
  /// When `true`, the grid caches computed cell values so that repeated
  /// lookups for the same cell (e.g. during sort comparisons and filter
  /// evaluations) return the cached result instead of re-executing the
  /// valueGetter.
  ///
  /// The cache is automatically invalidated on data changes (setRowData,
  /// applyTransaction, column definition changes, sort, filter). Use
  /// [OsGridController.expireValueCache] for manual invalidation when
  /// external state affecting valueGetters changes.
  ///
  /// Defaults to `false`.
  final bool valueCacheEnabled;

  /// Whether to pre-compute valueGetter results for the NEXT viewport-height
  /// worth of rows after each paint frame (quality program v3 item 50).
  ///
  /// When `true`, after the body painter finishes painting the current frame
  /// the grid schedules an idle microtask that evaluates the value getters
  /// for the rows just below the visible window (or above it, when scrolling
  /// up), writing the results into the value cache under the same
  /// (rowId, colId) keying the sort/filter pipeline and lazy row maps use.
  /// When the user then scrolls, those cells resolve from the cache instead
  /// of stalling on first-time getter evaluation.
  ///
  /// Pairs with [valueCacheEnabled]: the prefetched entries are only
  /// consumed (and expired on reprocess) while the value cache is enabled,
  /// so this parameter has no effect without it.
  ///
  /// Defaults to `false`.
  final bool prefetchEnabled;

  // --- Locale / i18n ---

  /// Locale text overrides for all grid UI strings.
  ///
  /// Provide an [OsLocaleText] instance to translate the grid's built-in
  /// text (pagination labels, filter operations, column menu items, etc.).
  ///
  /// When null, English defaults are used.
  ///
  /// ```dart
  /// OsGrid(
  ///   localeText: OsLocaleText(
  ///     noRowsToShow: 'Keine Zeilen vorhanden',
  ///     page: 'Seite',
  ///   ),
  ///   ...
  /// )
  /// ```
  final OsLocaleText? localeText;

  /// Optional callback for dynamic locale text resolution.
  ///
  /// When provided, this callback is called to resolve each locale key.
  /// It receives the key name and the default value (from [localeText] or
  /// the English default). Return the translated string.
  ///
  /// This is useful for integrating with external i18n libraries:
  /// ```dart
  /// OsGrid(
  ///   getLocaleText: (key, defaultValue) => myI18n.translate(key) ?? defaultValue,
  ///   ...
  /// )
  /// ```
  final String Function(String key, String defaultValue)? getLocaleText;

  // --- Event callbacks ---

  /// Called when the grid is fully initialised and ready for interaction.
  final ValueChanged<OsGridController<TData>>? onGridReady;

  /// Called when a row is selected or deselected.
  final ValueChanged<OsRowSelectedEvent<TData>>? onRowSelected;

  /// Called when a row is double-clicked.
  final ValueChanged<OsRowDoubleClickedEvent<TData>>? onRowDoubleClicked;

  /// Called when a cell is clicked.
  final ValueChanged<OsCellClickedEvent<TData>>? onCellClicked;

  /// Called post-frame when the focused cell changes (keyboard navigation,
  /// pointer-down focus, or [OsGridController.setFocusedCell]).
  ///
  /// Clearing the focus does not fire this callback. Also available as the
  /// [OsGridController.onCellFocused] stream.
  final ValueChanged<OsCellFocusedEvent>? onCellFocused;

  /// Called post-frame when a printable or navigation key is pressed while
  /// a cell is focused and the grid is not editing.
  ///
  /// Fires before the grid's built-in key handling; listeners are
  /// informational and cannot consume the key. Also available as the
  /// [OsGridController.onCellKeyDown] stream.
  final ValueChanged<OsCellKeyDownEvent>? onCellKeyDown;

  /// Called when a cell is double-clicked.
  final ValueChanged<OsCellClickedEvent<TData>>? onCellDoubleClicked;

  /// Called after a cell value has been changed via editing.
  final ValueChanged<OsCellValueChangedEvent<TData>>? onCellValueChanged;

  /// Called when cell editing starts.
  final ValueChanged<OsCellEditingStartedEvent<TData>>? onCellEditingStarted;

  /// Called when cell editing stops (committed or cancelled).
  final ValueChanged<OsCellEditingStoppedEvent<TData>>? onCellEditingStopped;

  /// Called when [readOnlyEdit] is enabled and the user commits an edit.
  ///
  /// The event contains the old and new values. The application should
  /// handle the data update externally and refresh the grid.
  final ValueChanged<OsCellEditRequestEvent<TData>>? onCellEditRequest;

  /// Called when the set of selected rows changes.
  final ValueChanged<OsSelectionChangedEvent<TData>>? onSelectionChanged;

  /// Called when the sort model changes.
  final ValueChanged<OsSortChangedEvent>? onSortChanged;

  /// Called when the filter model changes.
  final ValueChanged<OsFilterChangedEvent>? onFilterChanged;

  /// Called when a row is clicked (any cell in the row is tapped).
  final ValueChanged<OsRowClickedEvent<TData>>? onRowClicked;

  /// Called when pagination state changes (page navigation or page size).
  final ValueChanged<OsPaginationChangedEvent>? onPaginationChanged;

  /// Called when row data is updated via the controller.
  final ValueChanged<OsRowDataUpdatedEvent<TData>>? onRowDataUpdated;

  /// Called when the cell range selection changes.
  final ValueChanged<OsRangeSelectionChangedEvent>? onRangeSelectionChanged;

  /// Called when a chart definition is created from a range selection —
  /// via the chart palette popup (requires [enableIntegratedCharts]) or
  /// `controller.createChartRange()`. Render the event's
  /// [OsChartDefinition] with an `OsChartRenderer` (see the
  /// `os_grid_flutter_charts` companion package).
  final ValueChanged<OsChartRangeCreatedEvent>? onChartRangeCreated;

  /// Called when columns are shown or hidden.
  final ValueChanged<OsColumnVisibleEvent>? onColumnVisible;

  /// Called when columns are pinned or unpinned.
  final ValueChanged<OsColumnPinnedEvent>? onColumnPinned;

  /// Called when columns are resized.
  final ValueChanged<OsColumnResizedEvent>? onColumnResized;

  /// Called when columns are moved (reordered).
  final ValueChanged<OsColumnMovedEvent>? onColumnMoved;

  // --- Row drag event callbacks ---

  /// Called when a row drag operation enters the grid.
  final ValueChanged<OsRowDragEnterEvent<TData>>? onRowDragEnter;

  /// Called while a row is being dragged over the grid.
  final ValueChanged<OsRowDragMoveEvent<TData>>? onRowDragMove;

  /// Called when a row drag operation ends (the row is dropped).
  final ValueChanged<OsRowDragEndEvent<TData>>? onRowDragEnd;

  /// Called when a row drag operation leaves the grid area.
  final ValueChanged<OsRowDragLeaveEvent<TData>>? onRowDragLeave;

  /// Called when pinned row data changes (top or bottom).
  final ValueChanged<OsPinnedRowDataChangedEvent>? onPinnedRowDataChanged;

  /// Called before an undo operation is applied.
  final ValueChanged<OsUndoStartedEvent>? onUndoStarted;

  /// Called after an undo operation completes.
  final ValueChanged<OsUndoEndedEvent>? onUndoEnded;

  /// Called before a redo operation is applied.
  final ValueChanged<OsRedoStartedEvent>? onRedoStarted;

  /// Called after a redo operation completes.
  final ValueChanged<OsRedoEndedEvent>? onRedoEnded;

  // --- Clipboard event callbacks ---

  /// Called when a clipboard copy operation completes.
  final ValueChanged<OsClipboardCopyEvent>? onClipboardCopy;

  /// Called when a clipboard paste operation completes.
  final ValueChanged<OsClipboardPasteEvent>? onClipboardPaste;

  /// Called when a clipboard cut operation completes.
  final ValueChanged<OsClipboardCutEvent>? onClipboardCut;

  // --- Tooltip event callbacks ---

  /// Called when a tooltip is shown.
  final ValueChanged<OsTooltipShowEvent>? onTooltipShow;

  /// Called when a tooltip is hidden.
  final ValueChanged<OsTooltipHideEvent>? onTooltipHide;

  /// Called when the hovered column changes.
  ///
  /// Only fires when [columnHoverHighlight] is `true`. The event contains
  /// the column ID being hovered, or `null` when the pointer leaves.
  final ValueChanged<OsColumnHoverChangedEvent>? onColumnHoverChanged;

  /// Called when the grid state changes (debounced).
  ///
  /// The event includes the full state snapshot and a list of which
  /// properties triggered the update.
  final ValueChanged<OsStateUpdatedEvent>? onStateUpdated;

  /// Initial state to restore when the grid first renders.
  ///
  /// Provide a previously saved [OsGridState] to restore sort, filter,
  /// column state, pagination, selection, and scroll position.
  ///
  /// ```dart
  /// OsGrid(
  ///   initialState: savedState,
  ///   columnDefs: [...],
  ///   rowData: [...],
  /// )
  /// ```
  final OsGridState? initialState;

  // --- Aligned Grids ---

  /// Configuration for synchronising horizontal scroll with other grids.
  ///
  /// When provided, this grid's horizontal scroll position is synchronised
  /// with all other grids that share the same [OsAlignedGrid.groupId].
  /// Scrolling one grid horizontally will scroll all aligned grids to the
  /// same offset.
  ///
  /// ```dart
  /// OsGrid(
  ///   alignedGrids: OsAlignedGrid(groupId: 'my-group'),
  ///   columnDefs: [...],
  ///   rowData: [...],
  /// )
  /// ```
  final OsAlignedGrid? alignedGrids;

  // --- Infinite Row Model ---

  /// Configuration for the infinite row model.
  ///
  /// When set, the grid switches from client-side row model (using [rowData])
  /// to infinite row model (using a [datasource]). Data is loaded in blocks
  /// as the user scrolls, making it suitable for very large server-backed
  /// datasets.
  ///
  /// When this is set, [rowData] is ignored.
  ///
  /// ```dart
  /// OsGrid(
  ///   columnDefs: [...],
  ///   infiniteRowModel: const OsInfiniteRowModel(cacheBlockSize: 50),
  ///   datasource: MyDatasource(),
  /// )
  /// ```
  final OsInfiniteRowModel? infiniteRowModel;

  /// The datasource for the infinite row model.
  ///
  /// Required when [infiniteRowModel] is set. Provides data to the grid
  /// on demand via the [OsInfiniteDatasource.getRows] callback.
  ///
  /// The datasource can also be changed at runtime via
  /// [OsGridController.setDatasource].
  final OsInfiniteDatasource<TData>? datasource;

  // --- Server-Side Row Model ---

  /// The datasource for the server-side row model (SSRM).
  ///
  /// When set, the grid delegates sorting, filtering and grouping to the
  /// server: it requests blocks of rows at each group level (identified
  /// by group keys) as the user scrolls and expands groups. Group columns
  /// come from [groupBy] / `rowGroup` column definitions as usual, but
  /// the hierarchy itself is server-defined.
  ///
  /// When this is set it takes precedence over [rowData], [infiniteRowModel]
  /// and [datasource] — those are ignored.
  ///
  /// ```dart
  /// OsGrid(
  ///   columnDefs: [...],
  ///   groupBy: ['country'],
  ///   serverSideDatasource: MyServerSideDatasource(),
  /// )
  /// ```
  final OsServerSideDatasource<TData>? serverSideDatasource;

  /// Called when the infinite row model's virtual row count changes.
  ///
  /// Only fires when [infiniteRowModel] is set. The event includes the
  /// current row count and whether the total is definitively known.
  final ValueChanged<OsInfiniteRowCountChangedEvent>? onInfiniteRowCountChanged;

  /// Called when [OsGridController.expandAll] or [OsGridController.collapseAll]
  /// is invoked.
  ///
  /// Fires regardless of whether any rows actually changed state. When tree
  /// data or row grouping is not configured, the event still fires but no
  /// rows are affected.
  final ValueChanged<OsExpandOrCollapseAllEvent>? onExpandOrCollapseAll;

  // --- Row Grouping ---

  /// List of column IDs to group by (programmatic grouping).
  ///
  /// When provided, the grid groups rows by the unique values of these
  /// columns in order. This is an alternative to setting `rowGroup: true`
  /// on individual column definitions.
  ///
  /// If both `groupBy` and `OsColumnDef.rowGroup` are used, `groupBy`
  /// takes precedence.
  final List<String>? groupBy;

  /// Number of group levels to expand by default.
  ///
  /// - `null` or `0`: all groups collapsed (default)
  /// - `1`: first level expanded
  /// - `-1`: all levels expanded
  final int? groupDefaultExpanded;

  /// Callback fired when a single group row is expanded or collapsed.
  final ValueChanged<OsRowGroupOpenedEvent>? onRowGroupOpened;

  /// Enables tree data mode.
  ///
  /// When `true`, the grid skips the column-based row grouping pipeline
  /// and builds a hierarchy from [getDataPath] instead: each data row is
  /// placed under synthetic group nodes for its path segments, and every
  /// original row remains a leaf row.
  ///
  /// Requires [getDataPath]. Incompatible with `groupBy` / `rowGroup`
  /// columns — when combined, a validation warning is emitted in debug
  /// mode and tree data takes precedence (row grouping is ignored).
  ///
  /// ```dart
  /// OsGrid(
  ///   treeData: true,
  ///   getDataPath: (data) => data['path'] as List<Object>,
  ///   // ...
  /// )
  /// ```
  /// Configuration for the row group panel ('drop zone') visibility.
  final OsRowGroupPanelVisibility rowGroupPanelVisibility;

  /// Callback when the ordered list of grouped column IDs changes via the row group panel.
  final void Function(List<String>)? onRowGroupColumnsChanged;

  final bool treeData;

  /// Returns the ancestor path segments for a row (tree data mode).
  ///
  /// Each segment names one level of synthetic grouping; the row itself
  /// always becomes a leaf under the deepest segment. Rows returning an
  /// empty path are displayed at the root level. Required when
  /// [treeData] is `true`.
  ///
  /// ```dart
  /// getDataPath: (data) => [data['country'], data['city']],
  /// ```
  final List<Object>? Function(TData data)? getDataPath;

  // --- Pivot Mode ---

  /// Whether pivot mode is active.
  ///
  /// When `true`, the grid generates dynamic columns from the unique values
  /// of columns marked with `pivot: true`. Row groups define the row hierarchy
  /// and value columns (with `aggFunc`) define what's computed in each cell.
  ///
  /// Requires at least one row group column, one pivot column, and one value
  /// column to produce meaningful output.
  final bool pivotMode;

  /// Callback fired when pivot mode is toggled via the controller.
  final ValueChanged<OsPivotModeChangedEvent>? onPivotModeChanged;

  // --- Validation ---
  ///
  /// When `false` (default), the grid validates its configuration in debug
  /// mode and logs warnings for common mistakes (e.g. contradictory options,
  /// missing callbacks). Set to `true` to silence these warnings.
  ///
  /// Validation never runs in release builds regardless of this setting.
  final bool suppressGridOptionsValidation;

  // --- Side Bar ---

  // --- Column menu ---

  /// Tabbed column menu configuration.
  ///
  /// When provided, the column header ⋮ icon opens a tabbed popup with
  /// up to three tabs: General (sort/pin/autosize), Filter, and Columns
  /// (visibility checkboxes). This replaces the simple flat menu.
  ///
  /// When `null` (default), the simple flat column menu is used.
  ///
  /// ```dart
  /// OsGrid(
  ///   columnMenu: const OsColumnMenuDef(),
  ///   // ...
  /// )
  /// ```
  final OsColumnMenuDef? columnMenu;

  /// Side bar configuration. When provided, a collapsible side panel is
  /// shown next to the grid with tool panels (e.g. Columns, Filters).
  ///
  /// Use [OsSideBarDef.defaultPanels] for both Columns and Filters panels,
  /// or [OsSideBarDef.columns] / [OsSideBarDef.filters] for individual ones.
  ///
  /// ```dart
  /// OsGrid(
  ///   sideBar: OsSideBarDef.defaultPanels(),
  ///   // ...
  /// )
  /// ```
  final OsSideBarDef? sideBar;

  /// Callback when a tool panel's visibility changes (opens or closes).
  final void Function(OsToolPanelVisibleChangedEvent event)?
  onToolPanelVisibleChanged;

  /// Callback when the side bar state is updated.
  final void Function(OsSideBarUpdatedEvent event)? onSideBarUpdated;

  // --- Context menu ---

  /// When `true`, disables the right-click context menu entirely.
  ///
  /// Defaults to `false`. When suppressed, right-clicking does nothing.
  /// Per-column suppression is available via [OsColumnDef.suppressMenu].
  final bool suppressContextMenu;

  /// When `true`, clicking a data cell no longer changes the row selection
  /// (quality program v2 item 14, mirroring AG Grid's flag of the same name).
  ///
  /// Checkbox-column selection and programmatic selection
  /// ([OsGridController.selectAll] etc.) keep working. `cellClicked` /
  /// `rowClicked` events still fire.
  final bool suppressRowClickSelection;

  /// When `true`, tapping a data cell never moves the cell focus: the grid
  /// does not request keyboard focus on pointer down and the visual focus
  /// cursor stays parked (quality program v2 item 14).
  ///
  /// The focused-cell API value is retained — [OsGridController.getFocusedCell]
  /// keeps returning the last focused cell. Programmatic focus via
  /// [OsGridController.setFocusedCell] and keyboard navigation on an
  /// already-focused grid still work.
  final bool suppressCellFocus;

  /// Callback to customise the context menu items shown on right-click.
  ///
  /// Receives [GetContextMenuItemsParams] with information about the
  /// right-clicked cell. Return a list of [OsContextMenuItem] to show
  /// a custom menu, return `null` to show the default menu, or return
  /// an empty list to suppress the menu for that cell.
  ///
  /// ```dart
  /// OsGrid(
  ///   getContextMenuItems: (params) => [
  ///     OsContextMenuItem.copy,
  ///     OsContextMenuItem.separator,
  ///     OsContextMenuItem(
  ///       name: 'Alert',
  ///       icon: Icons.warning,
  ///       action: () => print('Clicked on ${params.value}'),
  ///     ),
  ///   ],
  /// )
  /// ```
  final List<OsContextMenuItem>? Function(
    GetContextMenuItemsParams<TData> params,
  )?
  getContextMenuItems;

  /// Called when a right-click (context menu) occurs on a data cell.
  ///
  /// Fires before the context menu is shown. Call [OsCellContextMenuEvent.preventDefault]
  /// on the event to suppress the default menu.
  final void Function(OsCellContextMenuEvent<TData> event)? onCellContextMenu;

  // --- Static module registration ---

  /// Globally registered modules available to all grid instances.
  static final List<OsModule> _globalModules = [];

  /// Register modules globally so they are available to all [OsGrid] instances.
  ///
  /// Call this once at app startup:
  /// ```dart
  /// void main() {
  ///   OsGrid.registerModules([ClipboardModule(), EditingModule()]);
  ///   runApp(MyApp());
  /// }
  /// ```
  ///
  /// Registering any module switches the grid to an opt-in feature model:
  /// only features whose module is registered (globally or per instance
  /// via [OsGrid.modules]) are enabled; everything else is ignored with a
  /// debug-mode warning. When nothing is registered, all features are
  /// implicitly enabled.
  static void registerModules(List<OsModule> modules) {
    _globalModules.addAll(modules);
  }

  /// Clears all globally registered modules.
  ///
  /// Primarily useful in tests to reset global module state.
  static void clearRegisteredModules() => _globalModules.clear();

  @override
  State<OsGrid<TData>> createState() => _OsGridState<TData>();
}

class _OsGridState<TData> extends State<OsGrid<TData>>
    with SingleTickerProviderStateMixin {
  late OsGridController<TData> _controller;
  bool _ownsController = false;

  // TextPainter cache for reusing painters across frames.
  // We use a fixed capacity of 2000 entries to provide headroom for dense viewports
  // (e.g. 4K displays). Undersizing the cache degrades gracefully to re-layout on scroll
  // (misses cost layout performance, not correctness), so a dynamic size is unnecessary.
  final TextPainterCache _textPainterCache = TextPainterCache(maxSize: 2000);

  @visibleForTesting
  TextPainterCache get textPainterCacheForTesting => _textPainterCache;

  /// Effective row height — uses theme value if available, otherwise widget prop.
  double get _effectiveRowHeight => widget.theme?.rowHeight ?? widget.rowHeight;

  /// Effective header height — uses theme value if available, otherwise widget prop.
  double get _effectiveHeaderHeight =>
      widget.theme?.headerHeight ?? widget.headerHeight;

  /// Whether tree-data mode is active: requires both the `treeData`
  /// parameter and the TreeDataModule to be enabled. When an explicit
  /// module registry excludes TreeDataModule, the parameter is ignored
  /// with a debug-mode warning.
  bool get _treeDataActive {
    if (!widget.treeData) return false;
    if (_treeDataModuleEnabled) return true;
    GridDiagnostics.warnOnce(
      'module:gated:treeData',
      'treeData is ignored: register TreeDataModule (via the modules '
          'parameter or OsGrid.registerModules) to enable tree data.',
    );
    return false;
  }

  // Sort state — multi-column sort service
  late final SortService<TData> _sortService;

  /// Backwards-compatible: returns the single sorted column index for the painter,
  /// or null if no sort or multi-sort is active.
  int? get _sortColumnIndex =>
      _sortService.sortModel.isEmpty ? null : _legacySortColumnIndex;
  int? _legacySortColumnIndex;
  bool get _sortAscending => _sortService.sortModel.isEmpty
      ? true
      : _sortService.sortModel.first.sort == OsSortDirection.ascending;

  // Quick filter override (set via controller.setQuickFilter(), takes precedence over widget prop)
  String? _quickFilterOverride;

  // --- Module lifecycle ---

  /// Effective module registry for this instance: globally registered
  /// modules plus the per-instance `modules` widget parameter. Resolved
  /// once in initState; module sets are expected to stay stable for the
  /// lifetime of the grid.
  late final List<OsModule> _registeredModules;

  /// Whether an explicit module registry is in effect. When false, every
  /// feature is implicitly enabled (backwards-compatible default).
  bool get _hasExplicitModules => _registeredModules.isNotEmpty;

  /// Per-feature enablement flags derived from the registry in initState.
  late final bool _clipboardEnabled;
  late final bool _editingEnabled;
  late final bool _treeDataModuleEnabled;
  late final bool _sparklineModuleEnabled;
  late final bool _setFilterModuleEnabled;

  /// Finds the first registered module of type [T], or null.
  T? _findModule<T extends OsModule>() {
    for (final module in _registeredModules) {
      if (module is T) return module;
    }
    return null;
  }

  // Data pipeline coordinator (created in initState)
  late final DataPipelineCoordinator<TData> _pipeline;

  // Column API coordinator (created in initState; owns width/pin/hide/order)
  late final ColumnApiCoordinator<TData> _columns;

  // Compatibility accessors over the coordinator-owned maps so existing
  // call sites keep working unchanged.
  Map<String, double> get _columnWidths => _columns.widths;
  Map<String, OsColumnPin?> get _columnPinOverrides => _columns.pins;
  Set<String> get _hiddenColumnIds => _columns.hiddenIds;
  List<String>? get _columnOrder => _columns.order;

  /// Column definitions installed at runtime by
  /// `controller.setColumnDefs`, which shadow [OsGrid.columnDefs] until the
  /// host passes a different list.
  List<OsColumnDefBase>? _columnDefsOverride;

  /// The definitions the grid actually renders: the runtime override when
  /// one is installed, otherwise the widget's own list.
  List<OsColumnDefBase> get _effectiveColumnDefs =>
      _columnDefsOverride ?? widget.columnDefs;

  /// Width of the centre (unpinned) viewport, reported by the render layer
  /// once it has been laid out. Null before the first layout pass — this is
  /// what `sizeColumnsToFit` needs and what `onGridSizeChanged` does not
  /// report on the first frame.
  double? _centreViewportWidth;

  /// Whether a deferred `sizeColumnsToFit` is already queued, so repeated
  /// calls before the first layout only schedule one pass.
  bool _sizeColumnsToFitScheduled = false;

  /// Replaces the rendered column definitions at runtime.
  ///
  /// Backs `controller.setColumnDefs`. View state (widths, pins, visibility,
  /// order) for columns that survive the swap is preserved; state for
  /// removed columns is dropped so it cannot leak onto a later column that
  /// reuses the colId.
  void _setColumnDefs(List<OsColumnDefBase> defs) {
    if (!mounted) return;

    final flatNewCols = <OsColumnDef>[];
    final tempSpans = <ColumnGroupSpan>[];
    _flattenColumnDefs(defs, flatNewCols, tempSpans);

    setState(() {
      _columnDefsOverride = defs;
      _columns.pruneTo(flatNewCols);
    });

    // Point the controller's query surface at the new definitions.
    _controller.columnDefs = defs.whereType<OsColumnDef>().toList();
    _syncColumnStateToController();

    // Re-apply `hide: true` from the new definitions and re-run the
    // pipeline: grouping, pivot and filter column queries all read the
    // rendered definitions.
    _initHiddenColumnsFromDefs();
    _reprocessData();

    // Drop grouping state for columns that no longer exist.
    _pruneGroupedColumns(flatNewCols);
  }

  /// Removes grouped columns whose definition has disappeared, notifying
  /// the host exactly once when the grouping actually changed.
  void _pruneGroupedColumns(List<OsColumnDef> flatCols) {
    final validIds = flatCols.map((c) => c.effectiveColId).toSet();
    final override = _groupByOverride;
    if (override == null) return;
    final cleaned = override.where((id) => validIds.contains(id)).toList();
    if (cleaned.length == override.length) return;
    _groupByOverride = cleaned.isEmpty ? null : cleaned;
    widget.onRowGroupColumnsChanged?.call(_groupByOverride ?? []);
  }

  /// Distributes the centre viewport width across the unpinned columns.
  ///
  /// Backs `controller.sizeColumnsToFit`. When the grid has not been laid
  /// out yet (a call from `onGridReady` runs during `initState`) the work is
  /// deferred to the first frame that has a viewport width.
  void _sizeColumnsToFit() {
    if (!mounted) return;

    final centreWidth = _centreViewportWidth;
    if (centreWidth == null) {
      if (_sizeColumnsToFitScheduled) return;
      _sizeColumnsToFitScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _sizeColumnsToFitScheduled = false;
        if (!mounted) return;
        // The render layer reports the width during layout, so by the time
        // this callback runs it is available.
        _sizeColumnsToFit();
      });
      return;
    }

    _columns.sizeColumnsToFit(centreWidth);
  }

  // Clipboard coordinator (created in initState when the clipboard feature
  // is enabled; null when an explicit module registry excludes it).
  ClipboardCoordinator<TData>? _clipboard;

  // Undo/redo coordinator (created in initState)
  late final UndoRedoCoordinator<TData> _undoRedo;

  /// Compatibility accessor for editor commit paths until editing is fully
  /// extracted into its own coordinator.
  UndoRedoService? get _undoRedoService => _undoRedo.service;

  // Column drag-reorder coordinator (created in initState)
  late final ColumnDragCoordinator<TData> _columnDrag;

  // Row drag-reorder coordinator (created in initState)
  late final RowDragCoordinator<TData> _rowDrag;

  // Processed row data (after filter + sort)
  List<TData>? _processedRowData;

  // Row grouping service and state
  final RowGroupService<TData> _rowGroupService = RowGroupService<TData>();
  final TreeDataService<TData> _treeDataService = TreeDataService<TData>();
  final RowGroupState _rowGroupState = RowGroupState();
  List<String>? _groupByOverride;
  final GlobalKey<RowGroupPanelState> _rowGroupPanelKey =
      GlobalKey<RowGroupPanelState>();

  // Master/detail expansion state (RowGroupState pattern, keyed by row id)
  final DetailExpansionState _detailExpansion = DetailExpansionState();

  /// Number of synthetic detail rows currently present in
  /// [_displayRowData]. Zero when master/detail is inactive or nothing is
  /// expanded — drives the display→source index rebasing below.
  int _displayDetailRowCount = 0;

  // Aggregation: programmatic value column override
  List<String>? _valueColumnOverride;

  // Aggregation: per-column aggFunc overrides (from controller.setColumnAggFunc)
  final Map<String, String?> _aggFuncOverrides = {};

  // Pivot mode state
  final PivotService<TData> _pivotService = PivotService<TData>();
  bool _pivotModeOverride = false;
  List<String>? _pivotColumnOverride;

  /// The last computed pivot result (column definitions generated from pivot).
  /// Used by the controller to query generated pivot column metadata.
  PivotResult? _lastPivotResult;

  // Current display row data (after grouping + pagination), used for
  // hit testing to identify group rows.
  List<Map<String, dynamic>> _displayRowData = [];

  // Cached flat columns list (updated in build, used by _handleEditStartRequested)
  List<OsColumnDef> _flatColumnsCache = [];

  // Pagination state
  int _currentPage = 0;
  late int _pageSize;

  // Cell flash animation coordinator (created in initState)
  late final CellFlashCoordinator _cellFlashCoordinator;

  // Tooltip service
  late TooltipService _tooltipService;

  // Cell span service
  final CellSpanService _cellSpanService = CellSpanService();

  // Value cache (lazily populated when valueCacheEnabled is true)
  final ValueCache _valueCache = ValueCache();

  // Scroll offset at the last idle-time prefetch (quality program v3
  // item 50) — drives scroll-direction inference for the prefetch window.
  double? _lastPrefetchScrollY;

  // Grid state service
  GridStateService<TData>? _gridStateService;
  StreamSubscription<OsStateUpdatedEvent>? _stateUpdatedSubscription;
  StreamSubscription<dynamic>? _selectionStateSubscription;
  StreamSubscription<OsRangeSelectionChangedEvent>? _rangeSelectionSubscription;
  final ValueNotifier<Offset> _scrollPositionNotifier = ValueNotifier(
    Offset.zero,
  );
  final ValueNotifier<({int row, int col})> _focusedCellNotifier =
      ValueNotifier((row: 0, col: 0));

  /// Last focused cell reported by the grid, or null when nothing has been
  /// focused yet (before the first interaction or after clearFocusedCell).
  ({int rowIndex, int columnIndex})? _trackedFocusedCell;

  // Aligned grids coordinator (created in initState once controller exists)
  late final AlignedGridCoordinator _alignedGridCoordinator;

  // Infinite row model cache
  InfiniteBlockCache<TData>? _infiniteCache;

  // Server-side row model
  ServerSideRowModel<TData>? _serverSideModel;

  // Immutable data service (for diffing rowData changes by ID)
  ImmutableDataService<TData>? _immutableDataService;

  // Async transaction service (for batching rapid-fire transactions)
  AsyncTransactionService<TData>? _asyncTransactionService;

  // Delta sort service (for incremental sorting after transactions)
  DeltaSortService<TData>? _deltaSortService;

  // Tracks the last set of touched rows from a transaction (for delta sort)
  Set<TData>? _lastTransactionTouchedRows;

  // --- Side bar state ---
  String? _openToolPanelId;
  bool _sideBarVisible = true;

  @override
  void didUpdateWidget(covariant OsGrid<TData> oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Clear TextPainter cache when theme changes (font/size may differ)
    if (widget.theme != oldWidget.theme) {
      _textPainterCache.clear();
    }

    // Handle controller change
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?.removeListener(_onControllerChanged);
      if (_ownsController) {
        _controller.dispose();
      }
      if (widget.controller != null) {
        _controller = widget.controller!;
        _ownsController = false;
      } else {
        _controller = OsGridController<TData>();
        _ownsController = true;
      }
      // Re-point every collaborator that captured the previous controller
      // instance BEFORE re-binding the controller callbacks: the
      // state-level wiring below assigns request hooks onto the coordinators'
      // captured reference, so a stale reference would leave the grid
      // half-wired to the disposed controller (emissions would throw from
      // its closed event bus).
      _pipeline.rebind(_controller);
      _columns.rebind(_controller);
      _undoRedo.rebind(_controller);
      _editing.rebind(_controller);
      _rowDrag.rebind(_controller);
      _clipboard?.rebind(_controller);
      _gridStateService?.rebind(_controller);
      _bindControllerCallbacks();
    }

    // Sync getRowId and rowSelection if they changed
    if (widget.getRowId != oldWidget.getRowId) {
      _controller.getRowId = widget.getRowId;
    }
    if (widget.rowSelection != oldWidget.rowSelection) {
      _controller.rowSelection = widget.rowSelection;
    }

    // Sync locale if it changed
    if (widget.localeText != oldWidget.localeText) {
      _controller.localeText = widget.localeText;
    }
    if (widget.getLocaleText != oldWidget.getLocaleText) {
      _controller.getLocaleTextCallback = widget.getLocaleText;
    }

    // Sync expand/collapse callback if it changed
    if (widget.onExpandOrCollapseAll != oldWidget.onExpandOrCollapseAll) {
      _controller.onExpandOrCollapseAllCallback = widget.onExpandOrCollapseAll;
    }

    // Sync column defs if they changed. A host-driven change wins over an
    // override installed by `controller.setColumnDefs`, so it is dropped
    // here and the widget's definitions take over again.
    if (widget.columnDefs != oldWidget.columnDefs) {
      _columnDefsOverride = null;
      _controller.columnDefs = _effectiveColumnDefs
          .whereType<OsColumnDef>()
          .toList();
      _syncColumnStateToController();

      // Auto-remove any grouped columns whose definition is deleted
      final flatNewCols = <OsColumnDef>[];
      final tempSpans2 = <ColumnGroupSpan>[];
      _flattenColumnDefs(_effectiveColumnDefs, flatNewCols, tempSpans2);
      final validIds = flatNewCols.map((c) => c.effectiveColId).toSet();

      if (_groupByOverride != null) {
        final cleanedOverride = _groupByOverride!
            .where((id) => validIds.contains(id))
            .toList();
        if (cleanedOverride.length != _groupByOverride!.length) {
          _groupByOverride = cleanedOverride.isEmpty ? null : cleanedOverride;
          widget.onRowGroupColumnsChanged?.call(_groupByOverride ?? []);
        }
      } else {
        // Groups may come from rowGroup:true column defs; if any were removed,
        // fire the callback with the remaining grouped columns.
        final flatOldCols = <OsColumnDef>[];
        final tempSpans3 = <ColumnGroupSpan>[];
        _flattenColumnDefs(oldWidget.columnDefs, flatOldCols, tempSpans3);
        final oldGroupIds = flatOldCols
            .where((c) => c.rowGroup == true)
            .map((c) => c.effectiveColId)
            .toSet();
        final newGroupIds = flatNewCols
            .where((c) => c.rowGroup == true)
            .map((c) => c.effectiveColId)
            .toSet();
        if (!oldGroupIds.containsAll(newGroupIds) ||
            !newGroupIds.containsAll(oldGroupIds)) {
          widget.onRowGroupColumnsChanged?.call(newGroupIds.toList());
        }
      }
    }

    // Sync accentedSort option
    if (widget.accentedSort != oldWidget.accentedSort) {
      _sortService.accentedSort = widget.accentedSort;
      if (_sortService.isSortActive) {
        _reprocessData();
      }
    }

    // Sync row data changes
    if (widget.rowData != oldWidget.rowData && widget.rowData != null) {
      // Emit row data changed BEFORE the pipeline processes the new list.
      // Stream .add only (broadcast streams deliver asynchronously), so
      // listeners are safe to call setState; the widget callback is
      // documented as synchronous and must not rebuild.
      if (!identical(widget.rowData, oldWidget.rowData)) {
        final rowDataChangedEvent = OsRowDataChangedEvent<TData>(
          rowData: widget.rowData,
        );
        widget.onRowDataChanged?.call(rowDataChangedEvent);
        _controller.emitRowDataChanged(rowDataChangedEvent);
      }

      if (_immutableDataService != null && oldWidget.rowData != null) {
        // Immutable data mode: diff by ID and apply minimal transaction.
        final diff = _immutableDataService!.computeDiff(
          oldData: oldWidget.rowData!,
          newData: widget.rowData!,
        );
        if (diff.hasChanges || diff.orderChanged) {
          final transaction = OsRowTransaction<TData>(
            add: diff.adds.isEmpty ? null : diff.adds,
            remove: diff.removes.isEmpty ? null : diff.removes,
            update: diff.updates.isEmpty ? null : diff.updates,
          );
          final touched = _controller.applyTransaction(transaction);
          _lastTransactionTouchedRows = touched;
          _reprocessData();
          _undoRedoService?.clearStacks();
        } else if (!identical(widget.rowData, oldWidget.rowData)) {
          // Data reference changed but content is identical — still update.
          _controller.setRowData(widget.rowData!);
          _reprocessData();
        }
      } else {
        // No immutable mode: full replacement.
        _controller.setRowData(widget.rowData!);
        _reprocessData();
        _undoRedoService?.clearStacks();
      }

      // Emit row data updated callback
      widget.onRowDataUpdated?.call(
        OsRowDataUpdatedEvent<TData>(
          rowData: widget.rowData!,
          rowCount: widget.rowData!.length,
        ),
      );
    }

    // Sync pinned row data changes
    if (widget.pinnedTopRowData != oldWidget.pinnedTopRowData ||
        widget.pinnedBottomRowData != oldWidget.pinnedBottomRowData) {
      _syncPinnedRowDataToController();
      final event = OsPinnedRowDataChangedEvent(
        pinnedTopRowCount: widget.pinnedTopRowData?.length ?? 0,
        pinnedBottomRowCount: widget.pinnedBottomRowData?.length ?? 0,
      );
      widget.onPinnedRowDataChanged?.call(event);
      _controller.emitPinnedRowDataChanged(event);
    }

    // Sync infinite row model datasource changes
    if (widget.datasource != oldWidget.datasource &&
        widget.datasource != null &&
        _isInfiniteMode) {
      _infiniteCache?.dispose();
      _infiniteCache = InfiniteBlockCache<TData>(
        config: widget.infiniteRowModel!,
        datasource: widget.datasource!,
        onRowCountChanged: _onInfiniteRowCountChanged,
        onBlockLoaded: _onInfiniteBlockLoaded,
      );
      _infiniteCache!.init();
    }

    // Sync infinite row model config changes
    if (widget.infiniteRowModel != oldWidget.infiniteRowModel) {
      if (widget.infiniteRowModel != null && widget.datasource != null) {
        _infiniteCache?.dispose();
        _infiniteCache = InfiniteBlockCache<TData>(
          config: widget.infiniteRowModel!,
          datasource: widget.datasource!,
          onRowCountChanged: _onInfiniteRowCountChanged,
          onBlockLoaded: _onInfiniteBlockLoaded,
        );
        _infiniteCache!.init();
      } else if (widget.infiniteRowModel == null) {
        _infiniteCache?.dispose();
        _infiniteCache = null;
      }
    }

    // Sync server-side row model datasource changes
    if (widget.serverSideDatasource != oldWidget.serverSideDatasource) {
      _serverSideModel?.dispose();
      _initServerSideRowModel();
      // Item 25: bare setState kept — same rationale as the infinite
      // datasource swap above (whole row source behind a CustomPaint).
      setState(() {});
    }

    // Reprocess if filter text changed
    if (widget.quickFilterText != oldWidget.quickFilterText) {
      // Widget prop change clears any controller override
      _quickFilterOverride = null;
      _controller.quickFilterText = widget.quickFilterText;
      _reprocessData();

      // Emit filter changed event
      final filterModel = <String, dynamic>{};
      if (widget.quickFilterText != null &&
          widget.quickFilterText!.isNotEmpty) {
        filterModel['quickFilter'] = widget.quickFilterText;
      }
      final filterEvent = OsFilterChangedEvent(filterModel: filterModel);
      widget.onFilterChanged?.call(filterEvent);
      _controller.emitFilterChanged(filterEvent);
    }

    // Reprocess if external filter callbacks changed
    if (widget.isExternalFilterPresent != oldWidget.isExternalFilterPresent ||
        widget.doesExternalFilterPass != oldWidget.doesExternalFilterPass) {
      _reprocessData();
      _emitFilterChangedEvent();
    }

    // Re-run validation if configuration changed
    if (!widget.suppressGridOptionsValidation) {
      OsGridValidator.validate(
        columnDefs: _effectiveColumnDefs,
        rowData: widget.rowData,
        rowSelection: widget.rowSelection,
        cellSelection: widget.cellSelection,
        pagination: widget.pagination,
        undoRedoCellEditing: widget.undoRedoCellEditing,
        singleClickEdit: widget.singleClickEdit,
        suppressClickEdit: widget.suppressClickEdit,
        enterNavigatesVertically: widget.enterNavigatesVertically,
        enterNavigatesVerticallyAfterEdit:
            widget.enterNavigatesVerticallyAfterEdit,
        floatingFilter: widget.floatingFilter,
        rowDrag: widget.rowDrag,
        rowDragManaged: widget.rowDragManaged,
        getRowId: widget.getRowId,
        onRowDragEnd: widget.onRowDragEnd,
        treeData: _treeDataActive,
        getDataPath: widget.getDataPath,
        groupBy: widget.groupBy,
      );
    }

    // Handle aligned grids configuration change
    if (widget.alignedGrids != oldWidget.alignedGrids) {
      _alignedGridCoordinator
        ..detach()
        ..attach();
    }
  }

  /// Binds controller listeners and imperative-API callbacks.
  ///
  /// Called once from initState and again whenever the controller instance
  /// is swapped in didUpdateWidget.
  void _bindControllerCallbacks() {
    _controller.addListener(_onControllerChanged);
    _controller.getRowId = widget.getRowId;
    _controller.rowSelection = widget.rowSelection;
    _controller.localeText = widget.localeText;
    _controller.getLocaleTextCallback = widget.getLocaleText;
    _controller.onPageChangeRequested = (page) {
      setState(() => _currentPage = page);
      _scheduleModelUpdated();
    };
    _controller.onPageSizeChangeRequested = (size) {
      setState(() {
        _pageSize = size;
        _currentPage = 0;
      });
      _scheduleModelUpdated();
    };
    _wireColumnApiCallbacks();
    _wireEditingApiCallbacks();
    _controller.onExpandOrCollapseAllCallback = widget.onExpandOrCollapseAll;
    _controller.onFlashCellsRequested = _cellFlashCoordinator.handle;
    _controller.onSetSortModelRequested = (model) {
      setState(() {
        _sortService.setSortModel(model);
        _deltaSortService?.invalidate();
        _legacySortColumnIndex = null;
        _reprocessData();
      });
      _emitSortChanged();
    };
    _controller.onGetSortModelRequested = () => _sortService.sortModel;
    _controller.onSetColumnDefsRequested = _setColumnDefs;
    _controller.onSizeColumnsToFitRequested = _sizeColumnsToFit;
    _wireFocusApiCallbacks();
    _syncColumnStateToController();
  }

  /// Wires the focused-cell API (quality program v2 item 11): the
  /// controller reads the tracked focused cell and issues focus commands
  /// through the grid's command notifier.
  void _wireFocusApiCallbacks() {
    _controller.onGetFocusedCellRequested = () => _trackedFocusedCell;
    _controller.onSetFocusedCellRequested = (rowIndex, columnIndex) {
      // Track optimistically (the grid clamps to bounds and confirms via
      // the focused-cell notifier when the position differs from the
      // current cursor). Skipped when there is nothing to focus.
      if (_displayRowData.isNotEmpty) {
        _trackedFocusedCell = (rowIndex: rowIndex, columnIndex: columnIndex);
      }
      _controller.focusCommandNotifier.value = SetFocusedCellCommand(
        rowIndex: rowIndex,
        columnIndex: columnIndex,
      );
    };
    _controller.onClearFocusedCellRequested = () {
      _trackedFocusedCell = null;
      _controller.focusCommandNotifier.value = const ClearFocusedCellCommand();
    };
  }

  /// Tracks the focused cell reported by the grid so the controller's
  /// `getFocusedCell` can return it. Null until a cell is actually focused.
  void _onFocusedCellNotifierChanged() {
    final value = _focusedCellNotifier.value;
    _trackedFocusedCell = (rowIndex: value.row, columnIndex: value.col);
  }

  /// Handles a post-frame focused-cell change from the grid: fires the
  /// widget callback and the controller stream.
  void _handleCellFocused(OsCellFocusedEvent event) {
    widget.onCellFocused?.call(event);
    _controller.emitCellFocused(event);
  }

  /// Handles a post-frame cell key-down from the grid: fires the widget
  /// callback and the controller stream.
  void _handleCellKeyDown(OsCellKeyDownEvent event) {
    widget.onCellKeyDown?.call(event);
    _controller.emitCellKeyDown(event);
  }

  /// Unknown column-type names already warned about (one warning per name).
  final Set<String> _warnedUnknownColumnTypes = {};

  /// Warns once per unknown name referenced by any colDef's `type`.
  void _warnUnknownColumnTypes() {
    final types = widget.columnTypes;
    if (types == null) return;
    for (final col in _effectiveColumnDefs.whereType<OsColumnDef>()) {
      for (final name in ColumnDefResolver.unknownTypeNames(
        typeSpec: col.type,
        columnTypes: types,
      )) {
        if (_warnedUnknownColumnTypes.add(name)) {
          GridDiagnostics.warnOnce(
            'columnType:$name',
            'Unknown column type "$name" (not found in columnTypes)',
          );
        }
      }
    }
  }

  /// Warns once per colId when a RESOLVED column has neither `field` nor
  /// `valueGetter` (replaces the former ctor assert, which blocked partial
  /// definitions such as defaultColDef/columnTypes entries).
  void _warnColumnsMissingField(List<OsColumnDef> columns) {
    for (final col in columns) {
      if (col.field != null || col.valueGetter != null) continue;
      final key = 'nofield:${col.effectiveColId}';
      if (_warnedUnknownColumnTypes.add(key)) {
        GridDiagnostics.warnOnce(
          key,
          'Column "${col.effectiveColId}" has neither field nor valueGetter',
        );
      }
    }
  }

  void _onControllerChanged() {
    // Import externally-set filter models (controller.setFilterModel) into
    // the typed per-column filter state so programmatic filtering affects
    // the client-side pipeline, not just state capture.
    _importControllerFilterModel();
    // Controller state changed (e.g. selectAll called) — rebuild.
    // Item 25: kept as a bare setState deliberately. This listener fans in
    // from every controller mutation (selection, filters, row data, pinned
    // rows, ...); build() consumers span the painter, selection chrome,
    // status bar and semantics, so a targeted rebuild would require routing
    // each mutation class to its own listener — full reactive-refactor
    // territory (item 10), not a trivially safe narrowing.
    if (mounted) setState(() {});
  }

  /// Last controller filter model observed by [_importControllerFilterModel].
  Map<String, dynamic>? _lastControllerFilterModel;

  /// Parses `controller.getFilterModel()` into the internal typed filter
  /// state used by the sort/filter pipeline.
  ///
  /// Values may be JSON maps (parsed via [OsColumnFilterModel.fromJson]) or
  /// already-typed [OsColumnFilterModel] instances. A `null` entry clears a
  /// column's filter. Custom-filter models are routed to the custom store.
  void _importControllerFilterModel() {
    final json = _controller.getFilterModel();
    if (_mapEqualsShallow(json, _lastControllerFilterModel)) return;
    _lastControllerFilterModel = json == null ? null : Map.of(json);

    if (json == null) {
      if (_columnFilterModels.isEmpty && _customFilterModels.isEmpty) return;
      _columnFilterModels.clear();
      _customFilterModels.clear();
      _columnFilterTexts.clear();
      _columnFilterOperations.clear();
      _reprocessData();
      return;
    }

    for (final entry in json.entries) {
      final colId = entry.key;
      final value = entry.value;
      if (value == null) {
        _columnFilterModels.remove(colId);
        _customFilterModels.remove(colId);
        continue;
      }

      final OsColumnFilterModel model;
      if (value is OsColumnFilterModel) {
        model = value;
      } else if (value is Map<String, dynamic>) {
        model = OsColumnFilterModel.fromJson(value);
      } else {
        continue; // Unsupported model shape — ignore
      }

      if (model.filterType == 'custom') {
        _columnFilterModels.remove(colId);
        _customFilterModels[colId] = value;
      } else {
        _customFilterModels.remove(colId);
        _columnFilterModels[colId] = model;
        if (model.filterType == 'set') {
          _columnFilterOperations.remove(colId);
          _columnFilterTexts[colId] = '${model.values?.length ?? 0} selected';
        } else if (model.conditions.isNotEmpty) {
          final firstCondition = model.conditions.first;
          _columnFilterOperations[colId] = firstCondition.type;
          _columnFilterTexts[colId] = firstCondition.filter?.toString() ?? '';
        }
      }
    }
    _reprocessData();
  }

  bool _mapEqualsShallow(Map<String, dynamic>? a, Map<String, dynamic>? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || a[key] != b[key]) return false;
    }
    return true;
  }

  void _onTooltipStateChanged() {
    if (!mounted) return;
    final service = _tooltipService;
    if (service.state == OsTooltipState.showing) {
      // Tooltip just became visible — emit show event
      final event = OsTooltipShowEvent(
        value: service.tooltipValue ?? '',
        location: service.tooltipLocation ?? TooltipLocation.cell,
        rowIndex: _tooltipRowIndex,
        colId: _tooltipColId,
      );
      widget.onTooltipShow?.call(event);
      _controller.emitTooltipShow(event);
    } else if (service.state == OsTooltipState.nothing && _wasShowingTooltip) {
      // Tooltip just became hidden — emit hide event
      final event = OsTooltipHideEvent(
        location: _lastTooltipLocation,
        colId: _lastTooltipColId,
      );
      widget.onTooltipHide?.call(event);
      _controller.emitTooltipHide(event);
    }
    _wasShowingTooltip = service.state == OsTooltipState.showing;
    if (_wasShowingTooltip) {
      _lastTooltipLocation = service.tooltipLocation;
      _lastTooltipColId = _tooltipColId;
    }
    // Item 25: no bare setState here. The only build-time consumer of the
    // tooltip service is the tooltip overlay entry, which subscribes to
    // [TooltipService.stateChangeNotifier] directly via a scoped
    // ValueListenableBuilder — the event emissions above must still run on
    // every state transition regardless of any visual rebuild.
  }

  // Tooltip tracking state
  bool _wasShowingTooltip = false;
  TooltipLocation? _lastTooltipLocation;
  String? _lastTooltipColId;
  int? _tooltipRowIndex;
  String? _tooltipColId;

  // Column hover tracking state (for event emission)
  String? _lastHoveredColId;

  /// Handles hover changes from the VirtualisedGrid for tooltip integration.
  void _handleHoverChanged(GridHitTestResult? hit, Offset position) {
    // --- Column hover event emission ---
    if (widget.columnHoverHighlight) {
      String? newColId;
      if (hit != null) {
        switch (hit) {
          case DataCellHit():
            newColId = hit.colDef.effectiveColId;
          case HeaderCellHit():
            newColId = hit.colDef.effectiveColId;
          case HeaderResizeEdgeHit():
            newColId = hit.colDef.effectiveColId;
          case HeaderFilterIconHit():
            newColId = hit.colDef.effectiveColId;
          case HeaderMenuIconHit():
            newColId = hit.colDef.effectiveColId;
          case FloatingFilterCellHit():
            newColId = hit.colDef.effectiveColId;
          case EmptyHit():
            newColId = null;
        }
      }
      if (newColId != _lastHoveredColId) {
        _lastHoveredColId = newColId;
        final event = OsColumnHoverChangedEvent(column: newColId);
        widget.onColumnHoverChanged?.call(event);
        _controller.emitColumnHoverChanged(event);
      }
    }

    // --- Tooltip handling ---
    if (hit == null) {
      _tooltipService.onHoverEnd();
      _tooltipRowIndex = null;
      _tooltipColId = null;
      return;
    }

    switch (hit) {
      case DataCellHit():
        final colDef = hit.colDef;
        final tooltipValue = _resolveTooltipValue(hit);
        _tooltipRowIndex = hit.rowIndex;
        _tooltipColId = colDef.effectiveColId;
        _tooltipService.onHoverStart(
          value: tooltipValue,
          location: TooltipLocation.cell,
          anchor: position,
          mousePos: position,
        );
      case HeaderCellHit():
        final colDef = hit.colDef;
        _tooltipRowIndex = null;
        _tooltipColId = colDef.effectiveColId;
        _tooltipService.onHoverStart(
          value: colDef.headerTooltip,
          location: TooltipLocation.header,
          anchor: position,
          mousePos: position,
        );
      default:
        // Other hit types (resize edge, filter icon, menu icon, etc.)
        // don't show tooltips — cancel any pending tooltip.
        _tooltipService.onHoverEnd();
        _tooltipRowIndex = null;
        _tooltipColId = null;
    }
  }

  /// Resolves the tooltip value for a data cell hit.
  String? _resolveTooltipValue(DataCellHit hit) {
    final colDef = hit.colDef;

    // tooltipField takes precedence
    if (colDef.tooltipField != null) {
      final data = _getRowDataAt(hit.rowIndex);
      if (data == null) return null;
      if (data is Map<String, dynamic>) {
        final value = _getNestedValue(data, colDef.tooltipField!);
        return value?.toString();
      }
      return null;
    }

    // tooltipValueGetter is the fallback
    final getter = colDef.tooltipValueGetter;
    if (getter != null) {
      final data = _getRowDataAt(hit.rowIndex);
      if (data == null) return null;
      final params = TooltipValueGetterParams(
        data: data,
        value: hit.value,
        valueFormatted: _formatCellValue(hit),
        colDef: colDef,
        rowIndex: hit.rowIndex,
      );
      return (getter as Function)(params) as String?;
    }

    return null;
  }

  /// Gets the row data at the given processed index.
  TData? _getRowDataAt(int rowIndex) {
    final data = _processedRowData ?? widget.rowData;
    if (data == null || rowIndex < 0) return null;

    // Master/detail: display indices include synthetic detail rows —
    // rebase onto the source row index first (null when the hit row is a
    // detail row), THEN bounds-check against the source list.
    final rebased = _displayIndexToSourceIndex(rowIndex);
    if (rebased == null || rebased >= data.length) return null;

    // Account for pagination
    if (widget.pagination != null) {
      final startIndex = _currentPage * _pageSize;
      final actualIndex = startIndex + rebased;
      if (actualIndex >= data.length) return null;
      return data[actualIndex];
    }
    return data[rebased];
  }

  /// Formats a cell value using the column's valueFormatter (if any).
  String? _formatCellValue(DataCellHit hit) {
    final colDef = hit.colDef;
    if (colDef.valueFormatter == null) return null;
    return colDef.valueFormatter!(
      ValueFormatterParams(value: hit.value, rowIndex: hit.rowIndex),
    );
  }

  /// Gets a nested value from a map using dot notation (e.g. 'address.city').
  dynamic _getNestedValue(Map<String, dynamic> data, String path) {
    final parts = path.split('.');
    dynamic current = data;
    for (final part in parts) {
      if (current is Map<String, dynamic>) {
        current = current[part];
      } else {
        return null;
      }
    }
    return current;
  }

  @override
  void dispose() {
    _alignedGridCoordinator.dispose();
    _textPainterCache.dispose();
    _asyncTransactionService?.dispose();
    _infiniteCache?.dispose();
    _serverSideModel?.dispose();
    _scrollPositionNotifier.removeListener(_onScrollPositionChangedForInfinite);
    _cellFlashCoordinator.dispose();
    _columnDrag.dispose();
    _rowDrag.dispose();
    _columns.dispose();
    _stateUpdatedSubscription?.cancel();
    _selectionStateSubscription?.cancel();
    _rangeSelectionSubscription?.cancel();
    _gridStateService?.dispose();
    _scrollPositionNotifier.dispose();
    _focusedCellNotifier.removeListener(_onFocusedCellNotifierChanged);
    _focusedCellNotifier.dispose();
    _tooltipService.stateChangeNotifier.removeListener(_onTooltipStateChanged);
    _tooltipService.dispose();
    _undoRedo.dispose();
    _controller.removeListener(_onControllerChanged);
    if (_ownsController) {
      _controller.dispose();
    }
    _floatingFilterFocusNode.removeListener(_onFloatingFilterFocusChanged);
    _floatingFilterFocusNode.dispose();
    _floatingFilterTextController.dispose();
    // Module lifecycle exit: detach registered modules first (unwires any
    // coordinator wiring they own), then tear the coordinators down.
    for (final module in _registeredModules) {
      module.detach();
    }
    if (_clipboard != null) _unwireClipboardControllerCallbacks();
    _editing.detach();
    _editing.dispose();
    super.dispose();
  }

  void _handleCellTap(DataCellHit hit) {
    // Row drag handle column — ignore taps (drag is handled by pan gesture)
    if (hit.colDef.field == SpecialColumns.rowDrag) return;

    // Pointer-down focus: track the focused cell for the focus API even
    // when the visual cursor already sat on this cell — the focused-cell
    // notifier dedupes equal writes, so its listener alone cannot observe
    // the unfocused→focused transition on the initial cell.
    if (!widget.suppressCellFocus) {
      _trackedFocusedCell = (
        rowIndex: hit.rowIndex,
        columnIndex: hit.columnIndex,
      );
    }

    // Per-column selection checkbox: tapping always toggles the row's
    // selection and skips value/range/edit behaviours (mirrors the
    // synthetic checkbox column).
    if (hit.colDef.checkboxSelection == true) {
      _controller.toggleSelection(hit.rowIndex);
      widget.onSelectionChanged?.call(
        OsSelectionChangedEvent(selectedRows: _controller.getSelectedRows()),
      );
      return;
    }

    // Group row — toggle expand/collapse on tap anywhere in the row
    if (hit.rowIndex < _displayRowData.length &&
        _displayRowData[hit.rowIndex][RowGroupKeys.kIsGroupRow] == true) {
      _handleGroupRowTap(_displayRowData[hit.rowIndex]);
      return;
    }

    // If currently editing, commit the edit when clicking another cell
    if (_editCellRect != null) {
      final isSameCell =
          _editRowIndex == hit.rowIndex && _editColIndex == hit.columnIndex;
      if (!isSameCell) {
        _commitEdit();
      }
    }

    // Master/detail rows (quality program v3 item 4): tapping a master row
    // toggles its detail area (mirrors the group-row toggle). Taps landing
    // on a synthetic detail row are no-ops — the detail widget overlay
    // handles its own interactions.
    if (_masterDetailConfigured && hit.rowIndex < _displayRowData.length) {
      final tappedRow = _displayRowData[hit.rowIndex];
      if (tappedRow[MasterDetailKeys.isDetailRow] == true) {
        return;
      }
      if (tappedRow[MasterDetailKeys.isMasterRow] == true) {
        _toggleDetailRowExpanded(hit.rowIndex);
        return;
      }
    }

    // Handle cell/range selection: clicking a cell starts a new single-cell range
    if (widget.cellSelection != null) {
      final isCtrlHeld = HardwareKeyboard.instance.logicalKeysPressed.any(
        (key) =>
            key == LogicalKeyboardKey.controlLeft ||
            key == LogicalKeyboardKey.controlRight ||
            key == LogicalKeyboardKey.metaLeft ||
            key == LogicalKeyboardKey.metaRight,
      );
      final suppressMulti = widget.cellSelection!.suppressMultiRanges;

      setState(() {
        if (!isCtrlHeld || suppressMulti) {
          // Clear existing ranges and start a new single-cell range
          _controller.cellRanges = [
            CellRange(
              startRow: hit.rowIndex,
              endRow: hit.rowIndex,
              startColumn: hit.columnIndex,
              endColumn: hit.columnIndex,
            ),
          ];
        } else {
          // Ctrl+click: add a new single-cell range
          final existing = _controller.getCellRanges();
          _controller.cellRanges = [
            ...existing,
            CellRange(
              startRow: hit.rowIndex,
              endRow: hit.rowIndex,
              startColumn: hit.columnIndex,
              endColumn: hit.columnIndex,
            ),
          ];
        }
      });

      final event = OsRangeSelectionChangedEvent(
        ranges: _controller.getCellRanges(),
        started: false,
        finished: true,
      );
      _controller.emitRangeSelectionChanged(event);
    }

    // Handle row selection via controller. Suppressed entirely by
    // suppressRowClickSelection (quality program v2 item 14) — cellClicked
    // events below still fire, and checkbox/API selection still work.
    if (widget.rowSelection != null &&
        widget.rowSelection!.enableClickSelection &&
        !widget.suppressRowClickSelection) {
      // Detect modifier keys
      final isShiftHeld = HardwareKeyboard.instance.logicalKeysPressed.any(
        (key) =>
            key == LogicalKeyboardKey.shiftLeft ||
            key == LogicalKeyboardKey.shiftRight,
      );
      final isCtrlHeld = HardwareKeyboard.instance.logicalKeysPressed.any(
        (key) =>
            key == LogicalKeyboardKey.controlLeft ||
            key == LogicalKeyboardKey.controlRight ||
            key == LogicalKeyboardKey.metaLeft ||
            key == LogicalKeyboardKey.metaRight,
      );

      if (widget.rowSelection!.mode == OsRowSelectionMode.single) {
        // Single mode ignores Ctrl/Shift entirely — every click replaces
        // the selection with the clicked row.
        _controller.setSingleSelection(hit.rowIndex);
      } else {
        // Multiple mode — full AG Grid desktop modifier matrix:
        // - Plain click: clear others, select the clicked row, move anchor.
        // - Ctrl/Cmd+click: toggle the clicked row, preserving the rest.
        // - Shift+click: replace the selection with the anchor→clicked range.
        // - Ctrl/Cmd+Shift+click: extend the selection with that range
        //   (rows outside the range keep their state).
        // The anchor is the last non-shift clicked row and survives
        // sort/filter (ID-based); it resets on deselectAll or page change.
        if (isShiftHeld) {
          _controller.selectRange(hit.rowIndex, extend: isCtrlHeld);
        } else if (isCtrlHeld ||
            widget.rowSelection!.enableSelectionWithoutKeys) {
          // Ctrl+click always toggles; plain click toggles when enableSelectionWithoutKeys is true
          _controller.toggleSelection(hit.rowIndex);
        } else {
          // Plain click without enableSelectionWithoutKeys: replace selection
          _controller.setSingleSelection(hit.rowIndex);
        }
      }

      // Also fire widget callback
      widget.onSelectionChanged?.call(
        OsSelectionChangedEvent(selectedRows: _controller.getSelectedRows()),
      );
    }

    // Emit cell clicked event
    final effectiveData = _processedRowData ?? widget.rowData;
    if (effectiveData != null && hit.rowIndex < effectiveData.length) {
      final event = OsCellClickedEvent<TData>(
        data: effectiveData[hit.rowIndex],
        rowIndex: hit.rowIndex,
        colDef: OsColumnDef<TData>(
          field: hit.colDef.field,
          headerName: hit.colDef.headerName,
        ),
        value: hit.value,
      );
      widget.onCellClicked?.call(event);
      _controller.emitCellClicked(event);

      // Emit row clicked event
      final rowEvent = OsRowClickedEvent<TData>(
        data: effectiveData[hit.rowIndex],
        rowIndex: hit.rowIndex,
      );
      widget.onRowClicked?.call(rowEvent);
      _controller.emitRowClicked(rowEvent);

      // Check for singleClickEdit — start editing on single click
      final col = hit.colDef;
      final useSingleClick = col.singleClickEdit ?? widget.singleClickEdit;

      // Checkbox cells always toggle on single click (matching OS Grid behaviour
      // where the checkbox renderer handles clicks directly).
      if (col.cellEditor is OsCheckboxCellEditor &&
          _isCellEditable(col, effectiveData[hit.rowIndex], hit.rowIndex)) {
        _toggleCheckboxCell(
          hit.rowIndex,
          col,
          col.cellEditor as OsCheckboxCellEditor,
          effectiveData[hit.rowIndex],
        );
      } else if (useSingleClick &&
          !widget.suppressClickEdit &&
          _isCellEditable(col, effectiveData[hit.rowIndex], hit.rowIndex)) {
        // Calculate cell rect and start editing
        final cellRect = _calculateCellRect(hit.rowIndex, hit.columnIndex);
        if (cellRect != null) {
          _handleCellEditRequest(hit, cellRect);
        }
      }
    }
  }

  void _handleCellDoubleTap(DataCellHit hit) {
    final effectiveData = _processedRowData ?? widget.rowData;
    if (effectiveData != null && hit.rowIndex < effectiveData.length) {
      final event = OsCellClickedEvent<TData>(
        data: effectiveData[hit.rowIndex],
        rowIndex: hit.rowIndex,
        colDef: OsColumnDef<TData>(
          field: hit.colDef.field,
          headerName: hit.colDef.headerName,
        ),
        value: hit.value,
      );
      widget.onCellDoubleClicked?.call(event);
    }
  }

  void _handleHeaderTap(HeaderCellHit hit) {
    // Handle checkbox header click (select all / deselect all)
    if (hit.colDef.field == SpecialColumns.checkbox ||
        hit.colDef.headerCheckboxSelection == true) {
      if (_controller.selectedIndices.isEmpty) {
        _controller.selectAll();
      } else {
        _controller.deselectAll();
      }
      widget.onSelectionChanged?.call(
        OsSelectionChangedEvent(selectedRows: _controller.getSelectedRows()),
      );
      return;
    }

    if (!hit.colDef.sortable) return;

    // Resolve the column ID from the hit index
    final colId = _resolveColIdFromHitIndex(hit.columnIndex);
    if (colId == null) return;

    // Determine if multi-sort modifier key is held
    final bool isMultiSortKeyHeld;
    if (widget.multiSortKey == OsMultiSortKey.ctrl) {
      isMultiSortKeyHeld = HardwareKeyboard.instance.logicalKeysPressed.any(
        (key) =>
            key == LogicalKeyboardKey.controlLeft ||
            key == LogicalKeyboardKey.controlRight ||
            key == LogicalKeyboardKey.metaLeft ||
            key == LogicalKeyboardKey.metaRight,
      );
    } else {
      isMultiSortKeyHeld = HardwareKeyboard.instance.logicalKeysPressed.any(
        (key) =>
            key == LogicalKeyboardKey.shiftLeft ||
            key == LogicalKeyboardKey.shiftRight,
      );
    }

    // Determine effective multi-sort behaviour
    final bool doMultiSort =
        !widget.suppressMultiSort &&
        (widget.alwaysMultiSort || isMultiSortKeyHeld);

    setState(() {
      _sortService.progressSort(
        colId: colId,
        multiSort: doMultiSort,
        sortingOrder: hit.colDef.sortingOrder,
      );
      _deltaSortService?.invalidate();
      _updateLegacySortIndex(hit.columnIndex);
      _reprocessData();
    });

    _emitSortChanged();
  }

  /// Converts pinned row data (typed TData) to `Map<String, dynamic>` for the painter.
  ///
  /// Map rows are copied through; typed rows are wrapped in lazy display maps
  /// (quality program v3 item 15) using the same value extraction logic as
  /// the main row data. Returns an empty list if [data] is null or empty.
  List<Map<String, dynamic>> _buildPinnedRowMaps(
    List<TData>? data,
    List<OsColumnDef> columns,
  ) {
    if (data == null || data.isEmpty) return const [];
    final lazyFieldIndex = GridModelResolver.buildLazyFieldIndex(columns);
    return [
      for (int i = 0; i < data.length; i++)
        () {
          final row = data[i];
          if (row is Map<String, dynamic>) {
            return <String, dynamic>{...row};
          }
          // For typed data, values are extracted via valueGetter lazily,
          // on first per-cell read.
          return _typedRowToMap(row, i, lazyFieldIndex);
        }(),
    ];
  }

  /// Wraps a typed (non-Map) row in a lazy display map (quality program v3
  /// item 15).
  ///
  /// The canvas painter reads `Map<String, dynamic>` rows; typed rows are
  /// converted on the way into `build()` so they can be painted and hit
  /// tested like map rows. Each column's valueGetter now fires when the
  /// cell's value is FIRST READ (typically when the cell enters the visible
  /// window) instead of eagerly for every row × column on every build.
  /// [lazyFieldIndex] must come from
  /// `GridModelResolver.buildLazyFieldIndex` over the same column list and
  /// be shared by every row of the pass. When `valueCacheEnabled` is set,
  /// evaluations round-trip through the grid-level (rowId, colId) cache.
  Map<String, dynamic> _typedRowToMap(
    TData row,
    int rowIndex,
    Map<String, OsColumnDef> lazyFieldIndex,
  ) {
    final cache = widget.valueCacheEnabled ? _valueCache : null;
    String? rowId;
    if (cache != null) {
      final getter = widget.getRowId;
      rowId = getter != null ? getter(row) : identityHashCode(row).toString();
    }
    return GridModelResolver.lazyRowToMap<TData>(
      row,
      rowIndex,
      lazyFieldIndex,
      valueCache: cache,
      rowId: rowId,
    );
  }

  /// Flattens the widget's column definitions (including group children)
  /// into the flat display list shared by the pipeline/column coordinators
  /// and the idle prefetch (quality program v3 item 50).
  List<OsColumnDef> _allFlatColumns() {
    final flatCols = <OsColumnDef>[];
    final tempSpans = <ColumnGroupSpan>[];
    _flattenColumnDefs(_effectiveColumnDefs, flatCols, tempSpans);
    return flatCols;
  }

  /// Idle-time value prefetch (quality program v3 item 50).
  ///
  /// Invoked via a microtask scheduled by the body painter after each body
  /// paint. Computes valueGetter results for the next viewport-height worth
  /// of rows in the scroll direction through the pipeline's read-through
  /// resolver, warming the [ValueCache] with the same (rowId, colId) keying
  /// the sort/filter pipeline and lazy row maps consume. No-ops unless the
  /// value cache is enabled — its entries are only consumed (and expired on
  /// reprocess) while it is.
  void _prefetchValueWindow({
    required double scrollY,
    required double viewportHeight,
    required int firstVisibleRow,
    required int lastVisibleRow,
  }) {
    if (!mounted || !widget.valueCacheEnabled) return;
    final rows = _processedRowData;
    if (rows == null || rows.isEmpty) return;

    // Infer the scroll direction from the previous prefetch frame.
    final lastY = _lastPrefetchScrollY;
    _lastPrefetchScrollY = scrollY;
    final bool scrollingDown;
    if (lastY == null || scrollY > lastY) {
      scrollingDown = true;
    } else if (scrollY < lastY) {
      scrollingDown = false;
    } else {
      // Stationary repaint (hover/focus change): the adjacent window is
      // already warm from the frame that scrolled here.
      return;
    }

    final rowHeight = _effectiveRowHeight;
    final viewportRows = rowHeight <= 0
        ? 1
        : (viewportHeight / rowHeight).ceil().clamp(1, rows.length);

    final window = computeValuePrefetchWindow(
      rowCount: rows.length,
      firstVisibleRow: firstVisibleRow,
      lastVisibleRow: lastVisibleRow,
      viewportRows: viewportRows,
      scrollingDown: scrollingDown,
    );
    if (window == null) return;

    final columns = _prefetchColumns();
    for (int r = window.first; r <= window.last; r++) {
      final row = rows[r];
      for (final column in columns) {
        _pipeline.getCachedValue(row, column);
      }
    }
  }

  /// Getter-bearing visible data columns for the idle prefetch — field-backed,
  /// non-hidden columns only (synthetic `__` columns carry no getters and
  /// hidden columns are never painted).
  List<OsColumnDef> _prefetchColumns() {
    final columns = <OsColumnDef>[];
    for (final col in _allFlatColumns()) {
      final field = col.field;
      if (field == null || field.startsWith('__')) continue;
      if (_hiddenColumnIds.contains(col.effectiveColId)) continue;
      if (col.getValueGetterAsFunction() == null) continue;
      columns.add(col);
    }
    return columns;
  }

  /// Computes a [RowHeightLayout] for variable row heights.
  ///
  /// Returns `null` if all rows use the default height (no getRowHeight
  /// callback and no autoHeight columns).
  RowHeightLayout? _computeRowHeightLayout(
    List<Map<String, dynamic>> rowData,
    List<OsColumnDef> flatColumns,
    Map<int, double>? columnWidths,
  ) {
    if (widget.getRowHeight == null && !flatColumns.any((c) => c.autoHeight)) {
      return null;
    }

    return AutoHeightCalculator.computeLayout<TData>(
      rowData: _processedRowData ?? widget.rowData ?? [],
      columns: flatColumns,
      defaultRowHeight: _effectiveRowHeight,
      columnWidths: columnWidths ?? const {},
      getRowHeight: widget.getRowHeight,
      cellTextStyle: widget.theme?.cellTextStyle,
      textScaler: MediaQuery.textScalerOf(context),
    );
  }

  /// Expands the display list for master/detail (quality program v3 item 4).
  ///
  /// Every display row whose source data satisfies [OsGrid.isMasterRow] is
  /// annotated with [MasterDetailKeys.isMasterRow] so tap handling and the
  /// painter can identify it without re-running the callback. When a
  /// master row is expanded, a synthetic detail row (marked with
  /// [MasterDetailKeys.isDetailRow] and carrying the master's source data)
  /// is inserted directly below it, and its [OsGrid.detailRowHeight] is
  /// spliced into the returned height list.
  ///
  /// Returns `null` when the display list needs no master/detail pass at
  /// all (no master rows and no annotations). Otherwise returns the new
  /// display rows; the record's heights field is non-null only when at
  /// least one detail row was inserted (variable layout required).
  ({List<Map<String, dynamic>> rows, List<double>? heights, int detailCount})?
  _applyMasterDetail({
    required List<Map<String, dynamic>> displayRows,
    required RowHeightLayout? baseLayout,
    required int pageOffset,
  }) {
    final sourceRows = _processedRowData ?? widget.rowData;
    if (sourceRows == null) return null;

    final isMasterRow = widget.isMasterRow!;
    final outRows = <Map<String, dynamic>>[];
    List<double>? outHeights;
    var detailCount = 0;
    var annotatedCount = 0;

    for (var i = 0; i < displayRows.length; i++) {
      final sourceIndex = pageOffset + i;
      final source = sourceIndex < sourceRows.length
          ? sourceRows[sourceIndex]
          : null;
      final isMaster = source != null && isMasterRow(source);

      if (isMaster) {
        outRows.add(<String, dynamic>{
          ...displayRows[i],
          MasterDetailKeys.isMasterRow: true,
        });
        annotatedCount++;
      } else {
        outRows.add(displayRows[i]);
      }

      if (outHeights != null) {
        outHeights.add(baseLayout?.getRowHeight(i) ?? _effectiveRowHeight);
      }

      if (!isMaster) continue;
      final rowId = _detailRowIdFor(source);
      if (!_detailExpansion.isExpanded(rowId)) continue;

      // Expanded master: append its synthetic detail row.
      outHeights ??= <double>[
        for (var j = 0; j <= i; j++)
          baseLayout?.getRowHeight(j) ?? _effectiveRowHeight,
      ];
      outRows.add(<String, dynamic>{
        MasterDetailKeys.isDetailRow: true,
        MasterDetailKeys.detailSource: source,
        MasterDetailKeys.detailMasterIndex: i,
        MasterDetailKeys.detailRowId: rowId,
      });
      outHeights.add(
        widget.detailRowHeight?.call(source) ?? kDefaultDetailRowHeight,
      );
      detailCount++;
    }

    if (annotatedCount == 0) return null;
    return (rows: outRows, heights: outHeights, detailCount: detailCount);
  }

  // --- Infinite Row Model ---

  /// Whether the grid is currently in infinite row model mode.
  bool get _isInfiniteMode => widget.infiniteRowModel != null;

  /// Initialises the infinite row model cache if configured.
  void _initInfiniteRowModel() {
    if (!_isInfiniteMode) return;
    if (widget.datasource == null) return;

    _infiniteCache = InfiniteBlockCache<TData>(
      config: widget.infiniteRowModel!,
      datasource: widget.datasource!,
      onRowCountChanged: _onInfiniteRowCountChanged,
      onBlockLoaded: _onInfiniteBlockLoaded,
    );
    _infiniteCache!.init();

    // Schedule initial block loading after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _infiniteCache != null) {
        _onScrollPositionChangedForInfinite();
      }
    });
  }

  /// Wires the infinite row model controller callbacks.
  void _wireInfiniteRowModelCallbacks() {
    _controller.onRefreshInfiniteCacheRequested = () {
      _infiniteCache?.refresh();
    };
    _controller.onPurgeInfiniteCacheRequested = () {
      _infiniteCache?.purge();
    };
    _controller.onGetInfiniteRowCountRequested = () {
      return _infiniteCache?.getRowCount();
    };
    _controller.onIsLastRowKnownRequested = () =>
        _infiniteCache?.isLastRowKnown ?? false;
    _controller.onIsInfiniteCacheLoadingRequested = () =>
        _infiniteCache?.isAnyBlockLoading ?? false;
    _controller.onSetDatasourceRequested = (datasource) {
      if (!_isInfiniteMode) return;
      _infiniteCache?.dispose();
      _infiniteCache = InfiniteBlockCache<TData>(
        config: widget.infiniteRowModel!,
        datasource: datasource as OsInfiniteDatasource<TData>,
        onRowCountChanged: _onInfiniteRowCountChanged,
        onBlockLoaded: _onInfiniteBlockLoaded,
      );
      _infiniteCache!.init();
      // Item 25: kept as a bare setState — a fresh cache swaps out the
      // entire row source consumed by GridPainter across virtualised_grid's
      // CustomPaint boundary; narrowing this to the consuming subtree would
      // require repaint-notifier plumbing inside virtualised_grid.dart
      // (item 10 dirty-region territory), not a local change.
      setState(() {});
    };
    _controller.onRefreshServerSideRequested = (groupKeys) {
      _serverSideModel?.refresh(groupKeys: groupKeys);
      _scheduleServerSideFetch();
    };
    _controller.onGetServerSideRowCountRequested = (groupKeys) {
      final model = _serverSideModel;
      if (model == null) return null;
      return model.getVirtualRowCount(groupKeys ?? const []);
    };
  }

  /// Called when the infinite cache's virtual row count changes.
  void _onInfiniteRowCountChanged(int rowCount) {
    if (!mounted) return;
    // Item 25: bare setState kept — the row count feeds scroll metrics and
    // the painted row range inside virtualised_grid's CustomPaint, so there
    // is no single local subtree to rebuild instead (item 10 territory).
    setState(() {});
    final event = OsInfiniteRowCountChangedEvent(
      rowCount: rowCount,
      isLastRowKnown: _infiniteCache?.isLastRowKnown ?? false,
    );
    widget.onInfiniteRowCountChanged?.call(event);
    _controller.emitInfiniteRowCountChanged(event);
  }

  /// Called when a block finishes loading (triggers repaint).
  void _onInfiniteBlockLoaded() {
    if (!mounted) return;
    // Item 25: bare setState kept — freshly loaded rows are painted by
    // GridPainter inside virtualised_grid's CustomPaint; a targeted rebuild
    // would need a repaint signal threaded into that painter (item 10
    // dirty-region territory, different file ownership).
    setState(() {});
  }

  /// Called when an image cell's asynchronous load completes (triggers
  /// repaint so the decoded pixels blit on the next frame).
  void _onImageCellLoaded() {
    if (!mounted) return;
    // Same rationale as _onInfiniteBlockLoaded: decoded images are painted
    // by BodyPainter inside virtualised_grid's CustomPaint.
    setState(() {});
  }

  /// Purges the infinite/server-side caches when sort or filter changes.
  void _purgeInfiniteCacheOnChange() {
    if (_isInfiniteMode && _infiniteCache != null) {
      _infiniteCache!.setSortModel(_sortService.sortModel);
      _infiniteCache!.setFilterModel(_getFilterModelMap());
    }
    if (_isServerSideMode && _serverSideModel != null) {
      _serverSideModel!.setSortModel(_sortService.sortModel);
      _serverSideModel!.setFilterModel(_getFilterModelMap());
      _scheduleServerSideFetch();
    }
  }

  /// Called when scroll position changes — triggers block loading for visible range.
  void _onScrollPositionChangedForInfinite() {
    if (_isServerSideMode) {
      _onScrollPositionChangedForServerSide();
      return;
    }
    if (!_isInfiniteMode || _infiniteCache == null) return;

    final scrollY = _scrollPositionNotifier.value.dy;
    final rowHeight = _effectiveRowHeight;

    // Try to get actual viewport height from the RenderBox
    final renderBox = context.findRenderObject() as RenderBox?;
    final viewportHeight =
        renderBox?.size.height ?? _lastKnownViewportHeight ?? 600.0;
    if (renderBox != null) {
      _lastKnownViewportHeight = renderBox.size.height;
    }

    // Subtract header height and floating filter height from viewport
    final dataViewportHeight =
        viewportHeight -
        _effectiveHeaderHeight -
        (widget.floatingFilter ? widget.floatingFilterHeight : 0);

    final firstVisibleRow = (scrollY / rowHeight).floor().clamp(
      0,
      _infiniteCache!.virtualRowCount - 1,
    );
    final lastVisibleRow = ((scrollY + dataViewportHeight) / rowHeight)
        .ceil()
        .clamp(0, _infiniteCache!.virtualRowCount - 1);

    _infiniteCache!.ensureBlocksForRange(firstVisibleRow, lastVisibleRow);
  }

  /// Called when scroll position changes — requests the server-side
  /// blocks covering the visible display rows.
  void _onScrollPositionChangedForServerSide() {
    final model = _serverSideModel;
    if (model == null) return;

    final rowHeight = _effectiveRowHeight;
    if (rowHeight <= 0) return;

    final scrollY = _scrollPositionNotifier.value.dy;

    // Try to get actual viewport height from the RenderBox
    final renderBox = context.findRenderObject() as RenderBox?;
    final viewportHeight =
        renderBox?.size.height ?? _lastKnownViewportHeight ?? 600.0;
    if (renderBox != null) {
      _lastKnownViewportHeight = renderBox.size.height;
    }

    // Subtract header height and floating filter height from viewport
    final dataViewportHeight =
        viewportHeight -
        _effectiveHeaderHeight -
        (widget.floatingFilter ? widget.floatingFilterHeight : 0);
    if (dataViewportHeight <= 0) return;

    final totalDisplayRows = model.displayRowCount;
    if (totalDisplayRows <= 0) return;

    final firstVisibleRow = (scrollY / rowHeight).floor().clamp(
      0,
      totalDisplayRows - 1,
    );
    final lastVisibleRow = ((scrollY + dataViewportHeight) / rowHeight)
        .ceil()
        .clamp(0, totalDisplayRows - 1);

    model.requestVisibleRows(firstVisibleRow, lastVisibleRow);
  }

  /// Last known viewport height (updated from layout).
  double? _lastKnownViewportHeight;

  /// Gets the current filter model as a map for the datasource.
  Map<String, dynamic>? _getFilterModelMap() {
    if (_columnFilterModels.isEmpty && _customFilterModels.isEmpty) return null;
    final map = <String, dynamic>{};
    for (final entry in _columnFilterModels.entries) {
      map[entry.key] = entry.value;
    }
    for (final entry in _customFilterModels.entries) {
      map[entry.key] = {'filterType': 'custom', 'model': entry.value};
    }
    return map;
  }

  /// Builds the row data list for infinite mode.
  ///
  /// Returns a list of maps where loaded rows have real data and
  /// unloaded rows have a `__loading__` marker.
  List<Map<String, dynamic>> _buildInfiniteRowData(
    List<OsColumnDef> flatColumns,
  ) {
    if (_infiniteCache == null) return [];

    final rowCount = _infiniteCache!.virtualRowCount;
    final result = <Map<String, dynamic>>[];

    for (int i = 0; i < rowCount; i++) {
      final data = _infiniteCache!.getRow(i);
      if (data != null) {
        if (data is Map<String, dynamic>) {
          result.add(data);
        } else {
          // Typed data — build a map from column fields
          final map = <String, dynamic>{'__data__': data};
          for (final col in flatColumns) {
            if (col.field != null) {
              final getter = col.getValueGetterAsFunction();
              if (getter != null) {
                map[col.field!] = Function.apply(getter, [
                  ValueGetterParams<TData>(data: data, rowIndex: i),
                ]);
              }
            }
          }
          result.add(map);
        }
      } else {
        // Row not yet loaded — use a loading placeholder
        result.add(const {'__loading__': true});
      }
    }

    return result;
  }

  // --- Server-Side Row Model ---

  /// Whether the grid is currently in server-side row model mode.
  ///
  /// Takes precedence over the infinite row model.
  bool get _isServerSideMode => widget.serverSideDatasource != null;

  /// Creates a server-side row model for [datasource], sharing the grid's
  /// row-group expansion state so group taps drive the model.
  ServerSideRowModel<TData> _createServerSideModel(
    OsServerSideDatasource<TData> datasource,
  ) => ServerSideRowModel<TData>(
    datasource: datasource,
    rowGroupState: _rowGroupState,
    onCacheChanged: _onServerSideCacheChanged,
  );

  /// Initialises the server-side row model if configured.
  void _initServerSideRowModel() {
    if (!_isServerSideMode) return;

    _serverSideModel = _createServerSideModel(widget.serverSideDatasource!);
    // Seed the current sort/filter so the first requests carry them.
    _serverSideModel!.setSortModel(
      _sortService.sortModel.isEmpty ? null : _sortService.sortModel,
    );
    _serverSideModel!.setFilterModel(_getFilterModelMap());

    // Schedule initial block loading after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _onScrollPositionChangedForServerSide();
    });
  }

  /// Re-requests the server-side blocks covering the viewport.
  ///
  /// Deferred to a post-frame callback so callers inside event emission
  /// (sort/filter changes, refresh) stay safe; the fresh data arrives via
  /// the model's onCacheChanged rebuild.
  void _scheduleServerSideFetch() {
    if (!_isServerSideMode) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _onScrollPositionChangedForServerSide();
    });
  }

  /// Called when the server-side cache changes (triggers repaint).
  void _onServerSideCacheChanged() {
    if (!mounted) return;
    // Item 25: bare setState kept — same rationale as the infinite model:
    // freshly loaded rows are painted inside virtualised_grid's
    // CustomPaint (item 10 dirty-region territory).
    setState(() {});
  }

  /// Builds the row data list for server-side mode.
  ///
  /// The model flattens its level tree into display rows (group rows as
  /// synthetic maps, leaves mapped through the column valueGetters),
  /// requesting missing blocks as a side effect.
  List<Map<String, dynamic>> _buildServerSideRowData(
    List<OsColumnDef> flatColumns,
  ) {
    final model = _serverSideModel;
    if (model == null) return const [];

    final lazyFieldIndex = GridModelResolver.buildLazyFieldIndex(flatColumns);
    return model.buildDisplayRows(
      groupColumns: _getEffectiveGroupColumns(),
      leafToMap: (row, index) => row is Map<String, dynamic>
          ? row
          : _typedRowToMap(row, index, lazyFieldIndex),
    );
  }

  /// Applies quick filter, per-column filters, and sort to produce
  /// `_processedRowData` (delegated to the data pipeline coordinator).
  void _reprocessData() {
    _pipeline.reprocess();
    _scheduleModelUpdated();
  }

  /// Reprocesses data using the controller's internal row data as source.
  void _reprocessDataFromController() {
    _pipeline.reprocessFromController();
    _scheduleModelUpdated();
  }

  // --- Lifecycle event emission (RULE ZERO) ---
  //
  // Every emission below is deferred via addPostFrameCallback and guarded
  // with one-shot flags: no listener ever runs synchronously during build,
  // layout, or paint.

  /// Whether an onModelUpdated post-frame callback is already queued.
  bool _modelUpdatedPending = false;

  /// Whether an onModelUpdated emission is currently executing.
  ///
  /// Re-entrancy guard: onModelUpdated fires at the end of reprocess and
  /// reprocess can be triggered by listeners (e.g. a listener calling
  /// setFilterModel). Without this guard such a listener would schedule
  /// and flush another emission inside the current one.
  bool _emittingModelUpdated = false;

  /// Set when a reprocess happens while an onModelUpdated emission is
  /// running; honoured with one deferred catch-up emission afterwards.
  bool _modelUpdatedDirtyWhileEmitting = false;

  /// Schedules an onModelUpdated event for the end of the current frame.
  ///
  /// Multiple reprocesses within the same frame are coalesced into one
  /// event. If listeners trigger further reprocessing while the event is
  /// being emitted, exactly one deferred catch-up emission follows —
  /// breaking any synchronous recursion.
  void _scheduleModelUpdated() {
    if (!mounted) return;
    if (_emittingModelUpdated) {
      _modelUpdatedDirtyWhileEmitting = true;
      return;
    }
    if (_modelUpdatedPending) return;
    _modelUpdatedPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _modelUpdatedPending = false;
      if (!mounted) return;
      _emittingModelUpdated = true;
      try {
        const event = OsModelUpdatedEvent();
        widget.onModelUpdated?.call(event);
        _controller.emitModelUpdated(event);
      } finally {
        _emittingModelUpdated = false;
      }
      if (_modelUpdatedDirtyWhileEmitting && !_modelUpdatedPending) {
        _modelUpdatedDirtyWhileEmitting = false;
        _scheduleModelUpdated();
      }
    });
  }

  /// Whether onFirstDataRendered has fired (fires exactly once).
  bool _firstDataRenderedFired = false;

  /// Whether an onFirstDataRendered post-frame callback is queued.
  bool _firstDataRenderedScheduled = false;

  /// Schedules onFirstDataRendered once processed data is non-empty.
  ///
  /// Called from [build]; only registers a post-frame callback so it is
  /// safe to invoke during layout.
  void _maybeScheduleFirstDataRendered() {
    if (_firstDataRenderedFired || _firstDataRenderedScheduled) return;
    final data = _processedRowData ?? widget.rowData;
    if (data == null || data.isEmpty) return;
    _firstDataRenderedScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _firstDataRenderedScheduled = false;
      if (!mounted || _firstDataRenderedFired) return;
      final current = _processedRowData ?? widget.rowData;
      if (current == null || current.isEmpty) return;
      _firstDataRenderedFired = true;
      const event = OsFirstDataRenderedEvent();
      widget.onFirstDataRendered?.call(event);
      _controller.emitFirstDataRendered(event);
    });
  }

  /// Last grid size reported by the LayoutBuilder (null before first pass).
  Size? _lastGridSize;

  /// Whether an onGridSizeChanged post-frame callback is already queued.
  bool _gridSizeChangeScheduled = false;

  /// Records the latest grid size from the content LayoutBuilder and
  /// schedules a deferred emission when it actually changed.
  ///
  /// The first observed size never emits ("skip first" semantics), and
  /// repeated identical sizes are ignored. Safe to call from layout.
  void _maybeEmitGridSizeChanged(Size size) {
    final last = _lastGridSize;
    _lastGridSize = size;
    if (last == null || last == size) return;
    if (_gridSizeChangeScheduled) return;
    if (!mounted) return;
    _gridSizeChangeScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _gridSizeChangeScheduled = false;
      if (!mounted) return;
      final latest = _lastGridSize;
      if (latest == null) return;
      final event = OsGridSizeChangedEvent(
        width: latest.width,
        height: latest.height,
      );
      widget.onGridSizeChanged?.call(event);
      _controller.emitGridSizeChanged(event);
    });
  }

  /// Resolves which overlay should currently cover the grid body.
  ///
  /// Priority order:
  /// 1. Explicit controller override
  ///    (`OsGridController.showLoadingOverlay` / `.showNoRowsOverlay`) —
  ///    persists until `OsGridController.hideOverlay`.
  /// 2. The [OsGrid.loading] widget parameter.
  /// 3. Infinite row model auto-loading: a LOADING overlay while cache
  ///    blocks are in flight and rows needed for display are still
  ///    missing (suppressed once data arrives).
  /// 4. No-rows heuristic when nothing is displayed.
  OsGridOverlay _resolveOverlayState({required bool hasDisplayedRows}) {
    // 1. Explicit override wins over everything.
    final override = _controller.overlayOverride;
    if (override != null) return override;

    // 2. Widget loading parameter.
    if (widget.loading == true) return OsGridOverlay.loading;

    // 3. Infinite cache auto-loading.
    if (_isInfiniteViewportUnderLoaded()) return OsGridOverlay.loading;

    // 4. No-rows heuristic.
    if (!hasDisplayedRows) return OsGridOverlay.noRows;

    return OsGridOverlay.none;
  }

  /// Whether the infinite row model is still missing rows needed for the
  /// visible viewport while fetches are in flight.
  ///
  /// Two windows count as under-loaded:
  /// - any visible row's block has not arrived yet, or
  /// - no block has ever loaded and the total row count is unknown yet
  ///   (initial fetch / just after purge) so the grid would otherwise
  ///   flash the no-rows placeholder before the first data lands.
  bool _isInfiniteViewportUnderLoaded() {
    if (!_isInfiniteMode) return false;
    final cache = _infiniteCache;
    if (cache == null) return false;
    if (!_controller.isInfiniteCacheLoading &&
        !(!cache.isLastRowKnown && !cache.hasAnyLoadedBlock)) {
      return false;
    }

    final virtualRowCount = cache.virtualRowCount;
    if (virtualRowCount <= 0) return true;

    final scrollY = _scrollPositionNotifier.value.dy;
    final rowHeight = _effectiveRowHeight;
    if (rowHeight <= 0) return false;

    final viewportHeight = _lastKnownViewportHeight ?? 600.0;
    final dataViewportHeight =
        viewportHeight -
        _effectiveHeaderHeight -
        (widget.floatingFilter ? widget.floatingFilterHeight : 0);
    if (dataViewportHeight <= 0) return false;

    final firstVisibleRow = (scrollY / rowHeight).floor().clamp(
      0,
      virtualRowCount - 1,
    );
    final lastVisibleRow = ((scrollY + dataViewportHeight) / rowHeight)
        .ceil()
        .clamp(0, virtualRowCount - 1);

    for (int row = firstVisibleRow; row <= lastVisibleRow; row++) {
      if (!cache.isRowLoaded(row)) return true;
    }
    return false;
  }

  /// Builds the default centered overlay panel used when no custom
  /// [OsGrid.loadingOverlay] / [OsGrid.noRowsOverlay] is provided.
  Widget _buildDefaultOverlayPanel(String message) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: widget.theme?.backgroundColor ?? Colors.white,
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          message,
          style:
              widget.theme?.cellTextStyle ??
              const TextStyle(fontSize: 13, color: Colors.black87),
        ),
      ),
    );
  }
  // --- Row Grouping Helpers ---

  /// Returns the effective list of columns to group by.
  ///
  /// Priority: programmatic override > widget.groupBy > colDef.rowGroup.
  List<OsColumnDef> _getEffectiveGroupColumns() {
    final flatCols = <OsColumnDef>[];
    final tempSpans = <ColumnGroupSpan>[];
    _flattenColumnDefs(_effectiveColumnDefs, flatCols, tempSpans);

    // Programmatic override from controller.setRowGroupColumns()
    if (_groupByOverride != null && _groupByOverride!.isNotEmpty) {
      return _groupByOverride!
          .map(
            (colId) => flatCols.cast<OsColumnDef?>().firstWhere(
              (c) => c!.effectiveColId == colId,
              orElse: () => null,
            ),
          )
          .whereType<OsColumnDef>()
          .toList();
    }

    // Widget-level groupBy prop
    if (widget.groupBy != null && widget.groupBy!.isNotEmpty) {
      return widget.groupBy!
          .map(
            (colId) => flatCols.cast<OsColumnDef?>().firstWhere(
              (c) => c!.effectiveColId == colId,
              orElse: () => null,
            ),
          )
          .whereType<OsColumnDef>()
          .toList();
    }

    // Column definition level: columns with rowGroup: true
    return flatCols.where((c) => c.rowGroup == true).toList();
  }

  /// Returns columns with [OsColumnDef.aggFunc] set (value columns).
  ///
  /// These columns have their aggregate values computed for group rows.
  /// Uses the programmatic override [_valueColumnOverride] if set,
  /// otherwise scans column definitions for `aggFunc != null`.
  List<OsColumnDef> _getEffectiveValueColumns(List<OsColumnDef> flatColumns) {
    // Programmatic override from controller.setValueColumns()
    if (_valueColumnOverride != null && _valueColumnOverride!.isNotEmpty) {
      return _valueColumnOverride!
          .map(
            (colId) => flatColumns.cast<OsColumnDef?>().firstWhere(
              (c) => c!.effectiveColId == colId,
              orElse: () => null,
            ),
          )
          .whereType<OsColumnDef>()
          .toList();
    }

    // Column definition level: columns with aggFunc set.
    // Apply per-column aggFunc overrides from controller.setColumnAggFunc().
    return flatColumns.where((c) {
      final colId = c.effectiveColId;
      if (_aggFuncOverrides.containsKey(colId)) {
        return _aggFuncOverrides[colId] != null;
      }
      return c.aggFunc != null;
    }).toList();
  }

  /// Returns columns marked as pivot columns.
  ///
  /// Priority: programmatic override > colDef.pivot: true.
  List<OsColumnDef> _getEffectivePivotColumns() {
    final flatCols = <OsColumnDef>[];
    final tempSpans = <ColumnGroupSpan>[];
    _flattenColumnDefs(_effectiveColumnDefs, flatCols, tempSpans);

    // Programmatic override from controller.setPivotColumns()
    if (_pivotColumnOverride != null && _pivotColumnOverride!.isNotEmpty) {
      return _pivotColumnOverride!
          .map(
            (colId) => flatCols.cast<OsColumnDef?>().firstWhere(
              (c) => c!.effectiveColId == colId,
              orElse: () => null,
            ),
          )
          .whereType<OsColumnDef>()
          .toList();
    }

    // Column definition level: columns with pivot: true
    return flatCols.where((c) => c.pivot == true).toList();
  }

  /// Returns whether pivot mode is effectively active.
  bool get _isPivotModeActive => _pivotModeOverride || widget.pivotMode;

  /// Emits the [OsRowGroupOpenedEvent] via controller and widget callback.
  void _emitRowGroupOpenedEvent(String nodeId, bool expanded) {
    // Parse group metadata from node ID for the event
    // Node IDs have format: row-group-{field}-{key} or {parentId}-{field}-{key}
    final event = OsRowGroupOpenedEvent(
      nodeId: nodeId,
      expanded: expanded,
      groupKey: nodeId, // Full nodeId as key fallback
      groupField: '',
      level: 0,
    );
    _controller.emitRowGroupOpened(event);
    widget.onRowGroupOpened?.call(event);
  }

  /// Handles a tap on a group row's expand/collapse area.
  void _handleGroupRowTap(Map<String, dynamic> groupRow) {
    final nodeId = groupRow[RowGroupKeys.kGroupNodeId] as String?;
    if (nodeId == null) return;

    final wasExpanded = groupRow[RowGroupKeys.kGroupExpanded] as bool? ?? false;
    final newExpanded = !wasExpanded;

    setState(() {
      _rowGroupState.setExpanded(nodeId, expanded: newExpanded);
    });

    _emitRowGroupOpenedEvent(nodeId, newExpanded);

    // Server-side mode: expanding may expose child-level rows in the
    // viewport — request their blocks now (no scroll event will fire).
    if (_isServerSideMode) {
      _onScrollPositionChangedForServerSide();
    }
  }

  // --- Master/detail helpers (quality program v3 item 4) ---

  /// Whether master/detail is fully configured on this grid instance.
  bool get _masterDetailConfigured =>
      widget.isMasterRow != null && widget.detailWidgetBuilder != null;

  /// Stable expansion id for a master row's data.
  String _detailRowIdFor(TData data) =>
      widget.getRowId?.call(data) ?? identityHashCode(data).toString();

  /// Resolves the expansion id of the display row at [displayIndex], or
  /// `null` when the index is out of range or the row is not a master row.
  String? _detailRowIdAt(int displayIndex) {
    if (!_masterDetailConfigured) return null;
    if (displayIndex < 0 || displayIndex >= _displayRowData.length) {
      return null;
    }
    if (_displayRowData[displayIndex][MasterDetailKeys.isMasterRow] != true) {
      return null;
    }
    final data = _getRowDataAt(displayIndex);
    if (data == null) return null;
    return _detailRowIdFor(data);
  }

  /// Toggles the detail area of the master row at [displayIndex] (tap
  /// interaction — mirrors the group-row toggle).
  void _toggleDetailRowExpanded(int displayIndex) {
    final rowId = _detailRowIdAt(displayIndex);
    if (rowId == null) return;
    _setDetailRowExpanded(rowId, !_detailExpansion.isExpanded(rowId));
  }

  /// Expands or collapses the detail area of the master row identified by
  /// [rowId] and rebuilds the display list.
  void _setDetailRowExpanded(String rowId, bool expanded) {
    setState(() {
      _detailExpansion.setExpanded(rowId, expanded: expanded);
    });
  }

  /// Resolves the master row id at [displayIndex] and expands its detail.
  void _handleExpandDetailRowRequested(int displayIndex) {
    final rowId = _detailRowIdAt(displayIndex);
    if (rowId == null) return;
    _setDetailRowExpanded(rowId, true);
  }

  /// Resolves the master row id at [displayIndex] and collapses its detail.
  void _handleCollapseDetailRowRequested(int displayIndex) {
    final rowId = _detailRowIdAt(displayIndex);
    if (rowId == null) return;
    _setDetailRowExpanded(rowId, false);
  }

  /// Rebases a display index (which includes synthetic detail rows) onto
  /// the source row index within `_processedRowData`/`rowData`.
  ///
  /// Returns `null` when [displayIndex] is out of range or points at a
  /// synthetic detail row. When no detail rows are present this is the
  /// identity mapping.
  int? _displayIndexToSourceIndex(int displayIndex) {
    if (displayIndex < 0 || displayIndex >= _displayRowData.length) return null;
    if (_displayDetailRowCount == 0) return displayIndex;
    if (_displayRowData[displayIndex][MasterDetailKeys.isDetailRow] == true) {
      return null;
    }
    var sourceIndex = -1;
    for (var i = 0; i <= displayIndex; i++) {
      if (_displayRowData[i][MasterDetailKeys.isDetailRow] != true) {
        sourceIndex++;
      }
    }
    return sourceIndex;
  }

  void _handleColumnResize(int columnIndex, double newWidth) =>
      _columns.handleResize(columnIndex, newWidth);

  /// Emits a pagination changed event via both the widget callback and controller stream.
  void _emitPaginationChanged({
    required int currentPage,
    required int totalPages,
    required int totalRows,
    required bool newPage,
    required bool newPageSize,
  }) {
    final event = OsPaginationChangedEvent(
      currentPage: currentPage,
      totalPages: totalPages,
      pageSize: _pageSize,
      totalRows: totalRows,
      newPage: newPage,
      newPageSize: newPageSize,
    );
    widget.onPaginationChanged?.call(event);
    _controller.emitPaginationChanged(event);
    _scheduleModelUpdated();
    _notifyStateChanged('pagination');
  }

  // --- Cell editing (delegated to EditingCoordinator) ---

  // Editing coordinator (created in initState; owns the edit session state
  // and the typed editors: select, date, custom, large text).
  late final EditingCoordinator<TData> _editing;

  // Compatibility accessors over the coordinator-owned session state so
  // existing call sites keep working unchanged.
  Rect? get _editCellRect => _editing.editCellRect;
  int? get _editRowIndex => _editing.editRowIndex;
  int? get _editColIndex => _editing.editColIndex;
  TextEditingController get _editTextController => _editing.editTextController;
  FocusNode get _editFocusNode => _editing.editFocusNode;
  bool get _isSelectEditing => _editing.isSelectEditing;
  bool get _isCustomEditing => _editing.isCustomEditing;
  bool get _isLargeTextEditing => _editing.isLargeTextEditing;
  bool get _isDateEditing => _editing.isDateEditing;

  /// Debug warning emitted when an edit session is requested while the
  /// editing feature is gated off by the module registry.
  void _warnEditingGated() {
    GridDiagnostics.warnOnce(
      'module:gated:editing',
      'Editing feature is not enabled: register EditingModule (via the '
          'modules parameter or OsGrid.registerModules) to edit cells.',
    );
  }

  void _handleCellEditRequest(
    DataCellHit hit,
    Rect cellRect, {
    String? triggerKey,
  }) {
    if (!_editingEnabled) {
      _warnEditingGated();
      return;
    }
    _editing.handleCellEditRequest(hit, cellRect, triggerKey: triggerKey);
  }

  void _handleEditStartRequested(
    int rowIndex,
    int columnIndex,
    String triggerKey,
  ) {
    if (!_editingEnabled) {
      _warnEditingGated();
      return;
    }
    _editing.handleEditStartRequested(rowIndex, columnIndex, triggerKey);
  }

  void _commitEdit() => _editing.commitEdit();

  void _cancelEditRevert() => _editing.cancelEditRevert();

  void _commitAndNavigateVertically({bool up = false}) =>
      _editing.commitAndNavigateVertically(up: up);

  void _startEditingCellAt(int rowIndex, int columnIndex) {
    if (!_editingEnabled) {
      _warnEditingGated();
      return;
    }
    _editing.startEditingCellAt(rowIndex, columnIndex);
  }

  Rect? _calculateCellRect(int rowIndex, int columnIndex) =>
      _editing.calculateCellRect(rowIndex, columnIndex);

  KeyEventResult _handleEditKeyEvent(KeyEvent event) =>
      _editing.handleEditKeyEvent(event);

  void _commitLargeTextEdit() => _editing.commitLargeTextEdit();

  Widget _buildDateEditorOverlay() => _editing.buildDateEditorOverlay();

  Widget _buildCustomEditorOverlay() => _editing.buildCustomEditorOverlay();

  Widget _buildLargeTextEditorOverlay() =>
      _editing.buildLargeTextEditorOverlay();

  Widget _buildSelectEditorOverlay() => _editing.buildSelectEditorOverlay();

  void _toggleCheckboxCell(
    int rowIndex,
    OsColumnDef col,
    OsCheckboxCellEditor editor,
    TData rowData,
  ) {
    if (!_editingEnabled) {
      _warnEditingGated();
      return;
    }
    _editing.toggleCheckboxCell(rowIndex, col, editor, rowData);
  }

  // --- Floating filter / popups (delegated to PopupUiCoordinator) ---

  /// Per-column filter model (colId → filter model).
  final Map<String, OsColumnFilterModel> _columnFilterModels = {};

  /// Per-column custom filter model (colId → user-defined model).
  ///
  /// Stored separately from [_columnFilterModels] because custom filters use
  /// an opaque user-defined model rather than the structured [OsColumnFilterModel].
  final Map<String, dynamic> _customFilterModels = {};

  // Popup UI coordinator (created in initState; owns the filter popup,
  // floating-filter input, and column menu overlay state plus the per-column
  // filter display texts/operations).
  late final PopupUiCoordinator _popup;

  // Compatibility accessors over the coordinator-owned popup/filter/menu
  // state so existing call sites keep working unchanged. The map accessors
  // return live maps shared with the coordinator.
  Map<String, String> get _columnFilterTexts => _popup.columnFilterTexts;
  Map<String, String> get _columnFilterOperations =>
      _popup.columnFilterOperations;
  bool get _filterPopupVisible => _popup.filterPopupVisible;
  Rect? get _filterPopupAnchorRect => _popup.filterPopupAnchorRect;
  String? get _filterPopupColId => _popup.filterPopupColId;
  OsColumnDef? get _filterPopupColDef => _popup.filterPopupColDef;
  bool get _columnMenuVisible => _popup.columnMenuVisible;
  Rect? get _columnMenuAnchorRect => _popup.columnMenuAnchorRect;
  int? get _columnMenuColIndex => _popup.columnMenuColIndex;
  OsColumnDef? get _columnMenuColDef => _popup.columnMenuColDef;
  Rect? get _floatingFilterRect => _popup.floatingFilterRect;

  // --- Context menu popup ---

  /// Whether the context menu popup is currently visible.
  bool _contextMenuVisible = false;

  /// The position (in grid-local coordinates) where the context menu should appear.
  Offset? _contextMenuPosition;

  /// The resolved menu items to display in the context menu.
  List<OsContextMenuItem>? _contextMenuItems;

  // --- Integrated charts palette popup ---

  /// Whether the chart-type palette popup is currently visible.
  bool _chartPaletteVisible = false;

  /// Canvas-space rect of the palette button that opened the popup.
  Rect? _chartPaletteAnchor;

  void _handleChartPaletteTap(Rect anchorRect) {
    setState(() {
      _chartPaletteVisible = true;
      _chartPaletteAnchor = anchorRect;
    });
  }

  void _dismissChartPalette() {
    if (!_chartPaletteVisible) return;
    setState(() {
      _chartPaletteVisible = false;
      _chartPaletteAnchor = null;
    });
  }

  /// Extracts the chart definition for `controller.createChartRange` from
  /// the displayed model. Values resolve through the controller (valueGetter +
  /// field lookup, pagination-window aware rows); column identity comes
  /// from the display columns the range indices refer to.
  OsChartDefinition? _handleCreateChartRange({
    required OsChartType type,
    CellRange? range,
    required bool transpose,
    required OsChartSeriesLayout seriesLayout,
  }) {
    final sourceRange =
        range ??
        (_controller.getCellRanges().isEmpty
            ? null
            : _controller.getCellRanges().last);
    if (sourceRange == null) return null;

    final columns = _flatColumnsCache;
    final rowCount = _controller.getDisplayedRowCount();
    final startRow = sourceRange.normalizedStartRow.clamp(0, rowCount);
    final endRow = (sourceRange.normalizedEndRow + 1).clamp(0, rowCount);
    if (endRow <= startRow) return null;

    final startCol = sourceRange.normalizedStartColumn.clamp(0, columns.length);
    final endCol = (sourceRange.normalizedEndColumn + 1).clamp(
      0,
      columns.length,
    );
    if (endCol <= startCol) return null;

    final columnNames = <String>[];
    final cellValues = <List<dynamic>>[];
    for (final colIndex in Iterable<int>.generate(
      endCol - startCol,
    ).map((i) => i + startCol)) {
      final col = columns[colIndex];
      // Skip special synthesized columns (drag handles, checkboxes, row
      // numbers) — they carry no chartable data.
      if (col.field == null ||
          col.field == SpecialColumns.checkbox ||
          col.field == SpecialColumns.rowDrag ||
          col.field == SpecialColumns.rowNumber) {
        continue;
      }
      final colId = col.effectiveColId;
      if (columnNames.isEmpty) {
        for (var r = startRow; r < endRow; r++) {
          cellValues.add(<dynamic>[]);
        }
      }
      columnNames.add(col.headerName ?? colId);
      for (var r = startRow; r < endRow; r++) {
        final data = _controller.getDisplayedRowAtIndex(r);
        cellValues[r - startRow].add(
          data == null ? null : _controller.getValue(data, colId),
        );
      }
    }

    final definition = ChartRangeExtractor.extract(
      type: type,
      sourceRange: sourceRange,
      columnNames: columnNames,
      cellValues: cellValues,
      transpose: transpose,
      seriesLayout: seriesLayout,
    );
    if (definition == null) return null;

    final event = OsChartRangeCreatedEvent(definition: definition);
    _controller.emitChartRangeCreated(event);
    widget.onChartRangeCreated?.call(event);
    return definition;
  }

  late TextEditingController _floatingFilterTextController;
  final FocusNode _floatingFilterFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _floatingFilterTextController = TextEditingController();
    _floatingFilterFocusNode.addListener(_onFloatingFilterFocusChanged);
    _focusedCellNotifier.addListener(_onFocusedCellNotifierChanged);
    _pageSize = widget.pagination?.pageSize ?? 100;

    // Resolve the module registry (global + per-instance) and derive the
    // per-feature enablement flags. An empty registry implicitly enables
    // every feature so existing callers see zero behavioural change.
    _registeredModules = [...OsGrid._globalModules, ...?widget.modules];
    _clipboardEnabled =
        !_hasExplicitModules || _findModule<ClipboardModule>() != null;
    _editingEnabled =
        !_hasExplicitModules || _findModule<EditingModule>() != null;
    _treeDataModuleEnabled =
        !_hasExplicitModules || _findModule<TreeDataModule>() != null;
    _sparklineModuleEnabled =
        !_hasExplicitModules || _findModule<SparklineModule>() != null;
    _setFilterModuleEnabled =
        !_hasExplicitModules || _findModule<SetFilterModule>() != null;
    if (_hasExplicitModules && !_clipboardEnabled) {
      // Eager (not lazy) because gating skips coordinator construction, so
      // the controller-level API never reaches the call-site guard.
      _warnClipboardGated();
    }

    // Initialise multi-column sort service
    _sortService = SortService<TData>();
    _sortService.accentedSort = widget.accentedSort;
    if (widget.initialSort != null && widget.initialSort!.isNotEmpty) {
      _sortService.setSortModel(widget.initialSort!);
    } else {
      // Apply per-column sort declarations if no grid-level initialSort
      _applyPerColumnInitialSort();
    }

    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _controller = OsGridController<TData>();
      _ownsController = true;
    }

    // Initialise data pipeline coordinator
    _pipeline = DataPipelineCoordinator<TData>(
      controller: _controller,
      rowData: () => widget.rowData,
      allFlatColumns: _allFlatColumns,
      hiddenIds: () => _hiddenColumnIds,
      columnFilterModels: _columnFilterModels,
      customFilterModels: _customFilterModels,
      sortService: _sortService,
      deltaSortService: () => _deltaSortService,
      lastTouchedRows: () => _lastTransactionTouchedRows,
      setLastTouchedRows: (rows) => _lastTransactionTouchedRows = rows,
      valueCache: _valueCache,
      cellSpanService: _cellSpanService,
      textPainterCache: _textPainterCache,
      quickFilterOverride: () => _quickFilterOverride,
      quickFilterText: () => widget.quickFilterText,
      quickFilterParser: widget.quickFilterParser == null
          ? null
          : (text) => widget.quickFilterParser!(text),
      quickFilterMatcher: widget.quickFilterMatcher == null
          ? null
          : (parts, text) => widget.quickFilterMatcher!(parts, text),
      includeHiddenColumnsInQuickFilter:
          widget.includeHiddenColumnsInQuickFilter,
      cacheQuickFilter: widget.cacheQuickFilter,
      isExternalFilterPresent: widget.isExternalFilterPresent == null
          ? null
          : () => widget.isExternalFilterPresent!(),
      doesExternalFilterPass: widget.doesExternalFilterPass == null
          ? null
          : (row) => widget.doesExternalFilterPass!(row),
      postSortRows: widget.postSortRows == null
          ? null
          : (rows) => widget.postSortRows!(rows),
      valueCacheEnabled: widget.valueCacheEnabled,
      enableCellSpan: widget.enableCellSpan,
      getRowId: (row) => widget.getRowId?.call(row),
      resolveColumnValue: (col, row, rowIndex) =>
          _resolveColumnValue(col, row, rowIndex),
      controllerRowData: () => _controller.rawRowData,
      setProcessedRowData: (rows) => _processedRowData = rows,
    );

    // Initialise column API coordinator
    _columns = ColumnApiCoordinator<TData>(
      controller: _controller,
      allFlatColumns: _allFlatColumns,
      syntheticOffset: () {
        var offset = 0;
        if (widget.rowSelection?.hasCheckboxes == true) offset++;
        if (widget.rowNumbers) offset++;
        if (widget.rowDrag) offset++;
        return offset;
      },
      resolveRows: () => _processedRowData ?? widget.rowData,
      resolveCellValue: (col, row, rowIndex) =>
          _resolveColumnValue(col, row, rowIndex),
      clearTextCacheFor: (colId) => _textPainterCache.clearColumn(colId),
      setSortModel: (model) => _sortService.setSortModel(model),
      clearSort: () => _sortService.clearSort(),
      invalidateDeltaSort: () => _deltaSortService?.invalidate(),
      resetLegacySortIndex: () => _legacySortColumnIndex = null,
      emitSortChanged: _emitSortChanged,
      reprocess: _reprocessData,
      initHiddenFromDefs: _initHiddenColumnsFromDefs,
      notifyStateChanged: _notifyStateChanged,
      mutate: (fn) {
        if (mounted) setState(fn);
      },
      headerTextStyle: () =>
          widget.theme?.headerTextStyle ??
          const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      cellTextStyle: () =>
          widget.theme?.cellTextStyle ?? const TextStyle(fontSize: 14),
      textScaler: () => MediaQuery.textScalerOf(context),
      onColumnVisible: (event) => widget.onColumnVisible?.call(event),
      onColumnPinned: (event) => widget.onColumnPinned?.call(event),
      onColumnResized: (event) => widget.onColumnResized?.call(event),
      onColumnMoved: (event) => widget.onColumnMoved?.call(event),
    );

    // Initialise clipboard coordinator. Skipped entirely when an explicit
    // module registry excludes ClipboardModule — an unregistered feature
    // never allocates its coordinator.
    if (_clipboardEnabled) {
      _clipboard = ClipboardCoordinator<TData>(
        controller: _controller,
        delimiter: () => widget.clipboardDelimiter,
        copyHeaders: () => widget.copyHeadersToClipboard,
        suppressPaste: () => widget.suppressClipboardPaste,
        processCellForClipboard: () => widget.processCellForClipboard,
        processHeaderForClipboard: () => widget.processHeaderForClipboard,
        processCellFromClipboard: () => widget.processCellFromClipboard,
        resolveRows: () => _processedRowData ?? widget.rowData,
        resolveFlatColumns: _getVisibleFlatColumns,
        focusedCell: () => _focusedCellNotifier.value,
        isCellEditable: (col, row, rowIndex) =>
            _isCellEditable(col, row, rowIndex),
        setCellValue: (col, row, value) => _setCellValue(col, row, value),
        undoService: () => _undoRedo.service,
        mutate: (fn) {
          if (mounted) setState(fn);
        },
        onCopy: (event) => widget.onClipboardCopy?.call(event),
        onCut: (event) => widget.onClipboardCut?.call(event),
        onPaste: (event) => widget.onClipboardPaste?.call(event),
        onCellValueChanged: (event) => widget.onCellValueChanged?.call(event),
      );
    }

    // Initialise undo/redo coordinator
    _undoRedo = UndoRedoCoordinator<TData>(
      controller: _controller,
      isEnabled: () => widget.undoRedoCellEditing,
      limit: () => widget.undoRedoCellEditingLimit,
      resolveRows: () => _processedRowData ?? widget.rowData,
      mutate: (fn) {
        if (mounted) setState(fn);
      },
      onUndoStarted: (event) => widget.onUndoStarted?.call(event),
      onUndoEnded: (event) => widget.onUndoEnded?.call(event),
      onRedoStarted: (event) => widget.onRedoStarted?.call(event),
      onRedoEnded: (event) => widget.onRedoEnded?.call(event),
      onCellValueChanged: (event) => widget.onCellValueChanged?.call(event),
    );

    // Initialise editing coordinator
    _editing = EditingCoordinator<TData>(
      controller: _controller,
      undoRedoService: () => _undoRedo.service,
      resolveRows: () => _processedRowData ?? widget.rowData,
      flatColumnsCache: () => _flatColumnsCache,
      mutate: (fn) {
        if (mounted) setState(fn);
      },
      mounted: () => mounted,
      suppressClickEdit: () => widget.suppressClickEdit,
      enableCellEditingOnBackspace: () => widget.enableCellEditingOnBackspace,
      readOnlyEdit: () => widget.readOnlyEdit,
      enterNavigatesVerticallyAfterEdit: () =>
          widget.enterNavigatesVerticallyAfterEdit,
      stopEditingWhenCellsLoseFocus: () => widget.stopEditingWhenCellsLoseFocus,
      rowSelection: () => widget.rowSelection,
      rowNumbers: () => widget.rowNumbers,
      rowDrag: () => widget.rowDrag,
      floatingFilter: () => widget.floatingFilter,
      floatingFilterHeight: () => widget.floatingFilterHeight,
      theme: () => widget.theme,
      localeText: () => widget.localeText,
      columnDefs: () => _effectiveColumnDefs,
      hiddenIds: () => _hiddenColumnIds,
      order: () => _columnOrder,
      widths: () => _columnWidths,
      effectiveHeaderHeight: () => _effectiveHeaderHeight,
      effectiveRowHeight: () => _effectiveRowHeight,
      textPainterCache: _textPainterCache,
      flattenColumnDefs: _flattenColumnDefs,
      isCellEditable: _isCellEditable,
      clearCellValue: _clearCellValue,
      onCellEditingStarted: (event) => widget.onCellEditingStarted?.call(event),
      onCellEditingStopped: (event) => widget.onCellEditingStopped?.call(event),
      onCellValueChanged: (event) => widget.onCellValueChanged?.call(event),
      onCellEditRequest: (event) => widget.onCellEditRequest?.call(event),
      context: () => context,
      tabToNextCell: widget.tabToNextCell,
    );

    // Bind the editing module lifecycle (when registered) so module
    // attach/detach drives the coordinator; otherwise attach directly.
    final editingModule = _findModule<EditingModule>();
    if (editingModule != null) {
      editingModule.bindCoordinator(
        attach: () => _editing.attach(_controller),
        detach: _editing.detach,
      );
    } else {
      _editing.attach(_controller);
    }

    // Initialise popup/filter/menu UI coordinator
    _popup = PopupUiCoordinator(
      mutate: (fn) {
        if (mounted) setState(fn);
      },
      hasActiveEdit: () => _editCellRect != null,
      commitEdit: _commitEdit,
      floatingFilterTextController: () => _floatingFilterTextController,
      floatingFilterFocusNode: () => _floatingFilterFocusNode,
      columnFilterModels: () => _columnFilterModels,
      columnDefs: () => _effectiveColumnDefs,
      columnMenu: () => widget.columnMenu,
      theme: () => widget.theme,
      localeText: () => widget.localeText,
      flatColumnsCache: () => _flatColumnsCache,
      hiddenIds: () => _hiddenColumnIds,
      columnSortDirection: _getColumnSortDirection,
      flattenColumnDefs: _flattenColumnDefs,
      reprocessData: _reprocessData,
      emitFilterChangedEvent: _emitFilterChangedEvent,
      onFilterPopupApply: _onFilterPopupApply,
      onColumnVisibilityChanged: _handleSideBarColumnVisibilityChanged,
      applySortFromMenu: _applySortFromMenu,
      applyPinFromMenu: _applyPinFromMenu,
      autosizeColumn: _autosizeColumn,
      autosizeAllColumns: _autosizeAllColumns,
      resetColumns: _resetColumns,
    );

    // Initialise column drag-reorder coordinator
    _columnDrag = ColumnDragCoordinator<TData>(
      rowGroupPanelKey: () => _rowGroupPanelKey,
      columnDefs: () => _effectiveColumnDefs,
      hiddenIds: () => _hiddenColumnIds,
      order: () => _columnOrder,
      widths: () => _columnWidths,
      flatColumnsCache: () => _flatColumnsCache,
      resolveRows: () => _processedRowData ?? widget.rowData,
      rowSelection: () => widget.rowSelection,
      rowNumbers: () => widget.rowNumbers,
      rowDrag: () => widget.rowDrag,
      effectiveHeaderHeight: () => _effectiveHeaderHeight,
      effectiveRowHeight: () => _effectiveRowHeight,
      theme: () => widget.theme,
      flattenColumnDefs: _flattenColumnDefs,
      moveColumnByIndex: _moveColumnByIndex,
      onRowGroupAdd: (colId, index) {
        _controller.addRowGroupColumn(colId, index);
      },
      onRowGroupRemove: (colId) {
        _controller.removeRowGroupColumn(colId);
      },
      onRowGroupMove: (fromIndex, toIndex) {
        _controller.moveRowGroupColumn(fromIndex, toIndex);
      },
      context: () => context,
    );

    // Initialise row drag-reorder coordinator
    _rowDrag = RowDragCoordinator<TData>(
      controller: _controller,
      resolveRows: () => _processedRowData ?? widget.rowData,
      managedRowData: () => widget.rowData,
      mutate: (fn) {
        if (mounted) setState(fn);
      },
      reprocessData: _reprocessData,
      rowDragManaged: () => widget.rowDragManaged,
      floatingFilter: () => widget.floatingFilter,
      floatingFilterHeight: () => widget.floatingFilterHeight,
      columnDefs: () => _effectiveColumnDefs,
      effectiveHeaderHeight: () => _effectiveHeaderHeight,
      effectiveRowHeight: () => _effectiveRowHeight,
      theme: () => widget.theme,
      dragAndDrop: () => widget.dragAndDrop,
      scrollY: () => _scrollPositionNotifier.value.dy,
      onRowDragEnter: widget.onRowDragEnter == null
          ? null
          : (event) => widget.onRowDragEnter!(event),
      onRowDragMove: widget.onRowDragMove == null
          ? null
          : (event) => widget.onRowDragMove!(event),
      onRowDragOut: widget.onRowDragOut == null
          ? null
          : (event) => widget.onRowDragOut!(event),
      onRowDragEnd: widget.onRowDragEnd == null
          ? null
          : (event) => widget.onRowDragEnd!(event),
      context: () => context,
    );

    // Initialise cell flash animation coordinator
    _cellFlashCoordinator = CellFlashCoordinator(
      resolveColumnIds: () => _flatColumnsCache
          .where(
            (c) =>
                c.field != null &&
                c.field != SpecialColumns.checkbox &&
                c.field != SpecialColumns.rowDrag,
          )
          .map((c) => c.effectiveColId)
          .toList(),
      resolveRowCount: () => _processedRowData?.length ?? _controller.rowCount,
      mutate: (fn) {
        if (mounted) setState(fn);
      },
      vsync: this,
    );

    // Initialise hidden columns before binding so the initial state sync
    // includes hide:true definitions.
    _initHiddenColumnsFromDefs();

    _bindControllerCallbacks();

    if (widget.rowData != null) {
      _controller.setRowData(widget.rowData!);
      _reprocessData();
    }

    // Initialise infinite row model cache if configured
    _initInfiniteRowModel();

    // Initialise server-side row model if configured
    _initServerSideRowModel();

    // Listen to scroll position for infinite block loading
    _scrollPositionNotifier.addListener(_onScrollPositionChangedForInfinite);

    // Initialise undo/redo service if enabled
    _initUndoRedoService();

    // Wire clipboard controller callbacks (module-backed when a
    // ClipboardModule is registered, direct otherwise).
    if (_clipboard != null) {
      final clipboardModule = _findModule<ClipboardModule>();
      if (clipboardModule != null) {
        clipboardModule.bindCoordinator(
          attach: _wireClipboardControllerCallbacks,
          detach: _unwireClipboardControllerCallbacks,
        );
      } else {
        _wireClipboardControllerCallbacks();
      }
    }

    // Attach registered modules (module lifecycle entry point). Built-in
    // feature modules delegate to their coordinator wiring; custom modules
    // receive the controller.
    for (final module in _registeredModules) {
      module.attach(_controller);
    }

    _controller.columnDefs = _effectiveColumnDefs
        .whereType<OsColumnDef>()
        .toList();
    _controller.quickFilterText = widget.quickFilterText;
    _syncPinnedRowDataToController();

    // Wire infinite row model controller callbacks
    _wireInfiniteRowModelCallbacks();

    // Initialise tooltip service
    _tooltipService = TooltipService(
      showDelay: widget.tooltipShowDelay,
      hideDelay: widget.tooltipHideDelay,
      mouseTrack: widget.tooltipMouseTrack,
    );
    _tooltipService.stateChangeNotifier.addListener(_onTooltipStateChanged);

    // Initialise grid state service
    _initGridStateService();

    // Apply initial state if provided
    if (widget.initialState != null) {
      _gridStateService!.setState(widget.initialState!);
    }

    // Run configuration validation in debug mode
    if (!widget.suppressGridOptionsValidation) {
      OsGridValidator.validate(
        columnDefs: _effectiveColumnDefs,
        rowData: widget.rowData,
        rowSelection: widget.rowSelection,
        cellSelection: widget.cellSelection,
        pagination: widget.pagination,
        undoRedoCellEditing: widget.undoRedoCellEditing,
        singleClickEdit: widget.singleClickEdit,
        suppressClickEdit: widget.suppressClickEdit,
        enterNavigatesVertically: widget.enterNavigatesVertically,
        enterNavigatesVerticallyAfterEdit:
            widget.enterNavigatesVerticallyAfterEdit,
        floatingFilter: widget.floatingFilter,
        rowDrag: widget.rowDrag,
        rowDragManaged: widget.rowDragManaged,
        getRowId: widget.getRowId,
        onRowDragEnd: widget.onRowDragEnd,
        treeData: _treeDataActive,
        getDataPath: widget.getDataPath,
        groupBy: widget.groupBy,
      );
    }

    // Register with aligned grid service if configured
    _alignedGridCoordinator = AlignedGridCoordinator(
      config: () => widget.alignedGrids,
      scrollCommandNotifier: _controller.scrollCommandNotifier,
      scrollPositionNotifier: _scrollPositionNotifier,
    );
    _alignedGridCoordinator.attach();

    // Initialise immutable data service if getRowId is provided
    _initImmutableDataService();

    // Initialise async transaction service if configured
    _initAsyncTransactionService();

    // Initialise delta sort service if enabled
    if (widget.deltaSort) {
      _deltaSortService = DeltaSortService<TData>();
      // Wire the transaction applied callback for delta sort tracking.
      _controller.onTransactionApplied = (touched) {
        _lastTransactionTouchedRows = touched;
        // Reprocess data to apply sort/filter to the updated dataset.
        // The controller's _rowData has already been updated by applyTransaction.
        setState(() {
          _reprocessDataFromController();
        });
      };
    }

    // Wire refreshClientSideRowModel callback
    _controller.onRefreshClientSideRowModelRequested = () {
      setState(() {
        _reprocessDataFromController();
      });
    };

    // Wire row grouping callbacks
    _controller.onExpandAllRequested = () {
      setState(() {
        _rowGroupState.expandAll();
      });
      // Server-side mode: expanded child levels need their blocks.
      if (_isServerSideMode) {
        _onScrollPositionChangedForServerSide();
      }
    };
    _controller.onCollapseAllRequested = () {
      setState(() {
        _rowGroupState.collapseAll();
      });
    };
    _controller.onSetRowExpandedRequested = (nodeId, expanded) {
      setState(() {
        _rowGroupState.setExpanded(nodeId, expanded: expanded);
      });
      _emitRowGroupOpenedEvent(nodeId, expanded);
      // Server-side mode: expanding may expose child-level rows in the
      // viewport — request their blocks now (no scroll event will fire).
      if (expanded && _isServerSideMode) {
        _onScrollPositionChangedForServerSide();
      }
    };
    _controller.isRowExpandedCallback = (nodeId) {
      // Default to level 0 for the isExpanded check since we don't
      // know the level from just the nodeId. The explicit state
      // (expand/collapse sets) takes precedence over level-based defaults.
      return _rowGroupState.isExpanded(nodeId, level: 0);
    };

    // Wire master/detail callbacks (quality program v3 item 4)
    _controller.onExpandDetailRowRequested = _handleExpandDetailRowRequested;
    _controller.onCollapseDetailRowRequested =
        _handleCollapseDetailRowRequested;
    _controller.isDetailRowExpandedCallback = (rowIndex) {
      final rowId = _detailRowIdAt(rowIndex);
      return rowId != null && _detailExpansion.isExpanded(rowId);
    };

    _controller.onSetRowGroupColumnsRequested = (colIds) {
      if (mounted) {
        setState(() {
          _groupByOverride = colIds.isEmpty ? null : colIds;
        });
      }
      widget.onRowGroupColumnsChanged?.call(colIds);
    };
    _controller.onCreateChartRangeRequested = _handleCreateChartRange;
    _controller.getRowGroupColumnsCallback = () {
      return _getEffectiveGroupColumns().map((c) => c.effectiveColId).toList();
    };

    // Wire aggregation callbacks
    _controller.onSetValueColumnsRequested = (colIds) {
      setState(() {
        _valueColumnOverride = colIds.isEmpty ? null : colIds;
      });
    };
    _controller.getValueColumnsCallback = () {
      final flatCols = <OsColumnDef>[];
      final tempSpans = <ColumnGroupSpan>[];
      _flattenColumnDefs(_effectiveColumnDefs, flatCols, tempSpans);
      if (_valueColumnOverride != null && _valueColumnOverride!.isNotEmpty) {
        return List<String>.from(_valueColumnOverride!);
      }
      return flatCols
          .where((c) => c.aggFunc != null)
          .map((c) => c.effectiveColId)
          .toList();
    };
    _controller.onSetColumnAggFuncRequested = (colId, aggFunc) {
      setState(() {
        _aggFuncOverrides[colId] = aggFunc;
      });
    };

    // Wire pivot mode callbacks
    _controller.onSetPivotModeRequested = (enabled) {
      setState(() {
        _pivotModeOverride = enabled;
      });
      final event = OsPivotModeChangedEvent(pivotMode: enabled);
      _controller.emitPivotModeChanged(event);
      widget.onPivotModeChanged?.call(event);
    };
    _controller.isPivotModeCallback = () {
      return _pivotModeOverride || widget.pivotMode;
    };
    _controller.onSetPivotColumnsRequested = (colIds) {
      setState(() {
        _pivotColumnOverride = colIds.isEmpty ? null : colIds;
      });
    };
    _controller.getPivotColumnsCallback = () {
      // Note: _lastPivotResult holds generated columns when pivot is active.
      return _getEffectivePivotColumns().map((c) => c.effectiveColId).toList();
    };
    _controller.getPivotResultColumnsCallback = () {
      return _lastPivotResult?.columns.map((c) => c.colId).toList() ?? [];
    };

    // Initialise pivot mode state from widget prop
    _pivotModeOverride = widget.pivotMode;

    // Initialise row grouping default expanded state
    if (widget.groupDefaultExpanded != null) {
      _rowGroupState.setDefaultExpanded(widget.groupDefaultExpanded!);
    }

    // Schedule auto page size calculation after first layout
    if (widget.pagination?.paginationAutoPageSize == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _recalculateAutoPageSize();
          });
        }
      });
    }

    // Initialise side bar state
    _initSideBar();

    // Grid-ready LAST: every service, coordinator, and controller callback
    // above must be wired before the host (or any module) can drive the
    // imperative API — calls inside onGridReady previously hit unwired
    // hooks and silently no-oped.
    widget.onGridReady?.call(_controller);
    _controller.emitGridReady();
  }

  /// Initialises side bar state from widget configuration.
  void _initSideBar() {
    if (widget.sideBar == null) return;
    _sideBarVisible = !widget.sideBar!.hiddenByDefault;
    _openToolPanelId = widget.sideBar!.defaultToolPanel;

    // Wire sidebar controller callbacks
    _controller.sideBarVisibleState = _sideBarVisible;
    _controller.openToolPanelIdState = _openToolPanelId;
    _controller.onSetSideBarVisibleCallback = (visible) {
      setState(() {
        _sideBarVisible = visible;
        _controller.sideBarVisibleState = visible;
      });
      _emitSideBarUpdated();
    };
    _controller.onOpenToolPanelCallback = (key) {
      _handleToolPanelToggled(key);
    };
    _controller.onCloseToolPanelCallback = () {
      _handleToolPanelToggled(null);
    };
    _controller.onSetSideBarPositionCallback = (position) {
      // Position is stored in the widget prop — this is for runtime changes
      // via controller. We emit the event but position is widget-level.
      _emitSideBarUpdated();
    };
  }

  /// Handles when a tool panel is toggled (opened/closed).
  void _handleToolPanelToggled(String? panelId) {
    final previousId = _openToolPanelId;
    final isSwitching = panelId != null && previousId != null;

    setState(() {
      _openToolPanelId = panelId;
      _controller.openToolPanelIdState = panelId;
    });

    // Emit events
    if (previousId != null && previousId != panelId) {
      final closeEvent = OsToolPanelVisibleChangedEvent(
        key: previousId,
        visible: false,
        switchingToolPanel: isSwitching,
        source: OsSideBarSource.buttonClicked,
      );
      _controller.toolPanelVisibleChangedController.add(closeEvent);
      widget.onToolPanelVisibleChanged?.call(closeEvent);
    }
    if (panelId != null && panelId != previousId) {
      final openEvent = OsToolPanelVisibleChangedEvent(
        key: panelId,
        visible: true,
        switchingToolPanel: isSwitching,
        source: OsSideBarSource.buttonClicked,
      );
      _controller.toolPanelVisibleChangedController.add(openEvent);
      widget.onToolPanelVisibleChanged?.call(openEvent);
    }

    _emitSideBarUpdated();
  }

  /// Handles column visibility changes from the sidebar columns tool panel.
  void _handleSideBarColumnVisibilityChanged(String colId, bool visible) {
    setState(() {
      if (visible) {
        _hiddenColumnIds.remove(colId);
      } else {
        _hiddenColumnIds.add(colId);
      }
    });
    final event = OsColumnVisibleEvent(
      columns: [colId],
      visible: visible,
      source: 'sideBar',
    );
    _controller.emitColumnVisible(event);
    widget.onColumnVisible?.call(event);
    _syncColumnStateToController();
    _notifyStateChanged('column');
  }

  /// Emits the sideBarUpdated event.
  void _emitSideBarUpdated() {
    const event = OsSideBarUpdatedEvent();
    _controller.sideBarUpdatedController.add(event);
    widget.onSideBarUpdated?.call(event);
    _notifyStateChanged('sideBar');
  }

  /// Initialises hidden column IDs from column definitions that have `hide: true`.
  void _initHiddenColumnsFromDefs() {
    final flatCols = <OsColumnDef>[];
    final tempSpans = <ColumnGroupSpan>[];
    _flattenColumnDefs(_effectiveColumnDefs, flatCols, tempSpans);
    for (final col in flatCols) {
      if (col.hide == true) {
        _hiddenColumnIds.add(col.effectiveColId);
      }
    }
  }

  /// Syncs the current column state to the controller so it can answer queries.
  void _syncColumnStateToController() => _columns.syncToController();

  /// Syncs pinned row data to the controller for API queries.
  void _syncPinnedRowDataToController() {
    _controller.pinnedTopRowData = widget.pinnedTopRowData ?? [];
    _controller.pinnedBottomRowData = widget.pinnedBottomRowData ?? [];
  }

  /// Initialises the immutable data service when `getRowId` is provided.
  ///
  /// Immutable mode is enabled when:
  /// - `immutableData` is explicitly `true`, OR
  /// - `getRowId` is provided and `immutableData` is not explicitly `false`
  void _initImmutableDataService() {
    final enabled =
        widget.immutableData == true ||
        (widget.getRowId != null && widget.immutableData != false);
    if (enabled && widget.getRowId != null) {
      _immutableDataService = ImmutableDataService<TData>(
        getRowId: widget.getRowId!,
      );
    }
  }

  /// Initialises the async transaction service when `asyncTransactionWaitMillis`
  /// is configured.
  void _initAsyncTransactionService() {
    if (widget.asyncTransactionWaitMillis != null) {
      _asyncTransactionService = AsyncTransactionService<TData>(
        waitMillis: widget.asyncTransactionWaitMillis!,
        onFlush: _onAsyncTransactionsFlushed,
      );

      // Wire controller callbacks for async transactions.
      _controller.onApplyTransactionAsyncRequested = (transaction, callback) {
        _asyncTransactionService!.addTransaction(
          transaction,
          callback: callback,
        );
      };
      _controller.onFlushAsyncTransactionsRequested = () {
        _asyncTransactionService!.flush();
      };
    }
  }

  /// Called when the async transaction service flushes its batch.
  void _onAsyncTransactionsFlushed(OsRowTransaction<TData> mergedTransaction) {
    final batchCount = _asyncTransactionService?.pendingCount ?? 0;
    final touched = _controller.applyTransaction(mergedTransaction);
    _lastTransactionTouchedRows = touched;
    setState(() {
      _reprocessDataFromController();
    });

    // Emit the event.
    final event = OsAsyncTransactionsFlushedEvent<TData>(
      transaction: mergedTransaction,
      transactionCount: batchCount,
    );
    widget.onAsyncTransactionsFlushed?.call(event);
    _controller.emitAsyncTransactionsFlushed(event);
  }

  /// Initialises the grid state service and wires up callbacks.
  void _initGridStateService() {
    _gridStateService = GridStateService<TData>(
      controller: _controller,
      getScrollTop: () => _scrollPositionNotifier.value.dy,
      getScrollLeft: () => _scrollPositionNotifier.value.dx,
      setScrollPosition: (top, left) {
        // Scroll restoration is deferred — the VirtualisedGrid manages
        // its own scroll state. Pixel-level scroll restore requires
        // coordination with the virtualised grid's layout pass.
        // For now, scroll state is captured but not restored.
      },
    );

    // Wire controller callbacks for getState/setState
    _controller.onGetStateRequested = () => _gridStateService!.getState();
    _controller.onSetStateRequested = (state, propertiesToIgnore) {
      _gridStateService!.setState(
        state,
        propertiesToIgnore: propertiesToIgnore,
      );
      setState(() {
        _reprocessData();
      });
    };

    // Forward state updated events to the controller and widget callback
    _stateUpdatedSubscription = _gridStateService!.onStateUpdated.listen((
      event,
    ) {
      widget.onStateUpdated?.call(event);
      _controller.emitStateUpdated(event);
    });

    // Listen to selection changes from the controller
    _selectionStateSubscription = _controller.onSelectionChanged.listen((_) {
      _notifyStateChanged('rowSelection');
    });

    // Bridge controller range-selection events (programmatic and UI) to the
    // widget callback so both paths notify listeners exactly once.
    _rangeSelectionSubscription = _controller.onRangeSelectionChanged.listen((
      event,
    ) {
      widget.onRangeSelectionChanged?.call(event);
    });
  }

  /// Notifies the grid state service that a state property has changed.
  void _notifyStateChanged(String source) {
    _gridStateService?.notifyStateChanged(source);
  }

  /// Wires up the column API callbacks from controller → widget state.
  void _wireColumnApiCallbacks() {
    _columns.attach();
    _controller.onSetQuickFilterRequested = (text) {
      setState(() {
        _quickFilterOverride = text;
        _reprocessData();
      });

      // Emit filter changed event
      final filterModel = <String, dynamic>{};
      if (text != null && text.isNotEmpty) {
        filterModel['quickFilter'] = text;
      }
      final filterEvent = OsFilterChangedEvent(filterModel: filterModel);
      widget.onFilterChanged?.call(filterEvent);
      _controller.emitFilterChanged(filterEvent);
    };

    _controller.onExternalFilterChangedRequested = () {
      setState(() {
        _reprocessData();
      });

      // Emit filter changed event
      _emitFilterChangedEvent();
    };

    _controller.onExpireValueCacheRequested = () {
      _valueCache.expire();
    };

    _controller.onClearQuickFilterCacheRequested =
        _pipeline.invalidateQuickFilterCache;
  }

  /// Wires the clipboard API callbacks from controller → widget state.
  void _wireClipboardControllerCallbacks() {
    _controller.onCopyToClipboardRequested = () => _performCopy(source: 'api');
    _controller.onPasteFromClipboardRequested = () =>
        _performPaste(source: 'api');
    _controller.onCutToClipboardRequested = () => _performCut(source: 'api');
  }

  /// Clears the clipboard API callbacks (module detach path and dispose).
  void _unwireClipboardControllerCallbacks() {
    _controller.onCopyToClipboardRequested = null;
    _controller.onPasteFromClipboardRequested = null;
    _controller.onCutToClipboardRequested = null;
  }

  /// Wires up the editing API callbacks from controller → widget state.
  void _wireEditingApiCallbacks() {
    _controller.onStartEditingCellRequested = (rowIndex, colId) {
      // Find the column index for this colId
      final flatCols = <OsColumnDef>[];
      final tempSpans = <ColumnGroupSpan>[];
      _flattenColumnDefs(_effectiveColumnDefs, flatCols, tempSpans);

      final displayOrder =
          _columnOrder ?? flatCols.map((c) => c.effectiveColId).toList();
      final visibleOrder = displayOrder
          .where((id) => !_hiddenColumnIds.contains(id))
          .toList();

      int offset = 0;
      if (widget.rowSelection?.hasCheckboxes == true) offset++;
      if (widget.rowNumbers) offset++;
      if (widget.rowDrag) offset++;

      final colIndex = visibleOrder.indexOf(colId);
      if (colIndex == -1) return;

      // Commit any existing edit first
      if (_editCellRect != null) _commitEdit();

      _startEditingCellAt(rowIndex, colIndex + offset);
    };

    _controller.onStopEditingRequested = (cancel) {
      if (_editCellRect == null) return;
      if (cancel) {
        _cancelEditRevert();
      } else {
        _commitEdit();
      }
    };
  }

  /// Initialises the undo/redo service and wires controller callbacks.
  void _initUndoRedoService() {
    _undoRedo.init();
  }

  /// Performs an undo operation, applying old values to the data.
  void _performUndo({required String source}) =>
      _undoRedo.performUndo(source: source);

  /// Performs a redo operation, applying new values to the data.
  void _performRedo({required String source}) =>
      _undoRedo.performRedo(source: source);

  // --- Clipboard operations (delegated to ClipboardCoordinator) ---

  /// Debug warning emitted when a clipboard API is used while the
  /// clipboard feature is gated off by the module registry.
  void _warnClipboardGated() {
    GridDiagnostics.warnOnce(
      'module:gated:clipboard',
      'Clipboard feature is not enabled: register ClipboardModule (via the '
          'modules parameter or OsGrid.registerModules) to use clipboard APIs.',
    );
  }

  /// Performs a clipboard copy operation.
  void _performCopy({required String source}) {
    final clipboard = _clipboard;
    if (clipboard == null) {
      _warnClipboardGated();
      return;
    }
    clipboard.performCopy(source: source);
  }

  /// Performs a clipboard cut operation.
  void _performCut({required String source}) {
    final clipboard = _clipboard;
    if (clipboard == null) {
      _warnClipboardGated();
      return;
    }
    clipboard.performCut(source: source);
  }

  /// Performs a clipboard paste operation.
  Future<void> _performPaste({required String source}) async {
    final clipboard = _clipboard;
    if (clipboard == null) {
      _warnClipboardGated();
      return;
    }
    await clipboard.performPaste(source: source);
  }

  /// Builds the clipboard text from the current selection.
  String? _buildClipboardText({bool forceIncludeHeaders = false}) {
    final clipboard = _clipboard;
    if (clipboard == null) {
      _warnClipboardGated();
      return null;
    }
    return clipboard.buildText(forceIncludeHeaders: forceIncludeHeaders);
  }

  /// Resolves the raw value for a column from a row data object.
  dynamic _resolveColumnValue(OsColumnDef col, TData row, int rowIndex) {
    final getter = col.getValueGetterAsFunction();
    if (getter != null) {
      return Function.apply(getter, [
        ValueGetterParams<TData>(data: row, rowIndex: rowIndex),
      ]);
    }

    if (col.field != null && row is Map<String, dynamic>) {
      return row[col.field];
    }

    return null;
  }

  /// Sets a cell value directly (for cut/paste operations).
  void _setCellValue(OsColumnDef col, TData row, dynamic value) {
    if (row is Map<String, dynamic> && col.field != null) {
      row[col.field!] = value;
    }
  }

  /// Gets the visible flat columns in display order.
  List<OsColumnDef> _getVisibleFlatColumns() {
    final flatCols = <OsColumnDef>[];
    final tempSpans = <ColumnGroupSpan>[];
    _flattenColumnDefs(_effectiveColumnDefs, flatCols, tempSpans);

    // Filter out hidden columns
    return flatCols.where((col) {
      if (_hiddenColumnIds.contains(col.effectiveColId)) return false;
      return true;
    }).toList();
  }

  /// Applies column state from the controller API.
  /// Moves a column from one display index to another.
  void _moveColumnByIndex(int fromIndex, int toIndex) =>
      _columns.moveByIndex(fromIndex, toIndex);
  // --- Column header drag-to-reorder delegates ---
  // Thin delegates over [ColumnDragCoordinator]; kept here because build()
  // wires the VirtualisedGrid callbacks directly.

  /// Starts a column header drag.
  void _handleColumnDragStart(
    int columnIndex,
    double startX,
    double scrollX,
    List<double> effectiveWidths,
  ) => _columnDrag.handleColumnDragStart(
    columnIndex,
    startX,
    scrollX,
    effectiveWidths,
  );

  /// Updates the column drag position.
  void _handleColumnDragUpdate(double currentX, Offset globalPosition) =>
      _columnDrag.handleColumnDragUpdate(currentX, globalPosition);

  /// Ends the column drag and applies the move.
  void _handleColumnDragEnd() => _columnDrag.handleColumnDragEnd();

  // --- Row drag-to-reorder delegates ---

  /// Starts a row drag.
  void _handleRowDragStart(int rowIndex, Offset startPosition) =>
      _rowDrag.handleRowDragStart(rowIndex, startPosition);

  /// Updates the row drag position.
  void _handleRowDragUpdate(Offset position) =>
      _rowDrag.handleRowDragUpdate(position);

  /// Ends the row drag and applies the managed reorder.
  void _handleRowDragEnd() => _rowDrag.handleRowDragEnd();

  // --- External drag and drop state ---

  /// Whether an external drag is currently hovering over the grid.
  bool _isExternalDragOver = false;

  /// The target row index for the external drop indicator.
  int? _externalDropTargetIndex;

  // --- External drop-in (DragTarget wrapper) ---
  /// Wraps the grid content with a [DragTarget] to accept external drops.
  Widget _wrapWithDragTarget(Widget content, int rowCount) {
    return DragTarget<Object>(
      onWillAcceptWithDetails: (details) {
        setState(() {
          _isExternalDragOver = true;
        });
        return true;
      },
      onMove: (details) {
        // Compute the target row index from the pointer position
        final renderBox = context.findRenderObject() as RenderBox?;
        if (renderBox == null) return;
        final localPos = renderBox.globalToLocal(details.offset);

        final headerHeight = _effectiveHeaderHeight;
        final hasGroupHeaders = _effectiveColumnDefs.any(
          (d) => d is OsColumnGroup,
        );
        final groupHeaderOffset = hasGroupHeaders ? 36.0 : 0.0;
        final floatingFilterOffset = widget.floatingFilter
            ? widget.floatingFilterHeight
            : 0.0;
        final dataAreaTop =
            headerHeight + groupHeaderOffset + floatingFilterOffset;

        int targetIndex;
        if (localPos.dy < dataAreaTop) {
          targetIndex = 0;
        } else {
          final relativeY = localPos.dy - dataAreaTop;
          targetIndex = (relativeY / _effectiveRowHeight).floor();
          targetIndex = targetIndex.clamp(0, rowCount);
        }

        if (_externalDropTargetIndex != targetIndex) {
          setState(() {
            _externalDropTargetIndex = targetIndex;
          });
        }
      },
      onLeave: (_) {
        setState(() {
          _isExternalDragOver = false;
          _externalDropTargetIndex = null;
        });
      },
      onAcceptWithDetails: (details) {
        final renderBox = context.findRenderObject() as RenderBox?;
        if (renderBox == null) return;
        final localPos = renderBox.globalToLocal(details.offset);

        final headerHeight = _effectiveHeaderHeight;
        final hasGroupHeaders = _effectiveColumnDefs.any(
          (d) => d is OsColumnGroup,
        );
        final groupHeaderOffset = hasGroupHeaders ? 36.0 : 0.0;
        final floatingFilterOffset = widget.floatingFilter
            ? widget.floatingFilterHeight
            : 0.0;
        final dataAreaTop =
            headerHeight + groupHeaderOffset + floatingFilterOffset;

        int targetIndex;
        if (localPos.dy < dataAreaTop) {
          targetIndex = 0;
        } else {
          final relativeY = localPos.dy - dataAreaTop;
          targetIndex = (relativeY / _effectiveRowHeight).floor();
          targetIndex = targetIndex.clamp(0, rowCount);
        }

        final event = OsExternalDropEvent(
          targetRowIndex: targetIndex,
          dragData: details.data,
        );
        widget.onExternalDrop?.call(event);
        _controller.emitExternalDrop(event);

        setState(() {
          _isExternalDragOver = false;
          _externalDropTargetIndex = null;
        });
      },
      builder: (context, candidateData, rejectedData) {
        // Show drop indicator when an external drag is hovering
        if (_isExternalDragOver && _externalDropTargetIndex != null) {
          return Stack(
            children: [
              content,
              // External drop indicator line
              _buildExternalDropIndicator(),
            ],
          );
        }
        return content;
      },
    );
  }

  /// Whether any flat column declares a widget cell renderer. Gates the
  /// hybrid widget-cell overlay so grids without one skip the per-frame
  /// visible-window walk entirely.
  static bool _hasWidgetCellRenderers(List<OsColumnDef> columns) {
    for (final col in columns) {
      final dynamic c = col;
      if (c.cellRenderer != null || c.cellRendererBuilder != null) return true;
    }
    return false;
  }

  /// Builds the [CellWidgetBuilder] that resolves a widget cell for the
  /// hybrid widget overlay from the column def's `cellRenderer` /
  /// `cellRendererBuilder` callbacks. Both are accessed dynamically to
  /// dodge covariant generic type errors (the same pattern the canvas
  /// painters use for the `cellStyle` callback); the display row map is
  /// passed as `data` and the value is resolved with the same field lookup
  /// the body painter uses, so widget cells see the same inputs.
  CellWidgetBuilder _buildCellWidgetResolver(List<OsColumnDef> columns) {
    return (rowIndex, columnIndex, row) {
      if (columnIndex < 0 || columnIndex >= columns.length) return null;
      final dynamic col = columns[columnIndex];
      final dynamic renderer = col.cellRenderer;
      final dynamic builder = col.cellRendererBuilder;
      if (renderer == null && builder == null) return null;

      final params = CellRendererParams(
        value: col.field != null ? row[col.field] : null,
        data: row,
        rowIndex: rowIndex,
        colDef: col,
      );
      if (renderer != null) return renderer(params) as Widget?;
      return builder(context, params) as Widget?;
    };
  }

  /// Builds the drop indicator line for external drag hover.
  Widget _buildExternalDropIndicator() {
    if (_externalDropTargetIndex == null) return const SizedBox.shrink();

    final accentColor = widget.theme?.accentColor ?? Colors.blue;
    final headerHeight = _effectiveHeaderHeight;
    final hasGroupHeaders = _effectiveColumnDefs.any((d) => d is OsColumnGroup);
    final groupHeaderOffset = hasGroupHeaders ? 36.0 : 0.0;
    final floatingFilterOffset = widget.floatingFilter
        ? widget.floatingFilterHeight
        : 0.0;
    final dataAreaTop = headerHeight + groupHeaderOffset + floatingFilterOffset;

    final indicatorY =
        dataAreaTop + _externalDropTargetIndex! * _effectiveRowHeight;

    return Positioned(
      left: 0,
      top: indicatorY - 1,
      right: 0,
      height: 2,
      child: IgnorePointer(child: ColoredBox(color: accentColor)),
    );
  }

  /// Checks whether a cell is editable, respecting both the static `editable`
  /// flag and the per-row `editableCallback`.
  bool _isCellEditable(OsColumnDef col, TData rowData, int rowIndex) {
    // Per-column selection checkbox cells are not editable.
    if (col.checkboxSelection == true) return false;
    if (col.editableCallback != null) {
      return col.editableCallback!(
        CellRendererParams(
          value: null,
          data: rowData,
          rowIndex: rowIndex,
          colDef: col,
        ),
      );
    }
    return col.editable == true;
  }

  /// Clears a cell value directly (Delete/Backspace key behaviour).
  ///
  /// Sets the cell value to null, fires cellValueChanged if the value changed,
  /// and emits cellEditingStarted + cellEditingStopped events to match the
  /// TypeScript 'cellClear' source behaviour.
  ///
  /// When `readOnlyEdit` is enabled, fires `onCellEditRequest` instead of
  /// mutating data.
  void _clearCellValue(int rowIndex, OsColumnDef col, TData rowData) {
    dynamic oldValue;
    if (col.field != null && rowData is Map<String, dynamic>) {
      oldValue = rowData[col.field];
    }

    // readOnlyEdit mode: fire cellEditRequest instead of clearing data
    if (widget.readOnlyEdit) {
      final requestEvent = OsCellEditRequestEvent<TData>(
        data: rowData,
        rowIndex: rowIndex,
        colDef: OsColumnDef<TData>(field: col.field),
        oldValue: oldValue,
        newValue: null,
        source: 'cellClear',
      );
      widget.onCellEditRequest?.call(requestEvent);
      _controller.emitCellEditRequest(requestEvent);
      return;
    }

    // Write null using valueSetter or default Map write
    bool dataChanged;
    if ((col as dynamic).valueSetter != null) {
      dataChanged = ((col as dynamic).valueSetter as Function)(
        ValueSetterParams<TData>(
          data: rowData,
          colDef: col,
          oldValue: oldValue,
          newValue: null,
          rowIndex: rowIndex,
          source: 'cellClear',
        ),
      );
    } else if (rowData is Map<String, dynamic> && col.field != null) {
      (rowData as Map<String, dynamic>)[col.field!] = null;
      dataChanged = true;
    } else {
      dataChanged = false;
    }

    if (dataChanged && oldValue != null) {
      // Notify undo/redo service (cell clear is a single-action edit)
      if (col.field != null) {
        _undoRedoService?.onCellEditingStarted();
        _undoRedoService?.onCellValueChanged(
          rowIndex: rowIndex,
          columnId: col.field!,
          oldValue: oldValue,
          newValue: null,
        );
        _undoRedoService?.onCellEditingStopped(valueChanged: true);
      }

      // Emit cellValueChanged event
      final event = OsCellValueChangedEvent<TData>(
        data: rowData,
        rowIndex: rowIndex,
        colDef: OsColumnDef<TData>(field: col.field),
        oldValue: oldValue,
        newValue: null,
      );
      widget.onCellValueChanged?.call(event);
      _controller.emitCellValueChanged(event);
    }

    // Trigger repaint.
    // Item 25: bare setState kept — the cleared value lives in user row
    // data repainted by GridPainter inside virtualised_grid's CustomPaint;
    // a targeted rebuild would need painter repaint plumbing (item 10).
    setState(() {});
  }

  // --- Floating filter interaction (delegated to PopupUiCoordinator) ---

  void _handleFloatingFilterTap(FloatingFilterCellHit hit, Rect cellRect) =>
      _popup.handleFloatingFilterTap(hit, cellRect);

  void _commitFloatingFilter() => _popup.commitFloatingFilter();

  void _onFloatingFilterFocusChanged() {
    if (!_floatingFilterFocusNode.hasFocus && _floatingFilterRect != null) {
      _commitFloatingFilter();
    }
  }

  void _onFloatingFilterTextChanged(String text) =>
      _popup.onFloatingFilterTextChanged(text);

  void _cycleFilterOperation(String colId) =>
      _popup.cycleFilterOperation(colId);

  /// Shows the filter popup when the header filter icon is tapped.
  void _handleHeaderFilterIconTap(HeaderFilterIconHit hit, Rect iconRect) =>
      _popup.handleHeaderFilterIconTap(hit, iconRect);

  /// Dismisses the filter popup.
  void _dismissFilterPopup() => _popup.dismissFilterPopup();

  // --- Column menu handlers (delegated to PopupUiCoordinator) ---

  /// Shows the column menu when the ⋮ icon is tapped.
  void _handleHeaderMenuIconTap(HeaderMenuIconHit hit, Rect iconRect) =>
      _popup.handleHeaderMenuIconTap(hit, iconRect);

  /// Dismisses the column menu popup.
  void _dismissColumnMenu() => _popup.dismissColumnMenu();

  /// Handles a column menu action.
  void _handleColumnMenuAction(ColumnMenuEvent event) =>
      _popup.handleColumnMenuAction(event);

  /// Builds the tabbed column menu widget.
  Widget _buildTabbedColumnMenu(Size gridSize) =>
      _popup.buildTabbedColumnMenu(gridSize);

  // --- Context menu handlers ---

  /// Handles a secondary (right-click) tap on the grid.
  void _handleSecondaryTap(GridHitTestResult hit, Offset localPosition) {
    // Check grid-level suppression
    if (widget.suppressContextMenu) return;

    if (hit is HeaderCellHit) {
      if (hit.colDef.suppressMenu == true) return;

      // Dismiss any active overlays
      if (_editCellRect != null) _commitEdit();
      if (_floatingFilterRect != null) _commitFloatingFilter();
      if (_filterPopupVisible) _dismissFilterPopup();
      if (_columnMenuVisible) _dismissColumnMenu();

      final colId = hit.colDef.effectiveColId;
      final groupCols = _controller.getRowGroupColumns();
      final isGrouped = groupCols.contains(colId);
      final items = <OsContextMenuItem>[];

      if (isGrouped) {
        final groupIndex = groupCols.indexOf(colId);
        if (groupIndex > 0) {
          items.add(
            OsContextMenuItem(
              name: 'Move group left',
              icon: Icons.arrow_back,
              action: () {
                _controller.moveRowGroupColumn(groupIndex, groupIndex - 1);
              },
            ),
          );
        }
        if (groupIndex < groupCols.length - 1) {
          items.add(
            OsContextMenuItem(
              name: 'Move group right',
              icon: Icons.arrow_forward,
              action: () {
                _controller.moveRowGroupColumn(groupIndex, groupIndex + 1);
              },
            ),
          );
        }
        items.add(
          OsContextMenuItem(
            name: 'Ungroup by ${hit.colDef.headerName ?? hit.colDef.field}',
            icon: Icons.unfold_less,
            action: () {
              _controller.removeRowGroupColumn(colId);
            },
          ),
        );
      } else {
        items.add(
          OsContextMenuItem(
            name: 'Group by ${hit.colDef.headerName ?? hit.colDef.field}',
            icon: Icons.account_tree_outlined,
            action: () {
              _controller.addRowGroupColumn(colId);
            },
          ),
        );
      }

      if (items.isEmpty) return;

      setState(() {
        _contextMenuVisible = true;
        _contextMenuPosition = localPosition;
        _contextMenuItems = items;
      });
      return;
    }

    if (hit is DataCellHit) {
      // Check per-column suppression
      if (hit.colDef.suppressMenu == true) return;

      // Dismiss any active overlays
      if (_editCellRect != null) _commitEdit();
      if (_floatingFilterRect != null) _commitFloatingFilter();
      if (_filterPopupVisible) _dismissFilterPopup();
      if (_columnMenuVisible) _dismissColumnMenu();

      // Resolve cell value and row data
      final rowData = _getRowDataAtIndex(hit.rowIndex);
      final colId = hit.colDef.effectiveColId;
      final value =
          hit.value ?? (rowData is Map ? rowData[hit.colDef.field] : null);

      // Fire the onCellContextMenu event
      final event = OsCellContextMenuEvent<TData>(
        rowIndex: hit.rowIndex,
        colId: colId,
        value: value,
        data: rowData as TData,
        globalPosition: localPosition,
      );

      // Emit on controller stream
      _controller.emitCellContextMenu(event);

      // Call widget callback
      widget.onCellContextMenu?.call(event);

      // If default was prevented, don't show the menu
      if (event.isDefaultPrevented) return;

      // Resolve menu items
      final items = _resolveContextMenuItems(hit, value, rowData);

      // If empty list returned, suppress the menu
      if (items.isEmpty) return;

      setState(() {
        _contextMenuVisible = true;
        _contextMenuPosition = localPosition;
        _contextMenuItems = items;
      });
    }
  }

  /// Handles the keyboard-triggered context menu (Shift+F10 or ContextMenu key).
  void _handleKeyboardContextMenu(int rowIndex, int colIndex) {
    if (widget.suppressContextMenu) return;
    if (colIndex >= _flatColumnsCache.length) {
      return;
    }

    final colDef = _flatColumnsCache[colIndex];
    if (colDef.suppressMenu == true) return;

    // Dismiss any active overlays
    if (_editCellRect != null) _commitEdit();
    if (_floatingFilterRect != null) _commitFloatingFilter();
    if (_filterPopupVisible) _dismissFilterPopup();
    if (_columnMenuVisible) _dismissColumnMenu();

    // Resolve cell value and row data
    final rowData = _getRowDataAtIndex(rowIndex);
    final colId = colDef.effectiveColId;
    final value = rowData is Map ? rowData[colDef.field] : null;

    // Fire the onCellContextMenu event
    final event = OsCellContextMenuEvent<TData>(
      rowIndex: rowIndex,
      colId: colId,
      value: value,
      data: rowData as TData,
      // Use a position relative to the grid — approximate the cell centre
      globalPosition: const Offset(100, 100),
    );

    _controller.emitCellContextMenu(event);
    widget.onCellContextMenu?.call(event);

    if (event.isDefaultPrevented) return;

    final hit = DataCellHit(
      rowIndex: rowIndex,
      columnIndex: colIndex,
      colDef: colDef,
      value: value,
    );
    final items = _resolveContextMenuItems(hit, value, rowData);
    if (items.isEmpty) return;

    // Position the menu near the focused cell (approximate)
    // Use a reasonable default position since we don't have exact cell coordinates
    const approxX = 100.0;
    final approxY =
        _effectiveHeaderHeight +
        (widget.floatingFilter ? widget.floatingFilterHeight : 0) +
        (rowIndex * _effectiveRowHeight) +
        (_effectiveRowHeight / 2);

    setState(() {
      _contextMenuVisible = true;
      _contextMenuPosition = Offset(approxX, approxY);
      _contextMenuItems = items;
    });
  }

  /// Resolves the context menu items to display.
  ///
  /// If `getContextMenuItems` is provided, calls it. Otherwise returns
  /// the default menu items.
  List<OsContextMenuItem> _resolveContextMenuItems(
    DataCellHit hit,
    dynamic value,
    dynamic rowData,
  ) {
    if (widget.getContextMenuItems != null) {
      final params = GetContextMenuItemsParams<TData>(
        rowIndex: hit.rowIndex,
        colId: hit.colDef.effectiveColId,
        value: value,
        data: rowData as TData,
        column: hit.colDef,
      );
      final customItems = widget.getContextMenuItems!(params);
      if (customItems == null) {
        // null means use default
        return _buildDefaultContextMenuItems(hit);
      }
      // Attach actions to built-in items that don't have them
      return customItems
          .map((item) => _attachBuiltInAction(item, hit))
          .toList();
    }
    return _buildDefaultContextMenuItems(hit);
  }

  /// Builds the default context menu items for a data cell.
  List<OsContextMenuItem> _buildDefaultContextMenuItems(DataCellHit hit) {
    final items = <OsContextMenuItem>[];

    // Copy
    items.add(
      OsContextMenuItem.copy.withAction(() {
        _performContextMenuCopy();
      }),
    );

    // Copy with Headers
    items.add(
      OsContextMenuItem.copyWithHeaders.withAction(() {
        _performContextMenuCopyWithHeaders();
      }),
    );

    // Cut (only if editable)
    final isEditable = _isCellEditableByIndex(hit.rowIndex, hit.columnIndex);
    if (isEditable) {
      items.add(
        OsContextMenuItem.cut.withAction(() {
          _performContextMenuCut();
        }),
      );
    }

    // Paste (only if editable)
    if (isEditable) {
      items.add(
        OsContextMenuItem.paste.withAction(() {
          _performContextMenuPaste();
        }),
      );
    }

    // Separator
    items.add(OsContextMenuItem.separator);

    // Export sub-menu
    items.add(
      OsContextMenuItem(
        name: 'Export',
        icon: Icons.file_download_outlined,
        subMenu: [
          OsContextMenuItem(
            name: 'CSV Export',
            icon: Icons.description_outlined,
            action: () {
              _controller.exportCsv();
            },
          ),
        ],
      ),
    );

    return items;
  }

  /// Attaches built-in actions to constant menu items that don't have actions.
  OsContextMenuItem _attachBuiltInAction(
    OsContextMenuItem item,
    DataCellHit hit,
  ) {
    if (item.action != null || item.isSeparator) return item;

    // Match by name to attach built-in actions
    if (item.name == OsContextMenuItem.copy.name) {
      return item.withAction(() => _performContextMenuCopy());
    }
    if (item.name == OsContextMenuItem.copyWithHeaders.name) {
      return item.withAction(() => _performContextMenuCopyWithHeaders());
    }
    if (item.name == OsContextMenuItem.cut.name) {
      return item.withAction(() => _performContextMenuCut());
    }
    if (item.name == OsContextMenuItem.paste.name) {
      return item.withAction(() => _performContextMenuPaste());
    }

    // For export sub-menu, attach CSV export action to sub-items
    if (item.name == OsContextMenuItem.export.name && item.subMenu != null) {
      return OsContextMenuItem(
        name: item.name,
        icon: item.icon,
        disabled: item.disabled,
        subMenu: item.subMenu!.map((subItem) {
          if (subItem.name == 'CSV Export' && subItem.action == null) {
            return subItem.withAction(() => _controller.exportCsv());
          }
          return subItem;
        }).toList(),
        shortcut: item.shortcut,
      );
    }

    return item;
  }

  /// Performs a copy operation (cell value or selected range).
  void _performContextMenuCopy() {
    _performCopy(source: 'contextMenu');
  }

  /// Performs a copy-with-headers operation.
  void _performContextMenuCopyWithHeaders() {
    // Copy with headers forced on, regardless of the copyHeadersToClipboard setting
    final text = _buildClipboardText(forceIncludeHeaders: true);
    if (text == null || text.isEmpty) return;

    Clipboard.setData(ClipboardData(text: text));

    final lines = text.split('\n');
    final cellCount = lines.fold<int>(
      0,
      (sum, line) => sum + line.split(widget.clipboardDelimiter).length,
    );

    final event = OsClipboardCopyEvent(
      text: text,
      cellCount: cellCount,
      source: 'contextMenu',
    );
    widget.onClipboardCopy?.call(event);
    _controller.emitClipboardCopy(event);
  }

  /// Performs a cut operation.
  void _performContextMenuCut() {
    _performCut(source: 'contextMenu');
  }

  /// Performs a paste operation.
  void _performContextMenuPaste() {
    _performPaste(source: 'contextMenu');
  }

  /// Checks if a cell is editable by index.
  bool _isCellEditableByIndex(int rowIndex, int colIndex) {
    if (colIndex >= _flatColumnsCache.length) {
      return false;
    }
    final colDef = _flatColumnsCache[colIndex];
    if (colDef.editable != true) return false;
    if (colDef.editableCallback != null) {
      final data = _getRowDataAtIndex(rowIndex);
      return colDef.editableCallback!(data) == true;
    }
    return true;
  }

  /// Gets the row data at the given display index.
  dynamic _getRowDataAtIndex(int rowIndex) {
    final effectiveData = _processedRowData ?? widget.rowData;
    if (effectiveData == null) return null;
    final isPaginated = widget.pagination != null;
    final dataIndex = isPaginated
        ? _currentPage * _pageSize + rowIndex
        : rowIndex;
    if (dataIndex < 0 || dataIndex >= (effectiveData as List).length) {
      return null;
    }
    return effectiveData[dataIndex];
  }

  /// Dismisses the context menu popup.
  void _dismissContextMenu() {
    if (!_contextMenuVisible) return;
    setState(() {
      _contextMenuVisible = false;
      _contextMenuPosition = null;
      _contextMenuItems = null;
    });
  }

  /// Applies sort from the column menu.
  void _applySortFromMenu(
    int columnIndex, {
    bool ascending = true,
    bool clear = false,
  }) {
    final colId = _resolveColIdFromHitIndex(columnIndex);

    setState(() {
      if (clear) {
        if (colId != null) {
          _sortService.setColumnSort(colId: colId, direction: null);
        } else {
          _sortService.clearSort();
        }
      } else if (colId != null) {
        _sortService.setColumnSort(
          colId: colId,
          direction: ascending
              ? OsSortDirection.ascending
              : OsSortDirection.descending,
          multiSort: false,
        );
      }
      _deltaSortService?.invalidate();
      _updateLegacySortIndex(columnIndex);
      _reprocessData();
    });

    _emitSortChanged();
  }

  /// Resolves a hit column index to a colId, accounting for special columns.
  String? _resolveColIdFromHitIndex(int columnIndex) {
    final flatCols = <OsColumnDef>[];
    final tempSpans = <ColumnGroupSpan>[];
    _flattenColumnDefs(_effectiveColumnDefs, flatCols, tempSpans);
    int offset = 0;
    if (widget.rowSelection?.hasCheckboxes == true) offset++;
    if (widget.rowNumbers) offset++;
    if (widget.rowDrag) offset++;
    final adjustedIndex = columnIndex - offset;
    final displayOrder =
        _columnOrder ?? flatCols.map((c) => c.effectiveColId).toList();
    final visibleOrder = displayOrder
        .where((id) => !_hiddenColumnIds.contains(id))
        .toList();
    if (adjustedIndex >= 0 && adjustedIndex < visibleOrder.length) {
      return visibleOrder[adjustedIndex];
    }
    return null;
  }

  /// Updates the legacy single-column sort index for backwards compatibility
  /// with the painter (which still uses a single sortColumnIndex for the arrow).
  void _updateLegacySortIndex(int? hitColumnIndex) {
    if (_sortService.sortModel.isEmpty) {
      _legacySortColumnIndex = null;
    } else {
      // For single sort, use the hit column index directly.
      // For multi-sort, the painter uses the sort model map instead.
      _legacySortColumnIndex = hitColumnIndex;
    }
  }

  /// Emits the sort changed event with the current sort model.
  void _emitSortChanged() {
    _purgeInfiniteCacheOnChange();
    final sortEvent = OsSortChangedEvent(sortModel: _sortService.sortModel);
    widget.onSortChanged?.call(sortEvent);
    _controller.emitSortChanged(sortEvent);
    _notifyStateChanged('sort');
  }

  /// Applies per-column sort declarations (sort/initialSort/sortIndex on OsColumnDef)
  /// when no grid-level initialSort is provided.
  void _applyPerColumnInitialSort() {
    final flatCols = <OsColumnDef>[];
    final tempSpans = <ColumnGroupSpan>[];
    _flattenColumnDefs(_effectiveColumnDefs, flatCols, tempSpans);

    // Collect columns that have sort or initialSort set
    final sortEntries = <_SortStateEntry>[];
    for (final col in flatCols) {
      final direction = col.sort ?? col.initialSort;
      if (direction != null) {
        sortEntries.add(
          _SortStateEntry(
            colId: col.effectiveColId,
            direction: direction,
            sortIndex: col.sortIndex,
          ),
        );
      }
    }

    if (sortEntries.isEmpty) return;

    // Sort by sortIndex (entries without sortIndex go at the end, in definition order)
    sortEntries.sort((a, b) {
      final aIdx = a.sortIndex ?? 999999;
      final bIdx = b.sortIndex ?? 999999;
      return aIdx.compareTo(bIdx);
    });

    final sortModel = sortEntries
        .map((e) => OsSortModel(colId: e.colId, sort: e.direction))
        .toList();
    _sortService.setSortModel(sortModel);
  }

  /// Recalculates the page size based on the grid's viewport height.
  ///
  /// Used when [OsPagination.paginationAutoPageSize] is enabled.
  /// Calculates: floor((gridBodyHeight - headerHeight - floatingFilterHeight) / rowHeight)
  void _recalculateAutoPageSize() {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;

    final gridHeight = renderBox.size.height;
    final headerHeight = _effectiveHeaderHeight;
    final floatingFilterHeight = widget.floatingFilter
        ? widget.floatingFilterHeight
        : 0.0;
    final hasGroupHeaders = _effectiveColumnDefs.any((d) => d is OsColumnGroup);
    final groupHeaderHeight = hasGroupHeaders ? 36.0 : 0.0;
    // Account for pagination footer (approximately 48px)
    const paginationFooterHeight = 48.0;

    final availableHeight =
        gridHeight -
        headerHeight -
        floatingFilterHeight -
        groupHeaderHeight -
        paginationFooterHeight;
    final rowHeight = _effectiveRowHeight;

    if (availableHeight > 0 && rowHeight > 0) {
      final calculatedPageSize = (availableHeight / rowHeight).floor();
      final newPageSize = calculatedPageSize.clamp(1, 10000);
      if (newPageSize != _pageSize) {
        _pageSize = newPageSize;
        // Ensure current page is still valid
        _currentPage = 0;
      }
    }
  }

  /// Builds the sort indicator map for the painter (column index → info).
  ///
  /// Resolves colIds from the sort model to display column indices so the
  /// painter can render arrows and priority numbers on the correct headers.
  Map<int, SortIndicatorInfo>? _buildSortIndicators() {
    if (!_sortService.isSortActive) return null;

    final flatCols = <OsColumnDef>[];
    final tempSpans = <ColumnGroupSpan>[];
    _flattenColumnDefs(_effectiveColumnDefs, flatCols, tempSpans);

    int offset = 0;
    if (widget.rowSelection?.hasCheckboxes == true) offset++;
    if (widget.rowNumbers) offset++;
    if (widget.rowDrag) offset++;

    final displayOrder =
        _columnOrder ?? flatCols.map((c) => c.effectiveColId).toList();
    final visibleOrder = displayOrder
        .where((id) => !_hiddenColumnIds.contains(id))
        .toList();

    final isMulti = _sortService.isMultiSorting;
    final indicators = <int, SortIndicatorInfo>{};

    for (var i = 0; i < _sortService.sortModel.length; i++) {
      final model = _sortService.sortModel[i];
      final visibleIdx = visibleOrder.indexOf(model.colId);
      if (visibleIdx >= 0) {
        indicators[visibleIdx + offset] = SortIndicatorInfo(
          direction: model.sort,
          priority: i + 1,
          isMultiSort: isMulti,
        );
      }
    }

    return indicators.isEmpty ? null : indicators;
  }

  /// Returns the sort direction for a column at the given display index,
  /// or `null` if the column is not sorted.
  OsSortDirection? _getColumnSortDirection(int columnIndex) {
    final colId = _resolveColIdFromHitIndex(columnIndex);
    if (colId == null) return null;
    return _sortService.getSortDirection(colId);
  }

  /// Applies column pinning from the column menu.
  void _applyPinFromMenu(int columnIndex, OsColumnPin? pin) =>
      _columns.pinFromMenu(columnIndex, pin);

  /// Auto-sizes a single column to fit its content.
  ///
  /// Measures the widest cell value (including header) and sets the column
  /// width accordingly.
  void _autosizeColumn(int columnIndex) => _columns.autosize(columnIndex);

  /// Auto-sizes all columns to fit their content.
  void _autosizeAllColumns() => _columns.autosizeAll();

  /// Resets all columns to their default widths and clears pin overrides.
  void _resetColumns() => _columns.reset();

  /// Called when the filter popup applies a new filter model.
  void _onFilterPopupApply(String colId, OsColumnFilterModel? model) {
    if (model == null || !model.isActive) {
      // Clear the filter
      _columnFilterModels.remove(colId);
      _columnFilterTexts.remove(colId);
      _columnFilterOperations.remove(colId);
    } else {
      // Apply the filter model
      _columnFilterModels[colId] = model;

      if (model.filterType == 'set') {
        // Set filters surface a read-only selection count in the floating
        // filter row; there is no operation/text input for them.
        _columnFilterOperations.remove(colId);
        _columnFilterTexts[colId] = '${model.values?.length ?? 0} selected';
      } else {
        // Sync the floating filter text and operation from the first condition
        if (model.conditions.isNotEmpty) {
          final firstCondition = model.conditions.first;
          _columnFilterOperations[colId] = firstCondition.type;
          _columnFilterTexts[colId] = firstCondition.filter?.toString() ?? '';
        }
      }
    }

    setState(() {
      _reprocessData();
    });
    _emitFilterChangedEvent();
  }

  /// Builds the full filter model and emits the filter changed event.
  void _emitFilterChangedEvent() {
    _purgeInfiniteCacheOnChange();
    final filterModel = <String, dynamic>{};

    // Include quick filter if active
    if (widget.quickFilterText != null && widget.quickFilterText!.isNotEmpty) {
      filterModel['quickFilter'] = widget.quickFilterText;
    }

    // Include per-column filter models
    for (final entry in _columnFilterModels.entries) {
      if (entry.value.isActive) {
        filterModel[entry.key] = entry.value.toJson();
      }
    }

    // Include custom filter models
    for (final entry in _customFilterModels.entries) {
      filterModel[entry.key] = {'filterType': 'custom', 'model': entry.value};
    }

    final filterEvent = OsFilterChangedEvent(filterModel: filterModel);
    widget.onFilterChanged?.call(filterEvent);
    _controller.emitFilterChanged(filterEvent);
    _notifyStateChanged('filter');
  }

  /// Called when a custom filter's model changes.
  void _onCustomFilterModelChanged(String colId, dynamic model) {
    final col = _filterPopupColDef;
    if (col == null) return;

    final filterConfig = col.filter;
    if (filterConfig is! OsCustomFilter) return;

    if (model == null || !filterConfig.isFilterActive(model)) {
      // Clear the custom filter
      _customFilterModels.remove(colId);
      _columnFilterTexts.remove(colId);
    } else {
      // Apply the custom filter model
      _customFilterModels[colId] = model;

      // Update floating filter text from getModelAsString
      if (filterConfig.getModelAsString != null) {
        final displayText = filterConfig.getModelAsString!(model);
        if (displayText.isNotEmpty) {
          _columnFilterTexts[colId] = displayText;
        } else {
          _columnFilterTexts.remove(colId);
        }
      } else {
        // Generic indicator
        _columnFilterTexts[colId] = '⚡';
      }
    }

    setState(() {
      _reprocessData();
    });
    _emitFilterChangedEvent();
  }

  /// Builds the custom filter popup widget.
  Widget _buildCustomFilterPopup() {
    final colId = _filterPopupColId!;
    final col = _filterPopupColDef!;
    final filterConfig = col.filter as OsCustomFilter;
    final currentModel = _customFilterModels[colId];

    final theme = widget.theme;
    final bgColor = theme?.backgroundColor ?? const Color(0xFF1F2836);
    final borderColor = theme?.borderColor ?? const Color(0xFF3D4A5C);
    final chromeColor = theme?.chromeBackgroundColor ?? const Color(0xFF222B3A);
    final fgColor = theme?.foregroundColor ?? Colors.white;

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(6),
      color: bgColor,
      child: Container(
        width: 240,
        decoration: BoxDecoration(
          border: Border.all(color: borderColor, width: 1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: chromeColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(5),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      col.effectiveHeaderName,
                      style: TextStyle(
                        fontFamily: 'IBM Plex Sans',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: fgColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  GestureDetector(
                    onTap: _dismissFilterPopup,
                    child: Icon(
                      Icons.close,
                      size: 16,
                      color: fgColor.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            // Custom filter content
            Padding(
              padding: const EdgeInsets.all(12),
              child: filterConfig.builder(
                context,
                CustomFilterParams(
                  model: currentModel,
                  colDef: col,
                  column: col.field ?? col.effectiveColId,
                  onModelChanged: (model) =>
                      _onCustomFilterModelChanged(colId, model),
                  getValue: (row) {
                    if (row is Map<String, dynamic> && col.field != null) {
                      return row[col.field];
                    }
                    return null;
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Range selection handlers ---

  /// Handles the start of a range drag on a data cell.
  ///
  /// If Ctrl/Cmd is held and multi-ranges are allowed, starts a new range
  /// without clearing existing ones. Otherwise, clears existing ranges first.
  void _handleRangeDragStart(DataCellHit hit) {
    final isCtrlHeld = HardwareKeyboard.instance.logicalKeysPressed.any(
      (key) =>
          key == LogicalKeyboardKey.controlLeft ||
          key == LogicalKeyboardKey.controlRight ||
          key == LogicalKeyboardKey.metaLeft ||
          key == LogicalKeyboardKey.metaRight,
    );

    final suppressMulti = widget.cellSelection?.suppressMultiRanges ?? true;

    setState(() {
      if (!isCtrlHeld || suppressMulti) {
        // Clear existing ranges and start fresh
        _controller.cellRanges = [
          CellRange(
            startRow: hit.rowIndex,
            endRow: hit.rowIndex,
            startColumn: hit.columnIndex,
            endColumn: hit.columnIndex,
          ),
        ];
      } else {
        // Add a new range (Ctrl+click with multi-ranges enabled)
        final existing = _controller.getCellRanges();
        _controller.cellRanges = [
          ...existing,
          CellRange(
            startRow: hit.rowIndex,
            endRow: hit.rowIndex,
            startColumn: hit.columnIndex,
            endColumn: hit.columnIndex,
          ),
        ];
      }
    });

    // Emit started event
    final event = OsRangeSelectionChangedEvent(
      ranges: _controller.getCellRanges(),
      started: true,
      finished: false,
    );
    _controller.emitRangeSelectionChanged(event);
  }

  /// Handles drag movement — extends the last range to the new cell position.
  void _handleRangeDragUpdate(int rowIndex, int columnIndex) {
    final ranges = _controller.getCellRanges();
    if (ranges.isEmpty) return;

    // Update the last range's end position
    final lastRange = ranges.last;
    final updatedRange = lastRange.copyWithEnd(
      endRow: rowIndex,
      endColumn: columnIndex,
    );

    setState(() {
      _controller.cellRanges = [
        ...ranges.sublist(0, ranges.length - 1),
        updatedRange,
      ];
    });

    // Emit in-progress event (not finished)
    final event = OsRangeSelectionChangedEvent(
      ranges: _controller.getCellRanges(),
      started: false,
      finished: false,
    );
    _controller.emitRangeSelectionChanged(event);
  }

  /// Handles the end of a range drag.
  void _handleRangeDragEnd() {
    final event = OsRangeSelectionChangedEvent(
      ranges: _controller.getCellRanges(),
      started: false,
      finished: true,
    );
    _controller.emitRangeSelectionChanged(event);
  }

  /// Handles Shift+click to extend the current range to the clicked cell.
  void _handleRangeExtend(int rowIndex, int columnIndex) {
    final ranges = _controller.getCellRanges();

    if (ranges.isEmpty) {
      // No existing range — create a new one from (0,0) to the clicked cell
      setState(() {
        _controller.cellRanges = [
          CellRange(
            startRow: 0,
            endRow: rowIndex,
            startColumn: 0,
            endColumn: columnIndex,
          ),
        ];
      });
    } else {
      // Extend the last range's end to the clicked cell
      final lastRange = ranges.last;
      final updatedRange = lastRange.copyWithEnd(
        endRow: rowIndex,
        endColumn: columnIndex,
      );
      setState(() {
        _controller.cellRanges = [
          ...ranges.sublist(0, ranges.length - 1),
          updatedRange,
        ];
      });
    }

    final event = OsRangeSelectionChangedEvent(
      ranges: _controller.getCellRanges(),
      started: false,
      finished: true,
    );
    _controller.emitRangeSelectionChanged(event);
  }

  /// Handles Escape key to clear all range selections.
  void _handleRangeClear() {
    if (_controller.getCellRanges().isEmpty) return;

    setState(() {
      _controller.cellRanges = [];
    });

    const event = OsRangeSelectionChangedEvent(
      ranges: [],
      started: false,
      finished: true,
    );
    _controller.emitRangeSelectionChanged(event);
  }

  /// Applies a range fill (quality program v3 item 10).
  ///
  /// Called when the user releases a drag that started on the active range's
  /// fill handle. The fill direction is inferred from the release cell:
  /// below/above the source fills the source columns over the target rows;
  /// right/left of the source fills the source rows over the target columns.
  ///
  /// Copy mode (default) replicates the source values as a repeating
  /// pattern. Ctrl/Cmd+drag fills a numeric series instead: the step is the
  /// difference of the last two source values, or ±1 for a single numeric
  /// source cell. Columns/rows without an all-numeric source fall back to
  /// copy mode.
  ///
  /// All writes happen in one [setState]; each changed cell emits
  /// `onCellValueChanged` and the batch is pushed as a single undo action.
  void _handleFillDrag(int endRow, int endCol) {
    final ranges = _controller.getCellRanges();
    if (ranges.isEmpty) return;
    final source = ranges.last;

    final data = _processedRowData ?? widget.rowData;
    if (data == null || data.isEmpty) return;
    // Use the build's flat column list so fill column indices match the
    // painted/hit-tested column order (falls back to a fresh flatten).
    final flatColumns = _flatColumnsCache.isNotEmpty
        ? _flatColumnsCache
        : _getVisibleFlatColumns();
    if (flatColumns.isEmpty) return;

    final srcTop = source.normalizedStartRow;
    final srcBottom = source.normalizedEndRow;
    final srcLeft = source.normalizedStartColumn;
    final srcRight = source.normalizedEndColumn;

    // The source range must lie fully within the data bounds.
    if (srcTop < 0 ||
        srcBottom >= data.length ||
        srcLeft < 0 ||
        srcRight >= flatColumns.length) {
      return;
    }

    // Infer the fill direction from where the drag was released and compute
    // the target rectangle (clamped to the data bounds).
    int fillTop;
    int fillBottom;
    int fillLeft;
    int fillRight;
    if (endRow > srcBottom) {
      fillTop = srcBottom + 1;
      fillBottom = endRow;
      fillLeft = srcLeft;
      fillRight = srcRight;
    } else if (endRow < srcTop) {
      fillTop = endRow;
      fillBottom = srcTop - 1;
      fillLeft = srcLeft;
      fillRight = srcRight;
    } else if (endCol > srcRight) {
      fillTop = srcTop;
      fillBottom = srcBottom;
      fillLeft = srcRight + 1;
      fillRight = endCol;
    } else if (endCol < srcLeft) {
      fillTop = srcTop;
      fillBottom = srcBottom;
      fillLeft = endCol;
      fillRight = srcLeft - 1;
    } else {
      // Released inside the source range — nothing to fill.
      return;
    }
    fillTop = fillTop.clamp(0, data.length - 1);
    fillBottom = fillBottom.clamp(0, data.length - 1);
    fillLeft = fillLeft.clamp(0, flatColumns.length - 1);
    fillRight = fillRight.clamp(0, flatColumns.length - 1);
    if (fillBottom < fillTop || fillRight < fillLeft) return;

    final isSeriesFill = HardwareKeyboard.instance.logicalKeysPressed.any(
      (key) =>
          key == LogicalKeyboardKey.controlLeft ||
          key == LogicalKeyboardKey.controlRight ||
          key == LogicalKeyboardKey.metaLeft ||
          key == LogicalKeyboardKey.metaRight,
    );

    final fillDownwards = endRow > srcBottom;
    final fillRightwards = endCol > srcRight;
    final vertical = fillDownwards || endRow < srcTop;

    final undoChanges = <CellValueChange>[];

    setState(() {
      for (int r = fillTop; r <= fillBottom; r++) {
        for (int c = fillLeft; c <= fillRight; c++) {
          final col = flatColumns[c];
          final row = data[r];
          if (!_isCellEditable(col, row, r)) continue;

          final int distance;
          final List<dynamic> sourceLine;
          if (vertical) {
            distance = fillDownwards ? r - srcBottom : srcTop - r;
            sourceLine = [
              for (int s = srcTop; s <= srcBottom; s++)
                _resolveColumnValue(col, data[s], s),
            ];
          } else {
            distance = fillRightwards ? c - srcRight : srcLeft - c;
            sourceLine = [
              for (int s = srcLeft; s <= srcRight; s++)
                _resolveColumnValue(flatColumns[s], row, r),
            ];
          }

          final oldValue = _resolveColumnValue(col, row, r);
          final newValue = _computeFillValue(
            sourceLine: sourceLine,
            distance: distance,
            forwards: vertical ? fillDownwards : fillRightwards,
            series: isSeriesFill,
          );
          if (newValue == oldValue) continue;

          _applyFillValue(col, row, r, newValue);
          undoChanges.add(
            CellValueChange(
              rowIndex: r,
              rowId: _controller.rowIdFor(row),
              columnId: col.effectiveColId,
              oldValue: oldValue,
              newValue: newValue,
            ),
          );

          final changeEvent = OsCellValueChangedEvent<TData>(
            data: row,
            rowIndex: r,
            colDef: OsColumnDef<TData>(field: col.effectiveColId),
            oldValue: oldValue,
            newValue: newValue,
          );
          widget.onCellValueChanged?.call(changeEvent);
          _controller.emitCellValueChanged(changeEvent);
        }
      }
    });

    final undo = _undoRedo.service;
    if (undoChanges.isNotEmpty && undo != null) {
      undo.pushAction(UndoRedoAction(undoChanges));
    }
  }

  /// Resolves the value a fill writes [distance] cells (1-based) beyond the
  /// [sourceLine] of values, repeating the pattern [forwards] (down/right)
  /// or continuing it backwards (up/left).
  ///
  /// With [series] set and an all-numeric source, an arithmetic series is
  /// continued instead: the step is the difference of the last two source
  /// values, or ±1 for a single source cell.
  dynamic _computeFillValue({
    required List<dynamic> sourceLine,
    required int distance,
    required bool forwards,
    required bool series,
  }) {
    final n = sourceLine.length;
    if (n == 0) return null;
    dynamic copyValue() => forwards
        ? sourceLine[(distance - 1) % n]
        : sourceLine[n - 1 - ((distance - 1) % n)];

    if (series) {
      final numbers = sourceLine.whereType<num>().toList();
      if (numbers.length == n) {
        final step = n >= 2
            ? numbers[n - 1] - numbers[n - 2]
            : (numbers.first < 0 ? -1 : 1);
        if (forwards) {
          return numbers.last + step * distance;
        }
        return numbers.first - step * distance;
      }
    }
    return copyValue();
  }

  /// Writes a fill value, honouring a custom valueSetter when present.
  void _applyFillValue(
    OsColumnDef col,
    TData row,
    int rowIndex,
    dynamic value,
  ) {
    final setter =
        (col as dynamic).valueSetter
            as bool Function(ValueSetterParams<TData>)?;
    if (setter != null) {
      setter(
        ValueSetterParams<TData>(
          data: row,
          colDef: col,
          newValue: value,
          oldValue: _resolveColumnValue(col, row, rowIndex),
          rowIndex: rowIndex,
          source: 'fill',
        ),
      );
      return;
    }
    _setCellValue(col, row, value);
  }

  /// Flattens column defs (including groups) into leaf columns and computes group spans.
  void _flattenColumnDefs(
    List<OsColumnDefBase> defs,
    List<OsColumnDef> outColumns,
    List<ColumnGroupSpan> outSpans,
  ) {
    for (final def in defs) {
      if (def is OsColumnDef) {
        outColumns.add(_applyModuleGates(def));
      } else if (def is OsColumnGroup) {
        final startIndex = outColumns.length;
        // Recursively flatten children
        for (final child in def.children) {
          if (child is OsColumnDef) {
            outColumns.add(_applyModuleGates(child));
          } else if (child is OsColumnGroup) {
            _flattenColumnDefs(child.children, outColumns, outSpans);
          }
        }
        final endIndex = outColumns.length - 1;
        if (endIndex >= startIndex) {
          // Split group spans by pinned state to avoid spanning across sections
          int? currentSpanStart;
          dynamic currentPinned;
          bool isFirstSpan = true;
          for (int i = startIndex; i <= endIndex; i++) {
            final pinned = outColumns[i].pinned;
            if (currentSpanStart == null) {
              currentSpanStart = i;
              currentPinned = pinned;
            } else if (pinned != currentPinned) {
              // End current span, start new one
              outSpans.add(
                ColumnGroupSpan(
                  headerName: isFirstSpan ? def.headerName : '',
                  startIndex: currentSpanStart,
                  endIndex: i - 1,
                ),
              );
              isFirstSpan = false;
              currentSpanStart = i;
              currentPinned = pinned;
            }
          }
          // Close final span
          if (currentSpanStart != null) {
            outSpans.add(
              ColumnGroupSpan(
                headerName: isFirstSpan ? def.headerName : '',
                startIndex: currentSpanStart,
                endIndex: endIndex,
              ),
            );
          }
        }
      }
    }
  }

  /// Applies module gating to a flattened column definition.
  ///
  /// Fast path: when no explicit module registry is in effect (or the
  /// definition uses no gated feature) the definition is returned
  /// unchanged. Gated features — sparkline rendering and the set filter —
  /// are stripped via a clone so the render/filter pipeline never sees
  /// configuration for a module that is not registered.
  OsColumnDef _applyModuleGates(OsColumnDef def) {
    if (!_hasExplicitModules) return def;
    final stripSparkline =
        !_sparklineModuleEnabled &&
        (def.builtInCellRenderer == OsBuiltInCellRenderer.sparkline ||
            def.sparklineOptions != null);
    final stripSetFilter =
        !_setFilterModuleEnabled && def.filter is OsSetFilter;
    if (!stripSparkline && !stripSetFilter) return def;
    if (stripSparkline) {
      GridDiagnostics.warnOnce(
        'module:gated:sparkline',
        'Sparkline renderer is ignored: register SparklineModule (via the '
            'modules parameter or OsGrid.registerModules) to render sparklines.',
      );
    }
    if (stripSetFilter) {
      GridDiagnostics.warnOnce(
        'module:gated:setFilter',
        'OsSetFilter is ignored: register SetFilterModule (via the modules '
            'parameter or OsGrid.registerModules) to use the set filter.',
      );
    }
    return _cloneColumnDefWithout(
      def,
      stripSparkline: stripSparkline,
      stripSetFilter: stripSetFilter,
    );
  }

  /// Clones [def] with module-gated features removed.
  ///
  /// Mirrors the field list of `OsColumnDef.copyWith`; the gated fields are
  /// the only ones that can be cleared (copyWith keeps existing values for
  /// null arguments).
  OsColumnDef<TData> _cloneColumnDefWithout(
    OsColumnDef def, {
    required bool stripSparkline,
    required bool stripSetFilter,
  }) {
    return OsColumnDef<TData>(
      field: def.field,
      colId: def.colId,
      headerName: def.headerName,
      headerValueGetter: def.headerValueGetter,
      width: def.width,
      minWidth: def.minWidth,
      maxWidth: def.maxWidth,
      flex: def.flex,
      valueGetter: def.valueGetter,
      valueFormatter: def.valueFormatter,
      cellRenderer: def.cellRenderer,
      cellRendererBuilder: def.cellRendererBuilder,
      builtInCellRenderer: stripSparkline ? null : def.builtInCellRenderer,
      sparklineOptions: stripSparkline ? null : def.sparklineOptions,
      sortable: def.sortable,
      resizable: def.resizable,
      filter: stripSetFilter ? null : def.filter,
      editable: def.editable,
      editableCallback: def.editableCallback,
      cellEditor: def.cellEditor,
      valueSetter: def.valueSetter,
      valueParser: def.valueParser,
      singleClickEdit: def.singleClickEdit,
      suppressMovable: def.suppressMovable,
      type: def.type,
      colSpan: def.colSpan,
      rowSpan: def.rowSpan,
      spanRows: def.spanRows,
      pinned: def.pinned,
      hide: def.hide,
      lockVisible: def.lockVisible,
      lockPinned: def.lockPinned,
      lockPosition: def.lockPosition,
      suppressMenu: def.suppressMenu,
      checkboxSelection: def.checkboxSelection,
      headerCheckboxSelection: def.headerCheckboxSelection,
      cellStyle: def.cellStyle,
      cellClass: def.cellClass,
      theme: def.theme,
      comparator: def.comparator,
      sortingOrder: def.sortingOrder,
      sort: def.sort,
      initialSort: def.initialSort,
      sortIndex: def.sortIndex,
      getQuickFilterText: def.getQuickFilterText,
      autoHeight: def.autoHeight,
      wrapText: def.wrapText,
      rowGroup: def.rowGroup,
      aggFunc: def.aggFunc,
      pivot: def.pivot,
      tooltipField: def.tooltipField,
      tooltipValueGetter: def.tooltipValueGetter,
      headerTooltip: def.headerTooltip,
    );
  }

  /// Builds a mapping from colId to original group info.
  ///
  /// This mirrors OS Grid's `originalParent` concept: each leaf column
  /// remembers which group it was originally defined in. This is used
  /// to recompute group spans after column reorder.
  Map<String, _OriginalGroupInfo> _buildColumnGroupMembership(
    List<OsColumnDefBase> defs, [
    _OriginalGroupInfo? parentGroup,
  ]) {
    final result = <String, _OriginalGroupInfo>{};
    for (final def in defs) {
      if (def is OsColumnDef) {
        if (parentGroup != null) {
          result[def.effectiveColId] = parentGroup;
        }
      } else if (def is OsColumnGroup) {
        final groupInfo = _OriginalGroupInfo(
          groupId: def.groupId ?? def.headerName,
          headerName: def.headerName,
        );
        for (final child in def.children) {
          if (child is OsColumnDef) {
            result[child.effectiveColId] = groupInfo;
          } else if (child is OsColumnGroup) {
            result.addAll(_buildColumnGroupMembership([child], groupInfo));
          }
        }
      }
    }
    return result;
  }

  /// Recomputes group spans from the current column order based on original
  /// group membership.
  ///
  /// This implements the same logic as OS Grid's `createColumnGroups`:
  /// adjacent columns that share the same original parent group are grouped
  /// together. When a column is moved out of its group, the group splits.
  /// When a column is moved between columns of the same group, it joins.
  ///
  /// Groups are also split at pin boundaries (left/center/right) to avoid
  /// a single group header spanning across pinned sections.
  List<ColumnGroupSpan> _recomputeGroupSpans(
    List<OsColumnDef> orderedColumns,
    Map<String, _OriginalGroupInfo> membership,
  ) {
    final spans = <ColumnGroupSpan>[];
    if (orderedColumns.isEmpty) return spans;

    int i = 0;
    while (i < orderedColumns.length) {
      final colId = orderedColumns[i].effectiveColId;
      final group = membership[colId];

      if (group == null) {
        // Column has no group — skip it (no span needed)
        i++;
        continue;
      }

      // Find the extent of adjacent columns with the same group and same pin
      final pinned = orderedColumns[i].pinned;
      int j = i + 1;
      while (j < orderedColumns.length) {
        final nextColId = orderedColumns[j].effectiveColId;
        final nextGroup = membership[nextColId];
        final nextPinned = orderedColumns[j].pinned;
        if (nextGroup == null ||
            nextGroup.groupId != group.groupId ||
            nextPinned != pinned) {
          break;
        }
        j++;
      }

      // Create a span for this run of same-group, same-pin columns.
      // Single columns still get a span to maintain the 2-level header structure.
      spans.add(
        ColumnGroupSpan(
          headerName: group.headerName,
          startIndex: i,
          endIndex: j - 1,
        ),
      );

      i = j;
    }

    return spans;
  }

  @override
  Widget build(BuildContext context) {
    // Flatten column defs (handling groups) and compute group spans
    var allFlatColumns = <OsColumnDef>[];
    final groupSpans = <ColumnGroupSpan>[];
    _flattenColumnDefs(_effectiveColumnDefs, allFlatColumns, groupSpans);

    // Resolve defaultColDef / columnTypes before order/hide/pin so every
    // downstream step sees the merged definitions.
    if (widget.defaultColDef != null ||
        (widget.columnTypes?.isNotEmpty ?? false)) {
      _warnUnknownColumnTypes();
      allFlatColumns = ColumnDefResolver.resolve(
        columns: allFlatColumns,
        defaultColDef: widget.defaultColDef,
        columnTypes: widget.columnTypes,
      );
      _warnColumnsMissingField(allFlatColumns);
    }

    // Apply column order (if set via API)
    List<OsColumnDef> orderedColumns;
    if (_columnOrder != null) {
      final colMap = {for (final c in allFlatColumns) c.effectiveColId: c};
      orderedColumns = [
        for (final id in _columnOrder!)
          if (colMap.containsKey(id)) colMap[id]!,
      ];
      // Append any columns not in the order list (shouldn't happen, but safety)
      for (final col in allFlatColumns) {
        if (!_columnOrder!.contains(col.effectiveColId)) {
          orderedColumns.add(col);
        }
      }
      // Recompute group spans based on adjacency of columns from the same
      // original group (mirrors OS Grid's createColumnGroups algorithm).
      final membership = _buildColumnGroupMembership(_effectiveColumnDefs);
      groupSpans.clear();
      groupSpans.addAll(_recomputeGroupSpans(orderedColumns, membership));
    } else {
      orderedColumns = allFlatColumns;
    }

    // Filter hidden columns
    final flatColumns = orderedColumns
        .where((col) => !_hiddenColumnIds.contains(col.effectiveColId))
        .toList();

    // Recompute group spans for visible columns after filtering hidden ones
    if (_hiddenColumnIds.isNotEmpty) {
      final membership = _buildColumnGroupMembership(_effectiveColumnDefs);
      groupSpans.clear();
      groupSpans.addAll(_recomputeGroupSpans(flatColumns, membership));
    }

    // Apply pin overrides by colId
    if (_columnPinOverrides.isNotEmpty) {
      for (int i = 0; i < flatColumns.length; i++) {
        final colId = flatColumns[i].effectiveColId;
        if (_columnPinOverrides.containsKey(colId)) {
          // copyWith (with explicit pinned override) preserves every other
          // column property — spans, tooltips, grouping, sort config, etc.
          flatColumns[i] = flatColumns[i].copyWith(
            pinned: _columnPinOverrides[colId],
          );
        }
      }
      // Recompute group spans after pin changes (pin boundaries split groups)
      final membership = _buildColumnGroupMembership(_effectiveColumnDefs);
      groupSpans.clear();
      groupSpans.addAll(_recomputeGroupSpans(flatColumns, membership));
    }

    // Build index-based column widths map for VirtualisedGrid
    // (VirtualisedGrid still uses int-indexed widths internally)
    final indexedColumnWidths = <int, double>{};
    for (int i = 0; i < flatColumns.length; i++) {
      final colId = flatColumns[i].effectiveColId;
      if (_columnWidths.containsKey(colId)) {
        indexedColumnWidths[i] = _columnWidths[colId]!;
      }
    }

    // Compose the display column list: synthetic prefix columns (drag
    // handle, row numbers, checkbox) ahead of the data columns, with group
    // spans and indexed widths shifted once by the prefix length.
    final hasCheckboxes = widget.rowSelection?.hasCheckboxes == true;
    // Per-column checkboxes (AG Grid colDef.checkboxSelection): when any
    // data column opts in, the synthetic checkbox column is suppressed.
    final hasPerColumnCheckboxes = flatColumns.any(
      (c) => c.checkboxSelection == true,
    );
    final showSyntheticCheckbox = hasCheckboxes && !hasPerColumnCheckboxes;
    final perColumnHeaderCheckbox =
        hasPerColumnCheckboxes &&
        flatColumns.any((c) => c.headerCheckboxSelection == true);
    String? checkboxHeaderState;
    if (showSyntheticCheckbox || perColumnHeaderCheckbox) {
      final selectedCount = _controller.selectedIndices.length;
      final totalDataRows =
          ((_processedRowData ?? widget.rowData) as List?)?.length ?? 0;
      checkboxHeaderState = selectedCount == 0
          ? 'none'
          : (selectedCount >= totalDataRows && totalDataRows > 0)
          ? 'all'
          : 'partial';
    }
    final composed = GridModelResolver.composeDisplayColumns(
      dataColumns: flatColumns,
      groupSpans: groupSpans,
      indexedWidths: indexedColumnWidths,
      checkbox: showSyntheticCheckbox,
      rowNumbers: widget.rowNumbers,
      rowDrag: widget.rowDrag,
      checkboxHeaderState: checkboxHeaderState,
    );
    flatColumns
      ..clear()
      ..addAll(composed.columns);
    groupSpans
      ..clear()
      ..addAll(composed.spans);
    indexedColumnWidths
      ..clear()
      ..addAll(composed.widths);

    // Per-column header checkboxes: encode tri-state in headerName (same
    // token trick as the synthetic column) so the painter can render it.
    if (perColumnHeaderCheckbox && checkboxHeaderState != null) {
      for (int i = 0; i < flatColumns.length; i++) {
        if (flatColumns[i].headerCheckboxSelection == true) {
          flatColumns[i] = flatColumns[i].copyWith(
            headerName: checkboxHeaderState,
          );
        }
      }
    }
    final effectiveData = _processedRowData ?? widget.rowData;
    final typedSource = effectiveData ?? const [];

    // RULE ZERO: only registers a post-frame callback; never emits inline.
    _maybeScheduleFirstDataRendered();

    // Shared field → column index for the lazy typed-row conversion (quality
    // program v3 item 15) — built once per build, not once per row.
    final lazyFieldIndex = GridModelResolver.buildLazyFieldIndex(flatColumns);

    // Display rows for the painter. Map rows pass through unchanged; typed
    // rows are wrapped in lazy display maps whose valueGetters fire on first
    // per-cell read (visible-window entry) instead of eagerly for every row
    // × column. Infinite mode, the server-side row model, grouping/pivot
    // below replace this list with their own display maps when active.
    var rowData = _isServerSideMode
        ? _buildServerSideRowData(flatColumns)
        : _isInfiniteMode
        ? _buildInfiniteRowData(flatColumns)
        : [
            for (int i = 0; i < typedSource.length; i++)
              if (typedSource[i] is Map<String, dynamic>)
                typedSource[i] as Map<String, dynamic>
              else
                _typedRowToMap(typedSource[i], i, lazyFieldIndex),
          ];

    // Apply row grouping or tree-data flattening (after filter + sort,
    // before pagination).
    //
    // Tree data mode (widget.treeData) SKIPS the column-based grouping
    // pipeline entirely: the hierarchy is built from getDataPath segments
    // and every original row remains a leaf. When both are configured,
    // tree data takes precedence and row grouping is ignored (the
    // validator warns about this combination in debug mode).
    final groupCols = _getEffectiveGroupColumns();
    final isTreeDataMode =
        _treeDataActive &&
        widget.getDataPath != null &&
        !_isInfiniteMode &&
        !_isServerSideMode;
    if (isTreeDataMode) {
      rowData = _treeDataService.buildTreeData(
        data: effectiveData ?? [],
        getDataPath: widget.getDataPath!,
        state: _rowGroupState,
        typedLeafToMap: (row, index) =>
            _typedRowToMap(row, index, lazyFieldIndex),
      );
    } else if (groupCols.isNotEmpty && !_isInfiniteMode && !_isServerSideMode) {
      rowData = _rowGroupService.buildGroupedData(
        data: effectiveData ?? [],
        groupColumns: groupCols,
        state: _rowGroupState,
        valueColumns: _isPivotModeActive
            ? const [] // Pivot mode handles aggregation itself
            : _getEffectiveValueColumns(flatColumns),
        typedLeafToMap: (row, index) =>
            _typedRowToMap(row, index, lazyFieldIndex),
      );
    }

    // Apply pivot mode transformation (after grouping, before pagination)
    if (_isPivotModeActive &&
        groupCols.isNotEmpty &&
        !_isInfiniteMode &&
        !_isServerSideMode &&
        !isTreeDataMode) {
      final pivotCols = _getEffectivePivotColumns();
      final valueCols = _getEffectiveValueColumns(flatColumns);

      if (pivotCols.isNotEmpty && valueCols.isNotEmpty) {
        // Extract unique values from the raw filtered/sorted data.
        final rawTypedData = effectiveData ?? [];
        final uniqueValues = _pivotService.extractUniqueValues(
          data: rawTypedData,
          pivotColumns: pivotCols,
        );

        // Generate dynamic pivot result columns.
        final pivotResult = _pivotService.generatePivotColumns(
          uniqueValues: uniqueValues,
          pivotColumns: pivotCols,
          valueColumns: valueCols,
        );
        _lastPivotResult = pivotResult;

        // Compute pivot aggregation on the grouped display data.
        rowData = _pivotService.computePivotAggregation(
          displayData: rowData,
          rawData: rawTypedData,
          pivotColumns: pivotCols,
          valueColumns: valueCols,
          groupColumns: groupCols,
          pivotResultColumns: pivotResult.columns,
        );

        // Replace value columns in flatColumns with pivot result columns.
        // Keep group columns and special columns, replace everything else.
        final pivotColIds = pivotCols.map((c) => c.effectiveColId).toSet();
        final valueColIds = valueCols.map((c) => c.effectiveColId).toSet();

        // Remove value columns and pivot source columns from display.
        flatColumns.removeWhere((c) {
          final cid = c.effectiveColId;
          return valueColIds.contains(cid) || pivotColIds.contains(cid);
        });

        // Append the generated pivot result columns.
        flatColumns.addAll(pivotResult.columnDefs);
      } else {
        _lastPivotResult = null;
      }
    } else {
      _lastPivotResult = null;
    }

    // Apply pagination
    final totalRows = rowData.length;
    final isPaginated = widget.pagination != null;
    int totalPages = 1;

    // Handle paginationAutoPageSize: calculate page size from viewport
    if (isPaginated && widget.pagination!.paginationAutoPageSize) {
      _recalculateAutoPageSize();
    }

    if (isPaginated && rowData.isNotEmpty) {
      totalPages = (totalRows / _pageSize).ceil();
      _currentPage = _currentPage.clamp(0, totalPages - 1);
      final start = _currentPage * _pageSize;
      final end = (start + _pageSize).clamp(0, totalRows);
      rowData = rowData.sublist(start, end);
    }

    // Sync pagination state to controller for programmatic navigation
    _controller.updatePaginationState(
      currentPage: _currentPage,
      pageSize: _pageSize,
      totalPages: totalPages,
      totalRows: totalRows,
      isPaginated: isPaginated,
    );
    _controller.infiniteModeEnabled = _isInfiniteMode;

    // Sync page data to controller for page-scoped selection.
    //
    // For flat client-side data the page window is taken from the original
    // source rows so page-scoped selection works for Map AND typed rows.
    // Infinite mode keeps its placeholder display rows; tree-data,
    // grouping/pivot keep their synthetic display rows (previous behaviour).
    if (_isInfiniteMode ||
        isTreeDataMode ||
        _getEffectiveGroupColumns().isNotEmpty ||
        _isPivotModeActive) {
      _controller.pageData = rowData.cast<TData>();
    } else {
      final start = isPaginated ? _currentPage * _pageSize : 0;
      final end = (start + _pageSize).clamp(start, typedSource.length);
      _controller.pageData = [for (int i = start; i < end; i++) typedSource[i]];
    }

    // Inject row numbers and checkbox state if enabled
    if (widget.rowNumbers || hasCheckboxes || hasPerColumnCheckboxes) {
      final pageOffset = isPaginated ? _currentPage * _pageSize : 0;
      rowData = [
        for (int i = 0; i < rowData.length; i++)
          {
            ...rowData[i],
            if (widget.rowNumbers) SpecialColumns.rowNumber: pageOffset + i + 1,
            if (hasCheckboxes)
              ..._editing.resolveCheckboxCell(rowData[i], pageOffset + i),
          },
      ];
    }

    // Compute selected row count for status bar
    final selectedCount = _controller.selectedIndices.length;

    // Pre-compute row styles for visible rows
    Map<int, OsRowStyle>? computedRowStyles;
    if (widget.rowStyle != null || widget.getRowStyle != null) {
      computedRowStyles = <int, OsRowStyle>{};
      final sourceData = effectiveData;
      final pageOffset = isPaginated ? _currentPage * _pageSize : 0;
      for (int i = 0; i < rowData.length; i++) {
        OsRowStyle? style;

        // Start with static rowStyle
        if (widget.rowStyle != null) {
          style = widget.rowStyle;
        }

        // Merge with getRowStyle callback result (callback overrides static)
        if (widget.getRowStyle != null && sourceData != null) {
          final dataIndex = pageOffset + i;
          if (dataIndex < sourceData.length) {
            final params = RowStyleParams<TData>(
              data: sourceData[dataIndex],
              rowIndex: dataIndex,
            );
            final callbackStyle = widget.getRowStyle!(params);
            if (callbackStyle != null) {
              style = style?.merge(callbackStyle) ?? callbackStyle;
            }
          }
        }

        if (style != null) {
          computedRowStyles[i] = style;
        }
      }
      if (computedRowStyles.isEmpty) {
        computedRowStyles = null;
      }
    }

    // Cache flat columns for keyboard-initiated editing
    _flatColumnsCache = flatColumns;

    // Compute variable row height layout if getRowHeight or autoHeight columns exist
    // (computed pre-expansion: master/detail splices detail heights on top
    // of this base layout below).
    RowHeightLayout? rowHeightLayout = _computeRowHeightLayout(
      rowData,
      flatColumns,
      indexedColumnWidths,
    );

    // Master/detail rows (quality program v3 item 4): annotate master rows
    // and insert a synthetic detail row below every expanded master row.
    // The detail row's height is spliced into a variable layout so the
    // painter, hit testing and scroll metrics all account for it.
    final masterDetailApplies =
        _masterDetailConfigured &&
        !_isInfiniteMode &&
        !_isServerSideMode &&
        !isTreeDataMode &&
        groupCols.isEmpty;
    if (_masterDetailConfigured && !masterDetailApplies) {
      GridDiagnostics.warnOnce(
        'masterDetail:rowModel',
        'master/detail is ignored: it requires the client-side row model '
            'over flat rowData (row grouping, tree data, the infinite row '
            'model and the server-side row model are not supported).',
      );
    }
    _displayDetailRowCount = 0;
    if (masterDetailApplies) {
      final expansion = _applyMasterDetail(
        displayRows: rowData,
        baseLayout: rowHeightLayout,
        pageOffset: isPaginated ? _currentPage * _pageSize : 0,
      );
      if (expansion != null) {
        rowData = expansion.rows;
        if (expansion.heights != null) {
          rowHeightLayout = RowHeightLayout.variable(
            heights: expansion.heights!,
          );
        }
        _displayDetailRowCount = expansion.detailCount;
      }
    }

    // Store display data reference for hit testing (group row and
    // master/detail row detection) — post-expansion so hit testing sees
    // the synthetic detail rows too.
    _displayRowData = rowData;

    final grid = VirtualisedGrid(
      columns: flatColumns,
      rowData: rowData,
      rowHeight: _effectiveRowHeight,
      headerHeight: _effectiveHeaderHeight,
      theme: widget.theme,
      selectedRows: _controller.selectedIndices,
      scrollCommandNotifier: _controller.scrollCommandNotifier,
      columnWidths: indexedColumnWidths,
      sortColumnIndex: _sortColumnIndex,
      sortAscending: _sortAscending,
      sortIndicators: _buildSortIndicators(),
      columnGroupSpans: groupSpans.isNotEmpty ? groupSpans : null,
      floatingFilterHeight: widget.floatingFilter
          ? widget.floatingFilterHeight
          : 0,
      floatingFilterTexts: widget.floatingFilter ? _columnFilterTexts : null,
      floatingFilterOperations: widget.floatingFilter
          ? _columnFilterOperations
          : null,
      enableRangeSelection: widget.cellSelection != null,
      enableCharts:
          widget.enableIntegratedCharts && widget.cellSelection != null,
      onChartPaletteTap: _handleChartPaletteTap,
      cellRanges: _controller.getCellRanges(),
      enterNavigatesVertically: widget.enterNavigatesVertically,
      navigateToNextCell: widget.navigateToNextCell,
      tabToNextCell: widget.tabToNextCell,
      isEditing: _editCellRect != null,
      pinnedTopRowData: _buildPinnedRowMaps(
        widget.pinnedTopRowData,
        flatColumns,
      ),
      pinnedBottomRowData: _buildPinnedRowMaps(
        widget.pinnedBottomRowData,
        flatColumns,
      ),
      onCellTap: _handleCellTap,
      onCellDoubleTap: _handleCellDoubleTap,
      onHeaderTap: _handleHeaderTap,
      onColumnResize: _handleColumnResize,
      onHeaderResizeDoubleTap: _autosizeColumn,
      onCentreViewportWidthChanged: (width) => _centreViewportWidth = width,
      onCellEditRequest: _handleCellEditRequest,
      onEditStartRequested: _handleEditStartRequested,
      onFloatingFilterTap: widget.floatingFilter
          ? _handleFloatingFilterTap
          : null,
      onFloatingFilterOperationTap: widget.floatingFilter
          ? _cycleFilterOperation
          : null,
      onHeaderFilterIconTap: _handleHeaderFilterIconTap,
      onHeaderMenuIconTap: _handleHeaderMenuIconTap,
      onRangeDragStart: widget.cellSelection != null
          ? _handleRangeDragStart
          : null,
      onRangeDragUpdate: widget.cellSelection != null
          ? _handleRangeDragUpdate
          : null,
      onRangeDragEnd: widget.cellSelection != null ? _handleRangeDragEnd : null,
      onRangeExtend: widget.cellSelection != null ? _handleRangeExtend : null,
      onRangeClear: widget.cellSelection != null ? _handleRangeClear : null,
      onFillDrag: widget.cellSelection != null ? _handleFillDrag : null,
      onColumnDragStart: _handleColumnDragStart,
      onColumnDragUpdate: _handleColumnDragUpdate,
      onColumnDragEnd: _handleColumnDragEnd,
      onRowDragStart: widget.rowDrag ? _handleRowDragStart : null,
      onRowDragUpdate: widget.rowDrag ? _handleRowDragUpdate : null,
      onRowDragEnd: widget.rowDrag ? _handleRowDragEnd : null,
      onScrollStart: () {
        _commitEdit();
        if (_floatingFilterRect != null) _commitFloatingFilter();
        if (_filterPopupVisible) _dismissFilterPopup();
        if (_columnMenuVisible) _dismissColumnMenu();
        if (_contextMenuVisible) _dismissContextMenu();
        _dismissChartPalette();
        _tooltipService.hide();
        _notifyStateChanged('scroll');
      },
      scrollPositionNotifier: _scrollPositionNotifier,
      rowStyles: computedRowStyles,
      cellFlashes: _cellFlashCoordinator.flashes.isNotEmpty
          ? _cellFlashCoordinator.flashes
          : null,
      flashElapsed: _cellFlashCoordinator.elapsed,
      onUndoRequested: widget.undoRedoCellEditing
          ? () => _performUndo(source: 'ui')
          : null,
      onRedoRequested: widget.undoRedoCellEditing
          ? () => _performRedo(source: 'ui')
          : null,
      onCopyRequested: () => _performCopy(source: 'keyboard'),
      onCutRequested: () => _performCut(source: 'keyboard'),
      onPasteRequested: widget.suppressClipboardPaste
          ? null
          : () => _performPaste(source: 'keyboard'),
      onSecondaryTap: widget.suppressContextMenu ? null : _handleSecondaryTap,
      onContextMenuRequested: widget.suppressContextMenu
          ? null
          : _handleKeyboardContextMenu,
      focusedCellNotifier: _focusedCellNotifier,
      focusCommandNotifier: _controller.focusCommandNotifier,
      suppressCellFocus: widget.suppressCellFocus,
      onCellFocused: _handleCellFocused,
      onCellKeyDown: _handleCellKeyDown,
      onHoverChanged: _handleHoverChanged,
      cellSpanService: widget.enableCellSpan ? _cellSpanService : null,
      rowHeightLayout: rowHeightLayout,
      detailWidgetBuilder: masterDetailApplies
          ? (detailRow) => widget.detailWidgetBuilder!(
              detailRow[MasterDetailKeys.detailSource] as TData,
              detailRow[MasterDetailKeys.detailMasterIndex] as int,
            )
          : null,
      cellWidgetBuilder: _hasWidgetCellRenderers(flatColumns)
          ? _buildCellWidgetResolver(flatColumns)
          : null,
      columnHoverHighlight: widget.columnHoverHighlight,
      suppressColumnVirtualisation: widget.suppressColumnVirtualisation,
      textPainterCache: _textPainterCache,
      localeText: widget.localeText,
      valuePrefetch: widget.prefetchEnabled ? _prefetchValueWindow : null,
      onImageLoaded: _onImageCellLoaded,
    );

    final showRowGroupPanel =
        widget.rowGroupPanelVisibility == OsRowGroupPanelVisibility.always ||
        (widget.rowGroupPanelVisibility ==
                OsRowGroupPanelVisibility.whenGrouping &&
            _controller.getRowGroupColumns().isNotEmpty);

    Widget gridWidget = grid;
    if (showRowGroupPanel) {
      gridWidget = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RowGroupPanel(
            key: _rowGroupPanelKey,
            controller: _controller,
            resolvedTheme: ResolvedGridTheme.from(widget.theme),
            baseTheme: widget.theme,
            columnDragCoordinator: _columnDrag,
          ),
          Expanded(child: grid),
        ],
      );
    }

    // Build the main content (grid + optional edit/filter/menu overlays)
    Widget content;
    // Always use a Stack so the VirtualisedGrid's position in the widget tree
    // is stable (prevents State recreation when overlays appear/disappear).
    //
    // The LayoutBuilder only records the grid's rendered size and defers
    // any onGridSizeChanged emission to a post-frame callback (RULE ZERO).
    // Resolve which body overlay (if any) covers the grid this frame.
    final overlayState = _resolveOverlayState(
      hasDisplayedRows: rowData.isNotEmpty,
    );

    content = LayoutBuilder(
      builder: (context, constraints) {
        _maybeEmitGridSizeChanged(
          Size(constraints.maxWidth, constraints.maxHeight),
        );
        return Stack(
          clipBehavior: Clip.none,
          children: [
            gridWidget,
            // Screen-reader live region announcing model updates.
            GridLiveRegion(
              message: gridSummaryMessage(
                rowCount: _controller.getDisplayedRowCount(),
                selectedCount: _controller.getSelectedRows().length,
                localeText: widget.localeText ?? OsLocaleText.defaultLocale,
              ),
            ),
            // Loading / no-rows overlays (ignore-pointer, above the grid)
            if (overlayState == OsGridOverlay.loading)
              Positioned.fill(
                child: IgnorePointer(
                  child:
                      widget.loadingOverlay ??
                      _buildDefaultOverlayPanel(
                        _controller.getLocaleText('loadingOoo', 'Loading...'),
                      ),
                ),
              )
            else if (overlayState == OsGridOverlay.noRows)
              Positioned.fill(
                child: IgnorePointer(
                  child:
                      widget.noRowsOverlay ??
                      _buildDefaultOverlayPanel(
                        _controller.getLocaleText(
                          'noRowsToShow',
                          'No Rows To Show',
                        ),
                      ),
                ),
              ),
            // Dismiss scrim for filter popup (tap outside to close)
            if (_filterPopupVisible)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _dismissFilterPopup,
                  child: const SizedBox.expand(),
                ),
              ),
            // Cell edit overlay
            if (_editCellRect != null &&
                !_isSelectEditing &&
                !_isCustomEditing &&
                !_isLargeTextEditing &&
                !_isDateEditing)
              Positioned(
                left: _editCellRect!.left,
                top: _editCellRect!.top,
                width: _editCellRect!.width,
                height: _editCellRect!.height,
                child: KeyboardListener(
                  // Coordinator-owned: a fresh inline node here would leak
                  // on every rebuild of the edit overlay.
                  focusNode: _editing.editOverlayFocusNode,
                  onKeyEvent: (event) {
                    _handleEditKeyEvent(event);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: widget.theme?.backgroundColor ?? Colors.white,
                      border: Border.all(color: Colors.blue, width: 2),
                    ),
                    alignment: Alignment.centerLeft,
                    padding: EdgeInsets.zero,
                    child: TextField(
                      controller: _editTextController,
                      focusNode: _editFocusNode,
                      style:
                          widget.theme?.cellTextStyle ??
                          const TextStyle(fontSize: 13, color: Colors.black),
                      cursorColor: Colors.blue,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 0,
                        ),
                        isDense: true,
                      ),
                      onSubmitted: (_) {
                        if (widget.enterNavigatesVerticallyAfterEdit) {
                          final isShiftHeld = HardwareKeyboard
                              .instance
                              .logicalKeysPressed
                              .any(
                                (key) =>
                                    key == LogicalKeyboardKey.shiftLeft ||
                                    key == LogicalKeyboardKey.shiftRight,
                              );
                          _commitAndNavigateVertically(up: isShiftHeld);
                        } else {
                          _commitEdit();
                        }
                      },
                    ),
                  ),
                ),
              ),
            // Select cell editor dropdown overlay
            if (_editCellRect != null && _isSelectEditing) ...[
              // Dismiss scrim — tap outside to close the select dropdown
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _cancelEditRevert,
                  child: const SizedBox.expand(),
                ),
              ),
              _buildSelectEditorOverlay(),
            ],
            // Custom cell editor overlay
            if (_editCellRect != null && _isCustomEditing) ...[
              // Dismiss scrim — tap outside to cancel the custom editor
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _cancelEditRevert,
                  child: const SizedBox.expand(),
                ),
              ),
              _buildCustomEditorOverlay(),
            ],
            // Large text cell editor overlay
            if (_editCellRect != null && _isLargeTextEditing) ...[
              // Dismiss scrim — tap outside to commit the large text editor
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _commitLargeTextEdit,
                  child: const SizedBox.expand(),
                ),
              ),
              _buildLargeTextEditorOverlay(),
            ],
            // Date picker cell editor overlay
            if (_editCellRect != null && _isDateEditing) ...[
              // Dismiss scrim — tap outside to cancel the date picker
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _cancelEditRevert,
                  child: const SizedBox.expand(),
                ),
              ),
              _buildDateEditorOverlay(),
            ],
            // Floating filter input overlay
            if (_floatingFilterRect != null)
              Positioned(
                left: _floatingFilterRect!.left,
                top: _floatingFilterRect!.top,
                width: _floatingFilterRect!.width,
                height: _floatingFilterRect!.height,
                child: Container(
                  decoration: BoxDecoration(
                    color: widget.theme?.backgroundColor ?? Colors.white,
                    border: Border.all(
                      color: widget.theme?.accentColor ?? Colors.blue,
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: EditableText(
                    controller: _floatingFilterTextController,
                    focusNode: _floatingFilterFocusNode,
                    style:
                        widget.theme?.cellTextStyle?.copyWith(fontSize: 12) ??
                        const TextStyle(fontSize: 12, color: Colors.black),
                    cursorColor: widget.theme?.accentColor ?? Colors.blue,
                    backgroundCursorColor: Colors.grey,
                    scrollPhysics: const NeverScrollableScrollPhysics(),
                    onChanged: _onFloatingFilterTextChanged,
                    onSubmitted: (_) => _commitFloatingFilter(),
                  ),
                ),
              ),
            // Filter popup overlay
            if (_filterPopupVisible && _filterPopupColDef != null)
              Positioned(
                left: _filterPopupAnchorRect != null
                    ? _filterPopupAnchorRect!.left
                    : 0,
                top: _filterPopupAnchorRect != null
                    ? _filterPopupAnchorRect!.bottom + 2
                    : _effectiveHeaderHeight,
                child: _filterPopupColDef!.filter is OsCustomFilter
                    ? _buildCustomFilterPopup()
                    : FilterPopup(
                        colId: _filterPopupColId!,
                        headerName: _filterPopupColDef!.effectiveHeaderName,
                        filter: _filterPopupColDef!.filter!,
                        currentModel: _columnFilterModels[_filterPopupColId!],
                        theme: widget.theme,
                        localeText: widget.localeText,
                        onApply: _onFilterPopupApply,
                        onDismiss: _dismissFilterPopup,
                        valuesProvider: () {
                          final col = _filterPopupColDef!;
                          final rows = _processedRowData ?? widget.rowData;
                          if (rows == null) return const <Object?>[];
                          return [
                            for (var i = 0; i < rows.length; i++)
                              _resolveColumnValue(col, rows[i], i),
                          ];
                        },
                      ),
              ),
            // Column menu popup overlay
            if (_columnMenuVisible &&
                _columnMenuColDef != null &&
                _columnMenuAnchorRect != null)
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final gridSize = Size(
                      constraints.maxWidth,
                      constraints.maxHeight,
                    );
                    if (widget.columnMenu != null) {
                      return _buildTabbedColumnMenu(gridSize);
                    }
                    return ColumnMenuPopup(
                      columnIndex: _columnMenuColIndex!,
                      colDef: _columnMenuColDef!,
                      anchorRect: _columnMenuAnchorRect!,
                      gridSize: gridSize,
                      theme: widget.theme,
                      localeText: widget.localeText,
                      currentSortColumnIndex: _sortColumnIndex,
                      currentSortAscending: _sortAscending,
                      currentColumnSortDirection: _getColumnSortDirection(
                        _columnMenuColIndex!,
                      ),
                      onAction: _handleColumnMenuAction,
                      onDismiss: _dismissColumnMenu,
                    );
                  },
                ),
              ),
            // Tooltip overlay — scoped rebuild (item 25): the service's
            // stateChangeNotifier drives this entry directly so tooltip
            // show/hide/move no longer setState()s the whole grid.
            ValueListenableBuilder<int>(
              valueListenable: _tooltipService.stateChangeNotifier,
              builder: (context, _, __) {
                if (_tooltipService.state != OsTooltipState.showing ||
                    _tooltipService.tooltipValue == null) {
                  return const SizedBox.shrink();
                }
                // TooltipOverlay returns a Positioned, so it must be a
                // DIRECT child of this Stack — a LayoutBuilder in between
                // breaks the ParentData wiring (Positioned under
                // LayoutBuilder throws). The grid size comes from the
                // outer LayoutBuilder, which records it before this
                // subtree builds.
                final pos = widget.tooltipMouseTrack
                    ? (_tooltipService.mousePosition ??
                          _tooltipService.anchorPosition!)
                    : _tooltipService.anchorPosition!;
                return TooltipOverlay(
                  value: _tooltipService.tooltipValue!,
                  position: pos,
                  gridSize:
                      _lastGridSize ??
                      const Size(double.infinity, double.infinity),
                  theme: widget.theme,
                );
              },
            ),
            // Context menu popup overlay
            if (_contextMenuVisible &&
                _contextMenuItems != null &&
                _contextMenuPosition != null)
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return ContextMenuPopup(
                      items: _contextMenuItems!,
                      position: _contextMenuPosition!,
                      gridSize: Size(
                        constraints.maxWidth,
                        constraints.maxHeight,
                      ),
                      theme: widget.theme,
                      localeText: widget.localeText,
                      onDismiss: _dismissContextMenu,
                    );
                  },
                ),
              ),
            // Integrated-charts palette popup overlay
            if (_chartPaletteVisible && _chartPaletteAnchor != null)
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      children: [
                        // Outside-tap dismiss scrim.
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _dismissChartPalette,
                          child: const SizedBox.expand(),
                        ),
                        ChartPalettePopup(
                          anchorRect: _chartPaletteAnchor!,
                          gridSize: Size(
                            constraints.maxWidth,
                            constraints.maxHeight,
                          ),
                          theme: widget.theme,
                          onSelect: (type) {
                            _dismissChartPalette();
                            _controller.createChartRange(type: type);
                          },
                        ),
                      ],
                    );
                  },
                ),
              ),
            // Debug inspector (quality program v3 item 19) — mounted last so
            // it floats above every other overlay in the Stack.
            if (widget.showInspector)
              Positioned(
                top: 8,
                right: 8,
                child: GridInspector<TData>(
                  controller: _controller,
                  style: widget.theme,
                ),
              ),
          ],
        );
      },
    );

    // Wrap with DragTarget if external drop-in is enabled
    if (widget.dragAndDrop?.enableDropIn == true) {
      content = _wrapWithDragTarget(content, rowData.length);
    }

    // Wrap with side bar if configured
    if (widget.sideBar != null && _sideBarVisible) {
      final sideBar = OsSideBar(
        sideBarDef: widget.sideBar!,
        columns: flatColumns,
        columnDefs: _effectiveColumnDefs,
        hiddenColumnIds: _hiddenColumnIds,
        filterModel: _columnFilterModels,
        theme: widget.theme,
        localeText: widget.localeText,
        openToolPanelId: _openToolPanelId,
        onToolPanelToggled: _handleToolPanelToggled,
        onColumnVisibilityChanged: _handleSideBarColumnVisibilityChanged,
      );

      final isLeft = widget.sideBar!.position == OsSideBarPosition.left;
      content = Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isLeft) sideBar,
          Expanded(child: content),
          if (!isLeft) sideBar,
        ],
      );
    }

    // If paginated or has status bar, wrap in a Column
    final hasFooter =
        isPaginated || widget.statusBar || widget.statusBarConfig != null;
    if (!hasFooter) return content;

    final startRow = isPaginated ? _currentPage * _pageSize + 1 : 1;
    final endRow = isPaginated
        ? (_currentPage * _pageSize + rowData.length).clamp(0, totalRows)
        : totalRows;

    return Column(
      children: [
        Expanded(child: content),
        // Config-driven status bar wins over the legacy bool status bar.
        if (widget.statusBarConfig != null)
          OsStatusBarPanelRow(
            config: widget.statusBarConfig!,
            pageRows: rowData,
            columns: flatColumns,
            gridTheme: widget.theme,
            resolveLocaleText: _controller.getLocaleText,
          )
        else if (widget.statusBar)
          _StatusBar(
            totalRows: totalRows,
            filteredRows: rowData.length,
            selectedRows: selectedCount,
          ),
        if (isPaginated)
          _PaginationBar(
            currentPage: _currentPage,
            totalPages: totalPages,
            startRow: startRow,
            endRow: endRow,
            totalRows: totalRows,
            pageSize: _pageSize,
            pageSizeOptions: widget.pagination!.pageSizeOptions,
            showPageSizeSelector: widget.pagination!.showPageSizeSelector,
            onPageChanged: (page) {
              setState(() => _currentPage = page);
              _emitPaginationChanged(
                currentPage: page,
                totalPages: totalPages,
                totalRows: totalRows,
                newPage: true,
                newPageSize: false,
              );
            },
            onPageSizeChanged: (size) {
              setState(() {
                _pageSize = size;
                _currentPage = 0;
              });
              final newTotalPages = (totalRows / size).ceil();
              _emitPaginationChanged(
                currentPage: 0,
                totalPages: newTotalPages,
                totalRows: totalRows,
                newPage: false,
                newPageSize: true,
              );
            },
          ),
      ],
    );
  }
}

/// Pagination controls bar rendered below the grid.
/// Mirrors OS Grid's pagination panel with first/prev/next/last buttons
/// and a row count indicator.
class _PaginationBar extends StatelessWidget {
  const _PaginationBar({
    required this.currentPage,
    required this.totalPages,
    required this.startRow,
    required this.endRow,
    required this.totalRows,
    required this.pageSize,
    required this.pageSizeOptions,
    required this.showPageSizeSelector,
    required this.onPageChanged,
    required this.onPageSizeChanged,
  });

  final int currentPage;
  final int totalPages;
  final int startRow;
  final int endRow;
  final int totalRows;
  final int pageSize;
  final List<int> pageSizeOptions;
  final bool showPageSizeSelector;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onPageSizeChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle = theme.textTheme.bodySmall;

    return Container(
      height: 40,
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: theme.dividerColor)),
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          // Page size selector
          if (showPageSizeSelector) ...[
            Text('Page Size: ', style: textStyle),
            DropdownButton<int>(
              value: pageSize,
              isDense: true,
              underline: const SizedBox.shrink(),
              items: pageSizeOptions
                  .map(
                    (size) =>
                        DropdownMenuItem(value: size, child: Text('$size')),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) onPageSizeChanged(value);
              },
            ),
            const SizedBox(width: 24),
          ],

          // Row count
          Text('$startRow to $endRow of $totalRows', style: textStyle),

          const Spacer(),

          // Page indicator
          Text('Page ${currentPage + 1} of $totalPages', style: textStyle),
          const SizedBox(width: 12),

          // Navigation buttons
          _navButton(Icons.first_page, currentPage > 0, () => onPageChanged(0)),
          _navButton(
            Icons.chevron_left,
            currentPage > 0,
            () => onPageChanged(currentPage - 1),
          ),
          _navButton(
            Icons.chevron_right,
            currentPage < totalPages - 1,
            () => onPageChanged(currentPage + 1),
          ),
          _navButton(
            Icons.last_page,
            currentPage < totalPages - 1,
            () => onPageChanged(totalPages - 1),
          ),
        ],
      ),
    );
  }

  Widget _navButton(IconData icon, bool enabled, VoidCallback onPressed) {
    return IconButton(
      icon: Icon(icon, size: 20),
      onPressed: enabled ? onPressed : null,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      splashRadius: 16,
    );
  }
}

/// Status bar showing row counts (total, filtered, selected).
/// Mirrors OS Grid's status bar component.
class _StatusBar extends StatelessWidget {
  const _StatusBar({
    required this.totalRows,
    required this.filteredRows,
    required this.selectedRows,
  });

  final int totalRows;
  final int filteredRows;
  final int selectedRows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle = theme.textTheme.bodySmall;

    return Container(
      height: 32,
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: theme.dividerColor)),
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Text(
            'Rows: ',
            style: textStyle?.copyWith(fontWeight: FontWeight.w600),
          ),
          Text('$totalRows', style: textStyle),
          if (filteredRows != totalRows) ...[
            const SizedBox(width: 16),
            Text(
              'Filtered: ',
              style: textStyle?.copyWith(fontWeight: FontWeight.w600),
            ),
            Text('$filteredRows', style: textStyle),
          ],
          if (selectedRows > 0) ...[
            const SizedBox(width: 16),
            Text(
              'Selected: ',
              style: textStyle?.copyWith(fontWeight: FontWeight.w600),
            ),
            Text('$selectedRows', style: textStyle),
          ],
        ],
      ),
    );
  }
}

/// Stores the original group membership of a leaf column.
///
/// Used to recompute group spans after column reorder. Each leaf column
/// remembers which group it was originally defined in (mirroring OS Grid's
/// `originalParent` on `OsColumn`).
class _OriginalGroupInfo {
  const _OriginalGroupInfo({required this.groupId, required this.headerName});

  /// Unique identifier for the group (from [OsColumnGroup.groupId] or headerName).
  final String groupId;

  /// Display name for the group header.
  final String headerName;
}

/// Internal helper for collecting sort state during applyColumnState.
class _SortStateEntry {
  const _SortStateEntry({
    required this.colId,
    required this.direction,
    this.sortIndex,
  });

  final String colId;
  final OsSortDirection direction;
  final int? sortIndex;
}
