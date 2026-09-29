import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

/// Property-style tests over seeded random row models.
///
/// Each case derives its data from a fixed seed so failures are
/// reproducible. The generator deliberately produces heavy duplicate keys
/// to stress sort stability and pipeline composition.

List<Map<String, Object>> _generateRows(Random rng, int count) {
  const groups = ['A', 'B', 'C'];
  return List.generate(count, (i) {
    // Small value domain => many duplicate 'value'/'group' pairs.
    return <String, Object>{
      'id': 'row-$i',
      'group': groups[rng.nextInt(groups.length)],
      'name': 'n${rng.nextInt(8)}',
      'value': rng.nextInt(5) * 10,
    };
  });
}

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: SizedBox(width: 800, height: 600, child: child)),
);

List<Map<String, dynamic>> _displayRows(WidgetTester tester) {
  final grid = tester.widget<VirtualisedGrid>(find.byType(VirtualisedGrid));
  final rowData = grid.rowData;
  return [for (final row in rowData) row];
}

void main() {
  group('Sort stability under duplicate keys', () {
    test('equal keys keep original relative order across seeds', () {
      for (var seed = 0; seed < 40; seed++) {
        final rng = Random(seed);
        final rows = _generateRows(rng, 60);

        // Sort only by 'group': every row within a group ties.
        final service = SortService<Map<String, dynamic>>();
        service.setSortModel([
          const OsSortModel(colId: 'group', sort: OsSortDirection.ascending),
        ]);

        final sorted = service.sortData(
          data: rows,
          columns: const [OsColumnDef(field: 'group')],
        );

        // Multiset preserved.
        expect(sorted.length, rows.length);
        expect(
          sorted.map((r) => r['id']),
          containsAll(rows.map((r) => r['id'])),
        );

        // Group blocks are ordered ascending...
        final groupsInOrder = sorted.map((r) => r['group']).toList();
        final sortedGroups = [...groupsInOrder]..sort();
        expect(groupsInOrder, orderedEquals(sortedGroups));

        // ...and within each tie block the ORIGINAL relative order holds.
        final firstSeenIndex = <String, int>{};
        for (var i = 0; i < rows.length; i++) {
          firstSeenIndex.putIfAbsent(rows[i]['id'] as String, () => i);
        }
        var lastOriginalIndex = -1;
        String? currentGroup;
        for (final row in sorted) {
          final g = row['group'] as String?;
          if (currentGroup != g) {
            currentGroup = g;
            lastOriginalIndex = -1;
          }
          final original = firstSeenIndex[row['id'] as String]!;
          expect(
            original,
            greaterThan(lastOriginalIndex),
            reason: 'seed=$seed: instability inside group $g',
          );
          lastOriginalIndex = original;
        }
      }
    });

    test('multi-column sort respects priority then stability', () {
      for (var seed = 100; seed < 130; seed++) {
        final rng = Random(seed);
        final rows = _generateRows(rng, 80);

        final service = SortService<Map<String, dynamic>>();
        service.setSortModel([
          const OsSortModel(colId: 'group', sort: OsSortDirection.ascending),
          const OsSortModel(colId: 'value', sort: OsSortDirection.descending),
        ]);

        final sorted = service.sortData(
          data: rows,
          columns: const [
            OsColumnDef(field: 'group'),
            OsColumnDef(field: 'value'),
          ],
        );

        for (var i = 1; i < sorted.length; i++) {
          final prev = sorted[i - 1];
          final curr = sorted[i];
          final groupCmp = (prev['group'] as String).compareTo(
            curr['group'] as String,
          );
          expect(groupCmp, lessThanOrEqualTo(0));
          if (groupCmp == 0) {
            final vPrev = prev['value'] as int;
            final vCurr = curr['value'] as int;
            expect(vPrev, greaterThanOrEqualTo(vCurr));
          }
        }
      }
    });
  });

  group('Filter -> sort pipeline order', () {
    testWidgets('output equals independently composed expectation', (
      tester,
    ) async {
      for (final seed in [7, 21, 42]) {
        final rng = Random(seed);
        final rows = _generateRows(rng, 50);

        final controller = OsGridController<Map<String, dynamic>>();

        await tester.pumpWidget(
          _wrap(
            OsGrid<Map<String, dynamic>>(
              controller: controller,
              columnDefs: const [
                OsColumnDef(field: 'id', width: 80),
                OsColumnDef(field: 'name', width: 80, filter: OsTextFilter()),
                OsColumnDef(field: 'value', width: 80, sortable: true),
              ],
              rowData: rows,
              initialSort: const [
                OsSortModel(colId: 'value', sort: OsSortDirection.descending),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Apply the text filter through the public API.
        controller.setFilterModel({
          'name': const OsColumnFilterModel(
            filterType: 'text',
            conditions: [OsFilterCondition(type: 'equals', filter: 'n1')],
          ).toJson(),
        });
        await tester.pumpAndSettle();

        final displayed = _displayRows(
          tester,
        ).where((r) => r['__isGroupRow'] != true).toList();

        // Independent expectation: filter first, THEN stable-sort desc.
        final expected = rows.where((r) => r['name'] == 'n1').toList()
          ..sort((a, b) => (b['value'] as int).compareTo(a['value'] as int));

        expect(
          displayed.map((r) => r['id']).toList(),
          expected.map((r) => r['id']).toList(),
          reason: 'seed=$seed: pipeline must be filter->sort',
        );

        await tester.pumpWidget(const SizedBox.shrink());
      }
    });
  });

  group('Grouping preserves the leaf multiset', () {
    testWidgets('every input row appears exactly once as a leaf', (
      tester,
    ) async {
      for (final seed in [3, 17]) {
        final rng = Random(seed);
        final rows = _generateRows(rng, 45);

        await tester.pumpWidget(
          _wrap(
            OsGrid<Map<String, dynamic>>(
              columnDefs: const [
                OsColumnDef(field: 'group', rowGroup: true),
                OsColumnDef(field: 'id', width: 120),
              ],
              rowData: rows,
              groupDefaultExpanded: -1,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final allRows = _displayRows(tester);
        final leaves = allRows
            .where((r) => r['__isGroupRow'] != true)
            .map((r) => r['id'])
            .toList();
        final groupRows = allRows
            .where((r) => r['__isGroupRow'] == true)
            .toList();

        expect(leaves.length, rows.length, reason: 'seed=$seed');
        expect(
          leaves.toSet().length,
          leaves.length,
          reason: 'seed=$seed: duplicate leaves',
        );
        expect(
          leaves.toSet(),
          rows.map((r) => r['id']).toSet(),
          reason: 'seed=$seed',
        );

        // Group rows partition the distinct 'group' values.
        final distinctGroups = rows.map((r) => r['group']).toSet();
        expect(groupRows.length, distinctGroups.length, reason: 'seed=$seed');

        await tester.pumpWidget(const SizedBox.shrink());
      }
    });
  });

  group('Pagination slicing bounds', () {
    testWidgets('pages tile the dataset exactly; navigation clamps', (
      tester,
    ) async {
      for (final seed in [5, 11]) {
        final rng = Random(seed);
        final rows = _generateRows(rng, 37);
        const pageSize = 10;

        final controller = OsGridController<Map<String, dynamic>>();

        await tester.pumpWidget(
          _wrap(
            OsGrid<Map<String, dynamic>>(
              controller: controller,
              columnDefs: const [OsColumnDef(field: 'id', width: 140)],
              rowData: rows,
              pagination: const OsPagination(pageSize: pageSize),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final expectedPages = (rows.length + pageSize - 1) ~/ pageSize;
        expect(controller.paginationGetTotalPages(), expectedPages);
        expect(controller.paginationGetRowCount(), rows.length);

        // Walk pages forward collecting ids; tiles must be disjoint and
        // cover everything in order.
        final collected = <String>[];
        for (var p = 0; p < expectedPages; p++) {
          controller.paginationGoToPage(p);
          await tester.pumpAndSettle();

          expect(controller.paginationGetCurrentPage(), p);
          final pageRows = _displayRows(
            tester,
          ).where((r) => r['__isGroupRow'] != true).toList();
          expect(
            pageRows.length,
            lessThanOrEqualTo(pageSize),
            reason: 'seed=$seed page=$p exceeds page size',
          );
          collected.addAll(pageRows.map((r) => r['id'] as String));
        }
        expect(
          collected,
          rows.map((r) => r['id']).toList(),
          reason: 'seed=$seed: pages must tile the dataset in order',
        );

        // Bounds clamping.
        controller.paginationGoToPage(9999);
        await tester.pumpAndSettle();
        expect(controller.paginationGetCurrentPage(), expectedPages - 1);

        controller.paginationGoToPage(-7);
        await tester.pumpAndSettle();
        expect(controller.paginationGetCurrentPage(), 0);

        await tester.pumpWidget(const SizedBox.shrink());
      }
    });
  });

  group('Selection-by-id survives data shuffles', () {
    testWidgets('selected id set is invariant under row reorder', (
      tester,
    ) async {
      for (final seed in [2, 29]) {
        final rng = Random(seed);
        final rows = _generateRows(rng, 30);

        final controller = OsGridController<Map<String, dynamic>>();
        final selectedBefore = {'row-3', 'row-11', 'row-27'};

        Widget buildWith(List<Map<String, Object>> data) => _wrap(
          OsGrid<Map<String, dynamic>>(
            controller: controller,
            columnDefs: const [OsColumnDef(field: 'id', width: 140)],
            rowData: data,
            getRowId: (r) => r['id'] as String,
            rowSelection: OsRowSelection.multiple(),
          ),
        );

        await tester.pumpWidget(buildWith(rows));
        await tester.pumpAndSettle();

        controller.selectRowsById(selectedBefore.toList());
        await tester.pumpAndSettle();
        expect(controller.getSelectedIds(), selectedBefore);

        // Shuffle the source list and rebuild.
        final shuffled = [...rows]..shuffle(rng);
        await tester.pumpWidget(buildWith(shuffled));
        await tester.pumpAndSettle();

        expect(
          controller.getSelectedIds(),
          selectedBefore,
          reason: 'seed=$seed',
        );
        final selectedRowIds = controller
            .getSelectedRows()
            .map((r) => r['id'] as String)
            .toSet();
        expect(selectedRowIds, selectedBefore, reason: 'seed=$seed');

        await tester.pumpWidget(const SizedBox.shrink());
      }
    });
  });
}
