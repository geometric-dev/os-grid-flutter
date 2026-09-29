/// The side bar widget that renders the button strip and active tool panel.
library;

import 'package:flutter/material.dart';

import '../columns/os_column_def.dart';
import '../filtering/filter_model.dart';
import '../locale/os_locale_text.dart';
import '../theming/os_grid_theme.dart';
import '../theming/resolved_grid_theme.dart';
import 'columns_tool_panel.dart';
import 'filters_tool_panel.dart';
import 'os_side_bar_def.dart';
import 'os_tool_panel_def.dart';

/// Internal side bar widget rendered alongside the grid.
///
/// This is not intended to be used directly — it is composed by the OsGrid
/// widget when a [OsSideBarDef] is provided.
class OsSideBar extends StatefulWidget {
  /// Creates a side bar widget.
  const OsSideBar({
    super.key,
    required this.sideBarDef,
    required this.columns,
    required this.columnDefs,
    required this.hiddenColumnIds,
    required this.filterModel,
    this.theme,
    this.localeText,
    this.openToolPanelId,
    this.onToolPanelToggled,
    this.onColumnVisibilityChanged,
    this.onPanelWidthChanged,
  });

  /// The side bar configuration.
  final OsSideBarDef sideBarDef;

  /// All flat columns currently in the grid (for the columns tool panel).
  final List<OsColumnDef> columns;

  /// Original column definitions including groups (for tree display).
  final List<OsColumnDefBase> columnDefs;

  /// Set of currently hidden column IDs.
  final Set<String> hiddenColumnIds;

  /// Current filter model (for the filters tool panel).
  final Map<String, OsColumnFilterModel> filterModel;

  /// Theme for styling.
  final OsGridTheme? theme;

  /// Localised labels for panel titles and controls (defaults to English).
  final OsLocaleText? localeText;

  /// The currently open tool panel ID, or null if none is open.
  final String? openToolPanelId;

  /// Callback when a tool panel button is toggled.
  final void Function(String? panelId)? onToolPanelToggled;

  /// Callback when a column's visibility is toggled in the columns panel.
  final void Function(String colId, bool visible)? onColumnVisibilityChanged;

  /// Callback when the panel width changes via resize.
  final void Function(double width)? onPanelWidthChanged;

  @override
  State<OsSideBar> createState() => _OsSideBarState();
}

class _OsSideBarState extends State<OsSideBar> {
  late double _panelWidth;
  bool _isResizing = false;

  @override
  void initState() {
    super.initState();
    _panelWidth = _activeToolPanelDef?.initialWidth ?? 250;
  }

  OsToolPanelDef? get _activeToolPanelDef {
    if (widget.openToolPanelId == null) return null;
    return widget.sideBarDef.toolPanels
        .where((p) => p.id == widget.openToolPanelId)
        .firstOrNull;
  }

  void _handleButtonTap(String panelId) {
    if (widget.openToolPanelId == panelId) {
      // Close the currently open panel
      widget.onToolPanelToggled?.call(null);
    } else {
      // Open the tapped panel
      widget.onToolPanelToggled?.call(panelId);
    }
  }

  void _handleResizeStart(DragStartDetails details) {
    setState(() => _isResizing = true);
  }

  void _handleResizeUpdate(DragUpdateDetails details) {
    final activeDef = _activeToolPanelDef;
    if (activeDef == null) return;

    final isLeft = widget.sideBarDef.position == OsSideBarPosition.left;
    final delta = isLeft ? details.delta.dx : -details.delta.dx;

    setState(() {
      _panelWidth = (_panelWidth + delta).clamp(
        activeDef.minWidth,
        activeDef.maxWidth ?? 600,
      );
    });
  }

  void _handleResizeEnd(DragEndDetails details) {
    setState(() => _isResizing = false);
    widget.onPanelWidthChanged?.call(_panelWidth);
  }

  @override
  Widget build(BuildContext context) {
    final resolved = ResolvedGridTheme.from(widget.theme);
    final bgColor = resolved.background;
    final borderColor = resolved.border;
    final accentColor = resolved.accent;
    final foregroundColor = resolved.foreground;
    final isLeft = widget.sideBarDef.position == OsSideBarPosition.left;

    // Build tab buttons
    final buttons = widget.sideBarDef.hideButtons
        ? const SizedBox.shrink()
        : _buildButtonStrip(
            accentColor: accentColor,
            foregroundColor: foregroundColor,
            bgColor: bgColor,
            borderColor: borderColor,
          );

    // Build the active panel content
    final panelContent = widget.openToolPanelId != null
        ? _buildPanelContent()
        : const SizedBox.shrink();

    // Build the resize handle
    final resizeHandle = widget.openToolPanelId != null
        ? _buildResizeHandle(borderColor)
        : const SizedBox.shrink();

    // Compose the side bar layout
    final panelWithResize = widget.openToolPanelId != null
        ? SizedBox(width: _panelWidth, child: panelContent)
        : const SizedBox.shrink();

    // Arrange components based on position
    final children = isLeft
        ? [buttons, resizeHandle, panelWithResize]
        : [panelWithResize, resizeHandle, buttons];

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          left: isLeft
              ? BorderSide.none
              : BorderSide(color: borderColor, width: 1),
          right: isLeft
              ? BorderSide(color: borderColor, width: 1)
              : BorderSide.none,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget _buildButtonStrip({
    required Color accentColor,
    required Color foregroundColor,
    required Color bgColor,
    required Color borderColor,
  }) {
    return Container(
      width: 32,
      decoration: BoxDecoration(
        border: Border(
          left: widget.sideBarDef.position == OsSideBarPosition.right
              ? BorderSide(color: borderColor, width: 1)
              : BorderSide.none,
          right: widget.sideBarDef.position == OsSideBarPosition.left
              ? BorderSide(color: borderColor, width: 1)
              : BorderSide.none,
        ),
      ),
      child: Column(
        children: [
          for (final panel in widget.sideBarDef.toolPanels)
            _SideBarButton(
              panelDef: panel,
              isSelected: widget.openToolPanelId == panel.id,
              accentColor: accentColor,
              foregroundColor: foregroundColor,
              onTap: () => _handleButtonTap(panel.id),
            ),
        ],
      ),
    );
  }

  Widget _buildResizeHandle(Color borderColor) {
    if (widget.openToolPanelId == null) return const SizedBox.shrink();

    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        onHorizontalDragStart: _handleResizeStart,
        onHorizontalDragUpdate: _handleResizeUpdate,
        onHorizontalDragEnd: _handleResizeEnd,
        child: Container(
          width: 4,
          color: _isResizing ? borderColor : Colors.transparent,
        ),
      ),
    );
  }

  Widget _buildPanelContent() {
    final activeDef = _activeToolPanelDef;
    if (activeDef == null) return const SizedBox.shrink();

    switch (activeDef.toolPanelType) {
      case OsToolPanelType.columns:
        return ColumnsToolPanel(
          columns: widget.columns,
          columnDefs: widget.columnDefs,
          hiddenColumnIds: widget.hiddenColumnIds,
          theme: widget.theme,
          localeText: widget.localeText,
          suppressFilter: activeDef.suppressColumnFilter,
          suppressSelectAll: activeDef.suppressColumnSelectAll,
          suppressExpandAll: activeDef.suppressColumnExpandAll,
          contractGroups: activeDef.contractColumnSelection,
          onColumnVisibilityChanged: widget.onColumnVisibilityChanged,
        );
      case OsToolPanelType.filters:
        return FiltersToolPanel(
          columns: widget.columns,
          filterModel: widget.filterModel,
          theme: widget.theme,
          localeText: widget.localeText,
          suppressSearch: activeDef.suppressFilterSearch,
          suppressExpandAll: activeDef.suppressExpandAll,
        );
      case OsToolPanelType.custom:
        if (activeDef.toolPanelBuilder != null) {
          return Builder(builder: activeDef.toolPanelBuilder!);
        }
        return const SizedBox.shrink();
    }
  }
}

/// A single button in the side bar's vertical button strip.
class _SideBarButton extends StatelessWidget {
  const _SideBarButton({
    required this.panelDef,
    required this.isSelected,
    required this.accentColor,
    required this.foregroundColor,
    required this.onTap,
  });

  final OsToolPanelDef panelDef;
  final bool isSelected;
  final Color accentColor;
  final Color foregroundColor;
  final VoidCallback onTap;

  IconData get _icon {
    if (panelDef.iconData != null) return panelDef.iconData!;
    switch (panelDef.toolPanelType) {
      case OsToolPanelType.columns:
        return Icons.view_column_outlined;
      case OsToolPanelType.filters:
        return Icons.filter_list;
      case OsToolPanelType.custom:
        return Icons.extension;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: panelDef.labelDefault,
      waitDuration: const Duration(milliseconds: 500),
      child: Semantics(
        button: true,
        selected: isSelected,
        label: panelDef.labelDefault,
        child: InkWell(
          onTap: onTap,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isSelected
                  ? accentColor.withValues(alpha: 0.1)
                  : Colors.transparent,
              border: isSelected
                  ? Border(left: BorderSide(color: accentColor, width: 2))
                  : null,
            ),
            child: Icon(
              _icon,
              size: 18,
              color: isSelected ? accentColor : foregroundColor,
            ),
          ),
        ),
      ),
    );
  }
}
