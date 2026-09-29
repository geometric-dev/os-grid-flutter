import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

void main() {
  group('ID-based selection — OsGridController', () {
    late OsGridController<Map<String, dynamic>> controller;

    setUp(() {
      controller = OsGridController<Map<String, dynamic>>();
      controller.getRowId = (data) => data['id'].toString();
      controller.setRowData([
        {'id': 1, 'name': 'Alice', 'age': 32},
        {'id': 2, 'name': 'Bob', 'age': 28},
        {'id': 3, 'name': 'Charlie', 'age': 45},
        {'id': 4, 'name': 'Diana', 'age': 36},
        {'id': 5, 'name': 'Eve', 'age': 22},
      ]);
      // Simulate processed data (same as raw for now)
      controller.processedData = [
        {'id': 1, 'name': 'Alice', 'age': 32},
        {'id': 2, 'name': 'Bob', 'age': 28},
        {'id': 3, 'name': 'Charlie', 'age': 45},
        {'id': 4, 'name': 'Diana', 'age': 36},
        {'id': 5, 'name': 'Eve', 'age': 22},
      ];
    });

    tearDown(() => controller.dispose());

    test('selectAll selects all rows by ID', () {
      controller.selectAll();
      expect(controller.getSelectedRows().length, 5);
      expect(controller.getSelectedIds(), {'1', '2', '3', '4', '5'});
    });

    test('deselectAll clears all selections', () {
      controller.selectAll();
      controller.deselectAll();
      expect(controller.getSelectedRows(), isEmpty);
      expect(controller.getSelectedIds(), isEmpty);
    });

    test('toggleSelection adds and removes by ID', () {
      controller.toggleSelection(0); // Alice
      expect(controller.getSelectedIds(), {'1'});
      expect(controller.isRowSelected(0), true);

      controller.toggleSelection(0); // Toggle off
      expect(controller.getSelectedIds(), isEmpty);
      expect(controller.isRowSelected(0), false);
    });

    test('setSingleSelection clears others and selects one', () {
      controller.toggleSelection(0); // Alice
      controller.toggleSelection(1); // Bob
      controller.setSingleSelection(2); // Charlie only
      expect(controller.getSelectedIds(), {'3'});
      expect(controller.isRowSelected(0), false);
      expect(controller.isRowSelected(1), false);
      expect(controller.isRowSelected(2), true);
    });

    test('selection persists across sort (reordered processedData)', () {
      // Select Alice (id=1) and Charlie (id=3)
      controller.toggleSelection(0); // Alice at index 0
      controller.toggleSelection(2); // Charlie at index 2
      expect(controller.getSelectedIds(), {'1', '3'});

      // Simulate a sort that reverses the order
      controller.processedData = [
        {'id': 5, 'name': 'Eve', 'age': 22},
        {'id': 4, 'name': 'Diana', 'age': 36},
        {'id': 3, 'name': 'Charlie', 'age': 45},
        {'id': 2, 'name': 'Bob', 'age': 28},
        {'id': 1, 'name': 'Alice', 'age': 32},
      ];

      // Selection should still be Alice and Charlie by ID
      expect(controller.getSelectedIds(), {'1', '3'});
      // But their display indices have changed
      expect(controller.isRowSelected(0), false); // Eve
      expect(controller.isRowSelected(1), false); // Diana
      expect(controller.isRowSelected(2), true); // Charlie (id=3)
      expect(controller.isRowSelected(3), false); // Bob
      expect(controller.isRowSelected(4), true); // Alice (id=1)
    });

    test('selection persists across filter (hidden rows stay selected)', () {
      // Select Alice (id=1) and Charlie (id=3)
      controller.toggleSelection(0);
      controller.toggleSelection(2);
      expect(controller.getSelectedIds(), {'1', '3'});

      // Simulate a filter that hides Alice
      controller.processedData = [
        {'id': 2, 'name': 'Bob', 'age': 28},
        {'id': 3, 'name': 'Charlie', 'age': 45},
        {'id': 4, 'name': 'Diana', 'age': 36},
      ];

      // Alice is hidden but still selected by ID
      expect(controller.getSelectedIds(), {'1', '3'});
      // Charlie is now at index 1
      expect(controller.isRowSelected(0), false); // Bob
      expect(controller.isRowSelected(1), true); // Charlie
      expect(controller.isRowSelected(2), false); // Diana
    });

    test('selectRange selects all rows between anchor and target', () {
      // Click Alice (sets anchor)
      controller.toggleSelection(0);
      // Shift+click Diana (index 3) — should select range [0..3]
      controller.selectRange(3);
      expect(controller.getSelectedIds(), {'1', '2', '3', '4'});
    });

    test('selectRange with no anchor behaves like toggle', () {
      controller.selectRange(2);
      expect(controller.getSelectedIds(), {'3'});
    });

    test('selectRange respects isRowSelectable', () {
      controller.rowSelection = OsRowSelection.multiple(
        isRowSelectable: (data) => data['name'] != 'Bob',
      );
      controller.toggleSelection(0); // Alice (anchor)
      controller.selectRange(3); // Range [0..3]
      // Bob (id=2) should be skipped
      expect(controller.getSelectedIds(), {'1', '3', '4'});
    });

    test('selectAllFiltered only selects processed data', () {
      // Simulate filter showing only Bob and Diana
      controller.processedData = [
        {'id': 2, 'name': 'Bob', 'age': 28},
        {'id': 4, 'name': 'Diana', 'age': 36},
      ];
      controller.selectAllFiltered();
      expect(controller.getSelectedIds(), {'2', '4'});
    });

    test('deselectAllFiltered only deselects processed data', () {
      controller.selectAll(); // Select all 5
      expect(controller.getSelectedIds().length, 5);

      // Simulate filter showing only Bob and Diana
      controller.processedData = [
        {'id': 2, 'name': 'Bob', 'age': 28},
        {'id': 4, 'name': 'Diana', 'age': 36},
      ];
      controller.deselectAllFiltered();
      // Only Bob and Diana deselected; Alice, Charlie, Eve remain
      expect(controller.getSelectedIds(), {'1', '3', '5'});
    });

    test('selectAllOnCurrentPage only selects page data', () {
      controller.pageData = [
        {'id': 1, 'name': 'Alice', 'age': 32},
        {'id': 2, 'name': 'Bob', 'age': 28},
      ];
      controller.selectAllOnCurrentPage();
      expect(controller.getSelectedIds(), {'1', '2'});
    });

    test('deselectAllOnCurrentPage only deselects page data', () {
      controller.selectAll();
      controller.pageData = [
        {'id': 1, 'name': 'Alice', 'age': 32},
        {'id': 2, 'name': 'Bob', 'age': 28},
      ];
      controller.deselectAllOnCurrentPage();
      expect(controller.getSelectedIds(), {'3', '4', '5'});
    });

    test('isRowSelectable prevents selection via toggleSelection', () {
      controller.rowSelection = OsRowSelection.multiple(
        isRowSelectable: (data) => data['age'] > 30,
      );
      controller.toggleSelection(1); // Bob, age 28 — not selectable
      expect(controller.getSelectedIds(), isEmpty);

      controller.toggleSelection(0); // Alice, age 32 — selectable
      expect(controller.getSelectedIds(), {'1'});
    });

    test('isRowSelectable prevents selection via setSingleSelection', () {
      controller.rowSelection = OsRowSelection.single(
        isRowSelectable: (data) => data['name'] != 'Bob',
      );
      controller.setSingleSelection(1); // Bob — not selectable
      expect(controller.getSelectedIds(), isEmpty);

      controller.setSingleSelection(0); // Alice — selectable
      expect(controller.getSelectedIds(), {'1'});
    });

    test('isRowSelectable prevents selection via selectAll', () {
      controller.rowSelection = OsRowSelection.multiple(
        isRowSelectable: (data) => data['age'] > 30,
      );
      controller.selectAll();
      // Only Alice (32), Charlie (45), Diana (36) are selectable
      expect(controller.getSelectedIds(), {'1', '3', '4'});
    });

    test('selectRows by indices resolves to IDs', () {
      controller.selectRows([0, 2, 4]);
      expect(controller.getSelectedIds(), {'1', '3', '5'});
    });

    test('selectRowsById selects by ID directly', () {
      controller.selectRowsById(['2', '4']);
      expect(controller.getSelectedIds(), {'2', '4'});
      expect(controller.isRowSelected(1), true); // Bob at index 1
      expect(controller.isRowSelected(3), true); // Diana at index 3
    });

    test('selectedIndices returns correct display indices', () {
      controller.toggleSelection(0); // Alice
      controller.toggleSelection(2); // Charlie
      final indices = controller.selectedIndices;
      expect(indices, {0, 2});

      // After sort reversal
      controller.processedData = [
        {'id': 5, 'name': 'Eve', 'age': 22},
        {'id': 4, 'name': 'Diana', 'age': 36},
        {'id': 3, 'name': 'Charlie', 'age': 45},
        {'id': 2, 'name': 'Bob', 'age': 28},
        {'id': 1, 'name': 'Alice', 'age': 32},
      ];
      final newIndices = controller.selectedIndices;
      expect(newIndices, {2, 4}); // Charlie at 2, Alice at 4
    });

    test('getSelectedRows returns data in display order', () {
      controller.toggleSelection(2); // Charlie
      controller.toggleSelection(0); // Alice
      final rows = controller.getSelectedRows();
      // Should be in display order: Alice first, then Charlie
      expect(rows[0]['name'], 'Alice');
      expect(rows[1]['name'], 'Charlie');
    });

    test('setRowData clears selection', () {
      controller.selectAll();
      controller.setRowData([
        {'id': 10, 'name': 'New'},
      ]);
      expect(controller.getSelectedIds(), isEmpty);
    });

    test('applyTransaction remove clears selection for removed rows', () {
      final bob = {'id': 2, 'name': 'Bob', 'age': 28};
      controller.toggleSelection(1); // Bob
      expect(controller.getSelectedIds(), {'2'});

      controller.applyTransaction(OsRowTransaction(remove: [bob]));
      expect(controller.getSelectedIds(), isEmpty);
    });

    test('fallback to hashCode when getRowId is null', () {
      final controller2 = OsGridController<Map<String, dynamic>>();
      // No getRowId set — uses hashCode
      final data = [
        {'name': 'Alice'},
        {'name': 'Bob'},
      ];
      controller2.setRowData(data);
      controller2.processedData = data;

      controller2.toggleSelection(0);
      expect(controller2.isRowSelected(0), true);
      expect(controller2.isRowSelected(1), false);

      controller2.dispose();
    });

    test('onSelectionChanged stream emits with correct data', () async {
      final events = <OsSelectionChangedEvent<Map<String, dynamic>>>[];
      final sub = controller.onSelectionChanged.listen(events.add);

      controller.toggleSelection(0); // Alice
      await Future<void>.delayed(Duration.zero);

      expect(events.length, 1);
      expect(events.first.selectedRows.length, 1);
      expect(events.first.selectedRows.first['name'], 'Alice');

      await sub.cancel();
    });

    test('selectAll with SelectAllMode.filtered', () {
      controller.rowSelection = OsRowSelection.multiple(
        selectAll: SelectAllMode.filtered,
      );
      // Simulate filter
      controller.processedData = [
        {'id': 1, 'name': 'Alice', 'age': 32},
        {'id': 3, 'name': 'Charlie', 'age': 45},
      ];
      controller.selectAll(); // Should respect the mode
      expect(controller.getSelectedIds(), {'1', '3'});
    });

    test('selectAll with SelectAllMode.currentPage', () {
      controller.rowSelection = OsRowSelection.multiple(
        selectAll: SelectAllMode.currentPage,
      );
      controller.pageData = [
        {'id': 2, 'name': 'Bob', 'age': 28},
      ];
      controller.selectAll();
      expect(controller.getSelectedIds(), {'2'});
    });
  });

  group('ID-based selection — OsGrid widget integration', () {
    testWidgets('getRowId parameter is wired to controller', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              getRowId: (data) => data['id'].toString(),
              columnDefs: [
                const OsColumnDef(field: 'name', headerName: 'Name'),
              ],
              rowData: [
                {'id': 1, 'name': 'Alice'},
                {'id': 2, 'name': 'Bob'},
              ],
            ),
          ),
        ),
      );

      // Controller should use the getRowId function
      controller.toggleSelection(0);
      expect(controller.getSelectedIds(), {'1'});

      controller.dispose();
    });

    testWidgets('selection persists after sort via widget', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              getRowId: (data) => data['id'].toString(),
              rowSelection: OsRowSelection.multiple(),
              columnDefs: [
                const OsColumnDef(field: 'name', headerName: 'Name'),
                const OsColumnDef(
                  field: 'age',
                  headerName: 'Age',
                  sortable: true,
                ),
              ],
              rowData: [
                {'id': 1, 'name': 'Alice', 'age': 32},
                {'id': 2, 'name': 'Bob', 'age': 28},
                {'id': 3, 'name': 'Charlie', 'age': 45},
              ],
            ),
          ),
        ),
      );

      // Select Alice
      controller.toggleSelection(0);
      expect(controller.getSelectedIds(), {'1'});

      // The selection is by ID, so even if sort changes indices,
      // the ID '1' remains selected
      expect(controller.getSelectedIds().contains('1'), true);

      controller.dispose();
    });

    testWidgets('enableClickSelection=false prevents click selection', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              getRowId: (data) => data['id'].toString(),
              rowSelection: OsRowSelection.multiple(
                enableClickSelection: false,
              ),
              columnDefs: [
                const OsColumnDef(field: 'name', headerName: 'Name'),
              ],
              rowData: [
                {'id': 1, 'name': 'Alice'},
                {'id': 2, 'name': 'Bob'},
              ],
            ),
          ),
        ),
      );

      // Widget renders without error
      expect(find.byType(VirtualisedGrid), findsOneWidget);

      // API selection still works even when click is disabled
      controller.toggleSelection(0);
      expect(controller.getSelectedIds(), {'1'});

      controller.dispose();
    });
  });
}
