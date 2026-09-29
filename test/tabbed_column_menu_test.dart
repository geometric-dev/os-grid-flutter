import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

void main() {
  group('OsColumnMenuDef', () {
    test(
      'effectiveTabs returns all tabs by default when column has filter',
      () {
        const def = OsColumnMenuDef();
        final tabs = def.effectiveTabs(hasFilter: true);
        expect(tabs, [
          OsColumnMenuTab.general,
          OsColumnMenuTab.filter,
          OsColumnMenuTab.columns,
        ]);
      },
    );

    test('effectiveTabs hides filter tab when column has no filter', () {
      const def = OsColumnMenuDef();
      final tabs = def.effectiveTabs(hasFilter: false);
      expect(tabs, [OsColumnMenuTab.general, OsColumnMenuTab.columns]);
    });

    test(
      'effectiveTabs hides filter tab when suppressColumnFilter is true',
      () {
        const def = OsColumnMenuDef(suppressColumnFilter: true);
        final tabs = def.effectiveTabs(hasFilter: true);
        expect(tabs, [OsColumnMenuTab.general, OsColumnMenuTab.columns]);
      },
    );

    test('effectiveTabs respects custom menuTabs order', () {
      const def = OsColumnMenuDef(
        menuTabs: [OsColumnMenuTab.filter, OsColumnMenuTab.general],
      );
      final tabs = def.effectiveTabs(hasFilter: true);
      expect(tabs, [OsColumnMenuTab.filter, OsColumnMenuTab.general]);
    });

    test(
      'effectiveTabs filters out filter tab from custom menuTabs when no filter',
      () {
        const def = OsColumnMenuDef(
          menuTabs: [OsColumnMenuTab.filter, OsColumnMenuTab.general],
        );
        final tabs = def.effectiveTabs(hasFilter: false);
        expect(tabs, [OsColumnMenuTab.general]);
      },
    );
  });

  group('Tabbed column menu integration', () {
    Widget buildGrid({
      OsColumnMenuDef? columnMenu,
      List<OsColumnDef>? columns,
      List<Map<String, dynamic>>? rowData,
      OsGridTheme? theme,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: OsGrid(
              columnMenu: columnMenu,
              columnDefs:
                  columns ??
                  [
                    const OsColumnDef(
                      field: 'name',
                      headerName: 'Name',
                      sortable: true,
                      filter: OsTextFilter(),
                    ),
                    const OsColumnDef(
                      field: 'age',
                      headerName: 'Age',
                      sortable: true,
                      filter: OsNumberFilter(),
                    ),
                    const OsColumnDef(
                      field: 'city',
                      headerName: 'City',
                      sortable: true,
                    ),
                  ],
              rowData:
                  rowData ??
                  [
                    {'name': 'Alice', 'age': 30, 'city': 'London'},
                    {'name': 'Bob', 'age': 25, 'city': 'Paris'},
                    {'name': 'Carol', 'age': 35, 'city': 'Berlin'},
                  ],
              theme: theme,
            ),
          ),
        ),
      );
    }

    testWidgets('shows simple menu when columnMenu is null', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildGrid());
      await tester.pumpAndSettle();

      // The simple menu should be used — no tabbed menu present
      expect(find.byType(TabbedColumnMenu), findsNothing);
    });

    testWidgets('shows tabbed menu when columnMenu is configured', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildGrid(columnMenu: const OsColumnMenuDef()));
      await tester.pumpAndSettle();

      // Initially no menu shown
      expect(find.byType(TabbedColumnMenu), findsNothing);
    });

    testWidgets('tabbed menu shows General tab content by default', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 500,
              child: TabbedColumnMenu(
                columnIndex: 0,
                colDef: const OsColumnDef(
                  field: 'name',
                  headerName: 'Name',
                  sortable: true,
                  filter: OsTextFilter(),
                ),
                anchorRect: const Rect.fromLTWH(100, 48, 24, 24),
                gridSize: const Size(400, 500),
                menuDef: const OsColumnMenuDef(),
                tabs: const [
                  OsColumnMenuTab.general,
                  OsColumnMenuTab.filter,
                  OsColumnMenuTab.columns,
                ],
                onAction: (_) {},
                onDismiss: () {},
                filter: const OsTextFilter(),
                colId: 'name',
                allColumns: [
                  const OsColumnDef(field: 'name', headerName: 'Name'),
                  const OsColumnDef(field: 'age', headerName: 'Age'),
                ],
                columnDefs: [
                  const OsColumnDef(field: 'name', headerName: 'Name'),
                  const OsColumnDef(field: 'age', headerName: 'Age'),
                ],
                hiddenColumnIds: const {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The General tab label should be visible
      expect(find.text('General'), findsOneWidget);
      expect(find.text('Filter'), findsOneWidget);
      expect(find.text('Columns'), findsOneWidget);

      // General tab content: should show sort/pin/autosize items
      expect(find.text('Sort Ascending'), findsOneWidget);
      expect(find.text('Sort Descending'), findsOneWidget);
      expect(find.text('Autosize This Column'), findsOneWidget);
      expect(find.text('Reset Columns'), findsOneWidget);
    });

    testWidgets('switching to Filter tab shows filter controls', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 500,
              child: TabbedColumnMenu(
                columnIndex: 0,
                colDef: const OsColumnDef(
                  field: 'name',
                  headerName: 'Name',
                  sortable: true,
                  filter: OsTextFilter(),
                ),
                anchorRect: const Rect.fromLTWH(100, 48, 24, 24),
                gridSize: const Size(400, 500),
                menuDef: const OsColumnMenuDef(),
                tabs: const [
                  OsColumnMenuTab.general,
                  OsColumnMenuTab.filter,
                  OsColumnMenuTab.columns,
                ],
                onAction: (_) {},
                onDismiss: () {},
                filter: const OsTextFilter(),
                colId: 'name',
                allColumns: [
                  const OsColumnDef(field: 'name', headerName: 'Name'),
                ],
                columnDefs: [
                  const OsColumnDef(field: 'name', headerName: 'Name'),
                ],
                hiddenColumnIds: const {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the Filter tab
      await tester.tap(find.text('Filter'));
      await tester.pumpAndSettle();

      // Should show filter-specific UI: the Clear button and filter input
      expect(find.text('Clear'), findsOneWidget);
      // Sort items should be gone (we're on Filter tab now)
      expect(find.text('Sort Ascending'), findsNothing);
    });

    testWidgets('switching to Columns tab shows column checkboxes', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 500,
              child: TabbedColumnMenu(
                columnIndex: 0,
                colDef: const OsColumnDef(
                  field: 'name',
                  headerName: 'Name',
                  sortable: true,
                  filter: OsTextFilter(),
                ),
                anchorRect: const Rect.fromLTWH(100, 48, 24, 24),
                gridSize: const Size(400, 500),
                menuDef: const OsColumnMenuDef(),
                tabs: const [
                  OsColumnMenuTab.general,
                  OsColumnMenuTab.filter,
                  OsColumnMenuTab.columns,
                ],
                onAction: (_) {},
                onDismiss: () {},
                filter: const OsTextFilter(),
                colId: 'name',
                allColumns: [
                  const OsColumnDef(field: 'name', headerName: 'Name'),
                  const OsColumnDef(field: 'age', headerName: 'Age'),
                  const OsColumnDef(field: 'city', headerName: 'City'),
                ],
                columnDefs: [
                  const OsColumnDef(field: 'name', headerName: 'Name'),
                  const OsColumnDef(field: 'age', headerName: 'Age'),
                  const OsColumnDef(field: 'city', headerName: 'City'),
                ],
                hiddenColumnIds: const {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the Columns tab
      await tester.tap(find.text('Columns'));
      await tester.pumpAndSettle();

      // Should show column names with checkboxes
      expect(find.text('Name'), findsWidgets); // tab label + column name
      expect(find.text('Age'), findsOneWidget);
      expect(find.text('City'), findsOneWidget);
      // Should have checkboxes
      expect(find.byType(Checkbox), findsWidgets);
    });

    testWidgets('General tab fires onAction when item tapped', (
      WidgetTester tester,
    ) async {
      ColumnMenuEvent? receivedEvent;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 500,
              child: TabbedColumnMenu(
                columnIndex: 0,
                colDef: const OsColumnDef(
                  field: 'name',
                  headerName: 'Name',
                  sortable: true,
                  filter: OsTextFilter(),
                ),
                anchorRect: const Rect.fromLTWH(100, 48, 24, 24),
                gridSize: const Size(400, 500),
                menuDef: const OsColumnMenuDef(),
                tabs: const [
                  OsColumnMenuTab.general,
                  OsColumnMenuTab.filter,
                  OsColumnMenuTab.columns,
                ],
                onAction: (event) => receivedEvent = event,
                onDismiss: () {},
                filter: const OsTextFilter(),
                colId: 'name',
                allColumns: [],
                columnDefs: [],
                hiddenColumnIds: const {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap "Sort Ascending"
      await tester.tap(find.text('Sort Ascending'));
      await tester.pumpAndSettle();

      expect(receivedEvent, isNotNull);
      expect(receivedEvent!.action, ColumnMenuAction.sortAscending);
      expect(receivedEvent!.columnIndex, 0);
    });

    testWidgets('dismiss layer triggers onDismiss', (
      WidgetTester tester,
    ) async {
      var dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 500,
              child: TabbedColumnMenu(
                columnIndex: 0,
                colDef: const OsColumnDef(
                  field: 'name',
                  headerName: 'Name',
                  sortable: true,
                ),
                anchorRect: const Rect.fromLTWH(100, 48, 24, 24),
                gridSize: const Size(400, 500),
                menuDef: const OsColumnMenuDef(),
                tabs: const [OsColumnMenuTab.general],
                onAction: (_) {},
                onDismiss: () => dismissed = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap in the top-left corner (dismiss area)
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      expect(dismissed, isTrue);
    });

    testWidgets('filter tab applies filter when value entered', (
      WidgetTester tester,
    ) async {
      String? appliedColId;
      OsColumnFilterModel? appliedModel;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 500,
              child: TabbedColumnMenu(
                columnIndex: 0,
                colDef: const OsColumnDef(
                  field: 'name',
                  headerName: 'Name',
                  sortable: true,
                  filter: OsTextFilter(),
                ),
                anchorRect: const Rect.fromLTWH(100, 48, 24, 24),
                gridSize: const Size(400, 500),
                menuDef: const OsColumnMenuDef(),
                tabs: const [OsColumnMenuTab.filter],
                onAction: (_) {},
                onDismiss: () {},
                filter: const OsTextFilter(),
                colId: 'name',
                onFilterApply: (colId, model) {
                  appliedColId = colId;
                  appliedModel = model;
                },
                allColumns: [],
                columnDefs: [],
                hiddenColumnIds: const {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter a filter value in the text field
      final textField = find.byType(TextField);
      expect(textField, findsOneWidget);
      await tester.enterText(textField, 'Alice');
      await tester.pumpAndSettle();

      // Filter should have been applied
      expect(appliedColId, 'name');
      expect(appliedModel, isNotNull);
      expect(appliedModel!.isActive, isTrue);
      expect(appliedModel!.conditions.first.filter, 'Alice');
    });

    testWidgets('columns tab toggles column visibility', (
      WidgetTester tester,
    ) async {
      String? toggledColId;
      bool? toggledVisible;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 500,
              child: TabbedColumnMenu(
                columnIndex: 0,
                colDef: const OsColumnDef(
                  field: 'name',
                  headerName: 'Name',
                  sortable: true,
                ),
                anchorRect: const Rect.fromLTWH(100, 48, 24, 24),
                gridSize: const Size(400, 500),
                menuDef: const OsColumnMenuDef(),
                tabs: const [OsColumnMenuTab.columns],
                onAction: (_) {},
                onDismiss: () {},
                allColumns: [
                  const OsColumnDef(field: 'name', headerName: 'Name'),
                  const OsColumnDef(field: 'age', headerName: 'Age'),
                ],
                columnDefs: [
                  const OsColumnDef(field: 'name', headerName: 'Name'),
                  const OsColumnDef(field: 'age', headerName: 'Age'),
                ],
                hiddenColumnIds: const {},
                onColumnVisibilityChanged: (colId, visible) {
                  toggledColId = colId;
                  toggledVisible = visible;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the "Age" row to toggle its visibility
      await tester.tap(find.text('Age'));
      await tester.pumpAndSettle();

      expect(toggledColId, 'age');
      expect(toggledVisible, isFalse); // Was visible, now hidden
    });

    testWidgets('non-sortable column hides sort items in General tab', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 500,
              child: TabbedColumnMenu(
                columnIndex: 0,
                colDef: const OsColumnDef(
                  field: 'name',
                  headerName: 'Name',
                  sortable: false,
                ),
                anchorRect: const Rect.fromLTWH(100, 48, 24, 24),
                gridSize: const Size(400, 500),
                menuDef: const OsColumnMenuDef(),
                tabs: const [OsColumnMenuTab.general],
                onAction: (_) {},
                onDismiss: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Sort items should not be present
      expect(find.text('Sort Ascending'), findsNothing);
      expect(find.text('Sort Descending'), findsNothing);
      // But autosize and reset should still be there
      expect(find.text('Autosize This Column'), findsOneWidget);
      expect(find.text('Reset Columns'), findsOneWidget);
    });

    testWidgets('lockPinned column hides pin sub-menu in General tab', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 500,
              child: TabbedColumnMenu(
                columnIndex: 0,
                colDef: const OsColumnDef(
                  field: 'name',
                  headerName: 'Name',
                  sortable: true,
                  lockPinned: true,
                ),
                anchorRect: const Rect.fromLTWH(100, 48, 24, 24),
                gridSize: const Size(400, 500),
                menuDef: const OsColumnMenuDef(),
                tabs: const [OsColumnMenuTab.general],
                onAction: (_) {},
                onDismiss: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Pin items should not be present
      expect(find.text('Pin Column'), findsNothing);
      expect(find.text('Pin Left'), findsNothing);
      // Sort and autosize still present
      expect(find.text('Sort Ascending'), findsOneWidget);
      expect(find.text('Autosize This Column'), findsOneWidget);
    });

    testWidgets('tabbed menu only shows specified tabs', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 500,
              child: TabbedColumnMenu(
                columnIndex: 0,
                colDef: const OsColumnDef(
                  field: 'name',
                  headerName: 'Name',
                  sortable: true,
                  filter: OsTextFilter(),
                ),
                anchorRect: const Rect.fromLTWH(100, 48, 24, 24),
                gridSize: const Size(400, 500),
                menuDef: const OsColumnMenuDef(
                  menuTabs: [OsColumnMenuTab.general, OsColumnMenuTab.filter],
                ),
                tabs: const [OsColumnMenuTab.general, OsColumnMenuTab.filter],
                onAction: (_) {},
                onDismiss: () {},
                filter: const OsTextFilter(),
                colId: 'name',
                allColumns: [],
                columnDefs: [],
                hiddenColumnIds: const {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Only General and Filter tabs should be visible
      expect(find.text('General'), findsOneWidget);
      expect(find.text('Filter'), findsOneWidget);
      expect(find.text('Columns'), findsNothing);
    });

    testWidgets('columns tab search filters column list', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 500,
              child: TabbedColumnMenu(
                columnIndex: 0,
                colDef: const OsColumnDef(
                  field: 'name',
                  headerName: 'Name',
                  sortable: true,
                ),
                anchorRect: const Rect.fromLTWH(100, 48, 24, 24),
                gridSize: const Size(400, 500),
                menuDef: const OsColumnMenuDef(),
                tabs: const [OsColumnMenuTab.columns],
                onAction: (_) {},
                onDismiss: () {},
                allColumns: [
                  const OsColumnDef(field: 'name', headerName: 'Name'),
                  const OsColumnDef(field: 'age', headerName: 'Age'),
                  const OsColumnDef(field: 'city', headerName: 'City'),
                ],
                columnDefs: [
                  const OsColumnDef(field: 'name', headerName: 'Name'),
                  const OsColumnDef(field: 'age', headerName: 'Age'),
                  const OsColumnDef(field: 'city', headerName: 'City'),
                ],
                hiddenColumnIds: const {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // All columns visible initially
      expect(find.text('Name'), findsOneWidget);
      expect(find.text('Age'), findsOneWidget);
      expect(find.text('City'), findsOneWidget);

      // Type in the search field
      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'Ag');
      await tester.pumpAndSettle();

      // Only "Age" should remain
      expect(find.text('Age'), findsOneWidget);
      expect(find.text('City'), findsNothing);
    });
  });

  group('TabbedColumnMenu theming and locale', () {
    Widget buildHost(Widget child) {
      return MaterialApp(
        home: Scaffold(body: SizedBox(width: 400, height: 500, child: child)),
      );
    }

    TabbedColumnMenu buildMenu({OsLocaleText? localeText, OsGridTheme? theme}) {
      return TabbedColumnMenu(
        columnIndex: 0,
        colDef: const OsColumnDef(
          field: 'name',
          headerName: 'Name',
          sortable: true,
          filter: OsTextFilter(),
        ),
        anchorRect: const Rect.fromLTWH(100, 48, 24, 24),
        gridSize: const Size(400, 500),
        menuDef: const OsColumnMenuDef(),
        tabs: const [
          OsColumnMenuTab.general,
          OsColumnMenuTab.filter,
          OsColumnMenuTab.columns,
        ],
        onAction: (_) {},
        onDismiss: () {},
        localeText: localeText,
        theme: theme,
        filter: const OsTextFilter(),
        colId: 'name',
        allColumns: const [
          OsColumnDef(field: 'name', headerName: 'Name'),
          OsColumnDef(field: 'age', headerName: 'Age'),
        ],
        columnDefs: const [
          OsColumnDef(field: 'name', headerName: 'Name'),
          OsColumnDef(field: 'age', headerName: 'Age'),
        ],
        hiddenColumnIds: const {},
      );
    }

    testWidgets('localeText overrides tab labels and menu items', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildHost(
          buildMenu(
            localeText: OsLocaleText.fromMap({
              'general': 'Allgemein',
              'filter': 'Filtern',
              'columns': 'Spalten',
              'sortAscending': 'Aufsteigend sortieren',
            }),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Allgemein'), findsOneWidget);
      expect(find.text('Filtern'), findsOneWidget);
      expect(find.text('Spalten'), findsOneWidget);
      expect(find.text('Aufsteigend sortieren'), findsOneWidget);
      expect(find.text('General'), findsNothing);
    });

    testWidgets('theme colours resolve from the grid theme', (tester) async {
      const bg = Color(0xFF0E1116);
      await tester.pumpWidget(
        buildHost(buildMenu(theme: const OsGridTheme(backgroundColor: bg))),
      );
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate((w) => w is Material && w.color == bg),
        findsOneWidget,
      );
    });
  });
}
