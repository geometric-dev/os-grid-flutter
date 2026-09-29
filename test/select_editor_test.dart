import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

import 'gestures_test_utils.dart';

void main() {
  group('OsSelectCellEditor — model', () {
    test('holds values correctly', () {
      const editor = OsSelectCellEditor(values: ['A', 'B', 'C']);
      expect(editor.values, ['A', 'B', 'C']);
    });

    test('holds optional params', () {
      const editor = OsSelectCellEditor(
        values: ['X', 'Y'],
        valueListGap: 4.0,
        valueListMaxHeight: 300.0,
        valueListMaxWidth: 200.0,
      );
      expect(editor.valueListGap, 4.0);
      expect(editor.valueListMaxHeight, 300.0);
      expect(editor.valueListMaxWidth, 200.0);
    });

    test('defaults optional params to null', () {
      const editor = OsSelectCellEditor(values: ['A']);
      expect(editor.valueListGap, isNull);
      expect(editor.valueListMaxHeight, isNull);
      expect(editor.valueListMaxWidth, isNull);
    });

    test('supports dynamic values (non-string)', () {
      const editor = OsSelectCellEditor(values: [1, 2, 3]);
      expect(editor.values, [1, 2, 3]);
    });

    test('supports empty values list', () {
      const editor = OsSelectCellEditor(values: []);
      expect(editor.values, isEmpty);
    });
  });

  group('OsColumnDef — cellEditor property', () {
    test('accepts OsSelectCellEditor', () {
      const colDef = OsColumnDef(
        field: 'status',
        editable: true,
        cellEditor: OsSelectCellEditor(values: ['Active', 'Inactive']),
      );
      expect(colDef.cellEditor, isA<OsSelectCellEditor>());
      expect((colDef.cellEditor as OsSelectCellEditor).values, [
        'Active',
        'Inactive',
      ]);
    });

    test('cellEditor defaults to null', () {
      const colDef = OsColumnDef(field: 'name', editable: true);
      expect(colDef.cellEditor, isNull);
    });

    test('accepts OsTextCellEditor', () {
      const colDef = OsColumnDef(
        field: 'name',
        editable: true,
        cellEditor: OsTextCellEditor(maxLength: 50),
      );
      expect(colDef.cellEditor, isA<OsTextCellEditor>());
    });

    test('accepts OsNumberCellEditor', () {
      const colDef = OsColumnDef(
        field: 'age',
        editable: true,
        cellEditor: OsNumberCellEditor(min: 0, max: 120),
      );
      expect(colDef.cellEditor, isA<OsNumberCellEditor>());
    });
  });

  group('Select editor — widget integration', () {
    testWidgets('grid renders with select editor configured', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 400,
              child: OsGrid<Map<String, dynamic>>(
                columnDefs: [
                  OsColumnDef(
                    field: 'type',
                    headerName: 'Type',
                    width: 120,
                    editable: true,
                    cellEditor: OsSelectCellEditor(
                      values: ['Contract', 'Permanent'],
                    ),
                  ),
                  OsColumnDef(field: 'name', headerName: 'Name', width: 150),
                ],
                rowData: [
                  {'type': 'Contract', 'name': 'Alice'},
                  {'type': 'Permanent', 'name': 'Bob'},
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Grid should render without errors
      expect(find.byType(VirtualisedGrid), findsOneWidget);
    });

    testWidgets('double-click opens select dropdown', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 400,
              child: OsGrid<Map<String, dynamic>>(
                columnDefs: [
                  OsColumnDef(
                    field: 'type',
                    headerName: 'Type',
                    width: 200,
                    editable: true,
                    cellEditor: OsSelectCellEditor(
                      values: ['Contract', 'Permanent', 'Freelance'],
                    ),
                  ),
                ],
                rowData: [
                  {'type': 'Contract'},
                  {'type': 'Permanent'},
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Double-tap on the first data cell to open the select editor.
      // Header is 48px, first row center is at 48 + 21 = 69.
      const cell = Offset(100, 69);
      await tapCanvasCell(tester, localOffset: cell, settleMs: 50);
      await tapCanvasCell(tester, localOffset: cell);

      // The dropdown should appear — look for the list items
      expect(find.text('Contract'), findsWidgets);
      expect(find.text('Permanent'), findsOneWidget);
      expect(find.text('Freelance'), findsOneWidget);
    });

    testWidgets('selecting a value commits the edit', (tester) async {
      OsCellValueChangedEvent<Map<String, dynamic>>? changedEvent;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 400,
              child: OsGrid<Map<String, dynamic>>(
                columnDefs: [
                  const OsColumnDef<Map<String, dynamic>>(
                    field: 'type',
                    headerName: 'Type',
                    width: 200,
                    editable: true,
                    cellEditor: OsSelectCellEditor(
                      values: ['Contract', 'Permanent', 'Freelance'],
                    ),
                  ),
                ],
                rowData: [
                  {'type': 'Contract'},
                ],
                onCellValueChanged: (event) {
                  changedEvent = event;
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Double-tap to open editor
      const cell = Offset(100, 69);
      await tapCanvasCell(tester, localOffset: cell, settleMs: 50);
      await tapCanvasCell(tester, localOffset: cell);

      // Tap on 'Freelance' in the dropdown
      final freelanceItem = find.text('Freelance');
      expect(freelanceItem, findsOneWidget);
      await tester.tap(freelanceItem);
      await tester.pumpAndSettle();

      // Value should have changed
      expect(changedEvent, isNotNull);
      expect(changedEvent!.oldValue, 'Contract');
      expect(changedEvent!.newValue, 'Freelance');
    });

    testWidgets('escape cancels select editor without committing', (
      tester,
    ) async {
      OsCellValueChangedEvent<Map<String, dynamic>>? changedEvent;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 400,
              child: OsGrid<Map<String, dynamic>>(
                columnDefs: [
                  const OsColumnDef<Map<String, dynamic>>(
                    field: 'type',
                    headerName: 'Type',
                    width: 200,
                    editable: true,
                    cellEditor: OsSelectCellEditor(
                      values: ['Contract', 'Permanent'],
                    ),
                  ),
                ],
                rowData: [
                  {'type': 'Contract'},
                ],
                onCellValueChanged: (event) {
                  changedEvent = event;
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Double-tap to open editor
      const cell = Offset(100, 69);
      await tapCanvasCell(tester, localOffset: cell, settleMs: 50);
      await tapCanvasCell(tester, localOffset: cell);

      // Dropdown should be open
      expect(find.text('Permanent'), findsOneWidget);

      // Press Escape
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      // Dropdown should be closed and no value change
      expect(find.text('Permanent'), findsNothing);
      expect(changedEvent, isNull);
    });

    testWidgets('singleClickEdit opens select dropdown on single click', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 400,
              child: OsGrid<Map<String, dynamic>>(
                singleClickEdit: true,
                columnDefs: [
                  OsColumnDef(
                    field: 'type',
                    headerName: 'Type',
                    width: 200,
                    editable: true,
                    cellEditor: OsSelectCellEditor(values: ['A', 'B', 'C']),
                  ),
                ],
                rowData: [
                  {'type': 'A'},
                  {'type': 'B'},
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Single tap on the first data cell (header=48px, first row center=48+21=69)
      const cell = Offset(100, 69);
      // Wait for double-tap timeout to pass so onTapUp fires.
      await tapCanvasCell(tester, localOffset: cell, settleMs: 500);

      // Dropdown items should be visible
      expect(find.text('C'), findsOneWidget); // 'C' only in dropdown
    });

    testWidgets('cellEditingStarted and cellEditingStopped events fire', (
      tester,
    ) async {
      final startedEvents = <OsCellEditingStartedEvent<Map<String, dynamic>>>[];
      final stoppedEvents = <OsCellEditingStoppedEvent<Map<String, dynamic>>>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 400,
              child: OsGrid<Map<String, dynamic>>(
                columnDefs: [
                  const OsColumnDef<Map<String, dynamic>>(
                    field: 'type',
                    headerName: 'Type',
                    width: 200,
                    editable: true,
                    cellEditor: OsSelectCellEditor(values: ['X', 'Y', 'Z']),
                  ),
                ],
                rowData: [
                  {'type': 'X'},
                ],
                onCellEditingStarted: (event) => startedEvents.add(event),
                onCellEditingStopped: (event) => stoppedEvents.add(event),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Double-tap to open editor
      const cell = Offset(100, 69);
      await tapCanvasCell(tester, localOffset: cell, settleMs: 50);
      await tapCanvasCell(tester, localOffset: cell);

      // cellEditingStarted should have fired
      expect(startedEvents.length, 1);
      expect(startedEvents.first.value, 'X');

      // Select a value
      await tester.tap(find.text('Z'));
      await tester.pumpAndSettle();

      // cellEditingStopped should have fired
      expect(stoppedEvents.length, 1);
      expect(stoppedEvents.first.cancelled, false);
      expect(stoppedEvents.first.newValue, 'Z');
    });

    testWidgets('arrow keys navigate the dropdown list and Enter commits', (
      tester,
    ) async {
      OsCellValueChangedEvent<Map<String, dynamic>>? changedEvent;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 400,
              child: OsGrid<Map<String, dynamic>>(
                singleClickEdit: true,
                columnDefs: [
                  const OsColumnDef<Map<String, dynamic>>(
                    field: 'type',
                    headerName: 'Type',
                    width: 200,
                    editable: true,
                    cellEditor: OsSelectCellEditor(
                      values: ['Alpha', 'Beta', 'Gamma'],
                    ),
                  ),
                ],
                rowData: [
                  {'type': 'Alpha'},
                  {'type': 'Alpha'},
                ],
                onCellValueChanged: (event) => changedEvent = event,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Single tap on first data cell to open
      const cell = Offset(100, 69);
      await tapCanvasCell(tester, localOffset: cell, settleMs: 500);

      // Dropdown should be open
      expect(find.text('Beta'), findsOneWidget);
      expect(find.text('Gamma'), findsOneWidget);

      // Press ArrowDown to move to Beta, then Enter to select
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      // Value should have changed to Beta
      expect(changedEvent, isNotNull);
      expect(changedEvent!.newValue, 'Beta');
    });

    testWidgets('clicking outside dismisses select editor', (tester) async {
      OsCellValueChangedEvent<Map<String, dynamic>>? changedEvent;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 400,
              child: OsGrid<Map<String, dynamic>>(
                singleClickEdit: true,
                columnDefs: [
                  const OsColumnDef<Map<String, dynamic>>(
                    field: 'type',
                    headerName: 'Type',
                    width: 200,
                    editable: true,
                    cellEditor: OsSelectCellEditor(
                      values: ['One', 'Two', 'Three'],
                    ),
                  ),
                ],
                rowData: [
                  {'type': 'One'},
                  {'type': 'One'},
                ],
                onCellValueChanged: (event) => changedEvent = event,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Open the dropdown via single click on first data cell
      const cell = Offset(100, 69);
      await tapCanvasCell(tester, localOffset: cell, settleMs: 500);

      // Dropdown should be open
      expect(find.text('Two'), findsOneWidget);

      // Press Escape to dismiss
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      // Dropdown should be closed and no value change
      expect(find.text('Two'), findsNothing);
      expect(find.text('Three'), findsNothing);
      expect(changedEvent, isNull);
    });
  });
}
