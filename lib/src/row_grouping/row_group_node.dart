/// Represents a group node in the row grouping hierarchy.
///
/// Group nodes are synthetic rows created by the grouping service to
/// represent a set of leaf rows that share the same value for a grouped
/// column. They are rendered as expandable/collapsible rows in the grid.
class OsRowGroupNode<TData> {
  OsRowGroupNode({
    required this.nodeId,
    required this.groupKey,
    required this.groupField,
    required this.level,
    required this.childCount,
    this.expanded = false,
  });

  /// Unique stable identity for this group node.
  ///
  /// Format: `row-group-{colId}-{key}` for top-level groups,
  /// `{parentId}-{colId}-{key}` for nested groups.
  final String nodeId;

  /// The value that this group represents (the common value of the grouped
  /// column for all child rows).
  final dynamic groupKey;

  /// The column field (or colId) that this group is based on.
  final String groupField;

  /// The nesting depth of this group (0 = top-level group).
  final int level;

  /// The number of leaf rows (direct + nested) in this group.
  final int childCount;

  /// Whether this group is currently expanded (children visible).
  bool expanded;

  @override
  String toString() =>
      'OsRowGroupNode(id: $nodeId, key: $groupKey, field: $groupField, '
      'level: $level, children: $childCount, expanded: $expanded)';
}
