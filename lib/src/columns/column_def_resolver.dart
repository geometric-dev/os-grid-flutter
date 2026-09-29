import 'os_column_def.dart';

/// Resolution of `defaultColDef` / `columnTypes` for data columns.
///
/// Merge precedence per field (AG Grid semantics):
/// explicit colDef > each type in listed order > defaultColDef.
///
/// Only NULLABLE [OsColumnDef] fields participate: non-nullable convenience
/// flags (`sortable`, `resizable`, `autoHeight`, `wrapText`) bake their
/// defaults into every instance, so a default cannot be distinguished from
/// an explicit value. Documented limitation.
class ColumnDefResolver {
  ColumnDefResolver._();

  /// Returns [columns] with defaults/types merged into new instances.
  ///
  /// When both [defaultColDef] and [columnTypes] are absent/empty the same
  /// list is returned untouched.
  static List<OsColumnDef> resolve({
    required List<OsColumnDef> columns,
    required OsColumnDef<dynamic>? defaultColDef,
    required Map<String, OsColumnDef<dynamic>>? columnTypes,
  }) {
    final hasDefaults = defaultColDef != null;
    final hasTypes = columnTypes != null && columnTypes.isNotEmpty;
    if (!hasDefaults && !hasTypes) return columns;

    return [
      for (final col in columns)
        _mergeOne(
          explicit: col,
          defaultDef: hasDefaults ? defaultColDef : null,
          types: hasTypes ? _typesFor(col.type, columnTypes) : const [],
        ),
    ];
  }

  /// Names in [typeSpec] missing from [columnTypes] (for warnings).
  static List<String> unknownTypeNames({
    required Object? typeSpec,
    required Map<String, OsColumnDef<dynamic>>? columnTypes,
  }) {
    if (typeSpec == null || columnTypes == null || columnTypes.isEmpty) {
      return const [];
    }
    final names = switch (typeSpec) {
      final String s => [s],
      final List l => l.whereType<String>().toList(),
      _ => <String>[],
    };
    return [
      for (final n in names)
        if (!columnTypes.containsKey(n)) n,
    ];
  }

  static List<OsColumnDef<dynamic>> _typesFor(
    Object? typeSpec,
    Map<String, OsColumnDef<dynamic>> columnTypes,
  ) {
    final names = switch (typeSpec) {
      null => const <String>[],
      final String s => [s],
      final List l => l.whereType<String>().toList(),
      _ => <String>[],
    };
    return [
      for (final name in names)
        if (columnTypes.containsKey(name)) columnTypes[name]!,
    ];
  }

  static OsColumnDef _mergeOne({
    required OsColumnDef explicit,
    required OsColumnDef? defaultDef,
    required List<OsColumnDef> types,
  }) {
    if (defaultDef == null && types.isEmpty) return explicit;

    // Sources in reverse precedence; first non-null wins.
    final sources = <OsColumnDef>[
      explicit,
      ...types.reversed,
      if (defaultDef != null) defaultDef,
    ];

    Object? pick(Object? Function(dynamic s) get) {
      for (final s in sources) {
        final v = get(s);
        if (v != null) return v;
      }
      return null;
    }

    // Dynamic dispatch intentionally, in two places: merged closures come
    // from defs with identical field semantics but potentially different
    // (erased) type arguments, which static generics would reject despite
    // being safe. Accessing TData-parameterized members (cellStyle,
    // valueGetter, ...) through a statically-typed source would implicit-
    // downcast the tear-off and throw a covariant TypeError for concretely
    // typed columns (OsColumnDef<TData> read as OsColumnDef<dynamic>) — the
    // same pitfall body_painter dodges with dynamic access.
    // ignore: avoid_dynamic_calls
    return (explicit as dynamic).copyWith(
      field: pick((s) => s.field),
      colId: pick((s) => s.colId),
      headerName: pick((s) => s.headerName),
      headerValueGetter: pick((s) => s.headerValueGetter),
      width: pick((s) => s.width),
      minWidth: pick((s) => s.minWidth),
      maxWidth: pick((s) => s.maxWidth),
      flex: pick((s) => s.flex),
      valueGetter: pick((s) => s.valueGetter),
      valueFormatter: pick((s) => s.valueFormatter),
      cellRenderer: pick((s) => s.cellRenderer),
      cellRendererBuilder: pick((s) => s.cellRendererBuilder),
      builtInCellRenderer: pick((s) => s.builtInCellRenderer),
      filter: pick((s) => s.filter),
      editable: pick((s) => s.editable),
      editableCallback: pick((s) => s.editableCallback),
      cellEditor: pick((s) => s.cellEditor),
      valueSetter: pick((s) => s.valueSetter),
      valueParser: pick((s) => s.valueParser),
      singleClickEdit: pick((s) => s.singleClickEdit),
      suppressMovable: pick((s) => s.suppressMovable),
      colSpan: pick((s) => s.colSpan),
      rowSpan: pick((s) => s.rowSpan),
      spanRows: pick((s) => s.spanRows),
      pinned: pick((s) => s.pinned),
      hide: pick((s) => s.hide),
      lockVisible: pick((s) => s.lockVisible),
      lockPinned: pick((s) => s.lockPinned),
      lockPosition: pick((s) => s.lockPosition),
      suppressMenu: pick((s) => s.suppressMenu),
      checkboxSelection: pick((s) => s.checkboxSelection),
      headerCheckboxSelection: pick((s) => s.headerCheckboxSelection),
      cellStyle: pick((s) => s.cellStyle),
      cellClass: pick((s) => s.cellClass),
      theme: pick((s) => s.theme),
      comparator: pick((s) => s.comparator),
      sortingOrder: pick((s) => s.sortingOrder),
      sort: pick((s) => s.sort),
      initialSort: pick((s) => s.initialSort),
      sortIndex: pick((s) => s.sortIndex),
      getQuickFilterText: pick((s) => s.getQuickFilterText),
      rowGroup: pick((s) => s.rowGroup),
      aggFunc: pick((s) => s.aggFunc),
      pivot: pick((s) => s.pivot),
      tooltipField: pick((s) => s.tooltipField),
      tooltipValueGetter: pick((s) => s.tooltipValueGetter),
      headerTooltip: pick((s) => s.headerTooltip),
    );
  }
}
