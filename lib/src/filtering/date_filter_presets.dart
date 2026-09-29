/// Preset date range calculations for the date filter.
///
/// Mirrors OS Grid's `presetDateFilterTypeRelativeFromToMap` from
/// `dateFilterHandler.ts`. Each preset represents a relative date range
/// calculated at evaluation time.
///
/// All preset ranges use half-open intervals: `[from, to)` — i.e.
/// `cellDate >= from && cellDate < to`.
library;

/// A half-open date range: [from, to).
class DateRange {
  const DateRange(this.from, this.to);
  final DateTime from;
  final DateTime to;
}

/// Cache entry for a preset date range, valid until the start of the next day.
class _RangeCacheItem {
  _RangeCacheItem(this.range, this.expires);
  final DateRange range;
  final DateTime expires;
}

/// Manages preset date range calculations with caching.
///
/// Ranges are cached until the start of the next day, since all presets
/// are relative to "today" and don't change within a single day.
class DateFilterPresets {
  DateFilterPresets._();

  static final Map<String, _RangeCacheItem> _cache = {};

  /// The first day of the week (0 = Sunday, 1 = Monday, ..., 6 = Saturday).
  /// Defaults to Monday (1), matching OS Grid's TypeScript default.
  static int firstDayOfWeek = DateTime.monday;

  /// Clears the preset range cache. Useful for testing.
  static void clearCache() => _cache.clear();

  /// Returns the date range for a preset type, or null if the type is not
  /// a recognised preset.
  ///
  /// The [now] parameter allows injecting a specific time for testing.
  static DateRange? getPresetRange(String type, {DateTime? now}) {
    final rangeFn = _presetRangeFunctions[type];
    if (rangeFn == null) return null;

    final currentTime = now ?? DateTime.now();

    // Check cache (valid until start of next day)
    final cached = _cache[type];
    if (cached != null && currentTime.isBefore(cached.expires)) {
      return cached.range;
    }

    // Calculate the range
    final range = rangeFn(currentTime);

    // Cache until start of next day
    final nextDay = _startOfNextDay(currentTime);
    _cache[type] = _RangeCacheItem(range, nextDay);

    return range;
  }

  /// Whether the given type string is a recognised preset date range.
  static bool isPresetType(String type) =>
      _presetRangeFunctions.containsKey(type);

  // --- Range calculation functions ---

  static DateTime _startOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static DateTime _startOfNextDay(DateTime date) =>
      DateTime(date.year, date.month, date.day + 1);

  static DateTime _startOfWeek(DateTime date) {
    final day = date.weekday % 7; // Convert to 0=Sun, 1=Mon, ..., 6=Sat
    final weekStart = firstDayOfWeek % 7;
    final diff = (day - weekStart + 7) % 7;
    return _startOfDay(date.subtract(Duration(days: diff)));
  }

  static DateTime _startOfNextWeek(DateTime date) {
    final weekStart = _startOfWeek(date);
    return weekStart.add(const Duration(days: 7));
  }

  static DateTime _startOfMonth(DateTime date) =>
      DateTime(date.year, date.month, 1);

  static DateTime _startOfNextMonth(DateTime date) =>
      DateTime(date.year, date.month + 1, 1);

  static DateTime _startOfQuarter(DateTime date) {
    final quarter = (date.month - 1) ~/ 3; // 0, 1, 2, 3
    return DateTime(date.year, quarter * 3 + 1, 1);
  }

  static DateTime _startOfNextQuarter(DateTime date) {
    final quarter = (date.month - 1) ~/ 3;
    return DateTime(date.year, quarter * 3 + 4, 1);
  }

  static DateTime _startOfYear(DateTime date) => DateTime(date.year, 1, 1);

  static DateTime _startOfNextYear(DateTime date) =>
      DateTime(date.year + 1, 1, 1);

  // --- Preset range functions ---

  static final Map<String, DateRange Function(DateTime)>
  _presetRangeFunctions = {
    'today': (now) => DateRange(_startOfDay(now), _startOfNextDay(now)),
    'yesterday': (now) {
      final yesterday = now.subtract(const Duration(days: 1));
      return DateRange(_startOfDay(yesterday), _startOfDay(now));
    },
    'tomorrow': (now) {
      final tomorrow = now.add(const Duration(days: 1));
      return DateRange(_startOfNextDay(now), _startOfNextDay(tomorrow));
    },
    'thisWeek': (now) => DateRange(_startOfWeek(now), _startOfNextWeek(now)),
    'lastWeek': (now) {
      final lastWeekDate = now.subtract(const Duration(days: 7));
      return DateRange(_startOfWeek(lastWeekDate), _startOfWeek(now));
    },
    'nextWeek': (now) {
      final nextWeekDate = now.add(const Duration(days: 7));
      return DateRange(_startOfNextWeek(now), _startOfNextWeek(nextWeekDate));
    },
    'thisMonth': (now) => DateRange(_startOfMonth(now), _startOfNextMonth(now)),
    'lastMonth': (now) {
      final lastMonth = DateTime(now.year, now.month - 1, 1);
      return DateRange(_startOfMonth(lastMonth), _startOfMonth(now));
    },
    'nextMonth': (now) {
      final nextMonth = DateTime(now.year, now.month + 1, 1);
      return DateRange(_startOfNextMonth(now), _startOfNextMonth(nextMonth));
    },
    'thisQuarter': (now) =>
        DateRange(_startOfQuarter(now), _startOfNextQuarter(now)),
    'lastQuarter': (now) {
      final lastQuarterDate = DateTime(now.year, now.month - 3, 1);
      return DateRange(_startOfQuarter(lastQuarterDate), _startOfQuarter(now));
    },
    'nextQuarter': (now) {
      final nextQuarterDate = DateTime(now.year, now.month + 3, 1);
      return DateRange(
        _startOfNextQuarter(now),
        _startOfNextQuarter(nextQuarterDate),
      );
    },
    'thisYear': (now) => DateRange(_startOfYear(now), _startOfNextYear(now)),
    'lastYear': (now) {
      final lastYear = DateTime(now.year - 1, now.month, now.day);
      return DateRange(_startOfYear(lastYear), _startOfYear(now));
    },
    'nextYear': (now) {
      final nextYear = DateTime(now.year + 1, now.month, now.day);
      return DateRange(_startOfNextYear(now), _startOfNextYear(nextYear));
    },
    'yearToDate': (now) => DateRange(_startOfYear(now), _startOfNextDay(now)),
    'last7Days': (now) => DateRange(
      _startOfDay(now.subtract(const Duration(days: 7))),
      _startOfNextDay(now),
    ),
    'last30Days': (now) => DateRange(
      _startOfDay(now.subtract(const Duration(days: 30))),
      _startOfNextDay(now),
    ),
    'last90Days': (now) => DateRange(
      _startOfDay(now.subtract(const Duration(days: 90))),
      _startOfNextDay(now),
    ),
    'last6Months': (now) => DateRange(
      _startOfDay(DateTime(now.year, now.month - 6, now.day)),
      _startOfNextDay(now),
    ),
    'last12Months': (now) => DateRange(
      _startOfDay(DateTime(now.year - 1, now.month, now.day)),
      _startOfNextDay(now),
    ),
    'last24Months': (now) => DateRange(
      _startOfDay(DateTime(now.year - 2, now.month, now.day)),
      _startOfNextDay(now),
    ),
  };
}
