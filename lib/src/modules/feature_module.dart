import '../os_grid_controller.dart';
import 'os_module.dart';

/// Base for built-in modules whose feature behaviour is owned by a
/// coordinator inside the grid's State.
///
/// The grid installs the coordinator lifecycle hooks via [bindCoordinator]
/// before [attach] runs, so [attach]/[detach] delegate to the coordinator's
/// own wiring (controller callbacks, active-session teardown, etc.).
abstract class GridFeatureModule extends OsModule {
  /// Creates a feature module.
  ///
  /// User code uses the default constructor; the grid supplies the
  /// coordinator wiring before the module lifecycle runs.
  GridFeatureModule();

  void Function()? _attachCoordinator;
  void Function()? _detachCoordinator;

  /// Installs the coordinator lifecycle hooks. Called by the grid only.
  void bindCoordinator({
    required void Function() attach,
    required void Function() detach,
  }) {
    _attachCoordinator = attach;
    _detachCoordinator = detach;
  }

  @override
  void attach(OsGridController<Object?> controller) {
    super.attach(controller);
    _attachCoordinator?.call();
  }

  @override
  void detach() {
    _detachCoordinator?.call();
    super.detach();
  }
}
