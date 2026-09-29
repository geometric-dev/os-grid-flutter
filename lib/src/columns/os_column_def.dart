import 'package:flutter/widgets.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart'
    show OsCheckboxCellEditor, OsColumnGroup, OsGridController, OsGridTheme;

import '../cell_span/cell_span_params.dart';
import '../editing/os_cell_editor.dart';
import '../filtering/os_filter.dart';
import '../params/cell_renderer_params.dart';
import '../params/get_quick_filter_text_params.dart';
import '../params/header_value_getter_params.dart';
import '../params/value_formatter_params.dart';
import '../params/value_getter_params.dart';
import '../params/value_parser_params.dart';
import '../params/value_setter_params.dart';
import '../rendering/avatar_options.dart';
import '../rendering/image_options.dart';
import '../rendering/progress_bar_options.dart';
import '../rendering/sparkline_options.dart';
import '../sorting/sort_direction.dart';
import '../theming/os_cell_style.dart';
import '../tooltip/tooltip_params.dart';
import 'os_column_factory.dart';
import 'os_column_pin.dart';

/// Base class for column definitions and column groups.
///
/// Use [OsColumnDef] for leaf columns and [OsColumnGroup] for groups.
abstract class OsColumnDefBase {
  const OsColumnDefBase();
}

/// Defines a single column in the grid.
///
/// ```dart
/// OsColumnDef(
///   field: 'name',
///   headerName: 'Full Name',
///   sortable: true,
///   filter: OsTextFilter(),
/// )
/// ```
class OsColumnDef<TData> extends OsColumnDefBase {
  const OsColumnDef({
    this.field,
    this.colId,
    this.headerName,
    this.headerValueGetter,
    // Sizing
    this.width,
    this.minWidth,
    this.maxWidth,
    this.flex,
    // Display
    this.valueGetter,
    this.valueFormatter,
    this.cellRenderer,
    this.cellRendererBuilder,
    // Built-in renderer
    this.builtInCellRenderer,
    this.sparklineOptions,
    this.progressBarOptions,
    this.avatarOptions,
    this.imageOptions,
    // Behaviour
    this.sortable = false,
    this.resizable = true,
    this.filter,
    this.editable,
    this.editableCallback,
    this.cellEditor,
    this.valueSetter,
    this.valueParser,
    this.singleClickEdit,
    this.suppressMovable,
    this.type,
    // Spanning
    this.colSpan,
    this.rowSpan,
    this.spanRows,
    // Pinning
    this.pinned,
    // Visibility
    this.hide,
    // Locking
    this.lockVisible,
    this.lockPinned,
    this.lockPosition,
    // Menu suppression
    this.suppressMenu,
    // Selection checkboxes
    this.checkboxSelection,
    this.headerCheckboxSelection,
    // Styling
    this.cellStyle,
    this.cellClass,
    this.theme,
    // Sorting
    this.comparator,
    this.sortingOrder,
    this.sort,
    this.initialSort,
    this.sortIndex,
    // Quick filter
    this.getQuickFilterText,
    // Auto height
    this.autoHeight = false,
    this.wrapText = false,
    // Row Grouping
    this.rowGroup,
    // Aggregation
    this.aggFunc,
    // Pivot
    this.pivot,
    // Tooltip
    this.tooltipField,
    this.tooltipValueGetter,
    this.headerTooltip,
  });
  // NOTE: intentionally no field/valueGetter assert — partial definitions
  // (`defaultColDef`, `columnTypes` entries) legitimately omit both.
  // Grid-level validation warns when a RESOLVED column has neither.

  // --- Identity ---

  /// Field name used to look up values from Map-based row data.
  ///
  /// If row data is `Map<String, dynamic>`, this key is used to extract
  /// the cell value. Not needed if [valueGetter] is provided.
  final String? field;

  /// Unique column identifier. Auto-generated from [field] if not provided.
  final String? colId;

  /// Display name shown in the column header.
  /// Defaults to [field] with first letter capitalised if not provided.
  final String? headerName;

  /// Callback to compute the header display name dynamically.
  ///
  /// When set, takes precedence over the static [headerName] and is used
  /// everywhere headers render (column header painting, column menu titles,
  /// CSV export headers, side bar panels):
  /// ```dart
  /// headerValueGetter: (params) => '${params.colDef.field} (custom)',
  /// ```
  final String Function(HeaderValueGetterParams<TData> params)?
  headerValueGetter;

  // --- Sizing ---

  /// Initial width in logical pixels.
  final double? width;

  /// Minimum width the column can be resized to.
  final double? minWidth;

  /// Maximum width the column can be resized to.
  final double? maxWidth;

  /// Flex factor for distributing remaining space. Works like [Flexible.flex].
  final int? flex;

  // --- Display ---

  /// Custom value getter for typed row data.
  ///
  /// Use this instead of [field] when working with typed data classes:
  /// ```dart
  /// valueGetter: (params) => params.data.fullName,
  /// ```
  final dynamic Function(ValueGetterParams<TData> params)? valueGetter;

  /// Formats the cell value for display.
  ///
  /// Receives the raw value and returns a display string:
  /// ```dart
  /// valueFormatter: (params) => '\$${params.value.toStringAsFixed(2)}',
  /// ```
  final String Function(ValueFormatterParams params)? valueFormatter;

  /// Custom cell renderer that returns a widget.
  ///
  /// Unlike the canvas-based renderers ([builtInCellRenderer] and the paint
  /// callbacks), widgets returned here are embedded as REAL Flutter widgets
  /// in an overlay above the canvas — one widget subtree per visible cell of
  /// this column, repositioned on scroll. Interactive widgets (buttons,
  /// dropdowns) work, at the cost of the canvas rendering performance
  /// guarantee: keep widget cell columns narrow and datasets moderate.
  ///
  /// For simple cases where you don't need BuildContext:
  /// ```dart
  /// cellRenderer: (params) => Text(params.value.toString()),
  /// ```
  final Widget Function(CellRendererParams<TData> params)? cellRenderer;

  /// Custom cell renderer with access to BuildContext.
  ///
  /// Rendered as a real widget in the hybrid overlay (see [cellRenderer] for
  /// the performance trade-off). Use when you need theme data, providers, or
  /// other context:
  /// ```dart
  /// cellRendererBuilder: (context, params) => Icon(
  ///   Icons.star,
  ///   color: Theme.of(context).primaryColor,
  /// ),
  /// ```
  final Widget Function(BuildContext context, CellRendererParams<TData> params)?
  cellRendererBuilder;

  /// Built-in cell renderer type. Use [OsBuiltInCellRenderer.animateShowChange]
  /// for the animated value change renderer (shows delta arrows + value pill).
  final OsBuiltInCellRenderer? builtInCellRenderer;

  /// Configuration for the built-in sparkline renderer.
  ///
  /// Only used when [builtInCellRenderer] is
  /// [OsBuiltInCellRenderer.sparkline]; ignored otherwise. When null, the
  /// sparkline paints with defaults (thin accent line, 2 px padding).
  final OsSparklineOptions? sparklineOptions;

  /// Configuration for the built-in progress bar renderer.
  ///
  /// Only used when [builtInCellRenderer] is
  /// [OsBuiltInCellRenderer.progressBar]; ignored otherwise.
  final OsProgressBarOptions? progressBarOptions;

  /// Configuration for the built-in avatar renderer.
  ///
  /// Only used when [builtInCellRenderer] is
  /// [OsBuiltInCellRenderer.avatar]; ignored otherwise.
  final OsAvatarOptions<TData>? avatarOptions;

  /// Configuration for the built-in image renderer.
  ///
  /// Only used when [builtInCellRenderer] is
  /// [OsBuiltInCellRenderer.image]; ignored otherwise. When the loader is
  /// null, only cell values that are already a `ui.Image` are painted.
  final OsImageOptions<TData>? imageOptions;

  // --- Behaviour ---

  /// Whether this column can be sorted by clicking the header.
  final bool sortable;

  /// Whether this column can be resized by dragging the header edge.
  final bool resizable;

  /// Filter configuration for this column.
  final OsFilter? filter;

  /// Whether cells in this column are editable (static).
  ///
  /// For conditional editing, use [editableCallback] instead.
  final bool? editable;

  /// Callback to determine if a specific cell is editable.
  ///
  /// Takes precedence over [editable] when provided:
  /// ```dart
  /// editableCallback: (params) => params.data.status != 'locked',
  /// ```
  final bool Function(CellRendererParams<TData> params)? editableCallback;

  /// Cell editor to use when editing cells in this column.
  final OsCellEditor? cellEditor;

  /// Custom function to write the edited value back to the row data.
  ///
  /// Return `true` if the data was changed, `false` otherwise.
  /// When `false` is returned, `onCellValueChanged` will not fire.
  ///
  /// When not provided, the grid writes directly to `row[field]` (Map data only).
  ///
  /// ```dart
  /// valueSetter: (params) {
  ///   (params.data as MyModel).price = params.newValue as double;
  ///   return true;
  /// },
  /// ```
  final bool Function(ValueSetterParams<TData> params)? valueSetter;

  /// Custom function to parse the raw string from the editor into the correct type.
  ///
  /// Called before [valueSetter] (or the default write). Receives the raw string
  /// from the editor and should return the parsed value.
  ///
  /// When not provided, the grid uses a simple type-inference heuristic
  /// (preserving int/double from the original value).
  ///
  /// ```dart
  /// valueParser: (params) => double.tryParse(params.newValue) ?? 0.0,
  /// ```
  final dynamic Function(ValueParserParams<TData> params)? valueParser;

  /// Whether single-click starts editing for this column.
  ///
  /// Overrides the grid-level `singleClickEdit` option for this column.
  /// When `true`, a single click on a cell in this column starts editing.
  /// When `null`, the grid-level setting is used.
  final bool? singleClickEdit;

  /// Whether this column cannot be moved via dragging.
  ///
  /// When `true`, the column header cannot be dragged to reorder.
  /// Defaults to `null` (movable). Both `null` and `false` mean movable.
  final bool? suppressMovable;

  /// Column type name(s) referencing `OsGrid.columnTypes`.
  ///
  /// Accepts a single type name or a list. Types are merged in listed order
  /// with precedence: explicit colDef fields > types > `defaultColDef`.
  /// Unknown names produce a one-time debug warning.
  final Object? type;

  // --- Spanning ---

  /// Callback that returns the number of columns this cell should span.
  ///
  /// Return 1 for normal (no span). Values greater than 1 cause the cell
  /// to extend across subsequent columns. Requires `enableCellSpan` on the grid.
  ///
  /// ```dart
  /// colSpan: (params) => params.rowIndex == 0 ? 3 : 1,
  /// ```
  final int Function(ColSpanParams<TData> params)? colSpan;

  /// Callback that returns the number of rows this cell should span.
  ///
  /// Return 1 for normal (no span). Values greater than 1 cause the cell
  /// to extend downward across subsequent rows. Requires `enableCellSpan` on the grid.
  ///
  /// ```dart
  /// rowSpan: (params) => params.data['category'] == 'header' ? 3 : 1,
  /// ```
  final int Function(RowSpanParams<TData> params)? rowSpan;

  /// Auto-merge consecutive rows with equal values in this column.
  ///
  /// When set to `true`, cells with the same value in consecutive rows are
  /// merged into a single spanning cell. Provide a callback for custom
  /// comparison logic. Requires `enableCellSpan` on the grid.
  ///
  /// ```dart
  /// // Simple: merge cells with equal values
  /// spanRows: true,
  ///
  /// // Custom: merge if category matches
  /// spanRows: (params) => params.valueA == params.valueB,
  /// ```
  final Object? spanRows;

  // --- Pinning ---

  /// Pin this column to the left or right side of the grid.
  final OsColumnPin? pinned;

  // --- Visibility ---

  /// Whether this column is initially hidden.
  ///
  /// When `true`, the column is not displayed but remains in the column
  /// definitions. It can be shown programmatically via
  /// [OsGridController.setColumnsVisible].
  ///
  /// Defaults to null (visible). Both `null` and `false` mean visible.
  final bool? hide;

  // --- Locking ---

  /// Whether this column's visibility is locked.
  ///
  /// When `true`, the column cannot be hidden via [OsGridController.setColumnsVisible]
  /// or the column menu. The "Hide Column" menu item is suppressed.
  ///
  /// Defaults to null (not locked). Both `null` and `false` mean unlocked.
  final bool? lockVisible;

  /// Whether this column's pin state is locked.
  ///
  /// When `true`, the column cannot be pinned or unpinned via
  /// [OsGridController.setColumnsPinned] or the column menu. The pin
  /// sub-menu items are suppressed.
  ///
  /// Defaults to null (not locked). Both `null` and `false` mean unlocked.
  final bool? lockPinned;

  /// Whether this column's position is locked.
  ///
  /// When `true`, the column cannot be moved via drag-and-drop or
  /// programmatic APIs ([OsGridController.moveColumnByIndex],
  /// [OsGridController.moveColumns]). Other columns also cannot be
  /// moved past a locked-position column.
  ///
  /// This is stronger than [suppressMovable] — `suppressMovable` only
  /// prevents the column itself from being dragged, while `lockPosition`
  /// also prevents other columns from displacing it.
  ///
  /// Defaults to null (not locked). Both `null` and `false` mean unlocked.
  final bool? lockPosition;

  // --- Menu suppression ---

  /// When `true`, suppresses the context menu for this column.
  ///
  /// Right-clicking on cells in this column will not show a context menu.
  /// Defaults to `null` (not suppressed).
  final bool? suppressMenu;

  // --- Selection checkboxes ---

  /// Whether this column's cells paint a row-selection checkbox.
  ///
  /// Mirrors AG Grid's `colDef.checkboxSelection`. When any data column sets
  /// this to `true`, the grid does NOT prepend its synthetic selection
  /// checkbox column; instead each flagged column paints a selection
  /// checkbox in place of its cell value. Clicking the cell still toggles
  /// the row's selection (subject to the grid-level `rowSelection` config).
  ///
  /// When `null` (default), the column inherits grid-level behaviour
  /// (`rowSelection.checkboxes`).
  ///
  /// ```dart
  /// OsColumnDef(
  ///   field: 'name',
  ///   headerName: 'Name',
  ///   checkboxSelection: true,
  /// )
  /// ```
  final bool? checkboxSelection;

  /// Whether this column's header paints the tri-state select-all checkbox.
  ///
  /// Mirrors AG Grid's `colDef.headerCheckboxSelection`. The header renders
  /// checked/partial/unchecked based on the current selection, and clicking
  /// it toggles select-all / deselect-all exactly like the synthetic
  /// selection column's header.
  ///
  /// When `null` (default), only the synthetic selection column's header
  /// shows the select-all checkbox (when `rowSelection.checkboxes` and
  /// `rowSelection.headerCheckbox` are enabled).
  ///
  /// ```dart
  /// OsColumnDef(
  ///   field: 'name',
  ///   headerName: 'Name',
  ///   checkboxSelection: true,
  ///   headerCheckboxSelection: true,
  /// )
  /// ```
  final bool? headerCheckboxSelection;

  // --- Styling ---

  /// Dynamic cell style based on cell/row data.
  ///
  /// ```dart
  /// cellStyle: (params) => OsCellStyle(
  ///   backgroundColor: params.value > 100 ? Colors.green : null,
  /// ),
  /// ```
  final OsCellStyle Function(CellRendererParams<TData> params)? cellStyle;

  /// Dynamic CSS-like class name for the cell (used for theme-based styling).
  final String Function(CellRendererParams<TData> params)? cellClass;

  /// Per-column theme overrides — the static "column" level of the styling
  /// cascade (see [OsGridTheme] for the full precedence chain).
  ///
  /// On `OsGrid.columnTypes` entries this themes every column of that type:
  /// ```dart
  /// columnTypes: {
  ///   'currency': OsColumnDef<dynamic>(
  ///     theme: OsGridTheme(cellTextColor: Colors.green),
  ///   ),
  /// },
  /// columnDefs: [
  ///   OsColumnDef(field: 'price', type: 'currency'),
  /// ],
  /// ```
  ///
  /// On an explicit column definition it overrides the type theme for that
  /// column only. The resolver merges `theme` like any other field:
  /// explicit colDef > column types (in listed order) > `defaultColDef`.
  ///
  /// Cell painting consumes the cascade through
  /// `ResolvedGridTheme.forColumn`; only the cell-paint tokens participate
  /// ([OsGridTheme.cellTextStyle], [OsGridTheme.cellTextColor],
  /// [OsGridTheme.cellFontSize]).
  final OsGridTheme? theme;

  // --- Sorting ---

  /// Custom comparator for sorting this column.
  ///
  /// ```dart
  /// comparator: (valueA, valueB, nodeA, nodeB, isDescending) =>
  ///     valueA.compareTo(valueB),
  /// ```
  final int Function(
    dynamic valueA,
    dynamic valueB,
    TData? dataA,
    TData? dataB,
    bool isDescending,
  )?
  comparator;

  /// Custom sort cycle for this column.
  ///
  /// Defines the order of sort directions when the user clicks the header.
  /// For example, `[OsSortDirection.ascending, OsSortDirection.descending]`
  /// skips the "clear" state (always sorted). Or
  /// `[OsSortDirection.descending, OsSortDirection.ascending]` starts with
  /// descending.
  ///
  /// When `null`, the default cycle is used: ascending → descending → clear.
  ///
  /// ```dart
  /// sortingOrder: [OsSortDirection.ascending, OsSortDirection.descending],
  /// ```
  final List<OsSortDirection?>? sortingOrder;

  /// The initial sort direction for this column.
  ///
  /// Sets the column's sort direction when the grid first renders.
  /// This is equivalent to [initialSort] — use either one (not both).
  /// Grid-level `initialSort` takes precedence over per-column sort.
  final OsSortDirection? sort;

  /// The initial sort direction for this column (alias for [sort]).
  ///
  /// Sets the column's sort direction when the grid first renders.
  /// Grid-level `initialSort` takes precedence over per-column sort declarations.
  final OsSortDirection? initialSort;

  /// The multi-sort priority index for this column's initial sort.
  ///
  /// When multiple columns have [sort] or [initialSort] set, this determines
  /// the sort priority. Lower values are sorted first (0 = primary sort).
  /// Columns without a sortIndex are appended in definition order.
  final int? sortIndex;

  // --- Quick Filter ---

  /// Custom callback to provide the text used for quick filter matching.
  ///
  /// By default, the cell value's `toString()` is used. Use this to
  /// customise what text is searched for this column:
  /// ```dart
  /// getQuickFilterText: (params) => '${params.value} custom text',
  /// ```
  ///
  /// Return an empty string to exclude this column from quick filter matching.
  final String Function(GetQuickFilterTextParams<TData> params)?
  getQuickFilterText;

  // --- Auto Height ---

  /// Whether the grid should calculate row height based on this column's content.
  ///
  /// When `true`, the grid measures the text content of cells in this column
  /// (using [TextPainter]) and adjusts the row height to fit. If multiple
  /// columns have `autoHeight: true`, the tallest cell determines the row height.
  ///
  /// Typically used with [wrapText] to allow multi-line content:
  /// ```dart
  /// OsColumnDef(
  ///   field: 'description',
  ///   autoHeight: true,
  ///   wrapText: true,
  /// )
  /// ```
  final bool autoHeight;

  /// Whether text should wrap within cells of this column.
  ///
  /// When `true`, cell text wraps to multiple lines instead of being
  /// truncated with an ellipsis. Typically used with [autoHeight] so
  /// the row expands to fit the wrapped content.
  ///
  /// When `false` (default), text is rendered on a single line and
  /// clipped if it exceeds the column width.
  final bool wrapText;

  // --- Row Grouping ---

  /// Whether this column is used for row grouping.
  ///
  /// When `true`, the grid groups rows by the unique values of this column.
  /// Multiple columns can have `rowGroup: true` to create nested groups.
  /// The grouping order follows the column definition order.
  ///
  /// ```dart
  /// OsColumnDef(
  ///   field: 'country',
  ///   headerName: 'Country',
  ///   rowGroup: true,
  /// )
  /// ```
  final bool? rowGroup;

  // --- Aggregation ---

  /// Aggregation function for this column (makes it a "value column").
  ///
  /// When row grouping is active, group rows display the aggregate of all
  /// leaf row values for this column. Accepts either a built-in function
  /// name (String) or a custom function.
  ///
  /// Built-in functions: `'sum'`, `'avg'`, `'count'`, `'min'`, `'max'`,
  /// `'first'`, `'last'`.
  ///
  /// ```dart
  /// // Built-in: sum of sales values
  /// OsColumnDef(field: 'sales', aggFunc: 'sum')
  ///
  /// // Custom: weighted average
  /// OsColumnDef(
  ///   field: 'score',
  ///   aggFunc: (params) {
  ///     final values = params.values.whereType<num>();
  ///     if (values.isEmpty) return null;
  ///     return values.reduce((a, b) => a + b) / values.length;
  ///   },
  /// )
  /// ```
  final Object? aggFunc;

  // --- Pivot ---

  /// Whether this column is used as a pivot column.
  ///
  /// When pivot mode is active, the unique values of pivot columns become
  /// dynamically generated column headers. The intersection of row groups
  /// and pivot values shows aggregated data from value columns.
  ///
  /// ```dart
  /// OsColumnDef(
  ///   field: 'year',
  ///   headerName: 'Year',
  ///   pivot: true,
  /// )
  /// ```
  final bool? pivot;

  // --- Tooltip ---

  /// Field name to extract the tooltip value from row data.
  ///
  /// When set, the tooltip displays the value of this field when the user
  /// hovers over a cell in this column. Supports dot notation for nested
  /// fields (e.g. `'address.city'`).
  ///
  /// If both [tooltipField] and [tooltipValueGetter] are set,
  /// [tooltipField] takes precedence.
  final String? tooltipField;

  /// Callback to compute the tooltip value dynamically.
  ///
  /// Called when the user hovers over a cell in this column. Return `null`
  /// or an empty string to suppress the tooltip for that cell.
  ///
  /// ```dart
  /// tooltipValueGetter: (params) => 'Row ${params.rowIndex}: ${params.value}',
  /// ```
  final String? Function(TooltipValueGetterParams<TData> params)?
  tooltipValueGetter;

  /// Static tooltip text for the column header.
  ///
  /// Displayed when the user hovers over this column's header cell.
  final String? headerTooltip;

  /// The effective column ID (uses [colId] if set, otherwise [field]).
  String get effectiveColId => colId ?? field ?? 'col_$hashCode';

  /// Returns the [valueGetter] as an untyped [Function], or null.
  ///
  /// This avoids Dart's contravariance issue when accessing the typed
  /// `valueGetter` property through a `OsColumnDef<dynamic>` reference
  /// (e.g., when the column is stored in a `List<OsColumnDef>`).
  Function? getValueGetterAsFunction() => valueGetter as Function?;

  /// The effective header name.
  ///
  /// Precedence: [headerValueGetter] → [headerName] → capitalised [field].
  String get effectiveHeaderName {
    final getter = headerValueGetter;
    if (getter != null) {
      return getter(HeaderValueGetterParams<TData>(colDef: this));
    }
    if (headerName != null) return headerName!;
    if (field != null && field!.isNotEmpty) {
      return field![0].toUpperCase() + field!.substring(1);
    }
    return '';
  }

  /// Sentinel used by [copyWith] to distinguish "not provided" from an
  /// explicit `null` for fields where `null` is meaningful.
  static const Object _unset = Object();

  /// Derives typed column definitions from the registered column schema
  /// for `T` (quality-program-v3 item 8 runtime path).
  ///
  /// Convenience forwarder to [OsColumnDefs.fromType]; see that class for
  /// the annotation-driven derivation rules. Throws a descriptive
  /// [StateError] when `T` has no registered schema.
  ///
  /// ```dart
  /// final columns = OsColumnDef.fromType<Person>();
  /// ```
  static List<OsColumnDef<T>> fromType<T extends Object>({
    Map<String, OsColumnDef<T>> overrides = const {},
  }) {
    return OsColumnDefs.fromType<T>(overrides: overrides);
  }

  /// Returns a copy of this column definition with the given fields replaced.
  ///
  /// Fields that are nullable follow standard copy semantics: passing `null`
  /// keeps the current value. The exception is [pinned], where `null` is
  /// meaningful ("unpinned"); omit the argument to keep the current pin
  /// state, or pass an explicit `OsColumnPin?` value (including `null`) to
  /// set it.
  OsColumnDef<TData> copyWith({
    String? field,
    String? colId,
    String? headerName,
    String Function(HeaderValueGetterParams<TData> params)? headerValueGetter,
    double? width,
    double? minWidth,
    double? maxWidth,
    int? flex,
    dynamic Function(ValueGetterParams<TData> params)? valueGetter,
    String Function(ValueFormatterParams params)? valueFormatter,
    Widget Function(CellRendererParams<TData> params)? cellRenderer,
    Widget Function(BuildContext context, CellRendererParams<TData> params)?
    cellRendererBuilder,
    OsBuiltInCellRenderer? builtInCellRenderer,
    OsSparklineOptions? sparklineOptions,
    OsProgressBarOptions? progressBarOptions,
    OsAvatarOptions<TData>? avatarOptions,
    OsImageOptions<TData>? imageOptions,
    bool? sortable,
    bool? resizable,
    OsFilter? filter,
    bool? editable,
    bool Function(CellRendererParams<TData> params)? editableCallback,
    OsCellEditor? cellEditor,
    bool Function(ValueSetterParams<TData> params)? valueSetter,
    dynamic Function(ValueParserParams<TData> params)? valueParser,
    bool? singleClickEdit,
    bool? suppressMovable,
    Object? type,
    int Function(ColSpanParams<TData> params)? colSpan,
    int Function(RowSpanParams<TData> params)? rowSpan,
    Object? spanRows,
    Object? pinned = _unset,
    bool? hide,
    bool? lockVisible,
    bool? lockPinned,
    bool? lockPosition,
    bool? suppressMenu,
    bool? checkboxSelection,
    bool? headerCheckboxSelection,
    OsCellStyle Function(CellRendererParams<TData> params)? cellStyle,
    String Function(CellRendererParams<TData> params)? cellClass,
    OsGridTheme? theme,
    int Function(
      dynamic valueA,
      dynamic valueB,
      TData? dataA,
      TData? dataB,
      bool isDescending,
    )?
    comparator,
    List<OsSortDirection?>? sortingOrder,
    OsSortDirection? sort,
    OsSortDirection? initialSort,
    int? sortIndex,
    String Function(GetQuickFilterTextParams<TData> params)? getQuickFilterText,
    bool? autoHeight,
    bool? wrapText,
    bool? rowGroup,
    Object? aggFunc,
    bool? pivot,
    String? tooltipField,
    String? Function(TooltipValueGetterParams<TData> params)?
    tooltipValueGetter,
    String? headerTooltip,
  }) {
    return OsColumnDef<TData>(
      field: field ?? this.field,
      colId: colId ?? this.colId,
      headerName: headerName ?? this.headerName,
      headerValueGetter: headerValueGetter ?? this.headerValueGetter,
      width: width ?? this.width,
      minWidth: minWidth ?? this.minWidth,
      maxWidth: maxWidth ?? this.maxWidth,
      flex: flex ?? this.flex,
      valueGetter: valueGetter ?? this.valueGetter,
      valueFormatter: valueFormatter ?? this.valueFormatter,
      cellRenderer: cellRenderer ?? this.cellRenderer,
      cellRendererBuilder: cellRendererBuilder ?? this.cellRendererBuilder,
      builtInCellRenderer: builtInCellRenderer ?? this.builtInCellRenderer,
      sparklineOptions: sparklineOptions ?? this.sparklineOptions,
      progressBarOptions: progressBarOptions ?? this.progressBarOptions,
      avatarOptions: avatarOptions ?? this.avatarOptions,
      imageOptions: imageOptions ?? this.imageOptions,
      sortable: sortable ?? this.sortable,
      resizable: resizable ?? this.resizable,
      filter: filter ?? this.filter,
      editable: editable ?? this.editable,
      editableCallback: editableCallback ?? this.editableCallback,
      cellEditor: cellEditor ?? this.cellEditor,
      valueSetter: valueSetter ?? this.valueSetter,
      valueParser: valueParser ?? this.valueParser,
      singleClickEdit: singleClickEdit ?? this.singleClickEdit,
      suppressMovable: suppressMovable ?? this.suppressMovable,
      type: type ?? this.type,
      colSpan: colSpan ?? this.colSpan,
      rowSpan: rowSpan ?? this.rowSpan,
      spanRows: spanRows ?? this.spanRows,
      pinned: identical(pinned, _unset) ? this.pinned : pinned as OsColumnPin?,
      hide: hide ?? this.hide,
      lockVisible: lockVisible ?? this.lockVisible,
      lockPinned: lockPinned ?? this.lockPinned,
      lockPosition: lockPosition ?? this.lockPosition,
      suppressMenu: suppressMenu ?? this.suppressMenu,
      checkboxSelection: checkboxSelection ?? this.checkboxSelection,
      headerCheckboxSelection:
          headerCheckboxSelection ?? this.headerCheckboxSelection,
      cellStyle: cellStyle ?? this.cellStyle,
      cellClass: cellClass ?? this.cellClass,
      theme: theme ?? this.theme,
      comparator: comparator ?? this.comparator,
      sortingOrder: sortingOrder ?? this.sortingOrder,
      sort: sort ?? this.sort,
      initialSort: initialSort ?? this.initialSort,
      sortIndex: sortIndex ?? this.sortIndex,
      getQuickFilterText: getQuickFilterText ?? this.getQuickFilterText,
      autoHeight: autoHeight ?? this.autoHeight,
      wrapText: wrapText ?? this.wrapText,
      rowGroup: rowGroup ?? this.rowGroup,
      aggFunc: aggFunc ?? this.aggFunc,
      pivot: pivot ?? this.pivot,
      tooltipField: tooltipField ?? this.tooltipField,
      tooltipValueGetter: tooltipValueGetter ?? this.tooltipValueGetter,
      headerTooltip: headerTooltip ?? this.headerTooltip,
    );
  }
}

/// Built-in cell renderer types that trigger special rendering in the grid painter.
enum OsBuiltInCellRenderer {
  /// Animated show-change renderer: displays a delta arrow (↑/↓) with the change
  /// amount, plus the current value in a highlighted pill background.
  /// Requires the row data to include a `'__delta_<field>'` key with the change amount.
  animateShowChange,

  /// Star rating renderer: paints filled (★) and empty (☆) stars based on a
  /// numeric cell value (0–5). Uses the theme's [OsGridTheme.accentColor] for
  /// filled stars and a muted border colour for empty stars.
  starRating,

  /// Checkbox renderer: paints a read-only checkbox based on a boolean cell value.
  ///
  /// - `true` → checked (accent-coloured box with white tick)
  /// - `false` → unchecked (empty bordered box)
  /// - `null` → indeterminate (accent-coloured box with dash)
  ///
  /// This is a display-only renderer. For an interactive checkbox that supports
  /// editing, use [OsCheckboxCellEditor] as the column's `cellEditor` instead.
  ///
  /// ```dart
  /// OsColumnDef(
  ///   field: 'active',
  ///   headerName: 'Active',
  ///   builtInCellRenderer: OsBuiltInCellRenderer.checkbox,
  /// )
  /// ```
  checkbox,

  /// Sparkline renderer: paints a canvas-drawn miniature chart from a
  /// `List<num>` cell value (ints and doubles can be mixed). Supports line,
  /// area and bar styles via [OsSparklineOptions]; colours default to the
  /// theme's [OsGridTheme.accentColor]/[OsGridTheme.cellTextColor].
  ///
  /// Non-numeric entries are ignored; null or empty values paint nothing
  /// (cell borders are kept).
  ///
  /// ```dart
  /// OsColumnDef(
  ///   field: 'trend',
  ///   headerName: 'Trend',
  ///   width: 120,
  ///   builtInCellRenderer: OsBuiltInCellRenderer.sparkline,
  ///   sparklineOptions: const OsSparklineOptions(
  ///     type: OsSparklineType.area,
  ///   ),
  /// )
  /// ```
  sparkline,

  /// Progress bar renderer: paints a canvas-drawn progress bar from a numeric cell
  /// value. Supports custom minimum/maximum, colors, and labels via
  /// [OsProgressBarOptions].
  progressBar,

  /// Avatar renderer: paints a canvas-drawn circular avatar with initials. Supports
  /// custom hashing palettes, gap spacing, and label extraction via
  /// [OsAvatarOptions].
  avatar,

  /// Image renderer: paints a decoded `dart:ui.Image` in the cell.
  ///
  /// The cell value can be a `ui.Image` directly, or any value resolved
  /// through [OsImageOptions.imageForCell] (results are cached in
  /// `ImageCellCache`; a placeholder paints while a load is in flight).
  image,
}
