import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

void main() {
  group('GridLiveRegion', () {
    testWidgets('exposes a liveRegion node with the message as label', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: GridLiveRegion(message: '3 rows, 1 selected')),
      );

      final semantics = tester.getSemantics(find.byType(GridLiveRegion));
      expect(semantics.getSemanticsData().flagsCollection.isLiveRegion, isTrue);
      expect(semantics.label, '3 rows, 1 selected');
    });

    testWidgets('announces by changing label without moving focus', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: GridLiveRegion(message: '3 rows, 0 selected')),
      );

      await tester.pumpWidget(
        const MaterialApp(home: GridLiveRegion(message: '5 rows, 2 selected')),
      );
      await tester.pumpAndSettle();

      final semantics = tester.getSemantics(find.byType(GridLiveRegion));
      expect(semantics.label, '5 rows, 2 selected');
      expect(semantics.getSemanticsData().flagsCollection.isLiveRegion, isTrue);
    });

    testWidgets('derives text direction from ambient Directionality', (
      tester,
    ) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.rtl,
          child: GridLiveRegion(message: 'message'),
        ),
      );

      final semantics = tester.getSemantics(find.byType(GridLiveRegion));
      expect(semantics.textDirection, TextDirection.rtl);
    });
  });

  group('gridSummaryMessage', () {
    test('interpolates rows and selected counts into gridSummary', () {
      expect(
        gridSummaryMessage(rowCount: 12, selectedCount: 3),
        '12 rows, 3 selected',
      );
    });

    test('uses localized template via localeText', () {
      const locale = OsLocaleText(gridSummary: '{selected} von {rows}');
      expect(
        gridSummaryMessage(rowCount: 10, selectedCount: 2, localeText: locale),
        '2 von 10',
      );
    });

    test('leaves unknown tokens untouched', () {
      const locale = OsLocaleText(gridSummary: '{rows}/{selected}/{other}');
      expect(
        gridSummaryMessage(rowCount: 1, selectedCount: 0, localeText: locale),
        '1/0/{other}',
      );
    });
  });

  group('rowsSelectedMessage', () {
    test('interpolates count into rowsSelected', () {
      expect(rowsSelectedMessage(count: 7), '7 rows selected');
    });

    test('uses localized template via localeText', () {
      const locale = OsLocaleText(rowsSelected: '{n} Zeilen ausgewählt');
      expect(
        rowsSelectedMessage(count: 4, localeText: locale),
        '4 Zeilen ausgewählt',
      );
    });
  });
}
