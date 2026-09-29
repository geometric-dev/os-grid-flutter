# Changelog

## 0.1.0

- **Initial release**: `FlChartRenderer` (fl_chart) and `GraphicChartRenderer` (graphic) implementing the core `OsChartRenderer` interface for line, bar, pie and scatter series.
- `OsChartSeriesLayout` support: grouped (default), stacked and normalized. Stacked bars render as a single rod with per-series `rodStackItems`; normalized layouts scale bar, line and scatter values against `OsChartDefinition.totalFor(category)`.
- `OsIntegratedChart` live panel listening to `onChartRangeCreated`, plus a `showAsDialog` helper.
