import 'os_grid_event.dart';

/// Emitted when a row is clicked (any cell in the row is tapped).
///
/// ```dart
/// controller.onRowClicked.listen((event) {
///   print('row ${event.rowIndex} clicked');
/// });
/// ```
class OsRowClickedEvent<TData> extends OsGridEvent {
  const OsRowClickedEvent({required this.data, required this.rowIndex});

  /// The row data for the clicked row.
  final TData data;

  /// The row index of the clicked row.
  final int rowIndex;
}

/// Emitted when a row is selected or deselected.
///
/// ```dart
/// OsGrid(
///   onRowSelected: (event) =>
///       print('${event.rowIndex} selected=${event.selected}'),
/// );
/// ```
class OsRowSelectedEvent<TData> extends OsGridEvent {
  const OsRowSelectedEvent({
    required this.data,
    required this.rowIndex,
    required this.selected,
  });

  /// The row data.
  final TData data;

  /// The row index.
  final int rowIndex;

  /// Whether the row is now selected.
  final bool selected;
}

/// Emitted when a row is double-clicked.
///
/// ```dart
/// controller.onRowDoubleClicked.listen((event) {
///   openDetailPage(event.data);
/// });
/// ```
class OsRowDoubleClickedEvent<TData> extends OsGridEvent {
  const OsRowDoubleClickedEvent({required this.data, required this.rowIndex});

  /// The row data.
  final TData data;

  /// The row index.
  final int rowIndex;
}
