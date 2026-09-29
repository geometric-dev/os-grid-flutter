import 'date_filter_presets.dart';
import 'filter_model.dart';
import 'os_bigint_filter.dart';
import 'os_date_filter.dart';
import 'os_filter.dart';
import 'os_number_filter.dart';
import 'os_set_filter.dart';
import 'os_text_filter.dart';

/// Centralised filter evaluation engine.
///
/// Evaluates whether a cell value passes a column's filter model.
/// Supports single conditions, combined conditions (AND/OR), and all
/// built-in text and number filter operations.
///
/// This mirrors OS Grid's `SimpleFilterHandler` and `ScalarFilterHandler`
/// logic, ported to idiomatic Dart.
class FilterEvaluator {
  const FilterEvaluator._();

  /// Evaluates whether a [cellValue] passes the given [model].
  ///
  /// [filterConfig] is the column's filter configuration (e.g. [OsTextFilter])
  /// which provides settings like case sensitivity.
  ///
  /// Returns `true` if the value passes the filter (should be shown).
  static bool evaluate({
    required dynamic cellValue,
    required OsColumnFilterModel model,
    required OsFilter filterConfig,
  }) {
    if (!model.isActive) return true;

    // Set filter: membership check on the value's string key. Blanks share
    // the '' key and only pass when explicitly selected. Unless the filter
    // opts into case sensitivity, keys match case-insensitively so a
    // selected entry passes every case variant of that value (AG Grid
    // behaviour).
    if (filterConfig is OsSetFilter) {
      final selected = model.values ?? const <String>[];
      final cellKey = osSetFilterValueKey(cellValue);
      if (filterConfig.caseSensitive) {
        return selected.contains(cellKey);
      }
      final foldedCellKey = cellKey.toLowerCase();
      for (final value in selected) {
        if (value.toLowerCase() == foldedCellKey) return true;
      }
      return false;
    }

    if (model.isCombined) {
      return _evaluateCombined(cellValue, model, filterConfig);
    }

    // Single condition
    final condition = model.conditions.first;
    return _evaluateCondition(cellValue, condition, filterConfig);
  }

  /// Evaluates a combined (multi-condition) filter model.
  static bool _evaluateCombined(
    dynamic cellValue,
    OsColumnFilterModel model,
    OsFilter filterConfig,
  ) {
    final conditions = model.conditions;
    final isOr = model.operator == OsJoinOperator.or;

    for (final condition in conditions) {
      // Skip empty/inactive conditions
      if (condition.type == 'empty') continue;
      if (condition.filter == null &&
          condition.type != 'blank' &&
          condition.type != 'notBlank' &&
          !DateFilterPresets.isPresetType(condition.type)) {
        continue;
      }

      final passes = _evaluateCondition(cellValue, condition, filterConfig);

      if (isOr && passes) return true;
      if (!isOr && !passes) return false;
    }

    // AND: all passed; OR: none passed
    return !isOr;
  }

  /// Evaluates a single filter condition against a cell value.
  static bool _evaluateCondition(
    dynamic cellValue,
    OsFilterCondition condition,
    OsFilter filterConfig,
  ) {
    final type = condition.type;

    // Handle blank/notBlank first (no filter value needed)
    if (type == 'blank') return _isBlank(cellValue);
    if (type == 'notBlank') return !_isBlank(cellValue);

    // For date filters, null handling depends on includeBlanksIn* options,
    // so delegate to the date evaluator which handles this.
    if (filterConfig is OsDateFilter) {
      return _evaluateDateCondition(cellValue, condition, filterConfig);
    }

    // Number/bigint evaluators likewise own their null-cell handling via
    // their includeBlanksIn* options, so delegate before the generic
    // null check below.
    if (filterConfig is OsNumberFilter) {
      return _evaluateNumberCondition(cellValue, condition, filterConfig);
    }

    if (filterConfig is OsBigIntFilter) {
      return _evaluateBigIntCondition(cellValue, condition, filterConfig);
    }

    // Null cell values fail all other filter types (except notEqual/notContains)
    if (cellValue == null) {
      return type == 'notEqual' || type == 'notContains';
    }

    if (filterConfig is OsTextFilter) {
      return _evaluateTextCondition(cellValue, condition, filterConfig);
    }

    // Fallback: string contains match
    final filterValue = condition.filter?.toString().toLowerCase() ?? '';
    return cellValue.toString().toLowerCase().contains(filterValue);
  }

  /// Evaluates a text filter condition.
  static bool _evaluateTextCondition(
    dynamic cellValue,
    OsFilterCondition condition,
    OsTextFilter config,
  ) {
    final type = condition.type;

    var filterValue = condition.filter?.toString() ?? '';

    // Apply the custom formatter to the raw filter input before any
    // comparison or normalisation (AG Grid `textFormatter` semantics).
    final formatter = config.textFormatter;
    if (formatter != null) {
      filterValue = formatter(filterValue) ?? '';
    }

    if (filterValue.isEmpty && type != 'blank' && type != 'notBlank') {
      return true; // No filter value means no filtering
    }

    final cellStr = cellValue.toString();

    // A custom matcher overrides the built-in operations whenever it returns
    // a verdict; null falls back to the built-in logic below. blank/notBlank
    // conditions are resolved by the caller and never reach here.
    final matcher = config.textMatcher;
    if (matcher != null && type != 'blank' && type != 'notBlank') {
      final verdict = matcher(
        filterValue: filterValue,
        cellValue: cellStr,
        filterOption: type,
      );
      if (verdict != null) return verdict;
    }

    // Apply case sensitivity and trimming
    final effectiveCell = config.caseSensitive
        ? cellStr
        : cellStr.toLowerCase();
    var effectiveFilter = config.caseSensitive
        ? filterValue
        : filterValue.toLowerCase();
    if (config.trimInput) effectiveFilter = effectiveFilter.trim();

    switch (type) {
      case 'contains':
        return effectiveCell.contains(effectiveFilter);
      case 'notContains':
        return !effectiveCell.contains(effectiveFilter);
      case 'equals':
        return effectiveCell == effectiveFilter;
      case 'notEqual':
        return effectiveCell != effectiveFilter;
      case 'startsWith':
        return effectiveCell.startsWith(effectiveFilter);
      case 'endsWith':
        return effectiveCell.endsWith(effectiveFilter);
      case 'blank':
        return _isBlank(cellValue);
      case 'notBlank':
        return !_isBlank(cellValue);
      default:
        return true;
    }
  }

  /// Evaluates a number filter condition.
  static bool _evaluateNumberCondition(
    dynamic cellValue,
    OsFilterCondition condition,
    OsNumberFilter config,
  ) {
    final type = condition.type;

    // Null cell values follow the includeBlanksIn* options (mirrors the date
    // filter; AG Grid excludes blanks from every operation by default).
    if (cellValue == null) {
      return _evaluateNumberNull(type, config);
    }

    // Parse the filter value as a number
    final filterNum = _parseNumber(condition.filter);
    if (filterNum == null && type != 'blank' && type != 'notBlank') {
      return true; // Invalid filter value means no filtering
    }

    // Parse the cell value as a number
    final cellNum = _parseNumber(cellValue);
    if (cellNum == null) {
      // Non-numeric cell values: only pass notEqual and notBlank
      return type == 'notEqual' || type == 'notBlank';
    }

    switch (type) {
      case 'equals':
        return cellNum == filterNum;
      case 'notEqual':
        return cellNum != filterNum;
      case 'greaterThan':
        return cellNum > filterNum!;
      case 'greaterThanOrEqual':
        return cellNum >= filterNum!;
      case 'lessThan':
        return cellNum < filterNum!;
      case 'lessThanOrEqual':
        return cellNum <= filterNum!;
      case 'inRange':
        final filterTo = _parseNumber(condition.filterTo);
        if (filterTo == null) return true;
        if (config.inRangeInclusive) {
          return cellNum >= filterNum! && cellNum <= filterTo;
        }
        return cellNum > filterNum! && cellNum < filterTo;
      case 'blank':
        return _isBlank(cellValue);
      case 'notBlank':
        return !_isBlank(cellValue);
      default:
        return true;
    }
  }

  /// Checks whether a value is considered "blank" (null or empty string).
  ///
  /// Whitespace-only strings are NOT blank — they are non-empty values,
  /// matching AG Grid semantics.
  static bool _isBlank(dynamic value) {
    if (value == null) return true;
    if (value is String) return value.isEmpty;
    if (value is double && value.isNaN) return true;
    return false;
  }

  /// Attempts to parse a value as a number.
  static num? _parseNumber(dynamic value) {
    if (value == null) return null;
    if (value is num) return value;
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      return num.tryParse(trimmed);
    }
    return null;
  }

  /// Evaluates a BigInt filter condition.
  ///
  /// Uses Dart's [BigInt] type for arbitrary-precision integer comparison,
  /// matching OS Grid TypeScript's use of JavaScript's native `bigint`.
  static bool _evaluateBigIntCondition(
    dynamic cellValue,
    OsFilterCondition condition,
    OsBigIntFilter config,
  ) {
    final type = condition.type;

    // Null cell values follow the includeBlanksIn* options (mirrors the date
    // filter; AG Grid excludes blanks from every operation by default).
    if (cellValue == null) {
      return _evaluateBigIntNull(type, config);
    }

    // Parse the filter value as a BigInt
    final filterBigInt = _parseBigInt(condition.filter);
    if (filterBigInt == null && type != 'blank' && type != 'notBlank') {
      return true; // Invalid filter value means no filtering
    }

    // Parse the cell value as a BigInt
    final cellBigInt = _parseBigInt(cellValue);
    if (cellBigInt == null) {
      // Non-integer cell values: only pass notEqual and notBlank
      return type == 'notEqual' || type == 'notBlank';
    }

    switch (type) {
      case 'equals':
        return cellBigInt == filterBigInt;
      case 'notEqual':
        return cellBigInt != filterBigInt;
      case 'greaterThan':
        return cellBigInt > filterBigInt!;
      case 'greaterThanOrEqual':
        return cellBigInt >= filterBigInt!;
      case 'lessThan':
        return cellBigInt < filterBigInt!;
      case 'lessThanOrEqual':
        return cellBigInt <= filterBigInt!;
      case 'inRange':
        final filterTo = _parseBigInt(condition.filterTo);
        if (filterTo == null) return true;
        if (config.inRangeInclusive) {
          return cellBigInt >= filterBigInt! && cellBigInt <= filterTo;
        }
        return cellBigInt > filterBigInt! && cellBigInt < filterTo;
      case 'blank':
        return _isBlank(cellValue);
      case 'notBlank':
        return !_isBlank(cellValue);
      default:
        return true;
    }
  }

  /// Handles null cell values for number filter operations.
  ///
  /// Returns true if the null value should pass the given operation
  /// based on the `includeBlanksIn*` configuration.
  static bool _evaluateNumberNull(String type, OsNumberFilter config) {
    switch (type) {
      case 'equals':
        return config.includeBlanksInEquals;
      case 'notEqual':
        return config.includeBlanksInNotEqual;
      case 'lessThan':
      case 'lessThanOrEqual':
        return config.includeBlanksInLessThan;
      case 'greaterThan':
      case 'greaterThanOrEqual':
        return config.includeBlanksInGreaterThan;
      case 'inRange':
        return config.includeBlanksInRange;
      default:
        return false;
    }
  }

  /// Handles null cell values for BigInt filter operations.
  ///
  /// Returns true if the null value should pass the given operation
  /// based on the `includeBlanksIn*` configuration.
  static bool _evaluateBigIntNull(String type, OsBigIntFilter config) {
    switch (type) {
      case 'equals':
        return config.includeBlanksInEquals;
      case 'notEqual':
        return config.includeBlanksInNotEqual;
      case 'lessThan':
      case 'lessThanOrEqual':
        return config.includeBlanksInLessThan;
      case 'greaterThan':
      case 'greaterThanOrEqual':
        return config.includeBlanksInGreaterThan;
      case 'inRange':
        return config.includeBlanksInRange;
      default:
        return false;
    }
  }

  /// Attempts to parse a value as a [BigInt].
  ///
  /// Accepts:
  /// - [BigInt] values directly
  /// - [int] values (converted to BigInt)
  /// - [String] values containing only digits with optional leading sign
  ///   (trailing 'n' suffix is stripped for JavaScript BigInt literal compat)
  /// - [double] values with no fractional part (converted to BigInt)
  ///
  /// Returns `null` for unparseable values (null, empty string, NaN,
  /// Infinity, decimals, non-numeric strings).
  static BigInt? _parseBigInt(dynamic value) {
    if (value == null) return null;
    if (value is BigInt) return value;
    if (value is int) return BigInt.from(value);
    if (value is double) {
      if (value.isNaN || value.isInfinite) return null;
      if (value == value.truncateToDouble()) {
        return BigInt.from(value.toInt());
      }
      return null;
    }
    if (value is String) {
      var trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      // Strip trailing 'n' for JavaScript BigInt literal compatibility
      if (trimmed.endsWith('n')) {
        trimmed = trimmed.substring(0, trimmed.length - 1);
      }
      // Validate: optional sign followed by digits only
      if (!RegExp(r'^[+-]?\d+$').hasMatch(trimmed)) return null;
      return BigInt.tryParse(trimmed);
    }
    return null;
  }

  /// Evaluates a date filter condition.
  ///
  /// Timezone contract: comparison is a **date-only calendar comparison in
  /// the cell's own parsed zone; Z-suffixed cells compare by their UTC
  /// calendar day**. Filter inputs without zone information are interpreted
  /// as local calendar dates. Neither side is converted between zones, so a
  /// cell string like '2024-01-01T23:30:00Z' equals the filter input
  /// '2024-01-01' (same UTC calendar day), and a local timestamp like
  /// '2024-01-01T23:30:00' also equals it (same local calendar day).
  static bool _evaluateDateCondition(
    dynamic cellValue,
    OsFilterCondition condition,
    OsDateFilter config,
  ) {
    final type = condition.type;

    // Handle blank/notBlank first (no filter value needed)
    if (type == 'blank') return _isBlank(cellValue);
    if (type == 'notBlank') return !_isBlank(cellValue);

    // Check if this is a preset date range type (today, yesterday, thisWeek, etc.)
    if (DateFilterPresets.isPresetType(type)) {
      return _evaluateDatePreset(cellValue, type, config);
    }

    // Parse the cell value to DateTime
    final cellDate = _parseDateTime(cellValue);

    // Null/unparseable cell values: check includeBlanksIn* options
    if (cellDate == null) {
      return _evaluateDateNull(type, config);
    }

    // Parse the filter value
    final filterDate = _parseDateString(condition.filter?.toString());
    if (filterDate == null) return true; // No valid filter value = no filtering

    final comparator = config.comparator ?? _defaultDateComparatorFor(config);
    final compareResult = comparator(
      filterDate,
      cellValue is DateTime ? cellValue : cellDate,
    );

    switch (type) {
      case 'equals':
        return compareResult == 0;
      case 'notEqual':
        return compareResult != 0;
      case 'lessThan':
        return compareResult < 0;
      case 'lessThanOrEqual':
        return compareResult <= 0;
      case 'greaterThan':
        return compareResult > 0;
      case 'greaterThanOrEqual':
        return compareResult >= 0;
      case 'inRange':
        final filterToDate = _parseDateString(condition.filterTo?.toString());
        if (filterToDate == null) return true;
        final compareToResult = comparator(
          filterToDate,
          cellValue is DateTime ? cellValue : cellDate,
        );
        if (config.inRangeInclusive) {
          return compareResult >= 0 && compareToResult <= 0;
        }
        return compareResult > 0 && compareToResult < 0;
      default:
        return true;
    }
  }

  /// Evaluates a preset date range (e.g. 'today', 'thisWeek', 'last30Days').
  ///
  /// Preset ranges use half-open intervals: [from, to) — the cell date must
  /// be >= from and < to. The default comparator applies the same
  /// zone policy as [_evaluateDateCondition]: date-only calendar comparison
  /// in the cell's own parsed zone (Z-suffixed cells use their UTC calendar
  /// day).
  static bool _evaluateDatePreset(
    dynamic cellValue,
    String presetType,
    OsDateFilter config,
  ) {
    // Parse the cell value to DateTime
    final cellDate = _parseDateTime(cellValue);

    // Null cell values: check includeBlanksInRange (presets are range-like)
    if (cellDate == null) {
      return config.includeBlanksInRange;
    }

    final range = DateFilterPresets.getPresetRange(presetType);
    if (range == null) return true; // Unknown preset = no filtering

    final comparator = config.comparator ?? _defaultDateComparatorFor(config);
    final compareFrom = comparator(
      range.from,
      cellValue is DateTime ? cellValue : cellDate,
    );
    final compareTo = comparator(
      range.to,
      cellValue is DateTime ? cellValue : cellDate,
    );

    // Half-open interval: cellDate >= from && cellDate < to
    return compareFrom >= 0 && compareTo < 0;
  }

  /// Handles null cell values for date filter operations.
  ///
  /// Returns true if the null value should pass the given operation
  /// based on the `includeBlanksIn*` configuration.
  static bool _evaluateDateNull(String type, OsDateFilter config) {
    switch (type) {
      case 'equals':
        return config.includeBlanksInEquals;
      case 'notEqual':
        return config.includeBlanksInNotEqual;
      case 'lessThan':
      case 'lessThanOrEqual':
        return config.includeBlanksInLessThan;
      case 'greaterThan':
      case 'greaterThanOrEqual':
        return config.includeBlanksInGreaterThan;
      case 'inRange':
        return config.includeBlanksInRange;
      default:
        return false;
    }
  }

  /// Parses a date string in 'YYYY-MM-DD' or 'YYYY-MM-DD hh:mm:ss' or
  /// 'YYYY-MM-DDThh:mm:ss' format to a [DateTime].
  ///
  /// Zone information is preserved: a trailing 'Z' (or explicit offset)
  /// yields a UTC-aware [DateTime]; without it, the result is local.
  static DateTime? _parseDateString(String? value) {
    if (value == null || value.isEmpty) return null;
    // Normalise space separator to T for DateTime.parse compatibility
    final normalised = value.contains('T')
        ? value
        : value.replaceFirst(' ', 'T');
    return DateTime.tryParse(normalised);
  }

  /// Parses a cell value to [DateTime].
  ///
  /// Handles: [DateTime], [String] (ISO format), null.
  ///
  /// Zone information is preserved: Z-suffixed strings parse as UTC (the
  /// date filter then compares their UTC calendar day); plain timestamps
  /// stay local. [DateTime] values pass through untouched — no conversion
  /// to local time is applied.
  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) {
      if (value.trim().isEmpty) return null;
      final normalised = value.contains('T')
          ? value
          : value.replaceFirst(' ', 'T');
      return DateTime.tryParse(normalised);
    }
    return null;
  }

  /// Default date comparator: returns sign(cellValue - filterDate).
  ///
  /// Compares date-only calendar days (year/month/day integers), ignoring
  /// time-of-day. Each side contributes the calendar day of its **own parsed
  /// zone** — Z-suffixed cells use their UTC calendar day, local timestamps
  /// and [DateTime] values use their local calendar day — with no timezone
  /// conversion applied to either side. Comparing integer parts (rather than
  /// reconstructed midnight DateTimes) keeps the result independent of
  /// DST-gap edge cases and of mixed UTC/local representations.
  static int _defaultDateComparator(DateTime filterDate, dynamic cellValue) {
    final cellDate = cellValue is DateTime
        ? cellValue
        : _parseDateTime(cellValue);
    if (cellDate == null) return -1;

    return _compareCalendarDays(cellDate, filterDate);
  }

  /// Compares two dates by calendar day only (year, then month, then day).
  ///
  /// The fields are read from each date in its own zone (`year`/`month`/
  /// `day` of a UTC date are its UTC calendar day; of a local date, its
  /// local calendar day). No new [DateTime] is constructed and no zone
  /// conversion happens.
  static int _compareCalendarDays(DateTime a, DateTime b) {
    if (a.year != b.year) return a.year.compareTo(b.year);
    if (a.month != b.month) return a.month.compareTo(b.month);
    return a.day.compareTo(b.day);
  }

  /// Returns the appropriate default comparator based on the `includeTime` setting.
  static int Function(DateTime, dynamic) _defaultDateComparatorFor(
    OsDateFilter config,
  ) {
    if (config.includeTime) {
      return _defaultDateTimeComparator;
    }
    return _defaultDateComparator;
  }

  /// Date comparator that includes the time component.
  ///
  /// Used when `OsDateFilter.includeTime` is `true`.
  static int _defaultDateTimeComparator(
    DateTime filterDate,
    dynamic cellValue,
  ) {
    final cellDate = cellValue is DateTime
        ? cellValue
        : _parseDateTime(cellValue);
    if (cellDate == null) return -1;
    return cellDate.compareTo(filterDate);
  }
}

/// Returns the default filter operation type string for a given filter config.
///
/// This maps the enum-based `defaultOption` on [OsTextFilter],
/// [OsNumberFilter], [OsBigIntFilter], and [OsDateFilter] to the
/// string-based operation type used in filter models.
String getDefaultFilterType(OsFilter filter) {
  if (filter is OsTextFilter) {
    return filter.defaultOption.name;
  }
  if (filter is OsNumberFilter) {
    return filter.defaultOption.name;
  }
  if (filter is OsBigIntFilter) {
    return filter.defaultOption.name;
  }
  if (filter is OsDateFilter) {
    return filter.defaultOption.name;
  }
  if (filter is OsSetFilter) {
    return 'set';
  }
  return 'contains';
}

/// Returns the list of available filter option type strings for a filter config.
///
/// If the filter has explicit `filterOptions`, those are returned.
/// Otherwise, returns all options for that filter type.
List<String> getAvailableFilterOptions(OsFilter filter) {
  if (filter is OsTextFilter) {
    if (filter.filterOptions != null) {
      return filter.filterOptions!.map((o) => o.name).toList();
    }
    return OsTextFilterOption.values.map((o) => o.name).toList();
  }
  if (filter is OsNumberFilter) {
    if (filter.filterOptions != null) {
      return filter.filterOptions!.map((o) => o.name).toList();
    }
    return OsNumberFilterOption.values.map((o) => o.name).toList();
  }
  if (filter is OsBigIntFilter) {
    if (filter.filterOptions != null) {
      return filter.filterOptions!.map((o) => o.name).toList();
    }
    return OsBigIntFilterOption.values.map((o) => o.name).toList();
  }
  if (filter is OsDateFilter) {
    if (filter.filterOptions != null) {
      return filter.filterOptions!.map((o) => o.name).toList();
    }
    return defaultDateFilterOptions.map((o) => o.name).toList();
  }
  if (filter is OsSetFilter) {
    return const <String>[];
  }
  return ['contains'];
}

/// Returns a short display label for a filter operation type.
///
/// Used in the floating filter to show the current operation as a compact
/// prefix (e.g., "=" for equals, "≠" for notEqual, ">" for greaterThan).
String getFilterOperationLabel(String type) {
  switch (type) {
    case 'contains':
      return '≈';
    case 'notContains':
      return '≉';
    case 'equals':
      return '=';
    case 'notEqual':
      return '≠';
    case 'startsWith':
      return 'A*';
    case 'endsWith':
      return '*A';
    case 'greaterThan':
      return '>';
    case 'greaterThanOrEqual':
      return '≥';
    case 'lessThan':
      return '<';
    case 'lessThanOrEqual':
      return '≤';
    case 'inRange':
      return '⇔';
    case 'blank':
      return '∅';
    case 'notBlank':
      return '∃';
    case 'set':
      return 'in';
    default:
      return '?';
  }
}

/// Returns a human-readable display name for a filter operation type.
///
/// Used in tooltips and accessibility labels.
/// For date filters, 'lessThan' is displayed as "Before" and
/// 'greaterThan' as "After".
String getFilterOperationDisplayName(String type, {OsFilter? filter}) {
  // Date-specific labels
  if (filter is OsDateFilter) {
    switch (type) {
      case 'lessThan':
        return 'Before';
      case 'lessThanOrEqual':
        return 'Before or on';
      case 'greaterThan':
        return 'After';
      case 'greaterThanOrEqual':
        return 'After or on';
    }
  }

  switch (type) {
    case 'contains':
      return 'Contains';
    case 'notContains':
      return 'Not contains';
    case 'equals':
      return 'Equals';
    case 'notEqual':
      return 'Not equal';
    case 'startsWith':
      return 'Starts with';
    case 'endsWith':
      return 'Ends with';
    case 'greaterThan':
      return 'Greater than';
    case 'greaterThanOrEqual':
      return 'Greater than or equal';
    case 'lessThan':
      return 'Less than';
    case 'lessThanOrEqual':
      return 'Less than or equal';
    case 'inRange':
      return 'In range';
    case 'blank':
      return 'Blank';
    case 'notBlank':
      return 'Not blank';
    default:
      return type;
  }
}

/// Returns the number of input values required for a filter operation.
///
/// Most operations need 1 input. 'inRange' needs 2. 'blank'/'notBlank' need 0.
int getNumberOfInputs(String type) {
  switch (type) {
    case 'blank':
    case 'notBlank':
      return 0;
    case 'inRange':
      return 2;
    default:
      return 1;
  }
}

/// Returns the maximum number of filter conditions for the given filter.
int getMaxConditionsForFilter(OsFilter filter) {
  if (filter is OsTextFilter) return filter.maxNumConditions;
  if (filter is OsNumberFilter) return filter.maxNumConditions;
  if (filter is OsBigIntFilter) return filter.maxNumConditions;
  if (filter is OsDateFilter) return filter.maxNumConditions;
  return 1;
}

/// Returns the configured debounce window (milliseconds) for a filter's
/// popup/floating inputs, or `null` when input should apply immediately
/// on every change.
int? getFilterDebounceMs(OsFilter filter) {
  if (filter is OsTextFilter) return filter.debounceMs;
  if (filter is OsNumberFilter) return filter.debounceMs;
  if (filter is OsBigIntFilter) return filter.debounceMs;
  if (filter is OsDateFilter) return filter.debounceMs;
  return null;
}

/// Returns the default join operator for the given filter.
OsJoinOperator getDefaultJoinOperatorForFilter(OsFilter filter) {
  if (filter is OsTextFilter) return filter.defaultJoinOperator;
  if (filter is OsNumberFilter) return filter.defaultJoinOperator;
  if (filter is OsBigIntFilter) return filter.defaultJoinOperator;
  if (filter is OsDateFilter) return filter.defaultJoinOperator;
  return OsJoinOperator.and;
}

/// Returns the filter type name string used in filter models.
String getFilterTypeName(OsFilter filter) {
  if (filter is OsNumberFilter) return 'number';
  if (filter is OsBigIntFilter) return 'bigint';
  if (filter is OsDateFilter) return 'date';
  if (filter is OsSetFilter) return 'set';
  return 'text';
}
