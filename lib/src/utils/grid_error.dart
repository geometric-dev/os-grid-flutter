/// Machine-readable error codes for structured grid diagnostics.
///
/// Each code identifies a class of configuration problem or recovered
/// runtime failure detected by grid internals. Codes are delivered on
/// `OsGridController.onDiagnostic` inside a [GridDiagnostic], alongside
/// the existing human-readable `debugPrint` output, so hosts can branch
/// on failure classes instead of parsing warning text.
enum GridErrorCode {
  /// Two or more leaf columns resolve to the same effective column ID
  /// (explicit `colId`, falling back to `field`).
  duplicateColId,

  /// A resolved column defines neither `field` nor `valueGetter`.
  missingFieldOrGetter,

  /// A user-supplied comparator threw; a safe default comparison was used.
  invalidComparator,

  /// A colDef references a type name that is not present in
  /// `columnTypes`.
  unknownColumnType,

  /// `treeData: true` was set without `getDataPath`; rows render flat.
  treeDataWithoutPath,

  /// `columnDefs` is empty — the grid renders with no columns.
  emptyColumnDefs,

  /// A column is marked `editable: true` without a `cellEditor`; the
  /// default text editor will be used.
  editableWithoutEditor,

  /// A column has a filter while `floatingFilter` is disabled on the grid.
  filterWithoutFloatingFilter,

  /// `rowSelection` is configured without `getRowId`; selection may not
  /// survive sort/filter operations.
  selectionWithoutRowId,

  /// `undoRedoCellEditing` is enabled but no column is editable.
  undoRedoWithoutEditable,

  /// `pagination.pageSize` is not a positive integer.
  invalidPaginationPageSize,

  /// Row drag is enabled without managed mode and without an
  /// `onRowDragEnd` handler.
  rowDragWithoutHandler,

  /// `cellSelection` is combined with multi-row `rowSelection`, which may
  /// cause UX conflicts between range and row selection.
  conflictingSelectionModes,

  /// `singleClickEdit` and `suppressClickEdit` are both true;
  /// `suppressClickEdit` takes precedence.
  contradictoryClickEdit,

  /// `enterNavigatesVertically` and
  /// `enterNavigatesVerticallyAfterEdit` are both true; the latter takes
  /// precedence during editing.
  redundantEnterNavigation,

  /// `treeData` is combined with row grouping (`groupBy` / `rowGroup`
  /// columns); treeData takes precedence and grouping is ignored.
  treeDataWithRowGroups,

  /// A valueGetter threw while computing an aggregation, pivot
  /// extraction, status-bar panel value or group key; field lookup (or a
  /// null group/aggregate value) was used as fallback.
  valueGetterThrew,

  /// A custom `aggFunc` threw; the aggregate value will be null.
  aggFuncThrew,

  /// Fallback for diagnostics emitted through legacy string-keyed sites
  /// that do not (yet) map to a specific code.
  unspecified,
}

/// A single structured diagnostic emitted by the grid.
///
/// Diagnostics are produced in debug builds by the central diagnostics
/// helper (which owns the `debugPrint` path) and re-emitted on
/// `OsGridController.onDiagnostic`. The [key] identifies the diagnostic
/// site and matches the once-per-key deduplication applied to console
/// output.
class GridDiagnostic {
  /// Creates a diagnostic. All fields are required.
  const GridDiagnostic({
    required this.code,
    required this.message,
    required this.key,
  });

  /// Machine-readable classification of the problem.
  final GridErrorCode code;

  /// Human-readable description, identical to the text printed via
  /// `debugPrint` (without the `[OS Grid] ` prefix).
  final String message;

  /// Identifier of the diagnostic site, used for once-per-key
  /// de-duplication (e.g. `'validation:duplicateColIds'`,
  /// `'sort:comparator'`, `'columnType:sparkline'`).
  final String key;

  @override
  String toString() => '[OS Grid] $message ($code)';
}
