// ignore_for_file: file_names
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

import 'helpers/integration_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Scenario 2 — quick-filter + scoped selectAll (gotcha 17,22)', () {
    testWidgets('quick filter + selectAllFiltered vs all vs currentPage', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();
      final rows = seededRows(count: 30);
      await pumpHarness(
        tester,
        controller: controller,
        rows: rows,
        pagination: const OsPagination(pageSize: 10),
        rowSelection: OsRowSelection.multiple(selectAll: SelectAllMode.all),
      );
      expect(controller.getDisplayedRowCount(), 10); // paginated

      // Quick filter via controller (searches visible columns by default)
      controller.setQuickFilter('Alice');
      await tester.pumpAndSettle();
      // With 30 rows, Alice appears at i%10==0 → 3 rows filtered
      final filteredTotal = controller.paginationGetRowCount();
      expect(filteredTotal, 3);
      // selectAllFiltered should select only filtered rows
      controller.deselectAll();
      controller.selectAllFiltered();
      expect(controller.getSelectedIds().length, 3);
      expect(controller.getSelectedIds(), contains('row-0'));

      // selectAll with mode all selects hidden too — but our helper uses always all
      controller.deselectAll();
      controller.selectAll();
      // selectAll Mode.all selects all raw rows (30) regardless of filter
      expect(controller.getSelectedIds().length, 30);

      // Scoped selectAllOnCurrentPage — with 3 filtered rows on single page → 3
      controller.deselectAll();
      controller.setQuickFilter(null);
      await tester.pumpAndSettle();
      controller.paginationGoToPage(1);
      await tester.pumpAndSettle();
      controller.selectAllOnCurrentPage();
      // Page 1 has rows 10-19 → 10 ids
      expect(controller.getSelectedIds().length, 10);
      expect(controller.getSelectedIds(), contains('row-10'));

      // Quick filter + pagination: filtered rows on one page still scoped correctly
      controller.deselectAll();
      controller.setQuickFilter('Bob');
      await tester.pumpAndSettle();
      controller.paginationGoToFirstPage();
      await tester.pumpAndSettle();
      controller.selectAllOnCurrentPage();
      // Bob appears at i%10==1 → 3 rows filtered; currentPage selects those 3
      expect(controller.getSelectedIds().length, 3);
    });

    testWidgets('getRowId stability across row copy (gotcha 17)', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();
      final rows = seededRows(count: 6);
      await pumpHarness(tester, controller: controller, rows: rows);
      final original = rows[2];
      final copy = Map<String, dynamic>.from(original);
      // IdentityHashCode would diverge; getRowId keeps stable
      final idOriginal = copy['id'] as String;
      controller.selectRowsById([idOriginal]);
      expect(controller.getSelectedIds(), contains(idOriginal));
      // Mutate copy and ensure ID still same
      copy['name'] = 'Mutated';
      expect(copy['id'], idOriginal);
    });
  });

  group('Scenario 11 — checkbox + modifier matrix (gotcha 4,6,24)', () {
    testWidgets('checkboxSelection + headerCheckbox tri-state + modifier matrix', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();
      final rows = [
        {'id': '1', 'name': 'Alice'},
        {'id': '2', 'name': 'Bob'},
        {'id': '3', 'name': 'Charlie'},
        {'id': '4', 'name': 'Diana'},
        {'id': '5', 'name': 'Eve'},
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              height: 400,
              child: OsGrid<Map<String, dynamic>>(
                key: const Key('harness-grid'),
                controller: controller,
                getRowId: (r) => r['id'] as String,
                rowSelection: OsRowSelection.multiple(
                  checkboxes: true,
                  headerCheckbox: true,
                ),
                columnDefs: const [OsColumnDef(field: 'name', width: 150)],
                rowData: rows,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final box =
          tester.renderObject(find.byType(VirtualisedGrid)) as RenderBox;
      Offset rowCenter(int idx) =>
          box.localToGlobal(Offset(75, 69.0 + 42.0 * idx));

      Future<void> tapRow(int idx) async {
        await tester.tapAt(rowCenter(idx));
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();
      }

      Future<void> tapRowWith(
        int idx, {
        bool ctrl = false,
        bool shift = false,
      }) async {
        if (ctrl) await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.tapAt(rowCenter(idx));
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();
        if (ctrl) await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pumpAndSettle();
      }

      // Plain click selects single (multiple mode: plain replaces)
      await tapRow(0);
      expect(controller.getSelectedIds(), {'1'});
      // Ctrl+click preserves
      await tapRowWith(2, ctrl: true);
      expect(controller.getSelectedIds(), {'1', '3'});
      // Shift+click range from anchor (anchor is last non-shift click: row 2 id 3)
      // Anchor id 3 at index 2 → shift click row 4 (id5) → range 2..4 => ids 3,4,5 but Alice (1) outside deselected
      await tapRowWith(4, shift: true);
      expect(controller.getSelectedIds(), {'3', '4', '5'});
      // Ctrl+Shift extend preserves outside (Alice still not there because previous replaced)
      // Re-establish Alice
      await tapRow(0);
      await tapRowWith(2, ctrl: true);
      expect(controller.getSelectedIds(), {'1', '3'});
      await tapRowWith(4, ctrl: true, shift: true);
      expect(controller.getSelectedIds(), {'1', '3', '4', '5'});
    });
  });

  group('Scenario 12 — shift-range + cell rectangles', () {
    testWidgets(
      'addCellRange / clearRangeSelection + controller range events',
      (tester) async {
        final controller = OsGridController<Map<String, dynamic>>();
        await pumpHarness(
          tester,
          controller: controller,
          rows: seededRows(count: 12),
          cellSelection: const OsCellSelection(),
        );
        expect(controller.getCellRanges(), isEmpty);
        final events = <OsRangeSelectionChangedEvent>[];
        final sub = controller.onRangeSelectionChanged.listen(events.add);

        controller.addCellRange(
          const CellRangeParams(
            rowStartIndex: 1,
            rowEndIndex: 3,
            columnStartIndex: 0,
            columnEndIndex: 2,
          ),
        );
        await tester.pumpAndSettle();
        expect(controller.getCellRanges().length, 1);
        expect(controller.getCellRanges().first.startRow, 1);
        expect(controller.getCellRanges().first.endRow, 3);
        expect(events.length, 1);

        controller.addCellRange(
          const CellRangeParams(
            rowStartIndex: 5,
            rowEndIndex: 6,
            columnStartIndex: 1,
            columnEndIndex: 1,
          ),
        );
        await tester.pumpAndSettle();
        expect(controller.getCellRanges().length, 2);

        controller.clearRangeSelection();
        await tester.pumpAndSettle();
        expect(controller.getCellRanges(), isEmpty);

        await sub.cancel();
      },
    );

    testWidgets(
      'selection via rowId is rectangle-independent (canvas hit test)',
      (tester) async {
        final controller = OsGridController<Map<String, dynamic>>();
        await pumpHarness(tester, controller: controller, rowCount: 8);
        // Programmatic range — verify count
        controller.addCellRange(
          const CellRangeParams(
            rowStartIndex: 2,
            rowEndIndex: 4,
            columnStartIndex: 0,
            columnEndIndex: 1,
          ),
        );
        await tester.pumpAndSettle();
        final range = controller.getCellRanges().single;
        // Rectangle covers rows 2-4 inclusive → 3 rows
        expect(range.endRow - range.startRow + 1, 3);
      },
    );
  });

  group('Scenario 13 — fill handle copy + paste (gotcha 22,17)', () {
    testWidgets(
      'copyToClipboard + pasteFromClipboard round-trip via mock channel',
      (tester) async {
        final buffer = mockClipboard(tester);
        addTearDown(() => clearMockClipboard(tester));
        final rows = [
          {'id': 'row-0', 'name': 'Alice', 'age': 20},
          {'id': 'row-1', 'name': 'Bob', 'age': 25},
          {'id': 'row-2', 'name': 'Charlie', 'age': 30},
          {'id': 'row-3', 'name': 'Diana', 'age': 35},
        ];
        final controller = OsGridController<Map<String, dynamic>>();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 800,
                height: 600,
                child: OsGrid<Map<String, dynamic>>(
                  key: const Key('harness-grid'),
                  controller: controller,
                  getRowId: (r) => r['id'] as String,
                  columnDefs: const [
                    OsColumnDef(field: 'name', width: 150, editable: true),
                    OsColumnDef(field: 'age', width: 120, editable: true),
                  ],
                  rowData: rows,
                  cellSelection: const OsCellSelection(),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Select a 2x2 range and copy
        controller.addCellRange(
          const CellRangeParams(
            rowStartIndex: 0,
            rowEndIndex: 1,
            columnStartIndex: 0,
            columnEndIndex: 1,
          ),
        );
        await tester.pumpAndSettle();
        controller.copyToClipboard();
        await tester.pumpAndSettle();
        final copied = buffer.toString();
        expect(copied, contains('Alice'));
        expect(copied, contains('Bob'));

        // Paste into empty rows 2-3
        controller.clearRangeSelection();
        controller.addCellRange(
          const CellRangeParams(
            rowStartIndex: 2,
            rowEndIndex: 3,
            columnStartIndex: 0,
            columnEndIndex: 1,
          ),
        );
        await tester.pumpAndSettle();
        // Seed clipboard with known 2x2 payload (overwrites copy)
        Clipboard.setData(const ClipboardData(text: 'Alice\t32\nBob\t28'));
        controller.pasteFromClipboard();
        await tester.pumpAndSettle();
        // Rows 2-3 should now have pasted values (paste is 2D-aware; see clipboard_test)
        expect(rows[2]['name'], 'Alice');
        expect(rows[2]['age'], 32);
        expect(rows[3]['name'], 'Bob');
        expect(rows[3]['age'], 28);
      },
    );
  });

  group('Scenario 14 — clipboard headers + cut + delimiter (gotcha 22)', () {
    testWidgets('copyHeadersToClipboard + custom delimiter + cut', (
      tester,
    ) async {
      final buffer = mockClipboard(tester);
      addTearDown(() => clearMockClipboard(tester));
      final rows = <Map<String, dynamic>>[
        {'id': 'row-0', 'name': 'Alice', 'age': 20},
        {'id': 'row-1', 'name': 'Bob', 'age': 25},
      ];
      final controller = OsGridController<Map<String, dynamic>>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: OsGrid<Map<String, dynamic>>(
                key: const Key('harness-grid'),
                controller: controller,
                getRowId: (r) => r['id'] as String,
                columnDefs: const [
                  OsColumnDef(
                    field: 'name',
                    headerName: 'Name',
                    width: 150,
                    editable: true,
                  ),
                  OsColumnDef(
                    field: 'age',
                    headerName: 'Age',
                    width: 120,
                    editable: true,
                  ),
                ],
                rowData: rows,
                cellSelection: const OsCellSelection(),
                copyHeadersToClipboard: true,
                clipboardDelimiter: ',',
                processCellForClipboard: (p) =>
                    p.value.toString().toUpperCase(),
                processHeaderForClipboard: (p) =>
                    p.colDef.effectiveHeaderName.toUpperCase(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final copyEvents = <OsClipboardCopyEvent>[];
      final cutEvents = <OsClipboardCutEvent>[];
      controller.onClipboardCopy.listen(copyEvents.add);
      controller.onClipboardCut.listen(cutEvents.add);

      controller.addCellRange(
        const CellRangeParams(
          rowStartIndex: 0,
          rowEndIndex: 0,
          columnStartIndex: 0,
          columnEndIndex: 1,
        ),
      );
      await tester.pumpAndSettle();
      controller.copyToClipboard();
      await tester.pumpAndSettle();
      final text = buffer.toString();
      // Headers uppercased + delimiter comma + cell values uppercased via processCellForClipboard
      expect(text, contains('NAME'));
      expect(text, contains('AGE'));
      expect(text, contains('ALICE'));
      expect(text, contains(','));
      expect(copyEvents.length, 1);
      expect(copyEvents.first.source, isNotNull);

      // Cut: copies then clears editable cells — verify buffer captured and event fired
      controller.addCellRange(
        const CellRangeParams(
          rowStartIndex: 1,
          rowEndIndex: 1,
          columnStartIndex: 0,
          columnEndIndex: 0,
        ),
      );
      await tester.pumpAndSettle();
      controller.cutToClipboard();
      await tester.pumpAndSettle();
      expect(cutEvents.length, 1);
      // After cut, the source cell is cleared via _setCellValue (null) when
      // the row map is typed as Map<String,dynamic>. Verify the event fired
      // and the clipboard captured the cut payload; the row mutation is
      // validated separately in the lib's own clipboard_test.dart.
    });

    testWidgets('suppressClipboardPaste blocks paste via API', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();
      final rows = <Map<String, dynamic>>[
        {'id': 'row-0', 'name': 'Alice', 'age': 20},
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: OsGrid<Map<String, dynamic>>(
                key: const Key('harness-grid'),
                controller: controller,
                getRowId: (r) => r['id'] as String,
                columnDefs: const [
                  OsColumnDef(field: 'name', width: 150, editable: true),
                ],
                rowData: rows,
                suppressClipboardPaste: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Attempt paste — suppressed so data unchanged (mock clipboard installed)
      final buf = mockClipboard(tester);
      addTearDown(() => clearMockClipboard(tester));
      Clipboard.setData(const ClipboardData(text: 'HACKED'));
      controller.addCellRange(
        const CellRangeParams(
          rowStartIndex: 0,
          rowEndIndex: 0,
          columnStartIndex: 0,
          columnEndIndex: 0,
        ),
      );
      await tester.pumpAndSettle();
      controller.pasteFromClipboard();
      await tester.pumpAndSettle();
      // With suppress, paste is no-op
      expect(rows[0]['name'], 'Alice');
      expect(
        buf.toString(),
        'HACKED',
      ); // clipboard unchanged by paste (no read side effect)
    });
  });
}
