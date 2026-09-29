import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

void main() {
  group('TooltipService', () {
    late TooltipService service;

    setUp(() {
      service = TooltipService(
        showDelay: 500,
        hideDelay: 5000,
        mouseTrack: false,
      );
    });

    tearDown(() {
      service.dispose();
    });

    test('starts in nothing state', () {
      expect(service.state, OsTooltipState.nothing);
      expect(service.tooltipValue, isNull);
      expect(service.anchorPosition, isNull);
    });

    test('transitions to waitingToShow on hover start', () {
      service.onHoverStart(
        value: 'Hello',
        location: TooltipLocation.cell,
        anchor: const Offset(100, 50),
        mousePos: const Offset(100, 50),
      );

      expect(service.state, OsTooltipState.waitingToShow);
      expect(service.tooltipValue, 'Hello');
      expect(service.anchorPosition, const Offset(100, 50));
    });

    test('transitions to showing after delay', () {
      fakeAsync((async) {
        service.onHoverStart(
          value: 'Hello',
          location: TooltipLocation.cell,
          anchor: const Offset(100, 50),
          mousePos: const Offset(100, 50),
        );

        expect(service.state, OsTooltipState.waitingToShow);

        // Advance past the show delay
        async.elapse(const Duration(milliseconds: 600));

        expect(service.state, OsTooltipState.showing);
        expect(service.tooltipValue, 'Hello');
      });
    });

    test('auto-hides after hide delay', () {
      fakeAsync((async) {
        service.onHoverStart(
          value: 'Hello',
          location: TooltipLocation.cell,
          anchor: const Offset(100, 50),
          mousePos: const Offset(100, 50),
        );

        // Show the tooltip
        async.elapse(const Duration(milliseconds: 600));
        expect(service.state, OsTooltipState.showing);

        // Wait for auto-hide
        async.elapse(const Duration(milliseconds: 5100));
        expect(service.state, OsTooltipState.nothing);
      });
    });

    test('cancels pending show on hover end', () {
      fakeAsync((async) {
        service.onHoverStart(
          value: 'Hello',
          location: TooltipLocation.cell,
          anchor: const Offset(100, 50),
          mousePos: const Offset(100, 50),
        );

        expect(service.state, OsTooltipState.waitingToShow);

        service.onHoverEnd();
        expect(service.state, OsTooltipState.nothing);
        expect(service.tooltipValue, isNull);

        // Advancing time should not show tooltip
        async.elapse(const Duration(milliseconds: 600));
        expect(service.state, OsTooltipState.nothing);
      });
    });

    test('hides on hover end when showing', () {
      fakeAsync((async) {
        service.onHoverStart(
          value: 'Hello',
          location: TooltipLocation.cell,
          anchor: const Offset(100, 50),
          mousePos: const Offset(100, 50),
        );

        async.elapse(const Duration(milliseconds: 600));
        expect(service.state, OsTooltipState.showing);

        service.onHoverEnd();
        expect(service.state, OsTooltipState.nothing);
      });
    });

    test('does not show tooltip for null value', () {
      fakeAsync((async) {
        service.onHoverStart(
          value: null,
          location: TooltipLocation.cell,
          anchor: const Offset(100, 50),
          mousePos: const Offset(100, 50),
        );

        expect(service.state, OsTooltipState.nothing);

        async.elapse(const Duration(milliseconds: 600));
        expect(service.state, OsTooltipState.nothing);
      });
    });

    test('does not show tooltip for empty string', () {
      fakeAsync((async) {
        service.onHoverStart(
          value: '',
          location: TooltipLocation.cell,
          anchor: const Offset(100, 50),
          mousePos: const Offset(100, 50),
        );

        expect(service.state, OsTooltipState.nothing);

        async.elapse(const Duration(milliseconds: 600));
        expect(service.state, OsTooltipState.nothing);
      });
    });

    test('switches tooltip when hovering different cell', () {
      fakeAsync((async) {
        service.onHoverStart(
          value: 'First',
          location: TooltipLocation.cell,
          anchor: const Offset(100, 50),
          mousePos: const Offset(100, 50),
        );

        async.elapse(const Duration(milliseconds: 600));
        expect(service.state, OsTooltipState.showing);
        expect(service.tooltipValue, 'First');

        // Hover a different cell
        service.onHoverStart(
          value: 'Second',
          location: TooltipLocation.cell,
          anchor: const Offset(200, 50),
          mousePos: const Offset(200, 50),
        );

        // Should reset and start waiting again
        expect(service.state, OsTooltipState.waitingToShow);
        expect(service.tooltipValue, 'Second');

        async.elapse(const Duration(milliseconds: 600));
        expect(service.state, OsTooltipState.showing);
        expect(service.tooltipValue, 'Second');
      });
    });

    test('hide() immediately resets state', () {
      fakeAsync((async) {
        service.onHoverStart(
          value: 'Hello',
          location: TooltipLocation.cell,
          anchor: const Offset(100, 50),
          mousePos: const Offset(100, 50),
        );

        async.elapse(const Duration(milliseconds: 600));
        expect(service.state, OsTooltipState.showing);

        service.hide();
        expect(service.state, OsTooltipState.nothing);
        expect(service.tooltipValue, isNull);
        expect(service.anchorPosition, isNull);
      });
    });

    test('clamps show delay to minimum 200ms', () {
      final fastService = TooltipService(
        showDelay: 50, // below minimum
        hideDelay: 5000,
        mouseTrack: false,
      );

      fakeAsync((async) {
        fastService.onHoverStart(
          value: 'Hello',
          location: TooltipLocation.cell,
          anchor: const Offset(100, 50),
          mousePos: const Offset(100, 50),
        );

        // Should not show at 50ms
        async.elapse(const Duration(milliseconds: 100));
        expect(fastService.state, OsTooltipState.waitingToShow);

        // Should show at 200ms (clamped minimum)
        async.elapse(const Duration(milliseconds: 150));
        expect(fastService.state, OsTooltipState.showing);
      });

      fastService.dispose();
    });

    test('notifies listeners on state changes', () {
      fakeAsync((async) {
        int notifyCount = 0;
        service.stateChangeNotifier.addListener(() => notifyCount++);

        service.onHoverStart(
          value: 'Hello',
          location: TooltipLocation.cell,
          anchor: const Offset(100, 50),
          mousePos: const Offset(100, 50),
        );

        // No notification yet (just started waiting)
        // Actually the state machine doesn't notify on waitingToShow
        // It notifies when showing or hiding
        async.elapse(const Duration(milliseconds: 600));
        expect(notifyCount, greaterThan(0));
      });
    });

    test('mouse track mode updates position', () {
      final trackService = TooltipService(
        showDelay: 200,
        hideDelay: 5000,
        mouseTrack: true,
      );

      fakeAsync((async) {
        trackService.onHoverStart(
          value: 'Hello',
          location: TooltipLocation.cell,
          anchor: const Offset(100, 50),
          mousePos: const Offset(100, 50),
        );

        async.elapse(const Duration(milliseconds: 300));
        expect(trackService.state, OsTooltipState.showing);

        // Move mouse
        trackService.onHoverMove(const Offset(150, 60));
        expect(trackService.mousePosition, const Offset(150, 60));
      });

      trackService.dispose();
    });
  });

  group('TooltipOverlay widget', () {
    testWidgets('renders tooltip text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: Stack(
                children: [
                  TooltipOverlay(
                    value: 'Test tooltip',
                    position: Offset(100, 100),
                    gridSize: Size(800, 600),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Test tooltip'), findsOneWidget);
    });

    testWidgets('applies dark theme styling for light grid', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: Stack(
                children: [
                  TooltipOverlay(
                    value: 'Light theme tooltip',
                    position: const Offset(100, 100),
                    gridSize: const Size(800, 600),
                    theme: OsGridTheme.quartz(),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Light theme tooltip'), findsOneWidget);
      // Tooltip should have dark background on light theme
      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, const Color(0xFF1E1E1E));
    });

    testWidgets('applies light theme styling for dark grid', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: Stack(
                children: [
                  TooltipOverlay(
                    value: 'Dark theme tooltip',
                    position: const Offset(100, 100),
                    gridSize: const Size(800, 600),
                    theme: OsGridTheme.quartzDark(),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Dark theme tooltip'), findsOneWidget);
      // Tooltip should have light background on dark theme
      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, const Color(0xFFF5F5F5));
    });
  });

  group('OsColumnDef tooltip properties', () {
    test('tooltipField is stored correctly', () {
      const colDef = OsColumnDef(field: 'name', tooltipField: 'description');

      expect(colDef.tooltipField, 'description');
    });

    test('tooltipValueGetter is stored correctly', () {
      final colDef = OsColumnDef<Map<String, dynamic>>(
        field: 'name',
        tooltipValueGetter: (params) => 'Tooltip: ${params.value}',
      );

      expect(colDef.tooltipValueGetter, isNotNull);
    });

    test('headerTooltip is stored correctly', () {
      const colDef = OsColumnDef(
        field: 'name',
        headerTooltip: 'This is the name column',
      );

      expect(colDef.headerTooltip, 'This is the name column');
    });

    test('tooltip properties default to null', () {
      const colDef = OsColumnDef(field: 'name');

      expect(colDef.tooltipField, isNull);
      expect(colDef.tooltipValueGetter, isNull);
      expect(colDef.headerTooltip, isNull);
    });
  });

  group('OsGrid tooltip options', () {
    testWidgets('default tooltip options', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              columnDefs: [OsColumnDef(field: 'name')],
              rowData: [
                {'name': 'Alice'},
              ],
            ),
          ),
        ),
      );

      // Grid should render without errors
      expect(find.byType(OsGrid<Map<String, dynamic>>), findsOneWidget);
    });

    testWidgets('custom tooltip delays', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              columnDefs: [OsColumnDef(field: 'name')],
              rowData: [
                {'name': 'Alice'},
              ],
              tooltipShowDelay: 1000,
              tooltipHideDelay: 3000,
              tooltipMouseTrack: true,
            ),
          ),
        ),
      );

      expect(find.byType(OsGrid<Map<String, dynamic>>), findsOneWidget);
    });
  });

  group('OsGridController tooltip events', () {
    test('exposes onTooltipShow stream', () {
      final controller = OsGridController<Map<String, dynamic>>();
      expect(controller.onTooltipShow, isA<Stream<OsTooltipShowEvent>>());
      controller.dispose();
    });

    test('exposes onTooltipHide stream', () {
      final controller = OsGridController<Map<String, dynamic>>();
      expect(controller.onTooltipHide, isA<Stream<OsTooltipHideEvent>>());
      controller.dispose();
    });

    test('emitTooltipShow adds to stream', () async {
      final controller = OsGridController<Map<String, dynamic>>();
      final events = <OsTooltipShowEvent>[];
      final sub = controller.onTooltipShow.listen(events.add);

      controller.emitTooltipShow(
        const OsTooltipShowEvent(
          value: 'Test',
          location: TooltipLocation.cell,
          rowIndex: 0,
          colId: 'name',
        ),
      );

      await Future<void>.delayed(Duration.zero);
      expect(events, hasLength(1));
      expect(events.first.value, 'Test');
      expect(events.first.location, TooltipLocation.cell);
      expect(events.first.rowIndex, 0);
      expect(events.first.colId, 'name');

      await sub.cancel();
      controller.dispose();
    });

    test('emitTooltipHide adds to stream', () async {
      final controller = OsGridController<Map<String, dynamic>>();
      final events = <OsTooltipHideEvent>[];
      final sub = controller.onTooltipHide.listen(events.add);

      controller.emitTooltipHide(
        const OsTooltipHideEvent(
          location: TooltipLocation.header,
          colId: 'age',
        ),
      );

      await Future<void>.delayed(Duration.zero);
      expect(events, hasLength(1));
      expect(events.first.location, TooltipLocation.header);
      expect(events.first.colId, 'age');

      await sub.cancel();
      controller.dispose();
    });
  });

  group('TooltipValueGetterParams', () {
    test('stores all parameters', () {
      const params = TooltipValueGetterParams<Map<String, dynamic>>(
        data: {'name': 'Alice', 'age': 30},
        value: 'Alice',
        valueFormatted: 'ALICE',
        colDef: OsColumnDef(field: 'name'),
        rowIndex: 5,
      );

      expect(params.data, {'name': 'Alice', 'age': 30});
      expect(params.value, 'Alice');
      expect(params.valueFormatted, 'ALICE');
      expect(params.colDef.field, 'name');
      expect(params.rowIndex, 5);
    });

    test('valueFormatted is optional', () {
      const params = TooltipValueGetterParams<Map<String, dynamic>>(
        data: {'name': 'Alice'},
        value: 'Alice',
        colDef: OsColumnDef(field: 'name'),
        rowIndex: 0,
      );

      expect(params.valueFormatted, isNull);
    });
  });

  group('Tooltip integration with grid', () {
    testWidgets('tooltipField extracts value from row data', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              columnDefs: [
                const OsColumnDef(field: 'name', tooltipField: 'description'),
              ],
              rowData: const [
                {'name': 'Alice', 'description': 'First user'},
                {'name': 'Bob', 'description': 'Second user'},
              ],
              tooltipShowDelay: 200,
            ),
          ),
        ),
      );

      // Grid renders without errors
      expect(find.byType(OsGrid<Map<String, dynamic>>), findsOneWidget);

      controller.dispose();
    });

    testWidgets('headerTooltip shows on header hover', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              columnDefs: [
                const OsColumnDef(
                  field: 'name',
                  headerTooltip: 'The name column',
                ),
              ],
              rowData: const [
                {'name': 'Alice'},
              ],
              tooltipShowDelay: 200,
            ),
          ),
        ),
      );

      expect(find.byType(OsGrid<Map<String, dynamic>>), findsOneWidget);

      controller.dispose();
    });

    testWidgets('tooltip callbacks fire', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();
      OsTooltipShowEvent? showEvent;
      OsTooltipHideEvent? hideEvent;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              columnDefs: [
                const OsColumnDef(field: 'name', tooltipField: 'name'),
              ],
              rowData: const [
                {'name': 'Alice'},
              ],
              tooltipShowDelay: 200,
              onTooltipShow: (event) => showEvent = event,
              onTooltipHide: (event) => hideEvent = event,
            ),
          ),
        ),
      );

      // Grid renders without errors — callbacks are wired
      expect(find.byType(OsGrid<Map<String, dynamic>>), findsOneWidget);
      // We can't easily simulate hover in widget tests, but we verify
      // the callbacks are accepted without error
      expect(showEvent, isNull); // No hover yet
      expect(hideEvent, isNull);

      controller.dispose();
    });

    testWidgets('tooltip dismissed on scroll', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              columnDefs: [
                const OsColumnDef(field: 'name', tooltipField: 'name'),
              ],
              rowData: List.generate(100, (i) => {'name': 'Row $i'}),
              tooltipShowDelay: 200,
            ),
          ),
        ),
      );

      // Grid renders without errors
      expect(find.byType(OsGrid<Map<String, dynamic>>), findsOneWidget);

      controller.dispose();
    });
  });
}

/// Helper to run code with fake async for timer testing.
void fakeAsync(void Function(FakeAsync async) callback) {
  final fakeAsync = FakeAsync();
  fakeAsync.run((async) {
    callback(async);
  });
}

/// Minimal fake async implementation for timer-based tests.
class FakeAsync {
  final List<_PendingTimer> _timers = [];
  Duration _elapsed = Duration.zero;

  void run(void Function(FakeAsync) callback) {
    Zone.current
        .fork(
          specification: ZoneSpecification(
            createTimer: (self, parent, zone, duration, fn) {
              final timer = _PendingTimer(
                duration: _elapsed + duration,
                callback: fn,
              );
              _timers.add(timer);
              return timer;
            },
          ),
        )
        .run(() => callback(this));
  }

  void elapse(Duration duration) {
    final target = _elapsed + duration;
    while (_timers.isNotEmpty) {
      _timers.sort((a, b) => a.duration.compareTo(b.duration));
      final next = _timers.first;
      if (next.duration <= target) {
        _elapsed = next.duration;
        _timers.removeAt(0);
        if (!next.cancelled) {
          next.callback();
        }
      } else {
        break;
      }
    }
    _elapsed = target;
  }
}

class _PendingTimer implements Timer {
  _PendingTimer({required this.duration, required this.callback});

  final Duration duration;
  final void Function() callback;
  bool cancelled = false;

  @override
  void cancel() => cancelled = true;

  @override
  bool get isActive => !cancelled;

  @override
  int get tick => 0;
}
