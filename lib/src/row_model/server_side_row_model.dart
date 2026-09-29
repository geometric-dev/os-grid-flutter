import '../columns/os_column_def.dart';
import '../row_grouping/row_group_service.dart' show RowGroupKeys;
import '../row_grouping/row_group_state.dart';
import '../sorting/sort_model.dart';
import 'server_side_datasource.dart';

/// The loading state of a server-side cache block.
enum ServerSideBlockState {
  /// The block has not been requested yet.
  empty,

  /// The block is currently being loaded from the datasource.
  loading,

  /// The block has been successfully loaded.
  loaded,

  /// The block request failed.
  ///
  /// Failed blocks are not retried automatically; use
  /// [ServerSideRowModel.refresh] (exposed as
  /// `OsGridController.refreshServerSide`) to re-request them.
  failed,
}

/// A single block (page) of children at one group level.
class ServerSideBlock<TData> {
  ServerSideBlock({required this.startRow, required this.endRow});

  /// The first child index in this block (inclusive).
  final int startRow;

  /// The last child index in this block (exclusive).
  final int endRow;

  /// The current state of this block.
  ServerSideBlockState state = ServerSideBlockState.empty;

  /// The loaded children (null until loaded).
  List<OsServerSideGroupChild>? children;

  /// Timestamp of last access (for LRU eviction).
  int lastAccessTime = 0;
}

/// The block cache for a single group level.
class _LevelCache<TData> {
  _LevelCache({
    required this.groupKeys,
    required int initialRowCount,
    int? seedRowCount,
  }) : virtualRowCount = seedRowCount ?? initialRowCount;

  /// The group keys path identifying this level (empty for the root).
  final List<String> groupKeys;

  /// Blocks at this level, keyed by their start row.
  final Map<int, ServerSideBlock<TData>> blocks = {};

  /// The exact total child count once known, otherwise null.
  int? lastRow;

  /// The virtual child count used for display iteration.
  int virtualRowCount;
}

/// Server-side row model (SSRM).
///
/// A lazy-loading row model where the server performs sorting, filtering
/// and grouping. The grid requests blocks of children at each group level
/// (identified by the path of group keys) as the user scrolls and expands
/// groups.
///
/// Structure:
///
/// - **Level tree**: each distinct `List<String>` group-keys path has its
///   own block cache and virtual row count. Levels are created lazily —
///   the root on first walk, child levels when a group expands (seeded
///   with the server-reported child count).
/// - **Block cache per level**: blocks keyed by start row, deduplicated
///   while in flight (a block is never requested twice concurrently) and
///   LRU-evicted when [maxBlocksInCache] is set.
/// - **Expansion state**: reuses [RowGroupState] (typically the same
///   instance the grid mutates when the user taps a group row).
///
/// Requests are viewport-driven: [buildDisplayRows] never triggers
/// fetches; the host calls [requestVisibleRows] (e.g. on scroll and after
/// the first frame) to load the blocks covering the visible display rows.
///
/// ```dart
/// final model = ServerSideRowModel<Map<String, dynamic>>(
///   datasource: MyServer(),
///   rowGroupState: gridRowGroupState,
///   cacheBlockSize: 100,
///   onCacheChanged: () => setState(() {}),
/// );
/// ```
class ServerSideRowModel<TData> {
  ServerSideRowModel({
    required this.datasource,
    RowGroupState? rowGroupState,
    this.cacheBlockSize = 100,
    this.maxBlocksInCache,
    this.initialRowCount = 1,
    this.onCacheChanged,
  }) : _rowGroupState = rowGroupState ?? RowGroupState(),
       assert(cacheBlockSize > 0, 'cacheBlockSize must be positive'),
       assert(
         maxBlocksInCache == null || maxBlocksInCache > 0,
         'maxBlocksInCache must be positive or null (unlimited)',
       ),
       assert(initialRowCount >= 0, 'initialRowCount must be non-negative');

  /// The datasource to fetch level blocks from.
  final OsServerSideDatasource<TData> datasource;

  /// Expansion state for group nodes. Defaults to a private instance;
  /// the grid shares its own instance so group taps drive this model.
  final RowGroupState _rowGroupState;

  /// Number of children per block/page fetched from the datasource.
  final int cacheBlockSize;

  /// Maximum number of blocks kept per level (LRU eviction).
  ///
  /// When `null`, all loaded blocks are kept indefinitely.
  final int? maxBlocksInCache;

  /// Virtual child count used for a level until the datasource reports
  /// the actual count (via `lastRow` or a short block).
  final int initialRowCount;

  /// Called whenever cached data or a row count changes (triggers repaint).
  final void Function()? onCacheChanged;

  /// Level caches keyed by [levelKey].
  final Map<String, _LevelCache<TData>> _levels = {};

  /// Current sort model (passed to the datasource on every request).
  List<OsSortModel>? _sortModel;

  /// Current filter model (passed to the datasource on every request).
  Map<String, dynamic>? _filterModel;

  /// Generation counter, incremented on [purge]/[refresh]/model updates.
  /// Datasource completions capture the generation at request time so
  /// stale completions from before a purge are ignored.
  int _generation = 0;

  /// Monotonically increasing access counter for LRU tracking.
  int _accessCounter = 0;

  /// Whether the model has been disposed.
  bool _disposed = false;

  /// Separator used to build level map keys from group-key paths.
  static const String _levelKeySeparator = '\u001f';

  /// Builds the stable node ID for the group whose key path is [path].
  ///
  /// IDs only need to be unique and stable within this model; they are
  /// echoed back by the grid's group-tap handler.
  static String nodeIdForPath(List<String> path) =>
      path.isEmpty ? 'row-group' : ['row-group', ...path].join('-');

  /// Builds a map key for a group-keys path.
  static String levelKey(List<String> groupKeys) =>
      groupKeys.join(_levelKeySeparator);

  /// Whether any block at any level is currently being loaded.
  bool get isAnyBlockLoading => _levels.values.any(
    (level) =>
        level.blocks.values.any((b) => b.state == ServerSideBlockState.loading),
  );

  // --- Cache management ---

  /// Update the sort model and purge all levels.
  void setSortModel(List<OsSortModel>? sortModel) {
    _sortModel = sortModel;
    purge();
  }

  /// Update the filter model and purge all levels.
  void setFilterModel(Map<String, dynamic>? filterModel) {
    _filterModel = filterModel;
    purge();
  }

  /// Discard all cached levels and reset state.
  void purge() {
    _levels.clear();
    _generation++;
    onCacheChanged?.call();
  }

  /// Refresh the cache for one level (and all deeper levels), or all
  /// levels when [groupKeys] is null or empty.
  ///
  /// Child levels are discarded together with their parent because the
  /// refreshed parent data may regroup into different children.
  void refresh({List<String>? groupKeys}) {
    if (groupKeys == null || groupKeys.isEmpty) {
      purge();
      return;
    }
    final prefix = levelKey(groupKeys);
    _generation++;
    _levels.removeWhere(
      (key, _) => key == prefix || key.startsWith('$prefix$_levelKeySeparator'),
    );
    onCacheChanged?.call();
  }

  /// The virtual row count at the level identified by [groupKeys]
  /// (the root level when empty).
  int getVirtualRowCount(List<String> groupKeys) =>
      _levels[levelKey(groupKeys)]?.virtualRowCount ?? initialRowCount;

  /// The root level's virtual row count.
  int getRootVirtualRowCount() => getVirtualRowCount(const []);

  /// The total number of display rows (group rows, leaf rows and loading
  /// placeholders) given the current caches and expansion state.
  int get displayRowCount =>
      _walk(groupKeys: const [], level: 0, displayOffset: 0);

  /// Requests the blocks covering display rows [firstDisplayRow]..
  /// [lastDisplayRow] (inclusive).
  ///
  /// Called by the host when the scroll position changes and once after
  /// the first frame. Blocks are deduplicated: one already loading or
  /// loaded is never requested again.
  void requestVisibleRows(int firstDisplayRow, int lastDisplayRow) {
    if (_disposed || lastDisplayRow < firstDisplayRow) return;
    _walk(
      groupKeys: const [],
      level: 0,
      displayOffset: 0,
      visibleRange: (firstDisplayRow, lastDisplayRow),
    );
  }

  /// Builds the flattened display rows for the painter.
  ///
  /// Walks the level tree: group children become synthetic group-row maps
  /// (using [RowGroupKeys] metadata, expansion resolved from the shared
  /// [RowGroupState]); leaf children are mapped through [leafToMap];
  /// children whose blocks are not loaded yet become loading
  /// placeholders.
  ///
  /// This never triggers datasource fetches — see [requestVisibleRows].
  List<Map<String, dynamic>> buildDisplayRows({
    required List<OsColumnDef> groupColumns,
    Map<String, dynamic> Function(TData row, int index)? leafToMap,
  }) {
    if (_disposed) return const [];
    final out = <Map<String, dynamic>>[];
    _walk(
      groupKeys: const [],
      level: 0,
      displayOffset: 0,
      materialize: true,
      out: out,
      groupColumns: groupColumns,
      leafToMap: leafToMap,
    );
    return out;
  }

  /// Dispose the model and clean up resources.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _levels.clear();
    datasource.destroy();
  }

  // --- Level walk ---

  /// Walks the level tree rooted at [groupKeys].
  ///
  /// Returns the number of display rows in the subtree. When [materialize]
  /// is true, appends the display rows to [out]. When [visibleRange] is
  /// given (display-row coordinates), blocks covering rows in the range
  /// are requested; entries outside the range are read from cache without
  /// triggering requests.
  int _walk({
    required List<String> groupKeys,
    required int level,
    required int displayOffset,
    (int, int)? visibleRange,
    bool materialize = false,
    List<Map<String, dynamic>>? out,
    List<OsColumnDef>? groupColumns,
    Map<String, dynamic> Function(TData row, int index)? leafToMap,
    int? seedRowCount,
  }) {
    final cache = _levelFor(groupKeys, seedRowCount: seedRowCount);
    var count = 0;

    for (int i = 0; i < cache.virtualRowCount; i++) {
      final displayIndex = displayOffset + count;
      final isVisible =
          visibleRange != null &&
          displayIndex >= visibleRange.$1 &&
          displayIndex <= visibleRange.$2;

      final child = isVisible && !materialize
          ? _getChild(cache, groupKeys, i)
          : _peekChild(cache, i);

      if (child == null) {
        if (materialize) out!.add(const {'__loading__': true});
        count++;
        continue;
      }

      if (child is OsServerSideGroupChildLeaf<TData>) {
        if (materialize) {
          final row = child.data;
          final Map<String, dynamic> displayRow;
          if (row is Map<String, dynamic>) {
            displayRow = row;
          } else {
            displayRow = leafToMap?.call(row, i) ?? <String, dynamic>{};
          }
          // Stamp hierarchy depth on a shallow copy so the painter indents
          // the leaf under its parent group (AG Grid parity).
          out!.add(
            level > 0
                ? {...displayRow, RowGroupKeys.kRowDepth: level + 1}
                : displayRow,
          );
        }
        count++;
        continue;
      }

      final group = child as OsServerSideGroupChildGroup;
      final childKeys = [...groupKeys, group.key];
      final nodeId = nodeIdForPath(childKeys);
      final expanded = _rowGroupState.isExpanded(nodeId, level: level);

      if (materialize) {
        out!.add({
          RowGroupKeys.kIsGroupRow: true,
          RowGroupKeys.kGroupKey: group.key,
          RowGroupKeys.kGroupField: level < (groupColumns?.length ?? 0)
              ? groupColumns![level].effectiveColId
              : '',
          RowGroupKeys.kGroupLevel: level,
          RowGroupKeys.kGroupExpanded: expanded,
          RowGroupKeys.kGroupChildCount: group.childCount,
          RowGroupKeys.kGroupNodeId: nodeId,
        });
      }
      count++;

      if (expanded) {
        count += _walk(
          groupKeys: childKeys,
          level: level + 1,
          displayOffset: displayOffset + count,
          visibleRange: visibleRange,
          materialize: materialize,
          out: out,
          groupColumns: groupColumns,
          leafToMap: leafToMap,
          seedRowCount: group.childCount,
        );
      }
    }
    return count;
  }

  // --- Block loading ---

  _LevelCache<TData> _levelFor(List<String> groupKeys, {int? seedRowCount}) {
    final key = levelKey(groupKeys);
    return _levels.putIfAbsent(
      key,
      () => _LevelCache<TData>(
        groupKeys: List.unmodifiable(groupKeys),
        initialRowCount: initialRowCount,
        seedRowCount: seedRowCount,
      ),
    );
  }

  /// Returns the child at [index] in [cache], requesting its block when
  /// missing. Returns null while the block is loading/failed/short.
  OsServerSideGroupChild? _getChild(
    _LevelCache<TData> cache,
    List<String> groupKeys,
    int index,
  ) {
    var block = _blockAt(cache, index);
    if (block == null) {
      _ensureBlock(cache, groupKeys, index ~/ cacheBlockSize);
      // A synchronous datasource may have completed the block during the
      // dispatch — re-read so the walk can recurse into fresh data.
      block = _blockAt(cache, index);
      if (block == null) return null;
    }

    if (block.state == ServerSideBlockState.loaded) {
      block.lastAccessTime = ++_accessCounter;
      final localIndex = index - block.startRow;
      final children = block.children;
      if (children != null && localIndex < children.length) {
        return children[localIndex];
      }
    }

    return null;
  }

  /// Returns the child at [index] in [cache] without triggering requests.
  OsServerSideGroupChild? _peekChild(_LevelCache<TData> cache, int index) {
    final block = _blockAt(cache, index);
    if (block == null || block.state != ServerSideBlockState.loaded) {
      return null;
    }
    final localIndex = index - block.startRow;
    final children = block.children;
    if (children != null && localIndex < children.length) {
      return children[localIndex];
    }
    return null;
  }

  /// The block containing [index], or null when not present in the cache.
  ServerSideBlock<TData>? _blockAt(_LevelCache<TData> cache, int index) {
    final startRow = (index ~/ cacheBlockSize) * cacheBlockSize;
    return cache.blocks[startRow];
  }

  /// Ensures the block containing the given child index is requested.
  void _ensureBlock(
    _LevelCache<TData> cache,
    List<String> groupKeys,
    int blockNumber,
  ) {
    if (_disposed) return;

    final startRow = blockNumber * cacheBlockSize;

    // Don't request blocks beyond the level's known row count.
    final lastRow = cache.lastRow;
    if (lastRow != null && startRow >= lastRow) return;

    final existing = cache.blocks[startRow];
    if (existing != null &&
        (existing.state == ServerSideBlockState.loading ||
            existing.state == ServerSideBlockState.loaded)) {
      // Dedup: already loading or loaded — never request twice.
      if (existing.state == ServerSideBlockState.loaded) {
        existing.lastAccessTime = ++_accessCounter;
      }
      return;
    }
    // Failed blocks are only retried via an explicit refresh to avoid
    // request storms when the datasource keeps failing.

    final block = ServerSideBlock<TData>(
      startRow: startRow,
      endRow: lastRow != null
          ? (startRow + cacheBlockSize).clamp(0, lastRow)
          : startRow + cacheBlockSize,
    )..state = ServerSideBlockState.loading;
    cache.blocks[startRow] = block;

    _dispatchRequest(cache, block);
  }

  /// Sends the datasource request for [block], completing synchronously
  /// when the datasource returns children directly.
  void _dispatchRequest(
    _LevelCache<TData> cache,
    ServerSideBlock<TData> block,
  ) {
    final generation = _generation;
    final groupKeys = cache.groupKeys;
    final params = ServerSideGetRowsParams<TData>(
      startRow: block.startRow,
      endRow: block.endRow,
      groupKeys: groupKeys,
      sortModel: _sortModel,
      filterModel: _filterModel,
      successCallback: (children, {int? lastRow}) {
        _onBlockSuccess(cache, block, children, lastRow, generation);
      },
      failCallback: () => _onBlockFailed(cache, block, generation),
    );

    final syncChildren = datasource.getRows(params);

    // Synchronous datasource contract: a non-empty return value completes
    // the request immediately. If the datasource already called the
    // success callback synchronously, the block is no longer loading and
    // this is a no-op.
    if (syncChildren.isNotEmpty &&
        generation == _generation &&
        block.state == ServerSideBlockState.loading) {
      _onBlockSuccess(cache, block, syncChildren, null, generation);
    }
  }

  void _onBlockSuccess(
    _LevelCache<TData> cache,
    ServerSideBlock<TData> block,
    List<OsServerSideGroupChild> children,
    int? lastRow,
    int generation,
  ) {
    if (_disposed || generation != _generation) return;
    if (cache.blocks[block.startRow] != block) return;
    if (block.state != ServerSideBlockState.loading) return;

    block.children = children;
    block.state = ServerSideBlockState.loaded;
    block.lastAccessTime = ++_accessCounter;
    _evictIfNeeded(cache);

    if (lastRow != null) {
      cache.lastRow = lastRow;
      cache.virtualRowCount = lastRow;
    } else if (children.length < cacheBlockSize) {
      // Fewer children than the block size means we reached the end.
      final actualLastRow = block.startRow + children.length;
      cache.lastRow = actualLastRow;
      cache.virtualRowCount = actualLastRow;
    } else {
      // More data may exist — expand the virtual count if needed.
      final blockEnd = block.startRow + children.length;
      if (blockEnd >= cache.virtualRowCount) {
        cache.virtualRowCount = blockEnd + cacheBlockSize;
      }
    }

    onCacheChanged?.call();
  }

  void _onBlockFailed(
    _LevelCache<TData> cache,
    ServerSideBlock<TData> block,
    int generation,
  ) {
    if (_disposed || generation != _generation) return;
    if (cache.blocks[block.startRow] != block) return;
    if (block.state != ServerSideBlockState.loading) return;

    block.state = ServerSideBlockState.failed;
    block.children = null;
    onCacheChanged?.call();
  }

  /// Evicts the least recently used loaded block in [cache] when the
  /// level exceeds [maxBlocksInCache].
  void _evictIfNeeded(_LevelCache<TData> cache) {
    final maxBlocks = maxBlocksInCache;
    if (maxBlocks == null) return;

    while (cache.blocks.length > maxBlocks) {
      int? lruStartRow;
      var lruTime = _accessCounter + 1;
      for (final entry in cache.blocks.entries) {
        if (entry.value.state == ServerSideBlockState.loading) continue;
        if (entry.value.lastAccessTime < lruTime) {
          lruTime = entry.value.lastAccessTime;
          lruStartRow = entry.key;
        }
      }
      if (lruStartRow == null) break;
      cache.blocks.remove(lruStartRow);
    }
  }
}
