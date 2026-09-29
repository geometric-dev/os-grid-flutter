import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

void main() {
  group('Floating filter — functional filtering', () {
    testWidgets('tapping floating filter cell shows text input overlay', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SizedBox(
            width: 600,
            height: 400,
            child: OsGrid(
              floatingFilter: true,
              floatingFilterHeight: 32.0,
              headerHeight: 48.0,
              rowHeight: 42.0,
              columnDefs: [
                OsColumnDef(
                  field: 'name',
                  headerName: 'Name',
                  filter: OsTextFilter(),
                  width: 200,
                ),
                OsColumnDef(
                  field: 'age',
                  headerName: 'Age',
                  filter: OsNumberFilter(),
                  width: 200,
                ),
              ],
              rowData: [
                {'name': 'Alice', 'age': 32},
                {'name': 'Bob', 'age': 28},
                {'name': 'Charlie', 'age': 45},
              ],
            ),
          ),
        ),
      );

      // Tap in the floating filter area for the 'name' column
      // Header is at y=0..48, floating filter is at y=48..80
      final gridFinder = find.byType(VirtualisedGrid);
      final gridBox = tester.renderObject(gridFinder) as RenderBox;
      final gridTopLeft = gridBox.localToGlobal(Offset.zero);

      // Tap in the middle of the floating filter row, first column
      await tester.tapAt(gridTopLeft + const Offset(100, 64));
      await tester.pumpAndSettle();

      // An EditableText overlay should appear for the floating filter
      // The grid uses a Stack with EditableText for the overlay
      expect(find.byType(EditableText), findsOneWidget);
    });

    testWidgets('typing in floating filter filters rows', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SizedBox(
            width: 600,
            height: 400,
            child: OsGrid(
              floatingFilter: true,
              floatingFilterHeight: 32.0,
              headerHeight: 48.0,
              rowHeight: 42.0,
              columnDefs: [
                OsColumnDef(
                  field: 'name',
                  headerName: 'Name',
                  filter: OsTextFilter(),
                  width: 200,
                ),
              ],
              rowData: [
                {'name': 'Alice'},
                {'name': 'Bob'},
                {'name': 'Charlie'},
                {'name': 'Alicia'},
              ],
            ),
          ),
        ),
      );

      // Tap the floating filter cell
      final gridFinder = find.byType(VirtualisedGrid);
      final gridBox = tester.renderObject(gridFinder) as RenderBox;
      final gridTopLeft = gridBox.localToGlobal(Offset.zero);

      await tester.tapAt(gridTopLeft + const Offset(100, 64));
      await tester.pumpAndSettle();

      // Type 'ali' to filter
      await tester.enterText(find.byType(EditableText), 'ali');
      await tester.pumpAndSettle();

      // The grid should now show only rows containing 'ali' (Alice, Alicia)
      // We verify by checking the VirtualisedGrid's rowData prop
      final virtualisedGrid = tester.widget<VirtualisedGrid>(
        find.byType(VirtualisedGrid),
      );
      expect(virtualisedGrid.rowData.length, 2);
      expect(virtualisedGrid.rowData[0]['name'], 'Alice');
      expect(virtualisedGrid.rowData[1]['name'], 'Alicia');
    });

    testWidgets('multiple column filters combine with AND logic', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SizedBox(
            width: 600,
            height: 400,
            child: OsGrid(
              floatingFilter: true,
              floatingFilterHeight: 32.0,
              headerHeight: 48.0,
              rowHeight: 42.0,
              columnDefs: [
                OsColumnDef(
                  field: 'name',
                  headerName: 'Name',
                  filter: OsTextFilter(),
                  width: 200,
                ),
                OsColumnDef(
                  field: 'city',
                  headerName: 'City',
                  filter: OsTextFilter(),
                  width: 200,
                ),
              ],
              rowData: [
                {'name': 'Alice', 'city': 'London'},
                {'name': 'Bob', 'city': 'London'},
                {'name': 'Alice', 'city': 'Paris'},
                {'name': 'Charlie', 'city': 'Berlin'},
              ],
            ),
          ),
        ),
      );

      final gridFinder = find.byType(VirtualisedGrid);
      final gridBox = tester.renderObject(gridFinder) as RenderBox;
      final gridTopLeft = gridBox.localToGlobal(Offset.zero);

      // Filter by name = 'alice'
      await tester.tapAt(gridTopLeft + const Offset(100, 64));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText), 'alice');
      await tester.pumpAndSettle();

      // Commit by tapping elsewhere (the second column's filter)
      await tester.tapAt(gridTopLeft + const Offset(300, 64));
      await tester.pumpAndSettle();

      // Now filter by city = 'london'
      await tester.enterText(find.byType(EditableText).last, 'london');
      await tester.pumpAndSettle();

      // Should only show Alice in London (AND logic)
      final virtualisedGrid = tester.widget<VirtualisedGrid>(
        find.byType(VirtualisedGrid),
      );
      expect(virtualisedGrid.rowData.length, 1);
      expect(virtualisedGrid.rowData[0]['name'], 'Alice');
      expect(virtualisedGrid.rowData[0]['city'], 'London');
    });

    testWidgets('column filter works alongside quick filter', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SizedBox(
            width: 600,
            height: 400,
            child: OsGrid(
              floatingFilter: true,
              floatingFilterHeight: 32.0,
              headerHeight: 48.0,
              rowHeight: 42.0,
              quickFilterText: 'lon',
              columnDefs: [
                OsColumnDef(
                  field: 'name',
                  headerName: 'Name',
                  filter: OsTextFilter(),
                  width: 200,
                ),
                OsColumnDef(
                  field: 'city',
                  headerName: 'City',
                  filter: OsTextFilter(),
                  width: 200,
                ),
              ],
              rowData: [
                {'name': 'Alice', 'city': 'London'},
                {'name': 'Bob', 'city': 'London'},
                {'name': 'Charlie', 'city': 'Berlin'},
              ],
            ),
          ),
        ),
      );

      // Quick filter 'lon' already filters to Alice+Bob (London rows)
      // Now add a column filter on name = 'bob'
      final gridFinder = find.byType(VirtualisedGrid);
      final gridBox = tester.renderObject(gridFinder) as RenderBox;
      final gridTopLeft = gridBox.localToGlobal(Offset.zero);

      await tester.tapAt(gridTopLeft + const Offset(100, 64));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText), 'bob');
      await tester.pumpAndSettle();

      // Should show only Bob (passes both quick filter 'lon' via city and column filter 'bob' via name)
      final virtualisedGrid = tester.widget<VirtualisedGrid>(
        find.byType(VirtualisedGrid),
      );
      expect(virtualisedGrid.rowData.length, 1);
      expect(virtualisedGrid.rowData[0]['name'], 'Bob');
    });

    testWidgets('onFilterChanged event fires with column filter model', (
      tester,
    ) async {
      OsFilterChangedEvent? lastEvent;

      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 600,
            height: 400,
            child: OsGrid(
              floatingFilter: true,
              floatingFilterHeight: 32.0,
              headerHeight: 48.0,
              rowHeight: 42.0,
              onFilterChanged: (event) => lastEvent = event,
              columnDefs: [
                const OsColumnDef(
                  field: 'name',
                  headerName: 'Name',
                  filter: OsTextFilter(),
                  width: 200,
                ),
              ],
              rowData: [
                {'name': 'Alice'},
                {'name': 'Bob'},
              ],
            ),
          ),
        ),
      );

      final gridFinder = find.byType(VirtualisedGrid);
      final gridBox = tester.renderObject(gridFinder) as RenderBox;
      final gridTopLeft = gridBox.localToGlobal(Offset.zero);

      // Tap and type in the floating filter
      await tester.tapAt(gridTopLeft + const Offset(100, 64));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText), 'ali');
      await tester.pumpAndSettle();

      // Event should have been fired
      expect(lastEvent, isNotNull);
      expect(lastEvent!.filterModel.containsKey('name'), isTrue);
      expect((lastEvent!.filterModel['name'] as Map)['filter'], 'ali');
    });

    testWidgets('number filter with valid number filters by equality', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SizedBox(
            width: 600,
            height: 400,
            child: OsGrid(
              floatingFilter: true,
              floatingFilterHeight: 32.0,
              headerHeight: 48.0,
              rowHeight: 42.0,
              columnDefs: [
                OsColumnDef(field: 'name', headerName: 'Name', width: 200),
                OsColumnDef(
                  field: 'age',
                  headerName: 'Age',
                  filter: OsNumberFilter(),
                  width: 200,
                ),
              ],
              rowData: [
                {'name': 'Alice', 'age': 32},
                {'name': 'Bob', 'age': 28},
                {'name': 'Charlie', 'age': 32},
              ],
            ),
          ),
        ),
      );

      final gridFinder = find.byType(VirtualisedGrid);
      final gridBox = tester.renderObject(gridFinder) as RenderBox;
      final gridTopLeft = gridBox.localToGlobal(Offset.zero);

      // Tap the age column's floating filter (second column, x=200..400)
      await tester.tapAt(gridTopLeft + const Offset(300, 64));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText), '32');
      await tester.pumpAndSettle();

      // Should show Alice and Charlie (age == 32)
      final virtualisedGrid = tester.widget<VirtualisedGrid>(
        find.byType(VirtualisedGrid),
      );
      expect(virtualisedGrid.rowData.length, 2);
      expect(virtualisedGrid.rowData[0]['name'], 'Alice');
      expect(virtualisedGrid.rowData[1]['name'], 'Charlie');
    });

    testWidgets('clearing filter text shows all rows again', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SizedBox(
            width: 600,
            height: 400,
            child: OsGrid(
              floatingFilter: true,
              floatingFilterHeight: 32.0,
              headerHeight: 48.0,
              rowHeight: 42.0,
              columnDefs: [
                OsColumnDef(
                  field: 'name',
                  headerName: 'Name',
                  filter: OsTextFilter(),
                  width: 200,
                ),
              ],
              rowData: [
                {'name': 'Alice'},
                {'name': 'Bob'},
                {'name': 'Charlie'},
              ],
            ),
          ),
        ),
      );

      final gridFinder = find.byType(VirtualisedGrid);
      final gridBox = tester.renderObject(gridFinder) as RenderBox;
      final gridTopLeft = gridBox.localToGlobal(Offset.zero);

      // Filter to 'bob'
      await tester.tapAt(gridTopLeft + const Offset(100, 64));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(find.byType(EditableText), 'bob');
      await tester.pumpAndSettle();

      var virtualisedGrid = tester.widget<VirtualisedGrid>(
        find.byType(VirtualisedGrid),
      );
      expect(virtualisedGrid.rowData.length, 1);

      // Clear the filter
      await tester.enterText(find.byType(EditableText), '');
      await tester.pumpAndSettle();

      virtualisedGrid = tester.widget<VirtualisedGrid>(
        find.byType(VirtualisedGrid),
      );
      expect(virtualisedGrid.rowData.length, 3);
    });

    testWidgets('text filter is case-insensitive by default', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SizedBox(
            width: 600,
            height: 400,
            child: OsGrid(
              floatingFilter: true,
              floatingFilterHeight: 32.0,
              headerHeight: 48.0,
              rowHeight: 42.0,
              columnDefs: [
                OsColumnDef(
                  field: 'name',
                  headerName: 'Name',
                  filter: OsTextFilter(),
                  width: 200,
                ),
              ],
              rowData: [
                {'name': 'Alice'},
                {'name': 'ALICE'},
                {'name': 'Bob'},
              ],
            ),
          ),
        ),
      );

      final gridFinder = find.byType(VirtualisedGrid);
      final gridBox = tester.renderObject(gridFinder) as RenderBox;
      final gridTopLeft = gridBox.localToGlobal(Offset.zero);

      await tester.tapAt(gridTopLeft + const Offset(100, 64));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText), 'ALICE');
      await tester.pumpAndSettle();

      final virtualisedGrid = tester.widget<VirtualisedGrid>(
        find.byType(VirtualisedGrid),
      );
      expect(virtualisedGrid.rowData.length, 2);
    });

    testWidgets('null cell values are filtered out', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SizedBox(
            width: 600,
            height: 400,
            child: OsGrid(
              floatingFilter: true,
              floatingFilterHeight: 32.0,
              headerHeight: 48.0,
              rowHeight: 42.0,
              columnDefs: [
                OsColumnDef(
                  field: 'name',
                  headerName: 'Name',
                  filter: OsTextFilter(),
                  width: 200,
                ),
              ],
              rowData: [
                {'name': 'Alice'},
                {'name': null},
                {'name': 'Bob'},
              ],
            ),
          ),
        ),
      );

      final gridFinder = find.byType(VirtualisedGrid);
      final gridBox = tester.renderObject(gridFinder) as RenderBox;
      final gridTopLeft = gridBox.localToGlobal(Offset.zero);

      await tester.tapAt(gridTopLeft + const Offset(100, 64));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText), 'a');
      await tester.pumpAndSettle();

      // Only 'Alice' should match — null row is excluded
      final virtualisedGrid = tester.widget<VirtualisedGrid>(
        find.byType(VirtualisedGrid),
      );
      expect(virtualisedGrid.rowData.length, 1);
      expect(virtualisedGrid.rowData[0]['name'], 'Alice');
    });

    testWidgets('columns without filter do not show input overlay', (
      tester,
    ) async {
      bool filterTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 600,
            height: 400,
            child: OsGrid(
              floatingFilter: true,
              floatingFilterHeight: 32.0,
              headerHeight: 48.0,
              rowHeight: 42.0,
              onFilterChanged: (_) => filterTapped = true,
              columnDefs: [
                const OsColumnDef(
                  field: 'name',
                  headerName: 'Name',
                  // No filter configured
                  width: 200,
                ),
              ],
              rowData: [
                {'name': 'Alice'},
              ],
            ),
          ),
        ),
      );

      final gridFinder = find.byType(VirtualisedGrid);
      final gridBox = tester.renderObject(gridFinder) as RenderBox;
      final gridTopLeft = gridBox.localToGlobal(Offset.zero);

      // Tap in the floating filter area
      await tester.tapAt(gridTopLeft + const Offset(100, 64));
      await tester.pumpAndSettle();

      // No EditableText should appear (no filter configured)
      expect(find.byType(EditableText), findsNothing);
      expect(filterTapped, isFalse);
    });

    testWidgets('filter text persists in painted cells after commit', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SizedBox(
            width: 600,
            height: 400,
            child: OsGrid(
              floatingFilter: true,
              floatingFilterHeight: 32.0,
              headerHeight: 48.0,
              rowHeight: 42.0,
              columnDefs: [
                OsColumnDef(
                  field: 'name',
                  headerName: 'Name',
                  filter: OsTextFilter(),
                  width: 200,
                ),
              ],
              rowData: [
                {'name': 'Alice'},
                {'name': 'Bob'},
              ],
            ),
          ),
        ),
      );

      final gridFinder = find.byType(VirtualisedGrid);
      final gridBox = tester.renderObject(gridFinder) as RenderBox;
      final gridTopLeft = gridBox.localToGlobal(Offset.zero);

      // Type a filter
      await tester.tapAt(gridTopLeft + const Offset(100, 64));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText), 'ali');
      await tester.pumpAndSettle();

      // Commit by tapping elsewhere (data area)
      await tester.tapAt(gridTopLeft + const Offset(100, 150));
      await tester.pumpAndSettle();

      // The VirtualisedGrid should have floatingFilterTexts set
      final virtualisedGrid = tester.widget<VirtualisedGrid>(
        find.byType(VirtualisedGrid),
      );
      expect(virtualisedGrid.floatingFilterTexts, isNotNull);
      expect(virtualisedGrid.floatingFilterTexts!['name'], 'ali');
    });

    testWidgets('number filter with greaterThan option', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SizedBox(
            width: 600,
            height: 400,
            child: OsGrid(
              floatingFilter: true,
              floatingFilterHeight: 32.0,
              headerHeight: 48.0,
              rowHeight: 42.0,
              columnDefs: [
                OsColumnDef(
                  field: 'age',
                  headerName: 'Age',
                  filter: OsNumberFilter(
                    defaultOption: OsNumberFilterOption.greaterThan,
                  ),
                  width: 200,
                ),
              ],
              rowData: [
                {'age': 20},
                {'age': 30},
                {'age': 40},
                {'age': 50},
              ],
            ),
          ),
        ),
      );

      final gridFinder = find.byType(VirtualisedGrid);
      final gridBox = tester.renderObject(gridFinder) as RenderBox;
      final gridTopLeft = gridBox.localToGlobal(Offset.zero);

      await tester.tapAt(gridTopLeft + const Offset(100, 64));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText), '30');
      await tester.pumpAndSettle();

      // Should show rows where age > 30 (40, 50)
      final virtualisedGrid = tester.widget<VirtualisedGrid>(
        find.byType(VirtualisedGrid),
      );
      expect(virtualisedGrid.rowData.length, 2);
      expect(virtualisedGrid.rowData[0]['age'], 40);
      expect(virtualisedGrid.rowData[1]['age'], 50);
    });

    testWidgets('text filter with startsWith option', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SizedBox(
            width: 600,
            height: 400,
            child: OsGrid(
              floatingFilter: true,
              floatingFilterHeight: 32.0,
              headerHeight: 48.0,
              rowHeight: 42.0,
              columnDefs: [
                OsColumnDef(
                  field: 'name',
                  headerName: 'Name',
                  filter: OsTextFilter(
                    defaultOption: OsTextFilterOption.startsWith,
                  ),
                  width: 200,
                ),
              ],
              rowData: [
                {'name': 'Alice'},
                {'name': 'Alicia'},
                {'name': 'Bob'},
                {'name': 'Balice'},
              ],
            ),
          ),
        ),
      );

      final gridFinder = find.byType(VirtualisedGrid);
      final gridBox = tester.renderObject(gridFinder) as RenderBox;
      final gridTopLeft = gridBox.localToGlobal(Offset.zero);

      await tester.tapAt(gridTopLeft + const Offset(100, 64));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText), 'ali');
      await tester.pumpAndSettle();

      // startsWith 'ali' → Alice, Alicia (not Balice)
      final virtualisedGrid = tester.widget<VirtualisedGrid>(
        find.byType(VirtualisedGrid),
      );
      expect(virtualisedGrid.rowData.length, 2);
      expect(virtualisedGrid.rowData[0]['name'], 'Alice');
      expect(virtualisedGrid.rowData[1]['name'], 'Alicia');
    });

    testWidgets('controller stream receives filter changed events', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();
      final events = <OsFilterChangedEvent>[];
      controller.onFilterChanged.listen(events.add);

      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 600,
            height: 400,
            child: OsGrid<Map<String, dynamic>>(
              controller: controller,
              floatingFilter: true,
              floatingFilterHeight: 32.0,
              headerHeight: 48.0,
              rowHeight: 42.0,
              columnDefs: [
                const OsColumnDef(
                  field: 'name',
                  headerName: 'Name',
                  filter: OsTextFilter(),
                  width: 200,
                ),
              ],
              rowData: [
                {'name': 'Alice'},
                {'name': 'Bob'},
              ],
            ),
          ),
        ),
      );

      final gridFinder = find.byType(VirtualisedGrid);
      final gridBox = tester.renderObject(gridFinder) as RenderBox;
      final gridTopLeft = gridBox.localToGlobal(Offset.zero);

      await tester.tapAt(gridTopLeft + const Offset(100, 64));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText), 'a');
      await tester.pumpAndSettle();

      // Stream should have received at least one event
      expect(events, isNotEmpty);
      expect(events.last.filterModel.containsKey('name'), isTrue);

      controller.dispose();
    });
  });
}
