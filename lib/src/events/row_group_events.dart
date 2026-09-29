import 'expand_collapse_events.dart' show OsExpandOrCollapseAllEvent;
import 'os_grid_event.dart';

/// Emitted when a single group row is expanded or collapsed.
///
/// This fires for individual group node toggles (via user click on the
/// expand/collapse icon or programmatic `setRowExpanded` calls).
/// For bulk operations, [OsExpandOrCollapseAllEvent] is also emitted.
///
/// ```dart
/// controller.onRowGroupOpened.listen((event) {
///   print('${event.groupField}=${event.groupKey} expanded=${event.expanded}');
/// });
/// ```
class OsRowGroupOpenedEvent extends OsGridEvent {
  const OsRowGroupOpenedEvent({
    required this.nodeId,
    required this.expanded,
    required this.groupKey,
    required this.groupField,
    required this.level,
  });

  /// The stable identity of the group node that was toggled.
  final String nodeId;

  /// Whether the group is now expanded (`true`) or collapsed (`false`).
  final bool expanded;

  /// The group key value (the common value of the grouped column).
  final dynamic groupKey;

  /// The column field (or colId) used for grouping at this level.
  final String groupField;

  /// The nesting level of the group (0 = top-level).
  final int level;

  @override
  String toString() =>
      'OsRowGroupOpenedEvent(nodeId: $nodeId, expanded: $expanded, '
      'key: $groupKey, field: $groupField, level: $level)';
}
