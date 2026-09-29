import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide ScrollbarPainter;

import '../accessibility/grid_semantics.dart';
import '../cell_span/cell_span_service.dart';
import '../columns/os_column_def.dart';
import '../render_api/cell_flash.dart';
import '../row_auto_height/row_height_layout.dart';
import '../selection/cell_range.dart';
import '../sorting/sort_indicator_info.dart';
import '../theming/os_grid_theme.dart';
import '../theming/os_row_style.dart';
import 'body_painter.dart';
import 'column_group_layout.dart';
import 'column_layout.dart';
import 'flash_overlay_painter.dart';
import 'grid_paint_context.dart';
import 'grid_paint_inputs.dart';
import 'header_painter.dart';
import 'pinned_row_painter.dart';
import 'range_painter.dart';
import 'raster_glyph_cache.dart';
import 'rtl_geometry.dart';
import 'scrollbar_painter.dart';
import 'text_painter_cache.dart';

/// Custom painter that renders the grid directly on canvas.
///
/// Mirrors OS Grid's three-section row architecture:
/// - Left pinned columns (fixed position, not affected by horizontal scroll)
/// - Center columns (scrollable, clipped between pinned regions)
/// - Right pinned columns (fixed to right edge)
///
/// Only visible cells are painted for O(visible) performance.
class GridPainter extends CustomPainter {
  GridPainter({
    required this.columns,
    required this.rowData,
    required this.rowHeight,
    required this.headerHeight,
    required this.scrollX,
    required this.scrollY,
    this.theme,
    this.selectedRows = const {},
    this.hoveredRow,
    this.hoveredColId,
    this.columnWidths,
    this.sortColumnIndex,
    this.sortAscending = true,
    this.sortIndicators,
    this.columnGroupSpans,
    this.groupHeaderHeight = 0,
    this.floatingFilterHeight = 0,
    this.floatingFilterTexts,
    this.floatingFilterOperations,
    this.cellRanges,
    this.rowStyles,
    this.pinnedTopRowData = const [],
    this.pinnedBottomRowData = const [],
    this.pinnedTopRowStyles,
    this.pinnedBottomRowStyles,
    this.cellFlashes,
    this.flashElapsed = Duration.zero,
    this.cellSpanService,
    this.rowHeightLayout,
    this.suppressColumnVirtualisation = false,
    this.textPainterCache,
    this.textScaler = TextScaler.noScaling,
    this.localeResolver,
    this.textDirection,
    this.focusedRow = 0,
    this.focusedCol = 0,
  });

  /// Internal seam for the per-section painters (quality program v3 item 5).
  ///
  /// Builds a painter whose input fields mirror [ctx], so a band painter can
  /// extend [GridPainter] — keeping the public entry type visible to the
  /// framework and tests — while painting only its own band. Not intended
  /// for application use; construct the default constructor instead.
  GridPainter.layered(GridPaintContext ctx)
    : this(
        columns: ctx.columns,
        rowData: ctx.rowData,
        rowHeight: ctx.rowHeight,
        headerHeight: ctx.headerHeight,
        scrollX: ctx.scrollX,
        scrollY: ctx.scrollY,
        theme: ctx.theme,
        selectedRows: ctx.selectedRows,
        hoveredRow: ctx.hoveredRow,
        hoveredColId: ctx.hoveredColId,
        columnWidths: ctx.columnWidths,
        sortColumnIndex: ctx.sortColumnIndex,
        sortAscending: ctx.sortAscending,
        sortIndicators: ctx.sortIndicators,
        columnGroupSpans: ctx.columnGroupSpans,
        groupHeaderHeight: ctx.groupHeaderHeight,
        floatingFilterHeight: ctx.floatingFilterHeight,
        floatingFilterTexts: ctx.floatingFilterTexts,
        floatingFilterOperations: ctx.floatingFilterOperations,
        cellRanges: ctx.cellRanges,
        rowStyles: ctx.rowStyles,
        pinnedTopRowData: ctx.pinnedTopRowData,
        pinnedBottomRowData: ctx.pinnedBottomRowData,
        pinnedTopRowStyles: ctx.pinnedTopRowStyles,
        pinnedBottomRowStyles: ctx.pinnedBottomRowStyles,
        cellFlashes: ctx.cellFlashes,
        flashElapsed: ctx.flashElapsed,
        cellSpanService: ctx.cellSpanService,
        rowHeightLayout: ctx.rowHeightLayout,
        suppressColumnVirtualisation: ctx.suppressColumnVirtualisation,
        textPainterCache: ctx.textPainterCache,
        textScaler: ctx.textScaler,
        localeResolver: ctx.localeResolver,
        textDirection: ctx.textDirection,
        focusedRow: ctx.focusedRow,
        focusedCol: ctx.focusedCol,
      );

  final List<OsColumnDef> columns;
  final List<Map<String, dynamic>> rowData;
  final double rowHeight;
  final double headerHeight;
  final double scrollX;
  final double scrollY;
  final OsGridTheme? theme;
  final Set<int> selectedRows;
  final int? hoveredRow;

  /// The colId of the currently hovered column (for column hover highlight).
  ///
  /// When non-null, the painter draws a semi-transparent highlight over all
  /// visible cells in this column (header, floating filter, and data cells).
  final String? hoveredColId;

  final List<double>? columnWidths;
  final int? sortColumnIndex;
  final bool sortAscending;
  final Map<int, SortIndicatorInfo>? sortIndicators;
  final List<ColumnGroupSpan>? columnGroupSpans;
  final double groupHeaderHeight;

  /// Height of the floating filter row (0 when disabled).
  final double floatingFilterHeight;

  /// Current filter text per column (colId → text). When non-empty, the
  /// painted floating filter cell shows the typed text instead of "Filter...".
  final Map<String, String>? floatingFilterTexts;

  /// Current filter operation per column (colId → operation type string).
  /// When set, the floating filter cell shows an operation indicator on the left.
  final Map<String, String>? floatingFilterOperations;

  /// Active cell ranges to paint as highlights (fill + border).
  final List<CellRange>? cellRanges;

  /// Pre-computed row styles keyed by display row index.
  ///
  /// Applied after selection/hover but before alternate row colouring.
  /// Priority: selected > hovered > rowStyles > alternate > default.
  final Map<int, OsRowStyle>? rowStyles;

  /// Rows pinned to the top of the grid (rendered above the scrollable body).
  final List<Map<String, dynamic>> pinnedTopRowData;

  /// Rows pinned to the bottom of the grid (rendered below the scrollable body).
  final List<Map<String, dynamic>> pinnedBottomRowData;

  /// Pre-computed row styles for pinned top rows.
  final Map<int, OsRowStyle>? pinnedTopRowStyles;

  /// Pre-computed row styles for pinned bottom rows.
  final Map<int, OsRowStyle>? pinnedBottomRowStyles;

  /// Active cell flash states, keyed by cell position.
  ///
  /// When non-null and non-empty, the painter overlays a semi-transparent
  /// highlight on flashing cells with opacity derived from [flashElapsed].
  final Map<CellPosition, CellFlashState>? cellFlashes;

  /// Current elapsed time for flash animation calculations.
  ///
  /// Updated by the grid's animation ticker each frame while flashes are
  /// active.
  final Duration flashElapsed;

  /// Cell span service for computing row/col span information.
  ///
  /// When non-null, the painter uses this to skip consumed cells and
  /// extend spanning cells across multiple rows/columns.
  final CellSpanService? cellSpanService;

  /// Optional variable row height layout.
  ///
  /// When provided, overrides the uniform [rowHeight] for row positioning.
  /// Each row can have a different height as determined by the layout.
  final RowHeightLayout? rowHeightLayout;

  /// When true, disables column virtualisation and paints all columns
  /// regardless of horizontal scroll position. Useful for debugging.
  final bool suppressColumnVirtualisation;

  /// Optional TextPainter cache for reusing painters across frames.
  ///
  /// When provided, cell text painters are cached by (rowIndex, colId,
  /// displayValue, style, textScaler) and reused when the display value
  /// hasn't changed, avoiding expensive `TextPainter.layout()` calls on
  /// every frame.
  final TextPainterCache? textPainterCache;

  /// The active text scaler, part of the TextPainter cache key so font-scale
  /// changes invalidate cached painters automatically.
  ///
  /// Note: scaling is not yet applied during layout — threading the scaler
  /// through all layout calls is quality-program-v2 item 8 (W8).
  final TextScaler textScaler;

  /// Resolves semantics labels (see [buildGridSemantics]). Null = English.
  final OsLocaleResolver? localeResolver;

  /// Reading direction for painting, hit-testing parity, and semantics
  /// labels. Null = [TextDirection.ltr].
  ///
  /// Resolved ONCE per paint via [_resolvedDirection] and shared with the
  /// hit-test path through [RtlGeometry] so visuals and interaction can
  /// never disagree (quality program v2 item 48).
  final TextDirection? textDirection;

  /// The currently focused row index (for semantics annotation).
  final int focusedRow;

  /// The currently focused column index (for semantics annotation).
  final int focusedCol;

  /// Resolved reading direction (never null) used by all paint maths.
  TextDirection get _resolvedDirection => textDirection ?? TextDirection.ltr;

  // --- Raster glyph caches (quality program v3 item 6) ---

  /// Total number of pre-rendered paint primitives (checkbox, star-rating,
  /// sparkline frames) currently cached across all raster stores.
  @visibleForTesting
  int get rasterCacheSize => RasterGlyphCache.rasterCacheSize;

  /// Disposes and clears every raster glyph cache.
  @visibleForTesting
  void clearRasterCaches() => RasterGlyphCache.clearRasterCaches();

  /// Builds the shared immutable paint-input snapshot consumed by this
  /// painter and every per-section painter it delegates to (quality program
  /// v3 item 5).
  GridPaintContext _buildContext() {
    return GridPaintContext(
      columns: columns,
      rowData: rowData,
      rowHeight: rowHeight,
      headerHeight: headerHeight,
      scrollX: scrollX,
      scrollY: scrollY,
      theme: theme,
      selectedRows: selectedRows,
      hoveredRow: hoveredRow,
      hoveredColId: hoveredColId,
      columnWidths: columnWidths,
      sortColumnIndex: sortColumnIndex,
      sortAscending: sortAscending,
      sortIndicators: sortIndicators,
      columnGroupSpans: columnGroupSpans,
      groupHeaderHeight: groupHeaderHeight,
      floatingFilterHeight: floatingFilterHeight,
      floatingFilterTexts: floatingFilterTexts,
      floatingFilterOperations: floatingFilterOperations,
      cellRanges: cellRanges,
      rowStyles: rowStyles,
      pinnedTopRowData: pinnedTopRowData,
      pinnedBottomRowData: pinnedBottomRowData,
      pinnedTopRowStyles: pinnedTopRowStyles,
      pinnedBottomRowStyles: pinnedBottomRowStyles,
      cellFlashes: cellFlashes,
      flashElapsed: flashElapsed,
      cellSpanService: cellSpanService,
      rowHeightLayout: rowHeightLayout,
      suppressColumnVirtualisation: suppressColumnVirtualisation,
      textPainterCache: textPainterCache,
      textScaler: textScaler,
      localeResolver: localeResolver,
      textDirection: _resolvedDirection,
      focusedRow: focusedRow,
      focusedCol: focusedCol,
    );
  }

  /// Total height of all header rows (group + column + floating filter).
  double get _totalHeaderHeight =>
      groupHeaderHeight + headerHeight + floatingFilterHeight;

  /// Total height of pinned top rows.
  double get _pinnedTopHeight => pinnedTopRowData.length * rowHeight;

  // --- Dirty-region tracking (quality program v2 item 10) ---

  /// Damage rect computed by the last [shouldRepaint] call. Non-null means
  /// only a classifier-covered slice changed (hover move, focus move, or
  /// flash tick) — paint() restricts its clip to this rect. Null = full
  /// repaint.
  @visibleForTesting
  Rect? get hoverDamageRect => _damageRect;
  Rect? _damageRect;

  /// Size captured by the most recent [paint] call; used by
  /// [shouldRepaint] to compute damage rects without a canvas.
  Size? _lastPaintedSize;

  /// Fields whose sole change the focus damage rule can localise.
  static const Set<String> _focusFields = {'focusedRow', 'focusedCol'};

  /// Fields whose sole change the selection damage rule can localise.
  static const Set<String> _selectionFields = {'selectedRows'};

  /// Above this many rows entering/leaving selection, the band union
  /// degenerates towards the full data area anyway — skip the slice.
  static const int _maxLocalizedSelectionRows = 64;

  /// Names every paint input on which this painter differs from [old].
  ///
  /// Name-level mirror of [shouldRepaint]; see [GridPaintInputs.diff] for
  /// the authoritative field inventory (quality program v2 item 10
  /// groundwork: paint inputs must be auditable before per-section painters
  /// get their own shouldRepaint).
  @visibleForTesting
  List<String> diffFrom(GridPainter old) => GridPaintInputs.diff(old, this);

  /// Minimal rect needing repaint versus [oldDelegate], or null when no
  /// restricted damage can be proven (full repaint).
  ///
  /// Classifier rules, most specific first:
  ///
  /// | Only these fields differ      | No overlays active | Damage rect |
  /// |-------------------------------|--------------------|-------------|
  /// | hoveredRow / hoveredColId     | no flashes/ranges  | union of prev+current hovered row bands and hovered column bands |
  /// | focusedRow/focusedCol         | n/a (not painted)  | union of prev+current focused cell rects |
  /// | selectedRows (≤64 rows in/out)| n/a                | union of bands for every row entering or leaving selection |
  /// | flashElapsed (same flash set) | n/a                | union of flashing cell rects (both ticks) |
  /// | anything else                 | —                  | null |
  ///
  /// Deliberately conservative: any unrecognised difference falls back to a
  /// full repaint so clipping can never drop stale pixels.
  @visibleForTesting
  Rect? computeDamageRect(GridPainter oldDelegate) {
    return _hoverDamageRect(oldDelegate) ??
        _focusDamageRect(oldDelegate) ??
        _selectionDamageRect(oldDelegate) ??
        _flashTickDamageRect(oldDelegate);
  }

  /// Computes the restricted damage rect when ONLY the hover fields
  /// ([hoveredRow]/[hoveredColId]) changed and every other input is
  /// identical with no flash/range overlays active.
  ///
  /// Returns the union of the previous and current hovered row bands and
  /// hovered column bands so all transitions are repainted. Returns null
  /// (full repaint) whenever the change is not a pure hover transition —
  /// deliberately conservative: any overlay activity is excluded from this
  /// slice.
  Rect? _hoverDamageRect(GridPainter oldDelegate) {
    if (oldDelegate.hoveredRow == hoveredRow &&
        oldDelegate.hoveredColId == hoveredColId) {
      return null;
    }
    if (!_identicalExceptHover(oldDelegate)) return null;

    // Scoped slice: flash/range overlays always force a full repaint. The
    // new state matters (overlays appearing) and so does the old one
    // (overlays disappearing alongside a hover change).
    final overlaysActive =
        (cellFlashes != null && cellFlashes!.isNotEmpty) ||
        (oldDelegate.cellFlashes != null &&
            oldDelegate.cellFlashes!.isNotEmpty) ||
        (cellRanges != null && cellRanges!.isNotEmpty) ||
        (oldDelegate.cellRanges != null && oldDelegate.cellRanges!.isNotEmpty);
    if (overlaysActive) return null;

    final size = oldDelegate._lastPaintedSize;
    if (size == null) return null;

    Rect? union;
    if (oldDelegate.hoveredRow != hoveredRow) {
      final prevBand = _hoveredRowBand(oldDelegate.hoveredRow, size);
      final nextBand = _hoveredRowBand(hoveredRow, size);
      union = _clippedUnion([prevBand, nextBand], Offset.zero & size);
    }
    if (oldDelegate.hoveredColId != hoveredColId) {
      final prevBand = _hoveredColumnBand(oldDelegate.hoveredColId, size);
      final nextBand = _hoveredColumnBand(hoveredColId, size);
      final columnUnion = _clippedUnion([
        prevBand,
        nextBand,
      ], Offset.zero & size);
      union = _clippedUnion([union, columnUnion], Offset.zero & size);
    }
    return union;
  }

  /// Whether every painter input EXCEPT the two hover fields matches
  /// [oldDelegate] exactly (mirrors the full [shouldRepaint] condition set).
  bool _identicalExceptHover(GridPainter oldDelegate) {
    return oldDelegate.scrollX == scrollX &&
        oldDelegate.scrollY == scrollY &&
        identical(oldDelegate.columns, columns) &&
        identical(oldDelegate.rowData, rowData) &&
        listEquals(oldDelegate.pinnedTopRowData, pinnedTopRowData) &&
        listEquals(oldDelegate.pinnedBottomRowData, pinnedBottomRowData) &&
        mapEquals(oldDelegate.pinnedTopRowStyles, pinnedTopRowStyles) &&
        mapEquals(oldDelegate.pinnedBottomRowStyles, pinnedBottomRowStyles) &&
        identical(oldDelegate.cellSpanService, cellSpanService) &&
        oldDelegate.rowHeight == rowHeight &&
        oldDelegate.headerHeight == headerHeight &&
        identical(oldDelegate.theme, theme) &&
        setEquals(oldDelegate.selectedRows, selectedRows) &&
        // Widths are rebuilt per widget build, so compare by content — an
        // identity check would flag every frame (quality program v3 item 7).
        listEquals(oldDelegate.columnWidths, columnWidths) &&
        oldDelegate.sortColumnIndex == sortColumnIndex &&
        oldDelegate.sortAscending == sortAscending &&
        identical(oldDelegate.sortIndicators, sortIndicators) &&
        identical(oldDelegate.columnGroupSpans, columnGroupSpans) &&
        oldDelegate.groupHeaderHeight == groupHeaderHeight &&
        oldDelegate.floatingFilterHeight == floatingFilterHeight &&
        identical(oldDelegate.floatingFilterTexts, floatingFilterTexts) &&
        identical(
          oldDelegate.floatingFilterOperations,
          floatingFilterOperations,
        ) &&
        identical(oldDelegate.rowStyles, rowStyles) &&
        identical(oldDelegate.cellFlashes, cellFlashes) &&
        oldDelegate.flashElapsed == flashElapsed &&
        identical(oldDelegate.rowHeightLayout, rowHeightLayout) &&
        oldDelegate.suppressColumnVirtualisation ==
            suppressColumnVirtualisation &&
        identical(oldDelegate.textPainterCache, textPainterCache) &&
        oldDelegate.textScaler.scale(16) == textScaler.scale(16) &&
        oldDelegate.textDirection == textDirection &&
        oldDelegate.focusedRow == focusedRow &&
        oldDelegate.focusedCol == focusedCol;
  }

  /// Full-width canvas band for the hovered [row], or null when no row is
  /// hovered / the band lies entirely outside the painted data area.
  Rect? _hoveredRowBand(int? row, Size size) {
    if (row == null || row < 0 || row >= rowData.length) return null;
    final dataAreaTop = _totalHeaderHeight + _pinnedTopHeight;
    final rowTopOffset = rowHeightLayout?.getRowTop(row) ?? (row * rowHeight);
    final rowHeight_ = rowHeightLayout?.getRowHeight(row) ?? rowHeight;
    final top = dataAreaTop + rowTopOffset - scrollY;
    final bottom = top + rowHeight_;
    if (bottom <= dataAreaTop || top >= size.height) return null;
    return Rect.fromLTRB(0, top, size.width, bottom);
  }

  /// Full-height canvas band for the hovered column [colId], or null when
  /// no column is hovered / the colId resolves to no layout entry (e.g. a
  /// column hidden mid-hover — the highlight painted nothing for it).
  ///
  /// Resolves the column's x-range through the same layout + geometry the
  /// overlay painter uses ([RangePainter._paintColumnHoverInSection]), so
  /// the damage rect always covers every pixel the highlight could occupy.
  /// The band may extend beyond section viewports (the painter clips those
  /// pixels out); a larger damage rect is safe, only a smaller one drops
  /// stale pixels.
  Rect? _hoveredColumnBand(String? colId, Size size) {
    if (colId == null) return null;
    final ctx = _buildContext();
    final layout = ctx.buildLayout();
    final geom = ctx.geometry(
      viewportWidth: size.width,
      leftWidth: layout.leftWidth,
      rightWidth: layout.rightWidth,
    );

    Rect? bandIn(List<ColumnLayoutEntry> cols, GridSection section) {
      var offset = 0.0;
      for (final entry in cols) {
        if (entry.column.effectiveColId == colId) {
          final x = ctx.colX(geom, section, offset, entry.width);
          return Rect.fromLTWH(x, 0, entry.width, size.height);
        }
        offset += entry.width;
      }
      return null;
    }

    return bandIn(layout.leftCols, GridSection.leading) ??
        bandIn(layout.centerCols, GridSection.center) ??
        bandIn(layout.rightCols, GridSection.trailing);
  }

  /// Damage rect when ONLY [focusedRow]/[focusedCol] changed: the union of
  /// the previous and current focused cell rects. Conservative fallbacks to
  /// a full repaint whenever either focus position cannot resolve to an
  /// on-canvas cell rect (out-of-bounds indices — e.g. the -1 "no focus"
  /// sentinel — or nothing painted yet).
  Rect? _focusDamageRect(GridPainter oldDelegate) {
    if (oldDelegate.focusedRow == focusedRow &&
        oldDelegate.focusedCol == focusedCol) {
      return null;
    }
    final changed = GridPaintInputs.diff(oldDelegate, this);
    if (!changed.every(_focusFields.contains)) return null;

    final size = oldDelegate._lastPaintedSize;
    if (size == null) return null;
    final prevRect = _focusedCellRect(
      oldDelegate.focusedRow,
      oldDelegate.focusedCol,
      size,
    );
    final nextRect = _focusedCellRect(focusedRow, focusedCol, size);
    return _clippedUnion([prevRect, nextRect], Offset.zero & size);
  }

  /// Damage rect when ONLY [selectedRows] changed: the union of the row
  /// bands for every row entering or leaving selection.
  ///
  /// Selection only affects per-row body pixels (selected row background and
  /// per-row checkbox glyphs) — the header and pinned-row painters never
  /// read [selectedRows] — so per-row bands always cover every changed
  /// pixel. Rows scrolled off-canvas contribute nothing after clipping.
  ///
  /// Guard rails: requires no other paint input to differ, and falls back to
  /// a full repaint when more than [_maxLocalizedSelectionRows] rows changed
  /// (bulk select/clear — the band union would degenerate to the data area
  /// anyway) or when nothing has been painted yet.
  Rect? _selectionDamageRect(GridPainter oldDelegate) {
    if (identical(oldDelegate.selectedRows, selectedRows)) return null;
    final changed = GridPaintInputs.diff(oldDelegate, this);
    if (!changed.every(_selectionFields.contains)) return null;

    final size = oldDelegate._lastPaintedSize;
    if (size == null) return null;

    final changedRows = selectedRows
        .difference(oldDelegate.selectedRows)
        .union(oldDelegate.selectedRows.difference(selectedRows));
    if (changedRows.length > _maxLocalizedSelectionRows) return null;

    return _clippedUnion([
      for (final row in changedRows) _hoveredRowBand(row, size),
    ], Offset.zero & size);
  }

  /// Damage rect when ONLY [flashElapsed] changed over the SAME flash set:
  /// the union of every visibly flashing cell's rect under BOTH the old and
  /// new elapsed times. The previous tick's rects must be included so a
  /// flash that completed between ticks is erased rather than frozen.
  ///
  /// Requires map identity between the two delegates' [cellFlashes]
  /// (matching shouldRepaint), guaranteeing no cell entered or left the
  /// flashing population — otherwise opacity changes would not be the only
  /// frame difference.
  Rect? _flashTickDamageRect(GridPainter oldDelegate) {
    if (oldDelegate.flashElapsed == flashElapsed) return null;
    if (!identical(oldDelegate.cellFlashes, cellFlashes)) return null;
    final flashes = cellFlashes;
    if (flashes == null || flashes.isEmpty) return null;
    final changed = GridPaintInputs.diff(oldDelegate, this);
    if (changed.any((name) => name != 'flashElapsed')) return null;

    final size = oldDelegate._lastPaintedSize;
    if (size == null) return null;

    // Everything but flashElapsed is proven equal above, so layout and
    // section geometry can be built once from this delegate.
    final ctx = _buildContext();
    final layout = ctx.buildLayout();
    final geom = ctx.geometry(
      viewportWidth: size.width,
      leftWidth: layout.leftWidth,
      rightWidth: layout.rightWidth,
    );
    final lookup = ctx.flashColumnLookup(layout);
    final dataAreaTop = ctx.dataAreaTop;

    Rect? resolveAt(Duration elapsed) {
      final rects = <Rect>[];
      for (final flash in flashes.values) {
        final opacity = flash.opacityAt(elapsed);
        if (opacity == null || opacity <= 0.0) continue;
        final resolved = ctx.resolveFlashCell(
          flash.position,
          lookup,
          geom,
          dataAreaTop,
        );
        if (resolved == null) continue;
        rects.add(resolved.rect);
      }
      return _clippedUnion(rects, Offset.zero & size);
    }

    final prevDamage = resolveAt(oldDelegate.flashElapsed);
    final nextDamage = resolveAt(flashElapsed);
    if (prevDamage == null) return nextDamage;
    if (nextDamage == null) return prevDamage;
    return prevDamage.expandToInclude(nextDamage);
  }

  /// Unions [rects], clipping each against [bounds] first; drops rects that
  /// lie entirely outside the canvas so off-screen cells never inflate the
  /// damage region. Returns null when nothing survives clipping.
  Rect? _clippedUnion(Iterable<Rect?> rects, Rect bounds) {
    Rect? union;
    for (final rect in rects) {
      if (rect == null || !rect.overlaps(bounds)) continue;
      final clipped = rect.intersect(bounds);
      if (clipped.isEmpty) continue;
      union = union?.expandToInclude(clipped) ?? clipped;
    }
    return union;
  }

  /// On-canvas rect for the focused cell at ([row], [col]) under [size],
  /// or null when the position is out of bounds / has no column entry.
  Rect? _focusedCellRect(int row, int col, Size size) {
    if (row < 0 || row >= rowData.length) return null;
    if (col < 0 || col >= columns.length) return null;
    final ctx = _buildContext();
    final layout = ctx.buildLayout();
    final geom = ctx.geometry(
      viewportWidth: size.width,
      leftWidth: layout.leftWidth,
      rightWidth: layout.rightWidth,
    );

    var offset = 0.0;
    for (final entry in layout.leftCols) {
      if (entry.index == col) {
        return _focusedCellRectIn(
          ctx,
          entry.width,
          offset,
          GridSection.leading,
          geom,
          row,
        );
      }
      offset += entry.width;
    }
    offset = 0.0;
    for (final entry in layout.centerCols) {
      if (entry.index == col) {
        return _focusedCellRectIn(
          ctx,
          entry.width,
          offset,
          GridSection.center,
          geom,
          row,
        );
      }
      offset += entry.width;
    }
    offset = 0.0;
    for (final entry in layout.rightCols) {
      if (entry.index == col) {
        return _focusedCellRectIn(
          ctx,
          entry.width,
          offset,
          GridSection.trailing,
          geom,
          row,
        );
      }
      offset += entry.width;
    }
    return null;
  }

  /// Positions a focused cell of [width] at content [offset] within
  /// [section] on display [row].
  Rect _focusedCellRectIn(
    GridPaintContext ctx,
    double width,
    double offset,
    GridSection section,
    RtlGeometry geom,
    int row,
  ) {
    final x = ctx.colX(geom, section, offset, width);
    final dataAreaTop = ctx.dataAreaTop;
    final rowTopOffset =
        ctx.rowHeightLayout?.getRowTop(row) ?? (row * ctx.rowHeight);
    final height = ctx.rowHeightLayout?.getRowHeight(row) ?? ctx.rowHeight;
    return Rect.fromLTWH(
      x,
      dataAreaTop + rowTopOffset - ctx.scrollY,
      width,
      height,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    _lastPaintedSize = size;
    final damage = _damageRect;
    if (damage != null) {
      // Restricted repaint: only the damage rect proven by
      // [computeDamageRect] is redrawn (quality program v2 item 10).
      canvas.save();
      canvas.clipRect(damage);
      _paintCore(canvas, size);
      canvas.restore();
    } else {
      _paintCore(canvas, size);
    }
  }

  void _paintCore(Canvas canvas, Size size) {
    // Each band painter builds its own layout/geometry from the shared
    // context; the orchestration below preserves the monolithic draw order
    // exactly, so compositing them sequentially is pixel-equivalent.
    final ctx = _buildContext();

    // === Body bands (quality program v3 item 5) ===
    // Per-section painter owning the canvas background, the three column
    // sections' backgrounds, and all virtualised data rows (values,
    // formatters, built-in renderers, group rows). Runs FIRST so every other
    // band paints above it, matching the monolithic draw order exactly.
    BodyPainter(ctx).paint(canvas, size);

    // === Header bands (quality program v3 item 5) ===
    // Per-section painter owning every header-band pixel plus the pinned
    // section separator strokes: per-section header backgrounds and cells,
    // pinned separators, group headers, floating filter row and the
    // full-width header bottom border.
    //
    // Painted after the three body sections (data rows never enter the
    // header band, so this ordering is pixel-equivalent to the legacy
    // interleaved sequence) and before the pinned row bands, preserving the
    // legacy draw order exactly.
    HeaderPainter(ctx).paint(canvas, size);

    // === Pinned row bands (quality program v3 item 5) ===
    // Per-section painter owning the pinned top/bottom rows and their full-
    // width separator strokes. Painted after the header bands (its opaque
    // backgrounds cover the lower half of the header bottom border, exactly
    // as the monolithic sequence did) and before the overlay passes.
    PinnedRowPainter(ctx).paint(canvas, size);

    // === Selection overlays (quality program v3 item 5) ===
    // Per-section painter owning the translucent overlay band: the full-
    // height column hover highlight and the cell-range fills/borders, in the
    // same relative order they had in the monolithic sequence.
    RangePainter(ctx).paint(canvas, size);

    // === Cell flash overlays (quality program v3 item 5) ===
    // Flash pass owned by the body painter, run on its own topmost overlay
    // band to preserve the monolithic draw order (flashes above ranges).
    FlashOverlayPainter(ctx).paint(canvas, size);

    // === Scrollbars (quality program v3 item 5) ===
    ScrollbarPainter(ctx).paint(canvas, size);
  }

  @override
  SemanticsBuilderCallback get semanticsBuilder => _buildSemantics;

  List<CustomPainterSemantics> _buildSemantics(Size size) {
    return buildGridSemantics(
      size: size,
      columns: columns,
      rowData: rowData,
      rowHeight: rowHeight,
      headerHeight: headerHeight,
      scrollX: scrollX,
      scrollY: scrollY,
      groupHeaderHeight: groupHeaderHeight.toDouble(),
      floatingFilterHeight: floatingFilterHeight,
      selectedRows: selectedRows,
      focusedRow: focusedRow,
      focusedCol: focusedCol,
      columnWidths: columnWidths,
      sortIndicators: sortIndicators,
      rowHeightLayout: rowHeightLayout,
      localeResolver: localeResolver,
      textDirection: textDirection,
    );
  }

  @override
  bool shouldRebuildSemantics(GridPainter oldDelegate) {
    return oldDelegate.scrollX != scrollX ||
        oldDelegate.scrollY != scrollY ||
        oldDelegate.columns != columns ||
        oldDelegate.rowData != rowData ||
        oldDelegate.selectedRows != selectedRows ||
        oldDelegate.focusedRow != focusedRow ||
        oldDelegate.focusedCol != focusedCol ||
        oldDelegate.sortIndicators != sortIndicators ||
        oldDelegate.rowHeightLayout != rowHeightLayout ||
        oldDelegate.textScaler != textScaler;
  }

  @override
  bool shouldRepaint(GridPainter oldDelegate) {
    // Dirty-region tracking (quality program v2 item 10): try to prove a
    // minimal damage rect first; paint() clips to it when this repaint was
    // triggered solely by classifier-covered fields. The boolean result
    // below stays byte-for-byte equivalent to the pre-item-10 condition set.
    _damageRect = null;
    final damage = computeDamageRect(oldDelegate);

    if (oldDelegate.scrollX != scrollX ||
        oldDelegate.scrollY != scrollY ||
        oldDelegate.columns != columns ||
        oldDelegate.rowData != rowData ||
        !listEquals(oldDelegate.pinnedTopRowData, pinnedTopRowData) ||
        !listEquals(oldDelegate.pinnedBottomRowData, pinnedBottomRowData) ||
        !mapEquals(oldDelegate.pinnedTopRowStyles, pinnedTopRowStyles) ||
        !mapEquals(oldDelegate.pinnedBottomRowStyles, pinnedBottomRowStyles) ||
        !identical(oldDelegate.cellSpanService, cellSpanService) ||
        oldDelegate.rowHeight != rowHeight ||
        oldDelegate.headerHeight != headerHeight ||
        oldDelegate.theme != theme ||
        oldDelegate.selectedRows != selectedRows ||
        oldDelegate.hoveredRow != hoveredRow ||
        oldDelegate.hoveredColId != hoveredColId ||
        !listEquals(oldDelegate.columnWidths, columnWidths) ||
        oldDelegate.sortColumnIndex != sortColumnIndex ||
        oldDelegate.sortAscending != sortAscending ||
        oldDelegate.sortIndicators != sortIndicators ||
        oldDelegate.columnGroupSpans != columnGroupSpans ||
        oldDelegate.groupHeaderHeight != groupHeaderHeight ||
        oldDelegate.floatingFilterHeight != floatingFilterHeight ||
        oldDelegate.floatingFilterTexts != floatingFilterTexts ||
        oldDelegate.floatingFilterOperations != floatingFilterOperations ||
        oldDelegate.cellRanges != cellRanges ||
        oldDelegate.rowStyles != rowStyles ||
        oldDelegate.cellFlashes != cellFlashes ||
        oldDelegate.flashElapsed != flashElapsed ||
        oldDelegate.rowHeightLayout != rowHeightLayout ||
        oldDelegate.suppressColumnVirtualisation !=
            suppressColumnVirtualisation) {
      if (damage != null) _damageRect = damage;
      return true;
    }
    return false;
  }
}
