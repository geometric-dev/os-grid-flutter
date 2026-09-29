import 'package:flutter/material.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

import '../../theme_selector.dart';
import '../widgets/demo_ui.dart';

/// Enterprise features showcase — tree data, sparklines, status bar
/// panels, XLSX export, loading overlays, and GridInspector.
class EnterpriseFeaturesPage extends StatefulWidget {
  const EnterpriseFeaturesPage({super.key, required this.themePreset});

  final GridThemePreset themePreset;

  @override
  State<EnterpriseFeaturesPage> createState() => _EnterpriseFeaturesPageState();
}

class _EnterpriseFeaturesPageState extends State<EnterpriseFeaturesPage> {
  final _controller = OsGridController<Map<String, dynamic>>();

  static final _orgData = _generateOrgData();

  static List<Map<String, dynamic>> _generateOrgData() {
    final rows = <Map<String, dynamic>>[];
    const departments = ['Engineering', 'Sales', 'Marketing', 'Finance'];
    const names = [
      'Alice Johnson',
      'Bob Smith',
      'Carol Davis',
      'David Wilson',
      'Eve Brown',
      'Frank Miller',
      'Grace Lee',
      'Henry Chen',
      'Ivy Garcia',
      'Jack Rodriguez',
      'Karen White',
      'Liam Taylor',
    ];
    const roles = ['Engineer', 'Senior Eng', 'Lead', 'Manager', 'Director'];
    const regions = ['NA', 'EMEA', 'APAC'];

    for (int i = 0; i < 60; i++) {
      final dept = departments[i % departments.length];
      rows.add({
        'id': 'emp-$i',
        'name': names[(i * 7) % names.length],
        'department': dept,
        'role': roles[i % roles.length],
        'region': regions[i % regions.length],
        'salary': 60000 + (i * 2500) % 90000,
        'satisfaction': (i * 7) % 5 + 1,
        'revenue': [for (var j = 0; j < 8; j++) 20 + ((i * 13 + j * 7) % 60)],
        'headcount': 3 + i % 12,
        'path': [dept, 'Team ${i % 3}'],
      });
    }
    return rows;
  }

  bool _treeMode = false;
  bool _showInspector = false;
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = getThemeForPreset(widget.themePreset, context);
    return Scaffold(
      body: Column(
        children: [
          // Feature toggle bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Wrap(
              spacing: 12,
              children: [
                DemoToggle(
                  key: const Key('enterprise-tree-data-toggle'),
                  label: 'Tree Data',
                  value: _treeMode,
                  onChanged: (v) => setState(() => _treeMode = v),
                ),
                DemoToggle(
                  label: 'Inspector',
                  value: _showInspector,
                  onChanged: (v) => setState(() => _showInspector = v),
                ),
                DemoToggle(
                  label: 'Loading',
                  value: _loading,
                  onChanged: (v) => setState(() => _loading = v),
                ),
                TextButton(
                  onPressed: () => _controller.showLoadingOverlay(),
                  child: const Text('Show Overlay'),
                ),
                TextButton(
                  onPressed: () => _controller.hideOverlay(),
                  child: const Text('Hide Overlay'),
                ),
                TextButton(
                  onPressed: () {
                    final bytes = _controller.exportXlsx();
                    debugPrint('XLSX: ${bytes.length} bytes');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Exported ${bytes.length} bytes')),
                    );
                  },
                  child: const Text('Export XLSX'),
                ),
              ],
            ),
          ),
          Expanded(
            child: OsGrid<Map<String, dynamic>>(
              controller: _controller,
              getRowId: (row) => row['id'] as String,
              theme: theme,
              showInspector: _showInspector,
              loading: _loading ? true : null,
              columnDefs: [
                if (_treeMode)
                  // Tree data provides the hierarchy via getDataPath; adding
                  // rowGroup here would trip the grid validator's
                  // treeData+rowGroup combination warning.
                  const OsColumnDef(
                    field: 'department',
                    headerName: 'Department',
                  )
                else
                  OsColumnDef(
                    field: 'department',
                    headerName: 'Department',
                    checkboxSelection: true,
                    headerCheckboxSelection: true,
                  ),
                OsColumnDef(field: 'name', headerName: 'Name', width: 160),
                const OsColumnDef(
                  field: 'role',
                  headerName: 'Role',
                  width: 120,
                ),
                const OsColumnDef(
                  field: 'region',
                  headerName: 'Region',
                  width: 90,
                ),
                OsColumnDef(
                  field: 'salary',
                  headerName: 'Salary',
                  width: 110,
                  valueFormatter: (params) =>
                      '\$${(params.value as num?)?.toStringAsFixed(0) ?? '-'}',
                ),
                const OsColumnDef(
                  field: 'satisfaction',
                  headerName: 'Rating',
                  width: 120,
                  builtInCellRenderer: OsBuiltInCellRenderer.starRating,
                ),
                OsColumnDef(
                  field: 'revenue',
                  headerName: 'Revenue',
                  width: 130,
                  sparklineOptions: const OsSparklineOptions(
                    type: OsSparklineType.area,
                  ),
                  builtInCellRenderer: OsBuiltInCellRenderer.sparkline,
                ),
                const OsColumnDef(
                  field: 'headcount',
                  headerName: 'HC',
                  width: 60,
                ),
              ],
              rowData: _orgData,
              defaultColDef: const OsColumnDef<dynamic>(
                sortable: true,
                resizable: true,
              ),
              rowSelection: OsRowSelection.multiple(
                checkboxes: true,
                headerCheckbox: true,
              ),
              treeData: _treeMode,
              getDataPath: _treeMode
                  ? (row) => row['path'] as List<String>?
                  : null,
              groupDefaultExpanded: _treeMode ? 1 : null,
              pagination: const OsPagination(pageSize: 25),
              statusBarConfig: OsStatusBarConfig(
                statusPanels: [
                  const OsStatusPanelDef(
                    aggregationFunc: 'sum',
                    valueColId: 'salary',
                    label: 'Total Salary',
                  ),
                  const OsStatusPanelDef(
                    aggregationFunc: 'avg',
                    valueColId: 'salary',
                    label: 'Avg',
                    align: OsStatusPanelAlign.right,
                  ),
                  const OsStatusPanelDef(
                    aggregationFunc: 'count',
                    label: 'Rows',
                    align: OsStatusPanelAlign.right,
                  ),
                ],
              ),
              cellSelection: const OsCellSelection(),
            ),
          ),
        ],
      ),
    );
  }
}
