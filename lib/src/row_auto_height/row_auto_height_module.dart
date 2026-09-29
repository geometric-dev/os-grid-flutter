import '../modules/os_module.dart';

/// Module that enables variable row heights in the grid.
///
/// When registered, this module enables:
/// - The `getRowHeight` callback on the grid widget for per-row height calculation
/// - The `autoHeight` property on column definitions for content-based height
/// - The `wrapText` property on column definitions for text wrapping
///
/// ```dart
/// OsGrid(
///   modules: [OsRowAutoHeightModule()],
///   getRowHeight: (params) {
///     final data = params.data as Map<String, dynamic>;
///     final text = data['description'] as String? ?? '';
///     return text.length > 50 ? 84.0 : 42.0;
///   },
///   // ...
/// )
/// ```
class OsRowAutoHeightModule extends OsModule {
  const OsRowAutoHeightModule();

  @override
  String get moduleName => 'RowAutoHeight';

  @override
  String get version => '0.1.0';
}
