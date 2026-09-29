import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theming/os_grid_theme.dart';
import 'chart_definition.dart';

/// The mini chart-type palette shown when the user taps the chart button
/// anchored at an active cell range selection (AG Grid "chart range" UX).
///
/// Choosing a type invokes [onSelect]; the owning grid then calls
/// `controller.createChartRange(type: ...)` which emits
/// `onChartRangeCreated` with the extracted definition.
class ChartPalettePopup extends StatelessWidget {
  const ChartPalettePopup({
    super.key,
    required this.anchorRect,
    required this.gridSize,
    this.theme,
    required this.onSelect,
  });

  /// Canvas-space rect of the palette button that opened this popup. The
  /// popup is positioned above it and clamped into [gridSize].
  final Rect anchorRect;

  /// The grid viewport size, used to clamp the popup position.
  final Size gridSize;

  /// The grid theme, for colours. Null = Material defaults.
  final OsGridTheme? theme;

  /// Called with the chosen chart type.
  final ValueChanged<OsChartType> onSelect;

  @override
  Widget build(BuildContext context) {
    final background =
        theme?.headerBackgroundColor ?? Theme.of(context).cardColor;
    final foreground =
        theme?.headerTextColor ?? Theme.of(context).colorScheme.onSurface;
    final borderColor = theme?.borderColor ?? foreground.withValues(alpha: 0.2);

    const popupWidth = 4.0 * 36.0 + 8.0;
    const popupHeight = 44.0;

    final left = anchorRect.left
        .clamp(0.0, math.max(0.0, gridSize.width - popupWidth))
        .toDouble();
    final top = (anchorRect.top - popupHeight - 4)
        .clamp(0.0, math.max(0.0, gridSize.height - popupHeight))
        .toDouble();
    return Transform.translate(
      offset: Offset(left, top),
      child: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(6),
        color: background,
        child: Container(
          width: popupWidth,
          height: popupHeight,
          decoration: BoxDecoration(
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final type in OsChartType.values)
                _ChartTypeButton(
                  type: type,
                  icon: switch (type) {
                    OsChartType.line => Icons.show_chart,
                    OsChartType.bar => Icons.bar_chart,
                    OsChartType.pie => Icons.pie_chart_outline,
                    OsChartType.scatter => Icons.scatter_plot,
                  },
                  color: foreground,
                  onTap: () => onSelect(type),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChartTypeButton extends StatelessWidget {
  const _ChartTypeButton({
    required this.type,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final OsChartType type;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = switch (type) {
      OsChartType.line => 'Line chart',
      OsChartType.bar => 'Bar chart',
      OsChartType.pie => 'Pie chart',
      OsChartType.scatter => 'Scatter chart',
    };
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 20, color: color),
        ),
      ),
    );
  }
}
