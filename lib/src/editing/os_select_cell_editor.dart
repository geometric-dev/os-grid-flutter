import 'os_cell_editor.dart';

/// A dropdown/select cell editor.
///
/// When a cell with this editor is activated, a dropdown list appears
/// showing all available values. The user can select a value by clicking,
/// or navigate with arrow keys and confirm with Enter.
///
/// Mirrors OS Grid's `OsSelectCellEditor` with `ISelectCellEditorParams`.
///
/// ```dart
/// OsColumnDef(
///   field: 'country',
///   editable: true,
///   cellEditor: OsSelectCellEditor(values: ['UK', 'US', 'DE', 'FR']),
/// )
/// ```
class OsSelectCellEditor extends OsCellEditor {
  const OsSelectCellEditor({
    this.values = const [],
    this.valueListGap,
    this.valueListMaxHeight,
    this.valueListMaxWidth,
  });

  /// The list of values available for selection.
  final List<dynamic> values;

  /// The gap in logical pixels between the cell and the dropdown list.
  ///
  /// Defaults to 0 (dropdown appears directly below/above the cell).
  final double? valueListGap;

  /// The maximum height of the dropdown list in logical pixels.
  ///
  /// If the list of items exceeds this height, it becomes scrollable.
  /// Defaults to 200.
  final double? valueListMaxHeight;

  /// The maximum width of the dropdown list in logical pixels.
  ///
  /// Defaults to the width of the cell being edited.
  final double? valueListMaxWidth;
}
