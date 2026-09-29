import '../columns/os_column_def.dart';

/// Parameters passed to [OsColumnDef.tooltipValueGetter].
///
/// Provides context about the cell for which a tooltip value is being computed.
class TooltipValueGetterParams<TData> {
  const TooltipValueGetterParams({
    required this.data,
    required this.value,
    this.valueFormatted,
    required this.colDef,
    required this.rowIndex,
  });

  /// The row data for this cell.
  final TData data;

  /// The raw cell value.
  final dynamic value;

  /// The formatted cell value (if a valueFormatter is configured).
  final String? valueFormatted;

  /// The column definition for this cell.
  final OsColumnDef colDef;

  /// The row index (in processed/displayed data).
  final int rowIndex;
}

/// Location where a tooltip is being shown.
enum TooltipLocation {
  /// Tooltip on a data cell.
  cell,

  /// Tooltip on a column header.
  header,

  /// Tooltip on a column group header.
  headerGroup,
}
