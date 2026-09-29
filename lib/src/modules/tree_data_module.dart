import 'os_module.dart';

/// Module that enables tree data (hierarchical rows via `getDataPath`).
///
/// ```dart
/// OsGrid(
///   modules: [TreeDataModule()],
///   treeData: true,
///   getDataPath: (data) => data['path'] as List<String>,
///   // ...
/// )
/// ```
///
/// When an explicit module registry is in effect (any module registered)
/// and [TreeDataModule] is absent, the `treeData` parameter is ignored and
/// rows are rendered flat; a debug-mode warning is emitted.
class TreeDataModule extends OsModule {
  /// Creates a tree-data feature module.
  const TreeDataModule();

  @override
  String get moduleName => 'TreeData';

  @override
  String get version => '0.1.0';
}
