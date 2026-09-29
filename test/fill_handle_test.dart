import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';
import 'package:os_grid_flutter/src/rendering/range_painter.dart';

void main() {
  // Default test surface is 800x600; the grid fills the scaffold body.
  Widget wrap(OsGrid<Map<String, dynamic>> grid) => MaterialApp(
    home: Scaffold(body: SizedBox(width: 800, height: 600, child: grid)),
  );

  Future<OsGridController<Map<String, dynamic>>> pumpGrid(
    WidgetTester tester, {
    required List<Map<String, dynamic>> rows,
    bool cellSelection = true,
    ValueChanged<OsCellValueChangedEvent<Map<String, dynamic>>>?
    onCellValueChanged,
  }) async {
    final controller = OsGridController<Map<String, dynamic>>();
    await tester.pumpWidget(
      wrap(
        OsGrid<Map<String, dynamic>>(
          controller: controller,
          columnDefs: const [
            OsColumnDef(
              field: 'v',
              headerName: 'V',
              width: 120,
              editable: true,
            ),
            OsColumnDef(
              field: 'w',
              headerName: 'W',
              width: 120,
              editable: true,
            ),
            OsColumnDef(
              field: 'x',
              headerName: 'X',
              width: 120,
              editable: true,
            ),
          ],
          rowData: rows,
          cellSelection: cellSelection ? const OsCellSelection() : null,
          onCellValueChanged: onCellValueChanged,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return controller;
  }

  RangePainter rangePainter(WidgetTester tester) {
    final customPaint = tester.widget<CustomPaint>(
      find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is RangePainter,
      ),
    );
    return customPaint.painter! as RangePainter;
  }

  /// Centre of the painted fill handle for the active range.
  Offset handleCenter(WidgetTester tester) {
    final painter = rangePainter(tester);
    final rect = painter.lastPaintedFillHandle;
    if (rect == null) fail('fill handle is not painted');
    final origin = tester.getTopLeft(find.byType(VirtualisedGrid));
    return origin + rect.center;
  }

  Future<void> drag(
    WidgetTester tester,
    Offset start,
    Offset delta, {
    bool ctrl = false,
  }) async {
    if (ctrl) {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    }
    final gesture = await tester.startGesture(
      start,
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveBy(delta / 2);
    await tester.pump();
    await gesture.moveBy(delta / 2);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    if (ctrl) {
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    }
    await tester.pumpAndSettle();
  }

  group('Fill handle painting', () {
    testWidgets('paints an 8x8 square at the range end cell corner', (
      tester,
    ) async {
      final controller = await pumpGrid(
        tester,
        rows: List.generate(4, (i) => {'v': i, 'w': i, 'x': i}),
      );

      controller.addCellRange(
        const CellRangeParams(
          rowStartIndex: 0,
          rowEndIndex: 0,
          columnStartIndex: 0,
          columnEndIndex: 0,
        ),
      );
      await tester.pumpAndSettle();

      final painter = rangePainter(tester);
      final rect = painter.lastPaintedFillHandle;
      expect(rect, isNotNull);
      expect(rect!.width, 8.0);
      expect(rect.height, 8.0);

      // Anchored at the bottom-right corner of cell (0, 0). Column width
      // comes from the widget's indexed widths map, falling back to the
      // colDef width when the width state does not carry an entry.
      final vg = tester.widget<VirtualisedGrid>(find.byType(VirtualisedGrid));
      final origin = tester.getTopLeft(find.byType(VirtualisedGrid));
      final col0Width = vg.columnWidths?[0] ?? 120.0;
      final expectedLeft = origin.dx + col0Width - 8;
      final expectedTop = origin.dy + vg.headerHeight + vg.rowHeight - 8;
      expect(rect, Rect.fromLTWH(expectedLeft, expectedTop, 8, 8));
    });

    testWidgets('is hidden without an active range', (tester) async {
      await pumpGrid(
        tester,
        rows: List.generate(4, (i) => {'v': i, 'w': i, 'x': i}),
      );

      expect(rangePainter(tester).lastPaintedFillHandle, isNull);
    });

    testWidgets('is hidden when cell selection is disabled', (tester) async {
      final controller = await pumpGrid(
        tester,
        rows: List.generate(4, (i) => {'v': i, 'w': i, 'x': i}),
        cellSelection: false,
      );

      controller.addCellRange(
        const CellRangeParams(
          rowStartIndex: 0,
          rowEndIndex: 0,
          columnStartIndex: 0,
          columnEndIndex: 0,
        ),
      );
      await tester.pumpAndSettle();

      expect(rangePainter(tester).lastPaintedFillHandle, isNull);
    });
  });

  group('Drag fill — copy mode', () {
    testWidgets('replicates a single cell downwards', (tester) async {
      final changes = <OsCellValueChangedEvent<Map<String, dynamic>>>[];
      final List<Map<String, dynamic>> rows = [
        {'v': 5, 'w': 1, 'x': 1},
        {'v': null, 'w': 2, 'x': 2},
        {'v': null, 'w': 3, 'x': 3},
        {'v': null, 'w': 4, 'x': 4},
      ];
      final controller = await pumpGrid(
        tester,
        rows: rows,
        onCellValueChanged: changes.add,
      );
      controller.addCellRange(
        const CellRangeParams(
          rowStartIndex: 0,
          rowEndIndex: 0,
          columnStartIndex: 0,
          columnEndIndex: 0,
        ),
      );
      await tester.pumpAndSettle();

      await drag(tester, handleCenter(tester), const Offset(0, 84));

      expect(rows[1]['v'], 5);
      expect(rows[2]['v'], 5);
      expect(rows[3]['v'], isNull); // drag only covered two rows
      // Source columns of untouched cells stay unchanged.
      expect(rows[1]['w'], 2);
      expect(changes.length, 2);
    });

    testWidgets('repeats a multi-row pattern downwards', (tester) async {
      final List<Map<String, dynamic>> rows = [
        {'v': 10, 'w': 0, 'x': 0},
        {'v': 20, 'w': 0, 'x': 0},
        {'v': null, 'w': 0, 'x': 0},
        {'v': null, 'w': 0, 'x': 0},
      ];
      final controller = await pumpGrid(tester, rows: rows);
      controller.addCellRange(
        const CellRangeParams(
          rowStartIndex: 0,
          rowEndIndex: 1,
          columnStartIndex: 0,
          columnEndIndex: 0,
        ),
      );
      await tester.pumpAndSettle();

      await drag(tester, handleCenter(tester), const Offset(0, 84));

      expect(rows[2]['v'], 10);
      expect(rows[3]['v'], 20);
    });

    testWidgets('replicates a single cell rightwards', (tester) async {
      final List<Map<String, dynamic>> rows = [
        {'v': 7, 'w': null, 'x': null},
        {'v': 0, 'w': 0, 'x': 0},
      ];
      final controller = await pumpGrid(tester, rows: rows);
      controller.addCellRange(
        const CellRangeParams(
          rowStartIndex: 0,
          rowEndIndex: 0,
          columnStartIndex: 0,
          columnEndIndex: 0,
        ),
      );
      await tester.pumpAndSettle();

      await drag(tester, handleCenter(tester), const Offset(240, 0));

      expect(rows[0]['w'], 7);
      expect(rows[0]['x'], 7);
      expect(rows[1]['v'], 0); // other rows untouched
    });

    testWidgets('fill respects non-editable cells', (tester) async {
      final List<Map<String, dynamic>> rows = [
        {'v': 7, 'w': null, 'x': null},
        {'v': 0, 'w': 0, 'x': 0},
      ];
      final controller = OsGridController<Map<String, dynamic>>();
      await tester.pumpWidget(
        wrap(
          OsGrid<Map<String, dynamic>>(
            controller: controller,
            columnDefs: const [
              OsColumnDef(field: 'v', width: 120, editable: true),
              OsColumnDef(field: 'w', width: 120, editable: false),
              OsColumnDef(field: 'x', width: 120, editable: true),
            ],
            rowData: rows,
            cellSelection: const OsCellSelection(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      controller.addCellRange(
        const CellRangeParams(
          rowStartIndex: 0,
          rowEndIndex: 0,
          columnStartIndex: 0,
          columnEndIndex: 0,
        ),
      );
      await tester.pumpAndSettle();

      await drag(tester, handleCenter(tester), const Offset(240, 0));

      expect(rows[0]['w'], isNull); // non-editable column skipped
      expect(rows[0]['x'], 7);
    });
  });

  group('Drag fill — series mode (Ctrl+drag)', () {
    testWidgets('increments from a single numeric cell', (tester) async {
      final List<Map<String, dynamic>> rows = [
        {'v': 1, 'w': 0, 'x': 0},
        {'v': null, 'w': 0, 'x': 0},
        {'v': null, 'w': 0, 'x': 0},
      ];
      final controller = await pumpGrid(tester, rows: rows);
      controller.addCellRange(
        const CellRangeParams(
          rowStartIndex: 0,
          rowEndIndex: 0,
          columnStartIndex: 0,
          columnEndIndex: 0,
        ),
      );
      await tester.pumpAndSettle();

      await drag(tester, handleCenter(tester), const Offset(0, 84), ctrl: true);

      expect(rows[1]['v'], 2);
      expect(rows[2]['v'], 3);
    });

    testWidgets('infers the step from a multi-cell source', (tester) async {
      final List<Map<String, dynamic>> rows = [
        {'v': 2, 'w': 0, 'x': 0},
        {'v': 4, 'w': 0, 'x': 0},
        {'v': null, 'w': 0, 'x': 0},
        {'v': null, 'w': 0, 'x': 0},
      ];
      final controller = await pumpGrid(tester, rows: rows);
      controller.addCellRange(
        const CellRangeParams(
          rowStartIndex: 0,
          rowEndIndex: 1,
          columnStartIndex: 0,
          columnEndIndex: 0,
        ),
      );
      await tester.pumpAndSettle();

      await drag(tester, handleCenter(tester), const Offset(0, 84), ctrl: true);

      expect(rows[2]['v'], 6);
      expect(rows[3]['v'], 8);
    });

    testWidgets('falls back to copy for non-numeric sources', (tester) async {
      final List<Map<String, dynamic>> rows = [
        {'v': 'a', 'w': 0, 'x': 0},
        {'v': null, 'w': 0, 'x': 0},
      ];
      final controller = await pumpGrid(tester, rows: rows);
      controller.addCellRange(
        const CellRangeParams(
          rowStartIndex: 0,
          rowEndIndex: 0,
          columnStartIndex: 0,
          columnEndIndex: 0,
        ),
      );
      await tester.pumpAndSettle();

      await drag(tester, handleCenter(tester), const Offset(0, 42), ctrl: true);

      expect(rows[1]['v'], 'a');
    });

    testWidgets('runs a series horizontally across columns', (tester) async {
      final List<Map<String, dynamic>> rows = [
        {'v': 1, 'w': null, 'x': null},
        {'v': 0, 'w': 0, 'x': 0},
      ];
      final controller = await pumpGrid(tester, rows: rows);
      controller.addCellRange(
        const CellRangeParams(
          rowStartIndex: 0,
          rowEndIndex: 0,
          columnStartIndex: 0,
          columnEndIndex: 0,
        ),
      );
      await tester.pumpAndSettle();

      await drag(
        tester,
        handleCenter(tester),
        const Offset(240, 0),
        ctrl: true,
      );

      expect(rows[0]['w'], 2);
      expect(rows[0]['x'], 3);
    });
  });

  group('Drag fill — side effects', () {
    testWidgets('emits one change event per written cell and one undo action', (
      tester,
    ) async {
      final changes = <OsCellValueChangedEvent<Map<String, dynamic>>>[];
      final List<Map<String, dynamic>> rows = [
        {'v': 5, 'w': 0, 'x': 0},
        {'v': null, 'w': 0, 'x': 0},
        {'v': null, 'w': 0, 'x': 0},
      ];
      final controller = await pumpGrid(
        tester,
        rows: rows,
        onCellValueChanged: changes.add,
      );
      controller.addCellRange(
        const CellRangeParams(
          rowStartIndex: 0,
          rowEndIndex: 0,
          columnStartIndex: 0,
          columnEndIndex: 0,
        ),
      );
      await tester.pumpAndSettle();

      await drag(tester, handleCenter(tester), const Offset(0, 84));

      expect(changes, hasLength(2));
      expect(changes[0].rowIndex, 1);
      expect(changes[0].oldValue, isNull);
      expect(changes[0].newValue, 5);
      expect(changes[1].rowIndex, 2);
    });

    testWidgets('keeps the source range selection unchanged', (tester) async {
      final List<Map<String, dynamic>> rows = [
        {'v': 5, 'w': 0, 'x': 0},
        {'v': null, 'w': 0, 'x': 0},
      ];
      final controller = await pumpGrid(tester, rows: rows);
      controller.addCellRange(
        const CellRangeParams(
          rowStartIndex: 0,
          rowEndIndex: 0,
          columnStartIndex: 0,
          columnEndIndex: 0,
        ),
      );
      await tester.pumpAndSettle();

      await drag(tester, handleCenter(tester), const Offset(0, 42));

      final ranges = controller.getCellRanges();
      expect(ranges, hasLength(1));
      expect(ranges.first.normalizedStartRow, 0);
      expect(ranges.first.normalizedEndRow, 0);
      expect(ranges.first.normalizedStartColumn, 0);
      expect(ranges.first.normalizedEndColumn, 0);
    });

    testWidgets('does not write when released inside the source range', (
      tester,
    ) async {
      final changes = <OsCellValueChangedEvent<Map<String, dynamic>>>[];
      final List<Map<String, dynamic>> rows = [
        {'v': 5, 'w': 0, 'x': 0},
        {'v': null, 'w': 0, 'x': 0},
      ];
      final controller = await pumpGrid(
        tester,
        rows: rows,
        onCellValueChanged: changes.add,
      );
      controller.addCellRange(
        const CellRangeParams(
          rowStartIndex: 0,
          rowEndIndex: 0,
          columnStartIndex: 0,
          columnEndIndex: 0,
        ),
      );
      await tester.pumpAndSettle();

      // Small drag that stays within the source cell itself.
      await drag(tester, handleCenter(tester), const Offset(-4, -4));

      expect(changes, isEmpty);
      expect(rows[1]['v'], isNull);
    });

    testWidgets('fill drag does not start a range selection instead', (
      tester,
    ) async {
      final List<Map<String, dynamic>> rows = [
        {'v': 5, 'w': 0, 'x': 0},
        {'v': null, 'w': 0, 'x': 0},
        {'v': null, 'w': 0, 'x': 0},
      ];
      final controller = await pumpGrid(tester, rows: rows);
      controller.addCellRange(
        const CellRangeParams(
          rowStartIndex: 0,
          rowEndIndex: 0,
          columnStartIndex: 0,
          columnEndIndex: 0,
        ),
      );
      await tester.pumpAndSettle();

      await drag(tester, handleCenter(tester), const Offset(0, 84));

      // Still exactly the source range — the drag was a fill, not a
      // selection.
      expect(controller.getCellRanges(), hasLength(1));
      expect(rows[1]['v'], 5);
      expect(rows[2]['v'], 5);
    });
  });
}
