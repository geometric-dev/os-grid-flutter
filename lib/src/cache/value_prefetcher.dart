/// Idle-time value prefetch (quality program v3 item 50).
///
/// After the body paint completes for a frame, the grid may schedule a
/// microtask that pre-computes valueGetter results for the NEXT
/// viewport-height worth of rows in the scroll direction, warming the
/// `ValueCache` so scrolling does not stall on first-time getter evaluation.
/// This file holds the shared callback signature and the pure window maths
/// so both can be tested independently of the widget wiring.
library;

/// Signature of the idle-time value-prefetch hook installed by the grid
/// widget on the paint context.
///
/// Invoked in a microtask after the body paint completes with the frame's
/// scroll offset, the paint viewport height, and the visible row window, so
/// the host can pre-compute valueGetter results for the next viewport-height
/// worth of rows in the scroll direction.
typedef OsValuePrefetchCallback =
    void Function({
      required double scrollY,
      required double viewportHeight,
      required int firstVisibleRow,
      required int lastVisibleRow,
    });

/// Computes the row window to prefetch after a paint pass (quality program
/// v3 item 50).
///
/// Given the visible row window, prefetches one viewport worth of rows
/// beyond it in the scroll direction, clamped to the data bounds. Returns
/// `null` when there is nothing to prefetch (empty data, non-positive
/// window, or the boundary was reached).
({int first, int last})? computeValuePrefetchWindow({
  required int rowCount,
  required int firstVisibleRow,
  required int lastVisibleRow,
  required int viewportRows,
  required bool scrollingDown,
}) {
  if (rowCount <= 0 || viewportRows <= 0) return null;
  final int first;
  final int last;
  if (scrollingDown) {
    first = lastVisibleRow + 1;
    last = lastVisibleRow + viewportRows;
    if (first > rowCount - 1) return null;
  } else {
    last = firstVisibleRow - 1;
    first = firstVisibleRow - viewportRows;
    if (last < 0) return null;
  }
  final clampedFirst = first.clamp(0, rowCount - 1);
  final clampedLast = last.clamp(0, rowCount - 1);
  if (clampedFirst > clampedLast) return null;
  return (first: clampedFirst, last: clampedLast);
}
