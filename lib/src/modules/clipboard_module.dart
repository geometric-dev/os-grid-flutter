import 'feature_module.dart';

/// Module that enables clipboard integration (copy / cut / paste).
///
/// Registering this module keeps the clipboard coordinator alive and wires
/// its copy/cut/paste callbacks onto the grid controller:
///
/// ```dart
/// OsGrid(
///   modules: [ClipboardModule()],
///   onClipboardCopy: (event) => print('copied ${event.cellCount} cells'),
///   // ...
/// )
/// ```
///
/// When an explicit module registry is in effect (any module registered)
/// and [ClipboardModule] is absent, the clipboard coordinator is not created
/// at all and clipboard API calls are ignored with a debug-mode warning.
class ClipboardModule extends GridFeatureModule {
  /// Creates a clipboard feature module.
  ClipboardModule();

  @override
  String get moduleName => 'Clipboard';

  @override
  String get version => '0.1.0';
}
