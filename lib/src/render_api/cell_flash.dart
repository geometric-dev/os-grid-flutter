// Cell flash state and parameter types for the Render API.
//
// Provides RefreshCellsParams for triggering cell repaints and
// FlashCellsParams for temporarily highlighting cells with a
// flash-then-fade animation.

/// Parameters for `OsGridController.refreshCells`.
///
/// Controls which cells are refreshed and whether they flash afterwards.
/// In the canvas-based Flutter grid, "refresh" simply triggers a repaint
/// (the painter always reads current values), so this is primarily useful
/// for triggering flash effects on specific cells.
class RefreshCellsParams {
  const RefreshCellsParams({
    this.rowIndices,
    this.columns,
    this.force = false,
    this.suppressFlash = false,
  });

  /// Specific row indices to refresh. When null, all visible rows are
  /// refreshed.
  final List<int>? rowIndices;

  /// Specific column IDs to refresh. When null, all columns are refreshed.
  final List<String>? columns;

  /// Force refresh even if the value hasn't changed.
  ///
  /// In the canvas grid this has no additional effect (the painter always
  /// reads fresh values), but it controls whether flash is triggered on
  /// cells whose value hasn't changed.
  final bool force;

  /// When true, cells are refreshed without flashing.
  final bool suppressFlash;
}

/// Parameters for `OsGridController.flashCells`.
///
/// Controls which cells flash and the timing of the flash animation.
class FlashCellsParams {
  const FlashCellsParams({
    this.rowIndices,
    this.columns,
    this.flashDuration = 500,
    this.fadeDuration = 1000,
    this.flashDelay = 0,
    this.fadeDelay = 0,
  });

  /// Specific row indices to flash. When null, all visible rows flash.
  final List<int>? rowIndices;

  /// Specific column IDs to flash. When null, all columns flash.
  final List<String>? columns;

  /// Duration of the full-opacity flash highlight in milliseconds.
  final int flashDuration;

  /// Duration of the fade-out after the flash in milliseconds.
  final int fadeDuration;

  /// Delay before the flash starts in milliseconds.
  final int flashDelay;

  /// Delay before the fade starts (after flash completes) in milliseconds.
  final int fadeDelay;
}

/// Identifies a single cell by row index and column ID.
class CellPosition {
  const CellPosition({required this.rowIndex, required this.colId});

  final int rowIndex;
  final String colId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CellPosition &&
          other.rowIndex == rowIndex &&
          other.colId == colId;

  @override
  int get hashCode => Object.hash(rowIndex, colId);

  @override
  String toString() => 'CellPosition(row: $rowIndex, col: $colId)';
}

/// The current phase of a cell flash animation.
enum CellFlashPhase {
  /// Waiting for the flash to start (during [FlashCellsParams.flashDelay]).
  delay,

  /// Full-opacity highlight is active.
  flash,

  /// Waiting for the fade to start (during [FlashCellsParams.fadeDelay]).
  fadeDelay,

  /// Fading from full opacity to zero.
  fading,
}

/// Tracks the animation state of a single flashing cell.
class CellFlashState {
  CellFlashState({
    required this.position,
    required this.startTime,
    required this.flashDuration,
    required this.fadeDuration,
    required this.flashDelay,
    required this.fadeDelay,
  });

  /// Which cell is flashing.
  final CellPosition position;

  /// When the flash was initiated, in the animation clock's time base (the
  /// ticker's elapsed time — see `CellFlashCoordinator`).
  final Duration startTime;

  /// How long the full-opacity highlight lasts.
  final Duration flashDuration;

  /// How long the fade-out lasts.
  final Duration fadeDuration;

  /// Delay before the flash starts.
  final Duration flashDelay;

  /// Delay between flash end and fade start.
  final Duration fadeDelay;

  /// Total duration of the entire animation (delay + flash + fadeDelay + fade).
  Duration get totalDuration =>
      flashDelay + flashDuration + fadeDelay + fadeDuration;

  /// Compute the current opacity [0.0–1.0] given the elapsed time since
  /// [startTime].
  ///
  /// Returns null if the animation is complete (should be removed).
  double? opacityAt(Duration currentTime) {
    final elapsed = currentTime - startTime;

    // Phase 1: delay — not yet visible
    if (elapsed < flashDelay) return 0.0;

    // Phase 2: flash — full opacity
    final flashStart = flashDelay;
    final flashEnd = flashStart + flashDuration;
    if (elapsed < flashEnd) return 1.0;

    // Phase 3: fade delay — still full opacity
    final fadeDelayEnd = flashEnd + fadeDelay;
    if (elapsed < fadeDelayEnd) return 1.0;

    // Phase 4: fading
    final fadeEnd = fadeDelayEnd + fadeDuration;
    if (elapsed >= fadeEnd) return null; // animation complete

    // Linear fade from 1.0 to 0.0
    final fadeElapsed = elapsed - fadeDelayEnd;
    final progress = fadeElapsed.inMicroseconds / fadeDuration.inMicroseconds;
    return 1.0 - progress.clamp(0.0, 1.0);
  }
}
