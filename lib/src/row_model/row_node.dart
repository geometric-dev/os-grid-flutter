/// Represents a single row in the grid's internal model.
///
/// Wraps the user-provided data with grid state (selection, display index,
/// grouping flags, etc.) and carries a stable [id] used for transaction
/// updates and selection that survives sorts and filters.
///
/// Node instances are owned by `OsGridController` and reused across data
/// updates: a row whose ID survives a `setRowData`/transaction keeps the
/// same [OsRowNode] instance while its [data] reference is refreshed.
///
/// ## Retention contract
///
/// [OsRowNode] instances are plain GC-managed objects — there is no object
/// pool that keeps nodes alive independently of the data. Retention works
/// as follows:
///
/// * The controller's internal `_nodesById` map is the node pool and holds
///   the ONLY long-lived strong reference to every live node. The ordered
///   node lists (`_rawNodes`, `_renderedNodes`) are views over the same
///   nodes, rebuilt atomically with the map on every rebuild — they never
///   outlive the map that owns their nodes.
/// * A node is kept alive from its first appearance until its row ID no
///   longer appears in the dataset — i.e. the row is removed via
///   `applyTransaction`, or the entire dataset is replaced via
///   `setRowData` with data that does not contain that ID. Dropped nodes
///   are removed from the map during the same rebuild pass and are
///   immediately GC-eligible; the rebuild's transient `previousById`
///   snapshot does not outlive the call.
/// * Nothing else in the library retains node instances: selection is
///   tracked by ID string, and the derived-state caches (ValueCache,
///   quick-filter text cache, undo/redo stacks) hold row data values and
///   row IDs, never [OsRowNode]s.
///
/// Consequence for hosts: if you observe a suspected node leak, the only
/// place to look is the controller's `_nodesById` map — its size is the
/// live node count (surfaced as `nodePoolSize` for tests).
class OsRowNode<TData> {
  OsRowNode({
    required this.data,
    required this.id,
    this.rowIndex = -1,
    this.selected = false,
    this.height,
    this.group = false,
    this.groupKey,
  });

  /// Creates a node for [data], deriving the stable [id] from [getRowId]
  /// when provided, falling back to the object's identity hash code.
  factory OsRowNode.fromData(
    TData data, {
    String Function(TData data)? getRowId,
    int rowIndex = -1,
    bool selected = false,
  }) {
    return OsRowNode<TData>(
      data: data,
      id: getRowId?.call(data) ?? identityHashCode(data).toString(),
      rowIndex: rowIndex,
      selected: selected,
    );
  }

  /// The user-provided data for this row.
  ///
  /// Mutable so the controller can refresh the data reference on an
  /// existing node when the underlying row object is replaced while the
  /// row ID survives (e.g. transaction updates, immutable data).
  TData data;

  /// Unique identifier for this row.
  ///
  /// Derived from the grid's `getRowId` callback, falling back to the row
  /// object's hash-based identity. Used for transaction updates and stable
  /// selection across sorts.
  final String id;

  /// The display index of this row (after sorting/filtering), or `-1` if
  /// the row is not currently displayed (filtered out or not yet synced).
  int rowIndex;

  /// Whether this row is currently selected.
  bool selected;

  /// The resolved height of this row in logical pixels, or `null` when the
  /// theme/default row height applies.
  double? height;

  /// Whether this row is a group header row (row grouping / tree data).
  bool group;

  /// The key this group node aggregates over, or `null` for leaf rows.
  Object? groupKey;

  @override
  String toString() =>
      'OsRowNode(id: $id, index: $rowIndex, selected: $selected)';
}
