import 'package:os_grid_flutter/os_grid_flutter.dart';
import 'package:flutter/material.dart';

import '../../theme_selector.dart';
import '../sample_data.dart';
import '../widgets/feature_panel.dart';

/// Demonstrates column configuration features of the grid.
///
/// Shows column groups (nested), pinning, resizing, reordering, column menu,
/// column state save/restore, and column hover highlight.
class ColumnFeaturesPage extends StatefulWidget {
  const ColumnFeaturesPage({
    super.key,
    required this.themePreset,
    this.onThemeChanged,
  });

  final GridThemePreset themePreset;
  final ValueChanged<GridThemePreset>? onThemeChanged;

  @override
  State<ColumnFeaturesPage> createState() => _ColumnFeaturesPageState();
}

class _ColumnFeaturesPageState extends State<ColumnFeaturesPage> {
  final _controller = OsGridController<Map<String, dynamic>>();
  late final List<Map<String, dynamic>> _rowData;

  List<ColumnState>? _savedColumnState;

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
          title: 'Column Feature Controls',
          children: [
            FilledButton.tonalIcon(
              icon: const Icon(Icons.visibility_off, size: 16),
              label: const Text('Hide Email'),
              onPressed: () {
                _controller.setColumnsVisible(['email'], false);
              },
            ),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.visibility, size: 16),
              label: const Text('Show Email'),
              onPressed: () {
                _controller.setColumnsVisible(['email'], true);
              },
            ),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.push_pin, size: 16),
              label: const Text('Pin Name Left'),
              onPressed: () {
                _controller.setColumnsPinned(['name'], OsColumnPin.left);
              },
            ),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.push_pin_outlined, size: 16),
              label: const Text('Unpin Name'),
              onPressed: () {
                _controller.setColumnsPinned(['name'], null);
              },
            ),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.restart_alt, size: 16),
              label: const Text('Reset Columns'),
              onPressed: () {
                _controller.resetColumnState();
              },
            ),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.save, size: 16),
              label: const Text('Save State'),
              onPressed: () {
                setState(() {
                  _savedColumnState = _controller.getColumnState();
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Column state saved'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                }
              },
            ),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.restore, size: 16),
              label: const Text('Restore State'),
              onPressed: _savedColumnState == null
                  ? null
                  : () {
                      _controller.applyColumnState(
                        ApplyColumnStateParams(
                          state: _savedColumnState,
                          applyOrder: true,
                        ),
                      );
                    },
            ),
          ],
        ),
        Expanded(
          child: OsGrid<Map<String, dynamic>>(
            controller: _controller,
            theme: theme,
            rowData: _rowData,
            columnHoverHighlight: true,
            columnDefs: _buildColumnDefs(),
          ),
        ),
      ],
    );
  }

  List<OsColumnDefBase> _buildColumnDefs() {
    return [
      // Pinned left: ID column
      OsColumnDef<Map<String, dynamic>>(
        field: 'id',
        headerName: 'ID',
        pinned: OsColumnPin.left,
        width: 70,
        minWidth: 50,
        sortable: true,
        resizable: true,
      ),
      // Group: Personal Information
      OsColumnGroup(
        headerName: 'Personal Information',
        children: [
          // Nested group: Identity
          OsColumnGroup(
            headerName: 'Identity',
            children: [
              OsColumnDef<Map<String, dynamic>>(
                field: 'name',
                headerName: 'Name',
                sortable: true,
                resizable: true,
                minWidth: 50,
                flex: 2,
              ),
              OsColumnDef<Map<String, dynamic>>(
                field: 'email',
                headerName: 'Email',
                sortable: true,
                resizable: true,
                minWidth: 50,
                flex: 2,
              ),
              OsColumnDef<Map<String, dynamic>>(
                field: 'country',
                headerName: 'Country',
                sortable: true,
                resizable: true,
                minWidth: 50,
                width: 130,
              ),
            ],
          ),
          // Nested group: Demographics
          OsColumnGroup(
            headerName: 'Demographics',
            children: [
              OsColumnDef<Map<String, dynamic>>(
                field: 'age',
                headerName: 'Age',
                sortable: true,
                resizable: true,
                minWidth: 50,
                width: 90,
              ),
              OsColumnDef<Map<String, dynamic>>(
                field: 'department',
                headerName: 'Department',
                sortable: true,
                resizable: true,
                minWidth: 50,
                width: 130,
              ),
              OsColumnDef<Map<String, dynamic>>(
                field: 'active',
                headerName: 'Active',
                sortable: true,
                resizable: true,
                minWidth: 50,
                width: 90,
                builtInCellRenderer: OsBuiltInCellRenderer.checkbox,
              ),
            ],
          ),
        ],
      ),
      // Group: Employment
      OsColumnGroup(
        headerName: 'Employment',
        children: [
          // Nested group: Compensation
          OsColumnGroup(
            headerName: 'Compensation',
            children: [
              OsColumnDef<Map<String, dynamic>>(
                field: 'salary',
                headerName: 'Salary',
                sortable: true,
                resizable: true,
                minWidth: 50,
                width: 120,
              ),
              OsColumnDef<Map<String, dynamic>>(
                field: 'rating',
                headerName: 'Rating',
                sortable: true,
                resizable: true,
                minWidth: 50,
                width: 90,
              ),
              OsColumnDef<Map<String, dynamic>>(
                field: 'startDate',
                headerName: 'Start Date',
                sortable: true,
                resizable: true,
                minWidth: 50,
                width: 130,
                valueFormatter: (params) {
                  final v = params.value;
                  if (v is DateTime) {
                    return v.toIso8601String().substring(0, 10);
                  }
                  final s = v?.toString() ?? '';
                  return s.length >= 10 ? s.substring(0, 10) : s;
                },
              ),
            ],
          ),
        ],
      ),
      // Pinned right: Notes column
      OsColumnDef<Map<String, dynamic>>(
        field: 'notes',
        headerName: 'Notes',
        pinned: OsColumnPin.right,
        width: 150,
        minWidth: 50,
        sortable: true,
        resizable: true,
      ),
    ];
  }
}
