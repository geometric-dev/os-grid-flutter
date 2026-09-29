import 'package:flutter/material.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart' show OsColumnDef, OsGrid;

/// Theme data for the Row Grouping Panel ("Drop Zone").
class RowGroupPanelThemeData {
  const RowGroupPanelThemeData({
    this.height = 40.0,
    this.backgroundColor,
    this.chipDecoration,
    this.chipTextStyle,
    this.placeholderBorder,
    this.placeholderTextStyle,
    this.dragIndicatorColor,
  });

  /// Height of the panel. Defaults to 40.0.
  final double height;

  /// Background color. If null, falls back to the grid's chrome background.
  final Color? backgroundColor;

  /// Custom decoration for the group chips.
  final BoxDecoration? chipDecoration;

  /// Custom text style for the group chips.
  final TextStyle? chipTextStyle;

  /// Custom decoration for the placeholder (when no columns are grouped).
  final BoxDecoration? placeholderBorder;

  /// Custom text style for the placeholder text.
  final TextStyle? placeholderTextStyle;

  /// Color for the drag insertion indicator.
  final Color? dragIndicatorColor;
}

/// Visual theme configuration for the grid.
///
/// Mirrors OS Grid's theming parameter system. Use the named constructors
/// for preset themes that match OS Grid's built-in themes:
///
/// ```dart
/// theme: OsGridTheme.quartz()          // Light Quartz theme
/// theme: OsGridTheme.quartzDark()      // Dark Quartz theme
/// theme: OsGridTheme.fromThemeData(Theme.of(context))  // From Flutter theme
/// ```
///
/// ## Styling cascade (precedence chain)
///
/// Cell styling resolves through an explicit precedence chain, lowest to
/// highest:
///
/// 1. **Base theme** — this object (a preset like [OsGridTheme.quartz], or
///    a custom instance). Resolved once by `ResolvedGridTheme` for chrome
///    surfaces, and per column by `ResolvedGridTheme.forColumn` for cell
///    painting.
/// 2. **Column type theme** — the [OsColumnDef.theme] carried by an
///    `OsGrid.columnTypes` entry overrides the base theme for every column
///    referencing that type.
/// 3. **Per-column overrides** — a column's own [OsColumnDef.theme] (static,
///    merged by `ColumnDefResolver` with precedence explicit colDef > types
///    > `defaultColDef`) and its `OsColumnDef.cellStyle` callback (per cell).
/// 4. **Row style** — `OsGrid.getRowStyle` / `OsGrid.rowStyle` apply
///    row-wide, overriding the column-level theme defaults.
///
/// The per-cell `cellStyle` callback remains the final word: an individual
/// cell style wins over the row style, which wins over the column/theme
/// defaults. Tokens omitted at a higher level fall through to the level
/// below, so a column type can override just one token (for example
/// [cellTextColor]) and inherit the rest of the base theme. Cells with no
/// override at any level paint exactly as the base theme dictates.
class OsGridTheme {
  const OsGridTheme({
    this.backgroundColor,
    this.foregroundColor,
    this.accentColor,
    this.borderColor,
    this.chromeBackgroundColor,
    this.headerBackgroundColor,
    this.headerTextColor,
    this.headerTextStyle,
    this.headerFontWeight,
    this.cellTextColor,
    this.cellTextStyle,
    this.cellFontSize,
    this.rowHeight,
    this.headerHeight,
    this.rowGroupPanelTheme,
    this.selectedRowColor,
    this.hoverRowColor,
    this.alternateRowColor,
    this.gridBorderRadius,
    this.spacing,
    this.pinnedColumnBorderColor,
    this.pinnedColumnBorderWidth,
    this.rowBorderColor,
    this.columnBorderColor,
    this.wrapperBorderColor,
    this.valueChangeDeltaUpColor,
    this.valueChangeDeltaDownColor,
    this.valueChangeValueHighlightBackgroundColor,
    this.cellFlashColor,
    this.columnHoverColor,
    this.popupBlurSigma = 0,
  });

  // ===== Preset Themes (mirroring OS Grid's built-in themes) =====

  /// Quartz Light theme — the default OS Grid theme.
  /// Uses IBM Plex Sans font, blue accent, light background.
  factory OsGridTheme.quartz() {
    const bg = Color(0xFFFFFFFF);
    const fg = Color(0xFF181D1F);
    const accent = Color(0xFF2196F3);
    const chrome = Color(0xFFF8F8F8); // foregroundBackgroundMix(0.02)
    const border = Color(0xFFE2E2E2); // foregroundMix(0.15)

    return OsGridTheme(
      backgroundColor: bg,
      foregroundColor: fg,
      accentColor: accent,
      borderColor: border,
      chromeBackgroundColor: chrome,
      headerBackgroundColor: chrome,
      headerTextColor: fg,
      headerTextStyle: const TextStyle(
        fontFamily: 'IBM Plex Sans',
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Color(0xFF181D1F),
      ),
      headerFontWeight: FontWeight.w600,
      cellTextColor: fg,
      cellTextStyle: const TextStyle(
        fontFamily: 'IBM Plex Sans',
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: Color(0xFF181D1F),
      ),
      cellFontSize: 14,
      rowHeight: 42,
      headerHeight: 48,
      selectedRowColor: Color.lerp(bg, accent, 0.12)!,
      hoverRowColor: Color.lerp(bg, accent, 0.08)!,
      alternateRowColor: null, // Quartz doesn't stripe by default
      gridBorderRadius: BorderRadius.circular(8),
      spacing: 8,
      pinnedColumnBorderColor: border,
      pinnedColumnBorderWidth: 1,
      rowBorderColor: border,
      columnBorderColor: Colors.transparent,
      wrapperBorderColor: border,
      valueChangeDeltaUpColor: const Color(0xFF43A047),
      valueChangeDeltaDownColor: const Color(0xFFE53935),
      valueChangeValueHighlightBackgroundColor: const Color(0x6144AD49),
    );
  }

  /// Quartz Dark theme — dark variant of the default OS Grid theme.
  factory OsGridTheme.quartzDark() {
    const bg = Color(0xFF1F2836);
    const fg = Color(0xFFFFFFFF);
    const accent = Color(0xFF2196F3);
    const chrome = Color(0xFF222B3A); // slightly lighter than bg
    const border = Color(0xFF3D4A5C); // foregroundMix(0.15) on dark

    return OsGridTheme(
      backgroundColor: bg,
      foregroundColor: fg,
      accentColor: accent,
      borderColor: border,
      chromeBackgroundColor: chrome,
      headerBackgroundColor: chrome,
      headerTextColor: const Color(0xFFBAC4CF),
      headerTextStyle: const TextStyle(
        fontFamily: 'IBM Plex Sans',
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Color(0xFFBAC4CF),
      ),
      headerFontWeight: FontWeight.w600,
      cellTextColor: fg,
      cellTextStyle: const TextStyle(
        fontFamily: 'IBM Plex Sans',
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: Color(0xFFFFFFFF),
      ),
      cellFontSize: 14,
      rowHeight: 42,
      headerHeight: 48,
      selectedRowColor: Color.lerp(bg, accent, 0.15)!,
      hoverRowColor: Color.lerp(bg, accent, 0.08)!,
      alternateRowColor: null,
      gridBorderRadius: BorderRadius.circular(8),
      spacing: 8,
      pinnedColumnBorderColor: border,
      pinnedColumnBorderWidth: 1,
      rowBorderColor: border,
      columnBorderColor: Colors.transparent,
      wrapperBorderColor: border,
      valueChangeDeltaUpColor: const Color(0xFF43A047),
      valueChangeDeltaDownColor: const Color(0xFFE53935),
      valueChangeValueHighlightBackgroundColor: const Color(0x6144AD49),
    );
  }

  /// Alpine Light theme — a clean, modern theme with rounded styling.
  factory OsGridTheme.alpine() {
    const bg = Color(0xFFFFFFFF);
    const fg = Color(0xFF181D1F);
    const accent = Color(0xFF2196F3);
    const chrome = Color(0xFFF5F7F7);
    const border = Color(0xFFDDE2EB);

    return OsGridTheme(
      backgroundColor: bg,
      foregroundColor: fg,
      accentColor: accent,
      borderColor: border,
      chromeBackgroundColor: chrome,
      headerBackgroundColor: chrome,
      headerTextColor: const Color(0xFF3B4045),
      headerTextStyle: const TextStyle(
        fontFamily: 'Segoe UI',
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: Color(0xFF3B4045),
      ),
      headerFontWeight: FontWeight.w700,
      cellTextColor: fg,
      cellTextStyle: const TextStyle(
        fontFamily: 'Segoe UI',
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: Color(0xFF181D1F),
      ),
      cellFontSize: 13,
      rowHeight: 42,
      headerHeight: 48,
      selectedRowColor: const Color(0xFFE8F0FE),
      hoverRowColor: const Color(0xFFF1F5F9),
      alternateRowColor: null,
      gridBorderRadius: BorderRadius.circular(4),
      spacing: 6,
      pinnedColumnBorderColor: border,
      pinnedColumnBorderWidth: 1,
      rowBorderColor: border,
      columnBorderColor: Colors.transparent,
      wrapperBorderColor: border,
      valueChangeDeltaUpColor: const Color(0xFF43A047),
      valueChangeDeltaDownColor: const Color(0xFFE53935),
      valueChangeValueHighlightBackgroundColor: const Color(0x6144AD49),
    );
  }

  /// Alpine Dark theme — dark variant of the Alpine theme.
  factory OsGridTheme.alpineDark() {
    const bg = Color(0xFF222628);
    const fg = Color(0xFFFFFFFF);
    const accent = Color(0xFF2196F3);
    const chrome = Color(0xFF2D3436);
    const border = Color(0xFF424A4E);

    return OsGridTheme(
      backgroundColor: bg,
      foregroundColor: fg,
      accentColor: accent,
      borderColor: border,
      chromeBackgroundColor: chrome,
      headerBackgroundColor: chrome,
      headerTextColor: const Color(0xFFBDC3C7),
      headerTextStyle: const TextStyle(
        fontFamily: 'Segoe UI',
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: Color(0xFFBDC3C7),
      ),
      headerFontWeight: FontWeight.w700,
      cellTextColor: fg,
      cellTextStyle: const TextStyle(
        fontFamily: 'Segoe UI',
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: Color(0xFFFFFFFF),
      ),
      cellFontSize: 13,
      rowHeight: 42,
      headerHeight: 48,
      selectedRowColor: Color.lerp(bg, accent, 0.15)!,
      hoverRowColor: Color.lerp(bg, accent, 0.08)!,
      alternateRowColor: null,
      gridBorderRadius: BorderRadius.circular(4),
      spacing: 6,
      pinnedColumnBorderColor: border,
      pinnedColumnBorderWidth: 1,
      rowBorderColor: border,
      columnBorderColor: Colors.transparent,
      wrapperBorderColor: border,
      valueChangeDeltaUpColor: const Color(0xFF43A047),
      valueChangeDeltaDownColor: const Color(0xFFE53935),
      valueChangeValueHighlightBackgroundColor: const Color(0x6144AD49),
    );
  }

  /// Balham Light theme — a compact, professional theme with visible column borders.
  factory OsGridTheme.balham() {
    const bg = Color(0xFFFFFFFF);
    const fg = Color(0xFF000000);
    const accent = Color(0xFF0091EA);
    const chrome = Color(0xFFF5F7F7);
    const border = Color(0xFFBDC3C7);

    return const OsGridTheme(
      backgroundColor: bg,
      foregroundColor: fg,
      accentColor: accent,
      borderColor: border,
      chromeBackgroundColor: chrome,
      headerBackgroundColor: chrome,
      headerTextColor: Color(0xFF464646),
      headerTextStyle: TextStyle(
        fontFamily: 'Segoe UI',
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Color(0xFF464646),
      ),
      headerFontWeight: FontWeight.w600,
      cellTextColor: fg,
      cellTextStyle: TextStyle(
        fontFamily: 'Segoe UI',
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: Color(0xFF000000),
      ),
      cellFontSize: 12,
      rowHeight: 28,
      headerHeight: 32,
      selectedRowColor: Color(0xFFB7E4FF),
      hoverRowColor: Color(0xFFF0F0F0),
      alternateRowColor: Color(0xFFFCFDFE),
      gridBorderRadius: BorderRadius.zero,
      spacing: 4,
      pinnedColumnBorderColor: border,
      pinnedColumnBorderWidth: 1,
      rowBorderColor: Color(0xFFD9DCDE),
      columnBorderColor: Color(0xFFD9DCDE),
      wrapperBorderColor: border,
      valueChangeDeltaUpColor: Color(0xFF43A047),
      valueChangeDeltaDownColor: Color(0xFFE53935),
      valueChangeValueHighlightBackgroundColor: Color(0x6144AD49),
    );
  }

  /// Balham Dark theme — dark variant of the compact Balham theme.
  factory OsGridTheme.balhamDark() {
    const bg = Color(0xFF2D3436);
    const fg = Color(0xFFFFFFFF);
    const accent = Color(0xFF0091EA);
    const chrome = Color(0xFF3D4749);
    const border = Color(0xFF5C6970);

    return OsGridTheme(
      backgroundColor: bg,
      foregroundColor: fg,
      accentColor: accent,
      borderColor: border,
      chromeBackgroundColor: chrome,
      headerBackgroundColor: chrome,
      headerTextColor: const Color(0xFFD4D8DA),
      headerTextStyle: const TextStyle(
        fontFamily: 'Segoe UI',
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Color(0xFFD4D8DA),
      ),
      headerFontWeight: FontWeight.w600,
      cellTextColor: fg,
      cellTextStyle: const TextStyle(
        fontFamily: 'Segoe UI',
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: Color(0xFFFFFFFF),
      ),
      cellFontSize: 12,
      rowHeight: 28,
      headerHeight: 32,
      selectedRowColor: const Color(0xFF005880),
      hoverRowColor: Color.lerp(bg, fg, 0.05)!,
      alternateRowColor: const Color(0xFF323C3E),
      gridBorderRadius: BorderRadius.zero,
      spacing: 4,
      pinnedColumnBorderColor: border,
      pinnedColumnBorderWidth: 1,
      rowBorderColor: const Color(0xFF4A5456),
      columnBorderColor: const Color(0xFF4A5456),
      wrapperBorderColor: border,
      valueChangeDeltaUpColor: const Color(0xFF43A047),
      valueChangeDeltaDownColor: const Color(0xFFE53935),
      valueChangeValueHighlightBackgroundColor: const Color(0x6144AD49),
    );
  }

  /// High Contrast theme — designed for accessibility.
  ///
  /// Uses maximum contrast colours (pure black on white), bold 2px borders,
  /// and no transparency. Meets WCAG 2.1 Level AA minimum contrast ratio
  /// of 4.5:1 for all text (achieves 21:1 with pure black/white).
  ///
  /// Use this theme when the platform reports high contrast mode, or when
  /// users need increased visual distinction between UI elements.
  ///
  /// Note: Full WCAG compliance validation requires manual testing with
  /// assistive technologies and expert accessibility review.
  factory OsGridTheme.highContrast() {
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

  /// Creates a theme derived from Flutter's [ThemeData].
  ///
  /// Maps Material Design tokens to grid styling, producing a result
  /// similar to Quartz but using the app's color scheme.
  factory OsGridTheme.fromThemeData(ThemeData themeData) {
    final colorScheme = themeData.colorScheme;
    final isDark = themeData.brightness == Brightness.dark;

    final bg = colorScheme.surface;
    final fg = colorScheme.onSurface;
    final accent = colorScheme.primary;
    final border = themeData.dividerColor;
    final chrome = isDark
        ? Color.lerp(bg, fg, 0.03)!
        : Color.lerp(bg, fg, 0.02)!;

    return OsGridTheme(
      backgroundColor: bg,
      foregroundColor: fg,
      accentColor: accent,
      borderColor: border,
      chromeBackgroundColor: chrome,
      headerBackgroundColor: chrome,
      headerTextColor: isDark
          ? Color.lerp(fg, bg, 0.3)
          : Color.lerp(fg, bg, 0.1),
      headerTextStyle: themeData.textTheme.labelMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      headerFontWeight: FontWeight.w600,
      cellTextColor: fg,
      cellTextStyle: themeData.textTheme.bodyMedium,
      cellFontSize: 14,
      rowHeight: 42,
      headerHeight: 48,
      selectedRowColor: Color.lerp(bg, accent, 0.12),
      hoverRowColor: Color.lerp(bg, accent, 0.08),
      alternateRowColor: null,
      gridBorderRadius: BorderRadius.circular(8),
      spacing: 8,
      pinnedColumnBorderColor: border,
      pinnedColumnBorderWidth: 1,
      rowBorderColor: border,
      columnBorderColor: Colors.transparent,
      wrapperBorderColor: border,
    );
  }

  // ===== Core Parameters =====

  /// Background color of the grid body (data area).
  final Color? backgroundColor;

  /// Default foreground/text color.
  final Color? foregroundColor;

  /// Brand/accent color used for selections, focus, checkboxes.
  final Color? accentColor;

  /// Default border color.
  final Color? borderColor;

  /// Background for non-data areas (headers, tool panels).
  final Color? chromeBackgroundColor;

  /// Background colour for column headers.
  final Color? headerBackgroundColor;

  /// Text color for column headers.
  final Color? headerTextColor;

  /// Text style for column header labels.
  final TextStyle? headerTextStyle;

  /// Font weight for header text.
  final FontWeight? headerFontWeight;

  /// Text color for cell content.
  final Color? cellTextColor;

  /// Default text style for cell content.
  final TextStyle? cellTextStyle;

  /// Font size for cell text.
  final double? cellFontSize;

  /// Height of data rows in logical pixels.
  final double? rowHeight;

  /// Height of the header row in logical pixels.
  final double? headerHeight;

  /// Theming for the row grouping panel.
  final RowGroupPanelThemeData? rowGroupPanelTheme;

  /// Background colour of selected rows.
  final Color? selectedRowColor;

  /// Background colour of rows on hover.
  final Color? hoverRowColor;

  /// Background colour for alternating rows (striped effect).
  final Color? alternateRowColor;

  /// Border radius for the grid container.
  final BorderRadius? gridBorderRadius;

  /// Base spacing unit (all padding/margins are multiples of this).
  final double? spacing;

  /// Border color for pinned column dividers.
  final Color? pinnedColumnBorderColor;

  /// Border width for pinned column dividers.
  final double? pinnedColumnBorderWidth;

  /// Color of horizontal row borders.
  final Color? rowBorderColor;

  /// Color of vertical column borders (transparent by default in Quartz).
  final Color? columnBorderColor;

  /// Color of the outer grid border.
  final Color? wrapperBorderColor;

  /// Color for positive value changes (green by default).
  /// Mirrors OS Grid's `valueChangeDeltaUpColor` theme param.
  final Color? valueChangeDeltaUpColor;

  /// Color for negative value changes (red by default).
  /// Mirrors OS Grid's `valueChangeDeltaDownColor` theme param.
  final Color? valueChangeDeltaDownColor;

  /// Background color for the value highlight pill when a cell value changes.
  /// Mirrors OS Grid's `valueChangeValueHighlightBackgroundColor` theme param.
  final Color? valueChangeValueHighlightBackgroundColor;

  /// Colour used for the cell flash highlight overlay.
  ///
  /// Defaults to green (0xFF4CAF50) when not specified. The flash is painted
  /// at 30% of this colour's opacity, fading to transparent over the
  /// configured duration.
  final Color? cellFlashColor;

  /// Background colour for the hovered column highlight.
  ///
  /// When [OsGrid.columnHoverHighlight] is enabled, the entire column under
  /// the pointer is painted with this colour. Defaults to a subtle mix of
  /// the accent colour at 5% opacity.
  final Color? columnHoverColor;

  /// Gaussian blur sigma applied behind popup surfaces (context menu,
  /// column menu, tabbed menu, filter popups, date picker).
  ///
  /// Defaults to 0 — no blur, popups render exactly as before. Values above
  /// zero install a full-screen [BackdropFilter] beneath popup content while
  /// a popup is open, blurring whatever renders behind it. Blur costs a
  /// saveLayer per frame for the popup's lifetime; keep sigma modest.
  final double popupBlurSigma;
}
