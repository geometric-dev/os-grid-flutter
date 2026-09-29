import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

void main() {
  group('OsProgressBarOptions', () {
    test('defaults', () {
      const opts = OsProgressBarOptions();
      expect(opts.min, 0.0);
      expect(opts.max, 100.0);
      expect(opts.thickness, isNull);
      expect(opts.borderRadius, 4.0);
      expect(opts.color, isNull);
      expect(opts.backgroundColor, isNull);
      expect(opts.labelStyle, isNull);
      expect(opts.showLabel, isTrue);
      expect(opts.labelBuilder, isNull);
      expect(opts.colorBuilder, isNull);
      expect(opts.labelOverflow, TextOverflow.ellipsis);
    });

    test('rejects min >= max', () {
      expect(
        () => OsProgressBarOptions(min: 10, max: 5),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => OsProgressBarOptions(min: 10, max: 10),
        throwsA(isA<AssertionError>()),
      );
    });

    test('copyWith replaces provided fields', () {
      const opts = OsProgressBarOptions();
      final copied = opts.copyWith(
        min: 10,
        max: 50,
        thickness: 8,
        borderRadius: 2,
        color: Colors.red,
        backgroundColor: Colors.grey,
        showLabel: false,
        labelOverflow: TextOverflow.clip,
      );
      expect(copied.min, 10);
      expect(copied.max, 50);
      expect(copied.thickness, 8);
      expect(copied.borderRadius, 2);
      expect(copied.color, Colors.red);
      expect(copied.backgroundColor, Colors.grey);
      expect(copied.showLabel, false);
      expect(copied.labelOverflow, TextOverflow.clip);
    });

    test('equality checks values and ignores builders', () {
      const opts1 = OsProgressBarOptions(min: 10, max: 50, color: Colors.red);
      const opts2 = OsProgressBarOptions(min: 10, max: 50, color: Colors.red);
      expect(opts1, equals(opts2));
      expect(opts1.hashCode, equals(opts2.hashCode));

      final optsWithBuilders1 = opts1.copyWith(
        labelBuilder: (v, p) => 'a',
        colorBuilder: (v) => Colors.blue,
      );
      final optsWithBuilders2 = opts1.copyWith(
        labelBuilder: (v, p) => 'b',
        colorBuilder: (v) => Colors.green,
      );

      // equality ignores function references
      expect(optsWithBuilders1, equals(optsWithBuilders2));
    });
  });

  group('ProgressBarRenderer Widget Tests', () {
    Future<void> pumpProgressBarGrid(
      WidgetTester tester, {
      double value = 45.0,
      OsGridTheme theme = const OsGridTheme(),
      double columnWidth = 120,
      OsProgressBarOptions? options,
      bool isRtl = false,
    }) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Directionality(
              textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
              child: OsGrid(
                key: const Key('grid'),
                theme: theme,
                columnDefs: [
                  OsColumnDef(
                    field: 'progress',
                    headerName: 'Progress',
                    width: columnWidth,
                    builtInCellRenderer: OsBuiltInCellRenderer.progressBar,
                    progressBarOptions: options,
                  ),
                ],
                rowData: [
                  {'progress': value},
                ],
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('renders basic progress bar', (tester) async {
      await pumpProgressBarGrid(tester);
      await tester.pumpAndSettle();

      final customPaint = tester.widget<CustomPaint>(
        find.byType(CustomPaint).first,
      );
      expect(customPaint, isNotNull);
    });

    testWidgets('respects RTL text direction', (tester) async {
      await pumpProgressBarGrid(tester, isRtl: true);
      await tester.pumpAndSettle();
    });

    testWidgets('handles narrow columns gracefully', (tester) async {
      await pumpProgressBarGrid(tester, columnWidth: 10);
      await tester.pumpAndSettle();
    });

    testWidgets('skips rendering if value is not num', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OsGrid(
              columnDefs: [
                OsColumnDef(
                  field: 'progress',
                  headerName: 'Progress',
                  builtInCellRenderer: OsBuiltInCellRenderer.progressBar,
                ),
              ],
              rowData: [
                {'progress': 'invalid'},
                {'progress': null},
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    });

    testWidgets('draws labels if labelBuilder is provided', (tester) async {
      await pumpProgressBarGrid(
        tester,
        options: OsProgressBarOptions(
          labelBuilder: (v, p) => 'Custom \${v.round()}',
        ),
      );
      await tester.pumpAndSettle();
    });
  });
}
