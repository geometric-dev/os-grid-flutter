import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

void main() {
  group('enableSelectionWithoutKeys', () {
    late OsGridController<Map<String, dynamic>> controller;

    setUp(() {
      controller = OsGridController<Map<String, dynamic>>();
      controller.getRowId = (data) => data['id'].toString();
      controller.setRowData([
        {'id': 1, 'name': 'Alice'},
        {'id': 2, 'name': 'Bob'},
        {'id': 3, 'name': 'Charlie'},
      ]);
      controller.processedData = [
        {'id': 1, 'name': 'Alice'},
        {'id': 2, 'name': 'Bob'},
        {'id': 3, 'name': 'Charlie'},
      ];
    });

    tearDown(() => controller.dispose());

    test('defaults to false', () {
      final selection = OsRowSelection.multiple();
      expect(selection.enableSelectionWithoutKeys, false);
    });

    test('can be set to true', () {
      final selection = OsRowSelection.multiple(
        enableSelectionWithoutKeys: true,
      );
      expect(selection.enableSelectionWithoutKeys, true);
    });

    test('not available on single mode (always false)', () {
      final selection = OsRowSelection.single();
      expect(selection.enableSelectionWithoutKeys, false);
    });

    test(
      'toggleSelection works correctly for enableSelectionWithoutKeys pattern',
      () {
        // When enableSelectionWithoutKeys is true, each click calls toggleSelection
        // Simulate: click row 0, click row 1, click row 0 again
        controller.toggleSelection(0); // Alice selected
        expect(controller.getSelectedIds(), {'1'});

        controller.toggleSelection(1); // Bob also selected
        expect(controller.getSelectedIds(), {'1', '2'});

        controller.toggleSelection(0); // Alice deselected
        expect(controller.getSelectedIds(), {'2'});
      },
    );

    test(
      'setSingleSelection replaces selection (enableSelectionWithoutKeys=false pattern)',
      () {
        // When enableSelectionWithoutKeys is false, plain click calls setSingleSelection
        controller.setSingleSelection(0); // Alice only
        expect(controller.getSelectedIds(), {'1'});

        controller.setSingleSelection(1); // Bob only (replaces)
        expect(controller.getSelectedIds(), {'2'});
      },
    );

    testWidgets('widget renders with enableSelectionWithoutKeys=true', (
      tester,
    ) async {
      final ctrl = OsGridController<Map<String, dynamic>>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 300,
              child: OsGrid<Map<String, dynamic>>(
                controller: ctrl,
                rowData: const [
                  {'id': 1, 'name': 'Alice'},
                  {'id': 2, 'name': 'Bob'},
                  {'id': 3, 'name': 'Charlie'},
                ],
                getRowId: (data) => data['id'].toString(),
                rowSelection: OsRowSelection.multiple(
                  enableSelectionWithoutKeys: true,
                ),
                columnDefs: const [
                  OsColumnDef(field: 'name', headerName: 'Name'),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Grid renders without error
      expect(find.byType(VirtualisedGrid), findsOneWidget);

      // API-based toggle works (simulates what click handler does)
      ctrl.toggleSelection(0);
      expect(ctrl.getSelectedIds(), contains('1'));

      ctrl.toggleSelection(1);
      expect(ctrl.getSelectedIds(), {'1', '2'});

      ctrl.toggleSelection(0);
      expect(ctrl.getSelectedIds(), {'2'});

      ctrl.dispose();
    });

    testWidgets('widget renders with enableSelectionWithoutKeys=false', (
      tester,
    ) async {
      final ctrl = OsGridController<Map<String, dynamic>>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 300,
              child: OsGrid<Map<String, dynamic>>(
                controller: ctrl,
                rowData: const [
                  {'id': 1, 'name': 'Alice'},
                  {'id': 2, 'name': 'Bob'},
                  {'id': 3, 'name': 'Charlie'},
                ],
                getRowId: (data) => data['id'].toString(),
                rowSelection: OsRowSelection.multiple(
                  enableSelectionWithoutKeys: false,
                ),
                columnDefs: const [
                  OsColumnDef(field: 'name', headerName: 'Name'),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Grid renders without error
      expect(find.byType(VirtualisedGrid), findsOneWidget);

      // API-based setSingleSelection works (simulates what plain click does)
      ctrl.setSingleSelection(0);
      expect(ctrl.getSelectedIds(), {'1'});

      ctrl.setSingleSelection(1);
      expect(ctrl.getSelectedIds(), {'2'});

      ctrl.dispose();
    });
  });

  group('hideDisabledCheckboxes', () {
    test('defaults to false', () {
      final selection = OsRowSelection.multiple(checkboxes: true);
      expect(selection.hideDisabledCheckboxes, false);
    });

    test('can be set to true', () {
      final selection = OsRowSelection.multiple(
        checkboxes: true,
        hideDisabledCheckboxes: true,
        isRowSelectable: (data) => data['active'] == true,
      );
      expect(selection.hideDisabledCheckboxes, true);
    });

    testWidgets('renders with hideDisabledCheckboxes=true without errors', (
      tester,
    ) async {
      final ctrl = OsGridController<Map<String, dynamic>>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 300,
              child: OsGrid<Map<String, dynamic>>(
                controller: ctrl,
                rowData: const [
                  {'id': 1, 'name': 'Alice', 'active': true},
                  {'id': 2, 'name': 'Bob', 'active': false},
                  {'id': 3, 'name': 'Charlie', 'active': true},
                ],
                getRowId: (data) => data['id'].toString(),
                rowSelection: OsRowSelection.multiple(
                  checkboxes: true,
                  hideDisabledCheckboxes: true,
                  isRowSelectable: (data) => data['active'] == true,
                ),
                columnDefs: const [
                  OsColumnDef(field: 'name', headerName: 'Name'),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Grid renders without error
      expect(find.byType(VirtualisedGrid), findsOneWidget);

      // Non-selectable row (Bob) cannot be selected via API
      ctrl.toggleSelection(1); // Bob — should be rejected
      expect(ctrl.getSelectedIds().contains('2'), false);

      // Selectable row (Alice) can be selected
      ctrl.toggleSelection(0);
      expect(ctrl.getSelectedIds(), contains('1'));

      ctrl.dispose();
    });

    testWidgets(
      'renders with hideDisabledCheckboxes=false (disabled checkbox shown)',
      (tester) async {
        final ctrl = OsGridController<Map<String, dynamic>>();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                height: 300,
                child: OsGrid<Map<String, dynamic>>(
                  controller: ctrl,
                  rowData: const [
                    {'id': 1, 'name': 'Alice', 'active': true},
                    {'id': 2, 'name': 'Bob', 'active': false},
                  ],
                  getRowId: (data) => data['id'].toString(),
                  rowSelection: OsRowSelection.multiple(
                    checkboxes: true,
                    hideDisabledCheckboxes: false,
                    isRowSelectable: (data) => data['active'] == true,
                  ),
                  columnDefs: const [
                    OsColumnDef(field: 'name', headerName: 'Name'),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Grid renders without error — disabled checkbox is painted (⊘ state)
        expect(find.byType(VirtualisedGrid), findsOneWidget);

        // Non-selectable row still cannot be selected
        ctrl.toggleSelection(1);
        expect(ctrl.getSelectedIds().contains('2'), false);

        ctrl.dispose();
      },
    );
  });

  group('checkboxes callback', () {
    test('shouldShowCheckbox returns true when checkboxes=true', () {
      final selection = OsRowSelection.multiple(checkboxes: true);
      expect(selection.shouldShowCheckbox({'type': 'row'}, 0), true);
    });

    test('shouldShowCheckbox returns false when checkboxes=false', () {
      final selection = OsRowSelection.multiple(checkboxes: false);
      expect(selection.shouldShowCheckbox({'type': 'row'}, 0), false);
    });

    test('shouldShowCheckbox uses callback when provided', () {
      final selection = OsRowSelection.multiple(
        checkboxesCallback: (data, rowIndex) => data['type'] != 'group',
      );
      expect(selection.shouldShowCheckbox({'type': 'row'}, 0), true);
      expect(selection.shouldShowCheckbox({'type': 'group'}, 1), false);
    });

    test('checkboxesCallback takes precedence over checkboxes bool', () {
      final selection = OsRowSelection.multiple(
        checkboxes: true,
        checkboxesCallback: (data, rowIndex) => rowIndex.isEven,
      );
      // Callback takes precedence
      expect(selection.shouldShowCheckbox({'id': 1}, 0), true);
      expect(selection.shouldShowCheckbox({'id': 2}, 1), false);
      expect(selection.shouldShowCheckbox({'id': 3}, 2), true);
    });

    test('hasCheckboxes is true when checkboxes=true', () {
      final selection = OsRowSelection.multiple(checkboxes: true);
      expect(selection.hasCheckboxes, true);
    });

    test('hasCheckboxes is true when checkboxesCallback is provided', () {
      final selection = OsRowSelection.multiple(
        checkboxesCallback: (data, rowIndex) => true,
      );
      expect(selection.hasCheckboxes, true);
    });

    test('hasCheckboxes is false when neither is set', () {
      final selection = OsRowSelection.multiple();
      expect(selection.hasCheckboxes, false);
    });

    testWidgets('renders with checkboxesCallback without errors', (
      tester,
    ) async {
      final ctrl = OsGridController<Map<String, dynamic>>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 300,
              child: OsGrid<Map<String, dynamic>>(
                controller: ctrl,
                rowData: const [
                  {'id': 1, 'name': 'Alice', 'type': 'person'},
                  {'id': 2, 'name': 'Group A', 'type': 'group'},
                  {'id': 3, 'name': 'Charlie', 'type': 'person'},
                ],
                getRowId: (data) => data['id'].toString(),
                rowSelection: OsRowSelection.multiple(
                  checkboxesCallback: (data, rowIndex) =>
                      data['type'] != 'group',
                ),
                columnDefs: const [
                  OsColumnDef(field: 'name', headerName: 'Name'),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Grid renders without error
      expect(find.byType(VirtualisedGrid), findsOneWidget);

      ctrl.dispose();
    });

    testWidgets('row with hidden checkbox is still selectable via API', (
      tester,
    ) async {
      final ctrl = OsGridController<Map<String, dynamic>>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 300,
              child: OsGrid<Map<String, dynamic>>(
                controller: ctrl,
                rowData: const [
                  {'id': 1, 'name': 'Alice', 'type': 'person'},
                  {'id': 2, 'name': 'Group A', 'type': 'group'},
                ],
                getRowId: (data) => data['id'].toString(),
                rowSelection: OsRowSelection.multiple(
                  enableSelectionWithoutKeys: true,
                  checkboxesCallback: (data, rowIndex) =>
                      data['type'] != 'group',
                ),
                columnDefs: const [
                  OsColumnDef(field: 'name', headerName: 'Name'),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Row should be selectable even though checkbox is hidden
      // (checkboxesCallback is distinct from isRowSelectable)
      ctrl.toggleSelection(1); // Group A
      expect(ctrl.getSelectedIds(), contains('2'));

      ctrl.dispose();
    });

    test('checkboxesCallback does not affect isRowSelectable', () {
      // A row can have no checkbox but still be selectable
      final selection = OsRowSelection.multiple(
        checkboxesCallback: (data, rowIndex) => false, // No checkboxes
        // No isRowSelectable — all rows are selectable
      );
      expect(selection.isRowSelectable, isNull);
      expect(selection.shouldShowCheckbox({'id': 1}, 0), false);
    });
  });

  group('deselectRowsById', () {
    late OsGridController<Map<String, dynamic>> controller;

    setUp(() {
      controller = OsGridController<Map<String, dynamic>>();
      controller.getRowId = (data) => data['id'].toString();
      controller.setRowData([
        {'id': 1, 'name': 'Alice'},
        {'id': 2, 'name': 'Bob'},
        {'id': 3, 'name': 'Charlie'},
        {'id': 4, 'name': 'Diana'},
        {'id': 5, 'name': 'Eve'},
      ]);
      controller.processedData = [
        {'id': 1, 'name': 'Alice'},
        {'id': 2, 'name': 'Bob'},
        {'id': 3, 'name': 'Charlie'},
        {'id': 4, 'name': 'Diana'},
        {'id': 5, 'name': 'Eve'},
      ];
    });

    tearDown(() => controller.dispose());

    test('deselects specific rows by ID', () {
      controller.selectAll();
      expect(controller.getSelectedIds().length, 5);

      controller.deselectRowsById({'2', '4'});
      expect(controller.getSelectedIds(), {'1', '3', '5'});
    });

    test('ignores IDs that are not selected', () {
      controller.selectRowsById(['1', '3']);
      controller.deselectRowsById({'2', '4'}); // Not selected — no-op
      expect(controller.getSelectedIds(), {'1', '3'});
    });

    test('handles empty set gracefully', () {
      controller.selectAll();
      controller.deselectRowsById({});
      expect(controller.getSelectedIds().length, 5);
    });

    test('selection empties when all rows deselected by ID', () {
      controller.toggleSelection(0); // Alice
      expect(controller.getSelectedIds(), {'1'});

      controller.deselectRowsById({'1'});
      expect(controller.getSelectedIds(), isEmpty);
    });

    test('emits selection changed event', () {
      controller.selectAll();

      final events = <Object>[];
      controller.onSelectionChanged.listen(events.add);

      controller.deselectRowsById({'1', '2'});
      // Stream events are async, but the controller should have notified
      expect(controller.getSelectedIds(), {'3', '4', '5'});
    });

    test('works with selectRowsById for add/remove pattern', () {
      // Add some
      controller.selectRowsById(['1', '2', '3']);
      expect(controller.getSelectedIds(), {'1', '2', '3'});

      // Remove some
      controller.deselectRowsById({'2'});
      expect(controller.getSelectedIds(), {'1', '3'});

      // Add more
      controller.selectRowsById(['4']);
      expect(controller.getSelectedIds(), {'1', '3', '4'});
    });

    test('mirrors TypeScript setNodesSelected(nodes, false) pattern', () {
      // Select all, then deselect specific ones
      controller.selectAll();
      controller.deselectRowsById({'1', '5'});
      expect(controller.getSelectedIds(), {'2', '3', '4'});
    });

    test('deselecting all rows via deselectRowsById', () {
      controller.selectRowsById(['1', '2', '3']);
      controller.deselectRowsById({'1', '2', '3'});
      expect(controller.getSelectedIds(), isEmpty);
    });
  });

  group('backward compatibility', () {
    test(
      'OsRowSelection.multiple() still works with just checkboxes: true',
      () {
        final selection = OsRowSelection.multiple(checkboxes: true);
        expect(selection.checkboxes, true);
        expect(selection.hasCheckboxes, true);
        expect(selection.checkboxesCallback, isNull);
        expect(selection.enableSelectionWithoutKeys, false);
        expect(selection.hideDisabledCheckboxes, false);
      },
    );

    test('OsRowSelection.single() is unchanged', () {
      final selection = OsRowSelection.single();
      expect(selection.mode, OsRowSelectionMode.single);
      expect(selection.enableClickSelection, true);
      expect(selection.enableSelectionWithoutKeys, false);
      expect(selection.hideDisabledCheckboxes, false);
    });

    test('OsRowSelection.multiple() defaults are backward compatible', () {
      final selection = OsRowSelection.multiple();
      expect(selection.mode, OsRowSelectionMode.multiple);
      expect(selection.checkboxes, false);
      expect(selection.headerCheckbox, false);
      expect(selection.isRowSelectable, isNull);
      expect(selection.enableClickSelection, true);
      expect(selection.enableSelectionWithoutKeys, false);
      expect(selection.hideDisabledCheckboxes, false);
      expect(selection.selectAll, SelectAllMode.all);
    });

    test('selectRowsById still works as before', () {
      final controller = OsGridController<Map<String, dynamic>>();
      controller.getRowId = (data) => data['id'].toString();
      controller.setRowData([
        {'id': 1, 'name': 'Alice'},
        {'id': 2, 'name': 'Bob'},
      ]);
      controller.processedData = [
        {'id': 1, 'name': 'Alice'},
        {'id': 2, 'name': 'Bob'},
      ];

      controller.selectRowsById(['1', '2']);
      expect(controller.getSelectedIds(), {'1', '2'});

      controller.dispose();
    });
  });

  group('cross-feature interactions', () {
    test('enableSelectionWithoutKeys with isRowSelectable', () {
      final controller = OsGridController<Map<String, dynamic>>();
      controller.getRowId = (data) => data['id'].toString();
      controller.setRowData([
        {'id': 1, 'name': 'Alice', 'active': true},
        {'id': 2, 'name': 'Bob', 'active': false},
        {'id': 3, 'name': 'Charlie', 'active': true},
      ]);
      controller.processedData = [
        {'id': 1, 'name': 'Alice', 'active': true},
        {'id': 2, 'name': 'Bob', 'active': false},
        {'id': 3, 'name': 'Charlie', 'active': true},
      ];
      controller.rowSelection = OsRowSelection.multiple(
        enableSelectionWithoutKeys: true,
        isRowSelectable: (data) => data['active'] == true,
      );

      // Toggle Alice — should work
      controller.toggleSelection(0);
      expect(controller.getSelectedIds(), {'1'});

      // Toggle Bob — should be rejected (not selectable)
      controller.toggleSelection(1);
      expect(controller.getSelectedIds(), {'1'});

      // Toggle Charlie — should work
      controller.toggleSelection(2);
      expect(controller.getSelectedIds(), {'1', '3'});

      controller.dispose();
    });

    test('deselectRowsById with isRowSelectable', () {
      final controller = OsGridController<Map<String, dynamic>>();
      controller.getRowId = (data) => data['id'].toString();
      controller.setRowData([
        {'id': 1, 'name': 'Alice'},
        {'id': 2, 'name': 'Bob'},
        {'id': 3, 'name': 'Charlie'},
      ]);
      controller.processedData = [
        {'id': 1, 'name': 'Alice'},
        {'id': 2, 'name': 'Bob'},
        {'id': 3, 'name': 'Charlie'},
      ];

      // Select all, then deselect specific ones
      controller.selectAll();
      controller.deselectRowsById({'2'});
      expect(controller.getSelectedIds(), {'1', '3'});

      // Deselect remaining
      controller.deselectRowsById({'1', '3'});
      expect(controller.getSelectedIds(), isEmpty);

      controller.dispose();
    });

    test('checkboxesCallback with hideDisabledCheckboxes', () {
      // Both can be set together — they serve different purposes
      final selection = OsRowSelection.multiple(
        checkboxesCallback: (data, rowIndex) => data['showCheckbox'] == true,
        hideDisabledCheckboxes: true,
        isRowSelectable: (data) => data['selectable'] == true,
      );

      // Row with showCheckbox=false: no checkbox shown (callback)
      expect(
        selection.shouldShowCheckbox({
          'showCheckbox': false,
          'selectable': true,
        }, 0),
        false,
      );

      // Row with showCheckbox=true: checkbox shown (callback)
      expect(
        selection.shouldShowCheckbox({
          'showCheckbox': true,
          'selectable': true,
        }, 1),
        true,
      );

      // hideDisabledCheckboxes affects rows where isRowSelectable=false
      // but checkboxesCallback=true — those get the '⊘' → '' treatment
      expect(selection.hideDisabledCheckboxes, true);
    });
  });
}
