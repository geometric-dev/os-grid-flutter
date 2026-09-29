/// Events related to the side bar and tool panels.
library;

import 'os_grid_event.dart';

/// Emitted when a tool panel's visibility changes (opened or closed).
///
/// ```dart
/// controller.onToolPanelVisibleChanged.listen((event) {
///   print('${event.key} visible=${event.visible}');
/// });
/// ```
class OsToolPanelVisibleChangedEvent extends OsGridEvent {
  /// Creates a tool panel visible changed event.
  const OsToolPanelVisibleChangedEvent({
    required this.key,
    required this.visible,
    this.switchingToolPanel = false,
    this.source = OsSideBarSource.api,
  });

  /// The ID of the tool panel whose visibility changed.
  final String key;

  /// Whether the panel is now visible.
  final bool visible;

  /// Whether this event is part of a panel switch (one closing, another opening).
  final bool switchingToolPanel;

  /// What triggered the change.
  final OsSideBarSource source;
}

/// Emitted when the side bar state is updated (visibility, position, or
/// open panel changes).
///
/// ```dart
/// controller.onSideBarUpdated.listen((_) {
///   print('side bar state changed');
/// });
/// ```
class OsSideBarUpdatedEvent extends OsGridEvent {
  /// Creates a side bar updated event.
  const OsSideBarUpdatedEvent();
}

/// The source of a side bar state change.
///
/// ```dart
/// controller.onToolPanelVisibleChanged.listen((event) {
///   if (event.source == OsSideBarSource.buttonClicked) {
///     print('user opened ${event.key}');
///   }
/// });
/// ```
enum OsSideBarSource {
  /// Changed via the API (controller method call).
  api,

  /// Changed via a user clicking a side bar button.
  buttonClicked,

  /// Set during side bar initialisation.
  initializing,
}
