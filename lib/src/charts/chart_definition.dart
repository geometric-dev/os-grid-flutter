import 'package:flutter/material.dart';

import '../selection/cell_range.dart';

/// The type of chart to render from an [OsChartDefinition].
enum OsChartType { line, bar, pie, scatter }

/// How multiple series are arranged relative to each other.
///
/// [grouped] draws series side by side (default). [stacked] piles series
/// values on top of each other per category. [normalized] scales each
/// category's series values so they sum to 1 (proportional rendering).
enum OsChartSeriesLayout { grouped, stacked, normalized }

/// A single (category, value) data point of an [OsChartSeries].
class OsChartPoint {
  /// Creates a chart point.
  const OsChartPoint({required this.category, required this.value});

  /// The category-axis label for this point.
  final String category;

  /// The numeric value at this point.
  final num value;

  @override
  bool operator ==(Object other) =>
      other is OsChartPoint &&
      other.category == category &&
      other.value == value;

  @override
  int get hashCode => Object.hash(category, value);

  @override
  String toString() => 'OsChartPoint($category: $value)';
}

/// One named series of an [OsChartDefinition].
class OsChartSeries {
  /// Creates a chart series.
  const OsChartSeries({required this.name, required this.points});

  /// The series display name (usually the source column's header).
  final String name;

  /// The points of this series, in category order.
  final List<OsChartPoint> points;

  @override
  bool operator ==(Object other) =>
      other is OsChartSeries &&
      other.name == name &&
      _listsEqual(other.points, points);

  static bool _listsEqual(List<OsChartPoint> a, List<OsChartPoint> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(name, Object.hashAll(points));

  @override
  String toString() => 'OsChartSeries($name, ${points.length} points)';
}

/// A chartable snapshot of grid data, extracted from a cell range selection.
///
/// Produced by `OsGridController.createChartRange` (range → definition
/// extraction is chart-library agnostic); render it with any
/// [OsChartRenderer] implementation — e.g. the `os_grid_flutter_charts`
/// companion package's fl_chart / graphic renderers.
class OsChartDefinition {
  /// Creates a chart definition.
  const OsChartDefinition({
    required this.type,
    required this.categories,
    required this.series,
    required this.sourceRange,
    this.seriesLayout = OsChartSeriesLayout.grouped,
  });

  /// The chart type the definition was created for.
  final OsChartType type;

  /// How multiple series are arranged (ignored by pie charts).
  final OsChartSeriesLayout seriesLayout;

  /// The category-axis labels (union of all series' categories, in order).
  final List<String> categories;

  /// The data series, one per value column (or per row when transposed).
  final List<OsChartSeries> series;

  /// The cell range the data was extracted from.
  final CellRange sourceRange;

  /// Convenience access to one series' values indexed against
  /// [categories] (null where a series skips a category).
  List<num?> valuesOf(String seriesName) {
    for (final s in series) {
      if (s.name != seriesName) continue;
      final byCategory = {for (final p in s.points) p.category: p.value};
      return [for (final category in categories) byCategory[category]];
    }
    return List.filled(categories.length, null);
  }

  /// Sum of every series' value at [category] (missing points count 0).
  ///
  /// Denominator for [OsChartSeriesLayout.normalized] rendering.
  num totalFor(String category) {
    var total = 0.0;
    for (final s in series) {
      for (final p in s.points) {
        if (p.category == category) total += p.value.toDouble();
      }
    }
    return total;
  }
}

/// Visual style for a rendered chart, bridged from the grid theme.
///
/// Chart renderers should consume only these colours so charts stay visually
/// consistent with the grid without knowing about `OsGridTheme`.
class OsChartStyle {
  /// Creates a chart style.
  const OsChartStyle({
    this.palette = defaultPalette,
    this.background,
    this.foreground,
    this.gridLineColor,
    this.tooltipBackground,
  });

  /// Derives a style from the grid's resolved chrome colours.
  factory OsChartStyle.fromColors({
    Color? accentColor,
    Color? background,
    Color? foreground,
    Color? borderColor,
  }) {
    return OsChartStyle(
      palette: accentColor == null
          ? defaultPalette
          : [accentColor, ...defaultPalette],
      background: background,
      foreground: foreground,
      gridLineColor: borderColor,
    );
  }

  /// The default series colour palette (AG Grid Quartz-inspired hues).
  static const List<Color> defaultPalette = [
    Color(0xFF4572A7),
    Color(0xFFAA4643),
    Color(0xFF89A54E),
    Color(0xFF71588E),
    Color(0xFF4198AF),
    Color(0xFFF28E43),
  ];

  /// Series colours, applied per series in order.
  final List<Color> palette;

  /// Chart background colour (defaults to the surface it sits on).
  final Color? background;

  /// Axis / label colour.
  final Color? foreground;

  /// Grid line colour.
  final Color? gridLineColor;

  /// Tooltip background colour.
  final Color? tooltipBackground;
}

/// Contract for turning an [OsChartDefinition] into a widget.
///
/// Implemented by chart-library backends in the `os_grid_flutter_charts`
/// companion package (`FlChartRenderer`, `GraphicChartRenderer`); the core
/// package has no chart-library dependency, and applications may provide
/// their own implementation for any other backend.
abstract class OsChartRenderer {
  /// Renders [definition] as a widget styled with [style].
  ///
  /// Implementations should be pure functions of their inputs (no internal
  /// caching of definitions) so the grid can re-render freely.
  Widget render(
    BuildContext context,
    OsChartDefinition definition,
    OsChartStyle style,
  );
}
