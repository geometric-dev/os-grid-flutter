import 'os_cell_editor.dart';

/// A multi-line text editor rendered as a popup below the cell.
///
/// Provides a textarea-style editor for editing longer text content.
/// The editor appears as a popup positioned below the cell being edited,
/// allowing the user to enter multiple lines of text.
///
/// Mirrors OS Grid's `OsLargeTextCellEditor` with `ILargeTextEditorParams`.
///
/// ```dart
/// OsColumnDef(
///   field: 'notes',
///   editable: true,
///   cellEditor: OsLargeTextCellEditor(maxLength: 500, rows: 6, cols: 50),
/// )
/// ```
class OsLargeTextCellEditor extends OsCellEditor {
  const OsLargeTextCellEditor({
    this.maxLength = 200,
    this.rows = 10,
    this.cols = 60,
  });

  /// Maximum number of characters allowed.
  ///
  /// Defaults to 200, matching OS Grid's TypeScript default.
  final int maxLength;

  /// Number of visible text rows (height of the textarea).
  ///
  /// Defaults to 10, matching OS Grid's TypeScript default.
  final int rows;

  /// Number of visible text columns (width hint for the textarea).
  ///
  /// Defaults to 60, matching OS Grid's TypeScript default.
  /// The actual width is calculated as approximately `cols * 8` logical pixels.
  final int cols;
}
