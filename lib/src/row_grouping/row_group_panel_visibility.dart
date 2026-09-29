/// Configures when the Row Grouping Panel ("Drop Zone") is shown above the grid.
enum OsRowGroupPanelVisibility {
  /// The row group panel is never shown.
  never,

  /// The row group panel is always visible, displaying a placeholder when empty.
  always,

  /// The row group panel is only visible when at least one column is grouped.
  whenGrouping,
}
