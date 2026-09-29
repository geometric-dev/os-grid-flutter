import 'os_grid_event.dart';

/// Emitted when pinned row data changes (top or bottom).
///
/// ```dart
/// controller.onPinnedRowDataChanged.listen((event) {
///   print('top=${event.pinnedTopRowCount} bottom=${event.pinnedBottomRowCount}');
/// });
/// ```
class OsPinnedRowDataChangedEvent extends OsGridEvent {
  const OsPinnedRowDataChangedEvent({
    required this.pinnedTopRowCount,
    required this.pinnedBottomRowCount,
  });

  /// The number of rows pinned to the top after the change.
  final int pinnedTopRowCount;

  /// The number of rows pinned to the bottom after the change.
  final int pinnedBottomRowCount;
}
