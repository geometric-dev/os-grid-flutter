/// Navigation metadata for every showcase page, shared by the shell's
/// drawer, the Home hub and the prev/next arrows. [DemoPage.builder]
/// receives the theme preset — theme is selected on Home and flows down.
library;

import 'package:flutter/material.dart';

import '../theme_selector.dart';
import 'pages/advanced_rows_page.dart';
import 'pages/cell_editing_page.dart';
import 'pages/clipboard_context_menu_page.dart';
import 'pages/column_features_page.dart';
import 'pages/column_state_page.dart';
import 'pages/data_persistence_page.dart';
import 'pages/enterprise_features_page.dart';
import 'pages/grouping_page.dart';
import 'pages/infinite_row_model_page.dart';
import 'pages/overlays_page.dart';
import 'pages/pagination_data_page.dart';
import 'pages/row_drag_page.dart';
import 'pages/selection_range_page.dart';
import 'pages/side_bar_page.dart';
import 'pages/sorting_filtering_page.dart';
import 'pages/theming_page.dart';
import 'pages/tooltips_advanced_page.dart';
import 'pages/whats_new_page.dart';

/// One demo page in the showcase.
class DemoPage {
  const DemoPage({
    required this.title,
    required this.description,
    required this.icon,
    required this.category,
    required this.builder,
  });

  final String title;
  final String description;
  final IconData icon;
  final String category;
  final Widget Function(
    GridThemePreset themePreset,
    ValueChanged<GridThemePreset>? onThemeChanged,
  )
  builder;
}

/// All showcase pages in navigation order, grouped by [DemoPage.category].
const demoPages = <DemoPage>[
  DemoPage(
    title: "What's New",
    description: 'Recent additions across the grid',
    icon: Icons.new_releases,
    category: 'Start',
    builder: _whatsNew,
  ),
  DemoPage(
    title: 'Theming',
    description: 'Presets, dark mode, Material bridge',
    icon: Icons.palette,
    category: 'Start',
    builder: _theming,
  ),
  DemoPage(
    title: 'Enterprise Features',
    description: 'Tree data, sparklines, status bar, export',
    icon: Icons.business,
    category: 'Start',
    builder: _enterprise,
  ),
  DemoPage(
    title: 'Sorting & Filtering',
    description: 'Multi-sort, accent sort, column filters',
    icon: Icons.sort,
    category: 'Data',
    builder: _sortingFiltering,
  ),
  DemoPage(
    title: 'Pagination & Data',
    description: 'Pages, transactions, pinned rows',
    icon: Icons.table_rows,
    category: 'Data',
    builder: _paginationData,
  ),
  DemoPage(
    title: 'Infinite Row Model',
    description: 'Lazy block loading from a datasource',
    icon: Icons.all_inclusive,
    category: 'Data',
    builder: _infinite,
  ),
  DemoPage(
    title: 'Data & Persistence',
    description: 'Grid state save and restore',
    icon: Icons.save,
    category: 'Data',
    builder: _dataPersistence,
  ),
  DemoPage(
    title: 'Cell Editing',
    description: 'Editors, keyboard triggers, undo/redo',
    icon: Icons.edit,
    category: 'Interaction',
    builder: _cellEditing,
  ),
  DemoPage(
    title: 'Selection & Range',
    description: 'Row selection, cell ranges, fill handle',
    icon: Icons.select_all,
    category: 'Interaction',
    builder: _selectionRange,
  ),
  DemoPage(
    title: 'Row Drag',
    description: 'Drag-to-reorder with auto-scroll',
    icon: Icons.drag_indicator,
    category: 'Interaction',
    builder: _rowDrag,
  ),
  DemoPage(
    title: 'Clipboard & Context Menu',
    description: 'Copy/paste and right-click menus',
    icon: Icons.content_paste,
    category: 'Interaction',
    builder: _clipboard,
  ),
  DemoPage(
    title: 'Column Features',
    description: 'Groups, pinning, renderers, tooltips',
    icon: Icons.view_column,
    category: 'Structure',
    builder: _columnFeatures,
  ),
  DemoPage(
    title: 'Grouping & Aggregation',
    description: 'Row grouping with aggregate columns',
    icon: Icons.account_tree,
    category: 'Structure',
    builder: _grouping,
  ),
  DemoPage(
    title: 'Column State',
    description: 'Save, restore and reset column layout',
    icon: Icons.settings,
    category: 'Structure',
    builder: _columnState,
  ),
  DemoPage(
    title: 'Side Bar',
    description: 'Columns and filters tool panels',
    icon: Icons.view_sidebar,
    category: 'Structure',
    builder: _sideBar,
  ),
  DemoPage(
    title: 'Advanced Rows',
    description: 'Tree data and master/detail rows',
    icon: Icons.account_tree_outlined,
    category: 'Structure',
    builder: _advancedRows,
  ),
  DemoPage(
    title: 'Overlays',
    description: 'Loading and no-rows placeholders',
    icon: Icons.layers,
    category: 'Extended',
    builder: _overlays,
  ),
  DemoPage(
    title: 'Tooltips & Advanced',
    description: 'Tooltips, value getters, hover column',
    icon: Icons.info_outline,
    category: 'Extended',
    builder: _tooltipsAdvanced,
  ),
];

Widget _whatsNew(
  GridThemePreset t,
  ValueChanged<GridThemePreset>? onThemeChanged,
) => WhatsNewPage(themePreset: t);
Widget _theming(
  GridThemePreset t,
  ValueChanged<GridThemePreset>? onThemeChanged,
) => ThemingPage(themePreset: t, onThemeChanged: onThemeChanged);
Widget _enterprise(
  GridThemePreset t,
  ValueChanged<GridThemePreset>? onThemeChanged,
) => EnterpriseFeaturesPage(themePreset: t);
Widget _sortingFiltering(
  GridThemePreset t,
  ValueChanged<GridThemePreset>? onThemeChanged,
) => SortingFilteringPage(themePreset: t);
Widget _paginationData(
  GridThemePreset t,
  ValueChanged<GridThemePreset>? onThemeChanged,
) => PaginationDataPage(themePreset: t);
Widget _infinite(
  GridThemePreset t,
  ValueChanged<GridThemePreset>? onThemeChanged,
) => InfiniteRowModelPage(themePreset: t);
Widget _dataPersistence(
  GridThemePreset t,
  ValueChanged<GridThemePreset>? onThemeChanged,
) => DataPersistencePage(themePreset: t);
Widget _cellEditing(
  GridThemePreset t,
  ValueChanged<GridThemePreset>? onThemeChanged,
) => CellEditingPage(themePreset: t);
Widget _selectionRange(
  GridThemePreset t,
  ValueChanged<GridThemePreset>? onThemeChanged,
) => SelectionRangePage(themePreset: t);
Widget _rowDrag(
  GridThemePreset t,
  ValueChanged<GridThemePreset>? onThemeChanged,
) => RowDragPage(themePreset: t);
Widget _clipboard(
  GridThemePreset t,
  ValueChanged<GridThemePreset>? onThemeChanged,
) => ClipboardContextMenuPage(themePreset: t);
Widget _columnFeatures(
  GridThemePreset t,
  ValueChanged<GridThemePreset>? onThemeChanged,
) => ColumnFeaturesPage(themePreset: t);
Widget _grouping(
  GridThemePreset t,
  ValueChanged<GridThemePreset>? onThemeChanged,
) => GroupingPage(themePreset: t);
Widget _columnState(
  GridThemePreset t,
  ValueChanged<GridThemePreset>? onThemeChanged,
) => ColumnStatePage(themePreset: t);
Widget _sideBar(
  GridThemePreset t,
  ValueChanged<GridThemePreset>? onThemeChanged,
) => SideBarPage(themePreset: t);
Widget _advancedRows(
  GridThemePreset t,
  ValueChanged<GridThemePreset>? onThemeChanged,
) => AdvancedRowsPage(themePreset: t);
Widget _overlays(
  GridThemePreset t,
  ValueChanged<GridThemePreset>? onThemeChanged,
) => OverlaysPage(themePreset: t);
Widget _tooltipsAdvanced(
  GridThemePreset t,
  ValueChanged<GridThemePreset>? onThemeChanged,
) => TooltipsAdvancedPage(themePreset: t);
