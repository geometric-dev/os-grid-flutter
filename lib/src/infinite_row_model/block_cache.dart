import 'dart:collection';

import '../sorting/sort_model.dart';
import 'infinite_datasource.dart';
import 'infinite_row_model.dart';

/// The loading state of a cache block.
enum BlockState {
  /// The block has not been requested yet.
  empty,

  /// The block is currently being loaded from the datasource.
  loading,

  /// The block has been successfully loaded.
  loaded,

  /// The block request failed.
  failed,
}

/// Represents a single block (page) of rows in the infinite cache.
class CacheBlock<TData> {
  CacheBlock({
    required this.blockNumber,
    required this.startRow,
    required this.endRow,
  });

  /// The block number (0-based index).
  final int blockNumber;

  /// The first row index in this block (inclusive).
  final int startRow;

  /// The last row index in this block (exclusive).
  final int endRow;

  /// The current state of this block.
  BlockState state = BlockState.empty;

  /// The loaded row data (null until loaded).
  List<TData>? rows;

  /// Timestamp of last access (for LRU eviction).
  int lastAccessTime = 0;
}

/// Manages the block cache for the infinite row model.
///
/// Tracks which blocks are loaded, loading, or failed. Handles block
/// eviction when `maxBlocksInCache` is reached, prevents duplicate
/// requests for the same block, and respects concurrency limits.
class InfiniteBlockCache<TData> {
  InfiniteBlockCache({
    required this.config,
    required this.datasource,
    required this.onRowCountChanged,
    required this.onBlockLoaded,
  });

  /// The infinite row model configuration.
  final OsInfiniteRowModel config;

  /// The datasource to fetch blocks from.
  final OsInfiniteDatasource<TData> datasource;

  /// Callback when the known row count changes.
  final void Function(int rowCount) onRowCountChanged;

  /// Callback when a block finishes loading (triggers repaint).
  final void Function() onBlockLoaded;

  /// The block cache, keyed by block number.
  final Map<int, CacheBlock<TData>> _blocks = {};

  /// Queue of block numbers waiting to be requested.
  final Queue<int> _pendingQueue = Queue<int>();

  /// Number of currently active (in-flight) requests.
  int _activeRequests = 0;

  /// Generation counter, incremented on [purge]. Datasource callbacks
  /// capture the generation at request time so stale completions from
  /// before a purge cannot decrement [_activeRequests].
  int _generation = 0;

  /// Monotonically increasing access counter for LRU tracking.
  int _accessCounter = 0;

  /// Minimum time to wait before automatically retrying a failed block.
  static const Duration _failedRetryCooldown = Duration(seconds: 2);

  /// Timestamp (epoch ms) of the last failed attempt per block number,
  /// used to suppress automatic retries within [_failedRetryCooldown].
  final Map<int, int> _failedAtByBlock = {};

  /// The known total row count. Null means unknown (still loading).
  int? _lastRow;

  /// The current virtual row count (what the grid uses for scroll height).
  int _virtualRowCount = 0;

  /// The current sort model (passed to datasource on each request).
  List<OsSortModel>? _sortModel;

  /// The current filter model (passed to datasource on each request).
  Map<String, dynamic>? _filterModel;

  /// Whether the cache has been disposed.
  bool _disposed = false;

  /// The known total row count, or null if not yet determined.
  int? get lastRow => _lastRow;

  /// The current virtual row count used for scroll calculations.
  int get virtualRowCount => _virtualRowCount;

  /// Whether the total row count is known.
  bool get isLastRowKnown => _lastRow != null;

  /// Whether any cache block is currently being loaded from the datasource.
  ///
  /// True from the moment a block request is created until its success or
  /// failure callback arrives. Blocks abandoned by [purge] are discarded
  /// entirely, so stale in-flight requests never count as loading.
  bool get isAnyBlockLoading =>
      _blocks.values.any((b) => b.state == BlockState.loading);

  /// Whether at least one cache block has successfully loaded.
  ///
  /// False before the first data arrives and immediately after [purge].
  bool get hasAnyLoadedBlock =>
      _blocks.values.any((b) => b.state == BlockState.loaded);

  /// Initialise the cache with the configured initial row count.
  void init() {
    _virtualRowCount = config.infiniteInitialRowCount;
  }

  /// Update the sort model and purge the cache.
  ///
  /// Called when the user changes the sort. All cached blocks are discarded
  /// and the grid re-fetches from block 0.
  void setSortModel(List<OsSortModel>? sortModel) {
    _sortModel = sortModel;
    purge();
  }

  /// Update the filter model and purge the cache.
  ///
  /// Called when the user changes filters. All cached blocks are discarded
  /// and the grid re-fetches from block 0.
  void setFilterModel(Map<String, dynamic>? filterModel) {
    _filterModel = filterModel;
    purge();
  }

  /// Purge all cached blocks and reset state.
  ///
  /// The virtual row count resets to `infiniteInitialRowCount` and the
  /// grid will re-request blocks as needed.
  void purge() {
    _blocks.clear();
    _pendingQueue.clear();
    _failedAtByBlock.clear();
    // Abandon in-flight requests: bump the generation so their callbacks
    // are recognised as stale and cannot decrement `_activeRequests`.
    _generation++;
    _activeRequests = 0;
    _lastRow = null;
    _virtualRowCount = config.infiniteInitialRowCount;
    onRowCountChanged(_virtualRowCount);
  }

  /// Refresh the cache: purge and trigger a re-fetch.
  ///
  /// Equivalent to [purge] but semantically indicates the user wants
  /// fresh data (e.g. after a server-side mutation).
  void refresh() {
    purge();
  }

  /// Get the row data at a specific index, or null if not yet loaded.
  ///
  /// Also triggers loading of the block containing this row if it hasn't
  /// been requested yet.
  TData? getRow(int rowIndex) {
    if (rowIndex < 0 || rowIndex >= _virtualRowCount) return null;

    final blockNumber = rowIndex ~/ config.cacheBlockSize;
    final block = _blocks[blockNumber];

    if (block == null || block.state == BlockState.empty) {
      _ensureBlockRequested(blockNumber);
      return null;
    }

    if (block.state == BlockState.loaded) {
      block.lastAccessTime = ++_accessCounter;
      final localIndex = rowIndex - block.startRow;
      if (block.rows != null && localIndex < block.rows!.length) {
        return block.rows![localIndex];
      }
      return null;
    }

    if (block.state == BlockState.failed) {
      // Retry failed blocks on access, throttled by the failure cooldown.
      _ensureBlockRequested(blockNumber);
    }

    return null;
  }

  /// Check if a row at the given index is loaded.
  bool isRowLoaded(int rowIndex) {
    if (rowIndex < 0 || rowIndex >= _virtualRowCount) return false;
    final blockNumber = rowIndex ~/ config.cacheBlockSize;
    final block = _blocks[blockNumber];
    if (block == null || block.state != BlockState.loaded) return false;
    final localIndex = rowIndex - block.startRow;
    return block.rows != null && localIndex < block.rows!.length;
  }

  /// Get the state of the block containing the given row index.
  BlockState getBlockState(int rowIndex) {
    final blockNumber = rowIndex ~/ config.cacheBlockSize;
    final block = _blocks[blockNumber];
    return block?.state ?? BlockState.empty;
  }

  /// Ensure blocks needed for the visible range are requested.
  ///
  /// Called by the grid when the scroll position changes. Determines which
  /// blocks are needed for the visible range (plus overflow) and queues
  /// requests for any that aren't already loaded or loading.
  void ensureBlocksForRange(int firstVisibleRow, int lastVisibleRow) {
    if (_disposed) return;

    final firstBlock = firstVisibleRow ~/ config.cacheBlockSize;
    final lastBlock = lastVisibleRow ~/ config.cacheBlockSize;

    // Include overflow blocks.
    final startBlock = (firstBlock - config.cacheOverflowSize).clamp(
      0,
      _maxBlockNumber,
    );
    final endBlock = (lastBlock + config.cacheOverflowSize).clamp(
      0,
      _maxBlockNumber,
    );

    for (int b = startBlock; b <= endBlock; b++) {
      _ensureBlockRequested(b);
    }
  }

  /// The maximum possible block number based on known row count.
  int get _maxBlockNumber {
    if (_lastRow != null) {
      return (_lastRow! - 1) ~/ config.cacheBlockSize;
    }
    // If row count unknown, allow up to virtual row count.
    return (_virtualRowCount - 1).clamp(0, double.maxFinite.toInt()) ~/
        config.cacheBlockSize;
  }

  /// Ensure a specific block is requested (if not already loaded/loading).
  void _ensureBlockRequested(int blockNumber) {
    if (_disposed) return;

    // Don't request blocks beyond known last row.
    if (_lastRow != null) {
      final blockStart = blockNumber * config.cacheBlockSize;
      if (blockStart >= _lastRow!) return;
    }

    final existing = _blocks[blockNumber];
    if (existing != null &&
        (existing.state == BlockState.loading ||
            existing.state == BlockState.loaded)) {
      // Already loading or loaded — update access time if loaded.
      if (existing.state == BlockState.loaded) {
        existing.lastAccessTime = ++_accessCounter;
      }
      return;
    }

    // Throttle automatic retries of failed blocks to avoid request
    // storms when the datasource is failing. Manual purges clear the
    // failure timestamps and always force a retry.
    if (existing != null && existing.state == BlockState.failed) {
      if (!_isRetryCooldownElapsed(blockNumber)) return;
    }

    // Create or reset the block entry.
    final startRow = blockNumber * config.cacheBlockSize;
    final endRow = startRow + config.cacheBlockSize;
    final block = CacheBlock<TData>(
      blockNumber: blockNumber,
      startRow: startRow,
      endRow: _lastRow != null ? endRow.clamp(0, _lastRow!) : endRow,
    );
    block.state = BlockState.loading;
    _blocks[blockNumber] = block;

    // Queue the request.
    if (!_pendingQueue.contains(blockNumber)) {
      _pendingQueue.add(blockNumber);
    }

    _processQueue();
  }

  /// Process the pending request queue, respecting concurrency limits.
  void _processQueue() {
    while (_pendingQueue.isNotEmpty &&
        _activeRequests < config.maxConcurrentDatasourceRequests) {
      final blockNumber = _pendingQueue.removeFirst();
      final block = _blocks[blockNumber];

      // Skip if block was evicted or already loaded while queued.
      if (block == null || block.state != BlockState.loading) continue;

      _activeRequests++;
      _evictIfNeeded();
      _requestBlock(block);
    }
  }

  /// Send a request to the datasource for a specific block.
  void _requestBlock(CacheBlock<TData> block) {
    // Capture the generation so completions arriving after a purge
    // (which resets the accounting) are recognised as stale.
    final generation = _generation;
    final params = OsInfiniteGetRowsParams<TData>(
      startRow: block.startRow,
      endRow: block.endRow,
      sortModel: _sortModel,
      filterModel: _filterModel,
      successCallback: (List<TData> rows, {int? lastRow}) {
        _onBlockSuccess(block, rows, lastRow, generation);
      },
      failCallback: () {
        _onBlockFailed(block, generation);
      },
    );

    datasource.getRows(params);
  }

  /// Release one concurrency slot, never dropping below zero.
  void _releaseRequestSlot() {
    if (_activeRequests > 0) _activeRequests--;
  }

  /// Whether enough time has passed since [blockNumber] last failed for
  /// it to be retried automatically.
  bool _isRetryCooldownElapsed(int blockNumber) {
    final failedAt = _failedAtByBlock[blockNumber];
    if (failedAt == null) return true;
    return DateTime.now().millisecondsSinceEpoch - failedAt >=
        _failedRetryCooldown.inMilliseconds;
  }

  /// Handle a successful block load.
  void _onBlockSuccess(
    CacheBlock<TData> block,
    List<TData> rows,
    int? lastRow,
    int generation,
  ) {
    if (_disposed) return;

    // Ignore stale completions from before a purge.
    if (generation != _generation) return;

    // Verify the block is still in the cache (may have been evicted).
    if (!_blocks.containsKey(block.blockNumber)) {
      _releaseRequestSlot();
      _processQueue();
      return;
    }

    block.rows = rows;
    block.state = BlockState.loaded;
    block.lastAccessTime = ++_accessCounter;
    _failedAtByBlock.remove(block.blockNumber);
    _releaseRequestSlot();

    // Update row count if the datasource reported it.
    if (lastRow != null) {
      _lastRow = lastRow;
      if (_virtualRowCount != lastRow) {
        _virtualRowCount = lastRow;
        onRowCountChanged(_virtualRowCount);
      }
    } else if (rows.length < config.cacheBlockSize) {
      // Fewer rows than block size means we've reached the end.
      final actualLastRow = block.startRow + rows.length;
      _lastRow = actualLastRow;
      if (_virtualRowCount != actualLastRow) {
        _virtualRowCount = actualLastRow;
        onRowCountChanged(_virtualRowCount);
      }
    } else {
      // More data may exist — expand virtual row count if needed.
      final blockEnd = block.startRow + rows.length;
      if (blockEnd >= _virtualRowCount) {
        _virtualRowCount = blockEnd + config.cacheBlockSize;
        onRowCountChanged(_virtualRowCount);
      }
    }

    onBlockLoaded();
    _processQueue();
  }

  /// Handle a failed block load.
  void _onBlockFailed(CacheBlock<TData> block, int generation) {
    if (_disposed) return;

    // Ignore stale completions from before a purge.
    if (generation != _generation) return;

    if (_blocks.containsKey(block.blockNumber)) {
      block.state = BlockState.failed;
      block.rows = null;
      _failedAtByBlock[block.blockNumber] =
          DateTime.now().millisecondsSinceEpoch;
    }

    _releaseRequestSlot();
    onBlockLoaded(); // Trigger repaint to show error state.
    _processQueue();
  }

  /// Evict the least recently used block if the cache is full.
  void _evictIfNeeded() {
    if (config.maxBlocksInCache == null) return;

    while (_blocks.length > config.maxBlocksInCache!) {
      // Find the LRU block that isn't currently loading.
      int? lruBlockNumber;
      int lruTime = _accessCounter + 1;

      for (final entry in _blocks.entries) {
        if (entry.value.state == BlockState.loading) continue;
        if (entry.value.lastAccessTime < lruTime) {
          lruTime = entry.value.lastAccessTime;
          lruBlockNumber = entry.key;
        }
      }

      if (lruBlockNumber != null) {
        _blocks.remove(lruBlockNumber);
      } else {
        break; // All blocks are loading, can't evict.
      }
    }
  }

  /// Get the current row count (for the controller API).
  int getRowCount() => _virtualRowCount;

  /// Dispose the cache and clean up resources.
  void dispose() {
    _disposed = true;
    _blocks.clear();
    _pendingQueue.clear();
    _failedAtByBlock.clear();
    datasource.destroy();
  }
}
