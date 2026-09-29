import 'package:os_grid_flutter/os_grid_flutter.dart';
import 'package:flutter/material.dart';

import '../../theme_selector.dart';
import '../sample_data.dart';
import '../widgets/feature_panel.dart';

/// Demonstrates the grid side bar and tool panels.
///
/// Shows the built-in Columns and Filters tool panels hosted in a side
/// bar, side switching (left/right), show/hide via the side bar API, and
/// opening a specific tool panel programmatically.
class SideBarPage extends StatefulWidget {
  const SideBarPage({
    super.key,
    required this.themePreset,
    this.onThemeChanged,
  });

  final GridThemePreset themePreset;
  final ValueChanged<GridThemePreset>? onThemeChanged;

  @override
  State<SideBarPage> createState() => _SideBarPageState();
}

class _SideBarPageState extends State<SideBarPage> {
  final _controller = OsGridController<Map<String, dynamic>>();
  late final List<Map<String, dynamic>> _rowData;

  OsSideBarPosition _position = OsSideBarPosition.right;

  @override
  void initState() {
    super.initState();
    _rowData = generateSampleData(rowCount: 30);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = getThemeForPreset(widget.themePreset, context);

    return Column(
      children: [
        FeaturePanel(
          title: 'Side Bar Controls',
          children: [
            SegmentedButton<OsSideBarPosition>(
              segments: const [
                ButtonSegment(
                  value: OsSideBarPosition.left,
                  label: Text('Left'),
                ),
                ButtonSegment(
                  value: OsSideBarPosition.right,
                  label: Text('Right'),
                ),
              ],
              selected: {_position},
              onSelectionChanged: (selection) {
                setState(() => _position = selection.first);
              },
            ),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.visibility, size: 16),
              label: const Text('Show Side Bar'),
              onPressed: () => _controller.setSideBarVisible(true),
            ),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.visibility_off, size: 16),
              label: const Text('Hide Side Bar'),
              onPressed: () => _controller.setSideBarVisible(false),
            ),
          ],
        ),
        Expanded(
          child: OsGrid<Map<String, dynamic>>(
            controller: _controller,
            theme: theme,
            rowData: _rowData,
            getRowId: (row) => 'row-${row['id']}',
            sideBar: OsSideBarDef.defaultPanels(position: _position),
            columnDefs: _buildColumnDefs(),
          ),
        ),
      ],
    );
  }

  List<OsColumnDef<Map<String, dynamic>>> _buildColumnDefs() {
    return [
      OsColumnDef<Map<String, dynamic>>(
        field: 'name',
        headerName: 'Name',
        sortable: true,
        filter: const OsTextFilter(),
        flex: 2,
      ),
      OsColumnDef<Map<String, dynamic>>(
        field: 'email',
        headerName: 'Email',
        sortable: true,
        filter: const OsTextFilter(),
        flex: 2,
      ),
      OsColumnDef<Map<String, dynamic>>(
        field: 'age',
        headerName: 'Age',
        sortable: true,
        filter: const OsNumberFilter(),
        width: 100,
      ),
      OsColumnDef<Map<String, dynamic>>(
        field: 'salary',
        headerName: 'Salary',
        sortable: true,
        filter: const OsNumberFilter(),
        width: 130,
      ),
      OsColumnDef<Map<String, dynamic>>(
        field: 'department',
        headerName: 'Department',
        sortable: true,
        filter: const OsTextFilter(),
        width: 140,
      ),
      OsColumnDef<Map<String, dynamic>>(
        field: 'startDate',
        headerName: 'Start Date',
        sortable: true,
        filter: const OsDateFilter(),
        width: 140,
      ),
      OsColumnDef<Map<String, dynamic>>(
        field: 'country',
        headerName: 'Country',
        sortable: true,
        filter: const OsTextFilter(),
        width: 140,
      ),
    ];
  }
}
