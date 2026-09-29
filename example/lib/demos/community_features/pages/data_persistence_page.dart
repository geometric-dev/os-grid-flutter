import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

import '../../theme_selector.dart';
import '../sample_data.dart';
import '../widgets/event_log.dart';
import '../widgets/feature_panel.dart';

/// Demonstrates grid state persistence, external filters and the filter
/// model API.
///
/// - Grid state: [OsGridController.getState] / [OsGridController.setState]
///   capture and restore sort, filter, column state, pagination, selection
///   and cell ranges; [OsGrid.onStateUpdated] streams debounced change
///   events (the hook a host would use to persist state to storage).
/// - External filter: [OsGrid.isExternalFilterPresent] /
///   [OsGrid.doesExternalFilterPass] apply a host-owned predicate between
///   the quick filter and column filters.
/// - Filter model: [OsGridController.setFilterModel] /
///   [OsGridController.getFilterModel] drive column filters programmatically.
class DataPersistencePage extends StatefulWidget {
  const DataPersistencePage({
    super.key,
    required this.themePreset,
    this.onThemeChanged,
  });

  final GridThemePreset themePreset;
  final ValueChanged<GridThemePreset>? onThemeChanged;

  @override
  State<DataPersistencePage> createState() => _DataPersistencePageState();
}

class _DataPersistencePageState extends State<DataPersistencePage> {
  final _controller = OsGridController<Map<String, dynamic>>();
  late final List<Map<String, dynamic>> _rowData;

  OsGridState? _savedState;
  String? _activeDepartment;
  final List<EventLogEntry> _eventLog = [];

  void _addLog(String details) {
    setState(() {
      _eventLog.add(
        EventLogEntry(
          type: 'action',
          details: details,
          timestamp: DateTime.now(),
        ),
      );
      if (_eventLog.length > 50) {
        _eventLog.removeRange(0, _eventLog.length - 50);
      }
    });
  }

  static const _departments = [
    'Engineering',
    'Sales',
    'Marketing',
    'HR',
    'Finance',
  ];

  @override
  void initState() {
    super.initState();
    _rowData = generateSampleData(rowCount: 40);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
        field: 'age',
        headerName: 'Age',
        sortable: true,
        filter: const OsNumberFilter(),
        width: 90,
      ),
      OsColumnDef<Map<String, dynamic>>(
        field: 'department',
        headerName: 'Department',
        sortable: true,
        filter: const OsTextFilter(),
        width: 140,
      ),
      OsColumnDef<Map<String, dynamic>>(
        field: 'salary',
        headerName: 'Salary',
        sortable: true,
        filter: const OsNumberFilter(),
        width: 120,
      ),
      OsColumnDef<Map<String, dynamic>>(
        field: 'startDate',
        headerName: 'Start Date',
        sortable: true,
        filter: const OsDateFilter(),
        width: 140,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = getThemeForPreset(widget.themePreset, context);

    return Column(
      children: [
        FeaturePanel(
          title: 'Grid State (getState / setState / onStateUpdated)',
          children: [
            FilledButton.tonalIcon(
              icon: const Icon(Icons.save, size: 16),
              label: const Text('Save State'),
              onPressed: () {
                setState(() => _savedState = _controller.getState());
                _addLog('State saved (sort/filter/columns/selection)');
              },
            ),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.restore, size: 16),
              label: const Text('Restore State'),
              onPressed: _savedState == null
                  ? null
                  : () {
                      _controller.setState(_savedState!);
                      _addLog('State restored');
                    },
            ),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.shuffle, size: 16),
              label: const Text('Mutate State (sort + filter)'),
              onPressed: () {
                _controller.setSortModel([
                  const OsSortModel(
                    colId: 'salary',
                    sort: OsSortDirection.descending,
                  ),
                ]);
                _controller.setFilterModel({
                  'salary': {
                    'filterType': 'number',
                    'type': 'greaterThan',
                    'filter': '60000',
                  },
                });
                _addLog('Applied salary sort + >60000 filter');
              },
            ),
          ],
        ),
        FeaturePanel(
          title: 'External Filter',
          children: [
            DropdownButton<String?>(
              value: _activeDepartment,
              hint: const Text('All departments'),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('All departments'),
                ),
                for (final d in _departments)
                  DropdownMenuItem<String?>(value: d, child: Text(d)),
              ],
              onChanged: (value) => setState(() => _activeDepartment = value),
            ),
          ],
        ),
        FeaturePanel(
          title: 'Filter Model API (setFilterModel / getFilterModel)',
          children: [
            FilledButton.tonalIcon(
              icon: const Icon(Icons.filter_alt, size: 16),
              label: const Text('Apply High Earners Filter'),
              onPressed: () {
                _controller.setFilterModel({
                  'salary': {
                    'filterType': 'number',
                    'type': 'greaterThan',
                    'filter': '70000',
                  },
                });
                _addLog('setFilterModel: salary > 70000');
              },
            ),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.filter_alt_off, size: 16),
              label: const Text('Clear All Filters'),
              onPressed: () {
                _controller.setFilterModel(null);
                _addLog('setFilterModel(null)');
              },
            ),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.code, size: 16),
              label: const Text('Log getFilterModel()'),
              onPressed: () {
                final model = _controller.getFilterModel();
                _addLog(
                  'getFilterModel: ${model == null ? 'null' : jsonEncode(model)}',
                );
              },
            ),
          ],
        ),
        EventLog(entries: _eventLog, maxEntries: 4),
        Expanded(
          child: OsGrid<Map<String, dynamic>>(
            controller: _controller,
            theme: theme,
            rowData: _rowData,
            getRowId: (row) => 'row-${row['id']}',
            columnDefs: _buildColumnDefs(),
            rowSelection: OsRowSelection.multiple(
              checkboxes: true,
              headerCheckbox: true,
            ),
            isExternalFilterPresent: () => _activeDepartment != null,
            doesExternalFilterPass: (row) =>
                row['department'] == _activeDepartment,
            onStateUpdated: (event) {
              _addLog('onStateUpdated: ${event.sources.join(', ')}');
            },
          ),
        ),
      ],
    );
  }
}
