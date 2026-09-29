import 'dart:async' show scheduleMicrotask;
import 'dart:math' as math;
import 'dart:ui' as ui show Image;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import '../columns/os_column_def.dart';
import '../editing/os_checkbox_cell_editor.dart';
import '../params/cell_renderer_params.dart';
import '../params/value_formatter_params.dart';
import '../row_grouping/row_group_service.dart' show RowGroupKeys;
import '../theming/os_cell_style.dart';
import '../theming/os_grid_theme.dart';
import '../theming/resolved_grid_theme.dart';
import 'avatar_options.dart';
import 'column_layout.dart';
import 'grid_paint_context.dart';
import 'grid_painter.dart';
import 'image_cell_cache.dart';
import 'image_options.dart';
import 'master_detail.dart';
import 'progress_bar_options.dart';
import 'raster_glyph_cache.dart';
import 'rtl_geometry.dart';
import 'sparkline_options.dart';
import 'special_columns.dart';

/// Per-section painter for the scrollable body of the grid (quality program
/// v3 item 5).
///
/// Owns every pixel of the data area: canvas background, the three column
/// sections' backgrounds, virtualised data rows, group rows, and cell content
/// rendering — values, formatters, built-in renderers (checkbox, star rating,
/// sparkline, animate-show-change), selection/hover row highlighting, cell
/// spans, and the shared checkbox/drag-handle glyph primitives consumed by
/// both body cells and the header painter's checkbox-selection cell.
///
/// Reads all inputs from a shared [GridPaintContext] and renders byte-for-
/// byte the same ops the monolithic grid painter issued for the body bands,
/// so goldens stay stable whether this painter runs standalone or composed.
///
/// Extends [GridPainter] (via the internal `layered` factory) so the widget's
/// bottom band remains an instance of the public entry type — semantics
/// builder, input fields, and test instrumentation all keep working unchanged
/// — while its paint pass covers only the body band.
class BodyPainter extends GridPainter {
  BodyPainter(this.ctx) : super.layered(ctx);

  final GridPaintContext ctx;

  @override
  void paint(Canvas canvas, Size size) {
    final ctx = this.ctx;
    final viewportWidth = size.width;
    final viewportHeight = size.height;
    final layout = ctx.buildLayout();
    final geom = ctx.geometry(
      viewportWidth: viewportWidth,
      leftWidth: layout.leftWidth,
      rightWidth: layout.rightWidth,
    );

    final bgColor = ctx.backgroundColor;
    final bgPaint = Paint()..color = bgColor;
    final borderPaint = Paint()
      ..color = ctx.borderColor
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    final alternateBgPaint = Paint()..color = ctx.alternateRowColor;

    // --- Background ---
    canvas.drawRect(Offset.zero & size, bgPaint);

    // --- Determine visible rows ---
    final visible = ctx.visibleRowRange(size);
    final dataAreaTop = ctx.dataAreaTop;
    final dataAreaHeight = ctx.dataAreaHeightFor(size);

    // --- Compute section X offsets (directional via [geom]) ---
    final centerSectionX = geom.centerViewportLeft;
    final centerViewportWidth = geom.centerViewportWidth;

    // === PASS 1: Paint center (scrollable) section ===
    canvas.save();
    canvas.clipRect(
      Rect.fromLTWH(centerSectionX, 0, centerViewportWidth, viewportHeight),
    );

    // Visible column range for center section (column virtualisation)
    final visibleColRange = ctx.visibleColumnRange(layout, centerViewportWidth);
    final indentAnchorColIndex = _firstContentColumnIndex(layout);

    // Center data rows
    canvas.save();
    canvas.clipRect(
      Rect.fromLTWH(
        centerSectionX,
        dataAreaTop,
        centerViewportWidth,
        dataAreaHeight,
      ),
    );
    _paintDataRows(
      canvas,
      layout.centerCols,
      geom,
      GridSection.center,
      visible.first,
      visible.last,
      viewportWidth,
      viewportHeight,
      borderPaint,
      alternateBgPaint,
      dataAreaTop: dataAreaTop,
      visibleColRange: visibleColRange,
      indentAnchorColIndex: indentAnchorColIndex,
    );
    canvas.restore();

    canvas.restore(); // end center clip

    // === PASS 2: Paint leading pinned section ===
    if (layout.leftCols.isNotEmpty) {
      // Paint solid background first to cover any center section bleed
      canvas.drawRect(
        Rect.fromLTWH(
          geom.leadingSectionX,
          0,
          layout.leftWidth,
          viewportHeight,
        ),
        bgPaint,
      );

      canvas.save();
      canvas.clipRect(
        Rect.fromLTWH(
          geom.leadingSectionX,
          0,
          layout.leftWidth,
          viewportHeight,
        ),
      );

      // Left data rows
      canvas.save();
      canvas.clipRect(
        Rect.fromLTWH(
          geom.leadingSectionX,
          dataAreaTop,
          layout.leftWidth,
          dataAreaHeight,
        ),
      );
      _paintDataRows(
        canvas,
        layout.leftCols,
        geom,
        GridSection.leading,
        visible.first,
        visible.last,
        viewportWidth,
        viewportHeight,
        borderPaint,
        alternateBgPaint,
        dataAreaTop: dataAreaTop,
        indentAnchorColIndex: indentAnchorColIndex,
      );
      canvas.restore();

      canvas.restore(); // end left clip
    }

    // === PASS 3: Paint trailing pinned section ===
    if (layout.rightCols.isNotEmpty) {
      // Paint solid background first to cover any center section bleed
      canvas.drawRect(
        Rect.fromLTWH(
          geom.trailingSectionX,
          0,
          layout.rightWidth,
          viewportHeight,
        ),
        bgPaint,
      );

      canvas.save();
      canvas.clipRect(
        Rect.fromLTWH(
          geom.trailingSectionX,
          0,
          layout.rightWidth,
          viewportHeight,
        ),
      );

      // Right data rows
      canvas.save();
      canvas.clipRect(
        Rect.fromLTWH(
          geom.trailingSectionX,
          dataAreaTop,
          layout.rightWidth,
          dataAreaHeight,
        ),
      );
      _paintDataRows(
        canvas,
        layout.rightCols,
        geom,
        GridSection.trailing,
        visible.first,
        visible.last,
        viewportWidth,
        viewportHeight,
        borderPaint,
        alternateBgPaint,
        dataAreaTop: dataAreaTop,
        indentAnchorColIndex: indentAnchorColIndex,
      );
      canvas.restore();

      canvas.restore(); // end right clip
    }

    _scheduleValuePrefetch(ctx, visible, viewportHeight);
  }

  /// Schedules the idle-time value prefetch (quality program v3 item 50).
  ///
  /// After the main paint completes for the current frame, a microtask
  /// invokes the context's prefetch hook (installed by the grid widget when
  /// `prefetchEnabled` is set) with the visible row window, so the host can
  /// pre-compute valueGetter results for the next viewport-height worth of
  /// rows in the scroll direction, warming the ValueCache. The frame-local
  /// inputs are captured before the microtask runs — this painter and its
  /// context are rebuilt per frame.
  void _scheduleValuePrefetch(
    GridPaintContext ctx,
    ({int first, int last}) visible,
    double viewportHeight,
  ) {
    final prefetch = ctx.valuePrefetch;
    if (prefetch == null) return;
    final firstVisibleRow = visible.first;
    final lastVisibleRow = visible.last;
    final scrollY = ctx.scrollY;
    scheduleMicrotask(
      () => prefetch(
        scrollY: scrollY,
        viewportHeight: viewportHeight,
        firstVisibleRow: firstVisibleRow,
        lastVisibleRow: lastVisibleRow,
      ),
    );
  }

  // --- Data row painting ---

  /// The original column index of the row's first content cell in reading
  /// order (leading pinned -> center -> trailing pinned), skipping special
  /// columns that never carry the tree indent. Null when every column is
  /// special. Computed once per paint; identical for every row.
  int? _firstContentColumnIndex(ColumnLayout layout) {
    for (final cols in [layout.leftCols, layout.centerCols, layout.rightCols]) {
      for (final entry in cols) {
        final field = entry.column.field;
        final isSpecial =
            field == null ||
            field == SpecialColumns.rowNumber ||
            field == SpecialColumns.checkbox ||
            field == SpecialColumns.rowDrag ||
            entry.column.checkboxSelection == true;
        if (!isSpecial) return entry.index;
      }
    }
    return null;
  }

  void _paintDataRows(
    Canvas canvas,
    List<ColumnLayoutEntry> cols,
    RtlGeometry geom,
    GridSection section,
    int firstVisibleRow,
    int lastVisibleRow,
    double viewportWidth,
    double viewportHeight,
    Paint borderPaint,
    Paint alternateBgPaint, {
    double? dataAreaTop,
    ({int first, int last})? visibleColRange,
    required int? indentAnchorColIndex,
  }) {
    final ctx = this.ctx;
    final effectiveDataAreaTop = dataAreaTop ?? ctx.totalHeaderHeight;

    // Theme cascade: resolve per-column cell styles once per paint pass
    // (base theme → column type theme → colDef overrides), indexed like
    // [cols] so each cell below picks its column theme in O(1).
    final columnThemes = <ResolvedColumnTheme>[
      for (final entry in cols)
        ResolvedGridTheme.forColumn(entry.column, ctx.theme),
    ];

    for (
      int r = firstVisibleRow;
      r <= lastVisibleRow && r < ctx.rowData.length;
      r++
    ) {
      final currentRowHeight =
          ctx.rowHeightLayout?.getRowHeight(r) ?? ctx.rowHeight;
      final rowTopOffset =
          ctx.rowHeightLayout?.getRowTop(r) ?? (r * ctx.rowHeight);
      final rowTop = effectiveDataAreaTop + rowTopOffset - ctx.scrollY;
      final rowBottom = rowTop + currentRowHeight;

      if (rowBottom < effectiveDataAreaTop) continue;
      if (rowTop > viewportHeight) break;

      // Row background: selected > hovered > getRowStyle > rowStyle > alternate
      if (ctx.selectedRows.contains(r)) {
        final selectedPaint = Paint()
          ..color = ctx.theme?.selectedRowColor ?? const Color(0xFFE3F2FD);
        canvas.drawRect(
          Rect.fromLTRB(0, rowTop, viewportWidth, rowBottom),
          selectedPaint,
        );
      } else if (ctx.hoveredRow == r) {
        final hoverPaint = Paint()
          ..color = ctx.theme?.hoverRowColor ?? const Color(0xFFF5F5F5);
        canvas.drawRect(
          Rect.fromLTRB(0, rowTop, viewportWidth, rowBottom),
          hoverPaint,
        );
      } else {
        final rowStyle = ctx.rowStyles?[r];
        if (rowStyle?.backgroundColor != null) {
          final stylePaint = Paint()..color = rowStyle!.backgroundColor!;
          canvas.drawRect(
            Rect.fromLTRB(0, rowTop, viewportWidth, rowBottom),
            stylePaint,
          );
        } else if (r.isOdd) {
          canvas.drawRect(
            Rect.fromLTRB(0, rowTop, viewportWidth, rowBottom),
            alternateBgPaint,
          );
        }
      }

      // --- Group row rendering: full-width row with chevron + label ---
      if (ctx.rowData[r]['__isGroupRow'] == true) {
        _paintGroupRow(
          canvas,
          ctx.rowData[r],
          rowTop,
          rowBottom,
          viewportWidth,
          cols: cols,
          geom: geom,
          section: section,
        );
        // Draw bottom border for the group row
        canvas.drawLine(
          Offset(0, rowBottom),
          Offset(viewportWidth, rowBottom),
          borderPaint,
        );
        continue; // Skip individual cell painting for group rows
      }

      // --- Master/detail detail row: themed placeholder band ---
      // The actual detail widget content is rendered by VirtualisedGrid as
      // an overlay child above the canvas; the painter reserves the band.
      if (ctx.rowData[r][MasterDetailKeys.isDetailRow] == true) {
        _paintDetailRow(canvas, rowTop, rowBottom, viewportWidth, borderPaint);
        continue; // Skip individual cell painting for detail rows
      }

      // Paint cells in this section
      var contentOffset = 0.0;
      for (int colIdx = 0; colIdx < cols.length; colIdx++) {
        final entry = cols[colIdx];
        final colWidth = entry.width;
        final colId = entry.column.effectiveColId;

        // Column virtualisation: skip columns outside visible range.
        // However, if cell spans are active, a span may start in a visible
        // column and extend into off-screen columns, so we must still track
        // the content offset for correct positioning but can skip painting.
        if (visibleColRange != null &&
            (colIdx < visibleColRange.first || colIdx > visibleColRange.last)) {
          contentOffset += colWidth;
          continue;
        }

        // --- Row span: skip cells consumed by a span above ---
        if (ctx.cellSpanService != null &&
            ctx.cellSpanService!.isConsumedByRowSpan(r, colId)) {
          contentOffset += colWidth;
          continue;
        }

        // --- Col span: extend cell width across multiple columns ---
        int colSpanCount = 1;
        double effectiveColWidth = colWidth;
        if (ctx.cellSpanService != null) {
          colSpanCount = ctx.cellSpanService!.getColSpan(
            column: entry.column,
            rowData: ctx.rowData[r],
            rowIndex: r,
          );
          if (colSpanCount > 1) {
            // Sum widths of spanned columns
            for (
              int s = 1;
              s < colSpanCount && (colIdx + s) < cols.length;
              s++
            ) {
              effectiveColWidth += cols[colIdx + s].width;
            }
          }
        }

        // --- Row span: extend cell height if this is the head ---
        double effectiveRowHeight = currentRowHeight;
        double effectiveRowBottom = rowTop + currentRowHeight;
        if (ctx.cellSpanService != null) {
          final spanCount = ctx.cellSpanService!.getRowSpanCount(r, colId);
          if (spanCount > 1) {
            // Sum heights of spanned rows
            double spanHeight = currentRowHeight;
            for (
              int s = 1;
              s < spanCount && (r + s) < ctx.rowData.length;
              s++
            ) {
              spanHeight +=
                  ctx.rowHeightLayout?.getRowHeight(r + s) ?? ctx.rowHeight;
            }
            effectiveRowHeight = spanHeight;
            effectiveRowBottom = rowTop + effectiveRowHeight;
          }
        }

        final cellLeft = ctx.colX(
          geom,
          section,
          contentOffset,
          effectiveColWidth,
        );
        final cellRight = cellLeft + effectiveColWidth;

        // Leaf-row tree indent (AG Grid parity): display rows stamped with
        // RowGroupKeys.kRowDepth shift their first content cell's CONTENT
        // one hierarchy level in — borders and backgrounds stay put. The
        // width shrinks by the same amount so leading-edge-hugging content
        // (text, renderers) lands at the indented position in LTR and RTL
        // alike. No-op for every non-anchor cell (leafIndent == 0).
        final leafDepth = (ctx.rowData[r][RowGroupKeys.kRowDepth] as int?) ?? 0;
        final leafIndent = leafDepth > 0 && entry.index == indentAnchorColIndex
            ? leafDepth * 28.0 + 12.0
            : 0.0;
        final contentLeft = geom.isRtl ? cellLeft : cellLeft + leafIndent;
        final contentWidth = effectiveColWidth - leafIndent;

        // Get cell value
        final field = entry.column.field;
        final value = field != null ? ctx.rowData[r][field] : '';

        // Special rendering for checkbox column
        if (field == SpecialColumns.checkbox ||
            entry.column.checkboxSelection == true) {
          final isSyntheticCheckbox = field == SpecialColumns.checkbox;
          // Synthetic cells carry the resolved tri-state under
          // SpecialColumns.checkbox — the key is omitted entirely when the
          // checkbox is hidden for that row. Flagged data columns fall back
          // to their own boolean cell value; anything else paints nothing.
          final hasCheckboxCell =
              !isSyntheticCheckbox ||
              ctx.rowData[r].containsKey(SpecialColumns.checkbox);
          if (hasCheckboxCell) {
            if (value == true) {
              paintCheckbox(
                canvas,
                contentLeft,
                rowTop,
                contentWidth,
                effectiveRowHeight,
                true,
                theme: ctx.theme,
              );
            } else if (value == false) {
              paintCheckbox(
                canvas,
                contentLeft,
                rowTop,
                contentWidth,
                effectiveRowHeight,
                false,
                theme: ctx.theme,
              );
            } else if (isSyntheticCheckbox) {
              // Explicit null — the row is not selectable.
              paintDisabledCheckbox(
                canvas,
                contentLeft,
                rowTop,
                contentWidth,
                effectiveRowHeight,
                theme: ctx.theme,
              );
            }
          }
          canvas.drawLine(
            Offset(cellRight, rowTop),
            Offset(cellRight, effectiveRowBottom),
            borderPaint,
          );
          contentOffset += effectiveColWidth;
          if (colSpanCount > 1) colIdx += colSpanCount - 1;
          continue;
        }

        // Special rendering for row drag handle column
        if (field == SpecialColumns.rowDrag) {
          _paintRowDragHandle(
            canvas,
            contentLeft,
            rowTop,
            contentWidth,
            effectiveRowHeight,
          );
          canvas.drawLine(
            Offset(cellRight, rowTop),
            Offset(cellRight, effectiveRowBottom),
            borderPaint,
          );
          contentOffset += effectiveColWidth;
          if (colSpanCount > 1) colIdx += colSpanCount - 1;
          continue;
        }

        // Checkbox cell editor — render checkbox directly in cell
        if (entry.column.cellEditor is OsCheckboxCellEditor) {
          final boolValue = value == true
              ? true
              : value == false
              ? false
              : null;
          if (boolValue == true) {
            paintCheckbox(
              canvas,
              contentLeft,
              rowTop,
              contentWidth,
              effectiveRowHeight,
              true,
              theme: ctx.theme,
            );
          } else if (boolValue == false) {
            paintCheckbox(
              canvas,
              contentLeft,
              rowTop,
              contentWidth,
              effectiveRowHeight,
              false,
              theme: ctx.theme,
            );
          } else {
            // null/indeterminate state
            paintIndeterminateCheckbox(
              canvas,
              contentLeft,
              rowTop,
              contentWidth,
              effectiveRowHeight,
              theme: ctx.theme,
            );
          }
          canvas.drawLine(
            Offset(cellRight, rowTop),
            Offset(cellRight, effectiveRowBottom),
            borderPaint,
          );
          contentOffset += effectiveColWidth;
          if (colSpanCount > 1) colIdx += colSpanCount - 1;
          continue;
        }

        // Built-in animate-show-change renderer
        if (entry.column.builtInCellRenderer ==
            OsBuiltInCellRenderer.animateShowChange) {
          final delta = field != null ? ctx.rowData[r]['__delta_$field'] : null;
          _paintAnimateShowChange(
            canvas,
            contentLeft,
            rowTop,
            contentWidth,
            effectiveRowHeight,
            value,
            delta,
            isRtl: geom.isRtl,
          );
          canvas.drawLine(
            Offset(cellRight, rowTop),
            Offset(cellRight, effectiveRowBottom),
            borderPaint,
          );
          contentOffset += effectiveColWidth;
          if (colSpanCount > 1) colIdx += colSpanCount - 1;
          continue;
        }

        // Built-in star rating renderer
        if (entry.column.builtInCellRenderer ==
            OsBuiltInCellRenderer.starRating) {
          _paintStarRating(
            canvas,
            contentLeft,
            rowTop,
            contentWidth,
            effectiveRowHeight,
            value,
            isRtl: geom.isRtl,
          );
          canvas.drawLine(
            Offset(cellRight, rowTop),
            Offset(cellRight, effectiveRowBottom),
            borderPaint,
          );
          contentOffset += effectiveColWidth;
          if (colSpanCount > 1) colIdx += colSpanCount - 1;
          continue;
        }

        // Built-in checkbox renderer (read-only display)
        if (entry.column.builtInCellRenderer ==
            OsBuiltInCellRenderer.checkbox) {
          final boolValue = value == true
              ? true
              : value == false
              ? false
              : null;
          if (boolValue == true) {
            paintCheckbox(
              canvas,
              contentLeft,
              rowTop,
              contentWidth,
              effectiveRowHeight,
              true,
              theme: ctx.theme,
            );
          } else if (boolValue == false) {
            paintCheckbox(
              canvas,
              contentLeft,
              rowTop,
              contentWidth,
              effectiveRowHeight,
              false,
              theme: ctx.theme,
            );
          } else {
            paintIndeterminateCheckbox(
              canvas,
              contentLeft,
              rowTop,
              contentWidth,
              effectiveRowHeight,
              theme: ctx.theme,
            );
          }
          canvas.drawLine(
            Offset(cellRight, rowTop),
            Offset(cellRight, effectiveRowBottom),
            borderPaint,
          );
          contentOffset += effectiveColWidth;
          if (colSpanCount > 1) colIdx += colSpanCount - 1;
          continue;
        }

        // Built-in sparkline renderer
        if (entry.column.builtInCellRenderer ==
            OsBuiltInCellRenderer.sparkline) {
          _paintSparkline(
            canvas,
            contentLeft,
            rowTop,
            contentWidth,
            effectiveRowHeight,
            value,
            entry.column.sparklineOptions,
          );
          canvas.drawLine(
            Offset(cellRight, rowTop),
            Offset(cellRight, effectiveRowBottom),
            borderPaint,
          );
          contentOffset += effectiveColWidth;
          if (colSpanCount > 1) colIdx += colSpanCount - 1;
          continue;
        }

        // Built-in progress bar renderer
        if (entry.column.builtInCellRenderer ==
            OsBuiltInCellRenderer.progressBar) {
          _paintProgressBar(
            canvas,
            contentLeft,
            rowTop,
            contentWidth,
            effectiveRowHeight,
            value,
            entry.column.progressBarOptions,
            isRtl: geom.isRtl,
          );
          canvas.drawLine(
            Offset(cellRight, rowTop),
            Offset(cellRight, effectiveRowBottom),
            borderPaint,
          );
          contentOffset += effectiveColWidth;
          if (colSpanCount > 1) colIdx += colSpanCount - 1;
          continue;
        }

        // Built-in avatar renderer
        if (entry.column.builtInCellRenderer == OsBuiltInCellRenderer.avatar) {
          _paintAvatar(
            canvas,
            contentLeft,
            rowTop,
            contentWidth,
            effectiveRowHeight,
            ctx.rowData[r],
            value,
            entry.column.avatarOptions,
            isRtl: geom.isRtl,
          );
          canvas.drawLine(
            Offset(cellRight, rowTop),
            Offset(cellRight, effectiveRowBottom),
            borderPaint,
          );
          contentOffset += effectiveColWidth;
          if (colSpanCount > 1) colIdx += colSpanCount - 1;
          continue;
        }

        // Built-in image renderer
        if (entry.column.builtInCellRenderer == OsBuiltInCellRenderer.image) {
          _paintImage(
            canvas,
            contentLeft,
            rowTop,
            contentWidth,
            effectiveRowHeight,
            value,
            entry.column.imageOptions,
            colId: colId,
            data: ctx.rowData[r],
            rowIndex: r,
            colDef: entry.column,
          );
          canvas.drawLine(
            Offset(cellRight, rowTop),
            Offset(cellRight, effectiveRowBottom),
            borderPaint,
          );
          contentOffset += effectiveColWidth;
          if (colSpanCount > 1) colIdx += colSpanCount - 1;
          continue;
        }

        // Apply value formatter if present
        String displayText;
        if (entry.column.valueFormatter != null) {
          displayText = entry.column.valueFormatter!(
            ValueFormatterParams(value: value, rowIndex: r),
          );
        } else {
          displayText = value?.toString() ?? '';
        }

        // Paint cell text
        // Access cellStyle via dynamic to avoid covariant generic type error
        // when OsColumnDef<TData> is accessed through a OsColumnDef (dynamic)
        // reference.
        final dynamic colDynamic = entry.column;
        final cellStyleFn = colDynamic.cellStyle as Function?;
        final cellStyle = cellStyleFn != null
            ? cellStyleFn(
                    CellRendererParams(
                      value: value,
                      data: ctx.rowData[r],
                      rowIndex: r,
                      colDef: entry.column,
                    ),
                  )
                  as OsCellStyle?
            : null;

        // Row style provides defaults; cell style overrides row style.
        final rowStyle = ctx.rowStyles?[r];
        final columnTheme = columnThemes[colIdx];

        // For row-spanning cells, paint a background to cover rows beneath
        if (effectiveRowHeight > ctx.rowHeight) {
          canvas.drawRect(
            Rect.fromLTRB(cellLeft, rowTop, cellRight, effectiveRowBottom),
            Paint()..color = ctx.backgroundColor,
          );
        }

        // Use TextPainter cache if available, otherwise create fresh
        final cellMaxWidth = math.max(
          0.0,
          contentWidth - GridPaintContext.cellPaddingH * 2,
        );
        final TextPainter tp;
        if (ctx.textPainterCache != null &&
            cellStyle == null &&
            rowStyle == null &&
            !entry.column.wrapText) {
          // Cache is only used for standard cells without custom styling
          // (custom styles vary per-frame based on data, making caching unreliable)
          tp = ctx.textPainterCache!.getOrCreate(
            rowIndex: r,
            colId: colId,
            displayValue: displayText,
            maxWidth: cellMaxWidth,
            style: columnTheme.cellTextStyle,
            textScaler: ctx.textScaler,
            create: () => ctx.layoutText(
              TextSpan(text: displayText, style: columnTheme.cellTextStyle),
              ellipsis: '\u2026',
              maxWidth: cellMaxWidth,
            ),
          );
        } else {
          tp = ctx.layoutText(
            TextSpan(
              text: displayText,
              style: columnTheme.compose(
                cellStyle: cellStyle,
                rowStyle: rowStyle,
              ),
            ),
            maxLines: entry.column.wrapText ? null : 1,
            ellipsis: entry.column.wrapText ? null : '\u2026',
            maxWidth: cellMaxWidth,
          );
        }
        // Text hugs the reading-direction leading edge of the cell.
        final textX = geom.isRtl
            ? contentLeft +
                  contentWidth -
                  GridPaintContext.cellPaddingH -
                  tp.width
            : contentLeft + GridPaintContext.cellPaddingH;
        tp.paint(
          canvas,
          Offset(textX, rowTop + (effectiveRowHeight - tp.height) / 2),
        );

        // Cell right border
        canvas.drawLine(
          Offset(cellRight, rowTop),
          Offset(cellRight, effectiveRowBottom),
          borderPaint,
        );

        contentOffset += effectiveColWidth;
        if (colSpanCount > 1) colIdx += colSpanCount - 1;
      }

      // Row bottom border
      canvas.drawLine(
        Offset(0, rowBottom),
        Offset(viewportWidth, rowBottom),
        borderPaint,
      );
    }
  }

  // --- Animate show change renderer ---

  void _paintAnimateShowChange(
    Canvas canvas,
    double cellLeft,
    double cellTop,
    double cellWidth,
    double cellHeight,
    dynamic value,
    dynamic delta, {
    bool isRtl = false,
  }) {
    final ctx = this.ctx;
    if (value == null) return;

    final numValue = (value is num) ? value.toDouble() : 0.0;
    final numDelta = (delta is num) ? delta.toDouble() : 0.0;

    final deltaUp = numDelta >= 0;
    final deltaColor = deltaUp
        ? (ctx.theme?.valueChangeDeltaUpColor ?? const Color(0xFF43A047))
        : (ctx.theme?.valueChangeDeltaDownColor ?? const Color(0xFFE53935));
    final pillColor =
        ctx.theme?.valueChangeValueHighlightBackgroundColor ??
        const Color(0x6144AD49);

    // Format values
    final arrow = deltaUp ? '↑' : '↓';
    final deltaText = numDelta != 0
        ? '$arrow${numDelta.abs().toStringAsFixed(2)}'
        : '';
    final valueText = _formatNumber(numValue);

    // Measure value text (anchored to the reading-direction trailing edge,
    // alongside the pill)
    final valueTp = ctx.layoutText(
      TextSpan(
        text: valueText,
        style: ctx.cellTextStyle.copyWith(
          color: const Color(0xFFFFFFFF),
          fontWeight: FontWeight.w500,
        ),
      ),
    );

    // Paint value pill (trailing-aligned in the cell)
    const pillPadH = 6.0;
    final pillWidth = valueTp.width + pillPadH * 2;
    final pillHeight = valueTp.height + 6;
    final pillX = isRtl
        ? cellLeft + GridPaintContext.cellPaddingH
        : cellLeft + cellWidth - GridPaintContext.cellPaddingH - pillWidth;
    final pillY = cellTop + (cellHeight - pillHeight) / 2;

    if (numDelta != 0) {
      final pillRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(pillX, pillY, pillWidth, pillHeight),
        const Radius.circular(12),
      );
      canvas.drawRRect(pillRect, Paint()..color = pillColor);
    }

    // Paint value text inside pill
    valueTp.paint(canvas, Offset(pillX + pillPadH, pillY + 3));

    // Paint delta text on the reading-direction leading side of the pill
    if (deltaText.isNotEmpty && numDelta != 0) {
      final deltaTp = ctx.layoutText(
        TextSpan(
          text: deltaText,
          style: TextStyle(
            fontSize: 12,
            color: deltaColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
      final deltaX = isRtl ? pillX + pillWidth + 8 : pillX - deltaTp.width - 8;
      deltaTp.paint(
        canvas,
        Offset(deltaX, cellTop + (cellHeight - deltaTp.height) / 2),
      );
    }
  }

  String _formatNumber(double value) {
    final abs = value.abs();
    // Format with commas
    final intPart = abs.truncate();
    final decPart = ((abs - intPart) * 100).round();
    final intStr = intPart.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
    return '$intStr.${decPart.toString().padLeft(2, '0')}';
  }

  // --- Star rating renderer ---

  /// Paints filled (★) and empty (☆) stars for a numeric rating value (0–5).
  ///
  /// Uses the theme's accent colour for filled stars and a muted colour
  /// (border colour) for empty stars. Stars are centred vertically in the
  /// cell and run from the reading-direction leading edge.
  ///
  /// Each distinct glyph (filled/empty × resolved colour × font scale ×
  /// direction) is laid out and rasterised once into a cached ui.Picture
  /// (quality program v3 item 6); repeat frames blit the pictures instead of
  /// re-laying-out and re-painting the text runs.
  void _paintStarRating(
    Canvas canvas,
    double cellLeft,
    double cellTop,
    double cellWidth,
    double cellHeight,
    dynamic value, {
    bool isRtl = false,
  }) {
    final ctx = this.ctx;
    RasterGlyphCache.syncTheme(ctx.theme);
    // Clamp rating to 0–5 range
    final int rating;
    if (value is num) {
      rating = value.toInt().clamp(0, 5);
    } else {
      rating = 0;
    }

    final filledColor = ctx.accentColor;
    final emptyColor = ctx.theme?.borderColor ?? const Color(0xFFBDBDBD);

    const int totalStars = 5;
    const double starSpacing = 2.0;

    // Lay out all stars first so the glyph run can be anchored to either
    // edge of the cell depending on direction.
    final glyphs = <RasterGlyph>[];
    var runWidth = 0.0;
    for (int i = 0; i < totalStars; i++) {
      final isFilled = i < rating;
      final glyph = _cachedStarGlyph(
        filled: isFilled,
        color: isFilled ? filledColor : emptyColor,
      );
      runWidth += glyph.width + (i < totalStars - 1 ? starSpacing : 0.0);
      glyphs.add(glyph);
    }

    // Run starts at the leading padding; under RTL it is mirrored to hang
    // from the trailing padding instead.
    final runStart = isRtl
        ? cellLeft + cellWidth - GridPaintContext.cellPaddingH - runWidth
        : cellLeft + GridPaintContext.cellPaddingH;
    var x = runStart;
    for (int i = 0; i < totalStars; i++) {
      final glyph = glyphs[i];
      RasterGlyphCache.blit(
        canvas,
        Offset(x, cellTop + (cellHeight - glyph.height) / 2),
        glyph,
      );
      x += glyph.width + starSpacing;
    }
  }

  /// Cached raster of one star glyph at glyph-local origin.
  ///
  /// The key carries the glyph variant, the resolved colour, the scaled
  /// font size and the reading direction — every input that changes the
  /// rasterised pixels.
  RasterGlyph _cachedStarGlyph({required bool filled, required Color color}) {
    final ctx = this.ctx;
    const starFontSize = 16.0;
    final key =
        'star_${filled ? 'full' : 'empty'}_${starFontSize.round()}_'
        '${color.toARGB32()}_'
        '${ctx.textScaler.scale(starFontSize).toStringAsFixed(2)}_'
        '${ctx.textDirection.name}';
    var glyph = RasterGlyphCache.star.get(key);
    if (glyph == null) {
      final tp = ctx.layoutText(
        TextSpan(
          text: filled ? '\u2605' : '\u2606',
          style: TextStyle(fontSize: starFontSize, color: color),
        ),
      );
      glyph = RasterGlyphCache.record(
        width: tp.width,
        height: tp.height,
        draw: (rec) => tp.paint(rec, Offset.zero),
      );
      RasterGlyphCache.star.put(key, glyph);
    }
    return glyph;
  }

  // --- Sparkline renderer ---

  /// Paints a miniature chart from a `List<num>` cell value.
  ///
  /// Supports line, bar and area styles. Null/empty/non-numeric data paints
  /// nothing (the caller still draws cell borders). Colours resolve from the
  /// theme: line → accent colour, fill → accent at low opacity, last-point
  /// marker → cell text colour, bar baseline → border colour.
  ///
  /// Series wider than twice the pixel column are downsampled with
  /// [OsSparklineOptions.lttbDecimate] before path construction (quality
  /// program v3 item 43): the target is `cellWidth.floor().clamp(4, 500)`
  /// points and decimation only runs when the series exceeds twice that, so
  /// LTTB preserves the visually important peaks and valleys without
  /// spending path nodes on sub-pixel detail.
  ///
  /// The entire cell frame is cached as a ui.Picture keyed on the raw value
  /// object's identity, the cell size, and a hash of the options (quality
  /// program v3 item 6): cells whose data list has not changed blit the
  /// cached picture instead of re-pathing the series every frame. The raw
  /// value instance is the change signal — immutable data updates produce a
  /// new list instance, so mutated-in-place lists would render stale pixels
  /// (matching the library's immutable-data contract). Because the frame key
  /// already carries the data identity and the cell width (which determines
  /// the decimation target), the decimated series is effectively cached per
  /// data version + target points: it is computed once inside the recorded
  /// picture and replayed from then on, so no separate decimation store is
  /// needed.
  void _paintSparkline(
    Canvas canvas,
    double cellLeft,
    double cellTop,
    double cellWidth,
    double cellHeight,
    dynamic value,
    OsSparklineOptions? options,
  ) {
    final ctx = this.ctx;
    final OsSparklineOptions opts = options ?? const OsSparklineOptions();
    final List<double> data = OsSparklineOptions.extractData(value);
    if (data.isEmpty) return;

    RasterGlyphCache.syncTheme(ctx.theme);

    final key =
        'spark_${identityHashCode(value)}_${cellWidth}x${cellHeight}_'
        '${_sparklineOptionsHash(opts)}';
    var glyph = RasterGlyphCache.sparkline.get(key, guard: value);
    if (glyph == null) {
      glyph = RasterGlyphCache.record(
        width: cellWidth,
        height: cellHeight,
        guard: value,
        draw: (rec) =>
            _paintSparklineContent(rec, cellWidth, cellHeight, data, opts),
      );
      RasterGlyphCache.sparkline.put(key, glyph);
    }
    RasterGlyphCache.blit(canvas, Offset(cellLeft, cellTop), glyph);
  }

  /// Stable hash over every [OsSparklineOptions] field that changes the
  /// rendered pixels; part of the sparkline frame cache key.
  static int _sparklineOptionsHash(OsSparklineOptions opts) => Object.hash(
    opts.type.index,
    opts.lineColor?.toARGB32(),
    opts.fillColor?.toARGB32(),
    opts.highlightColor?.toARGB32(),
    opts.lineWidth,
    opts.paddingH,
    opts.paddingV,
    opts.minY,
    opts.maxY,
    opts.baseline,
  );

  /// Direct-path sparkline ops in glyph-local coordinates (cell top-left at
  /// the origin) — recorded into the cache on miss, replayed on hit.
  ///
  /// Runs only on raster-cache misses, which is what makes the decimated
  /// series a cached, data-version-stable artifact: the LTTB reduction below
  /// executes once per (data identity, cell size, options) combination and
  /// its output is baked into the recorded picture. All three sparkline
  /// types (line/area/bar) paint from the decimated [data].
  void _paintSparklineContent(
    Canvas canvas,
    double cellWidth,
    double cellHeight,
    List<double> data,
    OsSparklineOptions opts,
  ) {
    final ctx = this.ctx;
    // Wide series: downsample to one point per pixel (capped) before
    // computing geometry (quality program v3 item 43).
    final int targetPoints = cellWidth.floor().clamp(4, 500).toInt();
    if (data.length > targetPoints * 2) {
      data = OsSparklineOptions.lttbDecimate(data, targetPoints);
    }
    // Resolve theme fallbacks once per paint call (mirrors starRating).
    final Color accent = ctx.accentColor;
    final Color borderColor = ctx.theme?.borderColor ?? const Color(0xFFBDBDBD);
    final Color textColor = ctx.theme?.cellTextColor ?? const Color(0xFF424242);

    final Color lineColor = opts.lineColor ?? accent;
    final Color fillColor =
        opts.fillColor ??
        accent.withValues(
          alpha: opts.type == OsSparklineType.bar ? 0.55 : 0.20,
        );
    final Color highlightColor = opts.highlightColor ?? textColor;

    final (double min, double max) = OsSparklineOptions.resolveMinMax(
      data,
      minY: opts.minY,
      maxY: opts.maxY,
    );
    final List<Offset> points = opts.pointsFor(
      cellWidth,
      cellHeight,
      data,
      min,
      max,
    );

    switch (opts.type) {
      case OsSparklineType.bar:
        final double baseY = _sparklineYForValue(
          opts.resolveBaseline(min, max),
          min,
          max,
          cellHeight,
          opts.paddingV,
        );
        // Visible zero-line when the baseline sits above the plot bottom.
        if (baseY < cellHeight - opts.paddingV - 0.5) {
          canvas.drawLine(
            Offset(opts.paddingH, baseY),
            Offset(cellWidth - opts.paddingH, baseY),
            Paint()..color = borderColor,
          );
        }
        final Paint barPaint = Paint()..color = fillColor;
        final int n = points.length;
        for (int i = 0; i < n; i++) {
          final double slot = (cellWidth - opts.paddingH * 2) / n;
          final double barWidth = math.max(1.0, slot * 0.6);
          final double cxLocal = opts.paddingH + slot * (i + 0.5);
          canvas.drawRect(
            Rect.fromLTRB(
              cxLocal - barWidth / 2,
              baseY,
              cxLocal + barWidth / 2,
              points[i].dy,
            ),
            barPaint,
          );
        }
      case OsSparklineType.area || OsSparklineType.line:
        if (points.length < 2) break;
        final Path path = Path()..moveTo(points.first.dx, points.first.dy);
        for (int i = 1; i < points.length; i++) {
          path.lineTo(points[i].dx, points[i].dy);
        }
        if (opts.type == OsSparklineType.area) {
          final Path fillPath = Path.from(path)
            ..lineTo(points.last.dx, cellHeight - opts.paddingV)
            ..lineTo(points.first.dx, cellHeight - opts.paddingV)
            ..close();
          canvas.drawPath(fillPath, Paint()..color = fillColor);
        }
        canvas.drawPath(
          path,
          Paint()
            ..color = lineColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = opts.lineWidth
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        );
    }

    // Last-point marker dot (only meaningful with more than one point).
    if (points.length > 1) {
      canvas.drawCircle(
        points.last,
        opts.lineWidth + 1.5,
        Paint()..color = highlightColor,
      );
    }
  }

  /// Maps a value to a cell-local Y coordinate using the same padding and
  /// bounds as [OsSparklineOptions.pointsFor].
  double _sparklineYForValue(
    double v,
    double min,
    double max,
    double cellHeight,
    double paddingV,
  ) {
    final double innerH = math.max(0.0, cellHeight - paddingV * 2);
    final double range = max - min;
    final double t = range <= 0 ? 0.5 : (v - min) / range;
    return paddingV + innerH * (1 - t.clamp(0.0, 1.0));
  }

  void _paintProgressBar(
    Canvas canvas,
    double cellLeft,
    double cellTop,
    double cellWidth,
    double cellHeight,
    dynamic value,
    OsProgressBarOptions? options, {
    required bool isRtl,
  }) {
    if (value is! num) return;
    if (value.isNaN) return;

    final opts = options ?? const OsProgressBarOptions();
    if (opts.max <= opts.min) return;

    final progress = ((value - opts.min) / (opts.max - opts.min)).clamp(
      0.0,
      1.0,
    );
    const paddingH = 8.0;
    final trackWidth = math.max(0.0, cellWidth - paddingH * 2);
    if (trackWidth <= 0) return;

    final thickness =
        opts.thickness ?? math.max(1.0, cellHeight - paddingH * 2);
    // A radius beyond half the track's smallest extent distorts the RRect
    // corners, so clamp the configured value to the painted geometry.
    final radius = math.min(
      opts.borderRadius,
      math.min(thickness, trackWidth) / 2,
    );

    // Label space is reserved up front in a single layout pass: the label
    // is capped to what remains after a minimum track width, then the track
    // takes the rest. If the cell is too narrow for both, the label is
    // dropped and the track fills the cell.
    TextPainter? labelPainter;
    const gap = 8.0;
    const minTrackWidth = 20.0;
    if (opts.showLabel) {
      final String labelText;
      if (opts.labelBuilder != null) {
        labelText = opts.labelBuilder!(value.toDouble(), progress);
      } else {
        labelText = '${(progress * 100).round()}%';
      }
      if (labelText.isNotEmpty && trackWidth > minTrackWidth + gap) {
        labelPainter = _layoutRendererText(
          text: labelText,
          style: opts.labelStyle ?? ctx.theme?.cellTextStyle,
          direction: isRtl ? TextDirection.rtl : TextDirection.ltr,
          overflow: opts.labelOverflow,
          maxWidth: trackWidth - minTrackWidth - gap,
        );
      }
    }

    final actualTrackWidth = labelPainter == null
        ? trackWidth
        : math.max(minTrackWidth, trackWidth - labelPainter.width - gap);

    final drawTrackX = isRtl
        ? cellLeft + cellWidth - paddingH - actualTrackWidth
        : cellLeft + paddingH;

    final trackY = cellTop + (cellHeight - thickness) / 2.0;

    final trackRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(drawTrackX, trackY, actualTrackWidth, thickness),
      Radius.circular(radius),
    );

    final bgPaint = Paint()
      ..color =
          opts.backgroundColor ??
          ctx.theme?.cellTextColor?.withValues(alpha: 0.1) ??
          const Color(0x1A000000);
    canvas.drawRRect(trackRect, bgPaint);

    // The fill's width is exactly `progress` of the track — no minimum-size
    // floor, so a 1% value never paints wider than 1%. The fill is clipped
    // to the track so its leading corners inherit the track rounding at
    // every width.
    final fillWidth = actualTrackWidth * progress;
    if (fillWidth > 0) {
      final fillX = isRtl
          ? drawTrackX + actualTrackWidth - fillWidth
          : drawTrackX;
      final fgColor =
          opts.colorBuilder?.call(value.toDouble()) ??
          opts.color ??
          ctx.theme?.accentColor ??
          const Color(0xFF2196F3);
      canvas.save();
      canvas.clipRRect(trackRect);
      canvas.drawRect(
        Rect.fromLTWH(fillX, trackY, fillWidth, thickness),
        Paint()..color = fgColor,
      );
      canvas.restore();
    }

    if (labelPainter != null) {
      final drawLabelX = isRtl
          ? drawTrackX - gap - labelPainter.width
          : drawTrackX + actualTrackWidth + gap;
      final drawLabelY = cellTop + (cellHeight - labelPainter.height) / 2.0;
      labelPainter.paint(canvas, Offset(drawLabelX, drawLabelY));
    }
  }

  void _paintAvatar(
    Canvas canvas,
    double cellLeft,
    double cellTop,
    double cellWidth,
    double cellHeight,
    dynamic row,
    dynamic value,
    OsAvatarOptions<dynamic>? options, {
    required bool isRtl,
  }) {
    final opts = options ?? const OsAvatarOptions<dynamic>();

    String? initials = opts.initialsGetter?.call(row);
    if (initials == null) {
      if (value is! String || value.trim().isEmpty) {
        return;
      }
      initials = _initialsForValue(value.trim());
      if (initials.isEmpty) return;
    }

    final palette =
        opts.palette ??
        const [
          Color(0xFFE57373),
          Color(0xFFF06292),
          Color(0xFFBA68C8),
          Color(0xFF9575CD),
          Color(0xFF7986CB),
          Color(0xFF64B5F6),
          Color(0xFF4FC3F7),
          Color(0xFF4DD0E1),
          Color(0xFF4DB6AC),
          Color(0xFF81C784),
          Color(0xFFAED581),
          Color(0xFFFF8A65),
          Color(0xFFD4E157),
          Color(0xFFFFD54F),
          Color(0xFFFFB74D),
        ];

    final Color bgColor =
        opts.color ??
        _hashColorFnv1a(value is String ? value : initials, palette);

    const paddingH = 8.0;
    final double radius = math.min(opts.radius, cellHeight / 2.0);
    final double diameter = radius * 2.0;

    double startX = cellLeft + paddingH;

    if (isRtl) {
      startX = cellLeft + cellWidth - paddingH - diameter;
    }

    final bgPaint = Paint()..color = bgColor;
    canvas.drawCircle(
      Offset(startX + radius, cellTop + cellHeight / 2.0),
      radius,
      bgPaint,
    );

    final baseStyle = opts.textStyle ?? ctx.theme?.cellTextStyle;
    // Contrast-aware text colour for theme-derived styles; an explicitly
    // supplied textStyle keeps its own colour (falling back to the
    // contrast choice when it carries none).
    final double luminance = bgColor.computeLuminance();
    final Color contrastColor = luminance > 0.5
        ? const Color(0xFF000000)
        : const Color(0xFFFFFFFF);
    final Color textColor = opts.textStyle?.color ?? contrastColor;

    final initialsPainter = _layoutRendererText(
      text: initials,
      style: baseStyle,
      color: textColor,
      direction: isRtl ? TextDirection.rtl : TextDirection.ltr,
      overflow: TextOverflow.clip,
      maxWidth: diameter,
    );

    initialsPainter.paint(
      canvas,
      Offset(
        startX + radius - initialsPainter.width / 2.0,
        cellTop + cellHeight / 2.0 - initialsPainter.height / 2.0,
      ),
    );

    if (opts.showLabel && value is String && value.trim().isNotEmpty) {
      final labelMaxWidth = math.max(
        0.0,
        cellWidth - diameter - opts.gap - paddingH * 2,
      );

      if (labelMaxWidth > 0) {
        final labelPainter = _layoutRendererText(
          text: value.trim(),
          style: baseStyle,
          direction: isRtl ? TextDirection.rtl : TextDirection.ltr,
          overflow: TextOverflow.ellipsis,
          maxWidth: labelMaxWidth,
        );

        final drawLabelX = isRtl
            ? startX - opts.gap - labelPainter.width
            : startX + diameter + opts.gap;

        labelPainter.paint(
          canvas,
          Offset(
            drawLabelX,
            cellTop + cellHeight / 2.0 - labelPainter.height / 2.0,
          ),
        );
      }
    }
  }

  /// Extracts 1–2 uppercase initials from a display value: the first code
  /// point of the first word, plus the first code point of the second word
  /// when present. Iterating code points (not UTF-16 code units) keeps
  /// surrogate-pair characters such as emoji intact.
  static String _initialsForValue(String text) {
    final buffer = StringBuffer();
    for (final String word in text.split(RegExp(r'\s+')).take(2)) {
      if (word.isEmpty) continue;
      buffer.write(String.fromCharCode(word.runes.first));
    }
    return buffer.toString().toUpperCase();
  }

  /// Gets-or-creates a single-line [TextPainter] for renderer labels via
  /// the shared text painter cache, falling back to a direct layout when no
  /// cache is attached.
  ///
  /// The base [style] must be identity-stable across frames (a theme style
  /// or a user-supplied instance) so cache hits survive; per-cell colour
  /// variation is passed separately as [color], which participates in the
  /// cache key by value instead of forcing a fresh style instance per
  /// frame.
  TextPainter _layoutRendererText({
    required String text,
    TextStyle? style,
    Color? color,
    required TextDirection direction,
    required TextOverflow overflow,
    required double maxWidth,
  }) {
    final TextStyle effectiveStyle = style ?? const TextStyle();
    final TextPainter? cached = ctx.textPainterCache?.getPainter(
      text: text,
      style: effectiveStyle,
      color: color,
      direction: direction,
      overflow: overflow,
      textScaler: ctx.textScaler,
      maxWidth: maxWidth,
    );
    if (cached != null) return cached;
    return TextPainter(
      text: TextSpan(
        text: text,
        style: effectiveStyle.copyWith(color: color),
      ),
      textDirection: direction,
      maxLines: 1,
      ellipsis: overflow == TextOverflow.ellipsis ? '\u2026' : null,
      textScaler: ctx.textScaler,
    )..layout(maxWidth: maxWidth);
  }

  Color _hashColorFnv1a(String text, List<Color> palette) {
    int hash = 0x811c9dc5;
    for (int i = 0; i < text.length; i++) {
      hash ^= text.codeUnitAt(i);
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return palette[hash % palette.length];
  }

  // --- Image renderer ---

  /// Paints a decoded image inside the cell.
  ///
  /// A cell value that is already a `ui.Image` paints directly — it is
  /// never cached or disposed by the grid. Any other value resolves through
  /// [OsImageOptions.imageForCell] via `ImageCellCache`: a cache hit blits
  /// immediately; a miss paints the placeholder and starts exactly one load
  /// (in-flight requests are deduplicated), whose completion fires
  /// [GridPaintContext.onImageLoaded] so the host repaints with pixels.
  /// Failed loads keep painting the placeholder without retrying.
  void _paintImage(
    Canvas canvas,
    double cellLeft,
    double cellTop,
    double cellWidth,
    double cellHeight,
    dynamic value,
    OsImageOptions? options, {
    required String colId,
    required Map<String, dynamic> data,
    required int rowIndex,
    required OsColumnDef colDef,
  }) {
    final opts = options ?? const OsImageOptions();
    final inner = Rect.fromLTWH(
      cellLeft + opts.paddingH,
      cellTop + opts.paddingV,
      math.max(0.0, cellWidth - opts.paddingH * 2),
      math.max(0.0, cellHeight - opts.paddingV * 2),
    );
    if (inner.isEmpty) return;

    ui.Image? image = value is ui.Image ? value : null;
    if (image == null) {
      // Loader resolution goes through dynamic dispatch on the typed
      // column definition — the same pattern as the cellStyle callback,
      // which sidesteps the covariant generic TypeError the other way
      // round would raise.
      final dynamic colDynamic = colDef;
      final dynamic imageOptions = colDynamic.imageOptions;
      final dynamic loader = imageOptions?.imageForCell;
      if (loader != null) {
        final key = 'img_${colId}_${identityHashCode(data)}';
        image = ImageCellCache.get(key);
        if (image == null) {
          // Placeholder this frame; decoded pixels arrive on a later one.
          // The loader invocation lives inside the fetch closure so the
          // cache's in-flight dedup guarantees it runs at most once.
          _paintImagePlaceholder(canvas, inner, opts);
          ImageCellCache.load(
            key,
            () =>
                loader(
                      CellRendererParams(
                        value: value,
                        data: data,
                        rowIndex: rowIndex,
                        colDef: colDef,
                      ),
                    )
                    as Future<ui.Image?>,
            onLoaded: ctx.onImageLoaded,
          );
          return;
        }
      }
    }

    if (image == null) return;
    _drawImageFitted(canvas, inner, image, opts);
  }

  /// Subtle rounded fill shown while a load is in flight or after it
  /// failed, so a pending image cell still reads as occupied space.
  void _paintImagePlaceholder(Canvas canvas, Rect inner, OsImageOptions opts) {
    final Paint paint = Paint()
      ..color =
          opts.placeholderColor ??
          (ctx.theme?.borderColor ?? const Color(0xFFE0E0E0)).withValues(
            alpha: 0.35,
          );
    if (opts.cornerRadius > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          inner,
          Radius.circular(
            math.min(
              opts.cornerRadius,
              math.min(inner.width, inner.height) / 2,
            ),
          ),
        ),
        paint,
      );
    } else {
      canvas.drawRect(inner, paint);
    }
  }

  /// Clips to the cell's inner rect (honouring the corner radius) and draws
  /// the image at its [OsImageFit] destination rect.
  void _drawImageFitted(
    Canvas canvas,
    Rect inner,
    ui.Image image,
    OsImageOptions opts,
  ) {
    final double imageWidth = image.width.toDouble();
    final double imageHeight = image.height.toDouble();
    final Rect dest = OsImageOptions.resolveDestRect(
      inner,
      imageWidth,
      imageHeight,
      opts.fit,
    );
    canvas.save();
    if (opts.cornerRadius > 0) {
      canvas.clipRRect(
        RRect.fromRectAndRadius(
          inner,
          Radius.circular(
            math.min(
              opts.cornerRadius,
              math.min(inner.width, inner.height) / 2,
            ),
          ),
        ),
      );
    }
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, imageWidth, imageHeight),
      dest,
      Paint()..filterQuality = FilterQuality.medium,
    );
    canvas.restore();
  }

  // --- Detail row painting ---

  /// Paints the themed placeholder band for a master row's detail area
  /// (quality program v3 item 4).
  ///
  /// The detail widget itself is rendered as an overlay child above the
  /// canvas (see `VirtualisedGrid.detailWidgetBuilder`); this band
  /// reserves the space with a slightly tinted container so the detail
  /// area reads as part of the master row even when the widget content is
  /// transparent or still building.
  void _paintDetailRow(
    Canvas canvas,
    double rowTop,
    double rowBottom,
    double viewportWidth,
    Paint borderPaint,
  ) {
    final ctx = this.ctx;
    final detailBg =
        ctx.theme?.headerBackgroundColor?.withValues(alpha: 0.35) ??
        const Color(0xFFFAFAFA);
    canvas.drawRect(
      Rect.fromLTRB(0, rowTop, viewportWidth, rowBottom),
      Paint()..color = detailBg,
    );
    canvas.drawLine(
      Offset(0, rowBottom),
      Offset(viewportWidth, rowBottom),
      borderPaint,
    );
  }

  // --- Group row painting ---

  void _paintGroupRow(
    Canvas canvas,
    Map<String, dynamic> row,
    double rowTop,
    double rowBottom,
    double viewportWidth, {
    List<ColumnLayoutEntry>? cols,
    required RtlGeometry geom,
    GridSection section = GridSection.leading,
  }) {
    final ctx = this.ctx;
    final rowHeight = rowBottom - rowTop;
    final level = (row['__groupLevel'] as int?) ?? 0;
    final expanded = (row['__groupExpanded'] as bool?) ?? false;
    final key = row['__groupKey'];
    final childCount = (row['__groupChildCount'] as int?) ?? 0;
    final aggData = row['__groupAggData'] as Map<String, dynamic>?;

    // Group row background (slightly different tint from normal rows)
    final groupBg =
        ctx.theme?.headerBackgroundColor?.withValues(alpha: 0.4) ??
        const Color(0xFFF9F9F9);
    final bgPaint = Paint()..color = groupBg;
    canvas.drawRect(
      Rect.fromLTRB(0, rowTop, viewportWidth, rowBottom),
      bgPaint,
    );

    // Indentation per level
    const indentPerLevel = 28.0;
    const chevronSize = 16.0;
    const iconPadding = 8.0;
    final indent = level * indentPerLevel + 12.0;

    // Paint expand/collapse chevron at the reading-direction leading edge
    final isRtl = geom.isRtl;
    final chevronCenterX = isRtl
        ? viewportWidth - indent - chevronSize / 2
        : indent + chevronSize / 2;
    final chevronCenterY = rowTop + rowHeight / 2;
    final chevronPaint = Paint()
      ..color = ctx.accentColor.withValues(alpha: 0.8)
      ..style = PaintingStyle.fill;

    if (expanded) {
      // Down-pointing triangle (▼)
      final path = Path()
        ..moveTo(chevronCenterX - 5, chevronCenterY - 3)
        ..lineTo(chevronCenterX + 5, chevronCenterY - 3)
        ..lineTo(chevronCenterX, chevronCenterY + 4)
        ..close();
      canvas.drawPath(path, chevronPaint);
    } else {
      // Right-pointing triangle (▶); mirrored under RTL so it points into
      // the reading direction.
      final path = Path();
      if (isRtl) {
        path.moveTo(chevronCenterX + 3, chevronCenterY - 5);
        path.lineTo(chevronCenterX - 4, chevronCenterY);
        path.lineTo(chevronCenterX + 3, chevronCenterY + 5);
      } else {
        path.moveTo(chevronCenterX - 3, chevronCenterY - 5);
        path.lineTo(chevronCenterX + 4, chevronCenterY);
        path.lineTo(chevronCenterX - 3, chevronCenterY + 5);
      }
      path.close();
      canvas.drawPath(path, chevronPaint);
    }

    // Paint group text: "{key} ({count})" trailing the chevron in reading order.
    final textLtrX = indent + chevronSize + iconPadding;
    final keyDisplay = key?.toString() ?? '(Blanks)';
    final displayText = '$keyDisplay ($childCount)';

    final foreground = ctx.theme?.foregroundColor ?? const Color(0xFF212121);
    final textStyle = TextStyle(
      color: foreground,
      fontSize: 13,
      fontWeight: FontWeight.w600,
    );

    final textPainter = ctx.layoutText(
      TextSpan(text: displayText, style: textStyle),
      ellipsis: '…',
      maxWidth: viewportWidth - textLtrX - 12,
    );
    // Under RTL the text box hangs from the mirrored anchor rightward→left.
    final textAnchorX = isRtl ? viewportWidth - textLtrX : textLtrX;
    final textX = isRtl ? textAnchorX - textPainter.width : textAnchorX;
    final textY = rowTop + (rowHeight - textPainter.height) / 2;
    textPainter.paint(canvas, Offset(textX, textY));

    // Paint aggregate values in their respective column positions.
    if (aggData != null && aggData.isNotEmpty && cols != null) {
      _paintAggregateValues(
        canvas,
        aggData,
        cols,
        geom: geom,
        section: section,
        rowTop: rowTop,
        rowHeight: rowHeight,
        foreground: foreground,
      );
    }
  }

  /// Paints aggregate values in their respective column positions on a group
  /// row.
  void _paintAggregateValues(
    Canvas canvas,
    Map<String, dynamic> aggData,
    List<ColumnLayoutEntry> cols, {
    required RtlGeometry geom,
    GridSection section = GridSection.leading,
    required double rowTop,
    required double rowHeight,
    required Color foreground,
  }) {
    final ctx = this.ctx;
    final aggTextStyle = TextStyle(
      color: foreground.withValues(alpha: 0.8),
      fontSize: 12,
      fontWeight: FontWeight.w500,
    );
    const cellPadding = 8.0;
    final isRtl = geom.isRtl;

    var contentOffset = 0.0;
    for (final entry in cols) {
      final colWidth = entry.width;
      final colId = entry.column.effectiveColId;
      final field = entry.column.field ?? colId;

      // Check if this column has an aggregate value.
      final aggValue = aggData[colId] ?? aggData[field];
      if (aggValue != null) {
        // Format the aggregate value.
        String displayValue;
        final formatter = entry.column.valueFormatter;
        if (formatter != null) {
          try {
            displayValue = formatter(
              ValueFormatterParams(value: aggValue, rowIndex: -1),
            );
          } catch (_) {
            displayValue = _formatAggValue(aggValue);
          }
        } else {
          displayValue = _formatAggValue(aggValue);
        }

        final tp = ctx.layoutText(
          TextSpan(text: displayValue, style: aggTextStyle),
          ellipsis: '…',
          maxWidth: (colWidth - cellPadding * 2).clamp(0.0, double.infinity),
        );
        final ty = rowTop + (rowHeight - tp.height) / 2;
        final cx = ctx.colX(geom, section, contentOffset, colWidth);
        // Numeric aggregates hug the cell's trailing edge in reading order.
        final double tx;
        if (isRtl) {
          tx = (cx + cellPadding).clamp(
            double.negativeInfinity,
            cx + colWidth - cellPadding - tp.width,
          );
        } else {
          tx = (cx + colWidth - cellPadding - tp.width).clamp(
            cx + cellPadding,
            double.infinity,
          );
        }
        tp.paint(canvas, Offset(tx, ty));
      }
      contentOffset += colWidth;
    }
  }

  /// Formats an aggregate value for display.
  static String _formatAggValue(dynamic value) {
    if (value is double) {
      // Show up to 2 decimal places, trim trailing zeros.
      final s = value.toStringAsFixed(2);
      if (s.contains('.')) {
        final trimmed = s
            .replaceAll(RegExp(r'0+$'), '')
            .replaceAll(RegExp(r'\.$'), '');
        return trimmed;
      }
      return s;
    }
    if (value is num) return value.toString();
    return value.toString();
  }

  // --- Row drag handle painting ---

  /// Paints a drag handle icon (⠿ — six dots in 2 columns × 3 rows) centred
  /// within the cell. Uses a muted foreground colour.
  void _paintRowDragHandle(
    Canvas canvas,
    double cellLeft,
    double cellTop,
    double cellWidth,
    double cellHeight,
  ) {
    final dotPaint = Paint()
      ..color = (ctx.theme?.foregroundColor ?? const Color(0xFF333333))
          .withValues(alpha: 0.4)
      ..style = PaintingStyle.fill;

    _paintDragHandleDots(
      canvas,
      cellLeft,
      cellTop,
      cellWidth,
      cellHeight,
      dotPaint,
    );
  }

  /// Shared six-dot drag-handle geometry so every consumer stays identical.
  static void _paintDragHandleDots(
    Canvas canvas,
    double cellLeft,
    double cellTop,
    double cellWidth,
    double cellHeight,
    Paint paint,
  ) {
    const dotRadius = 2.0;
    const colSpacing = 6.0; // horizontal distance between dot centres
    const rowSpacing = 5.0; // vertical distance between dot centres

    final cx = cellLeft + cellWidth / 2;
    final cy = cellTop + cellHeight / 2;

    // Paint 2 columns × 3 rows of dots
    for (int row = 0; row < 3; row++) {
      for (int col = 0; col < 2; col++) {
        final dotX = cx + (col - 0.5) * colSpacing;
        final dotY = cy + (row - 1) * rowSpacing;
        canvas.drawCircle(Offset(dotX, dotY), dotRadius, paint);
      }
    }
  }

  // --- Shared checkbox glyphs ---
  //
  // Every glyph is pre-rendered once as a ui.Picture in glyph-local
  // coordinates and blitted via canvas.drawPicture (quality program v3 item
  // 6). The recorded ops are exactly the direct-path ops below translated
  // to the origin, so cached and uncached renders are pixel-identical.
  // Cache keys carry every resolved colour input, so entries can never be
  // reused under a theme they were not recorded for.

  /// Accent colour used by checked/indeterminate checkbox fills.
  static Color _checkboxAccent(OsGridTheme? theme) =>
      theme?.accentColor ?? const Color(0xFF2196F3);

  /// Border colour used by unchecked/partial/disabled checkbox strokes.
  static Color _checkboxBorder(OsGridTheme? theme) =>
      theme?.borderColor ?? const Color(0xFF5A6A7A);

  /// Shared key prefix: variant + size (logical px) + resolved colours.
  static String _checkboxKey(String variant, String colorSuffix) =>
      'cb_${variant}_16_$colorSuffix';

  /// Paints a checkbox centred within the given cell bounds.
  ///
  /// Shared by body checkbox cells and the header select-all cell.
  static void paintCheckbox(
    Canvas canvas,
    double cellLeft,
    double cellTop,
    double cellWidth,
    double cellHeight,
    bool checked, {
    OsGridTheme? theme,
  }) {
    RasterGlyphCache.syncTheme(theme);
    const size = 16.0;
    final accent = _checkboxAccent(theme);
    final border = _checkboxBorder(theme);
    RasterGlyphCache.drawGlyph(
      canvas: canvas,
      offset: Offset(
        cellLeft + (cellWidth - size) / 2,
        cellTop + (cellHeight - size) / 2,
      ),
      store: RasterGlyphCache.checkbox,
      key: _checkboxKey(
        checked ? 'checked' : 'unchecked',
        '${accent.toARGB32()}_${border.toARGB32()}',
      ),
      create: () => RasterGlyphCache.record(
        width: size,
        height: size,
        draw: (rec) =>
            _paintCheckboxContent(rec, size, checked, accent, border),
      ),
    );
  }

  /// Direct-path checkbox ops at glyph-local origin (cached variant source).
  static void _paintCheckboxContent(
    Canvas canvas,
    double size,
    bool checked,
    Color accent,
    Color border,
  ) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size, size),
      const Radius.circular(3),
    );

    if (checked) {
      // Filled checkbox with tick
      canvas.drawRRect(rect, Paint()..color = accent);

      // White tick
      final tickPaint = Paint()
        ..color = Colors.white
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      final path = Path()
        ..moveTo(3.5, size / 2)
        ..lineTo(6.5, size - 4)
        ..lineTo(size - 3.5, 4);
      canvas.drawPath(path, tickPaint);
    } else {
      // Empty checkbox border
      canvas.drawRRect(
        rect,
        Paint()
          ..color = border
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke,
      );
    }
  }

  /// Paints a partially-selected checkbox (grey fill with white dash).
  ///
  /// Shared by body cells and the header select-all cell.
  static void paintPartialCheckbox(
    Canvas canvas,
    double cellLeft,
    double cellTop,
    double cellWidth,
    double cellHeight, {
    OsGridTheme? theme,
  }) {
    RasterGlyphCache.syncTheme(theme);
    const size = 16.0;
    final border = _checkboxBorder(theme);
    RasterGlyphCache.drawGlyph(
      canvas: canvas,
      offset: Offset(
        cellLeft + (cellWidth - size) / 2,
        cellTop + (cellHeight - size) / 2,
      ),
      store: RasterGlyphCache.checkbox,
      key: _checkboxKey('partial', border.toARGB32().toString()),
      create: () => RasterGlyphCache.record(
        width: size,
        height: size,
        draw: (rec) => _paintPartialCheckboxContent(rec, size, border),
      ),
    );
  }

  /// Direct-path partial-checkbox ops at glyph-local origin.
  static void _paintPartialCheckboxContent(
    Canvas canvas,
    double size,
    Color border,
  ) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size, size),
      const Radius.circular(3),
    );

    // Grey filled background
    canvas.drawRRect(rect, Paint()..color = border);

    // White dash
    final dashPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(4, size / 2), Offset(size - 4, size / 2), dashPaint);
  }

  /// Paints a disabled (greyed-out) checkbox for non-selectable rows.
  static void paintDisabledCheckbox(
    Canvas canvas,
    double cellLeft,
    double cellTop,
    double cellWidth,
    double cellHeight, {
    OsGridTheme? theme,
  }) {
    RasterGlyphCache.syncTheme(theme);
    const size = 16.0;
    final border = _checkboxBorder(theme).withValues(alpha: 0.4);
    RasterGlyphCache.drawGlyph(
      canvas: canvas,
      offset: Offset(
        cellLeft + (cellWidth - size) / 2,
        cellTop + (cellHeight - size) / 2,
      ),
      store: RasterGlyphCache.checkbox,
      key: _checkboxKey('disabled', border.toARGB32().toString()),
      create: () => RasterGlyphCache.record(
        width: size,
        height: size,
        draw: (rec) => _paintDisabledCheckboxContent(rec, size, border),
      ),
    );
  }

  /// Direct-path disabled-checkbox ops at glyph-local origin.
  static void _paintDisabledCheckboxContent(
    Canvas canvas,
    double size,
    Color border,
  ) {
    // Light grey border to indicate disabled state
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size, size),
        const Radius.circular(3),
      ),
      Paint()
        ..color = border
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke,
    );
  }

  /// Paints an indeterminate checkbox (dash inside accent-coloured box).
  /// Used for null/indeterminate values in boolean columns with an
  /// `OsCheckboxCellEditor`.
  static void paintIndeterminateCheckbox(
    Canvas canvas,
    double cellLeft,
    double cellTop,
    double cellWidth,
    double cellHeight, {
    OsGridTheme? theme,
  }) {
    RasterGlyphCache.syncTheme(theme);
    const size = 16.0;
    final accent = _checkboxAccent(theme);
    RasterGlyphCache.drawGlyph(
      canvas: canvas,
      offset: Offset(
        cellLeft + (cellWidth - size) / 2,
        cellTop + (cellHeight - size) / 2,
      ),
      store: RasterGlyphCache.checkbox,
      key: _checkboxKey('indeterminate', accent.toARGB32().toString()),
      create: () => RasterGlyphCache.record(
        width: size,
        height: size,
        draw: (rec) => _paintIndeterminateCheckboxContent(rec, size, accent),
      ),
    );
  }

  /// Direct-path indeterminate-checkbox ops at glyph-local origin.
  static void _paintIndeterminateCheckboxContent(
    Canvas canvas,
    double size,
    Color accent,
  ) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size, size),
      const Radius.circular(3),
    );

    // Accent-coloured filled background
    canvas.drawRRect(rect, Paint()..color = accent);

    // White dash (indeterminate indicator)
    final dashPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(4, size / 2), Offset(size - 4, size / 2), dashPaint);
  }

  // --- Cell flash overlay pass ---

  /// Paints semi-transparent highlight overlays on cells that are currently
  /// flashing. Respects the three-section layout (leading/center/trailing).
  ///
  /// Static so the dedicated flash overlay painter can run this pass on its
  /// own layer ABOVE the range overlays — matching the monolithic draw order
  /// where flashes painted after range fills — while the code stays owned by
  /// the body painter (quality program v3 item 5).
  static void paintFlashOverlays(
    GridPaintContext ctx,
    Canvas canvas,
    Size size,
  ) {
    final flashes = ctx.cellFlashes;
    if (flashes == null || flashes.isEmpty) return;

    final flashColor = ctx.theme?.cellFlashColor ?? const Color(0xFF4CAF50);
    final viewportHeight = size.height;

    final layout = ctx.buildLayout();
    final geom = ctx.geometry(
      viewportWidth: size.width,
      leftWidth: layout.leftWidth,
      rightWidth: layout.rightWidth,
    );
    final visible = ctx.visibleRowRange(size);
    final centerSectionX = geom.centerViewportLeft;
    final centerViewportWidth = geom.centerViewportWidth;
    final dataAreaTop = ctx.dataAreaTop;

    // colId → (startX within section, width, section) lookup, shared with
    // the flash damage classifier so both walks resolve cells identically.
    final colIdToInfo = ctx.flashColumnLookup(layout);

    for (final flash in flashes.values) {
      final opacity = flash.opacityAt(ctx.flashElapsed);
      if (opacity == null || opacity <= 0.0) continue;

      final rowIndex = flash.position.rowIndex;
      if (rowIndex < visible.first || rowIndex > visible.last) continue;

      final resolved = ctx.resolveFlashCell(
        flash.position,
        colIdToInfo,
        geom,
        dataAreaTop,
      );
      if (resolved == null) continue;
      final cellRect = resolved.rect;
      final section = resolved.section;

      if (cellRect.bottom < dataAreaTop || cellRect.top > viewportHeight) {
        continue;
      }

      // Skip center columns outside the visible viewport
      if (section == FlashSection.center &&
          (cellRect.right < centerSectionX ||
              cellRect.left > centerSectionX + centerViewportWidth)) {
        continue;
      }

      // Clip to section bounds for center columns
      canvas.save();
      if (section == FlashSection.center) {
        canvas.clipRect(
          Rect.fromLTWH(
            centerSectionX,
            dataAreaTop,
            centerViewportWidth,
            viewportHeight - dataAreaTop,
          ),
        );
      }

      final paint = Paint()
        ..color = flashColor.withValues(alpha: opacity * 0.3)
        ..style = PaintingStyle.fill;
      canvas.drawRect(cellRect, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant BodyPainter oldDelegate) {
    return _shouldRepaint(ctx, oldDelegate.ctx);
  }
}

/// Whether any input consumed by the body bands changed between the two
/// contexts. Field set mirrors `GridPaintInputs.sectionFields` keys
/// `left`/`center`/`right` minus the overlay-only inputs (`cellRanges`,
/// `hoveredColId`, `cellFlashes`, `flashElapsed`) whose pixels moved to the
/// dedicated overlay painters in the split (quality program v3 item 5):
/// pure vertical scrolling still repaints the body, but flash ticks no
/// longer do.
bool _shouldRepaint(GridPaintContext a, GridPaintContext b) {
  // columnWidths is rebuilt per widget build, so compare by content — an
  // identity check would flag every frame (quality program v3 item 7).
  return !identical(a.columns, b.columns) ||
      !listEquals(a.columnWidths, b.columnWidths) ||
      a.theme != b.theme ||
      a.textDirection != b.textDirection ||
      a.textScaler.scale(16) != b.textScaler.scale(16) ||
      a.rowHeight != b.rowHeight ||
      a.rowHeightLayout != b.rowHeightLayout ||
      a.scrollX != b.scrollX ||
      a.scrollY != b.scrollY ||
      !identical(a.rowData, b.rowData) ||
      !identical(a.rowStyles, b.rowStyles) ||
      a.selectedRows != b.selectedRows ||
      a.hoveredRow != b.hoveredRow ||
      !identical(a.cellSpanService, b.cellSpanService) ||
      a.suppressColumnVirtualisation != b.suppressColumnVirtualisation;
}
