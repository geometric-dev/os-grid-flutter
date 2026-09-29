import 'package:flutter/foundation.dart';

import '../scrolling/scroll_command.dart';

/// A static service that synchronises horizontal scroll between aligned grids.
///
/// Grids register themselves with a group ID. When one grid scrolls
/// horizontally, the service propagates the scroll offset to all other
/// grids in the same group.
///
/// This service uses a flag-based approach to prevent infinite scroll loops:
/// when a grid receives a programmatic scroll from the service, it sets
/// `_isAlignedScrolling` to true so that its own scroll listener does not
/// re-propagate the change.
class AlignedGridService {
  AlignedGridService._();

  /// Registry of grid entries grouped by group ID.
  ///
  /// Each entry contains the grid's scroll command notifier (to set scroll)
  /// and a unique identity object to distinguish grids.
  static final Map<String, List<_AlignedGridEntry>> _groups = {};

  /// Register a grid with the aligned grid service.
  ///
  /// Returns an [AlignedGridRegistration] that the grid uses to notify
  /// scroll changes and to deregister on dispose.
  static AlignedGridRegistration register({
    required String groupId,
    required ValueNotifier<ScrollCommand?> scrollCommandNotifier,
  }) {
    final entry = _AlignedGridEntry(
      scrollCommandNotifier: scrollCommandNotifier,
    );

    _groups.putIfAbsent(groupId, () => []);
    _groups[groupId]!.add(entry);

    return AlignedGridRegistration._(groupId: groupId, entry: entry);
  }

  /// Deregister a grid from the service.
  ///
  /// Called when the grid is disposed or when the aligned grid configuration
  /// changes.
  static void deregister(AlignedGridRegistration registration) {
    final group = _groups[registration._groupId];
    if (group == null) return;

    group.remove(registration._entry);
    if (group.isEmpty) {
      _groups.remove(registration._groupId);
    }
  }

  /// Propagate a horizontal scroll offset to all other grids in the group.
  ///
  /// The [source] entry is excluded from receiving the scroll command
  /// to prevent feedback loops.
  static void _propagateScroll({
    required String groupId,
    required _AlignedGridEntry source,
    required double offset,
  }) {
    final group = _groups[groupId];
    if (group == null) return;

    for (final entry in group) {
      if (identical(entry, source)) continue;
      entry.scrollCommandNotifier.value = SetHorizontalScrollCommand(
        offset: offset,
      );
    }
  }

  /// Clear all registrations. Primarily for testing.
  @visibleForTesting
  static void reset() {
    _groups.clear();
  }

  /// Returns the number of grids registered in a group. For testing.
  @visibleForTesting
  static int groupSize(String groupId) {
    return _groups[groupId]?.length ?? 0;
  }
}

/// An entry in the aligned grid registry representing a single grid instance.
class _AlignedGridEntry {
  _AlignedGridEntry({required this.scrollCommandNotifier});

  /// The notifier used to send scroll commands to this grid's VirtualisedGrid.
  final ValueNotifier<ScrollCommand?> scrollCommandNotifier;
}

/// A registration handle returned by [AlignedGridService.register].
///
/// Holds the information needed to propagate scroll changes and to
/// deregister the grid on dispose.
class AlignedGridRegistration {
  AlignedGridRegistration._({
    required String groupId,
    required _AlignedGridEntry entry,
  }) : _groupId = groupId,
       _entry = entry;

  final String _groupId;
  final _AlignedGridEntry _entry;

  /// Whether this grid is currently processing an aligned scroll event
  /// (to prevent feedback loops).
  bool isAlignedScrolling = false;

  /// Notify the service that this grid has scrolled horizontally.
  ///
  /// If [isAlignedScrolling] is true, this is a no-op (the scroll was
  /// triggered by the service itself).
  void notifyScrollChanged(double horizontalOffset) {
    if (isAlignedScrolling) return;
    AlignedGridService._propagateScroll(
      groupId: _groupId,
      source: _entry,
      offset: horizontalOffset,
    );
  }
}
