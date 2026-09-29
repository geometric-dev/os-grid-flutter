import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';
import 'package:os_grid_flutter/src/rendering/range_painter.dart';

void main() {
  /// Commits one edit session (started → changed → stopped) on [service].
  void commitSession(
    UndoRedoService service, {
    required int rowIndex,
    required String columnId,
    required dynamic oldValue,
    required dynamic newValue,
  }) {
    service.onCellEditingStarted();
    service.onCellValueChanged(
      rowIndex: rowIndex,
      columnId: columnId,
      oldValue: oldValue,
      newValue: newValue,
    );
    service.onCellEditingStopped(valueChanged: true);
  }

  group('estimateActionMemory', () {
    test('grows with string payload size', () {
      final small = estimateChangeMemory(
        const CellValueChange(
          rowIndex: 0,
          columnId: 'c',
          oldValue: 'x',
          newValue: 'y',
        ),
      );
      final large = estimateChangeMemory(
        CellValueChange(
          rowIndex: 0,
          columnId: 'c',
          oldValue: 'x' * 100,
          newValue: 'y' * 100,
        ),
      );
      expect(large, greaterThan(small));
    });

    test('action estimate is the sum of its change estimates', () {
      const a = CellValueChange(
        rowIndex: 0,
        columnId: 'a',
        oldValue: 'a0',
        newValue: 'a1',
      );
      const b = CellValueChange(
        rowIndex: 1,
        columnId: 'bb',
        oldValue: null,
        newValue: 42,
      );
      expect(
        estimateActionMemory(UndoRedoAction([a, b])),
        estimateChangeMemory(a) + estimateChangeMemory(b),
      );
    });

    test('null values contribute less than string values', () {
      final withNulls = estimateChangeMemory(
        const CellValueChange(
          rowIndex: 0,
          columnId: 'c',
          oldValue: null,
          newValue: null,
        ),
      );
      final withStrings = estimateChangeMemory(
        const CellValueChange(
          rowIndex: 0,
          columnId: 'c',
          oldValue: 'x',
          newValue: 'y',
        ),
      );
      expect(withNulls, lessThan(withStrings));
    });
  });

  group('pushComposite', () {
    test('wraps multiple changes into ONE action preserving order', () {
      final service = UndoRedoService(limit: 10);
      final action = service.pushComposite([
        const CellValueChange(
          rowIndex: 0,
          columnId: 'a',
          oldValue: 'a0',
          newValue: 'a1',
        ),
        const CellValueChange(
          rowIndex: 1,
          columnId: 'b',
          oldValue: 'b0',
          newValue: 'b1',
        ),
        const CellValueChange(
          rowIndex: 2,
          columnId: 'c',
          oldValue: 'c0',
          newValue: 'c1',
        ),
      ]);

      expect(action, isNotNull);
      expect(action!.cellValueChanges, hasLength(3));
      expect(service.currentUndoSize, 1);

      final undone = service.undo()!;
      expect(undone.cellValueChanges, hasLength(3));
      expect(undone.cellValueChanges.map((c) => c.columnId).toList(), [
        'a',
        'b',
        'c',
      ]);
      expect(undone.cellValueChanges[0].oldValue, 'a0');
      expect(undone.cellValueChanges[2].oldValue, 'c0');
    });

    test('undo/redo exactness for a composite action', () {
      final service = UndoRedoService(limit: 10);
      service.pushComposite([
        const CellValueChange(
          rowIndex: 0,
          columnId: 'a',
          oldValue: 1,
          newValue: 2,
        ),
        const CellValueChange(
          rowIndex: 1,
          columnId: 'b',
          oldValue: 3,
          newValue: 4,
        ),
      ]);

      final undone = service.undo()!;
      expect(undone.cellValueChanges.map((c) => c.oldValue).toList(), [1, 3]);
      expect(service.currentUndoSize, 0);
      expect(service.currentRedoSize, 1);

      final redone = service.redo()!;
      expect(redone.cellValueChanges.map((c) => c.newValue).toList(), [2, 4]);
      expect(service.currentUndoSize, 1);
      expect(service.currentRedoSize, 0);
    });

    test('empty composite pushes nothing and leaves redo untouched', () {
      final service = UndoRedoService(limit: 10);
      service.pushComposite([
        const CellValueChange(
          rowIndex: 0,
          columnId: 'a',
          oldValue: 1,
          newValue: 2,
        ),
      ]);
      service.undo();
      expect(service.currentRedoSize, 1);

      expect(service.pushComposite(const []), isNull);
      expect(service.currentUndoSize, 0);
      expect(service.currentRedoSize, 1);
    });

    test('pushComposite clears the redo stack', () {
      final service = UndoRedoService(limit: 10);
      service.pushComposite([
        const CellValueChange(
          rowIndex: 0,
          columnId: 'a',
          oldValue: 1,
          newValue: 2,
        ),
      ]);
      service.undo();
      expect(service.currentRedoSize, 1);

      service.pushComposite([
        const CellValueChange(
          rowIndex: 1,
          columnId: 'b',
          oldValue: 3,
          newValue: 4,
        ),
      ]);
      expect(service.currentRedoSize, 0);
      expect(service.currentUndoSize, 1);
    });
  });

  group('Multi-edit batch (beginBatch/endBatch)', () {
    test('edits across sessions accumulate into ONE action at endBatch', () {
      final service = UndoRedoService(limit: 10);
      service.beginBatch();
      expect(service.isBatching, isTrue);

      commitSession(
        service,
        rowIndex: 0,
        columnId: 'a',
        oldValue: 1,
        newValue: 2,
      );
      expect(service.currentUndoSize, 0, reason: 'held in the open batch');

      commitSession(
        service,
        rowIndex: 1,
        columnId: 'b',
        oldValue: 3,
        newValue: 4,
      );
      expect(service.pendingChangeCount, 2);

      final action = service.endBatch();
      expect(action, isNotNull);
      expect(action!.cellValueChanges, hasLength(2));
      expect(service.currentUndoSize, 1);
      expect(service.isBatching, isFalse);
      expect(service.pendingChangeCount, 0);

      // Undo reverts the whole batch in one step.
      final undone = service.undo()!;
      expect(undone.cellValueChanges, hasLength(2));
      expect(undone.cellValueChanges[0].oldValue, 1);
      expect(undone.cellValueChanges[1].oldValue, 3);
      expect(service.currentRedoSize, 1);

      // Redo reapplies the whole batch in one step.
      final redone = service.redo()!;
      expect(redone.cellValueChanges, hasLength(2));
      expect(redone.cellValueChanges[0].newValue, 2);
      expect(redone.cellValueChanges[1].newValue, 4);
    });

    test('cancelled edit sessions contribute nothing to the batch', () {
      final service = UndoRedoService(limit: 10);
      service.beginBatch();

      commitSession(
        service,
        rowIndex: 0,
        columnId: 'a',
        oldValue: 1,
        newValue: 2,
      );
      service.onCellEditingStarted();
      service.onCellEditingStopped(valueChanged: false);

      final action = service.endBatch();
      expect(action, isNotNull);
      expect(action!.cellValueChanges, hasLength(1));
      expect(action.cellValueChanges.single.columnId, 'a');
    });

    test('beginBatch is idempotent while a batch is open', () {
      final service = UndoRedoService(limit: 10);
      service.beginBatch();
      service.beginBatch();

      commitSession(
        service,
        rowIndex: 0,
        columnId: 'a',
        oldValue: 1,
        newValue: 2,
      );
      commitSession(
        service,
        rowIndex: 1,
        columnId: 'b',
        oldValue: 3,
        newValue: 4,
      );

      final action = service.endBatch();
      expect(action, isNotNull);
      expect(action!.cellValueChanges, hasLength(2));
      expect(service.currentUndoSize, 1);
    });

    test('endBatch with no batch or no changes returns null', () {
      final service = UndoRedoService(limit: 10);
      expect(service.endBatch(), isNull);

      service.beginBatch();
      expect(service.endBatch(), isNull);
      expect(service.currentUndoSize, 0);
      expect(service.isBatching, isFalse);
    });

    test('undo during an open batch flushes and closes it', () {
      final service = UndoRedoService(limit: 10);
      service.beginBatch();
      commitSession(
        service,
        rowIndex: 0,
        columnId: 'a',
        oldValue: 1,
        newValue: 2,
      );
      commitSession(
        service,
        rowIndex: 1,
        columnId: 'b',
        oldValue: 3,
        newValue: 4,
      );

      final action = service.undo();
      expect(action, isNotNull);
      expect(action!.cellValueChanges, hasLength(2));
      expect(service.isBatching, isFalse);
      expect(service.currentUndoSize, 0);
      expect(service.currentRedoSize, 1);

      final redone = service.redo()!;
      expect(redone.cellValueChanges, hasLength(2));
    });

    test('pushComposite during a batch flushes accumulated edits first', () {
      final service = UndoRedoService(limit: 10);
      service.beginBatch();
      commitSession(
        service,
        rowIndex: 0,
        columnId: 'a',
        oldValue: 1,
        newValue: 2,
      );

      service.pushComposite([
        const CellValueChange(
          rowIndex: 1,
          columnId: 'b',
          oldValue: 3,
          newValue: 4,
        ),
      ]);

      expect(service.currentUndoSize, 2);
      expect(service.isBatching, isFalse);

      final top = service.undo()!;
      expect(top.cellValueChanges.single.columnId, 'b');
      final below = service.undo()!;
      expect(below.cellValueChanges.single.columnId, 'a');
    });

    test('pushAction during a batch flushes accumulated edits first', () {
      final service = UndoRedoService(limit: 10);
      service.beginBatch();
      commitSession(
        service,
        rowIndex: 0,
        columnId: 'a',
        oldValue: 1,
        newValue: 2,
      );

      service.pushAction(
        UndoRedoAction([
          const CellValueChange(
            rowIndex: 1,
            columnId: 'b',
            oldValue: 3,
            newValue: 4,
          ),
        ]),
      );

      expect(service.currentUndoSize, 2);
      final top = service.undo()!;
      expect(top.cellValueChanges.single.columnId, 'b');
      final below = service.undo()!;
      expect(below.cellValueChanges.single.columnId, 'a');
    });
  });

  group('Time-windowed batching (batchWindow)', () {
    const window = Duration(milliseconds: 500);

    Future<void> pumpEmpty(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
    }

    testWidgets('sessions within the window merge into ONE action', (
      tester,
    ) async {
      await pumpEmpty(tester);
      final service = UndoRedoService(limit: 10, batchWindow: window);

      commitSession(
        service,
        rowIndex: 0,
        columnId: 'a',
        oldValue: 'a0',
        newValue: 'a1',
      );
      await tester.pump(const Duration(milliseconds: 200));

      commitSession(
        service,
        rowIndex: 1,
        columnId: 'b',
        oldValue: 'b0',
        newValue: 'b1',
      );

      expect(service.currentUndoSize, 0, reason: 'still inside the window');
      expect(service.pendingChangeCount, 2);

      await tester.pump(const Duration(milliseconds: 500));

      expect(service.currentUndoSize, 1);
      expect(service.pendingChangeCount, 0);

      final action = service.undo()!;
      expect(action.cellValueChanges, hasLength(2));
      expect(action.cellValueChanges[0].columnId, 'a');
      expect(action.cellValueChanges[1].columnId, 'b');
      expect(service.currentRedoSize, 1);
    });

    testWidgets('sessions more than 500ms apart stay separate', (tester) async {
      await pumpEmpty(tester);
      final service = UndoRedoService(limit: 10, batchWindow: window);

      commitSession(
        service,
        rowIndex: 0,
        columnId: 'a',
        oldValue: 'a0',
        newValue: 'a1',
      );
      await tester.pump(const Duration(milliseconds: 600));

      expect(service.currentUndoSize, 1);

      commitSession(
        service,
        rowIndex: 1,
        columnId: 'b',
        oldValue: 'b0',
        newValue: 'b1',
      );
      await tester.pump(const Duration(milliseconds: 600));

      expect(service.currentUndoSize, 2);

      final second = service.undo()!;
      expect(second.cellValueChanges.single.columnId, 'b');
      final first = service.undo()!;
      expect(first.cellValueChanges.single.columnId, 'a');
      expect(service.currentUndoSize, 0);
    });

    testWidgets('flushes exactly when the window elapses', (tester) async {
      await pumpEmpty(tester);
      final service = UndoRedoService(limit: 10, batchWindow: window);

      commitSession(
        service,
        rowIndex: 0,
        columnId: 'a',
        oldValue: 'a0',
        newValue: 'a1',
      );

      await tester.pump(const Duration(milliseconds: 499));
      expect(service.currentUndoSize, 0);

      await tester.pump(const Duration(milliseconds: 1));
      expect(service.currentUndoSize, 1);
    });

    testWidgets('undo flushes the pending window immediately', (tester) async {
      await pumpEmpty(tester);
      final service = UndoRedoService(limit: 10, batchWindow: window);

      commitSession(
        service,
        rowIndex: 0,
        columnId: 'a',
        oldValue: 'a0',
        newValue: 'a1',
      );
      expect(service.currentUndoSize, 0);

      final action = service.undo();
      expect(action, isNotNull);
      expect(action!.cellValueChanges.single.newValue, 'a1');
      expect(service.currentUndoSize, 0);
      expect(service.currentRedoSize, 1);

      // The window timer was cut — no late flush arrives.
      await tester.pump(const Duration(milliseconds: 500));
      expect(service.currentUndoSize, 0);
      expect(service.currentRedoSize, 1);
    });

    testWidgets('an intervening undo keeps later edits separate', (
      tester,
    ) async {
      await pumpEmpty(tester);
      final service = UndoRedoService(limit: 10, batchWindow: window);

      commitSession(
        service,
        rowIndex: 0,
        columnId: 'a',
        oldValue: 'a0',
        newValue: 'a1',
      );
      service.undo();

      // Second edit right after the undo — must not merge with the first.
      commitSession(
        service,
        rowIndex: 1,
        columnId: 'b',
        oldValue: 'b0',
        newValue: 'b1',
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(service.currentUndoSize, 1);
      // The edit after the undo invalidated the earlier redo entry
      // (standard "new edit clears redo" rule, applied by the flush).
      expect(service.currentRedoSize, 0);
      final action = service.undo()!;
      expect(action.cellValueChanges.single.columnId, 'b');
      expect(service.currentRedoSize, 1);
    });

    testWidgets('clearStacks discards a pending window without pushing', (
      tester,
    ) async {
      await pumpEmpty(tester);
      final service = UndoRedoService(limit: 10, batchWindow: window);

      commitSession(
        service,
        rowIndex: 0,
        columnId: 'a',
        oldValue: 'a0',
        newValue: 'a1',
      );
      expect(service.pendingChangeCount, 1);

      service.clearStacks();
      expect(service.pendingChangeCount, 0);
      expect(service.currentUndoSize, 0);

      // Timer was cancelled — the discard is final.
      await tester.pump(const Duration(milliseconds: 600));
      expect(service.currentUndoSize, 0);
    });

    testWidgets('pushComposite cuts the window and keeps order', (
      tester,
    ) async {
      await pumpEmpty(tester);
      final service = UndoRedoService(limit: 10, batchWindow: window);

      commitSession(
        service,
        rowIndex: 0,
        columnId: 'a',
        oldValue: 'a0',
        newValue: 'a1',
      );
      service.pushComposite([
        const CellValueChange(
          rowIndex: 1,
          columnId: 'b',
          oldValue: 'b0',
          newValue: 'b1',
        ),
      ]);

      expect(service.currentUndoSize, 2);
      final top = service.undo()!;
      expect(top.cellValueChanges.single.columnId, 'b');
      final windowed = service.undo()!;
      expect(windowed.cellValueChanges.single.columnId, 'a');
    });
  });

  group('Memory accounting (maxUndoMemory)', () {
    CellValueChange changeOf(int rowIndex) => CellValueChange(
      rowIndex: rowIndex,
      columnId: 'c',
      oldValue: 'o$rowIndex',
      newValue: 'n$rowIndex',
    );

    test('default ceiling is 1 MiB and usage starts at zero', () {
      final service = UndoRedoService(limit: 10);
      expect(service.maxUndoMemory, 1024 * 1024);
      expect(service.estimatedMemoryUsage, 0);
    });

    test('evicts oldest actions when the memory cap is exceeded', () {
      final unit = estimateActionMemory(UndoRedoAction([changeOf(0)]));
      final service = UndoRedoService(limit: 10, maxUndoMemory: unit * 2 + 10);

      for (var i = 0; i < 4; i++) {
        service.pushComposite([changeOf(i)]);
      }

      // A third action would exceed the cap, so only two remain.
      expect(service.currentUndoSize, 2);
      expect(service.estimatedMemoryUsage, unit * 2);

      final top = service.undo()!;
      expect(top.cellValueChanges.single.rowIndex, 3);
      final next = service.undo()!;
      expect(next.cellValueChanges.single.rowIndex, 2);
      expect(service.undo(), isNull);
    });

    test('a single oversized action is retained, not dropped', () {
      final service = UndoRedoService(limit: 10, maxUndoMemory: 10);
      service.pushComposite([changeOf(7)]);

      expect(service.currentUndoSize, 1);
      final action = service.undo();
      expect(action, isNotNull);
      expect(action!.cellValueChanges.single.rowIndex, 7);
    });

    test('estimatedMemoryUsage tracks pushes, undos and clears', () {
      final unit = estimateActionMemory(UndoRedoAction([changeOf(0)]));
      final service = UndoRedoService(limit: 10, maxUndoMemory: 100 * unit);

      service.pushComposite([changeOf(0)]);
      service.pushComposite([changeOf(1)]);
      expect(service.estimatedMemoryUsage, unit * 2);

      // Undo moves the action to the redo stack — total is unchanged.
      service.undo();
      expect(service.estimatedMemoryUsage, unit * 2);

      // A new push clears the redo stack (the undone action is dropped).
      service.pushComposite([changeOf(2)]);
      expect(service.estimatedMemoryUsage, unit * 2);

      service.clearStacks();
      expect(service.estimatedMemoryUsage, 0);
    });

    test('count limit still applies alongside the memory cap', () {
      final service = UndoRedoService(limit: 2, maxUndoMemory: 1000000);
      for (var i = 0; i < 4; i++) {
        service.pushComposite([changeOf(i)]);
      }
      expect(service.currentUndoSize, 2);

      final top = service.undo()!;
      expect(top.cellValueChanges.single.rowIndex, 3);
      final next = service.undo()!;
      expect(next.cellValueChanges.single.rowIndex, 2);
    });
  });

  group('Widget-level paste/fill composition', () {
    Widget wrap(OsGrid<Map<String, dynamic>> grid) => MaterialApp(
      home: Scaffold(body: SizedBox(width: 800, height: 600, child: grid)),
    );

    testWidgets('multi-cell paste pushes ONE undo action; undo/redo exact', (
      tester,
    ) async {
      final clipboardBuffer = StringBuffer();
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
      addTearDown(() {
        clipboardBuffer.clear();
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });

      final rows = [
        {'name': 'n0', 'age': 0},
        {'name': 'n1', 'age': 1},
        {'name': 'n2', 'age': 2},
        {'name': 'n3', 'age': 3},
      ];
      final controller = OsGridController<Map<String, dynamic>>();
      await tester.pumpWidget(
        wrap(
          OsGrid<Map<String, dynamic>>(
            controller: controller,
            columnDefs: const [
              OsColumnDef(
                field: 'name',
                headerName: 'Name',
                width: 120,
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
            undoRedoCellEditing: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      controller.addCellRange(
        const CellRangeParams(
          rowStartIndex: 1,
          rowEndIndex: 2,
          columnStartIndex: 0,
          columnEndIndex: 1,
        ),
      );
      await tester.pumpAndSettle();

      Clipboard.setData(const ClipboardData(text: 'Alice\t30\nBob\t25'));
      controller.pasteFromClipboard();
      await tester.pumpAndSettle();

      // 2×2 paste wrote all four cells ...
      expect(rows[1]['name'], 'Alice');
      expect(rows[1]['age'], 30);
      expect(rows[2]['name'], 'Bob');
      expect(rows[2]['age'], 25);
      // ... as exactly ONE undo action.
      expect(controller.getCurrentUndoSize(), 1);

      controller.undoCellEditing();
      await tester.pumpAndSettle();
      expect(rows[1]['name'], 'n1');
      expect(rows[1]['age'], 1);
      expect(rows[2]['name'], 'n2');
      expect(rows[2]['age'], 2);
      expect(controller.getCurrentRedoSize(), 1);

      controller.redoCellEditing();
      await tester.pumpAndSettle();
      expect(rows[1]['name'], 'Alice');
      expect(rows[1]['age'], 30);
      expect(rows[2]['name'], 'Bob');
      expect(rows[2]['age'], 25);
      expect(controller.getCurrentUndoSize(), 1);
      expect(controller.getCurrentRedoSize(), 0);
    });

    testWidgets('fill handle writes M×N cells as ONE undo action', (
      tester,
    ) async {
      final rows = [
        {'v': 5, 'w': 0, 'x': 0},
        {'v': null, 'w': 0, 'x': 0},
        {'v': null, 'w': 0, 'x': 0},
      ];
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
            cellSelection: const OsCellSelection(),
            undoRedoCellEditing: true,
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

      final customPaint = tester.widget<CustomPaint>(
        find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is RangePainter,
        ),
      );
      final handleRect =
          (customPaint.painter! as RangePainter).lastPaintedFillHandle;
      expect(handleRect, isNotNull);
      final origin = tester.getTopLeft(find.byType(VirtualisedGrid));
      final handle = origin + handleRect!.center;

      final gesture = await tester.startGesture(
        handle,
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveBy(const Offset(0, 42));
      await tester.pump();
      await gesture.moveBy(const Offset(0, 42));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      // Fill wrote rows 1-2 of column v ...
      expect(rows[1]['v'], 5);
      expect(rows[2]['v'], 5);
      // ... as exactly ONE undo action.
      expect(controller.getCurrentUndoSize(), 1);

      controller.undoCellEditing();
      await tester.pumpAndSettle();
      expect(rows[1]['v'], isNull);
      expect(rows[2]['v'], isNull);
      expect(controller.getCurrentRedoSize(), 1);

      controller.redoCellEditing();
      await tester.pumpAndSettle();
      expect(rows[1]['v'], 5);
      expect(rows[2]['v'], 5);
      expect(controller.getCurrentUndoSize(), 1);
      expect(controller.getCurrentRedoSize(), 0);
    });
  });
}
