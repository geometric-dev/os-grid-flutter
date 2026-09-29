import 'package:flutter/foundation.dart';

import 'grid_painter.dart';

/// Audit utilities for [GridPainter]'s paint inputs.
///
/// Groundwork for quality program v2 item 10 (full dirty-rect tracking):
/// before the painter can be split into per-section painters with their own
/// `shouldRepaint` implementations, every input that can change painted
/// pixels must be enumerable and classifiable.
///
/// Two tools live here:
///
/// - [diff] — names every input on which two painter instances disagree.
///   This is the name-level mirror of [GridPainter.shouldRepaint] and is the
///   single source of truth used by [GridPainter.computeDamageRect] to prove
///   that a frame changed "only" in a restricted way (hover move, focus
///   move, flash tick).
/// - [sectionFields] — an advisory registry mapping each logical grid
///   section to the paint inputs whose pixels it consumes. When the painter
///   split happens, each section painter's `shouldRepaint` compares exactly
///   the fields registered under its key.
///
/// Inputs deliberately excluded from [fieldNames] because they cannot alter
/// painted pixels:
///
/// - `textPainterCache` — cache identity only; swapping it changes
///   performance, never output.
/// - `localeResolver` — semantics labels only (see [GridPainter.diffFrom]).
class GridPaintInputs {
  GridPaintInputs._();

  /// Ordered paint-input specs: `(name, differs)` pairs.
  ///
  /// The first 30 entries follow [GridPainter.shouldRepaint]'s evaluation
  /// order one-to-one; the last four are paint-affecting inputs that
  /// `shouldRepaint` does not (yet) compare but the damage classifier must
  /// know about to stay sound:
  ///
  /// - `focusedRow`/`focusedCol` — focus is not painted today (semantics
  ///   only), but rule coverage keeps the classifier future-proof for when
  ///   a focus ring lands.
  /// - `textScaler`/`textDirection` — compared by
  ///   [GridPainter.shouldRepaint]'s sibling `_identicalExceptHover`, so a
  ///   classifier that ignored them could clip a frame whose text metrics
  ///   or layout direction actually changed everywhere.
  static final List<(String, bool Function(GridPainter, GridPainter))>
  _fields = [
    // --- Fields compared by GridPainter.shouldRepaint (canonical order) ---
    ('scrollX', (a, b) => a.scrollX != b.scrollX),
    ('scrollY', (a, b) => a.scrollY != b.scrollY),
    ('columns', (a, b) => !identical(a.columns, b.columns)),
    ('rowData', (a, b) => !identical(a.rowData, b.rowData)),
    (
      'pinnedTopRowData',
      (a, b) => !listEquals(a.pinnedTopRowData, b.pinnedTopRowData),
    ),
    (
      'pinnedBottomRowData',
      (a, b) => !listEquals(a.pinnedBottomRowData, b.pinnedBottomRowData),
    ),
    (
      'pinnedTopRowStyles',
      (a, b) => !mapEquals(a.pinnedTopRowStyles, b.pinnedTopRowStyles),
    ),
    (
      'pinnedBottomRowStyles',
      (a, b) => !mapEquals(a.pinnedBottomRowStyles, b.pinnedBottomRowStyles),
    ),
    (
      'cellSpanService',
      (a, b) => !identical(a.cellSpanService, b.cellSpanService),
    ),
    ('rowHeight', (a, b) => a.rowHeight != b.rowHeight),
    ('headerHeight', (a, b) => a.headerHeight != b.headerHeight),
    ('theme', (a, b) => a.theme != b.theme),
    ('selectedRows', (a, b) => a.selectedRows != b.selectedRows),
    ('hoveredRow', (a, b) => a.hoveredRow != b.hoveredRow),
    ('hoveredColId', (a, b) => a.hoveredColId != b.hoveredColId),
    // Widths are rebuilt per widget build (fresh List.generate), so the
    // comparison must be content-based: an identity check would flag every
    // frame as a width change and defeat per-section repaint skipping
    // (quality program v3 item 7).
    ('columnWidths', (a, b) => !listEquals(a.columnWidths, b.columnWidths)),
    ('sortColumnIndex', (a, b) => a.sortColumnIndex != b.sortColumnIndex),
    ('sortAscending', (a, b) => a.sortAscending != b.sortAscending),
    (
      'sortIndicators',
      (a, b) => !identical(a.sortIndicators, b.sortIndicators),
    ),
    (
      'columnGroupSpans',
      (a, b) => !identical(a.columnGroupSpans, b.columnGroupSpans),
    ),
    ('groupHeaderHeight', (a, b) => a.groupHeaderHeight != b.groupHeaderHeight),
    (
      'floatingFilterHeight',
      (a, b) => a.floatingFilterHeight != b.floatingFilterHeight,
    ),
    (
      'floatingFilterTexts',
      (a, b) => !identical(a.floatingFilterTexts, b.floatingFilterTexts),
    ),
    (
      'floatingFilterOperations',
      (a, b) =>
          !identical(a.floatingFilterOperations, b.floatingFilterOperations),
    ),
    ('cellRanges', (a, b) => a.cellRanges != b.cellRanges),
    ('rowStyles', (a, b) => a.rowStyles != b.rowStyles),
    ('cellFlashes', (a, b) => a.cellFlashes != b.cellFlashes),
    ('flashElapsed', (a, b) => a.flashElapsed != b.flashElapsed),
    ('rowHeightLayout', (a, b) => a.rowHeightLayout != b.rowHeightLayout),
    (
      'suppressColumnVirtualisation',
      (a, b) =>
          a.suppressColumnVirtualisation != b.suppressColumnVirtualisation,
    ),
    // --- Paint-affecting inputs beyond shouldRepaint ---
    ('textScaler', (a, b) => a.textScaler.scale(16) != b.textScaler.scale(16)),
    ('textDirection', (a, b) => a.textDirection != b.textDirection),
    ('focusedRow', (a, b) => a.focusedRow != b.focusedRow),
    ('focusedCol', (a, b) => a.focusedCol != b.focusedCol),
  ];

  /// Names of every paint input on which [a] and [b] disagree, in canonical
  /// field order.
  ///
  /// Comparison semantics per field intentionally mirror
  /// [GridPainter.shouldRepaint]: identity for columns/rowData and other
  /// instance-owned collaborators, deep equality for pinned row data maps,
  /// and scalar equality elsewhere — see [_fields].
  static List<String> diff(GridPainter a, GridPainter b) {
    return [
      for (final (name, differs) in _fields)
        if (differs(a, b)) name,
    ];
  }

  /// Every audited paint-input name in canonical order.
  static List<String> get fieldNames => _fields
      .map(((String, bool Function(GridPainter, GridPainter)) f) => f.$1)
      .toList();

  /// Advisory registry: logical grid section → paint inputs consumed by
  /// that section's pixels (quality program v2 item 10 groundwork; updated
  /// by item 5 to reflect the per-section painter split).
  ///
  /// Each band painter's `shouldRepaint` compares exactly the fields listed
  /// under its key here. Fields appearing under several keys affect several
  /// sections; cross-cutting inputs (theme, column definitions, text
  /// scaling, direction) are repeated wherever they apply rather than parked
  /// in a catch-all bucket.
  ///
  /// Item-5 updates versus the pre-split registry:
  ///
  /// - `cellRanges`, `hoveredColId`, `cellFlashes` and `flashElapsed` moved
  ///   out of the band keys into the dedicated `range` / `flash` overlay
  ///   keys whose painters now own those pixels.
  /// - `scrollX` added to `pinnedTop`/`footer`: the center-column slice of
  ///   pinned rows scrolls horizontally even though the rows do not scroll
  ///   vertically.
  /// - `scrollbars` key added for the topmost track/thumb layer.
  ///
  /// Bands not named in the deliverable's five sections:
  ///
  /// - `pinnedTop` — the fixed row band above the scrollable body. It is
  ///   neither header nor footer in AG Grid terms, so it gets its own key.
  /// - Viewport size changes repaint every layer via the framework and are
  ///   deliberately not listed.
  ///
  /// Entries MUST be names from [fieldNames]; a test guards this contract.
  static const Map<String, List<String>> sectionFields = {
    // Group-header row + column-header row + floating-filter row.
    'header': [
      'columns',
      'columnWidths',
      'theme',
      'textDirection',
      'textScaler',
      'headerHeight',
      'groupHeaderHeight',
      'floatingFilterHeight',
      'columnGroupSpans',
      'sortColumnIndex',
      'sortAscending',
      'sortIndicators',
      'floatingFilterTexts',
      'floatingFilterOperations',
      'suppressColumnVirtualisation',
      'scrollX',
    ],
    // Leading pinned column band: header slice + fixed data rows.
    'left': [
      'columns',
      'columnWidths',
      'theme',
      'textDirection',
      'textScaler',
      'rowHeight',
      'rowHeightLayout',
      'scrollX',
      'scrollY',
      'rowData',
      'rowStyles',
      'selectedRows',
      'hoveredRow',
      'cellSpanService',
      'suppressColumnVirtualisation',
    ],
    // Scrollable center band: adds horizontal scroll + virtualisation.
    'center': [
      'columns',
      'columnWidths',
      'theme',
      'textDirection',
      'textScaler',
      'rowHeight',
      'rowHeightLayout',
      'scrollX',
      'scrollY',
      'rowData',
      'rowStyles',
      'selectedRows',
      'hoveredRow',
      'cellSpanService',
      'suppressColumnVirtualisation',
    ],
    // Trailing pinned column band: header slice + fixed data rows.
    'right': [
      'columns',
      'columnWidths',
      'theme',
      'textDirection',
      'textScaler',
      'rowHeight',
      'rowHeightLayout',
      'scrollX',
      'scrollY',
      'rowData',
      'rowStyles',
      'selectedRows',
      'hoveredRow',
      'cellSpanService',
      'suppressColumnVirtualisation',
    ],
    // Fixed row band above the scrollable body (AG Grid "pinned top rows").
    'pinnedTop': [
      'columns',
      'columnWidths',
      'theme',
      'textDirection',
      'textScaler',
      'rowHeight',
      'pinnedTopRowData',
      'pinnedTopRowStyles',
      'scrollX',
    ],
    // Fixed row band below the scrollable body ("footer" / pinned bottom).
    'footer': [
      'columns',
      'columnWidths',
      'theme',
      'textDirection',
      'textScaler',
      'rowHeight',
      'pinnedBottomRowData',
      'pinnedBottomRowStyles',
      'scrollX',
    ],
    // Column-hover highlight + cell-range selection overlays.
    'range': [
      'cellRanges',
      'hoveredColId',
      'columns',
      'columnWidths',
      'theme',
      'textDirection',
      'rowHeight',
      'rowHeightLayout',
      'scrollX',
      'scrollY',
      'rowData',
      'pinnedTopRowData',
      'pinnedBottomRowData',
    ],
    // Cell flash highlight overlay (topmost translucent band).
    'flash': [
      'cellFlashes',
      'flashElapsed',
      'columns',
      'columnWidths',
      'theme',
      'textDirection',
      'rowHeight',
      'rowHeightLayout',
      'scrollX',
      'scrollY',
      'rowData',
    ],
    // Scrollbar tracks/thumbs (topmost opaque-ish band). Colours are
    // hardcoded, so theme changes do not invalidate this layer.
    'scrollbars': [
      'scrollX',
      'scrollY',
      'columns',
      'columnWidths',
      'rowHeight',
      'rowHeightLayout',
      'rowData',
      'pinnedTopRowData',
      'pinnedBottomRowData',
    ],
  };
}
