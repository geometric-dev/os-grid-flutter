import 'package:flutter/material.dart';

import '../../theming/os_grid_theme.dart';
import '../os_large_text_cell_editor.dart';

/// Popup textarea overlay for the large text cell editor.
///
/// Renders a multi-line [TextField] below the edited cell, sized from the
/// editor's `rows`/`cols` params and clamped so it does not overflow the
/// grid's right edge.
class LargeTextEditorOverlay extends StatefulWidget {
  const LargeTextEditorOverlay({
    super.key,
    required this.cellRect,
    required this.editor,
    required this.controller,
    required this.focusNode,
    required this.onKeyEvent,
    required this.theme,
  });

  /// Rect of the cell being edited (the popup anchors below it).
  final Rect cellRect;

  /// The large text editor config (rows/cols/maxLength).
  final OsLargeTextCellEditor editor;

  /// Text controller backing the textarea.
  final TextEditingController controller;

  /// Focus node attached to the popup's key-event focus wrapper.
  final FocusNode focusNode;

  /// Key handler invoked by the focus wrapper (owned by the editing
  /// coordinator, which needs session state).
  final KeyEventResult Function(FocusNode node, KeyEvent event) onKeyEvent;

  /// Theme for styling the popup.
  final OsGridTheme? theme;

  @override
  State<LargeTextEditorOverlay> createState() => _LargeTextEditorOverlayState();
}

class _LargeTextEditorOverlayState extends State<LargeTextEditorOverlay> {
  @override
  Widget build(BuildContext context) {
    final largeTextEditor = widget.editor;

    // Calculate popup dimensions based on rows/cols params
    final double popupWidth = largeTextEditor.cols * 8.0;
    final double popupHeight = largeTextEditor.rows * 20.0;

    // Position below the cell
    final cellBottom = widget.cellRect.top + widget.cellRect.height;

    final theme = widget.theme;
    final bgColor = theme?.backgroundColor ?? Colors.white;
    final borderColor = theme?.accentColor ?? Colors.blue;
    final textStyle =
        theme?.cellTextStyle ??
        const TextStyle(fontSize: 13, color: Colors.black);

    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Clamp popup so it doesn't overflow the grid's right edge
          final maxRight = constraints.maxWidth;
          final left = widget.cellRect.left;
          final clampedWidth = popupWidth.clamp(
            0.0,
            (maxRight - left).clamp(0.0, double.infinity),
          );

          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: left,
                top: cellBottom,
                width: clampedWidth,
                height: popupHeight,
                child: Material(
                  elevation: 4,
                  color: bgColor,
                  borderRadius: BorderRadius.circular(2),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: borderColor, width: 2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Focus(
                      focusNode: widget.focusNode,
                      onKeyEvent: widget.onKeyEvent,
                      child: TextField(
                        controller: widget.controller,
                        maxLines: null,
                        expands: true,
                        maxLength: largeTextEditor.maxLength,
                        style: textStyle,
                        cursorColor: borderColor,
                        textAlignVertical: TextAlignVertical.top,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(8),
                          isDense: true,
                          counterText: '', // Hide the character counter
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
