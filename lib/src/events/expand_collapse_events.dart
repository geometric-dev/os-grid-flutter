import 'os_grid_event.dart';

/// Emitted when `expandAll()` or `collapseAll()` is called on the
/// grid controller.
///
/// This event fires regardless of whether any rows were actually expanded or
/// collapsed. When tree data or row grouping is not configured, the event
/// still fires but no rows change state.
///
/// ```dart
/// controller.onExpandOrCollapseAll.listen((event) {
///   print(event.expandedAll ? 'expanded all' : 'collapsed all');
/// });
/// ```
class OsExpandOrCollapseAllEvent extends OsGridEvent {
  const OsExpandOrCollapseAllEvent({
    required this.source,
    required this.expandedAll,
  });

  /// What triggered the expand/collapse operation.
  ///
  /// Typically `'api'` when called programmatically via the controller.
  final String source;

  /// Whether this was an expand-all (`true`) or collapse-all (`false`) operation.
  final bool expandedAll;
}
