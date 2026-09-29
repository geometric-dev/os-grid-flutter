import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

void main() {
  group('Event streams — previously dead streams', () {
    test(
      'onSortChanged emits when sort state changes via header tap',
      () async {
        final controller = OsGridController<Map<String, dynamic>>();
        final events = <OsSortChangedEvent>[];
        final sub = controller.onSortChanged.listen(events.add);

        controller.setRowData([
          {'name': 'Alice', 'age': 32},
          {'name': 'Bob', 'age': 28},
        ]);

        // Emit sort changed directly (simulating what _OsGridState does)
        controller.emitSortChanged(
          const OsSortChangedEvent(
            sortModel: [
              OsSortModel(colId: 'name', sort: OsSortDirection.ascending),
            ],
          ),
        );

        await Future<void>.delayed(Duration.zero);

        expect(events.length, 1);
        expect(events.first.sortModel.length, 1);
        expect(events.first.sortModel.first.colId, 'name');
        expect(events.first.sortModel.first.sort, OsSortDirection.ascending);

        await sub.cancel();
        controller.dispose();
      },
    );

    test('onFilterChanged emits when filter changes', () async {
      final controller = OsGridController<Map<String, dynamic>>();
      final events = <OsFilterChangedEvent>[];
      final sub = controller.onFilterChanged.listen(events.add);

      controller.setRowData([
        {'name': 'Alice'},
        {'name': 'Bob'},
      ]);

      // Emit filter changed directly (simulating what _OsGridState does)
      controller.emitFilterChanged(
        const OsFilterChangedEvent(filterModel: {'quickFilter': 'alice'}),
      );

      await Future<void>.delayed(Duration.zero);

      expect(events.length, 1);
      expect(events.first.filterModel['quickFilter'], 'alice');

      await sub.cancel();
      controller.dispose();
    });

    test('onCellValueChanged emits when cell value is edited', () async {
      final controller = OsGridController<Map<String, dynamic>>();
      final events = <OsCellValueChangedEvent<Map<String, dynamic>>>[];
      final sub = controller.onCellValueChanged.listen(events.add);

      controller.setRowData([
        {'name': 'Alice', 'age': 32},
      ]);

      // Emit cell value changed directly (simulating what _OsGridState does)
      controller.emitCellValueChanged(
        const OsCellValueChangedEvent<Map<String, dynamic>>(
          data: {'name': 'Alice', 'age': 33},
          rowIndex: 0,
          colDef: OsColumnDef(field: 'age'),
          oldValue: 32,
          newValue: 33,
        ),
      );

      await Future<void>.delayed(Duration.zero);

      expect(events.length, 1);
      expect(events.first.oldValue, 32);
      expect(events.first.newValue, 33);
      expect(events.first.rowIndex, 0);

      await sub.cancel();
      controller.dispose();
    });
  });

  group('Event streams — new streams', () {
    test('onRowClicked emits when a row is clicked', () async {
      final controller = OsGridController<Map<String, dynamic>>();
      final events = <OsRowClickedEvent<Map<String, dynamic>>>[];
      final sub = controller.onRowClicked.listen(events.add);

      controller.setRowData([
        {'name': 'Alice'},
        {'name': 'Bob'},
      ]);

      controller.emitRowClicked(
        const OsRowClickedEvent<Map<String, dynamic>>(
          data: {'name': 'Bob'},
          rowIndex: 1,
        ),
      );

      await Future<void>.delayed(Duration.zero);

      expect(events.length, 1);
      expect(events.first.data, {'name': 'Bob'});
      expect(events.first.rowIndex, 1);

      await sub.cancel();
      controller.dispose();
    });

    test('onPaginationChanged emits on page change', () async {
      final controller = OsGridController<Map<String, dynamic>>();
      final events = <OsPaginationChangedEvent>[];
      final sub = controller.onPaginationChanged.listen(events.add);

      controller.emitPaginationChanged(
        const OsPaginationChangedEvent(
          currentPage: 2,
          totalPages: 5,
          pageSize: 10,
          totalRows: 50,
          newPage: true,
          newPageSize: false,
        ),
      );

      await Future<void>.delayed(Duration.zero);

      expect(events.length, 1);
      expect(events.first.currentPage, 2);
      expect(events.first.totalPages, 5);
      expect(events.first.pageSize, 10);
      expect(events.first.totalRows, 50);
      expect(events.first.newPage, true);
      expect(events.first.newPageSize, false);

      await sub.cancel();
      controller.dispose();
    });

    test('onPaginationChanged emits on page size change', () async {
      final controller = OsGridController<Map<String, dynamic>>();
      final events = <OsPaginationChangedEvent>[];
      final sub = controller.onPaginationChanged.listen(events.add);

      controller.emitPaginationChanged(
        const OsPaginationChangedEvent(
          currentPage: 0,
          totalPages: 10,
          pageSize: 25,
          totalRows: 250,
          newPage: false,
          newPageSize: true,
        ),
      );

      await Future<void>.delayed(Duration.zero);

      expect(events.length, 1);
      expect(events.first.newPageSize, true);
      expect(events.first.newPage, false);
      expect(events.first.pageSize, 25);

      await sub.cancel();
      controller.dispose();
    });

    test('onRowDataUpdated emits when setRowData is called', () async {
      final controller = OsGridController<Map<String, dynamic>>();
      final events = <OsRowDataUpdatedEvent<Map<String, dynamic>>>[];
      final sub = controller.onRowDataUpdated.listen(events.add);

      controller.setRowData([
        {'name': 'Alice'},
        {'name': 'Bob'},
      ]);

      await Future<void>.delayed(Duration.zero);

      expect(events.length, 1);
      expect(events.first.rowCount, 2);
      expect(events.first.rowData.length, 2);

      await sub.cancel();
      controller.dispose();
    });

    test('onRowDataUpdated emits when applyTransaction is called', () async {
      final controller = OsGridController<Map<String, dynamic>>();
      controller.setRowData([
        {'name': 'Alice'},
      ]);

      final events = <OsRowDataUpdatedEvent<Map<String, dynamic>>>[];
      final sub = controller.onRowDataUpdated.listen(events.add);

      controller.applyTransaction(
        const OsRowTransaction(
          add: [
            {'name': 'Bob'},
          ],
        ),
      );

      await Future<void>.delayed(Duration.zero);

      expect(events.length, 1);
      expect(events.first.rowCount, 2);

      await sub.cancel();
      controller.dispose();
    });

    test('onRowDataUpdated emits after remove transaction', () async {
      final controller = OsGridController<Map<String, dynamic>>();
      final row = {'name': 'Alice'};
      controller.setRowData([
        row,
        {'name': 'Bob'},
      ]);

      final events = <OsRowDataUpdatedEvent<Map<String, dynamic>>>[];
      final sub = controller.onRowDataUpdated.listen(events.add);

      controller.applyTransaction(OsRowTransaction(remove: [row]));

      await Future<void>.delayed(Duration.zero);

      expect(events.length, 1);
      expect(events.first.rowCount, 1);

      await sub.cancel();
      controller.dispose();
    });
  });

  group('Event streams — multiple listeners', () {
    test('broadcast streams support multiple listeners', () async {
      final controller = OsGridController<Map<String, dynamic>>();
      final events1 = <OsRowClickedEvent<Map<String, dynamic>>>[];
      final events2 = <OsRowClickedEvent<Map<String, dynamic>>>[];
      final sub1 = controller.onRowClicked.listen(events1.add);
      final sub2 = controller.onRowClicked.listen(events2.add);

      controller.emitRowClicked(
        const OsRowClickedEvent<Map<String, dynamic>>(
          data: {'name': 'Alice'},
          rowIndex: 0,
        ),
      );

      await Future<void>.delayed(Duration.zero);

      expect(events1.length, 1);
      expect(events2.length, 1);

      await sub1.cancel();
      await sub2.cancel();
      controller.dispose();
    });
  });

  group('Event classes', () {
    test('OsRowClickedEvent holds correct data', () {
      const event = OsRowClickedEvent<String>(data: 'test', rowIndex: 5);
      expect(event.data, 'test');
      expect(event.rowIndex, 5);
    });

    test('OsPaginationChangedEvent holds correct data', () {
      const event = OsPaginationChangedEvent(
        currentPage: 1,
        totalPages: 3,
        pageSize: 50,
        totalRows: 150,
        newPage: true,
        newPageSize: false,
      );
      expect(event.currentPage, 1);
      expect(event.totalPages, 3);
      expect(event.pageSize, 50);
      expect(event.totalRows, 150);
      expect(event.newPage, true);
      expect(event.newPageSize, false);
    });

    test('OsPaginationChangedEvent defaults', () {
      const event = OsPaginationChangedEvent(
        currentPage: 0,
        totalPages: 1,
        pageSize: 100,
        totalRows: 10,
      );
      expect(event.newPage, false);
      expect(event.newPageSize, false);
    });

    test('OsRowDataUpdatedEvent holds correct data', () {
      const event = OsRowDataUpdatedEvent<Map<String, dynamic>>(
        rowData: [
          {'name': 'Alice'},
        ],
        rowCount: 1,
      );
      expect(event.rowData.length, 1);
      expect(event.rowCount, 1);
    });
  });

  group('Widget callbacks — integration', () {
    testWidgets('onRowDataUpdated callback fires when rowData changes', (
      tester,
    ) async {
      OsRowDataUpdatedEvent<Map<String, dynamic>>? receivedEvent;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              columnDefs: const [OsColumnDef(field: 'name')],
              rowData: const [
                {'name': 'Alice'},
              ],
              onRowDataUpdated: (event) => receivedEvent = event,
            ),
          ),
        ),
      );

      // Update the widget with new row data
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              columnDefs: const [OsColumnDef(field: 'name')],
              rowData: const [
                {'name': 'Alice'},
                {'name': 'Bob'},
              ],
              onRowDataUpdated: (event) => receivedEvent = event,
            ),
          ),
        ),
      );

      expect(receivedEvent, isNotNull);
      expect(receivedEvent!.rowCount, 2);
    });

    testWidgets('onFilterChanged callback fires when quickFilterText changes', (
      tester,
    ) async {
      OsFilterChangedEvent? receivedEvent;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              columnDefs: const [OsColumnDef(field: 'name')],
              rowData: const [
                {'name': 'Alice'},
                {'name': 'Bob'},
              ],
              onFilterChanged: (event) => receivedEvent = event,
            ),
          ),
        ),
      );

      // Update with filter text
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              columnDefs: const [OsColumnDef(field: 'name')],
              rowData: const [
                {'name': 'Alice'},
                {'name': 'Bob'},
              ],
              quickFilterText: 'alice',
              onFilterChanged: (event) => receivedEvent = event,
            ),
          ),
        ),
      );

      expect(receivedEvent, isNotNull);
      expect(receivedEvent!.filterModel['quickFilter'], 'alice');
    });
  });

  group('Event streams — cell focus/key (QW5)', () {
    test('onCellFocused emits the focused position', () async {
      final controller = OsGridController<Map<String, dynamic>>();
      final events = <OsCellFocusedEvent>[];
      final sub = controller.onCellFocused.listen(events.add);

      controller.emitCellFocused(
        const OsCellFocusedEvent(rowIndex: 3, columnIndex: 1),
      );
      await Future<void>.delayed(Duration.zero);

      expect(events.length, 1);
      expect(events.first.rowIndex, 3);
      expect(events.first.columnIndex, 1);

      await sub.cancel();
      controller.dispose();
    });

    test('onCellKeyDown emits row/column/key/physicalKey payload', () async {
      final controller = OsGridController<Map<String, dynamic>>();
      final events = <OsCellKeyDownEvent>[];
      final sub = controller.onCellKeyDown.listen(events.add);

      controller.emitCellKeyDown(
        const OsCellKeyDownEvent(
          rowIndex: 0,
          columnIndex: 2,
          key: 'Arrow Right',
          physicalKey: '0x0007004f',
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(events.length, 1);
      expect(events.first.rowIndex, 0);
      expect(events.first.columnIndex, 2);
      expect(events.first.key, 'Arrow Right');
      expect(events.first.physicalKey, '0x0007004f');

      await sub.cancel();
      controller.dispose();
    });

    test('focus API returns null when nothing focused yet', () {
      final controller = OsGridController<Map<String, dynamic>>();
      expect(controller.getFocusedCell(), isNull);
      controller.dispose();
    });

    test('set/clear without a bound grid are safe no-ops', () {
      final controller = OsGridController<Map<String, dynamic>>();
      controller.setFocusedCell(rowIndex: 1, columnIndex: 1);
      controller.clearFocusedCell();
      expect(controller.getFocusedCell(), isNull);
      controller.dispose();
    });
  });
}
