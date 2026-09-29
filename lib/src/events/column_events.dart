import '../columns/os_column_pin.dart';
import 'os_grid_event.dart';

/// Emitted when one or more columns are shown or hidden.
///
/// ```dart
/// controller.onColumnVisible.listen((event) {
///   print('${event.columns} visible=${event.visible}');
/// });
/// ```
class OsColumnVisibleEvent extends OsGridEvent {
  const OsColumnVisibleEvent({
    required this.columns,
    required this.visible,
    this.source = 'api',
  });

  /// The column IDs that were shown or hidden.
  final List<String> columns;

  /// Whether the columns were made visible (`true`) or hidden (`false`).
  final bool visible;

  /// The source of the change (e.g. 'api', 'uiColumnMenu').
  final String source;
}

/// Emitted when one or more columns are pinned or unpinned.
///
/// ```dart
/// controller.onColumnPinned.listen((event) {
///   print('${event.columns} pinned=${event.pinned != null}');
/// });
/// ```
class OsColumnPinnedEvent extends OsGridEvent {
  const OsColumnPinnedEvent({
    required this.columns,
    required this.pinned,
    this.source = 'api',
  });

  /// The column IDs that were pinned or unpinned.
  final List<String> columns;

  /// The new pin state (null means unpinned).
  final OsColumnPin? pinned;

  /// The source of the change (e.g. 'api', 'uiColumnMenu').
  final String source;
}

/// Emitted when one or more columns are resized.
class OsColumnResizedEvent extends OsGridEvent {
  const OsColumnResizedEvent({
    required this.columns,
    required this.finished,
    this.source = 'api',
  });

  /// The column IDs that were resized, paired with their new widths.
  final List<ColumnResizeEntry> columns;

  /// Whether the resize operation is complete.
  ///
  /// During a drag resize, this is `false` for intermediate updates
  /// and `true` when the user releases the mouse.
  final bool finished;

  /// The source of the change (e.g. 'api', 'uiColumnDragged').
  final String source;
}

/// A single column resize entry within an [OsColumnResizedEvent].
///
/// ```dart
/// controller.onColumnResized.listen((event) {
///   for (final entry in event.columns) {
///     print('${entry.colId}: ${entry.width}');
///   }
/// });
/// ```
class ColumnResizeEntry {
  const ColumnResizeEntry({required this.colId, required this.width});

  /// The column identifier.
  final String colId;

  /// The new width in logical pixels.
  final double width;
}

/// Emitted when columns are moved (reordered).
///
/// ```dart
/// controller.onColumnMoved.listen((event) {
///   print('${event.columns} moved to index ${event.toIndex}');
/// });
/// ```
class OsColumnMovedEvent extends OsGridEvent {
  const OsColumnMovedEvent({
    required this.columns,
    required this.toIndex,
    this.source = 'api',
  });

  /// The column IDs that were moved.
  final List<String> columns;

  /// The destination index where the columns were moved to.
  final int toIndex;

  /// The source of the change (e.g. 'api', 'uiColumnDragged').
  final String source;
}

/// Entry for setting column widths programmatically, specifying a column and its new width.
class ColumnWidthEntry {
  const ColumnWidthEntry({required this.colId, required this.newWidth});

  /// The column identifier.
  final String colId;

  /// The desired width in logical pixels.
  final double newWidth;
}
