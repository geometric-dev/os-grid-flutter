import 'package:flutter/material.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

import '../../theme_selector.dart';
import '../widgets/feature_panel.dart';
import '../widgets/demo_ui.dart';

/// What's New in 2.0 — showcases the headline features added in the 2.0
/// release: `defaultColDef`/`columnTypes`, Tree Data mode, the built-in
/// sparkline renderer, status bar aggregation panels, and the loading
/// overlay.
class WhatsNewPage extends StatefulWidget {
  const WhatsNewPage({
    super.key,
    required this.themePreset,
    this.onThemeChanged,
  });

  final GridThemePreset themePreset;
  final ValueChanged<GridThemePreset>? onThemeChanged;

  @override
  State<WhatsNewPage> createState() => _WhatsNewPageState();
}

class _WhatsNewPageState extends State<WhatsNewPage> {
  final _controller = OsGridController<Map<String, dynamic>>();

  bool _loading = false;

  /// Column types shared by the metric columns — resolved through
  /// `columnTypes` + per-column `type` (AG Grid DX parity).
  static const _columnTypes = <String, OsColumnDef<dynamic>>{
    'metric': OsColumnDef<dynamic>(width: 130, minWidth: 100),
  };

  /// Applied to every column that does not override it.
  static const _defaultColDef = OsColumnDef<dynamic>(sortable: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FeaturePanel(
          title: "What's New in 2.0 Controls",
          children: [
            DemoToggle(
              label: 'Loading overlay',
              value: _loading,
              onChanged: (v) => setState(() => _loading = v),
            ),
            FilledButton.tonalIcon(
              onPressed: _controller.expandAll,
              icon: const Icon(Icons.unfold_more),
              label: const Text('Expand all'),
            ),
            FilledButton.tonalIcon(
              onPressed: _controller.collapseAll,
              icon: const Icon(Icons.unfold_less),
              label: const Text('Collapse all'),
            ),
          ],
        ),
        Expanded(
          child: OsGrid<Map<String, dynamic>>(
            controller: _controller,
            theme: getThemeForPreset(widget.themePreset, context),
            defaultColDef: _defaultColDef,
            columnTypes: _columnTypes,
            treeData: true,
            getDataPath: (row) => row['path'] as List<Object>?,
            groupDefaultExpanded: 1,
            statusBarConfig: const OsStatusBarConfig(
              statusPanels: [
                OsStatusPanelDef(
                  aggregationFunc: 'sum',
                  valueColId: 'headcount',
                ),
                OsStatusPanelDef(aggregationFunc: 'avg', valueColId: 'revenue'),
                OsStatusPanelDef(
                  aggregationFunc: 'count',
                  valueColId: 'name',
                  align: OsStatusPanelAlign.right,
                ),
              ],
            ),
            loading: _loading,
            loadingOverlay: const Center(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 12),
                      Text('Fetching rows...'),
                    ],
                  ),
                ),
              ),
            ),
            columnDefs: [
              const OsColumnDef<Map<String, dynamic>>(
                field: 'name',
                headerName: 'Employee',
                flex: 2,
              ),
              const OsColumnDef<Map<String, dynamic>>(
                field: 'role',
                headerName: 'Role',
                flex: 1,
              ),
              const OsColumnDef<Map<String, dynamic>>(
                field: 'headcount',
                headerName: 'Reports',
                type: 'metric',
              ),
              OsColumnDef<Map<String, dynamic>>(
                field: 'revenue',
                headerName: 'Revenue',
                type: 'metric',
                valueFormatter: (params) =>
                    '\$${(params.value as num? ?? 0).toStringAsFixed(0)}k',
              ),
              const OsColumnDef<Map<String, dynamic>>(
                field: 'trend',
                headerName: 'Trend',
                width: 140,
                builtInCellRenderer: OsBuiltInCellRenderer.sparkline,
                sparklineOptions: OsSparklineOptions(
                  type: OsSparklineType.area,
                  lineWidth: 1.5,
                ),
              ),
            ],
            rowData: _orgData(),
          ),
        ),
      ],
    );
  }

  /// Org-chart sample data. `path` drives Tree Data; every leaf also carries
  /// metric values and a sparkline series.
  static List<Map<String, dynamic>> _orgData() {
    const paths = [
      <Object>['Engineering', 'Platform'],
      <Object>['Engineering', 'Platform'],
      <Object>['Engineering', 'Mobile'],
      <Object>['Engineering'],
      <Object>['Sales', 'EMEA'],
      <Object>['Sales', 'EMEA'],
      <Object>['Sales', 'APAC'],
      <Object>['Marketing'],
    ];
    const names = [
      'Ada Lovelace',
      'Grace Hopper',
      'Linus Nilsson',
      'Alan Turing',
      'Marie Curie',
      'Niels Bohr',
      'Lise Meitner',
      'Rosalind Franklin',
    ];
    const roles = [
      'Staff Engineer',
      'Backend Lead',
      'Mobile Lead',
      'VP Engineering',
      'Account Executive',
      'Regional Director',
      'Account Executive',
      'CMO',
    ];
    List<num> trend(int seed) => List<num>.generate(
      12,
      (i) => 20 + ((i * 37 + seed * 13) % 19) + (i * seed % 7),
    );
    return List<Map<String, dynamic>>.generate(names.length, (i) {
      return {
        'name': names[i],
        'role': roles[i],
        'path': paths[i],
        'headcount': 3 + i % 5,
        'revenue': 120 + i * 35,
        'trend': trend(i + 1),
      };
    });
  }
}
