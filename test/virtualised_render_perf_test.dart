import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';
import 'package:os_grid_flutter/src/rendering/grid_painter.dart';

/// QW4 render-performance regression tests:
/// - hover notifier repaints the painter without rebuilding the subtree
/// - ColumnLayout memoization hit/miss behaviour
/// - RepaintBoundary around the single-canvas grid paint
/// - flash ticker settles (stops scheduling frames) once flashes retire
/// - ballistic (fling) scroll continues past finger lift and settles
void main() {
  const headerHeight = 24.0;
  const rowHeight = 25.0;

  List<Map<String, dynamic>> buildRows(int count) =>
      List.generate(count, (i) => {'name': 'Row $i', 'value': i});

  List<OsColumnDef> buildColumns() => [
    const OsColumnDef(field: 'name', width: 140),
    const OsColumnDef(field: 'value', width: 120),
  ];

  Widget wrapGrid({
    required int rowCount,
    Map<int, double>? columnWidths,
    ValueNotifier<Offset>? scrollPositionNotifier,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 320,
          height: 240,
          child: VirtualisedGrid(
            columns: buildColumns(),
            rowData: buildRows(rowCount),
            headerHeight: headerHeight,
            rowHeight: rowHeight,
            columnWidths: columnWidths,
            scrollPositionNotifier: scrollPositionNotifier,
          ),
        ),
      ),
    );
  }

  GridPainter currentPainter(WidgetTester tester) =>
      tester
              .widgetList<CustomPaint>(
                find.byWidgetPredicate(
                  (w) => w is CustomPaint && w.painter is GridPainter,
                ),
              )
              .first
              .painter
          as GridPainter;

  VirtualisedGridState stateOf(WidgetTester tester) =>
      tester.state<VirtualisedGridState>(find.byType(VirtualisedGrid));

  Future<TestGesture> addMousePointer(WidgetTester tester, int pointer) async {
    final gridOrigin = tester.getTopLeft(find.byType(VirtualisedGrid));
    final gesture = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
      pointer: pointer,
    );
    await gesture.addPointer(location: gridOrigin);
    addTearDown(gesture.removePointer);
    await tester.pump();
    return gesture;
  }

  group('hover routed via ValueNotifier (QW4 item 3)', () {
    testWidgets('pointer moves repaint painter without subtree rebuild', (
      tester,
    ) async {
      await tester.pumpWidget(wrapGrid(rowCount: 40));
      await tester.pump();

      final state = stateOf(tester);
      final buildsBeforeHover = state.buildCount;

      final gridOrigin = tester.getTopLeft(find.byType(VirtualisedGrid));
      final gesture = await addMousePointer(tester, 7);

      // Sweep vertically across several rows (same cursor: click).
      for (var row = 1; row <= 5; row++) {
        await gesture.moveTo(
          gridOrigin +
              Offset(20, headerHeight + row * rowHeight + rowHeight / 2),
        );
        await tester.pump();
      }

      // No State.build ran for any hover move.
      expect(state.buildCount, buildsBeforeHover);

      // Painter reflects the latest hovered row — a repaint happened.
      expect(currentPainter(tester).hoveredRow, 5);

      // Exit clears hover without a rebuild either.
      await gesture.moveTo(gridOrigin - const Offset(50, 50));
      await tester.pump();
      expect(currentPainter(tester).hoveredRow, isNull);
      expect(state.buildCount, buildsBeforeHover);
    });

    testWidgets('cursor transition does not re-run State.build either', (
      tester,
    ) async {
      await tester.pumpWidget(wrapGrid(rowCount: 40));
      await tester.pump();

      final state = stateOf(tester);
      final buildsBefore = state.buildCount;

      final gridOrigin = tester.getTopLeft(find.byType(VirtualisedGrid));
      final gesture = await addMousePointer(tester, 8);

      // Onto a data cell (click cursor)...
      await gesture.moveTo(gridOrigin + const Offset(20, 80));
      await tester.pump();
      // ...then onto a header resize edge (within 5px of the name/value
      // boundary at x=140).
      await gesture.moveTo(gridOrigin + const Offset(138, 10));
      await tester.pump();

      // Column highlight is disabled, so no colId reaches the painter.
      expect(currentPainter(tester).hoveredColId, isNull);
      // Even a cursor change only rebuilds the scoped MouseRegion wrapper.
      expect(state.buildCount, buildsBefore);
    });
  });

  group('ColumnLayout memoization (QW4 item 20)', () {
    testWidgets('repeated hit tests hit the cache; config change misses', (
      tester,
    ) async {
      await tester.pumpWidget(wrapGrid(rowCount: 40));
      await tester.pump();
      await tester.pump(); // settle initial layout work

      var state = stateOf(tester);
      final missesAfterBuild = state.layoutCacheMisses;
      final hitsAfterBuild = state.layoutCacheHits;

      final gridOrigin = tester.getTopLeft(find.byType(VirtualisedGrid));

      // Hover sweep performs a hit test per move with unchanged inputs.
      final gesture = await addMousePointer(tester, 9);
      for (var row = 1; row <= 4; row++) {
        await gesture.moveTo(
          gridOrigin + Offset(20, headerHeight + row * rowHeight + 12),
        );
        await tester.pump();
      }

      expect(
        state.layoutCacheHits,
        greaterThan(hitsAfterBuild),
        reason: 'hover hit tests must be served from the memoized layout',
      );
      expect(state.layoutCacheMisses, missesAfterBuild);

      // Changing resolved widths invalidates the memoized layout — either
      // during the rebuild itself or on the next gesture-driven hit test.
      final missesBeforeConfigChange = state.layoutCacheMisses;
      await tester.pumpWidget(
        wrapGrid(rowCount: 40, columnWidths: const {0: 220.0}),
      );
      await tester.pump();
      state = stateOf(tester);

      await gesture.moveTo(gridOrigin + const Offset(20, 80));
      await tester.pump();

      expect(state.layoutCacheMisses, greaterThan(missesBeforeConfigChange));
    });
  });

  group('RepaintBoundary (QW4 item 21)', () {
    testWidgets('grid canvas is wrapped in its own repaint layer', (
      tester,
    ) async {
      await tester.pumpWidget(wrapGrid(rowCount: 10));
      await tester.pump();

      final customPaintFinder = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is GridPainter,
      );
      expect(customPaintFinder, findsOneWidget);
      expect(
        find.ancestor(
          of: customPaintFinder,
          matching: find.byType(RepaintBoundary),
        ),
        findsWidgets,
      );
    });
  });

  group('flash ticker (QW4 item 31)', () {
    testWidgets('flash animation retires and frames stop being scheduled', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              height: 240,
              child: OsGrid<Map<String, dynamic>>(
                controller: controller,
                columnDefs: [
                  const OsColumnDef(field: 'name'),
                  const OsColumnDef(field: 'value'),
                ],
                rowData: buildRows(20),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      controller.flashCells(const FlashCellsParams(columns: ['value']));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      // Must terminate: proves the frame-driven ticker stops once all
      // flashes retire (an always-running ticker would hang pumpAndSettle).
      await tester.pumpAndSettle();
    });
  });

  group('ballistic fling scroll (QW4 item 9 / stretch)', () {
    testWidgets('scroll continues past finger lift and settles', (
      tester,
    ) async {
      final scrollNotifier = ValueNotifier<Offset>(Offset.zero);
      await tester.pumpWidget(
        wrapGrid(rowCount: 400, scrollPositionNotifier: scrollNotifier),
      );
      await tester.pump();

      final state = stateOf(tester);

      await tester.fling(
        find.byType(VirtualisedGrid),
        const Offset(0, -160),
        1200,
      );
      final atLift = scrollNotifier.value.dy;
      expect(state.isFlingActive, isTrue);

      // First ticker callback is anchored at Duration.zero; the next frame
      // integrates the first real step.
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 80));
      final shortlyAfter = scrollNotifier.value.dy;
      expect(shortlyAfter, greaterThan(atLift));

      await tester.pumpAndSettle();
      expect(scrollNotifier.value.dy, greaterThan(shortlyAfter));
      expect(state.isFlingActive, isFalse);
      expect(scrollNotifier.value.dy, greaterThan(atLift + 10));
    });

    testWidgets('fling clamps at the bottom bound and stops', (tester) async {
      final scrollNotifier = ValueNotifier<Offset>(Offset.zero);
      await tester.pumpWidget(
        wrapGrid(rowCount: 12, scrollPositionNotifier: scrollNotifier),
      );
      await tester.pump();

      await tester.fling(
        find.byType(VirtualisedGrid),
        const Offset(0, -400),
        4000,
      );
      await tester.pumpAndSettle();

      expect(stateOf(tester).isFlingActive, isFalse);
      // Content: header 24 + 12*25 rows in a 240px viewport -> max ~84px.
      expect(scrollNotifier.value.dy, closeTo(84.0, 1.0));
    });

    testWidgets('single-move drag without timed samples does not fling', (
      tester,
    ) async {
      await tester.pumpWidget(wrapGrid(rowCount: 400));
      await tester.pump();

      final state = stateOf(tester);
      final center = tester.getCenter(find.byType(VirtualisedGrid));

      final gesture = await tester.startGesture(center);
      await gesture.moveBy(const Offset(0, -40));
      await tester.pump(kDoubleTapTimeout);
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(state.isFlingActive, isFalse);
    });

    testWidgets('new pointer down cancels an in-flight fling', (tester) async {
      final scrollNotifier = ValueNotifier<Offset>(Offset.zero);
      await tester.pumpWidget(
        wrapGrid(rowCount: 400, scrollPositionNotifier: scrollNotifier),
      );
      await tester.pump();

      final state = stateOf(tester);

      await tester.fling(
        find.byType(VirtualisedGrid),
        const Offset(0, -160),
        1200,
      );
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 50));
      expect(state.isFlingActive, isTrue);

      // Touch down cancels the ballistic scroll.
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(VirtualisedGrid)),
      );
      await tester.pump();
      expect(state.isFlingActive, isFalse);
      await gesture.up();
      await tester.pumpAndSettle();
    });
  });
}
