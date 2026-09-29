import '../grid_state/grid_state.dart';

/// Owns grid-state persistence wiring ([getState] / [setState]).
///
/// Extracted from `OsGridController` (controller split phase 2). The
/// controller keeps its full public surface — including the
/// `onStateUpdated` stream, which stays on the controller alongside all
/// other streams — and delegates snapshot/restore calls here.
///
/// The coordinator holds only the wiring hooks that `_OsGridState`
/// registers against the `GridStateService`; it never touches streams.
class StatePersistenceCoordinator {
  /// Callback set by _OsGridState to handle getState.
  OsGridState Function()? onGetStateRequested;

  /// Callback set by _OsGridState to handle setState.
  void Function(OsGridState state, List<String>? propertiesToIgnore)?
  onSetStateRequested;

  /// Get a snapshot of the current grid state.
  ///
  /// Returns an empty [OsGridState] before the grid attaches.
  OsGridState getState() => onGetStateRequested?.call() ?? const OsGridState();

  /// Restore a previously saved grid state.
  ///
  /// Only the non-null properties in [state] are applied. Properties
  /// listed in [propertiesToIgnore] are skipped.
  void setState(OsGridState state, {List<String>? propertiesToIgnore}) {
    onSetStateRequested?.call(state, propertiesToIgnore);
  }
}
