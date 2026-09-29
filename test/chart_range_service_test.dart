import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

void main() {
  const range = CellRange(startRow: 0, endRow: 2, startColumn: 0, endColumn: 2);
  const columns = ['Month', 'Revenue', 'Cost'];

  group('ChartRangeExtractor', () {
    test(
      'extracts categories from non-numeric first column and numeric series',
      () {
        final definition = ChartRangeExtractor.extract(
          type: OsChartType.bar,
          sourceRange: range,
          columnNames: columns,
          cellValues: const [
            ['Jan', 100, 60],
            ['Feb', 120, 70],
            ['Mar', 90, 50],
          ],
        );

        expect(definition, isNotNull);
        expect(definition!.type, OsChartType.bar);
        expect(definition.categories, ['Jan', 'Feb', 'Mar']);
        expect(definition.series.map((s) => s.name), ['Revenue', 'Cost']);
        expect(definition.series[0].points, const [
          OsChartPoint(category: 'Jan', value: 100),
          OsChartPoint(category: 'Feb', value: 120),
          OsChartPoint(category: 'Mar', value: 90),
        ]);
        expect(definition.series[1].points[2].value, 50);
        expect(definition.sourceRange, range);
      },
    );

    test(
      'single numeric column yields one series with row-index categories',
      () {
        final definition = ChartRangeExtractor.extract(
          type: OsChartType.line,
          sourceRange: const CellRange(
            startRow: 0,
            endRow: 1,
            startColumn: 1,
            endColumn: 1,
          ),
          columnNames: const ['Revenue'],
          cellValues: const [
            [100],
            [200],
          ],
        );

        expect(definition, isNotNull);
        expect(definition!.categories, ['1', '2']);
        expect(definition.series.single.name, 'Revenue');
        expect(definition.series.single.points[1].value, 200);
      },
    );

    test('skips non-numeric trailing columns', () {
      final definition = ChartRangeExtractor.extract(
        type: OsChartType.line,
        sourceRange: range,
        columnNames: const ['Month', 'Revenue', 'Note'],
        cellValues: const [
          ['Jan', 100, 'good'],
          ['Feb', 120, 'better'],
          ['Mar', 90, 'meh'],
        ],
      );

      expect(definition, isNotNull);
      expect(definition!.series.map((s) => s.name), ['Revenue']);
    });

    test('returns null when no numeric series can be derived', () {
      final definition = ChartRangeExtractor.extract(
        type: OsChartType.bar,
        sourceRange: range,
        columnNames: const ['Month', 'Note'],
        cellValues: const [
          ['Jan', 'good'],
          ['Feb', 'better'],
        ],
      );

      expect(definition, isNull);
    });

    test('returns null for empty input', () {
      expect(
        ChartRangeExtractor.extract(
          type: OsChartType.pie,
          sourceRange: range,
          columnNames: const [],
          cellValues: const [],
        ),
        isNull,
      );
    });

    test('transpose makes rows series and column headers categories', () {
      final definition = ChartRangeExtractor.extract(
        type: OsChartType.line,
        sourceRange: range,
        columnNames: columns,
        cellValues: const [
          ['2024', 100, 60],
          ['2025', 120, 70],
        ],
        transpose: true,
      );

      expect(definition, isNotNull);
      expect(definition!.categories, ['Revenue', 'Cost']);
      expect(definition.series.map((s) => s.name), ['2024', '2025']);
      expect(definition.series[0].points, const [
        OsChartPoint(category: 'Revenue', value: 100),
        OsChartPoint(category: 'Cost', value: 60),
      ]);
    });

    test('valuesOf maps series values onto categories with nulls', () {
      final definition = ChartRangeExtractor.extract(
        type: OsChartType.bar,
        sourceRange: range,
        columnNames: columns,
        cellValues: const [
          ['Jan', 100, 60],
          ['Feb', 120, 70],
        ],
      )!;

      expect(definition.valuesOf('Revenue'), [100, 120]);
      expect(definition.valuesOf('Missing'), [null, null]);
    });
  });
}
