import '../os_grid_controller.dart';

/// Base class for grid feature modules.
///
/// Modules are the unit of feature composition for the grid: every major
/// feature (clipboard, editing, set filter, tree data, sparklines) is
/// fronted by a module that can be registered per grid instance via the
/// `modules:` widget parameter or globally via `OsGrid.registerModules`.
///
/// **Gating semantics.** When a grid instance sees an empty module
/// registry, every feature is implicitly enabled (backwards-compatible
/// default — existing callers see no change). As soon as at least one
/// module is registered, the registry becomes authoritative: features whose
/// module is absent are disabled and their related parameters are ignored
/// with a debug-mode warning.
///
/// Custom modules may participate in the lifecycle by overriding
/// [attach] and [detach].
abstract class OsModule {
  const OsModule();

  /// Unique name identifying this module.
  String get moduleName;

  /// Version of this module (should match the package version).
  String get version;

  /// Other modules this module depends on.
  List<OsModule> get dependsOn => const [];

  /// Called by the grid once the controller exists, before the first frame
  /// is built and before `onGridReady` fires.
  ///
  /// Built-in feature modules use this hook to wire their coordinator onto
  /// the controller. The default implementation is a no-op.
  void attach(OsGridController<Object?> controller) {}

  /// Called when the grid's State is disposed, before coordinator teardown.
  ///
  /// Implementations should release anything they wired up in [attach].
  /// The default implementation is a no-op.
  void detach() {}
}
