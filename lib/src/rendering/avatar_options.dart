import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../theming/os_grid_theme.dart';

/// Configuration for the built-in `OsBuiltInCellRenderer.avatar` cell
/// renderer.
///
/// Use this class to customize the visual appearance, hashing palette, and
/// label extraction of avatar initials painted directly onto the canvas.
@immutable
class OsAvatarOptions<TData> {
  /// Creates a new avatar configuration.
  const OsAvatarOptions({
    this.radius = 14.0,
    this.gap = 8.0,
    this.color,
    this.palette,
    this.textStyle,
    this.initialsGetter,
    this.showLabel = true,
  });

  /// The radius of the avatar circle. Defaults to 14.0.
  final double radius;

  /// The padding between the avatar and the text label (if [showLabel] is true).
  /// Defaults to 8.0.
  final double gap;

  /// An explicit fixed color for the avatar background.
  ///
  /// If provided, this color is always used. If null, the color is determined
  /// dynamically by hashing the display value against the [palette].
  final Color? color;

  /// The palette of colors to use for dynamic hashing.
  ///
  /// If null, a default Material-like palette is used. The string's codeUnits
  /// are hashed via FNV-1a to deterministically pick a color from this palette.
  final List<Color>? palette;

  /// The text style for the initials and label.
  ///
  /// If null, defaults to [OsGridTheme.cellTextStyle]. The initials color may
  /// be dynamically flipped to white/black to ensure contrast against the
  /// background color.
  final TextStyle? textStyle;

  /// An optional builder to extract initials from the raw row data.
  ///
  /// If provided, this is evaluated first. If it returns null, the renderer
  /// attempts to extract 1–2 leading Unicode code points from the words of
  /// the string representation of the cell value.
  final String? Function(TData row)? initialsGetter;

  /// Whether to show the full name text label alongside the avatar. Defaults to true.
  final bool showLabel;

  /// Creates a copy of this configuration with the given fields replaced.
  OsAvatarOptions<TData> copyWith({
    double? radius,
    double? gap,
    Color? color,
    List<Color>? palette,
    TextStyle? textStyle,
    String? Function(TData row)? initialsGetter,
    bool? showLabel,
  }) {
    return OsAvatarOptions<TData>(
      radius: radius ?? this.radius,
      gap: gap ?? this.gap,
      color: color ?? this.color,
      palette: palette ?? this.palette,
      textStyle: textStyle ?? this.textStyle,
      initialsGetter: initialsGetter ?? this.initialsGetter,
      showLabel: showLabel ?? this.showLabel,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OsAvatarOptions<TData> &&
        other.radius == radius &&
        other.gap == gap &&
        other.color == color &&
        listEquals(other.palette, palette) &&
        other.textStyle == textStyle &&
        other.showLabel == showLabel;
    // Note: Function fields (initialsGetter) are excluded from equality
  }

  @override
  int get hashCode => Object.hash(
    radius,
    gap,
    color,
    palette == null ? null : Object.hashAll(palette!),
    textStyle,
    showLabel,
  );
}
