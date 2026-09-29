import 'package:os_grid_flutter/os_grid_flutter.dart';
import 'package:flutter/material.dart';

import '../../theme_selector.dart';
import '../sample_data.dart';
import '../widgets/event_log.dart';
import '../widgets/feature_panel.dart';
import '../widgets/demo_ui.dart';

/// Demonstrates all cell editing capabilities of the grid.
///
/// Shows each editor type (text, number, date, select, checkbox, large text),
/// undo/redo support, editing behaviour toggles, and an event log capturing
/// editing events.
class CellEditingPage extends StatefulWidget {
  const CellEditingPage({
    super.key,
    required this.themePreset,
    this.onThemeChanged,
  });

  final GridThemePreset themePreset;
  final ValueChanged<GridThemePreset>? onThemeChanged;

  @override
  State<CellEditingPage> createState() => _CellEditingPageState();
}

class _CellEditingPageState extends State<CellEditingPage> {
  final _controller = OsGridController<Map<String, dynamic>>();
  late final List<Map<String, dynamic>> _rowData;
  final List<EventLogEntry> _eventLog = [];

  // Feature panel toggles
  bool _singleClickEdit = false;
  bool _stopEditingWhenCellsLoseFocus = false;
  bool _enterNavigatesVertically = false;
  bool _enterNavigatesVerticallyAfterEdit = false;
  bool _suppressClickEdit = false;
  bool _readOnlyEdit = false;

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

  void _addEvent(String type, String details) {
    setState(() {
      _eventLog.add(
        EventLogEntry(type: type, details: details, timestamp: DateTime.now()),
      );
      // Keep only the most recent 50 entries.
      if (_eventLog.length > 50) {
        _eventLog.removeRange(0, _eventLog.length - 50);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = getThemeForPreset(widget.themePreset, context);

    return Column(
      children: [
        FeaturePanel(
          title: 'Cell Editing Controls',
          children: [
            DemoToggle(
              label: 'Single Click Edit',
              value: _singleClickEdit,
              onChanged: (v) {
                setState(() => _singleClickEdit = v);
              },
            ),
            DemoToggle(
              label: 'Stop Editing on Focus Loss',
              value: _stopEditingWhenCellsLoseFocus,
              onChanged: (v) {
                setState(() => _stopEditingWhenCellsLoseFocus = v);
              },
            ),
            DemoToggle(
              label: 'Enter Navigates Vertically',
              value: _enterNavigatesVertically,
              onChanged: (v) {
                setState(() => _enterNavigatesVertically = v);
              },
            ),
            DemoToggle(
              label: 'Enter Nav After Edit',
              value: _enterNavigatesVerticallyAfterEdit,
              onChanged: (v) {
                setState(() => _enterNavigatesVerticallyAfterEdit = v);
              },
            ),
            DemoToggle(
              label: 'Suppress Click Edit',
              value: _suppressClickEdit,
              onChanged: (v) {
                setState(() => _suppressClickEdit = v);
              },
            ),
            DemoToggle(
              label: 'Read Only Edit',
              value: _readOnlyEdit,
              onChanged: (v) {
                setState(() => _readOnlyEdit = v);
              },
            ),
          ],
        ),
        FeaturePanel(
          title: 'Imperative Editing API',
          children: [
            FilledButton.tonalIcon(
              icon: const Icon(Icons.edit, size: 16),
              label: const Text('Start Editing (row 0, Name)'),
              onPressed: () =>
                  _controller.startEditingCell(rowIndex: 0, colId: 'name'),
            ),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.flash_on, size: 16),
              label: const Text('Flash Changed Cells'),
              onPressed: () => _controller.flashCells(),
            ),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.undo, size: 16),
              label: const Text('Undo'),
              onPressed: () => _controller.undoCellEditing(),
            ),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.redo, size: 16),
              label: const Text('Redo'),
              onPressed: () => _controller.redoCellEditing(),
            ),
          ],
        ),
        Expanded(
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: OsGrid<Map<String, dynamic>>(
                  controller: _controller,
                  theme: theme,
                  rowData: _rowData,
                  undoRedoCellEditing: true,
                  undoRedoCellEditingLimit: 10,
                  singleClickEdit: _singleClickEdit,
                  stopEditingWhenCellsLoseFocus: _stopEditingWhenCellsLoseFocus,
                  enterNavigatesVertically: _enterNavigatesVertically,
                  enterNavigatesVerticallyAfterEdit:
                      _enterNavigatesVerticallyAfterEdit,
                  suppressClickEdit: _suppressClickEdit,
                  readOnlyEdit: _readOnlyEdit,
                  onCellEditingStarted: (event) {
                    final col = event.colDef.field ?? 'unknown';
                    _addEvent(
                      'cellEditingStarted',
                      'Row ${event.rowIndex}, Col: $col',
                    );
                  },
                  onCellEditingStopped: (event) {
                    final col = event.colDef.field ?? 'unknown';
                    final status = event.cancelled
                        ? '(cancelled)'
                        : '(committed)';
                    _addEvent(
                      'cellEditingStopped',
                      'Row ${event.rowIndex}, Col: $col $status',
                    );
                  },
                  onCellValueChanged: (event) {
                    final col = event.colDef.field ?? 'unknown';
                    _addEvent(
                      'cellValueChanged',
                      'Row ${event.rowIndex}, Col: $col — '
                          '${event.oldValue} → ${event.newValue}',
                    );
                  },
                  onCellEditRequest: _readOnlyEdit
                      ? (event) {
                          final col = event.colDef.field ?? 'unknown';
                          _addEvent(
                            'cellEditRequest',
                            'Row ${event.rowIndex}, Col: $col — '
                                'proposed: ${event.newValue} '
                                '(old: ${event.oldValue})',
                          );
                        }
                      : null,
                  columnDefs: _buildColumnDefs(),
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                flex: 1,
                child: EventLog(entries: _eventLog, maxEntries: 50),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<OsColumnDef<Map<String, dynamic>>> _buildColumnDefs() {
    return [
      OsColumnDef<Map<String, dynamic>>(
        field: 'name',
        headerName: 'Name (Text)',
        editable: true,
        cellEditor: const OsTextCellEditor(maxLength: 100),
        flex: 2,
      ),
      OsColumnDef<Map<String, dynamic>>(
        field: 'age',
        headerName: 'Age (Number)',
        editable: true,
        cellEditor: const OsNumberCellEditor(min: 0, max: 120, step: 1),
        width: 130,
      ),
      OsColumnDef<Map<String, dynamic>>(
        field: 'startDate',
        headerName: 'Start Date (Date)',
        editable: true,
        cellEditor: OsDateCellEditor(
          min: DateTime(2015, 1, 1),
          max: DateTime(2030, 12, 31),
        ),
        width: 160,
      ),
      OsColumnDef<Map<String, dynamic>>(
        field: 'department',
        headerName: 'Dept (Select)',
        editable: true,
        cellEditor: const OsSelectCellEditor(
          values: ['Engineering', 'Sales', 'Marketing', 'HR', 'Finance'],
        ),
        width: 150,
      ),
      OsColumnDef<Map<String, dynamic>>(
        field: 'active',
        headerName: 'Active (Checkbox)',
        editable: true,
        cellEditor: const OsCheckboxCellEditor(),
        width: 140,
      ),
      OsColumnDef<Map<String, dynamic>>(
        field: 'notes',
        headerName: 'Notes (Large Text)',
        editable: true,
        cellEditor: const OsLargeTextCellEditor(maxLength: 500, rows: 6),
        flex: 2,
      ),
      OsColumnDef<Map<String, dynamic>>(
        field: 'country',
        headerName: 'Country (Rich Select)',
        editable: true,
        cellEditor: const OsRichSelectCellEditor(
          values: [
            'United States',
            'United Kingdom',
            'Germany',
            'France',
            'Japan',
            'Australia',
            'Canada',
          ],
        ),
        width: 180,
      ),
      OsColumnDef<Map<String, dynamic>>(
        field: 'salary',
        headerName: 'Salary (Custom + valueSetter)',
        editable: true,
        valueParser: (params) {
          // Accept an '80k' / '80,000' style shorthand.
          final raw = params.newValue.replaceAll(',', '');
          if (raw.toLowerCase().endsWith('k')) {
            final base = double.tryParse(raw.substring(0, raw.length - 1));
            if (base != null) return (base * 1000).round();
          }
          return int.tryParse(raw) ?? params.oldValue;
        },
        valueSetter: (params) {
          final value = params.newValue;
          // Reject implausible salaries — the edit silently fails to commit.
          if (value is! num || value < 20000 || value > 500000) return false;
          params.data['salary'] = value;
          return true;
        },
        cellEditor: OsCustomCellEditor(
          builder: (context, params) {
            final controller = TextEditingController(text: '${params.value}');
            return TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'e.g. 80k',
                isDense: true,
              ),
              onSubmitted: (value) => params.stopEditing(false),
              onChanged: (value) {
                final parsed = int.tryParse(
                  value.replaceAll(',', '').replaceAll('k', '000'),
                );
                if (parsed != null) params.onValueChanged(parsed);
              },
            );
          },
        ),
        width: 220,
      ),
    ];
  }
}
