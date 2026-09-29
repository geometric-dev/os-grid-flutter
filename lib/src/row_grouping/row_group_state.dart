/// Tracks the expansion state of group nodes in the row grouping hierarchy.
///
/// Expansion state is identified by group node ID (string). This allows
/// state to survive data changes as long as the same group values exist.
class RowGroupState {
  /// The set of group node IDs that are currently expanded.
  final Set<String> _expandedNodeIds = {};

  /// The default number of levels to expand.
  ///
  /// - `-1` means expand all levels
  /// - `0` means collapse all (default)
  /// - `1` means expand the first level only
  /// - `n` means expand the first n levels
  int _defaultExpanded = 0;

  /// Updates the default expanded level count.
  void setDefaultExpanded(int levels) {
    _defaultExpanded = levels;
  }

  /// Returns whether a specific group node is expanded.
  ///
  /// If the node has never been explicitly toggled, falls back to the
  /// default expansion based on [_defaultExpanded] and the node's level.
  bool isExpanded(String nodeId, {required int level}) {
    if (_expandedNodeIds.contains(nodeId)) return true;
    if (_collapsedNodeIds.contains(nodeId)) return false;
    // Default expansion based on level
    if (_defaultExpanded == -1) return true;
    return level < _defaultExpanded;
  }

  /// The set of group node IDs that have been explicitly collapsed.
  ///
  /// Used to override the default expansion for nodes that the user
  /// or API has explicitly collapsed.
  final Set<String> _collapsedNodeIds = {};

  /// Expand a specific group node.
  void expand(String nodeId) {
    _expandedNodeIds.add(nodeId);
    _collapsedNodeIds.remove(nodeId);
  }

  /// Collapse a specific group node.
  void collapse(String nodeId) {
    _expandedNodeIds.remove(nodeId);
    _collapsedNodeIds.add(nodeId);
  }

  /// Set the expansion state of a specific group node.
  void setExpanded(String nodeId, {required bool expanded}) {
    if (expanded) {
      expand(nodeId);
    } else {
      collapse(nodeId);
    }
  }

  /// Expand all group nodes (clears explicit collapse state).
  void expandAll() {
    _collapsedNodeIds.clear();
    // Setting default to -1 means all levels are expanded by default.
    // We also clear expanded set since the default handles everything.
    _expandedNodeIds.clear();
    _defaultExpanded = -1;
  }

  /// Collapse all group nodes (clears explicit expand state).
  void collapseAll() {
    _expandedNodeIds.clear();
    _collapsedNodeIds.clear();
    _defaultExpanded = 0;
  }

  /// Reset all explicit expansion state (reverts to default behaviour).
  void reset() {
    _expandedNodeIds.clear();
    _collapsedNodeIds.clear();
  }

  /// Returns the set of currently expanded node IDs (for state serialisation).
  Set<String> get expandedNodeIds => Set.unmodifiable(_expandedNodeIds);
}
