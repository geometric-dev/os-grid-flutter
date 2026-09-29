import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide ScrollbarPainter;
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';
import 'package:os_grid_flutter/src/rendering/body_painter.dart';
import 'package:os_grid_flutter/src/rendering/flash_overlay_painter.dart';
import 'package:os_grid_flutter/src/rendering/grid_paint_context.dart';
import 'package:os_grid_flutter/src/rendering/grid_painter.dart';
import 'package:os_grid_flutter/src/rendering/header_painter.dart';
import 'package:os_grid_flutter/src/rendering/pinned_row_painter.dart';
import 'package:os_grid_flutter/src/rendering/range_painter.dart';
import 'package:os_grid_flutter/src/rendering/scrollbar_painter.dart';

/// Scroll-linked partial repaints (quality program v3 item 7).
///
/// Contract: when ONLY scrollY changes — verified via
/// `GridPaintInputs.diffFrom` showing a lone scrollY delta — the header and
/// pinned-row layers skip repainting entirely, the body and scrollbar layers
/// repaint (new rows scrolled in / thumb moved), and the range/flash overlay
/// layers repaint only when an overlay cell intersects the visible row band
/// under either scroll offset.
///
/// The contexts below are built widget-style: `columnWidths` is a FRESH list
/// per context (VirtualisedGrid does `List.generate` on every build), which
/// is why every comparison must be content-based.
void main() {
  final columns = [
    const OsColumnDef(field: 'a', headerName: 'A', width: 100),
    const OsColumnDef(field: 'b', headerName: 'B', width: 100),
    const OsColumnDef(field: 'c', headerName: 'C', width: 100),
  ];
  final rows = List.generate(
    100,
    (i) => <String, dynamic>{'a': i, 'b': i, 'c': i},
  );
  final theme = OsGridTheme.quartz();
  // Layout: header 48 + data area 352 → 42px rows ⇒ ~8.4 visible rows.
  const size = Size(300, 400);
  const headerHeight = 48.0;
  const rowHeight = 42.0;

  int firstVisibleRow(double scrollY) => (scrollY / rowHeight).floor();
  int lastVisibleRow(double scrollY) => (scrollY / rowHeight).floor() + 9;

  GridPaintContext buildCtx({
    double scrollX = 0,
    double scrollY = 0,
    List<CellRange>? cellRanges,
    Map<CellPosition, CellFlashState>? cellFlashes,
    Duration flashElapsed = Duration.zero,
    String? hoveredColId,
  }) {
    return GridPaintContext(
      columns: columns,
      rowData: rows,
      rowHeight: rowHeight,
      headerHeight: headerHeight,
      scrollX: scrollX,
      scrollY: scrollY,
      theme: theme,
      selectedRows: const {},
      hoveredRow: null,
      hoveredColId: hoveredColId,
      // Fresh list per context, exactly as VirtualisedGrid builds it.
      columnWidths: List.generate(columns.length, (i) => columns[i].width!),
      sortColumnIndex: null,
      sortAscending: true,
      sortIndicators: null,
      columnGroupSpans: null,
      groupHeaderHeight: 0,
      floatingFilterHeight: 0,
      floatingFilterTexts: null,
      floatingFilterOperations: null,
      cellRanges: cellRanges,
      rowStyles: null,
      pinnedTopRowData: const [],
      pinnedBottomRowData: const [],
      pinnedTopRowStyles: null,
      pinnedBottomRowStyles: null,
      cellFlashes: cellFlashes,
      flashElapsed: flashElapsed,
      cellSpanService: null,
      rowHeightLayout: null,
      suppressColumnVirtualisation: false,
      textPainterCache: null,
      textScaler: TextScaler.noScaling,
      localeResolver: null,
    );
  }

  CellFlashState flashAt(int rowIndex) {
    return CellFlashState(
      position: CellPosition(rowIndex: rowIndex, colId: 'a'),
      startTime: Duration.zero,
      flashDuration: const Duration(milliseconds: 500),
      fadeDuration: const Duration(milliseconds: 1000),
      flashDelay: Duration.zero,
      fadeDelay: Duration.zero,
    );
  }

  /// Paints [painter] so its last-painted-size bookkeeping is populated, as
  /// it would be in a real frame.
  void paintPainter(CustomPainter painter) {
    final recorder = ui.PictureRecorder();
    painter.paint(Canvas(recorder), size);
    recorder.endRecording();
  }

  group('diffFrom proves a lone scrollY delta in widget-style builds', () {
    testWidgets('fresh columnWidths lists do not pollute the diff', (
      tester,
    ) async {
      final old = GridPainter.layered(buildCtx(scrollY: 0));
      final current = GridPainter.layered(buildCtx(scrollY: 42));
      expect(current.diffFrom(old), ['scrollY']);
    });

    testWidgets('width content changes are still detected', (tester) async {
      final old = GridPainter.layered(buildCtx(scrollY: 0));
      final narrowed = [
        const OsColumnDef(field: 'a', headerName: 'A', width: 50),
        const OsColumnDef(field: 'b', headerName: 'B', width: 100),
        const OsColumnDef(field: 'c', headerName: 'C', width: 100),
      ];
      final current = GridPainter.layered(
        GridPaintContext(
          columns: narrowed,
          rowData: rows,
          rowHeight: rowHeight,
          headerHeight: headerHeight,
          scrollX: 0,
          scrollY: 0,
          theme: theme,
          selectedRows: const {},
          hoveredRow: null,
          hoveredColId: null,
          columnWidths: [50.0, 100.0, 100.0],
          sortColumnIndex: null,
          sortAscending: true,
          sortIndicators: null,
          columnGroupSpans: null,
          groupHeaderHeight: 0,
          floatingFilterHeight: 0,
          floatingFilterTexts: null,
          floatingFilterOperations: null,
          cellRanges: null,
          rowStyles: null,
          pinnedTopRowData: const [],
          pinnedBottomRowData: const [],
          pinnedTopRowStyles: null,
          pinnedBottomRowStyles: null,
          cellFlashes: null,
          flashElapsed: Duration.zero,
          cellSpanService: null,
          rowHeightLayout: null,
          suppressColumnVirtualisation: false,
          textPainterCache: null,
          textScaler: TextScaler.noScaling,
          localeResolver: null,
        ),
      );
      expect(current.diffFrom(old), contains('columnWidths'));
    });
  });

  group('scrollY-only delta: per-section repaint decisions', () {
    testWidgets('header and pinned rows skip; body and scrollbar repaint', (
      tester,
    ) async {
      final oldCtx = buildCtx(scrollY: 0);
      final newCtx = buildCtx(scrollY: 42);

      expect(
        HeaderPainter(newCtx).shouldRepaint(HeaderPainter(oldCtx)),
        isFalse,
      );
      expect(
        PinnedRowPainter(newCtx).shouldRepaint(PinnedRowPainter(oldCtx)),
        isFalse,
      );
      expect(BodyPainter(newCtx).shouldRepaint(BodyPainter(oldCtx)), isTrue);
      expect(
        ScrollbarPainter(newCtx).shouldRepaint(ScrollbarPainter(oldCtx)),
        isTrue,
      );
    });

    testWidgets('identical contexts skip every layer', (tester) async {
      final oldCtx = buildCtx(scrollY: 0);
      final newCtx = buildCtx(scrollY: 0);

      expect(
        HeaderPainter(newCtx).shouldRepaint(HeaderPainter(oldCtx)),
        isFalse,
      );
      expect(
        PinnedRowPainter(newCtx).shouldRepaint(PinnedRowPainter(oldCtx)),
        isFalse,
      );
      expect(BodyPainter(newCtx).shouldRepaint(BodyPainter(oldCtx)), isFalse);
      expect(
        ScrollbarPainter(newCtx).shouldRepaint(ScrollbarPainter(oldCtx)),
        isFalse,
      );
    });

    testWidgets(
      'hover-only rebuild does not repaint header/pinned/scrollbar layers',
      (tester) async {
        final oldCtx = buildCtx(scrollY: 0);
        final hoverCtx = _withHover(buildCtx(scrollY: 0));

        expect(
          HeaderPainter(hoverCtx).shouldRepaint(HeaderPainter(oldCtx)),
          isFalse,
        );
        expect(
          PinnedRowPainter(hoverCtx).shouldRepaint(PinnedRowPainter(oldCtx)),
          isFalse,
        );
        expect(
          ScrollbarPainter(hoverCtx).shouldRepaint(ScrollbarPainter(oldCtx)),
          isFalse,
        );
        expect(
          BodyPainter(hoverCtx).shouldRepaint(BodyPainter(oldCtx)),
          isTrue,
        );
      },
    );
  });

  group('range overlay scroll-linked gate', () {
    testWidgets('no ranges: scrollY-only delta skips the layer', (
      tester,
    ) async {
      final oldPainter = RangePainter(buildCtx(scrollY: 0));
      paintPainter(oldPainter);
      final newPainter = RangePainter(buildCtx(scrollY: 42));

      expect(newPainter.shouldRepaint(oldPainter), isFalse);
    });

    testWidgets(
      'range off-screen on both sides: scrollY-only delta skips the layer',
      (tester) async {
        const farRange = CellRange(
          startRow: 50,
          endRow: 51,
          startColumn: 0,
          endColumn: 1,
        );
        // One shared list instance, as the widget would supply via its
        // stable cellRanges field across scroll-only rebuilds.
        final ranges = [farRange];
        final oldPainter = RangePainter(
          buildCtx(scrollY: 0, cellRanges: ranges),
        );
        paintPainter(oldPainter);
        final newPainter = RangePainter(
          buildCtx(scrollY: 42, cellRanges: ranges),
        );

        // Sanity: rows 50..51 are outside the visible band on both sides.
        expect(lastVisibleRow(42), lessThan(50));
        expect(newPainter.shouldRepaint(oldPainter), isFalse);
      },
    );

    testWidgets(
      'range visible on either side: scrollY-only delta repaints the layer',
      (tester) async {
        // Visible before AND after the scroll.
        final nearRanges = <CellRange>[
          const CellRange(startRow: 2, endRow: 3, startColumn: 0, endColumn: 1),
        ];
        final oldPainter = RangePainter(
          buildCtx(scrollY: 0, cellRanges: nearRanges),
        );
        paintPainter(oldPainter);
        final newPainter = RangePainter(
          buildCtx(scrollY: 42, cellRanges: nearRanges),
        );
        expect(newPainter.shouldRepaint(oldPainter), isTrue);

        // Enters the window only AFTER the scroll (row 10 vs first-visible 1).
        final enteringRanges = <CellRange>[
          const CellRange(
            startRow: 10,
            endRow: 10,
            startColumn: 0,
            endColumn: 1,
          ),
        ];
        final exitingOld = RangePainter(
          buildCtx(scrollY: 0, cellRanges: enteringRanges),
        );
        paintPainter(exitingOld);
        final enteringNew = RangePainter(
          buildCtx(scrollY: 84, cellRanges: enteringRanges),
        );
        expect(firstVisibleRow(84), lessThanOrEqualTo(10));
        expect(enteringNew.shouldRepaint(exitingOld), isTrue);
      },
    );

    testWidgets('never-painted old delegate repaints conservatively', (
      tester,
    ) async {
      const range = CellRange(
        startRow: 2,
        endRow: 2,
        startColumn: 0,
        endColumn: 1,
      );
      final ranges = [range];
      final oldPainter = RangePainter(buildCtx(scrollY: 0, cellRanges: ranges));
      final newPainter = RangePainter(
        buildCtx(scrollY: 42, cellRanges: ranges),
      );
      expect(newPainter.shouldRepaint(oldPainter), isTrue);
    });

    testWidgets('non-scroll deltas still force a full-layer repaint', (
      tester,
    ) async {
      const range = CellRange(
        startRow: 50,
        endRow: 51,
        startColumn: 0,
        endColumn: 1,
      );
      final oldPainter = RangePainter(
        buildCtx(scrollY: 42, cellRanges: [range]),
      );
      paintPainter(oldPainter);
      // A second, different range arrives — the range SET changed.
      final newPainter = RangePainter(
        buildCtx(
          scrollY: 42,
          cellRanges: [
            range,
            const CellRange(
              startRow: 0,
              endRow: 1,
              startColumn: 0,
              endColumn: 1,
            ),
          ],
        ),
      );
      expect(newPainter.shouldRepaint(oldPainter), isTrue);
    });
  });

  group('flash overlay scroll-linked gate', () {
    testWidgets('no flashes: scrollY-only delta skips the layer', (
      tester,
    ) async {
      final oldPainter = FlashOverlayPainter(buildCtx(scrollY: 0));
      paintPainter(oldPainter);
      final newPainter = FlashOverlayPainter(buildCtx(scrollY: 42));

      expect(newPainter.shouldRepaint(oldPainter), isFalse);
    });

    testWidgets(
      'flash off-screen on both sides: scrollY-only delta skips the layer',
      (tester) async {
        final flashes = {
          const CellPosition(rowIndex: 50, colId: 'a'): flashAt(50),
        };
        final oldPainter = FlashOverlayPainter(
          buildCtx(scrollY: 0, cellFlashes: flashes),
        );
        paintPainter(oldPainter);
        final newPainter = FlashOverlayPainter(
          buildCtx(scrollY: 42, cellFlashes: flashes),
        );

        expect(newPainter.shouldRepaint(oldPainter), isFalse);
      },
    );

    testWidgets('flash visible: scrollY-only delta repaints the layer', (
      tester,
    ) async {
      final flashes = {const CellPosition(rowIndex: 2, colId: 'a'): flashAt(2)};
      final oldPainter = FlashOverlayPainter(
        buildCtx(scrollY: 0, cellFlashes: flashes),
      );
      paintPainter(oldPainter);
      final newPainter = FlashOverlayPainter(
        buildCtx(scrollY: 42, cellFlashes: flashes),
      );

      expect(newPainter.shouldRepaint(oldPainter), isTrue);
    });

    testWidgets('fully-faded flash paints nothing: layer skips', (
      tester,
    ) async {
      final flashes = {
        const CellPosition(rowIndex: 2, colId: 'a'): CellFlashState(
          position: const CellPosition(rowIndex: 2, colId: 'a'),
          startTime: Duration.zero,
          flashDuration: const Duration(milliseconds: 500),
          fadeDuration: const Duration(milliseconds: 1000),
          flashDelay: Duration.zero,
          fadeDelay: Duration.zero,
        ),
      };
      final oldPainter = FlashOverlayPainter(
        buildCtx(scrollY: 0, cellFlashes: flashes),
      );
      paintPainter(oldPainter);
      // Past flashDuration + fadeDelay + fadeDuration ⇒ opacityAt → null.
      final newPainter = FlashOverlayPainter(
        buildCtx(
          scrollY: 42,
          cellFlashes: flashes,
          flashElapsed: const Duration(seconds: 2),
        ),
      );

      // Note: flashElapsed differs ⇒ NOT a scrollY-only delta ⇒ the full
      // predicate path runs and must repaint (the fade advanced).
      expect(newPainter.shouldRepaint(oldPainter), isTrue);

      // Same elapsed on both sides with a completed (invisible) flash row
      // still on-screen: a scrollY-only delta must skip.
      final settledOld = FlashOverlayPainter(
        buildCtx(
          scrollY: 0,
          cellFlashes: flashes,
          flashElapsed: const Duration(seconds: 2),
        ),
      );
      paintPainter(settledOld);
      final settledNew = FlashOverlayPainter(
        buildCtx(
          scrollY: 42,
          cellFlashes: flashes,
          flashElapsed: const Duration(seconds: 2),
        ),
      );
      expect(settledNew.shouldRepaint(settledOld), isFalse);
    });

    testWidgets('non-scroll deltas still force a full-layer repaint', (
      tester,
    ) async {
      final oldFlashes = {
        const CellPosition(rowIndex: 2, colId: 'a'): flashAt(2),
      };
      final newFlashes = {
        const CellPosition(rowIndex: 2, colId: 'a'): flashAt(2),
        const CellPosition(rowIndex: 3, colId: 'b'): flashAt(3),
      };
      final oldPainter = FlashOverlayPainter(
        buildCtx(scrollY: 42, cellFlashes: oldFlashes),
      );
      paintPainter(oldPainter);
      final newPainter = FlashOverlayPainter(
        buildCtx(scrollY: 42, cellFlashes: newFlashes),
      );
      expect(newPainter.shouldRepaint(oldPainter), isTrue);
    });
  });

  group('real widget: scroll-only frame layer retention', () {
    CustomPainter? bandPainter(WidgetTester tester, Type painterType) {
      final customPaint = tester.widgetList(
        find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter.runtimeType == painterType,
        ),
      );
      if (customPaint.isEmpty) return null;
      return (customPaint.first as CustomPaint).painter;
    }

    RenderRepaintBoundary bandBoundary(WidgetTester tester, Type painterType) {
      final paintFinder = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter.runtimeType == painterType,
      );
      return tester.renderObject<RenderRepaintBoundary>(
        find
            .ancestor(of: paintFinder, matching: find.byType(RepaintBoundary))
            .first,
      );
    }

    /// Identity set of the pictures recorded inside [boundary]'s layer — a
    /// RepaintBoundary-level paint counter: an unchanged set across a frame
    /// means the layer was retained (not repainted).
    Set<String> layerPictures(RenderRepaintBoundary boundary) {
      final pictures = <String>{};
      void visit(Layer layer) {
        if (layer is PictureLayer) {
          pictures.add(identityHashCode(layer.picture).toString());
        }
        if (layer is ContainerLayer) {
          Layer? child = layer.firstChild;
          while (child != null) {
            visit(child);
            child = child.nextSibling;
          }
        }
      }

      final layer = boundary.debugLayer;
      if (layer != null) visit(layer);
      return pictures;
    }

    testWidgets(
      'scroll-only delta repaints body/scrollbar layers, retains the rest',
      (tester) async {
        final gridRows = List.generate(
          200,
          (i) => <String, dynamic>{'a': i, 'b': i, 'c': i},
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: OsGrid<Map<String, dynamic>>(
                columnDefs: columns,
                rowData: gridRows,
                rowHeight: rowHeight,
                headerHeight: headerHeight,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final header1 = bandPainter(tester, HeaderPainter)!;
        final pinned1 = bandPainter(tester, PinnedRowPainter)!;
        final body1 = bandPainter(tester, BodyPainter)!;
        final range1 = bandPainter(tester, RangePainter)!;
        final flash1 = bandPainter(tester, FlashOverlayPainter)!;
        final scrollbar1 = bandPainter(tester, ScrollbarPainter)!;

        final headerPics = layerPictures(bandBoundary(tester, HeaderPainter));
        final rangePics = layerPictures(bandBoundary(tester, RangePainter));
        final bodyPics = layerPictures(bandBoundary(tester, BodyPainter));

        // Touch-pan scroll: a pure vertical delta with no hover or
        // selection side effects (touch never fires MouseRegion hover, and
        // a moving pointer never produces a tap).
        await tester.drag(
          find.byType(OsGrid<Map<String, dynamic>>),
          const Offset(0, -120),
        );
        await tester.pumpAndSettle();

        final header2 = bandPainter(tester, HeaderPainter)!;
        final pinned2 = bandPainter(tester, PinnedRowPainter)!;
        final body2 = bandPainter(tester, BodyPainter)!;
        final range2 = bandPainter(tester, RangePainter)!;
        final flash2 = bandPainter(tester, FlashOverlayPainter)!;
        final scrollbar2 = bandPainter(tester, ScrollbarPainter)!;

        // Painter-level decisions through the live widget wiring.
        expect(header2.shouldRepaint(header1 as HeaderPainter), isFalse);
        expect(pinned2.shouldRepaint(pinned1 as PinnedRowPainter), isFalse);
        expect(range2.shouldRepaint(range1 as RangePainter), isFalse);
        expect(flash2.shouldRepaint(flash1 as FlashOverlayPainter), isFalse);
        expect(body2.shouldRepaint(body1 as BodyPainter), isTrue);
        expect(
          scrollbar2.shouldRepaint(scrollbar1 as ScrollbarPainter),
          isTrue,
        );

        // Layer-level: header/range pictures retained, body picture replaced.
        expect(
          layerPictures(bandBoundary(tester, HeaderPainter)),
          equals(headerPics),
          reason: 'header layer must be retained on a scroll-only frame',
        );
        expect(
          layerPictures(bandBoundary(tester, RangePainter)),
          equals(rangePics),
          reason: 'range layer must be retained on a scroll-only frame',
        );
        expect(
          layerPictures(bandBoundary(tester, BodyPainter)),
          isNot(equals(bodyPics)),
          reason: 'body layer must repaint on a scroll-only frame',
        );
      },
    );
  });
}

/// Returns [ctx] with a hovered row, for hover-rebuild comparisons.
GridPaintContext _withHover(GridPaintContext ctx) {
  return GridPaintContext(
    columns: ctx.columns,
    rowData: ctx.rowData,
    rowHeight: ctx.rowHeight,
    headerHeight: ctx.headerHeight,
    scrollX: ctx.scrollX,
    scrollY: ctx.scrollY,
    theme: ctx.theme,
    selectedRows: ctx.selectedRows,
    hoveredRow: 1,
    hoveredColId: ctx.hoveredColId,
    columnWidths: ctx.columnWidths,
    sortColumnIndex: ctx.sortColumnIndex,
    sortAscending: ctx.sortAscending,
    sortIndicators: ctx.sortIndicators,
    columnGroupSpans: ctx.columnGroupSpans,
    groupHeaderHeight: ctx.groupHeaderHeight,
    floatingFilterHeight: ctx.floatingFilterHeight,
    floatingFilterTexts: ctx.floatingFilterTexts,
    floatingFilterOperations: ctx.floatingFilterOperations,
    cellRanges: ctx.cellRanges,
    rowStyles: ctx.rowStyles,
    pinnedTopRowData: ctx.pinnedTopRowData,
    pinnedBottomRowData: ctx.pinnedBottomRowData,
    pinnedTopRowStyles: ctx.pinnedTopRowStyles,
    pinnedBottomRowStyles: ctx.pinnedBottomRowStyles,
    cellFlashes: ctx.cellFlashes,
    flashElapsed: ctx.flashElapsed,
    cellSpanService: ctx.cellSpanService,
    rowHeightLayout: ctx.rowHeightLayout,
    suppressColumnVirtualisation: ctx.suppressColumnVirtualisation,
    textPainterCache: ctx.textPainterCache,
    textScaler: ctx.textScaler,
    localeResolver: ctx.localeResolver,
    textDirection: ctx.textDirection,
  );
}
