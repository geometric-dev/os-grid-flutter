import 'dart:async';

import 'package:flutter/widgets.dart';

import 'tooltip_params.dart';

/// Manages tooltip show/hide state with configurable delays.
///
/// Implements a three-state machine:
/// - [OsTooltipState.nothing] — idle, no tooltip pending or shown
/// - [OsTooltipState.waitingToShow] — hover detected, waiting for show delay
/// - [OsTooltipState.showing] — tooltip is visible
///
/// Mirrors OS Grid's `BaseTooltipStateManager` timing logic.
class TooltipService {
  TooltipService({
    required this.showDelay,
    required this.hideDelay,
    required this.mouseTrack,
  });

  /// Delay in milliseconds before showing the tooltip after hover starts.
  final int showDelay;

  /// Delay in milliseconds before auto-hiding the tooltip.
  final int hideDelay;

  /// Whether the tooltip follows the cursor position.
  final bool mouseTrack;

  /// Current state of the tooltip state machine.
  OsTooltipState get state => _state;
  OsTooltipState _state = OsTooltipState.nothing;

  /// The current tooltip value to display (null if no tooltip).
  String? get tooltipValue => _tooltipValue;
  String? _tooltipValue;

  /// The current tooltip location type.
  TooltipLocation? get tooltipLocation => _tooltipLocation;
  TooltipLocation? _tooltipLocation;

  /// The position where the tooltip should be anchored (in grid-local coords).
  Offset? get anchorPosition => _anchorPosition;
  Offset? _anchorPosition;

  /// The last known mouse position (for mouse-tracking mode).
  Offset? get mousePosition => _mousePosition;
  Offset? _mousePosition;

  Timer? _showTimer;
  Timer? _hideTimer;

  /// Notifier that fires when tooltip state changes (show/hide).
  final ValueNotifier<int> stateChangeNotifier = ValueNotifier<int>(0);

  /// Called when the pointer hovers over a cell/header with tooltip content.
  ///
  /// Starts the show delay timer. If a tooltip is already showing for a
  /// different target, hides it first.
  void onHoverStart({
    required String? value,
    required TooltipLocation location,
    required Offset anchor,
    required Offset mousePos,
  }) {
    if (value == null || value.isEmpty) {
      // No tooltip content — cancel any pending show and hide current
      if (_state != OsTooltipState.nothing) {
        hide();
      }
      return;
    }

    // If already showing the same tooltip at the same location, just update mouse
    if (_state == OsTooltipState.showing &&
        _tooltipValue == value &&
        _tooltipLocation == location) {
      if (mouseTrack) {
        _mousePosition = mousePos;
        _notifyChange();
      }
      return;
    }

    // If showing a different tooltip, hide immediately and start new show timer
    if (_state == OsTooltipState.showing) {
      _cancelTimers();
      _state = OsTooltipState.nothing;
      _tooltipValue = null;
      _notifyChange();
    }

    // Cancel any existing show timer
    _cancelTimers();

    _tooltipValue = value;
    _tooltipLocation = location;
    _anchorPosition = anchor;
    _mousePosition = mousePos;
    _state = OsTooltipState.waitingToShow;

    final effectiveDelay = Duration(milliseconds: showDelay.clamp(200, 100000));
    _showTimer = Timer(effectiveDelay, _show);
  }

  /// Called when the pointer moves while hovering (for mouse-track mode).
  void onHoverMove(Offset mousePos) {
    _mousePosition = mousePos;
    if (_state == OsTooltipState.showing && mouseTrack) {
      _notifyChange();
    }
  }

  /// Called when the pointer leaves the tooltip target area.
  void onHoverEnd() {
    if (_state == OsTooltipState.waitingToShow) {
      _cancelTimers();
      _state = OsTooltipState.nothing;
      _tooltipValue = null;
      _tooltipLocation = null;
      _notifyChange();
      return;
    }

    if (_state == OsTooltipState.showing) {
      hide();
    }
  }

  /// Immediately hides the tooltip and resets state.
  void hide() {
    _cancelTimers();
    _state = OsTooltipState.nothing;
    _tooltipValue = null;
    _tooltipLocation = null;
    _anchorPosition = null;
    _mousePosition = null;
    _notifyChange();
  }

  /// Disposes timers and notifier.
  void dispose() {
    _cancelTimers();
    stateChangeNotifier.dispose();
  }

  void _show() {
    _showTimer = null;
    _state = OsTooltipState.showing;
    _notifyChange();

    // Start auto-hide timer
    final effectiveHideDelay = Duration(
      milliseconds: hideDelay.clamp(200, 100000),
    );
    _hideTimer = Timer(effectiveHideDelay, hide);
  }

  void _cancelTimers() {
    _showTimer?.cancel();
    _showTimer = null;
    _hideTimer?.cancel();
    _hideTimer = null;
  }

  void _notifyChange() {
    stateChangeNotifier.value++;
  }
}

/// States of the tooltip state machine.
enum OsTooltipState {
  /// No tooltip pending or shown.
  nothing,

  /// Hover detected, waiting for show delay to elapse.
  waitingToShow,

  /// Tooltip is currently visible.
  showing,
}
