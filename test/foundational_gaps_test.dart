import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

void main() {
  // =========================================================================
  // 1. ColumnState sort/sortIndex fields
  // =========================================================================
  group('ColumnState sort fields', () {
    test('ColumnState includes sort and sortIndex in toJson', () {
      const state = ColumnState(
        colId: 'name',
        sort: OsSortDirection.ascending,
        sortIndex: 0,
      );
      final json = state.toJson();
      expect(json['sort'], 'asc');
      expect(json['sortIndex'], 0);
    });

    test('ColumnState includes descending sort in toJson', () {
      const state = ColumnState(
        colId: 'age',
        sort: OsSortDirection.descending,
        sortIndex: 1,
      );
      final json = state.toJson();
      expect(json['sort'], 'desc');
      expect(json['sortIndex'], 1);
    });

    test('ColumnState omits sort fields when null', () {
      const state = ColumnState(colId: 'name', width: 100);
      final json = state.toJson();
      expect(json.containsKey('sort'), isFalse);
      expect(json.containsKey('sortIndex'), isFalse);
    });

    test('ColumnState fromJson parses sort fields', () {
      final state = ColumnState.fromJson({
        'colId': 'price',
        'sort': 'desc',
        'sortIndex': 2,
      });
      expect(state.sort, OsSortDirection.descending);
      expect(state.sortIndex, 2);
    });

    test('ColumnState fromJson handles missing sort fields', () {
      final state = ColumnState.fromJson({'colId': 'name', 'width': 150});
      expect(state.sort, isNull);
      expect(state.sortIndex, isNull);
    });

    test('ColumnState round-trips with sort fields', () {
      const original = ColumnState(
        colId: 'price',
        hide: false,
        width: 120,
        sort: OsSortDirection.ascending,
        sortIndex: 0,
        pinned: OsColumnPin.left,
      );
      final json = original.toJson();
      final restored = ColumnState.fromJson(json);
      expect(restored.sort, OsSortDirection.ascending);
      expect(restored.sortIndex, 0);
      expect(restored.pinned, OsColumnPin.left);
      expect(restored.width, 120);
    });

    test('ColumnState equality includes sort fields', () {
      const a = ColumnState(
        colId: 'x',
        sort: OsSortDirection.ascending,
        sortIndex: 0,
      );
      const b = ColumnState(
        colId: 'x',
        sort: OsSortDirection.ascending,
        sortIndex: 0,
      );
      const c = ColumnState(
        colId: 'x',
        sort: OsSortDirection.descending,
        sortIndex: 0,
      );
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('ColumnState copyWith handles sort fields', () {
      const state = ColumnState(
        colId: 'x',
        sort: OsSortDirection.ascending,
        sortIndex: 0,
      );
      final copy = state.copyWith(
        sort: OsSortDirection.descending,
        sortIndex: 1,
      );
      expect(copy.sort, OsSortDirection.descending);
      expect(copy.sortIndex, 1);
    });

    test('ColumnState copyWith clearSort removes sort', () {
      const state = ColumnState(
        colId: 'x',
        sort: OsSortDirection.ascending,
        sortIndex: 0,
      );
      final copy = state.copyWith(clearSort: true, clearSortIndex: true);
      expect(copy.sort, isNull);
      expect(copy.sortIndex, isNull);
    });
  });

  // =========================================================================
  // 2. sortingOrder on OsColumnDef
  // =========================================================================
  group('SortService sortingOrder', () {
    late SortService<Map<String, dynamic>> service;

    setUp(() {
      service = SortService<Map<String, dynamic>>();
    });

    test('default cycle: asc -> desc -> clear', () {
      service.progressSort(colId: 'name', multiSort: false);
      expect(service.getSortDirection('name'), OsSortDirection.ascending);

      service.progressSort(colId: 'name', multiSort: false);
      expect(service.getSortDirection('name'), OsSortDirection.descending);

      service.progressSort(colId: 'name', multiSort: false);
      expect(service.getSortDirection('name'), isNull);
    });

    test('custom sortingOrder skips clear state', () {
      final order = [OsSortDirection.ascending, OsSortDirection.descending];

      service.progressSort(
        colId: 'name',
        multiSort: false,
        sortingOrder: order,
      );
      expect(service.getSortDirection('name'), OsSortDirection.ascending);

      service.progressSort(
        colId: 'name',
        multiSort: false,
        sortingOrder: order,
      );
      expect(service.getSortDirection('name'), OsSortDirection.descending);

      // Should cycle back to ascending (no clear)
      service.progressSort(
        colId: 'name',
        multiSort: false,
        sortingOrder: order,
      );
      expect(service.getSortDirection('name'), OsSortDirection.ascending);
    });

    test('custom sortingOrder starts with descending', () {
      final order = [
        OsSortDirection.descending,
        OsSortDirection.ascending,
        null,
      ];

      service.progressSort(
        colId: 'price',
        multiSort: false,
        sortingOrder: order,
      );
      expect(service.getSortDirection('price'), OsSortDirection.descending);

      service.progressSort(
        colId: 'price',
        multiSort: false,
        sortingOrder: order,
      );
      expect(service.getSortDirection('price'), OsSortDirection.ascending);

      service.progressSort(
        colId: 'price',
        multiSort: false,
        sortingOrder: order,
      );
      expect(service.getSortDirection('price'), isNull);
    });

    test('sortingOrder with only descending and clear', () {
      final order = [OsSortDirection.descending, null];

      service.progressSort(colId: 'x', multiSort: false, sortingOrder: order);
      expect(service.getSortDirection('x'), OsSortDirection.descending);

      service.progressSort(colId: 'x', multiSort: false, sortingOrder: order);
      expect(service.getSortDirection('x'), isNull);
      expect(service.sortModel, isEmpty);
    });

    test('sortingOrder works with multiSort', () {
      final order = [OsSortDirection.ascending, OsSortDirection.descending];

      service.progressSort(colId: 'a', multiSort: false);
      service.progressSort(colId: 'b', multiSort: true, sortingOrder: order);
      expect(service.sortModel.length, 2);
      expect(service.getSortDirection('b'), OsSortDirection.ascending);

      // Cycle b: asc -> desc (no clear because order has no null)
      service.progressSort(colId: 'b', multiSort: true, sortingOrder: order);
      expect(service.getSortDirection('b'), OsSortDirection.descending);
      expect(service.sortModel.length, 2);
    });
  });

  // =========================================================================
  // 3. sort/initialSort/sortIndex on OsColumnDef
  // =========================================================================
  group('OsColumnDef sort properties', () {
    test('OsColumnDef accepts sort property', () {
      const col = OsColumnDef(
        field: 'name',
        sortable: true,
        sort: OsSortDirection.ascending,
      );
      expect(col.sort, OsSortDirection.ascending);
    });

    test('OsColumnDef accepts initialSort property', () {
      const col = OsColumnDef(
        field: 'name',
        sortable: true,
        initialSort: OsSortDirection.descending,
      );
      expect(col.initialSort, OsSortDirection.descending);
    });

    test('OsColumnDef accepts sortIndex property', () {
      const col = OsColumnDef(
        field: 'name',
        sortable: true,
        sort: OsSortDirection.ascending,
        sortIndex: 0,
      );
      expect(col.sortIndex, 0);
    });

    test('OsColumnDef accepts sortingOrder property', () {
      const col = OsColumnDef(
        field: 'name',
        sortable: true,
        sortingOrder: [OsSortDirection.descending, OsSortDirection.ascending],
      );
      expect(col.sortingOrder, hasLength(2));
      expect(col.sortingOrder![0], OsSortDirection.descending);
    });
  });

  // =========================================================================
  // 3b. Per-column sort applied during grid init (widget test)
  // =========================================================================
  group('Per-column initial sort in grid', () {
    testWidgets('per-column sort is applied when no grid-level initialSort', (
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
                columnDefs: [
                  const OsColumnDef(
                    field: 'name',
                    sortable: true,
                    sort: OsSortDirection.descending,
                    sortIndex: 1,
                  ),
                  const OsColumnDef(
                    field: 'age',
                    sortable: true,
                    sort: OsSortDirection.ascending,
                    sortIndex: 0,
                  ),
                ],
                rowData: [
                  {'name': 'Alice', 'age': 30},
                  {'name': 'Bob', 'age': 25},
                  {'name': 'Charlie', 'age': 35},
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final sortModel = controller.getSortModel();
      expect(sortModel.length, 2);
      // age has sortIndex 0, so it's primary
      expect(sortModel[0].colId, 'age');
      expect(sortModel[0].sort, OsSortDirection.ascending);
      // name has sortIndex 1, so it's secondary
      expect(sortModel[1].colId, 'name');
      expect(sortModel[1].sort, OsSortDirection.descending);
    });

    testWidgets(
      'grid-level initialSort takes precedence over per-column sort',
      (tester) async {
        final controller = OsGridController<Map<String, dynamic>>();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 800,
                height: 600,
                child: OsGrid<Map<String, dynamic>>(
                  controller: controller,
                  initialSort: [
                    const OsSortModel(
                      colId: 'name',
                      sort: OsSortDirection.ascending,
                    ),
                  ],
                  columnDefs: [
                    const OsColumnDef(
                      field: 'name',
                      sortable: true,
                      sort: OsSortDirection.descending, // should be ignored
                    ),
                    const OsColumnDef(field: 'age', sortable: true),
                  ],
                  rowData: [
                    {'name': 'Alice', 'age': 30},
                    {'name': 'Bob', 'age': 25},
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final sortModel = controller.getSortModel();
        expect(sortModel.length, 1);
        expect(sortModel[0].colId, 'name');
        // Grid-level says ascending, per-column says descending — grid wins
        expect(sortModel[0].sort, OsSortDirection.ascending);
      },
    );

    testWidgets('initialSort on colDef is alias for sort', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: OsGrid<Map<String, dynamic>>(
                controller: controller,
                columnDefs: [
                  const OsColumnDef(
                    field: 'name',
                    sortable: true,
                    initialSort: OsSortDirection.ascending,
                  ),
                  const OsColumnDef(field: 'age', sortable: true),
                ],
                rowData: [
                  {'name': 'Bob', 'age': 25},
                  {'name': 'Alice', 'age': 30},
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final sortModel = controller.getSortModel();
      expect(sortModel.length, 1);
      expect(sortModel[0].colId, 'name');
      expect(sortModel[0].sort, OsSortDirection.ascending);
    });
  });

  // =========================================================================
  // 3c. getColumnState includes sort, applyColumnState sets sort
  // =========================================================================
  group('getColumnState/applyColumnState with sort', () {
    testWidgets('getColumnState includes sort state', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: OsGrid<Map<String, dynamic>>(
                controller: controller,
                initialSort: [
                  const OsSortModel(
                    colId: 'name',
                    sort: OsSortDirection.ascending,
                  ),
                  const OsSortModel(
                    colId: 'age',
                    sort: OsSortDirection.descending,
                  ),
                ],
                columnDefs: [
                  const OsColumnDef(field: 'name', sortable: true),
                  const OsColumnDef(field: 'age', sortable: true),
                ],
                rowData: [
                  {'name': 'Alice', 'age': 30},
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final state = controller.getColumnState();
      expect(state.length, 2);

      final nameState = state.firstWhere((s) => s.colId == 'name');
      expect(nameState.sort, OsSortDirection.ascending);
      expect(nameState.sortIndex, 0);

      final ageState = state.firstWhere((s) => s.colId == 'age');
      expect(ageState.sort, OsSortDirection.descending);
      expect(ageState.sortIndex, 1);
    });

    testWidgets('applyColumnState sets sort state', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: OsGrid<Map<String, dynamic>>(
                controller: controller,
                columnDefs: [
                  const OsColumnDef(field: 'name', sortable: true),
                  const OsColumnDef(field: 'age', sortable: true),
                  const OsColumnDef(field: 'city', sortable: true),
                ],
                rowData: [
                  {'name': 'Alice', 'age': 30, 'city': 'London'},
                  {'name': 'Bob', 'age': 25, 'city': 'Paris'},
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially no sort
      expect(controller.getSortModel(), isEmpty);

      // Apply column state with sort
      controller.applyColumnState(
        const ApplyColumnStateParams(
          state: [
            ColumnState(
              colId: 'age',
              sort: OsSortDirection.descending,
              sortIndex: 0,
            ),
            ColumnState(
              colId: 'name',
              sort: OsSortDirection.ascending,
              sortIndex: 1,
            ),
            ColumnState(colId: 'city'),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final sortModel = controller.getSortModel();
      expect(sortModel.length, 2);
      expect(sortModel[0].colId, 'age');
      expect(sortModel[0].sort, OsSortDirection.descending);
      expect(sortModel[1].colId, 'name');
      expect(sortModel[1].sort, OsSortDirection.ascending);
    });

    testWidgets('applyColumnState clears sort when no sort in state', (
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
                initialSort: [
                  const OsSortModel(
                    colId: 'name',
                    sort: OsSortDirection.ascending,
                  ),
                ],
                columnDefs: [
                  const OsColumnDef(field: 'name', sortable: true),
                  const OsColumnDef(field: 'age', sortable: true),
                ],
                rowData: [
                  {'name': 'Alice', 'age': 30},
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(controller.getSortModel(), isNotEmpty);

      // Apply state without sort — should clear sort
      controller.applyColumnState(
        const ApplyColumnStateParams(
          state: [
            ColumnState(colId: 'name', width: 200),
            ColumnState(colId: 'age', width: 100),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(controller.getSortModel(), isEmpty);
    });

    testWidgets('getColumnState serialises sort to JSON correctly', (
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
                initialSort: [
                  const OsSortModel(
                    colId: 'name',
                    sort: OsSortDirection.ascending,
                  ),
                ],
                columnDefs: [const OsColumnDef(field: 'name', sortable: true)],
                rowData: [
                  {'name': 'Alice'},
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final state = controller.getColumnState();
      final json = state.first.toJson();
      expect(json['sort'], 'asc');
      expect(json['sortIndex'], 0);
    });
  });

  // =========================================================================
  // 4. lockVisible and lockPinned
  // =========================================================================
  group('lockVisible and lockPinned', () {
    test('OsColumnDef accepts lockVisible property', () {
      const col = OsColumnDef(field: 'name', lockVisible: true);
      expect(col.lockVisible, true);
    });

    test('OsColumnDef accepts lockPinned property', () {
      const col = OsColumnDef(field: 'name', lockPinned: true);
      expect(col.lockPinned, true);
    });

    test('lockVisible defaults to null', () {
      const col = OsColumnDef(field: 'name');
      expect(col.lockVisible, isNull);
    });

    test('lockPinned defaults to null', () {
      const col = OsColumnDef(field: 'name');
      expect(col.lockPinned, isNull);
    });

    testWidgets('lockVisible prevents hiding via setColumnsVisible', (
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
                columnDefs: [
                  const OsColumnDef(field: 'name', lockVisible: true),
                  const OsColumnDef(field: 'age'),
                ],
                rowData: [
                  {'name': 'Alice', 'age': 30},
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Try to hide the locked column
      controller.setColumnsVisible(['name'], false);
      await tester.pumpAndSettle();

      // name should still be visible (lockVisible prevents hiding)
      final state = controller.getColumnState();
      final nameState = state.firstWhere((s) => s.colId == 'name');
      expect(nameState.hide, isNot(true));
    });

    testWidgets('lockVisible allows hiding non-locked columns', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: OsGrid<Map<String, dynamic>>(
                controller: controller,
                columnDefs: [
                  const OsColumnDef(field: 'name', lockVisible: true),
                  const OsColumnDef(field: 'age'),
                ],
                rowData: [
                  {'name': 'Alice', 'age': 30},
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Hide the non-locked column
      controller.setColumnsVisible(['age'], false);
      await tester.pumpAndSettle();

      final state = controller.getColumnState();
      final ageState = state.firstWhere((s) => s.colId == 'age');
      expect(ageState.hide, true);
    });

    testWidgets('lockPinned prevents pinning via setColumnsPinned', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();
      final events = <OsColumnPinnedEvent>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: OsGrid<Map<String, dynamic>>(
                controller: controller,
                onColumnPinned: events.add,
                columnDefs: [
                  const OsColumnDef(field: 'name', lockPinned: true),
                  const OsColumnDef(field: 'age'),
                ],
                rowData: [
                  {'name': 'Alice', 'age': 30},
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Try to pin the locked column
      controller.setColumnsPinned(['name'], OsColumnPin.left);
      await tester.pumpAndSettle();

      // No event should fire (column was filtered out)
      expect(events, isEmpty);

      // name should not be pinned
      final state = controller.getColumnState();
      final nameState = state.firstWhere((s) => s.colId == 'name');
      expect(nameState.pinned, isNull);
    });

    testWidgets('lockPinned allows pinning non-locked columns', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: OsGrid<Map<String, dynamic>>(
                controller: controller,
                columnDefs: [
                  const OsColumnDef(field: 'name', lockPinned: true),
                  const OsColumnDef(field: 'age'),
                ],
                rowData: [
                  {'name': 'Alice', 'age': 30},
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Pin the non-locked column
      controller.setColumnsPinned(['age'], OsColumnPin.left);
      await tester.pumpAndSettle();

      final state = controller.getColumnState();
      final ageState = state.firstWhere((s) => s.colId == 'age');
      expect(ageState.pinned, OsColumnPin.left);
    });

    testWidgets('mixed lock: only non-locked columns are affected', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();
      final events = <OsColumnVisibleEvent>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: OsGrid<Map<String, dynamic>>(
                controller: controller,
                onColumnVisible: events.add,
                columnDefs: [
                  const OsColumnDef(field: 'name', lockVisible: true),
                  const OsColumnDef(field: 'age'),
                  const OsColumnDef(field: 'city'),
                ],
                rowData: [
                  {'name': 'Alice', 'age': 30, 'city': 'London'},
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Try to hide all three columns
      controller.setColumnsVisible(['name', 'age', 'city'], false);
      await tester.pumpAndSettle();

      // Only age and city should be hidden
      expect(events.length, 1);
      expect(events.first.columns, containsAll(['age', 'city']));
      expect(events.first.columns, isNot(contains('name')));
    });
  });

  // =========================================================================
  // 5. paginationAutoPageSize
  // =========================================================================
  group('paginationAutoPageSize', () {
    test('OsPagination accepts paginationAutoPageSize', () {
      const pagination = OsPagination(paginationAutoPageSize: true);
      expect(pagination.paginationAutoPageSize, true);
    });

    test('paginationAutoPageSize defaults to false', () {
      const pagination = OsPagination();
      expect(pagination.paginationAutoPageSize, false);
    });

    testWidgets('auto page size calculates from viewport height', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();
      // Create a grid with known dimensions
      // Grid height: 600, header: 48, pagination footer: ~48
      // Available: 600 - 48 - 48 = 504
      // Row height: 42 (default)
      // Expected page size: floor(504 / 42) = 12
      final rows = List.generate(50, (i) => {'name': 'Row $i', 'age': i});

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: OsGrid<Map<String, dynamic>>(
                controller: controller,
                pagination: const OsPagination(paginationAutoPageSize: true),
                columnDefs: [
                  const OsColumnDef(field: 'name'),
                  const OsColumnDef(field: 'age'),
                ],
                rowData: rows,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The auto page size should be calculated based on viewport
      // Exact value depends on layout, but should be > 0 and < 50
      final pageSize = controller.paginationGetPageSize();
      expect(pageSize, greaterThan(0));
      expect(pageSize, lessThan(50));
    });
  });

  // =========================================================================
  // 6. accentedSort locale collation
  // =========================================================================
  group('accentedSort', () {
    late SortService<Map<String, dynamic>> service;

    setUp(() {
      service = SortService<Map<String, dynamic>>();
      service.accentedSort = true;
    });

    test('accentedSort treats uppercase and lowercase as equal', () {
      final columns = [const OsColumnDef(field: 'name', sortable: true)];
      service.progressSort(colId: 'name', multiSort: false);

      final data = [
        {'name': 'banana'},
        {'name': 'Apple'},
        {'name': 'cherry'},
      ];

      final sorted = service.sortData(data: data, columns: columns);
      // Case-insensitive: Apple, banana, cherry
      expect(sorted[0]['name'], 'Apple');
      expect(sorted[1]['name'], 'banana');
      expect(sorted[2]['name'], 'cherry');
    });

    test('accentedSort uses case-sensitive tiebreaker', () {
      final columns = [const OsColumnDef(field: 'name', sortable: true)];
      service.progressSort(colId: 'name', multiSort: false);

      final data = [
        {'name': 'banana'},
        {'name': 'Banana'},
      ];

      final sorted = service.sortData(data: data, columns: columns);
      // Both are equal case-insensitively, tiebreaker uses case-sensitive
      // 'B' < 'b' in ASCII, so 'Banana' comes first
      expect(sorted[0]['name'], 'Banana');
      expect(sorted[1]['name'], 'banana');
    });

    test('accentedSort handles accented characters', () {
      final columns = [const OsColumnDef(field: 'name', sortable: true)];
      service.progressSort(colId: 'name', multiSort: false);

      final data = [
        {'name': 'éclair'},
        {'name': 'apple'},
        {'name': 'Éclair'},
      ];

      final sorted = service.sortData(data: data, columns: columns);
      // 'apple' < 'éclair'/'Éclair' (case-insensitive)
      expect(sorted[0]['name'], 'apple');
      // Both éclairs are equal case-insensitively
      // Tiebreaker: 'Éclair' < 'éclair' (uppercase first)
      expect(sorted[1]['name'], 'Éclair');
      expect(sorted[2]['name'], 'éclair');
    });

    test('non-accentedSort uses strict string comparison', () {
      service.accentedSort = false;
      final columns = [const OsColumnDef(field: 'name', sortable: true)];
      service.progressSort(colId: 'name', multiSort: false);

      final data = [
        {'name': 'banana'},
        {'name': 'Apple'},
        {'name': 'cherry'},
      ];

      final sorted = service.sortData(data: data, columns: columns);
      // Strict comparison: 'A' < 'b' < 'c' (uppercase letters first)
      expect(sorted[0]['name'], 'Apple');
      expect(sorted[1]['name'], 'banana');
      expect(sorted[2]['name'], 'cherry');
    });
  });
}
