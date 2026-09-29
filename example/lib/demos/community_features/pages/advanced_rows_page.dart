import 'package:flutter/material.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

import '../../theme_selector.dart';
import '../sample_data.dart';
import '../widgets/feature_panel.dart';

/// Demonstrates the advanced row layouts: master-detail and aligned grids.
///
/// - Master-detail: rows matching [OsGrid.isMasterRow] expand to render a
///   widget built by [OsGrid.detailWidgetBuilder] — here a nested OsGrid
///   showing the expanded row's team members.
/// - Aligned grids: two grids sharing an [OsAlignedGrid] groupId keep
///   their horizontal scroll positions and column state in sync.
class AdvancedRowsPage extends StatefulWidget {
  const AdvancedRowsPage({
    super.key,
    required this.themePreset,
    this.onThemeChanged,
  });

  final GridThemePreset themePreset;
  final ValueChanged<GridThemePreset>? onThemeChanged;

  @override
  State<AdvancedRowsPage> createState() => _AdvancedRowsPageState();
}

class _AdvancedRowsPageState extends State<AdvancedRowsPage> {
  final _masterController = OsGridController<Map<String, dynamic>>();
  final _alignedLeftController = OsGridController<Map<String, dynamic>>();
  final _alignedRightController = OsGridController<Map<String, dynamic>>();

  late final List<Map<String, dynamic>> _orgRows;
  late final List<Map<String, dynamic>> _alignedRows;

  bool _masterDetailOn = true;

  @override
  void initState() {
    super.initState();
    _orgRows = _generateOrgRows();
    _alignedRows = List.generate(12, (i) {
      return {
        'id': i,
        'metric': 'Metric ${String.fromCharCode(65 + i % 26)}',
        'q1': 100 + i * 7,
        'q2': 150 + i * 11,
        'q3': 90 + i * 13,
        'q4': 200 + i * 5,
      };
    });
  }

  @override
  void dispose() {
    _masterController.dispose();
    _alignedLeftController.dispose();
    _alignedRightController.dispose();
    super.dispose();
  }

  /// Department rows flagged as master rows, each with a nested team list.
  static List<Map<String, dynamic>> _generateOrgRows() {
    final people = generateSampleData(rowCount: 24);
    final rows = <Map<String, dynamic>>[];
    for (var i = 0; i < 6; i++) {
      final team = people
          .skip(i * 4)
          .take(4)
          .map(
            (p) => {
              'id': 100 + p['id'] as int,
              'name': p['name'],
              'age': p['age'],
              'salary': p['salary'],
            },
          )
          .toList();
      // The team travels ON the master row so the detail builder stays
      // correct even if the grid is sorted or filtered.
      rows.add({
        'id': i,
        'name': 'Department ${String.fromCharCode(65 + i)}',
        'isParent': true,
        'team': team,
      });
      rows.addAll(team);
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final theme = getThemeForPreset(widget.themePreset, context);

    return Column(
      children: [
        FeaturePanel(
          title: 'Master-Detail',
          children: [
            SwitchListTile(
              dense: true,
              title: const Text('Master rows expandable'),
              value: _masterDetailOn,
              onChanged: (value) => setState(() => _masterDetailOn = value),
            ),
          ],
        ),
        Expanded(
          child: OsGrid<Map<String, dynamic>>(
            controller: _masterController,
            theme: theme,
            rowData: _orgRows,
            getRowId: (row) => 'org-${row['id']}',
            columnDefs: const [
              OsColumnDef(field: 'name', headerName: 'Name', flex: 2),
              OsColumnDef(field: 'age', headerName: 'Age', width: 90),
              OsColumnDef(field: 'salary', headerName: 'Salary', width: 130),
            ],
            isMasterRow: _masterDetailOn
                ? (data) => data['isParent'] == true
                : null,
            detailWidgetBuilder: _masterDetailOn ? _buildDetailGrid : null,
          ),
        ),
        FeaturePanel(
          title: 'Aligned Grids (shared groupId — scroll one, both move)',
          children: const [],
        ),
        SizedBox(
          height: 180,
          child: OsGrid<Map<String, dynamic>>(
            controller: _alignedLeftController,
            theme: theme,
            rowData: _alignedRows,
            getRowId: (row) => 'metric-${row['id']}',
            alignedGrids: const OsAlignedGrid(groupId: 'demo-aligned'),
            columnDefs: const [
              OsColumnDef(field: 'metric', headerName: 'Metric', width: 160),
              OsColumnDef(field: 'q1', headerName: 'Q1', width: 120),
              OsColumnDef(field: 'q2', headerName: 'Q2', width: 120),
              OsColumnDef(field: 'q3', headerName: 'Q3', width: 120),
              OsColumnDef(field: 'q4', headerName: 'Q4', width: 120),
            ],
          ),
        ),
        SizedBox(
          height: 180,
          child: OsGrid<Map<String, dynamic>>(
            controller: _alignedRightController,
            theme: theme,
            rowData: _alignedRows,
            getRowId: (row) => 'metric-${row['id']}',
            alignedGrids: const OsAlignedGrid(groupId: 'demo-aligned'),
            columnDefs: const [
              OsColumnDef(field: 'metric', headerName: 'Metric', width: 160),
              OsColumnDef(field: 'q1', headerName: 'Q1', width: 120),
              OsColumnDef(field: 'q2', headerName: 'Q2', width: 120),
              OsColumnDef(field: 'q3', headerName: 'Q3', width: 120),
              OsColumnDef(field: 'q4', headerName: 'Q4', width: 120),
            ],
          ),
        ),
      ],
    );
  }

  /// Builds the nested detail grid for an expanded master row.
  Widget _buildDetailGrid(Map<String, dynamic> data, int rowIndex) {
    final team = (data['team'] as List).cast<Map<String, dynamic>>();
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: OsGrid<Map<String, dynamic>>(
        theme: getThemeForPreset(widget.themePreset, context),
        rowData: team,
        getRowId: (row) => 'org-${row['id']}',
        columnDefs: const [
          OsColumnDef(field: 'name', headerName: 'Team Member', flex: 2),
          OsColumnDef(field: 'age', headerName: 'Age', width: 90),
          OsColumnDef(field: 'salary', headerName: 'Salary', width: 130),
        ],
      ),
    );
  }
}
