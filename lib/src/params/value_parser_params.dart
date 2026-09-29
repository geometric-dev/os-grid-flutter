import '../columns/os_column_def.dart' show OsColumnDef;
import 'os_grid_edit_callback_params.dart';

/// Parameters passed to [OsColumnDef.valueParser] callbacks.
///
/// Provides the context needed to parse the raw string from the editor
/// into the correct type before writing to the data.
///
/// ```dart
/// OsColumnDef(
///   field: 'price',
///   valueParser: (params) => double.tryParse(params.newValue) ?? 0.0,
/// )
/// ```
class ValueParserParams<TData> extends OsGridEditCallbackParams<TData> {
  /// Creates value parser parameters.
  const ValueParserParams({
    required super.data,
    required super.colDef,
    required super.oldValue,
    required this.newValue,
    required super.rowIndex,
    super.source,
  });

  /// The raw string value from the editor input.
  final String newValue;
}
