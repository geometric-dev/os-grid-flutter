import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';
import 'package:os_grid_flutter/src/rendering/grid_painter.dart';

/// Pixel-level regression tests for column-group header geometry under
/// RTL (mirrors the true-min/max-visual-edge guard in RangePainter).
///
/// Geometry (no pins, viewport 320, columns a=140, b=90, c=60, groups
/// a+b and c, scroll 0). Under RTL the row is right-aligned: columns run
/// c x 30..90, b x 90..180, a x 180..320. Group extents follow the
/// min/max visual edges of their members:
///
/// - group a+b spans x 90..320 — accent bar hugs the reading-direction
///   leading (right) edge at x 317..319 (bar width 3).
/// - group c spans x 30..90 — accent bar at x 87..89.
///
/// The pre-fix formula (first member's left edge + sum of widths = 180 +
/// 230 = 410) pushed the wide group's bar off-canvas entirely, leaving the
/// group header unbranded — which is what these assertions catch.
void main() {
  const Color accent = Color(0xFF2196F3); // quartz accentColor

  Future<Uint8List> renderGroupHeader(TextDirection direction) async {
    final painter = GridPainter(
      columns: const [
        OsColumnDef(field: 'a', headerName: 'A', width: 140),
        OsColumnDef(field: 'b', headerName: 'B', width: 90),
        OsColumnDef(field: 'c', headerName: 'C', width: 60),
      ],
      rowData: [
        {'a': 'a1', 'b': 'b1', 'c': 'c1'},
      ],
      rowHeight: 42,
      headerHeight: 48,
      scrollX: 0,
      scrollY: 0,
      theme: OsGridTheme.quartz(),
      columnWidths: [140, 90, 60],
      columnGroupSpans: const [
        ColumnGroupSpan(headerName: 'Wide group', startIndex: 0, endIndex: 1),
        ColumnGroupSpan(headerName: 'Narrow', startIndex: 2, endIndex: 2),
      ],
      groupHeaderHeight: 36,
      textDirection: direction,
    );

    final recorder = ui.PictureRecorder();
    painter.paint(ui.Canvas(recorder), const Size(320, 160));
    final image = await recorder.endRecording().toImage(320, 160);
    final data = await image.toByteData(
      format: ui.ImageByteFormat.rawStraightRgba,
    );
    return data!.buffer.asUint8List();
  }

  /// Solid opaque pixels, so straight RGBA compares exactly (±1 for AA).
  void expectAccent(Uint8List pixels, int width, int x, int y) {
    final i = (y * width + x) * 4;
    expect(
      pixels[i],
      closeTo(accent.r * 255, 2),
      reason: 'accent red at ($x, $y)',
    );
    expect(
      pixels[i + 1],
      closeTo(accent.g * 255, 2),
      reason: 'accent green at ($x, $y)',
    );
    expect(
      pixels[i + 2],
      closeTo(accent.b * 255, 2),
      reason: 'accent blue at ($x, $y)',
    );
  }

  test('LTR group headers: accent bar at each group leading edge', () async {
    final pixels = await renderGroupHeader(TextDirection.ltr);
    // Group [a+b] spans x 0..230, group [c] spans x 230..290.
    expectAccent(pixels, 320, 1, 18);
    expectAccent(pixels, 320, 231, 18);
  });

  test(
    'RTL group headers: accent bar inside the group visual extent',
    () async {
      final pixels = await renderGroupHeader(TextDirection.rtl);
      // Group [a+b] spans x 90..320 — bar on its right (leading) edge. The
      // pre-fix geometry parked this bar off-canvas (x ~407).
      expectAccent(pixels, 320, 318, 18);
      // Group [c] spans x 30..90 — bar on its right edge.
      expectAccent(pixels, 320, 88, 18);
    },
  );
}
