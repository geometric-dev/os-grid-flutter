/// A tabbed column menu popup with General, Filter, and Columns tabs.
///
/// This is the AG Grid "legacy enterprise menu" equivalent — a richer
/// interface than the simple flat column menu, providing tabbed access
/// to column operations, inline filtering, and column visibility.
library;

import 'package:flutter/material.dart';

import '../columns/os_column_def.dart';
import '../columns/os_column_group.dart';
import '../columns/os_column_pin.dart';
import '../filtering/filter_evaluator.dart';
import '../filtering/filter_model.dart';
import '../filtering/os_date_filter.dart';
import '../filtering/os_filter.dart';
import '../locale/os_locale_text.dart';
import '../rendering/special_columns.dart';
import '../sorting/sort_direction.dart';
import '../theming/grid_popup_surface.dart';
import '../theming/os_grid_theme.dart';
import '../theming/resolved_grid_theme.dart';
import 'column_menu_popup.dart';
import 'os_column_menu_def.dart';

/// Callback for when a filter is applied from the Filter tab.
typedef TabbedMenuFilterCallback =
    void Function(String colId, OsColumnFilterModel? model);

/// Callback for when column visibility changes from the Columns tab.
typedef TabbedMenuColumnVisibilityCallback =
    void Function(String colId, bool visible);

/// Localised display label for a filter operation type.
///
/// Mirrors the English defaults of the filter evaluator's display-name
/// helper (including the date-specific Before/After variants) while routing
/// through [OsLocaleText] so hosts can translate them.
String tabbedMenuOperationLabel(
  OsLocaleText lt,
  String type, {
  OsFilter? filter,
}) {
  final isDate = filter is OsDateFilter;
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
      return isDate ? lt.after : lt.greaterThan;
    case 'greaterThanOrEqual':
      return isDate ? lt.afterOrOn : lt.greaterThanOrEqual;
    case 'lessThan':
      return isDate ? lt.before : lt.lessThan;
    case 'lessThanOrEqual':
      return isDate ? lt.beforeOrOn : lt.lessThanOrEqual;
    case 'inRange':
      return lt.inRange;
    case 'blank':
      return lt.blank;
    case 'notBlank':
      return lt.notBlank;
    default:
      return type;
  }
}

/// A tabbed column menu popup displayed when the user taps the ⋮ icon
/// in a column header (when [OsColumnMenuDef] is configured).
///
/// Provides up to three tabs:
/// - **General** — sort, pin, autosize, reset column operations
/// - **Filter** — inline column filter (same UI as the standalone filter popup)
/// - **Columns** — column visibility checkboxes (same as the Columns Tool Panel)
///
/// The visible menu renders into the nearest [Overlay] via an
/// [OverlayPortal]; styling resolves from [theme], labels from [localeText].
class TabbedColumnMenu extends StatefulWidget {
  const TabbedColumnMenu({
    super.key,
    required this.columnIndex,
    required this.colDef,
    required this.anchorRect,
    required this.gridSize,
    required this.menuDef,
    required this.tabs,
    required this.onAction,
    required this.onDismiss,
    this.theme,
    this.localeText,
    this.currentColumnSortDirection,
    // Filter tab props
    this.filter,
    this.colId,
    this.currentFilterModel,
    this.onFilterApply,
    // Columns tab props
    this.allColumns,
    this.columnDefs,
    this.hiddenColumnIds,
    this.onColumnVisibilityChanged,
  });

  /// The column index this menu is for.
  final int columnIndex;

  /// The column definition this menu is for.
  final OsColumnDef colDef;

  /// The rect of the menu icon (in grid-local coordinates) to anchor below.
  final Rect anchorRect;

  /// The total size of the grid widget (for positioning constraints).
  final Size gridSize;

  /// The column menu configuration.
  final OsColumnMenuDef menuDef;

  /// The effective tabs to display.
  final List<OsColumnMenuTab> tabs;

  /// Called when a General tab action is selected.
  final ValueChanged<ColumnMenuEvent> onAction;

  /// Called when the menu should be dismissed.
  final VoidCallback onDismiss;

  /// Theme for styling the popup.
  final OsGridTheme? theme;

  /// Localised labels (defaults to English).
  final OsLocaleText? localeText;

  /// The sort direction of this column (null means not sorted).
  final OsSortDirection? currentColumnSortDirection;

  // --- Filter tab ---

  /// The filter configuration for this column (null if no filter).
  final OsFilter? filter;

  /// The column ID (for filter model keying).
  final String? colId;

  /// The current filter model for this column.
  final OsColumnFilterModel? currentFilterModel;

  /// Called when the filter is changed from the Filter tab.
  final TabbedMenuFilterCallback? onFilterApply;

  // --- Columns tab ---

  /// All flat columns in the grid.
  final List<OsColumnDef>? allColumns;

  /// Original column definitions including groups.
  final List<OsColumnDefBase>? columnDefs;

  /// Currently hidden column IDs.
  final Set<String>? hiddenColumnIds;

  /// Called when a column's visibility is toggled from the Columns tab.
  final TabbedMenuColumnVisibilityCallback? onColumnVisibilityChanged;

  @override
  State<TabbedColumnMenu> createState() => _TabbedColumnMenuState();
}

class _TabbedColumnMenuState extends State<TabbedColumnMenu> {
  static const _popupWidth = 280.0;
  static const _popupHeight = 360.0;

  late OsColumnMenuTab _activeTab;

  @override
  void initState() {
    super.initState();
    _activeTab = widget.tabs.first;
  }

  @override
  Widget build(BuildContext context) {
    final resolved = ResolvedGridTheme.from(widget.theme);
    final lt = widget.localeText ?? OsLocaleText.defaultLocale;

    return GridPopupSurface.belowAnchor(
      anchorRect: widget.anchorRect,
      gridSize: widget.gridSize,
      popupWidth: _popupWidth,
      estimatedHeight: _popupHeight,
      onBarrierTap: widget.onDismiss,
      blurSigma: widget.theme?.popupBlurSigma ?? 0,
      contentBuilder: (context) => Material(
        elevation: resolved.popupElevation,
        borderRadius: BorderRadius.circular(resolved.panelRadius),
        color: resolved.background,
        child: Container(
          width: _popupWidth,
          height: _popupHeight,
          decoration: BoxDecoration(
            border: Border.all(color: resolved.border),
            borderRadius: BorderRadius.circular(resolved.panelRadius),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(resolved.panelRadius),
            child: Column(
              children: [
                // Tab bar
                _buildTabBar(lt, resolved),
                // Tab content
                Expanded(child: _buildTabContent(lt, resolved)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar(OsLocaleText lt, ResolvedGridTheme resolved) {
    return Container(
      decoration: BoxDecoration(
        color: resolved.chrome,
        border: Border(bottom: BorderSide(color: resolved.border)),
      ),
      child: Row(
        children: widget.tabs.map((tab) {
          final isActive = tab == _activeTab;
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _activeTab = tab),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isActive ? resolved.accent : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _tabIcon(tab),
                      size: 14,
                      color: isActive
                          ? resolved.accent
                          : resolved.mutedForeground,
                    ),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        _tabLabel(tab, lt),
                        style: resolved.text(
                          11,
                          fontWeight: isActive
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: isActive
                              ? resolved.accent
                              : resolved.foreground.withValues(alpha: 0.7),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTabContent(OsLocaleText lt, ResolvedGridTheme resolved) {
    switch (_activeTab) {
      case OsColumnMenuTab.general:
        return _GeneralTab(
          columnIndex: widget.columnIndex,
          colDef: widget.colDef,
          currentColumnSortDirection: widget.currentColumnSortDirection,
          resolved: resolved,
          localeText: lt,
          onAction: widget.onAction,
        );
      case OsColumnMenuTab.filter:
        return _FilterTab(
          colId: widget.colId ?? widget.colDef.effectiveColId,
          headerName: widget.colDef.effectiveHeaderName,
          filter: widget.filter!,
          currentModel: widget.currentFilterModel,
          resolved: resolved,
          localeText: lt,
          onApply: widget.onFilterApply,
        );
      case OsColumnMenuTab.columns:
        return _ColumnsTab(
          columns: widget.allColumns ?? [],
          columnDefs: widget.columnDefs ?? [],
          hiddenColumnIds: widget.hiddenColumnIds ?? const {},
          resolved: resolved,
          localeText: lt,
          suppressFilter: widget.menuDef.suppressColumnSearch,
          suppressSelectAll: widget.menuDef.suppressColumnSelectAll,
          suppressExpandAll: widget.menuDef.suppressColumnExpandAll,
          contractGroups: widget.menuDef.contractColumnSelection,
          onColumnVisibilityChanged: widget.onColumnVisibilityChanged,
        );
    }
  }

  IconData _tabIcon(OsColumnMenuTab tab) {
    switch (tab) {
      case OsColumnMenuTab.general:
        return Icons.menu;
      case OsColumnMenuTab.filter:
        return Icons.filter_list;
      case OsColumnMenuTab.columns:
        return Icons.view_column;
    }
  }

  String _tabLabel(OsColumnMenuTab tab, OsLocaleText lt) {
    switch (tab) {
      case OsColumnMenuTab.general:
        return lt.general;
      case OsColumnMenuTab.filter:
        return lt.filter;
      case OsColumnMenuTab.columns:
        return lt.columns;
    }
  }
}

// ---------------------------------------------------------------------------
// General Tab — sort, pin, autosize, reset actions
// ---------------------------------------------------------------------------

class _GeneralTab extends StatelessWidget {
  const _GeneralTab({
    required this.columnIndex,
    required this.colDef,
    required this.onAction,
    required this.resolved,
    required this.localeText,
    this.currentColumnSortDirection,
  });

  final int columnIndex;
  final OsColumnDef colDef;
  final OsSortDirection? currentColumnSortDirection;
  final ResolvedGridTheme resolved;
  final OsLocaleText localeText;
  final ValueChanged<ColumnMenuEvent> onAction;

  @override
  Widget build(BuildContext context) {
    final items = _buildMenuItems();

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 4),
      children: items.map((item) {
        if (item.isSeparator) {
          return Divider(height: 1, thickness: 1, color: resolved.border);
        }
        if (item.subItems != null) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _GeneralSubMenuHeader(
                label: item.label,
                icon: item.icon,
                resolved: resolved,
              ),
              ...item.subItems!.map(
                (sub) => _GeneralMenuItem(
                  label: sub.label,
                  icon: sub.icon,
                  checked: sub.checked,
                  indent: true,
                  resolved: resolved,
                  onTap: sub.action != null
                      ? () => _fireAction(sub.action!)
                      : null,
                ),
              ),
            ],
          );
        }
        return _GeneralMenuItem(
          label: item.label,
          icon: item.icon,
          resolved: resolved,
          onTap: item.action != null ? () => _fireAction(item.action!) : null,
        );
      }).toList(),
    );
  }

  void _fireAction(ColumnMenuAction action) {
    onAction(
      ColumnMenuEvent(action: action, columnIndex: columnIndex, colDef: colDef),
    );
  }

  List<_GeneralItem> _buildMenuItems() {
    final lt = localeText;
    final items = <_GeneralItem>[];

    final isSorted = currentColumnSortDirection != null;
    final isSortedAsc = currentColumnSortDirection == OsSortDirection.ascending;
    final isSortedDesc =
        currentColumnSortDirection == OsSortDirection.descending;

    // Sort items (only if column is sortable)
    if (colDef.sortable) {
      if (!isSortedAsc) {
        items.add(
          _GeneralItem(
            label: lt.sortAscending,
            icon: Icons.arrow_upward,
            action: ColumnMenuAction.sortAscending,
          ),
        );
      }
      if (!isSortedDesc) {
        items.add(
          _GeneralItem(
            label: lt.sortDescending,
            icon: Icons.arrow_downward,
            action: ColumnMenuAction.sortDescending,
          ),
        );
      }
      if (isSorted) {
        items.add(
          _GeneralItem(
            label: lt.clearSort,
            icon: Icons.clear,
            action: ColumnMenuAction.sortClear,
          ),
        );
      }
      items.add(const _GeneralItem.separator());
    }

    // Pin items
    if (colDef.lockPinned != true) {
      final currentPin = colDef.pinned;
      items.add(
        _GeneralItem(
          label: lt.pinColumn,
          icon: Icons.push_pin_outlined,
          subItems: [
            _GeneralItem(
              label: lt.pinLeft,
              action: ColumnMenuAction.pinLeft,
              checked: currentPin == OsColumnPin.left,
            ),
            _GeneralItem(
              label: lt.pinRight,
              action: ColumnMenuAction.pinRight,
              checked: currentPin == OsColumnPin.right,
            ),
            _GeneralItem(
              label: lt.noPin,
              action: ColumnMenuAction.pinNone,
              checked: currentPin == null,
            ),
          ],
        ),
      );
      items.add(const _GeneralItem.separator());
    }

    // Autosize items
    items.add(
      _GeneralItem(
        label: lt.autosizeThisColumn,
        icon: Icons.width_normal,
        action: ColumnMenuAction.autosizeThis,
      ),
    );
    items.add(
      _GeneralItem(
        label: lt.autosizeAllColumns,
        icon: Icons.width_full,
        action: ColumnMenuAction.autosizeAll,
      ),
    );
    items.add(const _GeneralItem.separator());

    // Reset columns
    items.add(
      _GeneralItem(
        label: lt.resetColumns,
        icon: Icons.restart_alt,
        action: ColumnMenuAction.resetColumns,
      ),
    );

    return items;
  }
}

class _GeneralItem {
  const _GeneralItem({
    this.label = '',
    this.icon,
    this.action,
    this.checked,
    this.subItems,
  }) : isSeparator = false;

  const _GeneralItem.separator()
    : label = '',
      icon = null,
      action = null,
      checked = null,
      subItems = null,
      isSeparator = true;

  final String label;
  final IconData? icon;
  final ColumnMenuAction? action;
  final bool? checked;
  final List<_GeneralItem>? subItems;
  final bool isSeparator;
}

class _GeneralSubMenuHeader extends StatelessWidget {
  const _GeneralSubMenuHeader({
    required this.label,
    this.icon,
    required this.resolved,
  });

  final String label;
  final IconData? icon;
  final ResolvedGridTheme resolved;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: resolved.mutedForeground),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              label,
              style: resolved.text(12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _GeneralMenuItem extends StatefulWidget {
  const _GeneralMenuItem({
    required this.label,
    this.icon,
    this.checked,
    this.indent = false,
    required this.resolved,
    this.onTap,
  });

  final String label;
  final IconData? icon;
  final bool? checked;
  final bool indent;
  final ResolvedGridTheme resolved;
  final VoidCallback? onTap;

  @override
  State<_GeneralMenuItem> createState() => _GeneralMenuItemState();
}

class _GeneralMenuItemState extends State<_GeneralMenuItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final resolved = widget.resolved;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          color: _hovered ? resolved.hover : null,
          padding: EdgeInsets.only(
            left: widget.indent ? 28 : 12,
            right: 12,
            top: 7,
            bottom: 7,
          ),
          child: Row(
            children: [
              if (widget.icon != null && !widget.indent) ...[
                Icon(widget.icon, size: 15, color: resolved.mutedForeground),
                const SizedBox(width: 8),
              ],
              if (widget.checked != null && widget.indent) ...[
                SizedBox(
                  width: 16,
                  child: widget.checked!
                      ? Icon(Icons.check, size: 14, color: resolved.accent)
                      : null,
                ),
                const SizedBox(width: 8),
              ],
              Expanded(child: Text(widget.label, style: resolved.text(12))),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Filter Tab — inline column filter
// ---------------------------------------------------------------------------

class _FilterTab extends StatefulWidget {
  const _FilterTab({
    required this.colId,
    required this.headerName,
    required this.filter,
    required this.resolved,
    required this.localeText,
    this.currentModel,
    this.onApply,
  });

  final String colId;
  final String headerName;
  final OsFilter filter;
  final ResolvedGridTheme resolved;
  final OsLocaleText localeText;
  final OsColumnFilterModel? currentModel;
  final TabbedMenuFilterCallback? onApply;

  @override
  State<_FilterTab> createState() => _FilterTabState();
}

class _FilterTabState extends State<_FilterTab> {
  late String _operationType;
  late TextEditingController _valueController;
  late TextEditingController _valueToController;
  late OsJoinOperator _joinOperator;
  late String _operationType2;
  late TextEditingController _valueController2;
  bool _showSecondCondition = false;

  @override
  void initState() {
    super.initState();

    final defaultOp = getDefaultFilterType(widget.filter);
    final maxConditions = _getMaxConditions();

    if (widget.currentModel != null && widget.currentModel!.isActive) {
      final model = widget.currentModel!;
      final firstCondition = model.conditions.isNotEmpty
          ? model.conditions.first
          : null;

      _operationType = firstCondition?.type ?? defaultOp;
      _valueController = TextEditingController(
        text: firstCondition?.filter?.toString() ?? '',
      );
      _valueToController = TextEditingController(
        text: firstCondition?.filterTo?.toString() ?? '',
      );

      if (model.conditions.length > 1 && maxConditions > 1) {
        _showSecondCondition = true;
        final secondCondition = model.conditions[1];
        _operationType2 = secondCondition.type;
        _valueController2 = TextEditingController(
          text: secondCondition.filter?.toString() ?? '',
        );
        _joinOperator = model.operator ?? OsJoinOperator.and;
      } else {
        _operationType2 = defaultOp;
        _valueController2 = TextEditingController();
        _joinOperator = _getDefaultJoinOperator();
      }
    } else {
      _operationType = defaultOp;
      _valueController = TextEditingController();
      _valueToController = TextEditingController();
      _operationType2 = defaultOp;
      _valueController2 = TextEditingController();
      _joinOperator = _getDefaultJoinOperator();
    }
  }

  @override
  void dispose() {
    _valueController.dispose();
    _valueToController.dispose();
    _valueController2.dispose();
    super.dispose();
  }

  int _getMaxConditions() {
    return getMaxConditionsForFilter(widget.filter);
  }

  OsJoinOperator _getDefaultJoinOperator() {
    return getDefaultJoinOperatorForFilter(widget.filter);
  }

  List<String> _getAvailableOptions() {
    return getAvailableFilterOptions(widget.filter);
  }

  void _applyFilter() {
    final conditions = <OsFilterCondition>[];

    // First condition
    final numInputs1 = getNumberOfInputs(_operationType);
    if (numInputs1 == 0) {
      conditions.add(OsFilterCondition(type: _operationType));
    } else {
      final value1 = _valueController.text.trim();
      if (value1.isNotEmpty) {
        if (numInputs1 == 2) {
          final valueTo = _valueToController.text.trim();
          conditions.add(
            OsFilterCondition(
              type: _operationType,
              filter: value1,
              filterTo: valueTo.isNotEmpty ? valueTo : null,
            ),
          );
        } else {
          conditions.add(
            OsFilterCondition(type: _operationType, filter: value1),
          );
        }
      }
    }

    // Second condition
    if (_showSecondCondition) {
      final numInputs2 = getNumberOfInputs(_operationType2);
      if (numInputs2 == 0) {
        conditions.add(OsFilterCondition(type: _operationType2));
      } else {
        final value2 = _valueController2.text.trim();
        if (value2.isNotEmpty) {
          conditions.add(
            OsFilterCondition(type: _operationType2, filter: value2),
          );
        }
      }
    }

    if (conditions.isEmpty) {
      widget.onApply?.call(widget.colId, null);
    } else {
      final filterType = getFilterTypeName(widget.filter);
      widget.onApply?.call(
        widget.colId,
        OsColumnFilterModel(
          filterType: filterType,
          conditions: conditions,
          operator: conditions.length > 1 ? _joinOperator : null,
        ),
      );
    }
  }

  void _clearFilter() {
    setState(() {
      _operationType = getDefaultFilterType(widget.filter);
      _valueController.clear();
      _valueToController.clear();
      _showSecondCondition = false;
      _operationType2 = getDefaultFilterType(widget.filter);
      _valueController2.clear();
      _joinOperator = _getDefaultJoinOperator();
    });
    widget.onApply?.call(widget.colId, null);
  }

  @override
  Widget build(BuildContext context) {
    final lt = widget.localeText;
    final resolved = widget.resolved;

    final textStyle = resolved.text(12);
    final availableOptions = _getAvailableOptions();
    final maxConditions = _getMaxConditions();
    final numInputs1 = getNumberOfInputs(_operationType);
    final isDate = widget.filter is OsDateFilter;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // Operation dropdown
        _buildDropdown(
          value: _operationType,
          options: availableOptions,
          textStyle: textStyle,
          resolved: resolved,
          onChanged: (value) {
            setState(() => _operationType = value);
            _applyFilter();
          },
        ),

        // Value input
        if (numInputs1 > 0) ...[
          const SizedBox(height: 8),
          _buildInput(
            controller: _valueController,
            placeholder: numInputs1 > 1
                ? (isDate ? lt.dateFormatOoo : lt.fromOoo)
                : (isDate ? lt.dateFormatOoo : lt.filterValueOoo),
            textStyle: textStyle,
            resolved: resolved,
            onChanged: (_) => _applyFilter(),
          ),
        ],

        // Range upper bound
        if (numInputs1 > 1) ...[
          const SizedBox(height: 8),
          _buildInput(
            controller: _valueToController,
            placeholder: isDate ? lt.dateFormatOoo : lt.toOoo,
            textStyle: textStyle,
            resolved: resolved,
            onChanged: (_) => _applyFilter(),
          ),
        ],

        // Join operator + second condition
        if (maxConditions > 1) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildJoinPill(
                label: lt.andCondition,
                isSelected: _joinOperator == OsJoinOperator.and,
                resolved: resolved,
                textStyle: textStyle,
                onTap: () {
                  setState(() => _joinOperator = OsJoinOperator.and);
                  if (_showSecondCondition) _applyFilter();
                },
              ),
              _buildJoinPill(
                label: lt.orCondition,
                isSelected: _joinOperator == OsJoinOperator.or,
                resolved: resolved,
                textStyle: textStyle,
                onTap: () {
                  setState(() => _joinOperator = OsJoinOperator.or);
                  if (_showSecondCondition) _applyFilter();
                },
              ),
              if (!_showSecondCondition)
                GestureDetector(
                  onTap: () => setState(() => _showSecondCondition = true),
                  child: Text(
                    lt.plusCondition,
                    style: textStyle.copyWith(
                      color: resolved.accent,
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ),
          if (_showSecondCondition) ...[
            const SizedBox(height: 8),
            _buildDropdown(
              value: _operationType2,
              options: availableOptions,
              textStyle: textStyle,
              resolved: resolved,
              onChanged: (value) {
                setState(() => _operationType2 = value);
                _applyFilter();
              },
            ),
            if (getNumberOfInputs(_operationType2) > 0) ...[
              const SizedBox(height: 8),
              _buildInput(
                controller: _valueController2,
                placeholder: lt.filterValueOoo,
                textStyle: textStyle,
                resolved: resolved,
                onChanged: (_) => _applyFilter(),
              ),
            ],
          ],
        ],

        // Action buttons
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                label: lt.clear,
                resolved: resolved,
                textStyle: textStyle,
                onTap: _clearFilter,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> options,
    required TextStyle textStyle,
    required ResolvedGridTheme resolved,
    required ValueChanged<String> onChanged,
  }) {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: resolved.chrome,
        border: Border.all(color: resolved.border),
        borderRadius: BorderRadius.circular(resolved.controlRadius),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: options.contains(value) ? value : options.first,
          isExpanded: true,
          isDense: true,
          icon: Icon(
            Icons.arrow_drop_down,
            size: 16,
            color: resolved.mutedForeground,
          ),
          dropdownColor: resolved.background,
          style: textStyle,
          items: options.map((option) {
            return DropdownMenuItem<String>(
              value: option,
              child: Text(
                tabbedMenuOperationLabel(
                  widget.localeText,
                  option,
                  filter: widget.filter,
                ),
                style: textStyle.copyWith(fontSize: 12),
              ),
            );
          }).toList(),
          onChanged: (newValue) {
            if (newValue != null) onChanged(newValue);
          },
        ),
      ),
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String placeholder,
    required TextStyle textStyle,
    required ResolvedGridTheme resolved,
    required ValueChanged<String> onChanged,
  }) {
    return SizedBox(
      height: 30,
      child: TextField(
        controller: controller,
        style: textStyle.copyWith(fontSize: 12),
        cursorColor: resolved.accent,
        decoration: InputDecoration(
          hintText: placeholder,
          hintStyle: textStyle.copyWith(
            color: resolved.hintForeground,
            fontSize: 12,
          ),
          filled: true,
          fillColor: resolved.background,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 6,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(resolved.controlRadius),
            borderSide: BorderSide(color: resolved.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(resolved.controlRadius),
            borderSide: BorderSide(color: resolved.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(resolved.controlRadius),
            borderSide: BorderSide(color: resolved.accent, width: 1.5),
          ),
          isDense: true,
        ),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildJoinPill({
    required String label,
    required bool isSelected,
    required ResolvedGridTheme resolved,
    required TextStyle textStyle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? resolved.accent.withValues(alpha: 0.2)
              : resolved.chrome,
          border: Border.all(
            color: isSelected ? resolved.accent : resolved.border,
          ),
          borderRadius: BorderRadius.circular(resolved.controlRadius),
        ),
        child: Text(
          label,
          style: textStyle.copyWith(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? resolved.accent : null,
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required ResolvedGridTheme resolved,
    required TextStyle textStyle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: resolved.chrome,
          border: Border.all(color: resolved.border),
          borderRadius: BorderRadius.circular(resolved.controlRadius),
        ),
        child: Text(
          label,
          style: textStyle.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: resolved.foreground,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Columns Tab — column visibility checkboxes
// ---------------------------------------------------------------------------

class _ColumnsTab extends StatefulWidget {
  const _ColumnsTab({
    required this.columns,
    required this.columnDefs,
    required this.hiddenColumnIds,
    required this.resolved,
    required this.localeText,
    this.suppressFilter = false,
    this.suppressSelectAll = false,
    this.suppressExpandAll = false,
    this.contractGroups = false,
    this.onColumnVisibilityChanged,
  });

  final List<OsColumnDef> columns;
  final List<OsColumnDefBase> columnDefs;
  final Set<String> hiddenColumnIds;
  final ResolvedGridTheme resolved;
  final OsLocaleText localeText;
  final bool suppressFilter;
  final bool suppressSelectAll;
  final bool suppressExpandAll;
  final bool contractGroups;
  final TabbedMenuColumnVisibilityCallback? onColumnVisibilityChanged;

  @override
  State<_ColumnsTab> createState() => _ColumnsTabState();
}

class _ColumnsTabState extends State<_ColumnsTab> {
  String _filterText = '';
  final Set<String> _expandedGroups = {};
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (!widget.contractGroups) {
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
    for (final col in widget.columns) {
      final colId = col.effectiveColId;
      if (_isSpecialColumn(colId)) continue;
      if (widget.hiddenColumnIds.contains(colId)) {
        widget.onColumnVisibilityChanged?.call(colId, true);
      }
    }
  }

  void _handleDeselectAll() {
    for (final col in widget.columns) {
      final colId = col.effectiveColId;
      if (_isSpecialColumn(colId)) continue;
      if (!widget.hiddenColumnIds.contains(colId)) {
        widget.onColumnVisibilityChanged?.call(colId, false);
      }
    }
  }

  bool _isSpecialColumn(String colId) => SpecialColumns.isSpecial(colId);

  @override
  Widget build(BuildContext context) {
    final lt = widget.localeText;
    final resolved = widget.resolved;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header controls
        if (!widget.suppressFilter ||
            !widget.suppressSelectAll ||
            !widget.suppressExpandAll)
          _buildControls(lt, resolved),
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

  Widget _buildControls(OsLocaleText lt, ResolvedGridTheme resolved) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: resolved.border, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!widget.suppressFilter)
            SizedBox(
              height: 26,
              child: TextField(
                controller: _searchController,
                style: resolved.text(11),
                decoration: InputDecoration(
                  hintText: lt.searchOoo,
                  hintStyle: resolved.text(11, color: resolved.hintForeground),
                  prefixIcon: Icon(
                    Icons.search,
                    size: 14,
                    color: resolved.hintForeground,
                  ),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 24,
                    maxHeight: 24,
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
                    _SmallIconBtn(
                      icon: Icons.unfold_more,
                      tooltip: lt.expandAll,
                      onTap: () =>
                          setState(() => _expandAllGroups(widget.columnDefs)),
                      color: resolved.foreground,
                    ),
                    _SmallIconBtn(
                      icon: Icons.unfold_less,
                      tooltip: lt.collapseAll,
                      onTap: () => setState(() => _expandedGroups.clear()),
                      color: resolved.foreground,
                    ),
                  ],
                  const Spacer(),
                  if (!widget.suppressSelectAll) ...[
                    _SmallIconBtn(
                      icon: Icons.check_box_outlined,
                      tooltip: lt.selectAll,
                      onTap: _handleSelectAll,
                      color: resolved.foreground,
                    ),
                    _SmallIconBtn(
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

        if (_filterText.isNotEmpty && !_groupHasVisibleChildren(def)) continue;

        widgets.add(
          InkWell(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedGroups.remove(groupId);
                } else {
                  _expandedGroups.add(groupId);
                }
              });
            },
            child: Padding(
              padding: EdgeInsets.only(left: 6.0 + depth * 14.0, right: 6),
              child: SizedBox(
                height: 26,
                child: Row(
                  children: [
                    Icon(
                      isExpanded ? Icons.expand_more : Icons.chevron_right,
                      size: 14,
                      color: resolved.foreground,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        def.headerName,
                        style: resolved.text(11, fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
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

        if (_filterText.isNotEmpty) {
          final name = def.effectiveHeaderName.toLowerCase();
          if (!name.contains(_filterText.toLowerCase())) continue;
        }

        final isVisible = !widget.hiddenColumnIds.contains(colId);

        widgets.add(
          InkWell(
            onTap: () {
              widget.onColumnVisibilityChanged?.call(colId, !isVisible);
            },
            child: Padding(
              padding: EdgeInsets.only(left: 6.0 + depth * 14.0, right: 6),
              child: SizedBox(
                height: 26,
                child: Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: Checkbox(
                        value: isVisible,
                        onChanged: (_) {
                          widget.onColumnVisibilityChanged?.call(
                            colId,
                            !isVisible,
                          );
                        },
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        activeColor: resolved.accent,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        def.effectiveHeaderName,
                        style: resolved.text(11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
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

class _SmallIconBtn extends StatelessWidget {
  const _SmallIconBtn({
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
          padding: const EdgeInsets.all(2),
          child: Icon(icon, size: 14, color: color),
        ),
      ),
    );
  }
}
