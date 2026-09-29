import 'dart:async';

import 'package:flutter/material.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

import 'fl_chart_renderer.dart';

/// Live chart panel driven by the grid's `onChartRangeCreated` stream.
///
/// Subscribe with [controller], pick a [renderer] (defaults to
/// [FlChartRenderer]), and embed the widget wherever the chart should
/// live — below the grid, in a side panel, or in a dialog via
/// [showAsDialog]. Re-renders automatically whenever a new chart
/// definition is created from a range selection.
class OsIntegratedChart extends StatefulWidget {
  const OsIntegratedChart({
    super.key,
    required this.controller,
    this.renderer = const FlChartRenderer(),
    this.style,
    this.width,
    this.height = 240,
    this.placeholder,
  });

  /// The grid controller whose chart events drive this panel.
  final OsGridController<dynamic> controller;

  /// The chart backend. Defaults to the fl_chart renderer.
  final OsChartRenderer renderer;

  /// Chart styling bridged from the grid theme. When null, a style is
  /// derived from the Material theme.
  final OsChartStyle? style;

  final double? width;
  final double? height;

  /// Shown before the first chart definition arrives.
  final Widget? placeholder;

  /// Opens a chart of [definition] rendered by [renderer] in a dialog.
  static Future<void> showAsDialog(
    BuildContext context, {
    required OsChartDefinition definition,
    OsChartRenderer renderer = const FlChartRenderer(),
    OsChartStyle? style,
    Size size = const Size(560, 360),
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        content: SizedBox(
          width: size.width,
          height: size.height,
          child: renderer.render(
            context,
            definition,
            style ?? const OsChartStyle(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  State<OsIntegratedChart> createState() => _OsIntegratedChartState();
}

class _OsIntegratedChartState extends State<OsIntegratedChart> {
  OsChartDefinition? _definition;
  StreamSubscription<OsChartRangeCreatedEvent>? _subscription;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void didUpdateWidget(covariant OsIntegratedChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.controller, oldWidget.controller)) {
      _listen();
    }
  }

  void _listen() {
    _subscription?.cancel();
    _subscription = widget.controller.onChartRangeCreated.listen((event) {
      if (mounted) setState(() => _definition = event.definition);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final definition = _definition;
    final style =
        widget.style ??
        OsChartStyle.fromColors(
          accentColor: Theme.of(context).colorScheme.primary,
          background: Theme.of(context).colorScheme.surface,
          foreground: Theme.of(context).colorScheme.onSurface,
          borderColor: Theme.of(context).dividerColor,
        );

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: definition == null
          ? widget.placeholder ??
                Center(
                  child: Text(
                    'Select a range and pick a chart type',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                )
          : widget.renderer.render(context, definition, style),
    );
  }
}
