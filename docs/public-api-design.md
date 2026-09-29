# OS Grid Flutter — Public API Design

This document defines the developer-facing API for `os_grid_flutter`. The goal is to feel native to Flutter/Dart while staying conceptually aligned with OS Grid's TypeScript API so that users familiar with OS Grid can transfer their knowledge.

---

## Basic Usage

```dart
import 'package:os_grid_flutter/os_grid_flutter.dart';

class MyGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return OsGrid(
      columnDefs: [
        OsColumnDef(field: 'name', headerName: 'Name'),
        OsColumnDef(field: 'age', headerName: 'Age', width: 100),
        OsColumnDef(field: 'country', headerName: 'Country', sortable: true),
      ],
      rowData: [
        {'name': 'Alice', 'age': 32, 'country': 'UK'},
        {'name': 'Bob', 'age': 28, 'country': 'US'},
        {'name': 'Charlie', 'age': 45, 'country': 'DE'},
      ],
    );
  }
}
```

---

## Strongly Typed Row Data

```dart
class Athlete {
  final String name;
  final int age;
  final String country;
  const Athlete({required this.name, required this.age, required this.country});
}

class MyGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return OsGrid<Athlete>(
      columnDefs: [
        OsColumnDef<Athlete>(
          headerName: 'Name',
          valueGetter: (params) => params.data.name,
        ),
        OsColumnDef<Athlete>(
          headerName: 'Age',
          valueGetter: (params) => params.data.age,
        ),
        OsColumnDef<Athlete>(
          headerName: 'Country',
          valueGetter: (params) => params.data.country,
          filter: OsTextFilter(),
        ),
      ],
      rowData: athletes,
    );
  }
}
```

---

## Grid Controller (Imperative API)

The `GridController` follows Flutter's controller pattern (like `ScrollController`, `TextEditingController`). It provides imperative access to the grid after it's created.

```dart
class MyGridPage extends StatefulWidget {
  @override
  State<MyGridPage> createState() => _MyGridPageState();
}

class _MyGridPageState extends State<MyGridPage> {
  final _gridController = OsGridController<Athlete>();

  @override
  void dispose() {
    _gridController.dispose();
    super.dispose();
  }

  void _selectAll() {
    _gridController.selectAll();
  }

  void _exportCsv() {
    _gridController.exportCsv();
  }

  void _scrollToTop() {
    _gridController.ensureIndexVisible(0);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            ElevatedButton(onPressed: _selectAll, child: Text('Select All')),
            ElevatedButton(onPressed: _exportCsv, child: Text('Export CSV')),
            ElevatedButton(onPressed: _scrollToTop, child: Text('Scroll to Top')),
          ],
        ),
        Expanded(
          child: OsGrid<Athlete>(
            controller: _gridController,
            columnDefs: columnDefs,
            rowData: athletes,
          ),
        ),
      ],
    );
  }
}
```

---

## Events (Streams)

Events are exposed as streams on the controller, following Dart conventions:

```dart
final controller = OsGridController<Athlete>();

// Listen to selection changes
controller.onSelectionChanged.listen((event) {
  print('Selected ${event.selectedRows.length} rows');
});

// Listen to cell value changes
controller.onCellValueChanged.listen((event) {
  print('${event.colDef.field} changed from ${event.oldValue} to ${event.newValue}');
});

// Listen to sort changes
controller.onSortChanged.listen((event) {
  print('Sort model: ${event.sortModel}');
});
```

Alternatively, for simpler cases, callback props on the widget:

```dart
OsGrid<Athlete>(
  columnDefs: columnDefs,
  rowData: athletes,
  onGridReady: (controller) {
    // Grid is ready, controller is populated
  },
  onRowSelected: (event) {
    print('Row selected: ${event.data.name}');
  },
  onCellClicked: (event) {
    print('Clicked ${event.column.field} on row ${event.rowIndex}');
  },
);
```

---

## Column Definitions

```dart
OsColumnDef<Athlete>(
  // Identity
  field: 'name',              // shorthand: uses this as key into Map row data
  colId: 'nameCol',          // explicit ID (auto-generated from field if omitted)
  headerName: 'Athlete Name',

  // Sizing
  width: 150,
  minWidth: 80,
  maxWidth: 400,
  flex: 1,                   // flex-grow within available space

  // Display
  valueGetter: (params) => params.data.name,
  valueFormatter: (params) => '${params.value}!',
  cellRenderer: (params) => Text(params.value, style: TextStyle(fontWeight: FontWeight.bold)),

  // Behaviour
  sortable: true,
  resizable: true,
  filter: OsTextFilter(),    // or OsNumberFilter(), OsDateFilter()
  editable: true,
  cellEditor: OsTextCellEditor(),

  // Pinning
  pinned: OsColumnPin.left,

  // Styling
  cellStyle: (params) => OsCellStyle(
    backgroundColor: params.value > 30 ? Colors.green.shade50 : null,
  ),
  cellClass: (params) => params.rowIndex.isEven ? 'even-row' : 'odd-row',
)
```

---

## Column Groups

```dart
OsGrid<Athlete>(
  columnDefs: [
    OsColumnGroup(
      headerName: 'Personal Info',
      children: [
        OsColumnDef(field: 'name'),
        OsColumnDef(field: 'age'),
      ],
    ),
    OsColumnGroup(
      headerName: 'Location',
      children: [
        OsColumnDef(field: 'country'),
        OsColumnDef(field: 'city'),
      ],
    ),
  ],
  rowData: athletes,
);
```

---

## Sorting

```dart
OsGrid<Athlete>(
  columnDefs: [
    OsColumnDef(field: 'name', sortable: true),
    OsColumnDef(
      field: 'age',
      sortable: true,
      comparator: (a, b, nodeA, nodeB, isDescending) => a.compareTo(b),
    ),
  ],
  rowData: athletes,
  // Multi-sort enabled by default with shift-click
  multiSortKey: AgMultiSortKey.ctrl,  // or .shift (default)
  // Pre-sorted
  initialSort: [
    OsSortModel(colId: 'age', sort: AgSortDirection.ascending),
  ],
);
```

---

## Filtering

```dart
OsGrid<Athlete>(
  columnDefs: [
    OsColumnDef(
      field: 'name',
      filter: OsTextFilter(
        filterOptions: [OsTextFilterOption.contains, OsTextFilterOption.startsWith],
        defaultOption: OsTextFilterOption.contains,
      ),
    ),
    OsColumnDef(
      field: 'age',
      filter: OsNumberFilter(
        filterOptions: [OsNumberFilterOption.greaterThan, OsNumberFilterOption.lessThan],
      ),
    ),
    OsColumnDef(
      field: 'date',
      filter: OsDateFilter(),
    ),
  ],
  rowData: athletes,
  // Quick filter (searches all columns)
  quickFilterText: searchQuery,
);
```

---

## Row Selection

```dart
OsGrid<Athlete>(
  columnDefs: columnDefs,
  rowData: athletes,
  rowSelection: OsRowSelection.multiple(
    checkboxes: true,
    headerCheckbox: true,
  ),
  // Or single selection:
  // rowSelection: OsRowSelection.single(),
  onSelectionChanged: (event) {
    final selected = event.selectedRows;
  },
);
```

---

## Cell Editing

```dart
OsGrid<Athlete>(
  columnDefs: [
    OsColumnDef(
      field: 'name',
      editable: true,
      cellEditor: OsTextCellEditor(),
    ),
    OsColumnDef(
      field: 'country',
      editable: true,
      cellEditor: OsSelectCellEditor(
        values: ['UK', 'US', 'DE', 'FR'],
      ),
    ),
    OsColumnDef(
      field: 'age',
      editable: (params) => params.data.country != 'UK', // conditional
      cellEditor: OsNumberCellEditor(min: 0, max: 120),
    ),
  ],
  rowData: athletes,
  onCellValueChanged: (event) {
    print('Changed: ${event.oldValue} -> ${event.newValue}');
  },
);
```

---

## Custom Cell Renderer (Flutter Widget)

```dart
OsColumnDef<Athlete>(
  field: 'country',
  cellRenderer: (params) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CountryFlag(code: params.value),
        SizedBox(width: 8),
        Text(params.value),
      ],
    );
  },
);
```

For stateful renderers with access to BuildContext:

```dart
OsColumnDef<Athlete>(
  field: 'actions',
  cellRendererBuilder: (context, params) {
    // Full access to BuildContext for themes, providers, etc.
    return IconButton(
      icon: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
      onPressed: () => deleteAthlete(params.data),
    );
  },
);
```

---

## Pagination

```dart
OsGrid<Athlete>(
  columnDefs: columnDefs,
  rowData: athletes,
  pagination: OsPagination(
    pageSize: 50,
    showPageSizeSelector: true,
    pageSizeOptions: [25, 50, 100],
  ),
);
```

---

## Pinned Rows

```dart
OsGrid<Athlete>(
  columnDefs: columnDefs,
  rowData: athletes,
  pinnedTopRowData: [
    Athlete(name: 'TOTAL', age: 0, country: ''),
  ],
  pinnedBottomRowData: [
    Athlete(name: 'AVERAGE', age: 35, country: ''),
  ],
);
```

---

## Theming

```dart
OsGrid<Athlete>(
  columnDefs: columnDefs,
  rowData: athletes,
  theme: OsGridTheme(
    // Follows Flutter's Material/Cupertino conventions
    headerBackgroundColor: Colors.blueGrey.shade50,
    headerTextStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
    cellTextStyle: TextStyle(fontSize: 13),
    rowHeight: 42,
    headerHeight: 48,
    borderColor: Colors.grey.shade300,
    selectedRowColor: Colors.blue.shade50,
    hoverRowColor: Colors.grey.shade100,
    // Or use a preset:
    // preset: OsGridThemePreset.alpine,
  ),
);

// Or integrate with Flutter's theme system:
OsGrid<Athlete>(
  columnDefs: columnDefs,
  rowData: athletes,
  theme: OsGridTheme.fromThemeData(Theme.of(context)),
);
```

---

## Modules (Feature Registration)

```dart
import 'package:os_grid_flutter/os_grid_flutter.dart';
import 'package:os_grid_flutter/modules/csv_export.dart';
import 'package:os_grid_flutter/modules/clipboard.dart';

// Register once at app startup
void main() {
  OsGrid.registerModules([
    AgCsvExportModule(),
    AgClipboardModule(),
  ]);
  runApp(MyApp());
}

// Or per-grid:
OsGrid<Athlete>(
  modules: [AgCsvExportModule()],
  columnDefs: columnDefs,
  rowData: athletes,
);
```

---

## Full Example

```dart
import 'package:flutter/material.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('OS Grid Flutter Demo')),
        body: const AthletesGrid(),
      ),
    );
  }
}

class AthletesGrid extends StatefulWidget {
  const AthletesGrid({super.key});

  @override
  State<AthletesGrid> createState() => _AthletesGridState();
}

class _AthletesGridState extends State<AthletesGrid> {
  final _controller = OsGridController<Map<String, dynamic>>();
  String _quickFilter = '';

  final _columnDefs = [
    OsColumnDef(field: 'name', headerName: 'Name', filter: OsTextFilter(), sortable: true),
    OsColumnDef(field: 'age', headerName: 'Age', width: 100, filter: OsNumberFilter(), sortable: true),
    OsColumnDef(field: 'country', headerName: 'Country', filter: OsTextFilter()),
    OsColumnDef(
      field: 'gold',
      headerName: 'Gold Medals',
      sortable: true,
      cellStyle: (params) => OsCellStyle(
        fontWeight: params.value > 5 ? FontWeight.bold : null,
        color: params.value > 5 ? Colors.amber.shade800 : null,
      ),
    ),
  ];

  final _rowData = [
    {'name': 'Michael Phelps', 'age': 39, 'country': 'US', 'gold': 23},
    {'name': 'Usain Bolt', 'age': 37, 'country': 'JM', 'gold': 8},
    {'name': 'Mo Farah', 'age': 41, 'country': 'UK', 'gold': 4},
    // ... thousands more rows
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Quick filter...',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) => setState(() => _quickFilter = value),
          ),
        ),
        Expanded(
          child: OsGrid(
            controller: _controller,
            columnDefs: _columnDefs,
            rowData: _rowData,
            quickFilterText: _quickFilter,
            rowSelection: OsRowSelection.multiple(checkboxes: true),
            pagination: OsPagination(pageSize: 100),
            theme: OsGridTheme.fromThemeData(Theme.of(context)),
            onGridReady: (_) => print('Grid ready!'),
          ),
        ),
      ],
    );
  }
}
```

---

## GridController API Reference (Key Methods)

```dart
abstract class OsGridController<TData> extends ChangeNotifier {
  // Lifecycle
  void dispose();

  // Row data
  void setRowData(List<TData> data);
  void applyTransaction(OsRowTransaction<TData> transaction);
  List<TData> getSelectedRows();
  TData? getRowAtIndex(int index);
  int get rowCount;

  // Selection
  void selectAll();
  void deselectAll();
  void selectRows(List<int> indices);

  // Columns
  void setColumnDefs(List<OsColumnDefBase> defs);
  void autoSizeColumns({List<String>? colIds, bool skipHeader = false});
  void sizeColumnsToFit();

  // Sort & Filter
  void setSortModel(List<OsSortModel> model);
  void setFilterModel(Map<String, dynamic> model);
  void setQuickFilter(String text);

  // Scrolling
  void ensureIndexVisible(int index);
  void ensureColumnVisible(String colId);

  // Export
  void exportCsv({OsCsvExportParams? params});

  // Events (streams)
  Stream<AgSelectionChangedEvent<TData>> get onSelectionChanged;
  Stream<OsCellClickedEvent<TData>> get onCellClicked;
  Stream<OsCellValueChangedEvent<TData>> get onCellValueChanged;
  Stream<AgSortChangedEvent> get onSortChanged;
  Stream<OsFilterChangedEvent> get onFilterChanged;
  Stream<OsRowDoubleClickedEvent<TData>> get onRowDoubleClicked;
  Stream<OsGridReadyEvent> get onGridReady;
}
```

---

## Design Principles

1. **Flutter-native feel** — Named parameters, controller pattern, streams, integrates with `Theme`, `MediaQuery`, `Semantics`.
2. **Conceptual parity with OS Grid** — Same terminology (ColDef, RowNode, GridApi concepts), same feature set. A developer who knows OS Grid should feel at home.
3. **Type-safe** — Generic `<TData>` throughout. No stringly-typed APIs where avoidable.
4. **Performant by default** — Virtualisation, efficient rebuilds, no unnecessary widget allocations.
5. **Modular** — Import only what you use. Core is lightweight; features are opt-in modules.
6. **Desktop-first** — Keyboard navigation, right-click context menus, resize cursors, platform scrollbars.
