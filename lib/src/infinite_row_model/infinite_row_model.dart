import '../os_grid.dart' show OsGrid;

/// Configuration for the infinite row model.
///
/// When set on [OsGrid.infiniteRowModel], the grid switches from client-side
/// row model (using `rowData`) to infinite row model (using a datasource).
/// Data is loaded in blocks (pages) as the user scrolls, making it suitable
/// for very large server-backed datasets.
///
/// ```dart
/// OsGrid(
///   columnDefs: [...],
///   infiniteRowModel: const OsInfiniteRowModel(cacheBlockSize: 50),
///   datasource: MyDatasource(),
/// )
/// ```
class OsInfiniteRowModel {
  /// Creates an infinite row model configuration.
  const OsInfiniteRowModel({
    this.cacheBlockSize = 100,
    this.maxBlocksInCache,
    this.cacheOverflowSize = 1,
    this.maxConcurrentDatasourceRequests = 1,
    this.infiniteInitialRowCount = 1,
  }) : assert(cacheBlockSize > 0, 'cacheBlockSize must be positive'),
       assert(
         maxBlocksInCache == null || maxBlocksInCache > 0,
         'maxBlocksInCache must be positive or null (unlimited)',
       ),
       assert(cacheOverflowSize >= 0, 'cacheOverflowSize must be non-negative'),
       assert(
         maxConcurrentDatasourceRequests > 0,
         'maxConcurrentDatasourceRequests must be positive',
       ),
       assert(
         infiniteInitialRowCount >= 0,
         'infiniteInitialRowCount must be non-negative',
       );

  /// Number of rows per block/page fetched from the datasource.
  ///
  /// The grid requests data in chunks of this size. Larger values mean
  /// fewer requests but more memory usage per block.
  ///
  /// Defaults to 100.
  final int cacheBlockSize;

  /// Maximum number of blocks to keep in cache.
  ///
  /// When set, the cache evicts the least recently accessed block when
  /// this limit is reached. When `null`, all loaded blocks are kept
  /// indefinitely (unlimited cache).
  ///
  /// Defaults to `null` (unlimited).
  final int? maxBlocksInCache;

  /// Number of extra rows to request beyond the visible viewport.
  ///
  /// This provides a buffer so that small scrolls don't immediately
  /// trigger new block requests. The grid will pre-fetch blocks that
  /// are within this many blocks of the visible area.
  ///
  /// Defaults to 1.
  final int cacheOverflowSize;

  /// Maximum number of concurrent requests to the datasource.
  ///
  /// When multiple blocks need loading simultaneously (e.g. fast scrolling),
  /// the grid queues requests beyond this limit. This prevents overwhelming
  /// the server with too many parallel requests.
  ///
  /// Defaults to 1.
  final int maxConcurrentDatasourceRequests;

  /// Initial row count before any data is loaded.
  ///
  /// The grid starts with this many placeholder rows. As the datasource
  /// reports the actual row count (via `lastRow` in the success callback),
  /// the grid adjusts its virtual scroll height accordingly.
  ///
  /// Defaults to 1.
  final int infiniteInitialRowCount;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OsInfiniteRowModel &&
          cacheBlockSize == other.cacheBlockSize &&
          maxBlocksInCache == other.maxBlocksInCache &&
          cacheOverflowSize == other.cacheOverflowSize &&
          maxConcurrentDatasourceRequests ==
              other.maxConcurrentDatasourceRequests &&
          infiniteInitialRowCount == other.infiniteInitialRowCount;

  @override
  int get hashCode => Object.hash(
    cacheBlockSize,
    maxBlocksInCache,
    cacheOverflowSize,
    maxConcurrentDatasourceRequests,
    infiniteInitialRowCount,
  );

  @override
  String toString() =>
      'OsInfiniteRowModel('
      'cacheBlockSize: $cacheBlockSize, '
      'maxBlocksInCache: $maxBlocksInCache, '
      'cacheOverflowSize: $cacheOverflowSize, '
      'maxConcurrentDatasourceRequests: $maxConcurrentDatasourceRequests, '
      'infiniteInitialRowCount: $infiniteInitialRowCount)';
}
