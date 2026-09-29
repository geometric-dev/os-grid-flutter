import 'date_filter_presets.dart';

/// Represents a single filter condition for a column.
///
/// This mirrors OS Grid's `ISimpleFilterModel` — each condition has a
/// [type] (the operation, e.g. 'contains', 'greaterThan') and one or two
/// values ([filter] and [filterTo] for range operations).
///
/// ```dart
/// final condition = OsFilterCondition(
///   type: 'contains',
///   filter: 'alice',
/// );
/// ```
class OsFilterCondition {
  const OsFilterCondition({required this.type, this.filter, this.filterTo});

  /// The filter operation type (e.g. 'contains', 'equals', 'greaterThan').
  final String type;

  /// The primary filter value.
  final dynamic filter;

  /// The secondary filter value (used for 'inRange' operations).
  final dynamic filterTo;

  /// Sentinel used by [copyWith] to distinguish "not provided" from an
  /// explicit `null`.
  static const Object _unset = Object();

  /// Creates a copy with the given fields replaced.
  ///
  /// Omit a parameter to keep the current value; pass an explicit value
  /// (including `null`) to replace it. This allows clearing stale values,
  /// e.g. removing `filterTo` when switching from 'inRange' to 'equals':
  ///
  /// ```dart
  /// condition.copyWith(type: 'equals', filterTo: null);
  /// ```
  OsFilterCondition copyWith({
    String? type,
    Object? filter = _unset,
    Object? filterTo = _unset,
  }) {
    return OsFilterCondition(
      type: type ?? this.type,
      filter: identical(filter, _unset) ? this.filter : filter,
      filterTo: identical(filterTo, _unset) ? this.filterTo : filterTo,
    );
  }

  /// Converts this condition to a JSON-compatible map.
  ///
  /// When [filterType] is 'date', outputs `dateFrom`/`dateTo` instead of
  /// `filter`/`filterTo` to match OS Grid TypeScript's wire format.
  Map<String, dynamic> toJson({String? filterType}) {
    final map = <String, dynamic>{'type': type};
    if (filterType == 'date') {
      if (filter != null) map['dateFrom'] = filter.toString();
      if (filterTo != null) map['dateTo'] = filterTo.toString();
    } else {
      if (filter != null) map['filter'] = filter;
      if (filterTo != null) map['filterTo'] = filterTo;
    }
    return map;
  }

  /// Creates a condition from a JSON-compatible map.
  ///
  /// Handles both standard `filter`/`filterTo` fields and date-specific
  /// `dateFrom`/`dateTo` fields.
  factory OsFilterCondition.fromJson(Map<String, dynamic> json) {
    // Support date filter format: dateFrom/dateTo → filter/filterTo
    final filter = json['filter'] ?? json['dateFrom'];
    final filterTo = json['filterTo'] ?? json['dateTo'];
    return OsFilterCondition(
      type: json['type'] as String,
      filter: filter,
      filterTo: filterTo,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OsFilterCondition &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          filter == other.filter &&
          filterTo == other.filterTo;

  @override
  int get hashCode => Object.hash(type, filter, filterTo);

  @override
  String toString() =>
      'OsFilterCondition(type: $type, filter: $filter, filterTo: $filterTo)';
}

/// The join operator for combining multiple filter conditions.
enum OsJoinOperator {
  /// All conditions must pass (logical AND).
  and,

  /// At least one condition must pass (logical OR).
  or,
}

/// Represents the complete filter state for a single column.
///
/// Mirrors OS Grid's filter model structure. A column filter model can be
/// either a single condition or a combined model with multiple conditions
/// joined by an [operator].
///
/// Single condition:
/// ```dart
/// OsColumnFilterModel(
///   filterType: 'text',
///   conditions: [OsFilterCondition(type: 'contains', filter: 'alice')],
/// )
/// ```
///
/// Combined conditions:
/// ```dart
/// OsColumnFilterModel(
///   filterType: 'text',
///   operator: OsJoinOperator.and,
///   conditions: [
///     OsFilterCondition(type: 'contains', filter: 'alice'),
///     OsFilterCondition(type: 'startsWith', filter: 'a'),
///   ],
/// )
/// ```
class OsColumnFilterModel {
  const OsColumnFilterModel({
    required this.filterType,
    this.conditions = const [],
    this.operator,
    this.values,
  });

  /// The filter type identifier ('text', 'number', 'date', 'set').
  final String filterType;

  /// The join operator when multiple conditions are present.
  /// Null when there is only one condition.
  final OsJoinOperator? operator;

  /// The filter conditions. A single-condition model has exactly one entry.
  final List<OsFilterCondition> conditions;

  /// The selected value keys for set filters (`filterType: 'set'`).
  ///
  /// Each entry is the string key of a selected checklist value (the cell
  /// value's `toString()`, with blanks normalised to `''`). An empty list
  /// means "nothing selected" — an active filter that excludes every row.
  /// `null` means the model carries no selection state (inactive).
  final List<String>? values;

  /// Whether this model has active filter conditions.
  ///
  /// Set models are active whenever a selection exists — including an
  /// empty one, which excludes all rows.
  bool get isActive {
    if (filterType == 'set') return values != null;
    return conditions.isNotEmpty &&
        conditions.any(
          (c) =>
              c.type != 'empty' &&
              (c.filter != null ||
                  c.type == 'blank' ||
                  c.type == 'notBlank' ||
                  DateFilterPresets.isPresetType(c.type)),
        );
  }

  /// Whether this is a combined (multi-condition) model.
  bool get isCombined => conditions.length > 1 && operator != null;

  /// Converts this model to a JSON-compatible map.
  ///
  /// Set filter models are serialised as:
  /// ```json
  /// { "filterType": "set", "values": ["alice", "bob"] }
  /// ```
  ///
  /// Single condition models are serialised flat (matching OS Grid's format):
  /// ```json
  /// { "filterType": "text", "type": "contains", "filter": "alice" }
  /// ```
  ///
  /// Combined models include the operator and conditions array:
  /// ```json
  /// { "filterType": "text", "operator": "AND", "conditions": [...] }
  /// ```
  Map<String, dynamic> toJson() {
    if (filterType == 'set') {
      return {
        'filterType': 'set',
        'values': List<String>.of(values ?? const []),
      };
    }

    if (isCombined) {
      return {
        'filterType': filterType,
        'operator': operator == OsJoinOperator.or ? 'OR' : 'AND',
        'conditions': conditions
            .map((c) => c.toJson(filterType: filterType))
            .toList(),
      };
    }

    // Single condition — flat format
    final condition = conditions.isNotEmpty ? conditions.first : null;
    return {
      'filterType': filterType,
      if (condition != null) ...condition.toJson(filterType: filterType),
    };
  }

  /// Creates a model from a JSON-compatible map.
  factory OsColumnFilterModel.fromJson(Map<String, dynamic> json) {
    final filterType = json['filterType'] as String? ?? 'text';

    // Set filter model — values array of selected keys
    if (filterType == 'set') {
      final raw = json['values'];
      final values = raw is List
          ? raw.map((v) => v?.toString() ?? '').toList()
          : const <String>[];
      return OsColumnFilterModel(filterType: filterType, values: values);
    }

    // Check if it's a combined model
    if (json.containsKey('operator') && json.containsKey('conditions')) {
      final operatorStr = json['operator'] as String;
      final conditionsJson = json['conditions'] as List;
      return OsColumnFilterModel(
        filterType: filterType,
        operator: operatorStr == 'OR' ? OsJoinOperator.or : OsJoinOperator.and,
        conditions: conditionsJson
            .cast<Map<String, dynamic>>()
            .map(OsFilterCondition.fromJson)
            .toList(),
      );
    }

    // Single condition — flat format
    final type = json['type'] as String?;
    if (type != null) {
      return OsColumnFilterModel(
        filterType: filterType,
        conditions: [OsFilterCondition.fromJson(json)],
      );
    }

    // Empty model
    return OsColumnFilterModel(filterType: filterType, conditions: const []);
  }

  /// Sentinel used by [copyWith] to distinguish "not provided" from an
  /// explicit `null`.
  static const Object _unset = Object();

  /// Creates a copy with the given fields replaced.
  OsColumnFilterModel copyWith({
    String? filterType,
    OsJoinOperator? operator,
    List<OsFilterCondition>? conditions,
    Object? values = _unset,
  }) {
    return OsColumnFilterModel(
      filterType: filterType ?? this.filterType,
      operator: operator ?? this.operator,
      conditions: conditions ?? this.conditions,
      values: identical(values, _unset) ? this.values : values as List<String>?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OsColumnFilterModel &&
          runtimeType == other.runtimeType &&
          filterType == other.filterType &&
          operator == other.operator &&
          _listEquals(conditions, other.conditions) &&
          _listEquals(values ?? const [], other.values ?? const []);

  @override
  int get hashCode => Object.hash(
    filterType,
    operator,
    Object.hashAll(conditions),
    Object.hashAll(values ?? const []),
  );

  @override
  String toString() =>
      'OsColumnFilterModel(filterType: $filterType, operator: $operator, '
      'conditions: $conditions, values: $values)';
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
