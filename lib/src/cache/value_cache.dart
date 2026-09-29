import 'package:os_grid_flutter/os_grid_flutter.dart'
    show OsColumnDef, OsGridController, TextPainterCache;

/// A cache for computed cell values (valueGetter results).
///
/// When `valueCacheEnabled` is `true` on the grid, this cache stores the
/// results of [OsColumnDef.valueGetter] calls keyed by (rowId, colId).
/// Subsequent lookups for the same cell return the cached value instead
/// of re-executing the valueGetter.
///
/// The primary benefit in a canvas-based grid is avoiding redundant
/// valueGetter calls during sort comparisons and filter evaluations,
/// where the same cell value may be requested multiple times in a
/// single processing pass.
///
/// The cache is invalidated (cleared) on any data change:
/// - [OsGridController.setRowData]
/// - [OsGridController.applyTransaction]
/// - Column definition changes
/// - Sort/filter reprocessing
/// - Manual expiry via [OsGridController.expireValueCache]
///
/// ## Memory bounding
///
/// Without a cap the cache grows without bound: a grid with 100k rows and
/// 100 columns has 10M cells, so a fully-populated cache could hold 10M
/// entries. To bound memory usage, [maxEntries] (default 10,000) limits the
/// number of cached cell values. When an insert pushes the cache past the
/// limit, the oldest ~10% of entries are evicted (insertion order, same
/// strategy as [TextPainterCache]). There is no behaviour change while the
/// cache stays under the limit; exceeding it only trades cache hits for a
/// hard memory ceiling.
class ValueCache {
  /// Creates a value cache with an optional entry cap.
  ///
  /// [maxEntries] is the maximum number of cached cell values retained
  /// before oldest-first eviction kicks in. Defaults to 10,000.
  ValueCache({this.maxEntries = 10000})
    : assert(maxEntries > 0, 'maxEntries must be positive');

  /// The maximum number of cached cell values retained before the oldest
  /// ~10% of entries are evicted.
  final int maxEntries;

  /// The cache storage.
  ///
  /// Outer key: row ID (stable identity from `getRowId`, or index-based fallback).
  /// Inner key: column ID (from `effectiveColId`).
  /// Value: the cached valueGetter result.
  ///
  /// Both levels are insertion-ordered maps, which drives the
  /// oldest-first eviction order.
  final Map<String, Map<String, dynamic>> _cache = {};

  /// Total number of cached cell values, maintained incrementally so the
  /// eviction check on insert is O(1).
  int _entryCount = 0;

  /// Whether the cache is currently active (has any entries).
  bool get isActive => _cache.isNotEmpty;

  /// The number of rows with cached values.
  int get rowCount => _cache.length;

  /// The total number of cached cell values across all rows.
  ///
  /// Equivalent to [length], but computed by traversal (O(rows)).
  /// Prefer [length] for hot paths.
  int get cellCount {
    int count = 0;
    for (final row in _cache.values) {
      count += row.length;
    }
    return count;
  }

  /// The total number of cached cell values across all rows.
  ///
  /// Maintained incrementally (O(1)); useful for tests and debugging the
  /// [maxEntries] bound.
  int get length => _entryCount;

  /// Retrieves a cached value for the given [rowId] and [colId].
  ///
  /// Returns the sentinel [notCached] if no cached value exists.
  /// Use [hasValue] to distinguish a cached `null` from a cache miss.
  dynamic getValue(String rowId, String colId) {
    final row = _cache[rowId];
    if (row == null) return notCached;
    if (!row.containsKey(colId)) return notCached;
    return row[colId];
  }

  /// Returns `true` if a cached value exists for the given cell.
  bool hasValue(String rowId, String colId) {
    final row = _cache[rowId];
    if (row == null) return false;
    return row.containsKey(colId);
  }

  /// Stores a value in the cache for the given [rowId] and [colId].
  ///
  /// If this insert pushes the cache past [maxEntries], the oldest ~10% of
  /// entries are evicted before returning. Overwriting an existing cell
  /// never triggers eviction and does not change its eviction order.
  void setValue(String rowId, String colId, dynamic value) {
    final row = _cache.putIfAbsent(rowId, () => {});
    if (row.containsKey(colId)) {
      row[colId] = value;
      return;
    }
    row[colId] = value;
    _entryCount++;
    _evictIfNeeded();
  }

  /// Clears the entire cache.
  ///
  /// Called on data changes (setRowData, applyTransaction, sort, filter)
  /// and when [OsGridController.expireValueCache] is invoked.
  ///
  /// Evicts every entry regardless of how many are cached.
  void expire() {
    _cache.clear();
    _entryCount = 0;
  }

  /// Clears cached values for a specific row.
  ///
  /// Useful for targeted invalidation after a single-row update.
  void expireRow(String rowId) {
    final removed = _cache.remove(rowId);
    if (removed != null) {
      _entryCount -= removed.length;
    }
  }

  /// Clears cached values for a specific column across all rows.
  ///
  /// Useful when a column definition changes (e.g. valueGetter updated).
  void expireColumn(String colId) {
    for (final row in _cache.values) {
      if (row.containsKey(colId)) {
        row.remove(colId);
        _entryCount--;
      }
    }
  }

  /// Evicts the oldest entries until the cache is back under [maxEntries].
  ///
  /// Walks rows in insertion order (outer map), then columns in insertion
  /// order (inner maps), removing roughly 10% of [maxEntries] entries per
  /// pass — the same strategy as `TextPainterCache._evict`. Rows emptied by
  /// the sweep are dropped entirely so [rowCount] stays accurate.
  void _evictIfNeeded() {
    while (_entryCount > maxEntries) {
      var remaining = (maxEntries * 0.1).ceil().clamp(1, maxEntries);
      final rowsToDrop = <String>[];
      var evicted = 0;
      for (final entry in _cache.entries) {
        if (remaining == 0) break;
        final row = entry.value;
        if (row.length <= remaining) {
          rowsToDrop.add(entry.key);
          remaining -= row.length;
          evicted += row.length;
        } else {
          final colIdsToRemove = row.keys.take(remaining).toList();
          for (final colId in colIdsToRemove) {
            row.remove(colId);
            evicted++;
          }
          remaining = 0;
          break;
        }
      }
      for (final rowId in rowsToDrop) {
        _cache.remove(rowId);
      }
      _entryCount -= evicted;
    }
  }

  /// Sentinel value indicating a cache miss (distinct from a cached `null`).
  static const Object notCached = _NotCachedSentinel();
}

/// Sentinel class to distinguish cache misses from cached `null` values.
class _NotCachedSentinel {
  const _NotCachedSentinel();
}
