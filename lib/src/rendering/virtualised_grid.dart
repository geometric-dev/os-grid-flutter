import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' hide ScrollbarPainter;
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart' show OsGrid;
import 'package:os_grid_flutter/src/os_grid.dart' show OsGrid;

import '../cache/value_prefetcher.dart' show OsValuePrefetchCallback;
import '../cell_span/cell_span_service.dart';
import '../columns/os_column_def.dart';
import '../columns/os_column_pin.dart';
import '../events/cell_focus_events.dart';
import '../locale/os_locale_text.dart';
import '../params/navigation_params.dart';
import '../render_api/cell_flash.dart';
import '../row_auto_height/row_height_layout.dart';
import '../scrolling/scroll_command.dart';
import '../selection/cell_range.dart';
import '../sorting/sort_indicator_info.dart';
import '../theming/os_grid_theme.dart';
import '../theming/os_row_style.dart';
import 'body_painter.dart';
import 'column_group_layout.dart';
import 'column_layout.dart';
import 'flash_overlay_painter.dart';
import 'focus_command.dart';
import 'grid_hit_test.dart';
import 'grid_paint_context.dart';
import 'header_painter.dart';
import 'headless_scroll_context.dart';
import 'master_detail.dart';
import 'pinned_row_painter.dart';
import 'range_painter.dart';
import 'rtl_geometry.dart';
import 'scrollbar_painter.dart';
import 'special_columns.dart';
import 'text_painter_cache.dart';

/// Callback signature for cell tap events.
typedef CellTapCallback = void Function(DataCellHit hit);

/// Callback signature for header tap events.
typedef HeaderTapCallback = void Function(HeaderCellHit hit);

/// Callback signature for column resize events.
typedef ColumnResizeCallback = void Function(int columnIndex, double newWidth);

/// Callback for when a column's resize separator is double-clicked.
///
/// The grid's gesture recogniser supplies the time/distance thresholding
/// (a second tap within [kDoubleTapTimeout] and the double-tap slop of the
/// first, on the same separator). [columnIndex] identifies the column whose
/// trailing edge was hit — the column a drag on that separator resizes.
typedef HeaderResizeDoubleTapCallback = void Function(int columnIndex);

/// Callback for when a cell edit is requested (double-tap on editable cell).
/// Returns the Rect of the cell in local coordinates for overlay positioning.
typedef CellEditRequestCallback = void Function(DataCellHit hit, Rect cellRect);

/// Callback for when a keyboard trigger requests editing to start.
///
/// [rowIndex] and [columnIndex] identify the focused cell.
/// [triggerKey] indicates how editing was triggered:
/// - `'enter'`: Enter key — show existing value, select all
/// - `'f2'`: F2 key — show existing value, caret at end
/// - `'delete'`: Delete key — clear cell value directly
/// - `'backspace'`: Backspace key — clear cell value directly
/// - Single character (e.g. `'a'`): printable char — replace with that char
typedef EditStartRequestedCallback =
    void Function(int rowIndex, int columnIndex, String triggerKey);

/// Callback for when a floating filter cell is tapped.
/// Returns the Rect of the filter cell in local coordinates for overlay positioning.
typedef FloatingFilterTapCallback =
    void Function(FloatingFilterCellHit hit, Rect cellRect);

/// Callback for when the operation indicator in a floating filter is tapped.
typedef FloatingFilterOperationTapCallback = void Function(String colId);

/// Callback for when the filter icon in a column header is tapped.
/// Returns the Rect of the filter icon area for popup positioning.
typedef HeaderFilterIconTapCallback =
    void Function(HeaderFilterIconHit hit, Rect iconRect);

/// Callback for when the column menu icon (⋮) in a column header is tapped.
/// Returns the Rect of the menu icon area for popup positioning.
typedef HeaderMenuIconTapCallback =
    void Function(HeaderMenuIconHit hit, Rect iconRect);

/// Callback for when a range drag starts on a data cell.
typedef RangeDragStartCallback = void Function(DataCellHit hit);

/// Callback for when a range drag moves to a new cell position.
typedef RangeDragUpdateCallback = void Function(int rowIndex, int columnIndex);

/// Callback for when a range drag ends.
typedef RangeDragEndCallback = void Function();

/// Callback for when Shift+click extends the current range.
typedef RangeExtendCallback = void Function(int rowIndex, int columnIndex);

/// Callback for when a fill-handle drag ends (quality program v3 item 10).
///
/// Provides the cell the drag was released on; the owning grid infers the
/// fill direction from the active range and writes the fill values.
typedef FillDragCallback = void Function(int rowIndex, int columnIndex);

/// Callback for when a column header drag starts.
typedef ColumnDragStartCallback =
    void Function(
      int columnIndex,
      double startX,
      double scrollX,
      List<double> effectiveWidths,
    );

/// Callback for when a column header drag updates position.
typedef ColumnDragUpdateCallback =
    void Function(double currentX, Offset globalPosition);

/// Callback for when a column header drag ends (drop).
typedef ColumnDragEndCallback = void Function();

/// Callback for when a row drag starts on a drag handle cell.
///
/// [startPosition] is the pointer position (local to the grid) where the
/// drag gesture began.
typedef RowDragStartCallback =
    void Function(int rowIndex, Offset startPosition);

/// Callback for when a row drag updates position.
///
/// [currentPosition] is the pointer position local to the grid — full-bounds
/// drag-out detection needs both axes, not just the vertical one.
typedef RowDragUpdateCallback = void Function(Offset currentPosition);

/// Callback for when a row drag ends (drop).
typedef RowDragEndCallback = void Function();

/// Callback for when a secondary (right-click) tap occurs on a data cell.
/// Provides the hit result and the local position of the tap.
typedef SecondaryTapCallback =
    void Function(GridHitTestResult hit, Offset localPosition);

/// Builds a real widget for a specific data cell, or returns `null` to keep
/// the canvas painting for that cell.
///
/// Called for every visible cell of every rebuild of the paint stack, so it
/// must be cheap; reserve it for columns that declare a widget
/// `cellRenderer`/`cellRendererBuilder`.
typedef CellWidgetBuilder =
    Widget? Function(int rowIndex, int columnIndex, Map<String, dynamic> row);

/// Callback for a tap on the integrated-charts palette button anchored at
/// the active range selection. Provides the button's canvas-space rect so
/// the owner can position the palette popup next to it.
typedef ChartPaletteTapCallback = void Function(Rect anchorRect);

/// Callback for customising keyboard cell-to-cell navigation.
///
/// Return the position to move focus to, or `null` to keep the grid's
/// default movement.
typedef NavigateToNextCellCallback =
    NavCellPosition? Function(NavigateToNextCellParams params);

/// Callback for customising Tab / Shift+Tab navigation.
///
/// Consulted during non-editing focus navigation and after committing an
/// edit with Tab. Return the position to move focus to, or `null` to keep
/// default behaviour.
typedef TabToNextCellCallback =
    NavCellPosition? Function(TabToNextCellParams params);

/// A virtualised grid widget that handles scroll input, column resize,
/// and paints cells directly on canvas for maximum performance.
class VirtualisedGrid extends StatefulWidget {
  const VirtualisedGrid({
    super.key,
    required this.columns,
    required this.rowData,
    this.rowHeight = 42.0,
    this.headerHeight = 48.0,
    this.theme,
    this.selectedRows = const {},
    this.scrollCommandNotifier,
    this.onCellTap,
    this.onCellDoubleTap,
    this.onHeaderTap,
    this.onColumnResize,
    this.onHeaderResizeDoubleTap,
    this.onCentreViewportWidthChanged,
    this.onCellEditRequest,
    this.onEditStartRequested,
    this.onFloatingFilterTap,
    this.onFloatingFilterOperationTap,
    this.onHeaderFilterIconTap,
    this.onHeaderMenuIconTap,
    this.onRangeDragStart,
    this.onRangeDragUpdate,
    this.onRangeDragEnd,
    this.onRangeExtend,
    this.onRangeClear,
    this.onFillDrag,
    this.onColumnDragStart,
    this.onColumnDragUpdate,
    this.onColumnDragEnd,
    this.onRowDragStart,
    this.onRowDragUpdate,
    this.onRowDragEnd,
    this.onSecondaryTap,
    this.onScrollStart,
    this.onHoverChanged,
    this.hoveredRow,
    this.scrollPositionNotifier,
    this.columnWidths,
    this.sortColumnIndex,
    this.sortAscending = true,
    this.sortIndicators,
    this.columnGroupSpans,
    this.groupHeaderHeight = 36,
    this.floatingFilterHeight = 0,
    this.floatingFilterTexts,
    this.floatingFilterOperations,
    this.enableRangeSelection = false,
    this.enableCharts = false,
    this.onChartPaletteTap,
    this.cellRanges,
    this.rowStyles,
    this.enterNavigatesVertically = false,
    this.navigateToNextCell,
    this.tabToNextCell,
    this.isEditing = false,
    this.pinnedTopRowData = const [],
    this.pinnedBottomRowData = const [],
    this.pinnedTopRowStyles,
    this.pinnedBottomRowStyles,
    this.cellFlashes,
    this.flashElapsed = Duration.zero,
    this.onUndoRequested,
    this.onRedoRequested,
    this.onCopyRequested,
    this.onCutRequested,
    this.onPasteRequested,
    this.onContextMenuRequested,
    this.focusedCellNotifier,
    this.focusCommandNotifier,
    this.suppressCellFocus = false,
    this.onCellFocused,
    this.onCellKeyDown,
    this.rowHeightLayout,
    this.detailWidgetBuilder,
    this.cellWidgetBuilder,
    this.cellSpanService,
    this.columnHoverHighlight = false,
    this.suppressColumnVirtualisation = false,
    this.textPainterCache,
    this.localeText,
    this.valuePrefetch,
    this.onImageLoaded,
    this.useScrollController = false,
  });

  final List<OsColumnDef> columns;
  final List<Map<String, dynamic>> rowData;
  final double rowHeight;
  final double headerHeight;
  final OsGridTheme? theme;
  final Set<int> selectedRows;

  /// Notifier for programmatic scroll commands from the controller.
  ///
  /// When a non-null command is set, the grid executes it and resets
  /// the notifier to null.
  final ValueNotifier<ScrollCommand?>? scrollCommandNotifier;

  final CellTapCallback? onCellTap;
  final CellTapCallback? onCellDoubleTap;
  final HeaderTapCallback? onHeaderTap;
  final ColumnResizeCallback? onColumnResize;

  /// Called when a column resize separator is double-clicked (quality
  /// program v3 item 42). The owning grid autosizes the column.
  final HeaderResizeDoubleTapCallback? onHeaderResizeDoubleTap;

  /// Reports the width of the centre (unpinned) viewport — the space the
  /// scrolling columns share once both pinned sections have taken their
  /// share. Fires from layout whenever the value changes, and backs
  /// `controller.sizeColumnsToFit`.
  final ValueChanged<double>? onCentreViewportWidthChanged;
  final CellEditRequestCallback? onCellEditRequest;
  final EditStartRequestedCallback? onEditStartRequested;
  final FloatingFilterTapCallback? onFloatingFilterTap;
  final FloatingFilterOperationTapCallback? onFloatingFilterOperationTap;
  final HeaderFilterIconTapCallback? onHeaderFilterIconTap;
  final HeaderMenuIconTapCallback? onHeaderMenuIconTap;
  final RangeDragStartCallback? onRangeDragStart;
  final RangeDragUpdateCallback? onRangeDragUpdate;
  final RangeDragEndCallback? onRangeDragEnd;
  final RangeExtendCallback? onRangeExtend;
  final VoidCallback? onRangeClear;

  /// Called when a drag that started on the active range's fill handle is
  /// released (quality program v3 item 10). Null disables the handle: it is
  /// never painted and drags on its corner start a normal range selection.
  final FillDragCallback? onFillDrag;
  final ColumnDragStartCallback? onColumnDragStart;
  final ColumnDragUpdateCallback? onColumnDragUpdate;
  final ColumnDragEndCallback? onColumnDragEnd;
  final RowDragStartCallback? onRowDragStart;
  final RowDragUpdateCallback? onRowDragUpdate;
  final RowDragEndCallback? onRowDragEnd;
  final SecondaryTapCallback? onSecondaryTap;
  final VoidCallback? onScrollStart;

  /// Notifier updated with the current scroll position (dx=horizontal, dy=vertical).
  ///
  /// Used by the grid state service to capture scroll position on demand.
  final ValueNotifier<Offset>? scrollPositionNotifier;

  /// Called when the hovered cell/header changes (for tooltip integration).
  ///
  /// Provides the current hit test result and the pointer position in
  /// grid-local coordinates. Called with `null` when the pointer exits.
  final void Function(GridHitTestResult? hit, Offset position)? onHoverChanged;

  final int? hoveredRow;

  /// Override widths per column index (from resize operations).
  final Map<int, double>? columnWidths;

  /// Index of the currently sorted column (for sort indicator painting).
  final int? sortColumnIndex;

  /// Whether the current sort is ascending.
  final bool sortAscending;

  /// Multi-column sort indicators keyed by column index.
  ///
  /// When non-null and non-empty, the painter uses this to show sort arrows
  /// and priority numbers on multiple columns simultaneously.
  final Map<int, SortIndicatorInfo>? sortIndicators;

  /// Column group spans for rendering a group header row.
  final List<ColumnGroupSpan>? columnGroupSpans;

  /// Height of the group header row (only used when columnGroupSpans is set).
  final double groupHeaderHeight;

  /// Height of the floating filter row (0 when disabled).
  final double floatingFilterHeight;

  /// Current filter text per column (colId → text). Used to display typed
  /// text in the painted floating filter cells.
  final Map<String, String>? floatingFilterTexts;

  /// Current filter operation per column (colId → operation type string).
  /// Used to display the operation indicator in the floating filter cells.
  final Map<String, String>? floatingFilterOperations;

  /// Whether range selection is enabled. When true, dragging in the data
  /// area selects cells instead of scrolling.
  final bool enableRangeSelection;

  /// Whether the integrated-charts palette button is drawn at the active
  /// range selection. Requires [enableRangeSelection] and
  /// [onChartPaletteTap]; the palette popup itself is owned by [OsGrid].
  final bool enableCharts;

  /// Fired when the range selection's chart palette button is tapped.
  final ChartPaletteTapCallback? onChartPaletteTap;

  /// Active cell ranges to paint as highlights.
  final List<CellRange>? cellRanges;

  /// Pre-computed row styles keyed by display row index.
  ///
  /// Computed by the parent [OsGrid] widget from [OsGrid.rowStyle] and
  /// [OsGrid.getRowStyle] for visible rows. The painter uses these to
  /// apply per-row background colours and text style overrides.
  final Map<int, OsRowStyle>? rowStyles;

  /// When true, Enter navigates vertically instead of starting editing.
  ///
  /// Matches OS Grid's `enterNavigatesVertically` option.
  final bool enterNavigatesVertically;

  /// Optional callback to customise keyboard cell-to-cell navigation.
  ///
  /// When set, it is consulted for every keyboard navigation move
  /// (arrows, PageUp/PageDown, Home/End). Receives the previous cell, the
  /// default next cell, the key name (`'arrowdown'`, `'pagedown'`, ...) and
  /// whether Shift was held. Return the position to move focus to — it is
  /// clamped to the grid bounds — or return `null` to keep default movement.
  final NavigateToNextCellCallback? navigateToNextCell;

  /// Optional callback to customise Tab / Shift+Tab focus navigation.
  ///
  /// When set, Tab no longer leaves the grid via Flutter's focus traversal;
  /// instead this callback decides where focus moves next. It is consulted
  /// during non-editing navigation and (via the editing coordinator) after
  /// committing an edit with Tab. Return `null` to keep default movement
  /// (one column right, or left with Shift).
  final TabToNextCellCallback? tabToNextCell;

  /// Whether the grid is currently in editing mode.
  ///
  /// When true, keyboard events are not handled by the grid (they go to
  /// the edit overlay instead).
  final bool isEditing;

  /// Rows pinned to the top of the grid (rendered above the scrollable body).
  ///
  /// These rows do not scroll vertically but do scroll horizontally with
  /// the center columns.
  final List<Map<String, dynamic>> pinnedTopRowData;

  /// Rows pinned to the bottom of the grid (rendered below the scrollable body).
  ///
  /// These rows do not scroll vertically but do scroll horizontally with
  /// the center columns.
  final List<Map<String, dynamic>> pinnedBottomRowData;

  /// Pre-computed row styles for pinned top rows, keyed by row index within
  /// the pinned top section.
  final Map<int, OsRowStyle>? pinnedTopRowStyles;

  /// Pre-computed row styles for pinned bottom rows, keyed by row index within
  /// the pinned bottom section.
  final Map<int, OsRowStyle>? pinnedBottomRowStyles;

  /// Active cell flash states, keyed by cell position.
  ///
  /// Rendered by the flash overlay band painter (quality program v3 item 5).
  final Map<CellPosition, CellFlashState>? cellFlashes;

  /// Current elapsed time for flash animation calculations.
  final Duration flashElapsed;

  /// Callback invoked when Ctrl+Z (Cmd+Z on macOS) is pressed.
  final VoidCallback? onUndoRequested;

  /// Callback invoked when Ctrl+Y (Cmd+Y on macOS) is pressed.
  final VoidCallback? onRedoRequested;

  /// Callback invoked when Ctrl+C (Cmd+C on macOS) is pressed.
  final VoidCallback? onCopyRequested;

  /// Callback invoked when Ctrl+X (Cmd+X on macOS) is pressed.
  final VoidCallback? onCutRequested;

  /// Callback invoked when Ctrl+V (Cmd+V on macOS) is pressed.
  final VoidCallback? onPasteRequested;

  /// Callback invoked when Shift+F10 or the ContextMenu key is pressed.
  ///
  /// Provides the focused row and column indices so the context menu can
  /// be positioned at the focused cell.
  final void Function(int rowIndex, int colIndex)? onContextMenuRequested;

  /// Notifier updated with the current focused cell position.
  ///
  /// Used by the parent widget to determine the focused cell for clipboard
  /// operations and other features that need focus awareness.
  final ValueNotifier<({int row, int col})>? focusedCellNotifier;

  /// Notifier for programmatic focus commands from the controller
  /// (`setFocusedCell` / `clearFocusedCell`).
  ///
  /// When a non-null command is set, the grid executes it and resets
  /// the notifier to null.
  final ValueNotifier<FocusCommand?>? focusCommandNotifier;

  /// When true, tapping a data cell never requests keyboard focus and the
  /// visual focus cursor stays parked where it was (pointer interaction
  /// does not move it). Programmatic focus via [focusCommandNotifier] and
  /// keyboard navigation on an already-focused grid still work.
  final bool suppressCellFocus;

  /// Called post-frame whenever the focused cell changes due to keyboard
  /// navigation, pointer-down focus, or a programmatic focus command.
  ///
  /// Clearing the focus does not fire this callback.
  final void Function(OsCellFocusedEvent event)? onCellFocused;

  /// Called post-frame when a printable or navigation key is pressed while
  /// a cell is focused and the grid is not editing.
  ///
  /// Fires before built-in key handling; listeners cannot consume the key.
  final void Function(OsCellKeyDownEvent event)? onCellKeyDown;

  /// Optional variable row height layout.
  ///
  /// When provided, overrides the uniform [rowHeight] for row positioning,
  /// hit testing, and scroll calculations. Each row can have a different
  /// height as determined by the layout.
  final RowHeightLayout? rowHeightLayout;

  /// Builds the widget content of a master row's detail area (quality
  /// program v3 item 4).
  ///
  /// Called for every visible synthetic detail row (marked
  /// [MasterDetailKeys.isDetailRow] in [rowData]); the returned widget is
  /// positioned over the detail row's rect in an overlay above the canvas
  /// bands, clipped to the scrollable data area. Null disables detail
  /// overlays entirely.
  ///
  /// The owning [OsGrid] adapts its typed
  /// `detailWidgetBuilder(data, rowIndex)` to this map-based callback.
  final Widget Function(Map<String, dynamic> detailRow)? detailWidgetBuilder;

  /// Overlay builder for hybrid widget cells.
  ///
  /// When non-null, the returned widgets are positioned over their cell
  /// rects in an overlay band above the canvas (below scrollbars and the
  /// master/detail band), clipped to the scrollable data area, and
  /// repositioned on every scroll rebuild. Cells whose builder returns
  /// `null` keep their canvas painting.
  final CellWidgetBuilder? cellWidgetBuilder;

  /// Cell span service for computing row/col span information.
  ///
  /// When non-null, the painter uses this to skip consumed cells and
  /// extend spanning cells across multiple rows/columns.
  final CellSpanService? cellSpanService;

  /// Whether to highlight the entire column on hover.
  ///
  /// When `true`, the grid tracks which column the pointer is over and
  /// paints a semi-transparent highlight across all visible cells in that
  /// column.
  final bool columnHoverHighlight;

  /// When true, disables column virtualisation and paints all columns
  /// regardless of horizontal scroll position. Useful for debugging.
  final bool suppressColumnVirtualisation;

  /// Resolves semantics/container labels. Null = English defaults.
  final OsLocaleText? localeText;

  /// Idle-time value-prefetch hook (quality program v3 item 50).
  ///
  /// Forwarded onto the paint context; when non-null the body painter
  /// schedules a microtask after each paint so the owning grid can warm the
  /// value cache for the next viewport-height worth of rows in the scroll
  /// direction.
  final OsValuePrefetchCallback? valuePrefetch;

  /// Repaint hook for the image cell renderer.
  ///
  /// Forwarded onto the paint context; fired when an image cell's
  /// asynchronous load completes so the owning grid can schedule a repaint
  /// and the next frame blits the decoded pixels.
  final void Function()? onImageLoaded;

  /// Optional TextPainter cache for reusing painters across frames.
  ///
  /// Owned by the parent widget (or its state) and passed through to the
  /// painter. The cache persists across repaints, avoiding expensive
  /// `TextPainter.layout()` calls for unchanged cells.
  final TextPainterCache? textPainterCache;

  /// When true, vertical scrolling is driven by a real [ScrollController]
  /// + [ScrollPosition] (quality program v2 item 45 spike) instead of the
  /// hand-managed offset double.
  ///
  /// The position is headless — there is no `Scrollable` widget in the
  /// tree: wrapping the single-canvas grid in a viewport was evaluated and
  /// rejected, since the grid owns its own scroll geometry. Wheel, pan,
  /// fling, scrollbar, keyboard and ensure-visible vertical scrolling all
  /// route through the controller, so ballistic fling physics come from
  /// [ClampingScrollPhysics] rather than the hand-rolled decay ticker.
  /// Painting, hit-testing, horizontal scrolling and pinned sections are
  /// byte-identical to the default (`false`) path.
  ///
  /// Defaults to false so all existing behaviour is unchanged.
  final bool useScrollController;

  @override
  VirtualisedGridState createState() => VirtualisedGridState();
}

/// State for [VirtualisedGrid].
///
/// Exposed (rather than private) so tests can read performance
/// instrumentation counters; not part of the public package API.
class VirtualisedGridState extends State<VirtualisedGrid>
    with TickerProviderStateMixin {
  // --- Vertical scroll offset (quality program v2 item 45 spike) ---
  //
  // `_scrollY` reads/writes either the manual double (flag off) or the
  // headless ScrollPosition's pixels (flag on). Every existing reader
  // (painter, hit-testing, scrollbar maths) is untouched; writers route
  // through the setter so both modes share one call site.

  /// Manual vertical offset — used only when `useScrollController` is false
  /// or before the headless position exists.
  double _manualScrollY = 0.0;

  ScrollController? _scrollController;
  ScrollPositionWithSingleContext? _scrollPosition;
  Drag? _activeScrollDrag;

  bool get _useHeadlessScroll =>
      widget.useScrollController && _scrollPosition != null;

  double get _scrollY =>
      _useHeadlessScroll ? _scrollPosition!.pixels : _manualScrollY;

  set _scrollY(double value) {
    final double clamped = value.clamp(0.0, math.max(0.0, _maxScrollY));
    if (_useHeadlessScroll) {
      if (_scrollPosition!.pixels != clamped) {
        _scrollPosition!.jumpTo(clamped);
      }
    } else if (_manualScrollY != clamped) {
      _manualScrollY = clamped;
    }
  }

  /// Creates the headless [ScrollController] + [ScrollPositionWithSingleContext]
  /// when `useScrollController` is enabled and they do not exist yet.
  void _ensureHeadlessScroll() {
    if (_scrollPosition != null) return;
    final scrollContext = HeadlessScrollContext(vsync: this, context: context);
    final controller = ScrollController();
    final position = ScrollPositionWithSingleContext(
      physics: const ClampingScrollPhysics(),
      context: scrollContext,
      initialPixels: _manualScrollY,
      keepScrollOffset: false,
      debugLabel: 'VirtualisedGrid.vertical',
    );
    controller.attach(position);
    position.addListener(_onHeadlessScrollChanged);
    _scrollController = controller;
    _scrollPosition = position;
  }

  /// Tears down the headless scroll machinery, migrating the current offset
  /// back into the manual double when the flag flips at runtime.
  void _teardownHeadlessScroll() {
    if (_scrollPosition == null) return;
    _stopFling();
    _manualScrollY = _scrollPosition!.pixels.clamp(
      0.0,
      math.max(0.0, _maxScrollY),
    );
    _scrollController!.detach(_scrollPosition!);
    _scrollPosition!.dispose();
    _scrollController!.dispose();
    _scrollPosition = null;
    _scrollController = null;
  }

  /// Applies viewport/content extents to the headless position.
  ///
  /// Called from [build] only: corrections are silent (`correctPixels`),
  /// never notifying, so this is safe inside layout/build phases.
  void _syncHeadlessScrollExtents() {
    final position = _scrollPosition!;
    final dataAreaHeight =
        _viewportSize.height -
        _totalHeaderHeight -
        _pinnedTopHeight -
        _pinnedBottomHeight;
    position.applyViewportDimension(math.max(0.0, dataAreaHeight));
    if (!position.applyContentDimensions(0.0, _maxScrollY)) {
      // Pixels were corrected for shrunken content; finish applying dims.
      position.applyContentDimensions(0.0, _maxScrollY);
    }
  }

  /// Repaints on every headless-position change (drag updates, ballistic
  /// frames, wheel jumps) and keeps the scroll-position notifier in sync.
  void _onHeadlessScrollChanged() {
    if (!mounted) return;
    widget.scrollPositionNotifier?.value = Offset(_scrollX, _scrollY);
    setState(() {});
  }

  double _scrollX = 0.0;
  Size _viewportSize = Size.zero;

  /// Last centre-viewport width handed to
  /// [VirtualisedGrid.onCentreViewportWidthChanged], so layout only writes
  /// the owner's field when the value actually moves.
  double? _lastReportedCentreWidth;

  /// Ambient reading direction, resolved once per [build] and reused by all
  /// gesture/hit-test handlers (which run outside build) so pointer mapping
  /// and painting share the exact same directional geometry (item 48).
  TextDirection _direction = TextDirection.ltr;

  /// Builds the shared directional x-resolver from the current layout —
  /// the SAME class the painter uses, guaranteeing hit-test parity.
  RtlGeometry _geometry(ColumnLayout layout) {
    return RtlGeometry.of(
      _direction,
      viewportWidth: _viewportSize.width,
      leadingWidth: layout.leftWidth,
      trailingWidth: layout.rightWidth,
    );
  }

  /// Hover position routed through a [ValueNotifier] so pointer moves
  /// repaint only the grid's paint layer (via a scoped rebuild of
  /// [CustomPaint]) instead of rebuilding the widget subtree.
  final ValueNotifier<({int? row, String? col})> _hoverNotifier =
      ValueNotifier<({int? row, String? col})>((row: null, col: null));

  /// Mouse cursor routed through a [ValueNotifier] so cursor transitions
  /// rebuild only the [MouseRegion] wrapper, keeping the child subtree
  /// instance-stable.
  final ValueNotifier<SystemMouseCursor> _cursorNotifier =
      ValueNotifier<SystemMouseCursor>(SystemMouseCursors.basic);

  // --- ColumnLayout memoization (quality program v2 item 20) ---

  ColumnLayout? _cachedLayout;
  List<OsColumnDef>? _cachedLayoutColumns;
  List<double>? _cachedLayoutWidths;
  double? _cachedLayoutViewportWidth;
  int _layoutCacheHits = 0;
  int _layoutCacheMisses = 0;

  /// Number of [ColumnLayout] cache hits (test instrumentation).
  @visibleForTesting
  int get layoutCacheHits => _layoutCacheHits;

  /// Number of [ColumnLayout] cache misses (test instrumentation).
  @visibleForTesting
  int get layoutCacheMisses => _layoutCacheMisses;

  /// Number of times [build] ran (test instrumentation used to assert that
  /// hover moves do not rebuild the widget subtree).
  @visibleForTesting
  int buildCount = 0;

  /// Current vertical scroll offset (test instrumentation for the
  /// item-45 ScrollController spike).
  @visibleForTesting
  double get currentScrollY => _scrollY;

  /// Current horizontal scroll offset (test instrumentation).
  @visibleForTesting
  double get currentScrollX => _scrollX;

  /// Whether vertical scrolling is currently routed through the headless
  /// [ScrollController] (test instrumentation).
  @visibleForTesting
  bool get usesControllerScrolling => _useHeadlessScroll;

  /// The headless [ScrollController], when active (test instrumentation).
  @visibleForTesting
  ScrollController? get debugScrollController => _scrollController;

  /// Shorthand for the widget-supplied locale resolver source.
  OsLocaleText? get _localeText => widget.localeText;

  /// Returns the memoized [ColumnLayout], rebuilding it only when the column
  /// definitions identity, resolved widths, or viewport width changed since
  /// the last call. Gesture/hover handlers call this many times per event;
  /// the cached instance keeps those paths allocation-free.
  ColumnLayout _getLayout() {
    final columns = widget.columns;
    final widths = List.generate(columns.length, _getColumnWidth);
    final viewportWidth = _viewportSize.width;
    final cachedColumns = _cachedLayoutColumns;
    final cachedWidths = _cachedLayoutWidths;
    if (_cachedLayout != null &&
        identical(cachedColumns, columns) &&
        cachedWidths != null &&
        _listsEqual(cachedWidths, widths) &&
        _cachedLayoutViewportWidth == viewportWidth) {
      _layoutCacheHits++;
      return _cachedLayout!;
    }

    _layoutCacheMisses++;
    final layout = ColumnLayout(columns: columns, widths: widths);
    _cachedLayout = layout;
    _cachedLayoutColumns = columns;
    _cachedLayoutWidths = widths;
    _cachedLayoutViewportWidth = viewportWidth;
    return layout;
  }

  static bool _listsEqual(List<double> a, List<double> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Width of the centre (unpinned) section: the viewport minus whatever
  /// the left and right pinned sections occupy. Never negative — a grid
  /// narrower than its pinned columns still reports zero rather than a
  /// negative space to distribute.
  double _centreViewportWidth() {
    final layout = _getLayout();
    final width = _viewportSize.width - layout.leftWidth - layout.rightWidth;
    return width > 0 ? width : 0.0;
  }

  // --- Fling (ballistic) scroll state (quality program v2 item 9) ---

  Ticker? _flingTicker;
  Duration _flingLastElapsed = Duration.zero;
  double _flingVelocityX = 0.0;
  double _flingVelocityY = 0.0;

  // Pan velocity estimate (px/s) accumulated across drag-update events.
  double _panVelocityX = 0.0;
  double _panVelocityY = 0.0;
  Duration? _lastPanMoveTime;
  int _panVelocitySamples = 0;

  /// Exponential decay constant (per second): velocity shrinks by e^-4 each
  /// second (~87% loss over 500ms), giving a natural glide-to-stop feel.
  static const double _flingDecayRate = 4.0;

  /// Speed (px/s) below which the ballistic scroll stops.
  static const double _flingEpsilon = 40.0;

  /// Minimum estimated release speed (px/s) required to start a fling, so
  /// slow deliberate drags never glide.
  static const double _flingMinStartVelocity = 350.0;

  /// Smoothing weight of the newest velocity sample in the pan EMA.
  static const double _panVelocitySmoothing = 0.6;

  /// Whether a ballistic (fling) scroll is currently running.
  @visibleForTesting
  bool get isFlingActive => _flingTicker?.isActive ?? false;

  /// Current fling velocity in px/s (test instrumentation).
  @visibleForTesting
  ({double x, double y}) get flingVelocity =>
      (x: _flingVelocityX, y: _flingVelocityY);

  // Column resize state
  int? _resizingColumnIndex;
  double _resizeStartX = 0.0;
  double _resizeStartWidth = 0.0;
  final Map<int, double> _localColumnWidths = {};

  // Keyboard navigation
  int _focusedRow = 0;
  int _focusedCol = 0;
  final FocusNode _focusNode = FocusNode();

  // Scrollbar drag state
  _ScrollbarDrag? _scrollbarDrag;

  // Range selection drag state
  bool _isRangeDragging = false;

  // Fill handle drag state (quality program v3 item 10)
  bool _isFillDragging = false;

  /// Cell the fill drag pointer is currently over; the fill is applied once
  /// when the drag ends.
  ({int row, int col})? _fillDragEndCell;

  /// Position of the most recent pointer-down event (canvas space).
  ///
  /// The fill-handle hit test uses this instead of the pan-start details:
  /// with [DragStartBehavior.start] the pan callback reports the position
  /// only after the slop move, which can already have left the 8×8 handle
  /// square.
  Offset? _pointerDownPosition;

  /// Side length of the square fill-handle hit zone. Must match
  /// [RangePainter.fillHandleSize].
  static const double _fillHandleSize = RangePainter.fillHandleSize;

  // Column header drag state
  bool _isColumnDragging = false;
  int? _pendingDragColumnIndex;
  double _pendingDragStartX = 0.0;
  static const double _columnDragThreshold = 5.0;

  // Row drag state
  bool _isRowDragging = false;
  int? _pendingDragRowIndex;
  double _pendingDragStartY = 0.0;
  Offset _pendingDragStartPosition = Offset.zero;
  static const double _rowDragThreshold = 5.0;

  // Row drag edge auto-scroll: while a row drag is active, holding the
  // pointer inside an edge zone of the data area scrolls the grid, so long
  // drags can reach rows beyond the current viewport (same pattern as the
  // row group panel's horizontal auto-scroll).
  static const double _rowDragEdgeZone = 30.0;
  static const double _rowDragAutoScrollStep = 6.0;
  Timer? _rowDragAutoScrollTimer;
  double _rowDragAutoScrollDelta = 0.0;
  Offset _lastRowDragPosition = Offset.zero;

  /// Current vertical scroll offset. Exposed for widget tests.
  @visibleForTesting
  double get scrollY => _scrollY;

  @override
  void initState() {
    super.initState();
    widget.scrollCommandNotifier?.addListener(_onScrollCommand);
    widget.focusCommandNotifier?.addListener(_onFocusCommand);
    _focusNode.addListener(_onFocusChanged);
  }

  void _onFocusChanged() {
    setState(() {});
  }

  @override
  void didUpdateWidget(covariant VirtualisedGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.scrollCommandNotifier != oldWidget.scrollCommandNotifier) {
      oldWidget.scrollCommandNotifier?.removeListener(_onScrollCommand);
      widget.scrollCommandNotifier?.addListener(_onScrollCommand);
    }
    if (widget.focusCommandNotifier != oldWidget.focusCommandNotifier) {
      oldWidget.focusCommandNotifier?.removeListener(_onFocusCommand);
      widget.focusCommandNotifier?.addListener(_onFocusCommand);
    }
    // Toggling the item-45 spike flag off at runtime migrates the offset
    // back to manual management; toggling on is picked up lazily in build.
    if (!widget.useScrollController && oldWidget.useScrollController) {
      _teardownHeadlessScroll();
      setState(() {});
    }
    _dropSupersededLocalWidths(oldWidget);
  }

  /// Drops local drag overrides that an external width change supersedes.
  ///
  /// `_localColumnWidths` holds the live value while a resize drag is in
  /// progress and keeps serving that value afterwards, so a column resized
  /// by dragging would silently ignore later `setColumnWidths`,
  /// `autoSizeColumns` or `sizeColumnsToFit` calls. An override is dropped
  /// when the incoming width map changes that index's width, or withdraws
  /// the width entry entirely (a runtime column-definition swap pruning a
  /// removed column, so its override cannot land on a new column at the
  /// same index). A drag in flight is unaffected: the coordinator only
  /// writes the final width when the drag ends.
  void _dropSupersededLocalWidths(VirtualisedGrid oldWidget) {
    if (_localColumnWidths.isEmpty) return;
    final incoming = widget.columnWidths;
    if (incoming == null) return;
    final previous = oldWidget.columnWidths;
    if (identical(previous, incoming)) return;

    _localColumnWidths.removeWhere((index, localWidth) {
      if (index >= incoming.length) return false;
      final newWidth = incoming[index];
      if (newWidth == null) {
        // The override was withdrawn for this index.
        return previous != null &&
            index < previous.length &&
            previous[index] != null;
      }
      return newWidth != localWidth;
    });
  }

  void _onScrollCommand() {
    final command = widget.scrollCommandNotifier?.value;
    if (command == null) return;

    setState(() {
      switch (command) {
        case EnsureColumnVisibleCommand():
          _executeEnsureColumnVisible(command.columnIndex, command.position);
        case EnsureIndexVisibleCommand():
          _executeEnsureIndexVisible(command.rowIndex, command.position);
        case SetHorizontalScrollCommand():
          _scrollX = command.offset.clamp(0.0, _maxScrollX);
      }
    });

    // Reset the notifier so the same command isn't re-executed on rebuild.
    widget.scrollCommandNotifier?.value = null;
  }

  /// Executes a focus command from [VirtualisedGrid.focusCommandNotifier]
  /// (programmatic `setFocusedCell` / `clearFocusedCell`), then resets the
  /// notifier to null.
  void _onFocusCommand() {
    final command = widget.focusCommandNotifier?.value;
    if (command == null) return;

    switch (command) {
      case SetFocusedCellCommand():
        _applyExternalFocus(command.rowIndex, command.columnIndex);
      case ClearFocusedCellCommand():
        _parkVisualFocus();
    }

    // Reset the notifier so the same command isn't re-executed on rebuild.
    widget.focusCommandNotifier?.value = null;
  }

  /// Applies a programmatic focus change: clamps to grid bounds, scrolls
  /// the target into view, and notifies listeners.
  void _applyExternalFocus(int rowIndex, int columnIndex) {
    final rowCount = widget.rowData.length;
    final colCount = widget.columns.length;
    if (rowCount == 0 || colCount == 0) return;

    final row = math.max(0, math.min(rowIndex, rowCount - 1));
    final col = math.max(0, math.min(columnIndex, colCount - 1));

    setState(() {
      _focusedRow = row;
      _focusedCol = col;
      _ensureRowVisible(row);
      _ensureColumnVisible(col);
    });
    _updateFocusedCellNotifier();
    _scheduleCellFocused(row, col);
  }

  /// Parks the visual focus cursor without notifying the focused-cell
  /// notifier — the controller's focused-cell value is retained until the
  /// next real focus change.
  void _parkVisualFocus() {
    if (_focusedRow < 0 && _focusedCol < 0) return;
    setState(() {
      _focusedRow = -1;
      _focusedCol = -1;
    });
  }

  /// Executes a column scroll command with the given position strategy.
  void _executeEnsureColumnVisible(
    int columnIndex,
    ColumnScrollPosition position,
  ) {
    final layout = _getLayout();

    // If the column is pinned, it's always visible — no-op.
    for (final entry in layout.leftCols) {
      if (entry.index == columnIndex) return;
    }
    for (final entry in layout.rightCols) {
      if (entry.index == columnIndex) return;
    }

    // Find the column's position within the center section.
    double colStart = 0.0;
    double colWidth = 0.0;
    bool found = false;
    for (final entry in layout.centerCols) {
      if (entry.index == columnIndex) {
        colWidth = entry.width;
        found = true;
        break;
      }
      colStart += entry.width;
    }
    if (!found) return;

    final centerViewportWidth =
        _viewportSize.width - layout.leftWidth - layout.rightWidth;
    final colEnd = colStart + colWidth;

    switch (position) {
      case ColumnScrollPosition.auto:
        // Only scroll if the column is outside the viewport.
        if (colStart < _scrollX) {
          _scrollX = colStart;
        } else if (colEnd > _scrollX + centerViewportWidth) {
          _scrollX = colEnd - centerViewportWidth;
        }
        // If column is wider than viewport, align to start.
        if (colWidth > centerViewportWidth) {
          _scrollX = colStart;
        }
      case ColumnScrollPosition.start:
        _scrollX = colStart;
      case ColumnScrollPosition.middle:
        final colMiddle = colStart + colWidth / 2;
        _scrollX = colMiddle - centerViewportWidth / 2;
      case ColumnScrollPosition.end:
        _scrollX = colEnd - centerViewportWidth;
    }

    _scrollX = _scrollX.clamp(0.0, _maxScrollX);
  }

  /// Executes a row scroll command with the given position strategy.
  void _executeEnsureIndexVisible(int rowIndex, RowScrollPosition? position) {
    final rowCount = widget.rowData.length;
    if (rowIndex < 0 || rowIndex >= rowCount) return;

    final dataAreaHeight =
        _viewportSize.height -
        _totalHeaderHeight -
        _pinnedTopHeight -
        _pinnedBottomHeight;
    final rowTop = _getRowTop(rowIndex);
    final rowHeight = _getRowHeight(rowIndex);
    final rowBottom = rowTop + rowHeight;

    if (position == null) {
      // Auto: only scroll if the row is outside the viewport.
      if (rowTop < _scrollY) {
        _scrollY = rowTop;
      } else if (rowBottom > _scrollY + dataAreaHeight) {
        _scrollY = rowBottom - dataAreaHeight;
      }
    } else {
      switch (position) {
        case RowScrollPosition.top:
          _scrollY = rowTop;
        case RowScrollPosition.middle:
          final rowMiddle = rowTop + rowHeight / 2;
          _scrollY = rowMiddle - dataAreaHeight / 2;
        case RowScrollPosition.bottom:
          _scrollY = rowBottom - dataAreaHeight;
      }
    }

    _scrollY = _scrollY.clamp(0.0, _maxScrollY);
  }

  double _getColumnWidth(int index) {
    return _localColumnWidths[index] ??
        widget.columnWidths?[index] ??
        widget.columns[index].width ??
        150.0;
  }

  double get _totalHeaderHeight =>
      widget.headerHeight +
      (widget.columnGroupSpans != null ? widget.groupHeaderHeight : 0) +
      widget.floatingFilterHeight;

  double get _pinnedTopHeight =>
      widget.pinnedTopRowData.length * widget.rowHeight;

  double get _pinnedBottomHeight =>
      widget.pinnedBottomRowData.length * widget.rowHeight;

  double get _maxScrollY {
    final dataAreaHeight =
        _viewportSize.height -
        _totalHeaderHeight -
        _pinnedTopHeight -
        _pinnedBottomHeight;
    final totalContentHeight = _totalDataHeight;
    return math.max(0.0, totalContentHeight - dataAreaHeight);
  }

  /// Total height of all data rows (uses layout if variable, otherwise uniform).
  double get _totalDataHeight {
    final layout = widget.rowHeightLayout;
    if (layout != null) return layout.totalHeight;
    return widget.rowData.length * widget.rowHeight;
  }

  /// Returns the height of the row at [index].
  double _getRowHeight(int index) {
    final layout = widget.rowHeightLayout;
    if (layout != null) return layout.getRowHeight(index);
    return widget.rowHeight;
  }

  /// Returns the Y offset (top edge) of the row at [index] relative to the data area.
  double _getRowTop(int index) {
    final layout = widget.rowHeightLayout;
    if (layout != null) return layout.getRowTop(index);
    return index * widget.rowHeight;
  }

  /// Returns the row index at the given Y offset within the data area.
  int _getRowIndexAtY(double y) {
    final layout = widget.rowHeightLayout;
    if (layout != null) {
      final idx = layout.getRowIndexAtY(y);
      return idx < 0 ? 0 : idx;
    }
    return (y / widget.rowHeight).floor();
  }

  double get _maxScrollX {
    // Only center (non-pinned) columns scroll horizontally
    final layout = _getLayout();
    final centerViewportWidth =
        _viewportSize.width - layout.leftWidth - layout.rightWidth;
    return math.max(0.0, layout.centerWidth - centerViewportWidth);
  }

  // --- Hit testing ---

  GridHitTestResult _hitTestAt(Offset localPosition) {
    final x = localPosition.dx;
    final y = localPosition.dy;

    // Header area (group header + column header, excluding floating filter)
    final headerBottom =
        widget.headerHeight +
        (widget.columnGroupSpans != null ? widget.groupHeaderHeight : 0);
    if (y < headerBottom) {
      return _hitTestHeader(x);
    }

    // Floating filter row area
    if (widget.floatingFilterHeight > 0 &&
        y < headerBottom + widget.floatingFilterHeight) {
      return _hitTestFloatingFilter(x);
    }

    return _hitTestDataCell(x, y);
  }

  /// Canvas-space rect of the active range's fill handle, or null when the
  /// handle is hidden (quality program v3 item 10).
  ///
  /// The handle is an 8×8 square anchored at the bottom-right corner of the
  /// primary (last) range's end cell — mirrored to the bottom-left under RTL,
  /// where the end column is the range's leftmost visual cell. Hidden when
  /// the end cell is not fully visible so the hit zone never sits on a
  /// clipped cell. Uses the same [RtlGeometry] mapping as hit testing and
  /// painting, and the returned rect is handed to [RangePainter] so both
  /// surfaces share one geometry source.
  Rect? _fillHandleRect() {
    if (!widget.enableRangeSelection || widget.onFillDrag == null) return null;
    final ranges = widget.cellRanges;
    if (ranges == null || ranges.isEmpty) return null;

    final range = ranges.last;
    final endRow = range.normalizedEndRow;
    final endCol = range.normalizedEndColumn;
    if (endRow < 0 || endRow >= widget.rowData.length) return null;
    if (endCol < 0 || endCol >= widget.columns.length) return null;

    // The end cell's row band must be fully inside the scrollable data area.
    final dataAreaTop = _totalHeaderHeight + _pinnedTopHeight;
    final rowTop = dataAreaTop + _getRowTop(endRow) - _scrollY;
    final rowBottom = rowTop + _getRowHeight(endRow);
    final dataAreaBottom = _viewportSize.height - _pinnedBottomHeight;
    if (rowTop < dataAreaTop || rowBottom > dataAreaBottom) return null;

    final layout = _getLayout();
    final geom = _geometry(layout);
    final rect = _columnRectForIndex(layout, endCol);
    if (rect == null) return null;
    if (rect.left < 0 || rect.left + rect.width > _viewportSize.width) {
      return null;
    }

    final double handleLeft;
    if (geom.isRtl) {
      handleLeft = rect.left;
    } else {
      handleLeft = rect.left + rect.width - _fillHandleSize;
    }
    return Rect.fromLTWH(
      handleLeft,
      rowBottom - _fillHandleSize,
      _fillHandleSize,
      _fillHandleSize,
    );
  }

  /// Canvas-space rect of the integrated-charts palette button, anchored
  /// just outside the active range's leading-top corner, or null when the
  /// button is hidden (charts disabled, no range, or the anchor cell
  /// off-screen). Painting and hit-testing share this one geometry source.
  Rect? _rangeChartButtonRect() {
    if (!widget.enableRangeSelection || !widget.enableCharts) return null;
    if (widget.onChartPaletteTap == null) return null;
    final ranges = widget.cellRanges;
    if (ranges == null || ranges.isEmpty) return null;

    final range = ranges.last;
    final anchorRow = range.normalizedStartRow;
    final anchorCol = range.normalizedEndColumn;
    if (anchorRow < 0 || anchorRow >= widget.rowData.length) return null;
    if (anchorCol < 0 || anchorCol >= widget.columns.length) return null;

    final dataAreaTop = _totalHeaderHeight + _pinnedTopHeight;
    final rowTop = dataAreaTop + _getRowTop(anchorRow) - _scrollY;
    final rowBottom = rowTop + _getRowHeight(anchorRow);
    final dataAreaBottom = _viewportSize.height - _pinnedBottomHeight;
    if (rowTop < dataAreaTop || rowBottom > dataAreaBottom) return null;

    final layout = _getLayout();
    final geom = _geometry(layout);
    final rect = _columnRectForIndex(layout, anchorCol);
    if (rect == null) return null;
    if (rect.left < 0 || rect.left + rect.width > _viewportSize.width) {
      return null;
    }

    // 18×18 button floating at the range's visual trailing-top corner.
    const buttonSize = 18.0;
    final buttonLeft = geom.isRtl
        ? rect.left - buttonSize - 2
        : rect.left + rect.width + 2;
    return Rect.fromLTWH(buttonLeft, rowTop + 2, buttonSize, buttonSize);
  }

  GridHitTestResult _hitTestHeader(double x) {
    const resizeEdgeWidth = 5.0;
    // Filter icon dimensions (must match GridPainter constants)
    const filterIconSize = 12.0;
    const filterIconRightPadding = 8.0;
    const menuIconWidth = 20.0;
    const menuIconRightPadding = 8.0;
    const menuIconDotRadius = 2.0;

    // Build column layout to know pinned positions
    final layout = _getLayout();
    final geom = _geometry(layout);

    // Helper to check if x is within the filter icon area of a column
    HeaderFilterIconHit? checkFilterIcon(
      double colX,
      double colWidth,
      ColumnLayoutEntry entry,
    ) {
      if (entry.column.filter == null) return null;
      final field = entry.column.field;
      final showMenuIcon =
          field == null ||
          !const {
            SpecialColumns.checkbox,
            SpecialColumns.rowNumber,
          }.contains(field);
      final menuOffset = showMenuIcon ? menuIconWidth : 0.0;
      // Mirrors GridPainter._paintFilterIcon edge anchoring per direction.
      final double iconRight;
      if (geom.isRtl) {
        iconRight = colX + filterIconRightPadding + menuOffset + filterIconSize;
      } else {
        iconRight = colX + colWidth - filterIconRightPadding - menuOffset;
      }
      final iconLeft = iconRight - filterIconSize;
      // Add some tap padding around the icon
      if (x >= iconLeft - 4 && x <= iconRight + 4) {
        return HeaderFilterIconHit(
          columnIndex: entry.index,
          colDef: entry.column,
        );
      }
      return null;
    }

    // Helper to check if x is within the menu icon (⋮) area of a column
    HeaderMenuIconHit? checkMenuIcon(
      double colX,
      double colWidth,
      ColumnLayoutEntry entry,
    ) {
      final field = entry.column.field;
      final showMenuIcon =
          field == null ||
          !const {
            SpecialColumns.checkbox,
            SpecialColumns.rowNumber,
          }.contains(field);
      if (!showMenuIcon) return null;
      // Menu icon centre mirrors GridPainter._paintMenuIcon per direction.
      // Generous tap target around the icon (±10px from centre).
      final double iconCenterX;
      if (geom.isRtl) {
        iconCenterX = colX + menuIconRightPadding + menuIconDotRadius;
      } else {
        iconCenterX =
            colX + colWidth - menuIconRightPadding - menuIconDotRadius;
      }
      if ((x - iconCenterX).abs() <= 10.0) {
        return HeaderMenuIconHit(
          columnIndex: entry.index,
          colDef: entry.column,
        );
      }
      return null;
    }

    // Check leading pinned columns (fixed position)
    var offset = 0.0;
    for (final entry in layout.leftCols) {
      final colX = geom.pinnedX(
        sectionX: geom.leadingSectionX,
        sectionWidth: geom.leadingWidth,
        offset: offset,
        width: entry.width,
      );
      final colRight = colX + entry.width;
      if ((x - colRight).abs() < resizeEdgeWidth) {
        return HeaderResizeEdgeHit(
          columnIndex: entry.index,
          colDef: entry.column,
        );
      }
      if (x >= colX && x < colRight) {
        // Check menu icon first (outermost), then filter icon, then general header
        final menuHit = checkMenuIcon(colX, entry.width, entry);
        if (menuHit != null) return menuHit;
        final filterHit = checkFilterIcon(colX, entry.width, entry);
        if (filterHit != null) return filterHit;
        return HeaderCellHit(columnIndex: entry.index, colDef: entry.column);
      }
      offset += entry.width;
    }

    // Check trailing pinned columns (fixed to the direction-end edge)
    offset = 0.0;
    for (final entry in layout.rightCols) {
      final colX = geom.pinnedX(
        sectionX: geom.trailingSectionX,
        sectionWidth: geom.trailingWidth,
        offset: offset,
        width: entry.width,
      );
      final colRight = colX + entry.width;
      if ((x - colRight).abs() < resizeEdgeWidth) {
        return HeaderResizeEdgeHit(
          columnIndex: entry.index,
          colDef: entry.column,
        );
      }
      if (x >= colX && x < colRight) {
        final menuHit = checkMenuIcon(colX, entry.width, entry);
        if (menuHit != null) return menuHit;
        final filterHit = checkFilterIcon(colX, entry.width, entry);
        if (filterHit != null) return filterHit;
        return HeaderCellHit(columnIndex: entry.index, colDef: entry.column);
      }
      offset += entry.width;
    }

    // Check center columns (scrolled by _scrollX)
    offset = 0.0;
    for (final entry in layout.centerCols) {
      final colX = geom.centerX(
        offset: offset,
        width: entry.width,
        scrollX: _scrollX,
      );
      final colRight = colX + entry.width;
      if ((x - colRight).abs() < resizeEdgeWidth) {
        return HeaderResizeEdgeHit(
          columnIndex: entry.index,
          colDef: entry.column,
        );
      }
      if (x >= colX && x < colRight) {
        final menuHit = checkMenuIcon(colX, entry.width, entry);
        if (menuHit != null) return menuHit;
        final filterHit = checkFilterIcon(colX, entry.width, entry);
        if (filterHit != null) return filterHit;
        return HeaderCellHit(columnIndex: entry.index, colDef: entry.column);
      }
      offset += entry.width;
    }

    return const EmptyHit();
  }

  GridHitTestResult _hitTestFloatingFilter(double x) {
    // Build column layout to know pinned positions
    final layout = _getLayout();
    final geom = _geometry(layout);

    // Check leading pinned columns (fixed position)
    var offset = 0.0;
    for (final entry in layout.leftCols) {
      final colX = geom.pinnedX(
        sectionX: geom.leadingSectionX,
        sectionWidth: geom.leadingWidth,
        offset: offset,
        width: entry.width,
      );
      final colRight = colX + entry.width;
      if (x >= colX && x < colRight) {
        return FloatingFilterCellHit(
          columnIndex: entry.index,
          colDef: entry.column,
        );
      }
      offset += entry.width;
    }

    // Check trailing pinned columns (fixed to the direction-end edge)
    offset = 0.0;
    for (final entry in layout.rightCols) {
      final colX = geom.pinnedX(
        sectionX: geom.trailingSectionX,
        sectionWidth: geom.trailingWidth,
        offset: offset,
        width: entry.width,
      );
      final colRight = colX + entry.width;
      if (x >= colX && x < colRight) {
        return FloatingFilterCellHit(
          columnIndex: entry.index,
          colDef: entry.column,
        );
      }
      offset += entry.width;
    }

    // Check center columns (scrolled by _scrollX)
    offset = 0.0;
    for (final entry in layout.centerCols) {
      final colX = geom.centerX(
        offset: offset,
        width: entry.width,
        scrollX: _scrollX,
      );
      final colRight = colX + entry.width;
      if (x >= colX && x < colRight) {
        return FloatingFilterCellHit(
          columnIndex: entry.index,
          colDef: entry.column,
        );
      }
      offset += entry.width;
    }

    return const EmptyHit();
  }

  GridHitTestResult _hitTestDataCell(double x, double y) {
    // Check if the tap is in the pinned top rows area
    final pinnedTopStart = _totalHeaderHeight;
    final pinnedTopEnd = pinnedTopStart + _pinnedTopHeight;
    if (widget.pinnedTopRowData.isNotEmpty &&
        y >= pinnedTopStart &&
        y < pinnedTopEnd) {
      final rowIndex = ((y - pinnedTopStart) / widget.rowHeight).floor();
      if (rowIndex >= 0 && rowIndex < widget.pinnedTopRowData.length) {
        return _hitTestPinnedRow(x, rowIndex, isPinnedTop: true);
      }
    }

    // Check if the tap is in the pinned bottom rows area
    final pinnedBottomStart = _viewportSize.height - _pinnedBottomHeight;
    if (widget.pinnedBottomRowData.isNotEmpty && y >= pinnedBottomStart) {
      final rowIndex = ((y - pinnedBottomStart) / widget.rowHeight).floor();
      if (rowIndex >= 0 && rowIndex < widget.pinnedBottomRowData.length) {
        return _hitTestPinnedRow(x, rowIndex, isPinnedTop: false);
      }
    }

    // Normal scrollable data area
    final dataAreaTop = _totalHeaderHeight + _pinnedTopHeight;
    final dataY = y - dataAreaTop + _scrollY;
    final rowIndex = _getRowIndexAtY(dataY);

    if (rowIndex < 0 || rowIndex >= widget.rowData.length) {
      return const EmptyHit();
    }

    // Synthetic master/detail rows are not canvas-interactive: the detail
    // widget overlay handles its own pointer events, and taps that fall
    // through its non-interactive content must not select/focus cells.
    if (widget.rowData[rowIndex][MasterDetailKeys.isDetailRow] == true) {
      return const EmptyHit();
    }

    // Build column layout
    final layout = _getLayout();
    final geom = _geometry(layout);

    // Check leading pinned
    var offset = 0.0;
    for (final entry in layout.leftCols) {
      final colX = geom.pinnedX(
        sectionX: geom.leadingSectionX,
        sectionWidth: geom.leadingWidth,
        offset: offset,
        width: entry.width,
      );
      final colRight = colX + entry.width;
      if (x >= colX && x < colRight) {
        final field = entry.column.field;
        final value = field != null ? widget.rowData[rowIndex][field] : null;
        return DataCellHit(
          rowIndex: rowIndex,
          columnIndex: entry.index,
          colDef: entry.column,
          value: value,
        );
      }
      offset += entry.width;
    }

    // Check trailing pinned
    offset = 0.0;
    for (final entry in layout.rightCols) {
      final colX = geom.pinnedX(
        sectionX: geom.trailingSectionX,
        sectionWidth: geom.trailingWidth,
        offset: offset,
        width: entry.width,
      );
      final colRight = colX + entry.width;
      if (x >= colX && x < colRight) {
        final field = entry.column.field;
        final value = field != null ? widget.rowData[rowIndex][field] : null;
        return DataCellHit(
          rowIndex: rowIndex,
          columnIndex: entry.index,
          colDef: entry.column,
          value: value,
        );
      }
      offset += entry.width;
    }

    // Check center (scrolled)
    offset = 0.0;
    for (final entry in layout.centerCols) {
      final colX = geom.centerX(
        offset: offset,
        width: entry.width,
        scrollX: _scrollX,
      );
      final colRight = colX + entry.width;
      if (x >= colX && x < colRight) {
        final field = entry.column.field;
        final value = field != null ? widget.rowData[rowIndex][field] : null;
        return DataCellHit(
          rowIndex: rowIndex,
          columnIndex: entry.index,
          colDef: entry.column,
          value: value,
        );
      }
      offset += entry.width;
    }

    return const EmptyHit();
  }

  /// Hit tests a pinned row (top or bottom) at the given row index.
  GridHitTestResult _hitTestPinnedRow(
    double x,
    int rowIndex, {
    required bool isPinnedTop,
  }) {
    final data = isPinnedTop
        ? widget.pinnedTopRowData
        : widget.pinnedBottomRowData;
    if (rowIndex < 0 || rowIndex >= data.length) return const EmptyHit();

    final layout = _getLayout();
    final geom = _geometry(layout);

    // Check leading pinned columns
    var offset = 0.0;
    for (final entry in layout.leftCols) {
      final colX = geom.pinnedX(
        sectionX: geom.leadingSectionX,
        sectionWidth: geom.leadingWidth,
        offset: offset,
        width: entry.width,
      );
      final colRight = colX + entry.width;
      if (x >= colX && x < colRight) {
        final field = entry.column.field;
        final value = field != null ? data[rowIndex][field] : null;
        return DataCellHit(
          rowIndex: rowIndex,
          columnIndex: entry.index,
          colDef: entry.column,
          value: value,
        );
      }
      offset += entry.width;
    }

    // Check trailing pinned columns
    offset = 0.0;
    for (final entry in layout.rightCols) {
      final colX = geom.pinnedX(
        sectionX: geom.trailingSectionX,
        sectionWidth: geom.trailingWidth,
        offset: offset,
        width: entry.width,
      );
      final colRight = colX + entry.width;
      if (x >= colX && x < colRight) {
        final field = entry.column.field;
        final value = field != null ? data[rowIndex][field] : null;
        return DataCellHit(
          rowIndex: rowIndex,
          columnIndex: entry.index,
          colDef: entry.column,
          value: value,
        );
      }
      offset += entry.width;
    }

    // Check center columns (scrolled)
    offset = 0.0;
    for (final entry in layout.centerCols) {
      final colX = geom.centerX(
        offset: offset,
        width: entry.width,
        scrollX: _scrollX,
      );
      final colRight = colX + entry.width;
      if (x >= colX && x < colRight) {
        final field = entry.column.field;
        final value = field != null ? data[rowIndex][field] : null;
        return DataCellHit(
          rowIndex: rowIndex,
          columnIndex: entry.index,
          colDef: entry.column,
          value: value,
        );
      }
      offset += entry.width;
    }

    return const EmptyHit();
  }

  // --- Scroll handlers ---

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      // Wheel input takes over from any in-flight ballistic scroll.
      _stopFling();
      widget.onScrollStart?.call();
      final isShiftHeld = HardwareKeyboard.instance.logicalKeysPressed.any(
        (key) =>
            key == LogicalKeyboardKey.shiftLeft ||
            key == LogicalKeyboardKey.shiftRight,
      );

      if (_useHeadlessScroll && !isShiftHeld) {
        // Controller mode: vertical wheel routes through the scroll
        // position (instant target under ClampingScrollPhysics); the
        // horizontal component stays manual.
        final dy = event.scrollDelta.dy;
        if (dy != 0) {
          _scrollPosition!.pointerScroll(dy);
        }
        if (event.scrollDelta.dx != 0) {
          // Horizontal wheel delta is gesture-space; flip the sign under
          // RTL so the content moves with the wheel (item 48).
          final dx = _direction == TextDirection.rtl
              ? -event.scrollDelta.dx
              : event.scrollDelta.dx;
          setState(() {
            _scrollX = (_scrollX + dx).clamp(0.0, _maxScrollX);
          });
        }
        return;
      }

      setState(() {
        if (isShiftHeld) {
          _scrollX = (_scrollX + event.scrollDelta.dy).clamp(0.0, _maxScrollX);
        } else {
          _scrollY = (_scrollY + event.scrollDelta.dy).clamp(0.0, _maxScrollY);
          if (event.scrollDelta.dx != 0) {
            // Horizontal wheel delta is gesture-space; flip the sign under
            // RTL so the content moves with the wheel (item 48).
            final dx = _direction == TextDirection.rtl
                ? -event.scrollDelta.dx
                : event.scrollDelta.dx;
            _scrollX = (_scrollX + dx).clamp(0.0, _maxScrollX);
          }
        }
      });
    }
  }

  // --- Gesture handlers ---

  static const double _scrollbarThickness = 8.0;
  static const double _scrollbarMinThumbLength = 30.0;

  _ScrollbarHit? _hitTestScrollbar(Offset pos) {
    final vw = _viewportSize.width;
    final vh = _viewportSize.height;
    final dataAreaHeight =
        vh - _totalHeaderHeight - _pinnedTopHeight - _pinnedBottomHeight;

    // Total content dimensions — center-section metrics only, since only
    // center columns scroll horizontally (matches the painter).
    var leftWidth = 0.0;
    var rightWidth = 0.0;
    var centerWidth = 0.0;
    for (int i = 0; i < widget.columns.length; i++) {
      final w = _getColumnWidth(i);
      final pin = widget.columns[i].pinned;
      if (pin == OsColumnPin.left) {
        leftWidth += w;
      } else if (pin == OsColumnPin.right) {
        rightWidth += w;
      } else {
        centerWidth += w;
      }
    }
    final totalContentHeight = _totalDataHeight;

    // Vertical scrollbar (right edge)
    if (totalContentHeight > dataAreaHeight &&
        pos.dx >= vw - _scrollbarThickness * 2) {
      final trackTop = _totalHeaderHeight + _pinnedTopHeight;
      final trackHeight = dataAreaHeight - _scrollbarThickness;
      final thumbRatio = dataAreaHeight / totalContentHeight;
      final thumbHeight = math.max(
        _scrollbarMinThumbLength,
        trackHeight * thumbRatio,
      );
      final thumbTop =
          trackTop + (_scrollY / _maxScrollY) * (trackHeight - thumbHeight);

      if (pos.dy >= thumbTop && pos.dy <= thumbTop + thumbHeight) {
        return _ScrollbarHit.vertical;
      }
      // Click on track (not thumb) — jump to position
      if (pos.dy >= trackTop && pos.dy <= trackTop + trackHeight) {
        return _ScrollbarHit.verticalTrack;
      }
    }

    // Horizontal scrollbar (bottom edge, center section only)
    final centerViewportWidth = vw - leftWidth - rightWidth;
    if (centerWidth > centerViewportWidth &&
        pos.dy >= vh - _scrollbarThickness * 2) {
      final trackLeft = leftWidth;
      final trackWidth = centerViewportWidth - _scrollbarThickness;
      final thumbRatio = centerViewportWidth / centerWidth;
      final thumbWidth = math.max(
        _scrollbarMinThumbLength,
        trackWidth * thumbRatio,
      );
      final maxScrollX = math.max(0.0, centerWidth - centerViewportWidth);
      final scrollRatio = maxScrollX > 0
          ? (_scrollX / maxScrollX).clamp(0.0, 1.0)
          : 0.0;
      // Thumb position mirrors with direction — same maths as the painter.
      final thumbLeft =
          RtlGeometry.of(
            _direction,
            viewportWidth: vw,
            leadingWidth: leftWidth,
            trailingWidth: rightWidth,
          ).horizontalThumbLeft(
            trackLeft: trackLeft,
            trackWidth: trackWidth,
            thumbWidth: thumbWidth,
            scrollRatio: scrollRatio,
          );

      if (pos.dx >= thumbLeft && pos.dx <= thumbLeft + thumbWidth) {
        return _ScrollbarHit.horizontal;
      }
      if (pos.dx >= trackLeft && pos.dx <= trackLeft + trackWidth) {
        return _ScrollbarHit.horizontalTrack;
      }
    }

    return null;
  }

  void _onPanStart(DragStartDetails details) {
    // Check scrollbar first
    final scrollbarHit = _hitTestScrollbar(details.localPosition);
    if (scrollbarHit == _ScrollbarHit.vertical) {
      _scrollbarDrag = _ScrollbarDrag(
        axis: Axis.vertical,
        startOffset: _scrollY,
        startPos: details.localPosition.dy,
      );
      return;
    }
    if (scrollbarHit == _ScrollbarHit.horizontal) {
      _scrollbarDrag = _ScrollbarDrag(
        axis: Axis.horizontal,
        startOffset: _scrollX,
        startPos: details.localPosition.dx,
      );
      return;
    }
    if (scrollbarHit == _ScrollbarHit.verticalTrack) {
      // Jump to position
      final dataAreaHeight =
          _viewportSize.height -
          _totalHeaderHeight -
          _pinnedTopHeight -
          _pinnedBottomHeight;
      final trackTop = _totalHeaderHeight + _pinnedTopHeight;
      final trackHeight = dataAreaHeight - _scrollbarThickness;
      final ratio = (details.localPosition.dy - trackTop) / trackHeight;
      setState(() {
        _scrollY = (ratio * _maxScrollY).clamp(0.0, _maxScrollY);
      });
      _scrollbarDrag = _ScrollbarDrag(
        axis: Axis.vertical,
        startOffset: _scrollY,
        startPos: details.localPosition.dy,
      );
      return;
    }
    if (scrollbarHit == _ScrollbarHit.horizontalTrack) {
      final trackWidth = _viewportSize.width - _scrollbarThickness;
      // Ratio measured from the reading-direction start edge so the jump
      // matches the mirrored thumb position.
      final ratio =
          RtlGeometry.of(
            _direction,
            viewportWidth: _viewportSize.width,
            leadingWidth: 0,
            trailingWidth: 0,
          ).scrollRatioAtTrackX(
            trackLeft: 0,
            trackWidth: trackWidth,
            x: details.localPosition.dx,
          );
      setState(() {
        _scrollX = (ratio * _maxScrollX).clamp(0.0, _maxScrollX);
      });
      _scrollbarDrag = _ScrollbarDrag(
        axis: Axis.horizontal,
        startOffset: _scrollX,
        startPos: details.localPosition.dx,
      );
      return;
    }

    // Check column resize
    final hit = _hitTestAt(details.localPosition);
    if (hit is HeaderResizeEdgeHit) {
      _resizingColumnIndex = hit.columnIndex;
      _resizeStartX = details.localPosition.dx;
      _resizeStartWidth = _getColumnWidth(hit.columnIndex);
      return;
    }

    // Check for column header drag (reorder).
    // Only start if the column is not pinned, not suppressMovable, and not lockPosition.
    // Only mouse drags initiate column reorder — trackpad/touch pans should scroll.
    if (hit is HeaderCellHit && widget.onColumnDragStart != null) {
      final kind = details.kind;
      if (kind == null || kind == PointerDeviceKind.mouse) {
        final col = hit.colDef;
        final isPinned = col.pinned != null;
        final isSuppressed = col.suppressMovable == true;
        final isLocked = col.lockPosition == true;
        if (!isPinned && !isSuppressed && !isLocked) {
          _pendingDragColumnIndex = hit.columnIndex;
          _pendingDragStartX = details.localPosition.dx;
          return;
        }
      }
    }

    // Check for row drag handle hit (data cell in the row-drag column).
    if (hit is DataCellHit &&
        hit.colDef.field == SpecialColumns.rowDrag &&
        widget.onRowDragStart != null) {
      final kind = details.kind;
      if (kind == null || kind == PointerDeviceKind.mouse) {
        _pendingDragRowIndex = hit.rowIndex;
        _pendingDragStartY = details.localPosition.dy;
        _pendingDragStartPosition = details.localPosition;
        return;
      }
    }

    // Fill handle: starting on the active range's fill-handle square begins
    // a fill drag instead of a new range selection (quality program v3
    // item 10). Mouse-only, like range selection. The hit test uses the
    // pointer-down contact point — the pan callback only fires after the
    // slop move, which may already have left the 8×8 square.
    if (widget.onFillDrag != null) {
      final handleRect = _fillHandleRect();
      final contactPoint = _pointerDownPosition ?? details.localPosition;
      if (handleRect != null && handleRect.contains(contactPoint)) {
        final kind = details.kind;
        if (kind == null || kind == PointerDeviceKind.mouse) {
          _isFillDragging = true;
          _fillDragEndCell = null;
          return;
        }
      }
    }

    // Range selection: if enabled and the pointer is in the data area, start a range drag.
    // Only start range selection for mouse drags — trackpad/touch pans should scroll.
    if (widget.enableRangeSelection && hit is DataCellHit) {
      final kind = details.kind;
      if (kind == null || kind == PointerDeviceKind.mouse) {
        _isRangeDragging = true;
        widget.onRangeDragStart?.call(hit);
        return;
      }
    }

    // Plain content pan. Controller mode hands the drag to the scroll
    // position so release velocity feeds real ballistic physics; the
    // returned Drag receives updates in _onPanUpdate and is ended with the
    // estimated velocity in _onPanEnd.
    if (_useHeadlessScroll) {
      _activeScrollDrag = _scrollPosition!.drag(
        DragStartDetails(
          sourceTimeStamp: details.sourceTimeStamp,
          globalPosition: details.globalPosition,
          localPosition: details.localPosition,
        ),
        () {},
      );
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_scrollbarDrag != null) {
      // Scrollbar drag in progress
      final drag = _scrollbarDrag!;
      if (drag.axis == Axis.vertical) {
        final dataAreaHeight = _viewportSize.height - _totalHeaderHeight;
        final trackHeight = dataAreaHeight - _scrollbarThickness;
        final totalContentHeight = _totalDataHeight;
        final thumbRatio = dataAreaHeight / totalContentHeight;
        final thumbHeight = math.max(
          _scrollbarMinThumbLength,
          trackHeight * thumbRatio,
        );
        final availableTrack = trackHeight - thumbHeight;
        if (availableTrack > 0) {
          final delta = details.localPosition.dy - drag.startPos;
          final scrollDelta = (delta / availableTrack) * _maxScrollY;
          setState(() {
            _scrollY = (drag.startOffset + scrollDelta).clamp(0.0, _maxScrollY);
          });
        }
      } else {
        final trackWidth = _viewportSize.width - _scrollbarThickness;
        var totalContentWidth = 0.0;
        for (int i = 0; i < widget.columns.length; i++) {
          totalContentWidth += _getColumnWidth(i);
        }
        final thumbRatio = _viewportSize.width / totalContentWidth;
        final thumbWidth = math.max(
          _scrollbarMinThumbLength,
          trackWidth * thumbRatio,
        );
        final availableTrack = trackWidth - thumbWidth;
        if (availableTrack > 0) {
          // Thumb-drag deltas are gesture-space; flip the horizontal sign
          // under RTL so the thumb tracks the pointer both directions.
          final xSign = _direction == TextDirection.rtl ? -1.0 : 1.0;
          final delta = details.localPosition.dx - drag.startPos;
          final scrollDelta = (delta / availableTrack) * _maxScrollX * xSign;
          setState(() {
            _scrollX = (drag.startOffset + scrollDelta).clamp(0.0, _maxScrollX);
          });
        }
      }
      return;
    }

    if (_isFillDragging) {
      // Fill drag — remember the cell under the pointer; the owning grid
      // applies the fill once when the drag ends.
      final hit = _hitTestAt(details.localPosition);
      if (hit is DataCellHit) {
        _fillDragEndCell = (row: hit.rowIndex, col: hit.columnIndex);
      }
      return;
    }

    if (_isRangeDragging) {
      // Range selection drag — update the range end position
      final hit = _hitTestAt(details.localPosition);
      if (hit is DataCellHit) {
        widget.onRangeDragUpdate?.call(hit.rowIndex, hit.columnIndex);
      }
      return;
    }

    // Column header drag — check threshold then update
    if (_pendingDragColumnIndex != null || _isColumnDragging) {
      if (!_isColumnDragging) {
        // Check if we've exceeded the horizontal threshold
        final dx = (details.localPosition.dx - _pendingDragStartX).abs();
        if (dx >= _columnDragThreshold) {
          _isColumnDragging = true;
          final effectiveWidths = List.generate(
            widget.columns.length,
            (i) => _getColumnWidth(i),
          );
          widget.onColumnDragStart?.call(
            _pendingDragColumnIndex!,
            _pendingDragStartX,
            _scrollX,
            effectiveWidths,
          );
          widget.onColumnDragUpdate?.call(
            details.localPosition.dx,
            details.globalPosition,
          );
        }
      } else {
        widget.onColumnDragUpdate?.call(
          details.localPosition.dx,
          details.globalPosition,
        );
      }
      return;
    }

    // Row drag — check threshold then update
    if (_pendingDragRowIndex != null || _isRowDragging) {
      _lastRowDragPosition = details.localPosition;
      if (!_isRowDragging) {
        // Check if we've exceeded the vertical threshold
        final dy = (details.localPosition.dy - _pendingDragStartY).abs();
        if (dy >= _rowDragThreshold) {
          _isRowDragging = true;
          widget.onRowDragStart?.call(
            _pendingDragRowIndex!,
            _pendingDragStartPosition,
          );
          widget.onRowDragUpdate?.call(details.localPosition);
          // The drag may begin already inside an edge zone (pan engages
          // wherever the pointer is when the slop is crossed).
          _updateRowDragAutoScroll(details.localPosition);
        }
      } else {
        widget.onRowDragUpdate?.call(details.localPosition);
        _updateRowDragAutoScroll(details.localPosition);
      }
      return;
    }

    if (_resizingColumnIndex != null) {
      final delta = details.localPosition.dx - _resizeStartX;
      final minWidth = widget.columns[_resizingColumnIndex!].minWidth ?? 50.0;
      final maxWidth = widget.columns[_resizingColumnIndex!].maxWidth ?? 800.0;
      final newWidth = (_resizeStartWidth + delta).clamp(minWidth, maxWidth);
      setState(() {
        _localColumnWidths[_resizingColumnIndex!] = newWidth;
      });
    } else {
      // Normal pan scroll. Horizontal pan deltas are gesture-space: under
      // RTL dragging the content rightward reveals later reading-order
      // columns, so the scrollX sign flips (item 48).
      final dx = _direction == TextDirection.rtl
          ? details.delta.dx
          : -details.delta.dx;
      widget.onScrollStart?.call();
      if (_useHeadlessScroll && _activeScrollDrag != null) {
        // Controller mode: vertical delta goes to the drag controller in
        // finger-space (it negates internally); horizontal stays manual.
        _activeScrollDrag!.update(
          DragUpdateDetails(
            sourceTimeStamp: details.sourceTimeStamp,
            delta: details.delta,
            primaryDelta: details.delta.dy,
            globalPosition: details.globalPosition,
            localPosition: details.localPosition,
          ),
        );
        setState(() {
          _scrollX = (_scrollX + dx).clamp(0.0, _maxScrollX);
        });
      } else {
        setState(() {
          _scrollY = (_scrollY - details.delta.dy).clamp(0.0, _maxScrollY);
          _scrollX = (_scrollX + dx).clamp(0.0, _maxScrollX);
        });
      }
      _trackPanVelocity(details);
    }
  }

  /// Updates the exponential-moving-average pan velocity estimate from a
  /// drag-update event. Uses the pointer event's source timestamp so
  /// synthetic (same-timestamp) events contribute no velocity.
  void _trackPanVelocity(DragUpdateDetails details) {
    final ts = details.sourceTimeStamp;
    final last = _lastPanMoveTime;
    if (ts == null) return;
    if (last != null) {
      final dt = (ts - last).inMicroseconds / 1e6;
      // Ignore zero/negative gaps and long pauses (>50ms) — both produce
      // meaningless instantaneous velocities.
      if (dt > 0 && dt <= 0.05) {
        // Scroll velocity is opposite to finger movement.
        final vx = -details.delta.dx / dt;
        final vy = -details.delta.dy / dt;
        const w = _panVelocitySmoothing;
        _panVelocityX = vx * w + _panVelocityX * (1 - w);
        _panVelocityY = vy * w + _panVelocityY * (1 - w);
        _panVelocitySamples++;
      }
    }
    _lastPanMoveTime = ts;
  }

  /// Starts a ballistic (fling) scroll from the estimated release velocity.
  ///
  /// Requires at least two timed movement samples: synthetic gestures that
  /// emit all moves at a single timestamp carry no usable velocity signal
  /// and must behave exactly like before flings existed (stop dead).
  void _startFling() {
    final vx = _panVelocityX;
    final vy = _panVelocityY;
    final samples = _panVelocitySamples;
    _resetVelocityTracking();
    if (samples < 2) return;
    if (vx.abs() < _flingMinStartVelocity &&
        vy.abs() < _flingMinStartVelocity) {
      return;
    }
    _flingVelocityX = vx;
    _flingVelocityY = vy;
    _flingLastElapsed = Duration.zero;
    final ticker = _flingTicker ??= createTicker(_onFlingTick);
    if (!ticker.isActive) {
      ticker.start();
    }
  }

  /// Cancels any in-flight ballistic scroll and resets velocity tracking.
  void _stopFling() {
    _flingTicker?.stop();
    _flingLastElapsed = Duration.zero;
    // A pointer down / wheel event also kills an in-flight headless drag;
    // cancelling routes the position back to idle before the new activity
    // (wheel jump or fresh drag) begins.
    final drag = _activeScrollDrag;
    _activeScrollDrag = null;
    drag?.cancel();
    _resetVelocityTracking();
  }

  void _resetVelocityTracking() {
    _flingVelocityX = 0.0;
    _flingVelocityY = 0.0;
    _panVelocityX = 0.0;
    _panVelocityY = 0.0;
    _lastPanMoveTime = null;
    _panVelocitySamples = 0;
  }

  /// Frame tick integrating the ballistic scroll: position advances by
  /// v·dt while velocity decays exponentially. Stops when speed drops below
  /// [_flingEpsilon] or when pinned at a scroll bound in the direction of
  /// travel.
  void _onFlingTick(Duration elapsed) {
    final dt = (elapsed - _flingLastElapsed).inMicroseconds / 1e6;
    _flingLastElapsed = elapsed;
    if (dt <= 0) return;

    // Stored velocities are gesture-space; convert X to scroll-space by
    // flipping the sign under RTL (item 48).
    final xSign = _direction == TextDirection.rtl ? -1.0 : 1.0;
    var vxScroll = _flingVelocityX * xSign;
    final dy = _flingVelocityY * dt;

    if (vxScroll != 0 || dy != 0) {
      setState(() {
        _scrollX = (_scrollX + vxScroll * dt).clamp(0.0, _maxScrollX);
        _scrollY = (_scrollY + dy).clamp(0.0, _maxScrollY);
      });
    }

    final factor = math.exp(-_flingDecayRate * dt);
    _flingVelocityX *= factor;
    _flingVelocityY *= factor;
    vxScroll = _flingVelocityX * xSign;

    if (vxScroll.abs() < _flingEpsilon ||
        (_scrollX <= 0 && vxScroll < 0) ||
        (_scrollX >= _maxScrollX && vxScroll > 0)) {
      _flingVelocityX = 0.0;
    }
    if (_flingVelocityY.abs() < _flingEpsilon ||
        (_scrollY <= 0 && _flingVelocityY < 0) ||
        (_scrollY >= _maxScrollY && _flingVelocityY > 0)) {
      _flingVelocityY = 0.0;
    }

    if (_flingVelocityX == 0.0 && _flingVelocityY == 0.0) {
      _flingTicker?.stop();
      _flingLastElapsed = Duration.zero;
    }
  }

  void _onPanEnd(DragEndDetails details) {
    if (_scrollbarDrag != null) {
      _scrollbarDrag = null;
      return;
    }
    if (_isFillDragging) {
      _isFillDragging = false;
      final endCell = _fillDragEndCell;
      _fillDragEndCell = null;
      if (endCell != null) {
        widget.onFillDrag?.call(endCell.row, endCell.col);
      }
      return;
    }
    if (_isRangeDragging) {
      _isRangeDragging = false;
      widget.onRangeDragEnd?.call();
      return;
    }
    if (_isColumnDragging) {
      _isColumnDragging = false;
      _pendingDragColumnIndex = null;
      widget.onColumnDragEnd?.call();
      return;
    }
    if (_pendingDragColumnIndex != null) {
      // Threshold was never exceeded — treat as a tap (header click for sort)
      final colIndex = _pendingDragColumnIndex!;
      _pendingDragColumnIndex = null;
      if (colIndex < widget.columns.length) {
        widget.onHeaderTap?.call(
          HeaderCellHit(
            columnIndex: colIndex,
            colDef: widget.columns[colIndex],
          ),
        );
      }
      return;
    }
    if (_isRowDragging) {
      _isRowDragging = false;
      _pendingDragRowIndex = null;
      _stopRowDragAutoScroll();
      widget.onRowDragEnd?.call();
      return;
    }
    if (_pendingDragRowIndex != null) {
      // Threshold was never exceeded — no drag occurred
      _pendingDragRowIndex = null;
      return;
    }
    if (_resizingColumnIndex != null) {
      final finalWidth = _localColumnWidths[_resizingColumnIndex!];
      if (finalWidth != null) {
        widget.onColumnResize?.call(_resizingColumnIndex!, finalWidth);
      }
      _resizingColumnIndex = null;
      return;
    }

    // Normal pan release: start a ballistic scroll from the estimated
    // velocity (no-op below the minimum fling speed). Controller mode ends
    // the active drag instead — the position runs the physics simulation.
    if (_useHeadlessScroll) {
      _endHeadlessDrag();
      return;
    }
    _startFling();
  }

  /// Ends the active headless drag, feeding the pan EMA velocity estimate
  /// back into the scroll position so [ClampingScrollPhysics] produces the
  /// ballistic glide.
  ///
  /// The EMA is tracked in *scroll space* (sign-flipped from finger
  /// movement); the drag protocol expects *finger-space* velocity and
  /// negates it internally, so the sign flips again here. Below-threshold
  /// releases end with zero velocity — matching legacy behaviour for
  /// synthetic gestures that carry no usable velocity signal.
  void _endHeadlessDrag() {
    final drag = _activeScrollDrag;
    _activeScrollDrag = null;
    if (drag == null) return;
    var vyScroll = _panVelocityY;
    final samples = _panVelocitySamples;
    _resetVelocityTracking();
    if (samples < 2 || vyScroll.abs() < _flingMinStartVelocity) {
      vyScroll = 0.0;
    }
    drag.end(
      DragEndDetails(
        velocity: Velocity(pixelsPerSecond: Offset(0, -vyScroll)),
        primaryVelocity: -vyScroll,
      ),
    );
  }

  void _onPanCancel() {
    // Clean up any in-progress drag state.
    if (_isColumnDragging) {
      // A cancel during an active column drag means the gesture recognizer
      // has given up — no _onPanEnd will follow. End the drag now.
      _isColumnDragging = false;
      _pendingDragColumnIndex = null;
      widget.onColumnDragEnd?.call();
      return;
    }
    // Same for row drag.
    if (_isRowDragging) {
      _isRowDragging = false;
      _pendingDragRowIndex = null;
      _stopRowDragAutoScroll();
      widget.onRowDragEnd?.call();
      return;
    }
    if (_pendingDragColumnIndex != null) {
      _pendingDragColumnIndex = null;
    }
    if (_pendingDragRowIndex != null) {
      _pendingDragRowIndex = null;
    }
    if (_isFillDragging) {
      // A cancelled fill drag aborts without writing values.
      _isFillDragging = false;
      _fillDragEndCell = null;
    }
    if (_isRangeDragging) {
      _isRangeDragging = false;
      widget.onRangeDragEnd?.call();
    }
    _scrollbarDrag = null;
    _resizingColumnIndex = null;
    // A cancelled plain-content pan ends the headless drag without a
    // ballistic glide (same semantics as the legacy path, which simply
    // never started its ticker on cancel).
    final drag = _activeScrollDrag;
    _activeScrollDrag = null;
    drag?.cancel();
    _resetVelocityTracking();
  }

  void _onTapUp(TapUpDetails details) {
    // Integrated-charts palette button (checked before general hit testing —
    // it floats over cell area next to the range).
    final chartButtonRect = _rangeChartButtonRect();
    if (chartButtonRect != null &&
        chartButtonRect.contains(details.localPosition)) {
      widget.onChartPaletteTap?.call(chartButtonRect);
      return;
    }

    final hit = _hitTestAt(details.localPosition);

    // Check for Shift+click to extend range
    if (widget.enableRangeSelection && hit is DataCellHit) {
      final isShiftHeld = HardwareKeyboard.instance.logicalKeysPressed.any(
        (key) =>
            key == LogicalKeyboardKey.shiftLeft ||
            key == LogicalKeyboardKey.shiftRight,
      );
      if (isShiftHeld) {
        widget.onRangeExtend?.call(hit.rowIndex, hit.columnIndex);
        return;
      }
    }

    switch (hit) {
      case DataCellHit():
        widget.onCellTap?.call(hit);
      case HeaderCellHit():
        widget.onHeaderTap?.call(hit);
      case HeaderFilterIconHit():
        // Already handled immediately in _onPointerDown to avoid
        // the double-tap gesture recognizer's 300ms delay.
        if (!_floatingFilterHandledOnDown) {
          if (widget.onHeaderFilterIconTap != null) {
            final iconRect = _getHeaderFilterIconRect(hit);
            if (iconRect != null) {
              widget.onHeaderFilterIconTap!.call(hit, iconRect);
            }
          }
        }
        _floatingFilterHandledOnDown = false;
      case HeaderMenuIconHit():
        if (!_floatingFilterHandledOnDown) {
          if (widget.onHeaderMenuIconTap != null) {
            final iconRect = _getHeaderMenuIconRect(hit);
            if (iconRect != null) {
              widget.onHeaderMenuIconTap!.call(hit, iconRect);
            }
          }
        }
        _floatingFilterHandledOnDown = false;
      case HeaderResizeEdgeHit():
        break;
      case FloatingFilterCellHit():
        // Already handled immediately in _onPointerDown to avoid
        // the double-tap gesture recognizer's 300ms delay.
        if (!_floatingFilterHandledOnDown) {
          if (widget.onFloatingFilterTap != null) {
            final cellRect = _getFloatingFilterCellRect(hit);
            if (cellRect != null) {
              widget.onFloatingFilterTap!.call(hit, cellRect);
            }
          }
        }
        _floatingFilterHandledOnDown = false;
      case EmptyHit():
        break;
    }
  }

  void _onDoubleTapDown(TapDownDetails details) {
    final hit = _hitTestAt(details.localPosition);
    if (hit is DataCellHit) {
      widget.onCellDoubleTap?.call(hit);

      // Calculate cell rect for edit overlay using the column layout
      if (widget.onCellEditRequest != null) {
        final cellRect = _getCellRectForHit(hit);
        if (cellRect != null) {
          widget.onCellEditRequest?.call(hit, cellRect);
        }
      }
      return;
    }

    // Double-click on a resize separator autosizes that column (quality
    // program v3 item 42). The framework's DoubleTapGestureRecognizer has
    // already applied the time/distance thresholding to the prior tap.
    if (hit is HeaderResizeEdgeHit) {
      widget.onHeaderResizeDoubleTap?.call(hit.columnIndex);
    }
  }

  /// Finds the visual left X of a column by its original index, using the
  /// shared directional resolver (paint/hit-test parity, item 48).
  ///
  /// Section offsets restart at zero per section — `RtlGeometry.centerX` /
  /// `pinnedX` expect an offset relative to the section start, matching the
  /// hit-test walk in `_hitTestDataCell`. (The offsets previously accumulated across
  /// sections, shifting every center-column x by the leading-pinned width.)
  double? _columnVisualLeft(ColumnLayout layout, int columnIndex) {
    final geom = _geometry(layout);
    var offset = 0.0;
    for (final entry in layout.leftCols) {
      if (entry.index == columnIndex) {
        return geom.pinnedX(
          sectionX: geom.leadingSectionX,
          sectionWidth: geom.leadingWidth,
          offset: offset,
          width: entry.width,
        );
      }
      offset += entry.width;
    }
    offset = 0.0;
    for (final entry in layout.centerCols) {
      if (entry.index == columnIndex) {
        return geom.centerX(
          offset: offset,
          width: entry.width,
          scrollX: _scrollX,
        );
      }
      offset += entry.width;
    }
    offset = 0.0;
    for (final entry in layout.rightCols) {
      if (entry.index == columnIndex) {
        return geom.pinnedX(
          sectionX: geom.trailingSectionX,
          sectionWidth: geom.trailingWidth,
          offset: offset,
          width: entry.width,
        );
      }
      offset += entry.width;
    }
    return null;
  }

  /// Shared per-cell geometry for overlay anchors (fill handle, chart
  /// palette button, edit overlay): the canvas-space rect of the cell at
  /// (`rowIndex`, `columnIndex`), or null when the column is unknown.
  ({double left, double width})? _columnRectForIndex(
    ColumnLayout layout,
    int columnIndex,
  ) {
    final left = _columnVisualLeft(layout, columnIndex);
    if (left == null) return null;
    return (left: left, width: _getColumnWidth(columnIndex));
  }

  /// Calculates the pixel rect for a data cell hit, accounting for
  /// pinned columns, scroll offset, and total header height.
  Rect? _getCellRectForHit(DataCellHit hit) {
    final layout = _getLayout();

    final rowTop = _totalHeaderHeight + _getRowTop(hit.rowIndex) - _scrollY;
    final colX = _columnVisualLeft(layout, hit.columnIndex);
    if (colX == null) return null;
    final colWidth = _getColumnWidth(hit.columnIndex);
    return Rect.fromLTWH(colX, rowTop, colWidth, _getRowHeight(hit.rowIndex));
  }

  void _onPointerHover(PointerHoverEvent event) {
    final hit = _hitTestAt(event.localPosition);

    // Update cursor based on what's under the pointer
    SystemMouseCursor newCursor;
    int? newHoveredRow;
    String? newHoveredColId;

    switch (hit) {
      case HeaderResizeEdgeHit():
        newCursor = SystemMouseCursors.resizeColumn;
        newHoveredColId = hit.colDef.effectiveColId;
      case DataCellHit():
        newCursor = SystemMouseCursors.click;
        newHoveredRow = hit.rowIndex;
        newHoveredColId = hit.colDef.effectiveColId;
      case HeaderCellHit():
        newCursor = SystemMouseCursors.click;
        newHoveredColId = hit.colDef.effectiveColId;
      case HeaderFilterIconHit():
        newCursor = SystemMouseCursors.click;
        newHoveredColId = hit.colDef.effectiveColId;
      case HeaderMenuIconHit():
        newCursor = SystemMouseCursors.click;
        newHoveredColId = hit.colDef.effectiveColId;
      case FloatingFilterCellHit():
        newCursor = SystemMouseCursors.click;
        newHoveredColId = hit.colDef.effectiveColId;
      case EmptyHit():
        newCursor = SystemMouseCursors.basic;
    }

    // Route hover state through the notifiers instead of setState: the
    // notifiers' listeners rebuild only the MouseRegion wrapper (cursor)
    // and the CustomPaint (painter), never the whole subtree. The
    // ValueNotifiers deduplicate equal writes, matching the previous
    // change-gated behaviour.
    _cursorNotifier.value = newCursor;
    final nextHover = (
      row: newHoveredRow,
      col: widget.columnHoverHighlight ? newHoveredColId : null,
    );
    if (nextHover != _hoverNotifier.value) {
      _hoverNotifier.value = nextHover;
    }

    // Notify parent about hover changes (for tooltip integration)
    widget.onHoverChanged?.call(hit, event.localPosition);
  }

  @override
  void dispose() {
    _stopFling();
    _flingTicker?.dispose();
    _stopRowDragAutoScroll();
    _scrollController?.detach(_scrollPosition!);
    _scrollPosition?.dispose();
    _scrollController?.dispose();
    _scrollPosition = null;
    _scrollController = null;
    widget.scrollCommandNotifier?.removeListener(_onScrollCommand);
    widget.focusCommandNotifier?.removeListener(_onFocusCommand);
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    _hoverNotifier.dispose();
    _cursorNotifier.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    // If the grid is currently editing, don't handle keys here
    // (they go to the edit overlay's KeyboardListener instead).
    if (widget.isEditing) return KeyEventResult.ignored;

    // Fire onCellKeyDown for printable + navigation keys BEFORE built-in
    // handling. Informational only — listeners cannot consume the key.
    _maybeFireCellKeyDown(event);

    final key = event.logicalKey;

    // Ctrl+Z / Cmd+Z → Undo
    if ((key == LogicalKeyboardKey.keyZ) && _isCtrlOrMetaHeld()) {
      widget.onUndoRequested?.call();
      return KeyEventResult.handled;
    }

    // Ctrl+Y / Cmd+Y → Redo
    if ((key == LogicalKeyboardKey.keyY) && _isCtrlOrMetaHeld()) {
      widget.onRedoRequested?.call();
      return KeyEventResult.handled;
    }

    // Ctrl+C / Cmd+C → Copy
    if ((key == LogicalKeyboardKey.keyC) && _isCtrlOrMetaHeld()) {
      widget.onCopyRequested?.call();
      return KeyEventResult.handled;
    }

    // Ctrl+X / Cmd+X → Cut
    if ((key == LogicalKeyboardKey.keyX) && _isCtrlOrMetaHeld()) {
      widget.onCutRequested?.call();
      return KeyEventResult.handled;
    }

    // Ctrl+V / Cmd+V → Paste
    if ((key == LogicalKeyboardKey.keyV) && _isCtrlOrMetaHeld()) {
      widget.onPasteRequested?.call();
      return KeyEventResult.handled;
    }

    // Shift+F10 or ContextMenu key → open context menu at focused cell
    if ((key == LogicalKeyboardKey.f10 && _isShiftHeld()) ||
        key == LogicalKeyboardKey.contextMenu) {
      if (widget.onContextMenuRequested != null) {
        widget.onContextMenuRequested!.call(_focusedRow, _focusedCol);
        return KeyEventResult.handled;
      }
    }

    final rowCount = widget.rowData.length;
    if (rowCount == 0) return KeyEventResult.ignored;

    final colCount = widget.columns.length;

    int? newFocusedRow;
    int? newFocusedCol;
    // Page size matches the scrollable data area (excludes header and the
    // pinned top/bottom rows, which are always visible).
    final pageSize =
        ((_viewportSize.height -
                    _totalHeaderHeight -
                    _pinnedTopHeight -
                    _pinnedBottomHeight) /
                widget.rowHeight)
            .floor();

    if (key == LogicalKeyboardKey.arrowDown) {
      newFocusedRow = math.min(_focusedRow + 1, rowCount - 1);
    } else if (key == LogicalKeyboardKey.arrowUp) {
      newFocusedRow = math.max(_focusedRow - 1, 0);
    } else if (key == LogicalKeyboardKey.arrowRight) {
      if (colCount > 0) {
        newFocusedCol = math.min(_focusedCol + 1, colCount - 1);
      }
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      if (colCount > 0) {
        newFocusedCol = math.max(_focusedCol - 1, 0);
      }
    } else if (key == LogicalKeyboardKey.pageDown) {
      newFocusedRow = math.min(_focusedRow + pageSize, rowCount - 1);
    } else if (key == LogicalKeyboardKey.pageUp) {
      newFocusedRow = math.max(_focusedRow - pageSize, 0);
    } else if (key == LogicalKeyboardKey.home) {
      newFocusedRow = 0;
    } else if (key == LogicalKeyboardKey.end) {
      newFocusedRow = rowCount - 1;
    } else if (key == LogicalKeyboardKey.tab && widget.tabToNextCell != null) {
      // Tab / Shift+Tab focus navigation owned by the grid while
      // `tabToNextCell` is configured.
      final isShift = _isShiftHeld();
      final defaultNextCol = colCount > 0
          ? (isShift
                ? math.max(_focusedCol - 1, 0)
                : math.min(_focusedCol + 1, colCount - 1))
          : _focusedCol;
      final overridden = widget.tabToNextCell!(
        TabToNextCellParams(
          previousCell: NavCellPosition(
            rowIndex: _focusedRow,
            columnIndex: _focusedCol,
          ),
          nextCell: NavCellPosition(
            rowIndex: _focusedRow,
            columnIndex: defaultNextCol,
          ),
          key: isShift ? 'shift+tab' : 'tab',
          shift: isShift,
        ),
      );
      int? tabRow;
      int? tabCol;
      if (overridden != null) {
        tabRow = math.max(0, math.min(overridden.rowIndex, rowCount - 1));
        if (colCount > 0) {
          tabCol = math.max(0, math.min(overridden.columnIndex, colCount - 1));
        }
      } else {
        tabCol = defaultNextCol;
      }
      _applyFocusedMovement(tabRow, tabCol);
      // Consume Tab even without movement so focus traversal does not
      // move focus out of the grid.
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.enter) {
      if (widget.enterNavigatesVertically) {
        // Navigate vertically instead of starting edit
        final isShift = HardwareKeyboard.instance.logicalKeysPressed.any(
          (k) =>
              k == LogicalKeyboardKey.shiftLeft ||
              k == LogicalKeyboardKey.shiftRight,
        );
        newFocusedRow = isShift
            ? math.max(_focusedRow - 1, 0)
            : math.min(_focusedRow + 1, rowCount - 1);
      } else {
        // Start editing the focused cell
        widget.onEditStartRequested?.call(_focusedRow, _focusedCol, 'enter');
        return KeyEventResult.handled;
      }
    } else if (key == LogicalKeyboardKey.f2) {
      // F2: start editing with caret at end
      widget.onEditStartRequested?.call(_focusedRow, _focusedCol, 'f2');
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.delete) {
      // Delete: clear cell value
      widget.onEditStartRequested?.call(_focusedRow, _focusedCol, 'delete');
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.backspace) {
      // Backspace: clear cell value (same as Delete)
      widget.onEditStartRequested?.call(_focusedRow, _focusedCol, 'backspace');
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.space) {
      // Space: row selection toggle (NOT editing) — matches TypeScript
      final hit = DataCellHit(
        rowIndex: _focusedRow,
        columnIndex: _focusedCol,
        colDef: widget.columns.isNotEmpty
            ? widget.columns[_focusedCol]
            : const OsColumnDef(field: ''),
        value: null,
      );
      widget.onCellTap?.call(hit);
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.escape) {
      // Clear range selection
      if (widget.enableRangeSelection &&
          widget.cellRanges != null &&
          widget.cellRanges!.isNotEmpty) {
        widget.onRangeClear?.call();
        return KeyEventResult.handled;
      }
    } else if (event is KeyDownEvent) {
      // Printable character: start editing with that character
      final character = event.character;
      if (character != null && character.length == 1 && !_isModifierHeld()) {
        // Only trigger for actual printable characters (not control chars)
        final codeUnit = character.codeUnitAt(0);
        if (codeUnit >= 32) {
          // Start editing with this character as initial text.
          // Return handled to consume the key event (prevents double-delivery).
          widget.onEditStartRequested?.call(
            _focusedRow,
            _focusedCol,
            character,
          );
          return KeyEventResult.handled;
        }
      }
    }

    // Custom navigation callback: allow the app to override the default
    // target cell. The returned position is clamped to the grid bounds;
    // returning null keeps the default movement.
    final navCallback = widget.navigateToNextCell;
    if (navCallback != null &&
        (newFocusedRow != null || newFocusedCol != null)) {
      final overridden = navCallback(
        NavigateToNextCellParams(
          previousCell: NavCellPosition(
            rowIndex: _focusedRow,
            columnIndex: _focusedCol,
          ),
          nextCell: NavCellPosition(
            rowIndex: newFocusedRow ?? _focusedRow,
            columnIndex: newFocusedCol ?? _focusedCol,
          ),
          key: _navKeyName(key),
          shift: _isShiftHeld(),
        ),
      );
      if (overridden != null) {
        newFocusedRow = math.max(
          0,
          math.min(overridden.rowIndex, rowCount - 1),
        );
        newFocusedCol = colCount > 0
            ? math.max(0, math.min(overridden.columnIndex, colCount - 1))
            : null;
      }
    }

    return _applyFocusedMovement(newFocusedRow, newFocusedCol);
  }

  /// Applies a computed focused-cell movement, scrolling it into view and
  /// notifying [VirtualisedGrid.focusedCellNotifier].
  ///
  /// Applies row and column movement together when both changed (possible
  /// with custom navigation callbacks).
  KeyEventResult _applyFocusedMovement(int? newFocusedRow, int? newFocusedCol) {
    final rowChanged = newFocusedRow != null && newFocusedRow != _focusedRow;
    final colChanged = newFocusedCol != null && newFocusedCol != _focusedCol;
    if (!rowChanged && !colChanged) return KeyEventResult.ignored;

    final row = newFocusedRow;
    final col = newFocusedCol;
    setState(() {
      if (rowChanged) {
        _focusedRow = row!;
        _ensureRowVisible(row);
      }
      if (colChanged) {
        _focusedCol = col!;
        _ensureColumnVisible(col);
      }
    });
    _updateFocusedCellNotifier();
    _scheduleCellFocused(_focusedRow, _focusedCol);
    return KeyEventResult.handled;
  }

  /// Lowercase key name used in navigation callback params.
  String _navKeyName(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.arrowDown) return 'arrowdown';
    if (key == LogicalKeyboardKey.arrowUp) return 'arrowup';
    if (key == LogicalKeyboardKey.arrowLeft) return 'arrowleft';
    if (key == LogicalKeyboardKey.arrowRight) return 'arrowright';
    if (key == LogicalKeyboardKey.pageDown) return 'pagedown';
    if (key == LogicalKeyboardKey.pageUp) return 'pageup';
    if (key == LogicalKeyboardKey.home) return 'home';
    if (key == LogicalKeyboardKey.end) return 'end';
    if (key == LogicalKeyboardKey.tab) return 'tab';
    return key.keyLabel.toLowerCase();
  }

  /// Updates the focused cell notifier with the current focused position.
  void _updateFocusedCellNotifier() {
    widget.focusedCellNotifier?.value = (row: _focusedRow, col: _focusedCol);
  }

  /// Schedules a post-frame [OsCellFocusedEvent] emission for the cell that
  /// was just focused (RULE ZERO: never emit synchronously during
  /// build/layout/gesture handling).
  void _scheduleCellFocused(int rowIndex, int columnIndex) {
    if (widget.onCellFocused == null) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onCellFocused?.call(
        OsCellFocusedEvent(rowIndex: rowIndex, columnIndex: columnIndex),
      );
    });
    // Ensure the post-frame callback runs even when nothing rebuilds.
    SchedulerBinding.instance.scheduleFrame();
  }

  /// Fires [OsCellKeyDownEvent] post-frame for printable + navigation keys
  /// pressed on a focused, non-editing cell. Purely informational.
  void _maybeFireCellKeyDown(KeyEvent event) {
    if (widget.onCellKeyDown == null) return;
    final rowCount = widget.rowData.length;
    final colCount = widget.columns.length;
    if (_focusedRow < 0 || _focusedCol < 0) return;
    if (_focusedRow >= rowCount || _focusedCol >= colCount) return;

    final logical = event.logicalKey;
    final isNavigation =
        logical == LogicalKeyboardKey.arrowDown ||
        logical == LogicalKeyboardKey.arrowUp ||
        logical == LogicalKeyboardKey.arrowLeft ||
        logical == LogicalKeyboardKey.arrowRight ||
        logical == LogicalKeyboardKey.pageUp ||
        logical == LogicalKeyboardKey.pageDown ||
        logical == LogicalKeyboardKey.home ||
        logical == LogicalKeyboardKey.end ||
        logical == LogicalKeyboardKey.tab ||
        logical == LogicalKeyboardKey.enter;

    String? printable;
    if (event is KeyDownEvent) {
      final character = event.character;
      if (character != null &&
          character.length == 1 &&
          character.codeUnitAt(0) >= 32 &&
          !_isModifierHeld()) {
        printable = character;
      }
    }
    if (!isNavigation && printable == null) return;

    final key = printable ?? logical.keyLabel;
    final physical = event.physicalKey;
    final physicalKey = physical.usbHidUsage == 0
        ? null
        : '0x${physical.usbHidUsage.toRadixString(16)}';
    final payload = OsCellKeyDownEvent(
      rowIndex: _focusedRow,
      columnIndex: _focusedCol,
      key: key,
      physicalKey: physicalKey,
    );
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onCellKeyDown?.call(payload);
    });
    // Ensure the post-frame callback runs even when nothing rebuilds.
    SchedulerBinding.instance.scheduleFrame();
  }

  /// Returns true if Ctrl, Alt, or Meta is currently held.
  bool _isModifierHeld() {
    return HardwareKeyboard.instance.logicalKeysPressed.any(
      (k) =>
          k == LogicalKeyboardKey.controlLeft ||
          k == LogicalKeyboardKey.controlRight ||
          k == LogicalKeyboardKey.altLeft ||
          k == LogicalKeyboardKey.altRight ||
          k == LogicalKeyboardKey.metaLeft ||
          k == LogicalKeyboardKey.metaRight,
    );
  }

  /// Returns true if Ctrl or Meta (Cmd on macOS) is currently held.
  bool _isCtrlOrMetaHeld() {
    return HardwareKeyboard.instance.logicalKeysPressed.any(
      (k) =>
          k == LogicalKeyboardKey.controlLeft ||
          k == LogicalKeyboardKey.controlRight ||
          k == LogicalKeyboardKey.metaLeft ||
          k == LogicalKeyboardKey.metaRight,
    );
  }

  /// Returns true if Shift is currently held.
  bool _isShiftHeld() {
    return HardwareKeyboard.instance.logicalKeysPressed.any(
      (k) =>
          k == LogicalKeyboardKey.shiftLeft ||
          k == LogicalKeyboardKey.shiftRight,
    );
  }

  void _ensureRowVisible(int rowIndex) {
    final dataAreaHeight = _viewportSize.height - _totalHeaderHeight;
    final rowTop = _getRowTop(rowIndex);
    final rowBottom = rowTop + _getRowHeight(rowIndex);

    if (rowTop < _scrollY) {
      _scrollY = rowTop;
    } else if (rowBottom > _scrollY + dataAreaHeight) {
      _scrollY = rowBottom - dataAreaHeight;
    }
    _scrollY = _scrollY.clamp(0.0, _maxScrollY);
  }

  void _ensureColumnVisible(int columnIndex) {
    // Only scroll horizontally for center (non-pinned) columns
    final layout = _getLayout();

    // Check if the column is pinned (left or right) — no scrolling needed.
    // Pinned sections render at fixed positions, so a left/right target is
    // always fully visible regardless of the horizontal scroll offset
    // (quality program v2 item 49).
    for (final entry in layout.leftCols) {
      if (entry.index == columnIndex) return;
    }
    for (final entry in layout.rightCols) {
      if (entry.index == columnIndex) return;
    }

    // Find the column's position within the center section
    double colStart = 0.0;
    double colWidth = 0.0;
    var found = false;
    for (final entry in layout.centerCols) {
      if (entry.index == columnIndex) {
        colWidth = entry.width;
        found = true;
        break;
      }
      colStart += entry.width;
    }
    // Unknown index (e.g. out-of-range navigation target): no-op rather
    // than spuriously scrolling to the end of the center section.
    if (!found) return;

    final centerViewportWidth =
        _viewportSize.width - layout.leftWidth - layout.rightWidth;
    final colEnd = colStart + colWidth;

    if (colStart < _scrollX) {
      _scrollX = colStart;
    } else if (colEnd > _scrollX + centerViewportWidth) {
      _scrollX = colEnd - centerViewportWidth;
    }
    _scrollX = _scrollX.clamp(0.0, _maxScrollX);
  }

  // Track whether a floating filter tap was handled on pointer down,
  // so we can skip it in onTapUp to avoid double-firing.
  bool _floatingFilterHandledOnDown = false;

  /// Handles pointer down events to immediately trigger floating filter taps.
  ///
  /// This bypasses the gesture arena's double-tap delay (300ms) which would
  /// otherwise prevent the floating filter overlay from appearing promptly.
  void _onPointerDown(PointerDownEvent event) {
    // A new pointer down cancels any in-flight ballistic scroll.
    _stopFling();

    // Remember the exact contact point for the fill-handle hit test.
    _pointerDownPosition = event.localPosition;

    final hit = _hitTestAt(event.localPosition);

    // Request focus immediately on pointer down so the focus indicator
    // appears without waiting for gesture arena resolution (which is
    // delayed by the double-tap recognizer). Skip when tapping a floating
    // filter cell — the filter overlay manages its own focus. Also skipped
    // entirely when cell focus is suppressed (quality program v2 item 14).
    if (!widget.suppressCellFocus && hit is! FloatingFilterCellHit) {
      _focusNode.requestFocus();
    }

    // Handle header filter icon tap immediately
    if (hit is HeaderFilterIconHit && widget.onHeaderFilterIconTap != null) {
      final iconRect = _getHeaderFilterIconRect(hit);
      if (iconRect != null) {
        _floatingFilterHandledOnDown = true;
        widget.onHeaderFilterIconTap!.call(hit, iconRect);
        return;
      }
    }

    // Handle header menu icon (⋮) tap immediately
    if (hit is HeaderMenuIconHit && widget.onHeaderMenuIconTap != null) {
      final iconRect = _getHeaderMenuIconRect(hit);
      if (iconRect != null) {
        _floatingFilterHandledOnDown = true;
        widget.onHeaderMenuIconTap!.call(hit, iconRect);
        return;
      }
    }

    if (widget.onFloatingFilterTap == null) return;

    if (hit is FloatingFilterCellHit) {
      // Check if the tap is on the operation indicator (left 28px of the input)
      final cellRect = _getFloatingFilterCellRect(hit);
      if (cellRect != null) {
        const operationIndicatorWidth = 28.0;
        const hPad = 6.0;
        final indicatorRight = cellRect.left + hPad + operationIndicatorWidth;

        if (event.localPosition.dx < indicatorRight &&
            hit.colDef.filter != null &&
            widget.onFloatingFilterOperationTap != null) {
          // Tap is on the operation indicator — show filter popup
          _floatingFilterHandledOnDown = true;
          widget.onFloatingFilterOperationTap!.call(hit.colDef.effectiveColId);
          return;
        }

        _floatingFilterHandledOnDown = true;
        widget.onFloatingFilterTap!.call(hit, cellRect);
      }
    }
  }

  /// Computes the local Rect of a floating filter cell for overlay positioning.
  Rect? _getFloatingFilterCellRect(FloatingFilterCellHit hit) {
    final layout = _getLayout();

    // The floating filter row top is below group header + column header
    final filterRowTop =
        widget.headerHeight +
        (widget.columnGroupSpans != null ? widget.groupHeaderHeight : 0);

    final colX = _columnVisualLeft(layout, hit.columnIndex);
    if (colX == null) return null;

    final colWidth = _getColumnWidth(hit.columnIndex);
    return Rect.fromLTWH(
      colX,
      filterRowTop,
      colWidth,
      widget.floatingFilterHeight,
    );
  }

  /// Computes the local Rect of the header cell for filter popup positioning.
  ///
  /// Returns a rect positioned at the bottom of the header cell (so the popup
  /// appears below the header).
  Rect? _getHeaderFilterIconRect(HeaderFilterIconHit hit) {
    final layout = _getLayout();

    // The header row top (below any group header)
    final headerTop = widget.columnGroupSpans != null
        ? widget.groupHeaderHeight
        : 0.0;

    final colX = _columnVisualLeft(layout, hit.columnIndex);
    if (colX == null) return null;

    final colWidth = _getColumnWidth(hit.columnIndex);
    return Rect.fromLTWH(colX, headerTop, colWidth, widget.headerHeight);
  }

  /// Computes the local Rect of the menu icon (⋮) for popup positioning.
  ///
  /// Returns a rect positioned at the bottom of the header cell, aligned
  /// to the right edge where the menu icon is painted.
  Rect? _getHeaderMenuIconRect(HeaderMenuIconHit hit) {
    final layout = _getLayout();

    // The header row top (below any group header)
    final headerTop = widget.columnGroupSpans != null
        ? widget.groupHeaderHeight
        : 0.0;

    final colX = _columnVisualLeft(layout, hit.columnIndex);
    if (colX == null) return null;

    final colWidth = _getColumnWidth(hit.columnIndex);
    return Rect.fromLTWH(colX, headerTop, colWidth, widget.headerHeight);
  }

  @override
  Widget build(BuildContext context) {
    buildCount++;
    final rowCount = widget.rowData.length;
    final colCount = widget.columns.length;

    // Resolve the ambient reading direction ONCE per build; gesture and
    // hit-test handlers read this stored value (item 48).
    _direction = Directionality.maybeOf(context) ?? TextDirection.ltr;

    return Semantics(
      container: true,
      textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
      label: _localeText == null
          ? 'Data grid with $rowCount rows and $colCount columns'
          : _localeText!.getLocaleText(
              'gridSummary',
              'Data grid with $rowCount rows and $colCount columns',
            ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          _viewportSize = Size(constraints.maxWidth, constraints.maxHeight);
          if (widget.useScrollController) {
            // Controller mode: create the position lazily, then apply
            // extents. Corrections are silent (no notifications), so this
            // is safe during build.
            _ensureHeadlessScroll();
            _syncHeadlessScrollExtents();
          } else {
            _scrollY = _scrollY.clamp(0.0, _maxScrollY);
          }
          _scrollX = _scrollX.clamp(0.0, _maxScrollX);

          // Update scroll position notifier for grid state service
          widget.scrollPositionNotifier?.value = Offset(_scrollX, _scrollY);

          // Report the centre (unpinned) viewport width — the exact space
          // the scrolling columns share, after both pinned sections have
          // taken their share. Only reported when it actually changes so
          // the owner's field write stays cheap.
          final centreWidth = _centreViewportWidth();
          if (centreWidth != _lastReportedCentreWidth) {
            _lastReportedCentreWidth = centreWidth;
            widget.onCentreViewportWidthChanged?.call(centreWidth);
          }

          // The gesture subtree is passed as `child` so cursor transitions
          // (rare) rebuild only the MouseRegion wrapper, and hover moves
          // rebuild only the CustomPaint below. Neither notifier write
          // re-runs this LayoutBuilder builder or any ancestor.
          return ValueListenableBuilder<SystemMouseCursor>(
            valueListenable: _cursorNotifier,
            child: GestureDetector(
              onPanStart: _onPanStart,
              onPanUpdate: _onPanUpdate,
              onPanEnd: _onPanEnd,
              onPanCancel: _onPanCancel,
              onSecondaryTapUp: (details) {
                final hit = _hitTestAt(details.localPosition);
                final DataCellHit? dataHit = hit is DataCellHit ? hit : null;
                if (!widget.suppressCellFocus) {
                  _focusNode.requestFocus();
                  if (dataHit != null) {
                    final prevRow = _focusedRow;
                    final prevCol = _focusedCol;
                    setState(() {
                      _focusedRow = dataHit.rowIndex;
                      _focusedCol = dataHit.columnIndex;
                    });
                    _updateFocusedCellNotifier();
                    if (prevRow != dataHit.rowIndex ||
                        prevCol != dataHit.columnIndex) {
                      _scheduleCellFocused(
                        dataHit.rowIndex,
                        dataHit.columnIndex,
                      );
                    }
                  }
                }
                if (hit is! EmptyHit) {
                  widget.onSecondaryTap?.call(hit, details.localPosition);
                }
              },
              onTapUp: (details) {
                final hit = _hitTestAt(details.localPosition);
                // Don't steal focus from the floating filter overlay, and
                // never move focus when cell focus is suppressed.
                if (!widget.suppressCellFocus &&
                    hit is! FloatingFilterCellHit) {
                  _focusNode.requestFocus();
                }
                _onTapUp(details);
                // Update focused row and column on click
                if (!widget.suppressCellFocus && hit is DataCellHit) {
                  final prevRow = _focusedRow;
                  final prevCol = _focusedCol;
                  setState(() {
                    _focusedRow = hit.rowIndex;
                    _focusedCol = hit.columnIndex;
                  });
                  _updateFocusedCellNotifier();
                  if (prevRow != hit.rowIndex || prevCol != hit.columnIndex) {
                    _scheduleCellFocused(hit.rowIndex, hit.columnIndex);
                  }
                }
              },
              onDoubleTapDown: _onDoubleTapDown,
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerSignal: _onPointerSignal,
                onPointerDown: _onPointerDown,
                child: ValueListenableBuilder<({int? row, String? col})>(
                  valueListenable: _hoverNotifier,
                  builder: (context, hover, _) =>
                      _buildGridPaint(constraints, hover),
                ),
              ),
            ),
            builder: (context, cursor, child) => Focus(
              focusNode: _focusNode,
              onKeyEvent: _handleKeyEvent,
              child: MouseRegion(
                cursor: cursor,
                onHover: _onPointerHover,
                onExit: (_) {
                  _cursorNotifier.value = SystemMouseCursors.basic;
                  _hoverNotifier.value = (row: null, col: null);
                  widget.onHoverChanged?.call(null, Offset.zero);
                },
                child: child,
              ),
            ),
          );
        },
      ),
    );
  }

  /// Builds the grid canvas from the current hover state.
  ///
  /// Invoked by the hover [ValueNotifier]'s scoped rebuild: a pointer move
  /// constructs fresh band painters (repainting only the affected composited
  /// layers) without rebuilding the surrounding widget subtree.
  ///
  /// Layered repaint architecture (quality program v3 item 5): one immutable
  /// [GridPaintContext] snapshot feeds six band painters stacked in the exact
  /// draw order the monolithic painter used — body (background + data rows),
  /// header bands, pinned row bands, selection overlays, flash overlays and
  /// scrollbars. Each band's [CustomPaint] sits inside its own
  /// [RepaintBoundary], and each painter's `shouldRepaint` compares only the
  /// inputs its pixels consume, so e.g. a pure vertical scroll skips the
  /// header layer and a flash tick only touches the flash layer.
  Widget _buildGridPaint(
    BoxConstraints constraints,
    ({int? row, String? col}) hover,
  ) {
    final canvasSize = Size(constraints.maxWidth, constraints.maxHeight);
    final ctx = GridPaintContext(
      columns: widget.columns,
      rowData: widget.rowData,
      rowHeight: widget.rowHeight,
      headerHeight: widget.headerHeight,
      scrollX: _scrollX,
      scrollY: _scrollY,
      theme: widget.theme,
      selectedRows: widget.selectedRows,
      hoveredRow: hover.row,
      hoveredColId: widget.columnHoverHighlight ? hover.col : null,
      columnWidths: List.generate(widget.columns.length, _getColumnWidth),
      sortColumnIndex: widget.sortColumnIndex,
      sortAscending: widget.sortAscending,
      sortIndicators: widget.sortIndicators,
      columnGroupSpans: widget.columnGroupSpans,
      groupHeaderHeight: widget.columnGroupSpans != null
          ? widget.groupHeaderHeight
          : 0,
      floatingFilterHeight: widget.floatingFilterHeight,
      floatingFilterTexts: widget.floatingFilterTexts,
      floatingFilterOperations: widget.floatingFilterOperations,
      cellRanges: widget.cellRanges,
      rowStyles: widget.rowStyles,
      pinnedTopRowData: widget.pinnedTopRowData,
      pinnedBottomRowData: widget.pinnedBottomRowData,
      pinnedTopRowStyles: widget.pinnedTopRowStyles,
      pinnedBottomRowStyles: widget.pinnedBottomRowStyles,
      cellFlashes: widget.cellFlashes,
      flashElapsed: widget.flashElapsed,
      cellSpanService: widget.cellSpanService,
      rowHeightLayout: widget.rowHeightLayout,
      suppressColumnVirtualisation: widget.suppressColumnVirtualisation,
      textPainterCache: widget.textPainterCache,
      textScaler: MediaQuery.textScalerOf(context),
      localeResolver: _localeText == null
          ? null
          : (key, def) => _localeText!.getLocaleText(key, def),
      textDirection: Directionality.maybeOf(context),
      focusedRow: _focusedRow,
      focusedCol: _focusedCol,
      valuePrefetch: widget.valuePrefetch,
      onImageLoaded: widget.onImageLoaded,
    );

    CustomPaint band(CustomPainter painter) =>
        CustomPaint(size: canvasSize, painter: painter);

    return Stack(
      fit: StackFit.expand,
      children: [
        // Bottom band is a BodyPainter — an instance of the public
        // GridPainter entry type carrying the semantics builder.
        RepaintBoundary(child: band(BodyPainter(ctx))),
        RepaintBoundary(child: band(HeaderPainter(ctx))),
        RepaintBoundary(child: band(PinnedRowPainter(ctx))),
        RepaintBoundary(
          child: band(
            RangePainter(
              ctx,
              fillHandleRect: widget.enableRangeSelection
                  ? _fillHandleRect()
                  : null,
              chartButtonRect: _rangeChartButtonRect(),
            ),
          ),
        ),
        RepaintBoundary(child: band(FlashOverlayPainter(ctx))),
        RepaintBoundary(child: band(ScrollbarPainter(ctx))),
        // Hybrid widget-cell overlay: real widgets positioned over their
        // cell rects, above the canvas bands. Placed AFTER the scrollbar
        // band because a full-canvas CustomPaint is opaque to the Stack's
        // first-hit-wins hit testing — the same reason the master/detail
        // band below sits last. Rebuilt with the canvas on scroll, so the
        // overlays track their cells.
        if (widget.cellWidgetBuilder != null)
          _buildWidgetCellOverlays(canvasSize),
        // Master/detail overlay (quality program v3 item 4): the detail
        // widget content positioned over each visible detail row's rect.
        // Rebuilt with the canvas on scroll, so overlays track the rows.
        if (widget.detailWidgetBuilder != null)
          _buildDetailOverlays(canvasSize),
      ],
    );
  }

  /// Builds the positioned overlay widgets for every VISIBLE detail row.
  ///
  /// The overlays live inside a band clipped to the scrollable data area
  /// (header + pinned rows are never overlapped) and are repositioned on
  /// every scroll rebuild because they read [_scrollY] directly.
  Widget _buildDetailOverlays(Size canvasSize) {
    final buildDetail = widget.detailWidgetBuilder;
    if (buildDetail == null) return const SizedBox.shrink();

    final dataAreaTop = _totalHeaderHeight + _pinnedTopHeight;
    final dataAreaHeight = math.max(
      0.0,
      canvasSize.height -
          _totalHeaderHeight -
          _pinnedTopHeight -
          _pinnedBottomHeight,
    );

    final children = <Widget>[];
    for (var r = 0; r < widget.rowData.length; r++) {
      final row = widget.rowData[r];
      if (row[MasterDetailKeys.isDetailRow] != true) continue;

      final top = dataAreaTop + _getRowTop(r) - _scrollY;
      final height = _getRowHeight(r);
      if (top + height <= dataAreaTop || top >= dataAreaTop + dataAreaHeight) {
        continue; // entirely off-screen
      }

      final rowId = row[MasterDetailKeys.detailRowId];
      children.add(
        Positioned(
          key: rowId is String ? ValueKey<String>('detail-$rowId') : null,
          left: 0,
          top: top - dataAreaTop,
          width: canvasSize.width,
          height: height,
          child: buildDetail(row),
        ),
      );
    }

    if (children.isEmpty) return const SizedBox.shrink();
    return Positioned(
      left: 0,
      top: dataAreaTop,
      width: canvasSize.width,
      height: dataAreaHeight,
      child: ClipRect(child: Stack(children: children)),
    );
  }

  /// Builds the positioned overlay widgets for every VISIBLE widget cell.
  ///
  /// Mirrors [_buildDetailOverlays]: a band clipped to the scrollable data
  /// area whose children are repositioned on every scroll rebuild because
  /// they read [_scrollY] directly. Only the visible row window is walked
  /// (via [_getRowIndexAtY]) and columns are culled per-section using the
  /// shared directional geometry, so the per-frame cost stays proportional
  /// to what is on screen. Performance-limited by design: one widget subtree
  /// per visible widget cell.
  Widget _buildWidgetCellOverlays(Size canvasSize) {
    final buildCell = widget.cellWidgetBuilder;
    if (buildCell == null) return const SizedBox.shrink();

    final dataAreaTop = _totalHeaderHeight + _pinnedTopHeight;
    final dataAreaHeight = math.max(
      0.0,
      canvasSize.height -
          _totalHeaderHeight -
          _pinnedTopHeight -
          _pinnedBottomHeight,
    );
    if (dataAreaHeight <= 0 || widget.rowData.isEmpty) {
      return const SizedBox.shrink();
    }

    final layout = _getLayout();
    final geom = _geometry(layout);

    final firstRow = _getRowIndexAtY(_scrollY).clamp(0, widget.rowData.length);
    final lastRow = (_getRowIndexAtY(_scrollY + dataAreaHeight) + 1).clamp(
      firstRow,
      widget.rowData.length,
    );

    // Resolve each section's visual x-offset for a column entry. Mirrors
    // [_columnVisualLeft] but walks pre-grouped section lists directly.
    double entryX(ColumnLayoutEntry entry, _Section section, double offset) {
      switch (section) {
        case _Section.left:
          return geom.pinnedX(
            sectionX: geom.leadingSectionX,
            sectionWidth: geom.leadingWidth,
            offset: offset,
            width: entry.width,
          );
        case _Section.center:
          return geom.centerX(
            offset: offset,
            width: entry.width,
            scrollX: _scrollX,
          );
        case _Section.right:
          return geom.pinnedX(
            sectionX: geom.trailingSectionX,
            sectionWidth: geom.trailingWidth,
            offset: offset,
            width: entry.width,
          );
      }
    }

    final children = <Widget>[];
    for (var r = firstRow; r < lastRow; r++) {
      final row = widget.rowData[r];
      // Detail rows are hit-test-transparent on the canvas; keep the overlay
      // band consistent by not layering widget cells over them either.
      if (row[MasterDetailKeys.isDetailRow] == true) continue;

      final top = _getRowTop(r) - _scrollY;
      final height = _getRowHeight(r);
      if (top + height <= 0 || top >= dataAreaHeight) continue;

      for (final section in _Section.values) {
        final entries = switch (section) {
          _Section.left => layout.leftCols,
          _Section.center => layout.centerCols,
          _Section.right => layout.rightCols,
        };
        var offset = 0.0;
        for (final entry in entries) {
          final x = entryX(entry, section, offset);
          offset += entry.width;
          if (x + entry.width <= 0 || x >= canvasSize.width) continue;

          final child = buildCell(r, entry.index, row);
          if (child == null) continue;

          children.add(
            Positioned(
              key: ValueKey('cell-widget-$r-${entry.index}'),
              left: x,
              top: top,
              width: entry.width,
              height: height,
              child: child,
            ),
          );
        }
      }
    }

    if (children.isEmpty) return const SizedBox.shrink();
    return Positioned(
      left: 0,
      top: dataAreaTop,
      width: canvasSize.width,
      height: dataAreaHeight,
      child: ClipRect(child: Stack(children: children)),
    );
  }

  // --- Row drag edge auto-scroll ---

  /// Starts/stops the row-drag auto-scroll timer based on where the pointer
  /// sits relative to the data area's top/bottom edge zones.
  void _updateRowDragAutoScroll(Offset position) {
    final dataAreaTop = _totalHeaderHeight + _pinnedTopHeight;
    final dataAreaBottom = _viewportSize.height - _pinnedBottomHeight;

    double delta = 0.0;
    if (position.dy < dataAreaTop + _rowDragEdgeZone) {
      delta = -_rowDragAutoScrollStep;
    } else if (position.dy > dataAreaBottom - _rowDragEdgeZone) {
      delta = _rowDragAutoScrollStep;
    }

    // No scrolling possible in the requested direction — don't spin a timer.
    final atBound =
        (delta < 0 && _scrollY <= 0) || (delta > 0 && _scrollY >= _maxScrollY);
    if (delta == 0.0 || atBound) {
      _stopRowDragAutoScroll();
      return;
    }

    _rowDragAutoScrollDelta = delta;
    if (_rowDragAutoScrollTimer?.isActive ?? false) return;
    _rowDragAutoScrollTimer = Timer.periodic(const Duration(milliseconds: 16), (
      _,
    ) {
      if (!mounted || !_isRowDragging) {
        _stopRowDragAutoScroll();
        return;
      }
      final before = _scrollY;
      setState(() {
        _scrollY = (_scrollY + _rowDragAutoScrollDelta).clamp(
          0.0,
          math.max(0.0, _maxScrollY),
        );
      });
      if (_scrollY == before) {
        // Reached a scroll bound — the edge zone check will re-arm the
        // timer on the next pointer move if it becomes relevant again.
        _stopRowDragAutoScroll();
        return;
      }
      // Content moved under a (possibly stationary) pointer — re-run the
      // drag update so the coordinator recomputes the drop target and
      // refreshes the indicator overlay.
      widget.onRowDragUpdate?.call(_lastRowDragPosition);
    });
  }

  void _stopRowDragAutoScroll() {
    _rowDragAutoScrollTimer?.cancel();
    _rowDragAutoScrollTimer = null;
  }
}

/// Which scrollbar element was hit.
enum _ScrollbarHit { vertical, horizontal, verticalTrack, horizontalTrack }

/// The three pinned/center column sections, for overlay walks.
enum _Section { left, center, right }

/// State for an in-progress scrollbar drag.
class _ScrollbarDrag {
  _ScrollbarDrag({
    required this.axis,
    required this.startOffset,
    required this.startPos,
  });

  final Axis axis;
  final double startOffset;
  final double startPos;
}
