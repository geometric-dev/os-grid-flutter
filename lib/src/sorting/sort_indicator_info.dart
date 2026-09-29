import 'sort_direction.dart';

/// Information needed to paint a sort indicator on a column header.
///
/// Used by the grid painter to render sort arrows and priority numbers
/// for multi-column sort.
class SortIndicatorInfo {
  const SortIndicatorInfo({
    required this.direction,
    required this.priority,
    required this.isMultiSort,
  });

  /// The sort direction for this column.
  final OsSortDirection direction;

  /// The 1-based priority number (1 = primary sort, 2 = secondary, etc.).
  final int priority;

  /// Whether multiple columns are currently sorted (determines if the
  /// priority number should be displayed).
  final bool isMultiSort;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SortIndicatorInfo &&
          direction == other.direction &&
          priority == other.priority &&
          isMultiSort == other.isMultiSort;

  @override
  int get hashCode => Object.hash(direction, priority, isMultiSort);
}
