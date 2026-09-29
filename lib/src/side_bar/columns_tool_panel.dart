/// The Columns tool panel — lists grid columns with visibility checkboxes.
library;

import 'package:flutter/material.dart';

import '../columns/os_column_def.dart';
import '../columns/os_column_group.dart';
import '../locale/os_locale_text.dart';
import '../rendering/special_columns.dart';
import '../theming/os_grid_theme.dart';
import '../theming/resolved_grid_theme.dart';

/// A tool panel that displays the grid's columns in a tree structure
/// with checkboxes to toggle visibility.
///
/// Supports:
/// - Search/filter to find columns by name
/// - Expand/collapse column groups
/// - Select all / deselect all columns
class ColumnsToolPanel extends StatefulWidget {
  /// Creates a columns tool panel.
  const ColumnsToolPanel({
    super.key,
    required this.columns,
    required this.columnDefs,
    required this.hiddenColumnIds,
    this.theme,
    this.localeText,
    this.suppressFilter = false,
    this.suppressSelectAll = false,
    this.suppressExpandAll = false,
    this.contractGroups = false,
    this.onColumnVisibilityChanged,
  });

  /// All flat columns in the grid.
  final List<OsColumnDef> columns;

  /// Original column definitions including groups.
  final List<OsColumnDefBase> columnDefs;

  /// Currently hidden column IDs.
  final Set<String> hiddenColumnIds;

  /// Theme for styling.
  final OsGridTheme? theme;

  /// Localised labels for titles, search hint and control tooltips
  /// (defaults to English).
  final OsLocaleText? localeText;

  /// Whether to hide the search filter input.
  final bool suppressFilter;

  /// Whether to hide the Select All / Deselect All button.
  final bool suppressSelectAll;

  /// Whether to hide the Expand / Collapse All button.
  final bool suppressExpandAll;

  /// Whether groups start collapsed.
  final bool contractGroups;

  /// Callback when a column's visibility is toggled.
  final void Function(String colId, bool visible)? onColumnVisibilityChanged;

  @override
  State<ColumnsToolPanel> createState() => _ColumnsToolPanelState();
}

class _ColumnsToolPanelState extends State<ColumnsToolPanel> {
  String _filterText = '';
  final Set<String> _expandedGroups = {};
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (!widget.contractGroups) {
      // Expand all groups by default
      _expandAllGroups(widget.columnDefs);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _expandAllGroups(List<OsColumnDefBase> defs) {
    for (final def in defs) {
      if (def is OsColumnGroup) {
        _expandedGroups.add(def.groupId ?? def.headerName);
        _expandAllGroups(def.children);
      }
    }
  }

  void _handleSelectAll() {
    // Make all columns visible
    for (final col in widget.columns) {
      final colId = col.effectiveColId;
      if (_isSpecialColumn(colId)) continue;
      if (widget.hiddenColumnIds.contains(colId)) {
        widget.onColumnVisibilityChanged?.call(colId, true);
      }
    }
  }

  void _handleDeselectAll() {
    // Hide all columns
    for (final col in widget.columns) {
      final colId = col.effectiveColId;
      if (_isSpecialColumn(colId)) continue;
      if (!widget.hiddenColumnIds.contains(colId)) {
        widget.onColumnVisibilityChanged?.call(colId, false);
      }
    }
  }

  void _handleExpandAll() {
    setState(() {
      _expandAllGroups(widget.columnDefs);
    });
  }

  void _handleCollapseAll() {
    setState(() {
      _expandedGroups.clear();
    });
  }

  bool _isSpecialColumn(String colId) => SpecialColumns.isSpecial(colId);

  @override
  Widget build(BuildContext context) {
    final resolved = ResolvedGridTheme.from(widget.theme);
    final lt = widget.localeText ?? OsLocaleText.defaultLocale;

    final showHeader =
        !widget.suppressFilter ||
        !widget.suppressSelectAll ||
        !widget.suppressExpandAll;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Panel header with title
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: resolved.border, width: 1),
            ),
          ),
          child: Text(
            lt.columns,
            style: resolved.text(12, fontWeight: FontWeight.w600),
          ),
        ),
        // Header controls (search, select all, expand all)
        if (showHeader) _buildHeader(lt: lt, resolved: resolved),
        // Column list
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 2),
            children: _buildColumnTree(
              widget.columnDefs,
              resolved: resolved,
              depth: 0,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader({
    required OsLocaleText lt,
    required ResolvedGridTheme resolved,
  }) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: resolved.border, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Search input
          if (!widget.suppressFilter)
            SizedBox(
              height: 28,
              child: TextField(
                controller: _searchController,
                style: resolved.text(12),
                decoration: InputDecoration(
                  hintText: lt.searchOoo,
                  hintStyle: resolved.text(12, color: resolved.hintForeground),
                  prefixIcon: Icon(
                    Icons.search,
                    size: 16,
                    color: resolved.hintForeground,
                  ),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 28,
                    maxHeight: 28,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(resolved.controlRadius),
                    borderSide: BorderSide(color: resolved.border),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  isDense: true,
                ),
                onChanged: (text) => setState(() => _filterText = text),
              ),
            ),
          if (!widget.suppressSelectAll || !widget.suppressExpandAll)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  if (!widget.suppressExpandAll) ...[
                    _ToolbarIconButton(
                      icon: Icons.unfold_more,
                      tooltip: lt.expandAll,
                      onTap: _handleExpandAll,
                      color: resolved.foreground,
                    ),
                    _ToolbarIconButton(
                      icon: Icons.unfold_less,
                      tooltip: lt.collapseAll,
                      onTap: _handleCollapseAll,
                      color: resolved.foreground,
                    ),
                  ],
                  const Spacer(),
                  if (!widget.suppressSelectAll) ...[
                    _ToolbarIconButton(
                      icon: Icons.check_box_outlined,
                      tooltip: lt.selectAll,
                      onTap: _handleSelectAll,
                      color: resolved.foreground,
                    ),
                    _ToolbarIconButton(
                      icon: Icons.check_box_outline_blank,
                      tooltip: lt.deselectAll,
                      onTap: _handleDeselectAll,
                      color: resolved.foreground,
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildColumnTree(
    List<OsColumnDefBase> defs, {
    required ResolvedGridTheme resolved,
    required int depth,
  }) {
    final widgets = <Widget>[];

    for (final def in defs) {
      if (def is OsColumnGroup) {
        final groupId = def.groupId ?? def.headerName;
        final isExpanded = _expandedGroups.contains(groupId);

        // Check if any children match the filter
        final hasVisibleChildren = _groupHasVisibleChildren(def);
        if (_filterText.isNotEmpty && !hasVisibleChildren) continue;

        widgets.add(
          _ColumnGroupRow(
            group: def,
            isExpanded: isExpanded,
            depth: depth,
            resolved: resolved,
            onToggle: () {
              setState(() {
                if (isExpanded) {
                  _expandedGroups.remove(groupId);
                } else {
                  _expandedGroups.add(groupId);
                }
              });
            },
          ),
        );

        if (isExpanded) {
          widgets.addAll(
            _buildColumnTree(
              def.children,
              resolved: resolved,
              depth: depth + 1,
            ),
          );
        }
      } else if (def is OsColumnDef) {
        final colId = def.effectiveColId;
        if (_isSpecialColumn(colId)) continue;

        // Filter by search text
        if (_filterText.isNotEmpty) {
          final name = def.effectiveHeaderName.toLowerCase();
          if (!name.contains(_filterText.toLowerCase())) continue;
        }

        final isVisible = !widget.hiddenColumnIds.contains(colId);

        widgets.add(
          _ColumnRow(
            column: def,
            isVisible: isVisible,
            depth: depth,
            resolved: resolved,
            onToggle: () {
              widget.onColumnVisibilityChanged?.call(colId, !isVisible);
            },
          ),
        );
      }
    }

    return widgets;
  }

  bool _groupHasVisibleChildren(OsColumnGroup group) {
    for (final child in group.children) {
      if (child is OsColumnGroup) {
        if (_groupHasVisibleChildren(child)) return true;
      } else if (child is OsColumnDef) {
        final name = child.effectiveHeaderName.toLowerCase();
        if (name.contains(_filterText.toLowerCase())) return true;
      }
    }
    return false;
  }
}

/// A row representing a column group (expandable).
class _ColumnGroupRow extends StatelessWidget {
  const _ColumnGroupRow({
    required this.group,
    required this.isExpanded,
    required this.depth,
    required this.resolved,
    required this.onToggle,
  });

  final OsColumnGroup group;
  final bool isExpanded;
  final int depth;
  final ResolvedGridTheme resolved;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: EdgeInsets.only(left: 8.0 + depth * 16.0, right: 8),
        child: SizedBox(
          height: 28,
          child: Row(
            children: [
              Icon(
                isExpanded ? Icons.expand_more : Icons.chevron_right,
                size: 16,
                color: resolved.foreground,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  group.headerName,
                  style: resolved.text(12, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A row representing a single column with a visibility checkbox.
class _ColumnRow extends StatelessWidget {
  const _ColumnRow({
    required this.column,
    required this.isVisible,
    required this.depth,
    required this.resolved,
    required this.onToggle,
  });

  final OsColumnDef column;
  final bool isVisible;
  final int depth;
  final ResolvedGridTheme resolved;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: EdgeInsets.only(left: 8.0 + depth * 16.0, right: 8),
        child: SizedBox(
          height: 28,
          child: Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: Checkbox(
                  value: isVisible,
                  onChanged: (_) => onToggle(),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  activeColor: resolved.accent,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  column.effectiveHeaderName,
                  style: resolved.text(12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small icon button for the toolbar (expand all, collapse all, etc.).
class _ToolbarIconButton extends StatelessWidget {
  const _ToolbarIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}
