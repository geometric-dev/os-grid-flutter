import '../selection/cell_range.dart';
import 'chart_definition.dart';

/// Pure range-selection → [OsChartDefinition] extraction.
///
/// Input is a plain value matrix (one entry per display row in the source
/// range, one entry per display column) plus the matching column display
/// names, so the service is unit-testable and independent of the data
/// model. The owning `_OsGridState` gathers the matrix from the displayed
/// rows/columns and delegates here.
abstract final class ChartRangeExtractor {
  /// Builds a chart definition from the given cell matrix.
  ///
  /// Semantics (AG Grid range-chart parity):
  /// - The first eligible column supplies the category axis; the remaining
  ///   fully-numeric columns become series. Non-numeric trailing columns
  ///   are ignored.
  /// - A single-column range of numbers yields one series named after the
  ///   column, with row indices as categories.
  /// - With [transpose] the roles swap: each row becomes a series (named by
  ///   its first-column value) and the column headers become categories;
  ///   rows containing non-numeric cells outside the category column are
  ///   skipped.
  ///
  /// Returns null when no chartable data can be derived.
  static OsChartDefinition? extract({
    required OsChartType type,
    required CellRange sourceRange,
    required List<String> columnNames,
    required List<List<dynamic>> cellValues,
    bool transpose = false,
    OsChartSeriesLayout seriesLayout = OsChartSeriesLayout.grouped,
  }) {
    if (columnNames.isEmpty || cellValues.isEmpty) return null;

    if (transpose) {
      return _extractTransposed(
        type,
        sourceRange,
        columnNames,
        cellValues,
        seriesLayout,
      );
    }
    return _extractNormal(
      type,
      sourceRange,
      columnNames,
      cellValues,
      seriesLayout,
    );
  }

  static OsChartDefinition? _extractNormal(
    OsChartType type,
    CellRange sourceRange,
    List<String> columnNames,
    List<List<dynamic>> cellValues,
    OsChartSeriesLayout seriesLayout,
  ) {
    final categories = <String>[];
    final series = <OsChartSeries>[];

    for (var c = 0; c < columnNames.length; c++) {
      final columnValues = [for (final row in cellValues) row[c]];

      if (c == 0 && !_isNumericColumn(columnValues)) {
        // First column becomes the category axis when non-numeric.
        categories.addAll([
          for (final value in columnValues) value?.toString() ?? '',
        ]);
        continue;
      }

      if (_isNumericColumn(columnValues)) {
        series.add(
          OsChartSeries(
            name: columnNames[c],
            points: [
              for (var r = 0; r < columnValues.length; r++)
                OsChartPoint(
                  category: categories.isNotEmpty
                      ? categories[r]
                      : (r + 1).toString(),
                  value: (columnValues[r] as num),
                ),
            ],
          ),
        );
      }
      // Non-numeric trailing columns are skipped.
    }

    if (series.isEmpty) return null;

    if (categories.isEmpty) {
      categories.addAll([
        for (var r = 0; r < cellValues.length; r++) (r + 1).toString(),
      ]);
    }

    return OsChartDefinition(
      type: type,
      categories: categories,
      series: series,
      sourceRange: sourceRange,
      seriesLayout: seriesLayout,
    );
  }

  static OsChartDefinition? _extractTransposed(
    OsChartType type,
    CellRange sourceRange,
    List<String> columnNames,
    List<List<dynamic>> cellValues,
    OsChartSeriesLayout seriesLayout,
  ) {
    if (columnNames.length < 2) return null;

    final categories = columnNames.sublist(1);
    final series = <OsChartSeries>[];

    for (var r = 0; r < cellValues.length; r++) {
      final row = cellValues[r];
      final seriesName = row.first?.toString() ?? '';
      final points = <OsChartPoint>[];
      var allNumeric = true;
      for (var c = 1; c < row.length; c++) {
        final value = _asNum(row[c]);
        if (value == null) {
          allNumeric = false;
          break;
        }
        points.add(OsChartPoint(category: categories[c - 1], value: value));
      }
      if (!allNumeric || points.isEmpty) continue;
      series.add(OsChartSeries(name: seriesName, points: points));
    }

    if (series.isEmpty) return null;

    return OsChartDefinition(
      type: type,
      categories: categories,
      series: series,
      sourceRange: sourceRange,
      seriesLayout: seriesLayout,
    );
  }

  static bool _isNumericColumn(List<dynamic> values) {
    if (values.isEmpty) return false;
    for (final value in values) {
      if (_asNum(value) == null) return false;
    }
    return true;
  }

  static num? _asNum(dynamic value) {
    if (value is num) return value;
    if (value is String) return num.tryParse(value);
    return null;
  }
}
