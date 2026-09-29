/// Base class for all grid events.
///
/// Concrete subclasses are delivered on typed streams exposed by
/// `OsGridController` (e.g. [OsGridReadyEvent] on `onGridReady`):
///
/// ```dart
/// controller.onGridReady.listen((event) {
///   print('grid ready');
/// });
/// ```
abstract class OsGridEvent {
  const OsGridEvent();
}

/// Emitted when the grid is fully initialised and ready for interaction.
///
/// ```dart
/// controller.onGridReady.listen((_) => controller.setFocusedCell(
///       rowIndex: 0,
///       columnIndex: 0,
///     ));
/// ```
class OsGridReadyEvent extends OsGridEvent {
  const OsGridReadyEvent();
}
