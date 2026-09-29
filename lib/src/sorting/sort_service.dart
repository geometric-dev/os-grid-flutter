import '../columns/os_column_def.dart';
import '../params/value_getter_params.dart';
import '../utils/grid_diagnostics.dart';
import 'sort_direction.dart';
import 'sort_model.dart';

/// Manages multi-column sort state and provides sort comparison logic.
///
/// This mirrors OS Grid's `SortService` and `RowNodeSorter` — handling
/// sort progression (asc → desc → clear), multi-column sort with priority
/// indices, and the actual row comparison using the sort model.
class SortService<TData> {
  /// The current sort model — an ordered list of column sorts.
  ///
  /// The order determines priority: index 0 is the primary sort,
  /// index 1 is the secondary sort, etc.
  List<OsSortModel> _sortModel = [];

  /// Returns the current sort model (unmodifiable view).
  List<OsSortModel> get sortModel => List.unmodifiable(_sortModel);

  /// Whether accented/locale-aware string comparison is used.
  ///
  /// When `true`, string comparisons use locale-sensitive ordering
  /// (equivalent to `String.localeCompare` in JavaScript). This is
  /// slower but correctly handles accented characters (é, ñ, ü, etc.).
  ///
  /// Note: Dart does not provide built-in ICU collation without `package:intl`.
  /// This implementation uses case-folded comparison which handles basic
  /// case-insensitivity but does not provide full Unicode collation order
  /// (e.g. ä sorting with a in German). For full locale-aware sorting,
  /// provide a custom [OsColumnDef.comparator].
  bool accentedSort = false;

  /// Sets the sort model directly (e.g. from `initialSort` or API).
  void setSortModel(List<OsSortModel> model) {
    _sortModel = List.of(model);
  }

  /// Progresses the sort for a column based on a header click.
  ///
  /// If [multiSort] is `true`, the column is added to (or updated in)
  /// the existing sort model. If `false`, the sort model is replaced
  /// with only this column.
  ///
  /// [sortingOrder] defines the custom sort cycle for this column.
  /// When `null`, the default cycle is used: ascending → descending → none (clear).
  /// A `null` entry in the list represents "clear sort".
  ///
  /// Sort progression: none → ascending → descending → none (removed).
  void progressSort({
    required String colId,
    required bool multiSort,
    List<OsSortDirection?>? sortingOrder,
  }) {
    final cycle = sortingOrder ?? _defaultSortingOrder;
    final existingIndex = _sortModel.indexWhere((m) => m.colId == colId);

    if (existingIndex >= 0) {
      final existing = _sortModel[existingIndex];
      // Find current position in cycle
      final currentDirection = existing.sort;
      final currentCycleIndex = cycle.indexOf(currentDirection);
      final nextCycleIndex = (currentCycleIndex + 1) % cycle.length;
      final nextDirection = cycle[nextCycleIndex];

      // If we've cycled back to the beginning and the current direction
      // is the last in the cycle, or if next is null (clear), remove sort
      if (nextDirection == null) {
        if (multiSort) {
          _sortModel.removeAt(existingIndex);
        } else {
          _sortModel = [];
        }
      } else {
        if (multiSort) {
          _sortModel[existingIndex] = OsSortModel(
            colId: colId,
            sort: nextDirection,
          );
        } else {
          _sortModel = [OsSortModel(colId: colId, sort: nextDirection)];
        }
      }
    } else {
      // Not currently sorted — start with first direction in cycle
      final firstDirection = cycle.isNotEmpty
          ? cycle.first
          : OsSortDirection.ascending;
      if (firstDirection == null) {
        // Edge case: cycle starts with null (clear) — skip to next
        final nextNonNull = cycle.firstWhere(
          (d) => d != null,
          orElse: () => null,
        );
        if (nextNonNull == null) return; // All null cycle — do nothing
        if (multiSort) {
          _sortModel.add(OsSortModel(colId: colId, sort: nextNonNull));
        } else {
          _sortModel = [OsSortModel(colId: colId, sort: nextNonNull)];
        }
      } else {
        if (multiSort) {
          _sortModel.add(OsSortModel(colId: colId, sort: firstDirection));
        } else {
          _sortModel = [OsSortModel(colId: colId, sort: firstDirection)];
        }
      }
    }
  }

  /// The default sort cycle: ascending → descending → clear.
  static const List<OsSortDirection?> _defaultSortingOrder = [
    OsSortDirection.ascending,
    OsSortDirection.descending,
    null,
  ];

  /// Sets a specific sort direction for a column (e.g. from column menu).
  ///
  /// If [direction] is `null`, the column is removed from the sort model.
  void setColumnSort({
    required String colId,
    OsSortDirection? direction,
    bool multiSort = false,
  }) {
    if (direction == null) {
      // Clear sort for this column
      _sortModel.removeWhere((m) => m.colId == colId);
      return;
    }

    final existingIndex = _sortModel.indexWhere((m) => m.colId == colId);

    if (multiSort) {
      if (existingIndex >= 0) {
        _sortModel[existingIndex] = OsSortModel(colId: colId, sort: direction);
      } else {
        _sortModel.add(OsSortModel(colId: colId, sort: direction));
      }
    } else {
      _sortModel = [OsSortModel(colId: colId, sort: direction)];
    }
  }

  /// Clears all sort state.
  void clearSort() {
    _sortModel = [];
  }

  /// Returns the sort direction for a specific column, or `null` if unsorted.
  OsSortDirection? getSortDirection(String colId) {
    final match = _sortModel.where((m) => m.colId == colId);
    return match.isEmpty ? null : match.first.sort;
  }

  /// Returns the sort priority index (0-based) for a column, or `null` if unsorted.
  ///
  /// Only meaningful when multiple columns are sorted. The priority number
  /// displayed in the header is `sortIndex + 1`.
  int? getSortIndex(String colId) {
    final idx = _sortModel.indexWhere((m) => m.colId == colId);
    return idx >= 0 ? idx : null;
  }

  /// Whether multiple columns are currently sorted (for showing priority numbers).
  bool get isMultiSorting => _sortModel.length > 1;

  /// Whether any column is sorted.
  bool get isSortActive => _sortModel.isNotEmpty;

  /// Sorts the given data using the current sort model.
  ///
  /// [columns] is the flat list of column definitions (used to resolve
  /// field names and custom comparators).
  ///
  /// [valueResolver] is an optional function that resolves the value for
  /// a given row and column. When provided, it is used instead of the
  /// default valueGetter/field lookup. This enables value caching.
  ///
  /// Returns a new sorted list (does not mutate the input).
  ///
  /// The sort is stable: rows that compare equal under the sort model keep
  /// their original relative order (each row's original index is used as an
  /// implicit final tiebreaker, since Dart's `List.sort` is not stable).
  List<TData> sortData({
    required List<TData> data,
    required List<OsColumnDef> columns,
    dynamic Function(TData row, OsColumnDef column)? valueResolver,
  }) {
    if (_sortModel.isEmpty) return data;

    // Build sort instructions: resolve each sort model entry to a column def
    final instructions = <_SortInstruction>[];
    for (final model in _sortModel) {
      final col = columns.cast<OsColumnDef?>().firstWhere(
        (c) => c!.effectiveColId == model.colId,
        orElse: () => null,
      );
      if (col != null) {
        instructions.add(_SortInstruction(column: col, direction: model.sort));
      }
    }

    if (instructions.isEmpty) return data;

    // Decorate each row with its original index, sort with that index as an
    // implicit final tiebreaker, then unwrap. Dart's `List.sort` is not
    // stable, so this guarantees deterministic ordering for equal rows.
    final decorated = <({int index, TData row})>[
      for (var i = 0; i < data.length; i++) (index: i, row: data[i]),
    ];
    decorated.sort((a, b) {
      final result = _compareRows(a.row, b.row, instructions, valueResolver);
      if (result != 0) return result;
      return a.index.compareTo(b.index);
    });
    return [for (final entry in decorated) entry.row];
  }

  /// Compares two rows using the multi-column sort instructions.
  ///
  /// Iterates through sort columns in priority order. Returns the first
  /// non-zero comparison result (like OS Grid's `RowNodeSorter.compareRowNodes`).
  int _compareRows(
    TData a,
    TData b,
    List<_SortInstruction> instructions,
    dynamic Function(TData row, OsColumnDef column)? valueResolver,
  ) {
    for (final instruction in instructions) {
      final isDescending = instruction.direction == OsSortDirection.descending;
      final valueA = valueResolver != null
          ? valueResolver(a, instruction.column)
          : _getValue(a, instruction.column);
      final valueB = valueResolver != null
          ? valueResolver(b, instruction.column)
          : _getValue(b, instruction.column);

      int result;
      final comparator = instruction.column.comparator;
      if (comparator != null) {
        try {
          result = comparator(valueA, valueB, a, b, isDescending);
        } catch (e) {
          // A throwing user comparator must not break sorting: fall back
          // to the deterministic default comparison for this pair so the
          // sort still completes with a stable, reproducible ordering.
          GridDiagnostics.warnOnce(
            'sort:comparator',
            'Custom comparator for column '
                '"${instruction.column.effectiveColId}" threw; falling back to '
                'the default comparison: $e',
          );
          result = _defaultCompare(valueA, valueB);
        }
      } else {
        result = _defaultCompare(valueA, valueB);
      }

      if (result != 0) {
        return isDescending ? -result : result;
      }
    }
    return 0;
  }

  /// Extracts the value from a row for a given column.
  dynamic _getValue(TData row, OsColumnDef column) {
    final valueGetter = column.getValueGetterAsFunction();
    if (valueGetter != null) {
      return valueGetter(ValueGetterParams(data: row, rowIndex: -1));
    }
    if (column.field != null && row is Map<String, dynamic>) {
      return row[column.field];
    }
    return null;
  }

  /// Default comparison logic matching OS Grid's `_defaultComparator`.
  ///
  /// Handles nulls (null < non-null). Numbers are compared numerically and
  /// strings lexicographically (using [accentedSort] for locale-aware
  /// ordering when enabled). Mixed-type values fall back to comparing their
  /// string representations so heterogeneous columns never throw.
  int _defaultCompare(dynamic valueA, dynamic valueB) {
    if (valueA == null && valueB == null) return 0;
    if (valueA == null) return -1;
    if (valueB == null) return 1;

    // Numeric comparison (int, double, num)
    if (valueA is num && valueB is num) {
      return valueA.compareTo(valueB);
    }

    // String comparison with optional locale-aware ordering
    if (valueA is String && valueB is String) {
      if (accentedSort) {
        // Case-insensitive comparison that handles accented characters better
        // than plain compareTo. For full ICU collation, users should provide
        // a custom comparator using package:intl's Intl.collator.
        final lowerA = valueA.toLowerCase();
        final lowerB = valueB.toLowerCase();
        final result = lowerA.compareTo(lowerB);
        // If case-insensitive comparison is equal, use case-sensitive as tiebreaker
        if (result == 0) {
          return valueA.compareTo(valueB);
        }
        return result;
      }
      return valueA.compareTo(valueB);
    }

    // Mixed or non-comparable types — compare string representations so
    // mismatched column values (e.g. String vs num) never crash.
    return valueA.toString().compareTo(valueB.toString());
  }
}

/// Internal sort instruction pairing a column with its sort direction.
class _SortInstruction {
  const _SortInstruction({required this.column, required this.direction});

  final OsColumnDef column;
  final OsSortDirection direction;
}
