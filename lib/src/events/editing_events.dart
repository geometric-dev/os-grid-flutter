import '../columns/os_column_def.dart';
import 'os_grid_event.dart';

/// Emitted when cell editing starts.
///
/// ```dart
/// controller.onCellEditingStarted.listen((event) {
///   print('editing ${event.colDef.field} = ${event.value}');
/// });
/// ```
class OsCellEditingStartedEvent<TData> extends OsGridEvent {
  const OsCellEditingStartedEvent({
    required this.data,
    required this.rowIndex,
    required this.colDef,
    required this.value,
  });

  /// The row data for the cell being edited.
  final TData data;

  /// The row index of the cell being edited.
  final int rowIndex;

  /// The column definition of the cell being edited.
  final OsColumnDef<TData> colDef;

  /// The current value of the cell when editing started.
  final dynamic value;
}

/// Emitted when `readOnlyEdit` is enabled and the user commits an edit.
///
/// Instead of writing the value to data, this event is fired so the
/// application can handle the update externally (e.g. via an API call)
/// and then refresh the grid data.
///
/// ```dart
/// controller.onCellEditRequest.listen((event) {
///   print('server write requested: ${event.newValue}');
/// });
/// ```
class OsCellEditRequestEvent<TData> extends OsGridEvent {
  const OsCellEditRequestEvent({
    required this.data,
    required this.rowIndex,
    required this.colDef,
    required this.oldValue,
    required this.newValue,
    this.source = 'edit',
  });

  /// The row data for the cell that was edited.
  final TData data;

  /// The row index of the cell that was edited.
  final int rowIndex;

  /// The column definition of the cell that was edited.
  final OsColumnDef<TData> colDef;

  /// The value before editing started.
  final dynamic oldValue;

  /// The new value the user entered (not yet written to data).
  final dynamic newValue;

  /// The source of the edit (e.g. 'edit', 'cellClear').
  final String source;
}

/// Emitted when cell editing stops (either committed or cancelled).
///
/// ```dart
/// controller.onCellEditingStopped.listen((event) {
///   if (!event.cancelled) print('committed ${event.newValue}');
/// });
/// ```
class OsCellEditingStoppedEvent<TData> extends OsGridEvent {
  const OsCellEditingStoppedEvent({
    required this.data,
    required this.rowIndex,
    required this.colDef,
    required this.oldValue,
    required this.newValue,
    required this.cancelled,
  });

  /// The row data for the cell that was being edited.
  final TData data;

  /// The row index of the cell that was being edited.
  final int rowIndex;

  /// The column definition of the cell that was being edited.
  final OsColumnDef<TData> colDef;

  /// The value before editing started.
  final dynamic oldValue;

  /// The value after editing (same as [oldValue] if [cancelled] is true).
  final dynamic newValue;

  /// Whether the edit was cancelled (Escape pressed or programmatic cancel).
  ///
  /// When `true`, the value was reverted to [oldValue].
  final bool cancelled;
}
