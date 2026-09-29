import 'dart:math' as math;

import 'package:os_grid_flutter/os_grid_flutter.dart'
    show OsGrid, OsGridController;

import '../events/os_grid_event.dart';

/// Represents a rectangular range of selected cells.
///
/// The range is defined by start and end row/column indices. The start
/// values may be greater than end values (e.g. when dragging upward or
/// leftward). Use [normalizedStartRow], [normalizedEndRow], etc. to get
/// the min/max values for iteration and painting.
class CellRange {
  /// Creates a cell range.
  const CellRange({
    required this.startRow,
    required this.endRow,
    required this.startColumn,
    required this.endColumn,
  });

  /// The row index where the range selection started (anchor).
  final int startRow;

  /// The row index where the range selection ended (may be < startRow).
  final int endRow;

  /// The column index where the range selection started (anchor).
  final int startColumn;

  /// The column index where the range selection ended (may be < startColumn).
  final int endColumn;

  /// The topmost row index in the range.
  int get normalizedStartRow => math.min(startRow, endRow);

  /// The bottommost row index in the range.
  int get normalizedEndRow => math.max(startRow, endRow);

  /// The leftmost column index in the range.
  int get normalizedStartColumn => math.min(startColumn, endColumn);

  /// The rightmost column index in the range.
  int get normalizedEndColumn => math.max(startColumn, endColumn);

  /// The number of rows in this range.
  int get rowCount => normalizedEndRow - normalizedStartRow + 1;

  /// The number of columns in this range.
  int get columnCount => normalizedEndColumn - normalizedStartColumn + 1;

  /// Whether this range contains only a single cell.
  bool get isSingleCell => rowCount == 1 && columnCount == 1;

  /// Whether the given [rowIndex] and [columnIndex] fall within this range.
  bool containsCell(int rowIndex, int columnIndex) {
    return rowIndex >= normalizedStartRow &&
        rowIndex <= normalizedEndRow &&
        columnIndex >= normalizedStartColumn &&
        columnIndex <= normalizedEndColumn;
  }

  /// Returns a new [CellRange] with the end position updated.
  CellRange copyWithEnd({required int endRow, required int endColumn}) {
    return CellRange(
      startRow: startRow,
      endRow: endRow,
      startColumn: startColumn,
      endColumn: endColumn,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CellRange &&
        other.startRow == startRow &&
        other.endRow == endRow &&
        other.startColumn == startColumn &&
        other.endColumn == endColumn;
  }

  @override
  int get hashCode => Object.hash(startRow, endRow, startColumn, endColumn);

  @override
  String toString() =>
      'CellRange(rows: $normalizedStartRow..$normalizedEndRow, '
      'cols: $normalizedStartColumn..$normalizedEndColumn)';
}

/// Configuration for cell/range selection behaviour.
///
/// Pass this to [OsGrid.cellSelection] to enable range selection.
///
/// ```dart
/// OsGrid(
///   cellSelection: const OsCellSelection(),
///   // ...
/// )
/// ```
class OsCellSelection {
  /// Creates a cell selection configuration.
  ///
  /// When [suppressMultiRanges] is true, only one range can exist at a time
  /// (Ctrl+click will not create additional ranges).
  const OsCellSelection({this.suppressMultiRanges = true});

  /// Whether to suppress multiple simultaneous ranges.
  ///
  /// When true (default for v1), only one range can exist at a time.
  /// When false, Ctrl/Cmd+click creates additional independent ranges.
  final bool suppressMultiRanges;
}

/// Emitted when the cell range selection changes.
///
/// Mirrors OS Grid's `rangeSelectionChanged` event.
class OsRangeSelectionChangedEvent extends OsGridEvent {
  /// Creates a range selection changed event.
  const OsRangeSelectionChangedEvent({
    required this.ranges,
    this.started = false,
    this.finished = true,
  });

  /// The current list of active cell ranges.
  final List<CellRange> ranges;

  /// Whether a drag operation has just started (range is being created).
  final bool started;

  /// Whether the range selection operation has finished (drag ended or click).
  final bool finished;
}

/// Parameters for programmatically adding a cell range.
///
/// Used with [OsGridController.addCellRange].
class CellRangeParams {
  /// Creates cell range parameters.
  const CellRangeParams({
    required this.rowStartIndex,
    required this.rowEndIndex,
    required this.columnStartIndex,
    required this.columnEndIndex,
  });

  /// The start row index of the range.
  final int rowStartIndex;

  /// The end row index of the range.
  final int rowEndIndex;

  /// The start column index of the range.
  final int columnStartIndex;

  /// The end column index of the range.
  final int columnEndIndex;
}
