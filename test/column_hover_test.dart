import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

void main() {
  group('OsColumnHoverChangedEvent', () {
    test('stores column ID', () {
      const event = OsColumnHoverChangedEvent(column: 'name');
      expect(event.column, 'name');
    });

    test('column can be null (pointer left grid)', () {
      const event = OsColumnHoverChangedEvent(column: null);
      expect(event.column, isNull);
    });

    test('default constructor has null column', () {
      const event = OsColumnHoverChangedEvent();
      expect(event.column, isNull);
    });
  });

  group('OsGridController.isColumnHovered', () {
    test('returns false when no column is hovered', () {
      final controller = OsGridController<Map<String, dynamic>>();
      expect(controller.isColumnHovered('name'), isFalse);
      expect(controller.isColumnHovered('age'), isFalse);
      controller.dispose();
    });

    test('returns true for the hovered column after event emission', () {
      final controller = OsGridController<Map<String, dynamic>>();
      controller.emitColumnHoverChanged(
        const OsColumnHoverChangedEvent(column: 'name'),
      );
      expect(controller.isColumnHovered('name'), isTrue);
      expect(controller.isColumnHovered('age'), isFalse);
      controller.dispose();
    });

    test('returns false after hover clears', () {
      final controller = OsGridController<Map<String, dynamic>>();
      controller.emitColumnHoverChanged(
        const OsColumnHoverChangedEvent(column: 'name'),
      );
      expect(controller.isColumnHovered('name'), isTrue);

      controller.emitColumnHoverChanged(
        const OsColumnHoverChangedEvent(column: null),
      );
      expect(controller.isColumnHovered('name'), isFalse);
      controller.dispose();
    });

    test('tracks column changes correctly', () {
      final controller = OsGridController<Map<String, dynamic>>();
      controller.emitColumnHoverChanged(
        const OsColumnHoverChangedEvent(column: 'name'),
      );
      expect(controller.isColumnHovered('name'), isTrue);

      controller.emitColumnHoverChanged(
        const OsColumnHoverChangedEvent(column: 'age'),
      );
      expect(controller.isColumnHovered('name'), isFalse);
      expect(controller.isColumnHovered('age'), isTrue);
      controller.dispose();
    });
  });

  group('OsGridController.onColumnHoverChanged stream', () {
    test('emits events when column hover changes', () async {
      final controller = OsGridController<Map<String, dynamic>>();
      final events = <OsColumnHoverChangedEvent>[];
      final sub = controller.onColumnHoverChanged.listen(events.add);

      controller.emitColumnHoverChanged(
        const OsColumnHoverChangedEvent(column: 'name'),
      );
      controller.emitColumnHoverChanged(
        const OsColumnHoverChangedEvent(column: 'age'),
      );
      controller.emitColumnHoverChanged(
        const OsColumnHoverChangedEvent(column: null),
      );

      await Future<void>.delayed(Duration.zero);

      expect(events, hasLength(3));
      expect(events[0].column, 'name');
      expect(events[1].column, 'age');
      expect(events[2].column, isNull);

      await sub.cancel();
      controller.dispose();
    });

    test('stream is broadcast (multiple listeners)', () async {
      final controller = OsGridController<Map<String, dynamic>>();
      final events1 = <OsColumnHoverChangedEvent>[];
      final events2 = <OsColumnHoverChangedEvent>[];
      final sub1 = controller.onColumnHoverChanged.listen(events1.add);
      final sub2 = controller.onColumnHoverChanged.listen(events2.add);

      controller.emitColumnHoverChanged(
        const OsColumnHoverChangedEvent(column: 'name'),
      );

      await Future<void>.delayed(Duration.zero);

      expect(events1, hasLength(1));
      expect(events2, hasLength(1));

      await sub1.cancel();
      await sub2.cancel();
      controller.dispose();
    });
  });

  group('OsGrid columnHoverHighlight widget integration', () {
    testWidgets('grid renders with columnHoverHighlight enabled', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: OsGrid<Map<String, dynamic>>(
                columnDefs: [
                  OsColumnDef(field: 'name', headerName: 'Name'),
                  OsColumnDef(field: 'age', headerName: 'Age'),
                ],
                rowData: [
                  {'name': 'Alice', 'age': 30},
                  {'name': 'Bob', 'age': 25},
                ],
                columnHoverHighlight: true,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(OsGrid<Map<String, dynamic>>), findsOneWidget);
    });

    testWidgets('grid renders with columnHoverHighlight disabled (default)', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: OsGrid<Map<String, dynamic>>(
                columnDefs: [
                  OsColumnDef(field: 'name', headerName: 'Name'),
                  OsColumnDef(field: 'age', headerName: 'Age'),
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

      expect(find.byType(OsGrid<Map<String, dynamic>>), findsOneWidget);
    });

    testWidgets('onColumnHoverChanged callback is accepted without error', (
      tester,
    ) async {
      OsColumnHoverChangedEvent? receivedEvent;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: OsGrid<Map<String, dynamic>>(
                columnDefs: const [
                  OsColumnDef(field: 'name', headerName: 'Name'),
                  OsColumnDef(field: 'age', headerName: 'Age'),
                ],
                rowData: const [
                  {'name': 'Alice', 'age': 30},
                  {'name': 'Bob', 'age': 25},
                ],
                columnHoverHighlight: true,
                onColumnHoverChanged: (event) {
                  receivedEvent = event;
                },
              ),
            ),
          ),
        ),
      );

      // Grid renders without error with the callback
      expect(find.byType(OsGrid<Map<String, dynamic>>), findsOneWidget);
      // No hover yet
      expect(receivedEvent, isNull);
    });

    testWidgets('controller stream is accessible with columnHoverHighlight', (
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
                  OsColumnDef(field: 'name', headerName: 'Name'),
                  OsColumnDef(field: 'age', headerName: 'Age'),
                ],
                rowData: const [
                  {'name': 'Alice', 'age': 30},
                  {'name': 'Bob', 'age': 25},
                ],
                columnHoverHighlight: true,
              ),
            ),
          ),
        ),
      );

      // isColumnHovered returns false when nothing is hovered
      expect(controller.isColumnHovered('name'), isFalse);
      expect(controller.isColumnHovered('age'), isFalse);
    });

    testWidgets('columnHoverHighlight with custom theme colour', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: OsGrid<Map<String, dynamic>>(
                columnDefs: const [
                  OsColumnDef(field: 'name', headerName: 'Name'),
                  OsColumnDef(field: 'age', headerName: 'Age'),
                ],
                rowData: const [
                  {'name': 'Alice', 'age': 30},
                  {'name': 'Bob', 'age': 25},
                ],
                columnHoverHighlight: true,
                theme: OsGridTheme(
                  columnHoverColor: Colors.blue.withValues(alpha: 0.1),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(OsGrid<Map<String, dynamic>>), findsOneWidget);
    });

    testWidgets('columnHoverHighlight works with pinned columns', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: OsGrid<Map<String, dynamic>>(
                columnDefs: [
                  OsColumnDef(
                    field: 'id',
                    headerName: 'ID',
                    pinned: OsColumnPin.left,
                  ),
                  OsColumnDef(field: 'name', headerName: 'Name'),
                  OsColumnDef(field: 'age', headerName: 'Age'),
                  OsColumnDef(
                    field: 'status',
                    headerName: 'Status',
                    pinned: OsColumnPin.right,
                  ),
                ],
                rowData: [
                  {'id': 1, 'name': 'Alice', 'age': 30, 'status': 'active'},
                  {'id': 2, 'name': 'Bob', 'age': 25, 'status': 'inactive'},
                ],
                columnHoverHighlight: true,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(OsGrid<Map<String, dynamic>>), findsOneWidget);
    });

    testWidgets('columnHoverHighlight works with sorting enabled', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: OsGrid<Map<String, dynamic>>(
                columnDefs: [
                  OsColumnDef(field: 'name', headerName: 'Name'),
                  OsColumnDef(field: 'age', headerName: 'Age'),
                ],
                rowData: [
                  {'name': 'Alice', 'age': 30},
                  {'name': 'Bob', 'age': 25},
                ],
                columnHoverHighlight: true,
                initialSort: [
                  OsSortModel(colId: 'name', sort: OsSortDirection.ascending),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byType(OsGrid<Map<String, dynamic>>), findsOneWidget);
    });

    testWidgets('columnHoverHighlight works with filtering enabled', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: OsGrid<Map<String, dynamic>>(
                columnDefs: [
                  OsColumnDef(
                    field: 'name',
                    headerName: 'Name',
                    filter: OsTextFilter(),
                  ),
                  OsColumnDef(field: 'age', headerName: 'Age'),
                ],
                rowData: [
                  {'name': 'Alice', 'age': 30},
                  {'name': 'Bob', 'age': 25},
                ],
                columnHoverHighlight: true,
                floatingFilter: true,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(OsGrid<Map<String, dynamic>>), findsOneWidget);
    });

    testWidgets('columnHoverHighlight works with pagination', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: OsGrid<Map<String, dynamic>>(
                columnDefs: [
                  OsColumnDef(field: 'name', headerName: 'Name'),
                  OsColumnDef(field: 'age', headerName: 'Age'),
                ],
                rowData: [
                  {'name': 'Alice', 'age': 30},
                  {'name': 'Bob', 'age': 25},
                  {'name': 'Charlie', 'age': 35},
                ],
                columnHoverHighlight: true,
                pagination: OsPagination(pageSize: 2),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(OsGrid<Map<String, dynamic>>), findsOneWidget);
    });
  });

  group('VirtualisedGrid columnHoverHighlight', () {
    testWidgets('passes columnHoverHighlight to VirtualisedGrid', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: OsGrid<Map<String, dynamic>>(
                columnDefs: [
                  OsColumnDef(field: 'name', headerName: 'Name'),
                  OsColumnDef(field: 'age', headerName: 'Age'),
                ],
                rowData: [
                  {'name': 'Alice', 'age': 30},
                  {'name': 'Bob', 'age': 25},
                ],
                columnHoverHighlight: true,
              ),
            ),
          ),
        ),
      );

      // Find the VirtualisedGrid and verify it received the property
      final virtualisedGrid = tester.widget<VirtualisedGrid>(
        find.byType(VirtualisedGrid),
      );
      expect(virtualisedGrid.columnHoverHighlight, isTrue);
    });

    testWidgets('columnHoverHighlight defaults to false in VirtualisedGrid', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: OsGrid<Map<String, dynamic>>(
                columnDefs: [
                  OsColumnDef(field: 'name', headerName: 'Name'),
                  OsColumnDef(field: 'age', headerName: 'Age'),
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

      final virtualisedGrid = tester.widget<VirtualisedGrid>(
        find.byType(VirtualisedGrid),
      );
      expect(virtualisedGrid.columnHoverHighlight, isFalse);
    });
  });

  group('OsGridTheme.columnHoverColor', () {
    test('defaults to null', () {
      const theme = OsGridTheme();
      expect(theme.columnHoverColor, isNull);
    });

    test('accepts custom colour', () {
      final theme = OsGridTheme(
        columnHoverColor: Colors.red.withValues(alpha: 0.1),
      );
      expect(theme.columnHoverColor, isNotNull);
      expect(theme.columnHoverColor!.a, closeTo(0.1, 0.01));
    });
  });
}
