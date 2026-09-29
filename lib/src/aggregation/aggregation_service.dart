import 'package:os_grid_flutter/os_grid_flutter.dart' show RowGroupService;

import 'package:os_grid_flutter/src/row_grouping/row_group_service.dart'
    show RowGroupService;

import '../columns/os_column_def.dart';
import '../params/value_getter_params.dart';
import '../utils/grid_diagnostics.dart';

/// Parameters passed to custom aggregation functions.
///
/// Provides the list of values to aggregate along with column context.
class OsAggFuncParams<TData> {
  const OsAggFuncParams({required this.values, required this.column});

  /// The values to aggregate (from all leaf rows in the group).
  final List<dynamic> values;

  /// The column definition that has this aggFunc.
  final OsColumnDef<TData> column;
}

/// Type alias for a custom aggregation function.
///
/// Receives aggregation parameters and returns the computed aggregate value.
typedef OsAggFunc<TData> = dynamic Function(OsAggFuncParams<TData> params);

/// Metadata key for aggregate data stored on group rows.
///
/// The value is a `Map<String, dynamic>` keyed by column field/colId,
/// with the computed aggregate value for each value column.
const String kGroupAggData = '__groupAggData';

/// Service that computes aggregate values for group rows.
///
/// When columns have an [OsColumnDef.aggFunc] set (the "value columns"),
/// this service collects the leaf row values for each group and computes
/// the aggregate (sum, avg, count, min, max, first, last, or a custom function).
///
/// This service is called by [RowGroupService] during the tree-building phase
/// so that aggregate data is available for both expanded and collapsed groups.
class AggregationService<TData> {
  /// Computes aggregate values for a group given its leaf rows.
  ///
  /// [leafRows] — all leaf data rows belonging to this group (recursive).
  /// [valueColumns] — columns with aggFunc configured.
  ///
  /// Returns a map of colId → aggregate value.
  Map<String, dynamic> computeGroupAggregates({
    required List<TData> leafRows,
    required List<OsColumnDef> valueColumns,
  }) {
    final aggData = <String, dynamic>{};

    for (final col in valueColumns) {
      final colId = col.effectiveColId;
      final values = <dynamic>[];

      for (final row in leafRows) {
        values.add(_extractValue(row, col));
      }

      aggData[colId] = _computeAggValue(col, values);
    }

    return aggData;
  }

  /// Extracts the value from a data row for a given column.
  ///
  /// Getter-aware: the getter is invoked with a real [ValueGetterParams]
  /// so typed getter signatures type-check at runtime; a throwing getter
  /// falls back to field lookup.
  dynamic _extractValue(TData row, OsColumnDef col) {
    // Try valueGetter first.
    final getter = col.getValueGetterAsFunction();
    if (getter != null) {
      try {
        return Function.apply(getter, [
          ValueGetterParams<TData>(data: row, rowIndex: 0),
        ]);
      } catch (e) {
        GridDiagnostics.warnOnce(
          'aggregation:valueGetter',
          'valueGetter threw during aggregation for column '
              '"${col.effectiveColId}"; falling back to field lookup: $e',
        );
        // Fall through to field lookup.
      }
    }

    // Map-based field lookup.
    if (row is Map<String, dynamic>) {
      final field = col.field;
      if (field != null) return row[field];
    }

    return null;
  }

  /// Computes the aggregate value for a column given a list of leaf values.
  dynamic _computeAggValue(OsColumnDef col, List<dynamic> values) {
    final aggFunc = col.aggFunc;
    if (aggFunc == null) return null;

    // String-based built-in function.
    if (aggFunc is String) {
      return _builtInAggFunc(aggFunc, values);
    }

    // Custom function callback.
    if (aggFunc is Function) {
      try {
        return Function.apply(aggFunc, [
          OsAggFuncParams(values: values, column: col),
        ]);
      } catch (e) {
        GridDiagnostics.warnOnce(
          'aggregation:aggFunc',
          'Custom aggFunc threw for column "${col.effectiveColId}"; '
              'aggregate value will be null: $e',
        );
        return null;
      }
    }

    return null;
  }

  /// Evaluates a built-in aggregation function by name.
  ///
  /// Supported names: `sum`, `avg`, `count`, `min`, `max`, `first`, `last`.
  /// Returns `null` for unknown names. Public so other components (e.g. the
  /// status bar aggregation panels) reuse the exact semantics used for
  /// group aggregation.
  static dynamic builtInAgg(String name, List<dynamic> values) =>
      _builtInAggFunc(name, values);

  static dynamic _builtInAggFunc(String name, List<dynamic> values) {
    switch (name) {
      case 'sum':
        return _aggSum(values);
      case 'avg':
        return _aggAvg(values);
      case 'count':
        return _aggCount(values);
      case 'min':
        return _aggMin(values);
      case 'max':
        return _aggMax(values);
      case 'first':
        return _aggFirst(values);
      case 'last':
        return _aggLast(values);
      default:
        return null;
    }
  }

  /// Sum of numeric values (ignores non-numeric).
  static num? _aggSum(List<dynamic> values) {
    num? result;
    for (final v in values) {
      if (v is num) {
        result = (result ?? 0) + v;
      }
    }
    return result;
  }

  /// Average of numeric values (ignores non-numeric).
  static double? _aggAvg(List<dynamic> values) {
    num sum = 0;
    int count = 0;
    for (final v in values) {
      if (v is num) {
        sum += v;
        count++;
      }
    }
    if (count == 0) return null;
    return sum / count;
  }

  /// Count of non-null values.
  static int _aggCount(List<dynamic> values) {
    int count = 0;
    for (final v in values) {
      if (v != null) count++;
    }
    return count;
  }

  /// Minimum numeric value (ignores non-numeric).
  static num? _aggMin(List<dynamic> values) {
    num? result;
    for (final v in values) {
      if (v is num) {
        if (result == null || v < result) {
          result = v;
        }
      }
    }
    return result;
  }

  /// Maximum numeric value (ignores non-numeric).
  static num? _aggMax(List<dynamic> values) {
    num? result;
    for (final v in values) {
      if (v is num) {
        if (result == null || v > result) {
          result = v;
        }
      }
    }
    return result;
  }

  /// First non-null value.
  static dynamic _aggFirst(List<dynamic> values) {
    for (final v in values) {
      if (v != null) return v;
    }
    return null;
  }

  /// Last non-null value.
  static dynamic _aggLast(List<dynamic> values) {
    for (var i = values.length - 1; i >= 0; i--) {
      if (values[i] != null) return values[i];
    }
    return null;
  }
}
