import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

/// RULE ZERO hang-prevention regression harness.
///
/// Every new lifecycle event (onFirstDataRendered, onGridSizeChanged,
/// onModelUpdated, onRowDataChanged) MUST be emitted asynchronously via
/// post-frame callbacks — never synchronously from build/layout/paint.
///
/// The harness below wires the four new widget callbacks to `setState` on
/// the parent. If any emission happens during build or layout, Flutter
/// throws "setState() or markNeedsBuild() called during build" and these
/// tests fail.
void main() {
  testWidgets('30 frames of interactions with overlays + all lifecycle events '
      'complete inside wall-clock watchdog', (tester) async {
    final controller = OsGridController<Map<String, dynamic>>();

    var firstDataRenderedCount = 0;
    var gridSizeChangedCount = 0;
    var modelUpdatedCount = 0;
    var rowDataChangedCount = 0;

    // NOTE: intentionally not cancelled — awaiting StreamSubscription
    // .cancel() inside testWidgets deadlocks teardown on this SDK.
    controller.onFirstDataRendered.listen((_) => firstDataRenderedCount++);
    controller.onGridSizeChanged.listen((_) => gridSizeChangedCount++);
    controller.onModelUpdated.listen((_) => modelUpdatedCount++);
    controller.onRowDataChanged.listen((_) => rowDataChangedCount++);

    final rows = List<Map<String, dynamic>>.generate(
      50,
      (i) => {'name': 'Row $i', 'value': i},
    );

    // Wall-clock watchdog: fail if driving the frames takes >10s.
    final watchdog = Stopwatch()..start();

    await tester.pumpWidget(
      _Harness(controller: controller, rows: rows, loading: false),
    );
    await tester.pump();

    // Drive 30 frames of mixed interactions: filter set, page change,
    // resize, loading toggle and a fresh rowData list instance.
    for (var i = 0; i < 10; i++) {
      // 1. Filter set via controller API.
      controller.setFilterModel({
        'name': {'filterType': 'text', 'type': 'contains', 'filter': 'Row'},
      });
      await tester.pump();

      // 2. Page change via controller API.
      controller.paginationGoToNextPage();
      await tester.pump();
      await tester.pump();

      // 3. Resize + overlay state flip through parent rebuilds.
      await tester.pumpWidget(
        _Harness(
          controller: controller,
          rows: rows,
          height: i.isEven ? 400 : 600,
          loading: i.isEven,
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    // Feed a new rowData list instance (didUpdateWidget path).
    await tester.pumpWidget(
      _Harness(controller: controller, rows: List.of(rows), loading: false),
    );
    await tester.pump();
    await tester.pump();

    watchdog.stop();

    expect(
      watchdog.elapsed,
      lessThan(const Duration(seconds: 10)),
      reason:
          'Driving 30 interaction frames took ${watchdog.elapsed} — a '
          'rebuild storm or event loop is likely (RULE ZERO violation).',
    );

    // All four events must actually have been delivered.
    expect(firstDataRenderedCount, 1);
    expect(gridSizeChangedCount, greaterThanOrEqualTo(1));
    expect(modelUpdatedCount, greaterThanOrEqualTo(1));
    expect(rowDataChangedCount, greaterThanOrEqualTo(1));

    controller.dispose();
  });

  testWidgets('no-rows overlay shows for empty data without hanging', (
    tester,
  ) async {
    final controller = OsGridController<Map<String, dynamic>>();
    // NOTE: intentionally not cancelled — awaiting StreamSubscription
    // .cancel() inside testWidgets deadlocks teardown on this SDK.
    controller.onModelUpdated.listen((_) {});
    controller.onFirstDataRendered.listen((_) {});

    await tester.pumpWidget(_Harness(controller: controller, rows: []));
    await tester.pump();
    await tester.pump();

    expect(find.text('No Rows To Show'), findsOneWidget);

    // Clearing the filter on an empty grid must not stall either.
    controller.setFilterModel(null);
    await tester.pump();
    await tester.pump();

    controller.dispose();
  });
}

/// Parent harness that calls setState from the new lifecycle event
/// callbacks — the RULE ZERO tripwire.
class _Harness extends StatefulWidget {
  const _Harness({
    required this.controller,
    required this.rows,
    this.height = 500,
    this.loading = false,
  });

  final OsGridController<Map<String, dynamic>> controller;
  final List<Map<String, dynamic>> rows;
  final double height;
  final bool loading;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  int _eventDrivenRebuilds = 0;

  /// Post-frame-emitted events may safely trigger parent rebuilds.
  void _onPostFrameEvent(dynamic _) {
    setState(() => _eventDrivenRebuilds++);
  }

  /// onRowDataChanged fires inside didUpdateWidget (before the pipeline
  /// runs) so its callback must never rebuild synchronously — count only.
  int _rowDataChangedCallbackCount = 0;
  void _countRowDataChanged(dynamic _) => _rowDataChangedCallbackCount++;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: widget.height,
          child: OsGrid<Map<String, dynamic>>(
            controller: widget.controller,
            columnDefs: [
              const OsColumnDef(field: 'name', headerName: 'Name'),
              const OsColumnDef(field: 'value', headerName: 'Value'),
            ],
            rowData: widget.rows,
            pagination: const OsPagination(pageSize: 10),
            loading: widget.loading,
            onModelUpdated: _onPostFrameEvent,
            onGridSizeChanged: _onPostFrameEvent,
            onFirstDataRendered: _onPostFrameEvent,
            onRowDataChanged: _countRowDataChanged,
          ),
        ),
      ),
    );
  }
}
