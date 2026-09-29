import 'package:os_grid_flutter/os_grid_flutter.dart'
    show OsNumberCellEditor, OsSelectCellEditor, OsTextCellEditor;

/// Base class for all cell editor configurations.
///
/// Subclasses define specific editor types:
/// - [OsTextCellEditor] for text input
/// - [OsNumberCellEditor] for numeric input
/// - [OsSelectCellEditor] for dropdown selection
abstract class OsCellEditor {
  const OsCellEditor();
}
