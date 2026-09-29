import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

void main() {
  group('OsCheckboxCellEditor — model', () {
    test('default constructor has allowIndeterminate = false', () {
      const editor = OsCheckboxCellEditor();
      expect(editor.allowIndeterminate, isFalse);
    });

    test('allowIndeterminate can be set to true', () {
      const editor = OsCheckboxCellEditor(allowIndeterminate: true);
      expect(editor.allowIndeterminate, isTrue);
    });

    test('is a subclass of OsCellEditor', () {
      const editor = OsCheckboxCellEditor();
      expect(editor, isA<OsCellEditor>());
    });
  });

  group('OsCheckboxCellEditor — nextValue (two-state)', () {
    const editor = OsCheckboxCellEditor();

    test('true → false', () {
      expect(editor.nextValue(true), false);
    });

    test('false → true', () {
      expect(editor.nextValue(false), true);
    });

    test('null → true', () {
      expect(editor.nextValue(null), true);
    });

    test('non-boolean value → true', () {
      expect(editor.nextValue('hello'), true);
      expect(editor.nextValue(42), true);
      expect(editor.nextValue([]), true);
    });
  });

  group('OsCheckboxCellEditor — nextValue (tri-state)', () {
    const editor = OsCheckboxCellEditor(allowIndeterminate: true);

    test('true → false', () {
      expect(editor.nextValue(true), false);
    });

    test('false → null', () {
      expect(editor.nextValue(false), isNull);
    });

    test('null → true', () {
      expect(editor.nextValue(null), true);
    });

    test('non-boolean value → true', () {
      expect(editor.nextValue('hello'), true);
      expect(editor.nextValue(42), true);
    });
  });

  group('OsColumnDef — checkbox editor integration', () {
    test('accepts OsCheckboxCellEditor', () {
      const colDef = OsColumnDef(
        field: 'active',
        editable: true,
        cellEditor: OsCheckboxCellEditor(),
      );
      expect(colDef.cellEditor, isA<OsCheckboxCellEditor>());
    });

    test('accepts OsCheckboxCellEditor with allowIndeterminate', () {
      const colDef = OsColumnDef(
        field: 'approved',
        editable: true,
        cellEditor: OsCheckboxCellEditor(allowIndeterminate: true),
      );
      final editor = colDef.cellEditor as OsCheckboxCellEditor;
      expect(editor.allowIndeterminate, isTrue);
    });
  });

  group('OsCheckboxCellEditor — widget integration', () {
    Widget buildGrid({
      List<Map<String, dynamic>>? rowData,
      bool readOnlyEdit = false,
      bool suppressClickEdit = false,
      OsCheckboxCellEditor editor = const OsCheckboxCellEditor(),
      OsGridController<Map<String, dynamic>>? controller,
      ValueChanged<OsCellEditingStartedEvent<Map<String, dynamic>>>?
      onCellEditingStarted,
      ValueChanged<OsCellEditingStoppedEvent<Map<String, dynamic>>>?
      onCellEditingStopped,
      ValueChanged<OsCellValueChangedEvent<Map<String, dynamic>>>?
      onCellValueChanged,
      ValueChanged<OsCellEditRequestEvent<Map<String, dynamic>>>?
      onCellEditRequest,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 300,
            child: OsGrid<Map<String, dynamic>>(
              controller: controller,
              columnDefs: [
                const OsColumnDef(
                  field: 'name',
                  headerName: 'Name',
                  width: 200,
                ),
                OsColumnDef(
                  field: 'active',
                  headerName: 'Active',
                  width: 100,
                  editable: true,
                  cellEditor: editor,
                ),
              ],
              rowData:
                  rowData ??
                  [
                    {'name': 'Alice', 'active': true},
                    {'name': 'Bob', 'active': false},
                    {'name': 'Charlie', 'active': null},
                  ],
              readOnlyEdit: readOnlyEdit,
              suppressClickEdit: suppressClickEdit,
              onCellEditingStarted: onCellEditingStarted,
              onCellEditingStopped: onCellEditingStopped,
              onCellValueChanged: onCellValueChanged,
              onCellEditRequest: onCellEditRequest,
            ),
          ),
        ),
      );
    }

    /// Taps a cell in the grid at the given local offset within the VirtualisedGrid.
    /// Waits for the double-tap timeout to ensure the single tap fires.
    Future<void> tapCell(WidgetTester tester, Offset localOffset) async {
      final gridFinder = find.byType(VirtualisedGrid);
      final gridBox = tester.renderObject(gridFinder) as RenderBox;
      final globalPos = gridBox.localToGlobal(localOffset);
      await tester.tapAt(globalPos);
      // Wait for double-tap timeout so single tap fires
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
    }

    // The checkbox column is at x=200..300 (after the 200px name column).
    // Header is 48px. First row centre is at y = 48 + 21 = 69.
    // Cell centre x = 200 + 50 = 250.
    const checkboxCellOffset = Offset(250, 69);

    testWidgets('renders without errors', (tester) async {
      await tester.pumpWidget(buildGrid());
      await tester.pumpAndSettle();
      expect(find.byType(OsGrid<Map<String, dynamic>>), findsOneWidget);
    });

    testWidgets('clicking checkbox cell toggles value true → false', (
      tester,
    ) async {
      final data = [
        {'name': 'Alice', 'active': true},
      ];
      OsCellValueChangedEvent<Map<String, dynamic>>? changedEvent;

      await tester.pumpWidget(
        buildGrid(rowData: data, onCellValueChanged: (e) => changedEvent = e),
      );
      await tester.pumpAndSettle();

      await tapCell(tester, checkboxCellOffset);

      expect(data[0]['active'], false);
      expect(changedEvent, isNotNull);
      expect(changedEvent!.oldValue, true);
      expect(changedEvent!.newValue, false);
    });

    testWidgets('clicking checkbox cell toggles value false → true', (
      tester,
    ) async {
      final data = [
        {'name': 'Alice', 'active': false},
      ];

      await tester.pumpWidget(buildGrid(rowData: data));
      await tester.pumpAndSettle();

      await tapCell(tester, checkboxCellOffset);

      expect(data[0]['active'], true);
    });

    testWidgets('clicking checkbox cell toggles null → true', (tester) async {
      final data = <Map<String, dynamic>>[
        {'name': 'Alice', 'active': null},
      ];

      await tester.pumpWidget(buildGrid(rowData: data));
      await tester.pumpAndSettle();

      await tapCell(tester, checkboxCellOffset);

      expect(data[0]['active'], true);
    });

    testWidgets('tri-state: false → null when allowIndeterminate is true', (
      tester,
    ) async {
      final data = <Map<String, dynamic>>[
        {'name': 'Alice', 'active': false},
      ];

      await tester.pumpWidget(
        buildGrid(
          rowData: data,
          editor: const OsCheckboxCellEditor(allowIndeterminate: true),
        ),
      );
      await tester.pumpAndSettle();

      await tapCell(tester, checkboxCellOffset);

      expect(data[0]['active'], isNull);
    });

    testWidgets('fires cellEditingStarted and cellEditingStopped events', (
      tester,
    ) async {
      final data = [
        {'name': 'Alice', 'active': true},
      ];
      OsCellEditingStartedEvent<Map<String, dynamic>>? startEvent;
      OsCellEditingStoppedEvent<Map<String, dynamic>>? stopEvent;

      await tester.pumpWidget(
        buildGrid(
          rowData: data,
          onCellEditingStarted: (e) => startEvent = e,
          onCellEditingStopped: (e) => stopEvent = e,
        ),
      );
      await tester.pumpAndSettle();

      await tapCell(tester, checkboxCellOffset);

      expect(startEvent, isNotNull);
      expect(startEvent!.value, true);
      expect(startEvent!.rowIndex, 0);

      expect(stopEvent, isNotNull);
      expect(stopEvent!.oldValue, true);
      expect(stopEvent!.newValue, false);
      expect(stopEvent!.cancelled, isFalse);
    });

    testWidgets('readOnlyEdit fires cellEditRequest instead of mutating', (
      tester,
    ) async {
      final data = [
        {'name': 'Alice', 'active': true},
      ];
      OsCellEditRequestEvent<Map<String, dynamic>>? requestEvent;

      await tester.pumpWidget(
        buildGrid(
          rowData: data,
          readOnlyEdit: true,
          onCellEditRequest: (e) => requestEvent = e,
        ),
      );
      await tester.pumpAndSettle();

      await tapCell(tester, checkboxCellOffset);

      // Data should NOT be mutated
      expect(data[0]['active'], true);

      // But the event should be fired
      expect(requestEvent, isNotNull);
      expect(requestEvent!.oldValue, true);
      expect(requestEvent!.newValue, false);
      expect(requestEvent!.source, 'checkboxToggle');
    });

    testWidgets(
      'checkbox toggles on click even when suppressClickEdit is true',
      (tester) async {
        final data = [
          {'name': 'Alice', 'active': true},
        ];

        await tester.pumpWidget(
          buildGrid(rowData: data, suppressClickEdit: true),
        );
        await tester.pumpAndSettle();

        await tapCell(tester, checkboxCellOffset);

        // Checkbox should still toggle despite suppressClickEdit
        expect(data[0]['active'], false);
      },
    );

    testWidgets('non-editable checkbox cell does not toggle on click', (
      tester,
    ) async {
      final data = [
        {'name': 'Alice', 'active': true},
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 300,
              child: OsGrid<Map<String, dynamic>>(
                columnDefs: const [
                  OsColumnDef(field: 'name', headerName: 'Name', width: 200),
                  OsColumnDef(
                    field: 'active',
                    headerName: 'Active',
                    width: 100,
                    editable: false, // Not editable
                    cellEditor: OsCheckboxCellEditor(),
                  ),
                ],
                rowData: data,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tapCell(tester, checkboxCellOffset);

      // Value should NOT change
      expect(data[0]['active'], true);
    });

    testWidgets('Enter key toggles checkbox when cell is focused', (
      tester,
    ) async {
      final data = [
        {'name': 'Alice', 'active': true},
      ];

      await tester.pumpWidget(buildGrid(rowData: data));
      await tester.pumpAndSettle();

      // Click the checkbox cell to focus it (this also toggles it)
      await tapCell(tester, checkboxCellOffset);

      // Value toggled to false from the click
      expect(data[0]['active'], false);

      // Now press Enter to toggle again
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(data[0]['active'], true);
    });

    testWidgets('Delete key does not clear checkbox cell value', (
      tester,
    ) async {
      final data = [
        {'name': 'Alice', 'active': true},
      ];

      await tester.pumpWidget(buildGrid(rowData: data));
      await tester.pumpAndSettle();

      // Click to focus the checkbox cell (also toggles)
      await tapCell(tester, checkboxCellOffset);

      // Value toggled to false from click
      expect(data[0]['active'], false);

      // Press Delete — should NOT clear the value
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pumpAndSettle();

      // Value should remain false (not null)
      expect(data[0]['active'], false);
    });

    testWidgets('controller stream receives editing events', (tester) async {
      final data = [
        {'name': 'Alice', 'active': true},
      ];
      final controller = OsGridController<Map<String, dynamic>>();
      final startEvents = <OsCellEditingStartedEvent<Map<String, dynamic>>>[];
      final stopEvents = <OsCellEditingStoppedEvent<Map<String, dynamic>>>[];

      controller.onCellEditingStarted.listen(startEvents.add);
      controller.onCellEditingStopped.listen(stopEvents.add);

      await tester.pumpWidget(buildGrid(rowData: data, controller: controller));
      await tester.pumpAndSettle();

      await tapCell(tester, checkboxCellOffset);

      // Allow stream events to propagate
      await tester.pump(const Duration(milliseconds: 50));

      expect(startEvents, hasLength(1));
      expect(stopEvents, hasLength(1));

      controller.dispose();
    });

    testWidgets('valueSetter is called when toggling', (tester) async {
      final data = [
        {'name': 'Alice', 'active': true},
      ];
      bool? setterNewValue;
      dynamic setterOldValue;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 300,
              child: OsGrid<Map<String, dynamic>>(
                columnDefs: [
                  const OsColumnDef(
                    field: 'name',
                    headerName: 'Name',
                    width: 200,
                  ),
                  OsColumnDef(
                    field: 'active',
                    headerName: 'Active',
                    width: 100,
                    editable: true,
                    cellEditor: const OsCheckboxCellEditor(),
                    valueSetter: (params) {
                      setterOldValue = params.oldValue;
                      setterNewValue = params.newValue as bool?;
                      (params.data as Map<String, dynamic>)['active'] =
                          params.newValue;
                      return true;
                    },
                  ),
                ],
                rowData: data,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tapCell(tester, checkboxCellOffset);

      expect(setterOldValue, true);
      expect(setterNewValue, false);
      expect(data[0]['active'], false);
    });

    testWidgets('multiple toggles cycle correctly', (tester) async {
      final data = [
        {'name': 'Alice', 'active': true},
      ];

      await tester.pumpWidget(buildGrid(rowData: data));
      await tester.pumpAndSettle();

      // Toggle 1: true → false
      await tapCell(tester, checkboxCellOffset);
      expect(data[0]['active'], false);

      // Toggle 2: false → true
      await tapCell(tester, checkboxCellOffset);
      expect(data[0]['active'], true);
    });

    testWidgets('tri-state cycles through all three values', (tester) async {
      final data = <Map<String, dynamic>>[
        {'name': 'Alice', 'active': true},
      ];

      await tester.pumpWidget(
        buildGrid(
          rowData: data,
          editor: const OsCheckboxCellEditor(allowIndeterminate: true),
        ),
      );
      await tester.pumpAndSettle();

      // Toggle 1: true → false
      await tapCell(tester, checkboxCellOffset);
      expect(data[0]['active'], false);

      // Toggle 2: false → null
      await tapCell(tester, checkboxCellOffset);
      expect(data[0]['active'], isNull);

      // Toggle 3: null → true
      await tapCell(tester, checkboxCellOffset);
      expect(data[0]['active'], true);
    });
  });
}
