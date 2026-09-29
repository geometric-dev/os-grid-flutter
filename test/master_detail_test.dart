import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

void main() {
  List<Map<String, dynamic>> sampleData() => [
    {'id': '1', 'name': 'Alice'},
    {'id': '2', 'name': 'Bob'},
    {'id': '3', 'name': 'Charlie'},
  ];

  Widget buildGrid({
    required OsGridController<Map<String, dynamic>> controller,
    required bool Function(Map<String, dynamic>) isMasterRow,
    Widget Function(Map<String, dynamic>, int)? detailWidgetBuilder,
    double Function(Map<String, dynamic>)? detailRowHeight,
    List<Map<String, dynamic>>? rowData,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 400,
          height: 300,
          child: OsGrid<Map<String, dynamic>>(
            controller: controller,
            columnDefs: const [
              OsColumnDef(field: 'name', headerName: 'Name', width: 200.0),
            ],
            rowData: rowData ?? sampleData(),
            getRowId: (data) => data['id'] as String,
            isMasterRow: isMasterRow,
            detailWidgetBuilder: detailWidgetBuilder,
            detailRowHeight: detailRowHeight,
          ),
        ),
      ),
    );
  }

  VirtualisedGrid virtualisedGrid(WidgetTester tester) =>
      tester.widget<VirtualisedGrid>(find.byType(VirtualisedGrid));

  group('master/detail rows', () {
    testWidgets('display row count matches data when nothing is expanded', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();
      await tester.pumpWidget(
        buildGrid(
          controller: controller,
          isMasterRow: (data) => data['id'] == '1',
          detailWidgetBuilder: (data, rowIndex) => Text('DETAIL:${data['id']}'),
        ),
      );
      await tester.pumpAndSettle();

      expect(virtualisedGrid(tester).rowData, hasLength(3));
      expect(virtualisedGrid(tester).rowHeightLayout, isNull);
      expect(controller.isDetailRowExpanded(0), isFalse);
    });

    testWidgets('expanding a master row inserts a detail row in the display', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();
      await tester.pumpWidget(
        buildGrid(
          controller: controller,
          isMasterRow: (data) => data['id'] == '1',
          detailWidgetBuilder: (data, rowIndex) => Text('DETAIL:${data['id']}'),
          detailRowHeight: (_) => 150.0,
        ),
      );
      await tester.pumpAndSettle();

      controller.expandDetailRow(0);
      await tester.pumpAndSettle();

      final grid = virtualisedGrid(tester);
      expect(grid.rowData, hasLength(4)); // 3 data rows + 1 detail row
      expect(grid.rowData[0][MasterDetailKeys.isMasterRow], isTrue);
      expect(grid.rowData[0]['name'], 'Alice');
      expect(grid.rowData[1][MasterDetailKeys.isDetailRow], isTrue);
      expect(grid.rowData[1][MasterDetailKeys.detailSource], sampleData()[0]);
      expect(grid.rowData[1][MasterDetailKeys.detailMasterIndex], 0);
      expect(grid.rowData[2]['name'], 'Bob');
      expect(grid.rowData[3]['name'], 'Charlie');
      expect(controller.isDetailRowExpanded(0), isTrue);
    });

    testWidgets('detail height is reflected in the row height layout', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();
      await tester.pumpWidget(
        buildGrid(
          controller: controller,
          isMasterRow: (data) => data['id'] == '1',
          detailWidgetBuilder: (data, rowIndex) => Text('DETAIL:${data['id']}'),
          detailRowHeight: (_) => 150.0,
        ),
      );
      await tester.pumpAndSettle();

      controller.expandDetailRow(0);
      await tester.pumpAndSettle();

      final layout = virtualisedGrid(tester).rowHeightLayout;
      expect(layout, isNotNull);
      expect(layout!.getRowHeight(0), 42.0); // master row keeps normal height
      expect(layout.getRowHeight(1), 150.0); // detail row
      expect(layout.getRowHeight(2), 42.0);
      expect(layout.totalHeight, 42.0 * 3 + 150.0);
      // The master row's top is unchanged; rows below the detail shift down.
      expect(layout.getRowTop(0), 0.0);
      expect(layout.getRowTop(1), 42.0);
      expect(layout.getRowTop(2), 42.0 + 150.0);
    });

    testWidgets('uses the default detail height when detailRowHeight is null', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();
      await tester.pumpWidget(
        buildGrid(
          controller: controller,
          isMasterRow: (data) => data['id'] == '1',
          detailWidgetBuilder: (data, rowIndex) => Text('DETAIL:${data['id']}'),
        ),
      );
      await tester.pumpAndSettle();

      controller.expandDetailRow(0);
      await tester.pumpAndSettle();

      final layout = virtualisedGrid(tester).rowHeightLayout;
      expect(layout, isNotNull);
      expect(layout!.getRowHeight(1), kDefaultDetailRowHeight);
    });

    testWidgets('collapsing restores the original display and layout', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();
      await tester.pumpWidget(
        buildGrid(
          controller: controller,
          isMasterRow: (data) => data['id'] == '1',
          detailWidgetBuilder: (data, rowIndex) => Text('DETAIL:${data['id']}'),
          detailRowHeight: (_) => 150.0,
        ),
      );
      await tester.pumpAndSettle();

      controller.expandDetailRow(0);
      await tester.pumpAndSettle();
      expect(virtualisedGrid(tester).rowData, hasLength(4));

      controller.collapseDetailRow(0);
      await tester.pumpAndSettle();

      final grid = virtualisedGrid(tester);
      expect(grid.rowData, hasLength(3));
      expect(grid.rowHeightLayout, isNull);
      expect(find.textContaining('DETAIL'), findsNothing);
      expect(controller.isDetailRowExpanded(0), isFalse);
    });

    testWidgets('isMasterRow is consulted per row', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();
      final consultedIds = <String>{};
      await tester.pumpWidget(
        buildGrid(
          controller: controller,
          isMasterRow: (data) {
            consultedIds.add(data['id'] as String);
            return data['id'] == '1';
          },
          detailWidgetBuilder: (data, rowIndex) => Text('DETAIL:${data['id']}'),
        ),
      );
      await tester.pumpAndSettle();

      expect(consultedIds, {'1', '2', '3'});
      // Only the matching row is a master row.
      expect(
        virtualisedGrid(tester).rowData[0][MasterDetailKeys.isMasterRow],
        isTrue,
      );
      expect(
        virtualisedGrid(tester).rowData[1][MasterDetailKeys.isMasterRow],
        isNull,
      );
      expect(
        virtualisedGrid(tester).rowData[2][MasterDetailKeys.isMasterRow],
        isNull,
      );
    });

    testWidgets('non-master rows cannot be expanded', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();
      await tester.pumpWidget(
        buildGrid(
          controller: controller,
          isMasterRow: (data) => data['id'] == '1',
          detailWidgetBuilder: (data, rowIndex) => Text('DETAIL:${data['id']}'),
        ),
      );
      await tester.pumpAndSettle();

      controller.expandDetailRow(1); // Bob — not a master row
      await tester.pumpAndSettle();

      expect(virtualisedGrid(tester).rowData, hasLength(3));
      expect(controller.isDetailRowExpanded(1), isFalse);
    });

    testWidgets('detailWidgetBuilder is called for expanded rows only', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();
      final builtCalls = <({String id, int rowIndex})>[];
      await tester.pumpWidget(
        buildGrid(
          controller: controller,
          isMasterRow: (data) => data['id'] == '1' || data['id'] == '3',
          detailWidgetBuilder: (data, rowIndex) {
            builtCalls.add((id: data['id'] as String, rowIndex: rowIndex));
            return Text('DETAIL:${data['id']}:$rowIndex');
          },
          detailRowHeight: (_) => 100.0,
        ),
      );
      await tester.pumpAndSettle();

      // Nothing expanded yet — the builder has not been called.
      expect(builtCalls, isEmpty);
      expect(find.textContaining('DETAIL'), findsNothing);

      controller.expandDetailRow(0);
      await tester.pumpAndSettle();

      expect(
        builtCalls.any((call) => call.id == '1' && call.rowIndex == 0),
        isTrue,
      );
      expect(
        builtCalls.any((call) => call.id == '3'),
        isFalse, // master row 2 is still collapsed
      );
      expect(find.text('DETAIL:1:0'), findsOneWidget);
    });

    testWidgets('detail widget is positioned at the detail row rect', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();
      await tester.pumpWidget(
        buildGrid(
          controller: controller,
          isMasterRow: (data) => data['id'] == '1',
          detailWidgetBuilder: (data, rowIndex) => Text('DETAIL:${data['id']}'),
          detailRowHeight: (_) => 150.0,
        ),
      );
      await tester.pumpAndSettle();

      controller.expandDetailRow(0);
      await tester.pumpAndSettle();

      // Detail row sits directly below master row 0: header (48) + row (42).
      final rect = tester.getRect(find.text('DETAIL:1'));
      expect(rect.left, 0.0);
      expect(rect.top, 48.0 + 42.0);
      expect(rect.width, 400.0);
      expect(rect.height, 150.0);
    });

    testWidgets('tapping a master row toggles its detail area', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();
      await tester.pumpWidget(
        buildGrid(
          controller: controller,
          isMasterRow: (data) => data['id'] == '1',
          detailWidgetBuilder: (data, rowIndex) => Text('DETAIL:${data['id']}'),
          detailRowHeight: (_) => 150.0,
        ),
      );
      await tester.pumpAndSettle();

      // Row 0 centre: header (48) + half row height (21); x within the
      // single 200px column. Pumping past the double-tap timeout resolves
      // the tap arena.
      await tester.tapAt(const Offset(100, 48 + 21));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(virtualisedGrid(tester).rowData, hasLength(4));
      expect(controller.isDetailRowExpanded(0), isTrue);

      await tester.tapAt(const Offset(100, 48 + 21));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(virtualisedGrid(tester).rowData, hasLength(3));
      expect(controller.isDetailRowExpanded(0), isFalse);
    });

    testWidgets('multiple master rows can be expanded independently', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();
      await tester.pumpWidget(
        buildGrid(
          controller: controller,
          isMasterRow: (data) => data['id'] == '1' || data['id'] == '3',
          detailWidgetBuilder: (data, rowIndex) => Text('DETAIL:${data['id']}'),
          detailRowHeight: (_) => 60.0,
        ),
      );
      await tester.pumpAndSettle();

      controller.expandDetailRow(0);
      await tester.pumpAndSettle();
      expect(virtualisedGrid(tester).rowData, hasLength(4));

      // Charlie is now display row 3 (after Alice's detail row).
      controller.expandDetailRow(3);
      await tester.pumpAndSettle();
      final grid = virtualisedGrid(tester);
      expect(grid.rowData, hasLength(5));
      expect(grid.rowData[4]['name'], isNull); // detail row, not data
      expect(controller.isDetailRowExpanded(0), isTrue);
      expect(controller.isDetailRowExpanded(3), isTrue);

      // Collapsing the first detail does not disturb the second. Note the
      // display-index shift: Charlie's master row is now display row 2.
      controller.collapseDetailRow(0);
      await tester.pumpAndSettle();
      expect(virtualisedGrid(tester).rowData, hasLength(4));
      expect(controller.isDetailRowExpanded(2), isTrue);
      expect(
        controller.isDetailRowExpanded(3),
        isFalse,
      ); // now Charlie's detail
    });

    testWidgets('expansion state survives a data refresh by row id', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();
      await tester.pumpWidget(
        buildGrid(
          controller: controller,
          isMasterRow: (data) => data['id'] == '1',
          detailWidgetBuilder: (data, rowIndex) => Text('DETAIL:${data['id']}'),
        ),
      );
      await tester.pumpAndSettle();

      controller.expandDetailRow(0);
      await tester.pumpAndSettle();
      expect(virtualisedGrid(tester).rowData, hasLength(4));

      // Push a fresh (identical-content) row list through the controller.
      controller.setRowData(sampleData());
      await tester.pumpAndSettle();

      expect(virtualisedGrid(tester).rowData, hasLength(4));
      expect(controller.isDetailRowExpanded(0), isTrue);
    });
  });

  group('DetailExpansionState', () {
    test('expand/collapse/isExpanded per row id', () {
      final state = DetailExpansionState();
      expect(state.isExpanded('a'), isFalse);
      state.expand('a');
      expect(state.isExpanded('a'), isTrue);
      state.expand('b');
      expect(state.expandedRowIds, {'a', 'b'});
      state.collapse('a');
      expect(state.isExpanded('a'), isFalse);
      expect(state.isExpanded('b'), isTrue);
      state.setExpanded('b', expanded: false);
      expect(state.isExpanded('b'), isFalse);
    });

    test('clear collapses everything', () {
      final state = DetailExpansionState();
      state.expand('a');
      state.expand('b');
      state.clear();
      expect(state.expandedRowIds, isEmpty);
    });
  });
}
