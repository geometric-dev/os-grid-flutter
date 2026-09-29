import 'package:flutter/material.dart';

import '../columns/os_column_def.dart';
import '../columns/os_column_pin.dart';
import '../locale/os_locale_text.dart';
import '../sorting/sort_direction.dart';
import '../theming/grid_popup_surface.dart';
import '../theming/os_grid_theme.dart';
import '../theming/resolved_grid_theme.dart';

/// Actions that can be performed from the column menu.
enum ColumnMenuAction {
  /// Sort the column ascending.
  sortAscending,

  /// Sort the column descending.
  sortDescending,

  /// Clear any sort on this column.
  sortClear,

  /// Pin the column to the left.
  pinLeft,

  /// Pin the column to the right.
  pinRight,

  /// Remove pinning from the column.
  pinNone,

  /// Auto-size this column to fit its content.
  autosizeThis,

  /// Auto-size all columns to fit their content.
  autosizeAll,

  /// Reset all columns to their default state.
  resetColumns,
}

/// Event emitted when a column menu action is selected.
class ColumnMenuEvent {
  const ColumnMenuEvent({
    required this.action,
    required this.columnIndex,
    required this.colDef,
  });

  /// The action that was selected.
  final ColumnMenuAction action;

  /// The index of the column the menu was opened for.
  final int columnIndex;

  /// The column definition the menu was opened for.
  final OsColumnDef colDef;
}

/// A popup menu displayed when the user taps the ⋮ icon in a column header.
///
/// Shows community-level actions: sort, pin, autosize, and reset columns.
/// Mirrors OS Grid's column menu (new-style, non-legacy) with the default
/// menu items from `ColumnMenuFactory.getDefaultMenuOptions()`.
///
/// The visible menu is rendered into the nearest [Overlay] via an
/// [OverlayPortal], so it can escape narrow grid bounds. Styling resolves
/// from [theme] (with Material fallbacks) and labels from [localeText]
/// (English defaults).
class ColumnMenuPopup extends StatefulWidget {
  const ColumnMenuPopup({
    super.key,
    required this.columnIndex,
    required this.colDef,
    required this.anchorRect,
    required this.gridSize,
    required this.onAction,
    required this.onDismiss,
    this.theme,
    this.localeText,
    this.currentSortColumnIndex,
    this.currentSortAscending = true,
    this.currentColumnSortDirection,
  });

  /// The column index this menu is for.
  final int columnIndex;

  /// The column definition this menu is for.
  final OsColumnDef colDef;

  /// The rect of the menu icon (in grid-local coordinates) to anchor below.
  final Rect anchorRect;

  /// The total size of the grid widget (for positioning constraints).
  final Size gridSize;

  /// Called when a menu action is selected.
  final ValueChanged<ColumnMenuEvent> onAction;

  /// Called when the menu should be dismissed (tap outside, etc.).
  final VoidCallback onDismiss;

  /// Theme for styling the popup.
  final OsGridTheme? theme;

  /// Localised labels for menu items (defaults to English).
  final OsLocaleText? localeText;

  /// The currently sorted column index (to show check marks).
  final int? currentSortColumnIndex;

  /// Whether the current sort is ascending.
  final bool currentSortAscending;

  /// The sort direction of this specific column (for multi-sort support).
  ///
  /// When provided, takes precedence over [currentSortColumnIndex] for
  /// determining the menu state. `null` means this column is not sorted.
  final OsSortDirection? currentColumnSortDirection;

  @override
  State<ColumnMenuPopup> createState() => _ColumnMenuPopupState();
}

class _ColumnMenuPopupState extends State<ColumnMenuPopup> {
  static const _popupWidth = 220.0;

  @override
  Widget build(BuildContext context) {
    final resolved = ResolvedGridTheme.from(widget.theme);
    final items = _buildMenuItems(
      widget.localeText ?? OsLocaleText.defaultLocale,
    );

    return GridPopupSurface.belowAnchor(
      anchorRect: widget.anchorRect,
      gridSize: widget.gridSize,
      popupWidth: _popupWidth,
      estimatedHeight: _estimateHeight(items),
      onBarrierTap: widget.onDismiss,
      blurSigma: widget.theme?.popupBlurSigma ?? 0,
      contentBuilder: (context) => Material(
        elevation: resolved.popupElevation,
        borderRadius: BorderRadius.circular(resolved.panelRadius),
        color: resolved.background,
        child: Container(
          width: _popupWidth,
          decoration: BoxDecoration(
            border: Border.all(color: resolved.border),
            borderRadius: BorderRadius.circular(resolved.panelRadius),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(resolved.panelRadius),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _buildWidgetItems(context, items, resolved: resolved),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<_MenuItem> _buildMenuItems(OsLocaleText lt) {
    final items = <_MenuItem>[];

    // Determine sort state: prefer multi-sort direction, fall back to legacy
    final bool isSorted;
    final bool isSortedAsc;
    final bool isSortedDesc;
    if (widget.currentColumnSortDirection != null) {
      isSorted = true;
      isSortedAsc =
          widget.currentColumnSortDirection == OsSortDirection.ascending;
      isSortedDesc =
          widget.currentColumnSortDirection == OsSortDirection.descending;
    } else {
      isSorted = widget.currentSortColumnIndex == widget.columnIndex;
      isSortedAsc = isSorted && widget.currentSortAscending;
      isSortedDesc = isSorted && !widget.currentSortAscending;
    }

    // Sort items (only if column is sortable)
    if (widget.colDef.sortable) {
      if (!isSortedAsc) {
        items.add(
          _MenuItem(
            label: lt.sortAscending,
            icon: Icons.arrow_upward,
            action: ColumnMenuAction.sortAscending,
          ),
        );
      }
      if (!isSortedDesc) {
        items.add(
          _MenuItem(
            label: lt.sortDescending,
            icon: Icons.arrow_downward,
            action: ColumnMenuAction.sortDescending,
          ),
        );
      }
      if (isSorted) {
        items.add(
          _MenuItem(
            label: lt.clearSort,
            icon: Icons.clear,
            action: ColumnMenuAction.sortClear,
          ),
        );
      }
      items.add(const _MenuItem.separator());
    }

    // Pin items (only if column doesn't have lockPinned)
    if (widget.colDef.lockPinned != true) {
      final currentPin = widget.colDef.pinned;
      items.add(
        _MenuItem(
          label: lt.pinColumn,
          icon: Icons.push_pin_outlined,
          subItems: [
            _MenuItem(
              label: lt.pinLeft,
              action: ColumnMenuAction.pinLeft,
              checked: currentPin == OsColumnPin.left,
            ),
            _MenuItem(
              label: lt.pinRight,
              action: ColumnMenuAction.pinRight,
              checked: currentPin == OsColumnPin.right,
            ),
            _MenuItem(
              label: lt.noPin,
              action: ColumnMenuAction.pinNone,
              checked: currentPin == null,
            ),
          ],
        ),
      );
      items.add(const _MenuItem.separator());
    }

    // Autosize items
    items.add(
      _MenuItem(
        label: lt.autosizeThisColumn,
        icon: Icons.width_normal,
        action: ColumnMenuAction.autosizeThis,
      ),
    );
    items.add(
      _MenuItem(
        label: lt.autosizeAllColumns,
        icon: Icons.width_full,
        action: ColumnMenuAction.autosizeAll,
      ),
    );
    items.add(const _MenuItem.separator());

    // Reset columns
    items.add(
      _MenuItem(
        label: lt.resetColumns,
        icon: Icons.restart_alt,
        action: ColumnMenuAction.resetColumns,
      ),
    );

    return items;
  }

  double _estimateHeight(List<_MenuItem> items) {
    var height = 0.0;
    for (final item in items) {
      if (item.isSeparator) {
        height += 9;
      } else if (item.subItems != null) {
        height += 33 + item.subItems!.length * 35;
      } else {
        height += 35;
      }
    }
    return height;
  }

  List<Widget> _buildWidgetItems(
    BuildContext context,
    List<_MenuItem> items, {
    required ResolvedGridTheme resolved,
  }) {
    final widgets = <Widget>[];

    for (final item in items) {
      if (item.isSeparator) {
        widgets.add(Divider(height: 1, thickness: 1, color: resolved.border));
        continue;
      }

      if (item.subItems != null) {
        // Render as an expandable sub-menu section
        widgets.add(_buildSubMenuHeader(item, resolved: resolved));
        for (final subItem in item.subItems!) {
          widgets.add(
            _buildActionItem(subItem, resolved: resolved, indent: true),
          );
        }
        continue;
      }

      widgets.add(_buildActionItem(item, resolved: resolved));
    }

    return widgets;
  }

  Widget _buildSubMenuHeader(
    _MenuItem item, {
    required ResolvedGridTheme resolved,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          if (item.icon != null) ...[
            Icon(item.icon, size: 16, color: resolved.mutedForeground),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              item.label,
              style: resolved.text(13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionItem(
    _MenuItem item, {
    required ResolvedGridTheme resolved,
    bool indent = false,
  }) {
    return _MenuItemWidget(
      label: item.label,
      icon: item.icon,
      checked: item.checked,
      indent: indent,
      resolved: resolved,
      onTap: item.action != null
          ? () {
              widget.onAction(
                ColumnMenuEvent(
                  action: item.action!,
                  columnIndex: widget.columnIndex,
                  colDef: widget.colDef,
                ),
              );
            }
          : null,
    );
  }
}

/// A single interactive menu item row with hover state.
class _MenuItemWidget extends StatefulWidget {
  const _MenuItemWidget({
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
  State<_MenuItemWidget> createState() => _MenuItemWidgetState();
}

class _MenuItemWidgetState extends State<_MenuItemWidget> {
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
            top: 8,
            bottom: 8,
          ),
          child: Row(
            children: [
              if (widget.icon != null && !widget.indent) ...[
                Icon(widget.icon, size: 16, color: resolved.mutedForeground),
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
              Expanded(child: Text(widget.label, style: resolved.text(13))),
            ],
          ),
        ),
      ),
    );
  }
}

/// Internal model for a menu item.
class _MenuItem {
  const _MenuItem({
    this.label = '',
    this.icon,
    this.action,
    this.checked,
    this.subItems,
  }) : isSeparator = false;

  const _MenuItem.separator()
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
  final List<_MenuItem>? subItems;
  final bool isSeparator;
}
