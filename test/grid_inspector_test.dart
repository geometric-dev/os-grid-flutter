import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

typedef Row = Map<String, dynamic>;

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(body: SizedBox(width: 800, height: 600, child: child)),
  );
}

Finder _inspector() => find.byType(GridInspector<Row>);

void main() {
  group('GridInspector', () {
    testWidgets('hidden by default, shown with showInspector flag', (
      tester,
    ) async {
      final controller = OsGridController<Row>();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          OsGrid<Row>(
            controller: controller,
            columnDefs: const [OsColumnDef(field: 'name')],
            rowData: const [
              <String, dynamic>{'name': 'Alice'},
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(_inspector(), findsNothing);

      await tester.pumpWidget(
        _wrap(
          OsGrid<Row>(
            key: const Key('grid'),
            controller: controller,
            columnDefs: const [OsColumnDef(field: 'name')],
            rowData: const [
              <String, dynamic>{'name': 'Alice'},
            ],
            showInspector: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(_inspector(), findsOneWidget);
    });

    testWidgets('collapses and expands via header toggle', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const OsGrid<Row>(
            columnDefs: [OsColumnDef(field: 'name')],
            rowData: [
              <String, dynamic>{'name': 'Alice'},
            ],
            showInspector: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('rows 1/1'), findsOneWidget);

      await tester.tap(find.byKey(const Key('grid-inspector-toggle')));
      await tester.pumpAndSettle();
      expect(find.textContaining('rows 1/1'), findsNothing);
      expect(_inspector(), findsOneWidget);

      await tester.tap(find.byKey(const Key('grid-inspector-toggle')));
      await tester.pumpAndSettle();
      expect(find.textContaining('rows 1/1'), findsOneWidget);
    });

    testWidgets('displays correct counts after setRowData + selectAll', (
      tester,
    ) async {
      final controller = OsGridController<Row>();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          OsGrid<Row>(
            controller: controller,
            columnDefs: const [
              OsColumnDef(field: 'name'),
              OsColumnDef(field: 'age'),
            ],
            rowData: const <Row>[],
            getRowId: (row) => row['id'] as String,
            showInspector: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('rows 0/0'), findsOneWidget);
      expect(find.textContaining('sel 0'), findsOneWidget);

      controller.setRowData([
        {'id': 'a', 'name': 'Alice', 'age': 30},
        {'id': 'b', 'name': 'Bob', 'age': 25},
        {'id': 'c', 'name': 'Charlie', 'age': 35},
      ]);
      // Sync the widget-side pipeline with the controller's new dataset
      // (documented pattern after programmatic data replacement).
      controller.refreshClientSideRowModel();
      await tester.pumpAndSettle();

      expect(find.textContaining('rows 3/3'), findsOneWidget);

      controller.selectAll();
      await tester.pumpAndSettle();

      expect(find.textContaining('sel 3 · a, b, c'), findsOneWidget);

      controller.deselectAll();
      await tester.pumpAndSettle();
      expect(find.textContaining('sel 0'), findsOneWidget);
    });

    testWidgets('pagination info updates on page change', (tester) async {
      final controller = OsGridController<Row>();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          OsGrid<Row>(
            controller: controller,
            columnDefs: const [OsColumnDef(field: 'name')],
            rowData: [
              for (var i = 0; i < 5; i++) <String, dynamic>{'name': 'Row $i'},
            ],
            pagination: const OsPagination(pageSize: 2),
            showInspector: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 5 rows at page size 2 -> 3 pages; displayed count is the page slice.
      expect(find.textContaining('page 0/3 · size 2'), findsOneWidget);
      expect(find.textContaining('rows 2/5'), findsOneWidget);

      controller.paginationGoToNextPage();
      await tester.pumpAndSettle();

      expect(find.textContaining('page 1/3 · size 2'), findsOneWidget);

      controller.paginationGoToLastPage();
      await tester.pumpAndSettle();

      expect(find.textContaining('page 2/3 · size 2'), findsOneWidget);
      expect(find.textContaining('rows 1/5'), findsOneWidget);
    });

    testWidgets('shows quick filter state and overlay override', (
      tester,
    ) async {
      final controller = OsGridController<Row>();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          OsGrid<Row>(
            controller: controller,
            columnDefs: const [OsColumnDef(field: 'name')],
            rowData: const [
              <String, dynamic>{'name': 'Alice'},
              <String, dynamic>{'name': 'Bob'},
            ],
            showInspector: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('quick filter off'), findsOneWidget);
      expect(find.textContaining('overlay auto'), findsOneWidget);

      controller.setQuickFilter('ali');
      await tester.pumpAndSettle();
      expect(find.textContaining('quick filter on "ali"'), findsOneWidget);

      controller.showLoadingOverlay();
      await tester.pumpAndSettle();
      expect(find.textContaining('overlay loading'), findsOneWidget);

      controller.hideOverlay();
      await tester.pumpAndSettle();
      expect(find.textContaining('overlay auto'), findsOneWidget);
    });

    testWidgets('column counts reflect hidden columns', (tester) async {
      final controller = OsGridController<Row>();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          OsGrid<Row>(
            controller: controller,
            columnDefs: const [
              OsColumnDef(field: 'name'),
              OsColumnDef(field: 'age'),
              OsColumnDef(field: 'email', hide: true),
            ],
            rowData: const [
              <String, dynamic>{'name': 'Alice', 'age': 30, 'email': 'a@x.io'},
            ],
            showInspector: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('cols 2/3 · hidden 1'), findsOneWidget);
    });
  });
}
