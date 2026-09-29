import '../columns/os_column_def.dart' show OsColumnDef;
import 'os_grid_edit_callback_params.dart';

/// Parameters passed to [OsColumnDef.valueSetter] callbacks.
///
/// Provides the context needed to write an edited value back to the row data.
/// The `valueSetter` should return `true` if the data was changed, `false` otherwise.
///
/// ```dart
/// OsColumnDef(
///   field: 'price',
///   valueSetter: (params) {
///     params.data.price = params.newValue as double;
///     return true;
///   },
/// )
/// ```
class ValueSetterParams<TData> extends OsGridEditCallbackParams<TData> {
  /// Creates value setter parameters.
  const ValueSetterParams({
    required super.data,
    required super.colDef,
    required super.oldValue,
    required this.newValue,
    required super.rowIndex,
    super.source,
  });

  /// The new value after parsing (via [OsColumnDef.valueParser] or default).
  final dynamic newValue;
}
