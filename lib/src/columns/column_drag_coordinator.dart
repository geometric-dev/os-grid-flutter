import 'package:flutter/material.dart';

import '../params/value_formatter_params.dart';
import '../rendering/column_group_layout.dart';
import '../rendering/special_columns.dart';
import '../row_grouping/row_group_panel.dart';
import '../selection/os_row_selection.dart';
import '../theming/os_grid_theme.dart';
import 'os_column_def.dart';
import 'os_column_group.dart';
import 'os_column_pin.dart';

enum OsColumnDragSource { gridHeader, rowGroupPanel }

/// Owns the column header drag-to-reorder interaction for the grid.
///
/// Extracted from `_OsGridState`. The coordinator owns the active drag state
/// (dragging index, current pointer X, drop target, cached centre-column
/// midpoints) plus the full-screen overlay showing the ghost column and the
/// drop indicator.
///
/// All grid-owned collaborators are supplied as closures/getters so they
/// always read live state from the owning `State`.
class ColumnDragCoordinator<TData> {
  /// Creates a coordinator.
  ///
  /// The `onXxx`-style getters supply live widget config; [flattenColumnDefs]
  /// and [moveColumnByIndex] delegate back into the owning State's existing
  /// helpers.
  ColumnDragCoordinator({
    required GlobalKey<RowGroupPanelState>? Function() rowGroupPanelKey,
    required List<OsColumnDefBase> Function() columnDefs,
    required Set<String> Function() hiddenIds,
    required List<String>? Function() order,
    required Map<String, double> Function() widths,
    required List<OsColumnDef> Function() flatColumnsCache,
    required List<TData>? Function() resolveRows,
    required OsRowSelection? Function() rowSelection,
    required bool Function() rowNumbers,
    required bool Function() rowDrag,
    required double Function() effectiveHeaderHeight,
    required double Function() effectiveRowHeight,
    required OsGridTheme? Function() theme,
    required void Function(
      List<OsColumnDefBase> defs,
      List<OsColumnDef> outColumns,
      List<ColumnGroupSpan> outSpans,
    )
    flattenColumnDefs,
    required void Function(int fromIndex, int toIndex) moveColumnByIndex,
    required void Function(String colId, int insertIndex)? onRowGroupAdd,
    required void Function(String colId)? onRowGroupRemove,
    required void Function(int fromIndex, int toIndex)? onRowGroupMove,
    required BuildContext Function() context,
  }) : _rowGroupPanelKey = rowGroupPanelKey,
       _columnDefs = columnDefs,
       _hiddenColumnIds = hiddenIds,
       _columnOrder = order,
       _columnWidths = widths,
       _flatColumnsCache = flatColumnsCache,
       _resolveRows = resolveRows,
       _rowSelection = rowSelection,
       _rowNumbers = rowNumbers,
       _rowDrag = rowDrag,
       _effectiveHeaderHeight = effectiveHeaderHeight,
       _effectiveRowHeight = effectiveRowHeight,
       _theme = theme,
       _flattenColumnDefs = flattenColumnDefs,
       _moveColumnByIndex = moveColumnByIndex,
       _onRowGroupAdd = onRowGroupAdd,
       _onRowGroupRemove = onRowGroupRemove,
       _onRowGroupMove = onRowGroupMove,
       _context = context;

  final GlobalKey<RowGroupPanelState>? Function() _rowGroupPanelKey;
  final void Function(String colId, int insertIndex)? _onRowGroupAdd;
  final void Function(String colId)? _onRowGroupRemove;
  final void Function(int fromIndex, int toIndex)? _onRowGroupMove;
  final List<OsColumnDefBase> Function() _columnDefs;
  final Set<String> Function() _hiddenColumnIds;
  final List<String>? Function() _columnOrder;
  final Map<String, double> Function() _columnWidths;
  final List<OsColumnDef> Function() _flatColumnsCache;
  final List<TData>? Function() _resolveRows;
  final OsRowSelection? Function() _rowSelection;
  final bool Function() _rowNumbers;
  final bool Function() _rowDrag;
  final double Function() _effectiveHeaderHeight;
  final double Function() _effectiveRowHeight;
  final OsGridTheme? Function() _theme;
  final void Function(
    List<OsColumnDefBase> defs,
    List<OsColumnDef> outColumns,
    List<ColumnGroupSpan> outSpans,
  )
  _flattenColumnDefs;
  final void Function(int fromIndex, int toIndex) _moveColumnByIndex;
  final BuildContext Function() _context;

  OverlayEntry? _dragOverlayEntry;

  /// Effective column widths from VirtualisedGrid (set at drag start).
  List<double>? _dragEffectiveWidths;

  int? _draggingColumnIndex;
  int? _draggingRowGroupIndex;
  OsColumnDragSource _dragSource = OsColumnDragSource.gridHeader;
  double _dragCurrentX = 0.0;
  int? _dropTargetIndex;

  // Cached column positions for drag (computed once at drag start)
  List<int> _dragCenterIndices = const [];
  List<double> _dragCenterMidpoints = const [];
  double _dragScrollX = 0.0;

  void handleColumnDragStart(
    int columnIndex,
    double startX,
    double scrollX,
    List<double> effectiveWidths, {
    OsColumnDragSource source = OsColumnDragSource.gridHeader,
    int? rowGroupIndex,
  }) {
    _dragEffectiveWidths = effectiveWidths;
    // Pre-compute column positions for the duration of the drag
    _buildDragColumnPositions(scrollX);
    _draggingColumnIndex = columnIndex;
    _draggingRowGroupIndex = rowGroupIndex;
    _dragSource = source;
    _dragCurrentX = startX;
    _dropTargetIndex = null;
    _dragScrollX = scrollX;
    _showDragOverlay();
  }

  bool _isOverRowGroupPanel = false;
  int? _rowGroupInsertIndex;

  void handleColumnDragStartById(
    String colId,
    double startX,
    double scrollX, {
    OsColumnDragSource source = OsColumnDragSource.gridHeader,
    int? rowGroupIndex,
  }) {
    final cache = _flatColumnsCache();
    final index = cache.indexWhere((c) => c.effectiveColId == colId);
    if (index < 0) return;

    // We don't have effectiveWidths from the grid for the panel chips,
    // but the drag coordinator doesn't strictly need them to drag the overlay.
    // However, if dropped in the grid, it calculates drop target based on it.
    // If we drag from the panel, we might want to just set it to a dummy list or the actual widths if we had them.
    // For now, pass empty list as we only really care about drop inside the panel or removal.
    // If dropped in the grid, it will drop at the end or wherever, which is fine for now.
    handleColumnDragStart(
      index,
      startX,
      scrollX,
      const [],
      source: source,
      rowGroupIndex: rowGroupIndex,
    );
  }

  void updateRowGroupInsertIndex(int index) {
    if (_rowGroupInsertIndex != index) {
      _rowGroupInsertIndex = index;
      if (_isOverRowGroupPanel) {
        _rowGroupPanelKey()?.currentState?.updateIndicator(index);
      }
    }
  }

  void handleColumnDragUpdate(double currentX, Offset globalPosition) {
    _dragCurrentX = currentX;

    // Check if we are intersecting the row group panel with 10px hysteresis
    final panelKey = _rowGroupPanelKey();
    bool overPanel = false;

    if (panelKey != null) {
      final panelState = panelKey.currentState;
      if (panelState != null && panelState.mounted) {
        final panelContext = panelKey.currentContext;
        if (panelContext != null) {
          final renderBox = panelContext.findRenderObject() as RenderBox;
          final localPosition = renderBox.globalToLocal(globalPosition);

          final bounds = renderBox.paintBounds;
          const threshold = 10.0;

          if (_isOverRowGroupPanel) {
            // Must move 10px outside bounds to leave
            overPanel =
                localPosition.dx >= bounds.left - threshold &&
                localPosition.dx <= bounds.right + threshold &&
                localPosition.dy >= bounds.top - threshold &&
                localPosition.dy <= bounds.bottom + threshold;
          } else {
            // Must move 10px inside bounds to enter
            overPanel =
                localPosition.dx >= bounds.left + threshold &&
                localPosition.dx <= bounds.right - threshold &&
                localPosition.dy >= bounds.top + threshold &&
                // The primary boundary is the bottom edge (between panel and header)
                localPosition.dy <= bounds.bottom - threshold;
          }

          if (overPanel) {
            _isOverRowGroupPanel = true;
            _rowGroupInsertIndex = panelState.indexForGlobalPosition(
              globalPosition,
            );
            if (_rowGroupInsertIndex != null) {
              panelState.updateIndicator(_rowGroupInsertIndex!);
            }
          } else {
            panelState.clearIndicator();
            _isOverRowGroupPanel = false;
            _rowGroupInsertIndex = null;
          }
        } else {
          _isOverRowGroupPanel = false;
          _rowGroupInsertIndex = null;
        }
      } else {
        _isOverRowGroupPanel = false;
        _rowGroupInsertIndex = null;
      }
    } else {
      _isOverRowGroupPanel = false;
      _rowGroupInsertIndex = null;
    }

    _dragCurrentX = currentX;
    _dropTargetIndex = _calculateDropTargetIndexCached(_dragCurrentX);
    _dragOverlayEntry?.markNeedsBuild();
  }

  void handleColumnDragEnd() {
    final fromIndex = _draggingColumnIndex;
    final rowGroupFromIndex = _draggingRowGroupIndex;
    final toIndex = _dropTargetIndex;
    final overPanel = _isOverRowGroupPanel;
    final panelInsertIndex = _rowGroupInsertIndex;

    // Clear panel indicator
    _rowGroupPanelKey()?.currentState?.clearIndicator();

    removeDragOverlay();
    _draggingColumnIndex = null;
    _draggingRowGroupIndex = null;
    _dropTargetIndex = null;
    _isOverRowGroupPanel = false;
    _rowGroupInsertIndex = null;

    if (fromIndex != null && overPanel && panelInsertIndex != null) {
      final colDef = _flatColumnsCache()[fromIndex];
      if (_dragSource == OsColumnDragSource.rowGroupPanel &&
          rowGroupFromIndex != null) {
        _onRowGroupMove?.call(rowGroupFromIndex, panelInsertIndex);
      } else {
        _onRowGroupAdd?.call(colDef.effectiveColId, panelInsertIndex);
      }
      return;
    }

    if (fromIndex != null &&
        _dragSource == OsColumnDragSource.rowGroupPanel &&
        !overPanel) {
      final colDef = _flatColumnsCache()[fromIndex];
      _onRowGroupRemove?.call(colDef.effectiveColId);
      return;
    }

    if (fromIndex != null && toIndex != null && fromIndex != toIndex) {
      // Adjust indices: subtract special column offset (checkbox + row numbers)
      // since moveColumnByIndex works on _columnOrder which doesn't include them.
      int offset = 0;
      if (_rowSelection()?.hasCheckboxes == true) offset++;
      if (_rowNumbers()) offset++;
      if (_rowDrag()) offset++;

      final adjustedFrom = fromIndex - offset;
      final adjustedTo = toIndex - offset;

      if (adjustedFrom < 0 || adjustedTo < 0) return;

      // If moving right, account for the removal of the source
      final finalTo = adjustedTo > adjustedFrom ? adjustedTo - 1 : adjustedTo;
      if (finalTo != adjustedFrom) {
        _moveColumnByIndex(adjustedFrom, finalTo);
      }
    }
  }

  void _showDragOverlay() {
    removeDragOverlay();
    _dragOverlayEntry = OverlayEntry(
      builder: (context) => _buildDragOverlayContent(),
    );
    Overlay.of(_context()).insert(_dragOverlayEntry!);
  }

  /// Removes the drag overlay if shown. Call from the owning State's dispose.
  void removeDragOverlay() {
    _dragOverlayEntry?.remove();
    _dragOverlayEntry = null;
  }

  /// Releases overlay resources owned by this coordinator.
  void dispose() {
    removeDragOverlay();
  }

  Widget _buildDragOverlayContent() {
    if (_draggingColumnIndex == null) return const SizedBox.shrink();

    final dragColIndex = _draggingColumnIndex!;
    if (dragColIndex >= _flatColumnsCache().length) {
      return const SizedBox.shrink();
    }

    final col = _flatColumnsCache()[dragColIndex];
    final colWidth =
        (_dragEffectiveWidths != null &&
            dragColIndex < _dragEffectiveWidths!.length)
        ? _dragEffectiveWidths![dragColIndex]
        : (_columnWidths()[col.effectiveColId] ?? col.width ?? 150.0);
    final headerHeight = _effectiveHeaderHeight();
    final rowHeight = _effectiveRowHeight();
    final accentColor = _theme()?.accentColor ?? Colors.blue;
    final headerBg = _theme()?.headerBackgroundColor ?? Colors.grey.shade100;
    final cellBg = _theme()?.backgroundColor ?? Colors.white;
    final headerTextStyle =
        _theme()?.headerTextStyle ??
        const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        );
    final cellTextStyle =
        _theme()?.cellTextStyle ??
        const TextStyle(fontSize: 13, color: Colors.black87);
    final borderColor = _theme()?.borderColor ?? const Color(0xFFE2E2E2);

    // Get the RenderBox to convert local coords to global
    final renderBox = _context().findRenderObject() as RenderBox?;
    if (renderBox == null) return const SizedBox.shrink();
    final gridTopLeft = renderBox.localToGlobal(Offset.zero);

    final hasGroupHeaders = _columnDefs().any((d) => d is OsColumnGroup);
    final groupHeaderOffset = hasGroupHeaders ? 36.0 : 0.0;

    final dataRows = _resolveRows() as List<dynamic>? ?? [];
    final maxGhostRows = 8.clamp(0, dataRows.length);
    final ghostDataHeight = maxGhostRows * rowHeight;
    final totalGhostHeight =
        headerHeight + ghostDataHeight + 4.0; // +4 for border

    final ghostLeft = gridTopLeft.dx + _dragCurrentX - colWidth / 2;
    final ghostTop = gridTopLeft.dy + groupHeaderOffset;

    final widgets = <Widget>[];

    // Ghost column
    widgets.add(
      Positioned(
        left: ghostLeft,
        top: ghostTop,
        width: colWidth,
        height: totalGhostHeight,
        child: IgnorePointer(
          child: Opacity(
            opacity: 0.75,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(4),
              color: cellBg,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: accentColor, width: 1.5),
                  borderRadius: BorderRadius.circular(4),
                ),
                clipBehavior: Clip.hardEdge,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      height: headerHeight,
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: headerBg,
                        border: Border(bottom: BorderSide(color: borderColor)),
                      ),
                      child: Text(
                        col.effectiveHeaderName,
                        style: headerTextStyle,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    ...List.generate(maxGhostRows, (i) {
                      String cellText = '';
                      if (i < dataRows.length) {
                        final row = dataRows[i];
                        if (col.field != null && row is Map<String, dynamic>) {
                          final value = row[col.field];
                          if (col.valueFormatter != null && value != null) {
                            cellText = col.valueFormatter!(
                              ValueFormatterParams(value: value, rowIndex: i),
                            );
                          } else {
                            cellText = value?.toString() ?? '';
                          }
                        }
                      }
                      return Container(
                        height: rowHeight,
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          cellText,
                          style: cellTextStyle,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    // Drop indicator
    if (_dropTargetIndex != null) {
      final dropX = _getDropIndicatorX(_flatColumnsCache(), _dropTargetIndex!);
      if (dropX != null) {
        widgets.add(
          Positioned(
            left: gridTopLeft.dx + dropX - 1,
            top: ghostTop,
            width: 2,
            height: totalGhostHeight,
            child: IgnorePointer(child: Container(color: accentColor)),
          ),
        );
      }
    }

    return Stack(children: widgets);
  }

  /// Pre-computes column midpoints for fast drop target lookup during drag.
  /// Midpoints are in viewport coordinates (accounting for scroll offset).
  void _buildDragColumnPositions(double scrollX) {
    final flatCols = <OsColumnDef>[];
    final tempSpans = <ColumnGroupSpan>[];
    _flattenColumnDefs(_columnDefs(), flatCols, tempSpans);

    final displayOrder =
        _columnOrder() ?? flatCols.map((c) => c.effectiveColId).toList();
    final visibleOrder = displayOrder
        .where((id) => !_hiddenColumnIds().contains(id))
        .toList();

    final orderedCols = <OsColumnDef>[];
    if (_rowSelection()?.hasCheckboxes == true) {
      orderedCols.add(
        const OsColumnDef(
          field: SpecialColumns.checkbox,
          width: 48,
          sortable: false,
        ),
      );
    }
    if (_rowNumbers()) {
      orderedCols.add(
        const OsColumnDef(
          field: SpecialColumns.rowNumber,
          headerName: '#',
          width: 50,
          sortable: false,
        ),
      );
    }
    if (_rowDrag()) {
      orderedCols.add(
        const OsColumnDef(
          field: SpecialColumns.rowDrag,
          headerName: '',
          width: 32,
          sortable: false,
        ),
      );
    }
    for (final colId in visibleOrder) {
      final col = flatCols.cast<OsColumnDef?>().firstWhere(
        (c) => c!.effectiveColId == colId,
        orElse: () => null,
      );
      if (col != null) orderedCols.add(col);
    }

    final widths = <double>[];
    for (int i = 0; i < orderedCols.length; i++) {
      // Use the actual rendered widths from VirtualisedGrid when available
      if (_dragEffectiveWidths != null && i < _dragEffectiveWidths!.length) {
        widths.add(_dragEffectiveWidths![i]);
      } else {
        final col = orderedCols[i];
        widths.add(_columnWidths()[col.effectiveColId] ?? col.width ?? 150.0);
      }
    }

    // x starts at the right edge of left-pinned columns (their viewport position)
    var x = 0.0;
    for (int i = 0; i < orderedCols.length; i++) {
      if (orderedCols[i].pinned == OsColumnPin.left) {
        x += widths[i];
      }
    }

    // For center columns, subtract scrollX to get viewport coordinates
    final leftPinnedWidth = x;
    var centerAbsoluteX = 0.0;

    final centerIndices = <int>[];
    final centerMidpoints = <double>[];
    for (int i = 0; i < orderedCols.length; i++) {
      if (orderedCols[i].pinned == null) {
        centerIndices.add(i);
        // Viewport X = leftPinnedWidth + (absoluteX - scrollX)
        final viewportX = leftPinnedWidth + centerAbsoluteX - scrollX;
        centerMidpoints.add(viewportX + widths[i] / 2);
        centerAbsoluteX += widths[i];
      }
    }

    _dragCenterIndices = centerIndices;
    _dragCenterMidpoints = centerMidpoints;
  }

  /// Fast drop target lookup using cached midpoints (O(n) scan, no allocations).
  int? _calculateDropTargetIndexCached(double cursorX) {
    if (_dragCenterIndices.isEmpty) return null;

    for (int j = 0; j < _dragCenterMidpoints.length; j++) {
      if (cursorX < _dragCenterMidpoints[j]) {
        return _dragCenterIndices[j];
      }
    }
    return _dragCenterIndices.last + 1;
  }

  /// Calculates the X position for the drop indicator line (in viewport coordinates).
  double? _getDropIndicatorX(List<OsColumnDef> flatColumns, int dropIndex) {
    // Walk through columns to find the left edge of the drop target index
    var leftPinnedWidth = 0.0;

    // Left-pinned columns first
    for (int i = 0; i < flatColumns.length; i++) {
      if (flatColumns[i].pinned == OsColumnPin.left) {
        final w =
            (_dragEffectiveWidths != null && i < _dragEffectiveWidths!.length)
            ? _dragEffectiveWidths![i]
            : (_columnWidths()[flatColumns[i].effectiveColId] ??
                  flatColumns[i].width ??
                  150.0);
        leftPinnedWidth += w;
      }
    }

    // Center columns — account for scroll offset
    var centerAbsoluteX = 0.0;
    for (int i = 0; i < flatColumns.length; i++) {
      if (flatColumns[i].pinned == null) {
        if (i == dropIndex) {
          return leftPinnedWidth + centerAbsoluteX - _dragScrollX;
        }
        final w =
            (_dragEffectiveWidths != null && i < _dragEffectiveWidths!.length)
            ? _dragEffectiveWidths![i]
            : (_columnWidths()[flatColumns[i].effectiveColId] ??
                  flatColumns[i].width ??
                  150.0);
        centerAbsoluteX += w;
      }
    }

    // If dropIndex is past the last center column, return the right edge
    return leftPinnedWidth + centerAbsoluteX - _dragScrollX;
  }
}
