/// Configuration for synchronising horizontal scroll between grid instances.
///
/// Grids that share the same [groupId] will have their horizontal scroll
/// positions synchronised: when one grid scrolls horizontally, all other
/// grids in the same group scroll to the same offset.
///
/// ```dart
/// OsGrid(
///   alignedGrids: OsAlignedGrid(groupId: 'my-group'),
///   columnDefs: [...],
///   rowData: [...],
/// )
/// ```
class OsAlignedGrid {
  /// Creates an aligned grid configuration.
  ///
  /// [groupId] identifies which grids should scroll together. All grids
  /// with the same group ID will have their horizontal scroll synchronised.
  const OsAlignedGrid({required this.groupId});

  /// Grids with the same groupId will have their horizontal scroll
  /// synchronised.
  final String groupId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OsAlignedGrid &&
          runtimeType == other.runtimeType &&
          groupId == other.groupId;

  @override
  int get hashCode => groupId.hashCode;
}
