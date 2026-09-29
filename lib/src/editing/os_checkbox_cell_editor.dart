import 'os_cell_editor.dart';

/// A checkbox/toggle cell editor for boolean columns.
///
/// When a column uses this editor, cells display a checkbox that can be
/// toggled by clicking or pressing Space/Enter when the cell is focused.
/// No overlay or popup is shown — the toggle happens in-place.
///
/// Mirrors OS Grid's `OsCheckboxCellEditor` and `agCheckboxCellRenderer`
/// behaviour: the checkbox is rendered directly in the cell and toggling
/// fires `cellEditingStarted`/`cellEditingStopped` events.
///
/// ```dart
/// OsColumnDef(
///   field: 'active',
///   headerName: 'Active',
///   editable: true,
///   cellEditor: OsCheckboxCellEditor(),
/// )
/// ```
///
/// For tri-state behaviour (true → false → null → true):
/// ```dart
/// OsColumnDef(
///   field: 'approved',
///   editable: true,
///   cellEditor: OsCheckboxCellEditor(allowIndeterminate: true),
/// )
/// ```
class OsCheckboxCellEditor extends OsCellEditor {
  const OsCheckboxCellEditor({this.allowIndeterminate = false});

  /// Whether the checkbox supports a third "indeterminate" (null) state.
  ///
  /// When `false` (default), clicking toggles between `true` and `false`.
  /// When `true`, clicking cycles through `true` → `false` → `null` → `true`.
  ///
  /// The indeterminate state is rendered as a dash (—) inside the checkbox,
  /// matching OS Grid's partial/indeterminate checkbox visual.
  final bool allowIndeterminate;

  /// Computes the next value in the toggle cycle.
  ///
  /// - Two-state (default): true → false → true
  /// - Tri-state ([allowIndeterminate] = true): true → false → null → true
  bool? nextValue(dynamic currentValue) {
    if (currentValue == true) {
      return false;
    } else if (currentValue == false) {
      return allowIndeterminate ? null : true;
    } else {
      // null or any non-boolean value → true
      return true;
    }
  }
}
