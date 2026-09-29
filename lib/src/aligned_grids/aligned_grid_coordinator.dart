import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';

import '../scrolling/scroll_command.dart';
import 'aligned_grid_service.dart';
import 'os_aligned_grid.dart';

/// Owns this grid's registration with the [AlignedGridService].
///
/// Extracted from `_OsGridState` so aligned-grid behaviour lives beside its
/// service. The coordinator listens to the grid's scroll position notifier
/// and propagates horizontal offsets to the other grids in its group while
/// suppressing feedback loops caused by inbound scroll commands.
class AlignedGridCoordinator {
  /// Creates a coordinator.
  ///
  /// [config] is re-evaluated on every [attach] so configuration updates via
  /// `didUpdateWidget` are picked up without recreating the coordinator.
  AlignedGridCoordinator({
    required OsAlignedGrid? Function() config,
    required ValueNotifier<ScrollCommand?> scrollCommandNotifier,
    required ValueNotifier<Offset> scrollPositionNotifier,
  }) : _config = config,
       _scrollCommandNotifier = scrollCommandNotifier,
       _scrollPositionNotifier = scrollPositionNotifier;

  final OsAlignedGrid? Function() _config;
  final ValueNotifier<ScrollCommand?> _scrollCommandNotifier;
  final ValueNotifier<Offset> _scrollPositionNotifier;

  AlignedGridRegistration? _registration;
  double _lastAlignedScrollX = 0.0;

  /// Registers this grid with the aligned grid service if configured.
  ///
  /// No-op when no `OsAlignedGrid` configuration is present.
  void attach() {
    final alignedGrids = _config();
    if (alignedGrids == null) return;
    _registration = AlignedGridService.register(
      groupId: alignedGrids.groupId,
      scrollCommandNotifier: _scrollCommandNotifier,
    );
    _scrollPositionNotifier.addListener(_onScrollPositionChanged);
    _scrollCommandNotifier.addListener(_onAlignedScrollCommand);
  }

  /// Deregisters this grid from the service and removes listeners.
  void detach() {
    _scrollCommandNotifier.removeListener(_onAlignedScrollCommand);
    _scrollPositionNotifier.removeListener(_onScrollPositionChanged);
    if (_registration != null) {
      AlignedGridService.deregister(_registration!);
      _registration = null;
    }
  }

  /// Alias for [detach] used by the owning State's dispose.
  void dispose() => detach();

  /// Detects when a [SetHorizontalScrollCommand] arrives (from the aligned
  /// grid service) and sets the flag to prevent re-propagation.
  void _onAlignedScrollCommand() {
    final command = _scrollCommandNotifier.value;
    if (command is SetHorizontalScrollCommand) {
      _registration?.isAlignedScrolling = true;
    }
  }

  /// Propagates horizontal scroll to aligned grids unless this change was
  /// caused by an aligned scroll.
  void _onScrollPositionChanged() {
    final registration = _registration;
    if (registration == null) return;

    final currentX = _scrollPositionNotifier.value.dx;
    if (currentX == _lastAlignedScrollX) return;
    _lastAlignedScrollX = currentX;

    registration.notifyScrollChanged(currentX);
    // Reset the flag after propagation attempt (notifyScrollChanged no-ops
    // if isAlignedScrolling is true, so this is safe to always reset).
    registration.isAlignedScrolling = false;
  }
}
