import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

void main() {
  group('OsSideBarDef', () {
    test('defaultPanels creates both columns and filters panels', () {
      final def = OsSideBarDef.defaultPanels();
      expect(def.toolPanels.length, 2);
      expect(def.toolPanels[0].id, 'columns');
      expect(def.toolPanels[1].id, 'filters');
      expect(def.defaultToolPanel, 'columns');
      expect(def.position, OsSideBarPosition.right);
      expect(def.hiddenByDefault, false);
      expect(def.hideButtons, false);
    });

    test('columns creates only columns panel', () {
      final def = OsSideBarDef.columns();
      expect(def.toolPanels.length, 1);
      expect(def.toolPanels[0].id, 'columns');
      expect(def.defaultToolPanel, 'columns');
    });

    test('filters creates only filters panel', () {
      final def = OsSideBarDef.filters();
      expect(def.toolPanels.length, 1);
      expect(def.toolPanels[0].id, 'filters');
      expect(def.defaultToolPanel, 'filters');
    });

    test('custom configuration', () {
      const def = OsSideBarDef(
        toolPanels: [OsToolPanelDef.columns()],
        defaultToolPanel: 'columns',
        hiddenByDefault: true,
        position: OsSideBarPosition.left,
        hideButtons: true,
      );
      expect(def.hiddenByDefault, true);
      expect(def.position, OsSideBarPosition.left);
      expect(def.hideButtons, true);
    });
  });

  group('OsToolPanelDef', () {
    test('columns has correct defaults', () {
      const def = OsToolPanelDef.columns();
      expect(def.id, 'columns');
      expect(def.labelDefault, 'Columns');
      expect(def.labelKey, 'columns');
      expect(def.toolPanelType, OsToolPanelType.columns);
      expect(def.minWidth, 200);
      expect(def.initialWidth, 250);
      expect(def.suppressColumnFilter, false);
      expect(def.suppressColumnSelectAll, false);
      expect(def.suppressColumnExpandAll, false);
      expect(def.contractColumnSelection, false);
    });

    test('filters has correct defaults', () {
      const def = OsToolPanelDef.filters();
      expect(def.id, 'filters');
      expect(def.labelDefault, 'Filters');
      expect(def.labelKey, 'filters');
      expect(def.toolPanelType, OsToolPanelType.filters);
      expect(def.suppressFilterSearch, false);
      expect(def.suppressExpandAll, false);
    });

    test('custom panel with builder', () {
      final def = OsToolPanelDef.custom(
        id: 'myPanel',
        labelDefault: 'My Panel',
        toolPanelBuilder: (context) => const Text('Hello'),
      );
      expect(def.id, 'myPanel');
      expect(def.labelDefault, 'My Panel');
      expect(def.toolPanelType, OsToolPanelType.custom);
      expect(def.toolPanelBuilder, isNotNull);
    });
  });

  group('Side Bar events', () {
    test('OsToolPanelVisibleChangedEvent has correct properties', () {
      const event = OsToolPanelVisibleChangedEvent(
        key: 'columns',
        visible: true,
        switchingToolPanel: false,
        source: OsSideBarSource.api,
      );
      expect(event.key, 'columns');
      expect(event.visible, true);
      expect(event.switchingToolPanel, false);
      expect(event.source, OsSideBarSource.api);
    });

    test('OsSideBarUpdatedEvent is const', () {
      const event = OsSideBarUpdatedEvent();
      expect(event, isA<OsGridEvent>());
    });
  });

  group('Side Bar widget integration', () {
    testWidgets('renders with default panels on right side', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: OsGrid(
                columnDefs: [
                  const OsColumnDef(field: 'name', headerName: 'Name'),
                  const OsColumnDef(field: 'age', headerName: 'Age'),
                ],
                rowData: [
                  {'name': 'Alice', 'age': 30},
                  {'name': 'Bob', 'age': 25},
                ],
                sideBar: OsSideBarDef.defaultPanels(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Side bar should be rendered
      expect(find.byType(OsSideBar), findsOneWidget);

      // The columns panel should be open by default
      expect(find.byType(ColumnsToolPanel), findsOneWidget);

      // Should show column names in the panel
      expect(find.text('Name'), findsWidgets);
      expect(find.text('Age'), findsWidgets);
    });

    testWidgets('renders on left side when position is left', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: OsGrid(
                columnDefs: [
                  const OsColumnDef(field: 'name', headerName: 'Name'),
                ],
                rowData: [
                  {'name': 'Alice'},
                ],
                sideBar: OsSideBarDef.defaultPanels(
                  position: OsSideBarPosition.left,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(OsSideBar), findsOneWidget);
    });

    testWidgets('hidden by default when hiddenByDefault is true', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: OsGrid(
                columnDefs: [
                  const OsColumnDef(field: 'name', headerName: 'Name'),
                ],
                rowData: [
                  {'name': 'Alice'},
                ],
                sideBar: OsSideBarDef.defaultPanels(hiddenByDefault: true),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Side bar should NOT be rendered when hidden by default
      expect(find.byType(OsSideBar), findsNothing);
    });

    testWidgets('switches between panels on button tap', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: OsGrid(
                columnDefs: [
                  const OsColumnDef(
                    field: 'name',
                    headerName: 'Name',
                    filter: OsTextFilter(),
                  ),
                ],
                rowData: [
                  {'name': 'Alice'},
                ],
                sideBar: OsSideBarDef.defaultPanels(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially shows Columns panel
      expect(find.byType(ColumnsToolPanel), findsOneWidget);
      expect(find.byType(FiltersToolPanel), findsNothing);

      // Tap the filters button (second icon button)
      final filterButtons = find.byIcon(Icons.filter_list);
      expect(filterButtons, findsOneWidget);
      await tester.tap(filterButtons);
      await tester.pumpAndSettle();

      // Should now show Filters panel
      expect(find.byType(FiltersToolPanel), findsOneWidget);
      expect(find.byType(ColumnsToolPanel), findsNothing);
    });

    testWidgets('closes panel when same button is tapped again', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: OsGrid(
                columnDefs: [
                  const OsColumnDef(field: 'name', headerName: 'Name'),
                ],
                rowData: [
                  {'name': 'Alice'},
                ],
                sideBar: OsSideBarDef.defaultPanels(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially columns panel is open
      expect(find.byType(ColumnsToolPanel), findsOneWidget);

      // Tap the columns button to close it
      final columnsButton = find.byIcon(Icons.view_column_outlined);
      expect(columnsButton, findsOneWidget);
      await tester.tap(columnsButton);
      await tester.pumpAndSettle();

      // Panel should be closed
      expect(find.byType(ColumnsToolPanel), findsNothing);
      expect(find.byType(FiltersToolPanel), findsNothing);
    });
  });

  group('Side Bar controller API', () {
    testWidgets('isSideBarVisible returns correct state', (tester) async {
      final controller = OsGridController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: OsGrid(
                controller: controller,
                columnDefs: [
                  const OsColumnDef(field: 'name', headerName: 'Name'),
                ],
                rowData: [
                  {'name': 'Alice'},
                ],
                sideBar: OsSideBarDef.defaultPanels(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(controller.isSideBarVisible(), true);
    });

    testWidgets('setSideBarVisible hides the sidebar', (tester) async {
      final controller = OsGridController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: OsGrid(
                controller: controller,
                columnDefs: [
                  const OsColumnDef(field: 'name', headerName: 'Name'),
                ],
                rowData: [
                  {'name': 'Alice'},
                ],
                sideBar: OsSideBarDef.defaultPanels(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(OsSideBar), findsOneWidget);

      controller.setSideBarVisible(false);
      await tester.pumpAndSettle();

      expect(find.byType(OsSideBar), findsNothing);
    });

    testWidgets('openToolPanel opens the specified panel', (tester) async {
      final controller = OsGridController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: OsGrid(
                controller: controller,
                columnDefs: [
                  const OsColumnDef(
                    field: 'name',
                    headerName: 'Name',
                    filter: OsTextFilter(),
                  ),
                ],
                rowData: [
                  {'name': 'Alice'},
                ],
                sideBar: OsSideBarDef.defaultPanels(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially columns
      expect(controller.getOpenedToolPanel(), 'columns');

      // Open filters
      controller.openToolPanel('filters');
      await tester.pumpAndSettle();

      expect(controller.getOpenedToolPanel(), 'filters');
      expect(find.byType(FiltersToolPanel), findsOneWidget);
    });

    testWidgets('closeToolPanel closes the active panel', (tester) async {
      final controller = OsGridController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: OsGrid(
                controller: controller,
                columnDefs: [
                  const OsColumnDef(field: 'name', headerName: 'Name'),
                ],
                rowData: [
                  {'name': 'Alice'},
                ],
                sideBar: OsSideBarDef.defaultPanels(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(controller.isToolPanelShowing(), true);

      controller.closeToolPanel();
      await tester.pumpAndSettle();

      expect(controller.isToolPanelShowing(), false);
      expect(controller.getOpenedToolPanel(), isNull);
    });

    testWidgets('onToolPanelVisibleChanged event fires', (tester) async {
      final controller = OsGridController();
      final events = <OsToolPanelVisibleChangedEvent>[];
      controller.onToolPanelVisibleChanged.listen(events.add);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: OsGrid(
                controller: controller,
                columnDefs: [
                  const OsColumnDef(
                    field: 'name',
                    headerName: 'Name',
                    filter: OsTextFilter(),
                  ),
                ],
                rowData: [
                  {'name': 'Alice'},
                ],
                sideBar: OsSideBarDef.defaultPanels(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch from columns to filters
      controller.openToolPanel('filters');
      await tester.pumpAndSettle();

      // Should get two events: columns closed, filters opened
      expect(events.length, 2);
      expect(events[0].key, 'columns');
      expect(events[0].visible, false);
      expect(events[0].switchingToolPanel, true);
      expect(events[1].key, 'filters');
      expect(events[1].visible, true);
      expect(events[1].switchingToolPanel, true);
    });
  });

  group('Columns Tool Panel', () {
    testWidgets('shows all columns with checkboxes', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: OsGrid(
                columnDefs: [
                  const OsColumnDef(field: 'name', headerName: 'Name'),
                  const OsColumnDef(field: 'age', headerName: 'Age'),
                  const OsColumnDef(field: 'city', headerName: 'City'),
                ],
                rowData: [
                  {'name': 'Alice', 'age': 30, 'city': 'London'},
                ],
                sideBar: OsSideBarDef.columns(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should show column names in the tool panel
      expect(find.text('Name'), findsWidgets);
      expect(find.text('Age'), findsWidgets);
      expect(find.text('City'), findsWidgets);

      // Should have checkboxes
      expect(find.byType(Checkbox), findsNWidgets(3));
    });

    testWidgets('toggling checkbox hides/shows column', (tester) async {
      final controller = OsGridController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: OsGrid(
                controller: controller,
                columnDefs: [
                  const OsColumnDef(field: 'name', headerName: 'Name'),
                  const OsColumnDef(field: 'age', headerName: 'Age'),
                ],
                rowData: [
                  {'name': 'Alice', 'age': 30},
                ],
                sideBar: OsSideBarDef.columns(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the checkbox for the 'Name' column row
      // The columns tool panel has InkWell rows with text + checkbox
      // Tap the row containing 'Name' text to toggle visibility
      final nameCheckboxes = find.byType(Checkbox);
      expect(nameCheckboxes, findsNWidgets(2));

      // Tap the first checkbox (Name) to hide it
      await tester.tap(nameCheckboxes.first);
      await tester.pumpAndSettle();

      // The onColumnVisible event should have fired
      // And the column state should reflect the hidden column
      final state = controller.getColumnState();
      final nameState = state.firstWhere((s) => s.colId == 'name');
      expect(nameState.hide, true);
    });

    testWidgets('search filters columns list', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: OsGrid(
                columnDefs: [
                  const OsColumnDef(field: 'name', headerName: 'Name'),
                  const OsColumnDef(field: 'age', headerName: 'Age'),
                  const OsColumnDef(field: 'city', headerName: 'City'),
                ],
                rowData: [
                  {'name': 'Alice', 'age': 30, 'city': 'London'},
                ],
                sideBar: OsSideBarDef.columns(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially all 3 columns visible
      expect(find.byType(Checkbox), findsNWidgets(3));

      // Type in the search box
      final searchField = find.byType(TextField);
      expect(searchField, findsOneWidget);
      await tester.enterText(searchField, 'Ag');
      await tester.pumpAndSettle();

      // Only 'Age' should match
      expect(find.byType(Checkbox), findsOneWidget);
    });

    testWidgets('column groups are expandable', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: OsGrid(
                columnDefs: [
                  const OsColumnGroup(
                    headerName: 'Personal',
                    children: [
                      OsColumnDef(field: 'name', headerName: 'Name'),
                      OsColumnDef(field: 'age', headerName: 'Age'),
                    ],
                  ),
                  const OsColumnDef(field: 'city', headerName: 'City'),
                ],
                rowData: [
                  {'name': 'Alice', 'age': 30, 'city': 'London'},
                ],
                sideBar: OsSideBarDef.columns(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should show the group name
      expect(find.text('Personal'), findsWidgets);

      // Group should be expanded by default — children visible
      // (Name and Age checkboxes, plus City)
      expect(find.byType(Checkbox), findsNWidgets(3));
    });
  });

  group('Filters Tool Panel', () {
    testWidgets('shows filterable columns', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: OsGrid(
                columnDefs: [
                  const OsColumnDef(
                    field: 'name',
                    headerName: 'Name',
                    filter: OsTextFilter(),
                  ),
                  const OsColumnDef(
                    field: 'age',
                    headerName: 'Age',
                    filter: OsNumberFilter(),
                  ),
                  const OsColumnDef(
                    field: 'city',
                    headerName: 'City',
                    // No filter
                  ),
                ],
                rowData: [
                  {'name': 'Alice', 'age': 30, 'city': 'London'},
                ],
                sideBar: OsSideBarDef.filters(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should show Name and Age (filterable) but not City
      expect(find.text('Name'), findsWidgets);
      expect(find.text('Age'), findsWidgets);
      // City appears in the grid header but not in the filters panel list
      // We can check the FiltersToolPanel specifically
      expect(find.byType(FiltersToolPanel), findsOneWidget);
    });
  });

  group('Side bar theming and locale', () {
    testWidgets('FiltersToolPanel localeText overrides title and summaries', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 260,
              child: FiltersToolPanel(
                columns: const [
                  OsColumnDef(
                    field: 'name',
                    headerName: 'Name',
                    filter: OsTextFilter(),
                  ),
                ],
                filterModel: const {},
                localeText: OsLocaleText.fromMap({
                  'filters': 'Filter',
                  'searchOoo': 'Suchen...',
                  'noActiveFilter': 'Kein aktiver Filter',
                }),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Filter'), findsOneWidget);
      // Expand the row to reveal the summary.
      await tester.tap(find.text('Name'));
      await tester.pumpAndSettle();
      expect(find.text('Kein aktiver Filter'), findsOneWidget);
    });

    testWidgets('OsSideBar theme colours resolve from the grid theme', (
      tester,
    ) async {
      const bg = Color(0xFF10161D);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 400,
              child: OsSideBar(
                sideBarDef: OsSideBarDef.defaultPanels(),
                columns: const [OsColumnDef(field: 'name', headerName: 'Name')],
                columnDefs: const [
                  OsColumnDef(field: 'name', headerName: 'Name'),
                ],
                hiddenColumnIds: const {},
                filterModel: const {},
                openToolPanelId: 'columns',
                theme: const OsGridTheme(backgroundColor: bg),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final containers = tester.widgetList<Container>(find.byType(Container));
      expect(
        containers.any(
          (c) =>
              c.decoration is BoxDecoration &&
              (c.decoration! as BoxDecoration).color == bg,
        ),
        isTrue,
      );
    });
  });
}
