import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../accessibility/grid_semantics.dart';
import '../cache/value_prefetcher.dart' show OsValuePrefetchCallback;
import '../cell_span/cell_span_service.dart';
import '../columns/os_column_def.dart';
import '../render_api/cell_flash.dart';
import '../row_auto_height/row_height_layout.dart';
import '../selection/cell_range.dart';
import '../sorting/sort_indicator_info.dart';
import '../theming/os_grid_theme.dart';
import '../theming/os_row_style.dart';
import 'column_group_layout.dart';
import 'column_layout.dart';
import 'rtl_geometry.dart';
import 'text_painter_cache.dart';

/// Selects which grid section a paint walk iterates, so the shared column
/// x-resolver maps content offsets per reading direction.
enum GridSection { leading, center, trailing }

/// Identifies which pinned band a flashing column belongs to during flash
/// painting and flash damage computation.
enum FlashSection { left, center, right }

/// Immutable snapshot of every paint input feeding the grid renderer.
///
/// Shared by the top-level painter and the per-section painters
/// (`BodyPainter`, `HeaderPainter`, `PinnedRowPainter`, `RangePainter`,
/// `FlashOverlayPainter`, `ScrollbarPainter`) so each focused painter reads
/// the exact same inputs the monolithic painter consumed, and so the layered
/// repaint path (one CustomPaint per section) and the single-canvas path can
/// never disagree about state.
///
/// Instances are cheap value snapshots: building one per paint pass (or per
/// widget build for the layered path) costs a handful of field copies.
///
/// Also hosts the derived helpers every painter needs — directional
/// geometry, column widths, text layout, visible-row window, and the flash
/// cell resolver shared with the damage classifier — so x-mapping and text
/// metrics stay consistent across all sections.
class GridPaintContext {
  /// Creates a snapshot. [textDirection] should be pre-resolved (pass
  /// [TextDirection.ltr] when the ambient direction is null).
  GridPaintContext({
    required this.columns,
    required this.rowData,
    required this.rowHeight,
    required this.headerHeight,
    required this.scrollX,
    required this.scrollY,
    required this.theme,
    required this.selectedRows,
    required this.hoveredRow,
    required this.hoveredColId,
    required this.columnWidths,
    required this.sortColumnIndex,
    required this.sortAscending,
    required this.sortIndicators,
    required this.columnGroupSpans,
    required this.groupHeaderHeight,
    required this.floatingFilterHeight,
    required this.floatingFilterTexts,
    required this.floatingFilterOperations,
    required this.cellRanges,
    required this.rowStyles,
    required this.pinnedTopRowData,
    required this.pinnedBottomRowData,
    required this.pinnedTopRowStyles,
    required this.pinnedBottomRowStyles,
    required this.cellFlashes,
    required this.flashElapsed,
    required this.cellSpanService,
    required this.rowHeightLayout,
    required this.suppressColumnVirtualisation,
    required this.textPainterCache,
    required this.textScaler,
    required this.localeResolver,
    TextDirection? textDirection,
    this.focusedRow = 0,
    this.focusedCol = 0,
    this.valuePrefetch,
    this.onImageLoaded,
  }) : textDirection = textDirection ?? TextDirection.ltr;

  final List<OsColumnDef> columns;
  final List<Map<String, dynamic>> rowData;
  final double rowHeight;
  final double headerHeight;
  final double scrollX;
  final double scrollY;
  final OsGridTheme? theme;
  final Set<int> selectedRows;
  final int? hoveredRow;
  final String? hoveredColId;
  final List<double>? columnWidths;
  final int? sortColumnIndex;
  final bool sortAscending;
  final Map<int, SortIndicatorInfo>? sortIndicators;
  final List<ColumnGroupSpan>? columnGroupSpans;
  final double groupHeaderHeight;
  final double floatingFilterHeight;
  final Map<String, String>? floatingFilterTexts;
  final Map<String, String>? floatingFilterOperations;
  final List<CellRange>? cellRanges;
  final Map<int, OsRowStyle>? rowStyles;
  final List<Map<String, dynamic>> pinnedTopRowData;
  final List<Map<String, dynamic>> pinnedBottomRowData;
  final Map<int, OsRowStyle>? pinnedTopRowStyles;
  final Map<int, OsRowStyle>? pinnedBottomRowStyles;
  final Map<CellPosition, CellFlashState>? cellFlashes;
  final Duration flashElapsed;
  final CellSpanService? cellSpanService;
  final RowHeightLayout? rowHeightLayout;
  final bool suppressColumnVirtualisation;
  final TextPainterCache? textPainterCache;
  final TextScaler textScaler;

  /// Resolves semantics labels (see [buildGridSemantics]). Null = English.
  final OsLocaleResolver? localeResolver;

  /// Resolved (never null) reading direction used by all paint maths.
  final TextDirection textDirection;

  /// The currently focused row index (semantics annotation only).
  final int focusedRow;

  /// The currently focused column index (semantics annotation only).
  final int focusedCol;

  /// Idle-time value-prefetch hook (quality program v3 item 50).
  ///
  /// When non-null, the body painter schedules a microtask after the main
  /// paint completes that invokes this hook with the frame's scroll offset
  /// and visible row window, so the host can pre-compute valueGetter results
  /// for the next viewport-height worth of rows in the scroll direction.
  /// Null unless the grid's `prefetchEnabled` param is set.
  final OsValuePrefetchCallback? valuePrefetch;

  /// Repaint hook for the image cell renderer.
  ///
  /// Fired by the image paint path when an asynchronous load completes
  /// (success or failure), so the host can schedule a repaint and the next
  /// frame blits the decoded pixels from `ImageCellCache`. Null in painter
  /// unit tests — the pixels simply arrive on the next repaint triggered
  /// elsewhere.
  final void Function()? onImageLoaded;

  static const double defaultColumnWidth = 150.0;

  /// Horizontal padding applied either side of cell text.
  static const double cellPaddingH = 12.0;

  /// Whether the reading direction is right-to-left.
  bool get isRtl => textDirection == TextDirection.rtl;

  /// Width of the pinned-column separator stroke.
  double get pinnedBorderWidth => theme?.pinnedColumnBorderWidth ?? 1.0;

  /// Total height of all header rows (group + column + floating filter).
  double get totalHeaderHeight =>
      groupHeaderHeight + headerHeight + floatingFilterHeight;

  /// Total height of pinned top rows.
  double get pinnedTopHeight => pinnedTopRowData.length * rowHeight;

  /// Total height of pinned bottom rows.
  double get pinnedBottomHeight => pinnedBottomRowData.length * rowHeight;

  /// Y offset where the scrollable data area begins.
  double get dataAreaTop => totalHeaderHeight + pinnedTopHeight;

  /// Height of the scrollable data area between the pinned row bands.
  double dataAreaHeightFor(Size size) =>
      size.height - totalHeaderHeight - pinnedTopHeight - pinnedBottomHeight;

  /// Y offset where the pinned bottom rows begin.
  double pinnedBottomTopFor(Size size) => size.height - pinnedBottomHeight;

  /// Effective width of the column at [index].
  double colWidth(int index) {
    final widths = columnWidths;
    if (widths != null && index < widths.length) {
      return widths[index];
    }
    return columns[index].width ?? defaultColumnWidth;
  }

  /// Builds the column layout (split into leading/center/trailing sections).
  ColumnLayout buildLayout() {
    final widths = List.generate(columns.length, colWidth);
    return ColumnLayout(columns: columns, widths: widths);
  }

  /// Builds the shared directional geometry resolver for a paint/hit-test
  /// pass from the resolved direction and section widths.
  RtlGeometry geometry({
    required double viewportWidth,
    required double leftWidth,
    required double rightWidth,
  }) {
    return RtlGeometry.of(
      textDirection,
      viewportWidth: viewportWidth,
      leadingWidth: leftWidth,
      trailingWidth: rightWidth,
    );
  }

  /// Visual left edge of a cell at content [offset] with [width] within
  /// [section]. The ONE mapping used by every painter walk (and mirrored by
  /// VirtualisedGrid hit-testing via [RtlGeometry] directly).
  double colX(
    RtlGeometry geom,
    GridSection section,
    double offset,
    double width,
  ) {
    return switch (section) {
      GridSection.leading => geom.pinnedX(
        sectionX: geom.leadingSectionX,
        sectionWidth: geom.leadingWidth,
        offset: offset,
        width: width,
      ),
      GridSection.center => geom.centerX(
        offset: offset,
        width: width,
        scrollX: scrollX,
      ),
      GridSection.trailing => geom.pinnedX(
        sectionX: geom.trailingSectionX,
        sectionWidth: geom.trailingWidth,
        offset: offset,
        width: width,
      ),
    };
  }

  /// Creates a [TextPainter] for [span] with the active [textScaler] and
  /// resolved reading direction applied, then lays it out.
  ///
  /// Every text layout in every section painter must route through here so
  /// system font scaling and directionality are honoured consistently.
  TextPainter layoutText(
    TextSpan span, {
    int? maxLines = 1,
    String? ellipsis,
    double? maxWidth,
  }) {
    final tp = TextPainter(
      text: span,
      maxLines: maxLines,
      ellipsis: ellipsis,
      textDirection: textDirection,
      textScaler: textScaler,
    );
    tp.layout(maxWidth: maxWidth ?? double.infinity);
    return tp;
  }

  /// First and last visible data row indices for a viewport [size],
  /// honouring variable row heights when a layout is present.
  ({int first, int last}) visibleRowRange(Size size) {
    final dataAreaHeight = dataAreaHeightFor(size);
    final layout = rowHeightLayout;
    if (layout != null) {
      return (
        first: layout.getFirstVisibleRow(scrollY),
        last: layout.getLastVisibleRow(scrollY, dataAreaHeight),
      );
    }
    return (
      first: math.max(0, (scrollY / rowHeight).floor()),
      last: math.min(
        rowData.length - 1,
        ((scrollY + dataAreaHeight) / rowHeight).ceil(),
      ),
    );
  }

  /// Visible center-column range for column virtualisation, or null when
  /// virtualisation is suppressed.
  ({int first, int last})? visibleColumnRange(
    ColumnLayout layout,
    double centerViewportWidth,
  ) {
    if (suppressColumnVirtualisation) return null;
    return layout.getVisibleColumnRange(scrollX, centerViewportWidth);
  }

  /// Builds the colId → (section-local start x, width, section) lookup used
  /// by flash painting and flash damage computation. Each column is keyed by
  /// its effective colId and (when present) its field name.
  Map<String, (double, double, FlashSection)> flashColumnLookup(
    ColumnLayout layout,
  ) {
    final colIdToInfo = <String, (double, double, FlashSection)>{};

    double x = 0;
    for (final entry in layout.leftCols) {
      colIdToInfo[entry.column.effectiveColId] = (
        x,
        entry.width,
        FlashSection.left,
      );
      if (entry.column.field != null) {
        colIdToInfo[entry.column.field!] = (x, entry.width, FlashSection.left);
      }
      x += entry.width;
    }

    x = 0;
    for (final entry in layout.centerCols) {
      colIdToInfo[entry.column.effectiveColId] = (
        x,
        entry.width,
        FlashSection.center,
      );
      if (entry.column.field != null) {
        colIdToInfo[entry.column.field!] = (
          x,
          entry.width,
          FlashSection.center,
        );
      }
      x += entry.width;
    }

    x = 0;
    for (final entry in layout.rightCols) {
      colIdToInfo[entry.column.effectiveColId] = (
        x,
        entry.width,
        FlashSection.right,
      );
      if (entry.column.field != null) {
        colIdToInfo[entry.column.field!] = (x, entry.width, FlashSection.right);
      }
      x += entry.width;
    }

    return colIdToInfo;
  }

  /// Resolves a flashing cell's painted geometry from the shared [lookup].
  ///
  /// Returns the on-canvas rect plus owning section for [position], or null
  /// when the colId is unknown to the layout. Opacity and row-visibility
  /// filtering stay with the callers so painting and damage classification
  /// can apply their own visibility policies.
  ({Rect rect, FlashSection section})? resolveFlashCell(
    CellPosition position,
    Map<String, (double, double, FlashSection)> lookup,
    RtlGeometry geom,
    double dataAreaTop,
  ) {
    final colInfo = lookup[position.colId];
    if (colInfo == null) return null;

    final (colStartX, colWidth, section) = colInfo;
    final rowIndex = position.rowIndex;
    final flashRowHeight = rowHeightLayout?.getRowHeight(rowIndex) ?? rowHeight;
    final flashRowTopOffset =
        rowHeightLayout?.getRowTop(rowIndex) ?? (rowIndex * rowHeight);
    final rowTop = dataAreaTop + flashRowTopOffset - scrollY;

    // Compute cell X position based on section (directional)
    final double cellLeft = switch (section) {
      FlashSection.left => geom.pinnedX(
        sectionX: geom.leadingSectionX,
        sectionWidth: geom.leadingWidth,
        offset: colStartX,
        width: colWidth,
      ),
      FlashSection.center => geom.centerX(
        offset: colStartX,
        width: colWidth,
        scrollX: scrollX,
      ),
      FlashSection.right => geom.pinnedX(
        sectionX: geom.trailingSectionX,
        sectionWidth: geom.trailingWidth,
        offset: colStartX,
        width: colWidth,
      ),
    };

    return (
      rect: Rect.fromLTWH(cellLeft, rowTop, colWidth, flashRowHeight),
      section: section,
    );
  }

  // --- Shared theme colour resolution (identical fallback chain the
  // monolithic painter used) ---

  /// Row/border stroke colour used by cell separators and section borders.
  Color get borderColor =>
      theme?.rowBorderColor ?? theme?.borderColor ?? const Color(0xFFE0E0E0);

  /// Solid background fill for the grid canvas and pinned sections.
  Color get backgroundColor =>
      theme?.backgroundColor ?? const Color(0xFFFFFFFF);

  /// Header band background colour.
  Color get headerBackgroundColor =>
      theme?.headerBackgroundColor ?? const Color(0xFFF5F5F5);

  /// Alternate (odd) row background colour.
  Color get alternateRowColor => theme?.alternateRowColor ?? backgroundColor;

  /// Accent colour used by selection ranges, checkboxes and indicators.
  Color get accentColor => theme?.accentColor ?? const Color(0xFF2196F3);

  /// Default cell text style.
  TextStyle get cellTextStyle =>
      theme?.cellTextStyle ??
      const TextStyle(fontSize: 13, color: Color(0xFF424242));

  /// Default header text style.
  TextStyle get headerTextStyle =>
      theme?.headerTextStyle ??
      const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Color(0xFF212121),
      );
}
