/// Owns quick-filter text state and cache invalidation hooks.
///
/// Extracted from `OsGridController` (controller split phase 2). The
/// controller keeps its full public surface and delegates the quick
/// filter API to this coordinator.
class QuickFilterCoordinator {
  /// Callback set by _OsGridState to handle quick filter changes.
  void Function(String? text)? onSetQuickFilterRequested;

  /// Callback set by _OsGridState for quick-filter cache clears.
  void Function()? onClearQuickFilterCacheRequested;

  /// Current quick filter text (set via `setQuickFilter` or synced from
  /// the widget prop), or `null` when no quick filter is active.
  String? text;

  /// Set the quick filter text (searches visible columns).
  ///
  /// Pass `null` or an empty string to clear the quick filter.
  void setText(String? value) {
    final normalised = (value == null || value.isEmpty) ? null : value;
    text = normalised;
    onSetQuickFilterRequested?.call(normalised);
  }

  /// Returns `true` if a quick filter is currently active.
  bool get isPresent => text != null && text!.isNotEmpty;

  /// Resets any cached quick filter state, forcing re-evaluation on the
  /// next filter pass. Delegates to [clearCache].
  void reset() {
    clearCache();
  }

  /// Manually invalidate the quick-filter cache.
  ///
  /// When `cacheQuickFilter` is `true` on the grid, this clears the
  /// per-row aggregate/getter text cache so the next quick-filter pass
  /// recomputes every cell text.
  void clearCache() {
    onClearQuickFilterCacheRequested?.call();
  }
}
