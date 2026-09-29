import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

void main() {
  group('OsCustomCellEditor — model', () {
    test('holds builder and default options', () {
      final editor = OsCustomCellEditor(
        builder: (context, params) => const SizedBox(),
      );
      expect(editor.popup, isFalse);
      expect(editor.popupPosition, PopupPosition.over);
      expect(editor.suppressEnterCommit, isFalse);
      expect(editor.suppressEscapeCancel, isFalse);
    });

    test('holds popup options', () {
      final editor = OsCustomCellEditor(
        builder: (context, params) => const SizedBox(),
        popup: true,
        popupPosition: PopupPosition.under,
      );
      expect(editor.popup, isTrue);
      expect(editor.popupPosition, PopupPosition.under);
    });

    test('holds suppress options', () {
      final editor = OsCustomCellEditor(
        builder: (context, params) => const SizedBox(),
        suppressEnterCommit: true,
        suppressEscapeCancel: true,
      );
      expect(editor.suppressEnterCommit, isTrue);
      expect(editor.suppressEscapeCancel, isTrue);
    });

    test('extends OsCellEditor', () {
      final editor = OsCustomCellEditor(
        builder: (context, params) => const SizedBox(),
      );
      expect(editor, isA<OsCellEditor>());
    });
  });

  group('CellEditorParams', () {
    test('holds all required fields', () {
      dynamic capturedValue;
      bool stopCalled = false;
      bool cancelledValue = false;

      final params = CellEditorParams<Map<String, dynamic>>(
        value: 'hello',
        data: {'name': 'Alice'},
        rowIndex: 0,
        colDef: const OsColumnDef(field: 'name'),
        column: 'name',
        eventKey: 'Enter',
        onValueChanged: (v) => capturedValue = v,
        stopEditing: (cancel) {
          stopCalled = true;
          cancelledValue = cancel;
        },
      );

      expect(params.value, 'hello');
      expect(params.data, {'name': 'Alice'});
      expect(params.rowIndex, 0);
      expect(params.column, 'name');
      expect(params.eventKey, 'Enter');

      params.onValueChanged('world');
      expect(capturedValue, 'world');

      params.stopEditing(true);
      expect(stopCalled, isTrue);
      expect(cancelledValue, isTrue);
    });

    test('eventKey can be null', () {
      final params = CellEditorParams<Map<String, dynamic>>(
        value: 42,
        data: {'age': 42},
        rowIndex: 1,
        colDef: const OsColumnDef(field: 'age'),
        column: 'age',
        eventKey: null,
        onValueChanged: (_) {},
        stopEditing: (_) {},
      );
      expect(params.eventKey, isNull);
    });
  });

  group('PopupPosition enum', () {
    test('has over and under values', () {
      expect(PopupPosition.values, hasLength(2));
      expect(PopupPosition.values, contains(PopupPosition.over));
      expect(PopupPosition.values, contains(PopupPosition.under));
    });
  });

  group('OsColumnDef — custom cellEditor', () {
    test('accepts OsCustomCellEditor', () {
      final colDef = OsColumnDef(
        field: 'colour',
        editable: true,
        cellEditor: OsCustomCellEditor(
          builder: (context, params) => const Text('custom'),
        ),
      );
      expect(colDef.cellEditor, isA<OsCustomCellEditor>());
    });
  });

  group('Custom editor — widget integration', () {
    testWidgets('grid renders with custom editor configured', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 400,
              child: OsGrid<Map<String, dynamic>>(
                columnDefs: [
                  OsColumnDef(
                    field: 'colour',
                    headerName: 'Colour',
                    width: 200,
                    editable: true,
                    cellEditor: OsCustomCellEditor(
                      builder: (context, params) {
                        return Container(
                          color: Colors.red,
                          child: const Text('Custom Editor'),
                        );
                      },
                    ),
                  ),
                ],
                rowData: [
                  {'colour': 'Red'},
                  {'colour': 'Blue'},
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(VirtualisedGrid), findsOneWidget);
    });

    testWidgets('double-click opens custom editor', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 400,
              child: OsGrid<Map<String, dynamic>>(
                columnDefs: [
                  OsColumnDef(
                    field: 'colour',
                    headerName: 'Colour',
                    width: 200,
                    editable: true,
                    cellEditor: OsCustomCellEditor(
                      builder: (context, params) {
                        return Container(
                          key: const Key('custom-editor'),
                          color: Colors.yellow,
                          child: Text('Editing: ${params.value}'),
                        );
                      },
                    ),
                  ),
                ],
                rowData: [
                  {'colour': 'Red'},
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Double-tap on the first data cell to open the custom editor.
      // Header is 48px, first row center is at 48 + 21 = 69.
      final gridFinder = find.byType(VirtualisedGrid);
      final gridBox = tester.renderObject(gridFinder) as RenderBox;
      final cellCenter = gridBox.localToGlobal(const Offset(100, 69));

      await tester.tapAt(cellCenter);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(cellCenter);
      await tester.pumpAndSettle();

      // The custom editor widget should appear
      expect(find.byKey(const Key('custom-editor')), findsOneWidget);
      expect(find.text('Editing: Red'), findsOneWidget);
    });

    testWidgets('onValueChanged updates the pending value', (tester) async {
      OsCellValueChangedEvent<Map<String, dynamic>>? changedEvent;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 400,
              child: OsGrid<Map<String, dynamic>>(
                columnDefs: [
                  OsColumnDef(
                    field: 'colour',
                    headerName: 'Colour',
                    width: 200,
                    editable: true,
                    cellEditor: OsCustomCellEditor(
                      builder: (context, params) {
                        return GestureDetector(
                          key: const Key('custom-editor'),
                          onTap: () {
                            params.onValueChanged('Green');
                            params.stopEditing(false);
                          },
                          child: const Text('Tap to set Green'),
                        );
                      },
                    ),
                  ),
                ],
                rowData: [
                  {'colour': 'Red'},
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
      final gridFinder = find.byType(VirtualisedGrid);
      final gridBox = tester.renderObject(gridFinder) as RenderBox;
      final cellCenter = gridBox.localToGlobal(const Offset(100, 69));

      await tester.tapAt(cellCenter);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(cellCenter);
      await tester.pumpAndSettle();

      // Tap the custom editor to commit
      await tester.tap(find.byKey(const Key('custom-editor')));
      await tester.pumpAndSettle();

      // Value should have changed
      expect(changedEvent, isNotNull);
      expect(changedEvent!.oldValue, 'Red');
      expect(changedEvent!.newValue, 'Green');
    });

    testWidgets('stopEditing(true) cancels the edit', (tester) async {
      OsCellEditingStoppedEvent<Map<String, dynamic>>? stoppedEvent;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 400,
              child: OsGrid<Map<String, dynamic>>(
                columnDefs: [
                  OsColumnDef(
                    field: 'colour',
                    headerName: 'Colour',
                    width: 200,
                    editable: true,
                    cellEditor: OsCustomCellEditor(
                      builder: (context, params) {
                        return GestureDetector(
                          key: const Key('custom-editor'),
                          onTap: () {
                            params.onValueChanged('Green');
                            params.stopEditing(true); // cancel
                          },
                          child: const Text('Tap to cancel'),
                        );
                      },
                    ),
                  ),
                ],
                rowData: [
                  {'colour': 'Red'},
                ],
                onCellEditingStopped: (event) {
                  stoppedEvent = event;
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Double-tap to open editor
      final gridFinder = find.byType(VirtualisedGrid);
      final gridBox = tester.renderObject(gridFinder) as RenderBox;
      final cellCenter = gridBox.localToGlobal(const Offset(100, 69));

      await tester.tapAt(cellCenter);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(cellCenter);
      await tester.pumpAndSettle();

      // Tap the custom editor to cancel
      await tester.tap(find.byKey(const Key('custom-editor')));
      await tester.pumpAndSettle();

      // Edit should be cancelled
      expect(stoppedEvent, isNotNull);
      expect(stoppedEvent!.cancelled, isTrue);
      expect(stoppedEvent!.oldValue, 'Red');
      expect(stoppedEvent!.newValue, 'Red');
    });

    testWidgets('Escape cancels custom editor', (tester) async {
      OsCellEditingStoppedEvent<Map<String, dynamic>>? stoppedEvent;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 400,
              child: OsGrid<Map<String, dynamic>>(
                columnDefs: [
                  OsColumnDef(
                    field: 'colour',
                    headerName: 'Colour',
                    width: 200,
                    editable: true,
                    cellEditor: OsCustomCellEditor(
                      builder: (context, params) {
                        return const Text('Editor', key: Key('custom-editor'));
                      },
                    ),
                  ),
                ],
                rowData: [
                  {'colour': 'Red'},
                ],
                onCellEditingStopped: (event) {
                  stoppedEvent = event;
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Double-tap to open editor
      final gridFinder = find.byType(VirtualisedGrid);
      final gridBox = tester.renderObject(gridFinder) as RenderBox;
      final cellCenter = gridBox.localToGlobal(const Offset(100, 69));

      await tester.tapAt(cellCenter);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(cellCenter);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('custom-editor')), findsOneWidget);

      // Press Escape
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      // Editor should be closed and edit cancelled
      expect(find.byKey(const Key('custom-editor')), findsNothing);
      expect(stoppedEvent, isNotNull);
      expect(stoppedEvent!.cancelled, isTrue);
    });

    testWidgets('Enter commits custom editor', (tester) async {
      OsCellValueChangedEvent<Map<String, dynamic>>? changedEvent;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 400,
              child: OsGrid<Map<String, dynamic>>(
                columnDefs: [
                  OsColumnDef(
                    field: 'colour',
                    headerName: 'Colour',
                    width: 200,
                    editable: true,
                    cellEditor: OsCustomCellEditor(
                      builder: (context, params) {
                        // Immediately set a new value
                        params.onValueChanged('Blue');
                        return const Text('Editor', key: Key('custom-editor'));
                      },
                    ),
                  ),
                ],
                rowData: [
                  {'colour': 'Red'},
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
      final gridFinder = find.byType(VirtualisedGrid);
      final gridBox = tester.renderObject(gridFinder) as RenderBox;
      final cellCenter = gridBox.localToGlobal(const Offset(100, 69));

      await tester.tapAt(cellCenter);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(cellCenter);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('custom-editor')), findsOneWidget);

      // Press Enter to commit
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      // Editor should be closed and value committed
      expect(find.byKey(const Key('custom-editor')), findsNothing);
      expect(changedEvent, isNotNull);
      expect(changedEvent!.newValue, 'Blue');
    });

    testWidgets('suppressEnterCommit prevents Enter from committing', (
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
                  OsColumnDef(
                    field: 'colour',
                    headerName: 'Colour',
                    width: 200,
                    editable: true,
                    cellEditor: OsCustomCellEditor(
                      suppressEnterCommit: true,
                      builder: (context, params) {
                        params.onValueChanged('Blue');
                        return const Text('Editor', key: Key('custom-editor'));
                      },
                    ),
                  ),
                ],
                rowData: [
                  {'colour': 'Red'},
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
      final gridFinder = find.byType(VirtualisedGrid);
      final gridBox = tester.renderObject(gridFinder) as RenderBox;
      final cellCenter = gridBox.localToGlobal(const Offset(100, 69));

      await tester.tapAt(cellCenter);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(cellCenter);
      await tester.pumpAndSettle();

      // Press Enter — should NOT commit
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      // Editor should still be open
      expect(find.byKey(const Key('custom-editor')), findsOneWidget);
      expect(changedEvent, isNull);
    });

    testWidgets('suppressEscapeCancel prevents Escape from cancelling', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 400,
              child: OsGrid<Map<String, dynamic>>(
                columnDefs: [
                  OsColumnDef(
                    field: 'colour',
                    headerName: 'Colour',
                    width: 200,
                    editable: true,
                    cellEditor: OsCustomCellEditor(
                      suppressEscapeCancel: true,
                      builder: (context, params) {
                        return const Text('Editor', key: Key('custom-editor'));
                      },
                    ),
                  ),
                ],
                rowData: [
                  {'colour': 'Red'},
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Double-tap to open editor
      final gridFinder = find.byType(VirtualisedGrid);
      final gridBox = tester.renderObject(gridFinder) as RenderBox;
      final cellCenter = gridBox.localToGlobal(const Offset(100, 69));

      await tester.tapAt(cellCenter);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(cellCenter);
      await tester.pumpAndSettle();

      // Press Escape — should NOT cancel
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      // Editor should still be open
      expect(find.byKey(const Key('custom-editor')), findsOneWidget);
    });

    testWidgets('outside tap cancels custom editor', (tester) async {
      OsCellEditingStoppedEvent<Map<String, dynamic>>? stoppedEvent;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 400,
              child: OsGrid<Map<String, dynamic>>(
                columnDefs: [
                  OsColumnDef(
                    field: 'colour',
                    headerName: 'Colour',
                    width: 200,
                    editable: true,
                    cellEditor: OsCustomCellEditor(
                      builder: (context, params) {
                        return const Text('Editor', key: Key('custom-editor'));
                      },
                    ),
                  ),
                ],
                rowData: [
                  {'colour': 'Red'},
                ],
                onCellEditingStopped: (event) {
                  stoppedEvent = event;
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Double-tap to open editor
      final gridFinder = find.byType(VirtualisedGrid);
      final gridBox = tester.renderObject(gridFinder) as RenderBox;
      final cellCenter = gridBox.localToGlobal(const Offset(100, 69));

      await tester.tapAt(cellCenter);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(cellCenter);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('custom-editor')), findsOneWidget);

      // Tap outside the editor (far corner of the grid)
      final outsidePoint = gridBox.localToGlobal(const Offset(700, 350));
      await tester.tapAt(outsidePoint);
      await tester.pumpAndSettle();

      // Editor should be closed (cancelled)
      expect(find.byKey(const Key('custom-editor')), findsNothing);
      expect(stoppedEvent, isNotNull);
      expect(stoppedEvent!.cancelled, isTrue);
    });

    testWidgets('cellEditingStarted event fires when custom editor opens', (
      tester,
    ) async {
      OsCellEditingStartedEvent<Map<String, dynamic>>? startedEvent;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 400,
              child: OsGrid<Map<String, dynamic>>(
                columnDefs: [
                  OsColumnDef(
                    field: 'colour',
                    headerName: 'Colour',
                    width: 200,
                    editable: true,
                    cellEditor: OsCustomCellEditor(
                      builder: (context, params) {
                        return const Text('Editor', key: Key('custom-editor'));
                      },
                    ),
                  ),
                ],
                rowData: [
                  {'colour': 'Red'},
                ],
                onCellEditingStarted: (event) {
                  startedEvent = event;
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Double-tap to open editor
      final gridFinder = find.byType(VirtualisedGrid);
      final gridBox = tester.renderObject(gridFinder) as RenderBox;
      final cellCenter = gridBox.localToGlobal(const Offset(100, 69));

      await tester.tapAt(cellCenter);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(cellCenter);
      await tester.pumpAndSettle();

      expect(startedEvent, isNotNull);
      expect(startedEvent!.value, 'Red');
      expect(startedEvent!.rowIndex, 0);
    });

    testWidgets('readOnlyEdit fires cellEditRequest instead of mutating', (
      tester,
    ) async {
      OsCellEditRequestEvent<Map<String, dynamic>>? requestEvent;
      OsCellValueChangedEvent<Map<String, dynamic>>? changedEvent;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 400,
              child: OsGrid<Map<String, dynamic>>(
                readOnlyEdit: true,
                columnDefs: [
                  OsColumnDef(
                    field: 'colour',
                    headerName: 'Colour',
                    width: 200,
                    editable: true,
                    cellEditor: OsCustomCellEditor(
                      builder: (context, params) {
                        return GestureDetector(
                          key: const Key('custom-editor'),
                          onTap: () {
                            params.onValueChanged('Green');
                            params.stopEditing(false);
                          },
                          child: const Text('Tap'),
                        );
                      },
                    ),
                  ),
                ],
                rowData: [
                  {'colour': 'Red'},
                ],
                onCellEditRequest: (event) {
                  requestEvent = event;
                },
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
      final gridFinder = find.byType(VirtualisedGrid);
      final gridBox = tester.renderObject(gridFinder) as RenderBox;
      final cellCenter = gridBox.localToGlobal(const Offset(100, 69));

      await tester.tapAt(cellCenter);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(cellCenter);
      await tester.pumpAndSettle();

      // Tap the custom editor to commit
      await tester.tap(find.byKey(const Key('custom-editor')));
      await tester.pumpAndSettle();

      // Should fire cellEditRequest, NOT cellValueChanged
      expect(requestEvent, isNotNull);
      expect(requestEvent!.oldValue, 'Red');
      expect(requestEvent!.newValue, 'Green');
      expect(changedEvent, isNull);
    });

    testWidgets('popup editor renders below cell when popupPosition is under', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 400,
              child: OsGrid<Map<String, dynamic>>(
                columnDefs: [
                  OsColumnDef(
                    field: 'colour',
                    headerName: 'Colour',
                    width: 200,
                    editable: true,
                    cellEditor: OsCustomCellEditor(
                      popup: true,
                      popupPosition: PopupPosition.under,
                      builder: (context, params) {
                        return Container(
                          key: const Key('popup-editor'),
                          width: 150,
                          height: 100,
                          color: Colors.green,
                          child: const Text('Popup'),
                        );
                      },
                    ),
                  ),
                ],
                rowData: [
                  {'colour': 'Red'},
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Double-tap to open editor
      final gridFinder = find.byType(VirtualisedGrid);
      final gridBox = tester.renderObject(gridFinder) as RenderBox;
      final cellCenter = gridBox.localToGlobal(const Offset(100, 69));

      await tester.tapAt(cellCenter);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(cellCenter);
      await tester.pumpAndSettle();

      // The popup editor should appear
      expect(find.byKey(const Key('popup-editor')), findsOneWidget);
      expect(find.text('Popup'), findsOneWidget);
    });

    testWidgets('valueSetter is called for custom editor commits', (
      tester,
    ) async {
      dynamic setterNewValue;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 400,
              child: OsGrid<Map<String, dynamic>>(
                columnDefs: [
                  OsColumnDef<Map<String, dynamic>>(
                    field: 'colour',
                    headerName: 'Colour',
                    width: 200,
                    editable: true,
                    cellEditor: OsCustomCellEditor(
                      builder: (context, params) {
                        return GestureDetector(
                          key: const Key('custom-editor'),
                          onTap: () {
                            params.onValueChanged('Purple');
                            params.stopEditing(false);
                          },
                          child: const Text('Tap'),
                        );
                      },
                    ),
                    valueSetter: (params) {
                      setterNewValue = params.newValue;
                      (params.data)['colour'] = params.newValue;
                      return true;
                    },
                  ),
                ],
                rowData: [
                  {'colour': 'Red'},
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Double-tap to open editor
      final gridFinder = find.byType(VirtualisedGrid);
      final gridBox = tester.renderObject(gridFinder) as RenderBox;
      final cellCenter = gridBox.localToGlobal(const Offset(100, 69));

      await tester.tapAt(cellCenter);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(cellCenter);
      await tester.pumpAndSettle();

      // Tap the custom editor to commit
      await tester.tap(find.byKey(const Key('custom-editor')));
      await tester.pumpAndSettle();

      expect(setterNewValue, 'Purple');
    });
  });
}
