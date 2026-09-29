import 'package:flutter/foundation.dart';

import '../columns/os_column_def.dart';
import '../columns/os_column_group.dart';
import '../pagination/os_pagination.dart';
import '../selection/cell_range.dart';
import '../selection/os_row_selection.dart';
import '../utils/grid_diagnostics.dart';
import '../utils/grid_error.dart';

/// Validates grid configuration and emits warnings via [GridDiagnostics].
///
/// This utility class checks for common configuration mistakes at
/// initialisation time. It only runs in debug mode and never throws
/// or breaks the grid — it simply logs warnings with an `[OS Grid]`
/// prefix (and reports them as structured [GridDiagnostic]s on any
/// registered controller's `onDiagnostic` stream) to help developers
/// catch issues early.
///
/// Each diagnostic site has its own key, so every distinct problem is
/// reported at most once per process lifetime — repeated validation runs
/// with an unchanged, invalid configuration do not re-warn.
///
/// Validation is skipped entirely in release builds (guarded by
/// [kDebugMode]) and can be suppressed per-grid via
/// `suppressGridOptionsValidation`.
class OsGridValidator {
  OsGridValidator._();

  /// Validates the grid configuration and logs warnings for common mistakes.
  ///
  /// This method is a no-op in release mode. It checks for contradictory,
  /// redundant, or incomplete configuration and emits helpful warnings.
  ///
  /// Pass [rowData] to enable data-shape checks (e.g. steering away from
  /// raw `Map` rows without a [getRowId] callback).
  static void validate<TData>({
    required List<OsColumnDefBase> columnDefs,
    List<TData>? rowData,
    required OsRowSelection? rowSelection,
    required OsCellSelection? cellSelection,
    required OsPagination? pagination,
    required bool undoRedoCellEditing,
    required bool singleClickEdit,
    required bool suppressClickEdit,
    required bool enterNavigatesVertically,
    required bool enterNavigatesVerticallyAfterEdit,
    required bool floatingFilter,
    required bool rowDrag,
    required bool rowDragManaged,
    required Function? getRowId,
    Function? onRowDragEnd,
    bool treeData = false,
    Function? getDataPath,
    List<String>? groupBy,
  }) {
    // Only run in debug mode — zero overhead in release builds.
    if (!kDebugMode) return;

    final flatColumns = _flattenColumns(columnDefs);

    _checkEmptyColumnDefs(columnDefs);
    _checkDuplicateColIds(flatColumns);
    _checkEditableWithoutEditor(flatColumns);
    _checkFilterWithoutFloatingFilter(flatColumns, floatingFilter);
    _checkSelectionWithoutRowId(rowSelection, getRowId);
    _checkMapRowsWithoutGetRowId(rowData, getRowId);
    _checkUndoRedoWithoutEditable(undoRedoCellEditing, flatColumns);
    _checkPaginationPageSize(pagination);
    _checkRowDragWithoutHandler(rowDrag, rowDragManaged, onRowDragEnd);
    _checkCellSelectionWithMultipleRowSelection(cellSelection, rowSelection);
    _checkContradictoryClickEdit(singleClickEdit, suppressClickEdit);
    _checkRedundantEnterNavigation(
      enterNavigatesVertically,
      enterNavigatesVerticallyAfterEdit,
    );
    _checkTreeData(treeData, getDataPath, groupBy, flatColumns);
  }

  /// Flattens column definitions (including groups) into a list of leaf columns.
  static List<OsColumnDef> _flattenColumns(List<OsColumnDefBase> defs) {
    final result = <OsColumnDef>[];
    for (final def in defs) {
      if (def is OsColumnDef) {
        result.add(def);
      } else if (def is OsColumnGroup) {
        result.addAll(_flattenColumns(def.children));
      }
    }
    return result;
  }

  static void _checkEmptyColumnDefs(List<OsColumnDefBase> columnDefs) {
    if (columnDefs.isEmpty) {
      GridDiagnostics.warn(
        GridErrorCode.emptyColumnDefs,
        'validation:emptyColumnDefs',
        'columnDefs is empty. The grid will render with no columns.',
      );
    }
  }

  /// Warns when two or more leaf columns resolve to the same effective
  /// column ID (explicit `colId`, falling back to `field`).
  ///
  /// Duplicates commonly arise when `colId` is omitted and the same
  /// `field` appears in different column groups. Column-addressed
  /// operations (sorting, selection, state persistence) key off
  /// [OsColumnDef.effectiveColId], so duplicates make those operations
  /// ambiguous.
  static void _checkDuplicateColIds(List<OsColumnDef> columns) {
    final seen = <String>{};
    final duplicates = <String>{};
    for (final col in columns) {
      final id = col.effectiveColId;
      if (!seen.add(id)) duplicates.add(id);
    }
    if (duplicates.isEmpty) return;

    final sortedIds = duplicates.toList()..sort();
    GridDiagnostics.warn(
      GridErrorCode.duplicateColId,
      'validation:duplicateColIds',
      'Duplicate column IDs detected: $sortedIds. Columns must have unique '
          'colId/field values — sorting, selection and column state may behave '
          'unexpectedly.',
    );
  }

  static void _checkEditableWithoutEditor(List<OsColumnDef> columns) {
    for (final col in columns) {
      if (col.editable == true && col.cellEditor == null) {
        final id = col.effectiveColId;
        GridDiagnostics.warn(
          GridErrorCode.editableWithoutEditor,
          'validation:editableWithoutEditor:$id',
          'Column "$id" has editable: true but no cellEditor specified. '
              'The default text editor will be used.',
        );
      }
    }
  }

  static void _checkFilterWithoutFloatingFilter(
    List<OsColumnDef> columns,
    bool floatingFilter,
  ) {
    if (floatingFilter) return;
    for (final col in columns) {
      if (col.filter != null) {
        final id = col.effectiveColId;
        GridDiagnostics.warn(
          GridErrorCode.filterWithoutFloatingFilter,
          'validation:filterWithoutFloatingFilter',
          'Column "$id" has a filter set but floatingFilter is not enabled '
              'on the grid. The floating filter row will not be shown.',
        );
        // Only warn once — no need to repeat for every column.
        return;
      }
    }
  }

  static void _checkSelectionWithoutRowId(
    OsRowSelection? rowSelection,
    Function? getRowId,
  ) {
    if (rowSelection != null && getRowId == null) {
      GridDiagnostics.warn(
        GridErrorCode.selectionWithoutRowId,
        'validation:selectionWithoutRowId',
        'rowSelection is set but getRowId is not provided. '
            'Selection may not survive sort/filter operations.',
      );
    }
  }

  /// Warns when raw `Map` row data is supplied without a [getRowId]
  /// callback, steering users toward the recommended patterns:
  ///
  /// 1. Typed `OsGrid<TData>` with valueGetters (best).
  /// 2. Map rows WITH `getRowId` for stable identity (fine for prototyping).
  ///
  /// The warning never fires when [getRowId] is provided (regardless of
  /// data type) and is emitted at most once per process via
  /// [GridDiagnostics.warnOnce].
  static void _checkMapRowsWithoutGetRowId<TData>(
    List<TData>? rowData,
    Function? getRowId,
  ) {
    if (getRowId != null || rowData == null || rowData.isEmpty) return;
    if (rowData.first is! Map) return;
    GridDiagnostics.warnOnce(
      'validation:mapRowsWithoutGetRowId',
      'Consider providing getRowId — Map row data without stable row identity '
          'means selection, transactions and delta sort may behave unexpectedly '
          'across sort/filter. Recommended: typed OsGrid<TData> with valueGetters, '
          'or keep Map rows and pass getRowId.',
    );
  }

  static void _checkUndoRedoWithoutEditable(
    bool undoRedoCellEditing,
    List<OsColumnDef> columns,
  ) {
    if (!undoRedoCellEditing) return;
    final hasEditable = columns.any((col) => col.editable == true);
    if (!hasEditable) {
      GridDiagnostics.warn(
        GridErrorCode.undoRedoWithoutEditable,
        'validation:undoRedoWithoutEditable',
        'undoRedoCellEditing is enabled but no columns have editable: true. '
            'Undo/redo will have no effect.',
      );
    }
  }

  static void _checkPaginationPageSize(OsPagination? pagination) {
    if (pagination == null) return;
    if (pagination.pageSize <= 0) {
      GridDiagnostics.warn(
        GridErrorCode.invalidPaginationPageSize,
        'validation:paginationPageSize',
        'pagination.pageSize is ${pagination.pageSize}. '
            'Page size must be a positive integer.',
      );
    }
  }

  static void _checkRowDragWithoutHandler(
    bool rowDrag,
    bool rowDragManaged,
    Function? onRowDragEnd,
  ) {
    if (!rowDrag) return;
    if (!rowDragManaged && onRowDragEnd == null) {
      GridDiagnostics.warn(
        GridErrorCode.rowDragWithoutHandler,
        'validation:rowDragWithoutHandler',
        'rowDrag is enabled with rowDragManaged: false but no onRowDragEnd '
            'callback is provided. Dropped rows will have no effect.',
      );
    }
  }

  static void _checkCellSelectionWithMultipleRowSelection(
    OsCellSelection? cellSelection,
    OsRowSelection? rowSelection,
  ) {
    if (cellSelection == null || rowSelection == null) return;
    if (rowSelection.mode == OsRowSelectionMode.multiple) {
      GridDiagnostics.warn(
        GridErrorCode.conflictingSelectionModes,
        'validation:conflictingSelectionModes',
        'cellSelection is set alongside rowSelection with multiple mode. '
            'This may cause UX conflicts between range and row selection.',
      );
    }
  }

  static void _checkContradictoryClickEdit(
    bool singleClickEdit,
    bool suppressClickEdit,
  ) {
    if (singleClickEdit && suppressClickEdit) {
      GridDiagnostics.warn(
        GridErrorCode.contradictoryClickEdit,
        'validation:contradictoryClickEdit',
        'singleClickEdit and suppressClickEdit are both true. '
            'suppressClickEdit takes precedence — click editing is disabled.',
      );
    }
  }

  static void _checkRedundantEnterNavigation(
    bool enterNavigatesVertically,
    bool enterNavigatesVerticallyAfterEdit,
  ) {
    if (enterNavigatesVertically && enterNavigatesVerticallyAfterEdit) {
      GridDiagnostics.warn(
        GridErrorCode.redundantEnterNavigation,
        'validation:redundantEnterNavigation',
        'enterNavigatesVertically and enterNavigatesVerticallyAfterEdit are '
            'both true. enterNavigatesVerticallyAfterEdit takes precedence '
            'during editing.',
      );
    }
  }

  static void _checkTreeData(
    bool treeData,
    Function? getDataPath,
    List<String>? groupBy,
    List<OsColumnDef> columns,
  ) {
    if (!treeData) return;
    if (getDataPath == null) {
      GridDiagnostics.warn(
        GridErrorCode.treeDataWithoutPath,
        'validation:treeDataWithoutPath',
        'treeData is enabled but getDataPath is not provided. '
            'Rows cannot be placed in the hierarchy without it — '
            'the grid will render a flat list.',
      );
    }
    final hasRowGroups =
        (groupBy != null && groupBy.isNotEmpty) ||
        columns.any((col) => col.rowGroup == true);
    if (hasRowGroups) {
      GridDiagnostics.warn(
        GridErrorCode.treeDataWithRowGroups,
        'validation:treeDataWithRowGroups',
        'treeData is combined with row grouping (groupBy or rowGroup '
            'columns). treeData takes precedence and row grouping is ignored.',
      );
    }
  }
}
