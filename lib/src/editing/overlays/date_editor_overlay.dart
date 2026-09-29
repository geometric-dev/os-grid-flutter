import 'package:flutter/material.dart';

import '../../columns/os_column_def.dart';
import '../../locale/os_locale_text.dart';
import '../../theming/os_grid_theme.dart';
import '../date_picker_overlay.dart';
import '../os_date_cell_editor.dart';
import '../os_date_string_cell_editor.dart';

/// Positioned wrapper hosting the inline calendar for the active date edit
/// session.
///
/// Resolves the initial date and the min/max/step/time constraints from the
/// column's cell editor ([OsDateCellEditor] or [OsDateStringCellEditor]) and
/// the value captured when the session opened, then renders a
/// [DatePickerOverlay] below the edited cell.
class DateEditorOverlay extends StatefulWidget {
  const DateEditorOverlay({
    super.key,
    required this.cellRect,
    required this.colDef,
    required this.originalValue,
    required this.onDateSelected,
    required this.onCancel,
    required this.theme,
    required this.localeText,
  });

  /// Rect of the cell being edited (the calendar anchors below it).
  final Rect cellRect;

  /// Column definition of the cell being edited.
  final OsColumnDef? colDef;

  /// The original cell value captured when the editing session opened.
  final dynamic originalValue;

  /// Called when the user picks a date.
  final ValueChanged<DateTime> onDateSelected;

  /// Called when the user cancels (Escape / outside tap).
  final VoidCallback onCancel;

  /// Theme for styling the picker.
  final OsGridTheme? theme;

  /// Localised labels for calendar strings (defaults to English).
  final OsLocaleText? localeText;

  @override
  State<DateEditorOverlay> createState() => _DateEditorOverlayState();
}

class _DateEditorOverlayState extends State<DateEditorOverlay> {
  @override
  Widget build(BuildContext context) {
    // Determine initial date and constraints
    DateTime initialDate;
    DateTime? minDate;
    DateTime? maxDate;
    int? step;
    bool includeTime = false;

    if (widget.colDef?.cellEditor is OsDateStringCellEditor) {
      final editor = widget.colDef!.cellEditor as OsDateStringCellEditor;
      minDate = editor.minDate;
      maxDate = editor.maxDate;
      step = editor.step;
      includeTime = editor.includeTime;

      // Parse the current string value to a DateTime
      final currentValue = widget.originalValue;
      if (currentValue is String) {
        initialDate = editor.parseCellValue(currentValue) ?? DateTime.now();
      } else {
        initialDate = DateTime.now();
      }
    } else if (widget.colDef?.cellEditor is OsDateCellEditor) {
      final editor = widget.colDef!.cellEditor as OsDateCellEditor;
      minDate = editor.minDate;
      maxDate = editor.maxDate;
      step = editor.step;
      includeTime = editor.includeTime;

      // Use the current DateTime value
      final currentValue = widget.originalValue;
      if (currentValue is DateTime) {
        initialDate = currentValue;
      } else if (currentValue is String) {
        initialDate =
            OsDateCellEditor.parseDate(currentValue) ?? DateTime.now();
      } else {
        initialDate = DateTime.now();
      }
    } else {
      initialDate = DateTime.now();
    }

    return Positioned(
      left: widget.cellRect.left,
      top: widget.cellRect.top + widget.cellRect.height,
      child: DatePickerOverlay(
        initialDate: initialDate,
        minDate: minDate,
        maxDate: maxDate,
        step: step,
        includeTime: includeTime,
        theme: widget.theme,
        localeText: widget.localeText,
        onDateSelected: widget.onDateSelected,
        onCancel: widget.onCancel,
      ),
    );
  }
}
