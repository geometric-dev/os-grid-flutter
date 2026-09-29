import 'package:os_grid_flutter/os_grid_flutter.dart' show OsColumnDef;
import 'package:os_grid_flutter/src/columns/os_column_def.dart'
    show OsColumnDef;

/// Parameters passed to [OsColumnDef.valueGetter] callbacks.
///
/// Provides access to the row data for extracting a cell value.
///
/// ```dart
/// valueGetter: (params) =>
///     '${params.data['firstName']} ${params.data['lastName']}',
/// ```
class ValueGetterParams<TData> {
  const ValueGetterParams({required this.data, required this.rowIndex});

  /// The full row data object.
  final TData data;

  /// The row's display index.
  final int rowIndex;
}
