import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

/// In-memory datasource for infinite-mode tests.
class _TestDatasource extends OsInfiniteDatasource<Map<String, dynamic>> {
  _TestDatasource({required this.totalRows});

  final int totalRows;

  @override
  void getRows(OsInfiniteGetRowsParams<Map<String, dynamic>> params) {
    final rows = <Map<String, dynamic>>[];
    final end = params.endRow.clamp(0, totalRows);
    for (int i = params.startRow; i < end; i++) {
      rows.add({'name': 'Row $i'});
    }
    final lastRow = end >= totalRows ? totalRows : null;
    params.successCallback(rows, lastRow: lastRow);
  }
}

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

void main() {
  group('Controller display accessors', () {
    testWidgets(
      'getDisplayedRowCount / getDisplayedRowAtIndex respect pagination slice',
      (tester) async {
        final controller = OsGridController<Map<String, dynamic>>();
        final rows = List<Map<String, dynamic>>.generate(
          25,
          (i) => {'name': 'Row $i'},
        );

        await tester.pumpWidget(
          _wrap(
            OsGrid<Map<String, dynamic>>(
              controller: controller,
              columnDefs: [const OsColumnDef(field: 'name')],
              rowData: rows,
              pagination: const OsPagination(pageSize: 10),
            ),
          ),
        );
        await tester.pump();

        expect(controller.getDisplayedRowCount(), 10);
        expect(controller.getDisplayedRowAtIndex(0), rows[0]);
        expect(controller.getDisplayedRowAtIndex(9), rows[9]);
        expect(controller.getDisplayedRowAtIndex(10), isNull);

        controller.paginationGoToLastPage();
        await tester.pump();
        await tester.pump();

        expect(controller.getDisplayedRowCount(), 5);
        expect(controller.getDisplayedRowAtIndex(4), rows[24]);
        expect(controller.getDisplayedRowAtIndex(-1), isNull);

        controller.dispose();
      },
    );

    testWidgets('accessors reflect filtered data without pagination', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();
      final rows = [
        {'name': 'Alice'},
        {'name': 'Bob'},
        {'name': 'Alex'},
      ];

      await tester.pumpWidget(
        _wrap(
          OsGrid<Map<String, dynamic>>(
            controller: controller,
            columnDefs: [
              const OsColumnDef(field: 'name', filter: OsTextFilter()),
            ],
            rowData: rows,
          ),
        ),
      );
      await tester.pump();

      expect(controller.getDisplayedRowCount(), 3);
      expect(controller.getVirtualRowCount(), 3);
      expect(controller.getDisplayedRowAtIndex(0)!, {'name': 'Alice'});
      expect(controller.isLastRowFound(), isFalse);

      controller.setFilterModel({
        'name': {'filterType': 'text', 'type': 'contains', 'filter': 'Al'},
      });
      await tester.pump();
      await tester.pump();

      expect(controller.getDisplayedRowCount(), 2);
      expect(controller.getDisplayedRowAtIndex(1), {'name': 'Alex'});

      controller.dispose();
    });

    testWidgets('getVirtualRowCount + isLastRowFound use block-cache knowledge '
        'in infinite mode', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(
        _wrap(
          OsGrid<Map<String, dynamic>>(
            controller: controller,
            columnDefs: [const OsColumnDef(field: 'name')],
            infiniteRowModel: const OsInfiniteRowModel(cacheBlockSize: 100),
            datasource: _TestDatasource(totalRows: 50),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      // The datasource reported lastRow=50 for the first block request.
      expect(controller.isLastRowFound(), isTrue);
      expect(controller.getVirtualRowCount(), 50);

      controller.dispose();
    });
  });

  group('Overlays', () {
    Future<OsGridController<Map<String, dynamic>>> pumpLoading(
      WidgetTester tester, {
      bool? loading,
      Widget? loadingOverlay,
      Widget? noRowsOverlay,
      List<Map<String, dynamic>>? rowData,
    }) async {
      final controller = OsGridController<Map<String, dynamic>>();
      await tester.pumpWidget(
        _wrap(
          OsGrid<Map<String, dynamic>>(
            controller: controller,
            columnDefs: [const OsColumnDef(field: 'name')],
            loading: loading,
            loadingOverlay: loadingOverlay,
            noRowsOverlay: noRowsOverlay,
            rowData:
                rowData ??
                [
                  {'name': 'Alice'},
                ],
          ),
        ),
      );
      await tester.pump();
      return controller;
    }

    testWidgets('loading shows default localized panel above grid', (
      tester,
    ) async {
      final controller = await pumpLoading(tester, loading: true);

      expect(find.text('Loading...'), findsOneWidget);
      expect(find.byType(VirtualisedGrid), findsOneWidget);

      // The overlay's own IgnorePointer must be active.
      final loadingAncestors = find
          .ancestor(
            of: find.text('Loading...'),
            matching: find.byType(IgnorePointer),
          )
          .evaluate();
      expect(
        loadingAncestors.any((w) => (w.widget as IgnorePointer).ignoring),
        isTrue,
      );

      controller.dispose();
    });

    testWidgets('custom loadingOverlay takes precedence', (tester) async {
      final controller = await pumpLoading(
        tester,
        loading: true,
        loadingOverlay: const KeyedSubtree(
          key: ValueKey('custom-loading'),
          child: SizedBox.expand(),
        ),
      );

      expect(find.byKey(const ValueKey('custom-loading')), findsOneWidget);
      expect(find.text('Loading...'), findsNothing);

      controller.dispose();
    });

    testWidgets('no-rows overlay shows when displayed rows are empty', (
      tester,
    ) async {
      final controller = await pumpLoading(tester, rowData: []);

      expect(find.text('No Rows To Show'), findsOneWidget);
      final emptyAncestors = find
          .ancestor(
            of: find.text('No Rows To Show'),
            matching: find.byType(IgnorePointer),
          )
          .evaluate();
      expect(
        emptyAncestors.any((w) => (w.widget as IgnorePointer).ignoring),
        isTrue,
      );

      controller.dispose();
    });

    testWidgets('custom noRowsOverlay takes precedence', (tester) async {
      final controller = await pumpLoading(
        tester,
        rowData: [],
        noRowsOverlay: const KeyedSubtree(
          key: ValueKey('custom-empty'),
          child: SizedBox.expand(),
        ),
      );

      expect(find.byKey(const ValueKey('custom-empty')), findsOneWidget);
      expect(find.text('No Rows To Show'), findsNothing);

      controller.dispose();
    });

    testWidgets('no overlay when not loading and rows exist', (tester) async {
      final controller = await pumpLoading(tester);

      expect(find.text('Loading...'), findsNothing);
      expect(find.text('No Rows To Show'), findsNothing);

      controller.dispose();
    });
  });

  group('Lifecycle events', () {
    testWidgets('onFirstDataRendered fires exactly once, dual emission', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();
      var callbackCount = 0;
      var streamCount = 0;
      // NOTE: intentionally not cancelled â€” awaiting StreamSubscription
      // .cancel() inside testWidgets deadlocks teardown on this SDK.
      controller.onFirstDataRendered.listen((_) => streamCount++);

      final rows = [
        {'name': 'Alice'},
      ];
      await tester.pumpWidget(
        _wrap(
          OsGrid<Map<String, dynamic>>(
            controller: controller,
            columnDefs: [const OsColumnDef(field: 'name')],
            rowData: rows,
            onFirstDataRendered: (_) => callbackCount++,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      // Extra rebuilds/interactions must not re-fire it.
      await tester.pumpWidget(
        _wrap(
          OsGrid<Map<String, dynamic>>(
            controller: controller,
            columnDefs: [const OsColumnDef(field: 'name')],
            rowData: rows,
            onFirstDataRendered: (_) => callbackCount++,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(callbackCount, 1);
      expect(streamCount, 1);

      controller.dispose();
    });

    testWidgets(
      'onFirstDataRendered waits for non-empty data after empty start',
      (tester) async {
        final controller = OsGridController<Map<String, dynamic>>();
        var callbackCount = 0;

        Widget buildGrid(List<Map<String, dynamic>> rows) => _wrap(
          OsGrid<Map<String, dynamic>>(
            controller: controller,
            columnDefs: [const OsColumnDef(field: 'name')],
            rowData: rows,
            onFirstDataRendered: (_) => callbackCount++,
          ),
        );

        await tester.pumpWidget(buildGrid([]));
        await tester.pump();
        await tester.pump();
        expect(callbackCount, 0);

        await tester.pumpWidget(
          buildGrid([
            {'name': 'Alice'},
          ]),
        );
        await tester.pump();
        await tester.pump();

        expect(callbackCount, 1);

        controller.dispose();
      },
    );

    testWidgets(
      'onGridSizeChanged skips first layout and emits actual size changes',
      (tester) async {
        final controller = OsGridController<Map<String, dynamic>>();
        final events = <OsGridSizeChangedEvent>[];

        Widget buildGrid(double height) => _wrap(
          SizedBox(
            height: height,
            child: OsGrid<Map<String, dynamic>>(
              controller: controller,
              columnDefs: [const OsColumnDef(field: 'name')],
              rowData: [
                {'name': 'Alice'},
              ],
              onGridSizeChanged: events.add,
            ),
          ),
        );

        await tester.pumpWidget(buildGrid(400));
        await tester.pump();
        expect(events, isEmpty); // first layout never emits

        await tester.pumpWidget(buildGrid(600));
        await tester.pump();
        await tester.pump();

        expect(events.length, 1);
        expect(events.first.height, 600);
        expect(events.first.width, greaterThan(0));

        // Same size again â€” no duplicate emission.
        await tester.pumpWidget(buildGrid(600));
        await tester.pump();
        expect(events.length, 1);

        controller.dispose();
      },
    );

    testWidgets('onModelUpdated fires on filter set and page change', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();
      var callbackCount = 0;
      var streamCount = 0;
      // NOTE: intentionally not cancelled — awaiting StreamSubscription
      // .cancel() inside testWidgets deadlocks teardown on this SDK.
      controller.onModelUpdated.listen((_) => streamCount++);

      final rows = List<Map<String, dynamic>>.generate(
        25,
        (i) => {'name': 'Row $i'},
      );
      await tester.pumpWidget(
        _wrap(
          OsGrid<Map<String, dynamic>>(
            controller: controller,
            columnDefs: [const OsColumnDef(field: 'name')],
            rowData: rows,
            pagination: const OsPagination(pageSize: 10),
            onModelUpdated: (_) => callbackCount++,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      final baselineCallback = callbackCount;
      final baselineStream = streamCount;

      controller.setFilterModel({
        'name': {'filterType': 'text', 'type': 'contains', 'filter': 'Row 1'},
      });
      await tester.pump();
      await tester.pump();

      expect(callbackCount, greaterThan(baselineCallback));
      expect(streamCount, greaterThan(baselineStream));

      final afterFilterCallback = callbackCount;

      controller.paginationGoToNextPage();
      await tester.pump();
      await tester.pump();

      expect(callbackCount, greaterThan(afterFilterCallback));

      controller.dispose();
    });

    testWidgets('onModelUpdated coalesces same-frame reprocesses', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();
      var streamCount = 0;
      // NOTE: intentionally not cancelled — awaiting StreamSubscription
      // .cancel() inside testWidgets deadlocks teardown on this SDK.
      controller.onModelUpdated.listen((_) => streamCount++);

      await tester.pumpWidget(
        _wrap(
          OsGrid<Map<String, dynamic>>(
            controller: controller,
            columnDefs: [const OsColumnDef(field: 'name')],
            rowData: [
              {'name': 'Alice'},
              {'name': 'Bob'},
            ],
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      final baseline = streamCount;

      // Two rapid filter updates inside one frame â€” one event.
      controller.setFilterModel({
        'name': {'filterType': 'text', 'type': 'contains', 'filter': 'A'},
      });
      controller.setFilterModel({
        'name': {'filterType': 'text', 'type': 'contains', 'filter': 'Ali'},
      });
      await tester.pump();
      await tester.pump();

      expect(streamCount, baseline + 1);

      controller.dispose();
    });

    testWidgets('onRowDataChanged fires before pipeline on reference change', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();
      final callbackObservedCounts = <int>[];
      var streamCount = 0;
      // NOTE: intentionally not cancelled — awaiting StreamSubscription
      // .cancel() inside testWidgets deadlocks teardown on this SDK.
      controller.onRowDataChanged.listen((_) => streamCount++);

      final rows = [
        {'name': 'Alice'},
        {'name': 'Bob'},
      ];
      final nextRows = [
        {'name': 'Alice'},
        {'name': 'Bob'},
        {'name': 'Carol'},
        {'name': 'Dave'},
      ];

      Widget buildGrid(List<Map<String, dynamic>> data) => _wrap(
        OsGrid<Map<String, dynamic>>(
          controller: controller,
          columnDefs: [const OsColumnDef(field: 'name')],
          rowData: data,
          onRowDataChanged: (_) =>
              callbackObservedCounts.add(controller.getDisplayedRowCount()),
        ),
      );

      await tester.pumpWidget(buildGrid(rows));
      await tester.pump();

      await tester.pumpWidget(buildGrid(nextRows));
      await tester.pump();
      await tester.pump();

      expect(callbackObservedCounts.length, 1);
      // The widget callback observed the OLD processed count â€” proving it
      // ran before the filter/sort pipeline processed the new list.
      expect(callbackObservedCounts.first, 2);
      // Stream received exactly one event for the one reference change.
      expect(streamCount, 1);
      // After processing, accessors see the new data.
      expect(controller.getDisplayedRowCount(), 4);

      controller.dispose();
    });

    testWidgets('onRowDataChanged does not fire for identical instance', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();
      var callbackCount = 0;

      final rows = [
        {'name': 'Alice'},
      ];

      Widget buildGrid() => _wrap(
        OsGrid<Map<String, dynamic>>(
          controller: controller,
          columnDefs: [const OsColumnDef(field: 'name')],
          rowData: rows,
          onRowDataChanged: (_) => callbackCount++,
        ),
      );

      await tester.pumpWidget(buildGrid());
      await tester.pump();
      await tester.pumpWidget(buildGrid());
      await tester.pump();

      expect(callbackCount, 0);

      controller.dispose();
    });
  });
}
