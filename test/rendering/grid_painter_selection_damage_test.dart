import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';
import 'package:os_grid_flutter/src/rendering/grid_painter.dart';

/// Tests for the selection-scoped dirty-region slice of GridPainter
/// (quality program v2 item 10, finishing slice).
///
/// Contract: when ONLY [GridPainter.selectedRows] changes versus the
/// previous delegate, `shouldRepaint` returns true and `hoverDamageRect` is
/// the union of the row bands for every row entering or leaving selection —
/// provided at most 64 rows changed. Bulk changes, coincident changes to any
/// other paint input, or a first transition before any paint fall back to a
/// full repaint (damage rect null).
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

  GridPainter build({
    Set<int>? selectedRows,
    int? hoveredRow,
    double scrollY = 0,
  }) {
    return GridPainter(
      columns: columns,
      rowData: rows,
      rowHeight: rowHeight,
      headerHeight: headerHeight,
      scrollX: 0,
      scrollY: scrollY,
      theme: theme,
      columnWidths: widths,
      selectedRows: selectedRows ?? const {},
      hoveredRow: hoveredRow,
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

  testWidgets('selection enter damages only the selected row band', (
    tester,
  ) async {
    final old = build();
    paintPainter(old);
    final current = build(selectedRows: {3});

    expect(current.shouldRepaint(old), isTrue);
    // Row 3's band extends below the 200px canvas; damage clips to it.
    expect(current.hoverDamageRect, Rect.fromLTRB(0, 174, size.width, 200));
  });

  testWidgets('selection move damages the union of both row bands', (
    tester,
  ) async {
    final old = build(selectedRows: {0});
    paintPainter(old);
    final current = build(selectedRows: {2});

    expect(current.shouldRepaint(old), isTrue);
    // Rows 0 and 2 are both in-band; the union spans rows 0..2.
    expect(
      current.hoverDamageRect,
      Rect.fromLTRB(0, band(0).top, size.width, band(2).bottom),
    );
  });

  testWidgets('selection exit damages only the previously selected band', (
    tester,
  ) async {
    final old = build(selectedRows: {1});
    paintPainter(old);
    final current = build();

    expect(current.shouldRepaint(old), isTrue);
    expect(current.hoverDamageRect, band(1));
  });

  testWidgets('off-canvas selected rows contribute nothing to the damage', (
    tester,
  ) async {
    // Row 60 sits far below the 200px-tall viewport and stays selected in
    // both delegates; only the off-canvas→on-canvas transition of row 1
    // changes pixels, so row 60's band is clipped away and cannot inflate
    // the damage.
    final old = build(selectedRows: {60});
    paintPainter(old);
    final current = build(selectedRows: {60, 1});

    expect(current.shouldRepaint(old), isTrue);
    expect(current.hoverDamageRect, band(1));
  });

  testWidgets('bulk selection beyond 64 rows falls back to full repaint', (
    tester,
  ) async {
    final old = build();
    paintPainter(old);
    final current = build(selectedRows: {for (var i = 0; i < 65; i++) i});

    expect(current.shouldRepaint(old), isTrue);
    expect(current.hoverDamageRect, isNull);
  });

  testWidgets('exactly 64 changed rows stays inside the slice', (tester) async {
    final old = build();
    paintPainter(old);
    final current = build(selectedRows: {for (var i = 0; i < 64; i++) i});

    expect(current.shouldRepaint(old), isTrue);
    expect(current.hoverDamageRect, isNotNull);
  });

  testWidgets(
    'content-equal but non-identical sets fall back to full repaint',
    (tester) async {
      final old = build(selectedRows: {1});
      paintPainter(old);
      final current = build(selectedRows: {1});

      expect(current.shouldRepaint(old), isTrue);
      expect(current.hoverDamageRect, isNull);
    },
  );

  testWidgets('selection change alongside hover forces full repaint', (
    tester,
  ) async {
    final old = build(selectedRows: {0}, hoveredRow: 1);
    paintPainter(old);
    final current = build(selectedRows: {2}, hoveredRow: 3);

    expect(current.shouldRepaint(old), isTrue);
    expect(current.hoverDamageRect, isNull);
  });

  testWidgets('selection change alongside scroll forces full repaint', (
    tester,
  ) async {
    final old = build(selectedRows: {0});
    paintPainter(old);
    final current = build(selectedRows: {2}, scrollY: 30);

    expect(current.shouldRepaint(old), isTrue);
    expect(current.hoverDamageRect, isNull);
  });

  testWidgets('first transition before any paint falls back to full repaint', (
    tester,
  ) async {
    final old = build();
    final current = build(selectedRows: {1});

    expect(current.shouldRepaint(old), isTrue);
    expect(current.hoverDamageRect, isNull);
  });
}
