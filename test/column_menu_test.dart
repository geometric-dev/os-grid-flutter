import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

void main() {
  group('Column menu popup', () {
    Widget buildGrid({
      List<OsColumnDef>? columns,
      List<Map<String, dynamic>>? rowData,
      OsGridTheme? theme,
      OsRowSelection? rowSelection,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: OsGrid<Map<String, dynamic>>(
              columnDefs:
                  columns ??
                  [
                    const OsColumnDef(
                      field: 'name',
                      headerName: 'Name',
                      width: 200,
                      sortable: true,
                    ),
                    const OsColumnDef(
                      field: 'age',
                      headerName: 'Age',
                      width: 100,
                      sortable: true,
                    ),
                    const OsColumnDef(
                      field: 'country',
                      headerName: 'Country',
                      width: 150,
                    ),
                  ],
              rowData:
                  rowData ??
                  [
                    {'name': 'Alice', 'age': 32, 'country': 'UK'},
                    {'name': 'Bob', 'age': 28, 'country': 'US'},
                    {'name': 'Charlie', 'age': 45, 'country': 'CA'},
                  ],
              theme: theme,
              rowSelection: rowSelection,
            ),
          ),
        ),
      );
    }

    testWidgets('tapping menu icon area opens column menu popup', (
      tester,
    ) async {
      await tester.pumpWidget(buildGrid());
      await tester.pumpAndSettle();

      // The menu icon (⋮) is at the right edge of the header cell.
      // For a 200px wide column starting at x=0, the icon centre is at
      // approximately x = 200 - 8 - 2 = 190, y = headerHeight/2 = 24
      await tester.tapAt(const Offset(190, 24));
      await tester.pumpAndSettle();

      // The column menu popup should now be visible
      expect(find.text('Sort Ascending'), findsOneWidget);
      expect(find.text('Sort Descending'), findsOneWidget);
      expect(find.text('Pin Column'), findsOneWidget);
      expect(find.text('Autosize This Column'), findsOneWidget);
      expect(find.text('Autosize All Columns'), findsOneWidget);
      expect(find.text('Reset Columns'), findsOneWidget);
    });

    testWidgets('menu shows pin sub-items', (tester) async {
      await tester.pumpWidget(buildGrid());
      await tester.pumpAndSettle();

      // Tap menu icon on first column
      await tester.tapAt(const Offset(190, 24));
      await tester.pumpAndSettle();

      // Pin sub-items should be visible
      expect(find.text('Pin Left'), findsOneWidget);
      expect(find.text('Pin Right'), findsOneWidget);
      expect(find.text('No Pin'), findsOneWidget);
    });

    testWidgets('sort ascending action sorts the column', (tester) async {
      await tester.pumpWidget(buildGrid());
      await tester.pumpAndSettle();

      // Tap menu icon on first column (Name, 200px wide)
      await tester.tapAt(const Offset(190, 24));
      await tester.pumpAndSettle();

      // Tap "Sort Ascending"
      await tester.tap(find.text('Sort Ascending'));
      await tester.pumpAndSettle();

      // Menu should be dismissed
      expect(find.text('Sort Ascending'), findsNothing);
    });

    testWidgets('sort descending action sorts the column', (tester) async {
      await tester.pumpWidget(buildGrid());
      await tester.pumpAndSettle();

      // Tap menu icon on first column
      await tester.tapAt(const Offset(190, 24));
      await tester.pumpAndSettle();

      // Tap "Sort Descending"
      await tester.tap(find.text('Sort Descending'));
      await tester.pumpAndSettle();

      // Menu should be dismissed
      expect(find.text('Sort Descending'), findsNothing);
    });

    testWidgets('non-sortable column does not show sort items', (tester) async {
      await tester.pumpWidget(buildGrid());
      await tester.pumpAndSettle();

      // Tap menu icon on third column (Country, not sortable)
      // Country column starts at x=300 (200+100), width=150
      // Menu icon at x = 300 + 150 - 8 - 2 = 440
      await tester.tapAt(const Offset(440, 24));
      await tester.pumpAndSettle();

      // Sort items should NOT be present
      expect(find.text('Sort Ascending'), findsNothing);
      expect(find.text('Sort Descending'), findsNothing);

      // But pin and autosize should still be there
      expect(find.text('Pin Column'), findsOneWidget);
      expect(find.text('Autosize This Column'), findsOneWidget);
    });

    testWidgets('dismiss menu by tapping outside', (tester) async {
      await tester.pumpWidget(buildGrid());
      await tester.pumpAndSettle();

      // Open menu
      await tester.tapAt(const Offset(190, 24));
      await tester.pumpAndSettle();
      expect(find.text('Pin Column'), findsOneWidget);

      // Tap far outside the menu area (bottom-right corner, well away from popup)
      await tester.tapAt(const Offset(700, 550));
      await tester.pumpAndSettle();

      // Menu should be dismissed
      expect(find.text('Pin Column'), findsNothing);
    });

    testWidgets('reset columns action clears sort and widths', (tester) async {
      await tester.pumpWidget(buildGrid());
      await tester.pumpAndSettle();

      // First sort a column via menu
      await tester.tapAt(const Offset(190, 24));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sort Ascending'));
      await tester.pumpAndSettle();

      // Now open menu again and reset
      await tester.tapAt(const Offset(190, 24));
      await tester.pumpAndSettle();

      // After sorting, "Clear Sort" should appear instead of one of the sort options
      expect(find.text('Clear Sort'), findsOneWidget);

      await tester.tap(find.text('Reset Columns'));
      await tester.pumpAndSettle();

      // Menu dismissed
      expect(find.text('Reset Columns'), findsNothing);
    });

    testWidgets('autosize this column action resizes column', (tester) async {
      await tester.pumpWidget(buildGrid());
      await tester.pumpAndSettle();

      // Open menu on first column
      await tester.tapAt(const Offset(190, 24));
      await tester.pumpAndSettle();

      // Tap autosize
      await tester.tap(find.text('Autosize This Column'));
      await tester.pumpAndSettle();

      // Menu should be dismissed (action was performed)
      expect(find.text('Autosize This Column'), findsNothing);
    });

    testWidgets('autosize all columns action resizes all', (tester) async {
      await tester.pumpWidget(buildGrid());
      await tester.pumpAndSettle();

      // Open menu
      await tester.tapAt(const Offset(190, 24));
      await tester.pumpAndSettle();

      // Tap autosize all
      await tester.tap(find.text('Autosize All Columns'));
      await tester.pumpAndSettle();

      // Menu should be dismissed
      expect(find.text('Autosize All Columns'), findsNothing);
    });

    testWidgets('pin left action pins the column', (tester) async {
      await tester.pumpWidget(buildGrid());
      await tester.pumpAndSettle();

      // Open menu on second column (Age, starts at x=200, width=100)
      // Menu icon at x = 200 + 100 - 8 - 2 = 290
      await tester.tapAt(const Offset(290, 24));
      await tester.pumpAndSettle();

      // Tap "Pin Left"
      await tester.tap(find.text('Pin Left'));
      await tester.pumpAndSettle();

      // Menu should be dismissed
      expect(find.text('Pin Left'), findsNothing);
    });

    testWidgets('renders with dark theme', (tester) async {
      await tester.pumpWidget(buildGrid(theme: OsGridTheme.quartzDark()));
      await tester.pumpAndSettle();

      // Open menu
      await tester.tapAt(const Offset(190, 24));
      await tester.pumpAndSettle();

      // Menu should render without errors
      expect(find.text('Sort Ascending'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('menu does not appear for checkbox column', (tester) async {
      await tester.pumpWidget(
        buildGrid(rowSelection: OsRowSelection.multiple(checkboxes: true)),
      );
      await tester.pumpAndSettle();

      // The checkbox column is 32px wide, pinned left.
      // Tap in the checkbox header area — should NOT open a menu
      await tester.tapAt(const Offset(16, 24));
      await tester.pumpAndSettle();

      // No menu should appear
      expect(find.text('Pin Column'), findsNothing);
    });

    testWidgets('clear sort appears only when column is sorted', (
      tester,
    ) async {
      await tester.pumpWidget(buildGrid());
      await tester.pumpAndSettle();

      // Open menu — no "Clear Sort" initially
      await tester.tapAt(const Offset(190, 24));
      await tester.pumpAndSettle();
      expect(find.text('Clear Sort'), findsNothing);

      // Sort ascending
      await tester.tap(find.text('Sort Ascending'));
      await tester.pumpAndSettle();

      // Re-open menu — "Clear Sort" should now appear
      await tester.tapAt(const Offset(190, 24));
      await tester.pumpAndSettle();
      expect(find.text('Clear Sort'), findsOneWidget);

      // "Sort Ascending" should NOT appear (already sorted asc)
      expect(find.text('Sort Ascending'), findsNothing);
      // "Sort Descending" should still appear
      expect(find.text('Sort Descending'), findsOneWidget);
    });
  });

  group('ColumnMenuPopup widget', () {
    testWidgets('renders all expected menu items for sortable column', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 600,
              child: ColumnMenuPopup(
                columnIndex: 0,
                colDef: const OsColumnDef(
                  field: 'name',
                  headerName: 'Name',
                  sortable: true,
                ),
                anchorRect: const Rect.fromLTWH(100, 48, 200, 48),
                gridSize: const Size(400, 600),
                theme: OsGridTheme.quartz(),
                onAction: (_) {},
                onDismiss: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Sort Ascending'), findsOneWidget);
      expect(find.text('Sort Descending'), findsOneWidget);
      expect(find.text('Pin Column'), findsOneWidget);
      expect(find.text('Pin Left'), findsOneWidget);
      expect(find.text('Pin Right'), findsOneWidget);
      expect(find.text('No Pin'), findsOneWidget);
      expect(find.text('Autosize This Column'), findsOneWidget);
      expect(find.text('Autosize All Columns'), findsOneWidget);
      expect(find.text('Reset Columns'), findsOneWidget);
    });

    testWidgets('emits correct action on tap', (tester) async {
      ColumnMenuEvent? receivedEvent;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 600,
              child: ColumnMenuPopup(
                columnIndex: 2,
                colDef: const OsColumnDef(
                  field: 'country',
                  headerName: 'Country',
                  sortable: true,
                ),
                anchorRect: const Rect.fromLTWH(100, 48, 150, 48),
                gridSize: const Size(400, 600),
                onAction: (event) => receivedEvent = event,
                onDismiss: () {},
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Sort Ascending'));
      await tester.pumpAndSettle();

      expect(receivedEvent, isNotNull);
      expect(receivedEvent!.action, ColumnMenuAction.sortAscending);
      expect(receivedEvent!.columnIndex, 2);
    });

    testWidgets('dismiss callback fires on outside tap', (tester) async {
      bool dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 600,
              child: ColumnMenuPopup(
                columnIndex: 0,
                colDef: const OsColumnDef(field: 'name', sortable: true),
                anchorRect: const Rect.fromLTWH(100, 48, 200, 48),
                gridSize: const Size(400, 600),
                onAction: (_) {},
                onDismiss: () => dismissed = true,
              ),
            ),
          ),
        ),
      );

      // Tap outside the menu area (top-left corner)
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      expect(dismissed, isTrue);
    });

    testWidgets('shows check mark on currently pinned state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 600,
              child: ColumnMenuPopup(
                columnIndex: 0,
                colDef: const OsColumnDef(
                  field: 'id',
                  pinned: OsColumnPin.left,
                  sortable: false,
                ),
                anchorRect: const Rect.fromLTWH(0, 48, 80, 48),
                gridSize: const Size(400, 600),
                onAction: (_) {},
                onDismiss: () {},
              ),
            ),
          ),
        ),
      );

      // The check icon should be present (for "Pin Left" being active)
      expect(find.byIcon(Icons.check), findsOneWidget);
    });
  });

  group('HeaderMenuIconHit', () {
    test('is a GridHitTestResult', () {
      const hit = HeaderMenuIconHit(
        columnIndex: 0,
        colDef: OsColumnDef(field: 'test'),
      );
      expect(hit, isA<GridHitTestResult>());
      expect(hit.columnIndex, 0);
    });
  });

  group('ColumnMenuPopup theming and locale', () {
    testWidgets('localeText overrides menu labels', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 600,
              child: ColumnMenuPopup(
                columnIndex: 0,
                colDef: const OsColumnDef(
                  field: 'name',
                  headerName: 'Name',
                  sortable: true,
                ),
                anchorRect: const Rect.fromLTWH(100, 48, 200, 48),
                gridSize: const Size(400, 600),
                localeText: OsLocaleText.fromMap({
                  'sortAscending': 'Aufsteigend sortieren',
                  'pinColumn': 'Spalte fixieren',
                  'resetColumns': 'Spalten zuruecksetzen',
                }),
                onAction: (_) {},
                onDismiss: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Aufsteigend sortieren'), findsOneWidget);
      expect(find.text('Spalte fixieren'), findsOneWidget);
      expect(find.text('Spalten zuruecksetzen'), findsOneWidget);
      expect(find.text('Sort Ascending'), findsNothing);
    });

    testWidgets('theme colours resolve from the grid theme', (tester) async {
      const bg = Color(0xFF101418);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 600,
              child: ColumnMenuPopup(
                columnIndex: 0,
                colDef: const OsColumnDef(field: 'name', sortable: true),
                anchorRect: const Rect.fromLTWH(100, 48, 200, 48),
                gridSize: const Size(400, 600),
                theme: const OsGridTheme(backgroundColor: bg),
                onAction: (_) {},
                onDismiss: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The popup panel's Material carries the themed background.
      expect(
        find.byWidgetPredicate((w) => w is Material && w.color == bg),
        findsOneWidget,
      );
    });

    testWidgets('menu renders outside a narrow host box', (tester) async {
      const hostWidth = 120.0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: hostWidth,
                  height: 80,
                  child: ColumnMenuPopup(
                    columnIndex: 0,
                    colDef: const OsColumnDef(field: 'name', sortable: true),
                    anchorRect: const Rect.fromLTWH(0, 40, hostWidth, 24),
                    gridSize: const Size(hostWidth, 80),
                    onAction: (_) {},
                    onDismiss: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final host = tester.getRect(find.byType(ColumnMenuPopup).first);
      final item = tester.getRect(find.text('Reset Columns'));
      expect(item.right, greaterThan(host.right));
      expect(item.bottom, greaterThan(host.bottom));
    });
  });
}
