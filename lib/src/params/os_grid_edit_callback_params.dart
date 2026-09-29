import '../columns/os_column_def.dart';

/// Shared immutable context for the value-editing callback parameter objects
/// (`ValueSetterParams` and `ValueParserParams`) — quality program v3 item 41.
///
/// Consolidates the five fields both classes carry ([data], [colDef],
/// [oldValue], [rowIndex] and [source]) so each concrete class only declares
/// its own new-value field. Subclasses keep their exact public constructors;
/// only the storage moves here.
///
/// This base intentionally does NOT extend `OsGridCallbackParams`: the edit
/// callbacks receive a raw [OsColumnDef] (the column def loses its type
/// parameter when stored in a `ColumnLayoutEntry`), and a raw reference
/// cannot soundly satisfy an `OsColumnDef<TData>` base field under Dart's
/// covariant generics.
class OsGridEditCallbackParams<TData> {
  /// Creates the shared edit-callback context.
  const OsGridEditCallbackParams({
    required this.data,
    required this.colDef,
    required this.oldValue,
    required this.rowIndex,
    this.source,
  });

  /// The row data object being edited.
  final TData data;

  /// The column definition for the edited cell.
  final OsColumnDef colDef;

  /// The value before editing.
  final dynamic oldValue;

  /// The row index of the edited cell.
  final int rowIndex;

  /// The source of the edit (e.g. 'edit', 'paste'). Currently always 'edit'.
  final String? source;
}
