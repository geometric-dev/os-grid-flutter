import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import 'body_painter.dart';
import 'grid_paint_context.dart';

/// Overlay painter for cell flash highlights (quality program v3 item 5).
///
/// A thin CustomPainter shell around [BodyPainter.paintFlashOverlays]: the
/// flash code is owned by the body painter, but legacy draw order places
/// flashes ABOVE the range overlays (and above the header/pinned layers), so
/// the layered repaint path needs this pass on its own topmost band rather
/// than inside the bottom body layer.
class FlashOverlayPainter extends CustomPainter {
  FlashOverlayPainter(this.ctx);

  final GridPaintContext ctx;

  /// Size captured by the most recent [paint] call.
  ///
  /// Lets [shouldRepaint] evaluate the scroll-linked visibility gate against
  /// the previous delegate without needing a canvas (quality program v3
  /// item 7).
  @visibleForTesting
  Size? lastPaintedSize;

  @override
  void paint(Canvas canvas, Size size) {
    lastPaintedSize = size;
    BodyPainter.paintFlashOverlays(ctx, canvas, size);
  }

  @override
  bool shouldRepaint(covariant FlashOverlayPainter oldDelegate) {
    // Scroll-linked gate (quality program v3 item 7): when ONLY scrollY
    // changed among the inputs this layer consumes, repaint just when a
    // visibly flashing cell's row is on-screen under either scroll offset.
    // Flash rects move with their rows, so flashes off-screen on BOTH sides
    // (including fully-faded entries, which paint nothing) leave the layer's
    // pixels unchanged and the previous frame's raster is retained.
    if (_sameExceptScrollY(oldDelegate.ctx, ctx)) {
      if (ctx.scrollY == oldDelegate.ctx.scrollY) return false;
      final size = oldDelegate.lastPaintedSize;
      if (size == null) return true;
      return _flashesIntersectVisibleBand(oldDelegate.ctx, size) ||
          _flashesIntersectVisibleBand(ctx, size);
    }
    return _flashShouldRepaint(ctx, oldDelegate.ctx);
  }
}

/// Whether any input consumed by the flash overlay changed between the two
/// contexts: the flash set itself, the animation clock, and the geometry the
/// flashing cells resolve against.
bool _flashShouldRepaint(GridPaintContext a, GridPaintContext b) {
  // columnWidths is rebuilt per widget build, so compare by content — an
  // identity check would flag every frame (quality program v3 item 7).
  return !identical(a.cellFlashes, b.cellFlashes) ||
      a.flashElapsed != b.flashElapsed ||
      a.theme != b.theme ||
      a.textDirection != b.textDirection ||
      a.rowHeight != b.rowHeight ||
      a.rowHeightLayout != b.rowHeightLayout ||
      a.scrollX != b.scrollX ||
      a.scrollY != b.scrollY ||
      !identical(a.columns, b.columns) ||
      !listEquals(a.columnWidths, b.columnWidths) ||
      !identical(a.rowData, b.rowData);
}

/// Whether every flash-painter input EXCEPT scrollY matches between the two
/// contexts — [_flashShouldRepaint] minus the scrollY clause (quality
/// program v3 item 7).
bool _sameExceptScrollY(GridPaintContext a, GridPaintContext b) {
  return identical(a.cellFlashes, b.cellFlashes) &&
      a.flashElapsed == b.flashElapsed &&
      a.theme == b.theme &&
      a.textDirection == b.textDirection &&
      a.rowHeight == b.rowHeight &&
      a.rowHeightLayout == b.rowHeightLayout &&
      a.scrollX == b.scrollX &&
      identical(a.columns, b.columns) &&
      listEquals(a.columnWidths, b.columnWidths) &&
      identical(a.rowData, b.rowData);
}

/// Whether any visibly flashing cell's row intersects the visible row window
/// for [ctx]'s scroll offset under [size] — the same window
/// `BodyPainter.paintFlashOverlays` culls against, so a false result
/// guarantees the scroll could not change any painted pixel of this layer.
bool _flashesIntersectVisibleBand(GridPaintContext ctx, Size size) {
  final flashes = ctx.cellFlashes;
  if (flashes == null || flashes.isEmpty) return false;
  final visible = ctx.visibleRowRange(size);
  for (final flash in flashes.values) {
    final opacity = flash.opacityAt(ctx.flashElapsed);
    if (opacity == null || opacity <= 0.0) continue;
    final row = flash.position.rowIndex;
    if (row >= visible.first && row <= visible.last) return true;
  }
  return false;
}
