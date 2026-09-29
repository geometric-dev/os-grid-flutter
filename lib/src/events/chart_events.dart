import '../charts/chart_definition.dart';
import 'os_grid_event.dart';

/// Emitted when a chart definition is created from a cell range selection
/// (via the chart palette popup or `OsGridController.createChartRange`).
///
/// Render the [definition] with an [OsChartRenderer] — e.g. from the
/// `os_grid_flutter_charts` companion package — or hand it to any charting
/// stack of your own.
///
/// ```dart
/// controller.onChartRangeCreated.listen((event) {
///   print('${event.definition.series.length} series charted');
/// });
/// ```
class OsChartRangeCreatedEvent extends OsGridEvent {
  /// Creates a chart range created event.
  const OsChartRangeCreatedEvent({required this.definition});

  /// The chart definition extracted from the source range.
  final OsChartDefinition definition;
}
