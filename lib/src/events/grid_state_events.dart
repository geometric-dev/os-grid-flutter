import '../grid_state/grid_state.dart';

/// Event emitted when the grid state changes.
///
/// Fired (debounced) whenever any part of the grid state is updated:
/// sort, filter, column visibility/pinning/sizing/order, pagination,
/// selection, or scroll position.
///
/// The [sources] list indicates which state properties changed.
///
/// ```dart
/// controller.onStateUpdated.listen((event) {
///   persistState(event.state);
///   print('changed: ${event.sources}');
/// });
/// ```
class OsStateUpdatedEvent {
  const OsStateUpdatedEvent({required this.state, required this.sources});

  /// The complete current grid state snapshot.
  final OsGridState state;

  /// Which state properties triggered this event.
  ///
  /// Possible values: `sort`, `filter`, `columnPinning`,
  /// `columnVisibility`, `columnSizing`, `columnOrder`,
  /// `pagination`, `rowSelection`, `cellSelection`, `scroll`.
  final List<String> sources;
}
