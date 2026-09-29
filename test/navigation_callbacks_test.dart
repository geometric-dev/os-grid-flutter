import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

/// Taps the data cell at [row]/[col] so the grid gains keyboard focus with
/// that cell focused. Default layout: 48px header, 42px rows, 150px columns.
///
/// A timed pump afterwards flushes the double-tap recognizer's countdown
/// timer, which otherwise keeps the widget tree "pending timers" dirty.
Future<void> focusCell(WidgetTester tester, int row, int col) async {
  final origin = tester.getTopLeft(find.byType(VirtualisedGrid));
  await tester.tapAt(origin + Offset(150.0 * col + 75, 48.0 + row * 42 + 21));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  group('Navigation callbacks — API surface', () {
    test('NavCellPosition equality and shape', () {
      const a = NavCellPosition(rowIndex: 1, columnIndex: 2);
      const b = NavCellPosition(rowIndex: 1, columnIndex: 2);
      const c = NavCellPosition(rowIndex: 1, columnIndex: 3);
      expect(a == b, isTrue);
      expect(a == c, isFalse);
      expect(a.hashCode, b.hashCode);
      expect(a.rowIndex, 1);
      expect(a.columnIndex, 2);
    });

    test('OsGrid accepts navigateToNextCell and tabToNextCell', () {
      NavCellPosition? nav(NavigateToNextCellParams p) => null;
      NavCellPosition? tab(TabToNextCellParams p) => null;
      final grid = OsGrid(
        columnDefs: const [OsColumnDef(field: 'name')],
        rowData: <Map<String, dynamic>>[],
        navigateToNextCell: nav,
        tabToNextCell: tab,
      );
      expect(grid.navigateToNextCell, same(nav));
      expect(grid.tabToNextCell, same(tab));
    });
  });

  group('Navigation callbacks — navigateToNextCell (VirtualisedGrid)', () {
    Future<ValueNotifier<({int row, int col})>> pumpGrid(
      WidgetTester tester, {
      NavigateToNextCellCallback? navigateToNextCell,
      TabToNextCellCallback? tabToNextCell,
      int rows = 10,
      int columns = 3,
    }) async {
      final focused = ValueNotifier<({int row, int col})>((row: 0, col: 0));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 600,
              child: VirtualisedGrid(
                columns: List.generate(
                  columns,
                  (i) => OsColumnDef(field: 'col$i'),
                ),
                rowData: List.generate(rows, (i) => {'col0': i}),
                focusedCellNotifier: focused,
                navigateToNextCell: navigateToNextCell,
                tabToNextCell: tabToNextCell,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      return focused;
    }

    testWidgets('custom jump moves focus down two rows', (tester) async {
      final focused = await pumpGrid(
        tester,
        navigateToNextCell: (p) => NavCellPosition(
          rowIndex: p.previousCell.rowIndex + 2,
          columnIndex: p.previousCell.columnIndex,
        ),
      );
      await focusCell(tester, 0, 0);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();

      // Callback jumps down 2 rows instead of 1.
      expect(focused.value, (row: 2, col: 0));
    });

    testWidgets('returning null keeps default movement', (tester) async {
      final focused = await pumpGrid(tester, navigateToNextCell: (p) => null);
      await focusCell(tester, 0, 0);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(focused.value, (row: 1, col: 0));

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(focused.value, (row: 1, col: 1));
    });

    testWidgets('without callback default arrow navigation still works', (
      tester,
    ) async {
      final focused = await pumpGrid(tester);
      await focusCell(tester, 0, 0);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();

      expect(focused.value, (row: 1, col: 1));
    });

    testWidgets('out-of-bounds result is clamped to bounds', (tester) async {
      final focused = await pumpGrid(
        tester,
        navigateToNextCell: (p) =>
            const NavCellPosition(rowIndex: 1000, columnIndex: 1000),
      );
      await focusCell(tester, 0, 0);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();

      // Clamped to the last row and last column.
      expect(focused.value, (row: 9, col: 2));
    });

    testWidgets('negative results are clamped to zero', (tester) async {
      final focused = await pumpGrid(
        tester,
        navigateToNextCell: (p) =>
            const NavCellPosition(rowIndex: -5, columnIndex: -5),
      );
      await focusCell(tester, 0, 0);

      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await tester.pump();

      // Clamped back onto the first cell — no movement.
      expect(focused.value, (row: 0, col: 0));
    });

    testWidgets('callback receives previous/next/key/shift params', (
      tester,
    ) async {
      final received = <NavigateToNextCellParams>[];
      final focused = await pumpGrid(
        tester,
        navigateToNextCell: (p) {
          received.add(p);
          return null;
        },
      );
      await focusCell(tester, 0, 0);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();

      expect(received, hasLength(1));
      expect(
        received.single.previousCell,
        const NavCellPosition(rowIndex: 0, columnIndex: 0),
      );
      expect(
        received.single.nextCell,
        const NavCellPosition(rowIndex: 1, columnIndex: 0),
      );
      expect(received.single.key, 'arrowdown');
      expect(received.single.shift, isFalse);
      expect(focused.value, (row: 1, col: 0));

      // Shift+ArrowDown reports shift: true.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();

      expect(received, hasLength(2));
      expect(received.last.shift, isTrue);
      expect(
        received.last.previousCell,
        const NavCellPosition(rowIndex: 1, columnIndex: 0),
      );
      expect(
        received.last.nextCell,
        const NavCellPosition(rowIndex: 2, columnIndex: 0),
      );

      // Row and column moves from a single callback apply together.
      received.clear();
      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await tester.pump();
      expect(received.single.key, 'pagedown');
    });
  });

  group('Navigation callbacks — tabToNextCell (VirtualisedGrid)', () {
    testWidgets('Tab follows the callback target', (tester) async {
      final focused = ValueNotifier<({int row, int col})>((row: 0, col: 0));
      final keys = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 600,
              child: VirtualisedGrid(
                columns: const [
                  OsColumnDef(field: 'a'),
                  OsColumnDef(field: 'b'),
                  OsColumnDef(field: 'c'),
                ],
                rowData: List.generate(10, (i) => {'a': i, 'b': i, 'c': i}),
                focusedCellNotifier: focused,
                tabToNextCell: (p) {
                  keys.add(p.key);
                  return NavCellPosition(
                    rowIndex: p.previousCell.rowIndex + 1,
                    columnIndex: p.previousCell.columnIndex,
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await focusCell(tester, 0, 0);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      expect(focused.value, (row: 1, col: 0));
      expect(keys, ['tab']);
    });

    testWidgets('Shift+Tab reports shift and key name; null keeps default', (
      tester,
    ) async {
      final focused = ValueNotifier<({int row, int col})>((row: 0, col: 0));
      final keys = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 600,
              child: VirtualisedGrid(
                columns: const [
                  OsColumnDef(field: 'a'),
                  OsColumnDef(field: 'b'),
                  OsColumnDef(field: 'c'),
                ],
                rowData: List.generate(10, (i) => {'a': i, 'b': i, 'c': i}),
                focusedCellNotifier: focused,
                tabToNextCell: (p) {
                  keys.add(p.key);
                  return null; // default: one column left
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await focusCell(tester, 0, 1);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();

      expect(keys, ['shift+tab']);
      expect(focused.value, (row: 0, col: 0)); // default movement
    });

    testWidgets('Tab returning the current cell causes no movement and '
        'no crash', (tester) async {
      final focused = ValueNotifier<({int row, int col})>((row: 0, col: 0));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 600,
              child: VirtualisedGrid(
                columns: const [OsColumnDef(field: 'a')],
                rowData: const [
                  {'a': 1},
                ],
                focusedCellNotifier: focused,
                tabToNextCell: (p) => p.previousCell,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await focusCell(tester, 0, 0);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      // Callback returned the current cell — focus stays put.
      expect(focused.value, (row: 0, col: 0));
    });
  });

  group('Navigation callbacks — tabToNextCell after edit commit', () {
    testWidgets('post-edit Tab starts editing at callback target', (
      tester,
    ) async {
      final startedFields = <String>[];
      final startedRows = <int>[];
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              columnDefs: const [
                OsColumnDef(field: 'a', editable: true),
                OsColumnDef(field: 'b', editable: true),
                OsColumnDef(field: 'c', editable: true),
              ],
              rowData: [
                {'a': 'a0', 'b': 'b0', 'c': 'c0'},
                {'a': 'a1', 'b': 'b1', 'c': 'c1'},
                {'a': 'a2', 'b': 'b2', 'c': 'c2'},
              ],
              onCellEditingStarted: (e) {
                startedRows.add(e.rowIndex);
                startedFields.add(e.colDef.effectiveColId);
              },
              tabToNextCell: (p) => NavCellPosition(
                rowIndex: p.previousCell.rowIndex + 1,
                columnIndex: p.previousCell.columnIndex,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Start editing cell (0, a).
      controller.startEditingCell(rowIndex: 0, colId: 'a');
      await tester.pumpAndSettle();
      expect(startedRows, [0]);
      expect(startedFields, ['a']);

      // Tab during editing → callback target (1, a).
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      expect(startedRows, [0, 1]);
      expect(startedFields, ['a', 'a']);
      controller.dispose();
    });

    testWidgets('null from callback keeps default next-editable-cell move', (
      tester,
    ) async {
      final startedFields = <String>[];
      final startedRows = <int>[];
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              columnDefs: const [
                OsColumnDef(field: 'a', editable: true),
                OsColumnDef(field: 'b', editable: true),
              ],
              rowData: [
                {'a': 'a0', 'b': 'b0'},
                {'a': 'a1', 'b': 'b1'},
              ],
              onCellEditingStarted: (e) {
                startedRows.add(e.rowIndex);
                startedFields.add(e.colDef.effectiveColId);
              },
              tabToNextCell: (p) => null,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      controller.startEditingCell(rowIndex: 0, colId: 'a');
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      // Default behaviour: next editable cell to the right (0, b).
      expect(startedRows, [0, 0]);
      expect(startedFields, ['a', 'b']);
      controller.dispose();
    });

    testWidgets('no tabToNextCell keeps legacy behaviour unchanged', (
      tester,
    ) async {
      final startedFields = <String>[];
      final startedRows = <int>[];
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              columnDefs: const [
                OsColumnDef(field: 'a', editable: true),
                OsColumnDef(field: 'b', editable: true),
              ],
              rowData: [
                {'a': 'a0', 'b': 'b0'},
                {'a': 'a1', 'b': 'b1'},
              ],
              onCellEditingStarted: (e) {
                startedRows.add(e.rowIndex);
                startedFields.add(e.colDef.effectiveColId);
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      controller.startEditingCell(rowIndex: 0, colId: 'a');
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      expect(startedRows, [0, 0]);
      expect(startedFields, ['a', 'b']);
      controller.dispose();
    });
  });
}
