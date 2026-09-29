import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../columns/column_drag_coordinator.dart';
import '../columns/column_state.dart';
import '../columns/os_column_def.dart';
import '../os_grid_controller.dart';
import '../sorting/sort_direction.dart';
import '../sorting/sort_model.dart';
import '../theming/os_grid_theme.dart';
import '../theming/resolved_grid_theme.dart';

/// Row Grouping Panel (Drop Zone) for the top of the grid.
///
/// Displays currently grouped columns as interactive chips, and serves as a
/// drop target for the ColumnDragCoordinator to add new grouped columns.
class RowGroupPanel extends StatefulWidget {
  const RowGroupPanel({
    super.key,
    required this.controller,
    required this.resolvedTheme,
    this.baseTheme,
    this.columnDragCoordinator,
  });

  final OsGridController controller;
  final ResolvedGridTheme resolvedTheme;
  final OsGridTheme? baseTheme;
  final ColumnDragCoordinator? columnDragCoordinator;

  @override
  State<RowGroupPanel> createState() => RowGroupPanelState();
}

class RowGroupPanelState extends State<RowGroupPanel> {
  int? _insertIndex;
  final GlobalKey _rowKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();

  @visibleForTesting
  ScrollController get scrollController => _scrollController;

  Timer? _autoScrollTimer;
  Offset? _lastGlobalPosition;
  double _autoScrollDelta = 0.0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onGridEvent);
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_lastGlobalPosition != null &&
        _insertIndex != null &&
        widget.columnDragCoordinator != null) {
      final newIndex = _computeIndexFromGlobalPosition(_lastGlobalPosition!);
      if (newIndex != _insertIndex) {
        widget.columnDragCoordinator!.updateRowGroupInsertIndex(newIndex);
      }
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onGridEvent);
    _scrollController.dispose();
    _autoScrollTimer?.cancel();
    super.dispose();
  }

  void updateIndicator(int index) {
    setState(() {
      _insertIndex = index;
    });
  }

  void clearIndicator() {
    setState(() {
      _insertIndex = null;
    });
    _stopAutoScroll();
    _lastGlobalPosition = null;
  }

  int indexForGlobalPosition(Offset globalPosition) {
    _lastGlobalPosition = globalPosition;
    final panelBox = context.findRenderObject() as RenderBox?;
    if (panelBox != null) {
      final panelLocal = panelBox.globalToLocal(globalPosition);
      if (panelLocal.dx < 30) {
        _autoScrollDelta = -5;
        _startAutoScroll();
      } else if (panelLocal.dx > panelBox.size.width - 30) {
        _autoScrollDelta = 5;
        _startAutoScroll();
      } else {
        _stopAutoScroll();
      }
    }

    return _computeIndexFromGlobalPosition(globalPosition);
  }

  int _computeIndexFromGlobalPosition(Offset globalPosition) {
    final groupColIds = widget.controller.getRowGroupColumns();
    final rowContext = _rowKey.currentContext;
    if (rowContext == null) return groupColIds.length;

    final rowBox = rowContext.findRenderObject() as RenderBox;
    final localPosition = rowBox.globalToLocal(globalPosition);
    final dx = localPosition.dx;

    // Rough approximation for now: assume chips take ~120 logical pixels
    return (dx / 120).clamp(0, groupColIds.length).round();
  }

  void _startAutoScroll() {
    if (_autoScrollTimer?.isActive ?? false) return;
    _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 16), (
      timer,
    ) {
      if (!mounted || _lastGlobalPosition == null) {
        _stopAutoScroll();
        return;
      }
      _autoScroll(_autoScrollDelta);

      // Tell the coordinator that the drop index might have changed due to scroll!
      if (widget.columnDragCoordinator != null) {
        final newIndex = _computeIndexFromGlobalPosition(_lastGlobalPosition!);
        widget.columnDragCoordinator!.updateRowGroupInsertIndex(newIndex);
      }
    });
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
  }

  void _autoScroll(double delta) {
    if (!_scrollController.hasClients) return;
    final currentScroll = _scrollController.position.pixels;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final minScroll = _scrollController.position.minScrollExtent;

    final targetScroll = (currentScroll + delta).clamp(minScroll, maxScroll);
    if (targetScroll != currentScroll) {
      _scrollController.jumpTo(targetScroll);
    }
  }

  void _onGridEvent() {
    // In Phase 1, we just rebuild when a relevant event happens.
    // In a real scenario, we'd listen to specific column/group events.
    // Assuming OsGrid rebuilds this when rowGroupColumns change,
    // this might not be strictly needed for group changes, but
    // it's useful for sort state changes on the grouped columns.
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final themeData =
        widget.baseTheme?.rowGroupPanelTheme ?? const RowGroupPanelThemeData();
    final height = themeData.height;
    final bgColor = themeData.backgroundColor ?? widget.resolvedTheme.chrome;

    final groupColIds = widget.controller.getRowGroupColumns();
    final colDefs = <OsColumnDef>[];
    for (final id in groupColIds) {
      final col = widget.controller.getColumnDef(id);
      if (col != null) {
        colDefs.add(col);
      }
    }

    return Container(
      height: height,
      color: bgColor,
      width: double.infinity,
      child: colDefs.isEmpty
          ? _buildPlaceholder(themeData)
          : _buildChips(context, colDefs, themeData),
    );
  }

  Widget _buildPlaceholder(RowGroupPanelThemeData themeData) {
    final borderColor = widget.resolvedTheme.border;
    final textColor = widget.resolvedTheme.foreground.withValues(alpha: 0.5);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
      child: Container(
        decoration:
            themeData.placeholderBorder ??
            BoxDecoration(
              border: Border.all(color: borderColor, style: BorderStyle.solid),
              borderRadius: BorderRadius.circular(4),
            ),
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'Drag here to set row groups',
            style:
                themeData.placeholderTextStyle ??
                TextStyle(color: textColor, fontSize: 13),
          ),
        ),
      ),
    );
  }

  Widget _buildChips(
    BuildContext context,
    List<OsColumnDef> cols,
    RowGroupPanelThemeData themeData,
  ) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return Scrollbar(
      controller: _scrollController,
      child: SingleChildScrollView(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Row(
          key: _rowKey,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (int i = 0; i <= cols.length; i++) ...[
              if (_insertIndex == i)
                Container(
                  width: 2,
                  height: 24,
                  color:
                      themeData.dragIndicatorColor ??
                      widget.resolvedTheme.accent,
                  margin: const EdgeInsets.symmetric(horizontal: 4.0),
                ),
              if (i < cols.length) ...[
                _buildChip(cols[i], themeData, i),
                if (i < cols.length - 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: Icon(
                      isRtl ? Icons.chevron_left : Icons.chevron_right,
                      size: 16,
                      color: widget.resolvedTheme.border,
                    ),
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChip(
    OsColumnDef col,
    RowGroupPanelThemeData themeData,
    int rowGroupIndex,
  ) {
    final colState = widget.controller.getColumnState();
    // Use firstWhere with an explicit cast if needed or iteration
    ColumnState? state;
    for (final s in colState) {
      if (s.colId == col.effectiveColId) {
        state = s;
        break;
      }
    }

    final sort = state?.sort; // OsSortDirection
    final headerName = col.headerName ?? col.field ?? col.effectiveColId;
    final fgColor = widget.resolvedTheme.foreground;
    final bgColor = widget.resolvedTheme.background;
    final borderColor = widget.resolvedTheme.border;

    return GestureDetector(
      onTap: () => _toggleSort(col.effectiveColId),
      onHorizontalDragStart: (details) {
        widget.columnDragCoordinator?.handleColumnDragStartById(
          col.effectiveColId,
          details.globalPosition.dx,
          0.0,
          source: OsColumnDragSource.rowGroupPanel,
          rowGroupIndex: rowGroupIndex,
        );
      },
      onHorizontalDragUpdate: (details) {
        widget.columnDragCoordinator?.handleColumnDragUpdate(
          details.globalPosition.dx,
          details.globalPosition,
        );
      },
      onHorizontalDragEnd: (details) {
        widget.columnDragCoordinator?.handleColumnDragEnd();
      },
      onHorizontalDragCancel: () {
        widget.columnDragCoordinator?.handleColumnDragEnd();
      },
      child: Semantics(
        label: 'Row Group: $headerName',
        customSemanticsActions: {
          const CustomSemanticsAction(label: 'Remove group'): () {
            widget.controller.removeRowGroupColumn(col.effectiveColId);
          },
          const CustomSemanticsAction(label: 'Toggle sort'): () {
            _toggleSort(col.effectiveColId);
          },
          if (rowGroupIndex > 0)
            const CustomSemanticsAction(label: 'Move group left'): () {
              widget.controller.moveRowGroupColumn(
                rowGroupIndex,
                rowGroupIndex - 1,
              );
            },
          if (rowGroupIndex < widget.controller.getRowGroupColumns().length - 1)
            const CustomSemanticsAction(label: 'Move group right'): () {
              widget.controller.moveRowGroupColumn(
                rowGroupIndex,
                rowGroupIndex + 1,
              );
            },
        },
        child: Container(
          decoration:
              themeData.chipDecoration ??
              BoxDecoration(
                color: bgColor,
                border: Border.all(color: borderColor),
                borderRadius: BorderRadius.circular(16),
              ),
          padding: const EdgeInsets.only(
            left: 8.0,
            right: 4.0,
            top: 4.0,
            bottom: 4.0,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.drag_indicator,
                size: 16,
                color: fgColor.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 150),
                  child: Tooltip(
                    message: headerName,
                    child: Text(
                      headerName,
                      overflow: TextOverflow.ellipsis,
                      style:
                          themeData.chipTextStyle ??
                          TextStyle(
                            fontSize: 12,
                            color: fgColor,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              InkWell(
                onTap: () => _toggleSort(col.effectiveColId),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Icon(
                    sort == OsSortDirection.descending
                        ? Icons.arrow_downward
                        : Icons.arrow_upward,
                    size: 14,
                    color: sort == null
                        ? fgColor.withValues(alpha: 0.2)
                        : widget.resolvedTheme.accent,
                  ),
                ),
              ),
              InkWell(
                onTap: () {
                  widget.controller.removeRowGroupColumn(col.effectiveColId);
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Icon(
                    Icons.close,
                    size: 14,
                    color: fgColor.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleSort(String colId) {
    final currentSort = widget.controller.getSortModel().toList();
    final index = currentSort.indexWhere((s) => s.colId == colId);

    if (index == -1) {
      currentSort.add(
        OsSortModel(colId: colId, sort: OsSortDirection.ascending),
      );
    } else {
      if (currentSort[index].sort == OsSortDirection.ascending) {
        currentSort[index] = OsSortModel(
          colId: colId,
          sort: OsSortDirection.descending,
        );
      } else {
        currentSort.removeAt(index);
      }
    }
    widget.controller.setSortModel(currentSort);
  }
}
