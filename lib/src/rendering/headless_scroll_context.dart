import 'package:flutter/rendering.dart' show AxisDirection, SemanticsAction;
import 'package:flutter/widgets.dart';

/// A [ScrollContext] with no backing [Scrollable] widget.
///
/// Used by the quality-program-v2 item 45 spike to drive a real
/// [ScrollPositionWithSingleContext] (and therefore real [ScrollPhysics]
/// ballistic simulations) from `VirtualisedGrid` without restructuring the
/// widget tree around a viewport.
///
/// All widget-facing callbacks are no-ops: there is no render object to
/// ignore pointers on, no drag recognisers to toggle, no semantics actions
/// to publish, and no page-storage bucket to persist into. Notifications
/// dispatch from [context] so ancestor listeners still observe them.
class HeadlessScrollContext implements ScrollContext {
  /// Creates a context bound to [context] (used for notifications and
  /// device-pixel-ratio lookup) and [vsync] (drives ballistic animations).
  HeadlessScrollContext({required this.context, required this.vsync});

  /// The ambient build context of the owning grid state.
  final BuildContext context;

  @override
  final TickerProvider vsync;

  @override
  AxisDirection get axisDirection => AxisDirection.down;

  @override
  double get devicePixelRatio => View.of(context).devicePixelRatio;

  @override
  BuildContext get notificationContext => context;

  @override
  BuildContext get storageContext => context;

  @override
  void setCanDrag(bool value) {}

  @override
  void setIgnorePointer(bool value) {}

  @override
  void setSemanticsActions(Set<SemanticsAction> actions) {}

  @override
  void saveOffset(double offset) {}
}
