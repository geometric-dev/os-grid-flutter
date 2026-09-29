import 'package:flutter/material.dart';

import '../../theming/os_grid_theme.dart';
import '../os_rich_select_cell_editor.dart';
import '../os_select_cell_editor.dart';

/// Dropdown overlay for the plain select cell editor.
///
/// Renders the option list below the edited cell with keyboard navigation
/// (highlight index owned by the editing coordinator) and hover-to-highlight.
class SelectEditorOverlay extends StatefulWidget {
  const SelectEditorOverlay({
    super.key,
    required this.cellRect,
    required this.editor,
    required this.values,
    required this.highlightedIndex,
    required this.originalValue,
    required this.scrollController,
    required this.focusNode,
    required this.onKeyEvent,
    required this.onSelect,
    required this.onHoverIndex,
    required this.theme,
  });

  /// Rect of the cell being edited (the dropdown anchors below it).
  final Rect cellRect;

  /// The select editor config (gap/max sizes for the value list).
  final OsSelectCellEditor editor;

  /// The option values to display.
  final List<dynamic> values;

  /// The currently highlighted option index.
  final int highlightedIndex;

  /// The original cell value captured when the editing session opened
  /// (marks the current-value check icon).
  final dynamic originalValue;

  /// Scroll controller for the option list.
  final ScrollController scrollController;

  /// Focus node attached to the dropdown's key-event focus wrapper.
  final FocusNode focusNode;

  /// Key handler invoked by the focus wrapper (owned by the editing
  /// coordinator, which needs session state).
  final KeyEventResult Function(KeyEvent event) onKeyEvent;

  /// Called when an option is tapped (commit).
  final void Function(dynamic value) onSelect;

  /// Called when the pointer hovers an option (updates the highlight).
  final void Function(int index) onHoverIndex;

  /// Theme for styling the dropdown.
  final OsGridTheme? theme;

  @override
  State<SelectEditorOverlay> createState() => _SelectEditorOverlayState();
}

class _SelectEditorOverlayState extends State<SelectEditorOverlay> {
  @override
  Widget build(BuildContext context) {
    final values = widget.values;
    final theme = widget.theme;
    final bgColor = theme?.backgroundColor ?? Colors.white;
    final fgColor = theme?.foregroundColor ?? Colors.black;
    final accentColor = theme?.accentColor ?? Colors.blue;
    final borderColor = theme?.borderColor ?? const Color(0xFFE2E2E2);
    final textStyle =
        theme?.cellTextStyle ?? TextStyle(fontSize: 13, color: fgColor);

    const itemHeight = 32.0;
    final gap = widget.editor.valueListGap ?? 0.0;
    final maxHeight = widget.editor.valueListMaxHeight ?? 200.0;
    final maxWidth = widget.editor.valueListMaxWidth ?? widget.cellRect.width;
    final listHeight = (values.length * itemHeight).clamp(0.0, maxHeight);

    // Position the dropdown below the cell (or above if not enough space)
    final cellBottom = widget.cellRect.top + widget.cellRect.height;

    return Positioned(
      left: widget.cellRect.left,
      top: cellBottom + gap,
      width: maxWidth,
      height: listHeight,
      child: Focus(
        focusNode: widget.focusNode,
        onKeyEvent: (_, event) => widget.onKeyEvent(event),
        child: Container(
          decoration: BoxDecoration(
            color: bgColor,
            border: Border.all(color: borderColor, width: 1),
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: ListView.builder(
              controller: widget.scrollController,
              padding: EdgeInsets.zero,
              itemCount: values.length,
              itemExtent: itemHeight,
              itemBuilder: (context, index) {
                final value = values[index];
                return _SelectItemRow(
                  value: value,
                  label: value?.toString() ?? '',
                  index: index,
                  highlightedIndex: widget.highlightedIndex,
                  originalValue: widget.originalValue,
                  itemHeight: itemHeight,
                  bgColor: bgColor,
                  accentColor: accentColor,
                  fgColor: fgColor,
                  textStyle: textStyle,
                  onTap: widget.onSelect,
                  onHover: widget.onHoverIndex,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Searchable dropdown overlay for the rich select cell editor.
///
/// Mirrors [SelectEditorOverlay]'s styling, adding a debounced search input
/// above the value list. Keyboard interaction flows through the search field's
/// focus node interceptor installed by the editing coordinator; the popup
/// wrapper handles commit/navigation keys when search is hidden.
class RichSelectEditorOverlay extends StatefulWidget {
  const RichSelectEditorOverlay({
    super.key,
    required this.cellRect,
    required this.editor,
    required this.values,
    required this.highlightedIndex,
    required this.originalValue,
    required this.scrollController,
    required this.selectFocusNode,
    required this.onKeyEvent,
    required this.searchController,
    required this.searchFocusNode,
    required this.onSearchChanged,
    required this.onSelect,
    required this.onHoverIndex,
    required this.theme,
  });

  /// Rect of the cell being edited (the dropdown anchors below it).
  final Rect cellRect;

  /// The rich select editor config.
  final OsRichSelectCellEditor editor;

  /// The (already filtered) option values to display.
  final List<dynamic> values;

  /// The currently highlighted option index.
  final int highlightedIndex;

  /// The original cell value captured when the editing session opened
  /// (marks the current-value check icon).
  final dynamic originalValue;

  /// Scroll controller for the option list.
  final ScrollController scrollController;

  /// Focus node attached to the dropdown's key-event focus wrapper.
  final FocusNode selectFocusNode;

  /// Key handler invoked by the popup focus wrapper (owned by the editing
  /// coordinator, which needs session state).
  final KeyEventResult Function(KeyEvent event) onKeyEvent;

  /// Text controller backing the search input.
  final TextEditingController searchController;

  /// Focus node backing the search input.
  final FocusNode searchFocusNode;

  /// Called on each search input change (coordinator applies its debounce).
  final ValueChanged<String> onSearchChanged;

  /// Called when an option is tapped (commit).
  final void Function(dynamic value) onSelect;

  /// Called when the pointer hovers an option (updates the highlight).
  final void Function(int index) onHoverIndex;

  /// Theme for styling the dropdown.
  final OsGridTheme? theme;

  @override
  State<RichSelectEditorOverlay> createState() =>
      _RichSelectEditorOverlayState();
}

class _RichSelectEditorOverlayState extends State<RichSelectEditorOverlay> {
  @override
  Widget build(BuildContext context) {
    final editor = widget.editor;
    final values = widget.values;

    final theme = widget.theme;
    final bgColor = theme?.backgroundColor ?? Colors.white;
    final fgColor = theme?.foregroundColor ?? Colors.black;
    final accentColor = theme?.accentColor ?? Colors.blue;
    final borderColor = theme?.borderColor ?? const Color(0xFFE2E2E2);
    final textStyle =
        theme?.cellTextStyle ?? TextStyle(fontSize: 13, color: fgColor);

    const itemHeight = 32.0;
    const searchHeight = 40.0;
    const searchPadding = 6.0;
    final gap = editor.valueListGap ?? 0.0;
    final maxHeight = editor.valueListMaxHeight ?? 200.0;
    final maxWidth = editor.valueListMaxWidth ?? widget.cellRect.width;
    final listHeight = (values.length * itemHeight).clamp(0.0, maxHeight);
    final showSearch = editor.allowTyping;
    final totalHeight =
        listHeight + (showSearch ? searchHeight + searchPadding * 2 : 0);

    // Position the dropdown below the cell.
    final cellBottom = widget.cellRect.top + widget.cellRect.height;

    return Positioned(
      left: widget.cellRect.left,
      top: cellBottom + gap,
      width: maxWidth,
      height: totalHeight,
      child: Focus(
        focusNode: widget.selectFocusNode,
        onKeyEvent: (_, event) => widget.onKeyEvent(event),
        child: Container(
          decoration: BoxDecoration(
            color: bgColor,
            border: Border.all(color: borderColor, width: 1),
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Column(
              children: [
                if (showSearch)
                  Padding(
                    padding: const EdgeInsets.all(searchPadding),
                    child: SizedBox(
                      height: searchHeight - searchPadding * 2,
                      child: TextField(
                        controller: widget.searchController,
                        focusNode: widget.searchFocusNode,
                        style: textStyle,
                        cursorColor: accentColor,
                        onChanged: widget.onSearchChanged,
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: editor.searchPlaceholder,
                          prefixIcon: const Icon(Icons.search, size: 16),
                          prefixIconColor: borderColor,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: BorderSide(color: accentColor),
                          ),
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: ListView.builder(
                    controller: widget.scrollController,
                    padding: EdgeInsets.zero,
                    itemCount: values.length,
                    itemExtent: itemHeight,
                    itemBuilder: (context, index) {
                      final value = values[index];
                      return _SelectItemRow(
                        value: value,
                        label:
                            editor.valueFormatter?.call(value) ??
                            value?.toString() ??
                            '',
                        index: index,
                        highlightedIndex: widget.highlightedIndex,
                        originalValue: widget.originalValue,
                        itemHeight: itemHeight,
                        bgColor: bgColor,
                        accentColor: accentColor,
                        fgColor: fgColor,
                        textStyle: textStyle,
                        onTap: widget.onSelect,
                        onHover: widget.onHoverIndex,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A single selectable row shared by the plain and rich select overlays.
class _SelectItemRow extends StatelessWidget {
  const _SelectItemRow({
    required this.value,
    required this.label,
    required this.index,
    required this.highlightedIndex,
    required this.originalValue,
    required this.itemHeight,
    required this.bgColor,
    required this.accentColor,
    required this.fgColor,
    required this.textStyle,
    required this.onTap,
    required this.onHover,
  });

  /// The raw option value (passed through to [onTap]).
  final dynamic value;

  /// Pre-formatted display label.
  final String label;

  /// Index of this row in the option list.
  final int index;

  /// The currently highlighted option index.
  final int highlightedIndex;

  /// The original cell value captured when the editing session opened.
  final dynamic originalValue;

  /// Fixed row height.
  final double itemHeight;

  final Color bgColor;
  final Color accentColor;
  final Color fgColor;
  final TextStyle textStyle;

  /// Called when the row is tapped, with the raw option value.
  final void Function(dynamic value) onTap;

  /// Called when the pointer enters the row, with this row's index.
  final void Function(int index) onHover;

  @override
  Widget build(BuildContext context) {
    final isHighlighted = index == highlightedIndex;
    final isCurrentValue = value?.toString() == originalValue?.toString();

    return GestureDetector(
      onTap: () => onTap(value),
      child: MouseRegion(
        onEnter: (_) {
          onHover(index);
        },
        child: Container(
          height: itemHeight,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          color: isHighlighted
              ? Color.lerp(bgColor, accentColor, 0.12)
              : bgColor,
          child: Row(
            children: [
              if (isCurrentValue)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Icon(Icons.check, size: 14, color: accentColor),
                ),
              Expanded(
                child: Text(
                  label,
                  style: textStyle.copyWith(
                    color: isCurrentValue ? accentColor : fgColor,
                    fontWeight: isCurrentValue
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
