import 'package:os_grid_flutter/os_grid_flutter.dart';
import 'package:flutter/material.dart';

import '../../theme_selector.dart';
import '../sample_data.dart';
import '../widgets/feature_panel.dart';
import '../widgets/demo_ui.dart';

/// Demonstrates row grouping and aggregation features of the grid.
///
/// Shows row grouping by department, built-in aggregation (sum/avg),
/// expand/collapse controls, and postSortRows post-processing that floats
/// flagged rows to the top after every sort.
class GroupingPage extends StatefulWidget {
  const GroupingPage({
    super.key,
    required this.themePreset,
    this.onThemeChanged,
  });

  final GridThemePreset themePreset;
  final ValueChanged<GridThemePreset>? onThemeChanged;

  @override
  State<GroupingPage> createState() => _GroupingPageState();
}

class _GroupingPageState extends State<GroupingPage> {
  final _controller = OsGridController<Map<String, dynamic>>();
  late final List<Map<String, dynamic>> _rowData;

  /// Whether postSortRows floats VIP rows above everything else.
  bool _vipFirst = false;

  @override
  void initState() {
    super.initState();
    _rowData = generateSampleData(rowCount: 30);
    // Deterministically flag the first three rows as VIP so the
    // postSortRows demo has a stable, observable effect.
    for (final row in _rowData.take(3)) {
      row['vip'] = true;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Sort post-processing: when enabled, rows flagged `vip` are floated
  /// to the top of the display order after every sort.
  List<Map<String, dynamic>> _postSortRows(List<Map<String, dynamic>> rows) {
    if (!_vipFirst) return rows;
    final vips = rows.where((r) => r['vip'] == true).toList();
    final rest = rows.where((r) => r['vip'] != true).toList();
    return [...vips, ...rest];
  }

  @override
  Widget build(BuildContext context) {
    final theme = getThemeForPreset(widget.themePreset, context);

    return Column(
      children: [
        FeaturePanel(
          title: 'Grouping & Aggregation Controls',
          children: [
            FilledButton.tonalIcon(
              icon: const Icon(Icons.unfold_more, size: 16),
              label: const Text('Expand All'),
              onPressed: () => _controller.expandAll(),
            ),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.unfold_less, size: 16),
              label: const Text('Collapse All'),
              onPressed: () => _controller.collapseAll(),
            ),
            DemoToggle(
              label: 'VIP rows first (postSortRows)',
              value: _vipFirst,
              onChanged: (v) {
                setState(() => _vipFirst = v);
              },
            ),
          ],
        ),
        Expanded(
          child: OsGrid<Map<String, dynamic>>(
            controller: _controller,
            theme: theme,
            rowData: _rowData,
            columnDefs: _buildColumnDefs(),
            groupDefaultExpanded: -1,
            postSortRows: _postSortRows,
            getRowId: (row) => 'row-${row['id']}',
          ),
        ),
      ],
    );
  }

  List<OsColumnDef<Map<String, dynamic>>> _buildColumnDefs() {
    return [
      OsColumnDef<Map<String, dynamic>>(
        field: 'department',
        headerName: 'Department',
        rowGroup: true,
        sortable: true,
        width: 150,
      ),
      OsColumnDef<Map<String, dynamic>>(
        field: 'name',
        headerName: 'Name',
        sortable: true,
        flex: 2,
      ),
      OsColumnDef<Map<String, dynamic>>(
        field: 'salary',
        headerName: 'Salary (sum)',
        sortable: true,
        aggFunc: 'sum',
        width: 140,
        valueFormatter: (params) =>
            '\$${(params.value as num?)?.toStringAsFixed(0) ?? '-'}',
      ),
      OsColumnDef<Map<String, dynamic>>(
        field: 'age',
        headerName: 'Age (avg)',
        sortable: true,
        aggFunc: 'avg',
        width: 120,
      ),
      OsColumnDef<Map<String, dynamic>>(
        field: 'rating',
        headerName: 'Rating (max)',
        sortable: true,
        aggFunc: 'max',
        width: 130,
      ),
    ];
  }
}
