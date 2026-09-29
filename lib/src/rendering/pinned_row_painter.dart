import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals, mapEquals;
import 'package:flutter/material.dart';

import '../params/cell_renderer_params.dart';
import '../params/value_formatter_params.dart';
import '../theming/os_cell_style.dart';
import '../theming/os_row_style.dart';
import 'column_layout.dart';
import 'grid_paint_context.dart';
import 'rtl_geometry.dart';
import 'special_columns.dart';

/// Per-section painter for the fixed pinned row bands (quality program v3
/// item 5).
///
/// Owns the rows pinned above the scrollable body ("pinned top") and below
/// it ("pinned bottom"), including their full-width separator strokes.
/// Pinned rows do not scroll vertically but their center-column slice scrolls
/// horizontally, so this layer repaints on horizontal — not vertical —
/// scroll.
///
/// Reads all inputs from a shared [GridPaintContext] and renders byte-for-
/// byte the same ops the monolithic grid painter issued for the pinned bands,
/// so goldens stay stable whether this painter runs standalone or composed
/// under the top-level painter.
class PinnedRowPainter extends CustomPainter {
  PinnedRowPainter(this.ctx);

  final GridPaintContext ctx;

  @override
  void paint(Canvas canvas, Size size) {
    final ctx = this.ctx;
    final viewportWidth = size.width;
    final layout = ctx.buildLayout();
    final geom = ctx.geometry(
      viewportWidth: viewportWidth,
      leftWidth: layout.leftWidth,
      rightWidth: layout.rightWidth,
    );

    final borderPaint = Paint()
      ..color = ctx.borderColor
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    final bgPaint = Paint()..color = ctx.backgroundColor;

    // === Pinned top rows (fixed above scrollable body) ===
    if (ctx.pinnedTopRowData.isNotEmpty) {
      _paintPinnedRows(
        canvas,
        layout,
        geom,
        ctx.pinnedTopRowData,
        ctx.totalHeaderHeight,
        viewportWidth,
        borderPaint,
        bgPaint,
        ctx.pinnedTopRowStyles,
      );
      // Border below pinned top rows
      final pinnedTopBottom = ctx.totalHeaderHeight + ctx.pinnedTopHeight;
      canvas.drawLine(
        Offset(0, pinnedTopBottom),
        Offset(viewportWidth, pinnedTopBottom),
        Paint()
          ..color = ctx.theme?.pinnedColumnBorderColor ?? ctx.borderColor
          ..strokeWidth = ctx.pinnedBorderWidth
          ..style = PaintingStyle.stroke,
      );
    }

    // === Pinned bottom rows (fixed below scrollable body) ===
    if (ctx.pinnedBottomRowData.isNotEmpty) {
      // Border above pinned bottom rows
      canvas.drawLine(
        Offset(0, ctx.pinnedBottomTopFor(size)),
        Offset(viewportWidth, ctx.pinnedBottomTopFor(size)),
        Paint()
          ..color = ctx.theme?.pinnedColumnBorderColor ?? ctx.borderColor
          ..strokeWidth = ctx.pinnedBorderWidth
          ..style = PaintingStyle.stroke,
      );
      _paintPinnedRows(
        canvas,
        layout,
        geom,
        ctx.pinnedBottomRowData,
        ctx.pinnedBottomTopFor(size),
        viewportWidth,
        borderPaint,
        bgPaint,
        ctx.pinnedBottomRowStyles,
      );
    }
  }

  /// Paints pinned rows (top or bottom) at a fixed vertical position.
  ///
  /// Pinned rows use the same cell rendering as body rows but are not
  /// affected by vertical scroll. They respect horizontal scroll for
  /// center columns and column pinning (left/center/right sections).
  void _paintPinnedRows(
    Canvas canvas,
    ColumnLayout layout,
    RtlGeometry geom,
    List<Map<String, dynamic>> pinnedData,
    double startY,
    double viewportWidth,
    Paint borderPaint,
    Paint bgPaint,
    Map<int, OsRowStyle>? pinnedRowStyles,
  ) {
    for (int r = 0; r < pinnedData.length; r++) {
      final rowTop = startY + (r * ctx.rowHeight);
      final rowBottom = rowTop + ctx.rowHeight;

      // Row background (pinned rows use a slightly different background to
      // visually distinguish them from body rows)
      final rowStyle = pinnedRowStyles?[r];
      if (rowStyle?.backgroundColor != null) {
        final stylePaint = Paint()..color = rowStyle!.backgroundColor!;
        canvas.drawRect(
          Rect.fromLTRB(0, rowTop, viewportWidth, rowBottom),
          stylePaint,
        );
      } else {
        // Use the standard background for pinned rows
        canvas.drawRect(
          Rect.fromLTRB(0, rowTop, viewportWidth, rowBottom),
          bgPaint,
        );
      }

      // Paint center columns (scrolled)
      canvas.save();
      canvas.clipRect(
        Rect.fromLTWH(
          geom.centerViewportLeft,
          rowTop,
          geom.centerViewportWidth,
          ctx.rowHeight,
        ),
      );
      _paintPinnedRowCells(
        canvas,
        layout.centerCols,
        geom,
        GridSection.center,
        rowTop,
        rowBottom,
        pinnedData[r],
        r,
        borderPaint,
        pinnedRowStyles,
      );
      canvas.restore();

      // Paint leading pinned columns (fixed)
      if (layout.leftCols.isNotEmpty) {
        canvas.save();
        canvas.clipRect(
          Rect.fromLTWH(
            geom.leadingSectionX,
            rowTop,
            layout.leftWidth,
            ctx.rowHeight,
          ),
        );
        // Background to cover center bleed
        canvas.drawRect(
          Rect.fromLTWH(
            geom.leadingSectionX,
            rowTop,
            layout.leftWidth,
            ctx.rowHeight,
          ),
          bgPaint,
        );
        if (rowStyle?.backgroundColor != null) {
          canvas.drawRect(
            Rect.fromLTWH(
              geom.leadingSectionX,
              rowTop,
              layout.leftWidth,
              ctx.rowHeight,
            ),
            Paint()..color = rowStyle!.backgroundColor!,
          );
        }
        _paintPinnedRowCells(
          canvas,
          layout.leftCols,
          geom,
          GridSection.leading,
          rowTop,
          rowBottom,
          pinnedData[r],
          r,
          borderPaint,
          pinnedRowStyles,
        );
        canvas.restore();
      }

      // Paint trailing pinned columns (fixed)
      if (layout.rightCols.isNotEmpty) {
        canvas.save();
        canvas.clipRect(
          Rect.fromLTWH(
            geom.trailingSectionX,
            rowTop,
            layout.rightWidth,
            ctx.rowHeight,
          ),
        );
        // Background to cover center bleed
        canvas.drawRect(
          Rect.fromLTWH(
            geom.trailingSectionX,
            rowTop,
            layout.rightWidth,
            ctx.rowHeight,
          ),
          bgPaint,
        );
        if (rowStyle?.backgroundColor != null) {
          canvas.drawRect(
            Rect.fromLTWH(
              geom.trailingSectionX,
              rowTop,
              layout.rightWidth,
              ctx.rowHeight,
            ),
            Paint()..color = rowStyle!.backgroundColor!,
          );
        }
        _paintPinnedRowCells(
          canvas,
          layout.rightCols,
          geom,
          GridSection.trailing,
          rowTop,
          rowBottom,
          pinnedData[r],
          r,
          borderPaint,
          pinnedRowStyles,
        );
        canvas.restore();
      }

      // Row bottom border
      canvas.drawLine(
        Offset(0, rowBottom),
        Offset(viewportWidth, rowBottom),
        borderPaint,
      );
    }
  }

  /// Paints cells for a single pinned row across the given column entries.
  void _paintPinnedRowCells(
    Canvas canvas,
    List<ColumnLayoutEntry> cols,
    RtlGeometry geom,
    GridSection section,
    double rowTop,
    double rowBottom,
    Map<String, dynamic> rowData_,
    int rowIndex,
    Paint borderPaint,
    Map<int, OsRowStyle>? pinnedRowStyles,
  ) {
    var contentOffset = 0.0;
    for (final entry in cols) {
      final colWidth = entry.width;
      final cellLeft = ctx.colX(geom, section, contentOffset, colWidth);
      final cellRight = cellLeft + colWidth;

      // Get cell value
      final field = entry.column.field;
      final value = field != null ? rowData_[field] : '';

      // Special columns render as empty in pinned rows
      if (field == SpecialColumns.checkbox ||
          entry.column.checkboxSelection == true ||
          field == SpecialColumns.rowNumber ||
          field == SpecialColumns.rowDrag) {
        canvas.drawLine(
          Offset(cellRight, rowTop),
          Offset(cellRight, rowBottom),
          borderPaint,
        );
        contentOffset += colWidth;
        continue;
      }

      // Apply value formatter if present
      String displayText;
      if (entry.column.valueFormatter != null) {
        displayText = entry.column.valueFormatter!(
          ValueFormatterParams(value: value, rowIndex: rowIndex),
        );
      } else {
        displayText = value?.toString() ?? '';
      }

      // Paint cell text
      // Access cellStyle via dynamic to avoid covariant generic type error
      final dynamic colDynamic2 = entry.column;
      final cellStyleFn2 = colDynamic2.cellStyle as Function?;
      final cellStyle = cellStyleFn2 != null
          ? cellStyleFn2(
                  CellRendererParams(
                    value: value,
                    data: rowData_,
                    rowIndex: rowIndex,
                    colDef: entry.column,
                  ),
                )
                as OsCellStyle?
          : null;

      final rowStyle = pinnedRowStyles?[rowIndex];

      final tp = ctx.layoutText(
        TextSpan(
          text: displayText,
          style: ctx.cellTextStyle.copyWith(
            color: cellStyle?.color ?? rowStyle?.foregroundColor,
            fontWeight:
                cellStyle?.fontWeight ??
                rowStyle?.fontWeight ??
                FontWeight.w600,
            fontStyle: cellStyle?.fontStyle ?? rowStyle?.fontStyle,
          ),
        ),
        ellipsis: '\u2026',
        maxWidth: math.max(0, colWidth - GridPaintContext.cellPaddingH * 2),
      );
      // Text hugs the reading-direction leading edge of the cell.
      final textX = geom.isRtl
          ? cellRight - GridPaintContext.cellPaddingH - tp.width
          : cellLeft + GridPaintContext.cellPaddingH;
      tp.paint(canvas, Offset(textX, rowTop + (ctx.rowHeight - tp.height) / 2));

      // Cell right border
      canvas.drawLine(
        Offset(cellRight, rowTop),
        Offset(cellRight, rowBottom),
        borderPaint,
      );

      contentOffset += colWidth;
    }
  }

  @override
  bool shouldRepaint(covariant PinnedRowPainter oldDelegate) {
    return _shouldRepaint(ctx, oldDelegate.ctx);
  }
}

/// Whether any input consumed by the pinned row bands changed between the two
/// contexts. Field set mirrors `GridPaintInputs.sectionFields` keys
/// `pinnedTop`/`footer` plus `scrollX`, which the registry omitted although
/// the center-column slice of pinned rows scrolls horizontally (quality
/// program v3 item 5): pure vertical scrolling skips this layer entirely.
bool _shouldRepaint(GridPaintContext a, GridPaintContext b) {
  // columnWidths is rebuilt per widget build, so compare by content — an
  // identity check would flag every frame (quality program v3 item 7).
  return !identical(a.columns, b.columns) ||
      !listEquals(a.columnWidths, b.columnWidths) ||
      a.theme != b.theme ||
      a.textDirection != b.textDirection ||
      a.textScaler.scale(16) != b.textScaler.scale(16) ||
      a.rowHeight != b.rowHeight ||
      a.scrollX != b.scrollX ||
      !listEquals(a.pinnedTopRowData, b.pinnedTopRowData) ||
      !listEquals(a.pinnedBottomRowData, b.pinnedBottomRowData) ||
      !mapEquals(a.pinnedTopRowStyles, b.pinnedTopRowStyles) ||
      !mapEquals(a.pinnedBottomRowStyles, b.pinnedBottomRowStyles);
}
