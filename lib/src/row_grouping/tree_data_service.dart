import 'row_group_service.dart';
import 'row_group_state.dart';

/// Service that builds a hierarchical display list from tree data.
///
/// AG Grid parity for `treeData: true` + `getDataPath`. Unlike column
/// grouping (which groups rows by cell values), every original data row
/// remains a leaf row: its path segments name the ancestor group nodes it
/// nests under, and synthetic group nodes are created only for path
/// prefixes shared between rows.
///
/// Example — paths `[["A"], ["A", "B"], ["A", "B", "C"]]` produce:
///
/// ```text
/// A            <- synthetic group (level 0)
///   row1       <- leaf (path ["A"])
///   B          <- synthetic group (level 1)
///     row2     <- leaf (path ["A", "B"])
///     C        <- synthetic group (level 2)
///       row3   <- leaf (path ["A", "B", "C"])
/// ```
///
/// Rows whose path is null or empty are placed at the root level as plain
/// leaves without a synthetic parent. Within any node, its direct leaves
/// and sub-group rows appear in first-encounter order of the input data
/// (i.e. sorted data order); each group row always precedes its own
/// subtree, mirroring column grouping.
///
/// The output uses the exact same synthetic group-row map keys as
/// [RowGroupService] ([RowGroupKeys]), so the painter, group-tap hit
/// testing and expansion logic work unchanged.
///
/// Expansion state is shared with column grouping through [RowGroupState],
/// keyed by stable node IDs derived from the PATH SEGMENTS via
/// [RowGroupService.makeNodeId] (see [makeTreeNodeId]). This means
/// `controller.expandAll()`, `collapseAll()` and `setRowExpanded()` work
/// for tree nodes with no extra wiring.
///
/// Filter and sort run before this service (the input is already the
/// processed flat data); sibling order therefore follows the sorted data
/// order. Pagination slices after flattening.
///
/// Node layer: leaf rows are ordinary `TData` rows, so they flow through
/// the controller's node layer (`getNode`/`getRenderedNodes`) unchanged
/// with `OsRowNode.group` left `false` — they are data rows, not groups.
/// Synthetic tree group rows are plain display maps not backed by any
/// `TData`, so — exactly like column-group rows — they never enter the
/// controller's `_nodesById` map; address them via their [makeTreeNodeId]
/// with `setRowExpanded`/`isRowExpanded` instead. Selection keeps using
/// `getRowId` on leaf rows; select-all covers every leaf regardless of
/// nesting depth.
class TreeDataService<TData> {
  /// Pseudo field ID used in node IDs and `kGroupField` metadata for
  /// tree-data group rows (tree groups are not backed by a column).
  static const String treeFieldId = '__tree';

  /// Builds the flattened display list from tree data.
  ///
  /// [data] — the filtered/sorted flat data.
  /// `getDataPath` — returns the ancestor path segments for a row.
  /// [state] — the current expansion state.
  /// [typedLeafToMap] converts non-Map (typed) leaf rows into display maps
  /// via their columns' valueGetters. When null, typed leaves fall back to
  /// empty maps (legacy behaviour).
  List<Map<String, dynamic>> buildTreeData({
    required List<TData> data,
    required List<Object?>? Function(TData row) getDataPath,
    required RowGroupState state,
    Map<String, dynamic> Function(TData row, int index)? typedLeafToMap,
  }) {
    // Synthetic root whose entries mix top-level tree nodes and root-level
    // leaves (rows without a usable path) in first-encounter order.
    final root = _TreeDataNode<TData>(key: null);

    for (final row in data) {
      final path = getDataPath(row);
      if (path == null || path.isEmpty) {
        // No ancestry: the row is a root-level leaf.
        root.entries.add(_Leaf<TData>(row));
        continue;
      }

      var node = root;
      for (final segment in path) {
        node = node.childFor(segment);
      }
      // Every original row stays a leaf under its deepest path segment.
      node.entries.add(_Leaf<TData>(row));
    }

    final result = <Map<String, dynamic>>[];
    _flatten(
      node: root,
      parentId: '',
      level: 0,
      state: state,
      result: result,
      typedLeafToMap: typedLeafToMap,
    );
    return result;
  }

  /// Recursively flattens [node]'s subtree into [result].
  ///
  /// Entries (interleaved sub-nodes and leaves) render in first-encounter
  /// order; each group row precedes its own subtree.
  void _flatten({
    required _TreeDataNode<TData> node,
    required String parentId,
    required int level,
    required RowGroupState state,
    required Map<String, dynamic> Function(TData row, int index)?
    typedLeafToMap,
    required List<Map<String, dynamic>> result,
  }) {
    var leafIndex = 0;
    for (final entry in node.entries) {
      if (entry is _SubTree<TData>) {
        final child = entry.node;
        final nodeId = makeTreeNodeId(parentId, child.key);
        final expanded = state.isExpanded(nodeId, level: level);
        result.add(<String, dynamic>{
          RowGroupKeys.kIsGroupRow: true,
          RowGroupKeys.kGroupKey: child.key,
          RowGroupKeys.kGroupField: treeFieldId,
          RowGroupKeys.kGroupLevel: level,
          RowGroupKeys.kGroupExpanded: expanded,
          RowGroupKeys.kGroupChildCount: _countLeaves(child),
          RowGroupKeys.kGroupNodeId: nodeId,
        });
        if (expanded) {
          _flatten(
            node: child,
            parentId: nodeId,
            level: level + 1,
            state: state,
            result: result,
            typedLeafToMap: typedLeafToMap,
          );
        }
      } else {
        final row = (entry as _Leaf<TData>).row;
        final Map<String, dynamic> displayRow;
        if (row is Map<String, dynamic>) {
          displayRow = row;
        } else if (typedLeafToMap != null) {
          displayRow = typedLeafToMap(row, leafIndex);
        } else {
          // Legacy fallback for typed data without a converter.
          displayRow = <String, dynamic>{};
        }
        // Stamp hierarchy depth on a shallow copy so the painter indents
        // the leaf under its parent node (AG Grid parity); the user's
        // original maps are never mutated.
        result.add({...displayRow, RowGroupKeys.kRowDepth: level});
        leafIndex++;
      }
    }
  }

  /// Counts all leaf rows under [node] (recursively).
  int _countLeaves(_TreeDataNode<TData> node) {
    var count = 0;
    for (final entry in node.entries) {
      if (entry is _SubTree<TData>) {
        count += _countLeaves(entry.node);
      } else {
        count++;
      }
    }
    return count;
  }

  /// Creates a stable node ID for one tree-path segment.
  ///
  /// Delegates to [RowGroupService.makeNodeId] so escaping matches exactly;
  /// [parentId] chains segment IDs so nested paths produce deterministic,
  /// collision-free IDs (segments containing '-' are escaped per level).
  static String makeTreeNodeId(String parentId, Object? segment) =>
      RowGroupService.makeNodeId(parentId, treeFieldId, segment);

  /// Returns the node ID of the deepest group along `path`.
  ///
  /// Useful for tests and API callers that need to address a tree node:
  ///
  /// ```dart
  /// controller.setRowExpanded(
  ///   TreeDataService.makeTreeNodeIdForPath(['A', 'B']),
  ///   expanded: true,
  /// );
  /// ```
  static String makeTreeNodeIdForPath(List<Object?> path) {
    var id = '';
    for (final segment in path) {
      id = makeTreeNodeId(id, segment);
    }
    return id;
  }
}

/// Internal tree node used during tree-data building.
class _TreeDataNode<TData> {
  _TreeDataNode({required this.key});

  /// The path segment value this node represents (`null` on the
  /// synthetic root).
  final Object? key;

  /// Child nodes keyed by their segment value (for identity lookup).
  final Map<Object?, _TreeDataNode<TData>> _childrenByKey = {};

  /// Ordered mix of sub-nodes and leaf rows in first-encounter order.
  final List<_TreeEntry<TData>> entries = [];

  /// Returns the existing child for [segment], creating and registering
  /// it in [entries] when seen for the first time.
  _TreeDataNode<TData> childFor(Object? segment) {
    return _childrenByKey.putIfAbsent(segment, () {
      final child = _TreeDataNode<TData>(key: segment);
      _childrenByKey[segment] = child;
      entries.add(_SubTree<TData>(child));
      return child;
    });
  }
}

/// An entry in a tree node's ordered child list.
sealed class _TreeEntry<TData> {
  const _TreeEntry();
}

/// A synthetic sub-group node.
final class _SubTree<TData> extends _TreeEntry<TData> {
  const _SubTree(this.node);
  final _TreeDataNode<TData> node;
}

/// An original data row kept as a leaf.
final class _Leaf<TData> extends _TreeEntry<TData> {
  const _Leaf(this.row);
  final TData row;
}
