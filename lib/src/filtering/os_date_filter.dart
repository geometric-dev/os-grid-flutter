import 'filter_model.dart';
import 'os_filter.dart';

/// Filter configuration for date columns.
///
/// Mirrors OS Grid's `DateFilter` with support for multiple conditions,
/// configurable operations, and range filtering.
///
/// Cell values can be [DateTime] objects or ISO date strings ('YYYY-MM-DD').
///
/// ```dart
/// OsColumnDef(
///   field: 'dateOfBirth',
///   filter: OsDateFilter(),
/// )
/// ```
class OsDateFilter extends OsFilter {
  const OsDateFilter({
    this.filterOptions,
    this.defaultOption = OsDateFilterOption.equals,
    this.maxNumConditions = 2,
    this.defaultJoinOperator = OsJoinOperator.and,
    this.inRangeInclusive = false,
    this.includeBlanksInEquals = false,
    this.includeBlanksInNotEqual = false,
    this.includeBlanksInLessThan = false,
    this.includeBlanksInGreaterThan = false,
    this.includeBlanksInRange = false,
    this.comparator,
    this.minValidDate,
    this.maxValidDate,
    this.minValidYear = 1000,
    this.maxValidYear,
    this.includeTime = false,
    this.debounceMs,
  });

  /// Available filter operations. If null, defaults are used:
  /// equals, notEqual, lessThan (Before), greaterThan (After), inRange, blank, notBlank.
  final List<OsDateFilterOption>? filterOptions;

  /// The default filter operation.
  final OsDateFilterOption defaultOption;

  /// Maximum number of conditions allowed in the filter.
  ///
  /// Defaults to 2, matching OS Grid's default. Set to 1 to disable
  /// combined conditions.
  final int maxNumConditions;

  /// The default join operator when combining multiple conditions.
  ///
  /// Defaults to [OsJoinOperator.and].
  final OsJoinOperator defaultJoinOperator;

  /// Whether the 'inRange' operation is inclusive of the boundary values.
  ///
  /// When `true`, the range check is `value >= from && value <= to`.
  /// When `false` (default), it is `value > from && value < to`.
  /// OS Grid's TypeScript default is exclusive (false).
  final bool inRangeInclusive;

  /// Whether blank/null values pass the 'equals' operation.
  final bool includeBlanksInEquals;

  /// Whether blank/null values pass the 'notEqual' operation.
  final bool includeBlanksInNotEqual;

  /// Whether blank/null values pass 'lessThan'/'lessThanOrEqual' operations.
  final bool includeBlanksInLessThan;

  /// Whether blank/null values pass 'greaterThan'/'greaterThanOrEqual' operations.
  final bool includeBlanksInGreaterThan;

  /// Whether blank/null values pass the 'inRange' operation.
  final bool includeBlanksInRange;

  /// Custom comparator for comparing dates.
  ///
  /// Receives the filter date and the cell value. Should return:
  /// - negative if cellValue < filterDate
  /// - 0 if equal
  /// - positive if cellValue > filterDate
  ///
  /// If null, the default comparator uses [DateTime.compareTo].
  final int Function(DateTime filterDate, dynamic cellValue)? comparator;

  /// Minimum selectable date in the filter.
  final DateTime? minValidDate;

  /// Maximum selectable date in the filter.
  final DateTime? maxValidDate;

  /// Minimum valid year (used when [minValidDate] is not set).
  final int minValidYear;

  /// Maximum valid year (used when [maxValidDate] is not set).
  final int? maxValidYear;

  /// Whether to include the time component in date comparisons.
  ///
  /// When `false` (default), only the date part (year, month, day) is compared.
  /// When `true`, the full date-time is compared including hours, minutes, seconds.
  final bool includeTime;

  /// Debounce window (milliseconds) for filter input before it is applied.
  ///
  /// When `null` (default), input applies immediately on every change.
  /// When set, rapid keystrokes are coalesced and the filter applies once
  /// after this many milliseconds of quiet.
  final int? debounceMs;
}

/// Available date filter operations.
enum OsDateFilterOption {
  /// Date equals the filter value (date-only comparison by default).
  equals,

  /// Date does not equal the filter value.
  notEqual,

  /// Date is before the filter value.
  lessThan,

  /// Date is on or before the filter value.
  lessThanOrEqual,

  /// Date is after the filter value.
  greaterThan,

  /// Date is on or after the filter value.
  greaterThanOrEqual,

  /// Date is within the range [dateFrom, dateTo].
  inRange,

  /// Cell value is blank/null.
  blank,

  /// Cell value is not blank/null.
  notBlank,
}

/// Default date filter options (matches OS Grid TypeScript defaults).
const List<OsDateFilterOption> defaultDateFilterOptions = [
  OsDateFilterOption.equals,
  OsDateFilterOption.notEqual,
  OsDateFilterOption.lessThan,
  OsDateFilterOption.greaterThan,
  OsDateFilterOption.inRange,
  OsDateFilterOption.blank,
  OsDateFilterOption.notBlank,
];
