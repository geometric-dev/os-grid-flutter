import 'os_grid_callback_params.dart';

/// Parameters passed to cell renderer callbacks.
///
/// Provides access to the cell's value, row data, indices, and column definition.
///
/// ```dart
/// OsColumnDef(
///   field: 'avatar',
///   cellRenderer: (params) => Icon(
///     params.value == null ? Icons.person_outline : Icons.person,
///   ),
/// )
/// ```
class CellRendererParams<TData> extends OsGridCallbackParams<TData> {
  /// Creates cell renderer parameters.
  const CellRendererParams({
    required super.value,
    required super.data,
    required super.rowIndex,
    required super.colDef,
  });
}
