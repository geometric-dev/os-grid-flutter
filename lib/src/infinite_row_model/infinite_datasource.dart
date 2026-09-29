import '../sorting/sort_model.dart';

/// Parameters passed to [OsInfiniteDatasource.getRows].
///
/// Contains the row range needed, current sort/filter state, and callbacks
/// to report success or failure.
///
/// ```dart
/// void getRows(OsInfiniteGetRowsParams<MyData> params) async {
///   final response = await api.fetchRows(
///     start: params.startRow,
///     end: params.endRow,
///     sort: params.sortModel,
///   );
///   params.successCallback(response.rows, lastRow: response.totalCount);
/// }
/// ```
class OsInfiniteGetRowsParams<TData> {
  OsInfiniteGetRowsParams({
    required this.startRow,
    required this.endRow,
    required this.successCallback,
    required this.failCallback,
    this.sortModel,
    this.filterModel,
    this.context,
  });

  /// The first row index to fetch (inclusive, zero-based).
  final int startRow;

  /// The last row index to fetch (exclusive).
  ///
  /// The datasource should return rows for indices [startRow, endRow).
  final int endRow;

  /// The current sort state of the grid.
  ///
  /// When the user sorts a column, the grid purges the cache and re-fetches
  /// from block 0 with the updated sort model. The datasource should apply
  /// this sort on the server side.
  final List<OsSortModel>? sortModel;

  /// The current filter state of the grid.
  ///
  /// A map of column ID to filter model (matching the OS Grid TypeScript
  /// filter model JSON structure). The datasource should apply these filters
  /// on the server side.
  final Map<String, dynamic>? filterModel;

  /// Optional application context passed through from the grid.
  final dynamic context;

  /// Call this when the data is successfully retrieved.
  ///
  /// `rows` is the list of row data for the requested range.
  /// `lastRow` is the total number of rows in the dataset (optional).
  /// When `lastRow` is provided, the grid knows the exact dataset size
  /// and stops requesting further blocks beyond that point. When omitted,
  /// the grid assumes more data may be available.
  ///
  /// The number of rows returned should equal [endRow] - [startRow] unless
  /// this is the last block (in which case fewer rows indicates the end).
  final void Function(List<TData> rows, {int? lastRow}) successCallback;

  /// Call this if the data request fails.
  ///
  /// The block will be marked as failed and can be retried on the next
  /// scroll or cache refresh.
  final void Function() failCallback;
}

/// Abstract datasource for the infinite row model.
///
/// Implement this class to provide data to the grid on demand. The grid
/// calls [getRows] whenever it needs a block of data that isn't in the cache.
///
/// ```dart
/// class MyDatasource extends OsInfiniteDatasource<Map<String, dynamic>> {
///   @override
///   void getRows(OsInfiniteGetRowsParams<Map<String, dynamic>> params) async {
///     try {
///       final response = await fetchFromServer(
///         start: params.startRow,
///         end: params.endRow,
///       );
///       params.successCallback(response.rows, lastRow: response.total);
///     } catch (e) {
///       params.failCallback();
///     }
///   }
/// }
/// ```
abstract class OsInfiniteDatasource<TData> {
  /// Called by the grid when it needs a block of rows.
  ///
  /// The implementation should fetch data for the range
  /// `params.startRow` to `params.endRow` and call either
  /// `params.successCallback` or `params.failCallback`.
  void getRows(OsInfiniteGetRowsParams<TData> params);

  /// Called when the datasource is no longer needed.
  ///
  /// Override this to clean up resources (close connections, cancel
  /// pending requests, etc.). The default implementation does nothing.
  void destroy() {}
}
