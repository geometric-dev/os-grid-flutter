import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

void main() {
  // Starts a row drag on the drag-handle column (32px, pinned left).
  //
  // The pan recognizer engages a move or two AFTER the pointer goes down and
  // hit-tests the CURRENT pointer position, so the two engagement moves must
  // stay inside the data area on the handle column before moving to edges.
  Future<TestGesture> startRowDrag(
    WidgetTester tester,
    Offset gridTopLeft,
    Offset downAt,
  ) async {
    final gesture = await tester.startGesture(
      gridTopLeft + downAt,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    await gesture.moveBy(const Offset(0, 10));
    await tester.pump();
    await gesture.moveBy(const Offset(0, 50));
    await tester.pump();
    return gesture;
  }

  Widget grid({
    required void Function(OsRowDragMoveEvent<Map<String, dynamic>>)?
    onRowDragMove,
    required void Function(OsRowDragEndEvent<Map<String, dynamic>>)?
    onRowDragEnd,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 600,
          height: 400,
          child: OsGrid<Map<String, dynamic>>(
            rowDrag: true,
            rowDragManaged: false,
            columnDefs: const [
              OsColumnDef(field: 'name', headerName: 'Name', width: 200),
            ],
            rowData: [
              for (var i = 0; i < 100; i++) {'name': 'Row $i'},
            ],
            onRowDragMove: onRowDragMove,
            onRowDragEnd: onRowDragEnd,
          ),
        ),
      ),
    );
  }

  VirtualisedGridState stateOf(WidgetTester tester) =>
      tester.state<VirtualisedGridState>(find.byType(VirtualisedGrid));

  Offset gridOrigin(WidgetTester tester) =>
      (tester.renderObject(find.byType(VirtualisedGrid)) as RenderBox)
          .localToGlobal(Offset.zero);

  testWidgets('row drag auto-scrolls down when held near the bottom edge', (
    tester,
  ) async {
    final moveEvents = <OsRowDragMoveEvent<Map<String, dynamic>>>[];
    OsRowDragEndEvent<Map<String, dynamic>>? dragEndEvent;

    await tester.pumpWidget(
      grid(
        onRowDragMove: moveEvents.add,
        onRowDragEnd: (event) => dragEndEvent = event,
      ),
    );
    await tester.pumpAndSettle();

    final gridTopLeft = gridOrigin(tester);
    final state = stateOf(tester);

    final gesture = await startRowDrag(
      tester,
      gridTopLeft,
      const Offset(16, 69),
    );
    addTearDown(gesture.removePointer);

    // Hold the pointer inside the bottom edge zone (8px from the edge).
    await gesture.moveTo(gridTopLeft + const Offset(16, 392));
    await tester.pump();

    final scrolledBefore = state.scrollY;
    // ~20 auto-scroll ticks at 6px each.
    await tester.pump(const Duration(milliseconds: 320));

    expect(state.scrollY, greaterThan(scrolledBefore));

    // While the pointer was stationary, scrolling content under it must
    // still have emitted move events with a growing overIndex.
    expect(moveEvents, isNotEmpty);
    expect(moveEvents.last.overIndex, greaterThan(5));

    // Move back to the middle of the data area — auto-scroll must stop.
    await gesture.moveTo(gridTopLeft + const Offset(16, 200));
    await tester.pump();
    final stoppedAt = state.scrollY;
    await tester.pump(const Duration(milliseconds: 320));
    expect(state.scrollY, stoppedAt);

    // Drop: the target row reflects the scrolled content position.
    await gesture.up();
    await tester.pump();
    await tester.pumpAndSettle();

    expect(dragEndEvent, isNotNull);
    expect(dragEndEvent!.toIndex, greaterThan(4));
  });

  testWidgets('row drag auto-scrolls up when held near the top edge while '
      'scrolled', (tester) async {
    OsRowDragEndEvent<Map<String, dynamic>>? dragEndEvent;

    await tester.pumpWidget(
      grid(onRowDragMove: null, onRowDragEnd: (event) => dragEndEvent = event),
    );
    await tester.pumpAndSettle();

    // Pre-scroll the grid down by ~300px.
    await tester.drag(find.byType(VirtualisedGrid), const Offset(0, -300));
    await tester.pumpAndSettle();

    final gridTopLeft = gridOrigin(tester);
    final state = stateOf(tester);
    expect(state.scrollY, greaterThan(0));

    // Engage the drag mid-data-area, then hold inside the top edge zone
    // (which begins 30px below the 48px header).
    final gesture = await startRowDrag(
      tester,
      gridTopLeft,
      const Offset(16, 200),
    );
    addTearDown(gesture.removePointer);
    await gesture.moveTo(gridTopLeft + const Offset(16, 60));
    await tester.pump();

    final scrolledBefore = state.scrollY;
    await tester.pump(const Duration(milliseconds: 320));

    expect(state.scrollY, lessThan(scrolledBefore));

    await gesture.up();
    await tester.pump();
    await tester.pumpAndSettle();
    expect(dragEndEvent, isNotNull);
  });

  testWidgets('no auto-scroll while the pointer rests mid-data-area', (
    tester,
  ) async {
    await tester.pumpWidget(grid(onRowDragMove: null, onRowDragEnd: null));
    await tester.pumpAndSettle();

    final gridTopLeft = gridOrigin(tester);
    final state = stateOf(tester);

    final gesture = await startRowDrag(
      tester,
      gridTopLeft,
      const Offset(16, 69),
    );
    addTearDown(gesture.removePointer);

    // Rest in the middle of the data area.
    await gesture.moveTo(gridTopLeft + const Offset(16, 200));
    await tester.pump();

    await tester.pump(const Duration(milliseconds: 320));
    expect(state.scrollY, 0);

    await gesture.up();
    await tester.pump();
  });
}
