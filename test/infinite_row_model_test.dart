import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

/// A simple in-memory datasource for testing.
class TestDatasource extends OsInfiniteDatasource<Map<String, dynamic>> {
  TestDatasource({
    required this.totalRows,
    this.delay = Duration.zero,
    this.shouldFail = false,
  });

  final int totalRows;
  final Duration delay;
  bool shouldFail;

  int getRowsCallCount = 0;
  List<OsInfiniteGetRowsParams<Map<String, dynamic>>> requests = [];

  @override
  void getRows(OsInfiniteGetRowsParams<Map<String, dynamic>> params) {
    getRowsCallCount++;
    requests.add(params);

    if (shouldFail) {
      if (delay > Duration.zero) {
        Future.delayed(delay, params.failCallback);
      } else {
        params.failCallback();
      }
      return;
    }

    final rows = <Map<String, dynamic>>[];
    final end = params.endRow.clamp(0, totalRows);
    for (int i = params.startRow; i < end; i++) {
      rows.add({'id': i, 'name': 'Row $i', 'value': i * 10});
    }

    final lastRow = end >= totalRows ? totalRows : null;

    if (delay > Duration.zero) {
      Future.delayed(delay, () {
        params.successCallback(rows, lastRow: lastRow);
      });
    } else {
      params.successCallback(rows, lastRow: lastRow);
    }
  }
}

/// A datasource that captures requests without completing them, for
/// simulating in-flight requests and stale callbacks.
class _ManualDatasource extends OsInfiniteDatasource<int> {
  final List<OsInfiniteGetRowsParams<int>> held = [];

  @override
  void getRows(OsInfiniteGetRowsParams<int> params) {
    held.add(params);
  }
}

/// A Map-typed datasource that captures requests without completing them,
/// for simulating in-flight fetches in widget tests.
class _HeldMapDatasource extends OsInfiniteDatasource<Map<String, dynamic>> {
  final List<OsInfiniteGetRowsParams<Map<String, dynamic>>> held = [];

  @override
  void getRows(OsInfiniteGetRowsParams<Map<String, dynamic>> params) {
    held.add(params);
  }
}

void main() {
  group('InfiniteBlockCache', () {
    test('initialises with configured initial row count', () {
      final datasource = TestDatasource(totalRows: 1000);
      final cache = InfiniteBlockCache<Map<String, dynamic>>(
        config: const OsInfiniteRowModel(
          cacheBlockSize: 100,
          infiniteInitialRowCount: 5,
        ),
        datasource: datasource,
        onRowCountChanged: (_) {},
        onBlockLoaded: () {},
      );
      cache.init();

      expect(cache.virtualRowCount, 5);
      expect(cache.isLastRowKnown, false);
      expect(cache.lastRow, isNull);

      cache.dispose();
    });

    test('getRow triggers block loading', () {
      final datasource = TestDatasource(totalRows: 500);
      final cache = InfiniteBlockCache<Map<String, dynamic>>(
        config: const OsInfiniteRowModel(cacheBlockSize: 50),
        datasource: datasource,
        onRowCountChanged: (_) {},
        onBlockLoaded: () {},
      );
      cache.init();

      // First access returns null (not loaded yet)
      final result = cache.getRow(0);
      expect(result, isNull);

      // But the datasource should have been called
      expect(datasource.getRowsCallCount, 1);
      expect(datasource.requests.first.startRow, 0);
      expect(datasource.requests.first.endRow, 50);

      cache.dispose();
    });

    test('getRow returns data after block loads', () {
      final datasource = TestDatasource(totalRows: 500);
      int rowCountChanges = 0;
      int blockLoadedCount = 0;

      final cache = InfiniteBlockCache<Map<String, dynamic>>(
        config: const OsInfiniteRowModel(cacheBlockSize: 50),
        datasource: datasource,
        onRowCountChanged: (_) => rowCountChanges++,
        onBlockLoaded: () => blockLoadedCount++,
      );
      cache.init();

      // Trigger block load
      cache.getRow(0);

      // After synchronous callback, data should be available
      final row = cache.getRow(0);
      expect(row, isNotNull);
      expect(row!['id'], 0);
      expect(row['name'], 'Row 0');
      expect(blockLoadedCount, 1);

      cache.dispose();
    });

    test('reports lastRow when datasource provides it', () {
      final datasource = TestDatasource(totalRows: 75);
      int? reportedRowCount;

      final cache = InfiniteBlockCache<Map<String, dynamic>>(
        config: const OsInfiniteRowModel(cacheBlockSize: 50),
        datasource: datasource,
        onRowCountChanged: (count) => reportedRowCount = count,
        onBlockLoaded: () {},
      );
      cache.init();

      // Load first block (50 rows, no lastRow since more exist)
      cache.getRow(0);
      expect(cache.isLastRowKnown, false);

      // Load second block (25 rows, lastRow = 75)
      cache.getRow(50);
      expect(cache.isLastRowKnown, true);
      expect(cache.lastRow, 75);
      expect(reportedRowCount, 75);

      cache.dispose();
    });

    test('infers end of data when fewer rows returned than block size', () {
      final datasource = TestDatasource(totalRows: 30);
      final cache = InfiniteBlockCache<Map<String, dynamic>>(
        config: const OsInfiniteRowModel(cacheBlockSize: 50),
        datasource: datasource,
        onRowCountChanged: (_) {},
        onBlockLoaded: () {},
      );
      cache.init();

      // Load first block — only 30 rows returned (< 50 block size)
      cache.getRow(0);
      expect(cache.isLastRowKnown, true);
      expect(cache.lastRow, 30);
      expect(cache.virtualRowCount, 30);

      cache.dispose();
    });

    test('purge resets cache state', () {
      final datasource = TestDatasource(totalRows: 500);
      final cache = InfiniteBlockCache<Map<String, dynamic>>(
        config: const OsInfiniteRowModel(
          cacheBlockSize: 50,
          infiniteInitialRowCount: 10,
        ),
        datasource: datasource,
        onRowCountChanged: (_) {},
        onBlockLoaded: () {},
      );
      cache.init();

      // Load some data
      cache.getRow(0);
      expect(cache.isRowLoaded(0), true);

      // Purge
      cache.purge();
      expect(cache.isRowLoaded(0), false);
      expect(cache.virtualRowCount, 10); // Reset to initial
      expect(cache.isLastRowKnown, false);

      cache.dispose();
    });

    test('setSortModel purges cache and stores sort model', () {
      final datasource = TestDatasource(totalRows: 500);
      final cache = InfiniteBlockCache<Map<String, dynamic>>(
        config: const OsInfiniteRowModel(cacheBlockSize: 50),
        datasource: datasource,
        onRowCountChanged: (_) {},
        onBlockLoaded: () {},
      );
      cache.init();

      // Load data
      cache.getRow(0);
      expect(cache.isRowLoaded(0), true);

      // Change sort — should purge
      cache.setSortModel([
        const OsSortModel(colId: 'name', sort: OsSortDirection.ascending),
      ]);
      expect(cache.isRowLoaded(0), false);

      // Next request should include the sort model
      cache.getRow(0);
      expect(datasource.requests.last.sortModel, isNotNull);
      expect(datasource.requests.last.sortModel!.first.colId, 'name');

      cache.dispose();
    });

    test('setFilterModel purges cache and stores filter model', () {
      final datasource = TestDatasource(totalRows: 500);
      final cache = InfiniteBlockCache<Map<String, dynamic>>(
        config: const OsInfiniteRowModel(cacheBlockSize: 50),
        datasource: datasource,
        onRowCountChanged: (_) {},
        onBlockLoaded: () {},
      );
      cache.init();

      // Load data
      cache.getRow(0);
      expect(cache.isRowLoaded(0), true);

      // Change filter — should purge
      cache.setFilterModel({
        'name': {'type': 'contains', 'filter': 'test'},
      });
      expect(cache.isRowLoaded(0), false);

      // Next request should include the filter model
      cache.getRow(0);
      expect(datasource.requests.last.filterModel, isNotNull);
      expect(datasource.requests.last.filterModel!['name'], isNotNull);

      cache.dispose();
    });

    test('respects maxConcurrentDatasourceRequests', () {
      final datasource = TestDatasource(
        totalRows: 500,
        delay: const Duration(milliseconds: 50),
      );
      final cache = InfiniteBlockCache<Map<String, dynamic>>(
        config: const OsInfiniteRowModel(
          cacheBlockSize: 10,
          maxConcurrentDatasourceRequests: 2,
          infiniteInitialRowCount: 100,
        ),
        datasource: datasource,
        onRowCountChanged: (_) {},
        onBlockLoaded: () {},
      );
      cache.init();

      // Request multiple blocks — with initial row count of 100,
      // blocks 0-4 are valid (rows 0-49)
      cache.ensureBlocksForRange(0, 49);

      // With delay, only maxConcurrent should be in-flight
      expect(datasource.getRowsCallCount, 2);

      cache.dispose();
    });

    test('maxBlocksInCache evicts LRU blocks', () {
      final datasource = TestDatasource(totalRows: 500);
      final cache = InfiniteBlockCache<Map<String, dynamic>>(
        config: const OsInfiniteRowModel(
          cacheBlockSize: 10,
          maxBlocksInCache: 3,
        ),
        datasource: datasource,
        onRowCountChanged: (_) {},
        onBlockLoaded: () {},
      );
      cache.init();

      // Load 4 blocks (exceeds max of 3)
      cache.getRow(0); // Block 0
      cache.getRow(10); // Block 1
      cache.getRow(20); // Block 2
      cache.getRow(30); // Block 3

      // Block 0 should have been evicted (LRU)
      expect(cache.isRowLoaded(0), false);
      // Most recent blocks should still be loaded
      expect(cache.isRowLoaded(30), true);

      cache.dispose();
    });

    test('failed blocks can be retried', () {
      final datasource = TestDatasource(totalRows: 500, shouldFail: true);
      final cache = InfiniteBlockCache<Map<String, dynamic>>(
        config: const OsInfiniteRowModel(cacheBlockSize: 50),
        datasource: datasource,
        onRowCountChanged: (_) {},
        onBlockLoaded: () {},
      );
      cache.init();

      // First attempt fails
      cache.getRow(0);
      expect(cache.getBlockState(0), BlockState.failed);

      // Fix the datasource
      datasource.shouldFail = false;

      // Manual refresh purges and forces a retry on next access
      cache.refresh();
      cache.getRow(0);
      expect(cache.isRowLoaded(0), true);

      cache.dispose();
    });

    test('failed block retries are suppressed within the cooldown', () {
      final datasource = TestDatasource(totalRows: 500, shouldFail: true);
      final cache = InfiniteBlockCache<Map<String, dynamic>>(
        config: const OsInfiniteRowModel(cacheBlockSize: 50),
        datasource: datasource,
        onRowCountChanged: (_) {},
        onBlockLoaded: () {},
      );
      cache.init();

      // First attempt fails
      cache.getRow(0);
      expect(cache.getBlockState(0), BlockState.failed);
      final callsAfterFailure = datasource.getRowsCallCount;

      // Repeated accesses within the cooldown must not re-request
      // the block (prevents retry storms on a failing datasource)
      datasource.shouldFail = false;
      cache.getRow(0);
      cache.getRow(0);
      cache.ensureBlocksForRange(0, 49);
      expect(datasource.getRowsCallCount, callsAfterFailure);

      // Manual refresh clears the cooldown and forces a retry
      cache.refresh();
      cache.getRow(0);
      expect(cache.isRowLoaded(0), true);

      cache.dispose();
    });

    test('stale completions after purge cannot corrupt concurrency budget', () {
      final datasource = _ManualDatasource();
      final cache = InfiniteBlockCache<int>(
        config: const OsInfiniteRowModel(
          cacheBlockSize: 10,
          maxConcurrentDatasourceRequests: 1,
          infiniteInitialRowCount: 100,
        ),
        datasource: datasource,
        onRowCountChanged: (_) {},
        onBlockLoaded: () {},
      );
      cache.init();

      // Start a request that stays in flight.
      cache.ensureBlocksForRange(0, 9);
      expect(datasource.held.length, 1);
      final staleRequest = datasource.held.single;
      datasource.held.clear();

      // Purge while the request is in flight; it is abandoned.
      cache.purge();

      // New requests fill the single concurrency slot; the rest queue.
      cache.ensureBlocksForRange(0, 39);
      expect(datasource.held.length, 1);
      final freshRequest = datasource.held.single;

      // The stale completion arrives after the purge — it must be
      // ignored entirely so it cannot decrement the counter.
      staleRequest.failCallback();

      // Completing the fresh request frees the slot for exactly one
      // queued block (a negative counter would admit several).
      freshRequest.successCallback(List<int>.generate(10, (i) => i));
      expect(datasource.held.length, 2);

      final secondRequest = datasource.held.last;
      secondRequest.successCallback(List<int>.generate(10, (i) => i + 10));
      expect(datasource.held.length, 3);

      cache.dispose();
    });

    test('ensureBlocksForRange loads blocks for visible range', () {
      final datasource = TestDatasource(totalRows: 500);
      final cache = InfiniteBlockCache<Map<String, dynamic>>(
        config: const OsInfiniteRowModel(
          cacheBlockSize: 50,
          cacheOverflowSize: 1,
          infiniteInitialRowCount: 500,
        ),
        datasource: datasource,
        onRowCountChanged: (_) {},
        onBlockLoaded: () {},
      );
      cache.init();

      // Visible range is rows 100-149 (block 2)
      // With overflow of 1, should also load blocks 1 and 3
      cache.ensureBlocksForRange(100, 149);

      // Blocks 1, 2, 3 should be loaded (overflow includes adjacent)
      expect(cache.isRowLoaded(50), true); // Block 1
      expect(cache.isRowLoaded(100), true); // Block 2
      expect(cache.isRowLoaded(150), true); // Block 3

      cache.dispose();
    });

    test('getRowCount returns virtual row count', () {
      final datasource = TestDatasource(totalRows: 500);
      final cache = InfiniteBlockCache<Map<String, dynamic>>(
        config: const OsInfiniteRowModel(
          cacheBlockSize: 50,
          infiniteInitialRowCount: 200,
        ),
        datasource: datasource,
        onRowCountChanged: (_) {},
        onBlockLoaded: () {},
      );
      cache.init();

      expect(cache.getRowCount(), 200);

      cache.dispose();
    });
  });

  group('OsInfiniteRowModel config', () {
    test('default values', () {
      const config = OsInfiniteRowModel();
      expect(config.cacheBlockSize, 100);
      expect(config.maxBlocksInCache, isNull);
      expect(config.cacheOverflowSize, 1);
      expect(config.maxConcurrentDatasourceRequests, 1);
      expect(config.infiniteInitialRowCount, 1);
    });

    test('custom values', () {
      const config = OsInfiniteRowModel(
        cacheBlockSize: 50,
        maxBlocksInCache: 5,
        cacheOverflowSize: 2,
        maxConcurrentDatasourceRequests: 3,
        infiniteInitialRowCount: 100,
      );
      expect(config.cacheBlockSize, 50);
      expect(config.maxBlocksInCache, 5);
      expect(config.cacheOverflowSize, 2);
      expect(config.maxConcurrentDatasourceRequests, 3);
      expect(config.infiniteInitialRowCount, 100);
    });

    test('equality', () {
      const a = OsInfiniteRowModel(cacheBlockSize: 50);
      const b = OsInfiniteRowModel(cacheBlockSize: 50);
      const c = OsInfiniteRowModel(cacheBlockSize: 100);
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('asserts on invalid values', () {
      expect(
        () => OsInfiniteRowModel(cacheBlockSize: 0),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => OsInfiniteRowModel(maxBlocksInCache: 0),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => OsInfiniteRowModel(cacheOverflowSize: -1),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => OsInfiniteRowModel(maxConcurrentDatasourceRequests: 0),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => OsInfiniteRowModel(infiniteInitialRowCount: -1),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('OsGrid widget integration', () {
    testWidgets('renders with infinite row model', (tester) async {
      final datasource = TestDatasource(totalRows: 100);
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: OsGrid<Map<String, dynamic>>(
                columnDefs: [
                  const OsColumnDef(field: 'id', headerName: 'ID'),
                  const OsColumnDef(field: 'name', headerName: 'Name'),
                  const OsColumnDef(field: 'value', headerName: 'Value'),
                ],
                controller: controller,
                infiniteRowModel: const OsInfiniteRowModel(
                  cacheBlockSize: 20,
                  infiniteInitialRowCount: 100,
                ),
                datasource: datasource,
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // Datasource should have been called for initial visible blocks
      expect(datasource.getRowsCallCount, greaterThan(0));

      controller.dispose();
    });

    testWidgets('controller.getInfiniteRowCount returns row count', (
      tester,
    ) async {
      final datasource = TestDatasource(totalRows: 200);
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: OsGrid<Map<String, dynamic>>(
                columnDefs: [
                  const OsColumnDef(field: 'id', headerName: 'ID'),
                  const OsColumnDef(field: 'name', headerName: 'Name'),
                ],
                controller: controller,
                infiniteRowModel: const OsInfiniteRowModel(
                  cacheBlockSize: 50,
                  infiniteInitialRowCount: 200,
                ),
                datasource: datasource,
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // Should report the row count
      final count = controller.getInfiniteRowCount();
      expect(count, isNotNull);
      expect(count, greaterThan(0));

      controller.dispose();
    });

    testWidgets('controller.purgeInfiniteCache resets cache', (tester) async {
      final datasource = TestDatasource(totalRows: 200);
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: OsGrid<Map<String, dynamic>>(
                columnDefs: [
                  const OsColumnDef(field: 'id', headerName: 'ID'),
                  const OsColumnDef(field: 'name', headerName: 'Name'),
                ],
                controller: controller,
                infiniteRowModel: const OsInfiniteRowModel(
                  cacheBlockSize: 50,
                  infiniteInitialRowCount: 200,
                ),
                datasource: datasource,
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      final initialCallCount = datasource.getRowsCallCount;

      // Purge the cache
      controller.purgeInfiniteCache();
      await tester.pump();

      // Row count should reset to initial
      expect(controller.getInfiniteRowCount(), 200);

      // After purge, scrolling should trigger new requests
      // (the cache was cleared)
      expect(
        datasource.getRowsCallCount,
        greaterThanOrEqualTo(initialCallCount),
      );

      controller.dispose();
    });

    testWidgets('controller.refreshInfiniteCache re-fetches blocks', (
      tester,
    ) async {
      final datasource = TestDatasource(totalRows: 200);
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: OsGrid<Map<String, dynamic>>(
                columnDefs: [
                  const OsColumnDef(field: 'id', headerName: 'ID'),
                  const OsColumnDef(field: 'name', headerName: 'Name'),
                ],
                controller: controller,
                infiniteRowModel: const OsInfiniteRowModel(
                  cacheBlockSize: 50,
                  infiniteInitialRowCount: 200,
                ),
                datasource: datasource,
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      final callCountBeforeRefresh = datasource.getRowsCallCount;

      // Refresh the cache
      controller.refreshInfiniteCache();
      await tester.pump();

      // Refresh should trigger re-fetch (purge + new requests)
      expect(datasource.getRowsCallCount, greaterThan(callCountBeforeRefresh));

      controller.dispose();
    });

    testWidgets('onInfiniteRowCountChanged fires when row count changes', (
      tester,
    ) async {
      final datasource = TestDatasource(totalRows: 75);
      final controller = OsGridController<Map<String, dynamic>>();
      final events = <OsInfiniteRowCountChangedEvent>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: OsGrid<Map<String, dynamic>>(
                columnDefs: [
                  const OsColumnDef(field: 'id', headerName: 'ID'),
                  const OsColumnDef(field: 'name', headerName: 'Name'),
                ],
                controller: controller,
                infiniteRowModel: const OsInfiniteRowModel(
                  cacheBlockSize: 50,
                  infiniteInitialRowCount: 1,
                ),
                datasource: datasource,
                onInfiniteRowCountChanged: (event) => events.add(event),
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // Should have received at least one row count change event
      expect(events, isNotEmpty);

      controller.dispose();
    });

    testWidgets('rowData is ignored when infiniteRowModel is set', (
      tester,
    ) async {
      final datasource = TestDatasource(totalRows: 50);
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: OsGrid<Map<String, dynamic>>(
                columnDefs: [
                  const OsColumnDef(field: 'id', headerName: 'ID'),
                  const OsColumnDef(field: 'name', headerName: 'Name'),
                ],
                controller: controller,
                rowData: [
                  {'id': 999, 'name': 'Should be ignored'},
                ],
                infiniteRowModel: const OsInfiniteRowModel(
                  cacheBlockSize: 50,
                  infiniteInitialRowCount: 50,
                ),
                datasource: datasource,
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // The datasource should be used, not rowData
      expect(datasource.getRowsCallCount, greaterThan(0));

      controller.dispose();
    });

    testWidgets('sort model is passed to datasource', (tester) async {
      final datasource = TestDatasource(totalRows: 200);
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: OsGrid<Map<String, dynamic>>(
                columnDefs: [
                  const OsColumnDef(
                    field: 'id',
                    headerName: 'ID',
                    sortable: true,
                  ),
                  const OsColumnDef(
                    field: 'name',
                    headerName: 'Name',
                    sortable: true,
                  ),
                ],
                controller: controller,
                infiniteRowModel: const OsInfiniteRowModel(
                  cacheBlockSize: 50,
                  infiniteInitialRowCount: 200,
                ),
                datasource: datasource,
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // Apply a sort via controller
      controller.setSortModel([
        const OsSortModel(colId: 'name', sort: OsSortDirection.ascending),
      ]);
      await tester.pump();

      // The latest request should include the sort model
      final lastRequest = datasource.requests.last;
      expect(lastRequest.sortModel, isNotNull);
      expect(lastRequest.sortModel!.length, 1);
      expect(lastRequest.sortModel!.first.colId, 'name');

      controller.dispose();
    });
  });

  group('InfiniteBlockCache loading state', () {
    test('isAnyBlockLoading is true while a request is in flight', () {
      final datasource = _ManualDatasource();
      final cache = InfiniteBlockCache<int>(
        config: const OsInfiniteRowModel(
          cacheBlockSize: 10,
          infiniteInitialRowCount: 100,
        ),
        datasource: datasource,
        onRowCountChanged: (_) {},
        onBlockLoaded: () {},
      );
      cache.init();

      expect(cache.isAnyBlockLoading, false);

      cache.ensureBlocksForRange(0, 9);
      expect(cache.isAnyBlockLoading, true);
      expect(datasource.held.length, greaterThanOrEqualTo(1));

      // Complete everything, including blocks that get dispatched from
      // the queue as earlier completions free concurrency slots.
      while (datasource.held.isNotEmpty) {
        final batch = List.of(datasource.held);
        datasource.held.clear();
        for (final params in batch) {
          params.successCallback(<int>[
            for (int i = params.startRow; i < params.endRow; i++) i,
          ], lastRow: 100);
        }
      }
      expect(cache.isAnyBlockLoading, false);

      cache.dispose();
    });

    test('isAnyBlockLoading is false after a failed request', () {
      final datasource = _ManualDatasource();
      final cache = InfiniteBlockCache<int>(
        config: const OsInfiniteRowModel(
          cacheBlockSize: 100,
          infiniteInitialRowCount: 100,
        ),
        datasource: datasource,
        onRowCountChanged: (_) {},
        onBlockLoaded: () {},
      );
      cache.init();

      // Single block covers the whole range (no queued siblings).
      cache.ensureBlocksForRange(0, 99);
      expect(cache.isAnyBlockLoading, true);

      datasource.held.single.failCallback();
      expect(cache.isAnyBlockLoading, false);
      expect(cache.getBlockState(0), BlockState.failed);

      cache.dispose();
    });

    test('purge discards in-flight blocks so nothing counts as loading', () {
      final datasource = _ManualDatasource();
      final cache = InfiniteBlockCache<int>(
        config: const OsInfiniteRowModel(
          cacheBlockSize: 10,
          maxConcurrentDatasourceRequests: 1,
          infiniteInitialRowCount: 100,
        ),
        datasource: datasource,
        onRowCountChanged: (_) {},
        onBlockLoaded: () {},
      );
      cache.init();

      // Block 0 dispatches; block 1 queues behind the concurrency limit.
      cache.ensureBlocksForRange(0, 19);
      expect(cache.isAnyBlockLoading, true);

      cache.purge();
      expect(cache.isAnyBlockLoading, false);
      expect(cache.hasAnyLoadedBlock, false);

      // The stale completion must not resurrect the loading state.
      datasource.held.first.failCallback();
      expect(cache.isAnyBlockLoading, false);

      cache.dispose();
    });

    test('hasAnyLoadedBlock flips after the first successful load', () {
      final datasource = _ManualDatasource();
      final cache = InfiniteBlockCache<int>(
        config: const OsInfiniteRowModel(
          cacheBlockSize: 10,
          infiniteInitialRowCount: 100,
        ),
        datasource: datasource,
        onRowCountChanged: (_) {},
        onBlockLoaded: () {},
      );
      cache.init();
      expect(cache.hasAnyLoadedBlock, false);

      cache.ensureBlocksForRange(0, 9);
      expect(cache.hasAnyLoadedBlock, false);

      datasource.held.single.successCallback(List<int>.generate(10, (i) => i));
      expect(cache.hasAnyLoadedBlock, true);

      cache.refresh();
      expect(cache.hasAnyLoadedBlock, false);

      cache.dispose();
    });
  });

  group('OsGrid widget integration — isInfiniteCacheLoading', () {
    testWidgets('controller reflects in-flight block fetches', (tester) async {
      final datasource = _HeldMapDatasource();
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: OsGrid<Map<String, dynamic>>(
                columnDefs: [
                  const OsColumnDef(field: 'id', headerName: 'ID'),
                  const OsColumnDef(field: 'name', headerName: 'Name'),
                ],
                controller: controller,
                infiniteRowModel: const OsInfiniteRowModel(
                  cacheBlockSize: 50,
                  infiniteInitialRowCount: 100,
                ),
                datasource: datasource,
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(controller.isInfiniteCacheLoading, true);

      // Complete every dispatched request; cascaded dispatches (queued
      // behind the concurrency limit) surface in `held` as we drain.
      while (datasource.held.isNotEmpty) {
        final batch = List.of(datasource.held);
        datasource.held.clear();
        for (final params in batch) {
          params.successCallback(<Map<String, dynamic>>[
            for (int i = params.startRow; i < params.endRow; i++)
              {'id': i, 'name': 'Row $i'},
          ], lastRow: 100);
        }
      }
      await tester.pump();

      expect(controller.isInfiniteCacheLoading, false);

      controller.dispose();
    });

    testWidgets('returns false outside infinite row model mode', (
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
                columnDefs: [const OsColumnDef(field: 'id', headerName: 'ID')],
                controller: controller,
                rowData: const [
                  {'id': 1},
                ],
              ),
            ),
          ),
        ),
      );

      expect(controller.isInfiniteCacheLoading, false);

      controller.dispose();
    });
  });
}
