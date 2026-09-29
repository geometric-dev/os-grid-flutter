import 'package:flutter/material.dart';

import '../aggregation/aggregation_service.dart';
import '../columns/os_column_def.dart';
import '../params/value_formatter_params.dart';
import '../params/value_getter_params.dart';
import '../theming/os_grid_theme.dart';
import '../utils/grid_diagnostics.dart';

/// Alignment of a status panel within the status bar.
enum OsStatusPanelAlign { left, right }

/// Definition of a single aggregation panel in the grid status bar.
///
/// Mirrors OS Grid's status bar panel definitions: each panel computes a
/// built-in aggregate over the currently visible page rows for one column
/// and renders it as a compact chip (label + formatted value).
///
/// ```dart
/// const OsStatusPanelDef(
///   aggregationFunc: 'sum',
///   valueColId: 'price',
/// )
/// ```
class OsStatusPanelDef {
  /// Creates a status panel definition.
  ///
  /// [aggregationFunc] is the name of a built-in aggregation function:
  /// `'sum'`, `'avg'`, `'min'`, `'max'` or `'count'`.
  ///
  /// [valueColId] is the colId (or field) of the column to aggregate.
  /// When null, the panel renders its label with an empty value.
  ///
  /// [label] overrides the localized default label for the function.
  ///
  /// [align] positions the panel within the status bar; defaults to left.
  const OsStatusPanelDef({
    required this.aggregationFunc,
    this.valueColId,
    this.label,
    this.align = OsStatusPanelAlign.left,
  });

  /// Name of the built-in aggregation function to compute.
  ///
  /// One of `'sum'`, `'avg'`, `'min'`, `'max'` or `'count'`. Unknown names
  /// render an empty value rather than throwing.
  final String aggregationFunc;

  /// The colId (or field name) of the column whose values are aggregated.
  final String? valueColId;

  /// Optional label override for the panel.
  ///
  /// When null, a localized default label is derived from the function name
  /// (e.g. `summed` → "Sum").
  final String? label;

  /// Which side of the status bar the panel is rendered on.
  final OsStatusPanelAlign align;
}

/// Configuration for the rich status bar with aggregation panels.
///
/// Passed via the grid's `statusBarConfig` parameter. Takes precedence over
/// the legacy `statusBar` boolean when both are provided.
///
/// ```dart
/// OsGrid(
///   statusBarConfig: const OsStatusBarConfig(
///     statusPanels: [
///       OsStatusPanelDef(aggregationFunc: 'sum', valueColId: 'price'),
///       OsStatusPanelDef(
///         aggregationFunc: 'max',
///         valueColId: 'price',
///         align: OsStatusPanelAlign.right,
///       ),
///     ],
///   ),
///   ...
/// )
/// ```
class OsStatusBarConfig {
  /// Creates a status bar configuration.
  const OsStatusBarConfig({this.statusPanels = const []});

  /// The panels rendered in the status bar, in order.
  final List<OsStatusPanelDef> statusPanels;
}

/// Status bar row that renders aggregation panels as compact chips.
///
/// Values are recomputed on every build from the given page rows so panels
/// stay in sync with filter/sort/pagination reprocessing without any extra
/// controllers.
class OsStatusBarPanelRow extends StatelessWidget {
  /// Creates a status bar row from the given configuration.
  const OsStatusBarPanelRow({
    super.key,
    required this.config,
    required this.pageRows,
    required this.columns,
    required this.resolveLocaleText,
    this.gridTheme,
  });

  /// The status bar configuration with the panels to render.
  final OsStatusBarConfig config;

  /// The currently visible page rows (post filter/sort/page).
  final List<Map<String, dynamic>> pageRows;

  /// The grid's flat columns used to resolve [OsStatusPanelDef.valueColId].
  final List<OsColumnDef> columns;

  /// Resolves a locale key to its translated value.
  final String Function(String key, String defaultValue) resolveLocaleText;

  /// The active grid theme providing chrome/border/text colors.
  final OsGridTheme? gridTheme;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final materialTheme = theme.colorScheme;
    final textStyle = theme.textTheme.bodySmall;

    final barColor =
        gridTheme?.headerBackgroundColor ??
        materialTheme.surfaceContainerHighest.withValues(alpha: 0.3);
    final borderColor = gridTheme?.borderColor ?? theme.dividerColor;
    final textColor =
        gridTheme?.cellTextColor ?? textStyle?.color ?? materialTheme.onSurface;

    final leftChips = <Widget>[];
    final rightChips = <Widget>[];

    for (var i = 0; i < config.statusPanels.length; i++) {
      final panel = config.statusPanels[i];
      final chip = Padding(
        key: ValueKey('status_panel_$i'),
        padding: const EdgeInsets.only(right: 16),
        child: _buildChip(panel, textStyle, textColor, borderColor),
      );
      if (panel.align == OsStatusPanelAlign.right) {
        rightChips.add(chip);
      } else {
        leftChips.add(chip);
      }
    }

    return Container(
      height: 32,
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: borderColor)),
        color: barColor,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          ...leftChips,
          if (rightChips.isNotEmpty) const Spacer(),
          ...rightChips,
        ],
      ),
    );
  }

  Widget _buildChip(
    OsStatusPanelDef panel,
    TextStyle? textStyle,
    Color textColor,
    Color borderColor,
  ) {
    final column = _findColumn(panel.valueColId);
    final valueText = column == null ? '' : _formatAggregate(column, panel);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor.withValues(alpha: 0.35)),
        color: borderColor.withValues(alpha: 0.08),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${_resolveLabel(panel)}:',
            style: textStyle?.copyWith(
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(width: 6),
          Text(valueText, style: textStyle?.copyWith(color: textColor)),
        ],
      ),
    );
  }

  /// Resolves the panel label: explicit override, then localized default
  /// for known functions, then the raw function name.
  String _resolveLabel(OsStatusPanelDef panel) {
    if (panel.label != null) return panel.label!;
    switch (panel.aggregationFunc) {
      case 'sum':
        return resolveLocaleText('summed', 'Sum');
      case 'avg':
        return resolveLocaleText('averaged', 'Avg');
      case 'min':
        return resolveLocaleText('minimum', 'Min');
      case 'max':
        return resolveLocaleText('maximum', 'Max');
      case 'count':
        return resolveLocaleText('count', 'Count');
      default:
        return panel.aggregationFunc;
    }
  }

  /// Finds a column by colId or field name.
  OsColumnDef? _findColumn(String? colId) {
    if (colId == null) return null;
    for (final col in columns) {
      if (col.effectiveColId == colId || col.field == colId) return col;
    }
    return null;
  }

  /// Computes the aggregate over the page rows and formats it using the
  /// column's valueFormatter when present.
  String _formatAggregate(OsColumnDef column, OsStatusPanelDef panel) {
    final values = <dynamic>[
      for (var i = 0; i < pageRows.length; i++)
        _resolveValue(column, pageRows[i], i),
    ];

    final aggregate = AggregationService.builtInAgg(
      panel.aggregationFunc,
      values,
    );
    if (aggregate == null) return '';

    final formatter = column.valueFormatter;
    if (formatter != null) {
      return formatter(ValueFormatterParams(value: aggregate, rowIndex: 0));
    }
    return aggregate.toString();
  }

  /// Resolves the raw cell value for a column from a display row.
  ///
  /// Mirrors the clipboard/export resolution order: valueGetter first, then
  /// Map field lookup. Params are typed as `Map<String, dynamic>` because
  /// page rows are always display maps; getters expecting other row types
  /// fail invocation and fall back to the field lookup, which already holds
  /// the valueGetter-resolved value for converted typed rows.
  dynamic _resolveValue(OsColumnDef col, Map<String, dynamic> row, int index) {
    final getter = col.getValueGetterAsFunction();
    if (getter != null) {
      try {
        return Function.apply(getter, [
          ValueGetterParams<Map<String, dynamic>>(data: row, rowIndex: index),
        ]);
      } catch (e) {
        GridDiagnostics.warnOnce(
          'statusBar:valueGetter',
          'valueGetter threw in a status-bar aggregation panel for column '
              '"${col.effectiveColId}"; falling back to field lookup: $e',
        );
        // Fall through to field lookup.
      }
    }
    return row[col.field];
  }
}
