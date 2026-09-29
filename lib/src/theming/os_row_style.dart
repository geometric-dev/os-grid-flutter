import 'package:flutter/widgets.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart' show OsColumnDef, OsGrid;

/// Parameters passed to the [OsGrid.getRowStyle] callback.
///
/// Provides the row data and display index so the callback can
/// determine per-row styling based on data values.
///
/// ```dart
/// getRowStyle: (params) {
///   if ((params.data as Map)['status'] == 'overdue') {
///     return OsRowStyle(backgroundColor: Colors.red.shade50);
///   }
///   return null;
/// }
/// ```
class RowStyleParams<TData> {
  /// Creates row style parameters.
  const RowStyleParams({required this.data, required this.rowIndex});

  /// The data for this row.
  ///
  /// For untyped grids this is typically `Map<String, dynamic>`.
  /// For group rows in future implementations this may be null.
  final TData data;

  /// The display index of this row (zero-based, after filter/sort).
  final int rowIndex;
}

/// Styling properties applied to an entire row during canvas painting.
///
/// Returned from [OsGrid.getRowStyle] or set as [OsGrid.rowStyle]:
/// ```dart
/// OsGrid(
///   rowStyle: const OsRowStyle(
///     fontWeight: FontWeight.w500,
///   ),
///   getRowStyle: (params) {
///     final data = params.data as Map<String, dynamic>;
///     if (data['priority'] == 'high') {
///       return OsRowStyle(
///         backgroundColor: Colors.red.shade50,
///         foregroundColor: Colors.red.shade900,
///       );
///     }
///     return null;
///   },
/// )
/// ```
///
/// Priority order for row backgrounds:
/// selected > hovered > getRowStyle > rowStyle > alternate > default
class OsRowStyle {
  /// Creates a row style.
  const OsRowStyle({
    this.backgroundColor,
    this.foregroundColor,
    this.fontWeight,
    this.fontStyle,
  });

  /// Background colour for the row.
  ///
  /// Overrides the theme's alternate row colour when set.
  /// Does not override selection or hover highlighting.
  final Color? backgroundColor;

  /// Text colour for all cells in the row.
  ///
  /// Overrides the theme's default cell text colour.
  /// Individual cell styles (from [OsColumnDef.cellStyle]) take
  /// precedence over this value.
  final Color? foregroundColor;

  /// Font weight for all cells in the row.
  ///
  /// Individual cell styles take precedence over this value.
  final FontWeight? fontWeight;

  /// Font style (italic/normal) for all cells in the row.
  ///
  /// Individual cell styles take precedence over this value.
  final FontStyle? fontStyle;

  /// Merges this style with another, where [other] takes precedence.
  ///
  /// Mirrors the TypeScript behaviour of `Object.assign({}, rowStyle, getRowStyleResult)`.
  OsRowStyle merge(OsRowStyle? other) {
    if (other == null) return this;
    return OsRowStyle(
      backgroundColor: other.backgroundColor ?? backgroundColor,
      foregroundColor: other.foregroundColor ?? foregroundColor,
      fontWeight: other.fontWeight ?? fontWeight,
      fontStyle: other.fontStyle ?? fontStyle,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OsRowStyle &&
          runtimeType == other.runtimeType &&
          backgroundColor == other.backgroundColor &&
          foregroundColor == other.foregroundColor &&
          fontWeight == other.fontWeight &&
          fontStyle == other.fontStyle;

  @override
  int get hashCode =>
      Object.hash(backgroundColor, foregroundColor, fontWeight, fontStyle);
}
