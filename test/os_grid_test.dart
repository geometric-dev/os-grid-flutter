import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

void main() {
  group('OsGrid widget', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OsGrid(
              columnDefs: [
                OsColumnDef(field: 'name', headerName: 'Name'),
                OsColumnDef(field: 'age', headerName: 'Age'),
              ],
              rowData: [
                {'name': 'Alice', 'age': 32},
                {'name': 'Bob', 'age': 28},
              ],
            ),
          ),
        ),
      );

      // Grid should render (VirtualisedGrid is the internal rendering widget)
      expect(find.byType(VirtualisedGrid), findsOneWidget);
    });

    testWidgets('accepts a controller', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              columnDefs: [const OsColumnDef(field: 'name')],
              rowData: [
                {'name': 'Alice'},
              ],
            ),
          ),
        ),
      );

      expect(find.byType(OsGrid<Map<String, dynamic>>), findsOneWidget);
      controller.dispose();
    });
  });

  group('OsGridController', () {
    test('setRowData updates row count', () {
      final controller = OsGridController<Map<String, dynamic>>();
      expect(controller.rowCount, 0);

      controller.setRowData([
        {'name': 'Alice'},
        {'name': 'Bob'},
      ]);
      expect(controller.rowCount, 2);

      controller.dispose();
    });

    test('selectAll and deselectAll', () {
      final controller = OsGridController<Map<String, dynamic>>();
      controller.setRowData([
        {'name': 'Alice'},
        {'name': 'Bob'},
        {'name': 'Charlie'},
      ]);

      controller.selectAll();
      expect(controller.getSelectedRows().length, 3);

      controller.deselectAll();
      expect(controller.getSelectedRows().length, 0);

      controller.dispose();
    });

    test('selectRows selects specific indices', () {
      final controller = OsGridController<Map<String, dynamic>>();
      controller.setRowData([
        {'name': 'Alice'},
        {'name': 'Bob'},
        {'name': 'Charlie'},
      ]);

      controller.selectRows([0, 2]);
      expect(controller.getSelectedRows().length, 2);
      expect(controller.isRowSelected(0), true);
      expect(controller.isRowSelected(1), false);
      expect(controller.isRowSelected(2), true);

      controller.dispose();
    });

    test('applyTransaction adds rows', () {
      final controller = OsGridController<Map<String, dynamic>>();
      controller.setRowData([
        {'name': 'Alice'},
      ]);

      controller.applyTransaction(
        const OsRowTransaction(
          add: [
            {'name': 'Bob'},
          ],
        ),
      );
      expect(controller.rowCount, 2);

      controller.dispose();
    });

    test('applyTransaction removes rows', () {
      final row = {'name': 'Alice'};
      final controller = OsGridController<Map<String, dynamic>>();
      controller.setRowData([
        row,
        {'name': 'Bob'},
      ]);

      controller.applyTransaction(OsRowTransaction(remove: [row]));
      expect(controller.rowCount, 1);

      controller.dispose();
    });

    test('getRowAtIndex returns correct data', () {
      final controller = OsGridController<Map<String, dynamic>>();
      controller.setRowData([
        {'name': 'Alice'},
        {'name': 'Bob'},
      ]);

      expect(controller.getRowAtIndex(0), {'name': 'Alice'});
      expect(controller.getRowAtIndex(1), {'name': 'Bob'});
      expect(controller.getRowAtIndex(5), null);
      expect(controller.getRowAtIndex(-1), null);

      controller.dispose();
    });

    test('onSelectionChanged stream emits on selection change', () async {
      final controller = OsGridController<Map<String, dynamic>>();
      controller.setRowData([
        {'name': 'Alice'},
        {'name': 'Bob'},
      ]);

      final events = <OsSelectionChangedEvent<Map<String, dynamic>>>[];
      final sub = controller.onSelectionChanged.listen(events.add);

      controller.selectAll();
      await Future<void>.delayed(Duration.zero);

      expect(events.length, 1);
      expect(events.first.selectedRows.length, 2);

      await sub.cancel();
      controller.dispose();
    });
  });

  group('OsColumnDef', () {
    test('effectiveColId uses colId when provided', () {
      const col = OsColumnDef(field: 'name', colId: 'myCol');
      expect(col.effectiveColId, 'myCol');
    });

    test('effectiveColId falls back to field', () {
      const col = OsColumnDef(field: 'name');
      expect(col.effectiveColId, 'name');
    });

    test('effectiveHeaderName capitalises field', () {
      const col = OsColumnDef(field: 'name');
      expect(col.effectiveHeaderName, 'Name');
    });

    test('effectiveHeaderName uses headerName when provided', () {
      const col = OsColumnDef(field: 'name', headerName: 'Full Name');
      expect(col.effectiveHeaderName, 'Full Name');
    });

    test('effectiveHeaderName prefers headerValueGetter over headerName', () {
      final col = OsColumnDef<Map<String, dynamic>>(
        field: 'name',
        headerName: 'Static Name',
        headerValueGetter: (params) => '${params.colDef.field} (dynamic)',
      );
      expect(col.effectiveHeaderName, 'name (dynamic)');
    });

    test('headerValueGetter result is used verbatim', () {
      // The getter's return value is used as-is; an empty string stays empty
      // rather than falling back to headerName/field.
      final col = OsColumnDef(field: 'name', headerValueGetter: (_) => '');
      expect(col.effectiveHeaderName, '');
    });

    test('headerValueGetter participates in defaults merge via resolver', () {
      final defaultColDef = OsColumnDef<dynamic>(
        headerValueGetter: (params) => 'Default: ${params.colDef.field}',
      );
      final resolved = ColumnDefResolver.resolve(
        columns: const [OsColumnDef(field: 'age')],
        defaultColDef: defaultColDef,
        columnTypes: null,
      );
      expect(resolved.single.effectiveHeaderName, 'Default: age');
    });

    test('explicit colDef headerValueGetter beats defaultColDef', () {
      final defaultColDef = OsColumnDef<dynamic>(
        headerValueGetter: (_) => 'From default',
      );
      final resolved = ColumnDefResolver.resolve(
        columns: [
          OsColumnDef(field: 'age', headerValueGetter: (_) => 'Explicit'),
        ],
        defaultColDef: defaultColDef,
        columnTypes: null,
      );
      expect(resolved.single.effectiveHeaderName, 'Explicit');
    });

    testWidgets('grid renders with headerValueGetter column', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              columnDefs: [
                OsColumnDef(
                  field: 'name',
                  headerName: 'Ignored',
                  headerValueGetter: (params) =>
                      'Dynamic ${params.colDef.field}',
                ),
              ],
              rowData: const [
                {'name': 'Alice'},
                {'name': 'Bob'},
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(OsGrid<Map<String, dynamic>>), findsOneWidget);
    });
  });
}
