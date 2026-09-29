import 'package:flutter/material.dart';
import 'package:graphic/graphic.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

/// [OsChartRenderer] backend backed by **graphic** (MIT).
///
/// Renders line / bar / pie / scatter charts from an [OsChartDefinition]
/// via graphic's grammar-of-graphics API. All series are flattened into
/// (category, value, series) tuples with the series variable driving the
/// colour channel; pie charts use a single-dimension polar coordinate.
class GraphicChartRenderer implements OsChartRenderer {
  const GraphicChartRenderer();

  @override
  Widget render(
    BuildContext context,
    OsChartDefinition definition,
    OsChartStyle style,
  ) {
    return switch (definition.type) {
      OsChartType.pie => _renderPie(definition, style),
      _ => _renderCartesian(definition, style),
    };
  }

  /// Flattened row datum shared by the cartesian marks.
  static Map<String, dynamic> _row(String category, num value, String series) =>
      {'category': category, 'value': value.toDouble(), 'series': series};

  List<Map<String, dynamic>> _rows(OsChartDefinition definition) {
    final normalize = definition.seriesLayout == OsChartSeriesLayout.normalized;
    return [
      for (final series in definition.series)
        for (final point in series.points)
          _row(
            point.category,
            normalize
                ? (definition.totalFor(point.category) == 0
                      ? 0.0
                      : point.value / definition.totalFor(point.category))
                : point.value,
            series.name,
          ),
    ];
  }

  Widget _renderCartesian(OsChartDefinition definition, OsChartStyle style) {
    final stacked =
        definition.seriesLayout == OsChartSeriesLayout.stacked &&
        definition.type == OsChartType.bar;
    final Mark<Shape> mark = switch (definition.type) {
      OsChartType.line => LineMark(
        position: Varset('category') * Varset('value'),
        color: ColorEncode(variable: 'series', values: style.palette),
      ),
      OsChartType.bar => IntervalMark(
        position: Varset('category') * Varset('value'),
        color: ColorEncode(variable: 'series', values: style.palette),
        modifiers: stacked ? [StackModifier()] : null,
      ),
      _ => PointMark(
        position: Varset('category') * Varset('value'),
        color: ColorEncode(variable: 'series', values: style.palette),
      ),
    };

    return Chart(
      data: _rows(definition),
      variables: {
        'category': Variable<Map<String, dynamic>, String>(
          accessor: (row) => row['category'] as String,
        ),
        'value': Variable<Map<String, dynamic>, num>(
          accessor: (row) => row['value'] as num,
        ),
        'series': Variable<Map<String, dynamic>, String>(
          accessor: (row) => row['series'] as String,
        ),
      },
      marks: [mark],
    );
  }

  Widget _renderPie(OsChartDefinition definition, OsChartStyle style) {
    final series = definition.series.first;
    return Chart(
      data: [
        for (final point in series.points)
          {'name': point.category, 'value': point.value.toDouble()},
      ],
      variables: {
        'name': Variable<Map<String, dynamic>, String>(
          accessor: (row) => row['name'] as String,
        ),
        'value': Variable<Map<String, dynamic>, num>(
          accessor: (row) => row['value'] as num,
        ),
      },
      coord: PolarCoord(transposed: true, dimCount: 1),
      marks: [
        IntervalMark(
          position: Varset('value'),
          color: ColorEncode(
            variable: 'name',
            values: [
              for (final point in series.points)
                style.palette[definition.categories
                    .indexOf(point.category)
                    .clamp(0, style.palette.length - 1)],
            ],
          ),
          modifiers: [StackModifier()],
        ),
      ],
    );
  }
}
