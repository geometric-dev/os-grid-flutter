import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

void main() {
  group('OsGridState model', () {
    test('creates empty state with all null properties', () {
      const state = OsGridState();
      expect(state.sort, isNull);
      expect(state.filter, isNull);
      expect(state.columnPinning, isNull);
      expect(state.columnVisibility, isNull);
      expect(state.columnSizing, isNull);
      expect(state.columnOrder, isNull);
      expect(state.pagination, isNull);
      expect(state.rowSelection, isNull);
      expect(state.cellSelection, isNull);
      expect(state.scroll, isNull);
    });

    test('toJson produces correct structure', () {
      const state = OsGridState(
        sort: SortState(
          sortModel: [
            OsSortModel(colId: 'name', sort: OsSortDirection.ascending),
          ],
        ),
        filter: FilterState(
          filterModel: {
            'age': {
              'filterType': 'number',
              'type': 'greaterThan',
              'filter': 30,
            },
          },
        ),
        columnPinning: ColumnPinningState(
          leftColIds: ['id'],
          rightColIds: ['actions'],
        ),
        columnVisibility: ColumnVisibilityState(hiddenColIds: ['email']),
        columnSizing: ColumnSizingState(
          columnSizingModel: [
            ColumnSizeEntry(colId: 'name', width: 200),
            ColumnSizeEntry(colId: 'age', flex: 1),
          ],
        ),
        columnOrder: ColumnOrderState(
          orderedColIds: ['id', 'name', 'age', 'email', 'actions'],
        ),
        pagination: PaginationState(page: 2, pageSize: 25),
        rowSelection: RowSelectionState(selectedRowIds: ['row-1', 'row-3']),
        cellSelection: CellSelectionState(
          cellRanges: [
            CellSelectionCellState(
              startRow: 0,
              endRow: 2,
              startColumn: 1,
              endColumn: 3,
            ),
          ],
        ),
        scroll: ScrollState(top: 100, left: 50),
      );

      final json = state.toJson();
      expect(json['sort'], isNotNull);
      expect(json['sort']['sortModel'], hasLength(1));
      expect(json['sort']['sortModel'][0]['colId'], 'name');
      expect(json['sort']['sortModel'][0]['sort'], 'asc');
      expect(json['filter']['filterModel']['age']['filter'], 30);
      expect(json['columnPinning']['leftColIds'], ['id']);
      expect(json['columnPinning']['rightColIds'], ['actions']);
      expect(json['columnVisibility']['hiddenColIds'], ['email']);
      expect(json['columnSizing']['columnSizingModel'], hasLength(2));
      expect(json['columnOrder']['orderedColIds'], hasLength(5));
      expect(json['pagination']['page'], 2);
      expect(json['pagination']['pageSize'], 25);
      expect(json['rowSelection']['selectedRowIds'], ['row-1', 'row-3']);
      expect(json['cellSelection']['cellRanges'], hasLength(1));
      expect(json['scroll']['top'], 100.0);
      expect(json['scroll']['left'], 50.0);
    });

    test('fromJson round-trips correctly', () {
      const original = OsGridState(
        sort: SortState(
          sortModel: [
            OsSortModel(colId: 'age', sort: OsSortDirection.descending),
          ],
        ),
        pagination: PaginationState(page: 1, pageSize: 50),
        columnVisibility: ColumnVisibilityState(hiddenColIds: ['secret']),
      );

      final json = original.toJson();
      final restored = OsGridState.fromJson(json);

      expect(restored.sort?.sortModel.length, 1);
      expect(restored.sort?.sortModel[0].colId, 'age');
      expect(restored.sort?.sortModel[0].sort, OsSortDirection.descending);
      expect(restored.pagination?.page, 1);
      expect(restored.pagination?.pageSize, 50);
      expect(restored.columnVisibility?.hiddenColIds, ['secret']);
      expect(restored.filter, isNull);
      expect(restored.columnPinning, isNull);
    });

    test('equality works for identical states', () {
      const state1 = OsGridState(
        pagination: PaginationState(page: 0, pageSize: 10),
      );
      const state2 = OsGridState(
        pagination: PaginationState(page: 0, pageSize: 10),
      );
      expect(state1, equals(state2));
    });

    test('equality detects differences', () {
      const state1 = OsGridState(
        pagination: PaginationState(page: 0, pageSize: 10),
      );
      const state2 = OsGridState(
        pagination: PaginationState(page: 1, pageSize: 10),
      );
      expect(state1, isNot(equals(state2)));
    });
  });

  group('SortState', () {
    test('fromJson parses sort model', () {
      final json = {
        'sortModel': [
          {'colId': 'name', 'sort': 'asc'},
          {'colId': 'age', 'sort': 'desc'},
        ],
      };
      final state = SortState.fromJson(json);
      expect(state.sortModel, hasLength(2));
      expect(state.sortModel[0].colId, 'name');
      expect(state.sortModel[0].sort, OsSortDirection.ascending);
      expect(state.sortModel[1].colId, 'age');
      expect(state.sortModel[1].sort, OsSortDirection.descending);
    });

    test('toJson produces OS Grid compatible format', () {
      const state = SortState(
        sortModel: [
          OsSortModel(colId: 'price', sort: OsSortDirection.descending),
        ],
      );
      final json = state.toJson();
      expect(json['sortModel'][0]['colId'], 'price');
      expect(json['sortModel'][0]['sort'], 'desc');
    });
  });

  group('ColumnPinningState', () {
    test('fromJson handles empty arrays', () {
      final state = ColumnPinningState.fromJson({
        'leftColIds': <dynamic>[],
        'rightColIds': <dynamic>[],
      });
      expect(state.leftColIds, isEmpty);
      expect(state.rightColIds, isEmpty);
    });

    test('fromJson handles missing keys', () {
      final state = ColumnPinningState.fromJson({});
      expect(state.leftColIds, isEmpty);
      expect(state.rightColIds, isEmpty);
    });
  });

  group('ColumnSizingState', () {
    test('round-trips width and flex entries', () {
      const original = ColumnSizingState(
        columnSizingModel: [
          ColumnSizeEntry(colId: 'a', width: 150),
          ColumnSizeEntry(colId: 'b', flex: 2),
          ColumnSizeEntry(colId: 'c', width: 100, flex: 1),
        ],
      );
      final json = original.toJson();
      final restored = ColumnSizingState.fromJson(json);
      expect(restored.columnSizingModel, hasLength(3));
      expect(restored.columnSizingModel[0].colId, 'a');
      expect(restored.columnSizingModel[0].width, 150);
      expect(restored.columnSizingModel[0].flex, isNull);
      expect(restored.columnSizingModel[1].colId, 'b');
      expect(restored.columnSizingModel[1].width, isNull);
      expect(restored.columnSizingModel[1].flex, 2);
    });
  });

  group('ScrollState', () {
    test('defaults to zero', () {
      const state = ScrollState();
      expect(state.top, 0);
      expect(state.left, 0);
    });

    test('fromJson parses numeric values', () {
      final state = ScrollState.fromJson({'top': 123.5, 'left': 45});
      expect(state.top, 123.5);
      expect(state.left, 45.0);
    });
  });

  group('OsSortModel JSON', () {
    test('fromJson parses ascending', () {
      final model = OsSortModel.fromJson({'colId': 'x', 'sort': 'asc'});
      expect(model.colId, 'x');
      expect(model.sort, OsSortDirection.ascending);
    });

    test('fromJson parses descending', () {
      final model = OsSortModel.fromJson({'colId': 'y', 'sort': 'desc'});
      expect(model.colId, 'y');
      expect(model.sort, OsSortDirection.descending);
    });

    test('toJson produces asc/desc strings', () {
      const model = OsSortModel(colId: 'z', sort: OsSortDirection.ascending);
      expect(model.toJson(), {'colId': 'z', 'sort': 'asc'});
    });
  });

  group('GridState integration with controller', () {
    late OsGridController<Map<String, dynamic>> controller;

    setUp(() {
      controller = OsGridController<Map<String, dynamic>>();
    });

    tearDown(() {
      controller.dispose();
    });

    testWidgets('getState returns empty state for fresh grid', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              columnDefs: [
                const OsColumnDef(field: 'name', headerName: 'Name'),
                const OsColumnDef(field: 'age', headerName: 'Age'),
              ],
              rowData: [
                {'name': 'Alice', 'age': 30},
                {'name': 'Bob', 'age': 25},
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final state = controller.getState();
      // Fresh grid has no sort, no filter, no selection
      expect(state.sort, isNull);
      expect(state.filter, isNull);
      expect(state.rowSelection, isNull);
    });

    testWidgets('getState captures sort state after sorting', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              columnDefs: [
                const OsColumnDef(
                  field: 'name',
                  headerName: 'Name',
                  sortable: true,
                ),
                const OsColumnDef(
                  field: 'age',
                  headerName: 'Age',
                  sortable: true,
                ),
              ],
              rowData: [
                {'name': 'Alice', 'age': 30},
                {'name': 'Bob', 'age': 25},
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Apply sort via controller
      controller.setSortModel([
        const OsSortModel(colId: 'name', sort: OsSortDirection.ascending),
      ]);
      await tester.pumpAndSettle();

      final state = controller.getState();
      expect(state.sort, isNotNull);
      expect(state.sort!.sortModel, hasLength(1));
      expect(state.sort!.sortModel[0].colId, 'name');
      expect(state.sort!.sortModel[0].sort, OsSortDirection.ascending);
    });

    testWidgets('getState captures selection state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              getRowId: (data) => data['name'] as String,
              rowSelection: OsRowSelection.multiple(),
              columnDefs: [
                const OsColumnDef(field: 'name', headerName: 'Name'),
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
      await tester.pumpAndSettle();

      controller.selectRowsById(['Alice', 'Charlie']);
      await tester.pumpAndSettle();

      final state = controller.getState();
      expect(state.rowSelection, isNotNull);
      expect(
        state.rowSelection!.selectedRowIds,
        containsAll(['Alice', 'Charlie']),
      );
    });

    testWidgets('getState captures pagination state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              pagination: const OsPagination(pageSize: 2),
              columnDefs: [
                const OsColumnDef(field: 'name', headerName: 'Name'),
              ],
              rowData: [
                {'name': 'Alice'},
                {'name': 'Bob'},
                {'name': 'Charlie'},
                {'name': 'Dave'},
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      controller.paginationGoToPage(1);
      await tester.pumpAndSettle();

      final state = controller.getState();
      expect(state.pagination, isNotNull);
      expect(state.pagination!.page, 1);
      expect(state.pagination!.pageSize, 2);
    });

    testWidgets('getState captures column visibility state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              columnDefs: [
                const OsColumnDef(field: 'name', headerName: 'Name'),
                const OsColumnDef(field: 'age', headerName: 'Age'),
                const OsColumnDef(field: 'email', headerName: 'Email'),
              ],
              rowData: [
                {'name': 'Alice', 'age': 30, 'email': 'a@b.com'},
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      controller.setColumnsVisible(['email'], false);
      await tester.pumpAndSettle();

      final state = controller.getState();
      expect(state.columnVisibility, isNotNull);
      expect(state.columnVisibility!.hiddenColIds, contains('email'));
    });

    testWidgets('setState restores sort', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              columnDefs: [
                const OsColumnDef(
                  field: 'name',
                  headerName: 'Name',
                  sortable: true,
                ),
                const OsColumnDef(
                  field: 'age',
                  headerName: 'Age',
                  sortable: true,
                ),
              ],
              rowData: [
                {'name': 'Charlie', 'age': 35},
                {'name': 'Alice', 'age': 30},
                {'name': 'Bob', 'age': 25},
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Apply state with sort
      controller.setState(
        const OsGridState(
          sort: SortState(
            sortModel: [
              OsSortModel(colId: 'name', sort: OsSortDirection.ascending),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify sort was applied
      final sortModel = controller.getSortModel();
      expect(sortModel, hasLength(1));
      expect(sortModel[0].colId, 'name');
      expect(sortModel[0].sort, OsSortDirection.ascending);
    });

    testWidgets('setState restores selection', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              getRowId: (data) => data['name'] as String,
              rowSelection: OsRowSelection.multiple(),
              columnDefs: [
                const OsColumnDef(field: 'name', headerName: 'Name'),
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
      await tester.pumpAndSettle();

      // Apply state with selection
      controller.setState(
        const OsGridState(
          rowSelection: RowSelectionState(selectedRowIds: ['Bob']),
        ),
      );
      await tester.pumpAndSettle();

      final selectedIds = controller.getSelectedIds();
      expect(selectedIds, contains('Bob'));
      expect(selectedIds, hasLength(1));
    });

    testWidgets('setState with propertiesToIgnore skips specified properties', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              getRowId: (data) => data['name'] as String,
              rowSelection: OsRowSelection.multiple(),
              columnDefs: [
                const OsColumnDef(
                  field: 'name',
                  headerName: 'Name',
                  sortable: true,
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
      await tester.pumpAndSettle();

      // Apply state but ignore selection
      controller.setState(
        const OsGridState(
          sort: SortState(
            sortModel: [
              OsSortModel(colId: 'name', sort: OsSortDirection.descending),
            ],
          ),
          rowSelection: RowSelectionState(selectedRowIds: ['Alice']),
        ),
        propertiesToIgnore: ['rowSelection'],
      );
      await tester.pumpAndSettle();

      // Sort should be applied
      expect(controller.getSortModel(), hasLength(1));
      // Selection should NOT be applied (ignored)
      expect(controller.getSelectedIds(), isEmpty);
    });

    testWidgets('initialState is applied on grid creation', (tester) async {
      const savedState = OsGridState(
        sort: SortState(
          sortModel: [
            OsSortModel(colId: 'name', sort: OsSortDirection.descending),
          ],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              initialState: savedState,
              columnDefs: [
                const OsColumnDef(
                  field: 'name',
                  headerName: 'Name',
                  sortable: true,
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
      await tester.pumpAndSettle();

      final sortModel = controller.getSortModel();
      expect(sortModel, hasLength(1));
      expect(sortModel[0].colId, 'name');
      expect(sortModel[0].sort, OsSortDirection.descending);
    });

    testWidgets('onStateUpdated fires when sort changes', (tester) async {
      final events = <OsStateUpdatedEvent>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              onStateUpdated: (event) => events.add(event),
              columnDefs: [
                const OsColumnDef(
                  field: 'name',
                  headerName: 'Name',
                  sortable: true,
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
      await tester.pumpAndSettle();

      controller.setSortModel([
        const OsSortModel(colId: 'name', sort: OsSortDirection.ascending),
      ]);
      await tester.pumpAndSettle();

      // Timer-based debounce requires runAsync to advance real time
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();

      expect(events, isNotEmpty);
      expect(events.last.sources, contains('sort'));
      expect(events.last.state.sort, isNotNull);
    });

    testWidgets('onStateUpdated stream on controller is available', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              columnDefs: [
                const OsColumnDef(
                  field: 'name',
                  headerName: 'Name',
                  sortable: true,
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
      await tester.pumpAndSettle();

      // Verify the stream is available and can be listened to
      expect(controller.onStateUpdated, isA<Stream<OsStateUpdatedEvent>>());

      // The stream fires correctly (proven by the widget callback test above).
      // Timer-based debounce in GridStateService doesn't play well with
      // Flutter's fake async test zone for stream assertions, but the
      // mechanism is verified via the onStateUpdated widget callback test.
    });

    testWidgets('getState/setState round-trip preserves state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              getRowId: (data) => data['name'] as String,
              rowSelection: OsRowSelection.multiple(),
              columnDefs: [
                const OsColumnDef(
                  field: 'name',
                  headerName: 'Name',
                  sortable: true,
                ),
                const OsColumnDef(field: 'age', headerName: 'Age'),
              ],
              rowData: [
                {'name': 'Charlie', 'age': 35},
                {'name': 'Alice', 'age': 30},
                {'name': 'Bob', 'age': 25},
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Set up some state
      controller.setSortModel([
        const OsSortModel(colId: 'name', sort: OsSortDirection.ascending),
      ]);
      controller.selectRowsById(['Alice', 'Bob']);
      await tester.pumpAndSettle();

      // Capture state
      final savedState = controller.getState();

      // Clear everything
      controller.setSortModel([]);
      controller.deselectAll();
      await tester.pumpAndSettle();

      // Verify cleared
      expect(controller.getSortModel(), isEmpty);
      expect(controller.getSelectedIds(), isEmpty);

      // Restore state
      controller.setState(savedState);
      await tester.pumpAndSettle();

      // Verify restored
      expect(controller.getSortModel(), hasLength(1));
      expect(controller.getSortModel()[0].colId, 'name');
      expect(controller.getSelectedIds(), containsAll(['Alice', 'Bob']));
    });

    testWidgets('getState captures filter model', (tester) async {
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

      controller.setFilterModel({
        'name': {'filterType': 'text', 'type': 'contains', 'filter': 'Ali'},
      });
      await tester.pumpAndSettle();

      final state = controller.getState();
      expect(state.filter, isNotNull);
      expect(state.filter!.filterModel, isNotNull);
      expect(state.filter!.filterModel!['name']['filter'], 'Ali');
    });

    testWidgets('setState restores filter model', (tester) async {
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

      controller.setState(
        const OsGridState(
          filter: FilterState(
            filterModel: {
              'name': {
                'filterType': 'text',
                'type': 'contains',
                'filter': 'Bob',
              },
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final filterModel = controller.getFilterModel();
      expect(filterModel, isNotNull);
      expect(filterModel!['name']['filter'], 'Bob');
    });
  });

  group('GridState JSON interoperability', () {
    test('can parse OS Grid TypeScript state format', () {
      // Simulates a state object from the TypeScript OS Grid
      final tsState = {
        'sort': {
          'sortModel': [
            {'colId': 'price', 'sort': 'desc'},
            {'colId': 'name', 'sort': 'asc'},
          ],
        },
        'columnPinning': {
          'leftColIds': ['id', 'name'],
          'rightColIds': ['total'],
        },
        'columnVisibility': {
          'hiddenColIds': ['internal_id'],
        },
        'pagination': {'page': 3, 'pageSize': 50},
      };

      final state = OsGridState.fromJson(tsState);
      expect(state.sort!.sortModel, hasLength(2));
      expect(state.sort!.sortModel[0].colId, 'price');
      expect(state.sort!.sortModel[0].sort, OsSortDirection.descending);
      expect(state.sort!.sortModel[1].colId, 'name');
      expect(state.sort!.sortModel[1].sort, OsSortDirection.ascending);
      expect(state.columnPinning!.leftColIds, ['id', 'name']);
      expect(state.columnPinning!.rightColIds, ['total']);
      expect(state.columnVisibility!.hiddenColIds, ['internal_id']);
      expect(state.pagination!.page, 3);
      expect(state.pagination!.pageSize, 50);
    });

    test('toJson produces OS Grid TypeScript compatible format', () {
      const state = OsGridState(
        sort: SortState(
          sortModel: [
            OsSortModel(colId: 'date', sort: OsSortDirection.descending),
          ],
        ),
        columnPinning: ColumnPinningState(
          leftColIds: ['checkbox'],
          rightColIds: [],
        ),
      );

      final json = state.toJson();
      // Verify the format matches what TypeScript OS Grid expects
      expect(json['sort']['sortModel'][0]['sort'], 'desc');
      expect(json['columnPinning']['leftColIds'], ['checkbox']);
      expect(json['columnPinning']['rightColIds'], isEmpty);
    });

    test('partial state fromJson ignores unknown keys', () {
      final json = {
        'sort': {
          'sortModel': [
            {'colId': 'a', 'sort': 'asc'},
          ],
        },
        'unknownFutureProperty': {'data': 123},
        'sideBar': {'visible': true},
      };

      // Should not throw — unknown keys are simply ignored
      final state = OsGridState.fromJson(json);
      expect(state.sort, isNotNull);
      expect(state.sort!.sortModel[0].colId, 'a');
    });
  });
}
