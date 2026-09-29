# Changelog

## 1.0.0

First public release of **OS Grid Flutter** — a high-performance,
canvas-based data grid for Flutter, inspired by the AG Grid Community
module and its TypeScript API.

- 42 AG Grid Community modules implemented
- Canvas-based virtualised rendering: 100k+ rows at 60fps, no widget per
  cell
- **Zero third-party runtime dependencies** beyond the Flutter SDK
- 2,750+ tests (unit, widget, golden, property-based) with CI on every push
- Windows, macOS, Linux, web, iOS and Android

### Rendering & performance

- Custom-paint virtualised grid: row and column virtualisation, a
  three-section pinned column layout (left / centre / right) mirroring
  AG Grid's `VisibleColsService`
- `TextPainter` caching across cells, plus a dirty-region classifier that
  repaints only the affected row/column bands for hover, focus, selection
  and flash changes (scroll and any unrecognised change fall back to a full
  repaint, deliberately)
- Binary-search row positioning for variable row heights (`getRowHeight`,
  `autoHeight`, `wrapText`)
- 100k-row frame-budget gate behind `OS_GRID_BENCH=1` (p95 < 120 ms budget;
  measured p95 ≈ 77 ms)
- RTL-aware geometry throughout, with LTR/RTL golden pairs

### Columns

- `OsColumnDef` with `field`, `headerName`, `width`/`minWidth`/`maxWidth`/
  `flex`, `defaultColDef`, `columnTypes` and a per-column `type`
  (precedence: explicit colDef → types → `defaultColDef`)
- Column groups with multi-level headers and a left-border accent bar;
  pin, resize, reorder (drag), show/hide, autosize, lock properties
  (`lockPosition`, `lockVisible`, `lockPinned`, `suppressMovable`,
  `suppressMenu`), `headerValueGetter`
- Column state: `getColumnState()` / `applyColumnState()` /
  `resetColumnState()`, with `getState()`/`setState()` at grid level
  (JSON-serialisable, AG Grid-compatible shape)
- Tabbed column menu (`OsColumnMenuDef`) with General / Filter / Columns
  tabs, `menuTabs` to restrict them
- **Column sizing API** (previously documented but inert — now implemented):
  - `controller.setColumnDefs(defs)` swaps the rendered definitions at
    runtime. State is keyed by colId: widths, pins, visibility and order
    survive for columns that remain and are dropped for columns that
    disappear. A host rebuild with a different `columnDefs` list wins.
  - `controller.autoSizeColumns({colIds, skipHeader})` measures the widest
    rendered value per column in a single batched pass (with a per-column
    measurement cache) and applies it plus the grid's cell padding,
    sort-indicator and menu-icon allowances, clamped to `minWidth`/
    `maxWidth`.
  - `controller.sizeColumnsToFit()` scales the unpinned columns
    proportionally to fill the centre viewport, clamping to each column's
    bounds and redistributing the residual. Deferred one frame when called
    before the first layout.

### Rows

- Row selection (single/multiple), checkboxes, per-column
  `checkboxSelection`, shift+click range, `isRowSelectable`, and scoped
  select-all (`all` / `filtered` / `currentPage`)
- ID-based selection via `getRowId`, so selection survives sort and filter
- `OsRowNode<TData>` identity layer shared by grouping, tree data and pivot,
  with `getNode(id)`, `getRenderedNodes()` and the displayed-model
  accessors (`getDisplayedRowCount`, `getDisplayedRowAtIndex`)
- Row grouping (multi-level, canvas-painted group rows, aggregation via
  `aggFunc`), a **row group panel** with drag-to-group chips and header
  context-menu actions, tree data (`treeData` + `getDataPath`), pivot mode,
  and master/detail rows
- Pinned top/bottom rows, cell spans (`colSpan`/`rowSpan`/`spanRows`),
  row auto-height, row drag-to-reorder (managed or unmanaged) with
  auto-scroll near the grid edges, and external drag and drop
- Aligned grids (horizontal scroll sync via a shared group id)

### Sorting & filtering

- Multi-column sort with priority indicators, custom comparators,
  `accentedSort`, `alwaysMultiSort`, `suppressMultiSort`
- Text (8 operations), number (9), date (9), BigInt (9) and set filters,
  custom filter widgets, combined AND/OR conditions with
  `maxNumConditions`, quick filter (`quickFilterParser`,
  `quickFilterMatcher`, `getQuickFilterText`) and external filters
- Filter popups from the header icon and from the floating filter row, with
  live re-evaluation and a JSON-serialisable filter model
  (`getFilterModel`/`setFilterModel`)

### Editing

- Double-click or single-click editing with text, number, date, select,
  rich-select, checkbox, large-text and custom editors
- Keyboard triggers (Enter, F2, Delete, Backspace, printable characters),
  Tab/Shift+Tab traversal, `valueSetter`/`valueParser`/`editableCallback`,
  `readOnlyEdit` (fires `cellEditRequest` instead of mutating), and
  `startEditingCell`/`stopEditing`
- Bounded undo/redo with a controller API and lifecycle events

### Cell renderers

- Built-in canvas renderers: text, `animateShowChange` (delta arrows and
  value pill), image (with an LRU `ImageCellCache` and async
  `imageForCell`), avatar (Unicode initials, deterministic palette
  hashing), progress bar, star rating and sparklines (line/bar/area)
- `cellStyle` and `getRowStyle` for dynamic styling
- **Hybrid widget cells**: `cellRenderer` / `cellRendererBuilder` render
  real Flutter widgets in an overlay band above the canvas, positioned per
  visible cell, clipped to the data area and geometry-aware for RTL and
  pinned sections. The overlay walk is skipped entirely when no column
  declares a widget renderer

### Data models

- Client-side row model: sort/filter pipeline, transactions
  (`applyTransaction` by row id), immutable data mode, async transactions,
  delta sort and value cache
- Infinite row model with block caching (LRU), server-side sort/filter
  requests and loading states
- Server-side row model with group-key-aware block loading and cached
  block states

### Export & clipboard

- `controller.exportCsv()` and `controller.exportXlsx()` (a pure-Dart
  zip/xlsx writer) over the processed rows, honouring `valueFormatter`,
  column visibility and order, with `processCellCallback`,
  `processHeaderCallback`, `shouldRowBeSkipped`, `allColumns`,
  `columnKeys` and formula sanitising
- Clipboard copy/cut/paste (Ctrl+C/V/X) in TSV with
  `processCellForClipboard` / `processCellFromClipboard` and undo/redo
  integration

### Layout & chrome

- Side bar with Columns and Filters tool panels (and custom panels), status
  bar aggregation panels, context menu, tooltips, loading and no-rows
  overlays, 37 localisable strings via `OsLocaleText`, and a semantics tree
  with ARIA-equivalent roles for screen readers
- Theming through `OsGridTheme` with `quartz`, `quartzDark`, `alpine`,
  `alpineDark`, `balham`, `balhamDark` presets and a
  `fromThemeData` bridge to Flutter's Material theme

### Events

20+ event streams on the controller with matching widget callbacks for
cell, row, selection, sort, filter, column, editing, pagination, data and
lifecycle events, plus `onFirstDataRendered`, `onGridSizeChanged`,
`onModelUpdated` and `onRowDataChanged`.

### Integrated Charts

The core ships a dependency-free chart model and extraction pipeline:
`OsChartDefinition` / `OsChartSeries` / `OsChartPoint`, the
`OsChartRenderer` adapter interface, `ChartRangeExtractor` (range
selection → series and categories, with transpose support),
`controller.createChartRange()` and the `onChartRangeCreated` event, plus
an `enableIntegratedCharts` palette button drawn at the range selection
with grouped/stacked/normalized series layouts.

Renderers for the fl_chart and graphic libraries live in the
[`os_grid_flutter_charts`](https://github.com/geometric-dev/os-grid-flutter/tree/main/packages/os_grid_flutter_charts)
companion package, which is developed and tested in this repository but
**not yet published to pub.dev** — bring your own `OsChartRenderer` until
it ships. The core package itself stays dependency-free.

### Notes on defaults

A few behaviours deliberately match AG Grid's documented semantics rather
than an earlier internal default. They are called out here because they
are the sort of thing that surprises:

- `stopEditingWhenCellsLoseFocus` defaults to `true`: edits commit or
  cancel when the grid loses focus. Pass `false` to keep editing alive
  across focus changes.
- Only `null` and the empty string are blank. A whitespace-only string is a
  value, not a blank.
- `trimInput` defaults to `false` on the text filter, and `inRange` on the
  number filter is exclusive by default (`inRangeInclusive: true` for the
  inclusive form).
- Custom `quickFilterMatcher` callbacks receive the raw parsed parts, not
  upper-cased ones, so case-sensitive matching works.

### Licence

MIT. The companion `os_grid_flutter_charts` package is MIT as well.
