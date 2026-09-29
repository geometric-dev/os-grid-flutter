import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import 'column_layout.dart';
import 'grid_paint_context.dart';
import 'rtl_geometry.dart';

/// Per-section painter for the translucent selection overlays (quality
/// program v3 item 5).
///
/// Owns the two overlay passes that share a z-band directly above the pinned
/// row bands in the monolithic draw order:
/// - the full-height column hover highlight ([GridPaintContext.hoveredColId]),
/// - the cell-range selection fills and borders.
///
/// Both read all inputs from a shared [GridPaintContext] and render byte-for-
/// byte the same ops the monolithic grid painter issued, so goldens stay
/// stable whether this painter runs standalone or composed under the
/// top-level painter.
class RangePainter extends CustomPainter {
  RangePainter(this.ctx, {this.fillHandleRect, this.chartButtonRect});

  final GridPaintContext ctx;

  /// Canvas-space rect of the active range's fill handle, computed by the
  /// owning grid so painting and hit-testing share one geometry source
  /// (quality program v3 item 10). Null hides the handle (no active range,
  /// cell selection disabled, or the range's end cell off-screen).
  final Rect? fillHandleRect;

  /// Canvas-space rect of the integrated-charts palette button, computed by
  /// the owning grid when range selection is active and charts are enabled.
  /// Null hides the button.
  final Rect? chartButtonRect;

  /// Size of the painted fill handle square (must match the hit zone used
  /// by the grid's fill-handle hit test).
  static const double fillHandleSize = 8.0;

  /// Rect painted by the most recent [paint] call (null when hidden).
  @visibleForTesting
  Rect? lastPaintedFillHandle;

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
    lastPaintedFillHandle = null;
    final ctx = this.ctx;
    final layout = ctx.buildLayout();
    final geom = ctx.geometry(
      viewportWidth: size.width,
      leftWidth: layout.leftWidth,
      rightWidth: layout.rightWidth,
    );
    final visible = ctx.visibleRowRange(size);
    final centerSectionX = geom.centerViewportLeft;
    final centerViewportWidth = geom.centerViewportWidth;

    // === Column hover highlight ===
    if (ctx.hoveredColId != null) {
      _paintColumnHoverHighlight(
        canvas,
        size,
        layout,
        geom,
        centerSectionX,
        centerViewportWidth,
      );
    }

    // === Cell range selection highlights ===
    if (ctx.cellRanges != null && ctx.cellRanges!.isNotEmpty) {
      _paintCellRanges(
        canvas,
        size,
        layout,
        geom,
        visible.first,
        visible.last,
        centerSectionX,
        centerViewportWidth,
      );
    }

    // === Fill handle (quality program v3 item 10) ===
    final handleRect = fillHandleRect;
    if (handleRect != null) {
      canvas.drawRect(
        handleRect,
        Paint()
          ..color = ctx.accentColor
          ..style = PaintingStyle.fill,
      );
      lastPaintedFillHandle = handleRect;
    }

    // === Integrated-charts palette button ===
    final buttonRect = chartButtonRect;
    if (buttonRect != null) {
      _paintChartButton(canvas, buttonRect);
    }
  }

  /// Paints the small rounded chart-palette button (a mini bar-chart glyph)
  /// anchored at the active range's leading-top corner.
  void _paintChartButton(Canvas canvas, Rect rect) {
    final accentColor = ctx.accentColor;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(3)),
      Paint()..color = accentColor,
    );

    // Three ascending bars, knocked out of the button in the surface colour.
    final glyphColor = const Color(0xFFFFFFFF).withValues(alpha: 0.9);
    final barPaint = Paint()..color = glyphColor;
    final barWidth = rect.width / 5;
    final padding = rect.width / 4;
    final innerHeight = rect.height - 2 * padding;
    final heights = [0.4, 0.7, 1.0];
    for (var i = 0; i < 3; i++) {
      final h = innerHeight * heights[i];
      canvas.drawRect(
        Rect.fromLTWH(
          rect.left + padding + i * barWidth * 1.5,
          rect.bottom - padding - h,
          barWidth,
          h,
        ),
        barPaint,
      );
    }
  }

  /// Paints a semi-transparent highlight over all visible cells in the
  /// hovered column. Covers header, floating filter, data area, and pinned
  /// rows for the column identified by the context's hovered colId.
  void _paintColumnHoverHighlight(
    Canvas canvas,
    Size size,
    ColumnLayout layout,
    RtlGeometry geom,
    double centerSectionX,
    double centerViewportWidth,
  ) {
    final ctx = this.ctx;
    final viewportHeight = size.height;

    // Determine the default column hover colour
    final hoverColor =
        ctx.theme?.columnHoverColor ??
        (ctx.theme?.accentColor ?? const Color(0xFF2196F3)).withValues(
          alpha: 0.05,
        );

    final hoverPaint = Paint()
      ..color = hoverColor
      ..style = PaintingStyle.fill;

    // Find the column in each section and paint the highlight
    _paintColumnHoverInSection(
      canvas,
      layout.leftCols,
      geom,
      GridSection.leading,
      ctx.hoveredColId!,
      hoverPaint,
      viewportHeight,
    );

    // Center section needs clipping and scroll offset
    canvas.save();
    canvas.clipRect(
      Rect.fromLTWH(centerSectionX, 0, centerViewportWidth, viewportHeight),
    );
    _paintColumnHoverInSection(
      canvas,
      layout.centerCols,
      geom,
      GridSection.center,
      ctx.hoveredColId!,
      hoverPaint,
      viewportHeight,
    );
    canvas.restore();

    _paintColumnHoverInSection(
      canvas,
      layout.rightCols,
      geom,
      GridSection.trailing,
      ctx.hoveredColId!,
      hoverPaint,
      viewportHeight,
    );
  }

  /// Paints the column hover highlight for a single section.
  void _paintColumnHoverInSection(
    Canvas canvas,
    List<ColumnLayoutEntry> cols,
    RtlGeometry geom,
    GridSection section,
    String colId,
    Paint hoverPaint,
    double viewportHeight,
  ) {
    var offset = 0.0;
    for (final entry in cols) {
      if (entry.column.effectiveColId == colId) {
        final x = ctx.colX(geom, section, offset, entry.width);
        // Paint a full-height highlight from top to bottom of the viewport
        final rect = Rect.fromLTWH(x, 0, entry.width, viewportHeight);
        canvas.drawRect(rect, hoverPaint);
        return;
      }
      offset += entry.width;
    }
  }

  /// Paints all active cell ranges as semi-transparent fill with solid
  /// border.
  ///
  /// Each range is painted per-section (leading pinned, center, trailing
  /// pinned) with appropriate clipping so the highlight respects the
  /// three-section layout.
  void _paintCellRanges(
    Canvas canvas,
    Size size,
    ColumnLayout layout,
    RtlGeometry geom,
    int firstVisibleRow,
    int lastVisibleRow,
    double centerSectionX,
    double centerViewportWidth,
  ) {
    final accentColor = ctx.accentColor;
    final fillColor = accentColor.withValues(alpha: 0.1);
    final borderColor = accentColor;

    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = borderColor
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final dataAreaTop = ctx.dataAreaTop;
    final dataAreaHeight = ctx.dataAreaHeightFor(size);

    for (final range in ctx.cellRanges!) {
      final startRow = range.normalizedStartRow;
      final endRow = range.normalizedEndRow;
      final startCol = range.normalizedStartColumn;
      final endCol = range.normalizedEndColumn;

      // Skip ranges entirely outside the visible row window
      if (endRow < firstVisibleRow || startRow > lastVisibleRow) continue;

      // Left pinned
      _paintRangeInSection(
        canvas,
        layout.leftCols,
        geom,
        GridSection.leading,
        startRow,
        endRow,
        startCol,
        endCol,
        fillPaint,
        borderPaint,
        dataAreaTop,
        dataAreaHeight,
        Rect.fromLTWH(
          geom.leadingSectionX,
          dataAreaTop,
          layout.leftWidth,
          dataAreaHeight,
        ),
      );

      // Center (scrolled)
      _paintRangeInSection(
        canvas,
        layout.centerCols,
        geom,
        GridSection.center,
        startRow,
        endRow,
        startCol,
        endCol,
        fillPaint,
        borderPaint,
        dataAreaTop,
        dataAreaHeight,
        Rect.fromLTWH(
          centerSectionX,
          dataAreaTop,
          centerViewportWidth,
          dataAreaHeight,
        ),
      );

      // Right pinned
      _paintRangeInSection(
        canvas,
        layout.rightCols,
        geom,
        GridSection.trailing,
        startRow,
        endRow,
        startCol,
        endCol,
        fillPaint,
        borderPaint,
        dataAreaTop,
        dataAreaHeight,
        Rect.fromLTWH(
          geom.trailingSectionX,
          dataAreaTop,
          layout.rightWidth,
          dataAreaHeight,
        ),
      );
    }
  }

  /// Paints the range highlight for a specific section
  /// (leading/center/trailing).
  void _paintRangeInSection(
    Canvas canvas,
    List<ColumnLayoutEntry> sectionCols,
    RtlGeometry geom,
    GridSection section,
    int startRow,
    int endRow,
    int startCol,
    int endCol,
    Paint fillPaint,
    Paint borderPaint,
    double dataAreaTop,
    double dataAreaHeight,
    Rect clipRect,
  ) {
    if (sectionCols.isEmpty) return;

    // Find the columns in this section that overlap with the range
    double? rangeLeft;
    double? rangeRight;
    var offset = 0.0;

    for (final entry in sectionCols) {
      final x = ctx.colX(geom, section, offset, entry.width);
      final colRight = x + entry.width;
      if (entry.index >= startCol && entry.index <= endCol) {
        // Under RTL the walk proceeds right-to-left, so track the true
        // min/max visual edges instead of relying on accumulation order.
        rangeLeft = rangeLeft == null ? x : math.min(rangeLeft, x);
        rangeRight = rangeRight == null
            ? colRight
            : math.max(rangeRight, colRight);
      }
      offset += entry.width;
    }

    if (rangeLeft == null || rangeRight == null) return;

    // Calculate row positions
    final rowTop =
        dataAreaTop +
        (ctx.rowHeightLayout?.getRowTop(startRow) ??
            (startRow * ctx.rowHeight)) -
        ctx.scrollY;
    final rowBottom =
        dataAreaTop +
        (ctx.rowHeightLayout?.getRowBottom(endRow) ??
            ((endRow + 1) * ctx.rowHeight)) -
        ctx.scrollY;

    // Clamp to visible data area
    final visibleTop = math.max(rowTop, dataAreaTop);
    final visibleBottom = math.min(rowBottom, dataAreaTop + dataAreaHeight);

    if (visibleTop >= visibleBottom) return;

    final rangeRect = Rect.fromLTRB(
      rangeLeft,
      visibleTop,
      rangeRight,
      visibleBottom,
    );

    // Clip to section bounds
    canvas.save();
    canvas.clipRect(clipRect);

    // Paint fill
    canvas.drawRect(rangeRect, fillPaint);

    // Paint border (only the edges that are actually visible)
    // We draw the full border rect — clipping handles section boundaries
    final fullRangeRect = Rect.fromLTRB(
      rangeLeft,
      rowTop,
      rangeRight,
      rowBottom,
    );
    canvas.drawRect(fullRangeRect, borderPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant RangePainter oldDelegate) {
    if (fillHandleRect != oldDelegate.fillHandleRect) return true;
    if (chartButtonRect != oldDelegate.chartButtonRect) return true;
    // Scroll-linked gate (quality program v3 item 7): when ONLY scrollY
    // changed among the inputs this layer consumes, repaint just when a
    // range's rows are on-screen under either scroll offset. Highlights
    // move with their rows, so ranges off-screen on BOTH sides leave every
    // painted pixel of this layer unchanged and the previous frame's raster
    // is retained.
    if (_sameExceptScrollY(oldDelegate.ctx, ctx)) {
      if (ctx.scrollY == oldDelegate.ctx.scrollY) return false;
      final size = oldDelegate.lastPaintedSize;
      if (size == null) return true;
      return _rangesIntersectVisibleBand(oldDelegate.ctx, size) ||
          _rangesIntersectVisibleBand(ctx, size);
    }
    return _shouldRepaint(ctx, oldDelegate.ctx);
  }
}

/// Whether any input consumed by the selection overlay bands changed between
/// the two contexts. Derived from `GridPaintInputs.sectionFields` keys
/// `left`/`center`/`right` restricted to the inputs whose pixels moved into
/// this painter in the split (cell ranges + column hover), plus the layout
/// geometry those rects depend on (quality program v3 item 5).
bool _shouldRepaint(GridPaintContext a, GridPaintContext b) {
  // columnWidths is rebuilt per widget build, so compare by content — an
  // identity check would flag every frame (quality program v3 item 7).
  return !identical(a.columns, b.columns) ||
      !listEquals(a.columnWidths, b.columnWidths) ||
      a.theme != b.theme ||
      a.textDirection != b.textDirection ||
      a.rowHeight != b.rowHeight ||
      a.rowHeightLayout != b.rowHeightLayout ||
      a.scrollX != b.scrollX ||
      a.scrollY != b.scrollY ||
      !identical(a.rowData, b.rowData) ||
      !listEquals(a.pinnedTopRowData, b.pinnedTopRowData) ||
      !listEquals(a.pinnedBottomRowData, b.pinnedBottomRowData) ||
      a.cellRanges != b.cellRanges ||
      a.hoveredColId != b.hoveredColId;
}

/// Whether every range-painter input EXCEPT scrollY matches between the two
/// contexts — [_shouldRepaint] minus the scrollY clause (quality program v3
/// item 7).
bool _sameExceptScrollY(GridPaintContext a, GridPaintContext b) {
  return identical(a.columns, b.columns) &&
      listEquals(a.columnWidths, b.columnWidths) &&
      a.theme == b.theme &&
      a.textDirection == b.textDirection &&
      a.rowHeight == b.rowHeight &&
      a.rowHeightLayout == b.rowHeightLayout &&
      a.scrollX == b.scrollX &&
      identical(a.rowData, b.rowData) &&
      listEquals(a.pinnedTopRowData, b.pinnedTopRowData) &&
      listEquals(a.pinnedBottomRowData, b.pinnedBottomRowData) &&
      a.cellRanges == b.cellRanges &&
      a.hoveredColId == b.hoveredColId;
}

/// Whether any cell range's row span intersects the visible row window for
/// [ctx]'s scroll offset under [size] — the same window `_paintCellRanges`
/// culls against, so a false result guarantees the scroll could not change
/// any painted pixel of this layer.
bool _rangesIntersectVisibleBand(GridPaintContext ctx, Size size) {
  final ranges = ctx.cellRanges;
  if (ranges == null || ranges.isEmpty) return false;
  final visible = ctx.visibleRowRange(size);
  for (final range in ranges) {
    if (range.normalizedEndRow >= visible.first &&
        range.normalizedStartRow <= visible.last) {
      return true;
    }
  }
  return false;
}
