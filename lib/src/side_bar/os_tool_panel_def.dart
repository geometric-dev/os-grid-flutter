/// Definition of a single tool panel within the side bar.
library;

import 'package:flutter/widgets.dart';

/// The type of built-in tool panel.
enum OsToolPanelType {
  /// The Columns tool panel — shows/hides columns, expand/collapse groups.
  columns,

  /// The Filters tool panel — shows filterable columns with filter status.
  filters,

  /// A custom tool panel provided by the user via [OsToolPanelDef.custom].
  custom,
}

/// Defines a single tool panel within the side bar.
///
/// Use the const constructors for built-in panels:
/// - [OsToolPanelDef.columns] — column visibility panel
/// - [OsToolPanelDef.filters] — filter access panel
/// - [OsToolPanelDef.custom] — user-provided panel widget
class OsToolPanelDef {
  /// Creates a tool panel definition.
  const OsToolPanelDef({
    required this.id,
    required this.labelDefault,
    this.labelKey,
    this.iconData,
    this.toolPanelType = OsToolPanelType.custom,
    this.minWidth = 200,
    this.maxWidth,
    this.initialWidth = 250,
    this.toolPanelBuilder,
    this.suppressColumnFilter = false,
    this.suppressColumnSelectAll = false,
    this.suppressColumnExpandAll = false,
    this.suppressFilterSearch = false,
    this.suppressExpandAll = false,
    this.contractColumnSelection = false,
  });

  /// Creates the built-in Columns tool panel definition.
  const OsToolPanelDef.columns({
    this.minWidth = 200,
    this.maxWidth,
    this.initialWidth = 250,
    this.suppressColumnFilter = false,
    this.suppressColumnSelectAll = false,
    this.suppressColumnExpandAll = false,
    this.contractColumnSelection = false,
  }) : id = 'columns',
       labelDefault = 'Columns',
       labelKey = 'columns',
       iconData = null,
       toolPanelType = OsToolPanelType.columns,
       toolPanelBuilder = null,
       suppressFilterSearch = false,
       suppressExpandAll = false;

  /// Creates the built-in Filters tool panel definition.
  const OsToolPanelDef.filters({
    this.minWidth = 200,
    this.maxWidth,
    this.initialWidth = 250,
    this.suppressFilterSearch = false,
    this.suppressExpandAll = false,
  }) : id = 'filters',
       labelDefault = 'Filters',
       labelKey = 'filters',
       iconData = null,
       toolPanelType = OsToolPanelType.filters,
       toolPanelBuilder = null,
       suppressColumnFilter = false,
       suppressColumnSelectAll = false,
       suppressColumnExpandAll = false,
       contractColumnSelection = false;

  /// Creates a custom tool panel definition.
  ///
  /// The [toolPanelBuilder] provides the widget content for the panel.
  const OsToolPanelDef.custom({
    required this.id,
    required this.labelDefault,
    required WidgetBuilder this.toolPanelBuilder,
    this.labelKey,
    this.iconData,
    this.minWidth = 200,
    this.maxWidth,
    this.initialWidth = 250,
  }) : toolPanelType = OsToolPanelType.custom,
       suppressColumnFilter = false,
       suppressColumnSelectAll = false,
       suppressColumnExpandAll = false,
       suppressFilterSearch = false,
       suppressExpandAll = false,
       contractColumnSelection = false;

  /// Unique identifier for this panel.
  final String id;

  /// Default display label for the tab button.
  final String labelDefault;

  /// Localisation key for the label.
  final String? labelKey;

  /// Icon to display on the tab button.
  ///
  /// If null, a default icon is used based on [toolPanelType].
  final IconData? iconData;

  /// The type of built-in panel, or [OsToolPanelType.custom] for user panels.
  final OsToolPanelType toolPanelType;

  /// Minimum width of the tool panel content area.
  final double minWidth;

  /// Maximum width of the tool panel content area, or null for unconstrained.
  final double? maxWidth;

  /// Initial width of the tool panel content area.
  final double initialWidth;

  /// Builder for custom tool panel content.
  ///
  /// Only used when [toolPanelType] is [OsToolPanelType.custom].
  final WidgetBuilder? toolPanelBuilder;

  // --- Columns Tool Panel params ---

  /// Whether to suppress the search filter in the columns panel.
  final bool suppressColumnFilter;

  /// Whether to suppress the Select All / Deselect All buttons.
  final bool suppressColumnSelectAll;

  /// Whether to suppress the Expand All / Collapse All buttons.
  final bool suppressColumnExpandAll;

  /// Whether column groups start collapsed in the columns panel.
  final bool contractColumnSelection;

  // --- Filters Tool Panel params ---

  /// Whether to suppress the search filter in the filters panel.
  final bool suppressFilterSearch;

  /// Whether to suppress the Expand All / Collapse All buttons in the filters panel.
  final bool suppressExpandAll;
}
