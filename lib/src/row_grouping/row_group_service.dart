import '../aggregation/aggregation_service.dart';
import '../columns/os_column_def.dart';
import '../utils/grid_diagnostics.dart';
import 'row_group_state.dart';

/// Keys used to identify group row metadata in Map-based display data.
///
/// Group rows are represented as `Map<String, dynamic>` with these
/// special keys. Regular data rows do not have `kIsGroupRow` set.
class RowGroupKeys {
  RowGroupKeys._();

  /// Whether this map represents a group row (always `true` on group rows).
  static const String kIsGroupRow = '__isGroupRow';

  /// The group key value (the common value of the grouped column).
  static const String kGroupKey = '__groupKey';

  /// The column field (or colId) used for grouping at this level.
  static const String kGroupField = '__groupField';

  /// The nesting level (0 = top-level group).
  static const String kGroupLevel = '__groupLevel';

  /// Whether the group is currently expanded.
  static const String kGroupExpanded = '__groupExpanded';

  /// Number of leaf rows in this group (direct + nested descendants).
  static const String kGroupChildCount = '__groupChildCount';

  /// Stable node ID for this group row.
  static const String kGroupNodeId = '__groupNodeId';

  /// Aggregate data for this group row.
  ///
  /// Value is a `Map<String, dynamic>` keyed by column field/colId,
  /// with the computed aggregate value for each value column.
  static const String kGroupAggData = '__groupAggData';

  /// Hierarchy depth of a LEAF row (0 = top level, no indent).
  ///
  /// Stamped on leaf display rows under row grouping / tree data / the
  /// server-side row model so the painter can indent the row's first
  /// content cell to match AG Grid's tree indentation. Only present when
  /// the depth is > 0; regular flat data never carries it.
  static const String kRowDepth = '__rowDepth';
}

/// Service that builds a grouped and flattened display list from sorted/filtered data.
///
/// The grouping pipeline:
/// 1. Identify group columns (from colDef.rowGroup or programmatic groupBy)
/// 2. Build a tree: for each leaf row, traverse group columns and create/find groups
/// 3. Flatten the tree respecting expansion state into a display list
///
/// The output is a `List<Map<String, dynamic>>` where each entry is either
/// a group row (with `__isGroupRow: true` and metadata) or an original data row.
class RowGroupService<TData> {
  /// Builds the grouped and flattened display list.
  ///
  /// [data] — the sorted/filtered flat data.
  /// [groupColumns] — ordered list of column definitions to group by.
  /// [state] — the current expansion state.
  /// [valueColumns] — columns with aggFunc set (for aggregation).
  ///
  /// Returns a list of maps representing the flattened display. Group rows
  /// are injected as synthetic maps. Leaf rows are cast to `Map<String, dynamic>`.
  ///
  /// If [groupColumns] is empty, returns the data unchanged (no grouping).
  ///
  /// [typedLeafToMap] converts non-Map (typed) leaf rows into display maps
  /// via their columns' valueGetters. When null, typed leaves fall back to
  /// empty maps (legacy behaviour).
  List<Map<String, dynamic>> buildGroupedData({
    required List<TData> data,
    required List<OsColumnDef> groupColumns,
    required RowGroupState state,
    List<OsColumnDef> valueColumns = const [],
    Map<String, dynamic> Function(TData row, int index)? typedLeafToMap,
  }) {
    if (groupColumns.isEmpty) {
      return [
        for (int i = 0; i < data.length; i++)
          if (data[i] is Map<String, dynamic>)
            data[i] as Map<String, dynamic>
          else if (typedLeafToMap != null)
            typedLeafToMap(data[i], i)
          else
            <String, dynamic>{},
      ];
    }

    // Build the tree structure.
    final tree = _buildTree(data, groupColumns);

    // Flatten the tree respecting expansion state.
    final result = <Map<String, dynamic>>[];
    _flattenTree(
      tree: tree,
      groupColumns: groupColumns,
      state: state,
      result: result,
      level: 0,
      parentId: '',
      valueColumns: valueColumns,
      typedLeafToMap: typedLeafToMap,
    );

    return result;
  }

  /// Returns the total count of visible rows (groups + visible leaves)
  /// given the current expansion state. Useful for pagination.
  int countVisibleRows({
    required List<TData> data,
    required List<OsColumnDef> groupColumns,
    required RowGroupState state,
  }) {
    if (groupColumns.isEmpty) return data.length;
    final tree = _buildTree(data, groupColumns);
    return _countVisible(
      tree: tree,
      groupColumns: groupColumns,
      state: state,
      level: 0,
      parentId: '',
    );
  }

  /// Builds a hierarchical tree from the flat data.
  ///
  /// Returns a list of [_GroupTreeNode] at the top level (grouped by the first
  /// group column). Each node may have child groups (for multi-level grouping)
  /// or leaf rows.
  List<_GroupTreeNode<TData>> _buildTree(
    List<TData> data,
    List<OsColumnDef> groupColumns,
  ) {
    final firstCol = groupColumns.first;
    final topLevelGroups = <dynamic, _GroupTreeNode<TData>>{};

    for (final row in data) {
      final key = _extractGroupKey(row, firstCol);
      final group = topLevelGroups.putIfAbsent(
        key,
        () => _GroupTreeNode<TData>(key: key, field: firstCol.effectiveColId),
      );
      group.leafRows.add(row);
    }

    // For multi-level grouping, recursively build sub-groups.
    if (groupColumns.length > 1) {
      final subColumns = groupColumns.sublist(1);
      for (final group in topLevelGroups.values) {
        group.children = _buildSubTree(group.leafRows, subColumns);
        // Clear leaf rows at non-leaf levels — they live in children.
        group.leafRows = [];
      }
    }

    return topLevelGroups.values.toList();
  }

  /// Recursively builds sub-groups for multi-level grouping.
  List<_GroupTreeNode<TData>> _buildSubTree(
    List<TData> data,
    List<OsColumnDef> groupColumns,
  ) {
    final col = groupColumns.first;
    final groups = <dynamic, _GroupTreeNode<TData>>{};

    for (final row in data) {
      final key = _extractGroupKey(row, col);
      final group = groups.putIfAbsent(
        key,
        () => _GroupTreeNode<TData>(key: key, field: col.effectiveColId),
      );
      group.leafRows.add(row);
    }

    if (groupColumns.length > 1) {
      final subColumns = groupColumns.sublist(1);
      for (final group in groups.values) {
        group.children = _buildSubTree(group.leafRows, subColumns);
        group.leafRows = [];
      }
    }

    return groups.values.toList();
  }

  /// Flattens the tree into a display list, respecting expansion state.
  void _flattenTree({
    required List<_GroupTreeNode<TData>> tree,
    required List<OsColumnDef> groupColumns,
    required RowGroupState state,
    Map<String, dynamic> Function(TData row, int index)? typedLeafToMap,
    required List<Map<String, dynamic>> result,
    required int level,
    required String parentId,
    List<OsColumnDef> valueColumns = const [],
  }) {
    final hasAggregation = valueColumns.isNotEmpty;
    final aggService = hasAggregation ? AggregationService<TData>() : null;

    for (final node in tree) {
      final nodeId = makeNodeId(parentId, node.field, node.key);
      final childCount = _countLeaves(node);
      final expanded = state.isExpanded(nodeId, level: level);

      // Compute aggregate data for this group node.
      Map<String, dynamic>? aggData;
      if (hasAggregation) {
        final allLeaves = _collectAllLeaves(node);
        aggData = aggService!.computeGroupAggregates(
          leafRows: allLeaves,
          valueColumns: valueColumns,
        );
      }

      // Add the group row.
      final groupRow = <String, dynamic>{
        RowGroupKeys.kIsGroupRow: true,
        RowGroupKeys.kGroupKey: node.key,
        RowGroupKeys.kGroupField: node.field,
        RowGroupKeys.kGroupLevel: level,
        RowGroupKeys.kGroupExpanded: expanded,
        RowGroupKeys.kGroupChildCount: childCount,
        RowGroupKeys.kGroupNodeId: nodeId,
      };
      if (aggData != null) {
        groupRow[RowGroupKeys.kGroupAggData] = aggData;
      }
      result.add(groupRow);

      // If expanded, add children.
      if (expanded) {
        if (node.children.isNotEmpty) {
          _flattenTree(
            tree: node.children,
            groupColumns: groupColumns,
            state: state,
            result: result,
            level: level + 1,
            parentId: nodeId,
            valueColumns: valueColumns,
            typedLeafToMap: typedLeafToMap,
          );
        } else {
          // Leaf level — add the actual data rows. Leaves are shallow
          // copies stamped with their hierarchy depth so the painter can
          // indent them under their parent group (AG Grid parity); the
          // user's original maps are never mutated.
          var leafIndex = 0;
          for (final row in node.leafRows) {
            final Map<String, dynamic> displayRow;
            if (row is Map<String, dynamic>) {
              displayRow = row;
            } else if (typedLeafToMap != null) {
              displayRow = typedLeafToMap(row, leafIndex);
            } else {
              // Legacy fallback for typed data without a converter.
              displayRow = <String, dynamic>{};
            }
            result.add({...displayRow, RowGroupKeys.kRowDepth: level + 1});
            leafIndex++;
          }
        }
      }
    }
  }

  /// Counts visible rows without building the full result list.
  int _countVisible({
    required List<_GroupTreeNode<TData>> tree,
    required List<OsColumnDef> groupColumns,
    required RowGroupState state,
    required int level,
    required String parentId,
  }) {
    var count = 0;
    for (final node in tree) {
      count++; // The group row itself.
      final nodeId = makeNodeId(parentId, node.field, node.key);
      final expanded = state.isExpanded(nodeId, level: level);

      if (expanded) {
        if (node.children.isNotEmpty) {
          count += _countVisible(
            tree: node.children,
            groupColumns: groupColumns,
            state: state,
            level: level + 1,
            parentId: nodeId,
          );
        } else {
          count += node.leafRows.length;
        }
      }
    }
    return count;
  }

  /// Counts all leaf rows under a node (recursively).
  int _countLeaves(_GroupTreeNode<TData> node) {
    if (node.children.isEmpty) return node.leafRows.length;
    var count = 0;
    for (final child in node.children) {
      count += _countLeaves(child);
    }
    return count;
  }

  /// Collects all leaf rows under a node (recursively).
  ///
  /// Used by the aggregation service to compute aggregates across
  /// all descendants of a group, regardless of expansion state.
  List<TData> _collectAllLeaves(_GroupTreeNode<TData> node) {
    if (node.children.isEmpty) return node.leafRows;
    final result = <TData>[];
    for (final child in node.children) {
      result.addAll(_collectAllLeaves(child));
    }
    return result;
  }

  /// Extracts the group key value from a row for a given column.
  dynamic _extractGroupKey(TData row, OsColumnDef col) {
    if (row is Map<String, dynamic>) {
      final field = col.field;
      if (field != null) return row[field];
    }
    // For typed data, try the valueGetter.
    final getter = col.getValueGetterAsFunction();
    if (getter != null) {
      // We don't have a proper ValueGetterParams here, so we try a
      // simplified approach — this works for the common case.
      try {
        return Function.apply(getter, [
          _SimpleValueGetterParams(data: row, rowIndex: 0),
        ]);
      } catch (e) {
        GridDiagnostics.warnOnce(
          'rowGroup:groupKey',
          'valueGetter threw while extracting the group key for column '
              '"${col.effectiveColId}"; group key will be null: $e',
        );
        return null;
      }
    }
    return null;
  }

  /// Creates a stable node ID for a group.
  ///
  /// Public so other services that must address group rows by node ID
  /// (e.g. pivot bucket building) construct IDs with the exact same
  /// scheme as this service. Each segment has its dashes escaped so keys
  /// containing '-' cannot collide across levels; dash-free inputs produce
  /// identical IDs to the original scheme.
  static String makeNodeId(String parentId, String field, dynamic key) {
    final keyStr = key?.toString() ?? '__null__';
    final f = _escapeSegment(field);
    final k = _escapeSegment(keyStr);
    if (parentId.isEmpty) {
      return 'row-group-$f-$k';
    }
    return '$parentId-$f-$k';
  }

  static String _escapeSegment(String segment) => segment.replaceAll('-', '--');
}

/// Internal tree node used during group building.
class _GroupTreeNode<TData> {
  _GroupTreeNode({required this.key, required this.field});

  /// The group key value.
  final dynamic key;

  /// The column field this group is based on.
  final String field;

  /// Sub-groups (for multi-level grouping).
  List<_GroupTreeNode<TData>> children = [];

  /// Leaf data rows (only populated at the deepest group level).
  List<TData> leafRows = [];
}

/// Minimal params object for value getter invocation during grouping.
class _SimpleValueGetterParams<TData> {
  const _SimpleValueGetterParams({required this.data, required this.rowIndex});
  final TData data;
  final int rowIndex;
}
