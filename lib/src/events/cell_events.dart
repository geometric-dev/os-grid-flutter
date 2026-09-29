import '../columns/os_column_def.dart';
import 'os_grid_event.dart';

/// Emitted when a cell is clicked.
///
/// ```dart
/// controller.onCellClicked.listen((event) {
///   print('clicked ${event.colDef.field} = ${event.value}');
/// });
/// ```
class OsCellClickedEvent<TData> extends OsGridEvent {
  const OsCellClickedEvent({
    required this.data,
    required this.rowIndex,
    required this.colDef,
    required this.value,
  });

  /// The row data for the clicked cell.
  final TData data;

  /// The row index of the clicked cell.
  final int rowIndex;

  /// The column definition of the clicked cell.
  final OsColumnDef<TData> colDef;

  /// The value of the clicked cell.
  final dynamic value;
}

/// Emitted when a cell value changes via editing.
///
/// ```dart
/// controller.onCellValueChanged.listen((event) {
///   print('${event.oldValue} -> ${event.newValue}');
/// });
/// ```
class OsCellValueChangedEvent<TData> extends OsGridEvent {
  const OsCellValueChangedEvent({
    required this.data,
    required this.rowIndex,
    required this.colDef,
    required this.oldValue,
    required this.newValue,
  });

  /// The row data (after the change).
  final TData data;

  /// The row index of the edited cell.
  final int rowIndex;

  /// The column definition of the edited cell.
  final OsColumnDef<TData> colDef;

  /// The value before editing.
  final dynamic oldValue;

  /// The value after editing.
  final dynamic newValue;
}
