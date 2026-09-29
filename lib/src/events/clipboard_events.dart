import 'os_grid_event.dart';

/// Emitted when a clipboard copy operation completes.
///
/// ```dart
/// controller.onClipboardCopy.listen((event) {
///   print('${event.cellCount} cells copied (${event.source})');
/// });
/// ```
class OsClipboardCopyEvent extends OsGridEvent {
  const OsClipboardCopyEvent({
    required this.text,
    required this.cellCount,
    required this.source,
  });

  /// The text that was copied to the clipboard.
  final String text;

  /// The number of cells that were copied.
  final int cellCount;

  /// How the copy was triggered: 'keyboard' or 'api'.
  final String source;
}

/// Emitted when a clipboard paste operation completes.
///
/// ```dart
/// controller.onClipboardPaste.listen((event) {
///   print('${event.cellCount} cells pasted (${event.source})');
/// });
/// ```
class OsClipboardPasteEvent extends OsGridEvent {
  const OsClipboardPasteEvent({required this.cellCount, required this.source});

  /// The number of cells that were pasted.
  final int cellCount;

  /// How the paste was triggered: 'keyboard' or 'api'.
  final String source;
}

/// Emitted when a clipboard cut operation completes.
///
/// ```dart
/// controller.onClipboardCut.listen((event) {
///   print('${event.cellCount} cells cut');
/// });
/// ```
class OsClipboardCutEvent extends OsGridEvent {
  const OsClipboardCutEvent({
    required this.text,
    required this.cellCount,
    required this.source,
  });

  /// The text that was cut to the clipboard.
  final String text;

  /// The number of cells that were cut.
  final int cellCount;

  /// How the cut was triggered: 'keyboard' or 'api'.
  final String source;
}
