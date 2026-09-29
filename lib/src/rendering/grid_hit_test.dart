import '../columns/os_column_def.dart';

/// Result of a hit test against the grid.
sealed class GridHitTestResult {
  const GridHitTestResult();
}

/// The pointer hit a column header cell.
class HeaderCellHit extends GridHitTestResult {
  const HeaderCellHit({required this.columnIndex, required this.colDef});

  /// Index of the column that was hit.
  final int columnIndex;

  /// The column definition that was hit.
  final OsColumnDef colDef;
}

/// The pointer hit a data cell.
class DataCellHit extends GridHitTestResult {
  const DataCellHit({
    required this.rowIndex,
    required this.columnIndex,
    required this.colDef,
    required this.value,
  });

  /// Row index in the data (after sort/filter).
  final int rowIndex;

  /// Column index.
  final int columnIndex;

  /// The column definition of the hit cell.
  final OsColumnDef colDef;

  /// The cell value at this position.
  final dynamic value;
}

/// The pointer hit the header resize edge (for column resizing).
class HeaderResizeEdgeHit extends GridHitTestResult {
  const HeaderResizeEdgeHit({required this.columnIndex, required this.colDef});

  /// The column whose right edge was hit.
  final int columnIndex;

  /// The column definition.
  final OsColumnDef colDef;
}

/// The pointer hit the filter icon in a column header.
class HeaderFilterIconHit extends GridHitTestResult {
  const HeaderFilterIconHit({required this.columnIndex, required this.colDef});

  /// Index of the column whose filter icon was hit.
  final int columnIndex;

  /// The column definition.
  final OsColumnDef colDef;
}

/// The pointer hit a floating filter cell.
class FloatingFilterCellHit extends GridHitTestResult {
  const FloatingFilterCellHit({
    required this.columnIndex,
    required this.colDef,
  });

  /// Index of the column whose floating filter was hit.
  final int columnIndex;

  /// The column definition.
  final OsColumnDef colDef;
}

/// The pointer hit the column menu icon (⋮) in a column header.
class HeaderMenuIconHit extends GridHitTestResult {
  const HeaderMenuIconHit({required this.columnIndex, required this.colDef});

  /// Index of the column whose menu icon was hit.
  final int columnIndex;

  /// The column definition.
  final OsColumnDef colDef;
}

/// The pointer didn't hit anything meaningful (empty area).
class EmptyHit extends GridHitTestResult {
  const EmptyHit();
}
