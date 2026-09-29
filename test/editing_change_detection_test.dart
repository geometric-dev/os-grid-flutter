import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';
import 'package:os_grid_flutter/src/editing/editing_coordinator.dart';

/// Wave QW3 item 6 — type-aware edit change detection.
///
/// `editValuesEqual` replaces the old `toString()` comparison so that
/// numerically-equal int/double pairs (1 vs 1.0) and the same DateTime
/// instant in different zone representations no longer count as edits,
/// while genuinely different values still fire [OsGrid.onCellValueChanged].
void main() {
  group('editValuesEqual — unit', () {
    test('num equality treats int/double equivalents as equal', () {
      expect(editValuesEqual(1, 1.0), isTrue);
      expect(editValuesEqual(2, 2.0), isTrue);
      expect(editValuesEqual(1.0, 1), isTrue);
      expect(editValuesEqual(0.5, 0.5), isTrue);
    });

    test('genuinely different nums are unequal', () {
      expect(editValuesEqual(1, 2), isFalse);
      expect(editValuesEqual(1.5, 2.5), isFalse);
    });

    test('identical NaN instances are unchanged (legacy toString parity)', () {
      // identical() short-circuits before numeric comparison, so canonical
      // NaN constants count as unchanged — same outcome as the previous
      // 'NaN' == 'NaN' string-form behaviour.
      expect(editValuesEqual(double.nan, double.nan), isTrue);
    });

    test('DateTime compares by moment, ignoring zone representation', () {
      expect(
        editValuesEqual(DateTime.utc(2024, 1, 1, 12), DateTime(2024, 1, 1, 12)),
        isTrue,
      );
      expect(
        editValuesEqual(DateTime(2024, 1, 1), DateTime(2024, 1, 2)),
        isFalse,
      );
    });

    test('identical instances and == equality short-circuit', () {
      final list = <String>[];
      expect(editValuesEqual(list, list), isTrue);
      expect(editValuesEqual('a', 'a'), isTrue);
      expect(editValuesEqual(true, true), isTrue);
      expect(editValuesEqual(null, null), isTrue);
    });

    test('null vs non-null is a change', () {
      expect(editValuesEqual(null, ''), isFalse);
      expect(editValuesEqual('', null), isFalse);
    });

    test('other types fall back to toString comparison', () {
      expect(editValuesEqual('abc', 'abc'), isTrue);
      expect(editValuesEqual('abc', 'abd'), isFalse);
      // Cross-type pairs keep the legacy string-form semantics.
      expect(editValuesEqual('1', 1), isTrue);
      expect(editValuesEqual('x', null), isFalse);
    });
  });

  group('Cell editing — numeric change detection', () {
    Future<OsGridController<Map<String, dynamic>>> pumpNumericGrid(
      WidgetTester tester, {
      required Map<String, dynamic> row,
      required void Function(OsCellValueChangedEvent<Map<String, dynamic>>)?
      onCellValueChanged,
    }) async {
      final controller = OsGridController<Map<String, dynamic>>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 300,
              child: OsGrid<Map<String, dynamic>>(
                controller: controller,
                columnDefs: [
                  OsColumnDef<Map<String, dynamic>>(
                    field: 'v',
                    editable: true,
                    valueParser: (params) =>
                        double.tryParse(params.newValue) ?? 0.0,
                  ),
                ],
                rowData: [row],
                singleClickEdit: true,
                onCellValueChanged: onCellValueChanged,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return controller;
    }

    Future<void> openEditorOnFirstCell(WidgetTester tester) async {
      final box =
          tester.renderObject(find.byType(VirtualisedGrid)) as RenderBox;
      final cell = box.localToGlobal(const Offset(75, 69));
      await tester.tapAt(cell);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(cell);
      await tester.pumpAndSettle();
    }

    testWidgets('int 1 committed over parsed double 1.0 does not fire '
        'cellValueChanged', (tester) async {
      final row = <String, dynamic>{'v': 1};
      final events = <OsCellValueChangedEvent<Map<String, dynamic>>>[];
      final controller = await pumpNumericGrid(
        tester,
        row: row,
        onCellValueChanged: events.add,
      );

      await openEditorOnFirstCell(tester);
      expect(find.byType(TextField), findsOneWidget);
      await tester.enterText(find.byType(TextField), '1');
      controller.stopEditing();
      await tester.pumpAndSettle();

      expect(
        events,
        isEmpty,
        reason: 'int 1 vs parsed double 1.0 is not an edit',
      );
      expect(row['v'], 1, reason: 'no write occurs when nothing changed');
    });

    testWidgets('int 2 committed over parsed double 2.0 does not fire '
        'cellValueChanged', (tester) async {
      final row = <String, dynamic>{'v': 2};
      final events = <OsCellValueChangedEvent<Map<String, dynamic>>>[];
      final controller = await pumpNumericGrid(
        tester,
        row: row,
        onCellValueChanged: events.add,
      );

      await openEditorOnFirstCell(tester);
      await tester.enterText(find.byType(TextField), '2');
      controller.stopEditing();
      await tester.pumpAndSettle();

      expect(
        events,
        isEmpty,
        reason: 'int 2 vs parsed double 2.0 is not an edit',
      );
      expect(row['v'], 2);
    });

    testWidgets('genuinely different values still fire cellValueChanged', (
      tester,
    ) async {
      final row = <String, dynamic>{'v': 1};
      final events = <OsCellValueChangedEvent<Map<String, dynamic>>>[];
      final controller = await pumpNumericGrid(
        tester,
        row: row,
        onCellValueChanged: events.add,
      );

      await openEditorOnFirstCell(tester);
      await tester.enterText(find.byType(TextField), '3');
      controller.stopEditing();
      await tester.pumpAndSettle();

      expect(events, hasLength(1));
      expect(events.single.oldValue, 1);
      expect(events.single.newValue, 3.0);
      expect(row['v'], 3.0);
    });
  });
}
