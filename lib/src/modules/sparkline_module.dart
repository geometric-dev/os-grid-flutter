import 'os_module.dart';

/// Module that enables the built-in sparkline cell renderer.
///
/// ```dart
/// OsGrid(
///   modules: [SparklineModule()],
///   columnDefs: [
///     const OsColumnDef(
///       field: 'trend',
///       builtInCellRenderer: OsBuiltInCellRenderer.sparkline,
///     ),
///   ],
///   // ...
/// )
/// ```
///
/// When an explicit module registry is in effect (any module registered)
/// and [SparklineModule] is absent, columns configured with the sparkline
/// renderer fall back to plain value rendering and a debug-mode warning is
/// emitted.
class SparklineModule extends OsModule {
  /// Creates a sparkline feature module.
  const SparklineModule();

  @override
  String get moduleName => 'Sparkline';

  @override
  String get version => '0.1.0';
}
