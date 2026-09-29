import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

void main() {
  group('OsRichSelectCellEditor — model', () {
    test('defaults searchPlaceholder, debounceMs and allowTyping', () {
      const editor = OsRichSelectCellEditor(values: ['A', 'B']);
      expect(editor.searchPlaceholder, 'Search...');
      expect(editor.debounceMs, 200);
      expect(editor.allowTyping, isTrue);
      expect(editor.valuesProvider, isNull);
      expect(editor.valueFormatter, isNull);
    });

    test('holds values and optional list params', () {
      const editor = OsRichSelectCellEditor(
        values: ['X', 'Y'],
        valueListGap: 4.0,
        valueListMaxHeight: 300.0,
        valueListMaxWidth: 250.0,
      );
      expect(editor.values, ['X', 'Y']);
      expect(editor.valueListGap, 4.0);
      expect(editor.valueListMaxHeight, 300.0);
      expect(editor.valueListMaxWidth, 250.0);
    });

    test('holds valuesProvider, custom search params and formatter', () {
      List<dynamic> provider(OsRichSelectValuesParams<dynamic> params) =>
          const [];
      String formatValue(dynamic value) => value.toString();
      final editor = OsRichSelectCellEditor(
        valuesProvider: provider,
        allowTyping: false,
        searchPlaceholder: 'Filter options',
        debounceMs: 0,
        valueFormatter: formatValue,
      );
      expect(editor.valuesProvider, same(provider));
      expect(editor.allowTyping, isFalse);
      expect(editor.searchPlaceholder, 'Filter options');
      expect(editor.debounceMs, 0);
      expect(editor.valueFormatter, same(formatValue));
    });

    test('satisfies the OsSelectCellEditor / OsCellEditor contract', () {
      const editor = OsRichSelectCellEditor(values: ['A']);
      expect(editor, isA<OsSelectCellEditor>());
      expect(editor, isA<OsCellEditor>());
    });

    test('valueFormatter passthrough formats display values', () {
      String formatted(dynamic value) => '<$value>';
      final editor = OsRichSelectCellEditor(
        values: const [1, 2],
        valueFormatter: formatted,
      );
      expect(editor.valueFormatter!(42), '<42>');
    });
  });

  group('OsColumnDef — rich select cellEditor property', () {
    test('accepts OsRichSelectCellEditor via cellEditor', () {
      const colDef = OsColumnDef(
        field: 'status',
        editable: true,
        cellEditor: OsRichSelectCellEditor(values: ['Active', 'Inactive']),
      );
      expect(colDef.cellEditor, isA<OsRichSelectCellEditor>());
      expect(colDef.cellEditor, isA<OsSelectCellEditor>());
    });
  });

  group('Rich select editor — widget integration', () {
    Future<void> openEditorAtFirstCell(WidgetTester tester) async {
      final gridFinder = find.byType(VirtualisedGrid);
      final gridBox = tester.renderObject(gridFinder) as RenderBox;
      final cellCenter = gridBox.localToGlobal(const Offset(100, 69));

      await tester.tapAt(cellCenter);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(cellCenter);
      await tester.pumpAndSettle();
    }

    Widget wrap(OsGrid<Map<String, dynamic>> grid) => MaterialApp(
      home: Scaffold(body: SizedBox(width: 800, height: 400, child: grid)),
    );

    testWidgets('double-click opens searchable dropdown', (tester) async {
      await tester.pumpWidget(
        wrap(
          const OsGrid<Map<String, dynamic>>(
            columnDefs: [
              OsColumnDef(
                field: 'type',
                headerName: 'Type',
                width: 200,
                editable: true,
                cellEditor: OsRichSelectCellEditor(
                  values: ['Contract', 'Permanent', 'Freelance'],
                ),
              ),
            ],
            rowData: [
              {'type': 'Contract'},
            ],
          ),
        ),
      );

      await tester.pumpAndSettle();
      await openEditorAtFirstCell(tester);

      // All options are listed plus a search field.
      expect(find.text('Permanent'), findsOneWidget);
      expect(find.text('Freelance'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Search...'), findsOneWidget);
    });

    testWidgets('typing filters options case-insensitively', (tester) async {
      await tester.pumpWidget(
        wrap(
          const OsGrid<Map<String, dynamic>>(
            columnDefs: [
              OsColumnDef(
                field: 'type',
                headerName: 'Type',
                width: 200,
                editable: true,
                cellEditor: OsRichSelectCellEditor(
                  values: ['Contract', 'Permanent', 'Freelance'],
                ),
              ),
            ],
            rowData: [
              {'type': 'Contract'},
            ],
          ),
        ),
      );

      await tester.pumpAndSettle();
      await openEditorAtFirstCell(tester);

      await tester.enterText(find.byType(TextField), 'PER');
      // Debounce is 200ms — filtering must not apply before it elapses...
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Contract'), findsOneWidget);

      // ...but must apply after it.
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Permanent'), findsOneWidget);
      expect(find.text('Contract'), findsNothing);
      expect(find.text('Freelance'), findsNothing);
    });

    testWidgets('arrow keys navigate filtered list, Enter commits', (
      tester,
    ) async {
      OsCellValueChangedEvent<Map<String, dynamic>>? changedEvent;

      await tester.pumpWidget(
        wrap(
          OsGrid<Map<String, dynamic>>(
            columnDefs: const [
              OsColumnDef(
                field: 'type',
                headerName: 'Type',
                width: 200,
                editable: true,
                cellEditor: OsRichSelectCellEditor(
                  values: ['Alpha', 'Beta', 'Gamma'],
                ),
              ),
            ],
            rowData: [
              {'type': 'Alpha'},
            ],
            onCellValueChanged: (event) => changedEvent = event,
          ),
        ),
      );

      await tester.pumpAndSettle();
      await openEditorAtFirstCell(tester);

      // Filter down, then move through matches and commit the highlighted one.
      await tester.enterText(find.byType(TextField), 'a');
      await tester.pump(const Duration(milliseconds: 300));

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(changedEvent, isNotNull);
      expect(changedEvent!.newValue, 'Gamma');
    });

    testWidgets('Enter with no matching options cancels the edit', (
      tester,
    ) async {
      OsCellValueChangedEvent<Map<String, dynamic>>? changedEvent;
      OsCellEditingStoppedEvent<Map<String, dynamic>>? stoppedEvent;

      await tester.pumpWidget(
        wrap(
          OsGrid<Map<String, dynamic>>(
            columnDefs: const [
              OsColumnDef(
                field: 'type',
                headerName: 'Type',
                width: 200,
                editable: true,
                cellEditor: OsRichSelectCellEditor(
                  values: ['Contract', 'Permanent'],
                ),
              ),
            ],
            rowData: const [
              {'type': 'Contract'},
            ],
            onCellValueChanged: (event) => changedEvent = event,
            onCellEditingStopped: (event) => stoppedEvent = event,
          ),
        ),
      );

      await tester.pumpAndSettle();
      await openEditorAtFirstCell(tester);

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Contract'), findsNothing);
      expect(find.text('Permanent'), findsNothing);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(changedEvent, isNull);
      expect(stoppedEvent, isNotNull);
      expect(stoppedEvent!.cancelled, isTrue);
    });

    testWidgets('escape cancels without committing', (tester) async {
      OsCellValueChangedEvent<Map<String, dynamic>>? changedEvent;

      await tester.pumpWidget(
        wrap(
          OsGrid<Map<String, dynamic>>(
            columnDefs: const [
              OsColumnDef(
                field: 'type',
                headerName: 'Type',
                width: 200,
                editable: true,
                cellEditor: OsRichSelectCellEditor(
                  values: ['Contract', 'Permanent'],
                ),
              ),
            ],
            rowData: const [
              {'type': 'Contract'},
            ],
            onCellValueChanged: (event) => changedEvent = event,
          ),
        ),
      );

      await tester.pumpAndSettle();
      await openEditorAtFirstCell(tester);

      expect(find.text('Permanent'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.text('Permanent'), findsNothing);
      expect(changedEvent, isNull);
    });

    testWidgets('clicking an option commits the edit', (tester) async {
      OsCellValueChangedEvent<Map<String, dynamic>>? changedEvent;

      await tester.pumpWidget(
        wrap(
          OsGrid<Map<String, dynamic>>(
            columnDefs: const [
              OsColumnDef(
                field: 'type',
                headerName: 'Type',
                width: 200,
                editable: true,
                cellEditor: OsRichSelectCellEditor(
                  values: ['Contract', 'Permanent', 'Freelance'],
                ),
              ),
            ],
            rowData: [
              {'type': 'Contract'},
            ],
            onCellValueChanged: (event) => changedEvent = event,
          ),
        ),
      );

      await tester.pumpAndSettle();
      await openEditorAtFirstCell(tester);

      await tester.tap(find.text('Freelance'));
      await tester.pumpAndSettle();

      expect(changedEvent, isNotNull);
      expect(changedEvent!.oldValue, 'Contract');
      expect(changedEvent!.newValue, 'Freelance');
    });

    testWidgets('valuesProvider supplies options and receives params', (
      tester,
    ) async {
      final capturedParams = <OsRichSelectValuesParams<dynamic>>[];
      final rowData = <String, dynamic>{'city': 'Paris'};

      await tester.pumpWidget(
        wrap(
          OsGrid<Map<String, dynamic>>(
            columnDefs: [
              OsColumnDef(
                field: 'city',
                headerName: 'City',
                width: 200,
                editable: true,
                cellEditor: OsRichSelectCellEditor(
                  valuesProvider: (params) {
                    capturedParams.add(params);
                    return const ['Paris', 'Berlin', 'Madrid'];
                  },
                ),
              ),
            ],
            rowData: [rowData],
          ),
        ),
      );

      await tester.pumpAndSettle();

      // The provider has not run until the editor opens.
      expect(capturedParams, isEmpty);

      await openEditorAtFirstCell(tester);

      expect(capturedParams.length, 1);
      expect(capturedParams.first.value, 'Paris');
      expect(capturedParams.first.data, same(rowData));
      expect(capturedParams.first.rowIndex, 0);
      expect(capturedParams.first.column, 'city');

      expect(find.text('Berlin'), findsOneWidget);
      expect(find.text('Madrid'), findsOneWidget);
    });

    testWidgets('Tab commits the highlighted option', (tester) async {
      OsCellValueChangedEvent<Map<String, dynamic>>? changedEvent;

      await tester.pumpWidget(
        wrap(
          OsGrid<Map<String, dynamic>>(
            columnDefs: const [
              OsColumnDef(
                field: 'type',
                headerName: 'Type',
                width: 200,
                editable: true,
                cellEditor: OsRichSelectCellEditor(
                  values: ['Alpha', 'Beta', 'Gamma'],
                ),
              ),
            ],
            rowData: [
              {'type': 'Alpha'},
            ],
            onCellValueChanged: (event) => changedEvent = event,
          ),
        ),
      );

      await tester.pumpAndSettle();
      await openEditorAtFirstCell(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      expect(changedEvent, isNotNull);
      expect(changedEvent!.newValue, 'Beta');
    });

    testWidgets('valueFormatter formats displayed options but not commits', (
      tester,
    ) async {
      OsCellValueChangedEvent<Map<String, dynamic>>? changedEvent;

      await tester.pumpWidget(
        wrap(
          OsGrid<Map<String, dynamic>>(
            columnDefs: [
              OsColumnDef(
                field: 'type',
                headerName: 'Type',
                width: 200,
                editable: true,
                cellEditor: OsRichSelectCellEditor(
                  values: const ['Contract', 'Freelance'],
                  valueFormatter: (value) => '[$value]',
                ),
              ),
            ],
            rowData: [
              {'type': 'Contract'},
            ],
            onCellValueChanged: (event) => changedEvent = event,
          ),
        ),
      );

      await tester.pumpAndSettle();
      await openEditorAtFirstCell(tester);

      // Options display formatted...
      expect(find.text('[Freelance]'), findsOneWidget);

      // ...but the committed value stays raw.
      await tester.tap(find.text('[Freelance]'));
      await tester.pumpAndSettle();

      expect(changedEvent, isNotNull);
      expect(changedEvent!.newValue, 'Freelance');
    });

    testWidgets('allowTyping false hides search input, keys still work', (
      tester,
    ) async {
      OsCellValueChangedEvent<Map<String, dynamic>>? changedEvent;

      await tester.pumpWidget(
        wrap(
          OsGrid<Map<String, dynamic>>(
            columnDefs: const [
              OsColumnDef(
                field: 'type',
                headerName: 'Type',
                width: 200,
                editable: true,
                cellEditor: OsRichSelectCellEditor(
                  values: ['Alpha', 'Beta'],
                  allowTyping: false,
                ),
              ),
            ],
            rowData: [
              {'type': 'Alpha'},
            ],
            onCellValueChanged: (event) => changedEvent = event,
          ),
        ),
      );

      await tester.pumpAndSettle();
      await openEditorAtFirstCell(tester);

      expect(find.byType(TextField), findsNothing);
      expect(find.text('Beta'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(changedEvent, isNotNull);
      expect(changedEvent!.newValue, 'Beta');
    });

    testWidgets('debounceMs 0 filters immediately on each keystroke', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const OsGrid<Map<String, dynamic>>(
            columnDefs: [
              OsColumnDef(
                field: 'type',
                headerName: 'Type',
                width: 200,
                editable: true,
                cellEditor: OsRichSelectCellEditor(
                  values: ['Contract', 'Permanent'],
                  debounceMs: 0,
                ),
              ),
            ],
            rowData: [
              {'type': 'Contract'},
            ],
          ),
        ),
      );

      await tester.pumpAndSettle();
      await openEditorAtFirstCell(tester);

      await tester.enterText(find.byType(TextField), 'per');
      await tester.pump();

      expect(find.text('Permanent'), findsOneWidget);
      expect(find.text('Contract'), findsNothing);
    });
  });
}
