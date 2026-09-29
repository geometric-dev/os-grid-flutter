import 'package:fl_chart/fl_chart.dart' as fl_chart;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';
import 'package:os_grid_flutter_charts/os_grid_flutter_charts.dart';

const _definition = OsChartDefinition(
  type: OsChartType.bar,
  categories: ['Jan', 'Feb'],
  series: [
    OsChartSeries(
      name: 'Revenue',
      points: [
        OsChartPoint(category: 'Jan', value: 100),
        OsChartPoint(category: 'Feb', value: 120),
      ],
    ),
    OsChartSeries(
      name: 'Cost',
      points: [
        OsChartPoint(category: 'Jan', value: 60),
        OsChartPoint(category: 'Feb', value: 70),
      ],
    ),
  ],
  sourceRange: CellRange(startRow: 0, endRow: 1, startColumn: 1, endColumn: 2),
);

OsChartDefinition _layout(OsChartSeriesLayout layout) => OsChartDefinition(
  type: _definition.type,
  categories: _definition.categories,
  series: _definition.series,
  sourceRange: _definition.sourceRange,
  seriesLayout: layout,
);

Widget _host(WidgetTester tester, OsChartDefinition definition) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: SizedBox(
            width: 400,
            height: 300,
            child: const FlChartRenderer().render(
              context,
              definition,
              const OsChartStyle(),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('FlChartRenderer series layouts', () {
    testWidgets('grouped bars emit one rod per series', (tester) async {
      await tester.pumpWidget(
        _host(tester, _layout(OsChartSeriesLayout.grouped)),
      );
      await tester.pumpAndSettle();

      final data = tester
          .widget<fl_chart.BarChart>(find.byType(fl_chart.BarChart))
          .data;
      expect(data.barGroups.first.barRods.length, 2);
    });

    testWidgets('stacked bars emit one rod with one stack item per series', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(tester, _layout(OsChartSeriesLayout.stacked)),
      );
      await tester.pumpAndSettle();

      final data = tester
          .widget<fl_chart.BarChart>(find.byType(fl_chart.BarChart))
          .data;
      final rod = data.barGroups.first.barRods.single;
      expect(rod.rodStackItems.length, 2);
      // Rod total = category total across series (Jan: 100 + 60).
      expect(rod.toY, 160);
    });

    testWidgets('normalized stacked bars span 0..1 per category', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(tester, _layout(OsChartSeriesLayout.normalized)),
      );
      await tester.pumpAndSettle();

      final data = tester
          .widget<fl_chart.BarChart>(find.byType(fl_chart.BarChart))
          .data;
      final rod = data.barGroups.first.barRods.single;
      final last = rod.rodStackItems.last;
      expect(last.toY, closeTo(1.0, 0.0001));
    });

    testWidgets('normalized line spots scale against the category total', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          tester,
          OsChartDefinition(
            type: OsChartType.line,
            categories: _definition.categories,
            series: _definition.series,
            sourceRange: _definition.sourceRange,
            seriesLayout: OsChartSeriesLayout.normalized,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final data = tester
          .widget<fl_chart.LineChart>(find.byType(fl_chart.LineChart))
          .data;
      // Jan total = 160, Revenue share = 100/160 = 0.625.
      expect(data.lineBarsData.first.spots.first.y, closeTo(0.625, 0.0001));
    });
  });

  group('GraphicChartRenderer series layouts', () {
    for (final layout in OsChartSeriesLayout.values) {
      testWidgets('renders bar ${layout.name} without exceptions', (
        tester,
      ) async {
        await tester.pumpWidget(_hostGraphic(tester, _layout(layout)));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });
}

Widget _hostGraphic(WidgetTester tester, OsChartDefinition definition) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: SizedBox(
            width: 400,
            height: 300,
            child: const GraphicChartRenderer().render(
              context,
              definition,
              const OsChartStyle(),
            ),
          ),
        ),
      ),
    ),
  );
}
