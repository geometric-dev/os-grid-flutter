# OS Grid Flutter

[![CI](https://github.com/geometric-dev/os-grid-flutter/actions/workflows/ci.yml/badge.svg)](https://github.com/geometric-dev/os-grid-flutter/actions/workflows/ci.yml)
[![pub package](https://img.shields.io/pub/v/os_grid_flutter.svg)](https://pub.dev/packages/os_grid_flutter)

A high-performance, feature-rich data grid for Flutter. Native Dart implementation inspired by the excellent [AG Grid](https://ag-grid.com/) for desktop and mobile platforms.

- **Canvas-based virtualised rendering** — 100k+ rows at 60fps, no widget-per-cell
- **Zero runtime dependencies** beyond the Flutter SDK
- **Full OS Grid Community parity** — 42 modules implemented
- **Enterprise features included** — tree data, row grouping, pivot mode, set filter, rich select editor, sparklines, status bar aggregations

> **New in 1.0.0** — the first public release. Highlights: a Row Group Panel with drag-to-group chips, hybrid widget-per-cell rendering via `cellRenderer`/`cellRendererBuilder`, row-drag auto-scroll near the grid edges, integrated-chart range extraction in the core (renderers in the in-repo, not-yet-published `os_grid_flutter_charts` companion), and a working `setColumnDefs` / `autoSizeColumns` / `sizeColumnsToFit` API. See the [changelog](CHANGELOG.md) for the full feature list.

## Quick Start

```bash
flutter pub add os_grid_flutter
```

The recommended pattern is **typed rows**: `OsGrid<TData>` with `valueGetter`s for compile-time safety and stable row identity.

```dart
import 'package:os_grid_flutter/os_grid_flutter.dart';

class Athlete {
  const Athlete(this.id, this.name, this.age, this.country);
  final String id;
  final String name;
  final int age;
  final String country;
}

final athletes = [
  const Athlete('a1', 'Alice', 32, 'UK'),
  const Athlete('a2', 'Bob', 28, 'US'),
  const Athlete('a3', 'Charlie', 35, 'Canada'),
];

OsGrid<Athlete>(
  columnDefs: [
    OsColumnDef<Athlete>(
      field: 'name',
      headerName: 'Name',
      sortable: true,
      valueGetter: (params) => params.data.name,
    ),
    OsColumnDef<Athlete>(
      field: 'age',
      headerName: 'Age',
      width: 100,
      valueGetter: (params) => params.data.age,
    ),
    OsColumnDef<Athlete>(
      field: 'country',
      headerName: 'Country',
      valueGetter: (params) => params.data.country,
    ),
  ],
  rowData: athletes,
  getRowId: (athlete) => athlete.id,
)
```

Raw map rows are also accepted — fine for prototyping — but always pair them with `getRowId` so rows have a stable identity across sort/filter/transactions:

```dart
OsGrid<Map<String, dynamic>>(
  columnDefs: [
    OsColumnDef(field: 'name', headerName: 'Name', sortable: true),
    OsColumnDef(field: 'age', headerName: 'Age', width: 100),
    OsColumnDef(field: 'country', headerName: 'Country'),
  ],
  rowData: [
    {'id': 'r1', 'name': 'Alice', 'age': 32, 'country': 'UK'},
    {'id': 'r2', 'name': 'Bob', 'age': 28, 'country': 'US'},
  ],
  getRowId: (row) => row['id'] as String,
)
```

> **Note:** in debug builds the grid emits a one-time warning when `rowData` is provided as `List<Map<String, dynamic>>` **without** a `getRowId` callback, since row identity is then unstable. Pass `getRowId`, switch to typed rows, or silence all configuration warnings with `suppressGridOptionsValidation: true`.

## Features

### Core
- Custom canvas-based virtualised rendering (no widget tree per cell)
- Generic `OsGrid<TData>` — works with typed classes or `Map<String, dynamic>`
- `OsGridController` with imperative API and event streams
- Module registration system (reserved for future use)

### Columns
- Column definitions with field, headerName, width, min/max, flex
- `defaultColDef` and `columnTypes` with per-column `type` references (precedence: explicit colDef > types > defaultColDef)
- `headerValueGetter` callback for dynamic header text
- Column groups (multi-level headers)
- Pinned columns (left/right) with border separator
- Column resize, reorder (drag header), show/hide
- Column menu (sort, pin, autosize, reset)
- Column state save/restore
- Lock properties (`lockVisible`, `lockPinned`, `lockPosition`)

### Sorting & Filtering
- Single and multi-column sort with priority indicators
- Text filter (8 operations), number filter (9 operations), date filter, BigInt filter
- **Set filter** (`OsSetFilter`) — multi-select value list with search and select-all
- Custom filters via builder pattern
- Combined conditions (AND/OR)
- Quick filter (searches across columns) with custom parser/matcher (receives raw parsed parts)
- External filter API
- Floating filter row with real-time filtering

### Row Features
- Row selection (single/multiple, checkboxes, shift+click range)
- Per-column selection checkboxes (`checkboxSelection` on colDef)
- ID-based selection (survives sort/filter) backed by the RowNode identity layer
- Row drag-to-reorder (managed and unmanaged modes)
- Pinned top/bottom rows
- Variable row heights (`getRowHeight`, `autoHeight`, `wrapText`)
- Row styling (static and dynamic callbacks)
- Alternating row backgrounds

### Cell Renderers
- Text renderer (default) with advanced styling and formatting rules.
- **Avatar built-in renderer**: `OsBuiltInCellRenderer.avatar` with customizable `OsAvatarOptions` (radius, palette, dynamic color and initials getters). 
- **Progress bar built-in renderer**: `OsBuiltInCellRenderer.progressBar` with customizable `OsProgressBarOptions` (bounds, responsive layout, custom labels and dynamic colors).
- **Image built-in renderer**: `OsBuiltInCellRenderer.image` with customizable `OsImageOptions` (fit, corner radius, padding, async loader with LRU cell cache and placeholder).
- Custom cell painters via builder pattern (direct canvas access).
- *Note:* Built-in canvas renderers like Avatar and Progress Bar currently do not map to the flutter semantics tree. Use custom widget renderers if cell-level accessibility traversal is strictly required for these specific rich displays.

### Cell Editing
- Text, number, date, select, **rich select (searchable)**, checkbox, large text, and custom editors
- Single-click and double-click edit modes
- Keyboard triggers (Enter, F2, Delete, Backspace, printable chars)
- Tab/Shift+Tab navigation between editable cells
- `readOnlyEdit` mode (fires events without mutating data)
- Undo/redo with Ctrl+Z/Y

### Cell Selection & Range
- Click-to-start, drag-to-extend range selection
- Shift+click to extend, Ctrl+click for multiple ranges
- `getCellRanges()`, `addCellRange()`, `clearRangeSelection()` API

### Data Management
- Client-side row model with sort/filter pipeline
- Infinite row model (lazy-loading with block cache)
- Row transactions (`applyTransaction`)
- Immutable data mode, async transactions, delta sort
- CSV export with full callback support
- Clipboard (copy/cut/paste) with undo/redo integration
- Grid state save/restore (JSON-serialisable)

### RowNode API & Displayed Model
- `OsRowNode<TData>` identity layer shared by grouping, tree data and pivot
- `controller.getNode(id)` / `controller.getRenderedNodes()`
- Displayed-model accessors: `getDisplayedRowCount()`, `getDisplayedRowAtIndex()` (filter+sort+pagination aware)

### Tree Data
- Hierarchical rows via `treeData: true` + `getDataPath`
- Path segments become synthetic group rows sharing the grouping pipeline's expansion state
- Expand/collapse via tap or controller API; works with filter, sort and pagination

### Cell Renderers
- Built-in `animateShowChange` renderer (delta arrows + value pill)
- **Sparklines** (`OsBuiltInCellRenderer.sparkline`) — line/bar/area mini-charts with theme-driven colours via `OsSparklineOptions`

### Pagination
- Page navigation with page size selector
- Auto page size from viewport height
- Full controller API

### Theming
- `OsGridTheme.quartz()` and `OsGridTheme.quartzDark()` presets
- `OsGridTheme.fromThemeData()` — derive from Flutter's Material theme
- Full parameter system mirroring OS Grid's theme params

### Other
- Keyboard navigation (arrows, Page Up/Down, Home/End) with `navigateToNextCell`/`tabToNextCell` overrides
- Tooltips (hover delay, mouse tracking, themed overlay)
- Cell spanning (colSpan, rowSpan, auto-merge)
- Context menu (right-click, customisable items)
- Aligned grids (horizontal scroll sync)
- Status bar aggregation panels (`statusBarConfig`: sum/avg/min/max/count chips with alignment and formatting)
- Loading / no-rows overlays (`loading`, `loadingOverlay`, `noRowsOverlay`) with localized defaults
- Lifecycle events: `onFirstDataRendered`, `onGridSizeChanged`, `onModelUpdated`, `onRowDataChanged`
- Value cache
- Localisation (90+ translatable keys)
- Grid options validation (debug mode warnings)
- Accessibility (semantics tree, ARIA roles, high contrast)

## Typed Data

Use generics for type-safe row data:

```dart
class Athlete {
  final String name;
  final int age;
  final String country;
  Athlete({required this.name, required this.age, required this.country});
}

OsGrid<Athlete>(
  columnDefs: [
    OsColumnDef<Athlete>(
      field: 'name',
      headerName: 'Name',
      valueGetter: (params) => params.data.name,
    ),
    OsColumnDef<Athlete>(
      field: 'age',
      headerName: 'Age',
      valueGetter: (params) => params.data.age,
    ),
  ],
  rowData: athletes,
)
```

## Controller API

```dart
final controller = OsGridController<Map<String, dynamic>>();

// Selection
controller.selectAll();
controller.deselectAll();
controller.getSelectedRows();

// Data
controller.setRowData(newData);
controller.applyTransaction(OsRowTransaction(add: [newRow]));

// Sorting & Filtering
controller.setSortModel([OsSortModel(colId: 'age', sort: SortDirection.asc)]);
controller.setFilterModel({'age': filterModel});

// Export
final csv = controller.exportCsv();

// State
final state = controller.getState();
controller.setState(savedState);

// Row nodes & displayed model
final node = controller.getNode('row-1');
for (final node in controller.getRenderedNodes()) { ... }
controller.getDisplayedRowCount();
controller.getDisplayedRowAtIndex(0);

// Events
controller.onSelectionChanged.listen((event) { ... });
controller.onCellClicked.listen((event) { ... });
```

## Theming

```dart
// Light theme
OsGrid(theme: OsGridTheme.quartz(), ...)

// Dark theme
OsGrid(theme: OsGridTheme.quartzDark(), ...)

// From Material theme
OsGrid(theme: OsGridTheme.fromThemeData(Theme.of(context)), ...)

// Custom
OsGrid(
  theme: OsGridTheme.quartz().copyWith(
    accentColor: Colors.indigo,
    headerBackgroundColor: Colors.grey.shade100,
    rowHeight: 48,
  ),
  ...
)
```

## Platform Support

| Platform | Status |
|----------|--------|
| Windows  | ✅ Fully supported |
| macOS    | ✅ Fully supported |
| Linux    | ✅ Fully supported |
| Web      | ✅ Supported (canvas renderer) |
| iOS      | ✅ Supported |
| Android  | ✅ Supported |

## Documentation

- [Changelog](CHANGELOG.md) — release notes and default-behaviour notes
- [Public API Design](docs/public-api-design.md) — full API surface documentation
- [Architecture](docs/architecture.md) — rendering, pipeline and internals
- [Example App](example/) — runnable demo with multiple screens
- [Charts companion](packages/os_grid_flutter_charts/) — fl_chart / graphic
  renderers behind the core `OsChartRenderer` interface (not yet on pub.dev)

## Known limitations

Honest gaps, so you are not surprised after installing:

- **Aligned grids** (`OsAlignedGrid`) synchronise horizontal scrolling
  only. Column moves, resizes, pinning and visibility are not shared
  between grouped grids — wire those yourself from the column events.
- The **text filter** has no `textMatcher` / `textFormatter` escape
  hatches that AG Grid offers.
- **Integrated Charts** ships the definition and extraction pipeline in the
  core, but the fl_chart and graphic renderers are not on pub.dev yet —
  supply your own `OsChartRenderer` (see
  [`packages/os_grid_flutter_charts`](packages/os_grid_flutter_charts/)).

## Issues

Report bugs and feature requests at
[github.com/geometric-dev/os-grid-flutter/issues](https://github.com/geometric-dev/os-grid-flutter/issues).

## Development

```bash
flutter pub get          # Install dependencies
dart format .            # Format code
flutter analyze          # Static analysis
flutter test             # Run all tests (2,700+)
flutter run -d windows   # Run example app
```

## License

MIT — see [LICENSE](LICENSE) for details.
