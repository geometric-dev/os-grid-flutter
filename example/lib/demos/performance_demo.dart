/// Performance Demo — 100,000 rows with sorting, filtering, column groups,
/// conditional cell styling, pagination, cell editing, row drag, pinned rows,
/// row grouping, aggregation, and pivot mode.
///
/// Mirrors the OS Grid Performance demo: https://ag-grid.com/example/
library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

import 'theme_selector.dart';

void main() => runApp(const PerformanceDemoApp());

class PerformanceDemoApp extends StatefulWidget {
  const PerformanceDemoApp({super.key});

  @override
  State<PerformanceDemoApp> createState() => _PerformanceDemoAppState();
}

class _PerformanceDemoAppState extends State<PerformanceDemoApp> {
  GridThemePreset _themePreset = GridThemePreset.quartzDark;

  @override
  Widget build(BuildContext context) {
    final isDark = isPresetDark(_themePreset);
    return MaterialApp(
      title: 'OS Grid Flutter — Performance Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      home: PerformancePage(
        themePreset: _themePreset,
        onThemeChanged: (preset) => setState(() => _themePreset = preset),
      ),
    );
  }
}

class PerformancePage extends StatefulWidget {
  const PerformancePage({
    super.key,
    required this.themePreset,
    required this.onThemeChanged,
  });

  final GridThemePreset themePreset;
  final ValueChanged<GridThemePreset> onThemeChanged;

  @override
  State<PerformancePage> createState() => _PerformancePageState();
}

class _PerformancePageState extends State<PerformancePage> {
  late final List<Map<String, dynamic>> _rowData;
  int _rowCount = 1000;
  String _quickFilter = '';
  final _controller = OsGridController<Map<String, dynamic>>();

  // Row Grouping & Pivot state
  bool _groupByCountry = false;
  bool _pivotMode = false;

  static const _countries = [
    'Ireland',
    'Spain',
    'United Kingdom',
    'France',
    'Germany',
    'Sweden',
    'Norway',
    'Italy',
    'Greece',
    'Iceland',
    'Portugal',
    'Malta',
    'Brazil',
    'Argentina',
    'Colombia',
    'Peru',
    'Venezuela',
    'Uruguay',
    'Belgium',
    'Luxembourg',
  ];
  static const _languages = [
    'English',
    'Spanish',
    'French',
    'Portuguese',
    'German',
    'Swedish',
    'Norwegian',
    'Italian',
    'Greek',
    'Icelandic',
  ];
  static const _games = [
    'Chess',
    'Backgammon',
    'Checkers',
    'Go',
    'Battleship',
    'Stratego',
    'Othello',
    'Hex',
    'Shogi',
    'Fanorona',
  ];
  static const _firstNames = [
    'Tony',
    'Andrew',
    'Kevin',
    'Sophie',
    'Isabelle',
    'Emily',
    'Olivia',
    'Lily',
    'Chloe',
    'Isabella',
    'Amelia',
    'Jessica',
    'Sophia',
    'Ava',
    'Charlotte',
    'Mia',
    'Lucy',
    'Grace',
    'Ruby',
    'Ella',
  ];
  static const _lastNames = [
    'Smith',
    'Connell',
    'Flanagan',
    'McGee',
    'Thornton',
    'Lopes',
    'Beckham',
    'Black',
    'Braxton',
    'Brennan',
    'Brock',
    'Bryson',
    'Cadwell',
    'Cage',
    'Carson',
    'Chandler',
    'Cohen',
    'Cole',
    'Corbin',
    'Dallas',
  ];
  static const _months = [
    'jan',
    'feb',
    'mar',
    'apr',
    'may',
    'jun',
    'jul',
    'aug',
    'sep',
    'oct',
    'nov',
    'dec',
  ];

  @override
  void initState() {
    super.initState();
    _rowData = _generateRows(100000);
  }

  List<Map<String, dynamic>> _generateRows(int count) {
    final rng = Random(42);
    final baseDate = DateTime(2020, 1, 1);
    return List.generate(count, (row) {
      final countryData = _countries[(row * 19) % _countries.length];
      final firstName = _firstNames[row % _firstNames.length];
      final lastName = _lastNames[row % _lastNames.length];
      final bankBalance = (rng.nextDouble() * 100000 - 3000).round();
      final rating = rng.nextInt(6);
      var totalWinnings = 0;
      final item = <String, dynamic>{
        'name': '$firstName $lastName',
        'country': countryData,
        'language': _languages[row % _languages.length],
        'game': _games[(row * 13 ~/ 17 * 19) % _games.length],
        'bankBalance': bankBalance,
        'rating': rating,
        'joinDate': baseDate.add(Duration(days: rng.nextInt(1800))),
      };
      for (final month in _months) {
        final value = (rng.nextDouble() * 100000 - 20).round();
        item[month] = value;
        totalWinnings += value;
      }
      item['totalWinnings'] = totalWinnings;
      return item;
    });
  }

  /// Pinned summary row showing totals.
  List<Map<String, dynamic>> get _pinnedBottomRows {
    final rows = _rowData.take(_rowCount).toList();
    if (rows.isEmpty) return [];
    final totals = <String, dynamic>{
      'name': 'TOTALS',
      'country': '',
      'language': '',
      'game': '',
      'bankBalance': 0,
      'rating': 0,
      'joinDate': null,
      'totalWinnings': 0,
    };
    for (final month in _months) {
      totals[month] = 0;
    }
    for (final row in rows) {
      totals['bankBalance'] =
          (totals['bankBalance'] as int) + (row['bankBalance'] as int);
      totals['totalWinnings'] =
          (totals['totalWinnings'] as int) + (row['totalWinnings'] as int);
      for (final month in _months) {
        totals[month] = (totals[month] as int) + (row[month] as int);
      }
    }
    return [totals];
  }

  String _formatCurrency(dynamic value) {
    if (value == null) return '';
    final v = value as int;
    final abs = v.abs();
    final formatted =
        '\$${abs.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
    return v < 0 ? '($formatted)' : formatted;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Performance Demo — $_rowCount rows'),
        actions: [
          DropdownButton<GridThemePreset>(
            value: widget.themePreset,
            underline: const SizedBox.shrink(),
            dropdownColor: Theme.of(context).colorScheme.surface,
            items: GridThemePreset.values.map((preset) {
              return DropdownMenuItem(
                value: preset,
                child: Text(preset.label, style: const TextStyle(fontSize: 13)),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) widget.onThemeChanged(value);
            },
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => setState(() => _rowCount = 100),
            child: const Text('100'),
          ),
          TextButton(
            onPressed: () => setState(() => _rowCount = 1000),
            child: const Text('1K'),
          ),
          TextButton(
            onPressed: () => setState(() => _rowCount = 10000),
            child: const Text('10K'),
          ),
          TextButton(
            onPressed: () => setState(() => _rowCount = 100000),
            child: const Text('100K'),
          ),
          const SizedBox(width: 8),
          // Row Grouping toggle
          FilterChip(
            label: const Text('Group'),
            selected: _groupByCountry,
            onSelected: (v) => setState(() => _groupByCountry = v),
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 4),
          // Pivot Mode toggle
          FilterChip(
            label: const Text('Pivot'),
            selected: _pivotMode,
            onSelected: (v) => setState(() => _pivotMode = v),
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 8),
          // Expand/Collapse All
          if (_groupByCountry) ...[
            IconButton(
              icon: const Icon(Icons.unfold_more, size: 20),
              tooltip: 'Expand All',
              onPressed: () => _controller.expandAll(),
            ),
            IconButton(
              icon: const Icon(Icons.unfold_less, size: 20),
              tooltip: 'Collapse All',
              onPressed: () => _controller.collapseAll(),
            ),
          ],
          TextButton(
            onPressed: () {
              final csv = _controller.exportCsv();
              debugPrint('CSV: ${csv.length} chars');
            },
            child: const Text('Export CSV'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Quick filter...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _quickFilter = v),
            ),
          ),
          Expanded(
            child: OsGrid(
              controller: _controller,
              getRowId: (data) => '${data['name']}_${data.hashCode}',
              columnDefs: [
                OsColumnGroup(
                  headerName: 'Participant',
                  children: [
                    OsColumnDef(
                      field: 'name',
                      headerName: 'Name',
                      width: 180,
                      sortable: true,
                      pinned: OsColumnPin.left,
                      filter: OsTextFilter(),
                      editable: true,
                      cellEditor: OsTextCellEditor(),
                    ),
                    OsColumnDef(
                      field: 'language',
                      headerName: 'Language',
                      width: 120,
                      sortable: true,
                      filter: OsTextFilter(),
                      editable: true,
                      cellEditor: OsSelectCellEditor(values: _languages),
                      // Pivot by language when pivot mode is on
                      pivot: _pivotMode ? true : null,
                    ),
                    OsColumnDef(
                      field: 'country',
                      headerName: 'Country',
                      width: 140,
                      sortable: true,
                      filter: OsTextFilter(),
                      // Group by country when grouping is enabled
                      rowGroup: _groupByCountry ? true : null,
                    ),
                    OsColumnDef(
                      field: 'joinDate',
                      headerName: 'Join Date',
                      width: 130,
                      sortable: true,
                      filter: OsDateFilter(),
                      valueFormatter: (params) {
                        if (params.value == null) return '';
                        final d = params.value as DateTime;
                        return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
                      },
                    ),
                  ],
                ),
                OsColumnGroup(
                  headerName: 'Game of Choice',
                  children: [
                    OsColumnDef(
                      field: 'game',
                      headerName: 'Game Name',
                      width: 160,
                      sortable: true,
                      filter: OsTextFilter(),
                      editable: true,
                      cellEditor: OsSelectCellEditor(values: _games),
                    ),
                  ],
                ),
                OsColumnGroup(
                  headerName: 'Performance',
                  children: [
                    OsColumnDef(
                      field: 'bankBalance',
                      headerName: 'Bank Balance',
                      width: 140,
                      sortable: true,
                      filter: OsNumberFilter(),
                      valueFormatter: (params) => _formatCurrency(params.value),
                      // Sum aggregate for group rows
                      aggFunc: _groupByCountry ? 'sum' : null,
                      cellStyle: (params) {
                        if (params.value == null) return const OsCellStyle();
                        final v = params.value as int;
                        if (v < 0) {
                          return OsCellStyle(color: Colors.red.shade300);
                        }
                        if (v > 50000) {
                          return OsCellStyle(color: Colors.green.shade300);
                        }
                        return const OsCellStyle();
                      },
                    ),
                  ],
                ),
                OsColumnDef(
                  field: 'rating',
                  headerName: 'Rating',
                  width: 100,
                  sortable: true,
                  builtInCellRenderer: OsBuiltInCellRenderer.starRating,
                  // Average rating in group rows
                  aggFunc: _groupByCountry ? 'avg' : null,
                ),
                OsColumnDef(
                  field: 'totalWinnings',
                  headerName: 'Total Winnings',
                  width: 150,
                  sortable: true,
                  filter: OsNumberFilter(),
                  valueFormatter: (params) => _formatCurrency(params.value),
                  // Sum aggregate for group rows
                  aggFunc: _groupByCountry ? 'sum' : null,
                  cellStyle: (params) {
                    if (params.value == null) return const OsCellStyle();
                    final v = params.value as int;
                    if (v < 0) {
                      return OsCellStyle(color: Colors.red.shade300);
                    }
                    if (v > 500000) {
                      return OsCellStyle(color: Colors.green.shade300);
                    }
                    return const OsCellStyle();
                  },
                ),
                OsColumnGroup(
                  headerName: 'Monthly Breakdown',
                  children: [
                    ..._months.map(
                      (m) => OsColumnDef(
                        field: m,
                        headerName: m.toUpperCase(),
                        width: 100,
                        sortable: true,
                        filter: OsNumberFilter(),
                        valueFormatter: (params) =>
                            _formatCurrency(params.value),
                        // Sum aggregate for group rows
                        aggFunc: _groupByCountry ? 'sum' : null,
                      ),
                    ),
                  ],
                ),
              ],
              rowData: _rowData.take(_rowCount).toList(),
              rowHeight: 36,
              headerHeight: 40,
              floatingFilter: true,
              rowNumbers: true,
              rowDrag: true,
              statusBar: true,
              quickFilterText: _quickFilter,
              // Row Grouping
              groupBy: _groupByCountry ? const ['country'] : null,
              groupDefaultExpanded: 0,
              // Pivot Mode
              pivotMode: _pivotMode,
              rowSelection: OsRowSelection.multiple(
                checkboxes: true,
                headerCheckbox: true,
              ),
              cellSelection: const OsCellSelection(suppressMultiRanges: false),
              undoRedoCellEditing: true,
              undoRedoCellEditingLimit: 20,
              initialSort: const [
                OsSortModel(colId: 'name', sort: OsSortDirection.ascending),
              ],
              pinnedBottomRowData: _groupByCountry ? null : _pinnedBottomRows,
              getRowStyle: (params) {
                final data = params.data;
                final balance = data['bankBalance'];
                if (balance is int && balance < -2000) {
                  return OsRowStyle(
                    backgroundColor: Colors.red.withValues(alpha: 0.05),
                  );
                }
                return null;
              },
              onRowGroupOpened: (event) {
                debugPrint(
                  'Group ${event.expanded ? "expanded" : "collapsed"}: '
                  '${event.groupKey} (${event.groupField})',
                );
              },
              onPivotModeChanged: (event) {
                debugPrint('Pivot mode: ${event.pivotMode}');
              },
              onRangeSelectionChanged: (event) {
                if (event.finished && event.ranges.isNotEmpty) {
                  final range = event.ranges.last;
                  debugPrint(
                    'Range selected: ${range.rowCount} rows × ${range.columnCount} cols',
                  );
                }
              },
              onSortChanged: (event) {
                debugPrint(
                  'Sort changed: ${event.sortModel.length} columns sorted',
                );
              },
              onFilterChanged: (event) {
                debugPrint('Filter changed: ${event.filterModel}');
              },
              onCellValueChanged: (event) {
                debugPrint(
                  'Cell edited: ${event.colDef.effectiveColId} = ${event.newValue}',
                );
              },
              pagination: OsPagination(
                pageSize: 100,
                showPageSizeSelector: true,
                pageSizeOptions: [50, 100, 500, 1000],
              ),
              theme: getThemeForPreset(widget.themePreset, context),
            ),
          ),
        ],
      ),
    );
  }
}
