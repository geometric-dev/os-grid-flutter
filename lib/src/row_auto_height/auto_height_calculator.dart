import 'dart:math' as math;

import 'package:flutter/painting.dart';

import '../columns/os_column_def.dart';
import '../params/value_formatter_params.dart';
import '../params/value_getter_params.dart';
import 'row_height_layout.dart';

/// Calculates row heights based on cell content measurement.
///
/// Uses [TextPainter] to measure the height of text content in columns
/// that have [OsColumnDef.autoHeight] set to `true`. The row height is
/// the maximum of the default height and the measured content heights
/// across all autoHeight columns.
class AutoHeightCalculator {
  const AutoHeightCalculator._();

  /// Computes a [RowHeightLayout] for the given row data.
  ///
  /// For each row, measures the text content of all columns with
  /// `autoHeight: true` and determines the row height as the maximum
  /// of [defaultRowHeight] and the measured content heights.
  ///
  /// If [getRowHeight] is provided, it takes precedence over auto-height
  /// measurement for rows where it returns a non-null value.
  ///
  /// Returns `null` if no variable heights are needed (all rows use the
  /// default height and no `getRowHeight` or `autoHeight` columns exist).
  static RowHeightLayout? computeLayout<TData>({
    required List<TData> rowData,
    required List<OsColumnDef> columns,
    required double defaultRowHeight,
    required Map<int, double> columnWidths,
    double? Function(RowHeightParams<TData> params)? getRowHeight,
    TextStyle? cellTextStyle,
    TextScaler textScaler = TextScaler.noScaling,
  }) {
    final autoHeightCols = columns.where((c) => c.autoHeight).toList();

    // If no variable height mechanism is active, return null (use uniform).
    if (getRowHeight == null && autoHeightCols.isEmpty) {
      return null;
    }

    final heights = List<double>.filled(rowData.length, defaultRowHeight);
    bool anyVariable = false;

    final effectiveTextStyle =
        cellTextStyle ??
        const TextStyle(fontSize: 13, color: Color(0xFF424242));

    // Horizontal padding per cell (matches GridPainter._cellPaddingH).
    const cellPaddingH = 12.0;
    // Vertical padding added to measured text height.
    const cellPaddingV = 8.0;

    for (int r = 0; r < rowData.length; r++) {
      final data = rowData[r];

      // 1. Check getRowHeight callback first.
      if (getRowHeight != null) {
        final callbackHeight = getRowHeight(
          RowHeightParams<TData>(data: data, rowIndex: r),
        );
        if (callbackHeight != null && callbackHeight > 0) {
          heights[r] = callbackHeight;
          if (callbackHeight != defaultRowHeight) anyVariable = true;
          continue; // getRowHeight takes full precedence.
        }
      }

      // 2. Measure autoHeight columns.
      if (autoHeightCols.isNotEmpty) {
        double maxHeight = defaultRowHeight;

        for (final col in autoHeightCols) {
          // Get cell value.
          dynamic value;
          if (col.valueGetter != null &&
              col.getValueGetterAsFunction() != null) {
            value = (col.getValueGetterAsFunction() as dynamic)(
              ValueGetterParams<TData>(data: data, rowIndex: r),
            );
          } else if (col.field != null && data is Map<String, dynamic>) {
            value = data[col.field];
          }

          // Apply value formatter.
          String displayText;
          if (col.valueFormatter != null) {
            displayText = col.valueFormatter!(
              ValueFormatterParams(value: value, rowIndex: r),
            );
          } else {
            displayText = value?.toString() ?? '';
          }

          if (displayText.isEmpty) continue;

          // Determine column width for text measurement.
          final colIndex = columns.indexOf(col);
          final colWidth = colIndex >= 0
              ? (columnWidths[colIndex] ?? col.width ?? 150.0)
              : (col.width ?? 150.0);
          final availableWidth = math.max(0.0, colWidth - cellPaddingH * 2);

          // Measure text height (honours the active TextScaler — item 8).
          final tp = TextPainter(
            text: TextSpan(text: displayText, style: effectiveTextStyle),
            maxLines: col.wrapText ? null : 1,
            textDirection: TextDirection.ltr,
            textScaler: textScaler,
          );
          tp.layout(maxWidth: availableWidth);

          final measuredHeight = tp.height + cellPaddingV * 2;
          maxHeight = math.max(maxHeight, measuredHeight);
        }

        if (maxHeight != defaultRowHeight) {
          heights[r] = maxHeight;
          anyVariable = true;
        }
      }
    }

    if (!anyVariable) return null;

    return RowHeightLayout.variable(heights: heights);
  }
}
