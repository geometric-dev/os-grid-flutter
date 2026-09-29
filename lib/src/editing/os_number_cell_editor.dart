import 'os_cell_editor.dart';

/// A numeric input cell editor.
///
/// ```dart
/// OsColumnDef(
///   field: 'age',
///   editable: true,
///   cellEditor: OsNumberCellEditor(min: 0, max: 120, step: 1),
/// )
/// ```
class OsNumberCellEditor extends OsCellEditor {
  const OsNumberCellEditor({this.min, this.max, this.step, this.precision});

  /// Minimum allowed value.
  final num? min;

  /// Maximum allowed value.
  final num? max;

  /// Step increment for up/down controls.
  final num? step;

  /// Number of decimal places to allow.
  final int? precision;
}
