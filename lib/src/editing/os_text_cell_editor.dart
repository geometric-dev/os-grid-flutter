import 'os_cell_editor.dart';

/// A text input cell editor.
///
/// ```dart
/// OsColumnDef(
///   field: 'name',
///   editable: true,
///   cellEditor: OsTextCellEditor(maxLength: 100),
/// )
/// ```
class OsTextCellEditor extends OsCellEditor {
  const OsTextCellEditor({this.maxLength, this.placeholder});

  /// Maximum number of characters allowed.
  final int? maxLength;

  /// Placeholder text shown when the editor is empty.
  final String? placeholder;
}
