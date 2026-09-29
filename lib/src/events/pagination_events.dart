import 'os_grid_event.dart';

/// Emitted when pagination state changes (page navigation or page size change).
///
/// ```dart
/// controller.onPaginationChanged.listen((event) {
///   print('page ${event.currentPage + 1} of ${event.totalPages}');
/// });
/// ```
class OsPaginationChangedEvent extends OsGridEvent {
  const OsPaginationChangedEvent({
    required this.currentPage,
    required this.totalPages,
    required this.pageSize,
    required this.totalRows,
    this.newPage = false,
    this.newPageSize = false,
  });

  /// The current page index (zero-based).
  final int currentPage;

  /// The total number of pages.
  final int totalPages;

  /// The current page size.
  final int pageSize;

  /// The total number of rows (before pagination).
  final int totalRows;

  /// Whether the user navigated to a new page.
  final bool newPage;

  /// Whether the user changed the page size.
  final bool newPageSize;
}
