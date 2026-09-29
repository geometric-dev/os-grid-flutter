import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

/// Frame-time profiling harness + budget regression gate.
///
/// SKIPPED BY DEFAULT. Run explicitly when you want the benchmark:
///
/// ```bash
/// # POSIX
/// OS_GRID_BENCH=1 flutter test test/bench_frame_budget_test.dart
/// ```
///
/// ```powershell
/// # Windows PowerShell
/// $env:OS_GRID_BENCH = '1'; flutter test test/bench_frame_budget_test.dart
/// ```
///
/// Scenarios (each pumps scripted interactions against a generated dataset
/// and records wall-clock samples around each layout+paint pump):
///
/// | scenario          | dataset | load                                   |
/// |-------------------|---------|----------------------------------------|
/// | scroll            | 100k    | 120 frames of vertical drag scrolling  |
/// | cold-start        | 100k    | first frame after setRowData (3 runs)  |
/// | edit-burst        | 10k     | 50 sequential open/type/commit edits   |
/// | transaction-storm | 50k     | 20 add/remove/update transaction rounds|
/// | filter-typing     | 100k    | 20 rapid quick-filter text changes     |
/// | column-resize     | 10k     | 30 resize drag gestures (20 columns)   |
///
/// Node profiling (quality program v3 item 27): every gated scenario also
/// reports `nodeRebuilds` (controller node-layer rebuilds performed during
/// the scenario) and `nodePoolSize` (row nodes retained at the end) in the
/// JSON report, sourced from `nodeRebuildCount`/`nodePoolSize` on the
/// controller.
///
/// Informational scenarios (quality program v3 item 30) — recorded in the
/// report with NO budget and NO pass/fail gate, trend data only:
///
/// | scenario          | dataset | metric                                  |
/// |-------------------|---------|-----------------------------------------|
/// | memory-100k       | 100k    | process RSS delta while grid is mounted |
/// | startup-10k       | 10k     | pumpWidget → first frame wall time      |
///
/// Output: a JSON report (one `{scenario, mean, p50, p95, budget, pass}`
/// entry per scenario, plus an `informational` array for the ungated
/// scenarios) is printed to stdout, and written to the file path in
/// `OS_GRID_BENCH_OUTPUT` when that env var is set:
///
/// ```powershell
/// $env:OS_GRID_BENCH = '1'
/// $env:OS_GRID_BENCH_OUTPUT = 'bench_results.json'
/// flutter test test/bench_frame_budget_test.dart
/// ```
///
/// Regression detection: if `test/bench_baseline.json` is present, each
/// scenario's p95 is compared against the committed baseline. A p95 more
/// than 20% above baseline prints a WARNING but does NOT fail the run —
/// budgets are the hard gate, baselines are the surfaced trend.
///
/// Budgets are regression tripwires measured in the widget-test renderer,
/// not absolute performance claims — GPU-composited release builds are far
/// faster.
void main() {
  final enabled = Platform.environment['OS_GRID_BENCH'] == '1';
  _loadBaseline();

  // Quality program v3 item 27: retention contract smoke test — always
  // runs (the bench scenarios below are skip-gated on OS_GRID_BENCH=1).
  test('node retention: setRowData with new data drops old nodes', () {
    final controller = OsGridController<Map<String, Object>>();
    controller.getRowId = (row) => 'id-${row['id']}';

    controller.setRowData([
      for (var i = 0; i < 50; i++) {'id': i, 'name': 'Row $i'},
    ]);
    expect(controller.nodePoolSize, 50);
    expect(controller.getNode('id-0'), isNotNull);

    // Completely new dataset: every old ID disappears, so every old node
    // is dropped from the pool in the same rebuild pass and becomes
    // GC-eligible. nodePoolSize must reflect only the new dataset.
    controller.setRowData([
      for (var i = 100; i < 175; i++) {'id': i, 'name': 'New row $i'},
    ]);

    expect(controller.nodePoolSize, 75);
    expect(controller.getNode('id-0'), isNull);
    expect(controller.getNode('id-49'), isNull);
    expect(controller.getNode('id-100'), isNotNull);

    // Profiling counter: exactly one rebuild per setRowData call.
    expect(controller.nodeRebuildCount, 2);
  });

  testWidgets('frame budget p95 under scroll for 100k rows', (tester) async {
    if (!enabled) {
      _log('bench scroll: skipped (set OS_GRID_BENCH=1 to run the gate)');
      return;
    }

    await _runScrollBench(tester);
  }, timeout: const Timeout(Duration(minutes: 10)));

  testWidgets('cold-start first frame after setRowData of 100k rows', (
    tester,
  ) async {
    if (!enabled) {
      _log('bench cold-start: skipped (set OS_GRID_BENCH=1 to run the gate)');
      return;
    }

    await _runColdStartBench(tester);
  }, timeout: const Timeout(Duration(minutes: 10)));

  testWidgets('edit burst: 50 sequential cell edits on 10k rows', (
    tester,
  ) async {
    if (!enabled) {
      _log('bench edit-burst: skipped (set OS_GRID_BENCH=1 to run the gate)');
      return;
    }

    await _runEditBurstBench(tester);
  }, timeout: const Timeout(Duration(minutes: 10)));

  testWidgets('transaction storm: 20 add/remove/update rounds on 50k rows', (
    tester,
  ) async {
    if (!enabled) {
      _log(
        'bench transaction-storm: skipped '
        '(set OS_GRID_BENCH=1 to run the gate)',
      );
      return;
    }

    await _runTransactionStormBench(tester);
  }, timeout: const Timeout(Duration(minutes: 10)));

  testWidgets('filter typing: 20 rapid quick-filter changes on 100k rows', (
    tester,
  ) async {
    if (!enabled) {
      _log(
        'bench filter-typing: skipped (set OS_GRID_BENCH=1 to run the gate)',
      );
      return;
    }

    await _runFilterTypingBench(tester);
  }, timeout: const Timeout(Duration(minutes: 10)));

  testWidgets('column resize: 30 resize gestures on a 20-column grid', (
    tester,
  ) async {
    if (!enabled) {
      _log(
        'bench column-resize: skipped (set OS_GRID_BENCH=1 to run the gate)',
      );
      return;
    }

    await _runColumnResizeBench(tester);
  }, timeout: const Timeout(Duration(minutes: 10)));

  testWidgets(
    'memory: RSS delta while a 100k-row grid is mounted (informational)',
    (tester) async {
      if (!enabled) {
        _log('bench memory-100k: skipped (set OS_GRID_BENCH=1 to run)');
        return;
      }

      await _runMemoryBench(tester);
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );

  testWidgets(
    'startup: pumpWidget to first frame for a 10k-row grid (informational)',
    (tester) async {
      if (!enabled) {
        _log('bench startup-10k: skipped (set OS_GRID_BENCH=1 to run)');
        return;
      }

      await _runStartupBench(tester);
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );

  tearDownAll(() {
    if (!_enabledReportPending()) return;
    _writeReport();
  });
}

// ---------------------------------------------------------------------------
// Harness constants
// ---------------------------------------------------------------------------

const int _scrollRowCount = 100000;
const int _scrollFrames = 120;
const int _scrollBounceEvery = 20;
const double _scrollBudgetMs = 120;

const int _coldStartRuns = 3;
const double _coldStartBudgetMs = 500;

const int _editBurstRowCount = 10000;
const int _editBurstEdits = 50;
const double _editBurstBudgetMs = 750;

const int _stormRowCount = 50000;
const int _stormRounds = 20;
const int _stormBatchSize = 100;
const double _stormBudgetMs = 4000;

const int _filterRowCount = 100000;
const int _filterChanges = 20;
const double _filterBudgetMs = 1500;

const int _resizeRowCount = 10000;
const int _resizeGestures = 30;
const int _resizeColumnCount = 20;
const double _resizeColumnWidth = 130;
const double _resizeDelta = 24;
const double _resizeBudgetMs = 50;

// Informational (no gate) scenarios — quality program v3 item 30.
const int _memoryRowCount = 100000;
const int _startupRowCount = 10000;
const int _startupRuns = 3;

/// p95 may exceed the committed baseline by at most this factor before a
/// regression WARNING is printed (warn-only — never fails the run).
const double _baselineRegressionFactor = 1.20;

/// Percentage form of [_baselineRegressionFactor], used only in messaging.
final int _baselineRegressionPct = ((_baselineRegressionFactor - 1) * 100)
    .round();

// ---------------------------------------------------------------------------
// Harness state: recorded results + committed baseline
// ---------------------------------------------------------------------------

final List<_ScenarioResult> _results = <_ScenarioResult>[];

/// Informational (ungated) scenario results — memory/startup trend data.
final List<_InfoResult> _infoResults = <_InfoResult>[];

Map<String, dynamic>? _baseline;

/// Whether any scenario ran (OS_GRID_BENCH=1) and a report should be emitted.
bool _enabledReportPending() => _results.isNotEmpty || _infoResults.isNotEmpty;

void _loadBaseline() {
  try {
    final file = File('test/bench_baseline.json');
    if (!file.existsSync()) return;
    final decoded = jsonDecode(file.readAsStringSync());
    if (decoded is Map<String, dynamic>) {
      _baseline = decoded;
    } else {
      _baseline = null;
    }
  } on FormatException {
    // An unparsable baseline is ignored; regression detection is optional.
    _baseline = null;
  }
}

double? _baselineP95(String scenario) {
  final scenarios = _baseline?['scenarios'];
  if (scenarios is! Map<String, dynamic>) return null;
  final entry = scenarios[scenario];
  if (entry is! Map<String, dynamic>) return null;
  final p95 = entry['p95'];
  if (p95 is num) return p95.toDouble();
  return null;
}

/// Committed informational baseline for a `{scenario, metric}` pair, or
/// null when absent. Informational values are trend data only — there is
/// deliberately no warning threshold and no failure path.
double? _baselineInfoValue(String scenario, String metric) {
  final informational = _baseline?['informational'];
  if (informational is! Map<String, dynamic>) return null;
  final entry = informational[scenario];
  if (entry is! Map<String, dynamic>) return null;
  final value = entry[metric];
  if (value is num) return value.toDouble();
  return null;
}

/// Records an informational (ungated) scenario metric, prints the summary
/// line, and surfaces the committed baseline delta when present.
void _recordInformational({
  required String scenario,
  required String metric,
  required double value,
  required String unit,
}) {
  _infoResults.add(
    _InfoResult(scenario: scenario, metric: metric, value: value, unit: unit),
  );

  final baseline = _baselineInfoValue(scenario, metric);
  final baselineText = baseline == null
      ? 'no committed baseline'
      : 'committed baseline ${_round2(baseline)} $unit, '
            'delta ${_round2(value - baseline)} $unit '
            '(${((value / baseline - 1) * 100).toStringAsFixed(1)}%)';
  _log(
    '--- info $scenario ($metric) ---\n'
    '${_round2(value)} $unit | $baselineText (trend data — no gate)',
  );
}

/// Records a scenario's samples, prints the summary line, surfaces a baseline
/// regression WARNING if applicable, and asserts the hard budget.
///
/// [nodeRebuilds] and [nodePoolSize] are the controller's node-layer
/// profiling counters captured around the scenario (item 27) and are
/// propagated into the JSON report when provided.
void _recordAndAssert({
  required String scenario,
  required List<double> samples,
  required double budget,
  bool passOnMean = false,
  int? nodeRebuilds,
  int? nodePoolSize,
}) {
  final sorted = List.of(samples)..sort();
  final mean = samples.reduce((a, b) => a + b) / samples.length;
  final p50 = _percentile(sorted, 0.50);
  final p95 = _percentile(sorted, 0.95);
  final metric = passOnMean ? mean : p95;
  final pass = metric < budget;

  _results.add(
    _ScenarioResult(
      scenario: scenario,
      mean: mean,
      p50: p50,
      p95: p95,
      budget: budget,
      pass: pass,
      nodeRebuilds: nodeRebuilds,
      nodePoolSize: nodePoolSize,
    ),
  );

  _log(
    '--- bench $scenario (samples=${samples.length}) ---\n'
    'mean ${mean.toStringAsFixed(2)} ms | '
    'p50 ${p50.toStringAsFixed(2)} ms | '
    'p95 ${p95.toStringAsFixed(2)} ms | '
    'budget $budget ms | ${pass ? 'PASS' : 'FAIL'}'
    '${nodeRebuilds == null ? '' : ' | nodeRebuilds $nodeRebuilds'}'
    '${nodePoolSize == null ? '' : ' | nodePoolSize $nodePoolSize'}',
  );

  final baseline = _baselineP95(scenario);
  if (baseline != null && p95 > baseline * _baselineRegressionFactor) {
    final pctOver = ((p95 / baseline - 1) * 100).toStringAsFixed(1);
    _log(
      'WARNING: "$scenario" p95 ${p95.toStringAsFixed(2)} ms is $pctOver% '
      'above the committed baseline ${baseline.toStringAsFixed(2)} ms '
      '(warning threshold $_baselineRegressionPct%) — possible performance '
      'regression. This does not fail the run.',
    );
  }

  expect(
    metric,
    lessThan(budget),
    reason: '$scenario exceeded its regression budget',
  );
}

void _writeReport() {
  final report = <String, Object>{
    'scenarios': <Object>[
      for (final r in _results)
        <String, Object>{
          'scenario': r.scenario,
          'mean': _round2(r.mean),
          'p50': _round2(r.p50),
          'p95': _round2(r.p95),
          'budget': r.budget,
          'pass': r.pass,
          if (r.nodeRebuilds != null) 'nodeRebuilds': r.nodeRebuilds!,
          if (r.nodePoolSize != null) 'nodePoolSize': r.nodePoolSize!,
        },
    ],
    if (_infoResults.isNotEmpty)
      'informational': <Object>[
        for (final r in _infoResults)
          <String, Object>{
            'scenario': r.scenario,
            'metric': r.metric,
            'value': _round2(r.value),
            'unit': r.unit,
          },
      ],
  };

  final json = const JsonEncoder.withIndent('  ').convert(report);
  _log('--- bench report (bench_results.json) ---\n$json');

  final outputPath = Platform.environment['OS_GRID_BENCH_OUTPUT'];
  if (outputPath != null && outputPath.isNotEmpty) {
    File(outputPath).writeAsStringSync('$json\n');
    _log('bench report written to $outputPath');
  }
}

// ---------------------------------------------------------------------------
// Stats helpers
// ---------------------------------------------------------------------------

class _ScenarioResult {
  const _ScenarioResult({
    required this.scenario,
    required this.mean,
    required this.p50,
    required this.p95,
    required this.budget,
    required this.pass,
    this.nodeRebuilds,
    this.nodePoolSize,
  });

  final String scenario;
  final double mean;
  final double p50;
  final double p95;
  final double budget;
  final bool pass;

  /// Controller node-layer rebuilds during the scenario (item 27), or null
  /// when the scenario did not capture a controller.
  final int? nodeRebuilds;

  /// Row nodes retained by the controller at scenario end (item 27), or
  /// null when the scenario did not capture a controller.
  final int? nodePoolSize;
}

/// An informational (ungated) scenario measurement — trend data only.
class _InfoResult {
  const _InfoResult({
    required this.scenario,
    required this.metric,
    required this.value,
    required this.unit,
  });

  final String scenario;
  final String metric;
  final double value;
  final String unit;
}

double _percentile(List<double> sorted, double p) {
  final idx = min(sorted.length - 1, max(0, (p * sorted.length).ceil() - 1));
  return sorted[idx];
}

double _round2(double v) => (v * 100).roundToDouble() / 100;

void _log(String message) {
  // ignore: avoid_print
  print(message);
}

// ---------------------------------------------------------------------------
// Grid builders
// ---------------------------------------------------------------------------

const List<OsColumnDef<Map<String, Object>>> _defaultColumns = [
  OsColumnDef(field: 'id', width: 90),
  OsColumnDef(field: 'name', width: 320),
  OsColumnDef(field: 'value', width: 140),
  OsColumnDef(field: 'flag', width: 120),
];

const List<OsColumnDef<Map<String, Object>>> _editableColumns = [
  OsColumnDef(field: 'id', width: 90),
  OsColumnDef(field: 'name', width: 320, editable: true),
  OsColumnDef(field: 'value', width: 140),
  OsColumnDef(field: 'flag', width: 120),
];

List<OsColumnDef<Map<String, Object>>> _generatedColumns(int count) =>
    List.generate(count, (i) => OsColumnDef(field: 'c$i', width: 130));

List<Map<String, Object>> _generateRows(int count) => List.generate(count, (i) {
  return <String, Object>{
    'id': i,
    'name': 'Row $i',
    'value': (i * 7919) % 9973,
    'flag': i.isEven ? 'on' : 'off',
  };
});

List<Map<String, Object>> _generateWideRows(int count, int columnCount) =>
    List.generate(count, (i) {
      return <String, Object>{
        'id': i,
        for (var c = 0; c < columnCount; c++) 'c$c': 'v$i-$c',
      };
    });

Widget _buildGrid(
  List<Map<String, Object>> rows, {
  OsGridController<Map<String, Object>>? controller,
  List<OsColumnDef<Map<String, Object>>> columns = _defaultColumns,
  String Function(Map<String, Object>)? getRowId,
}) => MaterialApp(
  home: Scaffold(
    body: SizedBox(
      width: 1024,
      height: 768,
      child: OsGrid<Map<String, Object>>(
        controller: controller,
        columnDefs: columns,
        rowData: rows,
        getRowId: getRowId,
      ),
    ),
  ),
);

Future<void> _teardownGrid(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Scenario: scroll (100k rows, 120 frames)
// ---------------------------------------------------------------------------

Future<void> _runScrollBench(WidgetTester tester) async {
  final rows = _generateRows(_scrollRowCount);
  final controller = OsGridController<Map<String, Object>>();

  // Initial build (not part of the measured samples).
  await tester.pumpWidget(_buildGrid(rows, controller: controller));
  await tester.pump();
  await tester.pump();

  final gridFinder = find.byType(VirtualisedGrid);
  expect(gridFinder, findsOneWidget);

  final viewportHeight = tester.getRect(gridFinder).height;
  final step = (viewportHeight * 0.8).clamp(200.0, 600.0);

  final samples = <double>[];
  var directionDown = true;

  for (var frame = 0; frame < _scrollFrames; frame++) {
    if ((frame + 1) % _scrollBounceEvery == 0) directionDown = !directionDown;

    final sw = Stopwatch()..start();
    final gesture = await tester.startGesture(tester.getCenter(gridFinder));
    // Move in several small pointer moves to emulate a fling-less drag.
    const chunks = 6;
    for (var c = 0; c < chunks; c++) {
      await gesture.moveBy(
        Offset(0, directionDown ? -step / chunks : step / chunks),
      );
      await tester.pump();
    }
    sw.stop();
    await gesture.up();
    // One frame for the pointer-up, then flush the double-tap recognizer's
    // countdown timers so the fake-async zone ends with no pending timers.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));

    samples.add(sw.elapsedMicroseconds / 1000.0);
  }

  _recordAndAssert(
    scenario: 'scroll',
    samples: samples,
    budget: _scrollBudgetMs,
    nodeRebuilds: controller.nodeRebuildCount,
    nodePoolSize: controller.nodePoolSize,
  );

  await _teardownGrid(tester);
}

// ---------------------------------------------------------------------------
// Scenario: cold-start (100k rows, first frame after setRowData)
// ---------------------------------------------------------------------------

Future<void> _runColdStartBench(WidgetTester tester) async {
  final samples = <double>[];
  var totalRebuilds = 0;
  var lastPoolSize = 0;

  for (var run = 0; run < _coldStartRuns; run++) {
    final controller = OsGridController<Map<String, Object>>();

    // Mount an empty grid so the measured pump covers exactly one
    // setRowData-driven first layout+paint of the full dataset.
    await tester.pumpWidget(_buildGrid(const [], controller: controller));
    await tester.pump();
    await tester.pump();

    final rows = _generateRows(_scrollRowCount);
    final sw = Stopwatch()..start();
    controller.setRowData(rows);
    await tester.pump();
    sw.stop();
    samples.add(sw.elapsedMicroseconds / 1000.0);

    totalRebuilds += controller.nodeRebuildCount;
    lastPoolSize = controller.nodePoolSize;

    // Drain follow-up frames/events before tearing down for the next run.
    await tester.pumpAndSettle();
    await _teardownGrid(tester);
  }

  _recordAndAssert(
    scenario: 'cold-start',
    samples: samples,
    budget: _coldStartBudgetMs,
    passOnMean: true,
    nodeRebuilds: totalRebuilds,
    nodePoolSize: lastPoolSize,
  );
}

// ---------------------------------------------------------------------------
// Scenario: edit-burst (10k rows, 50 open/type/commit edit cycles)
// ---------------------------------------------------------------------------

Future<void> _runEditBurstBench(WidgetTester tester) async {
  final rows = _generateRows(_editBurstRowCount);
  final controller = OsGridController<Map<String, Object>>();

  await tester.pumpWidget(
    _buildGrid(rows, controller: controller, columns: _editableColumns),
  );
  await tester.pump();
  await tester.pump();

  final samples = <double>[];

  for (var edit = 0; edit < _editBurstEdits; edit++) {
    final sw = Stopwatch()..start();

    controller.startEditingCell(rowIndex: edit, colId: 'name');
    await tester.pump();

    await tester.enterText(find.byType(EditableText).last, 'Edited $edit');
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    sw.stop();
    samples.add(sw.elapsedMicroseconds / 1000.0);
  }

  // Flush any pending recogniser timers before the fake-async zone ends.
  await tester.pump(const Duration(milliseconds: 300));

  _recordAndAssert(
    scenario: 'edit-burst',
    samples: samples,
    budget: _editBurstBudgetMs,
    nodeRebuilds: controller.nodeRebuildCount,
    nodePoolSize: controller.nodePoolSize,
  );

  await _teardownGrid(tester);
}

// ---------------------------------------------------------------------------
// Scenario: transaction-storm (50k rows, 20 add/remove/update rounds)
// ---------------------------------------------------------------------------

Future<void> _runTransactionStormBench(WidgetTester tester) async {
  final rows = _generateRows(_stormRowCount);
  final controller = OsGridController<Map<String, Object>>();

  await tester.pumpWidget(
    _buildGrid(rows, controller: controller, getRowId: (r) => 'id-${r['id']}'),
  );
  await tester.pump();
  await tester.pump();

  final samples = <double>[];

  for (var round = 0; round < _stormRounds; round++) {
    final adds = List.generate(_stormBatchSize, (i) {
      return <String, Object>{
        'id': 1000000 + round * _stormBatchSize + i,
        'name': 'New $round-$i',
        'value': i,
        'flag': 'new',
      };
    });
    final removals = <Map<String, Object>>[
      for (var i = 0; i < _stormBatchSize; i++)
        rows[round * _stormBatchSize + i],
    ];
    final updates = <Map<String, Object>>[
      for (var i = 0; i < _stormBatchSize; i++)
        <String, Object>{
          ...rows[40000 + round * _stormBatchSize + i],
          'value': i,
        },
    ];

    final sw = Stopwatch()..start();
    controller.applyTransaction(
      OsRowTransaction(add: adds, remove: removals, update: updates),
    );
    await tester.pump();
    sw.stop();

    samples.add(sw.elapsedMicroseconds / 1000.0);
  }

  _recordAndAssert(
    scenario: 'transaction-storm',
    samples: samples,
    budget: _stormBudgetMs,
    nodeRebuilds: controller.nodeRebuildCount,
    nodePoolSize: controller.nodePoolSize,
  );

  await _teardownGrid(tester);
}

// ---------------------------------------------------------------------------
// Scenario: filter-typing (100k rows, 20 rapid quick-filter changes)
// ---------------------------------------------------------------------------

Future<void> _runFilterTypingBench(WidgetTester tester) async {
  final rows = _generateRows(_filterRowCount);
  final controller = OsGridController<Map<String, Object>>();

  await tester.pumpWidget(_buildGrid(rows, controller: controller));
  await tester.pump();
  await tester.pump();

  // Progressive "typing" — each change re-runs the quick filter over the
  // full 100k-row dataset and repaints the visible window.
  const texts = <String>[
    'R',
    'Ro',
    'Row',
    'Row 1',
    'Row 12',
    'Row 123',
    'Row 1234',
    'Row 1235',
    'Row 2',
    'Row 21',
    'Row 3',
    'Row 33',
    'Row 4',
    'Row 44',
    'Row 5',
    'Row 55',
    'Row 6',
    'Row 66',
    'Row 7',
    'Row 77',
  ];
  expect(texts.length, _filterChanges);

  final samples = <double>[];

  for (final text in texts) {
    final sw = Stopwatch()..start();
    controller.setQuickFilter(text);
    await tester.pump();
    sw.stop();
    samples.add(sw.elapsedMicroseconds / 1000.0);
  }

  controller.setQuickFilter(null);
  await tester.pump();

  _recordAndAssert(
    scenario: 'filter-typing',
    samples: samples,
    budget: _filterBudgetMs,
    nodeRebuilds: controller.nodeRebuildCount,
    nodePoolSize: controller.nodePoolSize,
  );

  await _teardownGrid(tester);
}

// ---------------------------------------------------------------------------
// Scenario: column-resize (10k rows, 20 columns, 30 resize gestures)
// ---------------------------------------------------------------------------

Future<void> _runColumnResizeBench(WidgetTester tester) async {
  final rows = _generateWideRows(_resizeRowCount, _resizeColumnCount);
  final controller = OsGridController<Map<String, Object>>();

  await tester.pumpWidget(
    _buildGrid(
      rows,
      controller: controller,
      columns: _generatedColumns(_resizeColumnCount),
    ),
  );
  await tester.pump();
  await tester.pump();

  final gridFinder = find.byType(VirtualisedGrid);
  expect(gridFinder, findsOneWidget);

  final gridRect = tester.getRect(gridFinder);
  // Aim at the middle of the 48px header row, on the trailing edge of
  // column 0 (resize hit band is 5px wide). The +/- deltas alternate, so
  // the column width (and therefore its edge X) is deterministic per
  // gesture: even gestures start at the base width, odd ones at base + delta.
  final headerY = gridRect.top + 24.0;

  final samples = <double>[];

  for (var g = 0; g < _resizeGestures; g++) {
    final growing = g.isEven;
    final edgeX =
        gridRect.left +
        (growing ? _resizeColumnWidth : _resizeColumnWidth + _resizeDelta) -
        2.0;
    final dx = growing ? _resizeDelta : -_resizeDelta;

    final sw = Stopwatch()..start();
    final gesture = await tester.startGesture(Offset(edgeX, headerY));
    const chunks = 4;
    for (var c = 0; c < chunks; c++) {
      await gesture.moveBy(Offset(dx / chunks, 0));
      await tester.pump();
    }
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    sw.stop();

    samples.add(sw.elapsedMicroseconds / 1000.0);
  }

  // Flush any pending recogniser timers before the fake-async zone ends.
  await tester.pump(const Duration(milliseconds: 300));

  _recordAndAssert(
    scenario: 'column-resize',
    samples: samples,
    budget: _resizeBudgetMs,
    nodeRebuilds: controller.nodeRebuildCount,
    nodePoolSize: controller.nodePoolSize,
  );

  await _teardownGrid(tester);
}

// ---------------------------------------------------------------------------
// Scenario: memory (100k rows, RSS delta while mounted — informational)
// ---------------------------------------------------------------------------

Future<void> _runMemoryBench(WidgetTester tester) async {
  // RSS before any grid/data for this scenario exists. Garbage from prior
  // scenarios in the same process can inflate the delta; values are trend
  // data, not absolute footprint claims.
  final rssBefore = ProcessInfo.currentRss;

  final controller = OsGridController<Map<String, Object>>();
  final rows = _generateRows(_memoryRowCount);
  await tester.pumpWidget(_buildGrid(rows, controller: controller));
  await tester.pump();
  await tester.pump();

  final rssAfter = ProcessInfo.currentRss;
  final deltaMb = (rssAfter - rssBefore) / (1024 * 1024);

  _log(
    'node profiling: nodePoolSize ${controller.nodePoolSize} | '
    'nodeRebuilds ${controller.nodeRebuildCount}',
  );

  _recordInformational(
    scenario: 'memory-100k',
    metric: 'rssDeltaMb',
    value: deltaMb,
    unit: 'MB',
  );

  await _teardownGrid(tester);
}

// ---------------------------------------------------------------------------
// Scenario: startup (10k rows, pumpWidget → first frame — informational)
// ---------------------------------------------------------------------------

Future<void> _runStartupBench(WidgetTester tester) async {
  final samples = <double>[];

  for (var run = 0; run < _startupRuns; run++) {
    // Row generation is NOT part of the measurement: the clock covers
    // mount → first layout+paint of the 10k-row grid only.
    final rows = _generateRows(_startupRowCount);

    final sw = Stopwatch()..start();
    await tester.pumpWidget(_buildGrid(rows));
    await tester.pump();
    sw.stop();

    samples.add(sw.elapsedMicroseconds / 1000.0);

    await tester.pumpAndSettle();
    await _teardownGrid(tester);
  }

  final mean = samples.reduce((a, b) => a + b) / samples.length;

  _recordInformational(
    scenario: 'startup-10k',
    metric: 'firstFrameMs',
    value: mean,
    unit: 'ms',
  );
}
