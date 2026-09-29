/// Configuration for the tabbed column menu.
///
/// The tabbed column menu provides a richer interface than the default
/// simple popup, with up to three tabs: General, Filter, and Columns.
///
/// Mirrors AG Grid's legacy enterprise menu (`menuTabs` property on
/// `ColDef`) adapted for Flutter.
library;

/// Identifies which tabs are available in the tabbed column menu.
enum OsColumnMenuTab {
  /// The General tab — column operations (sort, pin, autosize, reset).
  general,

  /// The Filter tab — inline column filter (same UI as the filter popup).
  filter,

  /// The Columns tab — column visibility checkboxes (same as the
  /// Columns Tool Panel in the side bar).
  columns,
}

/// Configuration for the tabbed column menu feature.
///
/// When provided to `OsGrid.columnMenu`, the column header ⋮ icon
/// opens a tabbed popup instead of the simple flat menu.
///
/// ```dart
/// OsGrid(
///   columnMenu: const OsColumnMenuDef(),
///   // ...
/// )
/// ```
///
/// To restrict which tabs are shown:
/// ```dart
/// OsGrid(
///   columnMenu: const OsColumnMenuDef(
///     menuTabs: [OsColumnMenuTab.general, OsColumnMenuTab.filter],
///   ),
///   // ...
/// )
/// ```
class OsColumnMenuDef {
  /// Creates a column menu configuration.
  ///
  /// When [menuTabs] is null, all three tabs are shown (General, Filter,
  /// Columns). The Filter tab is automatically hidden for columns that
  /// do not have a filter configured.
  const OsColumnMenuDef({
    this.menuTabs,
    this.suppressColumnFilter = false,
    this.suppressColumnSelectAll = false,
    this.suppressColumnExpandAll = false,
    this.suppressColumnSearch = false,
    this.contractColumnSelection = false,
  });

  /// Which tabs to show in the menu. Defaults to all three.
  ///
  /// The order in this list determines the display order of the tabs.
  /// Tabs can be omitted to restrict the menu to fewer panels.
  final List<OsColumnMenuTab>? menuTabs;

  /// Whether to suppress the filter tab even when the column has a filter.
  ///
  /// When `true`, the filter tab is never shown regardless of column
  /// configuration. Defaults to `false`.
  final bool suppressColumnFilter;

  /// Whether to suppress the "Select All / Deselect All" buttons in the
  /// Columns tab. Defaults to `false`.
  final bool suppressColumnSelectAll;

  /// Whether to suppress the "Expand All / Collapse All" buttons in the
  /// Columns tab. Defaults to `false`.
  final bool suppressColumnExpandAll;

  /// Whether to suppress the search input in the Columns tab.
  /// Defaults to `false`.
  final bool suppressColumnSearch;

  /// Whether column groups start collapsed in the Columns tab.
  /// Defaults to `false`.
  final bool contractColumnSelection;

  /// Returns the effective tabs for a given column, considering whether
  /// the column has a filter configured.
  List<OsColumnMenuTab> effectiveTabs({required bool hasFilter}) {
    final tabs = menuTabs ?? OsColumnMenuTab.values;
    return tabs.where((tab) {
      if (tab == OsColumnMenuTab.filter) {
        if (suppressColumnFilter) return false;
        if (!hasFilter) return false;
      }
      return true;
    }).toList();
  }
}
