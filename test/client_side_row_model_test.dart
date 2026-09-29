import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

void main() {
  group('ClientSideRowModel — postSortRows', () {
    testWidgets('postSortRows reorders rows after sort', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              columnDefs: [
                const OsColumnDef(field: 'name', headerName: 'Name'),
                const OsColumnDef(field: 'priority', headerName: 'Priority'),
              ],
              rowData: [
                {'name': 'Charlie', 'priority': false},
                {'name': 'Alice', 'priority': true},
                {'name': 'Bob', 'priority': false},
              ],
              initialSort: [
                const OsSortModel(
                  colId: 'name',
                  sort: OsSortDirection.ascending,
                ),
              ],
              postSortRows: (rows) {
                // Pin priority rows to the top
                final priority = rows
                    .where((r) => r['priority'] == true)
                    .toList();
                final rest = rows.where((r) => r['priority'] != true).toList();
                return [...priority, ...rest];
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Without postSortRows, the order would be Alice, Bob, Charlie.
      // With postSortRows, Alice (priority) is first, then the rest sorted.
      final result = <String>[];
      controller.forEachNodeAfterFilterAndSort((data, index) {
        result.add(data['name'] as String);
      });

      expect(result[0], 'Alice'); // Priority row first
      // The remaining rows maintain sort order
      expect(result[1], 'Bob');
      expect(result[2], 'Charlie');
    });

    testWidgets('postSortRows receives all rows when no sort active', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();

      List<Map<String, dynamic>>? receivedRows;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              columnDefs: [
                const OsColumnDef(field: 'name', headerName: 'Name'),
              ],
              rowData: [
                {'name': 'Charlie'},
                {'name': 'Alice'},
                {'name': 'Bob'},
              ],
              postSortRows: (rows) {
                receivedRows = rows;
                // Reverse the order
                return rows.reversed.toList();
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(receivedRows, isNotNull);
      expect(receivedRows!.length, 3);

      // Verify the processed data is reversed
      final result = <String>[];
      controller.forEachNodeAfterFilterAndSort((data, index) {
        result.add(data['name'] as String);
      });
      expect(result, ['Bob', 'Alice', 'Charlie']);
    });

    testWidgets('postSortRows works with filter', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              columnDefs: [
                const OsColumnDef(field: 'name', headerName: 'Name'),
              ],
              rowData: [
                {'name': 'Charlie'},
                {'name': 'Alice'},
                {'name': 'Bob'},
                {'name': 'Dave'},
              ],
              quickFilterText:
                  'a', // Matches Alice, Charlie, Dave (contains 'A')
              initialSort: [
                const OsSortModel(
                  colId: 'name',
                  sort: OsSortDirection.ascending,
                ),
              ],
              postSortRows: (rows) {
                // Put Dave first regardless of sort
                final dave = rows.where((r) => r['name'] == 'Dave').toList();
                final rest = rows.where((r) => r['name'] != 'Dave').toList();
                return [...dave, ...rest];
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final result = <String>[];
      controller.forEachNodeAfterFilterAndSort((data, index) {
        result.add(data['name'] as String);
      });

      // Quick filter 'a' matches: Alice, Charlie, Dave (all contain 'a')
      // After sort: Alice, Charlie, Dave
      // After postSortRows: Dave, Alice, Charlie
      expect(result, ['Dave', 'Alice', 'Charlie']);
    });

    testWidgets('postSortRows disables delta sort', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();

      int callCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              columnDefs: [
                const OsColumnDef(field: 'name', headerName: 'Name'),
              ],
              rowData: [
                {'name': 'Alice'},
                {'name': 'Bob'},
              ],
              getRowId: (data) => data['name'] as String,
              deltaSort: true,
              initialSort: [
                const OsSortModel(
                  colId: 'name',
                  sort: OsSortDirection.ascending,
                ),
              ],
              postSortRows: (rows) {
                callCount++;
                return rows;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final initialCallCount = callCount;

      // Apply a transaction — should still call postSortRows
      // (delta sort should be disabled when postSortRows is set)
      controller.applyTransaction(
        const OsRowTransaction(
          add: [
            {'name': 'Charlie'},
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(callCount, greaterThan(initialCallCount));
    });
  });

  group('ClientSideRowModel — refreshClientSideRowModel', () {
    testWidgets('refreshClientSideRowModel re-runs filter/sort', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();
      bool filterActive = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return OsGrid<Map<String, dynamic>>(
                  controller: controller,
                  columnDefs: [
                    const OsColumnDef(field: 'name', headerName: 'Name'),
                  ],
                  rowData: [
                    {'name': 'Alice'},
                    {'name': 'Bob'},
                    {'name': 'Charlie'},
                  ],
                  isExternalFilterPresent: () => filterActive,
                  doesExternalFilterPass: (row) =>
                      (row['name'] as String).startsWith('A'),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially no filter — all 3 rows visible
      final before = <String>[];
      controller.forEachNodeAfterFilter((data, index) {
        before.add(data['name'] as String);
      });
      expect(before.length, 3);

      // Activate the external filter and refresh
      filterActive = true;
      controller.refreshClientSideRowModel();
      await tester.pumpAndSettle();

      // After refresh — only Alice passes the filter
      final after = <String>[];
      controller.forEachNodeAfterFilter((data, index) {
        after.add(data['name'] as String);
      });
      expect(after, ['Alice']);
    });

    testWidgets('refreshClientSideRowModel re-applies sort', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              columnDefs: [
                const OsColumnDef(field: 'name', headerName: 'Name'),
              ],
              rowData: [
                {'name': 'Charlie'},
                {'name': 'Alice'},
                {'name': 'Bob'},
              ],
              initialSort: [
                const OsSortModel(
                  colId: 'name',
                  sort: OsSortDirection.ascending,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify initial sorted order
      final before = <String>[];
      controller.forEachNodeAfterFilterAndSort((data, index) {
        before.add(data['name'] as String);
      });
      expect(before, ['Alice', 'Bob', 'Charlie']);

      // Calling refreshClientSideRowModel should reapply the sort
      // (useful after external state changes affecting comparators)
      controller.refreshClientSideRowModel();
      await tester.pumpAndSettle();

      // Same result — data is still correctly sorted
      final after = <String>[];
      controller.forEachNodeAfterFilterAndSort((data, index) {
        after.add(data['name'] as String);
      });
      expect(after, ['Alice', 'Bob', 'Charlie']);
    });
  });

  group('ClientSideRowModel — forEachLeafNode', () {
    testWidgets('forEachLeafNode iterates all raw rows', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              columnDefs: [
                const OsColumnDef(field: 'name', headerName: 'Name'),
              ],
              rowData: [
                {'name': 'Alice'},
                {'name': 'Bob'},
                {'name': 'Charlie'},
              ],
              quickFilterText: 'ali', // Only Alice passes
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // forEachLeafNode should iterate ALL rows (not filtered)
      final allRows = <String>[];
      controller.forEachLeafNode((data, index) {
        allRows.add(data['name'] as String);
      });
      expect(allRows, ['Alice', 'Bob', 'Charlie']);

      // forEachNodeAfterFilter should only have filtered rows
      final filteredRows = <String>[];
      controller.forEachNodeAfterFilter((data, index) {
        filteredRows.add(data['name'] as String);
      });
      expect(filteredRows, ['Alice']);
    });

    testWidgets('forEachLeafNode is equivalent to forEachNode', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              columnDefs: [
                const OsColumnDef(field: 'name', headerName: 'Name'),
              ],
              rowData: [
                {'name': 'Alice'},
                {'name': 'Bob'},
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final leafNodes = <Map<String, dynamic>>[];
      controller.forEachLeafNode((data, index) {
        leafNodes.add(data);
      });

      final allNodes = <Map<String, dynamic>>[];
      controller.forEachNode((data, index) {
        allNodes.add(data);
      });

      expect(leafNodes, allNodes);
    });
  });

  group('ClientSideRowModel — isRowDataEmpty', () {
    testWidgets('isRowDataEmpty returns true when no data', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              columnDefs: [
                const OsColumnDef(field: 'name', headerName: 'Name'),
              ],
              rowData: const [],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(controller.isRowDataEmpty(), true);
    });

    testWidgets('isRowDataEmpty returns false when data present', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              columnDefs: [
                const OsColumnDef(field: 'name', headerName: 'Name'),
              ],
              rowData: [
                {'name': 'Alice'},
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(controller.isRowDataEmpty(), false);
    });
  });
}
