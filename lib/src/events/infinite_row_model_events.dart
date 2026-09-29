import 'os_grid_event.dart';

/// Event emitted when the infinite row model's virtual row count changes.
///
/// This fires when:
/// - The datasource reports a `lastRow` value in the success callback
/// - The grid infers the end of data (fewer rows returned than block size)
/// - The virtual row count expands as new blocks are loaded
/// - The cache is purged (row count resets to initial value)
///
/// ```dart
/// controller.onInfiniteRowCountChanged.listen((event) {
///   print('${event.rowCount} rows (lastRowKnown=${event.isLastRowKnown})');
/// });
/// ```
class OsInfiniteRowCountChangedEvent extends OsGridEvent {
  OsInfiniteRowCountChangedEvent({
    required this.rowCount,
    required this.isLastRowKnown,
  });

  /// The current virtual row count.
  ///
  /// When [isLastRowKnown] is `false`, this is an estimate that grows
  /// as the user scrolls. When `true`, this is the exact dataset size.
  final int rowCount;

  /// Whether the total row count is definitively known.
  ///
  /// Becomes `true` when the datasource reports a `lastRow` value or
  /// when fewer rows are returned than the block size (indicating end of data).
  final bool isLastRowKnown;

  @override
  String toString() =>
      'OsInfiniteRowCountChangedEvent('
      'rowCount: $rowCount, isLastRowKnown: $isLastRowKnown)';
}
