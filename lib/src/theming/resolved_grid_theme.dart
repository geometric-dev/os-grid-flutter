import 'package:flutter/material.dart';

import '../columns/os_column_def.dart' show OsColumnDef;
import '../os_grid.dart' show OsGrid;
import 'os_cell_style.dart' show OsCellStyle;
import 'os_grid_theme.dart';
import 'os_row_style.dart' show OsRowStyle;

/// Fully-resolved styling tokens for grid chrome surfaces (menus, popups,
/// tool panels and overlays).
///
/// Every popup surface resolves its colours, fonts and radii through this
/// class exactly once, so fallback values live in a single place instead of
/// being duplicated as hardcoded literals across widget files. When the
/// ambient [OsGridTheme] is null — or omits a token — a sensible
/// Material-derived default is used.
///
/// ```dart
/// final t = ResolvedGridTheme.from(widget.theme);
/// Container(color: t.background, ...)
/// ```
class ResolvedGridTheme {
  const ResolvedGridTheme({
    required this.background,
    required this.foreground,
    required this.accent,
    required this.border,
    required this.chrome,
    required this.hover,
    required this.disabledForeground,
    required this.mutedForeground,
    required this.hintForeground,
    required this.fontFamily,
    required this.baseFontSize,
    this.panelRadius = 6,
    this.controlRadius = 4,
    this.popupElevation = 8,
  });

  /// Resolves every token from [theme], filling any omitted token with the
  /// Material-derived default.
  ///
  /// Derived tokens (chrome/hover surfaces, disabled/muted/hint text) are
  /// computed from the resolved core palette, honouring explicit overrides
  /// from [OsGridTheme] where provided.
  factory ResolvedGridTheme.from(OsGridTheme? theme) {
    final background = theme?.backgroundColor ?? Colors.white;
    final foreground = theme?.foregroundColor ?? Colors.black87;
    return ResolvedGridTheme(
      background: background,
      foreground: foreground,
      accent: theme?.accentColor ?? Colors.blue,
      border: theme?.borderColor ?? Colors.grey.shade300,
      chrome:
          theme?.chromeBackgroundColor ??
          Color.lerp(background, foreground, 0.03)!,
      hover: theme?.hoverRowColor ?? Color.lerp(background, foreground, 0.05)!,
      disabledForeground: foreground.withValues(alpha: 0.38),
      mutedForeground: foreground.withValues(alpha: 0.62),
      hintForeground: foreground.withValues(alpha: 0.40),
      fontFamily:
          theme?.cellTextStyle?.fontFamily ??
          theme?.headerTextStyle?.fontFamily,
      baseFontSize: theme?.cellFontSize ?? 14,
    );
  }

  /// Surface colour behind panel content.
  final Color background;

  /// Primary text/icon colour.
  final Color foreground;

  /// Brand colour for selection, focus borders, checkboxes.
  final Color accent;

  /// Hairline/divider colour.
  final Color border;

  /// Slightly-tinted surface for headers, controls and secondary panels.
  final Color chrome;

  /// Row/item hover highlight.
  final Color hover;

  /// Text colour for disabled items.
  final Color disabledForeground;

  /// Secondary text colour (submenu headers, inactive icons).
  final Color mutedForeground;

  /// Placeholder/hint text colour.
  final Color hintForeground;

  /// Font family inherited from the grid theme (null = platform default).
  final String? fontFamily;

  /// Base font size inherited from the grid theme.
  final double baseFontSize;

  /// Corner radius for popup panels.
  final double panelRadius;

  /// Corner radius for inner controls (inputs, buttons).
  final double controlRadius;

  /// Material elevation for floating popup panels.
  final double popupElevation;

  /// Builds a text style consistent with the resolved theme.
  TextStyle text(double fontSize, {FontWeight? fontWeight, Color? color}) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? foreground,
      fontFamily: fontFamily,
    );
  }

  /// Resolves the static levels of the styling cascade for one column over
  /// the grid's base [theme] (see [OsGridTheme] for the full chain).
  ///
  /// Precedence within this method, lowest to highest:
  /// base theme → column type theme → per-column overrides. The column
  /// type theme arrives merged into `colDef.theme` by `ColumnDefResolver`
  /// (explicit colDef > types > `defaultColDef`), so it only needs to be
  /// layered over the base here.
  ///
  /// The dynamic levels — row style and the per-cell `cellStyle` callback —
  /// need per-cell context and are applied by the painter via
  /// [ResolvedColumnTheme.compose].
  static ResolvedColumnTheme forColumn(
    OsColumnDef<dynamic> colDef,
    OsGridTheme? theme,
  ) {
    final baseStyle =
        theme?.cellTextStyle ??
        const TextStyle(fontSize: 13, color: Color(0xFF424242));
    final override = colDef.theme;
    if (override == null) {
      return ResolvedColumnTheme._(baseStyle);
    }
    var style = override.cellTextStyle ?? baseStyle;
    if (override.cellTextColor != null) {
      style = style.copyWith(color: override.cellTextColor);
    }
    if (override.cellFontSize != null) {
      style = style.copyWith(fontSize: override.cellFontSize);
    }
    return ResolvedColumnTheme._(style);
  }
}

/// Per-column result of the grid's styling cascade (quality program v3
/// item 25).
///
/// [ResolvedGridTheme.forColumn] collapses the cascade's static levels —
/// base theme → column type theme → per-column overrides — into the single
/// [cellTextStyle] that body cells paint with when no row/cell-level
/// override applies. The dynamic levels are composed per cell via [compose].
class ResolvedColumnTheme {
  const ResolvedColumnTheme._(this.cellTextStyle);

  /// The column-resolved default cell text style.
  ///
  /// Identity-stable across paint passes whenever no override or a single
  /// explicit [OsGridTheme.cellTextStyle] produces it, so the painter's
  /// identity-keyed text layout cache stays warm.
  final TextStyle cellTextStyle;

  /// Composes the final paint style for one cell.
  ///
  /// Precedence, lowest to highest: the column-resolved cascade style →
  /// [rowStyle] ([OsGrid.getRowStyle] / [OsGrid.rowStyle]) → [cellStyle]
  /// (the column's per-cell callback). Row styles override the column-level
  /// theme; an individual cell style still wins over the row style.
  TextStyle compose({OsCellStyle? cellStyle, OsRowStyle? rowStyle}) {
    return cellTextStyle.copyWith(
      color: cellStyle?.color ?? rowStyle?.foregroundColor,
      fontWeight: cellStyle?.fontWeight ?? rowStyle?.fontWeight,
      fontStyle: cellStyle?.fontStyle ?? rowStyle?.fontStyle,
    );
  }
}
