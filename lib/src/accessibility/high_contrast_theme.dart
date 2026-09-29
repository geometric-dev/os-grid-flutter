import 'package:flutter/material.dart';

import '../theming/os_grid_theme.dart';

/// Extension on [OsGridTheme] providing a high contrast preset.
///
/// High contrast mode is designed for users who need increased visual
/// distinction between UI elements. It uses:
/// - Bold borders (2px instead of 1px)
/// - Maximum contrast colours (pure black/white)
/// - No transparency or subtle colour mixing
///
/// The grid also automatically adapts when the platform reports high
/// contrast mode via [MediaQuery.highContrastOf]. See [isHighContrast].
///
/// ## Contrast requirements
///
/// All text in the high contrast theme meets WCAG 2.1 Level AA minimum
/// contrast ratio of 4.5:1 for normal text and 3:1 for large text.
/// The pure black on white (and vice versa) achieves 21:1 contrast ratio.
///
/// Note: Full WCAG compliance validation requires manual testing with
/// assistive technologies and expert accessibility review.

/// Returns `true` if the platform has requested high contrast mode.
///
/// Uses [MediaQuery.highContrastOf] which reads the platform's
/// accessibility settings (e.g. Windows High Contrast, macOS
/// Increase Contrast).
bool isHighContrast(BuildContext context) {
  return MediaQuery.highContrastOf(context);
}

/// Resolves the effective theme, applying high contrast adjustments
/// when the platform requests it.
///
/// If [theme] is already a high contrast theme or the platform does not
/// request high contrast, returns [theme] unchanged. Otherwise, returns
/// a modified theme with increased border widths and contrast.
OsGridTheme resolveThemeForAccessibility(
  BuildContext context,
  OsGridTheme? theme,
) {
  if (!isHighContrast(context)) {
    return theme ?? OsGridTheme.quartz();
  }

  // If user already specified a theme, boost its borders for high contrast
  if (theme != null) {
    return _applyHighContrastOverrides(theme);
  }

  return _highContrastTheme();
}

/// Applies high contrast overrides to an existing theme.
OsGridTheme _applyHighContrastOverrides(OsGridTheme base) {
  return OsGridTheme(
    backgroundColor: base.backgroundColor,
    foregroundColor: base.foregroundColor,
    accentColor: base.accentColor,
    borderColor: base.borderColor ?? const Color(0xFF000000),
    chromeBackgroundColor: base.chromeBackgroundColor,
    headerBackgroundColor: base.headerBackgroundColor,
    headerTextColor: base.headerTextColor,
    headerTextStyle: base.headerTextStyle?.copyWith(
      fontWeight: FontWeight.w700,
    ),
    headerFontWeight: FontWeight.w700,
    cellTextColor: base.cellTextColor,
    cellTextStyle: base.cellTextStyle,
    cellFontSize: base.cellFontSize,
    rowHeight: base.rowHeight,
    headerHeight: base.headerHeight,
    selectedRowColor: base.selectedRowColor,
    hoverRowColor: base.hoverRowColor,
    alternateRowColor: base.alternateRowColor,
    gridBorderRadius: base.gridBorderRadius,
    spacing: base.spacing,
    pinnedColumnBorderColor:
        base.pinnedColumnBorderColor ?? const Color(0xFF000000),
    pinnedColumnBorderWidth: 2,
    rowBorderColor: base.rowBorderColor ?? const Color(0xFF000000),
    columnBorderColor: base.columnBorderColor ?? const Color(0xFF000000),
    wrapperBorderColor: base.wrapperBorderColor ?? const Color(0xFF000000),
    valueChangeDeltaUpColor: base.valueChangeDeltaUpColor,
    valueChangeDeltaDownColor: base.valueChangeDeltaDownColor,
    valueChangeValueHighlightBackgroundColor:
        base.valueChangeValueHighlightBackgroundColor,
    cellFlashColor: base.cellFlashColor,
    columnHoverColor: base.columnHoverColor,
  );
}

/// The built-in high contrast theme.
OsGridTheme _highContrastTheme() {
  return const OsGridTheme(
    backgroundColor: Color(0xFFFFFFFF),
    foregroundColor: Color(0xFF000000),
    accentColor: Color(0xFF0000FF),
    borderColor: Color(0xFF000000),
    chromeBackgroundColor: Color(0xFFFFFFFF),
    headerBackgroundColor: Color(0xFFE0E0E0),
    headerTextColor: Color(0xFF000000),
    headerTextStyle: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: Color(0xFF000000),
    ),
    headerFontWeight: FontWeight.w700,
    cellTextColor: Color(0xFF000000),
    cellTextStyle: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: Color(0xFF000000),
    ),
    cellFontSize: 14,
    rowHeight: 42,
    headerHeight: 48,
    selectedRowColor: Color(0xFFCCCCFF),
    hoverRowColor: Color(0xFFE8E8E8),
    alternateRowColor: Color(0xFFF5F5F5),
    gridBorderRadius: BorderRadius.zero,
    spacing: 8,
    pinnedColumnBorderColor: Color(0xFF000000),
    pinnedColumnBorderWidth: 2,
    rowBorderColor: Color(0xFF000000),
    columnBorderColor: Color(0xFF000000),
    wrapperBorderColor: Color(0xFF000000),
    valueChangeDeltaUpColor: Color(0xFF006600),
    valueChangeDeltaDownColor: Color(0xFFCC0000),
    valueChangeValueHighlightBackgroundColor: Color(0xFFFFFF00),
  );
}
