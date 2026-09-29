import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import 'grid_paint_context.dart';

/// Per-section painter for the scrollbars (quality program v3 item 5).
///
/// Owns the vertical and horizontal scrollbar tracks and thumbs — the
/// topmost band of the grid's draw order. Geometry mirrors the hit-test
/// maths in `VirtualisedGrid` so thumbs are exactly where they can be
/// grabbed, including pinned-row offsets.
///
/// Reads all inputs from a shared [GridPaintContext] and renders byte-for-
/// byte the same ops the monolithic grid painter issued, so goldens stay
/// stable whether this painter runs standalone or composed under the
/// top-level painter.
class ScrollbarPainter extends CustomPainter {
  ScrollbarPainter(this.ctx);

  final GridPaintContext ctx;

  /// Stroke thickness of both scrollbar tracks/thumbs.
  static const double _scrollbarThickness = 8.0;

  /// Minimum thumb length so tiny viewports stay grabbable.
  static const double _scrollbarMinThumbLength = 30.0;

  @override
  void paint(Canvas canvas, Size size) {
    final ctx = this.ctx;
    final viewportWidth = size.width;
    final viewportHeight = size.height;
    // Match the hit-test math in VirtualisedGrid so thumbs are exactly
    // where they can be grabbed, including pinned-row offsets.
    final dataAreaHeight = ctx.dataAreaHeightFor(size);

    final totalContentHeight =
        ctx.rowHeightLayout?.totalHeight ??
        (ctx.rowData.length * ctx.rowHeight);
    // Only center columns scroll horizontally
    final layout = ctx.buildLayout();
    final totalScrollableWidth = layout.centerWidth;
    final centerViewportWidth =
        viewportWidth - layout.leftWidth - layout.rightWidth;

    final scrollbarColor = const Color(0xFF9E9E9E).withValues(alpha: 0.5);
    final scrollbarTrackColor = const Color(0xFFE0E0E0).withValues(alpha: 0.3);
    final thumbPaint = Paint()..color = scrollbarColor;
    final trackPaint = Paint()..color = scrollbarTrackColor;

    // Vertical scrollbar
    if (totalContentHeight > dataAreaHeight) {
      final trackTop = ctx.dataAreaTop;
      final trackHeight = dataAreaHeight - _scrollbarThickness;
      final thumbRatio = dataAreaHeight / totalContentHeight;
      final thumbHeight = math.max(
        _scrollbarMinThumbLength,
        trackHeight * thumbRatio,
      );
      final maxScrollY = totalContentHeight - dataAreaHeight;
      final thumbTop =
          trackTop + (ctx.scrollY / maxScrollY) * (trackHeight - thumbHeight);

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            viewportWidth - _scrollbarThickness,
            trackTop,
            _scrollbarThickness,
            trackHeight,
          ),
          const Radius.circular(4),
        ),
        trackPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            viewportWidth - _scrollbarThickness,
            thumbTop,
            _scrollbarThickness,
            thumbHeight,
          ),
          const Radius.circular(4),
        ),
        thumbPaint,
      );
    }

    // Horizontal scrollbar (only for center section)
    if (totalScrollableWidth > centerViewportWidth) {
      final geom = ctx.geometry(
        viewportWidth: viewportWidth,
        leftWidth: layout.leftWidth,
        rightWidth: layout.rightWidth,
      );
      final trackLeft = layout.leftWidth;
      final trackWidth = centerViewportWidth - _scrollbarThickness;
      final thumbRatio = centerViewportWidth / totalScrollableWidth;
      final thumbWidth = math.max(
        _scrollbarMinThumbLength,
        trackWidth * thumbRatio,
      );
      final maxScrollX = totalScrollableWidth - centerViewportWidth;
      final scrollRatio = maxScrollX > 0 ? ctx.scrollX / maxScrollX : 0.0;
      final thumbLeft = geom.horizontalThumbLeft(
        trackLeft: trackLeft,
        trackWidth: trackWidth,
        thumbWidth: thumbWidth,
        scrollRatio: scrollRatio.clamp(0.0, 1.0),
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            trackLeft,
            viewportHeight - _scrollbarThickness,
            trackWidth,
            _scrollbarThickness,
          ),
          const Radius.circular(4),
        ),
        trackPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            thumbLeft,
            viewportHeight - _scrollbarThickness,
            thumbWidth,
            _scrollbarThickness,
          ),
          const Radius.circular(4),
        ),
        thumbPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant ScrollbarPainter oldDelegate) {
    return _shouldRepaint(ctx, oldDelegate.ctx);
  }
}

/// Whether any input consumed by the scrollbar geometry changed between the
/// two contexts: scroll offsets, the column layout driving content/viewport
/// extents, and the row-mass inputs behind the content height. Colours are
/// hardcoded constants, so theme changes do not invalidate this layer
/// (quality program v3 item 5).
bool _shouldRepaint(GridPaintContext a, GridPaintContext b) {
  // columnWidths is rebuilt per widget build, so compare by content — an
  // identity check would flag every frame (quality program v3 item 7).
  return !identical(a.columns, b.columns) ||
      !listEquals(a.columnWidths, b.columnWidths) ||
      a.rowHeight != b.rowHeight ||
      a.rowHeightLayout != b.rowHeightLayout ||
      a.scrollX != b.scrollX ||
      a.scrollY != b.scrollY ||
      !identical(a.rowData, b.rowData) ||
      !listEquals(a.pinnedTopRowData, b.pinnedTopRowData) ||
      !listEquals(a.pinnedBottomRowData, b.pinnedBottomRowData);
}
