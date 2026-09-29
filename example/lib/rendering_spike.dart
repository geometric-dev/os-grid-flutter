/// Rendering spike: 100,000 rows with virtualised scrolling.
///
/// Run with: `flutter run -d windows` (or macos/linux) from the example/ directory.
///
/// This validates that the custom RenderObject approach can handle large
/// datasets at 60fps. The grid paints cells directly on the canvas —
/// no widget tree per cell.
library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

void main() => runApp(const RenderingSpikeApp());

class RenderingSpikeApp extends StatelessWidget {
  const RenderingSpikeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OS Grid Flutter — Rendering Spike',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const SpikePage(),
    );
  }
}

class SpikePage extends StatefulWidget {
  const SpikePage({super.key});

  @override
  State<SpikePage> createState() => _SpikePageState();
}

class _SpikePageState extends State<SpikePage> {
  static const int _rowCount = 100000;

  late final List<Map<String, dynamic>> _rowData;
  int _currentRowCount = _rowCount;
  String _quickFilter = '';
  final _gridController = OsGridController<Map<String, dynamic>>();

  final _countries = [
    'United States',
    'United Kingdom',
    'Germany',
    'France',
    'Australia',
    'Japan',
    'Canada',
    'Brazil',
    'India',
    'South Korea',
    'Italy',
    'Spain',
    'Netherlands',
    'Sweden',
    'Norway',
    'Denmark',
    'Finland',
    'Switzerland',
    'Austria',
    'Belgium',
  ];

  final _sports = [
    'Swimming',
    'Athletics',
    'Cycling',
    'Gymnastics',
    'Rowing',
    'Tennis',
    'Boxing',
    'Fencing',
    'Diving',
    'Weightlifting',
    'Archery',
    'Shooting',
    'Sailing',
    'Judo',
    'Wrestling',
  ];

  final _firstNames = [
    'James',
    'Emma',
    'Oliver',
    'Sophia',
    'William',
    'Ava',
    'Benjamin',
    'Isabella',
    'Lucas',
    'Mia',
    'Henry',
    'Charlotte',
    'Alexander',
    'Amelia',
    'Daniel',
    'Harper',
    'Matthew',
    'Evelyn',
    'Joseph',
    'Abigail',
  ];

  final _lastNames = [
    'Smith',
    'Johnson',
    'Williams',
    'Brown',
    'Jones',
    'Garcia',
    'Miller',
    'Davis',
    'Rodriguez',
    'Martinez',
    'Hernandez',
    'Lopez',
    'Gonzalez',
    'Wilson',
    'Anderson',
    'Thomas',
    'Taylor',
    'Moore',
    'Jackson',
    'Martin',
  ];

  @override
  void initState() {
    super.initState();
    _rowData = _generateRows(_rowCount);
  }

  List<Map<String, dynamic>> _generateRows(int count) {
    final rng = Random(42); // Fixed seed for reproducibility
    return List.generate(count, (i) {
      final gold = rng.nextInt(10);
      final silver = rng.nextInt(8);
      final bronze = rng.nextInt(12);
      return {
        'id': i + 1,
        'name':
            '${_firstNames[rng.nextInt(_firstNames.length)]} ${_lastNames[rng.nextInt(_lastNames.length)]}',
        'age': 18 + rng.nextInt(25),
        'country': _countries[rng.nextInt(_countries.length)],
        'sport': _sports[rng.nextInt(_sports.length)],
        'year': 2000 + rng.nextInt(24),
        'gold': gold,
        'silver': silver,
        'bronze': bronze,
        'total': gold + silver + bronze,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Rendering Spike — $_currentRowCount rows'),
        actions: [
          // Row count controls for benchmarking
          TextButton(
            onPressed: () => setState(() {
              _currentRowCount = 1000;
            }),
            child: const Text('1K'),
          ),
          TextButton(
            onPressed: () => setState(() {
              _currentRowCount = 10000;
            }),
            child: const Text('10K'),
          ),
          TextButton(
            onPressed: () => setState(() {
              _currentRowCount = 100000;
            }),
            child: const Text('100K'),
          ),
          TextButton(
            onPressed: () {
              final csv = _gridController.exportCsv();
              debugPrint('CSV exported (${csv.length} chars)');
              debugPrint(csv.substring(0, csv.length.clamp(0, 500)));
            },
            child: const Text('CSV'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Quick filter...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 12,
                ),
              ),
              onChanged: (value) => setState(() => _quickFilter = value),
            ),
          ),
          Expanded(
            child: OsGrid(
              columnDefs: [
                OsColumnDef(
                  field: 'id',
                  headerName: 'ID',
                  width: 80,
                  sortable: true,
                  pinned: OsColumnPin.left,
                ),
                OsColumnDef(
                  field: 'name',
                  headerName: 'Athlete',
                  width: 200,
                  sortable: true,
                  editable: true,
                ),
                OsColumnDef(
                  field: 'age',
                  headerName: 'Age',
                  width: 90,
                  sortable: true,
                  editable: true,
                ),
                OsColumnDef(
                  field: 'country',
                  headerName: 'Country',
                  width: 180,
                  sortable: true,
                  editable: true,
                ),
                OsColumnDef(
                  field: 'sport',
                  headerName: 'Sport',
                  width: 160,
                  sortable: true,
                ),
                OsColumnDef(
                  field: 'year',
                  headerName: 'Year',
                  width: 100,
                  sortable: true,
                ),
                OsColumnDef(
                  field: 'gold',
                  headerName: 'Gold',
                  width: 90,
                  sortable: true,
                  editable: true,
                ),
                OsColumnDef(
                  field: 'silver',
                  headerName: 'Silver',
                  width: 90,
                  sortable: true,
                  editable: true,
                ),
                OsColumnDef(
                  field: 'bronze',
                  headerName: 'Bronze',
                  width: 90,
                  sortable: true,
                  editable: true,
                ),
                OsColumnDef(
                  field: 'total',
                  headerName: 'Total',
                  width: 90,
                  sortable: true,
                  pinned: OsColumnPin.right,
                ),
              ],
              rowData: _rowData.take(_currentRowCount).toList(),
              rowHeight: 36,
              headerHeight: 44,
              controller: _gridController,
              rowSelection: OsRowSelection.multiple(),
              quickFilterText: _quickFilter,
              pagination: OsPagination(
                pageSize: 100,
                showPageSizeSelector: true,
                pageSizeOptions: [25, 50, 100, 500],
              ),
              theme: OsGridTheme.fromThemeData(Theme.of(context)),
              onCellClicked: (event) {
                debugPrint(
                  'Clicked row ${event.rowIndex}, col ${event.colDef.field}: ${event.value}',
                );
              },
              onSelectionChanged: (event) {
                debugPrint('Selection: ${event.selectedRows.length} rows');
              },
            ),
          ),
        ],
      ),
    );
  }
}
