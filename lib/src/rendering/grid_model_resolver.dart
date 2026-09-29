import '../cache/value_cache.dart';
import '../columns/os_column_def.dart';
import '../columns/os_column_pin.dart';
import '../data/lazy_row_map.dart';
import '../params/value_getter_params.dart';
import 'column_group_layout.dart';
import 'special_columns.dart';

/// Pure helpers that resolve widget-level column definitions into the flat
/// display model consumed by `VirtualisedGrid`.
///
/// Extracted from `_OsGridState.build` so the composition pipeline is
/// testable and free of side effects.
class GridModelResolver {
  GridModelResolver._();

  /// Reorders [columns] according to [order] (colIds), appending any columns
  /// missing from the list.
  static List<OsColumnDef> applyColumnOrder(
    List<OsColumnDef> columns,
    List<String>? order,
  ) {
    if (order == null) return columns;
    final colMap = {for (final c in columns) c.effectiveColId: c};
    final ordered = [
      for (final id in order)
        if (colMap.containsKey(id)) colMap[id]!,
    ];
    for (final col in columns) {
      if (!order.contains(col.effectiveColId)) {
        ordered.add(col);
      }
    }
    return ordered;
  }

  /// Filters out hidden columns.
  static List<OsColumnDef> applyHidden(
    List<OsColumnDef> columns,
    Set<String> hiddenIds,
  ) {
    if (hiddenIds.isEmpty) return columns;
    return columns
        .where((col) => !hiddenIds.contains(col.effectiveColId))
        .toList();
  }

  /// Returns copies of [columns] with pin overrides applied via copyWith so
  /// every other column property survives.
  static List<OsColumnDef> applyPinOverrides(
    List<OsColumnDef> columns,
    Map<String, OsColumnPin?> overrides,
  ) {
    if (overrides.isEmpty) return columns;
    return [
      for (final col in columns)
        overrides.containsKey(col.effectiveColId)
            ? col.copyWith(pinned: overrides[col.effectiveColId])
            : col,
    ];
  }

  /// Composes the final display column list by prefixing synthetic columns
  /// (drag handle, row numbers, checkbox) ahead of the data columns, and
  /// shifts group-header spans plus indexed widths accordingly.
  ///
  /// This replaces the three copy-pasted "insert + shift" blocks that used
  /// to live in `_OsGridState.build`.
  static ({
    List<OsColumnDef> columns,
    List<ColumnGroupSpan> spans,
    Map<int, double> widths,
  })
  composeDisplayColumns({
    required List<OsColumnDef> dataColumns,
    required List<ColumnGroupSpan> groupSpans,
    required Map<int, double> indexedWidths,
    bool checkbox = false,
    bool rowNumbers = false,
    bool rowDrag = false,
    String? checkboxHeaderState,
  }) {
    final prefix = <OsColumnDef>[
      if (rowDrag)
        const OsColumnDef(
          field: SpecialColumns.rowDrag,
          headerName: '',
          width: 32,
          pinned: OsColumnPin.left,
          sortable: false,
          resizable: false,
        ),
      if (rowNumbers)
        const OsColumnDef(
          field: SpecialColumns.rowNumber,
          headerName: '',
          width: 42,
          pinned: OsColumnPin.left,
        ),
      if (checkbox)
        OsColumnDef(
          field: SpecialColumns.checkbox,
          headerName: checkboxHeaderState ?? '',
          width: 32,
          pinned: OsColumnPin.left,
        ),
    ];

    final shift = prefix.length;
    final shiftedSpans = shift == 0
        ? groupSpans
        : [
            for (final s in groupSpans)
              ColumnGroupSpan(
                headerName: s.headerName,
                startIndex: s.startIndex + shift,
                endIndex: s.endIndex + shift,
              ),
          ];

    final shiftedWidths = <int, double>{
      if (shift > 0)
        for (final e in indexedWidths.entries) e.key + shift: e.value,
    };

    return (
      columns: [...prefix, ...dataColumns],
      spans: shiftedSpans,
      widths: shiftedWidths,
    );
  }

  /// Converts a typed (non-Map) row to a display map using each column's
  /// valueGetter. Columns without a valueGetter have no readable value on a
  /// typed row and are skipped.
  static Map<String, dynamic> typedRowToMap<TData>(
    TData row,
    int rowIndex,
    List<OsColumnDef> columns,
  ) {
    final map = <String, dynamic>{};
    for (final col in columns) {
      final field = col.field;
      if (field == null || field.startsWith('__')) continue;
      final getter = col.getValueGetterAsFunction();
      if (getter != null) {
        map[field] = Function.apply(getter, [
          ValueGetterParams<TData>(data: row, rowIndex: rowIndex),
        ]);
      }
    }
    return map;
  }

  /// Builds the shared field → column index consumed by the lazy row maps
  /// (quality program v3 item 15): getter-bearing, non-`__`-prefixed fields
  /// only — the exact key set [typedRowToMap] materialises eagerly. Build
  /// once per conversion pass and share it across every row of that pass.
  static Map<String, OsColumnDef> buildLazyFieldIndex(
    List<OsColumnDef> columns,
  ) {
    final index = <String, OsColumnDef>{};
    for (final col in columns) {
      final field = col.field;
      if (field == null || field.startsWith('__')) continue;
      if (col.getValueGetterAsFunction() == null) continue;
      index[field] = col;
    }
    return index;
  }

  /// Wraps a typed row in a lazy display map: valueGetters fire on first
  /// per-cell read instead of eagerly for the whole row (quality program v3
  /// item 15). When [valueCache] and [rowId] are provided, evaluations round-
  /// trip through the grid-level cache for cross-build reuse.
  static Map<String, dynamic> lazyRowToMap<TData>(
    TData row,
    int rowIndex,
    Map<String, OsColumnDef> lazyFieldIndex, {
    ValueCache? valueCache,
    String? rowId,
  }) {
    return LazyValueRowMap<TData>(
      row: row,
      rowIndex: rowIndex,
      columnsByField: lazyFieldIndex,
      valueCache: valueCache,
      rowId: rowId,
    );
  }
}
