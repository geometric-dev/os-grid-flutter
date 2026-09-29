import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

void main() {
  group('Column drag-to-reorder', () {
    testWidgets('renders grid with draggable headers', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              columnDefs: [
                OsColumnDef(field: 'a', headerName: 'A'),
                OsColumnDef(field: 'b', headerName: 'B'),
                OsColumnDef(field: 'c', headerName: 'C'),
              ],
              rowData: [
                {'a': 1, 'b': 2, 'c': 3},
              ],
            ),
          ),
        ),
      );

      // Grid should render without errors
      expect(find.byType(OsGrid<Map<String, dynamic>>), findsOneWidget);
    });

    testWidgets('dragging a header reorders columns', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();
      OsColumnMovedEvent? movedEvent;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              height: 400,
              child: OsGrid<Map<String, dynamic>>(
                controller: controller,
                columnDefs: const [
                  OsColumnDef(field: 'a', headerName: 'A', width: 150),
                  OsColumnDef(field: 'b', headerName: 'B', width: 150),
                  OsColumnDef(field: 'c', headerName: 'C', width: 150),
                ],
                rowData: const [
                  {'a': 1, 'b': 2, 'c': 3},
                ],
                onColumnMoved: (event) => movedEvent = event,
              ),
            ),
          ),
        ),
      );

      // Drag column A (at x=75, header area y=24) to column C position (x=375)
      final gridFinder = find.byType(VirtualisedGrid);
      final gridBox = tester.renderObject(gridFinder) as RenderBox;
      final gridTopLeft = gridBox.localToGlobal(Offset.zero);

      // Start drag at column A header centre (75, 24)
      final startPos = gridTopLeft + const Offset(75, 24);

      // Use dragFrom with mouse kind for smaller pan slop
      await tester.dragFrom(
        startPos,
        const Offset(300, 0), // Drag 300px to the right (into column C area)
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();

      // Verify the column was moved
      expect(movedEvent, isNotNull);

      // Verify the new column order
      final displayed = controller.getAllDisplayedColumns();
      // Column A should have moved to after C
      expect(displayed[0].effectiveColId, 'b');
      expect(displayed[1].effectiveColId, 'c');
      expect(displayed[2].effectiveColId, 'a');

      controller.dispose();
    });

    testWidgets('pinned columns are not draggable', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();
      OsColumnMovedEvent? movedEvent;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              height: 400,
              child: OsGrid<Map<String, dynamic>>(
                controller: controller,
                columnDefs: const [
                  OsColumnDef(
                    field: 'pinned',
                    headerName: 'Pinned',
                    width: 150,
                    pinned: OsColumnPin.left,
                  ),
                  OsColumnDef(field: 'b', headerName: 'B', width: 150),
                  OsColumnDef(field: 'c', headerName: 'C', width: 150),
                ],
                rowData: const [
                  {'pinned': 1, 'b': 2, 'c': 3},
                ],
                onColumnMoved: (event) => movedEvent = event,
              ),
            ),
          ),
        ),
      );

      // Try to drag the pinned column (at x=75, y=24)
      final gridFinder = find.byType(VirtualisedGrid);
      final gridBox = tester.renderObject(gridFinder) as RenderBox;
      final gridTopLeft = gridBox.localToGlobal(Offset.zero);

      final startPos = gridTopLeft + const Offset(75, 24);

      await tester.dragFrom(
        startPos,
        const Offset(300, 0),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();

      // The column should NOT have moved
      expect(movedEvent, isNull);

      // Order should be unchanged
      final displayed = controller.getAllDisplayedColumns();
      expect(displayed[0].effectiveColId, 'pinned');
      expect(displayed[1].effectiveColId, 'b');
      expect(displayed[2].effectiveColId, 'c');

      controller.dispose();
    });

    testWidgets('suppressMovable columns are not draggable', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();
      OsColumnMovedEvent? movedEvent;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              height: 400,
              child: OsGrid<Map<String, dynamic>>(
                controller: controller,
                columnDefs: const [
                  OsColumnDef(
                    field: 'locked',
                    headerName: 'Locked',
                    width: 150,
                    suppressMovable: true,
                  ),
                  OsColumnDef(field: 'b', headerName: 'B', width: 150),
                  OsColumnDef(field: 'c', headerName: 'C', width: 150),
                ],
                rowData: const [
                  {'locked': 1, 'b': 2, 'c': 3},
                ],
                onColumnMoved: (event) => movedEvent = event,
              ),
            ),
          ),
        ),
      );

      // Try to drag the suppressMovable column (at x=75, y=24)
      final gridFinder = find.byType(VirtualisedGrid);
      final gridBox = tester.renderObject(gridFinder) as RenderBox;
      final gridTopLeft = gridBox.localToGlobal(Offset.zero);

      final startPos = gridTopLeft + const Offset(75, 24);

      await tester.dragFrom(
        startPos,
        const Offset(300, 0),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();

      // The column should NOT have moved
      expect(movedEvent, isNull);

      // Order should be unchanged
      final displayed = controller.getAllDisplayedColumns();
      expect(displayed[0].effectiveColId, 'locked');
      expect(displayed[1].effectiveColId, 'b');
      expect(displayed[2].effectiveColId, 'c');

      controller.dispose();
    });

    testWidgets('drag below threshold does not reorder', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();
      OsColumnMovedEvent? movedEvent;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              height: 400,
              child: OsGrid<Map<String, dynamic>>(
                controller: controller,
                columnDefs: const [
                  OsColumnDef(field: 'a', headerName: 'A', width: 150),
                  OsColumnDef(field: 'b', headerName: 'B', width: 150),
                ],
                rowData: const [
                  {'a': 1, 'b': 2},
                ],
                onColumnMoved: (event) => movedEvent = event,
              ),
            ),
          ),
        ),
      );

      // Drag only 3px (below the pan slop, so the pan gesture won't even fire)
      final gridFinder = find.byType(VirtualisedGrid);
      final gridBox = tester.renderObject(gridFinder) as RenderBox;
      final gridTopLeft = gridBox.localToGlobal(Offset.zero);

      final startPos = gridTopLeft + const Offset(75, 24);

      // Use touchSlopX of 0 to bypass the framework's slop, but our 5px
      // threshold should still prevent the drag from starting
      await tester.dragFrom(
        startPos,
        const Offset(3, 0),
        kind: PointerDeviceKind.mouse,
        touchSlopX: 0,
        touchSlopY: 0,
      );
      await tester.pumpAndSettle();

      // No move should have occurred
      expect(movedEvent, isNull);

      // Order unchanged
      final displayed = controller.getAllDisplayedColumns();
      expect(displayed[0].effectiveColId, 'a');
      expect(displayed[1].effectiveColId, 'b');

      controller.dispose();
    });

    testWidgets('dragging to same position does not fire event', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();
      OsColumnMovedEvent? movedEvent;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              height: 400,
              child: OsGrid<Map<String, dynamic>>(
                controller: controller,
                columnDefs: const [
                  OsColumnDef(field: 'a', headerName: 'A', width: 150),
                  OsColumnDef(field: 'b', headerName: 'B', width: 150),
                  OsColumnDef(field: 'c', headerName: 'C', width: 150),
                ],
                rowData: const [
                  {'a': 1, 'b': 2, 'c': 3},
                ],
                onColumnMoved: (event) => movedEvent = event,
              ),
            ),
          ),
        ),
      );

      // Drag column A slightly right but still within its own area
      final gridFinder = find.byType(VirtualisedGrid);
      final gridBox = tester.renderObject(gridFinder) as RenderBox;
      final gridTopLeft = gridBox.localToGlobal(Offset.zero);

      final startPos = gridTopLeft + const Offset(75, 24);
      // Move 20px right (past pan slop and our threshold) but still within
      // column A's midpoint (75px from left edge). Drop target = index 0 = same.
      await tester.dragFrom(
        startPos,
        const Offset(20, 0),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();

      // No move event should fire (same position)
      expect(movedEvent, isNull);

      controller.dispose();
    });

    testWidgets('programmatic moveColumnByIndex still works', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();
      OsColumnMovedEvent? movedEvent;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              height: 400,
              child: OsGrid<Map<String, dynamic>>(
                controller: controller,
                columnDefs: const [
                  OsColumnDef(field: 'a', headerName: 'A', width: 150),
                  OsColumnDef(field: 'b', headerName: 'B', width: 150),
                  OsColumnDef(field: 'c', headerName: 'C', width: 150),
                ],
                rowData: const [
                  {'a': 1, 'b': 2, 'c': 3},
                ],
                onColumnMoved: (event) => movedEvent = event,
              ),
            ),
          ),
        ),
      );

      // Use the programmatic API
      controller.moveColumnByIndex(0, 2);
      await tester.pump();

      expect(movedEvent, isNotNull);
      expect(movedEvent!.toIndex, 2);

      final displayed = controller.getAllDisplayedColumns();
      expect(displayed[0].effectiveColId, 'b');
      expect(displayed[1].effectiveColId, 'c');
      expect(displayed[2].effectiveColId, 'a');

      controller.dispose();
    });
  });
}
