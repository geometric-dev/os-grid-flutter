import 'package:os_grid_flutter/os_grid_flutter.dart';
import 'package:flutter/material.dart';

import '../../theme_selector.dart';
import '../sample_data.dart';
import '../widgets/feature_panel.dart';
import '../widgets/demo_ui.dart';

/// Demonstrates sorting and filtering features of the grid.
///
/// Shows quick filter, floating filters, multi-column sort, and column-level
/// text/number/date filters with interactive Feature Panel toggles.
class SortingFilteringPage extends StatefulWidget {
  const SortingFilteringPage({
    super.key,
    required this.themePreset,
    this.onThemeChanged,
  });

  final GridThemePreset themePreset;
  final ValueChanged<GridThemePreset>? onThemeChanged;

  @override
  State<SortingFilteringPage> createState() => _SortingFilteringPageState();
}

class _SortingFilteringPageState extends State<SortingFilteringPage> {
  final _controller = OsGridController<Map<String, dynamic>>();
  late final List<Map<String, dynamic>> _rowData;

  String _quickFilterText = '';
  bool _accentedSort = false;
  bool _alwaysMultiSort = false;
  bool _suppressMultiSort = false;

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
          title: 'Sorting & Filtering Controls',
          children: [
            SizedBox(
              width: 250,
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'Quick Filter',
                  hintText: 'Type to filter...',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => setState(() => _quickFilterText = value),
              ),
            ),
            DemoToggle(
              label: 'Accented Sort',
              value: _accentedSort,
              onChanged: (v) {
                setState(() => _accentedSort = v);
              },
            ),
            DemoToggle(
              label: 'Always Multi Sort',
              value: _alwaysMultiSort,
              onChanged: (v) {
                setState(() => _alwaysMultiSort = v);
              },
            ),
            DemoToggle(
              label: 'Suppress Multi Sort',
              value: _suppressMultiSort,
              onChanged: (v) {
                setState(() => _suppressMultiSort = v);
              },
            ),
          ],
        ),
        Expanded(
          child: OsGrid<Map<String, dynamic>>(
            controller: _controller,
            theme: theme,
            rowData: _rowData,
            quickFilterText: _quickFilterText.isEmpty ? null : _quickFilterText,
            floatingFilter: true,
            accentedSort: _accentedSort,
            alwaysMultiSort: _alwaysMultiSort,
            suppressMultiSort: _suppressMultiSort,
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
