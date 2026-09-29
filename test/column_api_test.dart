import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';
import 'package:os_grid_flutter/src/columns/column_api_coordinator.dart';

void main() {
  group('ColumnState model', () {
    test('ColumnState toJson produces correct map', () {
      const state = ColumnState(
        colId: 'name',
        hide: true,
        width: 200,
        pinned: OsColumnPin.left,
      );
      final json = state.toJson();
      expect(json['colId'], 'name');
      expect(json['hide'], true);
      expect(json['width'], 200);
      expect(json['pinned'], 'left');
    });

    test('ColumnState fromJson round-trips correctly', () {
      const original = ColumnState(
        colId: 'age',
        hide: false,
        width: 100,
        flex: 2,
        pinned: OsColumnPin.right,
      );
      final json = original.toJson();
      final restored = ColumnState.fromJson(json);
      expect(restored.colId, 'age');
      expect(restored.width, 100);
      expect(restored.flex, 2);
      expect(restored.pinned, OsColumnPin.right);
    });

    test('ColumnState equality works', () {
      const a = ColumnState(colId: 'x', width: 100);
      const b = ColumnState(colId: 'x', width: 100);
      const c = ColumnState(colId: 'x', width: 200);
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('ColumnState copyWith replaces fields', () {
      const state = ColumnState(colId: 'x', width: 100, hide: true);
      final copy = state.copyWith(width: 200, clearHide: true);
      expect(copy.width, 200);
      expect(copy.hide, isNull);
      expect(copy.colId, 'x');
    });
  });

  group('OsColumnDef hide property', () {
    test('hide defaults to null (visible)', () {
      const col = OsColumnDef(field: 'name');
      expect(col.hide, isNull);
    });

    test('hide can be set to true', () {
      const col = OsColumnDef(field: 'name', hide: true);
      expect(col.hide, true);
    });
  });

  group('Column event streams', () {
    test('onColumnVisible emits when emitColumnVisible is called', () async {
      final controller = OsGridController<Map<String, dynamic>>();
      final events = <OsColumnVisibleEvent>[];
      final sub = controller.onColumnVisible.listen(events.add);

      controller.emitColumnVisible(
        const OsColumnVisibleEvent(columns: ['age'], visible: false),
      );
      await Future<void>.delayed(Duration.zero);

      expect(events.length, 1);
      expect(events.first.columns, ['age']);
      expect(events.first.visible, false);

      await sub.cancel();
      controller.dispose();
    });

    test('onColumnPinned emits when emitColumnPinned is called', () async {
      final controller = OsGridController<Map<String, dynamic>>();
      final events = <OsColumnPinnedEvent>[];
      final sub = controller.onColumnPinned.listen(events.add);

      controller.emitColumnPinned(
        const OsColumnPinnedEvent(columns: ['name'], pinned: OsColumnPin.left),
      );
      await Future<void>.delayed(Duration.zero);

      expect(events.length, 1);
      expect(events.first.columns, ['name']);
      expect(events.first.pinned, OsColumnPin.left);

      await sub.cancel();
      controller.dispose();
    });

    test('onColumnResized emits when emitColumnResized is called', () async {
      final controller = OsGridController<Map<String, dynamic>>();
      final events = <OsColumnResizedEvent>[];
      final sub = controller.onColumnResized.listen(events.add);

      controller.emitColumnResized(
        const OsColumnResizedEvent(
          columns: [ColumnResizeEntry(colId: 'name', width: 200)],
          finished: true,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(events.length, 1);
      expect(events.first.columns.first.colId, 'name');
      expect(events.first.columns.first.width, 200);
      expect(events.first.finished, true);

      await sub.cancel();
      controller.dispose();
    });

    test('onColumnMoved emits when emitColumnMoved is called', () async {
      final controller = OsGridController<Map<String, dynamic>>();
      final events = <OsColumnMovedEvent>[];
      final sub = controller.onColumnMoved.listen(events.add);

      controller.emitColumnMoved(
        const OsColumnMovedEvent(columns: ['b'], toIndex: 0),
      );
      await Future<void>.delayed(Duration.zero);

      expect(events.length, 1);
      expect(events.first.columns, ['b']);
      expect(events.first.toIndex, 0);

      await sub.cancel();
      controller.dispose();
    });
  });

  group('Column visibility — widget integration', () {
    testWidgets('setColumnsVisible hides columns', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();
      OsColumnVisibleEvent? received;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              columnDefs: const [
                OsColumnDef(field: 'name'),
                OsColumnDef(field: 'age'),
              ],
              rowData: const [
                {'name': 'Alice', 'age': 32},
              ],
              onColumnVisible: (event) => received = event,
            ),
          ),
        ),
      );

      controller.setColumnsVisible(['age'], false);
      await tester.pump();

      expect(received, isNotNull);
      expect(received!.columns, ['age']);
      expect(received!.visible, false);

      // Verify the column is excluded from displayed columns
      final displayed = controller.getAllDisplayedColumns();
      expect(displayed.length, 1);
      expect(displayed.first.effectiveColId, 'name');

      controller.dispose();
    });

    testWidgets('setColumnsVisible shows previously hidden columns', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              columnDefs: const [
                OsColumnDef(field: 'name'),
                OsColumnDef(field: 'age', hide: true),
              ],
              rowData: const [
                {'name': 'Alice', 'age': 32},
              ],
            ),
          ),
        ),
      );

      // Initially hidden
      expect(controller.getAllDisplayedColumns().length, 1);

      controller.setColumnsVisible(['age'], true);
      await tester.pump();

      expect(controller.getAllDisplayedColumns().length, 2);

      controller.dispose();
    });
  });

  group('Column pinning — widget integration', () {
    testWidgets('setColumnsPinned pins columns', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();
      OsColumnPinnedEvent? received;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              columnDefs: const [
                OsColumnDef(field: 'name'),
                OsColumnDef(field: 'age'),
              ],
              rowData: const [
                {'name': 'Alice', 'age': 32},
              ],
              onColumnPinned: (event) => received = event,
            ),
          ),
        ),
      );

      controller.setColumnsPinned(['name'], OsColumnPin.left);
      await tester.pump();

      expect(received, isNotNull);
      expect(received!.columns, ['name']);
      expect(received!.pinned, OsColumnPin.left);

      controller.dispose();
    });

    testWidgets('isPinning returns correct state', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              columnDefs: const [
                OsColumnDef(field: 'name'),
                OsColumnDef(field: 'age'),
              ],
              rowData: const [
                {'name': 'Alice', 'age': 32},
              ],
            ),
          ),
        ),
      );

      expect(controller.isPinning(), false);

      controller.setColumnsPinned(['name'], OsColumnPin.left);
      await tester.pump();

      expect(controller.isPinning(), true);
      expect(controller.isPinningLeft(), true);
      expect(controller.isPinningRight(), false);

      controller.dispose();
    });

    testWidgets('isPinning detects pinned from column def', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              columnDefs: const [
                OsColumnDef(field: 'name', pinned: OsColumnPin.right),
                OsColumnDef(field: 'age'),
              ],
              rowData: const [
                {'name': 'Alice', 'age': 32},
              ],
            ),
          ),
        ),
      );

      expect(controller.isPinning(), true);
      expect(controller.isPinningRight(), true);
      expect(controller.isPinningLeft(), false);

      controller.dispose();
    });
  });

  group('Column state — widget integration', () {
    testWidgets('getColumnState returns current state', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              columnDefs: const [
                OsColumnDef(field: 'name', width: 150),
                OsColumnDef(field: 'age', width: 80),
              ],
              rowData: const [
                {'name': 'Alice', 'age': 32},
              ],
            ),
          ),
        ),
      );

      final state = controller.getColumnState();
      expect(state.length, 2);
      expect(state[0].colId, 'name');
      expect(state[0].width, 150);
      expect(state[1].colId, 'age');
      expect(state[1].width, 80);

      controller.dispose();
    });

    testWidgets('applyColumnState restores state', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              columnDefs: const [
                OsColumnDef(field: 'name', width: 150),
                OsColumnDef(field: 'age', width: 80),
              ],
              rowData: const [
                {'name': 'Alice', 'age': 32},
              ],
            ),
          ),
        ),
      );

      final result = controller.applyColumnState(
        const ApplyColumnStateParams(
          state: [
            ColumnState(colId: 'name', width: 200),
            ColumnState(colId: 'age', hide: true),
          ],
        ),
      );
      await tester.pump();

      expect(result, true);

      final newState = controller.getColumnState();
      final nameState = newState.firstWhere((s) => s.colId == 'name');
      final ageState = newState.firstWhere((s) => s.colId == 'age');
      expect(nameState.width, 200);
      expect(ageState.hide, true);

      controller.dispose();
    });

    testWidgets('applyColumnState with applyOrder reorders columns', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              columnDefs: const [
                OsColumnDef(field: 'name'),
                OsColumnDef(field: 'age'),
                OsColumnDef(field: 'city'),
              ],
              rowData: const [
                {'name': 'Alice', 'age': 32, 'city': 'London'},
              ],
            ),
          ),
        ),
      );

      controller.applyColumnState(
        const ApplyColumnStateParams(
          state: [
            ColumnState(colId: 'city'),
            ColumnState(colId: 'name'),
            ColumnState(colId: 'age'),
          ],
          applyOrder: true,
        ),
      );
      await tester.pump();

      final displayed = controller.getAllDisplayedColumns();
      expect(displayed[0].effectiveColId, 'city');
      expect(displayed[1].effectiveColId, 'name');
      expect(displayed[2].effectiveColId, 'age');

      controller.dispose();
    });

    testWidgets('applyColumnState returns false for unmatched columns', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              columnDefs: const [OsColumnDef(field: 'name')],
              rowData: const [
                {'name': 'Alice'},
              ],
            ),
          ),
        ),
      );

      final result = controller.applyColumnState(
        const ApplyColumnStateParams(
          state: [
            ColumnState(colId: 'name'),
            ColumnState(colId: 'nonexistent'),
          ],
        ),
      );

      expect(result, false);
      controller.dispose();
    });

    testWidgets('resetColumnState clears all overrides', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              columnDefs: const [
                OsColumnDef(field: 'name', width: 150),
                OsColumnDef(field: 'age', width: 80),
              ],
              rowData: const [
                {'name': 'Alice', 'age': 32},
              ],
            ),
          ),
        ),
      );

      controller.setColumnsVisible(['age'], false);
      controller.setColumnsPinned(['name'], OsColumnPin.left);
      await tester.pump();

      controller.resetColumnState();
      await tester.pump();

      final state = controller.getColumnState();
      expect(state.every((s) => s.hide != true), true);
      expect(state.every((s) => s.pinned == null), true);

      controller.dispose();
    });
  });

  group('Column widths — widget integration', () {
    testWidgets('setColumnWidths sets widths', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();
      OsColumnResizedEvent? received;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              columnDefs: const [
                OsColumnDef(field: 'name', width: 150),
                OsColumnDef(field: 'age', width: 80),
              ],
              rowData: const [
                {'name': 'Alice', 'age': 32},
              ],
              onColumnResized: (event) => received = event,
            ),
          ),
        ),
      );

      controller.setColumnWidths([
        const ColumnWidthEntry(colId: 'name', newWidth: 250),
        const ColumnWidthEntry(colId: 'age', newWidth: 120),
      ]);
      await tester.pump();

      expect(received, isNotNull);
      expect(received!.columns.length, 2);

      final state = controller.getColumnState();
      expect(state.firstWhere((s) => s.colId == 'name').width, 250);
      expect(state.firstWhere((s) => s.colId == 'age').width, 120);

      controller.dispose();
    });

    testWidgets('setColumnWidths respects min/max constraints', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              columnDefs: const [
                OsColumnDef(
                  field: 'name',
                  width: 150,
                  minWidth: 100,
                  maxWidth: 300,
                ),
              ],
              rowData: const [
                {'name': 'Alice'},
              ],
            ),
          ),
        ),
      );

      controller.setColumnWidths([
        const ColumnWidthEntry(colId: 'name', newWidth: 50),
      ]);
      await tester.pump();

      final state = controller.getColumnState();
      expect(state.first.width, 100); // clamped to min

      controller.dispose();
    });
  });

  group('Column move — widget integration', () {
    testWidgets('moveColumnByIndex reorders columns', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();
      OsColumnMovedEvent? received;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              columnDefs: const [
                OsColumnDef(field: 'a'),
                OsColumnDef(field: 'b'),
                OsColumnDef(field: 'c'),
              ],
              rowData: const [
                {'a': 1, 'b': 2, 'c': 3},
              ],
              onColumnMoved: (event) => received = event,
            ),
          ),
        ),
      );

      controller.moveColumnByIndex(0, 2);
      await tester.pump();

      expect(received, isNotNull);
      expect(received!.toIndex, 2);

      final displayed = controller.getAllDisplayedColumns();
      expect(displayed[0].effectiveColId, 'b');
      expect(displayed[1].effectiveColId, 'c');
      expect(displayed[2].effectiveColId, 'a');

      controller.dispose();
    });

    testWidgets('moveColumns moves by colId', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();
      OsColumnMovedEvent? received;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              columnDefs: const [
                OsColumnDef(field: 'a'),
                OsColumnDef(field: 'b'),
                OsColumnDef(field: 'c'),
              ],
              rowData: const [
                {'a': 1, 'b': 2, 'c': 3},
              ],
              onColumnMoved: (event) => received = event,
            ),
          ),
        ),
      );

      controller.moveColumns(['c'], 0);
      await tester.pump();

      expect(received, isNotNull);
      expect(received!.columns, ['c']);

      final displayed = controller.getAllDisplayedColumns();
      expect(displayed[0].effectiveColId, 'c');
      expect(displayed[1].effectiveColId, 'a');
      expect(displayed[2].effectiveColId, 'b');

      controller.dispose();
    });
  });

  group('Column query — widget integration', () {
    testWidgets('getColumnDef returns column by ID', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              columnDefs: const [
                OsColumnDef(field: 'name', headerName: 'Full Name'),
                OsColumnDef(field: 'age'),
              ],
              rowData: const [
                {'name': 'Alice', 'age': 32},
              ],
            ),
          ),
        ),
      );

      final col = controller.getColumnDef('name');
      expect(col, isNotNull);
      expect(col!.headerName, 'Full Name');

      final missing = controller.getColumnDef('nonexistent');
      expect(missing, isNull);

      controller.dispose();
    });

    testWidgets('getAllDisplayedColumns excludes hidden', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              columnDefs: const [
                OsColumnDef(field: 'name'),
                OsColumnDef(field: 'age', hide: true),
              ],
              rowData: const [
                {'name': 'Alice', 'age': 32},
              ],
            ),
          ),
        ),
      );

      final displayed = controller.getAllDisplayedColumns();
      expect(displayed.length, 1);
      expect(displayed.first.effectiveColId, 'name');

      controller.dispose();
    });

    testWidgets('getDisplayedLeftColumns returns pinned left', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              columnDefs: const [
                OsColumnDef(field: 'name', pinned: OsColumnPin.left),
                OsColumnDef(field: 'age'),
              ],
              rowData: const [
                {'name': 'Alice', 'age': 32},
              ],
            ),
          ),
        ),
      );

      final left = controller.getDisplayedLeftColumns();
      expect(left.length, 1);
      expect(left.first.effectiveColId, 'name');

      final center = controller.getDisplayedCenterColumns();
      expect(center.length, 1);
      expect(center.first.effectiveColId, 'age');

      controller.dispose();
    });
  });

  group('Column state round-trip — widget integration', () {
    testWidgets('getColumnState → applyColumnState round-trips', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              columnDefs: const [
                OsColumnDef(field: 'name', width: 150),
                OsColumnDef(field: 'age', width: 80),
                OsColumnDef(field: 'city', width: 120),
              ],
              rowData: const [
                {'name': 'Alice', 'age': 32, 'city': 'London'},
              ],
            ),
          ),
        ),
      );

      // Modify state
      controller.setColumnsVisible(['age'], false);
      controller.setColumnsPinned(['name'], OsColumnPin.left);
      controller.setColumnWidths([
        const ColumnWidthEntry(colId: 'city', newWidth: 200),
      ]);
      await tester.pump();

      // Capture state
      final savedState = controller.getColumnState();

      // Reset
      controller.resetColumnState();
      await tester.pump();

      // Restore
      controller.applyColumnState(ApplyColumnStateParams(state: savedState));
      await tester.pump();

      // Verify
      final restoredState = controller.getColumnState();
      final nameState = restoredState.firstWhere((s) => s.colId == 'name');
      final ageState = restoredState.firstWhere((s) => s.colId == 'age');
      final cityState = restoredState.firstWhere((s) => s.colId == 'city');

      expect(nameState.pinned, OsColumnPin.left);
      expect(ageState.hide, true);
      expect(cityState.width, 200);

      controller.dispose();
    });
  });

  group('applyColumnState purge', () {
    testWidgets('purge clears prior width/pin/hide/sort then applies subset', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              columnDefs: const [
                OsColumnDef(field: 'name', width: 150),
                OsColumnDef(field: 'age', width: 80),
                OsColumnDef(field: 'city'),
              ],
              rowData: const [
                {'name': 'Alice', 'age': 32, 'city': 'London'},
              ],
            ),
          ),
        ),
      );

      // Establish a spread of overrides.
      controller.setColumnWidths([
        const ColumnWidthEntry(colId: 'name', newWidth: 300),
      ]);
      controller.setColumnsPinned(['age'], OsColumnPin.left);
      controller.setColumnsVisible(['city'], false);
      controller.setSortModel([
        const OsSortModel(colId: 'name', sort: OsSortDirection.descending),
      ]);
      await tester.pump();

      final result = controller.applyColumnState(
        const ApplyColumnStateParams(
          state: [ColumnState(colId: 'name', width: 120)],
          purge: true,
        ),
      );
      await tester.pump();

      expect(result, true);

      final state = {for (final s in controller.getColumnState()) s.colId: s};
      // Provided subset applied on the clean slate.
      expect(state['name']!.width, 120);
      // Everything else fell back to definition defaults.
      expect(state['age']!.width, 80);
      expect(state['age']!.pinned, isNull);
      expect(state['city']!.hide, isNot(true));
      expect(state.values.every((s) => s.sort == null), true);
      expect(controller.getSortModel(), isEmpty);
      expect(controller.isPinning(), false);
      // Order override (none set here) and display order intact.
      expect(controller.getAllDisplayedColumns().map((c) => c.effectiveColId), [
        'name',
        'age',
        'city',
      ]);

      controller.dispose();
    });

    testWidgets('without purge unrelated overrides survive (merge default)', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              columnDefs: const [
                OsColumnDef(field: 'name'),
                OsColumnDef(field: 'age'),
              ],
              rowData: const [
                {'name': 'Alice', 'age': 32},
              ],
            ),
          ),
        ),
      );

      controller.setColumnWidths([
        const ColumnWidthEntry(colId: 'name', newWidth: 300),
        const ColumnWidthEntry(colId: 'age', newWidth: 200),
      ]);
      await tester.pump();

      controller.applyColumnState(
        const ApplyColumnStateParams(
          state: [ColumnState(colId: 'name', width: 120)],
        ),
      );
      await tester.pump();

      final state = {for (final s in controller.getColumnState()) s.colId: s};
      expect(state['name']!.width, 120);
      expect(state['age']!.width, 200); // merge semantics keep it

      controller.dispose();
    });

    testWidgets('purge with null state behaves like resetColumnState', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              columnDefs: const [
                OsColumnDef(field: 'name'),
                OsColumnDef(field: 'age'),
              ],
              rowData: const [
                {'name': 'Alice', 'age': 32},
              ],
            ),
          ),
        ),
      );

      controller.setColumnsPinned(['name'], OsColumnPin.right);
      controller.setColumnWidths([
        const ColumnWidthEntry(colId: 'age', newWidth: 250),
      ]);
      await tester.pump();

      final result = controller.applyColumnState(
        const ApplyColumnStateParams(purge: true),
      );
      await tester.pump();

      expect(result, true);
      final state = controller.getColumnState();
      expect(state.every((s) => s.pinned == null), true);
      expect(state.firstWhere((s) => s.colId == 'age').width, isNull);
      expect(controller.isPinning(), false);

      controller.dispose();
    });

    testWidgets('purge re-initialises definition-hidden columns', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              columnDefs: const [
                OsColumnDef(field: 'name'),
                OsColumnDef(field: 'secret', hide: true),
              ],
              rowData: const [
                {'name': 'Alice', 'secret': 'x'},
              ],
            ),
          ),
        ),
      );
      // Guard: definition-hidden column starts hidden.
      var state = {for (final s in controller.getColumnState()) s.colId: s};
      expect(state['secret']!.hide, true);

      controller.setColumnsVisible(['name'], false);
      await tester.pump();

      controller.applyColumnState(const ApplyColumnStateParams(purge: true));
      await tester.pump();

      state = {for (final s in controller.getColumnState()) s.colId: s};
      expect(state['name']!.hide, isNot(true)); // API hide cleared
      expect(state['secret']!.hide, true); // def hide restored

      controller.dispose();
    });
  });

  group('getDisplayedColAfter / getDisplayedColBefore', () {
    Future<OsGridController<Map<String, dynamic>>> pumpPinnedGrid(
      WidgetTester tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 900,
              height: 600,
              child: OsGrid<Map<String, dynamic>>(
                controller: controller,
                columnDefs: const [
                  OsColumnDef(field: 'a', pinned: OsColumnPin.left),
                  OsColumnDef(field: 'b'),
                  OsColumnDef(field: 'c'),
                  OsColumnDef(field: 'd'),
                  OsColumnDef(field: 'e', pinned: OsColumnPin.right),
                ],
                rowData: const [
                  {'a': 1, 'b': 2, 'c': 3, 'd': 4, 'e': 5},
                ],
              ),
            ),
          ),
        ),
      );
      return controller;
    }

    testWidgets('middle column neighbours cross pin boundaries', (
      tester,
    ) async {
      final controller = await pumpPinnedGrid(tester);

      // Last left-pinned ↔ first centre column.
      expect(controller.getDisplayedColAfter('a')!.effectiveColId, 'b');
      expect(controller.getDisplayedColBefore('b')!.effectiveColId, 'a');
      // Last centre ↔ first right-pinned column.
      expect(controller.getDisplayedColAfter('d')!.effectiveColId, 'e');
      expect(controller.getDisplayedColBefore('e')!.effectiveColId, 'd');

      controller.dispose();
    });

    testWidgets('first and last displayed columns have null neighbours', (
      tester,
    ) async {
      final controller = await pumpPinnedGrid(tester);

      expect(controller.getDisplayedColBefore('a'), isNull);
      expect(controller.getDisplayedColAfter('e'), isNull);

      controller.dispose();
    });

    testWidgets('hidden columns are skipped', (tester) async {
      final controller = await pumpPinnedGrid(tester);

      controller.setColumnsVisible(['c'], false);
      await tester.pump();

      expect(controller.getDisplayedColAfter('b')!.effectiveColId, 'd');
      expect(controller.getDisplayedColBefore('d')!.effectiveColId, 'b');
      expect(controller.getDisplayedColAfter('c'), isNull);

      controller.dispose();
    });

    testWidgets('order overrides are respected', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 900,
              height: 600,
              child: OsGrid<Map<String, dynamic>>(
                controller: controller,
                columnDefs: const [
                  OsColumnDef(field: 'a'),
                  OsColumnDef(field: 'b'),
                  OsColumnDef(field: 'c'),
                  OsColumnDef(field: 'd'),
                  OsColumnDef(field: 'e'),
                ],
                rowData: const [
                  {'a': 1, 'b': 2, 'c': 3, 'd': 4, 'e': 5},
                ],
              ),
            ),
          ),
        ),
      );

      controller.moveColumns(['a'], 4); // display order b,c,d,e,a
      await tester.pump();

      expect(controller.getDisplayedColAfter('e')!.effectiveColId, 'a');
      expect(controller.getDisplayedColBefore('a')!.effectiveColId, 'e');
      expect(controller.getDisplayedColBefore('b'), isNull);

      controller.dispose();
    });

    testWidgets('unknown colId returns null in both directions', (
      tester,
    ) async {
      final controller = await pumpPinnedGrid(tester);

      expect(controller.getDisplayedColAfter('nope'), isNull);
      expect(controller.getDisplayedColBefore('nope'), isNull);

      controller.dispose();
    });

    testWidgets('returns null before a grid attaches callbacks', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();
      expect(controller.getDisplayedColAfter('a'), isNull);
      expect(controller.getDisplayedColBefore('a'), isNull);
      controller.dispose();
    });
  });

  group('paginationGetTotalRows alias', () {
    testWidgets('matches paginationGetRowCount with post-filter semantics', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();
      final rows = <Map<String, dynamic>>[
        for (int i = 0; i < 25; i++)
          {'id': i, 'name': 'Row $i', 'category': i.isEven ? 'keep' : 'skip'},
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: OsGrid<Map<String, dynamic>>(
                controller: controller,
                columnDefs: const [
                  OsColumnDef(field: 'id'),
                  OsColumnDef(field: 'name'),
                  OsColumnDef(field: 'category'),
                ],
                rowData: rows,
                pagination: const OsPagination(pageSize: 10),
              ),
            ),
          ),
        ),
      );

      // Alias identity.
      expect(controller.paginationGetTotalRows(), 25);
      expect(
        controller.paginationGetTotalRows(),
        controller.paginationGetRowCount(),
      );
      // Pagination slices the display but not the total.
      expect(controller.paginationGetTotalPages(), 3);
      expect(controller.getDisplayedRowCount(), 10);

      // Filtering shrinks the total (post-filter semantics).
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: OsGrid<Map<String, dynamic>>(
                controller: controller,
                columnDefs: const [
                  OsColumnDef(field: 'id'),
                  OsColumnDef(field: 'name'),
                  OsColumnDef(field: 'category'),
                ],
                rowData: rows,
                quickFilterText: 'keep',
                pagination: const OsPagination(pageSize: 10),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(controller.paginationGetTotalRows(), 13);
      expect(
        controller.paginationGetTotalRows(),
        controller.paginationGetRowCount(),
      );

      controller.dispose();
    });
  });

  group('Autosize double-tap — widget integration (item 42)', () {
    testWidgets('double-click on resize separator autosizes the column', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: OsGrid<Map<String, dynamic>>(
                controller: controller,
                columnDefs: const [
                  OsColumnDef(field: 'name', width: 100),
                  OsColumnDef(field: 'age', width: 100),
                ],
                rowData: const [
                  {'name': 'Alexandria', 'age': 7},
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Definition width before the interaction.
      var state = {for (final s in controller.getColumnState()) s.colId: s};
      expect(state['name']!.width, 100);

      // Separator between 'name' and 'age' sits at x=100, inside the
      // 48px header. Two taps within the double-tap window trigger the
      // autosize.
      const separator = Offset(100, 24);
      await tester.tapAt(separator);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(separator);
      await tester.pumpAndSettle();

      state = {for (final s in controller.getColumnState()) s.colId: s};
      final newWidth = state['name']!.width!;
      expect(newWidth, greaterThan(100));

      // Fits content: wide enough for the widest cell rendered with the
      // default cell text style (fontSize 14), but only padding beyond it.
      final tp = TextPainter(
        text: const TextSpan(
          text: 'Alexandria',
          style: TextStyle(fontSize: 14),
        ),
        maxLines: 1,
        textDirection: TextDirection.ltr,
      )..layout();
      expect(newWidth, greaterThanOrEqualTo(tp.width));
      expect(newWidth, lessThanOrEqualTo(tp.width + 64 + 0.01));

      controller.dispose();
    });

    testWidgets('single tap on separator does not autosize', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: OsGrid<Map<String, dynamic>>(
                controller: controller,
                columnDefs: const [
                  OsColumnDef(field: 'name', width: 100),
                  OsColumnDef(field: 'age', width: 100),
                ],
                rowData: const [
                  {'name': 'Alexandria', 'age': 7},
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(100, 24));
      // Past the double-tap timeout so a second tap would start a new pair.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      final state = {for (final s in controller.getColumnState()) s.colId: s};
      expect(state['name']!.width, 100);

      controller.dispose();
    });
  });

  group('Autosize measurement cache & batch (item 42)', () {
    late OsGridController<Map<String, dynamic>> controller;
    late List<OsColumnDef> columns;
    var rows = <Map<String, dynamic>>[];
    late ColumnApiCoordinator<Map<String, dynamic>> coordinator;

    ColumnApiCoordinator<Map<String, dynamic>> buildCoordinator() {
      return ColumnApiCoordinator<Map<String, dynamic>>(
        controller: controller,
        allFlatColumns: () => columns,
        syntheticOffset: () => 0,
        resolveRows: () => rows,
        resolveCellValue: (col, row, _) => row[col.field],
        clearTextCacheFor: (_) {},
        setSortModel: (_) {},
        clearSort: () {},
        invalidateDeltaSort: () {},
        resetLegacySortIndex: () {},
        emitSortChanged: () {},
        reprocess: () {},
        initHiddenFromDefs: () {},
        notifyStateChanged: (_) {},
        mutate: (fn) => fn(),
        headerTextStyle: () => const TextStyle(fontSize: 10),
        cellTextStyle: () => const TextStyle(fontSize: 10),
        textScaler: () => TextScaler.noScaling,
        onColumnVisible: null,
        onColumnPinned: null,
        onColumnResized: null,
        onColumnMoved: null,
      );
    }

    setUp(() {
      controller = OsGridController<Map<String, dynamic>>();
      rows = [
        {'a': 'ww', 'b': null, 'c': null, 'd': 'x'},
        {'a': 'www', 'b': 12345, 'c': null, 'd': 'y'},
      ];
      columns = const [
        OsColumnDef(field: 'a'),
        OsColumnDef(field: 'b'),
        OsColumnDef(field: 'c'),
        OsColumnDef(field: 'd'),
      ];
      coordinator = buildCoordinator();
    });

    tearDown(() {
      coordinator.dispose();
      controller.dispose();
    });

    test('autosize caches measurement — second call performs no layouts', () {
      coordinator.autosize(0);
      final afterFirst = coordinator.autosizeLayoutCount;
      expect(afterFirst, greaterThan(0));

      coordinator.autosize(0);
      expect(coordinator.autosizeLayoutCount, afterFirst);

      // Width fits content under deterministic Ahem metrics:
      // widest of header 'a' (10) and cells 'ww'/'www' (20/30) is 30,
      // plus the fixed 64px chrome padding.
      expect(coordinator.widths['a'], 30 + 64);
    });

    test('new row data list instance forces re-measurement', () {
      coordinator.autosize(0);
      final baseline = coordinator.autosizeLayoutCount;

      rows = [
        {'a': 'ww', 'b': null, 'c': null, 'd': 'x'},
        {'a': 'www', 'b': 12345, 'c': null, 'd': 'y'},
      ]; // same content, new instance
      coordinator.autosize(0);

      expect(coordinator.autosizeLayoutCount, greaterThan(baseline));
    });

    test(
      'controller data-change events invalidate cached measurements',
      () async {
        coordinator.autosize(0);
        final baseline = coordinator.autosizeLayoutCount;

        // Keep the same list instance so identity checks alone cannot
        // invalidate; the onRowDataUpdated subscription must do it.
        final sameList = rows;
        controller.setRowData(sameList);
        await Future<void>.delayed(Duration.zero);

        sameList[0]['a'] = 'much longer value';
        coordinator.autosize(0);

        expect(coordinator.autosizeLayoutCount, greaterThan(baseline));
        expect(coordinator.widths['a'], 'much longer value'.length * 10 + 64);
      },
    );

    test('autosizeAll measures all visible columns in one pass', () {
      coordinator.hiddenIds.add('d');

      coordinator.autosizeAll();

      // Per-column expected widths: widest of header/cell Ahem widths
      // plus the 64px chrome padding, clamped to [minWidth, maxWidth].
      expect(coordinator.widths['a'], 30 + 64); // cell-driven
      expect(coordinator.widths['b'], 50 + 64); // cell-driven
      expect(coordinator.widths['c'], 10 + 64); // header-only (all null)
      expect(coordinator.widths.containsKey('d'), isFalse); // hidden skipped
    });

    test('autosizeAll respects column min/max constraints', () {
      columns = const [OsColumnDef(field: 'a', minWidth: 500, maxWidth: 600)];

      coordinator.autosizeAll();

      // Content width 30+64=94 clamps up to minWidth 500.
      expect(coordinator.widths['a'], 500);
    });
  });
}
