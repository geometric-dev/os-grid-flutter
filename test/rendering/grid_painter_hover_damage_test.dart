import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';
import 'package:os_grid_flutter/src/rendering/grid_painter.dart';

/// Tests for the hover-scoped dirty-region slice of GridPainter
/// (quality program v2 item 10).
///
/// Contract: when ONLY [GridPainter.hoveredRow] changes versus the previous
/// delegate and no flash/range overlays are active on either side,
/// `shouldRepaint` returns true and `hoverDamageRect` is the union of the
/// previous and current hovered row bands. Any other difference falls back to
/// a full repaint (damage rect null).
void main() {
  final columns = [
    const OsColumnDef(field: 'a', headerName: 'A', width: 100),
    const OsColumnDef(field: 'b', headerName: 'B', width: 100),
    const OsColumnDef(field: 'c', headerName: 'C', width: 100),
  ];
  final rows = List.generate(
    6,
    (i) => <String, dynamic>{'a': i, 'b': i, 'c': i},
  );
  final widths = [100.0, 100.0, 100.0];
  final theme = OsGridTheme.quartz();
  const size = Size(300, 200);

  // Layout constants matching the painters below.
  const headerHeight = 48.0;
  const rowHeight = 42.0;
  Rect band(int row) => Rect.fromLTRB(
    0,
    headerHeight + row * rowHeight,
    size.width,
    headerHeight + (row + 1) * rowHeight,
  );

  // Columns are 100 wide with no pins, so column i sits at x = i * 100.
  Rect columnBand(int col) => Rect.fromLTWH(col * 100.0, 0, 100.0, size.height);

  GridPainter build({
    int? hoveredRow,
    String? hoveredColId,
    double scrollX = 0,
    double scrollY = 0,
    Map<CellPosition, CellFlashState>? cellFlashes,
    List<CellRange>? cellRanges,
  }) {
    return GridPainter(
      columns: columns,
      rowData: rows,
      rowHeight: rowHeight,
      headerHeight: headerHeight,
      scrollX: scrollX,
      scrollY: scrollY,
      theme: theme,
      columnWidths: widths,
      hoveredRow: hoveredRow,
      hoveredColId: hoveredColId,
      cellFlashes: cellFlashes,
      cellRanges: cellRanges,
    );
  }

  /// Paints [painter] so its internal last-painted-size bookkeeping is
  /// populated, as it would be in a real frame.
  void paintPainter(GridPainter painter) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    painter.paint(canvas, size);
    recorder.endRecording();
  }

  testWidgets('identical delegates do not repaint', (tester) async {
    final old = build(hoveredRow: 1);
    paintPainter(old);
    final current = build(hoveredRow: 1);

    expect(current.shouldRepaint(old), isFalse);
    expect(current.hoverDamageRect, isNull);
  });

  testWidgets('hover enter damages only the entered row band', (tester) async {
    final old = build();
    paintPainter(old);
    final current = build(hoveredRow: 1);

    expect(current.shouldRepaint(old), isTrue);
    expect(current.hoverDamageRect, band(1));
  });

  testWidgets('hover move damages the union of both row bands', (tester) async {
    final old = build(hoveredRow: 0);
    paintPainter(old);
    final current = build(hoveredRow: 2);

    expect(current.shouldRepaint(old), isTrue);
    // The union spans from the top of row 0 to the bottom of row 2.
    expect(
      current.hoverDamageRect,
      Rect.fromLTRB(0, band(0).top, size.width, band(2).bottom),
    );
  });

  testWidgets('hover exit damages only the previously hovered band', (
    tester,
  ) async {
    final old = build(hoveredRow: 1);
    paintPainter(old);
    final current = build();

    expect(current.shouldRepaint(old), isTrue);
    expect(current.hoverDamageRect, band(1));
  });

  testWidgets('scroll change alongside hover forces full repaint', (
    tester,
  ) async {
    final old = build(hoveredRow: 0);
    paintPainter(old);
    final current = build(hoveredRow: 2, scrollY: 30);

    expect(current.shouldRepaint(old), isTrue);
    expect(current.hoverDamageRect, isNull);
  });

  testWidgets('active flashes on the new delegate force full repaint', (
    tester,
  ) async {
    final old = build(hoveredRow: 0);
    paintPainter(old);
    final flashes = {
      const CellPosition(rowIndex: 3, colId: 'a'): CellFlashState(
        position: const CellPosition(rowIndex: 3, colId: 'a'),
        startTime: Duration.zero,
        flashDuration: const Duration(milliseconds: 500),
        fadeDuration: const Duration(milliseconds: 500),
        flashDelay: Duration.zero,
        fadeDelay: Duration.zero,
      ),
    };
    final current = build(hoveredRow: 2, cellFlashes: flashes);

    expect(current.shouldRepaint(old), isTrue);
    expect(current.hoverDamageRect, isNull);
  });

  testWidgets('active ranges on the old delegate force full repaint', (
    tester,
  ) async {
    final old = build(
      hoveredRow: 0,
      cellRanges: const [
        CellRange(startRow: 0, endRow: 1, startColumn: 0, endColumn: 1),
      ],
    );
    paintPainter(old);
    final current = build(hoveredRow: 2);

    expect(current.shouldRepaint(old), isTrue);
    expect(current.hoverDamageRect, isNull);
  });

  testWidgets('column hover move damages the union of both column bands', (
    tester,
  ) async {
    final old = build(hoveredRow: 0, hoveredColId: 'a');
    paintPainter(old);
    final current = build(hoveredRow: 0, hoveredColId: 'b');

    expect(current.shouldRepaint(old), isTrue);
    // Columns a (x 0..100) and b (x 100..200) union into x 0..200.
    expect(current.hoverDamageRect, Rect.fromLTRB(0, 0, 200, size.height));
  });

  testWidgets('column hover enter damages only the entered column band', (
    tester,
  ) async {
    final old = build();
    paintPainter(old);
    final current = build(hoveredColId: 'c');

    expect(current.shouldRepaint(old), isTrue);
    expect(current.hoverDamageRect, columnBand(2));
  });

  testWidgets('column hover exit damages only the previously hovered band', (
    tester,
  ) async {
    final old = build(hoveredColId: 'b');
    paintPainter(old);
    final current = build();

    expect(current.shouldRepaint(old), isTrue);
    expect(current.hoverDamageRect, columnBand(1));
  });

  testWidgets('row and column hover changing together unions all four bands', (
    tester,
  ) async {
    final old = build(hoveredRow: 0, hoveredColId: 'a');
    paintPainter(old);
    final current = build(hoveredRow: 2, hoveredColId: 'b');

    expect(current.shouldRepaint(old), isTrue);
    // Row bands are full-width and column bands are full-height, so a
    // combined row+column hover transition degrades to full-canvas damage.
    expect(
      current.hoverDamageRect,
      Rect.fromLTRB(0, 0, size.width, size.height),
    );
  });

  testWidgets('column hover onto an unknown colId falls back to full repaint', (
    tester,
  ) async {
    // The previous column band resolves, the new one does not (hidden
    // column) — nothing proves the disappearance is covered, so full
    // repaint.
    final old = build();
    paintPainter(old);
    final current = build(hoveredColId: 'missing');

    expect(current.shouldRepaint(old), isTrue);
    expect(current.hoverDamageRect, isNull);
  });

  testWidgets('column hover change alongside scroll forces full repaint', (
    tester,
  ) async {
    final old = build(hoveredColId: 'a');
    paintPainter(old);
    final current = build(hoveredColId: 'b', scrollY: 30);

    expect(current.shouldRepaint(old), isTrue);
    expect(current.hoverDamageRect, isNull);
  });

  testWidgets('data change alongside hover forces full repaint', (
    tester,
  ) async {
    final old = build(hoveredRow: 0);
    paintPainter(old);
    // New rowData instance breaks the identical-except-hover contract.
    final current = GridPainter(
      columns: columns,
      rowData: List.generate(
        6,
        (i) => <String, dynamic>{'a': i, 'b': i, 'c': i + 1},
      ),
      rowHeight: rowHeight,
      headerHeight: headerHeight,
      scrollX: 0,
      scrollY: 0,
      theme: theme,
      columnWidths: widths,
      hoveredRow: 2,
    );

    expect(current.shouldRepaint(old), isTrue);
    expect(current.hoverDamageRect, isNull);
  });

  testWidgets('first transition before any paint falls back to full repaint', (
    tester,
  ) async {
    // Old painter never painted — no size to compute bands from.
    final old = build();
    final current = build(hoveredRow: 1);

    expect(current.shouldRepaint(old), isTrue);
    expect(current.hoverDamageRect, isNull);
  });
}
