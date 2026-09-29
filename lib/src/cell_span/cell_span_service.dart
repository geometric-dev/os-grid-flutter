import '../columns/os_column_def.dart';
import '../render_api/cell_flash.dart' show CellPosition;
import 'cell_span_model.dart';
import 'cell_span_params.dart';

/// Service that computes and caches cell span information.
///
/// Mirrors OS Grid's `RowSpanService` + `RowSpanCache`. Computes which cells
/// should be merged vertically (via `spanRows` or `rowSpan`) and provides
/// lookup methods used during painting and hit testing.
///
/// For `colSpan`, no caching is needed — it's evaluated per-cell during paint.
class CellSpanService {
  /// Builds the row span cache for all columns that have `spanRows` or
  /// `rowSpan` configured.
  ///
  /// Call this whenever the displayed data changes (after sort, filter,
  /// pagination, or data update).
  ///
  /// [columns] — the flat list of visible columns.
  /// [rowData] — the currently displayed (sorted/filtered/paginated) rows.
  /// [enableCellSpan] — the grid-level master switch.
  void buildCache({
    required List<OsColumnDef> columns,
    required List<Map<String, dynamic>> rowData,
    required bool enableCellSpan,
  }) {
    _rowSpanGroups.clear();
    _cellToGroup.clear();

    if (!enableCellSpan || rowData.isEmpty) return;

    for (final col in columns) {
      final colId = col.effectiveColId;

      // spanRows: auto-merge consecutive equal values
      if (col.spanRows != null) {
        _buildSpanRowsCache(col, colId, rowData);
      }

      // rowSpan: explicit callback returning span count
      if (col.rowSpan != null) {
        _buildRowSpanCache(col, colId, rowData);
      }
    }
  }

  /// Returns the [RowSpanGroup] for the given cell position, or `null` if
  /// the cell is not part of any vertical span.
  RowSpanGroup? getRowSpanGroup(int rowIndex, String colId) {
    return _cellToGroup[CellPosition(rowIndex: rowIndex, colId: colId)];
  }

  /// Whether the cell at [rowIndex], [colId] is "consumed" by a span above
  /// (i.e., should not be painted — the head cell paints with extended height).
  bool isConsumedByRowSpan(int rowIndex, String colId) {
    final group = _cellToGroup[CellPosition(rowIndex: rowIndex, colId: colId)];
    return group != null && group.isConsumedRow(rowIndex);
  }

  /// Whether the cell at [rowIndex], [colId] is the head of a row span group.
  bool isRowSpanHead(int rowIndex, String colId) {
    final group = _cellToGroup[CellPosition(rowIndex: rowIndex, colId: colId)];
    return group != null && group.isHead(rowIndex);
  }

  /// Returns the number of rows the cell at [rowIndex], [colId] spans.
  /// Returns 1 if no span exists (normal cell).
  int getRowSpanCount(int rowIndex, String colId) {
    final group = _cellToGroup[CellPosition(rowIndex: rowIndex, colId: colId)];
    if (group == null || !group.isHead(rowIndex)) return 1;
    return group.rowCount;
  }

  /// Evaluates the `colSpan` callback for a cell and returns the number of
  /// columns it should span. Returns 1 if no colSpan is configured.
  ///
  /// This is evaluated at paint time (no caching needed for horizontal spans).
  int getColSpan({
    required OsColumnDef column,
    required Map<String, dynamic> rowData,
    required int rowIndex,
  }) {
    if (column.colSpan == null) return 1;
    final result =
        (column.colSpan! as Function)(
              ColSpanParams(
                data: rowData,
                rowIndex: rowIndex,
                column: column.effectiveColId,
              ),
            )
            as int;
    return result < 1 ? 1 : result;
  }

  /// All computed row span groups (for testing/inspection).
  List<RowSpanGroup> get allRowSpanGroups =>
      _rowSpanGroups.values.expand((groups) => groups).toList();

  // --- Private ---

  /// Column ID → list of span groups for that column.
  final Map<String, List<RowSpanGroup>> _rowSpanGroups = {};

  /// Fast lookup: cell position → its span group.
  final Map<CellPosition, RowSpanGroup> _cellToGroup = {};

  /// Builds the cache for `spanRows` (auto-merge equal values).
  void _buildSpanRowsCache(
    OsColumnDef col,
    String colId,
    List<Map<String, dynamic>> rowData,
  ) {
    final groups = <RowSpanGroup>[];
    final field = col.field;
    if (field == null) return;

    int spanStart = 0;
    dynamic lastValue = _getCellValue(col, rowData[0], 0);

    for (int r = 1; r < rowData.length; r++) {
      final value = _getCellValue(col, rowData[r], r);
      final shouldMerge = _shouldSpanRows(
        col,
        lastValue,
        rowData[spanStart],
        value,
        rowData[r],
        colId,
      );

      if (!shouldMerge) {
        // Close the current span if it covers more than one row
        if (r - 1 > spanStart) {
          final group = RowSpanGroup(
            firstRowIndex: spanStart,
            lastRowIndex: r - 1,
            colId: colId,
          );
          groups.add(group);
          _registerGroup(group);
        }
        spanStart = r;
        lastValue = value;
      }
    }

    // Close final span
    if (rowData.length - 1 > spanStart) {
      final group = RowSpanGroup(
        firstRowIndex: spanStart,
        lastRowIndex: rowData.length - 1,
        colId: colId,
      );
      groups.add(group);
      _registerGroup(group);
    }

    if (groups.isNotEmpty) {
      _rowSpanGroups[colId] = groups;
    }
  }

  /// Builds the cache for explicit `rowSpan` callbacks.
  void _buildRowSpanCache(
    OsColumnDef col,
    String colId,
    List<Map<String, dynamic>> rowData,
  ) {
    final groups = <RowSpanGroup>[];
    final consumedRows = <int>{};

    for (int r = 0; r < rowData.length; r++) {
      if (consumedRows.contains(r)) continue;

      final spanCount =
          (col.rowSpan! as Function)(
                RowSpanParams(data: rowData[r], rowIndex: r, column: colId),
              )
              as int;

      if (spanCount > 1) {
        final lastRow = (r + spanCount - 1).clamp(0, rowData.length - 1);
        final group = RowSpanGroup(
          firstRowIndex: r,
          lastRowIndex: lastRow,
          colId: colId,
        );
        groups.add(group);
        _registerGroup(group);

        // Mark consumed rows
        for (int consumed = r + 1; consumed <= lastRow; consumed++) {
          consumedRows.add(consumed);
        }
      }
    }

    if (groups.isNotEmpty) {
      _rowSpanGroups.putIfAbsent(colId, () => []).addAll(groups);
    }
  }

  /// Registers a group in the cell-to-group lookup map.
  void _registerGroup(RowSpanGroup group) {
    for (int r = group.firstRowIndex; r <= group.lastRowIndex; r++) {
      _cellToGroup[CellPosition(rowIndex: r, colId: group.colId)] = group;
    }
  }

  /// Gets the cell value for comparison, using valueGetter if available.
  dynamic _getCellValue(
    OsColumnDef col,
    Map<String, dynamic> row,
    int rowIndex,
  ) {
    if (col.valueGetter != null) {
      // Use the untyped accessor to avoid generic issues
      final getter = col.getValueGetterAsFunction();
      if (getter != null) {
        // We can't easily call the typed valueGetter here without the params type,
        // so fall back to field-based access for spanRows comparison.
      }
    }
    final field = col.field;
    return field != null ? row[field] : null;
  }

  /// Determines whether two consecutive rows should be merged.
  bool _shouldSpanRows(
    OsColumnDef col,
    dynamic valueA,
    dynamic nodeA,
    dynamic valueB,
    dynamic nodeB,
    String colId,
  ) {
    final spanRows = col.spanRows;
    if (spanRows == null) return false;

    if (spanRows is bool) {
      // Simple equality comparison
      return valueA == valueB;
    }

    // Custom comparison function
    final compareFn = spanRows as bool Function(SpanRowsParams);
    return compareFn(
      SpanRowsParams(
        valueA: valueA,
        nodeA: nodeA,
        valueB: valueB,
        nodeB: nodeB,
        column: colId,
      ),
    );
  }
}
