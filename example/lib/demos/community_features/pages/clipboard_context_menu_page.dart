import 'package:os_grid_flutter/os_grid_flutter.dart';
import 'package:flutter/material.dart';

import '../../theme_selector.dart';
import '../sample_data.dart';
import '../widgets/event_log.dart';
import '../widgets/feature_panel.dart';
import '../widgets/demo_ui.dart';

/// Demonstrates clipboard operations and context menu features.
///
/// Shows copy/cut/paste via keyboard shortcuts, a configurable context menu
/// with built-in and custom items, and an event log capturing clipboard events.
class ClipboardContextMenuPage extends StatefulWidget {
  const ClipboardContextMenuPage({
    super.key,
    required this.themePreset,
    this.onThemeChanged,
  });

  final GridThemePreset themePreset;
  final ValueChanged<GridThemePreset>? onThemeChanged;

  @override
  State<ClipboardContextMenuPage> createState() =>
      _ClipboardContextMenuPageState();
}

class _ClipboardContextMenuPageState extends State<ClipboardContextMenuPage> {
  final _controller = OsGridController<Map<String, dynamic>>();
  late final List<Map<String, dynamic>> _rowData;
  final List<EventLogEntry> _eventLog = [];

  // Feature panel toggles
  bool _copyHeadersToClipboard = false;
  bool _suppressClipboardPaste = false;

  @override
  void initState() {
    super.initState();
    _rowData = generateSampleData(rowCount: 30, seed: 99);
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
      // Keep only the most recent 20 entries for this page.
      if (_eventLog.length > 20) {
        _eventLog.removeRange(0, _eventLog.length - 20);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = getThemeForPreset(widget.themePreset, context);

    return Column(
      children: [
        FeaturePanel(
          title: 'Clipboard & Context Menu Controls',
          children: [
            DemoToggle(
              label: 'Copy Headers to Clipboard',
              value: _copyHeadersToClipboard,
              onChanged: (v) => setState(() => _copyHeadersToClipboard = v),
            ),
            DemoToggle(
              label: 'Suppress Clipboard Paste',
              value: _suppressClipboardPaste,
              onChanged: (v) => setState(() => _suppressClipboardPaste = v),
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
                  copyHeadersToClipboard: _copyHeadersToClipboard,
                  suppressClipboardPaste: _suppressClipboardPaste,
                  rowSelection: OsRowSelection.multiple(checkboxes: true),
                  cellSelection: const OsCellSelection(),
                  getContextMenuItems: _getContextMenuItems,
                  onClipboardCopy: (event) {
                    _addEvent(
                      'onClipboardCopy',
                      '${event.cellCount} cell(s) copied '
                          '(source: ${event.source})',
                    );
                  },
                  onClipboardPaste: (event) {
                    _addEvent(
                      'onClipboardPaste',
                      '${event.cellCount} cell(s) pasted '
                          '(source: ${event.source})',
                    );
                  },
                  onClipboardCut: (event) {
                    _addEvent(
                      'onClipboardCut',
                      '${event.cellCount} cell(s) cut '
                          '(source: ${event.source})',
                    );
                  },
                  columnDefs: _buildColumnDefs(),
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                flex: 1,
                child: EventLog(entries: _eventLog, maxEntries: 20),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<OsContextMenuItem>? _getContextMenuItems(
    GetContextMenuItemsParams<Map<String, dynamic>> params,
  ) {
    return [
      OsContextMenuItem.copy.withAction(() => _controller.copyToClipboard()),
      OsContextMenuItem.copyWithHeaders.withAction(
        () => _controller.copyToClipboard(),
      ),
      OsContextMenuItem.cut.withAction(() => _controller.cutToClipboard()),
      OsContextMenuItem.paste.withAction(
        () => _controller.pasteFromClipboard(),
      ),
      OsContextMenuItem.separator,
      OsContextMenuItem.export.withAction(() => _controller.exportCsv()),
      OsContextMenuItem.separator,
      // Custom item 1: Log cell info
      OsContextMenuItem(
        name: 'Log Cell Info',
        icon: Icons.info_outline,
        action: () {
          _addEvent(
            'customAction',
            'Cell info — Row: ${params.rowIndex}, '
                'Col: ${params.colId}, Value: ${params.value}',
          );
        },
      ),
      // Custom item 2: Highlight row in log
      OsContextMenuItem(
        name: 'Log Row Data',
        icon: Icons.data_object,
        action: () {
          final row = params.data;
          _addEvent(
            'customAction',
            'Row ${params.rowIndex}: '
                '${row['name']} (${row['department']})',
          );
        },
      ),
    ];
  }

  List<OsColumnDef<Map<String, dynamic>>> _buildColumnDefs() {
    return [
      OsColumnDef<Map<String, dynamic>>(
        field: 'name',
        headerName: 'Name',
        editable: true,
        flex: 2,
      ),
      OsColumnDef<Map<String, dynamic>>(
        field: 'email',
        headerName: 'Email',
        editable: true,
        flex: 2,
      ),
      OsColumnDef<Map<String, dynamic>>(
        field: 'department',
        headerName: 'Department',
        editable: true,
        width: 140,
      ),
      OsColumnDef<Map<String, dynamic>>(
        field: 'age',
        headerName: 'Age',
        editable: true,
        width: 80,
      ),
      OsColumnDef<Map<String, dynamic>>(
        field: 'salary',
        headerName: 'Salary',
        editable: true,
        width: 120,
      ),
      OsColumnDef<Map<String, dynamic>>(
        field: 'country',
        headerName: 'Country',
        editable: true,
        width: 140,
      ),
    ];
  }
}
