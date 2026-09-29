/// Identifies a cell by row index and column index for keyboard navigation.
///
/// This is the position shape used by the grid's `navigateToNextCell` and
/// `tabToNextCell` callbacks. It is intentionally separate from
/// `CellPosition` in `render_api/cell_flash.dart`, which identifies cells
/// by `(rowIndex, colId)` for flash targeting.
///
/// ```dart
/// final from = params.previousCell; // a NavCellPosition
/// print('leaving (${from.rowIndex}, ${from.columnIndex})');
/// ```
class NavCellPosition {
  /// Creates a cell position.
  const NavCellPosition({required this.rowIndex, required this.columnIndex});

  /// The row index of the cell.
  final int rowIndex;

  /// The column index of the cell (display order, including any prepended
  /// checkbox/row-number/row-drag columns).
  final int columnIndex;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NavCellPosition &&
          other.rowIndex == rowIndex &&
          other.columnIndex == columnIndex;

  @override
  int get hashCode => Object.hash(rowIndex, columnIndex);

  @override
  String toString() => 'NavCellPosition(row: $rowIndex, col: $columnIndex)';
}

/// Base contract shared by the navigation callback parameter types.
///
/// Provides the cell focus is moving from ([previousCell]), the default
/// target the grid would move to ([nextCell]), which key triggered the
/// navigation ([key]) and whether Shift was held ([shift]).
///
/// ```dart
/// navigateToNextCell: (params) {
///   final target = params.nextCell;
///   return NavCellPosition(
///     rowIndex: target.rowIndex,
///     columnIndex: target.columnIndex,
///   );
/// },
/// ```
abstract class NavigationCallbackParams {
  /// Creates navigation parameters.
  const NavigationCallbackParams({
    required this.previousCell,
    required this.nextCell,
    required this.key,
    required this.shift,
  });

  /// The cell that currently has focus.
  final NavCellPosition previousCell;

  /// The cell the grid would move focus to by default.
  ///
  /// Return this value (or null from the callback) to keep default movement.
  final NavCellPosition nextCell;

  /// Lowercase name of the key that triggered navigation:
  /// `'arrowup'`, `'arrowdown'`, `'arrowleft'`, `'arrowright'`,
  /// `'pagedown'`, `'pageup'`, `'home'`, `'end'`,
  /// `'tab'` or `'shift+tab'`.
  final String key;

  /// Whether the Shift key was held when the navigation key was pressed.
  final bool shift;
}

/// Parameters passed to the grid's `navigateToNextCell` callback.
///
/// Return a [NavCellPosition] to move focus there (clamped to the grid
/// bounds), or return `null` to keep the grid's default movement
/// ([NavigationCallbackParams.nextCell]).
///
/// ```dart
/// navigateToNextCell: (params) =>
///     params.key == 'arrowdown' ? params.nextCell : null,
/// ```
class NavigateToNextCellParams extends NavigationCallbackParams {
  /// Creates navigate-to-next-cell parameters.
  const NavigateToNextCellParams({
    required super.previousCell,
    required super.nextCell,
    required super.key,
    required super.shift,
  });
}

/// Parameters passed to the grid's `tabToNextCell` callback.
///
/// Consulted for Tab / Shift+Tab during non-editing focus navigation and
/// for Tab after committing an edit. Return a [NavCellPosition] to move
/// focus there, or return `null` to keep default behaviour.
///
/// ```dart
/// tabToNextCell: (params) =>
///     params.shift ? params.previousCell : params.nextCell,
/// ```
class TabToNextCellParams extends NavigationCallbackParams {
  /// Creates tab-to-next-cell parameters.
  const TabToNextCellParams({
    required super.previousCell,
    required super.nextCell,
    required super.key,
    required super.shift,
  });
}
