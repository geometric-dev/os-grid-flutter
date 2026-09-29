import '../columns/os_column_def.dart';

/// Parameters passed to [OsColumnDef.headerValueGetter] callbacks.
///
/// Provides the column definition whose header text is being resolved and,
/// where known, the display index of the column.
///
/// ```dart
/// headerValueGetter: (params) => '${params.colDef.field}'.toUpperCase(),
/// ```
class HeaderValueGetterParams<TData> {
  const HeaderValueGetterParams({required this.colDef, this.index});

  /// The column definition the header text is computed for.
  final OsColumnDef<TData> colDef;

  /// The column's display index, when known (`null` otherwise, e.g. when
  /// resolving header text outside a rendered column list context).
  final int? index;
}
