# os_grid_flutter_charts

Integrated Charts companion for [`os_grid_flutter`](https://pub.dev/packages/os_grid_flutter).

> **Status: not published to pub.dev yet** (`publish_to: none`). It is developed and tested in the `os-grid-flutter` repository against the local core package. The runnable demo lives in [`example/`](example) — `cd example && flutter run`.

The core grid ships a dependency-free chart model (`OsChartDefinition`, `OsChartSeries`, `OsChartPoint`) and an `OsChartRenderer` adapter interface, but deliberately takes no third-party runtime dependencies. This package plugs real renderers into that interface:

| Renderer | Backing library | Chart types |
|---|---|---|
| `FlChartRenderer` | [fl_chart](https://pub.dev/packages/fl_chart) | line, bar, pie, scatter |
| `GraphicChartRenderer` | [graphic](https://pub.dev/packages/graphic) | line, bar, pie, scatter |

Both support the `OsChartSeriesLayout` layouts — grouped, stacked and normalized.

## Usage

```dart
import 'package:os_grid_flutter/os_grid_flutter.dart';
import 'package:os_grid_flutter_charts/os_grid_flutter_charts.dart';

// A live panel: select a range in the grid, pick a chart type from the
// palette, and the chart renders here.
OsIntegratedChart(controller: controller)

// Or present a definition in a dialog.
OsGrid(
  cellSelection: true,
  enableIntegratedCharts: true,
  onChartRangeCreated: (event) => OsIntegratedChart.showAsDialog(
    context,
    definition: event.definition,
  ),
)
```

`OsIntegratedChart.showAsDialog` presents a definition in a dialog; for a live panel embedded in your own layout use the `OsIntegratedChart` widget directly.

## Licence

MIT — see [LICENSE](LICENSE).
