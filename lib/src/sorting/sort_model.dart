import 'sort_direction.dart';

/// Describes the sort state of a single column.
class OsSortModel {
  const OsSortModel({required this.colId, required this.sort});

  /// The column ID being sorted.
  final String colId;

  /// The sort direction.
  final OsSortDirection sort;

  /// Creates a sort model from a JSON map.
  ///
  /// Expects `{'colId': 'name', 'sort': 'asc'}` format matching
  /// the OS Grid TypeScript convention.
  factory OsSortModel.fromJson(Map<String, dynamic> json) {
    final sortStr = json['sort'] as String;
    final direction = sortStr == 'asc'
        ? OsSortDirection.ascending
        : OsSortDirection.descending;
    return OsSortModel(colId: json['colId'] as String, sort: direction);
  }

  /// Converts this sort model to a JSON map.
  ///
  /// Produces `{'colId': 'name', 'sort': 'asc'}` format matching
  /// the OS Grid TypeScript convention.
  Map<String, dynamic> toJson() => {
    'colId': colId,
    'sort': sort == OsSortDirection.ascending ? 'asc' : 'desc',
  };

  @override
  String toString() => 'OsSortModel(colId: $colId, sort: $sort)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OsSortModel && colId == other.colId && sort == other.sort;

  @override
  int get hashCode => Object.hash(colId, sort);
}

/// Key used for multi-sort (which modifier key enables multi-column sorting).
enum OsMultiSortKey {
  /// Hold Shift to add to sort (default).
  shift,

  /// Hold Ctrl/Cmd to add to sort.
  ctrl,
}
