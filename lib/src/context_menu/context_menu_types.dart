import 'package:flutter/material.dart';

/// Represents a single item in the context menu.
///
/// Items can be regular actions, separators, or contain sub-menus.
/// Use the named constructors for built-in items, or create custom
/// items directly.
///
/// ```dart
/// final items = [
///   OsContextMenuItem(name: 'Custom Action', action: () => doSomething()),
///   OsContextMenuItem.separator,
///   OsContextMenuItem.copy,
/// ];
/// ```
class OsContextMenuItem {
  /// Creates a context menu item.
  const OsContextMenuItem({
    required this.name,
    this.icon,
    this.action,
    this.disabled = false,
    this.isSeparator = false,
    this.subMenu,
    this.shortcut,
  });

  /// Creates a separator line between menu items.
  const OsContextMenuItem._separator()
    : name = '',
      icon = null,
      action = null,
      disabled = false,
      isSeparator = true,
      subMenu = null,
      shortcut = null;

  /// Display text for the menu item.
  final String name;

  /// Optional icon displayed to the left of the item text.
  final IconData? icon;

  /// Action to perform when the item is clicked.
  ///
  /// Null for separators or parent items with sub-menus only.
  final VoidCallback? action;

  /// Whether the item is greyed out but still visible.
  final bool disabled;

  /// Whether this item renders as a divider line instead of a clickable item.
  final bool isSeparator;

  /// Optional nested sub-menu items.
  ///
  /// When non-null, hovering/tapping this item shows a sub-menu to the right.
  final List<OsContextMenuItem>? subMenu;

  /// Optional keyboard shortcut hint text (display only, not functional).
  final String? shortcut;

  // --- Built-in item constants ---

  /// A separator divider line.
  static const separator = OsContextMenuItem._separator();

  /// Built-in "Copy" item — copies cell value or selected range.
  static const copy = OsContextMenuItem(
    name: 'Copy',
    icon: Icons.copy,
    shortcut: 'Ctrl+C',
  );

  /// Built-in "Copy with Headers" item — copies selection with column headers.
  static const copyWithHeaders = OsContextMenuItem(
    name: 'Copy with Headers',
    icon: Icons.table_chart_outlined,
    shortcut: 'Ctrl+Shift+C',
  );

  /// Built-in "Cut" item — cuts cell value (editable cells only).
  static const cut = OsContextMenuItem(
    name: 'Cut',
    icon: Icons.cut,
    shortcut: 'Ctrl+X',
  );

  /// Built-in "Paste" item — pastes clipboard content (editable cells only).
  static const paste = OsContextMenuItem(
    name: 'Paste',
    icon: Icons.paste,
    shortcut: 'Ctrl+V',
  );

  /// Built-in "Export" sub-menu with CSV export option.
  static const export = OsContextMenuItem(
    name: 'Export',
    icon: Icons.file_download_outlined,
    subMenu: [
      OsContextMenuItem(name: 'CSV Export', icon: Icons.description_outlined),
    ],
  );

  /// Creates a copy of this item with an action attached.
  ///
  /// Useful for attaching actions to built-in constant items.
  OsContextMenuItem withAction(VoidCallback action) {
    return OsContextMenuItem(
      name: name,
      icon: icon,
      action: action,
      disabled: disabled,
      isSeparator: isSeparator,
      subMenu: subMenu?.toList(),
      shortcut: shortcut,
    );
  }

  /// Creates a copy of this item with the disabled state changed.
  OsContextMenuItem withDisabled(bool disabled) {
    return OsContextMenuItem(
      name: name,
      icon: icon,
      action: action,
      disabled: disabled,
      isSeparator: isSeparator,
      subMenu: subMenu,
      shortcut: shortcut,
    );
  }
}

/// Parameters passed to the `getContextMenuItems` callback.
///
/// Contains information about the cell that was right-clicked,
/// allowing the callback to build a context-sensitive menu.
class GetContextMenuItemsParams<TData> {
  const GetContextMenuItemsParams({
    required this.rowIndex,
    required this.colId,
    required this.value,
    required this.data,
    this.column,
  });

  /// The row index of the right-clicked cell.
  final int rowIndex;

  /// The column ID of the right-clicked cell.
  final String colId;

  /// The value of the right-clicked cell.
  final dynamic value;

  /// The row data for the right-clicked cell.
  final TData data;

  /// The column definition of the right-clicked cell (if available).
  final dynamic column;
}
