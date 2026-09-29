import 'dart:math' as math;

import 'package:flutter/services.dart';

import '../columns/os_column_def.dart';
import '../editing/undo_redo_service.dart';
import '../events/cell_events.dart';
import '../events/clipboard_events.dart';
import '../os_grid_controller.dart';
import '../params/value_getter_params.dart';
import '../params/value_parser_params.dart';
import '../params/value_setter_params.dart';
import '../selection/cell_range.dart';
import 'clipboard_service.dart';

/// Owns clipboard operations (copy / cut / paste) for the grid.
///
/// Extracted from `_OsGridState`. Serialisation priority mirrors AG Grid:
/// cell range selection, then row selection, then the focused cell.
class ClipboardCoordinator<TData> {
  /// Creates a coordinator.
  ///
  /// All grid-owned collaborators are supplied as closures/getters so they
  /// always read live state from the owning `State`.
  ClipboardCoordinator({
    required OsGridController<TData> controller,
    required String Function() delimiter,
    required bool Function() copyHeaders,
    required bool Function() suppressPaste,
    required String Function(ProcessCellForClipboardParams<TData>)? Function()
    processCellForClipboard,
    required String Function(ProcessHeaderForClipboardParams)? Function()
    processHeaderForClipboard,
    required String Function(ProcessCellFromClipboardParams<TData>)? Function()
    processCellFromClipboard,
    required List<TData>? Function() resolveRows,
    required List<OsColumnDef> Function() resolveFlatColumns,
    required ({int row, int col}) Function() focusedCell,
    required bool Function(OsColumnDef col, TData row, int rowIndex)
    isCellEditable,
    required void Function(OsColumnDef col, TData row, dynamic value)
    setCellValue,
    required UndoRedoService? Function() undoService,
    required void Function(VoidCallback) mutate,
    required void Function(OsClipboardCopyEvent)? onCopy,
    required void Function(OsClipboardCutEvent)? onCut,
    required void Function(OsClipboardPasteEvent)? onPaste,
    required void Function(OsCellValueChangedEvent<TData>)? onCellValueChanged,
  }) : _controller = controller,
       _delimiter = delimiter,
       _copyHeaders = copyHeaders,
       _suppressPaste = suppressPaste,
       _processCellForClipboard = processCellForClipboard,
       _processHeaderForClipboard = processHeaderForClipboard,
       _processCellFromClipboard = processCellFromClipboard,
       _resolveRows = resolveRows,
       _resolveFlatColumns = resolveFlatColumns,
       _focusedCell = focusedCell,
       _isCellEditable = isCellEditable,
       _setCellValue = setCellValue,
       _undoService = undoService,
       _mutate = mutate,
       _onCopy = onCopy,
       _onCut = onCut,
       _onPaste = onPaste,
       _onCellValueChanged = onCellValueChanged;

  /// The live controller. Mutable only for runtime controller swaps —
  /// see [rebind].
  OsGridController<TData> _controller;

  /// Re-points the coordinator at [controller] after a runtime controller
  /// swap. The clipboard flow only emits events and queries state on the
  /// controller (its request hooks are wired by the owning state, which
  /// re-binds them itself), so reassigning the reference is sufficient.
  void rebind(OsGridController<TData> controller) {
    _controller = controller;
  }

  final String Function() _delimiter;
  final bool Function() _copyHeaders;
  final bool Function() _suppressPaste;
  final String Function(ProcessCellForClipboardParams<TData>)? Function()
  _processCellForClipboard;
  final String Function(ProcessHeaderForClipboardParams)? Function()
  _processHeaderForClipboard;
  final String Function(ProcessCellFromClipboardParams<TData>)? Function()
  _processCellFromClipboard;
  final List<TData>? Function() _resolveRows;
  final List<OsColumnDef> Function() _resolveFlatColumns;
  final ({int row, int col}) Function() _focusedCell;
  final bool Function(OsColumnDef col, TData row, int rowIndex) _isCellEditable;
  final void Function(OsColumnDef col, TData row, dynamic value) _setCellValue;
  final UndoRedoService? Function() _undoService;
  final void Function(VoidCallback) _mutate;
  final void Function(OsClipboardCopyEvent)? _onCopy;
  final void Function(OsClipboardCutEvent)? _onCut;
  final void Function(OsClipboardPasteEvent)? _onPaste;
  final void Function(OsCellValueChangedEvent<TData>)? _onCellValueChanged;

  /// Performs a clipboard copy operation.
  ///
  /// Priority: cell range selection > row selection > focused cell.
  void performCopy({required String source}) {
    final text = buildText();
    if (text == null || text.isEmpty) return;

    Clipboard.setData(ClipboardData(text: text));

    // Count cells for the event
    final lines = text.split('\n');
    final cellCount = lines.fold<int>(
      0,
      (sum, line) => sum + line.split(_delimiter()).length,
    );

    final event = OsClipboardCopyEvent(
      text: text,
      cellCount: cellCount,
      source: source,
    );
    _onCopy?.call(event);
    _controller.emitClipboardCopy(event);
  }

  /// Performs a clipboard cut operation.
  ///
  /// Same as copy, but also clears editable cells in the selection.
  void performCut({required String source}) {
    final text = buildText();
    if (text == null || text.isEmpty) return;

    Clipboard.setData(ClipboardData(text: text));

    // Clear editable cells in the selection
    final cellCount = clearSelectedCells();

    final event = OsClipboardCutEvent(
      text: text,
      cellCount: cellCount,
      source: source,
    );
    _onCut?.call(event);
    _controller.emitClipboardCut(event);
  }

  /// Performs a clipboard paste operation.
  ///
  /// With a multi-cell clipboard and an active cell range the whole clipboard
  /// grid is pasted into the range (anchored at its top-left, tiled across a
  /// larger range, expanded right/down when the clipboard is larger).
  /// Otherwise the paste starts at the focused cell and writes linearly.
  Future<void> performPaste({required String source}) async {
    if (_suppressPaste()) return;

    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    if (clipboardData?.text == null || clipboardData!.text!.isEmpty) return;

    final parser = ClipboardParser(delimiter: _delimiter());
    final parsedRows = parser.parse(clipboardData.text!);
    if (parsedRows.isEmpty) return;

    final effectiveData = _resolveRows();
    if (effectiveData == null || effectiveData.isEmpty) return;

    final flatColumns = _resolveFlatColumns();
    if (flatColumns.isEmpty) return;

    // Range-aware paste (quality program v3 item 10): only when the
    // clipboard carries more than a single cell AND a cell range is active.
    final ranges = _controller.getCellRanges();
    final range = ranges.isNotEmpty ? ranges.first : null;
    final clipboardCols = parsedRows.fold<int>(
      0,
      (max, row) => math.max(max, row.length),
    );
    final isMultiCellClipboard = parsedRows.length > 1 || clipboardCols > 1;

    int cellCount = 0;
    final undoChanges = <CellValueChange>[];

    if (range != null && isMultiCellClipboard) {
      cellCount = _pasteGridIntoRange(
        parsedRows,
        effectiveData,
        flatColumns,
        range,
        undoChanges,
      );
    } else {
      // Determine the paste start position from focused cell
      final focused = _focusedCell();
      final startRow = focused.row;
      final startCol = focused.col;

      _mutate(() {
        for (int r = 0; r < parsedRows.length; r++) {
          final targetRowIndex = startRow + r;
          if (targetRowIndex >= effectiveData.length) break;

          final row = effectiveData[targetRowIndex];
          final parsedCells = parsedRows[r];

          int colOffset = 0;
          for (int c = 0; c < parsedCells.length; c++) {
            final targetColIndex = startCol + colOffset;
            if (targetColIndex >= flatColumns.length) break;

            final col = flatColumns[targetColIndex];

            // Check if cell is editable
            if (!_isCellEditable(col, row, targetRowIndex)) {
              // Skip non-editable cells — advance column offset
              colOffset++;
              c--; // Retry this paste cell at the next column
              // Safety: don't loop forever if all remaining columns are non-editable
              if (startCol + colOffset >= flatColumns.length) break;
              continue;
            }

            if (_writePastedCell(
              col: col,
              row: row,
              targetRowIndex: targetRowIndex,
              pasteValue: parsedCells[c],
              undoChanges: undoChanges,
            )) {
              cellCount++;
            }

            colOffset++;
          }
        }
      });
    }

    // Push to undo stack if undo/redo is enabled
    if (undoChanges.isNotEmpty && _undoService() != null) {
      final action = UndoRedoAction(undoChanges);
      _undoService()!.pushAction(action);
    }

    final event = OsClipboardPasteEvent(cellCount: cellCount, source: source);
    _onPaste?.call(event);
    _controller.emitClipboardPaste(event);
  }

  /// Pastes a full clipboard grid into a cell range (quality program v3
  /// item 10).
  ///
  /// The grid is anchored at the range's top-left corner. Each target cell
  /// takes the clipboard value at `(row % clipboardRows, col % rowLength)`,
  /// so the pattern tiles across a range larger than the clipboard while a
  /// clipboard larger than the range expands the write area right/down.
  /// Non-editable cells are skipped without shifting the grid alignment.
  ///
  /// Returns the number of cells written; undo records accumulate into
  /// [undoChanges].
  int _pasteGridIntoRange(
    List<List<String>> parsedRows,
    List<TData> effectiveData,
    List<OsColumnDef> flatColumns,
    CellRange range,
    List<CellValueChange> undoChanges,
  ) {
    final startRow = range.normalizedStartRow;
    final startCol = range.normalizedStartColumn;
    final clipboardCols = parsedRows.fold<int>(
      0,
      (max, row) => math.max(max, row.length),
    );
    final targetRows = math.max(parsedRows.length, range.rowCount);
    final targetCols = math.max(clipboardCols, range.columnCount);

    int cellCount = 0;
    _mutate(() {
      for (int r = 0; r < targetRows; r++) {
        final targetRowIndex = startRow + r;
        if (targetRowIndex >= effectiveData.length) break;

        final row = effectiveData[targetRowIndex];
        final sourceRow = parsedRows[r % parsedRows.length];

        for (int c = 0; c < targetCols; c++) {
          final targetColIndex = startCol + c;
          if (targetColIndex >= flatColumns.length) break;

          final col = flatColumns[targetColIndex];

          // Non-editable cells are skipped in place — the pasted grid keeps
          // its 2D alignment (unlike the linear path, which shifts).
          if (!_isCellEditable(col, row, targetRowIndex)) continue;

          if (_writePastedCell(
            col: col,
            row: row,
            targetRowIndex: targetRowIndex,
            pasteValue: sourceRow[c % sourceRow.length],
            undoChanges: undoChanges,
          )) {
            cellCount++;
          }
        }
      }
    });
    return cellCount;
  }

  /// Writes one pasted value into a cell and emits the change event.
  ///
  /// Returns true when the value changed (and was recorded for undo).
  bool _writePastedCell({
    required OsColumnDef col,
    required TData row,
    required int targetRowIndex,
    required String pasteValue,
    required List<CellValueChange> undoChanges,
  }) {
    var pasteValue_ = pasteValue;

    // Apply processCellFromClipboard callback
    final processFromClipboard = _processCellFromClipboard();
    if (processFromClipboard != null) {
      pasteValue_ = processFromClipboard(
        ProcessCellFromClipboardParams<TData>(
          value: pasteValue_,
          rowIndex: targetRowIndex,
          data: row,
          colDef: col,
        ),
      );
    }

    // Get old value
    final oldValue = _resolveColumnValue(col, row, targetRowIndex);

    // Apply value using valueSetter or valueParser + direct assignment
    final newValue = _applyPasteValue(col, row, targetRowIndex, pasteValue_);

    if (newValue == oldValue) return false;

    // Record for undo
    undoChanges.add(
      CellValueChange(
        rowIndex: targetRowIndex,
        rowId: _controller.rowIdFor(row),
        columnId: col.effectiveColId,
        oldValue: oldValue,
        newValue: newValue,
      ),
    );

    // Emit cellValueChanged event
    final changeEvent = OsCellValueChangedEvent<TData>(
      data: row,
      rowIndex: targetRowIndex,
      colDef: OsColumnDef<TData>(field: col.effectiveColId),
      oldValue: oldValue,
      newValue: newValue,
    );
    _onCellValueChanged?.call(changeEvent);
    _controller.emitCellValueChanged(changeEvent);
    return true;
  }

  /// Builds the clipboard text from the current selection.
  ///
  /// Priority: cell range selection > row selection > focused cell.
  String? buildText({bool forceIncludeHeaders = false}) {
    final effectiveData = _resolveRows();
    if (effectiveData == null || effectiveData.isEmpty) return null;

    final flatColumns = _resolveFlatColumns();
    if (flatColumns.isEmpty) return null;

    final includeHeaders = forceIncludeHeaders || _copyHeaders();

    // 1. Cell range selection
    final ranges = _controller.getCellRanges();
    if (ranges.isNotEmpty) {
      return _buildTextFromRanges(
        ranges,
        flatColumns,
        effectiveData,
        includeHeaders: includeHeaders,
      );
    }

    // 2. Row selection
    final selectedRows = _controller.getSelectedRows();
    if (selectedRows.isNotEmpty) {
      return _buildTextFromRows(
        selectedRows,
        flatColumns,
        includeHeaders: includeHeaders,
      );
    }

    // 3. Focused cell
    final focused = _focusedCell();
    if (focused.row >= 0 &&
        focused.row < effectiveData.length &&
        focused.col >= 0 &&
        focused.col < flatColumns.length) {
      final row = effectiveData[focused.row];
      final col = flatColumns[focused.col];
      final serializer = ClipboardSerializer<TData>(
        columns: [col],
        rows: [row],
        rowStartIndex: focused.row,
        delimiter: _delimiter(),
        includeHeaders: includeHeaders,
        processCellForClipboard: _processCellForClipboard(),
        processHeaderForClipboard: _processHeaderForClipboard(),
      );
      return serializer.serialize();
    }

    return null;
  }

  /// Builds clipboard text from cell range selections.
  String _buildTextFromRanges(
    List<CellRange> ranges,
    List<OsColumnDef> flatColumns,
    List<TData> effectiveData, {
    bool? includeHeaders,
  }) {
    // Use the first range (primary range)
    final range = ranges.first;
    final startRow = range.normalizedStartRow;
    final endRow = range.normalizedEndRow;
    final startCol = range.normalizedStartColumn;
    final endCol = range.normalizedEndColumn;

    // Clamp to valid bounds
    final clampedEndRow = endRow.clamp(0, effectiveData.length - 1);
    final clampedEndCol = endCol.clamp(0, flatColumns.length - 1);
    final clampedStartRow = startRow.clamp(0, effectiveData.length - 1);
    final clampedStartCol = startCol.clamp(0, flatColumns.length - 1);

    final rangeColumns = flatColumns.sublist(
      clampedStartCol,
      clampedEndCol + 1,
    );
    final rangeRows = effectiveData.sublist(clampedStartRow, clampedEndRow + 1);

    final serializer = ClipboardSerializer<TData>(
      columns: rangeColumns,
      rows: rangeRows,
      rowStartIndex: clampedStartRow,
      delimiter: _delimiter(),
      includeHeaders: includeHeaders ?? _copyHeaders(),
      processCellForClipboard: _processCellForClipboard(),
      processHeaderForClipboard: _processHeaderForClipboard(),
    );
    return serializer.serialize();
  }

  /// Builds clipboard text from selected rows (all visible columns).
  String _buildTextFromRows(
    List<TData> selectedRows,
    List<OsColumnDef> flatColumns, {
    bool? includeHeaders,
  }) {
    // Find the index of the first selected row in processed data
    final effectiveData = _resolveRows() ?? [];
    int startIndex = 0;
    if (selectedRows.isNotEmpty && effectiveData.isNotEmpty) {
      final idx = effectiveData.indexOf(selectedRows.first);
      if (idx >= 0) startIndex = idx;
    }

    final serializer = ClipboardSerializer<TData>(
      columns: flatColumns,
      rows: selectedRows,
      rowStartIndex: startIndex,
      delimiter: _delimiter(),
      includeHeaders: includeHeaders ?? _copyHeaders(),
      processCellForClipboard: _processCellForClipboard(),
      processHeaderForClipboard: _processHeaderForClipboard(),
    );
    return serializer.serialize();
  }

  /// Clears editable cells in the current selection (for cut).
  ///
  /// Returns the number of cells cleared.
  int clearSelectedCells() {
    final effectiveData = _resolveRows();
    if (effectiveData == null || effectiveData.isEmpty) return 0;

    final flatColumns = _resolveFlatColumns();
    if (flatColumns.isEmpty) return 0;

    int cellCount = 0;
    final undoChanges = <CellValueChange>[];

    // Determine which cells to clear based on selection priority
    final ranges = _controller.getCellRanges();
    if (ranges.isNotEmpty) {
      final range = ranges.first;
      final startRow = range.normalizedStartRow.clamp(
        0,
        effectiveData.length - 1,
      );
      final endRow = range.normalizedEndRow.clamp(0, effectiveData.length - 1);
      final startCol = range.normalizedStartColumn.clamp(
        0,
        flatColumns.length - 1,
      );
      final endCol = range.normalizedEndColumn.clamp(0, flatColumns.length - 1);

      _mutate(() {
        for (int r = startRow; r <= endRow; r++) {
          final row = effectiveData[r];
          for (int c = startCol; c <= endCol; c++) {
            final col = flatColumns[c];
            if (!_isCellEditable(col, row, r)) continue;

            final oldValue = _resolveColumnValue(col, row, r);
            _setCellValue(col, row, null);
            cellCount++;

            undoChanges.add(
              CellValueChange(
                rowIndex: r,
                rowId: _controller.rowIdFor(row),
                columnId: col.effectiveColId,
                oldValue: oldValue,
                newValue: null,
              ),
            );

            final event = OsCellValueChangedEvent<TData>(
              data: row,
              rowIndex: r,
              colDef: OsColumnDef<TData>(field: col.effectiveColId),
              oldValue: oldValue,
              newValue: null,
            );
            _onCellValueChanged?.call(event);
            _controller.emitCellValueChanged(event);
          }
        }
      });
    } else {
      // Clear focused cell only
      final focused = _focusedCell();
      if (focused.row >= 0 &&
          focused.row < effectiveData.length &&
          focused.col >= 0 &&
          focused.col < flatColumns.length) {
        final row = effectiveData[focused.row];
        final col = flatColumns[focused.col];
        if (_isCellEditable(col, row, focused.row)) {
          final oldValue = _resolveColumnValue(col, row, focused.row);
          _mutate(() {
            _setCellValue(col, row, null);
          });
          cellCount++;

          undoChanges.add(
            CellValueChange(
              rowIndex: focused.row,
              rowId: _controller.rowIdFor(row),
              columnId: col.effectiveColId,
              oldValue: oldValue,
              newValue: null,
            ),
          );

          final event = OsCellValueChangedEvent<TData>(
            data: row,
            rowIndex: focused.row,
            colDef: OsColumnDef<TData>(field: col.effectiveColId),
            oldValue: oldValue,
            newValue: null,
          );
          _onCellValueChanged?.call(event);
          _controller.emitCellValueChanged(event);
        }
      }
    }

    // Push to undo stack
    if (undoChanges.isNotEmpty && _undoService() != null) {
      final action = UndoRedoAction(undoChanges);
      _undoService()!.pushAction(action);
    }

    return cellCount;
  }

  /// Resolves the raw value for a column from a row data object.
  static dynamic resolveColumnValue(
    OsColumnDef col,
    Object? row,
    int rowIndex,
  ) {
    final getter = col.getValueGetterAsFunction();
    if (getter != null) {
      return Function.apply(getter, [
        ValueGetterParams<Object?>(data: row, rowIndex: rowIndex),
      ]);
    }
    if (col.field != null && row is Map<String, dynamic>) {
      return row[col.field];
    }
    return null;
  }

  /// Applies a pasted string value to a cell, using valueSetter/valueParser.
  ///
  /// Returns the actual value that was set.
  dynamic _applyPasteValue(
    OsColumnDef col,
    TData row,
    int rowIndex,
    String pasteValue,
  ) {
    // Apply valueParser if available
    dynamic parsedValue = pasteValue;
    if ((col as dynamic).valueParser != null) {
      parsedValue = ((col as dynamic).valueParser as Function)(
        ValueParserParams<TData>(
          data: row,
          colDef: col,
          newValue: pasteValue,
          oldValue: _resolveColumnValue(col, row, rowIndex),
          rowIndex: rowIndex,
          source: 'paste',
        ),
      );
    } else {
      // Try to preserve original type
      final originalValue = _resolveColumnValue(col, row, rowIndex);
      if (originalValue is int) {
        parsedValue = int.tryParse(pasteValue) ?? pasteValue;
      } else if (originalValue is double) {
        parsedValue = double.tryParse(pasteValue) ?? pasteValue;
      } else if (originalValue is num) {
        parsedValue = num.tryParse(pasteValue) ?? pasteValue;
      }
    }

    // Try valueSetter first
    if ((col as dynamic).valueSetter != null) {
      ((col as dynamic).valueSetter as Function)(
        ValueSetterParams<TData>(
          data: row,
          colDef: col,
          newValue: parsedValue,
          oldValue: _resolveColumnValue(col, row, rowIndex),
          rowIndex: rowIndex,
          source: 'paste',
        ),
      );
      return _resolveColumnValue(col, row, rowIndex);
    }

    // Direct field assignment
    _setCellValue(col, row, parsedValue);
    return parsedValue;
  }

  dynamic _resolveColumnValue(OsColumnDef col, TData row, int rowIndex) =>
      resolveColumnValue(col, row, rowIndex);
}
