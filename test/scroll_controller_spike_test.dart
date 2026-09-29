// Quality program v2 item 45 — ScrollController adoption spike tests.
//
// These exercise `VirtualisedGrid(useScrollController: true)`: the headless
// ScrollController/ScrollPosition path. The flag defaults to false, so every
// other suite in the repo keeps testing the legacy manual-offset path.
//
// Geometry used throughout: viewport 800x600, header 48px, rows 42px,
// 8 columns of 150px (center width 1200 > 800 so horizontal scroll works).
import 'dart:math' as math;
import 'dart:ui' show ImageByteFormat;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

const double _viewportWidth = 800;
const double _viewportHeight = 600;
const double _headerHeight = 48;
const double _rowHeight = 42;

double get _dataAreaHeight => _viewportHeight - _headerHeight;

Future<VirtualisedGridState> pumpSpikeGrid(
  WidgetTester tester, {
  required bool useController,
  int rows = 200,
  Key? gridKey,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: _viewportWidth,
          height: _viewportHeight,
          child: VirtualisedGrid(
            key: gridKey,
            columns: List.generate(8, (i) => OsColumnDef(field: 'c$i')),
            rowData: List.generate(rows, (i) => {'c0': 'row $i'}),
            useScrollController: useController,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return tester.state<VirtualisedGridState>(find.byType(VirtualisedGrid));
}

/// Sends a mouse wheel event over the centre of the grid.
Future<void> sendWheel(WidgetTester tester, Offset delta) async {
  final pointer = TestPointer(1, PointerDeviceKind.mouse);
  final center = tester.getCenter(find.byType(VirtualisedGrid));
  await tester.sendEventToBinding(pointer.hover(center));
  await tester.sendEventToBinding(pointer.scroll(delta));
  await tester.pump();
}

void main() {
  group('ScrollController spike — wheel', () {
    testWidgets('vertical wheel routes through the scroll position', (
      tester,
    ) async {
      final state = await pumpSpikeGrid(tester, useController: true);
      expect(state.usesControllerScrolling, isTrue);
      expect(state.debugScrollController, isNotNull);

      await sendWheel(tester, const Offset(0, 120));
      await tester.pump();

      // pointerScroll is instant under ClampingScrollPhysics.
      expect(state.currentScrollY, 120.0);
    });

    testWidgets('wheel clamps at maxScrollExtent', (tester) async {
      final state = await pumpSpikeGrid(tester, useController: true);
      final expectedMax = 200 * _rowHeight - _dataAreaHeight;

      await sendWheel(tester, const Offset(0, 99999));

      expect(state.currentScrollY, expectedMax);
      expect(state.currentScrollY, state.debugScrollController!.offset);
    });

    testWidgets('horizontal wheel component stays manual and works', (
      tester,
    ) async {
      final state = await pumpSpikeGrid(tester, useController: true);

      await sendWheel(tester, const Offset(30, 40));

      expect(state.currentScrollY, 40.0);
      expect(state.currentScrollX, 30.0);
    });

    testWidgets('flag off keeps the legacy manual path', (tester) async {
      final state = await pumpSpikeGrid(tester, useController: false);
      expect(state.usesControllerScrolling, isFalse);

      await sendWheel(tester, const Offset(0, 120));

      expect(state.currentScrollY, 120.0);
    });
  });

  group('ScrollController spike — pan drag', () {
    testWidgets('dragging content scrolls through the drag protocol', (
      tester,
    ) async {
      // Establish the reference behaviour on the legacy manual path first:
      // identical synthetic input must produce an identical offset. Each
      // leg gets a fresh element (unique key) so state reuse does not
      // migrate the first leg's offset into the second.
      await pumpSpikeGrid(tester, useController: false, gridKey: UniqueKey());
      await tester.drag(find.byType(VirtualisedGrid), const Offset(0, -150));
      await tester.pump(const Duration(milliseconds: 400));
      final legacyOffset = tester
          .state<VirtualisedGridState>(find.byType(VirtualisedGrid))
          .currentScrollY;
      expect(legacyOffset, greaterThan(0));

      final state = await pumpSpikeGrid(
        tester,
        useController: true,
        gridKey: UniqueKey(),
      );

      // Finger moves up 150px. The synthetic gesture carries no timed
      // velocity samples, so the release must settle dead on the dragged
      // distance (legacy parity).
      await tester.drag(find.byType(VirtualisedGrid), const Offset(0, -150));
      await tester.pump(const Duration(milliseconds: 400));

      expect(state.currentScrollY, legacyOffset);
      expect(state.isFlingActive, isFalse);
    });

    testWidgets('dragging clamps at the top bound', (tester) async {
      final state = await pumpSpikeGrid(tester, useController: true);

      await tester.drag(find.byType(VirtualisedGrid), const Offset(0, 500));
      await tester.pump(const Duration(milliseconds: 400));

      expect(state.currentScrollY, 0.0);
    });

    testWidgets('drag deltas match the legacy path exactly', (tester) async {
      // Multi-step drag: every post-slop delta must reach the scroll
      // position in controller mode just as it reached _scrollY before.
      // The offset is sampled BEFORE lifting the finger — the two modes
      // intentionally use different fling physics after release (that is
      // the point of the spike).
      await pumpSpikeGrid(tester, useController: false, gridKey: UniqueKey());
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(VirtualisedGrid)),
      );
      for (var i = 0; i < 6; i++) {
        await gesture.moveBy(const Offset(0, -40));
        await tester.pump(const Duration(milliseconds: 16));
      }
      final legacyOffset = tester
          .state<VirtualisedGridState>(find.byType(VirtualisedGrid))
          .currentScrollY;
      await gesture.up();
      await tester.pumpAndSettle();

      await pumpSpikeGrid(tester, useController: true, gridKey: UniqueKey());
      final gesture2 = await tester.startGesture(
        tester.getCenter(find.byType(VirtualisedGrid)),
      );
      for (var i = 0; i < 6; i++) {
        await gesture2.moveBy(const Offset(0, -40));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pump();
      final controllerOffset = tester
          .state<VirtualisedGridState>(find.byType(VirtualisedGrid))
          .currentScrollY;
      await gesture2.up();
      await tester.pumpAndSettle();

      expect(controllerOffset, legacyOffset);
      expect(legacyOffset, greaterThan(0));
    });
  });

  group('ScrollController spike — fling physics', () {
    testWidgets('release velocity drives a real ballistic glide', (
      tester,
    ) async {
      final state = await pumpSpikeGrid(tester, useController: true);

      // ~1000 px/s upward finger flick via timed drag (60Hz samples feed
      // the EMA velocity estimator).
      await tester.timedDrag(
        find.byType(VirtualisedGrid),
        const Offset(0, -80),
        const Duration(milliseconds: 80),
        frequency: 60,
      );
      await tester.pump();
      final afterDrag = state.currentScrollY;

      // Frames advance WITHOUT any pointer input: the physics simulation
      // owns the motion now.
      await tester.pump(const Duration(milliseconds: 16));
      final afterOneFrame = state.currentScrollY;
      await tester.pump(const Duration(milliseconds: 16));
      final afterTwoFrames = state.currentScrollY;

      expect(afterDrag, greaterThan(0));
      expect(afterOneFrame, greaterThan(afterDrag));
      expect(afterTwoFrames, greaterThan(afterOneFrame));

      // The hand-rolled decay ticker must NOT be the engine here.
      expect(state.isFlingActive, isFalse);

      // ...and it settles within range.
      await tester.pumpAndSettle();
      final settled = state.currentScrollY;
      expect(settled, greaterThanOrEqualTo(afterTwoFrames));
      expect(settled, lessThanOrEqualTo(200 * _rowHeight - _dataAreaHeight));
      await tester.pump(const Duration(milliseconds: 400));
    });
  });

  group('ScrollController spike — programmatic + keyboard', () {
    testWidgets('ensureIndexVisible command jumps via jumpTo', (tester) async {
      final commands = ValueNotifier<ScrollCommand?>(null);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: _viewportWidth,
              height: _viewportHeight,
              child: VirtualisedGrid(
                columns: List.generate(8, (i) => OsColumnDef(field: 'c$i')),
                rowData: List.generate(200, (i) => {'c0': 'row $i'}),
                useScrollController: true,
                scrollCommandNotifier: commands,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      commands.value = const EnsureIndexVisibleCommand(
        rowIndex: 100,
        position: RowScrollPosition.top,
      );
      await tester.pump();
      commands.value = null;
      await tester.pump();

      // Row 100 top = 100 * 42 = 4200.
      expect(
        tester
            .state<VirtualisedGridState>(find.byType(VirtualisedGrid))
            .currentScrollY,
        4200.0,
      );
    });

    testWidgets('PageDown moves focus and scrolls it into view', (
      tester,
    ) async {
      final focused = ValueNotifier<({int row, int col})>((row: 0, col: 0));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: _viewportWidth,
              height: _viewportHeight,
              child: VirtualisedGrid(
                columns: List.generate(8, (i) => OsColumnDef(field: 'c$i')),
                rowData: List.generate(200, (i) => {'c0': 'row $i'}),
                useScrollController: true,
                focusedCellNotifier: focused,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Tap a cell to focus the grid.
      final origin = tester.getTopLeft(find.byType(VirtualisedGrid));
      await tester.tapAt(origin + const Offset(75, _headerHeight + 21));
      await tester.pump(const Duration(milliseconds: 400));

      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await tester.pump();

      const pageSize = 13; // floor(552 / 42)
      expect(focused.value.row, pageSize);
      // Row 13 bottom (14*42=588) exceeds data area bottom (48+552=600? no:
      // rowBottom > scrollY + 552 → 588 > 552) → scroll to 588 - 552 = 36.
      expect(
        tester
            .state<VirtualisedGridState>(find.byType(VirtualisedGrid))
            .currentScrollY,
        (pageSize + 1) * _rowHeight - _dataAreaHeight,
      );
      await tester.pump(const Duration(milliseconds: 400));
    });
  });

  group('ScrollController spike — scrollbar', () {
    testWidgets('vertical scrollbar thumb drag still functions', (
      tester,
    ) async {
      final state = await pumpSpikeGrid(tester, useController: true);

      const thickness = 8.0;
      const minThumb = 30.0;
      const trackTop = _headerHeight;
      final trackHeight = _dataAreaHeight - thickness;
      final thumbRatio = _dataAreaHeight / (200 * _rowHeight);
      final thumbHeight = math.max(minThumb, trackHeight * thumbRatio);
      final availableTrack = trackHeight - thumbHeight;
      final maxScrollY = 200 * _rowHeight - _dataAreaHeight;

      // Grab the thumb at its rest position (scrollY = 0) and drag halfway
      // down the free track.
      final start = Offset(
        _viewportWidth - thickness,
        trackTop + thumbHeight / 2,
      );
      final gesture = await tester.startGesture(start);
      await gesture.moveBy(Offset(0, availableTrack / 2));
      await tester.pump();
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 400));

      final expected = (availableTrack / 2 / availableTrack) * maxScrollY;
      expect(state.currentScrollY, closeTo(expected, 3.0));
    });

    testWidgets('track jump still functions', (tester) async {
      final state = await pumpSpikeGrid(tester, useController: true);

      // Press near the very bottom of the vertical track and nudge past
      // slop: the initial press must JUMP to that ratio, then follow drag.
      await tester
          .startGesture(const Offset(_viewportWidth - 4, _viewportHeight - 20))
          .then((gesture) async {
            await gesture.moveBy(const Offset(0, -30));
            await tester.pump();
            await gesture.up();
          });
      await tester.pump(const Duration(milliseconds: 400));

      // Track x-position maps to ~97% of the range.
      expect(state.currentScrollY, greaterThan(6000));
      expect(
        state.currentScrollY,
        lessThanOrEqualTo(200 * _rowHeight - _dataAreaHeight),
      );
    });
  });

  group('ScrollController spike — runtime toggle', () {
    testWidgets('turning the flag off migrates the offset to manual', (
      tester,
    ) async {
      VirtualisedGrid buildGrid(bool useController) => VirtualisedGrid(
        columns: List.generate(8, (i) => OsColumnDef(field: 'c$i')),
        rowData: List.generate(200, (i) => {'c0': 'row $i'}),
        useScrollController: useController,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(width: 800, height: 600, child: buildGrid(true)),
          ),
        ),
      );
      await tester.pump();
      var state = tester.state<VirtualisedGridState>(
        find.byType(VirtualisedGrid),
      );
      await sendWheel(tester, const Offset(0, 300));
      expect(state.currentScrollY, 300.0);

      // Flip the flag off at runtime.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(width: 800, height: 600, child: buildGrid(false)),
          ),
        ),
      );
      await tester.pump();
      state = tester.state<VirtualisedGridState>(find.byType(VirtualisedGrid));
      expect(state.usesControllerScrolling, isFalse);
      expect(state.currentScrollY, 300.0);

      // Legacy path still scrolls from the migrated offset.
      await sendWheel(tester, const Offset(0, 50));
      expect(state.currentScrollY, 350.0);
    });
  });

  group('ScrollController spike — paint parity', () {
    Future<Uint8List> capturePng(WidgetTester tester) async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byType(RepaintBoundary).first,
      );
      // Rasterisation needs real async — the fake-async zone never pumps
      // the raster thread, and toImage would block forever without this.
      final data = await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        return image.toByteData(format: ImageByteFormat.png);
      });
      return data!.buffer.asUint8List();
    }

    testWidgets('flag on paints byte-identical output to flag off', (
      tester,
    ) async {
      Uint8List flagOffPng;
      {
        await pumpSpikeGrid(tester, useController: false, gridKey: UniqueKey());
        await sendWheel(tester, const Offset(0, 210));
        flagOffPng = await capturePng(tester);
      }

      Uint8List flagOnPng;
      {
        await pumpSpikeGrid(tester, useController: true, gridKey: UniqueKey());
        await sendWheel(tester, const Offset(0, 210));
        flagOnPng = await capturePng(tester);
      }

      expect(flagOnPng.length, greaterThan(0));
      expect(listEquals(flagOffPng, flagOnPng), isTrue);
    });
  });
}
