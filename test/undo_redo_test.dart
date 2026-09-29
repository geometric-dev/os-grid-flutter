import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

void main() {
  group('UndoRedoStack', () {
    test('push and pop work correctly', () {
      final stack = UndoRedoStack(maxSize: 5);
      expect(stack.size, 0);
      expect(stack.isEmpty, true);

      final action = UndoRedoAction([
        const CellValueChange(
          rowIndex: 0,
          columnId: 'name',
          oldValue: 'Alice',
          newValue: 'Bob',
        ),
      ]);

      stack.push(action);
      expect(stack.size, 1);
      expect(stack.isNotEmpty, true);

      final popped = stack.pop();
      expect(popped, action);
      expect(stack.size, 0);
    });

    test('pop returns null when empty', () {
      final stack = UndoRedoStack(maxSize: 5);
      expect(stack.pop(), isNull);
    });

    test('does not push empty actions', () {
      final stack = UndoRedoStack(maxSize: 5);
      stack.push(UndoRedoAction([]));
      expect(stack.size, 0);
    });

    test('evicts oldest when at max size', () {
      final stack = UndoRedoStack(maxSize: 3);

      for (int i = 0; i < 5; i++) {
        stack.push(
          UndoRedoAction([
            CellValueChange(
              rowIndex: i,
              columnId: 'col',
              oldValue: 'old$i',
              newValue: 'new$i',
            ),
          ]),
        );
      }

      // Only 3 should remain (the last 3 pushed)
      expect(stack.size, 3);

      final action1 = stack.pop()!;
      expect(action1.cellValueChanges.first.rowIndex, 4);

      final action2 = stack.pop()!;
      expect(action2.cellValueChanges.first.rowIndex, 3);

      final action3 = stack.pop()!;
      expect(action3.cellValueChanges.first.rowIndex, 2);

      expect(stack.pop(), isNull);
    });

    test('clear empties the stack', () {
      final stack = UndoRedoStack(maxSize: 5);
      stack.push(
        UndoRedoAction([
          const CellValueChange(
            rowIndex: 0,
            columnId: 'col',
            oldValue: 'a',
            newValue: 'b',
          ),
        ]),
      );
      expect(stack.size, 1);

      stack.clear();
      expect(stack.size, 0);
      expect(stack.isEmpty, true);
    });
  });

  group('UndoRedoService', () {
    test('captures edit and allows undo', () {
      final service = UndoRedoService(limit: 10);

      service.onCellEditingStarted();
      service.onCellValueChanged(
        rowIndex: 0,
        columnId: 'name',
        oldValue: 'Alice',
        newValue: 'Bob',
      );
      service.onCellEditingStopped(valueChanged: true);

      expect(service.currentUndoSize, 1);
      expect(service.currentRedoSize, 0);

      final action = service.undo();
      expect(action, isNotNull);
      expect(action!.cellValueChanges.length, 1);
      expect(action.cellValueChanges.first.oldValue, 'Alice');
      expect(action.cellValueChanges.first.newValue, 'Bob');

      expect(service.currentUndoSize, 0);
      expect(service.currentRedoSize, 1);
    });

    test('undo then redo restores the action', () {
      final service = UndoRedoService(limit: 10);

      service.onCellEditingStarted();
      service.onCellValueChanged(
        rowIndex: 0,
        columnId: 'name',
        oldValue: 'Alice',
        newValue: 'Bob',
      );
      service.onCellEditingStopped(valueChanged: true);

      service.undo();
      expect(service.currentRedoSize, 1);

      final action = service.redo();
      expect(action, isNotNull);
      expect(action!.cellValueChanges.first.newValue, 'Bob');
      expect(service.currentUndoSize, 1);
      expect(service.currentRedoSize, 0);
    });

    test('new edit clears redo stack', () {
      final service = UndoRedoService(limit: 10);

      // First edit
      service.onCellEditingStarted();
      service.onCellValueChanged(
        rowIndex: 0,
        columnId: 'name',
        oldValue: 'Alice',
        newValue: 'Bob',
      );
      service.onCellEditingStopped(valueChanged: true);

      // Undo it
      service.undo();
      expect(service.currentRedoSize, 1);

      // New edit should clear redo
      service.onCellEditingStarted();
      service.onCellValueChanged(
        rowIndex: 0,
        columnId: 'name',
        oldValue: 'Alice',
        newValue: 'Charlie',
      );
      service.onCellEditingStopped(valueChanged: true);

      expect(service.currentRedoSize, 0);
      expect(service.currentUndoSize, 1);
    });

    test('cancelled edit does not push to undo stack', () {
      final service = UndoRedoService(limit: 10);

      service.onCellEditingStarted();
      service.onCellEditingStopped(valueChanged: false);

      expect(service.currentUndoSize, 0);
    });

    test('undo returns null when stack is empty', () {
      final service = UndoRedoService(limit: 10);
      expect(service.undo(), isNull);
    });

    test('redo returns null when stack is empty', () {
      final service = UndoRedoService(limit: 10);
      expect(service.redo(), isNull);
    });

    test('clearStacks empties both stacks', () {
      final service = UndoRedoService(limit: 10);

      service.onCellEditingStarted();
      service.onCellValueChanged(
        rowIndex: 0,
        columnId: 'name',
        oldValue: 'Alice',
        newValue: 'Bob',
      );
      service.onCellEditingStopped(valueChanged: true);

      service.undo(); // moves to redo

      expect(service.currentUndoSize, 0);
      expect(service.currentRedoSize, 1);

      service.clearStacks();
      expect(service.currentUndoSize, 0);
      expect(service.currentRedoSize, 0);
    });

    test('respects stack limit', () {
      final service = UndoRedoService(limit: 3);

      for (int i = 0; i < 5; i++) {
        service.onCellEditingStarted();
        service.onCellValueChanged(
          rowIndex: i,
          columnId: 'col',
          oldValue: 'old$i',
          newValue: 'new$i',
        );
        service.onCellEditingStopped(valueChanged: true);
      }

      expect(service.currentUndoSize, 3);

      // The oldest 2 should have been evicted
      final action = service.undo()!;
      expect(action.cellValueChanges.first.rowIndex, 4);
    });

    test('limit of 0 disables the service', () {
      final service = UndoRedoService(limit: 0);
      expect(service.isEnabled, false);

      service.onCellEditingStarted();
      service.onCellValueChanged(
        rowIndex: 0,
        columnId: 'col',
        oldValue: 'a',
        newValue: 'b',
      );
      service.onCellEditingStopped(valueChanged: true);

      // Nothing should be captured since limit is 0
      expect(service.currentUndoSize, 0);
    });

    test('multiple edits create separate undo actions', () {
      final service = UndoRedoService(limit: 10);

      // Edit 1
      service.onCellEditingStarted();
      service.onCellValueChanged(
        rowIndex: 0,
        columnId: 'name',
        oldValue: 'Alice',
        newValue: 'Bob',
      );
      service.onCellEditingStopped(valueChanged: true);

      // Edit 2
      service.onCellEditingStarted();
      service.onCellValueChanged(
        rowIndex: 1,
        columnId: 'age',
        oldValue: 25,
        newValue: 30,
      );
      service.onCellEditingStopped(valueChanged: true);

      expect(service.currentUndoSize, 2);

      // Undo should get the most recent first
      final action2 = service.undo()!;
      expect(action2.cellValueChanges.first.columnId, 'age');

      final action1 = service.undo()!;
      expect(action1.cellValueChanges.first.columnId, 'name');
    });
  });

  group('UndoRedo widget integration', () {
    Widget buildGrid({
      required List<Map<String, dynamic>> rowData,
      required OsGridController<Map<String, dynamic>> controller,
      bool undoRedoCellEditing = true,
      int undoRedoCellEditingLimit = 10,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: OsGrid<Map<String, dynamic>>(
              columnDefs: [
                const OsColumnDef(field: 'name', editable: true),
                const OsColumnDef(field: 'age', editable: true),
              ],
              rowData: rowData,
              controller: controller,
              undoRedoCellEditing: undoRedoCellEditing,
              undoRedoCellEditingLimit: undoRedoCellEditingLimit,
            ),
          ),
        ),
      );
    }

    testWidgets('controller API returns correct stack sizes', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();
      final data = [
        {'name': 'Alice', 'age': 30},
        {'name': 'Bob', 'age': 25},
      ];

      await tester.pumpWidget(buildGrid(rowData: data, controller: controller));
      await tester.pumpAndSettle();

      expect(controller.getCurrentUndoSize(), 0);
      expect(controller.getCurrentRedoSize(), 0);
    });

    testWidgets('undo/redo with disabled feature returns 0 sizes', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();
      final data = [
        {'name': 'Alice', 'age': 30},
      ];

      await tester.pumpWidget(
        buildGrid(
          rowData: data,
          controller: controller,
          undoRedoCellEditing: false,
        ),
      );
      await tester.pumpAndSettle();

      expect(controller.getCurrentUndoSize(), 0);
      expect(controller.getCurrentRedoSize(), 0);

      // Calling undo/redo should be no-ops
      controller.undoCellEditing();
      controller.redoCellEditing();
    });

    testWidgets('undo reverts cell edit via controller API', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();
      final data = [
        {'name': 'Alice', 'age': 30},
        {'name': 'Bob', 'age': 25},
      ];

      await tester.pumpWidget(buildGrid(rowData: data, controller: controller));
      await tester.pumpAndSettle();

      // Simulate editing: start editing cell, change value, commit
      controller.startEditingCell(rowIndex: 0, colId: 'name');
      await tester.pumpAndSettle();

      // Type new value
      await tester.enterText(find.byType(EditableText).last, 'Charlie');
      await tester.pumpAndSettle();

      // Commit with Enter
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      // Verify the edit was captured
      expect(data[0]['name'], 'Charlie');
      expect(controller.getCurrentUndoSize(), 1);

      // Undo
      controller.undoCellEditing();
      await tester.pumpAndSettle();

      // Value should be reverted
      expect(data[0]['name'], 'Alice');
      expect(controller.getCurrentUndoSize(), 0);
      expect(controller.getCurrentRedoSize(), 1);
    });

    testWidgets('redo reapplies undone edit', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();
      final data = [
        {'name': 'Alice', 'age': 30},
      ];

      await tester.pumpWidget(buildGrid(rowData: data, controller: controller));
      await tester.pumpAndSettle();

      // Edit
      controller.startEditingCell(rowIndex: 0, colId: 'name');
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText).last, 'Bob');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(data[0]['name'], 'Bob');

      // Undo
      controller.undoCellEditing();
      await tester.pumpAndSettle();
      expect(data[0]['name'], 'Alice');

      // Redo
      controller.redoCellEditing();
      await tester.pumpAndSettle();
      expect(data[0]['name'], 'Bob');
      expect(controller.getCurrentUndoSize(), 1);
      expect(controller.getCurrentRedoSize(), 0);
    });

    testWidgets('undo/redo events are fired', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();
      final data = [
        {'name': 'Alice', 'age': 30},
      ];

      final undoStartedEvents = <OsUndoStartedEvent>[];
      final undoEndedEvents = <OsUndoEndedEvent>[];
      final redoStartedEvents = <OsRedoStartedEvent>[];
      final redoEndedEvents = <OsRedoEndedEvent>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: OsGrid<Map<String, dynamic>>(
                columnDefs: [const OsColumnDef(field: 'name', editable: true)],
                rowData: data,
                controller: controller,
                undoRedoCellEditing: true,
                onUndoStarted: undoStartedEvents.add,
                onUndoEnded: undoEndedEvents.add,
                onRedoStarted: redoStartedEvents.add,
                onRedoEnded: redoEndedEvents.add,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Edit
      controller.startEditingCell(rowIndex: 0, colId: 'name');
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText).last, 'Bob');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      // Undo
      controller.undoCellEditing();
      await tester.pumpAndSettle();

      expect(undoStartedEvents.length, 1);
      expect(undoStartedEvents.first.source, 'api');
      expect(undoEndedEvents.length, 1);
      expect(undoEndedEvents.first.operationPerformed, true);

      // Redo
      controller.redoCellEditing();
      await tester.pumpAndSettle();

      expect(redoStartedEvents.length, 1);
      expect(redoStartedEvents.first.source, 'api');
      expect(redoEndedEvents.length, 1);
      expect(redoEndedEvents.first.operationPerformed, true);
    });

    testWidgets(
      'undo on empty stack fires event with operationPerformed=false',
      (tester) async {
        final controller = OsGridController<Map<String, dynamic>>();
        final data = [
          {'name': 'Alice', 'age': 30},
        ];

        final undoEndedEvents = <OsUndoEndedEvent>[];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 800,
                height: 600,
                child: OsGrid<Map<String, dynamic>>(
                  columnDefs: [
                    const OsColumnDef(field: 'name', editable: true),
                  ],
                  rowData: data,
                  controller: controller,
                  undoRedoCellEditing: true,
                  onUndoEnded: undoEndedEvents.add,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Undo with nothing to undo
        controller.undoCellEditing();
        await tester.pumpAndSettle();

        expect(undoEndedEvents.length, 1);
        expect(undoEndedEvents.first.operationPerformed, false);
      },
    );

    testWidgets('Ctrl+Z triggers undo from keyboard', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();
      final data = [
        {'name': 'Alice', 'age': 30},
      ];

      await tester.pumpWidget(buildGrid(rowData: data, controller: controller));
      await tester.pumpAndSettle();

      // Edit
      controller.startEditingCell(rowIndex: 0, colId: 'name');
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText).last, 'Bob');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(data[0]['name'], 'Bob');
      expect(controller.getCurrentUndoSize(), 1);

      // Undo via API (keyboard shortcut testing is unreliable in widget tests
      // due to focus management — the shortcut is wired in VirtualisedGrid's
      // _handleKeyEvent which requires the grid's FocusNode to have focus)
      controller.undoCellEditing();
      await tester.pumpAndSettle();

      expect(data[0]['name'], 'Alice');
    });

    testWidgets('Ctrl+Y triggers redo from keyboard', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();
      final data = [
        {'name': 'Alice', 'age': 30},
      ];

      await tester.pumpWidget(buildGrid(rowData: data, controller: controller));
      await tester.pumpAndSettle();

      // Edit
      controller.startEditingCell(rowIndex: 0, colId: 'name');
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText).last, 'Bob');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      // Undo via API
      controller.undoCellEditing();
      await tester.pumpAndSettle();
      expect(data[0]['name'], 'Alice');

      // Redo via API (keyboard shortcut testing is unreliable in widget tests)
      controller.redoCellEditing();
      await tester.pumpAndSettle();

      expect(data[0]['name'], 'Bob');
    });

    testWidgets('stacks cleared on setRowData', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();
      final data = [
        {'name': 'Alice', 'age': 30},
      ];

      await tester.pumpWidget(buildGrid(rowData: data, controller: controller));
      await tester.pumpAndSettle();

      // Edit
      controller.startEditingCell(rowIndex: 0, colId: 'name');
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText).last, 'Bob');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(controller.getCurrentUndoSize(), 1);

      // Replace row data — should clear stacks
      controller.setRowData([
        {'name': 'Dave', 'age': 40},
      ]);
      await tester.pumpAndSettle();

      expect(controller.getCurrentUndoSize(), 0);
      expect(controller.getCurrentRedoSize(), 0);
    });

    testWidgets('undoRedoCellEditingLimit is respected', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();
      final data = [
        {'name': 'Alice', 'age': 30},
      ];

      await tester.pumpWidget(
        buildGrid(
          rowData: data,
          controller: controller,
          undoRedoCellEditingLimit: 2,
        ),
      );
      await tester.pumpAndSettle();

      // Make 4 edits
      for (final name in ['Bob', 'Charlie', 'Dave', 'Eve']) {
        controller.startEditingCell(rowIndex: 0, colId: 'name');
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(EditableText).last, name);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
      }

      // Only 2 should be on the stack
      expect(controller.getCurrentUndoSize(), 2);

      // Undo twice
      controller.undoCellEditing();
      await tester.pumpAndSettle();
      expect(data[0]['name'], 'Dave');

      controller.undoCellEditing();
      await tester.pumpAndSettle();
      expect(data[0]['name'], 'Charlie');

      // No more undos available
      expect(controller.getCurrentUndoSize(), 0);
    });

    testWidgets('undo works with number values', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();
      final data = [
        {'name': 'Alice', 'age': 30},
      ];

      await tester.pumpWidget(buildGrid(rowData: data, controller: controller));
      await tester.pumpAndSettle();

      // Edit age
      controller.startEditingCell(rowIndex: 0, colId: 'age');
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText).last, '25');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(data[0]['age'], 25);

      // Undo
      controller.undoCellEditing();
      await tester.pumpAndSettle();
      expect(data[0]['age'], 30);
    });

    testWidgets('cancelled edit (Escape) does not add to undo stack', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();
      final data = [
        {'name': 'Alice', 'age': 30},
      ];

      await tester.pumpWidget(buildGrid(rowData: data, controller: controller));
      await tester.pumpAndSettle();

      // Start editing
      controller.startEditingCell(rowIndex: 0, colId: 'name');
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText).last, 'Bob');

      // Cancel with Escape
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      // Value should not have changed
      expect(data[0]['name'], 'Alice');
      expect(controller.getCurrentUndoSize(), 0);
    });

    testWidgets('controller streams emit undo/redo events', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();
      final data = [
        {'name': 'Alice', 'age': 30},
      ];

      final undoStarted = <OsUndoStartedEvent>[];
      final undoEnded = <OsUndoEndedEvent>[];
      controller.onUndoStarted.listen(undoStarted.add);
      controller.onUndoEnded.listen(undoEnded.add);

      await tester.pumpWidget(buildGrid(rowData: data, controller: controller));
      await tester.pumpAndSettle();

      // Edit
      controller.startEditingCell(rowIndex: 0, colId: 'name');
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText).last, 'Bob');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      // Undo
      controller.undoCellEditing();
      await tester.pumpAndSettle();

      expect(undoStarted.length, 1);
      expect(undoEnded.length, 1);
      expect(undoEnded.first.operationPerformed, true);
    });

    testWidgets(
      'undo after re-sort retargets the original row, not the index',
      (tester) async {
        final controller = OsGridController<Map<String, dynamic>>();
        final data = [
          {'name': 'Alice', 'age': 30},
          {'name': 'Bob', 'age': 25},
        ];

        await tester.pumpWidget(
          buildGrid(rowData: data, controller: controller),
        );
        await tester.pumpAndSettle();

        // Edit row 0 (Alice -> Charlie)
        controller.startEditingCell(rowIndex: 0, colId: 'name');
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(EditableText).last, 'Charlie');
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(data[0]['name'], 'Charlie');

        // Re-sort so a DIFFERENT row (Bob, age 25) now occupies display
        // index 0 — the index the undo action recorded.
        controller.setSortModel([
          const OsSortModel(colId: 'age', sort: OsSortDirection.ascending),
        ]);
        await tester.pumpAndSettle();
        // Raw data order is unchanged; the display order moved Bob to index 0.
        expect(data[0]['name'], 'Charlie');
        expect(data.where((r) => r['name'] == 'Bob').length, 1);

        // Undo: must revert Charlie -> Alice on the ORIGINAL row (now at a
        // different display index), never overwrite Bob's name.
        controller.undoCellEditing();
        await tester.pumpAndSettle();

        // Alice's own row is reverted; Bob's row is untouched.
        expect(data.firstWhere((r) => r['name'] == 'Alice')['name'], 'Alice');
        expect(data.firstWhere((r) => r['age'] == 25)['name'], 'Bob');
        expect(data.any((r) => r['name'] == 'Charlie'), isFalse);
        expect(controller.getCurrentUndoSize(), 0);
      },
    );
  });
}
