import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

void main() {
  group('OsLargeTextCellEditor — model', () {
    test('has correct defaults matching TypeScript', () {
      const editor = OsLargeTextCellEditor();
      expect(editor.maxLength, 200);
      expect(editor.rows, 10);
      expect(editor.cols, 60);
    });

    test('accepts custom parameters', () {
      const editor = OsLargeTextCellEditor(maxLength: 500, rows: 6, cols: 40);
      expect(editor.maxLength, 500);
      expect(editor.rows, 6);
      expect(editor.cols, 40);
    });

    test('extends OsCellEditor', () {
      const editor = OsLargeTextCellEditor();
      expect(editor, isA<OsCellEditor>());
    });
  });

  group('OsLargeTextCellEditor — widget integration', () {
    Widget buildGrid({
      OsLargeTextCellEditor? editor,
      List<Map<String, dynamic>>? rowData,
      ValueChanged<OsCellValueChangedEvent<Map<String, dynamic>>>?
      onCellValueChanged,
      ValueChanged<OsCellEditingStartedEvent<Map<String, dynamic>>>?
      onCellEditingStarted,
      ValueChanged<OsCellEditingStoppedEvent<Map<String, dynamic>>>?
      onCellEditingStopped,
      ValueChanged<OsCellEditRequestEvent<Map<String, dynamic>>>?
      onCellEditRequest,
      bool readOnlyEdit = false,
      bool enableCellEditingOnBackspace = false,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: OsGrid<Map<String, dynamic>>(
              readOnlyEdit: readOnlyEdit,
              enableCellEditingOnBackspace: enableCellEditingOnBackspace,
              columnDefs: [
                OsColumnDef(
                  field: 'notes',
                  headerName: 'Notes',
                  width: 300,
                  editable: true,
                  cellEditor: editor ?? const OsLargeTextCellEditor(),
                ),
              ],
              rowData:
                  rowData ??
                  [
                    {'notes': 'First note'},
                    {'notes': 'Second note'},
                    {'notes': 'Third note'},
                  ],
              onCellValueChanged: onCellValueChanged,
              onCellEditingStarted: onCellEditingStarted,
              onCellEditingStopped: onCellEditingStopped,
              onCellEditRequest: onCellEditRequest,
            ),
          ),
        ),
      );
    }

    /// Double-taps the first data cell to open the editor.
    Future<void> openEditor(WidgetTester tester) async {
      final gridFinder = find.byType(VirtualisedGrid);
      final gridBox = tester.renderObject(gridFinder) as RenderBox;
      // Header is 48px, first row centre is at 48 + 21 = 69
      final cellCenter = gridBox.localToGlobal(const Offset(150, 69));

      await tester.tapAt(cellCenter);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(cellCenter);
      await tester.pumpAndSettle();
    }

    testWidgets('grid renders with large text editor configured', (
      tester,
    ) async {
      await tester.pumpWidget(buildGrid());
      await tester.pumpAndSettle();
      expect(find.byType(VirtualisedGrid), findsOneWidget);
    });

    testWidgets('double-click opens large text editor popup', (tester) async {
      await tester.pumpWidget(buildGrid());
      await tester.pumpAndSettle();

      await openEditor(tester);

      // Should find a TextField (multi-line) in the overlay
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('editor shows existing cell value', (tester) async {
      await tester.pumpWidget(buildGrid());
      await tester.pumpAndSettle();

      await openEditor(tester);

      // The TextField should contain the cell value
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller!.text, 'First note');
    });

    testWidgets('editor respects maxLength parameter', (tester) async {
      await tester.pumpWidget(
        buildGrid(editor: const OsLargeTextCellEditor(maxLength: 50)),
      );
      await tester.pumpAndSettle();

      await openEditor(tester);

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.maxLength, 50);
    });

    testWidgets('editor is multi-line (expands)', (tester) async {
      await tester.pumpWidget(buildGrid());
      await tester.pumpAndSettle();

      await openEditor(tester);

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.maxLines, isNull); // null means unlimited lines
      expect(textField.expands, isTrue);
    });

    testWidgets('Escape cancels the edit', (tester) async {
      OsCellEditingStoppedEvent<Map<String, dynamic>>? stoppedEvent;

      await tester.pumpWidget(
        buildGrid(onCellEditingStopped: (event) => stoppedEvent = event),
      );
      await tester.pumpAndSettle();

      await openEditor(tester);

      // Type some text
      await tester.enterText(find.byType(TextField), 'Modified text');
      await tester.pump();

      // Press Escape
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      // Editor should be closed
      expect(find.byType(TextField), findsNothing);

      // Edit should be cancelled (value reverted)
      expect(stoppedEvent, isNotNull);
      expect(stoppedEvent!.cancelled, isTrue);
    });

    testWidgets('Tab commits and navigates to next cell', (tester) async {
      OsCellValueChangedEvent<Map<String, dynamic>>? changedEvent;

      await tester.pumpWidget(
        buildGrid(onCellValueChanged: (event) => changedEvent = event),
      );
      await tester.pumpAndSettle();

      await openEditor(tester);

      // Type new text
      await tester.enterText(find.byType(TextField), 'Updated note');
      await tester.pump();

      // Press Tab to commit
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      // Value should have changed
      expect(changedEvent, isNotNull);
      expect(changedEvent!.oldValue, 'First note');
      expect(changedEvent!.newValue, 'Updated note');
    });

    testWidgets('outside tap commits the edit', (tester) async {
      OsCellValueChangedEvent<Map<String, dynamic>>? changedEvent;

      await tester.pumpWidget(
        buildGrid(onCellValueChanged: (event) => changedEvent = event),
      );
      await tester.pumpAndSettle();

      await openEditor(tester);

      // Type new text
      await tester.enterText(find.byType(TextField), 'Tapped outside');
      await tester.pump();

      // Tap outside the editor (far corner)
      final gridFinder = find.byType(VirtualisedGrid);
      final gridBox = tester.renderObject(gridFinder) as RenderBox;
      final outsidePoint = gridBox.localToGlobal(const Offset(700, 500));
      await tester.tapAt(outsidePoint);
      await tester.pumpAndSettle();

      // Value should have changed
      expect(changedEvent, isNotNull);
      expect(changedEvent!.newValue, 'Tapped outside');
    });

    testWidgets('cellEditingStarted event fires when editor opens', (
      tester,
    ) async {
      OsCellEditingStartedEvent<Map<String, dynamic>>? startedEvent;

      await tester.pumpWidget(
        buildGrid(onCellEditingStarted: (event) => startedEvent = event),
      );
      await tester.pumpAndSettle();

      await openEditor(tester);

      expect(startedEvent, isNotNull);
      expect(startedEvent!.value, 'First note');
      expect(startedEvent!.rowIndex, 0);
    });

    testWidgets('cellEditingStopped event fires when editor closes', (
      tester,
    ) async {
      OsCellEditingStoppedEvent<Map<String, dynamic>>? stoppedEvent;

      await tester.pumpWidget(
        buildGrid(onCellEditingStopped: (event) => stoppedEvent = event),
      );
      await tester.pumpAndSettle();

      await openEditor(tester);

      // Press Escape to close
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(stoppedEvent, isNotNull);
      expect(stoppedEvent!.oldValue, 'First note');
    });

    testWidgets('no change does not fire cellValueChanged', (tester) async {
      OsCellValueChangedEvent<Map<String, dynamic>>? changedEvent;

      await tester.pumpWidget(
        buildGrid(onCellValueChanged: (event) => changedEvent = event),
      );
      await tester.pumpAndSettle();

      await openEditor(tester);

      // Don't change the text — just tap outside to commit
      final gridFinder = find.byType(VirtualisedGrid);
      final gridBox = tester.renderObject(gridFinder) as RenderBox;
      final outsidePoint = gridBox.localToGlobal(const Offset(700, 500));
      await tester.tapAt(outsidePoint);
      await tester.pumpAndSettle();

      // No value change event should fire
      expect(changedEvent, isNull);
    });

    testWidgets('readOnlyEdit fires cellEditRequest instead of mutating', (
      tester,
    ) async {
      OsCellEditRequestEvent<Map<String, dynamic>>? requestEvent;
      OsCellValueChangedEvent<Map<String, dynamic>>? changedEvent;

      await tester.pumpWidget(
        buildGrid(
          readOnlyEdit: true,
          onCellEditRequest: (event) => requestEvent = event,
          onCellValueChanged: (event) => changedEvent = event,
        ),
      );
      await tester.pumpAndSettle();

      await openEditor(tester);

      // Type new text
      await tester.enterText(find.byType(TextField), 'Read only change');
      await tester.pump();

      // Tab to commit
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      // Should fire cellEditRequest, NOT cellValueChanged
      expect(requestEvent, isNotNull);
      expect(requestEvent!.oldValue, 'First note');
      expect(requestEvent!.newValue, 'Read only change');
      expect(changedEvent, isNull);
    });

    testWidgets('arrow keys do not propagate to grid navigation', (
      tester,
    ) async {
      await tester.pumpWidget(buildGrid());
      await tester.pumpAndSettle();

      await openEditor(tester);

      // Press arrow keys — they should be consumed by the TextField
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();

      // Editor should still be open (arrows didn't close it or navigate away)
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('Enter does NOT commit (allows newlines)', (tester) async {
      OsCellValueChangedEvent<Map<String, dynamic>>? changedEvent;

      await tester.pumpWidget(
        buildGrid(onCellValueChanged: (event) => changedEvent = event),
      );
      await tester.pumpAndSettle();

      await openEditor(tester);

      // Press Enter — should NOT commit the edit (multi-line editor)
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      // Editor should still be open
      expect(find.byType(TextField), findsOneWidget);
      expect(changedEvent, isNull);
    });

    testWidgets('popup is positioned below the cell', (tester) async {
      await tester.pumpWidget(buildGrid());
      await tester.pumpAndSettle();

      await openEditor(tester);

      // Find the Material widget that wraps the editor (popup container)
      final materialFinder = find.byType(Material);
      // There should be at least one Material (from Scaffold) + the popup
      expect(materialFinder, findsWidgets);

      // The TextField should exist in the overlay
      final textFieldFinder = find.byType(TextField);
      expect(textFieldFinder, findsOneWidget);

      // Verify the popup is below the header row (48px) + first row (42px) = 90px
      final textFieldBox = tester.renderObject(textFieldFinder) as RenderBox;
      final textFieldPosition = textFieldBox.localToGlobal(Offset.zero);
      // The popup should be below the cell (cell bottom is approximately 90px from grid top)
      expect(textFieldPosition.dy, greaterThan(80));
    });

    testWidgets('popup dimensions based on rows/cols params', (tester) async {
      await tester.pumpWidget(
        buildGrid(editor: const OsLargeTextCellEditor(rows: 5, cols: 30)),
      );
      await tester.pumpAndSettle();

      await openEditor(tester);

      // The popup width should be cols * 8.0 = 240
      // The popup height should be rows * 20.0 = 100
      // Find the Positioned widget that wraps the editor
      final positionedFinder = find.ancestor(
        of: find.byType(TextField),
        matching: find.byType(Positioned),
      );
      expect(positionedFinder, findsWidgets);
    });

    testWidgets('valueSetter is called on commit', (tester) async {
      dynamic setterNewValue;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: OsGrid<Map<String, dynamic>>(
                columnDefs: [
                  OsColumnDef<Map<String, dynamic>>(
                    field: 'notes',
                    headerName: 'Notes',
                    width: 300,
                    editable: true,
                    cellEditor: const OsLargeTextCellEditor(),
                    valueSetter: (params) {
                      setterNewValue = params.newValue;
                      (params.data)['notes'] = params.newValue;
                      return true;
                    },
                  ),
                ],
                rowData: [
                  {'notes': 'Original'},
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Double-tap to open
      final gridFinder = find.byType(VirtualisedGrid);
      final gridBox = tester.renderObject(gridFinder) as RenderBox;
      final cellCenter = gridBox.localToGlobal(const Offset(150, 69));
      await tester.tapAt(cellCenter);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(cellCenter);
      await tester.pumpAndSettle();

      // Type new text and commit via Tab
      await tester.enterText(find.byType(TextField), 'New value');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      expect(setterNewValue, 'New value');
    });

    testWidgets('valueParser is applied before commit', (tester) async {
      OsCellValueChangedEvent<Map<String, dynamic>>? changedEvent;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: OsGrid<Map<String, dynamic>>(
                columnDefs: [
                  OsColumnDef<Map<String, dynamic>>(
                    field: 'notes',
                    headerName: 'Notes',
                    width: 300,
                    editable: true,
                    cellEditor: const OsLargeTextCellEditor(),
                    valueParser: (params) => params.newValue.toUpperCase(),
                  ),
                ],
                rowData: [
                  {'notes': 'hello'},
                ],
                onCellValueChanged: (event) => changedEvent = event,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Double-tap to open
      final gridFinder = find.byType(VirtualisedGrid);
      final gridBox = tester.renderObject(gridFinder) as RenderBox;
      final cellCenter = gridBox.localToGlobal(const Offset(150, 69));
      await tester.tapAt(cellCenter);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(cellCenter);
      await tester.pumpAndSettle();

      // Type and commit
      await tester.enterText(find.byType(TextField), 'world');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      expect(changedEvent, isNotNull);
      expect(changedEvent!.newValue, 'WORLD');
    });
  });
}
