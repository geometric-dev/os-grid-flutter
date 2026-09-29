import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

/// Idle-time value prefetch (quality program v3 item 50).
///
/// With `prefetchEnabled` (and `valueCacheEnabled`), after the body paint
/// completes for a frame the grid schedules a microtask that pre-computes
/// valueGetter results for the NEXT viewport-height worth of rows in the
/// scroll direction, warming the ValueCache so scrolling does not stall on
/// first-time getter evaluation.
void main() {
  group('computeValuePrefetchWindow — unit', () {
    test('scrolling down prefetches one viewport beyond the window', () {
      final window = computeValuePrefetchWindow(
        rowCount: 24,
        firstVisibleRow: 0,
        lastVisibleRow: 3,
        viewportRows: 4,
        scrollingDown: true,
      );
      expect(window, isNotNull);
      expect(window!.first, 4);
      expect(window.last, 7);
    });

    test('scrolling up prefetches one viewport above the window', () {
      final window = computeValuePrefetchWindow(
        rowCount: 24,
        firstVisibleRow: 5,
        lastVisibleRow: 8,
        viewportRows: 4,
        scrollingDown: false,
      );
      expect(window, isNotNull);
      expect(window!.first, 1);
      expect(window.last, 4);
    });

    test('clamps the window at the bottom of the data', () {
      final window = computeValuePrefetchWindow(
        rowCount: 24,
        firstVisibleRow: 20,
        lastVisibleRow: 22,
        viewportRows: 4,
        scrollingDown: true,
      );
      expect(window, isNotNull);
      expect(window!.first, 23);
      expect(window.last, 23);
    });

    test('returns null when the bottom boundary was reached', () {
      final window = computeValuePrefetchWindow(
        rowCount: 24,
        firstVisibleRow: 21,
        lastVisibleRow: 23,
        viewportRows: 4,
        scrollingDown: true,
      );
      expect(window, isNull);
    });

    test('clamps the window at the top of the data', () {
      final window = computeValuePrefetchWindow(
        rowCount: 24,
        firstVisibleRow: 2,
        lastVisibleRow: 5,
        viewportRows: 4,
        scrollingDown: false,
      );
      expect(window, isNotNull);
      expect(window!.first, 0);
      expect(window.last, 1);
    });

    test('returns null when the top boundary was reached', () {
      final window = computeValuePrefetchWindow(
        rowCount: 24,
        firstVisibleRow: 0,
        lastVisibleRow: 3,
        viewportRows: 4,
        scrollingDown: false,
      );
      expect(window, isNull);
    });

    test('returns null for empty data or non-positive window', () {
      expect(
        computeValuePrefetchWindow(
          rowCount: 0,
          firstVisibleRow: 0,
          lastVisibleRow: 0,
          viewportRows: 4,
          scrollingDown: true,
        ),
        isNull,
      );
      expect(
        computeValuePrefetchWindow(
          rowCount: 10,
          firstVisibleRow: 0,
          lastVisibleRow: 3,
          viewportRows: 0,
          scrollingDown: true,
        ),
        isNull,
      );
    });
  });

  group('ValuePrefetcher wiring — widget tests', () {
    const rowHeight = 50.0;
    const headerHeight = 50.0;
    // 200px viewport − 50px header = 150px data area → rows 0..3 visible;
    // the prefetch window is one full viewport (200/50 = 4 rows) beyond.
    const viewportHeight = 200.0;

    final rows = List<_Row>.generate(24, (i) => _Row('r$i', 'Row ${i + 1}'));

    Widget buildGrid({
      required Map<String, int> getterCalls,
      required OsGridController<_Row> controller,
      bool? prefetchEnabled,
      bool valueCacheEnabled = false,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            height: viewportHeight,
            child: OsGrid<_Row>(
              controller: controller,
              theme: const OsGridTheme(
                rowHeight: rowHeight,
                headerHeight: headerHeight,
              ),
              columnDefs: [
                OsColumnDef<_Row>(
                  field: 'name',
                  headerName: 'Name',
                  width: 400,
                  valueGetter: (params) {
                    getterCalls[params.data.id] =
                        (getterCalls[params.data.id] ?? 0) + 1;
                    return params.data.name;
                  },
                ),
              ],
              rowData: rows,
              getRowId: (r) => r.id,
              valueCacheEnabled: valueCacheEnabled,
              prefetchEnabled: prefetchEnabled ?? false,
            ),
          ),
        ),
      );
    }

    testWidgets('prefetchEnabled warms the cache for the next viewport', (
      tester,
    ) async {
      final getterCalls = <String, int>{};
      final controller = OsGridController<_Row>();

      await tester.pumpWidget(
        buildGrid(
          getterCalls: getterCalls,
          controller: controller,
          prefetchEnabled: true,
          valueCacheEnabled: true,
        ),
      );
      // Extra pump flushes the post-paint prefetch microtask.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Visible rows (0..3) were evaluated by the paint pass; the next
      // viewport worth of OFFSCREEN rows (4..7) was pre-computed by the
      // idle prefetch — they have never been painted.
      for (var i = 0; i <= 7; i++) {
        expect(getterCalls['r$i'], 1, reason: 'row $i evaluated once');
      }
      for (var i = 8; i < rows.length; i++) {
        expect(getterCalls['r$i'], isNull, reason: 'row $i untouched');
      }

      // Scroll one viewport down (row 4 top-aligned): the newly visible
      // rows 4..7 resolve from the warmed cache (no new getter calls), and
      // the prefetch warms the following window (8..11).
      controller.ensureIndexVisible(4, position: RowScrollPosition.top);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      for (var i = 0; i <= 11; i++) {
        expect(getterCalls['r$i'], 1, reason: 'row $i still evaluated once');
      }
      for (var i = 12; i < rows.length; i++) {
        expect(getterCalls['r$i'], isNull, reason: 'row $i untouched');
      }

      controller.dispose();
    });

    testWidgets('prefetch defaults to off — no offscreen evaluation', (
      tester,
    ) async {
      final getterCalls = <String, int>{};
      final controller = OsGridController<_Row>();

      await tester.pumpWidget(
        buildGrid(getterCalls: getterCalls, controller: controller),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Only the visible rows were evaluated by the paint pass.
      for (var i = 0; i <= 3; i++) {
        expect(getterCalls['r$i'], 1, reason: 'visible row $i painted');
      }
      for (var i = 4; i < rows.length; i++) {
        expect(getterCalls['r$i'], isNull, reason: 'row $i never prefetched');
      }

      controller.dispose();
    });

    testWidgets('prefetch without valueCacheEnabled is a documented no-op', (
      tester,
    ) async {
      final getterCalls = <String, int>{};
      final controller = OsGridController<_Row>();

      await tester.pumpWidget(
        buildGrid(
          getterCalls: getterCalls,
          controller: controller,
          prefetchEnabled: true,
          // valueCacheEnabled defaults to false.
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // The prefetch writes are only consumed (and expired) while the value
      // cache is enabled, so the hook no-ops without it: no offscreen rows
      // were evaluated.
      for (var i = 0; i <= 3; i++) {
        expect(getterCalls['r$i'], 1, reason: 'visible row $i painted');
      }
      for (var i = 4; i < rows.length; i++) {
        expect(getterCalls['r$i'], isNull, reason: 'row $i never prefetched');
      }

      controller.dispose();
    });
  });
}

class _Row {
  const _Row(this.id, this.name);

  final String id;
  final String name;
}
