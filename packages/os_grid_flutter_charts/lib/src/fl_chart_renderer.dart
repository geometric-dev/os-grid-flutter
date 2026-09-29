import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

/// [OsChartRenderer] backend backed by **fl_chart** (MIT).
///
/// Renders line / bar / pie / scatter charts from an [OsChartDefinition]:
/// one series per definition series (pie uses the first series only, one
/// section per category, matching AG Grid's single-measure pie).
class FlChartRenderer implements OsChartRenderer {
  const FlChartRenderer();

  @override
  Widget render(
    BuildContext context,
    OsChartDefinition definition,
    OsChartStyle style,
  ) {
    return switch (definition.type) {
      OsChartType.line => _renderLine(definition, style),
      OsChartType.bar => _renderBar(definition, style),
      OsChartType.pie => _renderPie(definition, style),
      OsChartType.scatter => _renderScatter(definition, style),
    };
  }

  Color seriesColor(OsChartStyle style, int index) =>
      style.palette[index % style.palette.length];

  Widget _renderLine(OsChartDefinition definition, OsChartStyle style) {
    return LineChart(
      LineChartData(
        backgroundColor: style.background,
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: style.gridLineColor ?? Colors.grey.shade300,
            strokeWidth: 1,
          ),
        ),
        titlesData: _titlesData(definition, style),
        lineBarsData: [
          for (var i = 0; i < definition.series.length; i++)
            LineChartBarData(
              color: seriesColor(style, i),
              barWidth: 2,
              dotData: const FlDotData(show: false),
              spots: [
                for (final point in definition.series[i].points)
                  FlSpot(
                    definition.categories.indexOf(point.category).toDouble(),
                    _scaledValue(definition, point).toDouble(),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _renderBar(OsChartDefinition definition, OsChartStyle style) {
    return BarChart(
      BarChartData(
        backgroundColor: style.background,
        gridData: const FlGridData(drawVerticalLine: false),
        titlesData: _titlesData(definition, style),
        barGroups: [
          for (var c = 0; c < definition.categories.length; c++)
            BarChartGroupData(
              x: c,
              // Stacked AND normalized both render as one rod per category
              // with per-series stack segments; normalized additionally
              // scales the segments so each rod spans 0..1.
              barRods: definition.seriesLayout != OsChartSeriesLayout.grouped
                  ? [
                      BarChartRodData(
                        toY:
                            definition.seriesLayout ==
                                OsChartSeriesLayout.normalized
                            ? 1.0
                            : definition
                                  .totalFor(definition.categories[c])
                                  .toDouble(),
                        width: 16,
                        rodStackItems: [
                          for (var i = 0; i < definition.series.length; i++)
                            _stackItem(definition, i, c, style),
                        ],
                      ),
                    ]
                  : [
                      for (var i = 0; i < definition.series.length; i++)
                        BarChartRodData(
                          toY: _scaledValue(
                            definition,
                            _pointFor(
                              definition.series[i],
                              definition.categories[c],
                            ),
                          ).toDouble(),
                          color: seriesColor(style, i),
                          width: 12,
                        ),
                    ],
            ),
        ],
      ),
    );
  }

  /// The stack segment for a series index at a category index. Normalized
  /// layouts scale each segment so the rod spans 0..1.
  BarChartRodStackItem _stackItem(
    OsChartDefinition definition,
    int seriesIndex,
    int categoryIndex,
    OsChartStyle style,
  ) {
    final category = definition.categories[categoryIndex];
    final raw = _valueFor(definition.series[seriesIndex], category);
    var from = 0.0;
    for (var i = 0; i < seriesIndex; i++) {
      from += _valueFor(definition.series[i], category);
    }
    if (definition.seriesLayout == OsChartSeriesLayout.normalized) {
      final total = definition.totalFor(category).toDouble();
      final scale = total == 0 ? 0.0 : 1 / total;
      final to = (from + raw) * scale;
      return BarChartRodStackItem(
        from * scale,
        to,
        seriesColor(style, seriesIndex),
      );
    }
    return BarChartRodStackItem(
      from,
      from + raw,
      seriesColor(style, seriesIndex),
    );
  }

  /// The point of [series] at [category], or a zero point when absent.
  OsChartPoint _pointFor(OsChartSeries series, String category) {
    for (final point in series.points) {
      if (point.category == category) return point;
    }
    return OsChartPoint(category: category, value: 0);
  }

  /// Applies [OsChartSeriesLayout.normalized] scaling; other layouts pass
  /// the raw value through.
  num _scaledValue(OsChartDefinition definition, OsChartPoint point) {
    if (definition.seriesLayout != OsChartSeriesLayout.normalized) {
      return point.value;
    }
    final total = definition.totalFor(point.category);
    return total == 0 ? 0.0 : point.value / total;
  }

  Widget _renderPie(OsChartDefinition definition, OsChartStyle style) {
    final series = definition.series.first;
    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        sections: [
          for (final point in series.points)
            PieChartSectionData(
              value: point.value.toDouble(),
              title: point.category,
              color: seriesColor(
                style,
                definition.categories.indexOf(point.category),
              ),
              radius: 60,
              titleStyle: TextStyle(
                fontSize: 11,
                color: style.foreground ?? Colors.black87,
              ),
            ),
        ],
      ),
    );
  }

  Widget _renderScatter(OsChartDefinition definition, OsChartStyle style) {
    return ScatterChart(
      ScatterChartData(
        backgroundColor: style.background,
        gridData: const FlGridData(drawVerticalLine: false),
        titlesData: _titlesData(definition, style),
        scatterSpots: [
          for (var i = 0; i < definition.series.length; i++)
            for (final point in definition.series[i].points)
              ScatterSpot(
                definition.categories.indexOf(point.category).toDouble(),
                _scaledValue(definition, point).toDouble(),
                dotPainter: FlDotCirclePainter(color: seriesColor(style, i)),
              ),
        ],
      ),
    );
  }

  FlTitlesData _titlesData(OsChartDefinition definition, OsChartStyle style) {
    final labelColor = style.foreground ?? Colors.black87;
    return FlTitlesData(
      rightTitles: const AxisTitles(),
      topTitles: const AxisTitles(),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 28,
          getTitlesWidget: (value, meta) => SideTitleWidget(
            meta: meta,
            child: Text(
              definition.categories[value.toInt()],
              style: TextStyle(fontSize: 10, color: labelColor),
            ),
          ),
        ),
      ),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 36,
          getTitlesWidget: (value, meta) => SideTitleWidget(
            meta: meta,
            child: Text(
              value.toStringAsFixed(0),
              style: TextStyle(fontSize: 10, color: labelColor),
            ),
          ),
        ),
      ),
    );
  }

  double _valueFor(OsChartSeries series, String category) {
    for (final point in series.points) {
      if (point.category == category) return point.value.toDouble();
    }
    return 0;
  }
}
