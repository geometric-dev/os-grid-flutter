/// Integrated Charts companion for os_grid_flutter.
///
/// Renders chart definition snapshots extracted by the core package's
/// `createChartRange` controller API with either the fl_chart backend
/// (`FlChartRenderer`) or the graphic backend (`GraphicChartRenderer`),
/// both implementing the core `OsChartRenderer` interface.
library;

export 'src/fl_chart_renderer.dart';
export 'src/graphic_chart_renderer.dart';
export 'src/os_integrated_chart.dart';
