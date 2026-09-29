import 'dart:math';

import 'package:os_grid_flutter/os_grid_flutter.dart';
import 'package:flutter/material.dart';

import '../../theme_selector.dart';
import '../sample_data.dart';
import '../widgets/feature_panel.dart';

/// Demonstrates pagination, row transactions, CSV export, and pinned summary
/// rows.
///
/// Shows page size selection, add/update/remove row operations via
/// `applyTransaction`, CSV export with preview, and pinned bottom summary rows
/// computing column sums.
class PaginationDataPage extends StatefulWidget {
  const PaginationDataPage({
    super.key,
    required this.themePreset,
    this.onThemeChanged,
  });

  final GridThemePreset themePreset;
  final ValueChanged<GridThemePreset>? onThemeChanged;

  @override
  State<PaginationDataPage> createState() => _PaginationDataPageState();
}

class _PaginationDataPageState extends State<PaginationDataPage> {
  final _controller = OsGridController<Map<String, dynamic>>();
  late List<Map<String, dynamic>> _rowData;

  int _pageSize = 25;
  int _rowCount = 100;
  String? _selectedRowId;

  // CSV export state
  String? _csvPreview;
  int? _csvCharCount;

  // Row ID counter for new rows
  int _nextId = 0;

  static const _pageSizeOptions = [10, 25, 50, 100];
  static const _rowCountOptions = [100, 500, 1000, 5000];

  @override
  void initState() {
    super.initState();
    _rowData = generateSampleData(rowCount: _rowCount);
    _nextId = _rowData.length;
    _controller.onSelectionChanged.listen(_onSelectionChanged);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onSelectionChanged(
    OsSelectionChangedEvent<Map<String, dynamic>> event,
  ) {
    final selected = _controller.getSelectedRows();
    setState(() {
      _selectedRowId = selected.isNotEmpty
          ? selected.first['id'].toString()
          : null;
    });
  }

  void _regenerateData(int count) {
    setState(() {
      _rowCount = count;
      _rowData = generateSampleData(rowCount: count);
      _nextId = _rowData.length;
      _selectedRowId = null;
      _csvPreview = null;
      _csvCharCount = null;
    });
  }

  void _addRow() {
    final rng = Random();
    final newRow = <String, dynamic>{
      'id': _nextId,
      'name': 'New Person $_nextId',
      'email': 'new.person$_nextId@example.com',
      'age': 18 + rng.nextInt(48),
      'salary': 30000 + rng.nextInt(120001),
      'department': const [
        'Engineering',
        'Sales',
        'Marketing',
        'HR',
        'Finance',
      ][rng.nextInt(5)],
      'startDate': DateTime.now(),
      'rating': rng.nextInt(6),
      'active': rng.nextBool(),
      'country': 'United States',
      'notes': 'Newly added row.',
    };
    _nextId++;
    _controller.applyTransaction(OsRowTransaction(add: [newRow]));
    setState(() {
      _rowData = List.of(_rowData)..add(newRow);
    });
  }

  void _updateRow() {
    if (_selectedRowId == null) return;
    final index = _rowData.indexWhere(
      (r) => r['id'].toString() == _selectedRowId,
    );
    if (index == -1) return;

    final existing = _rowData[index];
    final updatedRow = Map<String, dynamic>.from(existing);
    updatedRow['salary'] = (existing['salary'] as int) + 5000;

    _controller.applyTransaction(OsRowTransaction(update: [updatedRow]));
    setState(() {
      _rowData = List.of(_rowData);
      _rowData[index] = updatedRow;
    });
  }

  void _removeRow() {
    if (_selectedRowId == null) return;
    final index = _rowData.indexWhere(
      (r) => r['id'].toString() == _selectedRowId,
    );
    if (index == -1) return;

    final rowToRemove = _rowData[index];
    _controller.applyTransaction(OsRowTransaction(remove: [rowToRemove]));
    setState(() {
      _rowData = List.of(_rowData)..removeAt(index);
      _selectedRowId = null;
    });
  }

  void _exportCsv() {
    final csv = _controller.exportCsv();
    final lines = csv.split('\n');
    final previewLines = lines.take(5).join('\n');
    setState(() {
      _csvCharCount = csv.length;
      _csvPreview = previewLines;
    });
  }

  List<Map<String, dynamic>> _buildSummaryRows() {
    if (_rowData.isEmpty) return [];

    int ageSum = 0;
    int salarySum = 0;
    int ratingSum = 0;

    for (final row in _rowData) {
      ageSum += (row['age'] as int?) ?? 0;
      salarySum += (row['salary'] as int?) ?? 0;
      ratingSum += (row['rating'] as int?) ?? 0;
    }

    return [
      <String, dynamic>{
        'id': -1,
        'name': 'TOTAL',
        'email': '',
        'age': ageSum,
        'salary': salarySum,
        'department': '',
        'startDate': null,
        'rating': ratingSum,
        'active': null,
        'country': '',
        'notes': '',
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = getThemeForPreset(widget.themePreset, context);
    final hasSelection = _selectedRowId != null;

    return Column(
      children: [
        FeaturePanel(
          title: 'Pagination & Data Management Controls',
          children: [
            // Page size selector
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Page Size:'),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: _pageSize,
                  items: _pageSizeOptions
                      .map(
                        (size) =>
                            DropdownMenuItem(value: size, child: Text('$size')),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _pageSize = value);
                  },
                ),
              ],
            ),
            // Row count selector
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Row Count:'),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: _rowCount,
                  items: _rowCountOptions
                      .map(
                        (count) => DropdownMenuItem(
                          value: count,
                          child: Text('$count'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) _regenerateData(value);
                  },
                ),
              ],
            ),
            // Transaction buttons
            FilledButton.tonalIcon(
              onPressed: _addRow,
              icon: const Icon(Icons.add),
              label: const Text('Add Row'),
            ),
            FilledButton.tonalIcon(
              onPressed: hasSelection ? _updateRow : null,
              icon: const Icon(Icons.edit),
              label: const Text('Update Row'),
            ),
            FilledButton.tonalIcon(
              onPressed: hasSelection ? _removeRow : null,
              icon: const Icon(Icons.delete),
              label: const Text('Remove Row'),
            ),
            // CSV export button
            FilledButton.tonalIcon(
              onPressed: _exportCsv,
              icon: const Icon(Icons.download),
              label: const Text('Export CSV'),
            ),
          ],
        ),
        // CSV preview area
        if (_csvCharCount != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CSV Export: $_csvCharCount characters',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                if (_csvPreview != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _csvPreview!,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
        Expanded(
          child: OsGrid<Map<String, dynamic>>(
            controller: _controller,
            theme: theme,
            rowData: _rowData,
            getRowId: (data) => data['id'].toString(),
            pagination: OsPagination(
              pageSize: _pageSize,
              showPageSizeSelector: true,
              pageSizeOptions: _pageSizeOptions,
            ),
            rowSelection: OsRowSelection.single(),
            pinnedBottomRowData: _buildSummaryRows(),
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
        sortable: true,
      ),
      OsColumnDef<Map<String, dynamic>>(
        field: 'name',
        headerName: 'Name',
        flex: 2,
        sortable: true,
      ),
      OsColumnDef<Map<String, dynamic>>(
        field: 'email',
        headerName: 'Email',
        flex: 2,
        sortable: true,
      ),
      OsColumnDef<Map<String, dynamic>>(
        field: 'age',
        headerName: 'Age',
        width: 80,
        sortable: true,
        filter: const OsNumberFilter(),
      ),
      OsColumnDef<Map<String, dynamic>>(
        field: 'salary',
        headerName: 'Salary',
        width: 120,
        sortable: true,
        filter: const OsNumberFilter(),
      ),
      OsColumnDef<Map<String, dynamic>>(
        field: 'department',
        headerName: 'Department',
        width: 130,
        sortable: true,
        filter: const OsTextFilter(),
      ),
      OsColumnDef<Map<String, dynamic>>(
        field: 'rating',
        headerName: 'Rating',
        width: 90,
        sortable: true,
        filter: const OsNumberFilter(),
      ),
    ];
  }
}
