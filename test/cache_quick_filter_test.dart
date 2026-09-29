import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

/// Quality program v2 item 17 — `cacheQuickFilter`.
///
/// Verifies that the per-row aggregate/getter text cache:
/// - drops getter invocations on repeat quick-filter passes,
/// - produces results identical to the uncached path (seeded datasets),
/// - invalidates when the data source changes (setRowData, transaction)
///   and when cleared manually via the controller API.
///
/// Getter invocation counting uses [OsColumnDef.getQuickFilterText]
/// because it is invoked exclusively from the quick-filter text path —
/// unlike valueGetter, which also serves cell painting.

List<Map<String, Object>> _generateRows(Random rng, int count) {
  const groups = ['alpha', 'beta', 'gamma', 'delta'];
  return List.generate(count, (i) {
    return <String, Object>{
      'id': 'row-$i',
      'name': '${groups[rng.nextInt(groups.length)]}-$i',
      'value': rng.nextInt(100),
    };
  });
}

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: SizedBox(width: 800, height: 600, child: child)),
);

OsGrid<Map<String, Object>> _buildCountingGrid({
  required OsGridController<Map<String, Object>> controller,
  required List<Map<String, Object>> rows,
  required bool cacheQuickFilter,
  required void Function() onGetQuickFilterText,
}) {
  return OsGrid<Map<String, Object>>(
    controller: controller,
    cacheQuickFilter: cacheQuickFilter,
    getRowId: (r) => r['id'] as String,
    columnDefs: [
      const OsColumnDef<Map<String, Object>>(field: 'id', width: 140),
      // Untyped def: the pipeline resolves cols as OsColumnDef<dynamic>,
      // so typed closures are not subtypes here.
      OsColumnDef(
        field: 'name',
        width: 160,
        getQuickFilterText: (params) {
          onGetQuickFilterText();
          return params.value.toString();
        },
      ),
    ],
    rowData: rows,
  );
}

List<String> _filteredIds(OsGridController<Map<String, Object>> controller) {
  final ids = <String>[];
  controller.forEachNodeAfterFilterAndSort((data, _) {
    ids.add(data['id'] as String);
  });
  return ids;
}

void main() {
  group('getter invocation count', () {
    testWidgets('cache enabled: second identical run adds zero calls', (
      tester,
    ) async {
      var calls = 0;
      final controller = OsGridController<Map<String, Object>>();
      final rows = _generateRows(Random(9), 40);

      await tester.pumpWidget(
        _wrap(
          _buildCountingGrid(
            controller: controller,
            rows: rows,
            cacheQuickFilter: true,
            onGetQuickFilterText: () => calls++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(calls, 0, reason: 'no quick filter active yet');

      // First pass — computes and caches every consulted cell text.
      controller.setQuickFilter('ALPHA');
      await tester.pumpAndSettle();
      final afterFirstRun = calls;
      expect(afterFirstRun, greaterThan(0));

      // Second pass over the same unchanged data — fully cache-served.
      controller.setQuickFilter('BETA');
      await tester.pumpAndSettle();
      expect(
        calls,
        afterFirstRun,
        reason: 'second identical run must not re-invoke getQuickFilterText',
      );
    });

    testWidgets('cache disabled: getter re-invoked on every run', (
      tester,
    ) async {
      var calls = 0;
      final controller = OsGridController<Map<String, Object>>();
      final rows = _generateRows(Random(9), 40);

      await tester.pumpWidget(
        _wrap(
          _buildCountingGrid(
            controller: controller,
            rows: rows,
            cacheQuickFilter: false,
            onGetQuickFilterText: () => calls++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      controller.setQuickFilter('ALPHA');
      await tester.pumpAndSettle();
      final afterFirstRun = calls;
      expect(afterFirstRun, greaterThan(0));

      controller.setQuickFilter('BETA');
      await tester.pumpAndSettle();
      expect(
        calls,
        greaterThan(afterFirstRun),
        reason: 'without the cache every pass recomputes cell texts',
      );
    });
  });

  group('results parity: enabled vs disabled', () {
    testWidgets('identical filtered id sequences across seeds', (tester) async {
      const terms = ['a', 'alpha', '-1', 'zzz-no-match', ''];

      for (final seed in [3, 17, 42]) {
        final rows = _generateRows(Random(seed), 50);
        final runsByConfig = <bool, List<List<String>>>{};

        for (final cacheEnabled in [false, true]) {
          final controller = OsGridController<Map<String, Object>>();
          await tester.pumpWidget(
            _wrap(
              _buildCountingGrid(
                controller: controller,
                rows: rows,
                cacheQuickFilter: cacheEnabled,
                onGetQuickFilterText: () {},
              ),
            ),
          );
          await tester.pumpAndSettle();

          final runs = <List<String>>[];
          for (final term in terms) {
            controller.setQuickFilter(term.isEmpty ? null : term);
            await tester.pumpAndSettle();
            runs.add(_filteredIds(controller));
          }
          runsByConfig[cacheEnabled] = runs;

          await tester.pumpWidget(const SizedBox.shrink());
        }

        expect(
          runsByConfig[true],
          runsByConfig[false],
          reason: 'seed=$seed: cached results must equal uncached results',
        );
      }
    });
  });

  group('invalidation', () {
    testWidgets('setRowData invalidates cached texts', (tester) async {
      final controller = OsGridController<Map<String, Object>>();
      final rows = _generateRows(Random(5), 30);

      Widget buildWith(List<Map<String, Object>> data) => _wrap(
        _buildCountingGrid(
          controller: controller,
          rows: data,
          cacheQuickFilter: true,
          onGetQuickFilterText: () {},
        ),
      );

      await tester.pumpWidget(buildWith(rows));
      await tester.pumpAndSettle();

      // Populate the cache with the original name of row-0.
      controller.setQuickFilter('ALPHA');
      await tester.pumpAndSettle();

      // Replace rowData with new list/instances; row-0 is renamed.
      final updated = [
        for (final row in rows)
          row['id'] == 'row-0'
              ? <String, Object>{...row, 'name': 'omega-renamed'}
              : row,
      ];
      await tester.pumpWidget(buildWith(updated));
      await tester.pumpAndSettle();

      // Stale cache would still serve the old text for key row-0|name.
      controller.setQuickFilter('OMEGA-RENAMED');
      await tester.pumpAndSettle();
      expect(_filteredIds(controller), ['row-0']);

      controller.setQuickFilter('ALPHA');
      await tester.pumpAndSettle();
      expect(
        _filteredIds(controller),
        isNot(contains('row-0')),
        reason: 'renamed row must no longer match its old name',
      );
    });

    testWidgets('transaction update invalidates cached texts', (tester) async {
      final controller = OsGridController<Map<String, Object>>();
      final rows = _generateRows(
        Random(11),
        30,
      ).map((row) => <String, Object>{...row}).toList();

      await tester.pumpWidget(
        _wrap(
          OsGrid<Map<String, Object>>(
            controller: controller,
            cacheQuickFilter: true,
            deltaSort: true,
            getRowId: (r) => r['id'] as String,
            columnDefs: const [
              OsColumnDef<Map<String, Object>>(field: 'id', width: 140),
              OsColumnDef<Map<String, Object>>(field: 'name', width: 160),
            ],
            rowData: rows,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final row0Name = rows.first['name'] as String;
      // Filter by row-0's group prefix so the initial match set spans
      // multiple rows (an empty post-transaction result would fall back
      // to raw rows in forEachNodeAfterFilter and mask the assertion).
      final row0Term = row0Name.split('-').first.toUpperCase();
      controller.setQuickFilter(row0Term);
      await tester.pumpAndSettle();
      final initialIds = _filteredIds(controller);
      expect(initialIds, contains('row-0'));
      expect(initialIds.length, greaterThan(1));

      // Update transaction replaces the row object behind stable id
      // row-0. The cache key survives, so only invalidation keeps the
      // still-active filter correct: the old text must stop matching.
      controller.applyTransaction(
        OsRowTransaction<Map<String, Object>>(
          update: [
            <String, Object>{...rows.first, 'name': 'kappa-updated'},
          ],
        ),
      );
      await tester.pumpAndSettle();

      // The active quick filter is re-evaluated against the renamed
      // data — a stale cached text would keep row-0 matched.
      final afterIds = _filteredIds(controller);
      expect(afterIds, containsAll(initialIds.where((id) => id != 'row-0')));
      expect(afterIds, isNot(contains('row-0')));
    });

    testWidgets('clearQuickFilterCache forces recomputation', (tester) async {
      final controller = OsGridController<Map<String, Object>>();
      final rows = _generateRows(
        Random(21),
        20,
      ).map((row) => <String, Object>{...row}).toList();

      await tester.pumpWidget(
        _wrap(
          _buildCountingGrid(
            controller: controller,
            rows: rows,
            cacheQuickFilter: true,
            onGetQuickFilterText: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Populate the cache.
      controller.setQuickFilter('ALPHA');
      await tester.pumpAndSettle();

      // External in-place mutation: same list, same row instances.
      rows[0]['name'] = 'sigma-mutated';

      // A quick-filter-text-only change preserves the cache by design —
      // manual clearing must be what forces recomputation.
      controller.clearQuickFilterCache();
      controller.setQuickFilter('SIGMA-MUTATED');
      await tester.pumpAndSettle();
      expect(_filteredIds(controller), contains('row-0'));

      // resetQuickFilter delegates to clearQuickFilterCache.
      rows[1]['name'] = 'tau-mutated';
      controller.resetQuickFilter();
      controller.setQuickFilter('TAU-MUTATED');
      await tester.pumpAndSettle();
      expect(_filteredIds(controller), contains('row-1'));
    });
  });
}
