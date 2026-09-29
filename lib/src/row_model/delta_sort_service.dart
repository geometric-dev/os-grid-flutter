import 'dart:collection';

import '../columns/os_column_def.dart';
import '../sorting/sort_service.dart';

/// Minimum number of changed rows to enable delta sort.
///
/// Below this threshold, a full sort is faster due to lower overhead.
/// Matches OS Grid's `MIN_DELTA_SORT_ROWS` constant.
const int minDeltaSortRows = 4;

/// Service that performs incremental (delta) sorting after a transaction.
///
/// Instead of re-sorting the entire dataset when only a few rows change,
/// this service:
/// 1. Classifies rows as "touched" (added/updated) or "untouched"
/// 2. Sorts only the touched rows
/// 3. Merges them into the previously sorted untouched rows
///
/// Time complexity: O(t log t + n) where t = touched rows, n = total rows.
/// This is faster than full sort O(n log n) when t << n.
///
/// Mirrors OS Grid's `deltaSort.ts`.
class DeltaSortService<TData> {
  /// The previously sorted result, used as the base for delta sort.
  ///
  /// This is updated after each sort operation (full or delta).
  List<TData>? _previousSortedResult;

  /// Returns the previous sorted result (for testing/inspection).
  List<TData>? get previousSortedResult => _previousSortedResult;

  /// Clears the cached previous sort result.
  ///
  /// Should be called when the sort model changes (since the previous
  /// result is no longer valid for the new sort order).
  void invalidate() {
    _previousSortedResult = null;
  }

  /// Updates the cached previous sort result.
  ///
  /// Called after a full sort to establish the baseline for future delta sorts.
  void setPreviousResult(List<TData> sorted) {
    _previousSortedResult = List.of(sorted);
  }

  /// Attempts a delta sort on [allRows] given the [touchedRows] that changed.
  ///
  /// Returns the sorted list if delta sort was applied, or `null` if a full
  /// sort should be used instead (e.g. no previous result, too few rows, etc.).
  ///
  /// [allRows] is the complete dataset (after filter).
  /// [touchedRows] is the set of rows that were added or updated in the
  /// most recent transaction.
  /// [sortService] provides the comparison logic.
  /// [columns] are the column definitions for value resolution.
  /// [valueResolver] is an optional cached value resolver.
  List<TData>? tryDeltaSort({
    required List<TData> allRows,
    required Set<TData> touchedRows,
    required SortService<TData> sortService,
    required List<OsColumnDef> columns,
    dynamic Function(TData row, OsColumnDef column)? valueResolver,
  }) {
    // Cannot delta sort without a previous result.
    if (_previousSortedResult == null) return null;

    // Too few rows — full sort is faster.
    if (allRows.length <= minDeltaSortRows) return null;

    // If no rows are touched, check if we just need to filter removals.
    if (touchedRows.isEmpty) {
      final prev = _previousSortedResult!;
      if (prev.length == allRows.length) {
        // No changes at all — reuse previous result.
        return prev;
      }
      // Some rows were removed — filter them from previous result.
      final allRowsSet = LinkedHashSet<TData>.identity()..addAll(allRows);
      final filtered = prev.where((r) => allRowsSet.contains(r)).toList();
      _previousSortedResult = filtered;
      return filtered;
    }

    // If all rows are touched, fall back to full sort.
    if (touchedRows.length >= allRows.length) return null;

    // Build identity set of touched rows for O(1) lookup.
    final touchedSet = LinkedHashSet<TData>.identity()..addAll(touchedRows);

    // Separate touched and untouched rows, preserving their current indices.
    final touchedList = <TData>[];
    final currentIndexMap = <TData, int>{};

    for (int i = 0; i < allRows.length; i++) {
      final row = allRows[i];
      currentIndexMap[row] = i;
      if (touchedSet.contains(row)) {
        touchedList.add(row);
      }
    }

    // Sort only the touched rows.
    final sortedTouched = sortService.sortData(
      data: touchedList,
      columns: columns,
      valueResolver: valueResolver,
    );

    // Build the untouched rows in their previous sorted order.
    // Filter the previous sorted result to only include rows still present
    // and not touched.
    final allRowsIdentitySet = LinkedHashSet<TData>.identity()..addAll(allRows);
    final untouchedInOrder = _previousSortedResult!
        .where((r) => allRowsIdentitySet.contains(r) && !touchedSet.contains(r))
        .toList();

    // Merge sorted touched rows with untouched rows (two-pointer merge).
    final result = _merge(
      sortedTouched: sortedTouched,
      untouchedInOrder: untouchedInOrder,
      sortService: sortService,
      columns: columns,
      valueResolver: valueResolver,
      currentIndexMap: currentIndexMap,
    );

    _previousSortedResult = result;
    return result;
  }

  /// Two-pointer merge of sorted touched rows with untouched rows
  /// (already in correct relative order from previous sort).
  List<TData> _merge({
    required List<TData> sortedTouched,
    required List<TData> untouchedInOrder,
    required SortService<TData> sortService,
    required List<OsColumnDef> columns,
    dynamic Function(TData row, OsColumnDef column)? valueResolver,
    required Map<TData, int> currentIndexMap,
  }) {
    final resultSize = sortedTouched.length + untouchedInOrder.length;
    final result = List<TData>.filled(resultSize, sortedTouched.first);

    int touchedIdx = 0;
    int untouchedIdx = 0;
    int resultIdx = 0;

    while (touchedIdx < sortedTouched.length &&
        untouchedIdx < untouchedInOrder.length) {
      final touchedRow = sortedTouched[touchedIdx];
      final untouchedRow = untouchedInOrder[untouchedIdx];

      // Compare using the sort service's comparison logic.
      final cmp = _compareRows(
        touchedRow,
        untouchedRow,
        sortService,
        columns,
        valueResolver,
        currentIndexMap,
      );

      if (cmp <= 0) {
        result[resultIdx++] = touchedRow;
        touchedIdx++;
      } else {
        result[resultIdx++] = untouchedRow;
        untouchedIdx++;
      }
    }

    // Copy remaining touched rows.
    while (touchedIdx < sortedTouched.length) {
      result[resultIdx++] = sortedTouched[touchedIdx++];
    }

    // Copy remaining untouched rows.
    while (untouchedIdx < untouchedInOrder.length) {
      result[resultIdx++] = untouchedInOrder[untouchedIdx++];
    }

    return result;
  }

  /// Compares two rows using the sort service's sort model.
  ///
  /// Uses the current index as a stable tie-breaker to maintain
  /// insertion order for equal elements.
  int _compareRows(
    TData a,
    TData b,
    SortService<TData> sortService,
    List<OsColumnDef> columns,
    dynamic Function(TData row, OsColumnDef column)? valueResolver,
    Map<TData, int> currentIndexMap,
  ) {
    // Use sortData on a pair to leverage the existing comparison logic.
    // This is a simplified approach — for production, we'd expose the
    // comparator directly. But since SortService.sortData uses List.sort
    // internally, we can compare by sorting a 2-element list.
    //
    // More efficient: directly call the comparison. We'll use a helper
    // that leverages the sort service's internal logic.
    final sorted = sortService.sortData(
      data: [a, b],
      columns: columns,
      valueResolver: valueResolver,
    );

    if (identical(sorted[0], a)) {
      if (identical(sorted[1], a)) {
        // Both are the same object (shouldn't happen), use index tie-breaker.
        return (currentIndexMap[a] ?? 0) - (currentIndexMap[b] ?? 0);
      }
      return -1; // a comes before b
    }
    return 1; // b comes before a
  }
}
