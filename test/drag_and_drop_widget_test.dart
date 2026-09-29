import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

/// Widget-level tests for the external drag-and-drop integration — the
/// paths the unit tests for `DragAndDropService` cannot reach: the grid's
/// DragTarget wrapper (drop-in) and the row-drag coordinator's drag-out
/// detection.
///
/// Regression guard for the drag-out fix: exiting through ANY grid edge
/// fires `onRowDragOut` — the old check only tested the vertical edges, so
/// dragging a row onto an external side panel (the primary use case) never
/// fired.
void main() {
  Widget buildGrid({
    required ValueChanged<OsRowDragOutEvent<Map<String, dynamic>>>?
    onRowDragOut,
    ValueChanged<OsExternalDropEvent>? onExternalDrop,
    OsDragAndDrop? dragAndDrop,
    bool rowDrag = true,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 600,
          height: 400,
          child: OsGrid<Map<String, dynamic>>(
            rowDrag: rowDrag,
            dragAndDrop: dragAndDrop,
            onRowDragOut: onRowDragOut,
            onExternalDrop: onExternalDrop,
            columnDefs: const [
              OsColumnDef(field: 'name', headerName: 'Name', width: 200),
            ],
            rowData: [
              {'name': 'Alice'},
              {'name': 'Bob'},
              {'name': 'Charlie'},
            ],
          ),
        ),
      ),
    );
  }

  /// Drags the row-0 drag handle (32px pinned column, row 0 at y=69) by
  /// [delta] with mouse semantics and settles.
  Future<void> dragRowHandle(WidgetTester tester, Offset delta) async {
    final gridBox =
        tester.renderObject(find.byType(VirtualisedGrid)) as RenderBox;
    final gridTopLeft = gridBox.localToGlobal(Offset.zero);
    final gesture = await tester.startGesture(
      gridTopLeft + const Offset(16, 69),
      kind: PointerDeviceKind.mouse,
    );
    // Flush the double-tap arena (gotcha 4): pan updates only reach the
    // grid once the arena resolves past the double-tap timeout.
    await tester.pump(const Duration(milliseconds: 400));
    // Two slop moves before the real delta: the pan recognizer consumes
    // the first moves crossing touch slop, and updates reach the grid's
    // drag handler from the following move onward.
    await gesture.moveBy(const Offset(0, 10));
    await tester.pump();
    await gesture.moveBy(const Offset(0, 30));
    await tester.pump();
    await gesture.moveBy(delta);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
  }

  group('drag-out (row exits grid bounds)', () {
    testWidgets('fires onRowDragOut when the drag exits horizontally', (
      tester,
    ) async {
      OsRowDragOutEvent<Map<String, dynamic>>? outEvent;
      await tester.pumpWidget(
        buildGrid(
          onRowDragOut: (event) => outEvent = event,
          dragAndDrop: const OsDragAndDrop(enableDragOut: true),
        ),
      );
      await tester.pumpAndSettle();

      // Drag left past the grid's left edge.
      await dragRowHandle(tester, const Offset(-100, 0));

      expect(outEvent, isNotNull);
      expect(outEvent!.rowIndex, 0);
      expect(outEvent!.data['name'], 'Alice');
      // The reported global position is outside the grid's left edge.
      final gridBox =
          tester.renderObject(find.byType(VirtualisedGrid)) as RenderBox;
      final gridLeft = gridBox.localToGlobal(Offset.zero).dx;
      expect(outEvent!.globalPosition.dx, lessThan(gridLeft));
    });

    testWidgets('fires onRowDragOut when the drag exits the top edge', (
      tester,
    ) async {
      OsRowDragOutEvent<Map<String, dynamic>>? outEvent;
      await tester.pumpWidget(
        buildGrid(
          onRowDragOut: (event) => outEvent = event,
          dragAndDrop: const OsDragAndDrop(enableDragOut: true),
        ),
      );
      await tester.pumpAndSettle();

      await dragRowHandle(tester, const Offset(0, -120));

      expect(outEvent, isNotNull);
      expect(outEvent!.rowIndex, 0);
    });

    testWidgets('does not fire while the drag stays inside the grid', (
      tester,
    ) async {
      OsRowDragOutEvent<Map<String, dynamic>>? outEvent;
      OsRowDragEndEvent<Map<String, dynamic>>? endEvent;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              height: 400,
              child: OsGrid<Map<String, dynamic>>(
                rowDrag: true,
                dragAndDrop: const OsDragAndDrop(enableDragOut: true),
                onRowDragOut: (event) => outEvent = event,
                onRowDragEnd: (event) => endEvent = event,
                columnDefs: const [
                  OsColumnDef(field: 'name', headerName: 'Name', width: 200),
                ],
                rowData: [
                  {'name': 'Alice'},
                  {'name': 'Bob'},
                  {'name': 'Charlie'},
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // A pure in-grid reorder drag (down two rows) must not fire drag-out.
      await dragRowHandle(tester, const Offset(0, 84));

      expect(outEvent, isNull);
      expect(endEvent, isNotNull);
    });

    testWidgets('does not fire when enableDragOut is off', (tester) async {
      OsRowDragOutEvent<Map<String, dynamic>>? outEvent;
      await tester.pumpWidget(
        buildGrid(
          onRowDragOut: (event) => outEvent = event,
          dragAndDrop: const OsDragAndDrop(enableDropIn: true),
        ),
      );
      await tester.pumpAndSettle();

      await dragRowHandle(tester, const Offset(-100, 0));

      expect(outEvent, isNull);
    });
  });

  group('drop-in (external Draggable onto grid)', () {
    // Pointer-driven Draggable gestures proved timing-flaky under the test
    // binding (the drop sometimes resolved at the drag-start position), so
    // these tests invoke the grid's DragTarget callbacks directly — the
    // code under test is the grid's own drop handling (index computation,
    // indicator state, event emission), not Flutter's DragTarget plumbing.

    /// Pumps a grid with drop-in enabled below a placeholder source, and
    /// returns the grid's global top-left.
    Future<Offset> pumpDropInGrid(
      WidgetTester tester, {
      ValueChanged<OsExternalDropEvent>? onExternalDrop,
      OsDragAndDrop? dragAndDrop,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                const SizedBox(height: 60, child: Text('external source')),
                Expanded(
                  child: buildGrid(
                    onRowDragOut: null,
                    onExternalDrop: onExternalDrop,
                    dragAndDrop: dragAndDrop,
                    rowDrag: false,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final gridBox =
          tester.renderObject(find.byType(VirtualisedGrid)) as RenderBox;
      return gridBox.localToGlobal(Offset.zero);
    }

    testWidgets('drop at row 1 computes the target row and emits the event', (
      tester,
    ) async {
      OsExternalDropEvent? dropEvent;
      final gridTopLeft = await pumpDropInGrid(
        tester,
        onExternalDrop: (event) => dropEvent = event,
        dragAndDrop: const OsDragAndDrop(enableDropIn: true),
      );

      expect(find.byType(DragTarget<Object>), findsOneWidget);

      final target = tester.widget<DragTarget<Object>>(
        find.byType(DragTarget<Object>),
      );
      // Row 1 centre: header (48) + 1.5 rows (42 each) below the grid top.
      target.onAcceptWithDetails!(
        DragTargetDetails<Object>(
          data: 'external-item',
          offset: gridTopLeft + const Offset(100, 48 + 1.5 * 42),
        ),
      );
      await tester.pumpAndSettle();

      expect(dropEvent, isNotNull);
      expect(dropEvent!.targetRowIndex, 1);
      expect(dropEvent!.dragData, 'external-item');
    });

    testWidgets('drop above the data area clamps to row 0', (tester) async {
      OsExternalDropEvent? dropEvent;
      final gridTopLeft = await pumpDropInGrid(
        tester,
        onExternalDrop: (event) => dropEvent = event,
        dragAndDrop: const OsDragAndDrop(enableDropIn: true),
      );

      final target = tester.widget<DragTarget<Object>>(
        find.byType(DragTarget<Object>),
      );
      target.onAcceptWithDetails!(
        DragTargetDetails<Object>(
          data: 'x',
          offset: gridTopLeft + const Offset(50, 10),
        ),
      );
      await tester.pumpAndSettle();

      expect(dropEvent, isNotNull);
      expect(dropEvent!.targetRowIndex, 0);
    });

    testWidgets('hover shows the drop indicator, leave clears it', (
      tester,
    ) async {
      final gridTopLeft = await pumpDropInGrid(
        tester,
        dragAndDrop: const OsDragAndDrop(enableDropIn: true),
      );

      final target = tester.widget<DragTarget<Object>>(
        find.byType(DragTarget<Object>),
      );
      expect(target.onMove, isNotNull);

      // The hover state machine: willAccept arms the hover flag, move sets
      // the target row, leave clears both.
      target.onWillAcceptWithDetails!(
        DragTargetDetails<Object>(data: 'x', offset: gridTopLeft),
      );
      target.onMove!(
        DragTargetDetails<Object>(
          data: 'x',
          offset: gridTopLeft + const Offset(100, 48 + 2.5 * 42),
        ),
      );
      await tester.pump();

      // The drop indicator is a 2px-tall full-width Positioned line.
      final indicator = find.byWidgetPredicate(
        (w) => w is Positioned && w.height == 2.0,
      );
      expect(indicator, findsOneWidget);

      target.onLeave!.call('x');
      await tester.pump();
      expect(indicator, findsNothing);
    });

    testWidgets('drop-in disabled: no DragTarget in the tree', (tester) async {
      await pumpDropInGrid(tester, dragAndDrop: null);
      expect(find.byType(DragTarget<Object>), findsNothing);
    });
  });
}
