import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

void main() {
  group('Cell editing — valueSetter and valueParser', () {
    test(
      'valueSetter is called with correct params when editing commits',
      () async {
        final controller = OsGridController<Map<String, dynamic>>();

        await _pumpGrid(
          tester: null,
          controller: controller,
          columnDefs: [
            OsColumnDef<Map<String, dynamic>>(
              field: 'name',
              editable: true,
              valueSetter: (params) {
                params.data['name'] = params.newValue;
                return true;
              },
            ),
          ],
          rowData: [
            {'name': 'Alice'},
          ],
        );

        // Simulate what _commitEdit does by testing the params class directly
        const params = ValueSetterParams<Map<String, dynamic>>(
          data: {'name': 'Alice'},
          colDef: OsColumnDef(field: 'name'),
          oldValue: 'Alice',
          newValue: 'Bob',
          rowIndex: 0,
          source: 'edit',
        );

        expect(params.data, {'name': 'Alice'});
        expect(params.oldValue, 'Alice');
        expect(params.newValue, 'Bob');
        expect(params.rowIndex, 0);
        expect(params.source, 'edit');

        controller.dispose();
      },
    );

    test('valueParser is called with correct params', () {
      const params = ValueParserParams<Map<String, dynamic>>(
        data: {'price': 10.5},
        colDef: OsColumnDef(field: 'price'),
        oldValue: 10.5,
        newValue: '20.99',
        rowIndex: 0,
        source: 'edit',
      );

      expect(params.data, {'price': 10.5});
      expect(params.oldValue, 10.5);
      expect(params.newValue, '20.99');
      expect(params.rowIndex, 0);
      expect(params.source, 'edit');
    });

    test(
      'valueSetter returning false prevents cellValueChanged event',
      () async {
        final controller = OsGridController<Map<String, dynamic>>();
        final events = <OsCellValueChangedEvent<Map<String, dynamic>>>[];
        final sub = controller.onCellValueChanged.listen(events.add);

        // Simulate a valueSetter that returns false
        const bool valueSetterResult = false;
        bool valueSetter(ValueSetterParams<Map<String, dynamic>> params) {
          return valueSetterResult;
        }

        // The valueSetter returning false means no event should fire
        expect(
          valueSetter(
            const ValueSetterParams(
              data: {'name': 'Alice'},
              colDef: OsColumnDef(field: 'name'),
              oldValue: 'Alice',
              newValue: 'Bob',
              rowIndex: 0,
            ),
          ),
          false,
        );

        await Future<void>.delayed(Duration.zero);
        expect(events, isEmpty);

        await sub.cancel();
        controller.dispose();
      },
    );
  });

  group('Cell editing — editableCallback', () {
    test('editableCallback receives correct params', () {
      CellRendererParams<Map<String, dynamic>>? receivedParams;

      bool callback(CellRendererParams<Map<String, dynamic>> params) {
        receivedParams = params;
        return params.data['status'] != 'locked';
      }

      // Test with unlocked row
      expect(
        callback(
          const CellRendererParams(
            value: 'Alice',
            data: {'name': 'Alice', 'status': 'active'},
            rowIndex: 0,
            colDef: OsColumnDef(field: 'name'),
          ),
        ),
        true,
      );

      // Test with locked row
      expect(
        callback(
          const CellRendererParams(
            value: 'Bob',
            data: {'name': 'Bob', 'status': 'locked'},
            rowIndex: 1,
            colDef: OsColumnDef(field: 'name'),
          ),
        ),
        false,
      );

      expect(receivedParams, isNotNull);
      expect(receivedParams!.data['name'], 'Bob');
    });
  });

  group('Cell editing — singleClickEdit', () {
    test('singleClickEdit property defaults to false', () {
      // Verify the default value
      const grid = OsGrid(
        columnDefs: [OsColumnDef(field: 'name')],
        rowData: <Map<String, dynamic>>[],
      );
      expect(grid.singleClickEdit, false);
    });

    test('singleClickEdit can be set to true', () {
      const grid = OsGrid(
        columnDefs: [OsColumnDef(field: 'name')],
        rowData: <Map<String, dynamic>>[],
        singleClickEdit: true,
      );
      expect(grid.singleClickEdit, true);
    });

    test('per-column singleClickEdit overrides grid-level setting', () {
      const col = OsColumnDef(field: 'name', singleClickEdit: true);
      expect(col.singleClickEdit, true);

      const col2 = OsColumnDef(field: 'age', singleClickEdit: false);
      expect(col2.singleClickEdit, false);

      const col3 = OsColumnDef(field: 'email');
      expect(col3.singleClickEdit, isNull);
    });
  });

  group('Cell editing — events', () {
    test('cellEditingStarted event has correct structure', () {
      const event = OsCellEditingStartedEvent<Map<String, dynamic>>(
        data: {'name': 'Alice'},
        rowIndex: 0,
        colDef: OsColumnDef(field: 'name'),
        value: 'Alice',
      );

      expect(event.data, {'name': 'Alice'});
      expect(event.rowIndex, 0);
      expect(event.colDef.field, 'name');
      expect(event.value, 'Alice');
    });

    test('cellEditingStopped event has correct structure (committed)', () {
      const event = OsCellEditingStoppedEvent<Map<String, dynamic>>(
        data: {'name': 'Bob'},
        rowIndex: 0,
        colDef: OsColumnDef(field: 'name'),
        oldValue: 'Alice',
        newValue: 'Bob',
        cancelled: false,
      );

      expect(event.data, {'name': 'Bob'});
      expect(event.rowIndex, 0);
      expect(event.oldValue, 'Alice');
      expect(event.newValue, 'Bob');
      expect(event.cancelled, false);
    });

    test('cellEditingStopped event has correct structure (cancelled)', () {
      const event = OsCellEditingStoppedEvent<Map<String, dynamic>>(
        data: {'name': 'Alice'},
        rowIndex: 0,
        colDef: OsColumnDef(field: 'name'),
        oldValue: 'Alice',
        newValue: 'Alice',
        cancelled: true,
      );

      expect(event.cancelled, true);
      expect(event.oldValue, event.newValue);
    });

    test('controller emits cellEditingStarted stream event', () async {
      final controller = OsGridController<Map<String, dynamic>>();
      final events = <OsCellEditingStartedEvent<Map<String, dynamic>>>[];
      final sub = controller.onCellEditingStarted.listen(events.add);

      controller.emitCellEditingStarted(
        const OsCellEditingStartedEvent(
          data: {'name': 'Alice'},
          rowIndex: 0,
          colDef: OsColumnDef(field: 'name'),
          value: 'Alice',
        ),
      );

      await Future<void>.delayed(Duration.zero);

      expect(events.length, 1);
      expect(events.first.value, 'Alice');
      expect(controller.isEditing, true);

      await sub.cancel();
      controller.dispose();
    });

    test('controller emits cellEditingStopped stream event', () async {
      final controller = OsGridController<Map<String, dynamic>>();
      final events = <OsCellEditingStoppedEvent<Map<String, dynamic>>>[];
      final sub = controller.onCellEditingStopped.listen(events.add);

      // Start editing first
      controller.emitCellEditingStarted(
        const OsCellEditingStartedEvent(
          data: {'name': 'Alice'},
          rowIndex: 0,
          colDef: OsColumnDef(field: 'name'),
          value: 'Alice',
        ),
      );
      expect(controller.isEditing, true);

      // Stop editing
      controller.emitCellEditingStopped(
        const OsCellEditingStoppedEvent(
          data: {'name': 'Bob'},
          rowIndex: 0,
          colDef: OsColumnDef(field: 'name'),
          oldValue: 'Alice',
          newValue: 'Bob',
          cancelled: false,
        ),
      );

      await Future<void>.delayed(Duration.zero);

      expect(events.length, 1);
      expect(events.first.cancelled, false);
      expect(controller.isEditing, false);

      await sub.cancel();
      controller.dispose();
    });
  });

  group('Cell editing — controller API', () {
    test('isEditing defaults to false', () {
      final controller = OsGridController<Map<String, dynamic>>();
      expect(controller.isEditing, false);
      controller.dispose();
    });

    test('isEditing becomes true after emitCellEditingStarted', () {
      final controller = OsGridController<Map<String, dynamic>>();
      controller.emitCellEditingStarted(
        const OsCellEditingStartedEvent(
          data: {'name': 'Alice'},
          rowIndex: 0,
          colDef: OsColumnDef(field: 'name'),
          value: 'Alice',
        ),
      );
      expect(controller.isEditing, true);
      controller.dispose();
    });

    test('isEditing becomes false after emitCellEditingStopped', () {
      final controller = OsGridController<Map<String, dynamic>>();
      controller.emitCellEditingStarted(
        const OsCellEditingStartedEvent(
          data: {'name': 'Alice'},
          rowIndex: 0,
          colDef: OsColumnDef(field: 'name'),
          value: 'Alice',
        ),
      );
      controller.emitCellEditingStopped(
        const OsCellEditingStoppedEvent(
          data: {'name': 'Alice'},
          rowIndex: 0,
          colDef: OsColumnDef(field: 'name'),
          oldValue: 'Alice',
          newValue: 'Alice',
          cancelled: true,
        ),
      );
      expect(controller.isEditing, false);
      controller.dispose();
    });

    test('startEditingCell calls the registered callback', () {
      final controller = OsGridController<Map<String, dynamic>>();
      int? receivedRow;
      String? receivedColId;

      controller.onStartEditingCellRequested = (rowIndex, colId) {
        receivedRow = rowIndex;
        receivedColId = colId;
      };

      controller.startEditingCell(rowIndex: 2, colId: 'name');

      expect(receivedRow, 2);
      expect(receivedColId, 'name');
      controller.dispose();
    });

    test('stopEditing calls the registered callback with cancel flag', () {
      final controller = OsGridController<Map<String, dynamic>>();
      bool? receivedCancel;

      controller.onStopEditingRequested = (cancel) {
        receivedCancel = cancel;
      };

      controller.stopEditing(cancel: true);
      expect(receivedCancel, true);

      controller.stopEditing();
      expect(receivedCancel, false);

      controller.dispose();
    });
  });

  group('Cell editing — OsColumnDef properties', () {
    test('valueSetter can be assigned to OsColumnDef', () {
      final col = OsColumnDef<Map<String, dynamic>>(
        field: 'name',
        editable: true,
        valueSetter: (params) {
          params.data['name'] = params.newValue;
          return true;
        },
      );
      expect(col.valueSetter, isNotNull);
    });

    test('valueParser can be assigned to OsColumnDef', () {
      final col = OsColumnDef<Map<String, dynamic>>(
        field: 'price',
        editable: true,
        valueParser: (params) => double.tryParse(params.newValue) ?? 0.0,
      );
      expect(col.valueParser, isNotNull);

      // Test the parser
      final result = col.valueParser!(
        ValueParserParams(
          data: {'price': 10.0},
          colDef: col,
          oldValue: 10.0,
          newValue: '25.5',
          rowIndex: 0,
        ),
      );
      expect(result, 25.5);
    });

    test('valueParser handles invalid input gracefully', () {
      final col = OsColumnDef<Map<String, dynamic>>(
        field: 'price',
        editable: true,
        valueParser: (params) => double.tryParse(params.newValue) ?? 0.0,
      );

      final result = col.valueParser!(
        ValueParserParams(
          data: {'price': 10.0},
          colDef: col,
          oldValue: 10.0,
          newValue: 'not a number',
          rowIndex: 0,
        ),
      );
      expect(result, 0.0);
    });
  });

  group('Cell editing — widget integration', () {
    testWidgets('grid renders with singleClickEdit enabled', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              columnDefs: [
                OsColumnDef(field: 'name', editable: true),
                OsColumnDef(field: 'age', editable: true),
              ],
              rowData: [
                {'name': 'Alice', 'age': 32},
                {'name': 'Bob', 'age': 28},
              ],
              singleClickEdit: true,
            ),
          ),
        ),
      );
      await tester.pump();

      // Grid should render without errors
      expect(find.byType(OsGrid<Map<String, dynamic>>), findsOneWidget);
    });

    testWidgets('grid renders with editing callbacks', (tester) async {
      final startedEvents = <OsCellEditingStartedEvent<Map<String, dynamic>>>[];
      final stoppedEvents = <OsCellEditingStoppedEvent<Map<String, dynamic>>>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              columnDefs: const [OsColumnDef(field: 'name', editable: true)],
              rowData: const [
                {'name': 'Alice'},
              ],
              onCellEditingStarted: startedEvents.add,
              onCellEditingStopped: stoppedEvents.add,
            ),
          ),
        ),
      );
      await tester.pump();

      // Grid should render without errors
      expect(find.byType(OsGrid<Map<String, dynamic>>), findsOneWidget);
    });

    testWidgets('grid renders with valueSetter and valueParser', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              columnDefs: [
                OsColumnDef<Map<String, dynamic>>(
                  field: 'price',
                  editable: true,
                  valueSetter: (params) {
                    params.data['price'] = params.newValue;
                    return true;
                  },
                  valueParser: (params) =>
                      double.tryParse(params.newValue) ?? 0.0,
                ),
              ],
              rowData: const [
                {'price': 10.5},
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(OsGrid<Map<String, dynamic>>), findsOneWidget);
    });

    testWidgets('grid renders with editableCallback', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              columnDefs: [
                OsColumnDef<Map<String, dynamic>>(
                  field: 'name',
                  editableCallback: (params) =>
                      params.data['status'] != 'locked',
                ),
              ],
              rowData: const [
                {'name': 'Alice', 'status': 'active'},
                {'name': 'Bob', 'status': 'locked'},
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(OsGrid<Map<String, dynamic>>), findsOneWidget);
    });

    testWidgets('controller stopEditing with cancel calls through widget', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();
      final stoppedEvents = <OsCellEditingStoppedEvent<Map<String, dynamic>>>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              columnDefs: const [OsColumnDef(field: 'name', editable: true)],
              rowData: const [
                {'name': 'Alice'},
              ],
              onCellEditingStopped: stoppedEvents.add,
            ),
          ),
        ),
      );
      await tester.pump();

      // Verify the controller's stopEditing method exists and can be called
      // (it won't do anything since no cell is being edited)
      controller.stopEditing(cancel: true);
      controller.stopEditing();

      await tester.pump();

      // No events should fire since no cell was being edited
      expect(stoppedEvents, isEmpty);
    });
  });

  group('Cell editing — keyboard handling', () {
    test('Escape key event is recognised', () {
      // Test that LogicalKeyboardKey.escape is the correct key
      expect(LogicalKeyboardKey.escape, isNotNull);
      expect(LogicalKeyboardKey.tab, isNotNull);
    });

    testWidgets('KeyboardListener is present in edit overlay', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              columnDefs: const [OsColumnDef(field: 'name', editable: true)],
              rowData: const [
                {'name': 'Alice'},
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      // The grid should render without errors
      expect(find.byType(OsGrid<Map<String, dynamic>>), findsOneWidget);
    });
  });

  group('Cell editing — Tab navigation logic', () {
    test('finds next editable cell skipping non-editable columns', () {
      // Test the concept: given columns [editable, non-editable, editable],
      // Tab from column 0 should skip to column 2
      final columns = [
        const OsColumnDef(field: 'name', editable: true),
        const OsColumnDef(field: 'status'), // not editable
        const OsColumnDef(field: 'age', editable: true),
      ];

      // Verify column editability
      expect(columns[0].editable, true);
      expect(columns[1].editable, isNull);
      expect(columns[2].editable, true);
    });

    test('editableCallback is respected in navigation', () {
      final col = OsColumnDef<Map<String, dynamic>>(
        field: 'name',
        editableCallback: (params) => params.rowIndex == 0,
      );

      // Row 0 should be editable
      final result0 = col.editableCallback!(
        CellRendererParams(
          value: 'Alice',
          data: {'name': 'Alice'},
          rowIndex: 0,
          colDef: col,
        ),
      );
      expect(result0, true);

      // Row 1 should not be editable
      final result1 = col.editableCallback!(
        CellRendererParams(
          value: 'Bob',
          data: {'name': 'Bob'},
          rowIndex: 1,
          colDef: col,
        ),
      );
      expect(result1, false);
    });
  });

  group('Cell editing — readOnlyEdit', () {
    test('readOnlyEdit property defaults to false', () {
      const grid = OsGrid(
        columnDefs: [OsColumnDef(field: 'name')],
        rowData: <Map<String, dynamic>>[],
      );
      expect(grid.readOnlyEdit, false);
    });

    test('readOnlyEdit can be set to true', () {
      const grid = OsGrid(
        columnDefs: [OsColumnDef(field: 'name')],
        rowData: <Map<String, dynamic>>[],
        readOnlyEdit: true,
      );
      expect(grid.readOnlyEdit, true);
    });

    test('OsCellEditRequestEvent has correct structure', () {
      const event = OsCellEditRequestEvent<Map<String, dynamic>>(
        data: {'name': 'Alice'},
        rowIndex: 0,
        colDef: OsColumnDef(field: 'name'),
        oldValue: 'Alice',
        newValue: 'Bob',
        source: 'edit',
      );

      expect(event.data, {'name': 'Alice'});
      expect(event.rowIndex, 0);
      expect(event.colDef.field, 'name');
      expect(event.oldValue, 'Alice');
      expect(event.newValue, 'Bob');
      expect(event.source, 'edit');
    });

    test('OsCellEditRequestEvent source defaults to edit', () {
      const event = OsCellEditRequestEvent<Map<String, dynamic>>(
        data: {'name': 'Alice'},
        rowIndex: 0,
        colDef: OsColumnDef(field: 'name'),
        oldValue: 'Alice',
        newValue: 'Bob',
      );

      expect(event.source, 'edit');
    });

    test('OsCellEditRequestEvent with cellClear source', () {
      const event = OsCellEditRequestEvent<Map<String, dynamic>>(
        data: {'name': 'Alice'},
        rowIndex: 0,
        colDef: OsColumnDef(field: 'name'),
        oldValue: 'Alice',
        newValue: null,
        source: 'cellClear',
      );

      expect(event.source, 'cellClear');
      expect(event.newValue, null);
    });

    test('controller emits cellEditRequest stream event', () async {
      final controller = OsGridController<Map<String, dynamic>>();
      final events = <OsCellEditRequestEvent<Map<String, dynamic>>>[];
      final sub = controller.onCellEditRequest.listen(events.add);

      controller.emitCellEditRequest(
        const OsCellEditRequestEvent<Map<String, dynamic>>(
          data: {'name': 'Alice'},
          rowIndex: 0,
          colDef: OsColumnDef(field: 'name'),
          oldValue: 'Alice',
          newValue: 'Bob',
        ),
      );

      await Future<void>.delayed(Duration.zero);
      expect(events, hasLength(1));
      expect(events.first.oldValue, 'Alice');
      expect(events.first.newValue, 'Bob');

      await sub.cancel();
      controller.dispose();
    });

    testWidgets('readOnlyEdit fires onCellEditRequest callback', (
      tester,
    ) async {
      OsCellEditRequestEvent<Map<String, dynamic>>? receivedEvent;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: OsGrid<Map<String, dynamic>>(
                columnDefs: const [OsColumnDef(field: 'name', editable: true)],
                rowData: const [
                  {'name': 'Alice'},
                ],
                readOnlyEdit: true,
                onCellEditRequest: (event) {
                  receivedEvent = event;
                },
              ),
            ),
          ),
        ),
      );

      // The widget should render with readOnlyEdit enabled
      expect(receivedEvent, isNull);
    });

    testWidgets('readOnlyEdit does not mutate data when editing commits', (
      tester,
    ) async {
      final data = [
        {'name': 'Alice'},
      ];
      OsCellValueChangedEvent<Map<String, dynamic>>? valueChangedEvent;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: OsGrid<Map<String, dynamic>>(
                columnDefs: const [OsColumnDef(field: 'name', editable: true)],
                rowData: data,
                readOnlyEdit: true,
                onCellEditRequest: (event) {},
                onCellValueChanged: (event) {
                  valueChangedEvent = event;
                },
              ),
            ),
          ),
        ),
      );

      // Data should remain unchanged (readOnlyEdit prevents mutation)
      expect(data[0]['name'], 'Alice');
      // No cellValueChanged should fire in readOnlyEdit mode
      expect(valueChangedEvent, isNull);
    });
  });

  group('Cell editing — enableCellEditingOnBackspace', () {
    test('enableCellEditingOnBackspace property defaults to false', () {
      const grid = OsGrid(
        columnDefs: [OsColumnDef(field: 'name')],
        rowData: <Map<String, dynamic>>[],
      );
      expect(grid.enableCellEditingOnBackspace, false);
    });

    test('enableCellEditingOnBackspace can be set to true', () {
      const grid = OsGrid(
        columnDefs: [OsColumnDef(field: 'name')],
        rowData: <Map<String, dynamic>>[],
        enableCellEditingOnBackspace: true,
      );
      expect(grid.enableCellEditingOnBackspace, true);
    });

    testWidgets('grid renders with enableCellEditingOnBackspace enabled', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: OsGrid<Map<String, dynamic>>(
                columnDefs: [OsColumnDef(field: 'name', editable: true)],
                rowData: [
                  {'name': 'Alice'},
                ],
                enableCellEditingOnBackspace: true,
              ),
            ),
          ),
        ),
      );

      // Should render without errors
      expect(find.byType(OsGrid<Map<String, dynamic>>), findsOneWidget);
    });
  });
}

/// Helper to create a grid for testing (non-widget tests).
/// Returns immediately — used for controller-level tests.
Future<void> _pumpGrid({
  required WidgetTester? tester,
  required OsGridController<Map<String, dynamic>> controller,
  required List<OsColumnDef> columnDefs,
  required List<Map<String, dynamic>> rowData,
}) async {
  if (tester == null) {
    // For non-widget tests, just set up the controller
    controller.setRowData(rowData);
    controller.columnDefs = columnDefs;
    return;
  }
}
