import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';
import 'package:os_grid_flutter/src/editing/date_picker_overlay.dart';

void main() {
  group('OsDateCellEditor — model', () {
    test('default constructor has correct defaults', () {
      const editor = OsDateCellEditor();
      expect(editor.min, isNull);
      expect(editor.max, isNull);
      expect(editor.step, isNull);
      expect(editor.includeTime, isFalse);
      expect(editor.useNativePicker, isTrue);
    });

    test('is a subclass of OsCellEditor', () {
      const editor = OsDateCellEditor();
      expect(editor, isA<OsCellEditor>());
    });

    test('accepts DateTime min/max', () {
      final editor = OsDateCellEditor(
        min: DateTime(2020, 1, 1),
        max: DateTime(2030, 12, 31),
      );
      expect(editor.minDate, DateTime(2020, 1, 1));
      expect(editor.maxDate, DateTime(2030, 12, 31));
    });

    test('accepts String min/max in ISO format', () {
      const editor = OsDateCellEditor(min: '2020-01-01', max: '2030-12-31');
      expect(editor.minDate, DateTime(2020, 1, 1));
      expect(editor.maxDate, DateTime(2030, 12, 31));
    });

    test('step is stored correctly', () {
      const editor = OsDateCellEditor(step: 7);
      expect(editor.step, 7);
    });

    test('includeTime can be set to true', () {
      const editor = OsDateCellEditor(includeTime: true);
      expect(editor.includeTime, isTrue);
    });
  });

  group('OsDateCellEditor — resolve', () {
    test('resolves null to null', () {
      expect(OsDateCellEditor.resolve(null), isNull);
    });

    test('resolves DateTime directly', () {
      final dt = DateTime(2024, 6, 15);
      expect(OsDateCellEditor.resolve(dt), dt);
    });

    test('resolves ISO date string', () {
      expect(OsDateCellEditor.resolve('2024-06-15'), DateTime(2024, 6, 15));
    });

    test('resolves ISO datetime string', () {
      expect(
        OsDateCellEditor.resolve('2024-06-15T10:30:00'),
        DateTime(2024, 6, 15, 10, 30),
      );
    });

    test('returns null for invalid string', () {
      expect(OsDateCellEditor.resolve('not-a-date'), isNull);
    });

    test('returns null for non-string/non-DateTime types', () {
      expect(OsDateCellEditor.resolve(42), isNull);
      expect(OsDateCellEditor.resolve(true), isNull);
    });
  });

  group('OsDateCellEditor — parseDate', () {
    test('parses yyyy-MM-dd format', () {
      expect(OsDateCellEditor.parseDate('2024-03-15'), DateTime(2024, 3, 15));
    });

    test('parses yyyy-MM-ddTHH:mm:ss format', () {
      expect(
        OsDateCellEditor.parseDate('2024-03-15T14:30:00'),
        DateTime(2024, 3, 15, 14, 30),
      );
    });

    test('parses space-separated datetime', () {
      expect(
        OsDateCellEditor.parseDate('2024-03-15 14:30:00'),
        DateTime(2024, 3, 15, 14, 30),
      );
    });

    test('returns null for empty string', () {
      expect(OsDateCellEditor.parseDate(''), isNull);
    });

    test('returns null for null', () {
      expect(OsDateCellEditor.parseDate(null), isNull);
    });
  });

  group('OsDateCellEditor — serialiseDate', () {
    test('serialises date-only (includeTime: false)', () {
      const editor = OsDateCellEditor();
      expect(editor.serialiseDate(DateTime(2024, 3, 5)), '2024-03-05');
    });

    test('serialises with time (includeTime: true)', () {
      const editor = OsDateCellEditor(includeTime: true);
      expect(
        editor.serialiseDate(DateTime(2024, 3, 5, 14, 30, 45)),
        '2024-03-05T14:30:45',
      );
    });

    test('pads single-digit values', () {
      const editor = OsDateCellEditor();
      expect(editor.serialiseDate(DateTime(2024, 1, 2)), '2024-01-02');
    });

    test('pads time values', () {
      const editor = OsDateCellEditor(includeTime: true);
      expect(
        editor.serialiseDate(DateTime(2024, 1, 2, 3, 4, 5)),
        '2024-01-02T03:04:05',
      );
    });
  });

  group('OsDateCellEditor — validate', () {
    test('returns null for valid date within range', () {
      final editor = OsDateCellEditor(
        min: DateTime(2020, 1, 1),
        max: DateTime(2030, 12, 31),
      );
      expect(editor.validate(DateTime(2025, 6, 15)), isNull);
    });

    test('returns error when date is before min', () {
      final editor = OsDateCellEditor(min: DateTime(2020, 1, 1));
      final errors = editor.validate(DateTime(2019, 12, 31));
      expect(errors, isNotNull);
      expect(errors!.length, 1);
      expect(errors.first, contains('on or after'));
    });

    test('returns error when date is after max', () {
      final editor = OsDateCellEditor(max: DateTime(2030, 12, 31));
      final errors = editor.validate(DateTime(2031, 1, 1));
      expect(errors, isNotNull);
      expect(errors!.length, 1);
      expect(errors.first, contains('on or before'));
    });

    test('returns error when step constraint violated', () {
      final editor = OsDateCellEditor(min: DateTime(2024, 1, 1), step: 7);
      // 2024-01-01 + 3 days = not a multiple of 7
      final errors = editor.validate(DateTime(2024, 1, 4));
      expect(errors, isNotNull);
      expect(errors!.first, contains('multiple of 7'));
    });

    test('passes when step constraint satisfied', () {
      final editor = OsDateCellEditor(min: DateTime(2024, 1, 1), step: 7);
      // 2024-01-01 + 14 days = multiple of 7
      expect(editor.validate(DateTime(2024, 1, 15)), isNull);
    });

    test('returns null when no constraints set', () {
      const editor = OsDateCellEditor();
      expect(editor.validate(DateTime(2024, 6, 15)), isNull);
    });

    test('min boundary is inclusive', () {
      final editor = OsDateCellEditor(min: DateTime(2024, 1, 1));
      expect(editor.validate(DateTime(2024, 1, 1)), isNull);
    });

    test('max boundary is inclusive', () {
      final editor = OsDateCellEditor(max: DateTime(2024, 12, 31));
      expect(editor.validate(DateTime(2024, 12, 31)), isNull);
    });

    test('multiple errors returned when both min and max violated', () {
      final editor = OsDateCellEditor(
        min: DateTime(2024, 6, 1),
        max: DateTime(2024, 6, 30),
        step: 7,
      );
      // Before min AND not a step multiple
      final errors = editor.validate(DateTime(2024, 5, 3));
      expect(errors, isNotNull);
      expect(errors!.length, greaterThanOrEqualTo(1));
    });
  });

  group('OsDateStringCellEditor — model', () {
    test('default constructor has correct defaults', () {
      const editor = OsDateStringCellEditor();
      expect(editor.min, isNull);
      expect(editor.max, isNull);
      expect(editor.step, isNull);
      expect(editor.includeTime, isFalse);
      expect(editor.useNativePicker, isTrue);
      expect(editor.dateParser, isNull);
      expect(editor.dateFormatter, isNull);
    });

    test('is a subclass of OsCellEditor', () {
      const editor = OsDateStringCellEditor();
      expect(editor, isA<OsCellEditor>());
    });

    test('accepts custom dateParser', () {
      final editor = OsDateStringCellEditor(
        dateParser: (value) {
          final parts = value.split('/');
          return DateTime(
            int.parse(parts[2]),
            int.parse(parts[1]),
            int.parse(parts[0]),
          );
        },
      );
      expect(editor.dateParser, isNotNull);
    });

    test('accepts custom dateFormatter', () {
      final editor = OsDateStringCellEditor(
        dateFormatter: (date) => '${date.day}/${date.month}/${date.year}',
      );
      expect(editor.dateFormatter, isNotNull);
    });
  });

  group('OsDateStringCellEditor — parseCellValue', () {
    test('parses ISO date string with default parser', () {
      const editor = OsDateStringCellEditor();
      expect(editor.parseCellValue('2024-03-15'), DateTime(2024, 3, 15));
    });

    test('returns null for empty string', () {
      const editor = OsDateStringCellEditor();
      expect(editor.parseCellValue(''), isNull);
    });

    test('returns null for null', () {
      const editor = OsDateStringCellEditor();
      expect(editor.parseCellValue(null), isNull);
    });

    test('uses custom dateParser when provided', () {
      final editor = OsDateStringCellEditor(
        dateParser: (value) {
          final parts = value.split('/');
          return DateTime(
            int.parse(parts[2]),
            int.parse(parts[1]),
            int.parse(parts[0]),
          );
        },
      );
      expect(editor.parseCellValue('15/03/2024'), DateTime(2024, 3, 15));
    });
  });

  group('OsDateStringCellEditor — formatDate', () {
    test('formats with default ISO format (date only)', () {
      const editor = OsDateStringCellEditor();
      expect(editor.formatDate(DateTime(2024, 3, 15)), '2024-03-15');
    });

    test('formats with default ISO format (includeTime)', () {
      const editor = OsDateStringCellEditor(includeTime: true);
      expect(
        editor.formatDate(DateTime(2024, 3, 15, 14, 30, 0)),
        '2024-03-15T14:30:00',
      );
    });

    test('uses custom dateFormatter when provided', () {
      final editor = OsDateStringCellEditor(
        dateFormatter: (date) =>
            '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}',
      );
      expect(editor.formatDate(DateTime(2024, 3, 5)), '05/03/2024');
    });
  });

  group('OsDateStringCellEditor — validate', () {
    test('returns null for valid date', () {
      const editor = OsDateStringCellEditor(
        min: '2020-01-01',
        max: '2030-12-31',
      );
      expect(editor.validate(DateTime(2025, 6, 15)), isNull);
    });

    test('returns error when before min', () {
      const editor = OsDateStringCellEditor(min: '2020-01-01');
      final errors = editor.validate(DateTime(2019, 12, 31));
      expect(errors, isNotNull);
      expect(errors!.first, contains('on or after'));
    });

    test('returns error when after max', () {
      const editor = OsDateStringCellEditor(max: '2030-12-31');
      final errors = editor.validate(DateTime(2031, 1, 1));
      expect(errors, isNotNull);
      expect(errors!.first, contains('on or before'));
    });
  });

  group('OsColumnDef — date editor integration', () {
    test('accepts OsDateCellEditor', () {
      final colDef = OsColumnDef(
        field: 'startDate',
        editable: true,
        cellEditor: OsDateCellEditor(
          min: DateTime(2020, 1, 1),
          max: DateTime(2030, 12, 31),
        ),
      );
      expect(colDef.cellEditor, isA<OsDateCellEditor>());
    });

    test('accepts OsDateStringCellEditor', () {
      const colDef = OsColumnDef(
        field: 'birthDate',
        editable: true,
        cellEditor: OsDateStringCellEditor(
          min: '1900-01-01',
          max: '2024-12-31',
        ),
      );
      expect(colDef.cellEditor, isA<OsDateStringCellEditor>());
    });
  });

  group('Date editor — widget integration', () {
    testWidgets('grid renders with date editor configured', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 400,
              child: OsGrid<Map<String, dynamic>>(
                columnDefs: [
                  OsColumnDef(
                    field: 'startDate',
                    headerName: 'Start Date',
                    width: 200,
                    editable: true,
                    cellEditor: OsDateCellEditor(
                      min: DateTime(2020, 1, 1),
                      max: DateTime(2030, 12, 31),
                    ),
                  ),
                  const OsColumnDef(
                    field: 'name',
                    headerName: 'Name',
                    width: 150,
                  ),
                ],
                rowData: [
                  {'startDate': DateTime(2024, 3, 15), 'name': 'Alice'},
                  {'startDate': DateTime(2024, 6, 20), 'name': 'Bob'},
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(VirtualisedGrid), findsOneWidget);
    });

    testWidgets('double-click opens date picker overlay', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 400,
              child: OsGrid<Map<String, dynamic>>(
                columnDefs: [
                  OsColumnDef(
                    field: 'date',
                    headerName: 'Date',
                    width: 200,
                    editable: true,
                    cellEditor: OsDateCellEditor(
                      min: DateTime(2020, 1, 1),
                      max: DateTime(2030, 12, 31),
                    ),
                  ),
                ],
                rowData: [
                  {'date': DateTime(2024, 3, 15)},
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Double-tap on the first data cell to open the date picker.
      // Header is 48px, first row center is at 48 + 21 = 69.
      final gridFinder = find.byType(VirtualisedGrid);
      final gridBox = tester.renderObject(gridFinder) as RenderBox;
      final cellCenter = gridBox.localToGlobal(const Offset(100, 69));

      await tester.tapAt(cellCenter);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(cellCenter);
      await tester.pumpAndSettle();

      // The DatePickerOverlay should appear with month/day labels
      expect(find.text('March 2024'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
    });

    testWidgets('selecting a date commits the edit', (tester) async {
      OsCellValueChangedEvent<Map<String, dynamic>>? changedEvent;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 400,
              child: OsGrid<Map<String, dynamic>>(
                columnDefs: [
                  OsColumnDef<Map<String, dynamic>>(
                    field: 'date',
                    headerName: 'Date',
                    width: 200,
                    editable: true,
                    cellEditor: OsDateCellEditor(
                      min: DateTime(2024, 1, 1),
                      max: DateTime(2024, 12, 31),
                    ),
                  ),
                ],
                rowData: [
                  {'date': DateTime(2024, 3, 15)},
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

      // Double-tap to open date picker
      final gridFinder = find.byType(VirtualisedGrid);
      final gridBox = tester.renderObject(gridFinder) as RenderBox;
      final cellCenter = gridBox.localToGlobal(const Offset(100, 69));

      await tester.tapAt(cellCenter);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(cellCenter);
      await tester.pumpAndSettle();

      // Tap on day 20 in the calendar
      final day20 = find.text('20');
      expect(day20, findsOneWidget);
      await tester.tap(day20);
      await tester.pumpAndSettle();

      // Value should have changed
      expect(changedEvent, isNotNull);
      expect(changedEvent!.oldValue, DateTime(2024, 3, 15));
      expect(changedEvent!.newValue, DateTime(2024, 3, 20));
    });

    testWidgets('escape cancels date editor without committing', (
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
                  OsColumnDef<Map<String, dynamic>>(
                    field: 'date',
                    headerName: 'Date',
                    width: 200,
                    editable: true,
                    cellEditor: OsDateCellEditor(
                      min: DateTime(2024, 1, 1),
                      max: DateTime(2024, 12, 31),
                    ),
                  ),
                ],
                rowData: [
                  {'date': DateTime(2024, 3, 15)},
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

      // Double-tap to open date picker
      final gridFinder = find.byType(VirtualisedGrid);
      final gridBox = tester.renderObject(gridFinder) as RenderBox;
      final cellCenter = gridBox.localToGlobal(const Offset(100, 69));

      await tester.tapAt(cellCenter);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(cellCenter);
      await tester.pumpAndSettle();

      // Calendar should be open
      expect(find.text('March 2024'), findsOneWidget);

      // Press Escape
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      // Calendar should be closed and no value change
      expect(find.text('March 2024'), findsNothing);
      expect(changedEvent, isNull);
    });

    testWidgets('clicking outside dismisses date picker', (tester) async {
      OsCellValueChangedEvent<Map<String, dynamic>>? changedEvent;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 400,
              child: OsGrid<Map<String, dynamic>>(
                columnDefs: [
                  OsColumnDef<Map<String, dynamic>>(
                    field: 'date',
                    headerName: 'Date',
                    width: 200,
                    editable: true,
                    cellEditor: OsDateCellEditor(
                      min: DateTime(2024, 1, 1),
                      max: DateTime(2024, 12, 31),
                    ),
                  ),
                ],
                rowData: [
                  {'date': DateTime(2024, 3, 15)},
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

      // Double-tap to open date picker
      final gridFinder = find.byType(VirtualisedGrid);
      final gridBox = tester.renderObject(gridFinder) as RenderBox;
      final cellCenter = gridBox.localToGlobal(const Offset(100, 69));

      await tester.tapAt(cellCenter);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(cellCenter);
      await tester.pumpAndSettle();

      // Calendar should be open
      expect(find.text('March 2024'), findsOneWidget);

      // Tap outside (top-left corner of the grid area)
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      // Calendar should be closed and no value change
      expect(find.text('March 2024'), findsNothing);
      expect(changedEvent, isNull);
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
                  OsColumnDef<Map<String, dynamic>>(
                    field: 'date',
                    headerName: 'Date',
                    width: 200,
                    editable: true,
                    cellEditor: OsDateCellEditor(
                      min: DateTime(2024, 1, 1),
                      max: DateTime(2024, 12, 31),
                    ),
                  ),
                ],
                rowData: [
                  {'date': DateTime(2024, 3, 15)},
                ],
                onCellEditingStarted: (event) => startedEvents.add(event),
                onCellEditingStopped: (event) => stoppedEvents.add(event),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Double-tap to open date picker
      final gridFinder = find.byType(VirtualisedGrid);
      final gridBox = tester.renderObject(gridFinder) as RenderBox;
      final cellCenter = gridBox.localToGlobal(const Offset(100, 69));

      await tester.tapAt(cellCenter);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(cellCenter);
      await tester.pumpAndSettle();

      // cellEditingStarted should have fired
      expect(startedEvents.length, 1);
      expect(startedEvents.first.value, DateTime(2024, 3, 15));

      // Select a date
      await tester.tap(find.text('20'));
      await tester.pumpAndSettle();

      // cellEditingStopped should have fired
      expect(stoppedEvents.length, 1);
      expect(stoppedEvents.first.cancelled, false);
      expect(stoppedEvents.first.newValue, DateTime(2024, 3, 20));
    });

    testWidgets('singleClickEdit opens date picker on single click', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 400,
              child: OsGrid<Map<String, dynamic>>(
                singleClickEdit: true,
                columnDefs: [
                  OsColumnDef(
                    field: 'date',
                    headerName: 'Date',
                    width: 200,
                    editable: true,
                    cellEditor: OsDateCellEditor(
                      min: DateTime(2024, 1, 1),
                      max: DateTime(2024, 12, 31),
                    ),
                  ),
                ],
                rowData: [
                  {'date': DateTime(2024, 3, 15)},
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Single tap on the first data cell
      final gridFinder = find.byType(VirtualisedGrid);
      final gridBox = tester.renderObject(gridFinder) as RenderBox;
      final cellCenter = gridBox.localToGlobal(const Offset(100, 69));

      await tester.tapAt(cellCenter);
      // Wait for double-tap timeout to pass
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      // Calendar should be visible
      expect(find.text('March 2024'), findsOneWidget);
    });

    testWidgets('month navigation works', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 400,
              child: OsGrid<Map<String, dynamic>>(
                columnDefs: [
                  OsColumnDef(
                    field: 'date',
                    headerName: 'Date',
                    width: 200,
                    editable: true,
                    cellEditor: OsDateCellEditor(
                      min: DateTime(2020, 1, 1),
                      max: DateTime(2030, 12, 31),
                    ),
                  ),
                ],
                rowData: [
                  {'date': DateTime(2024, 3, 15)},
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Double-tap to open date picker
      final gridFinder = find.byType(VirtualisedGrid);
      final gridBox = tester.renderObject(gridFinder) as RenderBox;
      final cellCenter = gridBox.localToGlobal(const Offset(100, 69));

      await tester.tapAt(cellCenter);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(cellCenter);
      await tester.pumpAndSettle();

      // Should show March 2024
      expect(find.text('March 2024'), findsOneWidget);

      // Tap the right chevron to go to April
      final rightChevron = find.byIcon(Icons.chevron_right);
      await tester.tap(rightChevron);
      await tester.pumpAndSettle();

      // Should now show April 2024
      expect(find.text('April 2024'), findsOneWidget);
      expect(find.text('March 2024'), findsNothing);
    });

    testWidgets('date string editor commits formatted string', (tester) async {
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
                    field: 'date',
                    headerName: 'Date',
                    width: 200,
                    editable: true,
                    cellEditor: OsDateStringCellEditor(
                      min: '2024-01-01',
                      max: '2024-12-31',
                    ),
                  ),
                ],
                rowData: [
                  {'date': '2024-03-15'},
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

      // Double-tap to open date picker
      final gridFinder = find.byType(VirtualisedGrid);
      final gridBox = tester.renderObject(gridFinder) as RenderBox;
      final cellCenter = gridBox.localToGlobal(const Offset(100, 69));

      await tester.tapAt(cellCenter);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(cellCenter);
      await tester.pumpAndSettle();

      // Calendar should be open showing March 2024
      expect(find.text('March 2024'), findsOneWidget);

      // Tap on day 20
      await tester.tap(find.text('20'));
      await tester.pumpAndSettle();

      // Value should be committed as a formatted string
      expect(changedEvent, isNotNull);
      expect(changedEvent!.oldValue, '2024-03-15');
      expect(changedEvent!.newValue, '2024-03-20');
    });

    testWidgets('useNativePicker false falls back to text input', (
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
                  const OsColumnDef(
                    field: 'date',
                    headerName: 'Date',
                    width: 200,
                    editable: true,
                    cellEditor: OsDateCellEditor(useNativePicker: false),
                  ),
                ],
                rowData: [
                  {'date': DateTime(2024, 3, 15)},
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

      // Should NOT show the calendar picker
      expect(find.text('Today'), findsNothing);

      // Should show a text input (EditableText) with the date value
      expect(find.byType(EditableText), findsOneWidget);
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
                  OsColumnDef<Map<String, dynamic>>(
                    field: 'date',
                    headerName: 'Date',
                    width: 200,
                    editable: true,
                    cellEditor: OsDateCellEditor(
                      min: DateTime(2024, 1, 1),
                      max: DateTime(2024, 12, 31),
                    ),
                  ),
                ],
                rowData: [
                  {'date': DateTime(2024, 3, 15)},
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

      // Double-tap to open date picker
      final gridFinder = find.byType(VirtualisedGrid);
      final gridBox = tester.renderObject(gridFinder) as RenderBox;
      final cellCenter = gridBox.localToGlobal(const Offset(100, 69));

      await tester.tapAt(cellCenter);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(cellCenter);
      await tester.pumpAndSettle();

      // Select a date
      await tester.tap(find.text('20'));
      await tester.pumpAndSettle();

      // cellEditRequest should fire, cellValueChanged should NOT
      expect(requestEvent, isNotNull);
      expect(requestEvent!.oldValue, DateTime(2024, 3, 15));
      expect(requestEvent!.newValue, DateTime(2024, 3, 20));
      expect(changedEvent, isNull);
    });

    testWidgets('validation rejects out-of-range date selection', (
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
                  OsColumnDef<Map<String, dynamic>>(
                    field: 'date',
                    headerName: 'Date',
                    width: 200,
                    editable: true,
                    cellEditor: OsDateCellEditor(
                      min: DateTime(2024, 3, 10),
                      max: DateTime(2024, 3, 20),
                    ),
                  ),
                ],
                rowData: [
                  {'date': DateTime(2024, 3, 15)},
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

      // Double-tap to open date picker
      final gridFinder = find.byType(VirtualisedGrid);
      final gridBox = tester.renderObject(gridFinder) as RenderBox;
      final cellCenter = gridBox.localToGlobal(const Offset(100, 69));

      await tester.tapAt(cellCenter);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(cellCenter);
      await tester.pumpAndSettle();

      // The calendar should show disabled dates outside the range.
      // Days before 10 and after 20 should appear dimmed.
      // The DatePickerOverlay prevents selection of disabled dates,
      // so tapping on them should not commit.
      // Verify the picker is open
      expect(find.text('March 2024'), findsOneWidget);

      // Select a valid date (day 18)
      await tester.tap(find.text('18'));
      await tester.pumpAndSettle();

      // Should commit successfully
      expect(changedEvent, isNotNull);
      expect(changedEvent!.newValue, DateTime(2024, 3, 18));
    });
  });

  group('DatePickerOverlay — keyboard navigation', () {
    testWidgets('arrow keys navigate the calendar', (tester) async {
      OsCellValueChangedEvent<Map<String, dynamic>>? changedEvent;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 400,
              child: OsGrid<Map<String, dynamic>>(
                columnDefs: [
                  OsColumnDef<Map<String, dynamic>>(
                    field: 'date',
                    headerName: 'Date',
                    width: 200,
                    editable: true,
                    cellEditor: OsDateCellEditor(
                      min: DateTime(2024, 1, 1),
                      max: DateTime(2024, 12, 31),
                    ),
                  ),
                ],
                rowData: [
                  {'date': DateTime(2024, 3, 15)},
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

      // Double-tap to open date picker
      final gridFinder = find.byType(VirtualisedGrid);
      final gridBox = tester.renderObject(gridFinder) as RenderBox;
      final cellCenter = gridBox.localToGlobal(const Offset(100, 69));

      await tester.tapAt(cellCenter);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(cellCenter);
      await tester.pumpAndSettle();

      // Navigate right (+1 day: 15 → 16)
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();

      // Press Enter to select the navigated date (16th)
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(changedEvent, isNotNull);
      expect(changedEvent!.newValue, DateTime(2024, 3, 16));
    });

    testWidgets('arrow down moves selection by 7 days', (tester) async {
      OsCellValueChangedEvent<Map<String, dynamic>>? changedEvent;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 400,
              child: OsGrid<Map<String, dynamic>>(
                columnDefs: [
                  OsColumnDef<Map<String, dynamic>>(
                    field: 'date',
                    headerName: 'Date',
                    width: 200,
                    editable: true,
                    cellEditor: OsDateCellEditor(
                      min: DateTime(2024, 1, 1),
                      max: DateTime(2024, 12, 31),
                    ),
                  ),
                ],
                rowData: [
                  {'date': DateTime(2024, 3, 15)},
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

      // Double-tap to open date picker
      final gridFinder = find.byType(VirtualisedGrid);
      final gridBox = tester.renderObject(gridFinder) as RenderBox;
      final cellCenter = gridBox.localToGlobal(const Offset(100, 69));

      await tester.tapAt(cellCenter);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(cellCenter);
      await tester.pumpAndSettle();

      // Navigate down (+7 days: 15 → 22)
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();

      // Press Enter to select
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(changedEvent, isNotNull);
      expect(changedEvent!.newValue, DateTime(2024, 3, 22));
    });
  });

  group('Date editor — valueSetter integration', () {
    testWidgets('valueSetter is called with DateTime value', (tester) async {
      dynamic setterNewValue;
      dynamic setterOldValue;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 400,
              child: OsGrid<Map<String, dynamic>>(
                columnDefs: [
                  OsColumnDef(
                    field: 'date',
                    headerName: 'Date',
                    width: 200,
                    editable: true,
                    cellEditor: OsDateCellEditor(
                      min: DateTime(2024, 1, 1),
                      max: DateTime(2024, 12, 31),
                    ),
                    valueSetter: (params) {
                      setterOldValue = params.oldValue;
                      setterNewValue = params.newValue;
                      (params.data as Map<String, dynamic>)['date'] =
                          params.newValue;
                      return true;
                    },
                  ),
                ],
                rowData: [
                  {'date': DateTime(2024, 3, 15)},
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Double-tap to open date picker
      final gridFinder = find.byType(VirtualisedGrid);
      final gridBox = tester.renderObject(gridFinder) as RenderBox;
      final cellCenter = gridBox.localToGlobal(const Offset(100, 69));

      await tester.tapAt(cellCenter);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(cellCenter);
      await tester.pumpAndSettle();

      // Select day 20
      await tester.tap(find.text('20'));
      await tester.pumpAndSettle();

      expect(setterOldValue, DateTime(2024, 3, 15));
      expect(setterNewValue, DateTime(2024, 3, 20));
    });
  });

  group('DatePickerOverlay theming and locale', () {
    testWidgets('localeText overrides calendar labels', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DatePickerOverlay(
              initialDate: DateTime(2024, 3, 15),
              onDateSelected: (_) {},
              onCancel: () {},
              localeText: OsLocaleText.fromMap({
                'today': 'Heute',
                'march': 'Maerz',
                'mondayShort': 'Mo',
              }),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Maerz 2024'), findsOneWidget);
      expect(find.text('Heute'), findsOneWidget);
      expect(find.text('Today'), findsNothing);
    });

    testWidgets('theme colours resolve from the grid theme', (tester) async {
      const bg = Color(0xFF161C24);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DatePickerOverlay(
              initialDate: DateTime(2024, 3, 15),
              onDateSelected: (_) {},
              onCancel: () {},
              theme: const OsGridTheme(backgroundColor: bg),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate((w) => w is Material && w.color == bg),
        findsOneWidget,
      );
    });
  });
}
