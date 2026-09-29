import 'package:os_grid_flutter/os_grid_flutter.dart';
import 'package:flutter/material.dart';

import '../../theme_selector.dart';
import '../sample_data.dart';
import '../widgets/event_log.dart';
import '../widgets/feature_panel.dart';
import '../widgets/demo_ui.dart';

/// Demonstrates row drag-and-drop: managed/unmanaged internal reordering,
/// plus external drag-and-drop — dragging rows OUT of the grid onto an
/// external target ([OsGrid.onRowDragOut], enabled via
/// `OsDragAndDrop(enableDragOut: true)`), and dropping external items INTO
/// the grid ([OsGrid.onExternalDrop], enabled via
/// `OsDragAndDrop(enableDropIn: true)`).
class RowDragPage extends StatefulWidget {
  const RowDragPage({
    super.key,
    required this.themePreset,
    this.onThemeChanged,
  });

  final GridThemePreset themePreset;
  final ValueChanged<GridThemePreset>? onThemeChanged;

  @override
  State<RowDragPage> createState() => _RowDragPageState();
}

class _RowDragPageState extends State<RowDragPage> {
  final _controller = OsGridController<Map<String, dynamic>>();
  late final List<Map<String, dynamic>> _rowData;
  final List<EventLogEntry> _eventLog = [];

  /// Whether the grid auto-reorders rows on drop (managed mode).
  bool _managedMode = true;

  /// Rows accepted from external Draggables via the grid's drop-in target.
  final List<String> _externallyDropped = [];

  @override
  void initState() {
    super.initState();
    _rowData = generateSampleData(rowCount: 25);
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
          title: 'Row Drag Controls',
          children: [
            DemoToggle(
              label: 'Managed Mode',
              value: _managedMode,
              onChanged: (v) => setState(() => _managedMode = v),
            ),
            Text(
              _managedMode
                  ? '(Grid auto-reorders rows on drop)'
                  : '(Events only — rows stay in place)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
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
                  rowDrag: true,
                  rowDragManaged: _managedMode,
                  dragAndDrop: const OsDragAndDrop(
                    enableDragOut: true,
                    enableDropIn: true,
                  ),
                  onRowDragOut: (event) {
                    _addEvent(
                      'onRowDragOut',
                      'Row ${event.rowIndex} (${event.data['name']}) '
                          'dragged out of the grid',
                    );
                  },
                  onExternalDrop: (event) {
                    final payload = event.dragData;
                    setState(() => _externallyDropped.add('$payload'));
                    _addEvent(
                      'onExternalDrop',
                      '"$payload" dropped at row ${event.targetRowIndex}',
                    );
                  },
                  onRowDragEnter: (event) {
                    _addEvent(
                      'onRowDragEnter',
                      'Row index: ${event.overIndex}',
                    );
                  },
                  onRowDragMove: (event) {
                    _addEvent(
                      'onRowDragMove',
                      'Over index: ${event.overIndex}',
                    );
                  },
                  onRowDragEnd: (event) {
                    _addEvent(
                      'onRowDragEnd',
                      'fromIndex: ${event.fromIndex}, '
                          'toIndex: ${event.toIndex}',
                    );
                  },
                  columnDefs: _buildColumnDefs(),
                ),
              ),
              const VerticalDivider(width: 1),
              // External drop target: drag a row handle out of the grid
              // onto this panel (enableDragOut).
              Expanded(
                flex: 1,
                child: DragTarget<Map<String, dynamic>>(
                  onAcceptWithDetails: (details) {
                    _addEvent(
                      'external target',
                      'Accepted "${details.data['name']}"',
                    );
                  },
                  builder: (context, candidate, rejected) => Container(
                    margin: const EdgeInsets.all(8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: candidate.isNotEmpty
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'External drop target',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          candidate.isNotEmpty
                              ? 'Release to accept the row'
                              : 'Drag a row handle (⠿) here',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const VerticalDivider(width: 1),
              // External drag source: drag this chip INTO the grid
              // (enableDropIn).
              Expanded(
                flex: 1,
                child: Column(
                  children: [
                    Draggable<String>(
                      data: 'External item',
                      feedback: Material(
                        elevation: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          color: Theme.of(context).colorScheme.primaryContainer,
                          child: const Text('External item'),
                        ),
                      ),
                      childWhenDragging: const SizedBox.shrink(),
                      child: Chip(
                        avatar: const Icon(Icons.drag_indicator, size: 16),
                        label: const Text('Drag into grid'),
                      ),
                    ),
                    for (final item in _externallyDropped.take(5))
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.download, size: 16),
                        title: Text(item, overflow: TextOverflow.ellipsis),
                      ),
                  ],
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
    return const [
      OsColumnDef(field: 'id', headerName: '#', width: 60),
      OsColumnDef(field: 'name', headerName: 'Name', flex: 2),
      OsColumnDef(field: 'department', headerName: 'Department', flex: 1),
      OsColumnDef(field: 'country', headerName: 'Country', flex: 1),
      OsColumnDef(field: 'age', headerName: 'Age', width: 80),
    ];
  }
}
