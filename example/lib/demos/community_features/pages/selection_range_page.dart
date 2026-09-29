import 'package:os_grid_flutter/os_grid_flutter.dart';
import 'package:flutter/material.dart';

import '../../theme_selector.dart';
import '../sample_data.dart';
import '../widgets/feature_panel.dart';

/// Demonstrates row selection and cell range selection features.
///
/// Shows multiple row selection with checkboxes, click-and-drag range
/// selection, Shift+click contiguous selection, Ctrl+click multi-range,
/// and programmatic selection/deselection via the controller API.
class SelectionRangePage extends StatefulWidget {
  const SelectionRangePage({
    super.key,
    required this.themePreset,
    this.onThemeChanged,
  });

  final GridThemePreset themePreset;
  final ValueChanged<GridThemePreset>? onThemeChanged;

  @override
  State<SelectionRangePage> createState() => _SelectionRangePageState();
}

class _SelectionRangePageState extends State<SelectionRangePage> {
  final _controller = OsGridController<Map<String, dynamic>>();
  late final List<Map<String, dynamic>> _rowData;

  /// Whether the grid uses multiple selection mode (true) or single (false).
  bool _multipleMode = true;

  /// Number of currently selected rows.
  int _selectedRowCount = 0;

  /// Dimensions of the current range selection (rows × columns).
  int _rangeRows = 0;
  int _rangeCols = 0;

  @override
  void initState() {
    super.initState();
    _rowData = generateSampleData(rowCount: 50);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  OsRowSelection get _rowSelection {
    if (_multipleMode) {
      return OsRowSelection.multiple(checkboxes: true, headerCheckbox: true);
    }
    return OsRowSelection.single();
  }

  void _onSelectionChanged(
    OsSelectionChangedEvent<Map<String, dynamic>> event,
  ) {
    setState(() {
      _selectedRowCount = event.selectedRows.length;
    });
  }

  void _onRangeSelectionChanged(OsRangeSelectionChangedEvent event) {
    setState(() {
      if (event.ranges.isEmpty) {
        _rangeRows = 0;
        _rangeCols = 0;
      } else {
        // Sum up the dimensions across all active ranges.
        int totalRows = 0;
        int totalCols = 0;
        for (final range in event.ranges) {
          totalRows += range.rowCount;
          totalCols += range.columnCount;
        }
        // For display, show the last range dimensions if single range,
        // or total if multiple.
        if (event.ranges.length == 1) {
          _rangeRows = event.ranges.first.rowCount;
          _rangeCols = event.ranges.first.columnCount;
        } else {
          _rangeRows = totalRows;
          _rangeCols = totalCols;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = getThemeForPreset(widget.themePreset, context);

    return Column(
      children: [
        FeaturePanel(
          title: 'Selection Controls',
          children: [
            // Selection mode toggle
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Single')),
                ButtonSegment(value: true, label: Text('Multiple')),
              ],
              selected: {_multipleMode},
              onSelectionChanged: (values) {
                setState(() {
                  _multipleMode = values.first;
                  _selectedRowCount = 0;
                });
                _controller.deselectAll();
              },
            ),
            const SizedBox(width: 16),
            // Action buttons
            FilledButton.tonal(
              onPressed: () => _controller.selectAll(),
              child: const Text('Select All'),
            ),
            FilledButton.tonal(
              onPressed: () => _controller.deselectAll(),
              child: const Text('Deselect All'),
            ),
            FilledButton.tonal(
              onPressed: () => _controller.selectAllFiltered(),
              child: const Text('Select All Filtered'),
            ),
            FilledButton.tonal(
              onPressed: () {
                _controller.clearRangeSelection();
                setState(() {
                  _rangeRows = 0;
                  _rangeCols = 0;
                });
              },
              child: const Text('Clear Range Selection'),
            ),
          ],
        ),
        // Status area
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Chip(
                avatar: const Icon(Icons.check_box, size: 18),
                label: Text('Selected rows: $_selectedRowCount'),
              ),
              const SizedBox(width: 16),
              Chip(
                avatar: const Icon(Icons.grid_on, size: 18),
                label: Text(
                  _rangeRows > 0
                      ? 'Range: $_rangeRows × $_rangeCols'
                      : 'Range: none',
                ),
              ),
            ],
          ),
        ),
        // Grid
        Expanded(
          child: OsGrid<Map<String, dynamic>>(
            controller: _controller,
            theme: theme,
            rowData: _rowData,
            rowSelection: _rowSelection,
            cellSelection: const OsCellSelection(suppressMultiRanges: false),
            onSelectionChanged: _onSelectionChanged,
            onRangeSelectionChanged: _onRangeSelectionChanged,
            getRowId: (data) => data['id'].toString(),
            columnDefs: [
              OsColumnDef(field: 'id', headerName: 'ID', width: 70),
              OsColumnDef(field: 'name', headerName: 'Name', width: 160),
              OsColumnDef(
                field: 'department',
                headerName: 'Department',
                width: 130,
              ),
              OsColumnDef(field: 'age', headerName: 'Age', width: 80),
              OsColumnDef(field: 'salary', headerName: 'Salary', width: 110),
              OsColumnDef(field: 'country', headerName: 'Country', width: 130),
            ],
          ),
        ),
      ],
    );
  }
}
