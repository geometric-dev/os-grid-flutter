import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

void main() {
  group('DeltaSortService — unit tests', () {
    late DeltaSortService<Map<String, dynamic>> deltaSortService;
    late SortService<Map<String, dynamic>> sortService;
    late List<OsColumnDef> columns;

    setUp(() {
      deltaSortService = DeltaSortService<Map<String, dynamic>>();
      sortService = SortService<Map<String, dynamic>>();
      sortService.setSortModel([
        const OsSortModel(colId: 'name', sort: OsSortDirection.ascending),
      ]);
      columns = [
        const OsColumnDef<Map<String, dynamic>>(
          field: 'name',
          headerName: 'Name',
        ),
      ];
    });

    test('returns null when no previous result exists', () {
      final allRows = [
        {'id': 1, 'name': 'Alice'},
        {'id': 2, 'name': 'Bob'},
        {'id': 3, 'name': 'Charlie'},
        {'id': 4, 'name': 'Diana'},
        {'id': 5, 'name': 'Eve'},
      ];

      final result = deltaSortService.tryDeltaSort(
        allRows: allRows,
        touchedRows: {allRows[0]},
        sortService: sortService,
        columns: columns,
      );

      expect(result, isNull);
    });

    test('returns null when too few rows', () {
      final allRows = [
        {'id': 1, 'name': 'Alice'},
        {'id': 2, 'name': 'Bob'},
        {'id': 3, 'name': 'Charlie'},
      ];

      deltaSortService.setPreviousResult(allRows);

      final result = deltaSortService.tryDeltaSort(
        allRows: allRows,
        touchedRows: {allRows[0]},
        sortService: sortService,
        columns: columns,
      );

      // 3 rows <= minDeltaSortRows (4), so returns null
      expect(result, isNull);
    });

    test('returns previous result when no rows touched and no removals', () {
      final sorted = [
        {'id': 1, 'name': 'Alice'},
        {'id': 2, 'name': 'Bob'},
        {'id': 3, 'name': 'Charlie'},
        {'id': 4, 'name': 'Diana'},
        {'id': 5, 'name': 'Eve'},
      ];

      deltaSortService.setPreviousResult(sorted);

      final result = deltaSortService.tryDeltaSort(
        allRows: sorted,
        touchedRows: {},
        sortService: sortService,
        columns: columns,
      );

      expect(result, sorted);
    });

    test('delta sorts touched rows and merges correctly', () {
      // Previous sorted result: Alice, Bob, Charlie, Diana, Eve
      final alice = {'id': 1, 'name': 'Alice'};
      final bob = {'id': 2, 'name': 'Bob'};
      final charlie = {'id': 3, 'name': 'Charlie'};
      final diana = {'id': 4, 'name': 'Diana'};
      final eve = {'id': 5, 'name': 'Eve'};

      final previousSorted = [alice, bob, charlie, diana, eve];
      deltaSortService.setPreviousResult(previousSorted);

      // Add a new row "Frank" — should be inserted between Eve and end
      final frank = {'id': 6, 'name': 'Frank'};
      final allRows = [alice, bob, charlie, diana, eve, frank];

      final result = deltaSortService.tryDeltaSort(
        allRows: allRows,
        touchedRows: {frank},
        sortService: sortService,
        columns: columns,
      );

      expect(result, isNotNull);
      expect(result!.length, 6);
      // Frank should be after Eve in ascending name sort
      final names = result.map((r) => r['name'] as String).toList();
      expect(names, ['Alice', 'Bob', 'Charlie', 'Diana', 'Eve', 'Frank']);
    });

    test('delta sort inserts at correct position', () {
      final alice = {'id': 1, 'name': 'Alice'};
      final charlie = {'id': 3, 'name': 'Charlie'};
      final diana = {'id': 4, 'name': 'Diana'};
      final eve = {'id': 5, 'name': 'Eve'};
      final frank = {'id': 6, 'name': 'Frank'};

      final previousSorted = [alice, charlie, diana, eve, frank];
      deltaSortService.setPreviousResult(previousSorted);

      // Add "Bob" — should be inserted between Alice and Charlie
      final bob = {'id': 2, 'name': 'Bob'};
      final allRows = [alice, bob, charlie, diana, eve, frank];

      final result = deltaSortService.tryDeltaSort(
        allRows: allRows,
        touchedRows: {bob},
        sortService: sortService,
        columns: columns,
      );

      expect(result, isNotNull);
      final names = result!.map((r) => r['name'] as String).toList();
      expect(names, ['Alice', 'Bob', 'Charlie', 'Diana', 'Eve', 'Frank']);
    });

    test('invalidate clears previous result', () {
      final data = [
        {'id': 1, 'name': 'Alice'},
        {'id': 2, 'name': 'Bob'},
        {'id': 3, 'name': 'Charlie'},
        {'id': 4, 'name': 'Diana'},
        {'id': 5, 'name': 'Eve'},
      ];

      deltaSortService.setPreviousResult(data);
      expect(deltaSortService.previousSortedResult, isNotNull);

      deltaSortService.invalidate();
      expect(deltaSortService.previousSortedResult, isNull);
    });

    test('returns null when all rows are touched', () {
      final allRows = [
        {'id': 1, 'name': 'Eve'},
        {'id': 2, 'name': 'Diana'},
        {'id': 3, 'name': 'Charlie'},
        {'id': 4, 'name': 'Bob'},
        {'id': 5, 'name': 'Alice'},
      ];

      deltaSortService.setPreviousResult(allRows);

      final result = deltaSortService.tryDeltaSort(
        allRows: allRows,
        touchedRows: allRows.toSet(),
        sortService: sortService,
        columns: columns,
      );

      // All rows touched — falls back to full sort
      expect(result, isNull);
    });

    test('handles removals from previous result', () {
      final alice = {'id': 1, 'name': 'Alice'};
      final bob = {'id': 2, 'name': 'Bob'};
      final charlie = {'id': 3, 'name': 'Charlie'};
      final diana = {'id': 4, 'name': 'Diana'};
      final eve = {'id': 5, 'name': 'Eve'};
      final frank = {'id': 6, 'name': 'Frank'};

      deltaSortService.setPreviousResult([
        alice,
        bob,
        charlie,
        diana,
        eve,
        frank,
      ]);

      // Remove Bob — no touched rows, just fewer rows (5 rows > minDeltaSortRows)
      final allRows = [alice, charlie, diana, eve, frank];

      final result = deltaSortService.tryDeltaSort(
        allRows: allRows,
        touchedRows: {},
        sortService: sortService,
        columns: columns,
      );

      expect(result, isNotNull);
      expect(result!.length, 5);
      final names = result.map((r) => r['name'] as String).toList();
      expect(names, ['Alice', 'Charlie', 'Diana', 'Eve', 'Frank']);
    });
  });

  group('Delta sort — widget integration', () {
    testWidgets('deltaSort option enables incremental sorting', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              getRowId: (data) => data['id'].toString(),
              deltaSort: true,
              initialSort: [
                const OsSortModel(
                  colId: 'name',
                  sort: OsSortDirection.ascending,
                ),
              ],
              columnDefs: [
                const OsColumnDef(field: 'name', headerName: 'Name'),
              ],
              rowData: [
                {'id': 1, 'name': 'Alice'},
                {'id': 2, 'name': 'Charlie'},
                {'id': 3, 'name': 'Eve'},
                {'id': 4, 'name': 'George'},
                {'id': 5, 'name': 'Ivan'},
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Apply a transaction adding a row
      controller.applyTransaction(
        const OsRowTransaction(
          add: [
            {'id': 6, 'name': 'Bob'},
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Verify the data is correctly sorted (Bob between Alice and Charlie)
      final rows = <String>[];
      controller.forEachNodeAfterFilterAndSort((data, index) {
        rows.add(data['name'] as String);
      });

      expect(rows, ['Alice', 'Bob', 'Charlie', 'Eve', 'George', 'Ivan']);
    });

    testWidgets('deltaSort with update repositions row correctly', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              getRowId: (data) => data['id'].toString(),
              deltaSort: true,
              initialSort: [
                const OsSortModel(
                  colId: 'name',
                  sort: OsSortDirection.ascending,
                ),
              ],
              columnDefs: [
                const OsColumnDef(field: 'name', headerName: 'Name'),
              ],
              rowData: [
                {'id': 1, 'name': 'Alice'},
                {'id': 2, 'name': 'Bob'},
                {'id': 3, 'name': 'Charlie'},
                {'id': 4, 'name': 'Diana'},
                {'id': 5, 'name': 'Eve'},
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Update Alice to "Zara" — should move to end
      controller.applyTransaction(
        const OsRowTransaction(
          update: [
            {'id': 1, 'name': 'Zara'},
          ],
        ),
      );
      await tester.pumpAndSettle();

      final rows = <String>[];
      controller.forEachNodeAfterFilterAndSort((data, index) {
        rows.add(data['name'] as String);
      });

      expect(rows, ['Bob', 'Charlie', 'Diana', 'Eve', 'Zara']);
    });

    testWidgets('sort model change invalidates delta sort cache', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              getRowId: (data) => data['id'].toString(),
              deltaSort: true,
              initialSort: [
                const OsSortModel(
                  colId: 'name',
                  sort: OsSortDirection.ascending,
                ),
              ],
              columnDefs: [
                const OsColumnDef(field: 'name', headerName: 'Name'),
                const OsColumnDef(field: 'age', headerName: 'Age'),
              ],
              rowData: [
                {'id': 1, 'name': 'Alice', 'age': 30},
                {'id': 2, 'name': 'Bob', 'age': 25},
                {'id': 3, 'name': 'Charlie', 'age': 35},
                {'id': 4, 'name': 'Diana', 'age': 28},
                {'id': 5, 'name': 'Eve', 'age': 22},
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Change sort model — should still work correctly
      controller.setSortModel([
        const OsSortModel(colId: 'name', sort: OsSortDirection.descending),
      ]);
      await tester.pumpAndSettle();

      final rows = <String>[];
      controller.forEachNodeAfterFilterAndSort((data, index) {
        rows.add(data['name'] as String);
      });

      expect(rows, ['Eve', 'Diana', 'Charlie', 'Bob', 'Alice']);
    });
  });
}
