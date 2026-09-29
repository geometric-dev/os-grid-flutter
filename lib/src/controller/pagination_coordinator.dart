/// Owns client-side pagination state and navigation for the grid.
///
/// Extracted from `OsGridController` (controller split phase 2). The
/// controller keeps its full public surface and delegates the
/// `pagination*` API to this coordinator.
///
/// The coordinator is pure state + command logic: it never touches
/// streams or the widget tree. Widget sync happens through the
/// [onPageChangeRequested] / [onPageSizeChangeRequested] hooks and
/// repaints via the `onStateChanged` constructor callback.
class PaginationCoordinator {
  /// Creates a coordinator.
  ///
  /// [onStateChanged] is invoked after programmatic page / page size
  /// changes so the owning controller can call `notifyListeners`.
  PaginationCoordinator({required void Function()? onStateChanged})
    : _onStateChanged = onStateChanged;

  final void Function()? _onStateChanged;

  int _currentPage = 0;
  int _pageSize = 100;
  int _totalPages = 1;
  int _totalRows = 0;

  /// Callback set by _OsGridState to handle programmatic page changes.
  /// When the controller changes the page, it calls this to update widget state.
  void Function(int page)? onPageChangeRequested;

  /// Callback set by _OsGridState to handle programmatic page size changes.
  void Function(int pageSize)? onPageSizeChangeRequested;

  /// Get the current page size.
  int getPageSize() => _pageSize;

  /// Get the current page (0-indexed).
  int getCurrentPage() => _currentPage;

  /// Get the total number of pages.
  int getTotalPages() => _totalPages;

  /// Get the total row count (after filtering).
  int getRowCount() => _totalRows;

  /// Get the total number of rows the paginator is paging over.
  ///
  /// Mirrors AG Grid's `paginationGetTotalRows`. The count reflects the
  /// rows remaining AFTER the active filters are applied — it shrinks
  /// when filters exclude rows and grows back when they are cleared —
  /// but it is NOT reduced by pagination itself.
  int getTotalRows() => getRowCount();

  /// Navigate to the next page.
  ///
  /// Does nothing if already on the last page.
  void goToNextPage() {
    if (_currentPage < _totalPages - 1) {
      goToPage(_currentPage + 1);
    }
  }

  /// Navigate to the previous page.
  ///
  /// Does nothing if already on the first page.
  void goToPreviousPage() {
    if (_currentPage > 0) {
      goToPage(_currentPage - 1);
    }
  }

  /// Navigate to the first page.
  void goToFirstPage() {
    goToPage(0);
  }

  /// Navigate to the last page.
  void goToLastPage() {
    goToPage(_totalPages - 1);
  }

  /// Navigate to a specific page (0-indexed).
  ///
  /// The page is clamped to valid bounds [0, totalPages - 1].
  void goToPage(int page) {
    final clamped = page.clamp(0, _totalPages > 0 ? _totalPages - 1 : 0);
    if (clamped == _currentPage) return;
    _currentPage = clamped;
    onPageChangeRequested?.call(clamped);
    _onStateChanged?.call();
  }

  /// Set the page size programmatically.
  ///
  /// Resets to page 0 after changing the page size.
  void setPageSize(int pageSize) {
    if (pageSize <= 0 || pageSize == _pageSize) return;
    _pageSize = pageSize;
    _currentPage = 0;
    onPageSizeChangeRequested?.call(pageSize);
    _onStateChanged?.call();
  }

  /// Sync pagination state from the widget (used by _OsGridState).
  void updateState({
    required int currentPage,
    required int pageSize,
    required int totalPages,
    required int totalRows,
  }) {
    _currentPage = currentPage;
    _pageSize = pageSize;
    _totalPages = totalPages;
    _totalRows = totalRows;
  }
}
