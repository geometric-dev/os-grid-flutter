import '../columns/os_column_def.dart';

/// Shared immutable context for row-and-column-scoped callback parameter
/// objects (quality program v3 item 41).
///
/// Consolidates the fields the rich callback params classes all carry — the
/// cell's [value], the row's [data], the row's [rowIndex] and the column's
/// [colDef] — so concrete params types extend this class instead of
/// re-declaring them. Subclasses keep their exact public constructors
/// (named parameters and field types unchanged); only the storage moves to
/// this base class.
///
/// Not every params type joins this hierarchy, by audit (item 41):
/// - `ValueGetterParams`, `ValueFormatterParams` and
///   `HeaderValueGetterParams` share at most 2 fields with any other params
///   class (below the >3 consolidation threshold), and
///   `ValueFormatterParams` is deliberately non-generic.
/// - The edit params (`ValueSetterParams`/`ValueParserParams`) carry a raw
///   [OsColumnDef] because the column def loses its type parameter when
///   stored in a `ColumnLayoutEntry`; a raw reference cannot soundly satisfy
///   an `OsColumnDef<TData>` base field under Dart's covariant generics
///   (runtime type checks), so they share `OsGridEditCallbackParams` instead.
///
/// ```dart
/// class MyParams<TData> extends OsGridCallbackParams<TData> {
///   const MyParams({required super.value, required super.data,
///       required super.rowIndex, required super.colDef});
/// }
/// ```
class OsGridCallbackParams<TData> {
  /// Creates the shared callback context.
  const OsGridCallbackParams({
    required this.value,
    required this.data,
    required this.rowIndex,
    required this.colDef,
  });

  /// The cell's raw value (from field lookup or valueGetter).
  final dynamic value;

  /// The full row data object.
  final TData data;

  /// The row's display index.
  final int rowIndex;

  /// The column definition for this cell.
  final OsColumnDef<TData> colDef;
}
