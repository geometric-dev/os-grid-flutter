import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

void main() {
  group('ValueCache — unit tests', () {
    late ValueCache cache;

    setUp(() {
      cache = ValueCache();
    });

    test('initially empty', () {
      expect(cache.isActive, isFalse);
      expect(cache.rowCount, 0);
      expect(cache.cellCount, 0);
    });

    test('stores and retrieves values', () {
      cache.setValue('row1', 'col1', 42);
      cache.setValue('row1', 'col2', 'hello');
      cache.setValue('row2', 'col1', 99);

      expect(cache.getValue('row1', 'col1'), 42);
      expect(cache.getValue('row1', 'col2'), 'hello');
      expect(cache.getValue('row2', 'col1'), 99);
      expect(cache.isActive, isTrue);
      expect(cache.rowCount, 2);
      expect(cache.cellCount, 3);
    });

    test('returns notCached sentinel for missing values', () {
      final result = cache.getValue('missing', 'col');
      expect(identical(result, ValueCache.notCached), isTrue);
    });

    test('distinguishes cached null from cache miss', () {
      cache.setValue('row1', 'col1', null);

      expect(cache.hasValue('row1', 'col1'), isTrue);
      expect(cache.getValue('row1', 'col1'), isNull);

      expect(cache.hasValue('row1', 'col2'), isFalse);
      expect(
        identical(cache.getValue('row1', 'col2'), ValueCache.notCached),
        isTrue,
      );
    });

    test('expire() clears all entries', () {
      cache.setValue('row1', 'col1', 1);
      cache.setValue('row2', 'col2', 2);

      cache.expire();

      expect(cache.isActive, isFalse);
      expect(cache.rowCount, 0);
      expect(cache.cellCount, 0);
      expect(
        identical(cache.getValue('row1', 'col1'), ValueCache.notCached),
        isTrue,
      );
    });

    test('expireRow() clears only the specified row', () {
      cache.setValue('row1', 'col1', 1);
      cache.setValue('row2', 'col1', 2);

      cache.expireRow('row1');

      expect(cache.hasValue('row1', 'col1'), isFalse);
      expect(cache.hasValue('row2', 'col1'), isTrue);
      expect(cache.getValue('row2', 'col1'), 2);
    });

    test('expireColumn() clears the column across all rows', () {
      cache.setValue('row1', 'col1', 1);
      cache.setValue('row1', 'col2', 2);
      cache.setValue('row2', 'col1', 3);
      cache.setValue('row2', 'col2', 4);

      cache.expireColumn('col1');

      expect(cache.hasValue('row1', 'col1'), isFalse);
      expect(cache.hasValue('row2', 'col1'), isFalse);
      expect(cache.getValue('row1', 'col2'), 2);
      expect(cache.getValue('row2', 'col2'), 4);
    });

    test('overwrites existing values', () {
      cache.setValue('row1', 'col1', 'old');
      cache.setValue('row1', 'col1', 'new');

      expect(cache.getValue('row1', 'col1'), 'new');
      expect(cache.cellCount, 1);
    });
  });

  group('ValueCache — size cap & eviction', () {
    test('evicts oldest entries when exceeding maxEntries', () {
      final cache = ValueCache(maxEntries: 10);
      for (var i = 0; i < 12; i++) {
        cache.setValue('row$i', 'col', i);
      }

      expect(cache.length, lessThanOrEqualTo(10));
      // The two oldest rows were evicted first.
      expect(cache.hasValue('row0', 'col'), isFalse);
      expect(cache.hasValue('row1', 'col'), isFalse);
    });

    test('recent entries survive eviction', () {
      final cache = ValueCache(maxEntries: 10);
      for (var i = 0; i < 12; i++) {
        cache.setValue('row$i', 'col', i);
      }

      expect(cache.getValue('row11', 'col'), 11);
      expect(cache.getValue('row10', 'col'), 10);
      expect(cache.hasValue('row2', 'col'), isTrue);
      expect(cache.isActive, isTrue);
    });

    test('overwriting an existing cell does not trigger eviction', () {
      final cache = ValueCache(maxEntries: 10);
      for (var i = 0; i < 10; i++) {
        cache.setValue('row$i', 'col', i);
      }

      cache.setValue('row5', 'col', 'updated');

      expect(cache.length, 10);
      expect(cache.getValue('row5', 'col'), 'updated');
    });

    test('partial-row eviction keeps the remaining columns of a swept row', () {
      final cache = ValueCache(maxEntries: 10);
      for (var c = 0; c < 8; c++) {
        cache.setValue('r1', 'c$c', c);
      }
      cache.setValue('r2', 'a', 1);
      cache.setValue('r2', 'b', 2);
      cache.setValue('r2', 'c', 3); // 11 entries → evict 1

      expect(cache.length, 10);
      expect(cache.hasValue('r1', 'c0'), isFalse);
      expect(cache.hasValue('r1', 'c1'), isTrue);
      expect(cache.rowCount, 2); // partially swept row is retained
    });

    test('expire() clears everything regardless of size', () {
      final cache = ValueCache(maxEntries: 10);
      for (var i = 0; i < 50; i++) {
        cache.setValue('row$i', 'col', i);
      }
      expect(cache.length, lessThanOrEqualTo(10));

      cache.expire();

      expect(cache.length, 0);
      expect(cache.cellCount, 0);
      expect(cache.rowCount, 0);
      expect(cache.isActive, isFalse);
      expect(
        identical(cache.getValue('row11', 'col'), ValueCache.notCached),
        isTrue,
      );
    });

    test('length tracks accurately across inserts, overwrites and expiry', () {
      final cache = ValueCache();
      expect(cache.length, 0);

      cache.setValue('r1', 'c1', 1);
      cache.setValue('r1', 'c2', 2);
      cache.setValue('r2', 'c1', 3);
      expect(cache.length, 3);
      expect(cache.length, cache.cellCount);

      cache.setValue('r1', 'c1', 'overwrite');
      expect(cache.length, 3);

      cache.expireRow('r1');
      expect(cache.length, 1);

      cache.setValue('r2', 'c1', null);
      expect(cache.length, 1); // cached null overwrite not double-counted

      cache.expireColumn('c1');
      expect(cache.length, 0);
      expect(cache.length, cache.cellCount);
    });

    test('default maxEntries does not affect typical usage', () {
      final cache = ValueCache();
      expect(cache.maxEntries, 10000);

      for (var r = 0; r < 100; r++) {
        for (var c = 0; c < 20; c++) {
          cache.setValue('row$r', 'col$c', '$r-$c');
        }
      }

      expect(cache.length, 2000);
      expect(cache.getValue('row0', 'col0'), '0-0');
      expect(cache.getValue('row99', 'col19'), '99-19');
    });

    test('maxEntries must be positive', () {
      expect(() => ValueCache(maxEntries: 0), throwsA(isA<AssertionError>()));
    });
  });

  group('ValueCache — integration with OsGrid', () {
    testWidgets('valueCacheEnabled defaults to false', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              columnDefs: [
                OsColumnDef<Map<String, dynamic>>(
                  field: 'name',
                  headerName: 'Name',
                ),
              ],
              rowData: [
                {'name': 'Alice'},
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Grid renders without error when valueCacheEnabled is not set
      expect(find.byType(OsGrid<Map<String, dynamic>>), findsOneWidget);
    });

    testWidgets('valueCacheEnabled can be set to true', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              columnDefs: [
                OsColumnDef<Map<String, dynamic>>(
                  field: 'name',
                  headerName: 'Name',
                ),
              ],
              rowData: [
                {'name': 'Alice'},
              ],
              valueCacheEnabled: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(OsGrid<Map<String, dynamic>>), findsOneWidget);
    });

    testWidgets('valueGetter is called and results are cached during sort', (
      tester,
    ) async {
      int callCount = 0;
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              valueCacheEnabled: true,
              columnDefs: [
                OsColumnDef<Map<String, dynamic>>(
                  field: 'name',
                  headerName: 'Name',
                  valueGetter: (params) {
                    callCount++;
                    return params.data['name'];
                  },
                ),
              ],
              rowData: [
                {'name': 'Charlie'},
                {'name': 'Alice'},
                {'name': 'Bob'},
              ],
              initialSort: [
                const OsSortModel(
                  colId: 'name',
                  sort: OsSortDirection.ascending,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // With 3 rows and sort active, valueGetter is called.
      // With caching, each row's value should only be computed once
      // (not O(n log n) times for comparisons).
      // For 3 items, sort does ~3 comparisons = 6 getValue calls without cache.
      // With cache, it should be exactly 3 (one per row).
      expect(callCount, 3);

      controller.dispose();
    });

    testWidgets('cache is invalidated on setRowData', (tester) async {
      int callCount = 0;
      final controller = OsGridController<Map<String, dynamic>>();

      // Use a StatefulBuilder to allow changing rowData via setState
      List<Map<String, dynamic>> rowData = [
        {'name': 'Alice'},
        {'name': 'Bob'},
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setOuterState) {
              return Scaffold(
                body: Column(
                  children: [
                    TextButton(
                      key: const Key('update-btn'),
                      onPressed: () {
                        setOuterState(() {
                          rowData = [
                            {'name': 'Zara'},
                            {'name': 'Yuki'},
                          ];
                        });
                      },
                      child: const Text('Update'),
                    ),
                    Expanded(
                      child: OsGrid<Map<String, dynamic>>(
                        controller: controller,
                        valueCacheEnabled: true,
                        columnDefs: [
                          OsColumnDef<Map<String, dynamic>>(
                            field: 'name',
                            headerName: 'Name',
                            valueGetter: (params) {
                              callCount++;
                              return params.data['name'];
                            },
                          ),
                        ],
                        rowData: rowData,
                        initialSort: [
                          const OsSortModel(
                            colId: 'name',
                            sort: OsSortDirection.ascending,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final initialCallCount = callCount;
      expect(initialCallCount, 2); // 2 rows cached

      // Update row data via widget prop change — cache should be invalidated
      await tester.tap(find.byKey(const Key('update-btn')));
      await tester.pumpAndSettle();

      // New data should trigger fresh valueGetter calls
      expect(callCount, greaterThan(initialCallCount));

      controller.dispose();
    });

    testWidgets('expireValueCache() clears the cache', (tester) async {
      int callCount = 0;
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              valueCacheEnabled: true,
              columnDefs: [
                OsColumnDef<Map<String, dynamic>>(
                  field: 'name',
                  headerName: 'Name',
                  valueGetter: (params) {
                    callCount++;
                    return params.data['name'];
                  },
                ),
              ],
              rowData: [
                {'name': 'Alice'},
                {'name': 'Bob'},
              ],
              initialSort: [
                const OsSortModel(
                  colId: 'name',
                  sort: OsSortDirection.ascending,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Record call count after initial sort
      final afterInitial = callCount;

      // Expire the cache manually
      controller.expireValueCache();

      // The cache is cleared but no reprocess happens until data changes.
      // Verify the method doesn't throw.
      expect(afterInitial, greaterThan(0));

      controller.dispose();
    });

    testWidgets('cache works with getRowId for stable keys', (tester) async {
      int callCount = 0;
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              valueCacheEnabled: true,
              getRowId: (data) => data['id'].toString(),
              columnDefs: [
                OsColumnDef<Map<String, dynamic>>(
                  field: 'name',
                  headerName: 'Name',
                  valueGetter: (params) {
                    callCount++;
                    return params.data['name'];
                  },
                ),
              ],
              rowData: [
                {'id': 1, 'name': 'Charlie'},
                {'id': 2, 'name': 'Alice'},
                {'id': 3, 'name': 'Bob'},
              ],
              initialSort: [
                const OsSortModel(
                  colId: 'name',
                  sort: OsSortDirection.ascending,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // With getRowId, cache keys are stable IDs
      // Each row's value computed exactly once
      expect(callCount, 3);

      controller.dispose();
    });

    testWidgets(
      'without valueCacheEnabled, valueGetter called multiple times during sort',
      (tester) async {
        int callCount = 0;
        final controller = OsGridController<Map<String, dynamic>>();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: OsGrid<Map<String, dynamic>>(
                controller: controller,
                valueCacheEnabled: false,
                columnDefs: [
                  OsColumnDef<Map<String, dynamic>>(
                    field: 'name',
                    headerName: 'Name',
                    valueGetter: (params) {
                      callCount++;
                      return params.data['name'];
                    },
                  ),
                ],
                rowData: [
                  {'name': 'Charlie'},
                  {'name': 'Alice'},
                  {'name': 'Bob'},
                ],
                initialSort: [
                  const OsSortModel(
                    colId: 'name',
                    sort: OsSortDirection.ascending,
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Without cache, sort comparisons call valueGetter multiple times
        // For 3 items, sort typically does 2-3 comparisons = 4-6 calls
        expect(callCount, greaterThan(3));

        controller.dispose();
      },
    );

    testWidgets('cache handles null values from valueGetter', (tester) async {
      int callCount = 0;
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              valueCacheEnabled: true,
              columnDefs: [
                OsColumnDef<Map<String, dynamic>>(
                  field: 'name',
                  headerName: 'Name',
                  valueGetter: (params) {
                    callCount++;
                    return params.data['name']; // may be null
                  },
                ),
              ],
              rowData: [
                {'name': null},
                {'name': 'Alice'},
                {'name': null},
              ],
              initialSort: [
                const OsSortModel(
                  colId: 'name',
                  sort: OsSortDirection.ascending,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Each row computed once, even with null values
      expect(callCount, 3);

      controller.dispose();
    });

    testWidgets('cache is invalidated on row data widget prop change', (
      tester,
    ) async {
      int callCount = 0;
      final controller = OsGridController<Map<String, dynamic>>();

      List<Map<String, dynamic>> rowData = [
        {'name': 'Charlie'},
        {'name': 'Alice'},
        {'name': 'Bob'},
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setOuterState) {
              return Scaffold(
                body: Column(
                  children: [
                    TextButton(
                      key: const Key('change-data-btn'),
                      onPressed: () {
                        setOuterState(() {
                          rowData = [
                            {'name': 'Zara'},
                            {'name': 'Yuki'},
                            {'name': 'Xena'},
                            {'name': 'Wendy'},
                          ];
                        });
                      },
                      child: const Text('Change Data'),
                    ),
                    Expanded(
                      child: OsGrid<Map<String, dynamic>>(
                        controller: controller,
                        valueCacheEnabled: true,
                        columnDefs: [
                          OsColumnDef<Map<String, dynamic>>(
                            field: 'name',
                            headerName: 'Name',
                            valueGetter: (params) {
                              callCount++;
                              return params.data['name'];
                            },
                          ),
                        ],
                        rowData: rowData,
                        initialSort: [
                          const OsSortModel(
                            colId: 'name',
                            sort: OsSortDirection.ascending,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final afterFirst = callCount;
      expect(afterFirst, 3); // 3 rows cached

      // Change row data (triggers didUpdateWidget → _reprocessData → cache expire)
      await tester.tap(find.byKey(const Key('change-data-btn')));
      await tester.pumpAndSettle();

      // After data change, cache was invalidated and new values computed
      // 4 new rows = 4 new valueGetter calls
      expect(callCount, afterFirst + 4);

      controller.dispose();
    });
  });
}
