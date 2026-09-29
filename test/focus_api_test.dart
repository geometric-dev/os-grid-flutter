import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: SizedBox(width: 800, height: 600, child: child)),
);

/// Taps the data cell at [row]/[col] (default layout: 48px header, 42px
/// rows, 150px columns). A timed pump flushes the double-tap recognizer's
/// countdown timer.
Future<void> focusCellByTap(WidgetTester tester, int row, int col) async {
  final box = tester.renderObject(find.byType(VirtualisedGrid)) as RenderBox;
  await tester.tapAt(
    box.localToGlobal(Offset(150.0 * col + 75, 48.0 + row * 42 + 21)),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump();
}

void main() {
  group('Focus API — get/set/clear round-trip', () {
    testWidgets('null before any interaction, populated by tap and set', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();
      await tester.pumpWidget(
        _wrap(
          OsGrid<Map<String, dynamic>>(
            controller: controller,
            columnDefs: const [
              OsColumnDef(field: 'a'),
              OsColumnDef(field: 'b'),
              OsColumnDef(field: 'c'),
            ],
            rowData: List.generate(
              5,
              (i) => {'a': '$i-a', 'b': '$i-b', 'c': '$i-c'},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Nothing focused yet.
      expect(controller.getFocusedCell(), isNull);

      // Pointer-down focus populates it.
      await focusCellByTap(tester, 0, 1);
      expect(controller.getFocusedCell(), (rowIndex: 0, columnIndex: 1));

      // Programmatic move round-trips.
      controller.setFocusedCell(rowIndex: 2, columnIndex: 2);
      await tester.pump();
      await tester.pump();
      expect(controller.getFocusedCell(), (rowIndex: 2, columnIndex: 2));

      // Out-of-bounds target is clamped to the grid bounds.
      controller.setFocusedCell(rowIndex: 99, columnIndex: -3);
      await tester.pump();
      await tester.pump();
      expect(controller.getFocusedCell(), (rowIndex: 4, columnIndex: 0));

      controller.dispose();
    });

    testWidgets('clearFocusedCell resets the API value', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();
      await tester.pumpWidget(
        _wrap(
          OsGrid<Map<String, dynamic>>(
            controller: controller,
            columnDefs: const [OsColumnDef(field: 'a')],
            rowData: const [
              {'a': 'x'},
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      await focusCellByTap(tester, 0, 0);
      expect(controller.getFocusedCell(), isNotNull);

      controller.clearFocusedCell();
      await tester.pump();
      await tester.pump();
      expect(controller.getFocusedCell(), isNull);

      controller.dispose();
    });

    testWidgets('keyboard navigation updates the focused cell', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();
      await tester.pumpWidget(
        _wrap(
          OsGrid<Map<String, dynamic>>(
            controller: controller,
            columnDefs: const [
              OsColumnDef(field: 'a'),
              OsColumnDef(field: 'b'),
            ],
            rowData: List.generate(5, (i) => {'a': i, 'b': i}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await focusCellByTap(tester, 0, 0);
      expect(controller.getFocusedCell(), (rowIndex: 0, columnIndex: 0));

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      await tester.pump();
      expect(controller.getFocusedCell(), (rowIndex: 1, columnIndex: 1));

      controller.dispose();
    });
  });

  group('onCellFocused event', () {
    testWidgets('fires once per arrow-key change on stream and callback', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();
      final streamEvents = <OsCellFocusedEvent>[];
      final callbackEvents = <OsCellFocusedEvent>[];
      // NOTE: intentionally not cancelled — awaiting StreamSubscription
      // .cancel() inside testWidgets deadlocks teardown on this SDK.
      final sub = controller.onCellFocused.listen(streamEvents.add);

      await tester.pumpWidget(
        _wrap(
          OsGrid<Map<String, dynamic>>(
            controller: controller,
            columnDefs: const [
              OsColumnDef(field: 'a'),
              OsColumnDef(field: 'b'),
            ],
            rowData: List.generate(5, (i) => {'a': i, 'b': i}),
            onCellFocused: callbackEvents.add,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await focusCellByTap(tester, 0, 0);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.pump();

      // Exactly one event per change, with the post-change position.
      expect(callbackEvents, hasLength(1));
      expect(callbackEvents.first.rowIndex, 1);
      expect(callbackEvents.first.columnIndex, 0);
      expect(streamEvents, hasLength(1));
      expect(streamEvents.first.rowIndex, 1);
      expect(streamEvents.first.columnIndex, 0);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      await tester.pump();

      expect(callbackEvents, hasLength(2));
      expect(callbackEvents.last.rowIndex, 1);
      expect(callbackEvents.last.columnIndex, 1);
      expect(streamEvents, hasLength(2));

      // Moving nowhere fires nothing.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      await tester.pump();
      expect(callbackEvents, hasLength(2));

      // ignore: unawaited_futures
      sub.cancel();
      controller.dispose();
    });
  });

  group('onCellKeyDown event', () {
    testWidgets('navigation key payload is sane', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();
      final events = <OsCellKeyDownEvent>[];
      await tester.pumpWidget(
        _wrap(
          OsGrid<Map<String, dynamic>>(
            controller: controller,
            columnDefs: const [
              OsColumnDef(field: 'a'),
              OsColumnDef(field: 'b'),
            ],
            rowData: List.generate(5, (i) => {'a': i, 'b': i}),
            onCellKeyDown: events.add,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await focusCellByTap(tester, 1, 0);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.pump();

      expect(events, hasLength(1));
      expect(events.first.rowIndex, 1);
      expect(events.first.columnIndex, 0);
      expect(events.first.key, 'Arrow Down');
      expect(events.first.physicalKey, startsWith('0x'));

      controller.dispose();
    });

    testWidgets('printable key payload carries the character', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();
      final events = <OsCellKeyDownEvent>[];
      await tester.pumpWidget(
        _wrap(
          OsGrid<Map<String, dynamic>>(
            controller: controller,
            columnDefs: const [
              OsColumnDef(field: 'a'),
              OsColumnDef(field: 'b'),
            ],
            rowData: List.generate(5, (i) => {'a': i, 'b': i}),
            onCellKeyDown: events.add,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await focusCellByTap(tester, 0, 0);

      await tester.sendKeyEvent(LogicalKeyboardKey.keyX);
      await tester.pump();
      await tester.pump();

      expect(events, hasLength(1));
      expect(events.first.rowIndex, 0);
      expect(events.first.columnIndex, 0);
      expect(events.first.key, isNotNull);

      controller.dispose();
    });

    test('stream emits when the widget relays a key down', () async {
      final controller = OsGridController<Map<String, dynamic>>();
      final events = <OsCellKeyDownEvent>[];
      final sub = controller.onCellKeyDown.listen(events.add);

      controller.emitCellKeyDown(
        const OsCellKeyDownEvent(
          rowIndex: 2,
          columnIndex: 3,
          key: 'Enter',
          physicalKey: '0x00070028',
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(events, hasLength(1));
      expect(events.first.rowIndex, 2);
      expect(events.first.columnIndex, 3);
      expect(events.first.key, 'Enter');
      expect(events.first.physicalKey, '0x00070028');

      await sub.cancel();
      controller.dispose();
    });
  });

  group('suppressRowClickSelection', () {
    testWidgets('click selection off; checkbox and API selection still work', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();
      var cellClickedCount = 0;
      await tester.pumpWidget(
        _wrap(
          OsGrid<Map<String, dynamic>>(
            controller: controller,
            getRowId: (row) => row['id'] as String,
            columnDefs: const [
              OsColumnDef(
                field: 'sel',
                headerName: '',
                checkboxSelection: true,
              ),
              OsColumnDef(field: 'name'),
            ],
            rowData: const [
              {'id': '1', 'name': 'Alice'},
              {'id': '2', 'name': 'Bob'},
            ],
            rowSelection: OsRowSelection.multiple(),
            suppressRowClickSelection: true,
            onCellClicked: (_) => cellClickedCount++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final box =
          tester.renderObject(find.byType(VirtualisedGrid)) as RenderBox;

      // Plain click on the value column does NOT select the row…
      await tester.tapAt(box.localToGlobal(const Offset(225, 69)));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(controller.getSelectedIds(), isEmpty);
      // …but the click event still fires.
      expect(cellClickedCount, 1);

      // Checkbox-column click still toggles selection.
      await tester.tapAt(box.localToGlobal(const Offset(75, 69)));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(controller.getSelectedIds(), {'1'});

      // API selection still works.
      controller.selectAll();
      expect(controller.getSelectedIds(), {'1', '2'});
      controller.deselectAll();
      expect(controller.getSelectedIds(), isEmpty);

      controller.dispose();
    });

    testWidgets('without the flag click selection still selects', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();
      await tester.pumpWidget(
        _wrap(
          OsGrid<Map<String, dynamic>>(
            controller: controller,
            getRowId: (row) => row['id'] as String,
            columnDefs: const [OsColumnDef(field: 'name')],
            rowData: const [
              {'id': '1', 'name': 'Alice'},
              {'id': '2', 'name': 'Bob'},
            ],
            rowSelection: OsRowSelection.multiple(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final box =
          tester.renderObject(find.byType(VirtualisedGrid)) as RenderBox;

      await tester.tapAt(box.localToGlobal(const Offset(75, 69)));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(controller.getSelectedIds(), {'1'});

      controller.dispose();
    });
  });

  group('suppressCellFocus', () {
    testWidgets('tap neither requests focus nor moves the visual cursor', (
      tester,
    ) async {
      final focused = ValueNotifier<({int row, int col})>((row: 0, col: 0));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 300,
              child: VirtualisedGrid(
                columns: const [
                  OsColumnDef(field: 'a'),
                  OsColumnDef(field: 'b'),
                ],
                rowData: List.generate(5, (i) => {'a': i, 'b': i}),
                focusedCellNotifier: focused,
                suppressCellFocus: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final origin = tester.getTopLeft(find.byType(VirtualisedGrid));
      await tester.tapAt(origin + const Offset(225, 69)); // cell (0, 1)
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Visual focus cursor parked: notifier keeps its prior value.
      expect(focused.value, (row: 0, col: 0));
    });

    testWidgets('getFocusedCell retains prior value under suppression', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();
      await tester.pumpWidget(
        _wrap(
          OsGrid<Map<String, dynamic>>(
            controller: controller,
            columnDefs: const [
              OsColumnDef(field: 'a'),
              OsColumnDef(field: 'b'),
            ],
            rowData: List.generate(5, (i) => {'a': i, 'b': i}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Focus (0, 0) while suppression is off.
      await focusCellByTap(tester, 0, 0);
      expect(controller.getFocusedCell(), (rowIndex: 0, columnIndex: 0));

      // Turn suppression ON — same State instance rebuilds.
      await tester.pumpWidget(
        _wrap(
          OsGrid<Map<String, dynamic>>(
            controller: controller,
            columnDefs: const [
              OsColumnDef(field: 'a'),
              OsColumnDef(field: 'b'),
            ],
            rowData: List.generate(5, (i) => {'a': i, 'b': i}),
            suppressCellFocus: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap another cell: focus request suppressed, prior value retained.
      final box =
          tester.renderObject(find.byType(VirtualisedGrid)) as RenderBox;
      await tester.tapAt(box.localToGlobal(const Offset(225, 111))); // (1, 1)
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(controller.getFocusedCell(), (rowIndex: 0, columnIndex: 0));

      controller.dispose();
    });
  });

  group('ensureColumnVisible — pinned routing (item 49)', () {
    // Layout: viewport 600 wide. Columns: L(100, left), c0..c4 (100 each
    // center), R(100, right). Column indices: 0=L, 1..5=center, 6=R.
    // Center viewport = 600-100-100 = 400; max horizontal scroll = 100.
    Future<
      ({
        ValueNotifier<Offset> scroll,
        ValueNotifier<({int row, int col})> focused,
      })
    >
    pumpPinnedGrid(
      WidgetTester tester, {
      NavigateToNextCellCallback? navigateToNextCell,
    }) async {
      final scroll = ValueNotifier<Offset>(Offset.zero);
      final focused = ValueNotifier<({int row, int col})>((row: 0, col: 0));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              height: 600,
              child: VirtualisedGrid(
                columns: [
                  const OsColumnDef(
                    field: 'L',
                    width: 100,
                    pinned: OsColumnPin.left,
                  ),
                  ...List.generate(
                    5,
                    (i) => OsColumnDef(field: 'c$i', width: 100),
                  ),
                  const OsColumnDef(
                    field: 'R',
                    width: 100,
                    pinned: OsColumnPin.right,
                  ),
                ],
                rowData: List.generate(
                  10,
                  (r) => {
                    'L': r,
                    for (var i = 0; i < 5; i++) 'c$i': '$r-$i',
                    'R': r,
                  },
                ),
                scrollPositionNotifier: scroll,
                focusedCellNotifier: focused,
                navigateToNextCell: navigateToNextCell,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      return (scroll: scroll, focused: focused);
    }

    testWidgets('left-pinned target never scrolls horizontally', (
      tester,
    ) async {
      NavCellPosition? Function(NavigateToNextCellParams) override = (_) =>
          null;
      final (:scroll, :focused) = await pumpPinnedGrid(
        tester,
        navigateToNextCell: (p) => override(p),
      );
      final origin = tester.getTopLeft(find.byType(VirtualisedGrid));

      // Tap the LEFT-PINNED column, then jump to the far center column.
      await tester.tapAt(origin + const Offset(50, 69));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(focused.value, (row: 0, col: 0));

      override = (p) =>
          NavCellPosition(rowIndex: p.previousCell.rowIndex, columnIndex: 5);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(focused.value.col, 5);
      expect(scroll.value.dx, 100.0); // scrolled fully right

      // Now navigate back onto the LEFT-PINNED column: the horizontal
      // offset must remain untouched (no scroll reset).
      override = (_) => const NavCellPosition(rowIndex: 0, columnIndex: 0);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();

      expect(focused.value, (row: 0, col: 0));
      expect(scroll.value.dx, 100.0);
    });

    testWidgets('right-pinned target leaves scroll untouched', (tester) async {
      NavCellPosition? Function(NavigateToNextCellParams) override = (_) =>
          null;
      final (:scroll, :focused) = await pumpPinnedGrid(
        tester,
        navigateToNextCell: (p) => override(p),
      );
      final origin = tester.getTopLeft(find.byType(VirtualisedGrid));

      // Tap c0, jump to the far center column (scrolls right).
      await tester.tapAt(origin + const Offset(150, 69));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(focused.value, (row: 0, col: 1));

      override = (p) =>
          NavCellPosition(rowIndex: p.previousCell.rowIndex, columnIndex: 5);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(scroll.value.dx, 100.0);

      // Jump onto the RIGHT-PINNED column: offset unchanged.
      override = (p) =>
          NavCellPosition(rowIndex: p.previousCell.rowIndex, columnIndex: 6);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();

      expect(focused.value.col, 6);
      expect(scroll.value.dx, 100.0);
    });

    testWidgets('center target scrolls minimally; visible target is a no-op', (
      tester,
    ) async {
      final (:scroll, :focused) = await pumpPinnedGrid(tester);
      final origin = tester.getTopLeft(find.byType(VirtualisedGrid));

      // Tap c0 (center index 1): visible → no scroll.
      await tester.tapAt(origin + const Offset(150, 69));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(focused.value, (row: 0, col: 1));
      expect(scroll.value.dx, 0.0);

      // Walk right to the last center column (index 5): scrolls to max.
      for (var i = 0; i < 4; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();
      }
      expect(focused.value.col, 5);
      expect(scroll.value.dx, 100.0); // colEnd(500) - centerViewport(400)

      // Already-visible neighbor: no further change possible (clamped).
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(focused.value.col, 4);
      expect(scroll.value.dx, 100.0); // unchanged — still fully visible
    });

    testWidgets('cross-boundary neighbor: left pin → first center scrolls '
        'from scrolled-back state only when needed', (tester) async {
      // Start focused deep right, then step LEFT across the boundary into
      // c0 and finally onto L. Scroll must only change for center targets.
      final (:scroll, :focused) = await pumpPinnedGrid(
        tester,
        navigateToNextCell: (p) => p.previousCell.columnIndex == 0
            ? const NavCellPosition(rowIndex: 0, columnIndex: 5)
            : null,
      );
      final origin = tester.getTopLeft(find.byType(VirtualisedGrid));
      await tester.tapAt(origin + const Offset(50, 69)); // L
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Jump to c5 (far center).
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(scroll.value.dx, 100.0);

      // Step LEFT four times: c4..c1 all remain visible at dx=100 until c0
      // (colStart 0 < dx) forces a minimal scroll back to 0.
      for (var i = 0; i < 4; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pump();
      }
      expect(focused.value.col, 1); // c0
      expect(scroll.value.dx, 0.0);

      // One more LEFT crosses onto the LEFT-PINNED column: no scroll change.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(focused.value.col, 0);
      expect(scroll.value.dx, 0.0);
    });
  });
}
