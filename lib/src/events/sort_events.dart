import '../sorting/sort_model.dart';
import 'os_grid_event.dart';

/// Emitted when the sort model changes.
///
/// ```dart
/// controller.onSortChanged.listen((event) {
///   for (final sort in event.sortModel) {
///     print('${sort.colId}: ${sort.sort}');
///   }
/// });
/// ```
class OsSortChangedEvent extends OsGridEvent {
  const OsSortChangedEvent({required this.sortModel});

  /// The current sort model (list of sorted columns and their directions).
  final List<OsSortModel> sortModel;
}
