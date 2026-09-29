import '../aggregation/aggregation_service.dart';
import '../columns/os_column_def.dart';
import '../params/value_getter_params.dart';
import '../row_grouping/row_group_service.dart';
import '../utils/grid_diagnostics.dart';

/// Keys used for pivot-specific metadata on group rows.
class PivotKeys {
  PivotKeys._();

  /// Whether pivot mode is active (stored on generated column IDs).
  static const String kPivotPrefix = 'pivot_';
}

/// Metadata describing a dynamically generated pivot result column.
///
/// Each pivot result column corresponds to one unique combination of
/// pivot values crossed with one value (aggregation) column.
class PivotResultColumn {
  const PivotResultColumn({
    required this.colId,
    required this.headerName,
    required this.pivotKeys,
    required this.valueColId,
    required this.valueColAggFunc,
    this.groupId,
  });

  /// The generated column ID (unique across all pivot result columns).
  final String colId;

  /// The display header for this column (the pivot value, or value col name).
  final String headerName;

  /// The pivot key path that identifies this column's position in the
  /// pivot hierarchy. For single-level pivot, this is a single-element list.
  /// For multi-level pivot, contains one key per pivot column level.
  final List<String> pivotKeys;

  /// The source value column's effective colId.
  final String valueColId;

  /// The aggregation function from the source value column.
  final Object? valueColAggFunc;

  /// The group ID for nested column groups (null for flat columns).
  final String? groupId;
}

/// Represents a group of pivot result columns under a shared header.
///
/// Used for multi-level pivot where pivot values form a hierarchy:
/// e.g., Year > Quarter > sum(Sales), avg(Profit).
class PivotColumnGroup {
  const PivotColumnGroup({
    required this.groupId,
    required this.headerName,
    required this.pivotKeys,
    this.children = const [],
    this.columns = const [],
  });

  /// Unique identifier for this column group.
  final String groupId;

  /// Display header (the pivot value at this level).
  final String headerName;

  /// The pivot key path up to this level.
  final List<String> pivotKeys;

  /// Child groups (for deeper pivot nesting).
  final List<PivotColumnGroup> children;

  /// Leaf columns in this group (at the deepest level).
  final List<PivotResultColumn> columns;
}

/// Service that performs pivot data transformation.
///
/// When pivot mode is active, this service:
/// 1. Extracts unique values from pivot columns across all data rows
/// 2. Generates dynamic [OsColumnDef] instances for pivot result columns
/// 3. Computes per-group, per-pivot-bucket aggregations
///
/// This integrates with [RowGroupService] and [AggregationService].
class PivotService<TData> {
  /// Extracts all unique values for each pivot column from the data.
  ///
  /// Returns a nested map structure:
  /// - For single pivot column: `{pivotValue: null}`
  /// - For multi-level: `{pivotValue1: {pivotValue2: null, ...}, ...}`
  ///
  /// The map preserves insertion order (LinkedHashMap in Dart).
  Map<String, dynamic> extractUniqueValues({
    required List<TData> data,
    required List<OsColumnDef> pivotColumns,
  }) {
    if (pivotColumns.isEmpty || data.isEmpty) return {};

    final result = <String, dynamic>{};
    for (final row in data) {
      _insertRowValues(row, pivotColumns, 0, result);
    }
    return result;
  }

  /// Recursively inserts a row's pivot values into the unique values tree.
  void _insertRowValues(
    TData row,
    List<OsColumnDef> pivotColumns,
    int depth,
    Map<String, dynamic> level,
  ) {
    final col = pivotColumns[depth];
    final value = _extractValue(row, col);
    final key = value?.toString() ?? '';

    if (depth == pivotColumns.length - 1) {
      // Leaf level — just record the key exists.
      level.putIfAbsent(key, () => null);
    } else {
      // Intermediate level — recurse into sub-map.
      final subMap =
          level.putIfAbsent(key, () => <String, dynamic>{})
              as Map<String, dynamic>;
      _insertRowValues(row, pivotColumns, depth + 1, subMap);
    }
  }

  /// Generates [OsColumnDef] instances for the pivot result columns.
  ///
  /// For each unique pivot value combination, creates one column per
  /// value column. The generated columns have:
  /// - A composite `colId` for unique identification
  /// - A `headerName` showing the pivot value (or "pivotValue - valueCol"
  ///   when multiple value columns exist)
  /// - A `valueGetter` that extracts from the pivot aggregate data
  ///
  /// Returns both the flat list of generated column definitions and
  /// the structured [PivotResultColumn] metadata.
  PivotResult generatePivotColumns({
    required Map<String, dynamic> uniqueValues,
    required List<OsColumnDef> pivotColumns,
    required List<OsColumnDef> valueColumns,
  }) {
    final resultColumns = <PivotResultColumn>[];
    final columnDefs = <OsColumnDef>[];

    _recursivelyBuildColumns(
      uniqueValues: uniqueValues,
      pivotColumns: pivotColumns,
      valueColumns: valueColumns,
      depth: 0,
      pivotKeys: [],
      resultColumns: resultColumns,
      columnDefs: columnDefs,
    );

    return PivotResult(columns: resultColumns, columnDefs: columnDefs);
  }

  void _recursivelyBuildColumns({
    required Map<String, dynamic> uniqueValues,
    required List<OsColumnDef> pivotColumns,
    required List<OsColumnDef> valueColumns,
    required int depth,
    required List<String> pivotKeys,
    required List<PivotResultColumn> resultColumns,
    required List<OsColumnDef> columnDefs,
  }) {
    // Order unique pivot values using the pivot column's own comparator when
    // available, else numeric-aware comparison, with a stable first-seen
    // tie-break (so keys like 1, 2, 10 don't order lexicographically).
    final sortedKeys = _orderPivotKeys(
      uniqueValues.keys.toList(),
      depth < pivotColumns.length ? pivotColumns[depth] : null,
    );

    for (final key in sortedKeys) {
      final newPivotKeys = [...pivotKeys, key];

      if (depth < pivotColumns.length - 1) {
        // Intermediate level — recurse into sub-values.
        final subValues = uniqueValues[key] as Map<String, dynamic>?;
        if (subValues != null && subValues.isNotEmpty) {
          _recursivelyBuildColumns(
            uniqueValues: subValues,
            pivotColumns: pivotColumns,
            valueColumns: valueColumns,
            depth: depth + 1,
            pivotKeys: newPivotKeys,
            resultColumns: resultColumns,
            columnDefs: columnDefs,
          );
        }
      } else {
        // Leaf level — create measure columns for each value column.
        _buildMeasureColumns(
          pivotKeys: newPivotKeys,
          pivotColumns: pivotColumns,
          valueColumns: valueColumns,
          resultColumns: resultColumns,
          columnDefs: columnDefs,
        );
      }
    }
  }

  /// Orders pivot dimension keys for result-column generation.
  ///
  /// 1. When [pivotColumn] defines an `comparator`, it is invoked with the
  ///    coerced key values (see [_coercePivotKey]) and null row nodes,
  ///    ascending.
  /// 2. Otherwise a numeric-aware comparison is used ([_numericAwareCompare]).
  /// 3. Ties fall back to first-seen (insertion) order. The index fallback
  ///    makes the comparator total, so the result is deterministic even
  ///    though Dart's `List.sort` is not stable.
  static List<String> _orderPivotKeys(
    List<String> keys,
    OsColumnDef? pivotColumn,
  ) {
    final firstSeenIndex = <String, int>{};
    for (var i = 0; i < keys.length; i++) {
      firstSeenIndex.putIfAbsent(keys[i], () => i);
    }
    final sorted = List<String>.of(keys)
      ..sort((a, b) {
        final result = _comparePivotKeyValues(a, b, pivotColumn);
        if (result != 0) return result;
        return firstSeenIndex[a]!.compareTo(firstSeenIndex[b]!);
      });
    return sorted;
  }

  /// Compares two string pivot keys via the column comparator when present,
  /// else numerically-aware; falls back to the default comparison if the
  /// custom comparator throws.
  static int _comparePivotKeyValues(String a, String b, OsColumnDef? col) {
    final comparator = col?.comparator;
    if (comparator != null) {
      try {
        return comparator(
          _coercePivotKey(a),
          _coercePivotKey(b),
          null,
          null,
          false,
        );
      } catch (e) {
        // A throwing comparator must not break pivot generation.
        GridDiagnostics.warnOnce(
          'pivot:comparator',
          'Pivot key comparator threw; falling back to numeric-aware '
              'comparison: $e',
        );
      }
    }
    return _numericAwareCompare(a, b);
  }

  /// Coerces a string pivot key to its natural type for comparator
  /// invocation (numeric strings become `num`).
  static dynamic _coercePivotKey(String key) => num.tryParse(key) ?? key;

  /// Numeric-aware comparison for string pivot keys: when both parse as
  /// numbers they compare numerically (`2` before `10`); mixed pairs compare
  /// lexicographically (equivalent to `toString()` comparison since keys
  /// are already strings).
  static int _numericAwareCompare(String a, String b) {
    final numA = num.tryParse(a);
    final numB = num.tryParse(b);
    if (numA != null && numB != null) return numA.compareTo(numB);
    return a.compareTo(b);
  }

  /// Builds the measure (value) columns for a specific pivot key combination.
  void _buildMeasureColumns({
    required List<String> pivotKeys,
    required List<OsColumnDef> pivotColumns,
    required List<OsColumnDef> valueColumns,
    required List<PivotResultColumn> resultColumns,
    required List<OsColumnDef> columnDefs,
  }) {
    final pivotColIds = pivotColumns.map((c) => c.effectiveColId).join('-');
    final pivotKeyStr = pivotKeys.join('-');
    final hasMultipleValueCols = valueColumns.length > 1;

    if (valueColumns.isEmpty) {
      // No value columns — create a placeholder column.
      final colId = 'pivot_${pivotColIds}_${pivotKeyStr}_placeholder';
      final headerName = pivotKeys.last;
      resultColumns.add(
        PivotResultColumn(
          colId: colId,
          headerName: headerName,
          pivotKeys: pivotKeys,
          valueColId: '',
          valueColAggFunc: null,
        ),
      );
      columnDefs.add(
        OsColumnDef(
          field: colId,
          colId: colId,
          headerName: headerName,
          sortable: false,
        ),
      );
      return;
    }

    for (final valueCol in valueColumns) {
      final valueColId = valueCol.effectiveColId;
      final colId = 'pivot_${pivotColIds}_${pivotKeyStr}_$valueColId';

      // Header: "pivotValue - valueColName" or just "pivotValue" if single.
      final String headerName;
      if (hasMultipleValueCols) {
        headerName = '${pivotKeys.last} - ${valueCol.effectiveHeaderName}';
      } else {
        headerName = pivotKeys.last;
      }

      final resultCol = PivotResultColumn(
        colId: colId,
        headerName: headerName,
        pivotKeys: pivotKeys,
        valueColId: valueColId,
        valueColAggFunc: valueCol.aggFunc,
      );
      resultColumns.add(resultCol);

      // Generate an OsColumnDef for this pivot result column.
      // The field is set to the colId so the grid can extract values
      // from the flattened group row's pivot aggregate data.
      columnDefs.add(
        OsColumnDef(
          field: colId,
          colId: colId,
          headerName: headerName,
          sortable: false,
          resizable: true,
          valueFormatter: valueCol.valueFormatter,
          width: valueCol.width,
          minWidth: valueCol.minWidth,
          maxWidth: valueCol.maxWidth,
          flex: valueCol.flex,
        ),
      );
    }
  }

  /// Computes pivot-specific aggregation for grouped data.
  ///
  /// For each group row in the display data, computes aggregates bucketed
  /// by pivot column values. The result is stored in the group row's
  /// `__groupAggData` map with keys matching the generated pivot column IDs.
  ///
  /// [displayData] — the flattened display list (from RowGroupService).
  /// [rawData] — the original flat data (for leaf row lookups).
  /// [pivotColumns] — the columns marked as pivot columns.
  /// [valueColumns] — the columns with aggFunc.
  /// [groupColumns] — the columns used for row grouping.
  /// [pivotResultColumns] — the generated pivot column metadata.
  ///
  /// Returns a new display data list with pivot aggregate values injected
  /// into group rows.
  List<Map<String, dynamic>> computePivotAggregation({
    required List<Map<String, dynamic>> displayData,
    required List<TData> rawData,
    required List<OsColumnDef> pivotColumns,
    required List<OsColumnDef> valueColumns,
    required List<OsColumnDef> groupColumns,
    required List<PivotResultColumn> pivotResultColumns,
  }) {
    if (pivotResultColumns.isEmpty) return displayData;

    // Build a lookup: for each group node ID, collect the leaf rows
    // that belong to it, bucketed by pivot key combination.
    final groupBuckets = _buildGroupPivotBuckets(
      rawData: rawData,
      pivotColumns: pivotColumns,
      groupColumns: groupColumns,
    );

    final aggService = AggregationService<TData>();

    // Inject pivot aggregate values into group rows.
    final result = <Map<String, dynamic>>[];
    for (final row in displayData) {
      if (row[RowGroupKeys.kIsGroupRow] == true) {
        final nodeId = row[RowGroupKeys.kGroupNodeId] as String;
        final buckets = groupBuckets[nodeId];

        final pivotAggData = <String, dynamic>{};

        if (buckets != null) {
          for (final pivotCol in pivotResultColumns) {
            if (pivotCol.valueColId.isEmpty) continue;

            final bucketKey = pivotCol.pivotKeys.join('|');
            final leafRows = buckets[bucketKey];

            if (leafRows != null && leafRows.isNotEmpty) {
              // Find the value column definition.
              final valueCol = valueColumns.cast<OsColumnDef?>().firstWhere(
                (c) => c!.effectiveColId == pivotCol.valueColId,
                orElse: () => null,
              );
              if (valueCol != null) {
                final aggResult = aggService.computeGroupAggregates(
                  leafRows: leafRows,
                  valueColumns: [valueCol],
                );
                pivotAggData[pivotCol.colId] = aggResult[pivotCol.valueColId];
              }
            }
          }
        }

        // Also store leaf row data for pivot columns on expanded leaf rows.
        // Merge pivot agg data with any existing agg data.
        final existingAggData =
            row[RowGroupKeys.kGroupAggData] as Map<String, dynamic>? ?? {};
        result.add({
          ...row,
          RowGroupKeys.kGroupAggData: {...existingAggData, ...pivotAggData},
          // Also put pivot values at top level for field-based lookup.
          ...pivotAggData,
        });
      } else {
        // Leaf row: extract the actual value for each pivot result column.
        final leafPivotData = <String, dynamic>{};
        for (final pivotCol in pivotResultColumns) {
          if (pivotCol.valueColId.isEmpty) continue;

          // Check if this leaf row's pivot values match this column's pivotKeys.
          final pivotValues = <String>[];
          for (final pc in pivotColumns) {
            final v = _extractValueFromMap(row, pc);
            pivotValues.add(v?.toString() ?? '');
          }

          if (_listsEqual(pivotValues, pivotCol.pivotKeys)) {
            // This leaf row belongs to this pivot column — extract its value.
            final valueCol = valueColumns.cast<OsColumnDef?>().firstWhere(
              (c) => c!.effectiveColId == pivotCol.valueColId,
              orElse: () => null,
            );
            if (valueCol != null) {
              leafPivotData[pivotCol.colId] = _extractValueFromMap(
                row,
                valueCol,
              );
            }
          }
        }
        result.add({...row, ...leafPivotData});
      }
    }

    return result;
  }

  /// Builds a mapping from group node ID to pivot-bucketed leaf rows.
  ///
  /// For each group, the leaves are sorted into buckets keyed by the
  /// combined pivot column values (joined with '|').
  Map<String, Map<String, List<TData>>> _buildGroupPivotBuckets({
    required List<TData> rawData,
    required List<OsColumnDef> pivotColumns,
    required List<OsColumnDef> groupColumns,
  }) {
    // Step 1: Build group assignment for each row.
    // For each leaf row, determine which group(s) it belongs to and
    // what its pivot key is.
    final result = <String, Map<String, List<TData>>>{};

    for (final row in rawData) {
      // Compute the pivot bucket key for this row.
      final pivotKey = _computePivotKey(row, pivotColumns);

      // Add to all ancestor group buckets (for multi-level grouping).
      String parentId = '';
      for (int level = 0; level < groupColumns.length; level++) {
        final groupCol = groupColumns[level];
        final groupValue = _extractValue(row, groupCol);
        // Build node IDs via RowGroupService.makeNodeId so the escaping
        // scheme matches grouped display rows exactly (keys containing
        // '-' must not break bucket lookups).
        final nodeId = RowGroupService.makeNodeId(
          parentId,
          groupCol.effectiveColId,
          groupValue,
        );

        result.putIfAbsent(nodeId, () => <String, List<TData>>{});
        result[nodeId]!.putIfAbsent(pivotKey, () => <TData>[]);
        result[nodeId]![pivotKey]!.add(row);

        parentId = nodeId;
      }
    }

    return result;
  }

  /// Computes the pivot bucket key for a row (all pivot values joined).
  String _computePivotKey(TData row, List<OsColumnDef> pivotColumns) {
    final keys = <String>[];
    for (final col in pivotColumns) {
      final value = _extractValue(row, col);
      keys.add(value?.toString() ?? '');
    }
    return keys.join('|');
  }

  /// Extracts a value from a row for a given column definition.
  ///
  /// Getter-aware: tries the column's `valueGetter` first, then falls back
  /// to map-based field lookup.
  dynamic _extractValue(TData row, OsColumnDef col) =>
      _extractValueFromRow<TData>(row, col);

  /// Extracts a value from a Map row for a given column definition.
  ///
  /// Routes through the same getter-aware path as [_extractValue] so leaf
  /// rows honour `valueGetter` exactly like pivot-column and aggregation
  /// extraction does, falling back to plain field lookup.
  dynamic _extractValueFromMap(Map<String, dynamic> row, OsColumnDef col) =>
      _extractValueFromRow<Map<String, dynamic>>(row, col);

  /// Shared getter-aware value extraction used by [_extractValue] and
  /// [_extractValueFromMap].
  ///
  /// The getter is invoked with real [ValueGetterParams] so typed getter
  /// signatures type-check at runtime; a throwing getter falls back to
  /// field lookup.
  dynamic _extractValueFromRow<R>(R row, OsColumnDef col) {
    // Try valueGetter first.
    final getter = col.getValueGetterAsFunction();
    if (getter != null) {
      try {
        return Function.apply(getter, [
          ValueGetterParams<R>(data: row, rowIndex: 0),
        ]);
      } catch (e) {
        GridDiagnostics.warnOnce(
          'pivot:valueGetter',
          'valueGetter threw during pivot extraction for column '
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

  /// Checks if two lists of strings are equal.
  bool _listsEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// The result of pivot column generation.
class PivotResult {
  const PivotResult({required this.columns, required this.columnDefs});

  /// Metadata about each generated pivot result column.
  final List<PivotResultColumn> columns;

  /// The generated [OsColumnDef] instances to use for rendering.
  final List<OsColumnDef> columnDefs;
}
