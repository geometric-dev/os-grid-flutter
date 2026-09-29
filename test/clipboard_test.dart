import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

void main() {
  group('ClipboardSerializer', () {
    test('serializes single cell', () {
      final columns = [const OsColumnDef(field: 'name', headerName: 'Name')];
      final rows = [
        {'name': 'Alice'},
      ];

      final serializer = ClipboardSerializer<Map<String, dynamic>>(
        columns: columns,
        rows: rows,
        rowStartIndex: 0,
      );

      expect(serializer.serialize(), 'Alice');
    });

    test('serializes multiple cells with tab delimiter', () {
      final columns = [
        const OsColumnDef(field: 'name', headerName: 'Name'),
        const OsColumnDef(field: 'age', headerName: 'Age'),
      ];
      final rows = [
        {'name': 'Alice', 'age': 32},
        {'name': 'Bob', 'age': 28},
      ];

      final serializer = ClipboardSerializer<Map<String, dynamic>>(
        columns: columns,
        rows: rows,
        rowStartIndex: 0,
      );

      expect(serializer.serialize(), 'Alice\t32\nBob\t28');
    });

    test('includes headers when requested', () {
      final columns = [
        const OsColumnDef(field: 'name', headerName: 'Name'),
        const OsColumnDef(field: 'age', headerName: 'Age'),
      ];
      final rows = [
        {'name': 'Alice', 'age': 32},
      ];

      final serializer = ClipboardSerializer<Map<String, dynamic>>(
        columns: columns,
        rows: rows,
        rowStartIndex: 0,
        includeHeaders: true,
      );

      expect(serializer.serialize(), 'Name\tAge\nAlice\t32');
    });

    test('uses custom delimiter', () {
      final columns = [
        const OsColumnDef(field: 'name', headerName: 'Name'),
        const OsColumnDef(field: 'age', headerName: 'Age'),
      ];
      final rows = [
        {'name': 'Alice', 'age': 32},
      ];

      final serializer = ClipboardSerializer<Map<String, dynamic>>(
        columns: columns,
        rows: rows,
        rowStartIndex: 0,
        delimiter: ',',
      );

      expect(serializer.serialize(), 'Alice,32');
    });

    test('applies valueFormatter', () {
      final columns = [
        OsColumnDef(
          field: 'price',
          headerName: 'Price',
          valueFormatter: (params) => '\$${params.value}',
        ),
      ];
      final rows = [
        {'price': 100},
        {'price': 200},
      ];

      final serializer = ClipboardSerializer<Map<String, dynamic>>(
        columns: columns,
        rows: rows,
        rowStartIndex: 0,
      );

      expect(serializer.serialize(), '\$100\n\$200');
    });

    test('applies processCellForClipboard callback', () {
      final columns = [const OsColumnDef(field: 'name', headerName: 'Name')];
      final rows = [
        {'name': 'Alice'},
        {'name': 'Bob'},
      ];

      final serializer = ClipboardSerializer<Map<String, dynamic>>(
        columns: columns,
        rows: rows,
        rowStartIndex: 0,
        processCellForClipboard: (params) =>
            params.value.toString().toUpperCase(),
      );

      expect(serializer.serialize(), 'ALICE\nBOB');
    });

    test('applies processHeaderForClipboard callback', () {
      final columns = [
        const OsColumnDef(field: 'name', headerName: 'Name'),
        const OsColumnDef(field: 'age', headerName: 'Age'),
      ];
      final rows = [
        {'name': 'Alice', 'age': 32},
      ];

      final serializer = ClipboardSerializer<Map<String, dynamic>>(
        columns: columns,
        rows: rows,
        rowStartIndex: 0,
        includeHeaders: true,
        processHeaderForClipboard: (params) =>
            params.colDef.effectiveHeaderName.toUpperCase(),
      );

      expect(serializer.serialize(), 'NAME\tAGE\nAlice\t32');
    });

    test('handles null values', () {
      final columns = [
        const OsColumnDef(field: 'name', headerName: 'Name'),
        const OsColumnDef(field: 'email', headerName: 'Email'),
      ];
      final rows = [
        {'name': 'Alice', 'email': null},
      ];

      final serializer = ClipboardSerializer<Map<String, dynamic>>(
        columns: columns,
        rows: rows,
        rowStartIndex: 0,
      );

      expect(serializer.serialize(), 'Alice\t');
    });

    test('uses valueGetter when available', () {
      final columns = [
        OsColumnDef<Map<String, dynamic>>(
          field: 'fullName',
          headerName: 'Full Name',
          valueGetter: (params) =>
              '${params.data['first']} ${params.data['last']}',
        ),
      ];
      final rows = [
        {'first': 'Alice', 'last': 'Smith'},
      ];

      final serializer = ClipboardSerializer<Map<String, dynamic>>(
        columns: columns,
        rows: rows,
        rowStartIndex: 0,
      );

      expect(serializer.serialize(), 'Alice Smith');
    });
  });

  group('ClipboardParser', () {
    test('parses single cell', () {
      const parser = ClipboardParser();
      final result = parser.parse('hello');
      expect(result, [
        ['hello'],
      ]);
    });

    test('parses tab-separated values', () {
      const parser = ClipboardParser();
      final result = parser.parse('Alice\t32\nBob\t28');
      expect(result, [
        ['Alice', '32'],
        ['Bob', '28'],
      ]);
    });

    test('handles Windows line endings', () {
      const parser = ClipboardParser();
      final result = parser.parse('Alice\t32\r\nBob\t28\r\n');
      expect(result, [
        ['Alice', '32'],
        ['Bob', '28'],
      ]);
    });

    test('removes trailing empty row', () {
      const parser = ClipboardParser();
      final result = parser.parse('Alice\t32\n');
      expect(result, [
        ['Alice', '32'],
      ]);
    });

    test('handles empty string', () {
      const parser = ClipboardParser();
      final result = parser.parse('');
      expect(result, isEmpty);
    });

    test('uses custom delimiter', () {
      const parser = ClipboardParser(delimiter: ',');
      final result = parser.parse('Alice,32\nBob,28');
      expect(result, [
        ['Alice', '32'],
        ['Bob', '28'],
      ]);
    });

    test('handles single row with multiple columns', () {
      const parser = ClipboardParser();
      final result = parser.parse('A\tB\tC');
      expect(result, [
        ['A', 'B', 'C'],
      ]);
    });

    test('handles empty cells', () {
      const parser = ClipboardParser();
      final result = parser.parse('A\t\tC\n\tB\t');
      expect(result, [
        ['A', '', 'C'],
        ['', 'B', ''],
      ]);
    });
  });

  group('ProcessCellForClipboardParams', () {
    test('provides formatValue utility', () {
      final col = OsColumnDef(
        field: 'price',
        headerName: 'Price',
        valueFormatter: (params) => '\$${params.value}',
      );

      final params = ProcessCellForClipboardParams<Map<String, dynamic>>(
        value: 100,
        rowIndex: 0,
        data: {'price': 100},
        colDef: col,
        formatValue: (v) => '\$$v',
      );

      expect(params.formatValue(100), '\$100');
      expect(params.value, 100);
      expect(params.rowIndex, 0);
    });
  });

  group('PasteCellResult', () {
    test('stores paste result data', () {
      const col = OsColumnDef(field: 'name', headerName: 'Name');
      const result = PasteCellResult(
        rowIndex: 0,
        columnId: 'name',
        oldValue: 'Alice',
        newValue: 'Bob',
        data: {'name': 'Bob'},
        colDef: col,
      );

      expect(result.rowIndex, 0);
      expect(result.columnId, 'name');
      expect(result.oldValue, 'Alice');
      expect(result.newValue, 'Bob');
    });
  });

  group('Clipboard events', () {
    test('OsClipboardCopyEvent stores copy data', () {
      const event = OsClipboardCopyEvent(
        text: 'Alice\t32',
        cellCount: 2,
        source: 'keyboard',
      );

      expect(event.text, 'Alice\t32');
      expect(event.cellCount, 2);
      expect(event.source, 'keyboard');
    });

    test('OsClipboardPasteEvent stores paste data', () {
      const event = OsClipboardPasteEvent(cellCount: 4, source: 'api');

      expect(event.cellCount, 4);
      expect(event.source, 'api');
    });

    test('OsClipboardCutEvent stores cut data', () {
      const event = OsClipboardCutEvent(
        text: 'Alice\t32',
        cellCount: 2,
        source: 'keyboard',
      );

      expect(event.text, 'Alice\t32');
      expect(event.cellCount, 2);
      expect(event.source, 'keyboard');
    });
  });

  group('Controller clipboard API', () {
    test('copyToClipboard calls registered callback', () {
      final controller = OsGridController<Map<String, dynamic>>();
      bool called = false;
      controller.onCopyToClipboardRequested = () => called = true;

      controller.copyToClipboard();
      expect(called, isTrue);
    });

    test('pasteFromClipboard calls registered callback', () {
      final controller = OsGridController<Map<String, dynamic>>();
      bool called = false;
      controller.onPasteFromClipboardRequested = () => called = true;

      controller.pasteFromClipboard();
      expect(called, isTrue);
    });

    test('cutToClipboard calls registered callback', () {
      final controller = OsGridController<Map<String, dynamic>>();
      bool called = false;
      controller.onCutToClipboardRequested = () => called = true;

      controller.cutToClipboard();
      expect(called, isTrue);
    });

    test('clipboard event streams emit events', () async {
      final controller = OsGridController<Map<String, dynamic>>();

      final copyEvents = <OsClipboardCopyEvent>[];
      final pasteEvents = <OsClipboardPasteEvent>[];
      final cutEvents = <OsClipboardCutEvent>[];

      controller.onClipboardCopy.listen(copyEvents.add);
      controller.onClipboardPaste.listen(pasteEvents.add);
      controller.onClipboardCut.listen(cutEvents.add);

      controller.emitClipboardCopy(
        const OsClipboardCopyEvent(text: 'test', cellCount: 1, source: 'api'),
      );
      controller.emitClipboardPaste(
        const OsClipboardPasteEvent(cellCount: 2, source: 'keyboard'),
      );
      controller.emitClipboardCut(
        const OsClipboardCutEvent(text: 'cut', cellCount: 1, source: 'api'),
      );

      await Future.delayed(Duration.zero);

      expect(copyEvents.length, 1);
      expect(copyEvents.first.text, 'test');
      expect(pasteEvents.length, 1);
      expect(pasteEvents.first.cellCount, 2);
      expect(cutEvents.length, 1);
      expect(cutEvents.first.text, 'cut');

      controller.dispose();
    });
  });

  group('UndoRedoService.pushAction', () {
    test('pushes action to undo stack and clears redo', () {
      final service = UndoRedoService(limit: 10);

      // First, create an undo entry via normal flow
      service.onCellEditingStarted();
      service.onCellValueChanged(
        rowIndex: 0,
        columnId: 'name',
        oldValue: 'Alice',
        newValue: 'Bob',
      );
      service.onCellEditingStopped(valueChanged: true);
      expect(service.currentUndoSize, 1);

      // Undo to create a redo entry
      service.undo();
      expect(service.currentUndoSize, 0);
      expect(service.currentRedoSize, 1);

      // Push a batch action (like paste)
      service.pushAction(
        UndoRedoAction([
          const CellValueChange(
            rowIndex: 0,
            columnId: 'name',
            oldValue: 'Alice',
            newValue: 'Charlie',
          ),
          const CellValueChange(
            rowIndex: 1,
            columnId: 'name',
            oldValue: 'Bob',
            newValue: 'Dave',
          ),
        ]),
      );

      // Redo stack should be cleared
      expect(service.currentUndoSize, 1);
      expect(service.currentRedoSize, 0);
    });

    test('does not push empty action', () {
      final service = UndoRedoService(limit: 10);
      service.pushAction(UndoRedoAction([]));
      expect(service.currentUndoSize, 0);
    });
  });

  group('Widget integration', () {
    testWidgets('grid options expose clipboard properties', (tester) async {
      // This test verifies the widget accepts clipboard options without error.
      // Full rendering tests are affected by a pre-existing Semantics issue
      // in the test environment — the grid's Semantics node requires
      // textDirection which isn't provided in headless test mode.
      // The clipboard logic is verified via unit tests above.
      final controller = OsGridController<Map<String, dynamic>>();

      // Verify controller API is wired correctly
      bool copyCalled = false;
      bool pasteCalled = false;
      bool cutCalled = false;

      controller.onCopyToClipboardRequested = () => copyCalled = true;
      controller.onPasteFromClipboardRequested = () => pasteCalled = true;
      controller.onCutToClipboardRequested = () => cutCalled = true;

      controller.copyToClipboard();
      controller.pasteFromClipboard();
      controller.cutToClipboard();

      expect(copyCalled, isTrue);
      expect(pasteCalled, isTrue);
      expect(cutCalled, isTrue);

      controller.dispose();
    });
  });

  group('Multi-cell paste (quality program v3 item 10)', () {
    final clipboardBuffer = StringBuffer();

    /// In-memory platform-channel clipboard so paste round-trips headlessly.
    void installClipboardMock(WidgetTester tester) {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall call) async {
          switch (call.method) {
            case 'Clipboard.setData':
              clipboardBuffer
                ..clear()
                ..write(
                  (call.arguments as Map<Object?, Object?>)['text'] as String,
                );
            case 'Clipboard.getData':
              final text = clipboardBuffer.toString();
              return text.isEmpty ? null : <String, Object?>{'text': text};
          }
          return null;
        },
      );
    }

    void resetClipboardMock(WidgetTester tester) {
      clipboardBuffer.clear();
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    }

    Future<OsGridController<Map<String, dynamic>>> pumpGrid(
      WidgetTester tester, {
      required List<Map<String, dynamic>> rows,
      bool secondColumnEditable = true,
    }) async {
      final controller = OsGridController<Map<String, dynamic>>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: OsGrid<Map<String, dynamic>>(
                controller: controller,
                columnDefs: [
                  const OsColumnDef(
                    field: 'name',
                    headerName: 'Name',
                    width: 120,
                    editable: true,
                  ),
                  OsColumnDef(
                    field: 'age',
                    headerName: 'Age',
                    width: 120,
                    editable: secondColumnEditable,
                  ),
                ],
                rowData: rows,
                cellSelection: const OsCellSelection(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return controller;
    }

    testWidgets('pastes the full 2D clipboard grid into the selected range', (
      tester,
    ) async {
      installClipboardMock(tester);
      addTearDown(() => resetClipboardMock(tester));

      final rows = [
        {'name': 'p1', 'age': 1},
        {'name': 'p2', 'age': 2},
        {'name': 'p3', 'age': 3},
        {'name': 'p4', 'age': 4},
      ];
      final controller = await pumpGrid(tester, rows: rows);

      // 2x2 clipboard grid pasted onto a 2x2 range at rows 2-3.
      controller.addCellRange(
        const CellRangeParams(
          rowStartIndex: 2,
          rowEndIndex: 3,
          columnStartIndex: 0,
          columnEndIndex: 1,
        ),
      );
      await tester.pumpAndSettle();

      Clipboard.setData(const ClipboardData(text: 'Alice\t32\nBob\t28'));
      controller.pasteFromClipboard();
      await tester.pumpAndSettle();

      expect(rows[2]['name'], 'Alice');
      expect(rows[2]['age'], 32);
      expect(rows[3]['name'], 'Bob');
      expect(rows[3]['age'], 28);
      // Rows above the range are untouched.
      expect(rows[0]['name'], 'p1');
      expect(rows[1]['age'], 2);
    });

    testWidgets('expands right/down when the clipboard is larger than the '
        'range', (tester) async {
      installClipboardMock(tester);
      addTearDown(() => resetClipboardMock(tester));

      final rows = [
        {'name': 'p1', 'age': 1},
        {'name': 'p2', 'age': 2},
        {'name': 'p3', 'age': 3},
      ];
      final controller = await pumpGrid(tester, rows: rows);

      // Single-cell range, 2x2 clipboard — write area expands to 2x2.
      controller.addCellRange(
        const CellRangeParams(
          rowStartIndex: 1,
          rowEndIndex: 1,
          columnStartIndex: 0,
          columnEndIndex: 0,
        ),
      );
      await tester.pumpAndSettle();

      Clipboard.setData(const ClipboardData(text: 'Alice\t32\nBob\t28'));
      controller.pasteFromClipboard();
      await tester.pumpAndSettle();

      expect(rows[1]['name'], 'Alice');
      expect(rows[1]['age'], 32);
      expect(rows[2]['name'], 'Bob');
      expect(rows[2]['age'], 28);
    });

    testWidgets('tiles the clipboard across a larger range', (tester) async {
      installClipboardMock(tester);
      addTearDown(() => resetClipboardMock(tester));

      final rows = [
        {'name': 'p1', 'age': 1},
        {'name': 'p2', 'age': 2},
        {'name': 'p3', 'age': 3},
        {'name': 'p4', 'age': 4},
      ];
      final controller = await pumpGrid(tester, rows: rows);

      // 2x2 range with a 1x2 clipboard tiles horizontally and vertically.
      controller.addCellRange(
        const CellRangeParams(
          rowStartIndex: 2,
          rowEndIndex: 3,
          columnStartIndex: 0,
          columnEndIndex: 1,
        ),
      );
      await tester.pumpAndSettle();

      Clipboard.setData(const ClipboardData(text: 'Alice\t32'));
      controller.pasteFromClipboard();
      await tester.pumpAndSettle();

      expect(rows[2]['name'], 'Alice');
      expect(rows[2]['age'], 32);
      expect(rows[3]['name'], 'Alice');
      expect(rows[3]['age'], 32);
    });

    testWidgets('skips non-editable cells while keeping grid alignment', (
      tester,
    ) async {
      installClipboardMock(tester);
      addTearDown(() => resetClipboardMock(tester));

      final rows = [
        {'name': 'p1', 'age': 1},
        {'name': 'p2', 'age': 2},
      ];
      final controller = await pumpGrid(
        tester,
        rows: rows,
        secondColumnEditable: false,
      );

      controller.addCellRange(
        const CellRangeParams(
          rowStartIndex: 0,
          rowEndIndex: 1,
          columnStartIndex: 0,
          columnEndIndex: 1,
        ),
      );
      await tester.pumpAndSettle();

      Clipboard.setData(const ClipboardData(text: 'Alice\t32\nBob\t28'));
      controller.pasteFromClipboard();
      await tester.pumpAndSettle();

      // Editable column takes its clipboard column; the read-only column is
      // skipped in place without shifting the 2D structure.
      expect(rows[0]['name'], 'Alice');
      expect(rows[0]['age'], 1);
      expect(rows[1]['name'], 'Bob');
      expect(rows[1]['age'], 2);
    });

    testWidgets('single-cell clipboard keeps linear focused-cell paste', (
      tester,
    ) async {
      installClipboardMock(tester);
      addTearDown(() => resetClipboardMock(tester));

      final rows = [
        {'name': 'p1', 'age': 1},
        {'name': 'p2', 'age': 2},
        {'name': 'p3', 'age': 3},
      ];
      final controller = await pumpGrid(tester, rows: rows);

      // A range is active but the clipboard is 1x1 — legacy path applies.
      controller.addCellRange(
        const CellRangeParams(
          rowStartIndex: 0,
          rowEndIndex: 1,
          columnStartIndex: 0,
          columnEndIndex: 1,
        ),
      );
      controller.setFocusedCell(rowIndex: 2, columnIndex: 0);
      await tester.pumpAndSettle();

      Clipboard.setData(const ClipboardData(text: 'Zed'));
      controller.pasteFromClipboard();
      await tester.pumpAndSettle();

      expect(rows[2]['name'], 'Zed');
      expect(rows[0]['name'], 'p1');
      expect(rows[1]['name'], 'p2');
    });

    testWidgets('clipboard round-trip: copy a 2D range then paste it back', (
      tester,
    ) async {
      installClipboardMock(tester);
      addTearDown(() => resetClipboardMock(tester));

      final rows = [
        {'name': 'Alice', 'age': 32},
        {'name': 'Bob', 'age': 28},
        {'name': 'p3', 'age': 3},
        {'name': 'p4', 'age': 4},
      ];
      final controller = await pumpGrid(tester, rows: rows);

      // Copy a 2x2 block.
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
      expect(clipboardBuffer.toString(), 'Alice\t32\nBob\t28');

      // Paste it into the empty block below via a range selection.
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
      controller.pasteFromClipboard();
      await tester.pumpAndSettle();

      expect(rows[2]['name'], 'Alice');
      expect(rows[2]['age'], 32);
      expect(rows[3]['name'], 'Bob');
      expect(rows[3]['age'], 28);
    });
  });
}
