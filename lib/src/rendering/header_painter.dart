import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import '../filtering/filter_evaluator.dart';
import '../sorting/sort_direction.dart';
import 'body_painter.dart';
import 'column_group_layout.dart';
import 'column_layout.dart';
import 'grid_paint_context.dart';
import 'rtl_geometry.dart';
import 'special_columns.dart';

/// Per-section painter for the grid's header bands (quality program v3
/// item 5).
///
/// Owns every pixel inside the header region:
/// - per-section header backgrounds and column header cells,
/// - sort indicators (arrow + multi-sort priority number),
/// - filter funnel and column menu (⋮) icons,
/// - the checkbox-selection header cell,
/// - the column-group header row (accent bar + caption),
/// - the floating filter row,
/// - the full-width header bottom border.
///
/// Reads all inputs from a shared `GridPaintContext` and renders byte-for-
/// byte the same ops the monolithic grid painter issued, so goldens stay
/// stable whether this painter runs standalone or composed under the
/// top-level painter.
class HeaderPainter extends CustomPainter {
  HeaderPainter(this.ctx);

  final GridPaintContext ctx;

  /// Size of the filter icon in logical pixels.
  static const double _filterIconSize = 12.0;

  /// Right-side padding between the filter icon and the cell border.
  static const double _filterIconRightPadding = 8.0;

  /// Width reserved for the column menu icon (icon + padding).
  static const double _menuIconWidth = 20.0;

  /// Width of the accent bar painted on the leading edge of column groups.
  static const double _groupAccentBarWidth = 3.0;

  /// Extra padding applied after the accent bar to separate it from text.
  static const double _groupAccentBarPadding = 8.0;

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

    final borderColor = ctx.borderColor;
    final borderPaint = Paint()
      ..color = borderColor
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    final headerBgPaint = Paint()..color = ctx.headerBackgroundColor;
    final totalHeaderHeight = ctx.totalHeaderHeight;
    final centerSectionX = geom.centerViewportLeft;
    final centerViewportWidth = geom.centerViewportWidth;

    // --- Center section header band ---
    canvas.drawRect(
      Rect.fromLTWH(centerSectionX, 0, centerViewportWidth, totalHeaderHeight),
      headerBgPaint,
    );
    canvas.save();
    canvas.clipRect(
      Rect.fromLTWH(centerSectionX, 0, centerViewportWidth, viewportHeight),
    );
    final visibleColRange = ctx.visibleColumnRange(layout, centerViewportWidth);
    _paintHeaderCells(
      canvas,
      layout.centerCols,
      geom,
      GridSection.center,
      borderPaint,
      ctx.groupHeaderHeight,
      visibleColRange,
    );
    canvas.restore();

    // --- Leading pinned header band ---
    if (layout.leftCols.isNotEmpty) {
      canvas.drawRect(
        Rect.fromLTWH(
          geom.leadingSectionX,
          0,
          layout.leftWidth,
          totalHeaderHeight,
        ),
        headerBgPaint,
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
      _paintHeaderCells(
        canvas,
        layout.leftCols,
        geom,
        GridSection.leading,
        borderPaint,
        ctx.groupHeaderHeight,
      );
      canvas.restore();
    }

    // --- Trailing pinned header band ---
    if (layout.rightCols.isNotEmpty) {
      canvas.drawRect(
        Rect.fromLTWH(
          geom.trailingSectionX,
          0,
          layout.rightWidth,
          totalHeaderHeight,
        ),
        headerBgPaint,
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
      _paintHeaderCells(
        canvas,
        layout.rightCols,
        geom,
        GridSection.trailing,
        borderPaint,
        ctx.groupHeaderHeight,
      );
      canvas.restore();
    }

    // --- Pinned section separators ---
    // Full-height separator strokes between the pinned sections and the
    // scrollable body. Drawn AFTER the header cells (they overpaint the
    // last column's cell border, exactly as the monolithic painter did)
    // and BEFORE the group headers / floating filter row (whose per-section
    // backgrounds cover the stroke within their bands).
    final pinnedBorderColor =
        ctx.theme?.pinnedColumnBorderColor ?? ctx.borderColor;
    final pinnedBorderPaint = Paint()
      ..color = pinnedBorderColor
      ..strokeWidth = ctx.pinnedBorderWidth
      ..style = PaintingStyle.stroke;
    if (layout.leftCols.isNotEmpty) {
      canvas.drawLine(
        Offset(geom.leadingBorderX, 0),
        Offset(geom.leadingBorderX, viewportHeight),
        pinnedBorderPaint,
      );
    }
    if (layout.rightCols.isNotEmpty) {
      canvas.drawLine(
        Offset(geom.trailingBorderX, 0),
        Offset(geom.trailingBorderX, viewportHeight),
        pinnedBorderPaint,
      );
    }

    // --- Column group header row ---
    final spans = ctx.columnGroupSpans;
    if (spans != null && spans.isNotEmpty) {
      _paintGroupHeaders(canvas, layout, geom, viewportWidth, borderPaint);
    }

    // --- Floating filter row ---
    if (ctx.floatingFilterHeight > 0) {
      _paintFloatingFilterRow(canvas, layout, geom, viewportWidth);
    }

    // --- Header bottom border (full width, on top) ---
    canvas.drawLine(
      Offset(0, totalHeaderHeight),
      Offset(viewportWidth, totalHeaderHeight),
      borderPaint,
    );
  }

  /// Paints the header cells for one section's column entries.
  void _paintHeaderCells(
    Canvas canvas,
    List<ColumnLayoutEntry> cols,
    RtlGeometry geom,
    GridSection section,
    Paint borderPaint,
    double topOffset, [
    ({int first, int last})? visibleColRange,
  ]) {
    final ctx = this.ctx;
    // Build a set of column indices that belong to a group span.
    // Ungrouped columns will span the full header height (group + leaf rows)
    // to match OS Grid TypeScript behaviour.
    final groupedIndices = <int>{};
    final spans = ctx.columnGroupSpans;
    if (spans != null && ctx.groupHeaderHeight > 0) {
      for (final span in spans) {
        for (int i = span.startIndex; i <= span.endIndex; i++) {
          groupedIndices.add(i);
        }
      }
    }

    final isRtl = geom.isRtl;
    final theme = ctx.theme;
    var offset = 0.0;
    for (int colIdx = 0; colIdx < cols.length; colIdx++) {
      final entry = cols[colIdx];
      final colWidth = entry.width;

      // Column virtualisation: skip columns outside visible range
      if (visibleColRange != null &&
          (colIdx < visibleColRange.first || colIdx > visibleColRange.last)) {
        offset += colWidth;
        continue;
      }

      // Directional x-mapping via the shared resolver.
      final x = ctx.colX(geom, section, offset, colWidth);
      final cellRight = x + colWidth;

      // Determine if this column is ungrouped and should span full header
      // height
      final isUngrouped =
          ctx.groupHeaderHeight > 0 && !groupedIndices.contains(entry.index);
      final cellTopOffset = isUngrouped ? 0.0 : topOffset;
      final cellHeight = isUngrouped
          ? (ctx.groupHeaderHeight + ctx.headerHeight)
          : ctx.headerHeight;

      // Special rendering for checkbox header
      if (entry.column.field == SpecialColumns.checkbox ||
          entry.column.headerCheckboxSelection == true) {
        // Use headerName to encode state: 'all', 'partial', or 'none'
        final state = entry.column.headerName;
        if (state == 'all') {
          BodyPainter.paintCheckbox(
            canvas,
            x,
            cellTopOffset,
            colWidth,
            cellHeight,
            true,
            theme: ctx.theme,
          );
        } else if (state == 'partial') {
          BodyPainter.paintPartialCheckbox(
            canvas,
            x,
            cellTopOffset,
            colWidth,
            cellHeight,
            theme: ctx.theme,
          );
        } else {
          BodyPainter.paintCheckbox(
            canvas,
            x,
            cellTopOffset,
            colWidth,
            cellHeight,
            false,
            theme: ctx.theme,
          );
        }
        canvas.drawLine(
          Offset(cellRight, cellTopOffset),
          Offset(cellRight, cellTopOffset + cellHeight),
          borderPaint,
        );
        offset += colWidth;
        continue;
      }

      // Special rendering for row drag header (empty — no text or icons)
      if (entry.column.field == SpecialColumns.rowDrag) {
        canvas.drawLine(
          Offset(cellRight, cellTopOffset),
          Offset(cellRight, cellTopOffset + cellHeight),
          borderPaint,
        );
        offset += colWidth;
        continue;
      }

      // Determine if this column is filterable (has a filter configured)
      final hasFilter = entry.column.filter != null;
      final filterIconSpace = hasFilter
          ? _filterIconSize + _filterIconRightPadding
          : 0.0;

      // Determine whether this column should show a menu icon
      final field = entry.column.field;
      final showMenuIcon = field == null || !SpecialColumns.isSpecial(field);
      final menuIconSpace = showMenuIcon ? _menuIconWidth : 0.0;

      // Header text
      final headerText = entry.column.effectiveHeaderName;
      // Determine sort indicator: prefer multi-sort map, fall back to legacy
      // single index
      final multiSortInfo = ctx.sortIndicators?[entry.index];
      final hasSortIndicator =
          multiSortInfo != null || ctx.sortColumnIndex == entry.index;
      final showPriorityNumber =
          multiSortInfo != null && multiSortInfo.isMultiSort;
      final sortIndicatorWidth = hasSortIndicator
          ? (showPriorityNumber ? 30.0 : 18.0)
          : 0.0;
      final textMaxWidth = math.max(
        0.0,
        colWidth -
            GridPaintContext.cellPaddingH * 2 -
            sortIndicatorWidth -
            filterIconSpace -
            menuIconSpace,
      );

      final tp = ctx.layoutText(
        TextSpan(text: headerText, style: ctx.headerTextStyle),
        ellipsis: '\u2026',
        maxWidth: textMaxWidth,
      );
      // Text hugs the reading-direction leading edge of the cell.
      final textX = isRtl
          ? cellRight - GridPaintContext.cellPaddingH - tp.width
          : x + GridPaintContext.cellPaddingH;
      tp.paint(
        canvas,
        Offset(textX, cellTopOffset + (cellHeight - tp.height) / 2),
      );

      // Sort indicator (arrow + optional priority number) trails the caption
      // in reading order: right of the text under LTR, left of it under RTL.
      if (hasSortIndicator) {
        final arrowX = isRtl
            ? textX - 6 - 8
            : x + GridPaintContext.cellPaddingH + tp.width + 6;
        final arrowY = cellTopOffset + cellHeight / 2;
        final arrowPaint = Paint()
          ..color =
              theme?.foregroundColor?.withValues(alpha: 0.7) ??
              const Color(0xFF616161)
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

        // Determine direction from multi-sort info or legacy flag
        final bool isAscending;
        if (multiSortInfo != null) {
          isAscending = multiSortInfo.direction == OsSortDirection.ascending;
        } else {
          isAscending = ctx.sortAscending;
        }

        final path = Path();
        if (isAscending) {
          path.moveTo(arrowX, arrowY + 3);
          path.lineTo(arrowX + 4, arrowY - 3);
          path.lineTo(arrowX + 8, arrowY + 3);
        } else {
          path.moveTo(arrowX, arrowY - 3);
          path.lineTo(arrowX + 4, arrowY + 3);
          path.lineTo(arrowX + 8, arrowY - 3);
        }
        canvas.drawPath(path, arrowPaint);

        // Paint priority number for multi-column sort
        if (showPriorityNumber) {
          final priorityTp = ctx.layoutText(
            TextSpan(
              text: multiSortInfo.priority.toString(),
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color:
                    theme?.foregroundColor?.withValues(alpha: 0.6) ??
                    const Color(0xFF757575),
              ),
            ),
          );
          final priorityX = isRtl
              ? arrowX - 10 - priorityTp.width
              : arrowX + 10;
          priorityTp.paint(
            canvas,
            Offset(priorityX, arrowY - priorityTp.height / 2),
          );
        }
      }

      // Filter icon (funnel shape on the reading-direction trailing edge)
      if (hasFilter) {
        _paintFilterIcon(
          canvas,
          x,
          cellTopOffset,
          colWidth,
          menuIconSpace,
          cellHeight,
          isRtl,
        );
      }

      // Column menu icon (⋮) — three vertical dots, outermost in the header
      if (showMenuIcon) {
        _paintMenuIcon(
          canvas,
          x,
          cellTopOffset,
          colWidth,
          cellHeight,
          isRtl: isRtl,
        );
      }

      // Right border
      canvas.drawLine(
        Offset(cellRight, cellTopOffset),
        Offset(cellRight, cellTopOffset + cellHeight),
        borderPaint,
      );

      offset += colWidth;
    }
  }

  /// Paints a small funnel/filter icon on the reading-direction trailing
  /// side of a header cell.
  ///
  /// The icon is three horizontal lines of decreasing width (tapered funnel),
  /// rendered at 50% opacity of the header text colour.
  ///
  /// [menuIconOffset] shifts the filter icon inward to make room for the
  /// menu icon which sits outboard of it.
  void _paintFilterIcon(
    Canvas canvas,
    double cellX,
    double topOffset,
    double colWidth,
    double menuIconOffset, [
    double? cellHeight,
    bool isRtl = false,
  ]) {
    final effectiveHeight = cellHeight ?? ctx.headerHeight;
    final headerTextColor =
        ctx.theme?.headerTextStyle?.color ?? const Color(0xFF212121);
    final iconColor = headerTextColor.withValues(alpha: 0.5);

    final iconPaint = Paint()
      ..color = iconColor
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Position the icon on the trailing side of the cell (right under LTR,
    // left under RTL), shifted inward by the menu icon width.
    final double iconRight;
    final double iconLeft;
    if (isRtl) {
      iconLeft = cellX + _filterIconRightPadding + menuIconOffset;
      iconRight = iconLeft + _filterIconSize;
    } else {
      iconRight = cellX + colWidth - _filterIconRightPadding - menuIconOffset;
      iconLeft = iconRight - _filterIconSize;
    }
    final iconCenterY = topOffset + effectiveHeight / 2;

    // Draw three horizontal lines of decreasing width (funnel shape)
    // Top line: full width
    final topLineY = iconCenterY - 3.5;
    canvas.drawLine(
      Offset(iconLeft, topLineY),
      Offset(iconRight, topLineY),
      iconPaint,
    );

    // Middle line: ~66% width
    final midLineY = iconCenterY;
    const midInset = _filterIconSize * 0.17;
    canvas.drawLine(
      Offset(iconLeft + midInset, midLineY),
      Offset(iconRight - midInset, midLineY),
      iconPaint,
    );

    // Bottom line: ~33% width
    final botLineY = iconCenterY + 3.5;
    const botInset = _filterIconSize * 0.33;
    canvas.drawLine(
      Offset(iconLeft + botInset, botLineY),
      Offset(iconRight - botInset, botLineY),
      iconPaint,
    );
  }

  /// Paints the column menu icon (three vertical dots ⋮) on the
  /// reading-direction trailing side of a header cell.
  ///
  /// The icon is positioned as the outermost element in the header, with 8px
  /// padding from the cell's trailing border.
  void _paintMenuIcon(
    Canvas canvas,
    double cellLeft,
    double cellTop,
    double cellWidth,
    double cellHeight, {
    bool isRtl = false,
  }) {
    // Muted version of header text colour (40% opacity)
    final headerTextColor =
        ctx.theme?.headerTextStyle?.color ?? const Color(0xFF212121);
    final iconColor = headerTextColor.withValues(alpha: 0.4);
    final dotPaint = Paint()
      ..color = iconColor
      ..style = PaintingStyle.fill;

    // Position: aligned with 8px padding from the cell's trailing edge
    const dotRadius = 2.0;
    const dotSpacing = 5.0; // centre-to-centre vertical spacing
    const outerPadding = 8.0;

    final dotCenterX = isRtl
        ? cellLeft + outerPadding + dotRadius
        : cellLeft + cellWidth - outerPadding - dotRadius;
    final dotCenterY = cellTop + cellHeight / 2;

    // Three dots stacked vertically, centred in the cell height
    canvas.drawCircle(
      Offset(dotCenterX, dotCenterY - dotSpacing),
      dotRadius,
      dotPaint,
    );
    canvas.drawCircle(Offset(dotCenterX, dotCenterY), dotRadius, dotPaint);
    canvas.drawCircle(
      Offset(dotCenterX, dotCenterY + dotSpacing),
      dotRadius,
      dotPaint,
    );
  }

  /// Paints the column group header row: accent bar + caption per span, then
  /// the segmented bottom border that only runs under grouped columns.
  void _paintGroupHeaders(
    Canvas canvas,
    ColumnLayout layout,
    RtlGeometry geom,
    double viewportWidth,
    Paint borderPaint,
  ) {
    final ctx = this.ctx;
    final spans = ctx.columnGroupSpans;
    if (spans == null || ctx.groupHeaderHeight <= 0) return;
    final groupHeaderHeight = ctx.groupHeaderHeight;

    // Build a map of column index -> visual x position (accounting for
    // pinning, scroll, and reading direction)
    final colPositions = <int, double>{};
    final colSections = <int, String>{}; // 'leading', 'center', 'trailing'
    _fillColumnVisualPositions(layout, geom, colPositions, colSections);

    final centerSectionX = geom.centerViewportLeft;
    final centerViewportWidth = geom.centerViewportWidth;

    // Accent bar paint (uses theme accentColor, falls back to blue)
    final accentPaint = Paint()
      ..color = ctx.accentColor
      ..style = PaintingStyle.fill;

    // Resolve each group's on-canvas visual extent once — shared by the
    // content pass below and the bottom-border pass at the end.
    final extents = <Rect?>[
      for (final group in spans) _groupVisualExtent(group, colPositions),
    ];

    // Paint each group span
    for (var spanIndex = 0; spanIndex < spans.length; spanIndex++) {
      final group = spans[spanIndex];
      final extent = extents[spanIndex];
      if (extent == null) continue;
      final startX = extent.left;
      final endX = extent.right;
      final groupWidth = endX - startX;

      // Determine section for clipping
      final section = colSections[group.startIndex] ?? 'center';

      // Clip to appropriate section
      canvas.save();
      if (section == 'center') {
        canvas.clipRect(
          Rect.fromLTWH(
            centerSectionX,
            0,
            centerViewportWidth,
            groupHeaderHeight,
          ),
        );
      } else if (section == 'leading') {
        canvas.clipRect(
          Rect.fromLTWH(
            geom.leadingSectionX,
            0,
            layout.leftWidth,
            groupHeaderHeight,
          ),
        );
      } else {
        canvas.clipRect(
          Rect.fromLTWH(
            geom.trailingSectionX,
            0,
            layout.rightWidth,
            groupHeaderHeight,
          ),
        );
      }

      // Paint group header content (accent bar + text) for non-empty groups.
      // The accent bar hugs the group's leading (reading-direction) edge.
      if (group.headerName.isNotEmpty) {
        final barX = geom.isRtl ? endX - _groupAccentBarWidth : startX;
        canvas.drawRect(
          Rect.fromLTWH(barX, 0, _groupAccentBarWidth, groupHeaderHeight),
          accentPaint,
        );

        // Paint group header text trailing the accent bar in reading order.
        const textLeftPadding = _groupAccentBarWidth + _groupAccentBarPadding;
        final textMaxWidth = math.max(
          0.0,
          groupWidth - textLeftPadding - GridPaintContext.cellPaddingH,
        );

        final tp = ctx.layoutText(
          TextSpan(text: group.headerName, style: ctx.headerTextStyle),
          ellipsis: '\u2026',
          maxWidth: textMaxWidth,
        );
        final textX = geom.isRtl
            ? endX - textLeftPadding - tp.width
            : startX + textLeftPadding;
        tp.paint(canvas, Offset(textX, (groupHeaderHeight - tp.height) / 2));
      }

      // Border on the group's trailing edge
      final borderX = geom.isRtl ? startX : endX;
      canvas.drawLine(
        Offset(borderX, 0),
        Offset(borderX, groupHeaderHeight),
        borderPaint,
      );

      canvas.restore();
    }

    // Bottom border of group header row — only draw under grouped columns,
    // not through ungrouped columns that span the full header height.
    // Build segments from group spans to avoid cutting through full-height
    // headers.
    if (spans.isNotEmpty) {
      for (var spanIndex = 0; spanIndex < spans.length; spanIndex++) {
        final group = spans[spanIndex];
        final extent = extents[spanIndex];
        if (extent == null) continue;
        final segStartX = extent.left;
        final segEndX = extent.right;

        // Clip center group borders to the center viewport so they don't
        // bleed into pinned sections when scrolled.
        final section = colSections[group.startIndex] ?? 'center';
        if (section == 'center') {
          final clippedStartX = segStartX.clamp(
            centerSectionX,
            centerSectionX + centerViewportWidth,
          );
          final clippedEndX = segEndX.clamp(
            centerSectionX,
            centerSectionX + centerViewportWidth,
          );
          if (clippedStartX < clippedEndX) {
            canvas.drawLine(
              Offset(clippedStartX, groupHeaderHeight),
              Offset(clippedEndX, groupHeaderHeight),
              borderPaint,
            );
          }
        } else {
          canvas.drawLine(
            Offset(segStartX, groupHeaderHeight),
            Offset(segEndX, groupHeaderHeight),
            borderPaint,
          );
        }
      }
    }
  }

  /// Fills [positions]/[sections] with each column's visual left X and
  /// section membership, honouring the reading direction.
  void _fillColumnVisualPositions(
    ColumnLayout layout,
    RtlGeometry geom,
    Map<int, double> positions,
    Map<int, String> sections,
  ) {
    var offset = 0.0;
    for (final entry in layout.leftCols) {
      positions[entry.index] = geom.pinnedX(
        sectionX: geom.leadingSectionX,
        sectionWidth: geom.leadingWidth,
        offset: offset,
        width: entry.width,
      );
      sections[entry.index] = 'leading';
      offset += entry.width;
    }
    offset = 0.0;
    for (final entry in layout.centerCols) {
      positions[entry.index] = geom.centerX(
        offset: offset,
        width: entry.width,
        scrollX: ctx.scrollX,
      );
      sections[entry.index] = 'center';
      offset += entry.width;
    }
    offset = 0.0;
    for (final entry in layout.rightCols) {
      positions[entry.index] = geom.pinnedX(
        sectionX: geom.trailingSectionX,
        sectionWidth: geom.trailingWidth,
        offset: offset,
        width: entry.width,
      );
      sections[entry.index] = 'trailing';
      offset += entry.width;
    }
  }

  /// Visual on-canvas extent of [group] — [Rect.left]..[Rect.right] — from
  /// its member columns' resolved visual positions, or null when none of
  /// the span's columns resolve to a position.
  ///
  /// Uses min/max over the member edges instead of summing widths from the
  /// first member: under RTL [colPositions] holds each column's LEFT edge
  /// and columns are laid out right-to-left, so a group spans from the
  /// left edge of its LAST member to the right edge of its FIRST member —
  /// the sum formula overshoots into the neighbouring group (mirrors the
  /// true-min/max-visual-edge guard in RangePainter's range painting).
  Rect? _groupVisualExtent(
    ColumnGroupSpan group,
    Map<int, double> colPositions,
  ) {
    var left = double.infinity;
    var right = double.negativeInfinity;
    for (int i = group.startIndex; i <= group.endIndex; i++) {
      final position = colPositions[i];
      if (position == null) continue;
      left = math.min(left, position);
      right = math.max(right, position + ctx.colWidth(i));
    }
    if (left.isInfinite) return null;
    return Rect.fromLTRB(left, 0, right, 0);
  }

  /// Paints the floating filter row across all three sections.
  void _paintFloatingFilterRow(
    Canvas canvas,
    ColumnLayout layout,
    RtlGeometry geom,
    double viewportWidth,
  ) {
    final ctx = this.ctx;
    final theme = ctx.theme;
    // The floating filter row sits below the group header + column header
    final filterRowTop = ctx.groupHeaderHeight + ctx.headerHeight;
    final filterRowBottom = filterRowTop + ctx.floatingFilterHeight;
    final isRtl = geom.isRtl;

    // Background — slightly different from header to distinguish it
    final filterBgColor =
        theme?.chromeBackgroundColor ?? const Color(0xFFF8F8F8);
    final filterBgPaint = Paint()..color = filterBgColor;

    // Input box styling
    final inputBgColor = ctx.backgroundColor;
    final inputBorderColor = theme?.borderColor ?? const Color(0xFFE0E0E0);
    final inputBgPaint = Paint()..color = inputBgColor;
    final inputBorderPaint = Paint()
      ..color = inputBorderColor
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Placeholder text style
    final placeholderStyle = TextStyle(
      fontSize: 12,
      color: (theme?.foregroundColor ?? const Color(0xFF181D1F)).withValues(
        alpha: 0.4,
      ),
    );

    // Icon colour for the filter icon in each input
    final iconColor = (theme?.foregroundColor ?? const Color(0xFF181D1F))
        .withValues(alpha: 0.35);
    final iconPaint = Paint()
      ..color = iconColor
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final rowBorderPaint = Paint()
      ..color = ctx.borderColor
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Paint floating filter cells for a given section
    void paintFilterCells(List<ColumnLayoutEntry> cols, GridSection section) {
      var offset = 0.0;
      for (final entry in cols) {
        final colWidth = entry.width;
        final x = ctx.colX(geom, section, offset, colWidth);
        final cellRight = x + colWidth;

        // Determine if this column has a filter (is filterable)
        final hasFilter = entry.column.filter != null;
        final isSpecialCol =
            entry.column.field == SpecialColumns.checkbox ||
            entry.column.checkboxSelection == true ||
            entry.column.field == SpecialColumns.rowNumber ||
            entry.column.field == SpecialColumns.rowDrag;

        if (hasFilter && !isSpecialCol) {
          // Check if there's active filter text for this column
          final colId = entry.column.effectiveColId;
          final filterText = ctx.floatingFilterTexts?[colId];
          final hasActiveFilter = filterText != null && filterText.isNotEmpty;
          final operationType = ctx.floatingFilterOperations?[colId];

          // Paint input box placeholder
          const hPad = 6.0;
          const vPad = 4.0;
          final inputLeft = x + hPad;
          final inputTop = filterRowTop + vPad;
          final inputWidth = colWidth - hPad * 2;
          final inputHeight = ctx.floatingFilterHeight - vPad * 2;

          if (inputWidth > 0 && inputHeight > 0) {
            final inputRect = RRect.fromRectAndRadius(
              Rect.fromLTWH(inputLeft, inputTop, inputWidth, inputHeight),
              const Radius.circular(3),
            );

            // Active filters get a tinted background to indicate filtering
            if (hasActiveFilter) {
              final activeBgColor = ctx.accentColor.withValues(alpha: 0.08);
              final activeBorderColor = ctx.accentColor.withValues(alpha: 0.5);
              canvas.drawRRect(inputRect, Paint()..color = activeBgColor);
              canvas.drawRRect(
                inputRect,
                Paint()
                  ..color = activeBorderColor
                  ..strokeWidth = 1.0
                  ..style = PaintingStyle.stroke,
              );
            } else {
              // Fill + border (default inactive state)
              canvas.drawRRect(inputRect, inputBgPaint);
              canvas.drawRRect(inputRect, inputBorderPaint);
            }

            // Operation indicator on the reading-direction leading side of
            // the input (left under LTR, right under RTL)
            const operationIndicatorWidth = 24.0;
            final opLabel = operationType != null
                ? getFilterOperationLabel(operationType)
                : getFilterOperationLabel(
                    entry.column.filter != null
                        ? getDefaultFilterType(entry.column.filter!)
                        : 'contains',
                  );

            // Paint operation indicator background (subtle separator)
            final opLeft = isRtl
                ? inputLeft + inputWidth - operationIndicatorWidth
                : inputLeft;
            final opBgRect = Rect.fromLTWH(
              opLeft,
              inputTop,
              operationIndicatorWidth,
              inputHeight,
            );
            final opBgColor =
                (theme?.foregroundColor ?? const Color(0xFF181D1F)).withValues(
                  alpha: 0.05,
                );
            // Clip to rounded leading corners
            canvas.save();
            canvas.clipRRect(
              isRtl
                  ? RRect.fromRectAndCorners(
                      opBgRect,
                      topRight: const Radius.circular(3),
                      bottomRight: const Radius.circular(3),
                    )
                  : RRect.fromRectAndCorners(
                      opBgRect,
                      topLeft: const Radius.circular(3),
                      bottomLeft: const Radius.circular(3),
                    ),
            );
            canvas.drawRect(opBgRect, Paint()..color = opBgColor);
            canvas.restore();

            // Paint operation label text
            final opTp = ctx.layoutText(
              TextSpan(
                text: opLabel,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: hasActiveFilter
                      ? ctx.accentColor
                      : (theme?.foregroundColor ?? const Color(0xFF181D1F))
                            .withValues(alpha: 0.5),
                ),
              ),
              maxWidth: operationIndicatorWidth,
            );
            opTp.paint(
              canvas,
              Offset(
                opLeft + (operationIndicatorWidth - opTp.width) / 2,
                inputTop + (inputHeight - opTp.height) / 2,
              ),
            );

            // Separator line between operation indicator and text area
            final separatorX = isRtl
                ? opLeft
                : opLeft + operationIndicatorWidth;
            final separatorPaint = Paint()
              ..color = inputBorderColor
              ..strokeWidth = 0.5;
            canvas.drawLine(
              Offset(separatorX, inputTop + 3),
              Offset(separatorX, inputTop + inputHeight - 3),
              separatorPaint,
            );

            // Display either the typed filter text or the placeholder.
            // The text box hugs the trailing side of the separator in
            // reading order.
            final maxTextWidth =
                inputWidth - operationIndicatorWidth - 28; // room for icon
            if (maxTextWidth > 0) {
              final TextPainter tp;
              if (hasActiveFilter) {
                // Show the actual filter text
                final activeTextStyle =
                    (theme?.cellTextStyle ??
                            const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF212121),
                            ))
                        .copyWith(fontSize: 12);
                tp = ctx.layoutText(
                  TextSpan(text: filterText, style: activeTextStyle),
                  ellipsis: '\u2026',
                  maxWidth: maxTextWidth,
                );
              } else {
                // Show placeholder text: "Filter..."
                tp = ctx.layoutText(
                  TextSpan(text: 'Filter...', style: placeholderStyle),
                  ellipsis: '\u2026',
                  maxWidth: maxTextWidth,
                );
              }
              final textAnchorX = isRtl
                  ? opLeft - 4
                  : inputLeft + operationIndicatorWidth + 4;
              tp.paint(
                canvas,
                Offset(
                  isRtl ? textAnchorX - tp.width : textAnchorX,
                  inputTop + (inputHeight - tp.height) / 2,
                ),
              );
            }

            // Small filter icon (≡ three lines) on the reading-direction
            // trailing side of the input
            final iconRight = isRtl
                ? inputLeft + 8
                : inputLeft + inputWidth - 8;
            final iconCenterY = inputTop + inputHeight / 2;
            const lineWidth = 7.0;

            // Top line
            canvas.drawLine(
              Offset(iconRight - lineWidth, iconCenterY - 3),
              Offset(iconRight, iconCenterY - 3),
              iconPaint,
            );
            // Middle line (shorter)
            canvas.drawLine(
              Offset(iconRight - lineWidth + 1.5, iconCenterY),
              Offset(iconRight - 1.5, iconCenterY),
              iconPaint,
            );
            // Bottom line (shortest)
            canvas.drawLine(
              Offset(iconRight - lineWidth + 3, iconCenterY + 3),
              Offset(iconRight - 3, iconCenterY + 3),
              iconPaint,
            );
          }
        }

        // Right border
        canvas.drawLine(
          Offset(cellRight, filterRowTop),
          Offset(cellRight, filterRowBottom),
          rowBorderPaint,
        );

        offset += colWidth;
      }
    }

    // --- Center section (scrollable, clipped) ---
    canvas.save();
    canvas.clipRect(
      Rect.fromLTWH(
        geom.centerViewportLeft,
        filterRowTop,
        geom.centerViewportWidth,
        ctx.floatingFilterHeight,
      ),
    );
    canvas.drawRect(
      Rect.fromLTWH(
        geom.centerViewportLeft,
        filterRowTop,
        geom.centerViewportWidth,
        ctx.floatingFilterHeight,
      ),
      filterBgPaint,
    );
    paintFilterCells(layout.centerCols, GridSection.center);
    canvas.restore();

    // --- Leading pinned section ---
    if (layout.leftCols.isNotEmpty) {
      canvas.save();
      canvas.clipRect(
        Rect.fromLTWH(
          geom.leadingSectionX,
          filterRowTop,
          layout.leftWidth,
          ctx.floatingFilterHeight,
        ),
      );
      canvas.drawRect(
        Rect.fromLTWH(
          geom.leadingSectionX,
          filterRowTop,
          layout.leftWidth,
          ctx.floatingFilterHeight,
        ),
        filterBgPaint,
      );
      paintFilterCells(layout.leftCols, GridSection.leading);
      canvas.restore();
    }

    // --- Trailing pinned section ---
    if (layout.rightCols.isNotEmpty) {
      canvas.save();
      canvas.clipRect(
        Rect.fromLTWH(
          geom.trailingSectionX,
          filterRowTop,
          layout.rightWidth,
          ctx.floatingFilterHeight,
        ),
      );
      canvas.drawRect(
        Rect.fromLTWH(
          geom.trailingSectionX,
          filterRowTop,
          layout.rightWidth,
          ctx.floatingFilterHeight,
        ),
        filterBgPaint,
      );
      paintFilterCells(layout.rightCols, GridSection.trailing);
      canvas.restore();
    }

    // Bottom border of floating filter row
    canvas.drawLine(
      Offset(0, filterRowBottom),
      Offset(viewportWidth, filterRowBottom),
      rowBorderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant HeaderPainter oldDelegate) {
    return _shouldRepaint(ctx, oldDelegate.ctx);
  }
}

/// Whether any input consumed by the header bands changed between the two
/// contexts. Field set mirrors `GridPaintInputs.sectionFields['header']`
/// (quality program v3 item 5): vertical scroll, row data and selection do
/// not affect header pixels, so pure vertical scrolling skips this layer.
bool _shouldRepaint(GridPaintContext a, GridPaintContext b) {
  // columnWidths is rebuilt per widget build, so compare by content — an
  // identity check would flag every frame (quality program v3 item 7).
  return !identical(a.columns, b.columns) ||
      !listEquals(a.columnWidths, b.columnWidths) ||
      a.theme != b.theme ||
      a.textDirection != b.textDirection ||
      a.textScaler.scale(16) != b.textScaler.scale(16) ||
      a.headerHeight != b.headerHeight ||
      a.groupHeaderHeight != b.groupHeaderHeight ||
      a.floatingFilterHeight != b.floatingFilterHeight ||
      !identical(a.columnGroupSpans, b.columnGroupSpans) ||
      a.sortColumnIndex != b.sortColumnIndex ||
      a.sortAscending != b.sortAscending ||
      !identical(a.sortIndicators, b.sortIndicators) ||
      !identical(a.floatingFilterTexts, b.floatingFilterTexts) ||
      !identical(a.floatingFilterOperations, b.floatingFilterOperations) ||
      a.hoveredColId != b.hoveredColId ||
      a.suppressColumnVirtualisation != b.suppressColumnVirtualisation ||
      a.scrollX != b.scrollX;
}
