import 'package:flutter/material.dart';

import '../../columns/os_column_def.dart';
import '../os_custom_cell_editor.dart';

/// Overlay hosting a user-provided custom cell editor widget.
///
/// Assembles the [CellEditorParams] for the active session and invokes the
/// editor's builder with the owning grid's [BuildContext] (passed as
/// [editorContext]) so theme/media lookups inside user builders resolve
/// exactly as before the extraction.
///
/// The result is positioned either inline within the cell bounds or as a
/// popup below/over the cell, wrapped in a [Focus] wired to the editing
/// coordinator's key handler.
class CustomEditorOverlay<TData> extends StatefulWidget {
  const CustomEditorOverlay({
    super.key,
    required this.cellRect,
    required this.editor,
    required this.editorContext,
    required this.colDef,
    required this.rowData,
    required this.rowIndex,
    required this.originalValue,
    required this.field,
    required this.focusNode,
    required this.onKeyEvent,
    required this.onValueChanged,
    required this.onStopEditing,
  });

  /// Rect of the cell being edited.
  final Rect cellRect;

  /// The custom editor config (builder/popup options).
  final OsCustomCellEditor editor;

  /// The owning grid State's context — passed to the editor builder so its
  /// lookups resolve from the grid's position in the tree.
  final BuildContext editorContext;

  /// Column definition of the cell being edited.
  final OsColumnDef colDef;

  /// Row data of the cell being edited (already resolved by the coordinator).
  final TData rowData;

  /// Row index of the cell being edited.
  final int rowIndex;

  /// The original cell value captured when the editing session opened.
  final dynamic originalValue;

  /// Field name of the column being edited, if any.
  final String? field;

  /// Focus node attached to the overlay's key-event focus wrapper.
  final FocusNode focusNode;

  /// Key handler invoked by the focus wrapper (owned by the editing
  /// coordinator, which needs session state).
  final KeyEventResult Function(FocusNode node, KeyEvent event) onKeyEvent;

  /// Called when the custom editor reports a new pending value.
  final ValueChanged<dynamic> onValueChanged;

  /// Called when the custom editor requests to stop editing. Pass `true` to
  /// cancel (revert) or `false` to commit.
  final void Function(bool cancel) onStopEditing;

  @override
  State<CustomEditorOverlay<TData>> createState() =>
      _CustomEditorOverlayState<TData>();
}

class _CustomEditorOverlayState<TData>
    extends State<CustomEditorOverlay<TData>> {
  @override
  Widget build(BuildContext context) {
    final params = CellEditorParams<TData>(
      value: widget.originalValue,
      data: widget.rowData,
      rowIndex: widget.rowIndex,
      colDef: widget.colDef,
      column: widget.field ?? '',
      eventKey: null,
      onValueChanged: widget.onValueChanged,
      stopEditing: widget.onStopEditing,
    );

    final editorWidget = widget.editor.builder(widget.editorContext, params);

    if (widget.editor.popup) {
      // Popup mode: render below or over the cell
      if (widget.editor.popupPosition == PopupPosition.under) {
        final cellBottom = widget.cellRect.top + widget.cellRect.height;
        return Positioned(
          left: widget.cellRect.left,
          top: cellBottom,
          child: _wrapInFocus(editorWidget),
        );
      } else {
        // Over: position at the cell location
        return Positioned(
          left: widget.cellRect.left,
          top: widget.cellRect.top,
          child: _wrapInFocus(editorWidget),
        );
      }
    } else {
      // Inline mode: constrained to cell bounds
      return Positioned(
        left: widget.cellRect.left,
        top: widget.cellRect.top,
        width: widget.cellRect.width,
        height: widget.cellRect.height,
        child: _wrapInFocus(editorWidget),
      );
    }
  }

  Widget _wrapInFocus(Widget child) {
    return Focus(
      focusNode: widget.focusNode,
      onKeyEvent: widget.onKeyEvent,
      child: child,
    );
  }
}
