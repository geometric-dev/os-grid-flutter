/// The Filters tool panel — lists filterable columns with filter status.
library;

import 'package:flutter/material.dart';

import '../columns/os_column_def.dart';
import '../filtering/filter_model.dart';
import '../locale/os_locale_text.dart';
import '../rendering/special_columns.dart';
import '../theming/os_grid_theme.dart';
import '../theming/resolved_grid_theme.dart';

// Uses OsColumnFilterModel from filter_model.dart

/// A tool panel that displays all filterable columns with their
/// current filter status (active/inactive).
///
/// Supports:
/// - Search to find columns by name
/// - Expand/collapse individual filter entries
/// - Shows active filter indicator per column
class FiltersToolPanel extends StatefulWidget {
  /// Creates a filters tool panel.
  const FiltersToolPanel({
    super.key,
    required this.columns,
    required this.filterModel,
    this.theme,
    this.localeText,
    this.suppressSearch = false,
    this.suppressExpandAll = false,
  });

  /// All flat columns in the grid.
  final List<OsColumnDef> columns;

  /// Current filter model keyed by column ID.
  final Map<String, OsColumnFilterModel> filterModel;

  /// Theme for styling.
  final OsGridTheme? theme;

  /// Localised labels for title, summaries and controls (defaults to English).
  final OsLocaleText? localeText;

  /// Whether to hide the search input.
  final bool suppressSearch;

  /// Whether to hide the Expand All / Collapse All buttons.
  final bool suppressExpandAll;

  @override
  State<FiltersToolPanel> createState() => _FiltersToolPanelState();
}

class _FiltersToolPanelState extends State<FiltersToolPanel> {
  String _filterText = '';
  final Set<String> _expandedFilters = {};
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<OsColumnDef> get _filterableColumns {
    return widget.columns
        .where((col) => col.filter != null)
        .where((col) => !_isSpecialColumn(col.effectiveColId))
        .toList();
  }

  bool _isSpecialColumn(String colId) => SpecialColumns.isSpecial(colId);

  void _handleExpandAll() {
    setState(() {
      for (final col in _filterableColumns) {
        _expandedFilters.add(col.effectiveColId);
      }
    });
  }

  void _handleCollapseAll() {
    setState(() {
      _expandedFilters.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final resolved = ResolvedGridTheme.from(widget.theme);
    final lt = widget.localeText ?? OsLocaleText.defaultLocale;

    final showHeader = !widget.suppressSearch || !widget.suppressExpandAll;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Panel header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: resolved.border, width: 1),
            ),
          ),
          child: Text(
            lt.filters,
            style: resolved.text(12, fontWeight: FontWeight.w600),
          ),
        ),
        // Header controls
        if (showHeader) _buildHeader(lt: lt, resolved: resolved),
        // Filters list
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 2),
            children: _buildFilterList(lt: lt, resolved: resolved),
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
          if (!widget.suppressSearch)
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
          if (!widget.suppressExpandAll)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
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
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildFilterList({
    required OsLocaleText lt,
    required ResolvedGridTheme resolved,
  }) {
    final columns = _filterableColumns;
    final widgets = <Widget>[];

    for (final col in columns) {
      final colId = col.effectiveColId;
      final headerName = col.effectiveHeaderName;

      // Filter by search text
      if (_filterText.isNotEmpty) {
        if (!headerName.toLowerCase().contains(_filterText.toLowerCase())) {
          continue;
        }
      }

      final isActive = widget.filterModel.containsKey(colId);
      final isExpanded = _expandedFilters.contains(colId);

      widgets.add(
        _FilterColumnRow(
          colId: colId,
          headerName: headerName,
          isActive: isActive,
          isExpanded: isExpanded,
          resolved: resolved,
          localeText: lt,
          filterModel: isActive ? widget.filterModel[colId] : null,
          onToggleExpand: () {
            setState(() {
              if (isExpanded) {
                _expandedFilters.remove(colId);
              } else {
                _expandedFilters.add(colId);
              }
            });
          },
        ),
      );
    }

    return widgets;
  }
}

/// A row representing a filterable column in the filters panel.
class _FilterColumnRow extends StatelessWidget {
  const _FilterColumnRow({
    required this.colId,
    required this.headerName,
    required this.isActive,
    required this.isExpanded,
    required this.resolved,
    required this.localeText,
    required this.onToggleExpand,
    this.filterModel,
  });

  final String colId;
  final String headerName;
  final bool isActive;
  final bool isExpanded;
  final ResolvedGridTheme resolved;
  final OsLocaleText localeText;
  final OsColumnFilterModel? filterModel;
  final VoidCallback onToggleExpand;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onToggleExpand,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
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
                      headerName,
                      style: resolved.text(12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isActive)
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: resolved.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (isExpanded && filterModel != null) _buildFilterSummary(),
        if (isExpanded && filterModel == null)
          Padding(
            padding: const EdgeInsets.only(left: 28, right: 8, bottom: 4),
            child: Text(
              localeText.noActiveFilter,
              style: resolved
                  .text(11, color: resolved.hintForeground)
                  .copyWith(fontStyle: FontStyle.italic),
            ),
          ),
      ],
    );
  }

  Widget _buildFilterSummary() {
    final model = filterModel!;
    final description = _describeFilter(model);

    return Padding(
      padding: const EdgeInsets.only(left: 28, right: 8, bottom: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: resolved.accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          description,
          style: resolved.text(11, color: resolved.accent),
        ),
      ),
    );
  }

  String _describeFilter(OsColumnFilterModel model) {
    final lt = localeText;
    if (model.conditions.isEmpty) return lt.active;

    final firstCondition = model.conditions.first;
    final type = firstCondition.type;
    final filter = firstCondition.filter?.toString() ?? '';

    if (type == 'blank') return lt.isBlank;
    if (type == 'notBlank') return lt.isNotBlank;
    if (filter.isEmpty) return _operationDisplayName(lt, type);

    final opName = _operationDisplayName(lt, type);
    final summary = '$opName "$filter"';

    if (model.isCombined) {
      final op = model.operator == OsJoinOperator.and
          ? lt.andCondition
          : lt.orCondition;
      return '$summary $op ...';
    }

    return summary;
  }

  String _operationDisplayName(OsLocaleText lt, String type) {
    switch (type) {
      case 'contains':
        return lt.contains;
      case 'notContains':
        return lt.notContains;
      case 'equals':
        return lt.equals;
      case 'notEqual':
        return lt.notEqual;
      case 'startsWith':
        return lt.startsWith;
      case 'endsWith':
        return lt.endsWith;
      case 'greaterThan':
        return '>';
      case 'greaterThanOrEqual':
        return '>=';
      case 'lessThan':
        return '<';
      case 'lessThanOrEqual':
        return '<=';
      case 'inRange':
        return lt.inRange;
      default:
        return type;
    }
  }
}

/// Small icon button for the toolbar.
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
