import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../locale/os_locale_text.dart';
import '../theming/grid_popup_surface.dart';
import '../theming/os_grid_theme.dart';
import '../theming/resolved_grid_theme.dart';

/// An inline calendar date picker overlay for the date cell editor.
///
/// Renders a compact month-view calendar below the cell being edited.
/// The user can navigate months and select a date. Supports min/max
/// constraints and step validation.
///
/// The visible calendar renders into the nearest [Overlay] via an
/// [OverlayPortal], so it can escape narrow grid bounds; the host keeps
/// responsibility for outside-tap/scroll dismissal (no barrier is drawn).
/// Styling resolves from [theme]; labels come from [localeText].
class DatePickerOverlay extends StatefulWidget {
  const DatePickerOverlay({
    super.key,
    required this.initialDate,
    required this.onDateSelected,
    required this.onCancel,
    this.minDate,
    this.maxDate,
    this.step,
    this.includeTime = false,
    this.theme,
    this.localeText,
  });

  /// The initially selected date (highlighted in the calendar).
  final DateTime initialDate;

  /// Called when the user selects a date.
  final ValueChanged<DateTime> onDateSelected;

  /// Called when the user cancels (Escape key).
  final VoidCallback onCancel;

  /// Minimum selectable date (inclusive).
  final DateTime? minDate;

  /// Maximum selectable date (inclusive).
  final DateTime? maxDate;

  /// Step in days between valid values.
  final int? step;

  /// Whether to show a time picker after date selection.
  final bool includeTime;

  /// Theme for styling the picker.
  final OsGridTheme? theme;

  /// Localised labels for calendar strings (defaults to English).
  final OsLocaleText? localeText;

  @override
  State<DatePickerOverlay> createState() => _DatePickerOverlayState();
}

class _DatePickerOverlayState extends State<DatePickerOverlay> {
  static const _popupWidth = 280.0;

  late DateTime _displayedMonth;
  late DateTime _selectedDate;
  TimeOfDay? _selectedTime;
  final FocusNode _focusNode = FocusNode();

  /// Whether we're in time-picking mode (after date selection with includeTime).
  bool _pickingTime = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    _displayedMonth = DateTime(
      widget.initialDate.year,
      widget.initialDate.month,
    );
    if (widget.includeTime) {
      _selectedTime = TimeOfDay(
        hour: widget.initialDate.hour,
        minute: widget.initialDate.minute,
      );
    }
    // Explicitly request focus after the frame so the date picker receives
    // keyboard events even when another widget grabbed focus during the
    // pointer-down that triggered the double-tap.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resolved = ResolvedGridTheme.from(widget.theme);

    return GridPopupSurface.atOrigin(
      popupWidth: _popupWidth,
      estimatedHeight: 340,
      blurSigma: widget.theme?.popupBlurSigma ?? 0,
      contentBuilder: (context) => Focus(
        focusNode: _focusNode,
        onKeyEvent: _handleKeyEvent,
        child: Material(
          elevation: resolved.popupElevation - 4,
          borderRadius: BorderRadius.circular(resolved.controlRadius),
          color: resolved.background,
          child: Container(
            width: _popupWidth,
            decoration: BoxDecoration(
              border: Border.all(color: resolved.border),
              borderRadius: BorderRadius.circular(resolved.controlRadius),
            ),
            child: _pickingTime
                ? _buildTimePicker(resolved)
                : _buildCalendar(resolved),
          ),
        ),
      ),
    );
  }

  Widget _buildCalendar(ResolvedGridTheme resolved) {
    final daysInMonth = DateTime(
      _displayedMonth.year,
      _displayedMonth.month + 1,
      0,
    ).day;
    final firstDayOfWeek = DateTime(
      _displayedMonth.year,
      _displayedMonth.month,
      1,
    ).weekday;
    // Monday = 1, so offset is firstDayOfWeek - 1
    final offset = firstDayOfWeek - 1;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Month navigation header
        _buildMonthHeader(resolved),
        // Day-of-week labels
        _buildDayOfWeekRow(resolved),
        // Calendar grid
        _buildDayGrid(daysInMonth, offset, resolved),
        // Today button
        _buildTodayButton(resolved),
      ],
    );
  }

  Widget _buildMonthHeader(ResolvedGridTheme resolved) {
    final lt = widget.localeText ?? OsLocaleText.defaultLocale;
    final monthLabel =
        '${lt.monthNames[_displayedMonth.month - 1]} ${_displayedMonth.year}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _navButton(Icons.chevron_left, _goToPreviousMonth, resolved),
          Text(
            monthLabel,
            style: resolved.text(13, fontWeight: FontWeight.w600),
          ),
          _navButton(Icons.chevron_right, _goToNextMonth, resolved),
        ],
      ),
    );
  }

  Widget _navButton(
    IconData icon,
    VoidCallback onPressed,
    ResolvedGridTheme resolved,
  ) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: 18, color: resolved.mutedForeground),
      ),
    );
  }

  Widget _buildDayOfWeekRow(ResolvedGridTheme resolved) {
    final lt = widget.localeText ?? OsLocaleText.defaultLocale;
    final days = lt.dayOfWeekInitials;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: days.map((d) {
          return Expanded(
            child: Center(
              child: Text(
                d,
                style: resolved.text(
                  11,
                  fontWeight: FontWeight.w500,
                  color: resolved.hintForeground,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDayGrid(
    int daysInMonth,
    int offset,
    ResolvedGridTheme resolved,
  ) {
    final totalCells = offset + daysInMonth;
    final rows = (totalCells / 7).ceil();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(rows, (row) {
          return Row(
            children: List.generate(7, (col) {
              final cellIndex = row * 7 + col;
              final dayNumber = cellIndex - offset + 1;

              if (dayNumber < 1 || dayNumber > daysInMonth) {
                return const Expanded(child: SizedBox(height: 32));
              }

              final date = DateTime(
                _displayedMonth.year,
                _displayedMonth.month,
                dayNumber,
              );
              final isSelected = _isSameDay(date, _selectedDate);
              final isToday = _isSameDay(date, DateTime.now());
              final isDisabled = !_isDateSelectable(date);

              return Expanded(
                child: GestureDetector(
                  onTap: isDisabled ? null : () => _selectDate(date),
                  child: Container(
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected ? resolved.accent : null,
                      borderRadius: BorderRadius.circular(
                        resolved.controlRadius,
                      ),
                      border: isToday && !isSelected
                          ? Border.all(color: resolved.accent, width: 1)
                          : null,
                    ),
                    child: Text(
                      dayNumber.toString(),
                      style: resolved.text(
                        12,
                        fontWeight: isToday
                            ? FontWeight.w600
                            : FontWeight.normal,
                        color: isDisabled
                            ? resolved.disabledForeground
                            : isSelected
                            ? Colors.white
                            : resolved.foreground,
                      ),
                    ),
                  ),
                ),
              );
            }),
          );
        }),
      ),
    );
  }

  Widget _buildTodayButton(ResolvedGridTheme resolved) {
    final lt = widget.localeText ?? OsLocaleText.defaultLocale;
    final today = DateTime.now();
    final todaySelectable = _isDateSelectable(today);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: GestureDetector(
        onTap: todaySelectable
            ? () => _selectDate(DateTime(today.year, today.month, today.day))
            : null,
        child: Text(
          lt.today,
          style: resolved.text(
            12,
            fontWeight: FontWeight.w500,
            color: todaySelectable
                ? resolved.accent
                : resolved.accent.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }

  Widget _buildTimePicker(ResolvedGridTheme resolved) {
    final lt = widget.localeText ?? OsLocaleText.defaultLocale;
    final hour = _selectedTime?.hour ?? 0;
    final minute = _selectedTime?.minute ?? 0;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            lt.selectTime,
            style: resolved.text(13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Hour spinner
              _buildSpinner(
                value: hour,
                maxValue: 23,
                fgColor: resolved.foreground,
                accentColor: resolved.accent,
                onChanged: (v) => setState(() {
                  _selectedTime = TimeOfDay(hour: v, minute: minute);
                }),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(':', style: resolved.text(18)),
              ),
              // Minute spinner
              _buildSpinner(
                value: minute,
                maxValue: 59,
                fgColor: resolved.foreground,
                accentColor: resolved.accent,
                onChanged: (v) => setState(() {
                  _selectedTime = TimeOfDay(hour: hour, minute: v);
                }),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: widget.onCancel,
                child: Text(lt.cancel, style: resolved.text(12)),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: _confirmDateTime,
                child: Text(
                  lt.ok,
                  style: resolved.text(12, color: resolved.accent),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSpinner({
    required int value,
    required int maxValue,
    required Color fgColor,
    required Color accentColor,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () => onChanged(value < maxValue ? value + 1 : 0),
          child: Icon(Icons.arrow_drop_up, color: fgColor, size: 20),
        ),
        Container(
          width: 40,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: accentColor.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            value.toString().padLeft(2, '0'),
            style: TextStyle(
              fontSize: 16,
              color: fgColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        InkWell(
          onTap: () => onChanged(value > 0 ? value - 1 : maxValue),
          child: Icon(Icons.arrow_drop_down, color: fgColor, size: 20),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Logic
  // ---------------------------------------------------------------------------

  void _goToPreviousMonth() {
    setState(() {
      _displayedMonth = DateTime(
        _displayedMonth.year,
        _displayedMonth.month - 1,
      );
    });
  }

  void _goToNextMonth() {
    setState(() {
      _displayedMonth = DateTime(
        _displayedMonth.year,
        _displayedMonth.month + 1,
      );
    });
  }

  void _selectDate(DateTime date) {
    if (widget.includeTime) {
      setState(() {
        _selectedDate = date;
        _pickingTime = true;
      });
    } else {
      widget.onDateSelected(date);
    }
  }

  void _confirmDateTime() {
    final time = _selectedTime ?? const TimeOfDay(hour: 0, minute: 0);
    final dateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      time.hour,
      time.minute,
    );
    widget.onDateSelected(dateTime);
  }

  bool _isDateSelectable(DateTime date) {
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (widget.minDate != null) {
      final minOnly = DateTime(
        widget.minDate!.year,
        widget.minDate!.month,
        widget.minDate!.day,
      );
      if (dateOnly.isBefore(minOnly)) return false;
    }

    if (widget.maxDate != null) {
      final maxOnly = DateTime(
        widget.maxDate!.year,
        widget.maxDate!.month,
        widget.maxDate!.day,
      );
      if (dateOnly.isAfter(maxOnly)) return false;
    }

    if (widget.step != null && widget.step! > 0) {
      final reference = widget.minDate ?? widget.initialDate;
      final refOnly = DateTime(reference.year, reference.month, reference.day);
      final diff = dateOnly.difference(refOnly).inDays;
      if (diff % widget.step! != 0) return false;
    }

    return true;
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      widget.onCancel();
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.enter) {
      if (_pickingTime) {
        _confirmDateTime();
      } else {
        _selectDate(_selectedDate);
      }
      return KeyEventResult.handled;
    }

    // Arrow key navigation in calendar mode
    if (!_pickingTime) {
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        _moveSelection(-1);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        _moveSelection(1);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        _moveSelection(-7);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        _moveSelection(7);
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  void _moveSelection(int days) {
    final newDate = _selectedDate.add(Duration(days: days));
    if (_isDateSelectable(newDate)) {
      setState(() {
        _selectedDate = newDate;
        // Update displayed month if we've navigated to a different month
        if (newDate.month != _displayedMonth.month ||
            newDate.year != _displayedMonth.year) {
          _displayedMonth = DateTime(newDate.year, newDate.month);
        }
      });
    }
  }

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
