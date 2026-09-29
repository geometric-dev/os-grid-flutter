import 'os_grid_event.dart';

/// Emitted when the set of selected rows changes.
///
/// ```dart
/// controller.onSelectionChanged.listen((event) {
///   print('${event.selectedRows.length} rows selected');
/// });
/// ```
class OsSelectionChangedEvent<TData> extends OsGridEvent {
  const OsSelectionChangedEvent({required this.selectedRows});

  /// All currently selected rows.
  final List<TData> selectedRows;
}
