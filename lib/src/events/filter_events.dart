import 'os_grid_event.dart';

/// Emitted when the filter model changes.
///
/// ```dart
/// controller.onFilterChanged.listen((event) {
///   print('active filters: ${event.filterModel.length}');
/// });
/// ```
class OsFilterChangedEvent extends OsGridEvent {
  const OsFilterChangedEvent({required this.filterModel});

  /// The current filter model as a map of column ID to filter state.
  final Map<String, dynamic> filterModel;
}
