/// Configuration for client-side pagination.
///
/// ```dart
/// OsGrid(
///   pagination: OsPagination(pageSize: 50),
///   ...
/// )
/// ```
class OsPagination {
  const OsPagination({
    this.pageSize = 100,
    this.showPageSizeSelector = false,
    this.pageSizeOptions = const [25, 50, 100, 250],
    this.paginationAutoPageSize = false,
  });

  /// Number of rows per page.
  ///
  /// When [paginationAutoPageSize] is `true`, this value is overridden
  /// by the automatically calculated page size based on the grid's
  /// viewport height.
  final int pageSize;

  /// Whether to show a dropdown for changing page size.
  final bool showPageSizeSelector;

  /// Available page size options (shown in the selector).
  final List<int> pageSizeOptions;

  /// Whether the grid should automatically calculate the page size
  /// based on the available viewport height.
  ///
  /// When enabled, the page size is calculated as:
  /// `floor((gridBodyHeight - headerHeight - floatingFilterHeight) / rowHeight)`
  ///
  /// The page size is recalculated on grid resize. This overrides the
  /// configured [pageSize] when active.
  final bool paginationAutoPageSize;
}
