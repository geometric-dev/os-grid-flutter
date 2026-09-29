import 'feature_module.dart';

/// Module that enables cell editing (inline editors, checkbox toggles, the
/// `startEditingCell` API).
///
/// Registering this module attaches the editing coordinator lifecycle to
/// the grid; detaching cancels any active edit session:
///
/// ```dart
/// OsGrid(
///   modules: [EditingModule()],
///   onCellValueChanged: (event) => print('${event.colId} → ${event.newValue}'),
///   // ...
/// )
/// ```
///
/// When an explicit module registry is in effect (any module registered)
/// and [EditingModule] is absent, edit sessions cannot be started: editor
/// interactions and the `startEditingCell` API are ignored with a
/// debug-mode warning. Read-only rendering (including checkbox cells)
/// continues to work.
class EditingModule extends GridFeatureModule {
  /// Creates an editing feature module.
  EditingModule();

  @override
  String get moduleName => 'Editing';

  @override
  String get version => '0.1.0';
}
