import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

/// A mock server-side datasource that completes requests synchronously
/// from a path-nested level map.
///
/// Levels are keyed by the joined group-keys path (e.g. `'A|B'`, `''` for
/// the root). An empty/missing level is reported synchronously via
/// `successCallback(const [])` so the block completes immediately.
class MockServer extends OsServerSideDatasource<Map<String, dynamic>> {
  MockServer({this.levels = const {}, this.shouldFail = false});

  Map<String, List<OsServerSideGroupChild>> levels;
  bool shouldFail;

  int getRowsCallCount = 0;
  int destroyCallCount = 0;
  final List<ServerSideGetRowsParams<Map<String, dynamic>>> requests = [];

  int callCountFor(List<String> groupKeys) => requests
      .where((r) => r.groupKeys.join('|') == groupKeys.join('|'))
      .length;

  @override
  List<OsServerSideGroupChild> getRows(
    ServerSideGetRowsParams<Map<String, dynamic>> params,
  ) {
    getRowsCallCount++;
    requests.add(params);

    if (shouldFail) {
      params.failCallback();
      return const [];
    }

    final children = levels[params.groupKeys.join('|')];
    if (children == null || children.isEmpty) {
      // Report an empty block synchronously (an empty *return* would mean
      // "async pending" per the datasource contract).
      params.successCallback(const []);
      return const [];
    }
    return children;
  }

  @override
  void destroy() {
    destroyCallCount++;
  }
}

/// A mock datasource returning a flat leaf level of [totalRows] rows,
/// sliced to the requested range (for block-size / row-count tests).
class RangeServer extends OsServerSideDatasource<Map<String, dynamic>> {
  RangeServer(this.totalRows);

  final int totalRows;

  int getRowsCallCount = 0;
  final List<ServerSideGetRowsParams<Map<String, dynamic>>> requests = [];

  @override
  List<OsServerSideGroupChild> getRows(
    ServerSideGetRowsParams<Map<String, dynamic>> params,
  ) {
    getRowsCallCount++;
    requests.add(params);

    final end = params.endRow.clamp(0, totalRows);
    final rows = <OsServerSideGroupChild>[
      for (int i = params.startRow; i < end; i++)
        OsServerSideGroupChildLeaf<Map<String, dynamic>>({
          'id': i,
          'name': 'Row $i',
        }),
    ];
    if (rows.isEmpty) {
      params.successCallback(const []);
      return const [];
    }
    return rows;
  }
}

/// A datasource that captures requests without completing them, for
/// simulating in-flight fetches.
class HeldServer<TData> extends OsServerSideDatasource<TData> {
  final List<ServerSideGetRowsParams<TData>> held = [];

  @override
  List<OsServerSideGroupChild> getRows(ServerSideGetRowsParams<TData> params) {
    held.add(params);
    return const [];
  }
}

OsServerSideGroupChildGroup makeGroup(String key, int childCount) =>
    OsServerSideGroupChildGroup(key: key, childCount: childCount);

OsServerSideGroupChildLeaf<Map<String, dynamic>> leaf(String id) =>
    OsServerSideGroupChildLeaf<Map<String, dynamic>>({'id': id, 'name': id});

const List<OsColumnDef> testGroupColumns = [
  OsColumnDef(field: 'country', headerName: 'Country'),
];

ServerSideRowModel<Map<String, dynamic>> buildModel(
  OsServerSideDatasource<Map<String, dynamic>> datasource, {
  RowGroupState? rowGroupState,
  int cacheBlockSize = 50,
  int? maxBlocksInCache,
}) => ServerSideRowModel<Map<String, dynamic>>(
  datasource: datasource,
  rowGroupState: rowGroupState,
  cacheBlockSize: cacheBlockSize,
  maxBlocksInCache: maxBlocksInCache,
);

void main() {
  group('ServerSideRowModel — level cache and display', () {
    test('sync datasource supplies root group rows', () {
      final ds = MockServer(
        levels: {
          '': [makeGroup('A', 2), makeGroup('B', 3)],
        },
      );
      final model = buildModel(ds);

      model.requestVisibleRows(0, 10);
      final display = model.buildDisplayRows(groupColumns: testGroupColumns);

      expect(display.length, 2);
      expect(display[0][RowGroupKeys.kIsGroupRow], true);
      expect(display[0][RowGroupKeys.kGroupKey], 'A');
      expect(display[0][RowGroupKeys.kGroupChildCount], 2);
      expect(display[0][RowGroupKeys.kGroupLevel], 0);
      expect(display[0][RowGroupKeys.kGroupExpanded], false);
      expect(display[0][RowGroupKeys.kGroupNodeId], 'row-group-A');
      expect(display[1][RowGroupKeys.kGroupKey], 'B');
      expect(display[1][RowGroupKeys.kGroupChildCount], 3);

      // Short block (2 < 50) means the level's total is known.
      expect(model.getRootVirtualRowCount(), 2);

      model.dispose();
    });

    test('expanding a group fetches the child level with groupKeys', () {
      final ds = MockServer(
        levels: {
          '': [makeGroup('A', 2), makeGroup('B', 3)],
          'A': [leaf('a1'), leaf('a2')],
          'B': [leaf('b1'), leaf('b2'), leaf('b3')],
        },
      );
      final state = RowGroupState();
      final model = buildModel(ds, rowGroupState: state);

      model.requestVisibleRows(0, 10);
      // Root requests only — no group keys yet.
      expect(ds.callCountFor(const []), greaterThan(0));
      expect(ds.requests.every((r) => r.groupKeys.isEmpty), isTrue);

      state.expand('row-group-A');
      model.requestVisibleRows(0, 10);

      // Child level fetched with the parent's key path.
      expect(ds.callCountFor(const ['A']), 1);
      expect(ds.requests.last.groupKeys, ['A']);

      final display = model.buildDisplayRows(groupColumns: testGroupColumns);
      expect(display.length, 4);
      expect(display[0][RowGroupKeys.kGroupKey], 'A');
      expect(display[0][RowGroupKeys.kGroupExpanded], true);
      expect(display[1]['id'], 'a1');
      expect(display[2]['id'], 'a2');
      expect(display[3][RowGroupKeys.kGroupKey], 'B');

      model.dispose();
    });

    test('multi-level nesting fetches deeper levels by path', () {
      final ds = MockServer(
        levels: {
          '': [makeGroup('A', 1)],
          'A': [makeGroup('X', 1)],
          'A|X': [leaf('x1')],
        },
      );
      final state = RowGroupState();
      final model = buildModel(ds, rowGroupState: state);

      state.expand('row-group-A');
      state.expand('row-group-A-X');
      model.requestVisibleRows(0, 20);

      expect(ds.callCountFor(const ['A']), 1);
      expect(ds.callCountFor(const ['A', 'X']), 1);

      final display = model.buildDisplayRows(groupColumns: testGroupColumns);
      expect(display.length, 3);
      expect(display[0][RowGroupKeys.kGroupKey], 'A');
      expect(display[0][RowGroupKeys.kGroupLevel], 0);
      expect(display[1][RowGroupKeys.kGroupKey], 'X');
      expect(display[1][RowGroupKeys.kGroupLevel], 1);
      expect(display[2]['id'], 'x1');

      model.dispose();
    });

    test('child level virtual row count is seeded from childCount', () {
      final ds = MockServer(
        levels: {
          '': [makeGroup('A', 7)],
        },
      );
      final state = RowGroupState();
      final model = buildModel(ds, rowGroupState: state);

      state.expand('row-group-A');
      // Only the group row itself is visible — the child level is created
      // (seeded) but its blocks are not requested yet.
      model.requestVisibleRows(0, 0);

      // Seeded from the server-reported childCount before child data lands.
      expect(model.getVirtualRowCount(const ['A']), 7);

      model.dispose();
    });

    test('typed leaf rows map through leafToMap', () {
      final ds = HeldServer<int>();
      final model = ServerSideRowModel<int>(datasource: ds, cacheBlockSize: 50);

      model.requestVisibleRows(0, 10);
      ds.held.single.successCallback([
        const OsServerSideGroupChildLeaf<int>(5),
        const OsServerSideGroupChildLeaf<int>(7),
      ]);

      final withConverter = model.buildDisplayRows(
        groupColumns: testGroupColumns,
        leafToMap: (value, index) => {'value': value},
      );
      expect(withConverter, [
        {'value': 5},
        {'value': 7},
      ]);

      // Without a converter, typed leaves fall back to empty maps.
      final withoutConverter = model.buildDisplayRows(
        groupColumns: testGroupColumns,
      );
      expect(withoutConverter.length, 2);
      expect(withoutConverter[0], isEmpty);

      model.dispose();
    });

    test('unloaded rows render as loading placeholders', () {
      final ds = MockServer(
        levels: {
          '': [makeGroup('A', 2), makeGroup('B', 3)],
        },
      );
      final model = buildModel(ds);

      // No fetch yet — everything is a placeholder.
      expect(model.displayRowCount, 1); // initialRowCount default
      final display = model.buildDisplayRows(groupColumns: testGroupColumns);
      expect(display, [
        {'__loading__': true},
      ]);

      model.dispose();
    });
  });

  group('ServerSideRowModel — datasource params', () {
    test('sort and filter models are passed to the datasource', () {
      final ds = MockServer(
        levels: {
          '': [makeGroup('A', 2)],
        },
      );
      final model = buildModel(ds);

      model.setSortModel([
        const OsSortModel(colId: 'country', sort: OsSortDirection.ascending),
      ]);
      model.requestVisibleRows(0, 10);

      expect(ds.requests.last.sortModel, isNotNull);
      expect(ds.requests.last.sortModel!.single.colId, 'country');
      expect(
        ds.requests.last.sortModel!.single.sort,
        OsSortDirection.ascending,
      );

      model.setFilterModel({
        'country': {'filterType': 'text', 'filter': 'test'},
      });
      model.requestVisibleRows(0, 10);

      expect(ds.requests.last.filterModel, isNotNull);
      expect(ds.requests.last.filterModel!['country'], isNotNull);

      model.dispose();
    });

    test('sort/filter changes purge previously loaded levels', () {
      final ds = MockServer(
        levels: {
          '': [makeGroup('A', 2)],
        },
      );
      final model = buildModel(ds);

      model.requestVisibleRows(0, 10);
      expect(ds.getRowsCallCount, 1);

      // Changing the sort invalidates the cache — the level is re-fetched.
      model.setSortModel([
        const OsSortModel(colId: 'country', sort: OsSortDirection.descending),
      ]);
      model.requestVisibleRows(0, 10);
      expect(ds.getRowsCallCount, 2);

      model.dispose();
    });

    test('startRow/endRow window is passed through', () {
      final ds = HeldServer<Map<String, dynamic>>();
      final model = buildModel(ds, cacheBlockSize: 100);

      // Prime the root level: server reports a 1000-row level.
      model.requestVisibleRows(0, 5);
      ds.held.single.successCallback([
        for (int i = 0; i < 100; i++)
          OsServerSideGroupChildLeaf<Map<String, dynamic>>({'id': i}),
      ], lastRow: 1000);
      ds.held.clear();

      model.requestVisibleRows(120, 220);

      // Visible rows 120-220 span blocks 1 and 2.
      expect(ds.held.map((r) => r.startRow).toList(), [100, 200]);
      expect(ds.held[0].endRow, 200);
      expect(ds.held[0].groupKeys, isEmpty);
      expect(ds.held[1].endRow, 300);

      model.dispose();
    });
  });

  group('ServerSideRowModel — dedup and row counts', () {
    test('same block is not fetched twice while in flight', () {
      final ds = HeldServer<int>();
      final model = ServerSideRowModel<int>(datasource: ds, cacheBlockSize: 10);

      model.requestVisibleRows(0, 5);
      model.requestVisibleRows(0, 5);
      expect(ds.held.length, 1);
      expect(model.isAnyBlockLoading, true);

      // Completing the request reports the exact level total via lastRow.
      ds.held.single.successCallback([
        for (int i = 0; i < 10; i++) OsServerSideGroupChildLeaf<int>(i),
      ], lastRow: 25);

      expect(model.isAnyBlockLoading, false);
      expect(model.getRootVirtualRowCount(), 25);

      // A loaded block is not re-fetched either.
      model.requestVisibleRows(0, 5);
      expect(ds.held.length, 1);

      model.dispose();
    });

    test('short block infers the level total without lastRow', () {
      final ds = RangeServer(30);
      final model = buildModel(ds, cacheBlockSize: 50);

      model.requestVisibleRows(0, 10);

      expect(model.getRootVirtualRowCount(), 30);
      expect(model.isAnyBlockLoading, false);

      model.dispose();
    });

    test('full block grows the virtual count speculatively', () {
      final ds = RangeServer(100);
      final model = buildModel(ds, cacheBlockSize: 50);

      model.requestVisibleRows(0, 10);

      // Block 0 filled (50 rows), total unknown — assume one more block.
      expect(model.getRootVirtualRowCount(), 100);

      model.dispose();
    });

    test('blocks beyond the known last row are not requested', () {
      final ds = RangeServer(30);
      final model = buildModel(ds, cacheBlockSize: 50);

      model.requestVisibleRows(0, 10);
      expect(model.getRootVirtualRowCount(), 30);

      // Row 49 is past the known total — must not fire a request.
      model.requestVisibleRows(45, 49);
      expect(ds.getRowsCallCount, 1);

      model.dispose();
    });
  });

  group('ServerSideRowModel — refresh and failure', () {
    test('refresh(groupKeys) clears the level and deeper levels only', () {
      final ds = MockServer(
        levels: {
          '': [makeGroup('A', 2), makeGroup('B', 3)],
          'A': [leaf('a1'), leaf('a2')],
          'B': [leaf('b1'), leaf('b2'), leaf('b3')],
        },
      );
      final state = RowGroupState();
      final model = buildModel(ds, rowGroupState: state);

      state.expand('row-group-A');
      state.expand('row-group-B');
      model.requestVisibleRows(0, 20);
      final rootCalls = ds.callCountFor(const []);
      final aCalls = ds.callCountFor(const ['A']);
      final bCalls = ds.callCountFor(const ['B']);
      expect(rootCalls, greaterThan(0));
      expect(aCalls, 1);
      expect(bCalls, 1);

      // Refresh only level A (and its descendants).
      model.refresh(groupKeys: const ['A']);
      model.requestVisibleRows(0, 20);

      expect(ds.callCountFor(const []), rootCalls); // root kept
      expect(ds.callCountFor(const ['A']), aCalls + 1); // re-fetched
      expect(ds.callCountFor(const ['B']), bCalls); // sibling untouched

      // Full refresh discards everything.
      model.refresh();
      model.requestVisibleRows(0, 20);
      expect(ds.callCountFor(const []), rootCalls + 1);
      expect(ds.callCountFor(const ['A']), aCalls + 2);
      expect(ds.callCountFor(const ['B']), bCalls + 1);

      model.dispose();
    });

    test('failed blocks are not retried automatically; refresh retries', () {
      final ds = MockServer(
        levels: {
          '': [makeGroup('A', 2)],
        },
        shouldFail: true,
      );
      final model = buildModel(ds);

      model.requestVisibleRows(0, 10);
      expect(model.isAnyBlockLoading, false);
      final callsAfterFailure = ds.getRowsCallCount;

      // Fix the server — automatic re-requests are suppressed.
      ds.shouldFail = false;
      model.requestVisibleRows(0, 10);
      expect(ds.getRowsCallCount, callsAfterFailure);

      // Explicit refresh clears the failure and re-fetches.
      model.refresh();
      model.requestVisibleRows(0, 10);
      expect(ds.getRowsCallCount, greaterThan(callsAfterFailure));
      expect(model.buildDisplayRows(groupColumns: testGroupColumns).length, 1);

      model.dispose();
    });

    test('stale completions after refresh are ignored', () {
      final ds = HeldServer<int>();
      final model = ServerSideRowModel<int>(datasource: ds, cacheBlockSize: 10);

      model.requestVisibleRows(0, 5);
      final stale = ds.held.single;
      ds.held.clear();

      model.refresh();
      model.requestVisibleRows(0, 5);
      final fresh = ds.held.single;

      // The stale completion must not land in the fresh cache.
      stale.successCallback([
        for (int i = 0; i < 10; i++) OsServerSideGroupChildLeaf<int>(i),
      ], lastRow: 10);
      expect(model.getRootVirtualRowCount(), 1); // untouched

      fresh.successCallback([
        for (int i = 0; i < 10; i++) OsServerSideGroupChildLeaf<int>(i),
      ], lastRow: 10);
      expect(model.getRootVirtualRowCount(), 10);

      model.dispose();
    });

    test('empty synchronous completion reports an empty level', () {
      final ds = MockServer(); // no levels at all
      final model = buildModel(ds);

      model.requestVisibleRows(0, 10);

      expect(model.getRootVirtualRowCount(), 0);
      expect(model.buildDisplayRows(groupColumns: testGroupColumns), isEmpty);
      expect(model.isAnyBlockLoading, false);

      model.dispose();
    });
  });

  group('ServerSideRowModel — LRU eviction and lifecycle', () {
    test('maxBlocksInCache evicts LRU blocks per level', () {
      final ds = RangeServer(1000);
      final model = buildModel(ds, cacheBlockSize: 10, maxBlocksInCache: 2);

      model.requestVisibleRows(0, 9);
      model.requestVisibleRows(10, 19);
      model.requestVisibleRows(20, 29);

      // Block 0 was evicted; blocks 1 and 2 are still cached.
      final display = model.buildDisplayRows(
        groupColumns: testGroupColumns,
        leafToMap: (row, index) => row,
      );
      expect(display[0], {'__loading__': true});
      expect(display[15]['id'], 15);
      expect(display[25]['id'], 25);

      model.dispose();
    });

    test('dispose clears caches and destroys the datasource', () {
      final ds = MockServer(
        levels: {
          '': [makeGroup('A', 2)],
        },
      );
      final model = buildModel(ds);

      model.requestVisibleRows(0, 10);
      model.dispose();

      expect(model.getRootVirtualRowCount(), 1);
      expect(model.buildDisplayRows(groupColumns: testGroupColumns), isEmpty);
      expect(model.isAnyBlockLoading, false);
      expect(ds.destroyCallCount, 1);
    });

    test('config asserts on invalid values', () {
      final ds = MockServer();
      expect(
        () => ServerSideRowModel<Map<String, dynamic>>(
          datasource: ds,
          cacheBlockSize: 0,
        ),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => ServerSideRowModel<Map<String, dynamic>>(
          datasource: ds,
          maxBlocksInCache: 0,
        ),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => ServerSideRowModel<Map<String, dynamic>>(
          datasource: ds,
          initialRowCount: -1,
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('OsGrid widget integration — server-side row model', () {
    final levels = {
      '': [makeGroup('A', 2), makeGroup('B', 3)],
      'A': [leaf('a1'), leaf('a2')],
      'B': [leaf('b1'), leaf('b2'), leaf('b3')],
    };

    Widget wrapGrid(
      OsGridController<Map<String, dynamic>> controller,
      MockServer ds, {
      List<String>? groupBy,
      List<Map<String, dynamic>>? rowData,
    }) => MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 800,
          height: 600,
          child: OsGrid<Map<String, dynamic>>(
            columnDefs: const [
              OsColumnDef(field: 'country', headerName: 'Country'),
              OsColumnDef(field: 'id', headerName: 'ID'),
              OsColumnDef(field: 'name', headerName: 'Name'),
            ],
            controller: controller,
            groupBy: groupBy,
            rowData: rowData,
            serverSideDatasource: ds,
          ),
        ),
      ),
    );

    testWidgets('renders and fetches root level on first frame', (
      tester,
    ) async {
      final ds = MockServer(levels: levels);
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(wrapGrid(controller, ds, groupBy: ['country']));
      await tester.pump(); // post-frame initial fetch + rebuild

      expect(ds.getRowsCallCount, greaterThan(0));
      expect(controller.getServerSideRowCount(), 2);

      controller.dispose();
    });

    testWidgets('expanding a group fetches the child level', (tester) async {
      final ds = MockServer(levels: levels);
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(wrapGrid(controller, ds, groupBy: ['country']));
      await tester.pump();
      expect(ds.callCountFor(const ['A']), 0);

      controller.setRowExpanded('row-group-A', expanded: true);
      await tester.pump();
      await tester.pump();

      expect(ds.callCountFor(const ['A']), 1);
      expect(controller.getServerSideRowCount(const ['A']), 2);

      controller.dispose();
    });

    testWidgets('controller.refreshServerSide re-fetches the level', (
      tester,
    ) async {
      final ds = MockServer(levels: levels);
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(wrapGrid(controller, ds, groupBy: ['country']));
      await tester.pump();
      final callsBefore = ds.getRowsCallCount;

      controller.refreshServerSide();
      await tester.pump();
      await tester.pump();

      expect(ds.getRowsCallCount, greaterThan(callsBefore));

      controller.dispose();
    });

    testWidgets('refreshServerSide(groupKeys) leaves other levels cached', (
      tester,
    ) async {
      final ds = MockServer(levels: levels);
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(wrapGrid(controller, ds, groupBy: ['country']));
      await tester.pump();
      controller.setRowExpanded('row-group-A', expanded: true);
      await tester.pump();
      await tester.pump();

      final rootCalls = ds.callCountFor(const []);
      final aCalls = ds.callCountFor(const ['A']);

      controller.refreshServerSide(groupKeys: const ['A']);
      await tester.pump();
      await tester.pump();

      expect(ds.callCountFor(const []), rootCalls);
      expect(ds.callCountFor(const ['A']), greaterThan(aCalls));

      controller.dispose();
    });

    testWidgets('sort model is passed to the datasource', (tester) async {
      final ds = MockServer(levels: levels);
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(wrapGrid(controller, ds, groupBy: ['country']));
      await tester.pump();

      controller.setSortModel([
        const OsSortModel(colId: 'country', sort: OsSortDirection.ascending),
      ]);
      await tester.pump();
      await tester.pump();

      expect(ds.requests.last.sortModel, isNotNull);
      expect(ds.requests.last.sortModel!.single.colId, 'country');
      expect(
        ds.requests.last.sortModel!.single.sort,
        OsSortDirection.ascending,
      );

      controller.dispose();
    });

    testWidgets('rowData is ignored when serverSideDatasource is set', (
      tester,
    ) async {
      final ds = MockServer(levels: levels);
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(
        wrapGrid(
          controller,
          ds,
          rowData: [
            {'id': 999, 'name': 'Should be ignored'},
          ],
        ),
      );
      await tester.pump();

      expect(ds.getRowsCallCount, greaterThan(0));

      controller.dispose();
    });

    testWidgets('getServerSideRowCount returns null outside SSRM mode', (
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
                columnDefs: const [OsColumnDef(field: 'id', headerName: 'ID')],
                controller: controller,
                rowData: const [
                  {'id': 1},
                ],
              ),
            ),
          ),
        ),
      );

      expect(controller.getServerSideRowCount(), isNull);

      controller.dispose();
    });
  });
}
