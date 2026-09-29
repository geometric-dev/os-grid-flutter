/// Configuration for the grid side bar.
///
/// The side bar is a collapsible panel on the side of the grid that hosts
/// tool panels (e.g. Columns, Filters). Each tool panel has a tab button
/// in a vertical button strip.
///
/// ```dart
/// OsGrid(
///   sideBar: OsSideBarDef.defaultPanels(),
///   // ...
/// )
/// ```
library;

import 'os_tool_panel_def.dart';

/// Position of the side bar relative to the grid.
enum OsSideBarPosition {
  /// Side bar appears on the left of the grid.
  left,

  /// Side bar appears on the right of the grid.
  right,
}

/// Configuration for the grid side bar.
///
/// Use the named constructors for common configurations:
/// - [OsSideBarDef.defaultPanels] — both Columns and Filters panels
/// - [OsSideBarDef.columns] — only the Columns panel
/// - [OsSideBarDef.filters] — only the Filters panel
class OsSideBarDef {
  /// Creates a side bar definition with custom tool panels.
  const OsSideBarDef({
    required this.toolPanels,
    this.defaultToolPanel,
    this.hiddenByDefault = false,
    this.position = OsSideBarPosition.right,
    this.hideButtons = false,
  });

  /// Creates a side bar with both the Columns and Filters tool panels.
  ///
  /// The Columns panel is opened by default.
  factory OsSideBarDef.defaultPanels({
    OsSideBarPosition position = OsSideBarPosition.right,
    bool hiddenByDefault = false,
  }) {
    return OsSideBarDef(
      toolPanels: const [OsToolPanelDef.columns(), OsToolPanelDef.filters()],
      defaultToolPanel: 'columns',
      position: position,
      hiddenByDefault: hiddenByDefault,
    );
  }

  /// Creates a side bar with only the Columns tool panel.
  factory OsSideBarDef.columns({
    OsSideBarPosition position = OsSideBarPosition.right,
    bool hiddenByDefault = false,
  }) {
    return OsSideBarDef(
      toolPanels: const [OsToolPanelDef.columns()],
      defaultToolPanel: 'columns',
      position: position,
      hiddenByDefault: hiddenByDefault,
    );
  }

  /// Creates a side bar with only the Filters tool panel.
  factory OsSideBarDef.filters({
    OsSideBarPosition position = OsSideBarPosition.right,
    bool hiddenByDefault = false,
  }) {
    return OsSideBarDef(
      toolPanels: const [OsToolPanelDef.filters()],
      defaultToolPanel: 'filters',
      position: position,
      hiddenByDefault: hiddenByDefault,
    );
  }

  /// The tool panels to show in the side bar.
  final List<OsToolPanelDef> toolPanels;

  /// The ID of the panel to open by default.
  ///
  /// If null, the side bar starts with no panel open (buttons visible but
  /// panel area collapsed).
  final String? defaultToolPanel;

  /// Whether the side bar is hidden by default.
  ///
  /// When true, the side bar is not visible on initial render.
  /// Use the controller's `setSideBarVisible` method to show it.
  final bool hiddenByDefault;

  /// Position of the side bar relative to the grid.
  ///
  /// Defaults to [OsSideBarPosition.right].
  final OsSideBarPosition position;

  /// Whether to hide the tab button strip.
  ///
  /// When true, the side bar still shows the tool panel content
  /// but without the vertical button strip for switching panels.
  final bool hideButtons;
}
