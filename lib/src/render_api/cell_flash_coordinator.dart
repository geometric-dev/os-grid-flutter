import 'package:flutter/scheduler.dart';

import 'cell_flash.dart';

/// Owns the cell flash animation state and its animation ticker.
///
/// Extracted from `_OsGridState`. The coordinator creates flash entries for
/// requested cells, drives the per-frame [Ticker] that advances/retires them,
/// and exposes the current state for the painter.
///
/// The ticker is frame-driven (instead of the previous 16ms periodic timer),
/// so flash animation advances in lock-step with the display's vsync cadence
/// and automatically pauses when no flashes are active or when the widget
/// tree is disabled via TickerMode.
///
/// The animation clock is the [Ticker]'s own elapsed time rather than a
/// wall-clock [Stopwatch]: the two agree in production, but only the ticker's
/// clock advances with the frames a test pumps, which is what makes flash
/// timing deterministic under `WidgetTester.pump`.
class CellFlashCoordinator {
  /// Creates a coordinator.
  ///
  /// [resolveColumnIds] supplies the currently displayed column IDs (used to
  /// flash all columns when no explicit columns are given). [resolveRowCount]
  /// supplies the current row count. [mutate] wraps the owning State's
  /// `setState` so flash ticks repaint the grid. [vsync] sources the
  /// animation ticker (typically the owning State).
  CellFlashCoordinator({
    required List<String> Function() resolveColumnIds,
    required int Function() resolveRowCount,
    required void Function(VoidCallback) mutate,
    required TickerProvider vsync,
  }) : _resolveColumnIds = resolveColumnIds,
       _resolveRowCount = resolveRowCount,
       _mutate = mutate {
    _ticker = vsync.createTicker(_onTick);
  }

  final List<String> Function() _resolveColumnIds;
  final int Function() _resolveRowCount;
  final void Function(VoidCallback) _mutate;
  late final Ticker _ticker;

  /// Active flash states keyed by cell position (read by the painter).
  final Map<CellPosition, CellFlashState> flashes = {};

  /// Animation time published by the last tick, and the reference point for
  /// a flash started between ticks. Kept in the ticker's time base so
  /// `startTime` and `opacityAt` are always read from the same clock.
  Duration _elapsed = Duration.zero;

  /// Current elapsed time for in-flight flash animations (read by painter).
  Duration get elapsed => _elapsed;

  /// Handles a flashCells request from the controller.
  ///
  /// Creates flash state entries for the target cells and starts the
  /// animation ticker if not already running.
  void handle(FlashCellsParams params) {
    // Resolve target cells
    final flatCols = _resolveColumnIds();
    final rowCount = _resolveRowCount();

    // Determine which row indices to flash
    final List<int> rowIndices;
    if (params.rowIndices != null) {
      rowIndices = params.rowIndices!;
    } else {
      // Flash all rows
      rowIndices = List.generate(rowCount, (i) => i);
    }

    // Determine which column IDs to flash
    final List<String> colIds;
    if (params.columns != null) {
      colIds = params.columns!;
    } else {
      colIds = flatCols;
    }

    // A flash started between ticks is anchored to the last published
    // animation time, so restarting an in-flight flash keeps the timeline
    // continuous.
    final now = _elapsed;

    // Create flash states for each cell in the intersection
    for (final rowIndex in rowIndices) {
      if (rowIndex < 0 || rowIndex >= rowCount) continue;
      for (final colId in colIds) {
        final position = CellPosition(rowIndex: rowIndex, colId: colId);
        // Restart flash if already flashing
        flashes[position] = CellFlashState(
          position: position,
          startTime: now,
          flashDuration: Duration(milliseconds: params.flashDuration),
          fadeDuration: Duration(milliseconds: params.fadeDuration),
          flashDelay: Duration(milliseconds: params.flashDelay),
          fadeDelay: Duration(milliseconds: params.fadeDelay),
        );
      }
    }

    // Start the animation ticker if not already running
    _startTicker();
    _mutate(() {});
  }

  /// Per-frame tick advancing the flash animation (~display refresh rate).
  ///
  /// Mirrors the previous periodic-timer body: retires completed flashes,
  /// stops ticking when none remain, and publishes the elapsed time so the
  /// painter recomputes flash opacities.
  void _onTick(Duration timestamp) {
    if (flashes.isEmpty) {
      _stopTicker();
      return;
    }

    _elapsed = timestamp;

    // Remove completed flashes
    flashes.removeWhere((_, flash) => flash.opacityAt(_elapsed) == null);

    if (flashes.isEmpty) {
      _stopTicker();
    }

    _mutate(() {});
  }

  /// Starts the frame ticker if it is not already active.
  void _startTicker() {
    if (!_ticker.isActive) {
      _ticker.start();
    }
  }

  /// Stops the animation ticker and rewinds the animation clock.
  void _stopTicker() {
    if (_ticker.isActive) {
      _ticker.stop();
    }
    if (flashes.isEmpty) {
      // The next run restarts the ticker, whose elapsed time begins at zero
      // again, so the published clock has to be rewound with it.
      _elapsed = Duration.zero;
    }
  }

  /// Cancels the ticker. Call from the owning State's dispose.
  void dispose() {
    _ticker.dispose();
  }
}
