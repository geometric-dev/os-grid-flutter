import 'os_grid_event.dart';

/// Emitted when the focused cell changes.
///
/// Fired post-frame whenever the focused cell changes due to keyboard
/// navigation, a pointer-down on a cell, or `setFocusedCell`. Clearing the
/// focus via `clearFocusedCell` does not emit this event.
///
/// ```dart
/// controller.onCellFocused.listen((event) {
///   print('focused (${event.rowIndex}, ${event.columnIndex})');
/// });
/// ```
class OsCellFocusedEvent extends OsGridEvent {
  const OsCellFocusedEvent({required this.rowIndex, required this.columnIndex});

  /// Display index of the newly focused row.
  final int rowIndex;

  /// Index of the newly focused column in the flat columns list.
  final int columnIndex;
}

/// Emitted when a key is pressed while a cell is focused and the grid is
/// not editing.
///
/// Only printable characters and navigation keys fire this event. It is
/// informational: it fires before the grid's built-in key handling and
/// listeners cannot consume or override it.
///
/// ```dart
/// controller.onCellKeyDown.listen((event) {
///   print('${event.key} on row ${event.rowIndex}');
/// });
/// ```
class OsCellKeyDownEvent extends OsGridEvent {
  const OsCellKeyDownEvent({
    required this.rowIndex,
    required this.columnIndex,
    required this.key,
    this.physicalKey,
  });

  /// Display index of the focused row.
  final int rowIndex;

  /// Index of the focused column in the flat columns list.
  final int columnIndex;

  /// Label of the logical key, e.g. `'Arrow Down'`, `'Enter'`, `'X'`.
  final String key;

  /// Simplified physical key identity as a USB HID usage hex string
  /// (e.g. `'0x00070052'`), or null when unavailable.
  final String? physicalKey;
}
