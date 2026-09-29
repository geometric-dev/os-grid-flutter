import '../sorting/sort_model.dart';

/// A single child row returned by [OsServerSideDatasource.getRows].
///
/// At any group level the server returns a mix of child groups (further
/// nesting) and leaf rows (actual data). Each element of the returned list
/// is one of:
///
/// - [OsServerSideGroupChildLeaf] — a leaf data row at this level.
/// - [OsServerSideGroupChildGroup] — a child group with a key and a
///   server-reported child count.
sealed class OsServerSideGroupChild {
  const OsServerSideGroupChild();
}

/// A leaf data row returned by the server-side datasource.
///
/// Wraps the user row data ([TData]) exactly as provided by the server.
class OsServerSideGroupChildLeaf<TData> extends OsServerSideGroupChild {
  const OsServerSideGroupChildLeaf(this.data);

  /// The user row data for this leaf row.
  final TData data;

  @override
  String toString() => 'OsServerSideGroupChildLeaf($data)';
}

/// A child group row returned by the server-side datasource.
///
/// The server reports the group [key] (the common value of the grouped
/// column at this level) and the number of children the group contains.
/// The child count is used for the group row's display metadata and to
/// seed the child level's virtual row count.
class OsServerSideGroupChildGroup extends OsServerSideGroupChild {
  const OsServerSideGroupChildGroup({
    required this.key,
    required this.childCount,
  });

  /// The group key value (the common value of the grouped column).
  final String key;

  /// Number of children this group contains (as reported by the server).
  final int childCount;

  @override
  String toString() =>
      'OsServerSideGroupChildGroup(key: $key, childCount: $childCount)';
}

/// Parameters passed to [OsServerSideDatasource.getRows].
///
/// Contains the row range needed at a specific group level (identified by
/// [groupKeys]), the current sort/filter state, and callbacks to report
/// success or failure for asynchronous implementations.
///
/// ```dart
/// List<OsServerSideGroupChild> getRows(ServerSideGetRowsParams params) {
///   final response = api.fetchLevel(
///     start: params.startRow,
///     end: params.endRow,
///     groupKeys: params.groupKeys,
///     sort: params.sortModel,
///   );
///   return [
///     for (final group in response.groups)
///       OsServerSideGroupChildGroup(key: group.name, childCount: group.count),
///     for (final row in response.rows) OsServerSideGroupChildLeaf(row),
///   ];
/// }
/// ```
class ServerSideGetRowsParams<TData> {
  ServerSideGetRowsParams({
    required this.startRow,
    required this.endRow,
    required this.groupKeys,
    required this.successCallback,
    required this.failCallback,
    this.sortModel,
    this.filterModel,
    this.context,
  });

  /// The first row index to fetch at this level (inclusive, zero-based).
  final int startRow;

  /// The last row index to fetch at this level (exclusive).
  ///
  /// The datasource should return children for indices
  /// `[startRow, endRow)`.
  final int endRow;

  /// The group keys identifying the level being requested.
  ///
  /// An empty list means the root level. Each entry is the key of one
  /// ancestor group, from the top level down. For example `['Europe',
  /// 'UK']` requests the children of the `UK` group inside `Europe`.
  final List<String> groupKeys;

  /// The current sort state of the grid.
  ///
  /// The server applies this sort to the requested level before slicing
  /// the [startRow]/[endRow] window.
  final List<OsSortModel>? sortModel;

  /// The current filter state of the grid.
  ///
  /// A map of column ID to filter model (matching the OS Grid TypeScript
  /// filter model JSON structure). The server applies these filters
  /// before grouping and slicing.
  final Map<String, dynamic>? filterModel;

  /// Optional application context passed through from the grid.
  final dynamic context;

  /// Call this to complete the request when the datasource fetches
  /// asynchronously.
  ///
  /// See [OsServerSideDatasource.getRows] for the full completion
  /// contract.
  final void Function(List<OsServerSideGroupChild> children, {int? lastRow})
  successCallback;

  /// Call this if the data request fails (asynchronous implementations).
  ///
  /// The block will be marked as failed and can be retried via
  /// `OsGridController.refreshServerSide`.
  final void Function() failCallback;
}

/// Abstract datasource for the server-side row model (SSRM).
///
/// The server performs sorting, filtering and grouping; the grid requests
/// blocks of children at each group level as the user scrolls and expands
/// groups. The `groupKeys` parameter identifies the level being requested.
///
/// ## Completion contract
///
/// An implementation completes each request in one of two ways:
///
/// - **Synchronous**: return a non-empty list of children directly. The
///   grid stores them immediately. The end of a level is inferred the same
///   way as the infinite row model: returning fewer children than the
///   requested `endRow - startRow` marks the level's total row count as
///   `startRow + children.length`.
///
///   To report an *empty* block synchronously (e.g. a range past the end
///   of the level), call `params.successCallback(const [])` before
///   returning — an empty *return value* alone means "no synchronous
///   result" and keeps the request in flight.
///
/// - **Asynchronous**: return an empty list immediately and complete
///   later via `params.successCallback(children, lastRow: total)` or
///   `params.failCallback()`. The optional `lastRow` reports the exact
///   total child count for this level (like the infinite row model),
///   letting the grid size the level's virtual scroll range precisely.
///
/// ```dart
/// class MyDatasource extends OsServerSideDatasource<Map<String, dynamic>> {
///   @override
///   List<OsServerSideGroupChild> getRows(
///     ServerSideGetRowsParams<Map<String, dynamic>> params,
///   ) {
///     fetchFromServer(params).then((response) {
///       params.successCallback(response.children, lastRow: response.total);
///     }, onError: (e) => params.failCallback());
///     return const [];
///   }
/// }
/// ```
abstract class OsServerSideDatasource<TData> {
  /// Called by the grid when it needs a block of children at the level
  /// identified by `params.groupKeys`.
  ///
  /// See the class docs for the completion contract.
  List<OsServerSideGroupChild> getRows(ServerSideGetRowsParams<TData> params);

  /// Called when the datasource is no longer needed.
  ///
  /// Override this to clean up resources (close connections, cancel
  /// pending requests, etc.). The default implementation does nothing.
  void destroy() {}
}
