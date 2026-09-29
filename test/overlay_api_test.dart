import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

const _loadingOverlayKey = Key('test-loading-overlay');
const _noRowsOverlayKey = Key('test-no-rows-overlay');

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: SizedBox(width: 800, height: 600, child: child)),
);

OsGrid<Map<String, dynamic>> _grid({
  required OsGridController<Map<String, dynamic>> controller,
  List<Map<String, dynamic>>? rowData,
  bool? loading,
  OsInfiniteDatasource<Map<String, dynamic>>? datasource,
  OsInfiniteRowModel? infiniteRowModel,
}) {
  return OsGrid<Map<String, dynamic>>(
    controller: controller,
    columnDefs: const [
      OsColumnDef(field: 'id', headerName: 'ID'),
      OsColumnDef(field: 'name', headerName: 'Name'),
    ],
    rowData: rowData,
    loading: loading,
    loadingOverlay: const SizedBox(key: _loadingOverlayKey),
    noRowsOverlay: const SizedBox(key: _noRowsOverlayKey),
    infiniteRowModel: infiniteRowModel,
    datasource: datasource,
  );
}

/// A datasource that captures requests without completing them, so tests
/// control exactly when block fetches finish.
class _DeferredDatasource extends OsInfiniteDatasource<Map<String, dynamic>> {
  final List<OsInfiniteGetRowsParams<Map<String, dynamic>>> held = [];

  @override
  void getRows(OsInfiniteGetRowsParams<Map<String, dynamic>> params) {
    held.add(params);
  }

  /// Completes every held request with a full page of rows.
  ///
  /// Drains repeatedly: completing one request can synchronously dispatch
  /// further queued blocks (the concurrency slot frees up), which land in
  /// [held] mid-completion.
  void completeAll({int total = 100}) {
    while (held.isNotEmpty) {
      final batch = List.of(held);
      held.clear();
      for (final params in batch) {
        final end = params.endRow.clamp(0, total);
        final rows = <Map<String, dynamic>>[
          for (int i = params.startRow; i < end; i++)
            {'id': i, 'name': 'Row $i'},
        ];
        params.successCallback(rows, lastRow: total);
      }
    }
  }
}

void main() {
  group(
    'Overlay API — explicit override (showLoadingOverlay / hideOverlay)',
    () {
      testWidgets('showLoadingOverlay shows the loading overlay', (
        tester,
      ) async {
        final controller = OsGridController<Map<String, dynamic>>();

        await tester.pumpWidget(
          _wrap(
            _grid(
              controller: controller,
              rowData: const [
                {'id': 1, 'name': 'Alice'},
              ],
            ),
          ),
        );
        expect(find.byKey(_loadingOverlayKey), findsNothing);
        expect(find.byKey(_noRowsOverlayKey), findsNothing);

        controller.showLoadingOverlay();
        await tester.pump();

        expect(find.byKey(_loadingOverlayKey), findsOneWidget);
        expect(find.byKey(_noRowsOverlayKey), findsNothing);

        controller.dispose();
      });

      testWidgets('loading override persists across pumps and rebuilds', (
        tester,
      ) async {
        final controller = OsGridController<Map<String, dynamic>>();

        await tester.pumpWidget(
          _wrap(
            _grid(
              controller: controller,
              rowData: const [
                {'id': 1, 'name': 'Alice'},
              ],
            ),
          ),
        );
        controller.showLoadingOverlay();
        await tester.pump();
        await tester.pump();
        await tester.pump();

        expect(find.byKey(_loadingOverlayKey), findsOneWidget);

        controller.dispose();
      });

      testWidgets('hideOverlay restores automatic heuristics (rows → none)', (
        tester,
      ) async {
        final controller = OsGridController<Map<String, dynamic>>();

        await tester.pumpWidget(
          _wrap(
            _grid(
              controller: controller,
              rowData: const [
                {'id': 1, 'name': 'Alice'},
              ],
            ),
          ),
        );

        controller.showLoadingOverlay();
        await tester.pump();
        expect(find.byKey(_loadingOverlayKey), findsOneWidget);

        controller.hideOverlay();
        await tester.pump();

        expect(find.byKey(_loadingOverlayKey), findsNothing);
        expect(find.byKey(_noRowsOverlayKey), findsNothing);

        controller.dispose();
      });

      testWidgets('hideOverlay restores no-rows heuristic on empty grid', (
        tester,
      ) async {
        final controller = OsGridController<Map<String, dynamic>>();

        await tester.pumpWidget(
          _wrap(_grid(controller: controller, rowData: const [])),
        );
        expect(find.byKey(_noRowsOverlayKey), findsOneWidget);

        controller.showLoadingOverlay();
        await tester.pump();
        expect(find.byKey(_loadingOverlayKey), findsOneWidget);
        // Explicit override beats the no-rows heuristic.
        expect(find.byKey(_noRowsOverlayKey), findsNothing);

        controller.hideOverlay();
        await tester.pump();
        expect(find.byKey(_loadingOverlayKey), findsNothing);
        expect(find.byKey(_noRowsOverlayKey), findsOneWidget);

        controller.dispose();
      });

      testWidgets('override persists across a rowData change (kept until '
          'hidden, mirroring AG Grid)', (tester) async {
        final controller = OsGridController<Map<String, dynamic>>();

        await tester.pumpWidget(
          _wrap(_grid(controller: controller, rowData: const [])),
        );
        controller.showLoadingOverlay();
        await tester.pump();
        expect(find.byKey(_loadingOverlayKey), findsOneWidget);

        // New data arrives — the manual overlay is NOT auto-cleared.
        await tester.pumpWidget(
          _wrap(
            _grid(
              controller: controller,
              rowData: const [
                {'id': 1, 'name': 'Alice'},
                {'id': 2, 'name': 'Bob'},
              ],
            ),
          ),
        );
        await tester.pump();

        expect(find.byKey(_loadingOverlayKey), findsOneWidget);

        controller.hideOverlay();
        await tester.pump();
        expect(find.byKey(_loadingOverlayKey), findsNothing);

        controller.dispose();
      });

      testWidgets('explicit override wins over the widget loading parameter', (
        tester,
      ) async {
        final controller = OsGridController<Map<String, dynamic>>();

        await tester.pumpWidget(
          _wrap(
            _grid(
              controller: controller,
              rowData: const [
                {'id': 1, 'name': 'Alice'},
              ],
              loading: true,
            ),
          ),
        );
        expect(find.byKey(_loadingOverlayKey), findsOneWidget);

        controller.showNoRowsOverlay();
        await tester.pump();

        expect(find.byKey(_noRowsOverlayKey), findsOneWidget);
        expect(find.byKey(_loadingOverlayKey), findsNothing);

        controller.hideOverlay();
        await tester.pump();
        // Back to the widget param heuristic.
        expect(find.byKey(_loadingOverlayKey), findsOneWidget);

        controller.dispose();
      });

      testWidgets('showNoRowsOverlay shows the no-rows overlay over rows', (
        tester,
      ) async {
        final controller = OsGridController<Map<String, dynamic>>();

        await tester.pumpWidget(
          _wrap(
            _grid(
              controller: controller,
              rowData: const [
                {'id': 1, 'name': 'Alice'},
              ],
            ),
          ),
        );

        controller.showNoRowsOverlay();
        await tester.pump();

        expect(find.byKey(_noRowsOverlayKey), findsOneWidget);
        expect(find.byKey(_loadingOverlayKey), findsNothing);

        controller.dispose();
      });

      testWidgets('hideOverlay is a no-op without an active override', (
        tester,
      ) async {
        final controller = OsGridController<Map<String, dynamic>>();

        await tester.pumpWidget(
          _wrap(
            _grid(
              controller: controller,
              rowData: const [
                {'id': 1, 'name': 'Alice'},
              ],
            ),
          ),
        );

        controller.hideOverlay(); // must not throw
        await tester.pump();
        expect(find.byKey(_loadingOverlayKey), findsNothing);
        expect(find.byKey(_noRowsOverlayKey), findsNothing);
        expect(controller.overlayOverride, isNull);

        controller.dispose();
      });

      testWidgets('overlayOverride getter reflects the current request', (
        tester,
      ) async {
        final controller = OsGridController<Map<String, dynamic>>();
        expect(controller.overlayOverride, isNull);

        controller.showLoadingOverlay();
        expect(controller.overlayOverride, OsGridOverlay.loading);

        controller.showNoRowsOverlay();
        expect(controller.overlayOverride, OsGridOverlay.noRows);

        controller.hideOverlay();
        expect(controller.overlayOverride, isNull);

        controller.dispose();
      });
    },
  );

  group('Infinite row model — automatic loading overlay', () {
    testWidgets('shows LOADING while blocks are in flight and rows are '
        'missing, hides when data lands', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();
      final datasource = _DeferredDatasource();

      await tester.pumpWidget(
        _wrap(
          _grid(
            controller: controller,
            datasource: datasource,
            infiniteRowModel: const OsInfiniteRowModel(
              cacheBlockSize: 50,
              infiniteInitialRowCount: 100,
            ),
          ),
        ),
      );
      await tester.pump();

      // Requests are held by the test — grid shows the loading overlay
      // instead of silently displaying an under-loaded viewport.
      expect(datasource.held, isNotEmpty);
      expect(controller.isInfiniteCacheLoading, true);
      expect(find.byKey(_loadingOverlayKey), findsOneWidget);
      expect(find.byKey(_noRowsOverlayKey), findsNothing);

      datasource.completeAll(total: 100);
      await tester.pump();
      await tester.pump();

      expect(controller.isInfiniteCacheLoading, false);
      expect(find.byKey(_loadingOverlayKey), findsNothing);
      expect(find.byKey(_noRowsOverlayKey), findsNothing);

      controller.dispose();
    });

    testWidgets('auto-loading overlay does not fight a manual no-rows '
        'override', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();
      final datasource = _DeferredDatasource();

      await tester.pumpWidget(
        _wrap(
          _grid(
            controller: controller,
            datasource: datasource,
            infiniteRowModel: const OsInfiniteRowModel(
              cacheBlockSize: 50,
              infiniteInitialRowCount: 100,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(_loadingOverlayKey), findsOneWidget);

      controller.showNoRowsOverlay();
      await tester.pump();
      expect(find.byKey(_noRowsOverlayKey), findsOneWidget);
      expect(find.byKey(_loadingOverlayKey), findsNothing);

      datasource.completeAll(total: 100);
      await tester.pump();
      await tester.pump();
      // Manual override still up after data arrived.
      expect(find.byKey(_noRowsOverlayKey), findsOneWidget);

      controller.dispose();
    });

    testWidgets('non-infinite grids never consult the cache probe', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(
        _wrap(_grid(controller: controller, rowData: const [])),
      );
      await tester.pump();

      expect(controller.isInfiniteCacheLoading, false);
      expect(find.byKey(_noRowsOverlayKey), findsOneWidget);

      controller.dispose();
    });
  });
}
