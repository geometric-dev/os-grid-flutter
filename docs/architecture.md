# OS Grid Flutter — Architecture Guide

Source of truth for this document is the code itself (verified against
imports and call chains at quality-program-v3 item 44). Line references
drift; class and file names do not.

The package is a single Flutter library with **zero third-party runtime
dependencies**. It renders via canvas painting — there is no widget per
cell — so the widget layer is thin and almost all behaviour lives in a
controller + coordinator/service layer beneath it.

```
        host app
           │  rowData / columnDefs / callbacks
           ▼
      OsGrid (widget)  ──events/callbacks──►  host app
           │ owns / adopts
           ▼
  OsGridController (facade) ──GridEventBus──► onXxx streams
           │
   ┌───────┴─────────────────────────────┐
   │ coordinators + services (per feature)│
   └─────────────────────────────────────┘
           │  display model (rows, widths, selection, …)
           ▼
   VirtualisedGrid (StatefulWidget)
           │  GridPaintContext
           ▼
   CustomPaint bands: Body / Header / Pinned / Range / Flash / Scrollbar
```

---

## 1. Top-level components

| Component | File | Responsibility |
|---|---|---|
| `OsGrid<TData>` | `lib/src/os_grid.dart` (~7.5k ln) | Widget + `_OsGridState`: owns most coordinators, runs the display-model build, hosts `VirtualisedGrid` |
| `OsGridController<TData>` | `lib/src/os_grid_controller.dart` (~3.3k ln) | Public imperative API + `ChangeNotifier` + `GridEventBus` views; owns the node identity layer |
| `VirtualisedGrid` | `lib/src/rendering/virtualised_grid.dart` | Scroll + viewport + hit testing; paints via `CustomPaint` bands |
| Band painters | `lib/src/rendering/*_painter.dart` | `GridPainter` is the public entry; it and `VirtualisedGrid` stack `BodyPainter`, `HeaderPainter`, `PinnedRowPainter`, `RangePainter`, `FlashOverlayPainter`, `ScrollbarPainter` |
| `GridEventBus` | `lib/src/events/grid_event_bus.dart` | Single typed event bus; all 50+ `onXxx` controller getters are derived views over `_bus.on<T>()` |

## 2. Coordinator dependency graph

Ownership matters more than raw imports: the **controller** owns the
sub-coordinators extracted in quality-program-v3 item 13, while `_OsGridState`
owns the pipeline and feature coordinators. Arrows below mean
"constructed by / calls into".

```
OsGridController<TData> (facade)
├─ QuickFilterCoordinator        (lib/src/controller/quick_filter_coordinator.dart)
├─ PaginationCoordinator         (lib/src/controller/pagination_coordinator.dart)
├─ StatePersistenceCoordinator   (lib/src/controller/state_persistence_coordinator.dart)
├─ GridEventBus                  (lib/src/events/grid_event_bus.dart)
└─ node identity layer           (lib/src/row_model/row_node.dart)
     _nodesById  /  _rawNodes  /  _renderedNodes

_OsGridState (lib/src/os_grid.dart)
├─ DataPipelineCoordinator<TData>     (lib/src/data/data_pipeline_coordinator.dart)
│   ├─ SortService<TData>             (lib/src/sorting/sort_service.dart)
│   ├─ DeltaSortService<TData>?       (lib/src/row_model/delta_sort_service.dart)
│   ├─ ValueCache                     (lib/src/cache/value_cache.dart)
│   ├─ CellSpanService                (lib/src/cell_span/cell_span_service.dart)
│   └─ TextPainterCache               (lib/src/rendering/text_painter_cache.dart)
├─ ColumnApiCoordinator<TData>        (lib/src/columns/column_api_coordinator.dart)
│   └─ ColumnDragCoordinator<TData>   (lib/src/columns/column_drag_coordinator.dart)
├─ EditingCoordinator<TData>          (lib/src/editing/editing_coordinator.dart)
│   └─ UndoRedoCoordinator<TData>     (lib/src/editing/undo_redo_coordinator.dart)
│       └─ UndoRedoService            (lib/src/editing/undo_redo_service.dart)
├─ ClipboardCoordinator<TData>        (lib/src/clipboard/clipboard_coordinator.dart)
│   └─ ClipboardService               (lib/src/clipboard/clipboard_service.dart)
├─ PopupUiCoordinator                 (lib/src/popup/popup_ui_coordinator.dart)
├─ CellFlashCoordinator               (lib/src/render_api/cell_flash_coordinator.dart)
├─ AlignedGridCoordinator             (lib/src/aligned_grids/aligned_grid_coordinator.dart)
├─ RowDragCoordinator<TData>          (lib/src/row_drag/row_drag_coordinator.dart)
├─ TooltipService                     (lib/src/tooltip/tooltip_service.dart)
├─ GridStateService<TData>            (lib/src/grid_state/grid_state_service.dart)
├─ AsyncTransactionService<TData>?    (lib/src/row_model/async_transaction_service.dart)
├─ ImmutableDataService<TData>?       (lib/src/row_model/immutable_data_service.dart)
├─ InfiniteBlockCache<TData>?         (lib/src/infinite_row_model/block_cache.dart)
├─ ServerSideRowModel<TData>?         (lib/src/row_model/server_side_row_model.dart)
├─ RowGroupService<TData>             (lib/src/row_grouping/row_group_service.dart)
├─ TreeDataService<TData>             (lib/src/row_grouping/tree_data_service.dart)
└─ AggregationService<TData>          (lib/src/aggregation/aggregation_service.dart)
```

Key call relationships:

* `_OsGridState._reprocessData()` → `DataPipelineCoordinator.reprocess()`
  (source: widget `rowData`) or `.reprocessFromController()` (source:
  controller row data — used by direct `applyTransaction` /
  `refreshClientSideRowModel`). The pipeline is **inert**: every grid
  collaborator is injected as a live getter.
* `DataPipelineCoordinator` writes results back through
  `setProcessedRowData` and `controller.processedData` — the latter
  triggers `_refreshDisplayedNodeState()` in the controller (rowIndex,
  selection flags, `_renderedNodes`).
* Controller→widget requests travel through `onXxxRequested` callback
  fields registered in `_OsGridState._bindControllerCallbacks()`
  (`onSetSortModelRequested`, `onPageChangeRequested`,
  `onFlashCellsRequested`, …). Widget→controller notifications travel
  through `ChangeNotifier` (`addListener(_onControllerChanged)`).
* Feature gating: `OsModule` subclasses (lib/src/modules/) are resolved in
  `initState`; an empty registry implicitly enables every feature.

## 3. Event flow: data → pipeline → controller → widget → painter

```
 host data                     controller                    widget (_OsGridState)
 ────────                      ──────────                    ─────────────────────
 OsGrid.rowData ──────────►  didUpdateWidget
                               │
 controller.setRowData ────►  setRowData()
 controller.applyTransaction    ├─ _rowData = …
                                ├─ _rebuildNodesFromRaw()   ← node identity layer
                                │    (surviving IDs reuse OsRowNode; dropped
                                │     IDs leave _nodesById → GC-eligible)
                                ├─ notifyListeners() ───────► _onControllerChanged()
                                └─ _bus.emit(RowDataUpdated)    → setState
                                                                │
                               ┌────────────────────────────────┘
                               ▼
                       _reprocessData()
                               │
                               ▼
              DataPipelineCoordinator.reprocess()
                quick filter → external filter → column filters
                → custom filters → sort (+ delta sort) → postSortRows
                               │
                               ├─ _setProcessedRowData(data)
                               └─ controller.processedData = data
                                    └─ _refreshDisplayedNodeState()
                                       (rowIndex, selected, _renderedNodes)
                               │
                               ▼
                  build(): assemble DISPLAY rows
                  (pagination page → pinned top/bottom → group rows →
                   tree data → master/detail splice → _displayRowData)
                               │
                               ▼
                        VirtualisedGrid
                               │  viewport culling (rows × cols)
                               ▼
        GridPaintContext ──► CustomPaint bands (stacked RepaintBoundary):
          BodyPainter → HeaderPainter → PinnedRowPainter
          → RangePainter → FlashOverlayPainter → ScrollbarPainter
                               │  hit testing (grid_hit_test.dart)
                               ▼
            onCellTap / onHeaderTap / onColumnResize / …
                               │
                               ▼
        _OsGridState handlers → controller API / coordinators
                               → bus events + widget callbacks (post-frame only)
```

Two flow rules worth remembering:

1. **Node identity survives data updates.** `_rebuildNodesFromRaw()`
   reuses existing `OsRowNode` instances for IDs that survive; see
   `lib/src/row_model/row_node.dart` for the retention contract and
   `nodePoolSize` / `nodeRebuildCount` test hooks.
2. **RULE ZERO — no synchronous listener work during build/layout/paint.**
   Grid events are emitted via `addPostFrameCallback` guards
   (`_scheduleModelUpdated`), broadcast-bus emissions, or post-frame
   notifiers; listeners may call `setState` safely.

## 4. Lifecycle sequence

```
OsGrid<TData> mounted
│
├─ initState()
│   ├─ wire floating-filter / focused-cell listeners
│   ├─ resolve OsModule registry → per-feature enablement flags
│   ├─ SortService init (initialSort or per-column sort declarations)
│   ├─ controller: adopt widget.controller or create + _ownsController
│   ├─ construct DataPipelineCoordinator (live getters over state)
│   ├─ construct remaining coordinators/services
│   │   (popup, tooltip, grid-state, flash, drags, editing, clipboard, …)
│   └─ _bindControllerCallbacks()
│       ├─ controller.addListener(_onControllerChanged)
│       ├─ controller.getRowId / rowSelection / localeText sync
│       ├─ register onXxxRequested callbacks (sort, page, flash, focus, …)
│       └─ _syncColumnStateToController()
│
├─ didUpdateWidget()
│   ├─ controller swap → rebind + dispose owned controller
│   ├─ rowData change → emit RowDataChanged
│   │   ├─ immutable mode: ImmutableDataService.computeDiff → applyTransaction
│   │   └─ otherwise: controller.setRowData
│   ├─ columnDefs change → controller.columnDefs + column state sync
│   └─ _reprocessData() (+ undo/redo stack clears on data replacement)
│
├─ build()
│   ├─ display row assembly (page, pinned, groups, detail splice)
│   └─ VirtualisedGrid(paint bands…)
│
└─ dispose()   (reverse-ish order of wiring)
    ├─ AlignedGridCoordinator, TextPainterCache,
    │  AsyncTransactionService, InfiniteBlockCache, ServerSideRowModel
    ├─ CellFlashCoordinator, ColumnDragCoordinator, RowDragCoordinator,
    │  ColumnApiCoordinator
    ├─ stream subscriptions (state/selection/range)
    ├─ GridStateService, scroll notifier, focused-cell notifier, tooltip
    ├─ UndoRedoCoordinator
    ├─ controller.removeListener(_onControllerChanged)
    │  (+ dispose controller if _ownsController)
    ├─ floating filter focus/text controllers
    ├─ module.detach() for each registered module
    └─ EditingCoordinator.detach() + dispose()
```

## 5. File tree (one line each)

```
lib/
  os_grid_flutter.dart              Public barrel file — every exported type enters here.
  src/
    os_grid.dart                    OsGrid widget + _OsGridState (coordinator wiring, display model, overlays).
    os_grid_controller.dart         Controller facade: imperative API, event views, node identity layer, selection.
    accessibility/                  Semantics, live region and high-contrast support.
    aggregation/                    AggregationService for group/footer aggregation functions.
    aligned_grids/                  OsAlignedGrid + coordinator/service for syncing rows across sibling grids.
    cache/                          ValueCache — memoised cell values keyed (rowId, colId) with LRU cap.
    cell_span/                      Cell span model/service/params (colSpan/rowSpan).
    clipboard/                      ClipboardCoordinator/Service — copy/paste/cut pipelines.
    columns/                        OsColumnDef, schema/types, resolution, pinning, column API + drag coordinators.
    context_menu/                   ContextMenuPopup (keyboard nav, typeahead) and shared types.
    controller/                     Controller sub-coordinators: pagination, quick filter, state persistence.
    data/                           DataPipelineCoordinator (filter/sort chain) + LazyRowMap for typed rows.
    debug/                          GridInspector debug overlay (model stats, damage viz, frame timings).
    drag_and_drop/                  Generic drag-and-drop config/events/service (column + row drag sources).
    editing/                        EditingCoordinator, cell editors (text/number/date/select/…), undo/redo.
    events/                         GridEventBus + one file per event family (sealed OsGridEvent hierarchy).
    export/                         CSV export (zero-dependency).
    filtering/                      Filter models, FilterEvaluator, per-type filter defs, set-filter list, popups.
    grid_state/                     GridStateService — capture/restore of column, filter, sort and selection state.
    infinite_row_model/             OsInfiniteRowModel datasource + InfiniteBlockCache (LRU block cache).
    locale/                         OsLocaleText localisation keys/defaults.
    menu/                           Column menu popups (tabbed variant included).
    modules/                        OsModule base + feature modules (clipboard, editing, set filter, tree data, …).
    pagination/                     OsPagination widget/UI.
    params/                         Callback params objects (ValueGetterParams, CellRendererParams, …).
    pivot/                          PivotService (row/column pivot transformation).
    popup/                          PopupUiCoordinator — popup positioning + floating-filter popup pool.
    render_api/                     Cell flash API + CellFlashCoordinator.
    rendering/                      VirtualisedGrid, band painters, hit testing, layout, caches, RTL geometry.
    row_auto_height/                AutoHeightCalculator + RowHeightLayout + auto-height module.
    row_drag/                       RowDragCoordinator + events.
    row_grouping/                   RowGroupService, TreeDataService, group nodes/state.
    row_model/                      RowNode (identity layer), transactions, delta sort, async txns, SSRM, immutable diffing.
    scrolling/                      ScrollCommand — imperative scroll requests.
    selection/                      OsRowSelection config + CellRange for cell selection.
    side_bar/                       Side bar + columns/filters tool panels.
    sorting/                        SortService, SortModel, sort indicators/directions.
    status_bar/                     StatusBar panels (aggregation / selected-row counts).
    theming/                        OsGridTheme presets, ResolvedGridTheme, cell/row styles, popup surfaces.
    tooltip/                        TooltipService + overlay + params.
    utils/                          GridDiagnostics (structured warnOnce diagnostics) + GridError codes.
    validation/                     GridValidator — startup config validation.
```

## 6. Where to look when…

| Symptom | First place to look |
|---|---|
| Node/memory retention question | `lib/src/row_model/row_node.dart` (retention contract), `nodePoolSize` on the controller |
| Frame-time regression | `test/bench_frame_budget_test.dart` + `test/bench_baseline.json` (budgets gate, baselines warn) |
| Sort/filter wrong after transaction | `DataPipelineCoordinator._applySort` / delta-sort touched-rows plumbing |
| Selection lost after sort/filter | Controller selection is ID-based; check `_rebuildNodesFromRaw`/`_refreshDisplayedNodeState` |
| Event not firing | `GridEventBus` emission site; RULE ZERO post-frame guards in `os_grid.dart` |
| Painter misalignment | `GridPaintContext` inputs built in `VirtualisedGridState` → band painters |
