import 'package:flutter/widgets.dart';

import '../columns/os_column_def.dart';
import 'os_filter.dart';

/// Parameters passed to a custom filter builder.
///
/// Provides context about the column being filtered and callbacks to control
/// the filter lifecycle.
///
/// Mirrors OS Grid's `IFilterParams` interface.
class CustomFilterParams<TData> {
  const CustomFilterParams({
    required this.model,
    required this.colDef,
    required this.column,
    required this.onModelChanged,
    required this.getValue,
  });

  /// The current filter model.
  ///
  /// This is the user-defined model shape. It starts as `null` when no filter
  /// is active, and is whatever value the custom filter sets via
  /// [onModelChanged].
  ///
  /// The grid stores this value and passes it back on subsequent builds.
  final dynamic model;

  /// The column definition for the column being filtered.
  final OsColumnDef colDef;

  /// The column field name (convenience accessor for `colDef.field`).
  final String column;

  /// Callback to notify the grid that the filter model has changed.
  ///
  /// Call this whenever the user modifies the filter within your custom widget.
  /// Pass `null` to clear the filter (deactivate it).
  ///
  /// ```dart
  /// onModelChanged({'minAge': 18, 'maxAge': 65});
  /// ```
  ///
  /// The grid will re-evaluate all rows using [OsCustomFilter.doesFilterPass]
  /// with the new model, and emit an `onFilterChanged` event.
  final ValueChanged<dynamic> onModelChanged;

  /// Gets the cell value for a given row in this column.
  ///
  /// Uses the column's `valueGetter` if defined, otherwise reads the field
  /// from the row data map.
  ///
  /// ```dart
  /// final value = getValue(rowData);
  /// ```
  final dynamic Function(TData row) getValue;
}

/// A custom column filter that renders a user-provided widget.
///
/// Use this when the built-in filters (text, number, date) don't meet your
/// needs. Provide a [builder] that returns any Flutter widget to use as the
/// filter UI, along with [doesFilterPass] and [isFilterActive] callbacks
/// that define the filter logic.
///
/// The builder receives [CustomFilterParams] with the current filter model,
/// column info, and a callback to update the model.
///
/// ## Basic example
///
/// ```dart
/// OsColumnDef(
///   field: 'status',
///   headerName: 'Status',
///   filter: OsCustomFilter(
///     builder: (context, params) {
///       return StatusFilterWidget(
///         currentStatus: params.model as String?,
///         onStatusSelected: (status) {
///           params.onModelChanged(status);
///         },
///       );
///     },
///     doesFilterPass: (cellValue, model) {
///       if (model == null) return true;
///       return cellValue == model;
///     },
///     isFilterActive: (model) => model != null,
///   ),
/// )
/// ```
///
/// ## Multi-value filter example
///
/// ```dart
/// OsColumnDef(
///   field: 'category',
///   headerName: 'Category',
///   filter: OsCustomFilter(
///     builder: (context, params) {
///       final selected = (params.model as List<String>?) ?? [];
///       return CategoryCheckboxFilter(
///         selected: selected,
///         onChanged: (newSelection) {
///           params.onModelChanged(
///             newSelection.isEmpty ? null : newSelection,
///           );
///         },
///       );
///     },
///     doesFilterPass: (cellValue, model) {
///       if (model == null) return true;
///       final allowed = model as List<String>;
///       return allowed.contains(cellValue);
///     },
///     isFilterActive: (model) => model != null,
///     getModelAsString: (model) {
///       if (model == null) return '';
///       return (model as List<String>).join(', ');
///     },
///   ),
/// )
/// ```
///
/// ## Filter model
///
/// The filter model can be any serialisable value — a string, number, map,
/// list, or any object that can round-trip through JSON. The grid stores it
/// in the filter model map under the column's ID with `filterType: 'custom'`.
///
/// When using `OsGridController.getFilterModel()`, custom filter models appear as:
/// ```json
/// {
///   "status": {
///     "filterType": "custom",
///     "model": "active"
///   }
/// }
/// ```
///
/// ## Floating filter integration
///
/// When [getModelAsString] is provided, the floating filter row shows the
/// returned text as a read-only summary. If not provided, the floating filter
/// shows a generic filter-active indicator.
///
/// ## Lifecycle
///
/// 1. When the filter popup opens, the grid calls [builder] to create the
///    filter widget.
/// 2. The widget can call [CustomFilterParams.onModelChanged] at any time to
///    update the filter model.
/// 3. The grid re-evaluates all rows using [doesFilterPass] with the new model.
/// 4. The grid emits `onFilterChanged` with the updated filter model.
/// 5. When the popup is dismissed, the filter widget is disposed.
/// 6. The filter model persists — reopening the popup rebuilds the widget
///    with the stored model.
class OsCustomFilter extends OsFilter {
  const OsCustomFilter({
    required this.builder,
    required this.doesFilterPass,
    required this.isFilterActive,
    this.getModelAsString,
  });

  /// Builder function that creates the filter widget.
  ///
  /// Called each time the filter popup opens. The returned widget is rendered
  /// inside the filter popup panel, replacing the default filter UI.
  final Widget Function(BuildContext context, CustomFilterParams params)
  builder;

  /// Callback to determine whether a row passes this filter.
  ///
  /// Called for each row during filtering. Receives the cell value for this
  /// column and the current filter model.
  ///
  /// Return `true` if the row should be shown, `false` to hide it.
  ///
  /// The `cellValue` parameter is the value from the row for this column
  /// (resolved via `valueGetter` or field lookup).
  ///
  /// The `model` parameter is the current filter model (as set by
  /// [CustomFilterParams.onModelChanged]).
  final bool Function(dynamic cellValue, dynamic model) doesFilterPass;

  /// Callback to determine whether the filter is currently active.
  ///
  /// Called with the current filter model. Return `true` if the filter should
  /// be applied to the data, `false` if it's inactive (all rows pass).
  ///
  /// Typically: `(model) => model != null`
  final bool Function(dynamic model) isFilterActive;

  /// Optional callback to provide a text summary of the active filter.
  ///
  /// Used by the floating filter row to display a read-only summary of the
  /// current filter state. If not provided, the floating filter shows a
  /// generic "Custom" indicator when the filter is active.
  ///
  /// ```dart
  /// getModelAsString: (model) {
  ///   if (model == null) return '';
  ///   return 'Status: $model';
  /// },
  /// ```
  final String Function(dynamic model)? getModelAsString;
}
