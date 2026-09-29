import 'package:os_grid_flutter/os_grid_flutter.dart';
import 'package:flutter/material.dart';

import '../../theme_selector.dart';
import '../sample_data.dart';
import '../widgets/feature_panel.dart';

/// Demonstrates the column state API of the grid.
///
/// Shows save/restore of column configuration (visibility, width, pinning,
/// order, sort) via [OsGridController.getColumnState] /
/// [OsGridController.applyColumnState], hard-reset via `purge: true`, and
/// interactive pinning of columns.
class ColumnStatePage extends StatefulWidget {
  const ColumnStatePage({
    super.key,
    required this.themePreset,
    this.onThemeChanged,
  });

  final GridThemePreset themePreset;
  final ValueChanged<GridThemePreset>? onThemeChanged;

  @override
  State<ColumnStatePage> createState() => _ColumnStatePageState();
}

class _ColumnStatePageState extends State<ColumnStatePage> {
  final _controller = OsGridController<Map<String, dynamic>>();
  late final List<Map<String, dynamic>> _rowData;

  List<ColumnState>? _savedState;
  String _status = 'No state saved yet.';

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

  void _showStatus(String message) {
    setState(() => _status = message);
  }

  @override
  Widget build(BuildContext context) {
    final theme = getThemeForPreset(widget.themePreset, context);

    return Column(
      children: [
        FeaturePanel(
          title: 'Column State Controls',
          children: [
            FilledButton.tonalIcon(
              icon: const Icon(Icons.save, size: 16),
              label: const Text('Save State'),
              onPressed: () {
                final state = _controller.getColumnState();
                setState(() => _savedState = state);
                _showStatus('Saved ${state.length} column states.');
              },
            ),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.restore, size: 16),
              label: const Text('Restore State'),
              onPressed: _savedState == null
                  ? null
                  : () {
                      final ok = _controller.applyColumnState(
                        ApplyColumnStateParams(
                          state: _savedState,
                          applyOrder: true,
                        ),
                      );
                      _showStatus(
                        ok
                            ? 'State restored (merge semantics).'
                            : 'State restore failed.',
                      );
                    },
            ),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.clear_all, size: 16),
              label: const Text('Purge & Reset'),
              onPressed: () {
                // purge: true discards EVERY existing override (widths,
                // pins, visibility, order, sort model) before applying the
                // (empty) state — columns return to definition defaults.
                final ok = _controller.applyColumnState(
                  const ApplyColumnStateParams(purge: true),
                );
                _showStatus(
                  ok
                      ? 'All overrides purged — back to definition defaults.'
                      : 'Purge failed.',
                );
              },
            ),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.push_pin, size: 16),
              label: const Text('Pin Name & Dept Left'),
              onPressed: () {
                _controller.setColumnsPinned([
                  'name',
                  'department',
                ], OsColumnPin.left);
                _showStatus('Pinned name + department left.');
              },
            ),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.push_pin_outlined, size: 16),
              label: const Text('Unpin All'),
              onPressed: () {
                _controller.setColumnsPinned([
                  'id',
                  'name',
                  'department',
                  'email',
                  'salary',
                  'country',
                ], null);
                _showStatus('Unpinned all columns.');
              },
            ),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.visibility_off, size: 16),
              label: const Text('Hide Country'),
              onPressed: () {
                _controller.setColumnsVisible(['country'], false);
                _showStatus('Hid country.');
              },
            ),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.visibility, size: 16),
              label: const Text('Show Country'),
              onPressed: () {
                _controller.setColumnsVisible(['country'], true);
                _showStatus('Showed country.');
              },
            ),
            Text(_status, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        Expanded(
          child: OsGrid<Map<String, dynamic>>(
            controller: _controller,
            theme: theme,
            rowData: _rowData,
            getRowId: (row) => 'row-${row['id']}',
            columnDefs: _buildColumnDefs(),
          ),
        ),
      ],
    );
  }

  List<OsColumnDef<Map<String, dynamic>>> _buildColumnDefs() {
    return [
      OsColumnDef<Map<String, dynamic>>(
        field: 'id',
        headerName: 'ID',
        width: 70,
        pinned: OsColumnPin.left,
        sortable: true,
        resizable: true,
      ),
      OsColumnDef<Map<String, dynamic>>(
        field: 'name',
        headerName: 'Name',
        sortable: true,
        resizable: true,
        flex: 2,
      ),
      OsColumnDef<Map<String, dynamic>>(
        field: 'department',
        headerName: 'Department',
        sortable: true,
        resizable: true,
        width: 140,
      ),
      OsColumnDef<Map<String, dynamic>>(
        field: 'email',
        headerName: 'Email',
        sortable: true,
        resizable: true,
        flex: 2,
      ),
      OsColumnDef<Map<String, dynamic>>(
        field: 'salary',
        headerName: 'Salary',
        sortable: true,
        resizable: true,
        width: 120,
      ),
      OsColumnDef<Map<String, dynamic>>(
        field: 'country',
        headerName: 'Country',
        sortable: true,
        resizable: true,
        width: 140,
      ),
    ];
  }
}
