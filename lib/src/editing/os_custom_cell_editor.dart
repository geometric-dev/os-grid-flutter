import 'package:flutter/widgets.dart';

import '../columns/os_column_def.dart';
import 'os_cell_editor.dart';

/// Parameters passed to a custom cell editor builder.
///
/// Provides context about the cell being edited and callbacks to control
/// the editing lifecycle.
///
/// Mirrors OS Grid's `ICellEditorParams` interface.
class CellEditorParams<TData> {
  const CellEditorParams({
    required this.value,
    required this.data,
    required this.rowIndex,
    required this.colDef,
    required this.column,
    required this.onValueChanged,
    required this.stopEditing,
    this.eventKey,
  });

  /// The current value of the cell when editing started.
  final dynamic value;

  /// The row data for the cell being edited.
  final TData data;

  /// The row index of the cell being edited.
  final int rowIndex;

  /// The column definition of the cell being edited.
  final OsColumnDef colDef;

  /// The column field name (convenience accessor for `colDef.field`).
  final String column;

  /// Key that triggered the edit (e.g. 'Enter', 'F2', or a printable character).
  ///
  /// `null` if editing was started by a click or programmatic API call.
  final String? eventKey;

  /// Callback to notify the grid that the editor's value has changed.
  ///
  /// Call this whenever the user modifies the value within your custom editor.
  /// The grid uses this value when committing the edit.
  ///
  /// ```dart
  /// onValueChanged(newValue);
  /// ```
  final ValueChanged<dynamic> onValueChanged;

  /// Callback to programmatically stop editing from within the editor.
  ///
  /// Pass `true` to cancel the edit (revert to original value).
  /// Pass `false` (or omit) to commit the current value.
  ///
  /// ```dart
  /// // Commit the edit
  /// stopEditing(false);
  ///
  /// // Cancel the edit
  /// stopEditing(true);
  /// ```
  final void Function(bool cancel) stopEditing;
}

/// A custom cell editor that renders a user-provided widget.
///
/// Use this when the built-in editors (text, number, select, checkbox) don't
/// meet your needs. Provide a [builder] that returns any Flutter widget to
/// use as the editor.
///
/// The builder receives [CellEditorParams] with the current cell value,
/// row data, and callbacks to control the editing lifecycle.
///
/// ## Basic example
///
/// ```dart
/// OsColumnDef(
///   field: 'colour',
///   headerName: 'Colour',
///   editable: true,
///   cellEditor: OsCustomCellEditor(
///     builder: (context, params) {
///       return ColorPicker(
///         initialColor: params.value as Color?,
///         onColorSelected: (color) {
///           params.onValueChanged(color);
///           params.stopEditing(false);
///         },
///       );
///     },
///   ),
/// )
/// ```
///
/// ## Popup editor example
///
/// By default, the custom editor is rendered inline (constrained to the cell
/// bounds). Set [popup] to `true` to render it as a popup below the cell,
/// which allows the editor to have its own size.
///
/// ```dart
/// OsColumnDef(
///   field: 'rating',
///   editable: true,
///   cellEditor: OsCustomCellEditor(
///     popup: true,
///     popupPosition: PopupPosition.under,
///     builder: (context, params) {
///       return StarRatingEditor(
///         value: params.value as int? ?? 0,
///         onChanged: (rating) {
///           params.onValueChanged(rating);
///           params.stopEditing(false);
///         },
///       );
///     },
///   ),
/// )
/// ```
///
/// ## Lifecycle
///
/// 1. When editing starts, the grid calls [builder] to create the editor widget.
/// 2. The editor can call [CellEditorParams.onValueChanged] at any time to
///    update the pending value.
/// 3. The editor can call [CellEditorParams.stopEditing] to end editing
///    programmatically.
/// 4. If the user presses Escape or clicks outside, the grid cancels the edit.
/// 5. If the user presses Enter (and [suppressEnterCommit] is false), the grid
///    commits the current value.
class OsCustomCellEditor extends OsCellEditor {
  const OsCustomCellEditor({
    required this.builder,
    this.popup = false,
    this.popupPosition = PopupPosition.over,
    this.suppressEnterCommit = false,
    this.suppressEscapeCancel = false,
  });

  /// Builder function that creates the editor widget.
  ///
  /// Called each time editing starts. The returned widget is rendered either
  /// inline (within the cell bounds) or as a popup, depending on [popup].
  final Widget Function(BuildContext context, CellEditorParams params) builder;

  /// Whether the editor should be rendered as a popup rather than inline.
  ///
  /// When `false` (default), the editor is constrained to the cell's bounds.
  /// When `true`, the editor is rendered as a popup positioned relative to
  /// the cell, allowing it to have its own dimensions.
  ///
  /// Mirrors OS Grid's `isPopup()` method on `ICellEditor`.
  final bool popup;

  /// Where to position the popup relative to the cell.
  ///
  /// Only used when [popup] is `true`.
  /// - [PopupPosition.over]: The popup covers the cell (default).
  /// - [PopupPosition.under]: The popup appears below the cell.
  ///
  /// Mirrors OS Grid's `getPopupPosition()` method.
  final PopupPosition popupPosition;

  /// When `true`, pressing Enter does NOT commit the edit.
  ///
  /// Useful for multi-line editors or editors where Enter has a different
  /// meaning (e.g. adding a new item to a list).
  ///
  /// The editor must call [CellEditorParams.stopEditing] explicitly to
  /// end editing.
  final bool suppressEnterCommit;

  /// When `true`, pressing Escape does NOT cancel the edit.
  ///
  /// Useful for editors that use Escape for their own purposes (e.g.
  /// closing a sub-menu within the editor).
  ///
  /// The editor must call [CellEditorParams.stopEditing] explicitly to
  /// end editing.
  final bool suppressEscapeCancel;
}

/// Position of a popup editor relative to the cell.
enum PopupPosition {
  /// The popup covers the cell.
  over,

  /// The popup appears below the cell, leaving the cell value visible.
  under,
}
