import 'dart:async';
import 'dart:math';

import 'package:os_grid_flutter/os_grid_flutter.dart';
import 'package:flutter/material.dart';

import '../../theme_selector.dart';
import '../widgets/feature_panel.dart';

/// Demonstrates the infinite row model (lazy loading) with a simulated
/// datasource that generates 10,000+ rows on demand with configurable delay.
class InfiniteRowModelPage extends StatefulWidget {
  const InfiniteRowModelPage({
    super.key,
    required this.themePreset,
    this.onThemeChanged,
  });

  final GridThemePreset themePreset;
  final ValueChanged<GridThemePreset>? onThemeChanged;

  @override
  State<InfiniteRowModelPage> createState() => _InfiniteRowModelPageState();
}

class _InfiniteRowModelPageState extends State<InfiniteRowModelPage> {
  final _controller = OsGridController<Map<String, dynamic>>();

  int _blockSize = 100;
  int _networkDelayMs = 500;
  int _loadedBlockCount = 0;
  int _virtualRowCount = 0;

  late _SimulatedDatasource _datasource;
  StreamSubscription<OsInfiniteRowCountChangedEvent>? _rowCountSub;

  static const int _totalRows = 10000;

  @override
  void initState() {
    super.initState();
    _datasource = _SimulatedDatasource(
      totalRows: _totalRows,
      delayMs: _networkDelayMs,
    );
    _rowCountSub = _controller.onInfiniteRowCountChanged.listen((event) {
      if (mounted) {
        setState(() {
          _virtualRowCount = event.rowCount;
        });
      }
    });
  }

  @override
  void dispose() {
    _rowCountSub?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _rebuildDatasource() {
    _datasource = _SimulatedDatasource(
      totalRows: _totalRows,
      delayMs: _networkDelayMs,
    );
    _loadedBlockCount = 0;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = getThemeForPreset(widget.themePreset, context);

    return Column(
      children: [
        FeaturePanel(
          title: 'Infinite Row Model Controls',
          children: [
            _buildBlockSizeControl(),
            _buildDelayControl(),
            const SizedBox(width: 16),
            FilledButton.tonalIcon(
              onPressed: () {
                _controller.refreshInfiniteCache();
                setState(() => _loadedBlockCount = 0);
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh Cache'),
            ),
            FilledButton.tonalIcon(
              onPressed: () {
                _controller.purgeInfiniteCache();
                setState(() => _loadedBlockCount = 0);
              },
              icon: const Icon(Icons.delete_sweep),
              label: const Text('Purge Cache'),
            ),
          ],
        ),
        _buildStatusArea(),
        Expanded(
          child: OsGrid<Map<String, dynamic>>(
            controller: _controller,
            theme: theme,
            infiniteRowModel: OsInfiniteRowModel(
              cacheBlockSize: _blockSize,
              infiniteInitialRowCount: _blockSize,
            ),
            datasource: _datasource,
            onInfiniteRowCountChanged: (event) {
              setState(() {
                _virtualRowCount = event.rowCount;
                _loadedBlockCount = _datasource.successfulRequests;
              });
            },
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
        width: 80,
      ),
      OsColumnDef<Map<String, dynamic>>(
        field: 'name',
        headerName: 'Name',
        flex: 2,
      ),
      OsColumnDef<Map<String, dynamic>>(
        field: 'email',
        headerName: 'Email',
        flex: 2,
      ),
      OsColumnDef<Map<String, dynamic>>(
        field: 'age',
        headerName: 'Age',
        width: 80,
      ),
      OsColumnDef<Map<String, dynamic>>(
        field: 'salary',
        headerName: 'Salary',
        width: 120,
      ),
      OsColumnDef<Map<String, dynamic>>(
        field: 'department',
        headerName: 'Department',
        width: 140,
      ),
      OsColumnDef<Map<String, dynamic>>(
        field: 'country',
        headerName: 'Country',
        width: 140,
      ),
    ];
  }

  Widget _buildBlockSizeControl() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Block Size:'),
        const SizedBox(width: 8),
        SizedBox(
          width: 200,
          child: Slider(
            value: _blockSize.toDouble(),
            min: 10,
            max: 500,
            divisions: 49,
            label: '$_blockSize',
            onChanged: (value) {
              setState(() => _blockSize = value.round());
            },
            onChangeEnd: (_) => _rebuildDatasource(),
          ),
        ),
        SizedBox(width: 40, child: Text('$_blockSize')),
      ],
    );
  }

  Widget _buildDelayControl() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Network Delay (ms):'),
        const SizedBox(width: 8),
        SizedBox(
          width: 200,
          child: Slider(
            value: _networkDelayMs.toDouble(),
            min: 0,
            max: 5000,
            divisions: 50,
            label: '${_networkDelayMs}ms',
            onChanged: (value) {
              setState(() => _networkDelayMs = value.round());
            },
            onChangeEnd: (_) {
              _datasource.delayMs = _networkDelayMs;
            },
          ),
        ),
        SizedBox(width: 60, child: Text('${_networkDelayMs}ms')),
      ],
    );
  }

  Widget _buildStatusArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 16),
          const SizedBox(width: 8),
          Text(
            'Loaded Blocks: $_loadedBlockCount',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(width: 24),
          Text(
            'Virtual Row Count: $_virtualRowCount',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(width: 24),
          Text(
            'Total Dataset: $_totalRows rows',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Simulated datasource
// ---------------------------------------------------------------------------

/// Names and data pools for on-the-fly row generation.
const _firstNames = [
  'Alice',
  'Bob',
  'Charlie',
  'Diana',
  'Edward',
  'Fiona',
  'George',
  'Hannah',
  'Ivan',
  'Julia',
  'Kevin',
  'Laura',
  'Michael',
  'Nina',
  'Oscar',
  'Patricia',
  'Quentin',
  'Rachel',
  'Samuel',
  'Tina',
];

const _lastNames = [
  'Anderson',
  'Brown',
  'Clark',
  'Davis',
  'Evans',
  'Foster',
  'Garcia',
  'Harris',
  'Irwin',
  'Johnson',
  'King',
  'Lee',
  'Martinez',
  'Nelson',
  'Owen',
  'Patel',
  'Quinn',
  'Roberts',
  'Smith',
  'Taylor',
];

const _departments = ['Engineering', 'Sales', 'Marketing', 'HR', 'Finance'];

const _countries = [
  'United States',
  'United Kingdom',
  'Germany',
  'France',
  'Canada',
  'Australia',
  'Japan',
  'Brazil',
  'India',
  'Spain',
];

/// A simulated datasource that generates rows on-the-fly with an artificial
/// delay to demonstrate loading states in the infinite row model.
class _SimulatedDatasource extends OsInfiniteDatasource<Map<String, dynamic>> {
  _SimulatedDatasource({required this.totalRows, required this.delayMs});

  final int totalRows;
  int delayMs;

  /// Tracks how many successful block loads have completed.
  int successfulRequests = 0;

  @override
  void getRows(OsInfiniteGetRowsParams<Map<String, dynamic>> params) async {
    // Simulate network latency.
    if (delayMs > 0) {
      await Future<void>.delayed(Duration(milliseconds: delayMs));
    }

    // Generate rows on-the-fly using a seed derived from the start row
    // for reproducibility within the same block.
    final rows = <Map<String, dynamic>>[];
    final end = params.endRow.clamp(0, totalRows);
    for (int i = params.startRow; i < end; i++) {
      rows.add(_generateRow(i));
    }

    final lastRow = end >= totalRows ? totalRows : null;
    successfulRequests++;
    params.successCallback(rows, lastRow: lastRow);
  }

  /// Generates a single row deterministically based on the row index.
  Map<String, dynamic> _generateRow(int index) {
    final rng = Random(index);
    final firstName = _firstNames[rng.nextInt(_firstNames.length)];
    final lastName = _lastNames[rng.nextInt(_lastNames.length)];
    return {
      'id': index,
      'name': '$firstName $lastName',
      'email':
          '${firstName.toLowerCase()}.${lastName.toLowerCase()}@example.com',
      'age': 18 + rng.nextInt(48),
      'salary': 30000 + rng.nextInt(120001),
      'department': _departments[rng.nextInt(_departments.length)],
      'country': _countries[rng.nextInt(_countries.length)],
    };
  }
}
