import 'package:flutter/material.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

import 'demos/community_features/community_features_demo.dart';
import 'demos/finance_demo.dart';
import 'demos/hr_demo.dart';
import 'demos/inventory_demo.dart';
import 'demos/performance_demo.dart';
import 'rendering_spike.dart';

void main() => runApp(const DemoLauncherApp());

/// Entry point hosting a launcher for every bundled demo app.
///
/// Each demo remains runnable standalone via
/// `flutter run -t lib/<path>.dart`; the launcher makes them discoverable
/// from the default `flutter run` inside example/.
class DemoLauncherApp extends StatelessWidget {
  const DemoLauncherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OS Grid Flutter Demos',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const _LauncherHome(),
    );
  }
}

class _LauncherEntry {
  const _LauncherEntry({
    required this.title,
    required this.description,
    required this.icon,
    required this.builder,
  });

  final String title;
  final String description;
  final IconData icon;
  final WidgetBuilder builder;
}

final _launcherEntries = <_LauncherEntry>[
  _LauncherEntry(
    title: 'Community Features',
    description:
        '16 pages covering filtering, editing, selection, grouping, '
        'side bar, overlays, clipboard, theming and more',
    icon: Icons.apps,
    builder: (_) => const CommunityFeaturesDemoApp(),
  ),
  _LauncherEntry(
    title: 'Basics',
    description: 'Olympics grid — quick filter, selection, pagination',
    icon: Icons.grid_on,
    builder: _basicsBuilder,
  ),
  _LauncherEntry(
    title: 'Performance',
    description: '100k+ rows, grouping, pivot mode, range selection',
    icon: Icons.speed,
    builder: (_) => const PerformanceDemoApp(),
  ),
  _LauncherEntry(
    title: 'Finance',
    description: 'Live quote grid with animated cell renderers',
    icon: Icons.candlestick_chart,
    builder: (_) => const FinanceDemoApp(),
  ),
  _LauncherEntry(
    title: 'HR',
    description: 'Employee directory with avatar and progress-bar renderers',
    icon: Icons.badge,
    builder: (_) => const HrDemoApp(),
  ),
  _LauncherEntry(
    title: 'Inventory',
    description: 'Stock dashboard with image cells and context styling',
    icon: Icons.inventory_2,
    builder: (_) => const InventoryDemoApp(),
  ),
  _LauncherEntry(
    title: 'Rendering Spike',
    description: 'Canvas rendering experiments and stress scenarios',
    icon: Icons.brush,
    builder: (_) => const RenderingSpikeApp(),
  ),
];

Widget _basicsBuilder(BuildContext context) => const GridDemoPage();

class _LauncherHome extends StatelessWidget {
  const _LauncherHome();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('OS Grid Flutter Demos')),
      body: ListView(
        children: [
          for (final entry in _launcherEntries)
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: ListTile(
                leading: Icon(entry.icon, size: 32),
                title: Text(
                  entry.title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(entry.description),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: entry.builder),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The original standalone demo grid (quick filter + selection +
/// pagination over an Olympics dataset).
class GridDemoPage extends StatefulWidget {
  const GridDemoPage({super.key});

  @override
  State<GridDemoPage> createState() => _GridDemoPageState();
}

class _GridDemoPageState extends State<GridDemoPage> {
  final _controller = OsGridController<Map<String, dynamic>>();
  String _quickFilter = '';

  static final _columnDefs = <OsColumnDefBase>[
    OsColumnDef(
      field: 'name',
      headerName: 'Athlete',
      sortable: true,
      filter: OsTextFilter(),
      pinned: OsColumnPin.left,
    ),
    OsColumnDef(
      field: 'age',
      headerName: 'Age',
      width: 90,
      sortable: true,
      filter: OsNumberFilter(),
    ),
    OsColumnDef(
      field: 'country',
      headerName: 'Country',
      sortable: true,
      filter: OsTextFilter(),
    ),
    OsColumnDef(
      field: 'sport',
      headerName: 'Sport',
      sortable: true,
      filter: OsTextFilter(),
    ),
    OsColumnDef(field: 'gold', headerName: 'Gold', width: 80, sortable: true),
    OsColumnDef(
      field: 'silver',
      headerName: 'Silver',
      width: 80,
      sortable: true,
    ),
    OsColumnDef(
      field: 'bronze',
      headerName: 'Bronze',
      width: 80,
      sortable: true,
    ),
    OsColumnDef(field: 'total', headerName: 'Total', width: 80, sortable: true),
  ];

  static final _rowData = <Map<String, dynamic>>[
    {
      'name': 'Michael Phelps',
      'age': 23,
      'country': 'United States',
      'sport': 'Swimming',
      'gold': 8,
      'silver': 0,
      'bronze': 0,
      'total': 8,
    },
    {
      'name': 'Usain Bolt',
      'age': 22,
      'country': 'Jamaica',
      'sport': 'Athletics',
      'gold': 3,
      'silver': 0,
      'bronze': 0,
      'total': 3,
    },
    {
      'name': 'Natalie Coughlin',
      'age': 25,
      'country': 'United States',
      'sport': 'Swimming',
      'gold': 1,
      'silver': 2,
      'bronze': 3,
      'total': 6,
    },
    {
      'name': 'Stephanie Rice',
      'age': 20,
      'country': 'Australia',
      'sport': 'Swimming',
      'gold': 3,
      'silver': 0,
      'bronze': 0,
      'total': 3,
    },
    {
      'name': 'Chris Hoy',
      'age': 32,
      'country': 'Great Britain',
      'sport': 'Cycling',
      'gold': 3,
      'silver': 0,
      'bronze': 0,
      'total': 3,
    },
    {
      'name': 'Rebecca Adlington',
      'age': 19,
      'country': 'Great Britain',
      'sport': 'Swimming',
      'gold': 2,
      'silver': 0,
      'bronze': 0,
      'total': 2,
    },
    {
      'name': 'Kenenisa Bekele',
      'age': 26,
      'country': 'Ethiopia',
      'sport': 'Athletics',
      'gold': 2,
      'silver': 0,
      'bronze': 0,
      'total': 2,
    },
    {
      'name': 'Britta Steffen',
      'age': 24,
      'country': 'Germany',
      'sport': 'Swimming',
      'gold': 2,
      'silver': 0,
      'bronze': 0,
      'total': 2,
    },
    {
      'name': 'Shelly-Ann Fraser',
      'age': 21,
      'country': 'Jamaica',
      'sport': 'Athletics',
      'gold': 1,
      'silver': 0,
      'bronze': 0,
      'total': 1,
    },
    {
      'name': 'Leisel Jones',
      'age': 22,
      'country': 'Australia',
      'sport': 'Swimming',
      'gold': 1,
      'silver': 1,
      'bronze': 1,
      'total': 3,
    },
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OS Grid Flutter Demo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.select_all),
            tooltip: 'Select All',
            onPressed: () => _controller.selectAll(),
          ),
          IconButton(
            icon: const Icon(Icons.deselect),
            tooltip: 'Deselect All',
            onPressed: () => _controller.deselectAll(),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Quick filter...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (value) => setState(() => _quickFilter = value),
            ),
          ),
          Expanded(
            child: OsGrid(
              controller: _controller,
              columnDefs: _columnDefs,
              rowData: _rowData,
              quickFilterText: _quickFilter,
              rowSelection: OsRowSelection.multiple(
                checkboxes: true,
                headerCheckbox: true,
              ),
              pagination: const OsPagination(pageSize: 50),
              theme: OsGridTheme.fromThemeData(Theme.of(context)),
              onGridReady: (_) => debugPrint('Grid ready!'),
              onSelectionChanged: (event) {
                debugPrint('Selected ${event.selectedRows.length} rows');
              },
            ),
          ),
        ],
      ),
    );
  }
}
