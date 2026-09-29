import 'package:fl_chart/fl_chart.dart' as fl_chart;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graphic/graphic.dart' as graphic;
import 'package:os_grid_flutter/os_grid_flutter.dart';
import 'package:os_grid_flutter_charts/os_grid_flutter_charts.dart';

const _definition = OsChartDefinition(
  type: OsChartType.line,
  categories: ['Jan', 'Feb', 'Mar'],
  series: [
    OsChartSeries(
      name: 'Revenue',
      points: [
        OsChartPoint(category: 'Jan', value: 100),
        OsChartPoint(category: 'Feb', value: 120),
        OsChartPoint(category: 'Mar', value: 90),
      ],
    ),
    OsChartSeries(
      name: 'Cost',
      points: [
        OsChartPoint(category: 'Jan', value: 60),
        OsChartPoint(category: 'Feb', value: 70),
        OsChartPoint(category: 'Mar', value: 50),
      ],
    ),
  ],
  sourceRange: CellRange(startRow: 0, endRow: 2, startColumn: 1, endColumn: 2),
);

OsChartDefinition _withType(OsChartType type) => OsChartDefinition(
  type: type,
  categories: _definition.categories,
  series: _definition.series,
  sourceRange: _definition.sourceRange,
);

/// Pumps [renderer] rendering [type] inside a sized surface, via a Builder
/// so the render call happens with a real context after pumping starts.
Future<void> pumpChart(
  WidgetTester tester,
  OsChartRenderer renderer,
  OsChartType type,
) async {
  OsChartDefinition? captured;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) {
            // Defer the actual render to the build of a child so the
            // definition/type can't be captured before a context exists.
            captured = _withType(type);
            return SizedBox(
              width: 400,
              height: 300,
              child: renderer.render(context, captured!, const OsChartStyle()),
            );
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('FlChartRenderer', () {
    for (final type in OsChartType.values) {
      testWidgets('renders ${type.name}', (tester) async {
        await pumpChart(tester, const FlChartRenderer(), type);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('renders a fl_chart LineChart for line type', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => SizedBox(
                width: 400,
                height: 300,
                child: const FlChartRenderer().render(
                  context,
                  _definition,
                  const OsChartStyle(),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(fl_chart.LineChart), findsOneWidget);
    });
  });

  group('GraphicChartRenderer', () {
    for (final type in OsChartType.values) {
      testWidgets('renders ${type.name}', (tester) async {
        await pumpChart(tester, const GraphicChartRenderer(), type);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('renders a graphic Chart for line type', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => SizedBox(
                width: 400,
                height: 300,
                child: const GraphicChartRenderer().render(
                  context,
                  _definition,
                  const OsChartStyle(),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Chart<D> is generic — match by subtype, not exact runtimeType.
      expect(find.byWidgetPredicate((w) => w is graphic.Chart), findsOneWidget);
    });
  });

  group('OsIntegratedChart', () {
    testWidgets('renders the placeholder until a chart event arrives', (
      tester,
    ) async {
      final controller = OsGridController<dynamic>();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: OsIntegratedChart(controller: controller)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Select a range and pick a chart type'), findsOneWidget);

      controller.emitChartRangeCreated(
        const OsChartRangeCreatedEvent(definition: _definition),
      );
      await tester.pumpAndSettle();

      expect(find.text('Select a range and pick a chart type'), findsNothing);
      expect(find.byType(fl_chart.LineChart), findsOneWidget);
    });

    testWidgets('showAsDialog renders the definition', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => OsIntegratedChart.showAsDialog(
                    context,
                    definition: _definition,
                  ),
                  child: const Text('Chart it'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Chart it'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.byType(fl_chart.LineChart), findsOneWidget);
    });
  });
}
