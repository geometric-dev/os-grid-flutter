import 'os_grid_event.dart';

/// Emitted before an undo operation is applied.
///
/// ```dart
/// controller.onUndoStarted.listen((event) {
///   print('undo started from ${event.source}');
/// });
/// ```
class OsUndoStartedEvent extends OsGridEvent {
  const OsUndoStartedEvent({required this.source});

  /// The source of the undo operation ('api' or 'ui').
  final String source;
}

/// Emitted after an undo operation completes.
///
/// ```dart
/// controller.onUndoEnded.listen((event) {
///   if (!event.operationPerformed) print('nothing to undo');
/// });
/// ```
class OsUndoEndedEvent extends OsGridEvent {
  const OsUndoEndedEvent({
    required this.source,
    required this.operationPerformed,
  });

  /// The source of the undo operation ('api' or 'ui').
  final String source;

  /// Whether an undo was actually performed (false if stack was empty).
  final bool operationPerformed;
}

/// Emitted before a redo operation is applied.
///
/// ```dart
/// controller.onRedoStarted.listen((event) {
///   print('redo started from ${event.source}');
/// });
/// ```
class OsRedoStartedEvent extends OsGridEvent {
  const OsRedoStartedEvent({required this.source});

  /// The source of the redo operation ('api' or 'ui').
  final String source;
}

/// Emitted after a redo operation completes.
///
/// ```dart
/// controller.onRedoEnded.listen((event) {
///   if (!event.operationPerformed) print('nothing to redo');
/// });
/// ```
class OsRedoEndedEvent extends OsGridEvent {
  const OsRedoEndedEvent({
    required this.source,
    required this.operationPerformed,
  });

  /// The source of the redo operation ('api' or 'ui').
  final String source;

  /// Whether a redo was actually performed (false if stack was empty).
  final bool operationPerformed;
}
