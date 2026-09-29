import 'package:os_grid_flutter/os_grid_flutter.dart';
import 'package:flutter/material.dart';

import '../../theme_selector.dart';
import '../sample_data.dart';
import '../widgets/feature_panel.dart';

/// Demonstrates theming capabilities of the grid.
///
/// Shows all built-in theme presets, customisation of row height, header height,
/// and accent colour, plus value-dependent cell background styling.
class ThemingPage extends StatefulWidget {
  const ThemingPage({
    super.key,
    required this.themePreset,
    this.onThemeChanged,
  });

  final GridThemePreset themePreset;
  final ValueChanged<GridThemePreset>? onThemeChanged;

  @override
  State<ThemingPage> createState() => _ThemingPageState();
}

class _ThemingPageState extends State<ThemingPage> {
  final _controller = OsGridController<Map<String, dynamic>>();
  late final List<Map<String, dynamic>> _rowData;

  late double _rowHeight;
  late double _headerHeight;
  late Color _accentColor;

  static const _accentSwatches = <Color>[
    Color(0xFF2196F3), // Blue (default)
    Color(0xFF4CAF50), // Green
    Color(0xFFF44336), // Red
    Color(0xFF9C27B0), // Purple
    Color(0xFFFF9800), // Orange
    Color(0xFF009688), // Teal
    Color(0xFF795548), // Brown
    Color(0xFF607D8B), // Blue Grey
  ];

  @override
  void initState() {
    super.initState();
    _rowData = generateSampleData(rowCount: 25);
    _syncFromPreset();
  }

  @override
  void didUpdateWidget(covariant ThemingPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.themePreset != widget.themePreset) {
      _syncFromPreset();
    }
  }

  /// Syncs row height, header height, and accent colour from the current preset.
  void _syncFromPreset() {
    final theme = getThemeForPreset(widget.themePreset);
    _rowHeight = theme.rowHeight ?? 42;
    _headerHeight = theme.headerHeight ?? 48;
    _accentColor = theme.accentColor ?? const Color(0xFF2196F3);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = getThemeForPreset(widget.themePreset, context);
    final theme = _applyCustomisation(baseTheme);

    return Column(
      children: [
        FeaturePanel(
          title: 'Theme Controls',
          children: [
            // Theme preset selector
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Preset: '),
                const SizedBox(width: 8),
                DropdownButton<GridThemePreset>(
                  value: widget.themePreset,
                  underline: const SizedBox.shrink(),
                  items: GridThemePreset.values.map((preset) {
                    return DropdownMenuItem(
                      value: preset,
                      child: Text(
                        preset.label,
                        style: const TextStyle(fontSize: 13),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) widget.onThemeChanged?.call(value);
                  },
                ),
              ],
            ),
            // Row height slider
            SizedBox(
              width: 220,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Row Height: '),
                  Expanded(
                    child: Slider(
                      value: _rowHeight,
                      min: 20,
                      max: 100,
                      divisions: 80,
                      label: _rowHeight.round().toString(),
                      onChanged: (v) => setState(() => _rowHeight = v),
                    ),
                  ),
                  SizedBox(
                    width: 30,
                    child: Text(
                      _rowHeight.round().toString(),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            // Header height slider
            SizedBox(
              width: 240,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Header Height: '),
                  Expanded(
                    child: Slider(
                      value: _headerHeight,
                      min: 24,
                      max: 100,
                      divisions: 76,
                      label: _headerHeight.round().toString(),
                      onChanged: (v) => setState(() => _headerHeight = v),
                    ),
                  ),
                  SizedBox(
                    width: 30,
                    child: Text(
                      _headerHeight.round().toString(),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            // Accent colour swatches
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Accent: '),
                const SizedBox(width: 8),
                ..._accentSwatches.map((color) {
                  final isSelected = _accentColor == color;
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: GestureDetector(
                      onTap: () => setState(() => _accentColor = color),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? Theme.of(context).colorScheme.onSurface
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: isSelected
                            ? Icon(
                                Icons.check,
                                size: 16,
                                color: _contrastColor(color),
                              )
                            : null,
                      ),
                    ),
                  );
                }),
              ],
            ),
          ],
        ),
        Expanded(
          child: OsGrid<Map<String, dynamic>>(
            controller: _controller,
            theme: theme,
            rowData: _rowData,
            columnDefs: _buildColumnDefs(),
          ),
        ),
      ],
    );
  }

  /// Applies user customisation (row height, header height, accent colour)
  /// on top of the base theme.
  OsGridTheme _applyCustomisation(OsGridTheme base) {
    return OsGridTheme(
      backgroundColor: base.backgroundColor,
      foregroundColor: base.foregroundColor,
      accentColor: _accentColor,
      borderColor: base.borderColor,
      chromeBackgroundColor: base.chromeBackgroundColor,
      headerBackgroundColor: base.headerBackgroundColor,
      headerTextColor: base.headerTextColor,
      headerTextStyle: base.headerTextStyle,
      headerFontWeight: base.headerFontWeight,
      cellTextColor: base.cellTextColor,
      cellTextStyle: base.cellTextStyle,
      cellFontSize: base.cellFontSize,
      rowHeight: _rowHeight,
      headerHeight: _headerHeight,
      selectedRowColor: base.selectedRowColor,
      hoverRowColor: base.hoverRowColor,
      alternateRowColor: base.alternateRowColor,
      gridBorderRadius: base.gridBorderRadius,
      spacing: base.spacing,
      pinnedColumnBorderColor: base.pinnedColumnBorderColor,
      pinnedColumnBorderWidth: base.pinnedColumnBorderWidth,
      rowBorderColor: base.rowBorderColor,
      columnBorderColor: base.columnBorderColor,
      wrapperBorderColor: base.wrapperBorderColor,
      valueChangeDeltaUpColor: base.valueChangeDeltaUpColor,
      valueChangeDeltaDownColor: base.valueChangeDeltaDownColor,
      valueChangeValueHighlightBackgroundColor:
          base.valueChangeValueHighlightBackgroundColor,
      cellFlashColor: base.cellFlashColor,
      columnHoverColor: base.columnHoverColor,
    );
  }

  List<OsColumnDef<Map<String, dynamic>>> _buildColumnDefs() {
    return [
      OsColumnDef<Map<String, dynamic>>(
        field: 'name',
        headerName: 'Name',
        flex: 2,
      ),
      OsColumnDef<Map<String, dynamic>>(
        field: 'department',
        headerName: 'Department',
        width: 130,
      ),
      OsColumnDef<Map<String, dynamic>>(
        field: 'age',
        headerName: 'Age',
        width: 80,
      ),
      OsColumnDef<Map<String, dynamic>>(
        field: 'salary',
        headerName: 'Salary',
        width: 120,
        cellStyle: _salaryCellStyle,
      ),
      OsColumnDef<Map<String, dynamic>>(
        field: 'rating',
        headerName: 'Rating',
        width: 90,
      ),
      OsColumnDef<Map<String, dynamic>>(
        field: 'country',
        headerName: 'Country',
        flex: 1,
      ),
    ];
  }

  /// Value-dependent cell background styling for the salary column.
  ///
  /// Salaries above 90000 get a green-tinted background (positive),
  /// salaries below 50000 get a red-tinted background (negative/low).
  OsCellStyle _salaryCellStyle(
    CellRendererParams<Map<String, dynamic>> params,
  ) {
    final salary = params.value as int? ?? 0;
    if (salary > 90000) {
      return const OsCellStyle(
        backgroundColor: Color(0x2043A047),
        color: Color(0xFF2E7D32),
      );
    } else if (salary < 50000) {
      return const OsCellStyle(
        backgroundColor: Color(0x20E53935),
        color: Color(0xFFC62828),
      );
    }
    return const OsCellStyle();
  }

  /// Returns a contrasting colour (black or white) for the given background.
  Color _contrastColor(Color background) {
    final luminance = background.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }
}
