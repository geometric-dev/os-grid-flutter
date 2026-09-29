import 'package:flutter/widgets.dart';

import '../theming/os_grid_theme.dart';

/// Configuration for the built-in `OsBuiltInCellRenderer.progressBar` cell
/// renderer.
///
/// Use this class to customize the visual appearance, math, and labeling of
/// progress bars painted directly onto the canvas.
@immutable
class OsProgressBarOptions {
  /// Creates a new progress bar configuration.
  const OsProgressBarOptions({
    this.min = 0.0,
    this.max = 100.0,
    this.thickness,
    this.borderRadius = 4.0,
    this.color,
    this.backgroundColor,
    this.labelStyle,
    this.showLabel = true,
    this.labelBuilder,
    this.colorBuilder,
    this.labelOverflow = TextOverflow.ellipsis,
  }) : assert(max > min, 'max must be strictly greater than min');

  /// The minimum expected value (maps to 0% progress). Defaults to 0.0.
  final double min;

  /// The maximum expected value (maps to 100% progress). Defaults to 100.0.
  final double max;

  /// The vertical thickness of the progress bar track. If null, the track fills
  /// the available vertical space of the cell (minus padding).
  final double? thickness;

  /// The border radius for the track and the filled portion. Defaults to 4.0.
  final double borderRadius;

  /// The color of the filled portion of the progress bar. If null, defaults
  /// to [OsGridTheme.accentColor].
  final Color? color;

  /// The color of the empty track portion. If null, defaults to a muted variant
  /// of the theme foreground.
  final Color? backgroundColor;

  /// The text style for the label. If null, defaults to [OsGridTheme.cellTextStyle].
  final TextStyle? labelStyle;

  /// Whether to show a text label alongside the progress bar. Defaults to true.
  final bool showLabel;

  /// An optional builder to format the display label.
  ///
  /// The `value` is the raw numeric cell value. The `progress` is the clamped
  /// 0.0 to 1.0 ratio. If not provided, defaults to showing the percentage
  /// (e.g., "45%").
  final String Function(double value, double progress)? labelBuilder;

  /// An optional builder to dynamically set the fill color based on the value.
  /// Useful for status colors (e.g., red when value < 20).
  final Color? Function(double value)? colorBuilder;

  /// How to handle the label text when the cell width is too narrow to fit it.
  /// Defaults to [TextOverflow.ellipsis].
  final TextOverflow labelOverflow;

  /// Creates a copy of this configuration with the given fields replaced.
  OsProgressBarOptions copyWith({
    double? min,
    double? max,
    double? thickness,
    double? borderRadius,
    Color? color,
    Color? backgroundColor,
    TextStyle? labelStyle,
    bool? showLabel,
    String Function(double value, double progress)? labelBuilder,
    Color? Function(double value)? colorBuilder,
    TextOverflow? labelOverflow,
  }) {
    return OsProgressBarOptions(
      min: min ?? this.min,
      max: max ?? this.max,
      thickness: thickness ?? this.thickness,
      borderRadius: borderRadius ?? this.borderRadius,
      color: color ?? this.color,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      labelStyle: labelStyle ?? this.labelStyle,
      showLabel: showLabel ?? this.showLabel,
      labelBuilder: labelBuilder ?? this.labelBuilder,
      colorBuilder: colorBuilder ?? this.colorBuilder,
      labelOverflow: labelOverflow ?? this.labelOverflow,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OsProgressBarOptions &&
        other.min == min &&
        other.max == max &&
        other.thickness == thickness &&
        other.borderRadius == borderRadius &&
        other.color == color &&
        other.backgroundColor == backgroundColor &&
        other.labelStyle == labelStyle &&
        other.showLabel == showLabel &&
        other.labelOverflow == labelOverflow;
    // Note: Function fields (labelBuilder, colorBuilder) are excluded from equality
  }

  @override
  int get hashCode => Object.hash(
    min,
    max,
    thickness,
    borderRadius,
    color,
    backgroundColor,
    labelStyle,
    showLabel,
    labelOverflow,
  );
}
