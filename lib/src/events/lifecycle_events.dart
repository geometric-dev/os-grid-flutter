import 'os_grid_event.dart';

/// Emitted once after the first render that has non-empty processed data
/// (after filter + sort).
///
/// Fires exactly once per grid lifetime, deferred to a post-frame callback
/// so listeners never run during build or layout.
///
/// ```dart
/// controller.onFirstDataRendered.listen((_) {
///   print('first data on screen');
/// });
/// ```
class OsFirstDataRenderedEvent extends OsGridEvent {
  const OsFirstDataRenderedEvent();
}

/// Emitted when the grid's rendered size changes.
///
/// ```dart
/// controller.onGridSizeChanged.listen((event) {
///   print('${event.width}x${event.height}');
/// });
/// ```
class OsGridSizeChangedEvent extends OsGridEvent {
  const OsGridSizeChangedEvent({required this.width, required this.height});

  /// The new grid width in logical pixels.
  final double width;

  /// The new grid height in logical pixels.
  final double height;
}

/// Emitted when the client-side row model has been reprocessed
/// (filter, sort, transactions) and when the pagination page changes.
///
/// Emissions are coalesced: multiple reprocesses within the same frame
/// produce a single event, delivered post-frame with a re-entrancy guard
/// so listeners that trigger further reprocessing cannot recurse.
///
/// ```dart
/// controller.onModelUpdated.listen((_) {
///   print('row model reprocessed');
/// });
/// ```
class OsModelUpdatedEvent extends OsGridEvent {
  const OsModelUpdatedEvent();
}

/// Emitted when the raw [rowData] list reference changes, before the
/// filter/sort pipeline processes the new data.
///
/// ```dart
/// controller.onRowDataChanged.listen((event) {
///   print('new dataset: ${event.rowData?.length ?? 0} rows');
/// });
/// ```
class OsRowDataChangedEvent<TData> extends OsGridEvent {
  const OsRowDataChangedEvent({this.rowData});

  /// The new raw row data list. `null` when row data was removed.
  final List<TData>? rowData;
}
