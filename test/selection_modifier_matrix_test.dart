import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

void main() {
  final rows = [
    {'id': 1, 'name': 'Alice'},
    {'id': 2, 'name': 'Bob'},
    {'id': 3, 'name': 'Charlie'},
    {'id': 4, 'name': 'Diana'},
    {'id': 5, 'name': 'Eve'},
  ];

  OsGridController<Map<String, dynamic>> makeController({
    List<Map<String, dynamic>>? data,
  }) {
    final controller = OsGridController<Map<String, dynamic>>();
    controller.getRowId = (row) => row['id'].toString();
    controller.setRowData(data ?? rows);
    controller.processedData = List.of(data ?? rows);
    controller.rowSelection = OsRowSelection.multiple();
    return controller;
  }

  group('modifier matrix — controller level (multiple mode)', () {
    test('plain click clears others, selects clicked row, moves anchor', () {
      final controller = makeController();
      controller.toggleSelection(0); // Alice
      controller.toggleSelection(2); // Charlie — {1, 3}

      // Plain click (setSingleSelection) replaces selection with Eve
      controller.setSingleSelection(4);
      expect(controller.getSelectedIds(), {'5'});

      // Anchor moved to Eve (index 4): shift+click Alice extends full range
      controller.selectRange(0);
      expect(controller.getSelectedIds(), {'1', '2', '3', '4', '5'});
      controller.dispose();
    });

    test('ctrl+click toggles clicked row and preserves existing selection', () {
      final controller = makeController();
      controller.toggleSelection(0); // Alice
      controller.toggleSelection(2); // Charlie — ctrl+click keeps Alice
      expect(controller.getSelectedIds(), {'1', '3'});

      // Ctrl+click Alice again — toggles off, Charlie preserved
      controller.toggleSelection(0);
      expect(controller.getSelectedIds(), {'3'});
      controller.dispose();
    });

    test('shift+click replaces selection with the anchor range', () {
      final controller = makeController();
      controller.toggleSelection(0); // Alice — {1}, anchor id 1
      controller.toggleSelection(4); // Eve — {1, 5}, anchor moves to id 5

      // Shift+click Bob (index 1): range [1..4] replaces {1, 5} —
      // Alice (id 1, outside the range) is deselected
      controller.selectRange(1);
      expect(controller.getSelectedIds(), {'2', '3', '4', '5'});
      controller.dispose();
    });

    test('ctrl+shift+click extends selection without clearing others', () {
      final controller = makeController();
      controller.toggleSelection(0); // Alice — {1}, anchor id 1 (index 0)
      controller.toggleSelection(2); // Charlie — {1, 3}, anchor id 3

      // Ctrl+Shift+click Eve (index 4): add range [2..4] — Alice (id 1,
      // outside the range) stays selected
      controller.selectRange(4, extend: true);
      expect(controller.getSelectedIds(), {'1', '3', '4', '5'});
      controller.dispose();
    });

    test('shift+click with no anchor behaves like toggle', () {
      final controller = makeController();
      controller.selectRange(2);
      expect(controller.getSelectedIds(), {'3'});
      controller.dispose();
    });

    test('ctrl+shift+click with no anchor behaves like toggle', () {
      final controller = makeController();
      controller.selectRange(2, extend: true);
      expect(controller.getSelectedIds(), {'3'});
      controller.dispose();
    });

    test('repeated shift+clicks keep extending from the same anchor', () {
      final controller = makeController();
      controller.toggleSelection(0); // Alice — anchor id 1
      controller.selectRange(2); // [0..2] → {1, 2, 3}
      controller.selectRange(4); // [0..4] from the SAME anchor → all
      controller.selectRange(1); // [0..1] from the SAME anchor → {1, 2}
      expect(controller.getSelectedIds(), {'1', '2'});
      controller.dispose();
    });

    test('range respects isRowSelectable in both replace and extend modes', () {
      final controller = makeController();
      controller.rowSelection = OsRowSelection.multiple(
        isRowSelectable: (row) => row['name'] != 'Bob',
      );
      controller.toggleSelection(0); // Alice — anchor id 1
      controller.toggleSelection(4); // Eve — {1, 5}, anchor id 5

      // Ctrl+Shift+click Charlie (index 2): extend with range [2..4];
      // non-selectable rows would be skipped inside the range
      controller.selectRange(2, extend: true);
      expect(controller.getSelectedIds(), {'1', '3', '4', '5'});
      controller.dispose();
    });
  });

  group('anchor persistence — sort and filter', () {
    test('anchor persists through sort (re-finds new index by ID)', () {
      final controller = makeController();
      controller.toggleSelection(4); // Eve (id 5) — anchor id 5

      // Sort reverses the display order: Eve moves index 4 → 0
      controller.processedData = rows.reversed.toList();

      // Shift+click Alice (id 1) at its NEW index 4 — range [0..4] means
      // the anchor (Eve) was re-found at index 0
      controller.selectRange(4);
      expect(controller.getSelectedIds(), {'1', '2', '3', '4', '5'});
      controller.dispose();
    });

    test('anchor persists through filter (upward range after reorder)', () {
      final controller = makeController();
      controller.toggleSelection(3); // Diana (id 4) — anchor id 4

      // Sort reverses: Diana moves index 3 → 1
      controller.processedData = rows.reversed.toList();

      // Shift+click Alice (id 1) at index 4 — upward range [1..4],
      // Eve (id 5, index 0) is outside and gets deselected (replace)
      controller.selectRange(4);
      expect(controller.getSelectedIds(), {'1', '2', '3', '4'});
      controller.dispose();
    });

    test('anchor persists through filter (anchor row re-found in subset)', () {
      final controller = makeController();
      controller.toggleSelection(4); // Eve (id 5) — anchor id 5

      // Filter hides Alice: Eve moves index 4 → 3
      controller.processedData = rows.sublist(1);

      // Shift+click Bob (id 2) at index 0 — range [0..3]
      controller.selectRange(0);
      expect(controller.getSelectedIds(), {'2', '3', '4', '5'});
      controller.dispose();
    });
  });

  group('anchor reset rules', () {
    test('anchor resets on page change', () {
      final bigRows = List.generate(
        10,
        (i) => {'id': i + 1, 'name': 'Row ${i + 1}'},
      );
      final controller = makeController(data: bigRows);

      controller.toggleSelection(0); // id 1 — anchor id 1

      // First pagination sync (page 0) — anchor must survive
      controller.updatePaginationState(
        currentPage: 0,
        pageSize: 5,
        totalPages: 2,
        totalRows: 10,
        isPaginated: true,
      );
      controller.selectRange(2); // [0..2] → {1, 2, 3}
      expect(controller.getSelectedIds(), {'1', '2', '3'});

      // Page change → anchor reset
      controller.updatePaginationState(
        currentPage: 1,
        pageSize: 5,
        totalPages: 2,
        totalRows: 10,
        isPaginated: true,
      );
      controller.selectRange(4); // no anchor → toggle id 5 → {1, 2, 3, 5}
      expect(controller.getSelectedIds(), {'1', '2', '3', '5'});
      controller.dispose();
    });

    test('same-page pagination re-sync does not reset the anchor', () {
      final controller = makeController();
      controller.toggleSelection(0); // Alice — anchor id 1
      for (var i = 0; i < 3; i++) {
        controller.updatePaginationState(
          currentPage: 0,
          pageSize: 5,
          totalPages: 1,
          totalRows: 5,
          isPaginated: true,
        );
      }
      controller.selectRange(2); // anchor intact → [0..2]
      expect(controller.getSelectedIds(), {'1', '2', '3'});
      controller.dispose();
    });

    test('anchor resets on explicit deselectAll', () {
      final controller = makeController();
      controller.toggleSelection(0); // Alice — anchor id 1
      controller.deselectAll();
      controller.selectRange(3); // no anchor → toggle id 4 → {4}
      expect(controller.getSelectedIds(), {'4'});
      controller.dispose();
    });

    test('anchor survives deselectRowsById (only deselectAll/page resets)', () {
      final controller = makeController();
      controller.toggleSelection(0); // Alice — {1}, anchor id 1
      controller.deselectRowsById({'1'});
      expect(controller.getSelectedIds(), isEmpty);

      // Anchor (id 1) still set: shift+click Charlie replaces [0..2]
      controller.selectRange(2);
      expect(controller.getSelectedIds(), {'1', '2', '3'});
      controller.dispose();
    });

    test('anchor clears when the dataset is replaced via setRowData', () {
      final controller = makeController();
      controller.toggleSelection(0); // Alice — anchor id 1

      final newRows = [
        {'id': 100, 'name': 'New A'},
        {'id': 200, 'name': 'New B'},
        {'id': 300, 'name': 'New C'},
      ];
      controller.setRowData(newRows);
      controller.processedData = List.of(newRows);

      controller.selectRange(2); // no anchor → toggle id 300 → {300}
      expect(controller.getSelectedIds(), {'300'});
      controller.dispose();
    });
  });

  group('modifier matrix — OsGrid widget integration', () {
    Future<RenderBox> pumpGrid(
      WidgetTester tester, {
      required OsRowSelection rowSelection,
      required OsGridController<Map<String, dynamic>> controller,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 300,
              child: OsGrid<Map<String, dynamic>>(
                controller: controller,
                getRowId: (row) => row['id'].toString(),
                rowSelection: rowSelection,
                columnDefs: const [OsColumnDef(field: 'name')],
                rowData: rows,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return tester.renderObject(find.byType(VirtualisedGrid)) as RenderBox;
    }

    // Header height 48 + row height 42 — row i center at local y 69 + 42*i.
    Offset rowCenter(RenderBox box, int rowIndex) =>
        box.localToGlobal(Offset(75, 69.0 + 42.0 * rowIndex));

    Future<void> tapRow(
      WidgetTester tester,
      RenderBox box,
      int rowIndex,
    ) async {
      await tester.tapAt(rowCenter(box, rowIndex));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
    }

    Future<void> tapRowWithModifiers(
      WidgetTester tester,
      RenderBox box,
      int rowIndex, {
      bool ctrl = false,
      bool shift = false,
    }) async {
      if (ctrl) {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      }
      if (shift) {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      }
      await tester.tapAt(rowCenter(box, rowIndex));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      if (ctrl) {
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      }
      if (shift) {
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      }
      await tester.pumpAndSettle();
    }

    testWidgets('plain click replaces selection (multiple mode)', (
      tester,
    ) async {
      final controller = makeController();
      final box = await pumpGrid(
        tester,
        controller: controller,
        rowSelection: OsRowSelection.multiple(),
      );

      await tapRow(tester, box, 0);
      expect(controller.getSelectedIds(), {'1'});

      // Plain click on another row replaces the selection
      await tapRow(tester, box, 3);
      expect(controller.getSelectedIds(), {'4'});

      controller.dispose();
    });

    testWidgets('ctrl+click preserves existing selection', (tester) async {
      final controller = makeController();
      final box = await pumpGrid(
        tester,
        controller: controller,
        rowSelection: OsRowSelection.multiple(),
      );

      await tapRow(tester, box, 0);
      expect(controller.getSelectedIds(), {'1'});

      // Ctrl+click adds Eve without clearing Alice
      await tapRowWithModifiers(tester, box, 4, ctrl: true);
      expect(controller.getSelectedIds(), {'1', '5'});

      // Ctrl+click Eve again toggles her off, Alice preserved
      await tapRowWithModifiers(tester, box, 4, ctrl: true);
      expect(controller.getSelectedIds(), {'1'});

      controller.dispose();
    });

    testWidgets('meta+click also toggles (macOS parity)', (tester) async {
      final controller = makeController();
      final box = await pumpGrid(
        tester,
        controller: controller,
        rowSelection: OsRowSelection.multiple(),
      );

      await tapRow(tester, box, 0);
      expect(controller.getSelectedIds(), {'1'});

      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.tapAt(rowCenter(box, 2));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pumpAndSettle();

      expect(controller.getSelectedIds(), {'1', '3'});

      controller.dispose();
    });

    testWidgets('shift+click selects range from anchor', (tester) async {
      final controller = makeController();
      final box = await pumpGrid(
        tester,
        controller: controller,
        rowSelection: OsRowSelection.multiple(),
      );

      // Click Alice (anchor), then Eve (plain click replaces, anchor moves)
      await tapRow(tester, box, 0);
      await tapRow(tester, box, 4);
      expect(controller.getSelectedIds(), {'5'});

      // Shift+click Bob: replace with range [1..4]
      await tapRowWithModifiers(tester, box, 1, shift: true);
      expect(controller.getSelectedIds(), {'2', '3', '4', '5'});

      controller.dispose();
    });

    testWidgets('ctrl+shift+click extends selection from anchor', (
      tester,
    ) async {
      final controller = makeController();
      final box = await pumpGrid(
        tester,
        controller: controller,
        rowSelection: OsRowSelection.multiple(),
      );

      // Click Alice (anchor id 1), ctrl+click Charlie → {1, 3}
      await tapRow(tester, box, 0);
      await tapRowWithModifiers(tester, box, 2, ctrl: true);
      expect(controller.getSelectedIds(), {'1', '3'});

      // Ctrl+Shift+click Eve: extend with range [2..4] — Alice preserved
      await tapRowWithModifiers(tester, box, 4, ctrl: true, shift: true);
      expect(controller.getSelectedIds(), {'1', '3', '4', '5'});

      controller.dispose();
    });

    testWidgets('single mode ignores ctrl and shift', (tester) async {
      final controller = makeController();
      final box = await pumpGrid(
        tester,
        controller: controller,
        rowSelection: OsRowSelection.single(),
      );

      await tapRow(tester, box, 0);
      expect(controller.getSelectedIds(), {'1'});

      // Ctrl+click in single mode still replaces (no toggle-preserve)
      await tapRowWithModifiers(tester, box, 1, ctrl: true);
      expect(controller.getSelectedIds(), {'2'});

      // Shift+click in single mode does not range-select
      await tapRowWithModifiers(tester, box, 2, shift: true);
      expect(controller.getSelectedIds(), {'3'});

      controller.dispose();
    });
  });
}
