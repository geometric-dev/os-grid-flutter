import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

void main() {
  group('ImmutableDataService — unit tests', () {
    late ImmutableDataService<Map<String, dynamic>> service;

    setUp(() {
      service = ImmutableDataService<Map<String, dynamic>>(
        getRowId: (data) => data['id'].toString(),
      );
    });

    test('empty old data — all new rows are adds', () {
      final result = service.computeDiff(
        oldData: [],
        newData: [
          {'id': 1, 'name': 'Alice'},
          {'id': 2, 'name': 'Bob'},
        ],
      );

      expect(result.adds.length, 2);
      expect(result.removes, isEmpty);
      expect(result.updates, isEmpty);
      expect(result.hasChanges, true);
    });

    test('empty new data — all old rows are removes', () {
      final result = service.computeDiff(
        oldData: [
          {'id': 1, 'name': 'Alice'},
          {'id': 2, 'name': 'Bob'},
        ],
        newData: [],
      );

      expect(result.adds, isEmpty);
      expect(result.removes.length, 2);
      expect(result.updates, isEmpty);
      expect(result.hasChanges, true);
    });

    test('identical data (same objects) — no changes', () {
      final data = [
        {'id': 1, 'name': 'Alice'},
        {'id': 2, 'name': 'Bob'},
      ];

      final result = service.computeDiff(oldData: data, newData: data);

      expect(result.adds, isEmpty);
      expect(result.removes, isEmpty);
      expect(result.updates, isEmpty);
      expect(result.hasChanges, false);
      expect(result.orderChanged, false);
    });

    test('same IDs but different objects — detected as updates', () {
      final oldData = [
        {'id': 1, 'name': 'Alice'},
        {'id': 2, 'name': 'Bob'},
      ];
      final newData = [
        {'id': 1, 'name': 'Alice Updated'},
        {'id': 2, 'name': 'Bob Updated'},
      ];

      final result = service.computeDiff(oldData: oldData, newData: newData);

      expect(result.adds, isEmpty);
      expect(result.removes, isEmpty);
      expect(result.updates.length, 2);
      expect(result.hasChanges, true);
    });

    test('new row added — detected as add', () {
      final alice = {'id': 1, 'name': 'Alice'};
      final oldData = [alice];
      final newData = [
        alice, // same object reference — not an update
        {'id': 2, 'name': 'Bob'},
      ];

      final result = service.computeDiff(oldData: oldData, newData: newData);

      expect(result.adds.length, 1);
      expect(result.adds.first['name'], 'Bob');
      expect(result.removes, isEmpty);
      expect(result.updates, isEmpty);
    });

    test('row removed — detected as remove', () {
      final alice = {'id': 1, 'name': 'Alice'};
      final oldData = [
        alice,
        {'id': 2, 'name': 'Bob'},
      ];
      final newData = [alice]; // same object reference

      final result = service.computeDiff(oldData: oldData, newData: newData);

      expect(result.adds, isEmpty);
      expect(result.removes.length, 1);
      expect(result.removes.first['name'], 'Bob');
      expect(result.updates, isEmpty);
    });

    test('mixed adds, removes, and updates', () {
      final oldData = [
        {'id': 1, 'name': 'Alice'},
        {'id': 2, 'name': 'Bob'},
        {'id': 3, 'name': 'Charlie'},
      ];
      final newData = [
        {'id': 1, 'name': 'Alice Updated'}, // update
        // id=2 removed
        {'id': 3, 'name': 'Charlie'}, // same object? No, new map
        {'id': 4, 'name': 'Diana'}, // add
      ];

      final result = service.computeDiff(oldData: oldData, newData: newData);

      expect(result.adds.length, 1);
      expect(result.adds.first['id'], 4);
      expect(result.removes.length, 1);
      expect(result.removes.first['id'], 2);
      // id=1 and id=3 are updates (different object identity)
      expect(result.updates.length, 2);
    });

    test('order change detected', () {
      final row1 = {'id': 1, 'name': 'Alice'};
      final row2 = {'id': 2, 'name': 'Bob'};
      final row3 = {'id': 3, 'name': 'Charlie'};

      final result = service.computeDiff(
        oldData: [row1, row2, row3],
        newData: [row3, row1, row2], // reordered, same objects
      );

      expect(result.adds, isEmpty);
      expect(result.removes, isEmpty);
      expect(result.updates, isEmpty);
      expect(result.orderChanged, true);
    });

    test('no order change when same order', () {
      final row1 = {'id': 1, 'name': 'Alice'};
      final row2 = {'id': 2, 'name': 'Bob'};
      final row3 = {'id': 3, 'name': 'Charlie'};

      final result = service.computeDiff(
        oldData: [row1, row2, row3],
        newData: [row1, row2, row3], // same order, same objects
      );

      expect(result.orderChanged, false);
      expect(result.hasChanges, false);
    });
  });

  group('Immutable data mode — widget integration', () {
    testWidgets('rowData change with getRowId diffs instead of replacing', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();
      final events = <OsRowDataUpdatedEvent<Map<String, dynamic>>>[];

      controller.onRowDataUpdated.listen(events.add);

      final initialData = [
        {'id': 1, 'name': 'Alice', 'age': 30},
        {'id': 2, 'name': 'Bob', 'age': 25},
        {'id': 3, 'name': 'Charlie', 'age': 35},
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              getRowId: (data) => data['id'].toString(),
              columnDefs: [
                const OsColumnDef(field: 'name', headerName: 'Name'),
                const OsColumnDef(field: 'age', headerName: 'Age'),
              ],
              rowData: initialData,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Select a row
      controller.toggleSelection(0); // Alice
      expect(controller.getSelectedIds(), {'1'});

      // Update rowData with one row changed, one added, one removed
      final updatedData = [
        {'id': 1, 'name': 'Alice Updated', 'age': 31}, // updated
        // id=2 removed
        {'id': 3, 'name': 'Charlie', 'age': 35}, // unchanged (but new object)
        {'id': 4, 'name': 'Diana', 'age': 28}, // added
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              getRowId: (data) => data['id'].toString(),
              columnDefs: [
                const OsColumnDef(field: 'name', headerName: 'Name'),
                const OsColumnDef(field: 'age', headerName: 'Age'),
              ],
              rowData: updatedData,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Selection of Alice (id=1) should survive the diff
      expect(controller.getSelectedIds(), {'1'});

      // Bob (id=2) was removed — should not be in selection
      expect(controller.getSelectedIds().contains('2'), false);
    });

    testWidgets('immutableData: false disables diffing', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();

      final initialData = [
        {'id': 1, 'name': 'Alice'},
        {'id': 2, 'name': 'Bob'},
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              getRowId: (data) => data['id'].toString(),
              immutableData: false, // explicitly disabled
              columnDefs: [
                const OsColumnDef(field: 'name', headerName: 'Name'),
              ],
              rowData: initialData,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Select a row
      controller.toggleSelection(0);
      expect(controller.getSelectedIds(), {'1'});

      // Update rowData — since immutableData is false, full replacement
      final updatedData = [
        {'id': 1, 'name': 'Alice Updated'},
        {'id': 2, 'name': 'Bob'},
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              getRowId: (data) => data['id'].toString(),
              immutableData: false,
              columnDefs: [
                const OsColumnDef(field: 'name', headerName: 'Name'),
              ],
              rowData: updatedData,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Selection should be cleared (full replacement via setRowData)
      expect(controller.getSelectedIds(), isEmpty);
    });

    testWidgets('immutable mode preserves selection through updates', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();

      final row1 = {'id': 1, 'name': 'Alice'};
      final row2 = {'id': 2, 'name': 'Bob'};
      final row3 = {'id': 3, 'name': 'Charlie'};

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              getRowId: (data) => data['id'].toString(),
              rowSelection: OsRowSelection.multiple(),
              columnDefs: [
                const OsColumnDef(field: 'name', headerName: 'Name'),
              ],
              rowData: [row1, row2, row3],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Select Bob and Charlie
      controller.toggleSelection(1); // Bob
      controller.toggleSelection(2); // Charlie
      expect(controller.getSelectedIds(), {'2', '3'});

      // Update with Bob's data changed
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              getRowId: (data) => data['id'].toString(),
              rowSelection: OsRowSelection.multiple(),
              columnDefs: [
                const OsColumnDef(field: 'name', headerName: 'Name'),
              ],
              rowData: [
                row1,
                {'id': 2, 'name': 'Bob Updated'},
                row3,
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Both Bob and Charlie should still be selected
      expect(controller.getSelectedIds(), {'2', '3'});
    });
  });
}
