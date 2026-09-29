import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

/// Settles the tree after a flash, with an explicit pump cadence and a
/// bounded fake-time budget.
///
/// The budget is a failure bound, not a correctness assertion: the flash
/// animation runs on the ticker's clock, so it retires after its last phase
/// and this settles in a handful of pumps. If a flash ever fails to retire,
/// its ticker keeps scheduling frames and `pumpAndSettle` spins — the
/// default ten-minute budget turns that into a ten-minute hang whose outcome
/// depends on how loaded the machine is, which is how a wall-clock-driven
/// flash surfaced only intermittently in CI. Thirty seconds of fake time
/// fails the test in a bounded, diagnosable way instead.
Future<void> settleAfterFlash(WidgetTester tester) => tester.pumpAndSettle(
  const Duration(milliseconds: 16),
  EnginePhase.sendSemanticsUpdate,
  const Duration(seconds: 30),
);

void main() {
  group('CellFlashState', () {
    test('opacityAt returns 0.0 during delay phase', () {
      final flash = CellFlashState(
        position: const CellPosition(rowIndex: 0, colId: 'price'),
        startTime: Duration.zero,
        flashDuration: const Duration(milliseconds: 500),
        fadeDuration: const Duration(milliseconds: 1000),
        flashDelay: const Duration(milliseconds: 200),
        fadeDelay: Duration.zero,
      );

      // During delay (0–200ms), opacity should be 0.0
      expect(flash.opacityAt(const Duration(milliseconds: 0)), 0.0);
      expect(flash.opacityAt(const Duration(milliseconds: 100)), 0.0);
      expect(flash.opacityAt(const Duration(milliseconds: 199)), 0.0);
    });

    test('opacityAt returns 1.0 during flash phase', () {
      final flash = CellFlashState(
        position: const CellPosition(rowIndex: 0, colId: 'price'),
        startTime: Duration.zero,
        flashDuration: const Duration(milliseconds: 500),
        fadeDuration: const Duration(milliseconds: 1000),
        flashDelay: Duration.zero,
        fadeDelay: Duration.zero,
      );

      // During flash (0–500ms), opacity should be 1.0
      expect(flash.opacityAt(const Duration(milliseconds: 0)), 1.0);
      expect(flash.opacityAt(const Duration(milliseconds: 250)), 1.0);
      expect(flash.opacityAt(const Duration(milliseconds: 499)), 1.0);
    });

    test('opacityAt returns 1.0 during fadeDelay phase', () {
      final flash = CellFlashState(
        position: const CellPosition(rowIndex: 0, colId: 'price'),
        startTime: Duration.zero,
        flashDuration: const Duration(milliseconds: 500),
        fadeDuration: const Duration(milliseconds: 1000),
        flashDelay: Duration.zero,
        fadeDelay: const Duration(milliseconds: 300),
      );

      // During fadeDelay (500–800ms), opacity should be 1.0
      expect(flash.opacityAt(const Duration(milliseconds: 500)), 1.0);
      expect(flash.opacityAt(const Duration(milliseconds: 700)), 1.0);
      expect(flash.opacityAt(const Duration(milliseconds: 799)), 1.0);
    });

    test('opacityAt fades linearly during fade phase', () {
      final flash = CellFlashState(
        position: const CellPosition(rowIndex: 0, colId: 'price'),
        startTime: Duration.zero,
        flashDuration: const Duration(milliseconds: 500),
        fadeDuration: const Duration(milliseconds: 1000),
        flashDelay: Duration.zero,
        fadeDelay: Duration.zero,
      );

      // Fade starts at 500ms, ends at 1500ms
      // At 500ms: opacity = 1.0 (start of fade)
      expect(flash.opacityAt(const Duration(milliseconds: 500)), 1.0);
      // At 1000ms: opacity ≈ 0.5 (midpoint of fade)
      final midOpacity = flash.opacityAt(const Duration(milliseconds: 1000));
      expect(midOpacity, closeTo(0.5, 0.01));
      // At 1250ms: opacity ≈ 0.25
      final lateOpacity = flash.opacityAt(const Duration(milliseconds: 1250));
      expect(lateOpacity, closeTo(0.25, 0.01));
    });

    test('opacityAt returns null after animation completes', () {
      final flash = CellFlashState(
        position: const CellPosition(rowIndex: 0, colId: 'price'),
        startTime: Duration.zero,
        flashDuration: const Duration(milliseconds: 500),
        fadeDuration: const Duration(milliseconds: 1000),
        flashDelay: Duration.zero,
        fadeDelay: Duration.zero,
      );

      // After 1500ms (500 flash + 1000 fade), animation is complete
      expect(flash.opacityAt(const Duration(milliseconds: 1500)), isNull);
      expect(flash.opacityAt(const Duration(milliseconds: 2000)), isNull);
    });

    test('opacityAt handles zero flash duration (immediate fade)', () {
      final flash = CellFlashState(
        position: const CellPosition(rowIndex: 0, colId: 'price'),
        startTime: Duration.zero,
        flashDuration: Duration.zero,
        fadeDuration: const Duration(milliseconds: 1000),
        flashDelay: Duration.zero,
        fadeDelay: Duration.zero,
      );

      // Flash duration is 0, so it goes straight to fading
      expect(flash.opacityAt(Duration.zero), 1.0);
      final midOpacity = flash.opacityAt(const Duration(milliseconds: 500));
      expect(midOpacity, closeTo(0.5, 0.01));
      expect(flash.opacityAt(const Duration(milliseconds: 1000)), isNull);
    });

    test('opacityAt handles startTime offset', () {
      final flash = CellFlashState(
        position: const CellPosition(rowIndex: 0, colId: 'price'),
        startTime: const Duration(milliseconds: 1000),
        flashDuration: const Duration(milliseconds: 500),
        fadeDuration: const Duration(milliseconds: 500),
        flashDelay: Duration.zero,
        fadeDelay: Duration.zero,
      );

      // Before start time: elapsed is negative → treated as delay
      expect(flash.opacityAt(const Duration(milliseconds: 500)), 0.0);
      // At start time: flash begins
      expect(flash.opacityAt(const Duration(milliseconds: 1000)), 1.0);
      // During flash
      expect(flash.opacityAt(const Duration(milliseconds: 1250)), 1.0);
      // During fade
      final fadeOpacity = flash.opacityAt(const Duration(milliseconds: 1750));
      expect(fadeOpacity, closeTo(0.5, 0.01));
      // After completion
      expect(flash.opacityAt(const Duration(milliseconds: 2000)), isNull);
    });

    test('totalDuration sums all phases', () {
      final flash = CellFlashState(
        position: const CellPosition(rowIndex: 0, colId: 'price'),
        startTime: Duration.zero,
        flashDuration: const Duration(milliseconds: 500),
        fadeDuration: const Duration(milliseconds: 1000),
        flashDelay: const Duration(milliseconds: 200),
        fadeDelay: const Duration(milliseconds: 300),
      );

      expect(flash.totalDuration, const Duration(milliseconds: 2000));
    });
  });

  group('CellPosition', () {
    test('equality by rowIndex and colId', () {
      const a = CellPosition(rowIndex: 0, colId: 'price');
      const b = CellPosition(rowIndex: 0, colId: 'price');
      const c = CellPosition(rowIndex: 1, colId: 'price');
      const d = CellPosition(rowIndex: 0, colId: 'volume');

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
      expect(a, isNot(equals(d)));
    });

    test('toString includes row and col', () {
      const pos = CellPosition(rowIndex: 3, colId: 'name');
      expect(pos.toString(), contains('3'));
      expect(pos.toString(), contains('name'));
    });
  });

  group('RefreshCellsParams', () {
    test('defaults', () {
      const params = RefreshCellsParams();
      expect(params.rowIndices, isNull);
      expect(params.columns, isNull);
      expect(params.force, isFalse);
      expect(params.suppressFlash, isFalse);
    });

    test('custom values', () {
      const params = RefreshCellsParams(
        rowIndices: [0, 1, 2],
        columns: ['price', 'volume'],
        force: true,
        suppressFlash: true,
      );
      expect(params.rowIndices, [0, 1, 2]);
      expect(params.columns, ['price', 'volume']);
      expect(params.force, isTrue);
      expect(params.suppressFlash, isTrue);
    });
  });

  group('FlashCellsParams', () {
    test('defaults', () {
      const params = FlashCellsParams();
      expect(params.rowIndices, isNull);
      expect(params.columns, isNull);
      expect(params.flashDuration, 500);
      expect(params.fadeDuration, 1000);
      expect(params.flashDelay, 0);
      expect(params.fadeDelay, 0);
    });

    test('custom values', () {
      const params = FlashCellsParams(
        rowIndices: [5, 10],
        columns: ['price'],
        flashDuration: 300,
        fadeDuration: 600,
        flashDelay: 100,
        fadeDelay: 50,
      );
      expect(params.rowIndices, [5, 10]);
      expect(params.columns, ['price']);
      expect(params.flashDuration, 300);
      expect(params.fadeDuration, 600);
      expect(params.flashDelay, 100);
      expect(params.fadeDelay, 50);
    });
  });

  group('OsGridController Render API', () {
    test('refreshCells triggers notifyListeners', () {
      final controller = OsGridController<Map<String, dynamic>>();
      int notifyCount = 0;
      controller.addListener(() => notifyCount++);

      controller.refreshCells();
      expect(notifyCount, 1);

      controller.refreshCells(const RefreshCellsParams(suppressFlash: true));
      expect(notifyCount, 2);

      controller.dispose();
    });

    test('refreshCells with suppressFlash does not call flash callback', () {
      final controller = OsGridController<Map<String, dynamic>>();
      int flashCallCount = 0;
      controller.onFlashCellsRequested = (_) => flashCallCount++;

      controller.refreshCells(const RefreshCellsParams(suppressFlash: true));
      expect(flashCallCount, 0);

      controller.dispose();
    });

    test('refreshCells without suppressFlash calls flash callback', () {
      final controller = OsGridController<Map<String, dynamic>>();
      FlashCellsParams? receivedParams;
      controller.onFlashCellsRequested = (params) => receivedParams = params;

      controller.refreshCells(
        const RefreshCellsParams(rowIndices: [0, 1], columns: ['price']),
      );
      expect(receivedParams, isNotNull);
      expect(receivedParams!.rowIndices, [0, 1]);
      expect(receivedParams!.columns, ['price']);

      controller.dispose();
    });

    test('flashCells calls flash callback with params', () {
      final controller = OsGridController<Map<String, dynamic>>();
      FlashCellsParams? receivedParams;
      controller.onFlashCellsRequested = (params) => receivedParams = params;

      controller.flashCells(
        const FlashCellsParams(
          rowIndices: [3],
          columns: ['volume'],
          flashDuration: 200,
          fadeDuration: 400,
        ),
      );

      expect(receivedParams, isNotNull);
      expect(receivedParams!.rowIndices, [3]);
      expect(receivedParams!.columns, ['volume']);
      expect(receivedParams!.flashDuration, 200);
      expect(receivedParams!.fadeDuration, 400);

      controller.dispose();
    });

    test('flashCells with no params uses defaults', () {
      final controller = OsGridController<Map<String, dynamic>>();
      FlashCellsParams? receivedParams;
      controller.onFlashCellsRequested = (params) => receivedParams = params;

      controller.flashCells();

      expect(receivedParams, isNotNull);
      expect(receivedParams!.rowIndices, isNull);
      expect(receivedParams!.columns, isNull);
      expect(receivedParams!.flashDuration, 500);
      expect(receivedParams!.fadeDuration, 1000);

      controller.dispose();
    });

    test('refreshHeader triggers notifyListeners', () {
      final controller = OsGridController<Map<String, dynamic>>();
      int notifyCount = 0;
      controller.addListener(() => notifyCount++);

      controller.refreshHeader();
      expect(notifyCount, 1);

      controller.dispose();
    });
  });

  group('OsGrid widget flash integration', () {
    testWidgets('flashCells triggers visual update', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: OsGrid<Map<String, dynamic>>(
                controller: controller,
                columnDefs: [
                  const OsColumnDef(field: 'name', headerName: 'Name'),
                  const OsColumnDef(field: 'price', headerName: 'Price'),
                ],
                rowData: [
                  {'name': 'Apple', 'price': 150},
                  {'name': 'Google', 'price': 2800},
                  {'name': 'Microsoft', 'price': 300},
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Flash specific cells — should not throw
      controller.flashCells(
        const FlashCellsParams(
          rowIndices: [0, 1],
          columns: ['price'],
          flashDuration: 100,
          fadeDuration: 200,
        ),
      );

      // Pump a few frames to drive the animation
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));

      // After total duration (100 + 200 = 300ms), flashes should be gone
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 16));

      controller.dispose();
    });

    testWidgets('refreshCells triggers repaint without error', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: OsGrid<Map<String, dynamic>>(
                controller: controller,
                columnDefs: [
                  const OsColumnDef(field: 'name', headerName: 'Name'),
                  const OsColumnDef(field: 'value', headerName: 'Value'),
                ],
                rowData: [
                  {'name': 'A', 'value': 1},
                  {'name': 'B', 'value': 2},
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // refreshCells with no params — should not throw
      controller.refreshCells();
      await tester.pump();

      // refreshCells with suppressFlash — should not throw
      controller.refreshCells(const RefreshCellsParams(suppressFlash: true));
      await tester.pump();

      // refreshCells with specific rows/columns
      controller.refreshCells(
        const RefreshCellsParams(rowIndices: [0], columns: ['value']),
      );
      await tester.pump(const Duration(milliseconds: 16));
      await settleAfterFlash(tester);

      controller.dispose();
    });

    testWidgets('refreshHeader triggers repaint without error', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: OsGrid<Map<String, dynamic>>(
                controller: controller,
                columnDefs: [
                  const OsColumnDef(field: 'name', headerName: 'Name'),
                ],
                rowData: [
                  {'name': 'Test'},
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // refreshHeader should not throw
      controller.refreshHeader();
      await tester.pump();

      controller.dispose();
    });

    testWidgets('flash on already-flashing cell restarts animation', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: OsGrid<Map<String, dynamic>>(
                controller: controller,
                columnDefs: [
                  const OsColumnDef(field: 'price', headerName: 'Price'),
                ],
                rowData: [
                  {'price': 100},
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Start first flash
      controller.flashCells(
        const FlashCellsParams(
          rowIndices: [0],
          columns: ['price'],
          flashDuration: 500,
          fadeDuration: 500,
        ),
      );
      await tester.pump(const Duration(milliseconds: 16));

      // Wait partway through
      await tester.pump(const Duration(milliseconds: 300));

      // Flash again — should restart
      controller.flashCells(
        const FlashCellsParams(
          rowIndices: [0],
          columns: ['price'],
          flashDuration: 500,
          fadeDuration: 500,
        ),
      );
      await tester.pump(const Duration(milliseconds: 16));

      // The flash should still be active (restarted)
      await tester.pump(const Duration(milliseconds: 400));
      // Should still be animating (500ms flash hasn't completed from restart)
      await tester.pump(const Duration(milliseconds: 16));

      // Wait for full completion
      await settleAfterFlash(tester);

      controller.dispose();
    });

    testWidgets('flashCells with all rows and columns', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: OsGrid<Map<String, dynamic>>(
                controller: controller,
                columnDefs: [
                  const OsColumnDef(field: 'name', headerName: 'Name'),
                  const OsColumnDef(field: 'price', headerName: 'Price'),
                  const OsColumnDef(field: 'volume', headerName: 'Volume'),
                ],
                rowData: [
                  {'name': 'A', 'price': 10, 'volume': 100},
                  {'name': 'B', 'price': 20, 'volume': 200},
                  {'name': 'C', 'price': 30, 'volume': 300},
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Flash all cells (no rowIndices/columns specified)
      controller.flashCells(
        const FlashCellsParams(flashDuration: 100, fadeDuration: 100),
      );
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 16));

      // Should complete without error
      await settleAfterFlash(tester);

      controller.dispose();
    });
  });

  group('CellFlashPhase enum', () {
    test('all phases are distinct', () {
      const values = CellFlashPhase.values;
      expect(values.length, 4);
      expect(values, contains(CellFlashPhase.delay));
      expect(values, contains(CellFlashPhase.flash));
      expect(values, contains(CellFlashPhase.fadeDelay));
      expect(values, contains(CellFlashPhase.fading));
    });
  });
}
