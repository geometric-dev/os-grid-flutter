import '../columns/os_column_def.dart' show OsColumnDef;
import 'os_grid_callback_params.dart';

/// Parameters passed to [OsColumnDef.getQuickFilterText] callbacks.
///
/// Provides access to the cell value, row data, and column definition
/// so the callback can return custom text for quick filter matching.
///
/// ```dart
/// OsColumnDef(
///   field: 'name',
///   getQuickFilterText: (params) =>
///       '${params.data['name']} (${params.colDef.field})',
/// )
/// ```
class GetQuickFilterTextParams<TData> extends OsGridCallbackParams<TData> {
  /// Creates quick-filter-text parameters.
  ///
  /// [rowIndex] defaults to `-1` (the grid's "unknown index" convention)
  /// when the callback is evaluated outside a rendered-row context, such as
  /// quick-filter cache warm-up over unprocessed rows.
  const GetQuickFilterTextParams({
    required super.value,
    required super.data,
    required super.colDef,
    super.rowIndex = -1,
  });
}
