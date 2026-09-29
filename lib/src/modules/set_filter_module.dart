import 'os_module.dart';

/// Module that enables the set filter for columns configured with
/// `OsSetFilter`.
///
/// ```dart
/// OsGrid(
///   modules: [SetFilterModule()],
///   columnDefs: [
///     OsColumnDef(field: 'country', filter: OsSetFilter()),
///   ],
///   // ...
/// )
/// ```
///
/// When an explicit module registry is in effect (any module registered)
/// and [SetFilterModule] is absent, `OsSetFilter` configurations are
/// stripped from the flattened column model and a debug-mode warning is
/// emitted; affected columns are not filterable.
class SetFilterModule extends OsModule {
  /// Creates a set-filter feature module.
  const SetFilterModule();

  @override
  String get moduleName => 'SetFilter';

  @override
  String get version => '0.1.0';
}
