import 'filter_model.dart';
import 'os_filter.dart';

/// Filter configuration for numeric columns.
///
/// Mirrors OS Grid's `NumberFilter` with support for multiple conditions,
/// configurable operations, and range filtering.
///
/// ```dart
/// OsColumnDef(
///   field: 'age',
///   filter: OsNumberFilter(
///     filterOptions: [OsNumberFilterOption.greaterThan, OsNumberFilterOption.lessThan],
///     maxNumConditions: 2,
///   ),
/// )
/// ```
class OsNumberFilter extends OsFilter {
  const OsNumberFilter({
    this.filterOptions,
    this.defaultOption = OsNumberFilterOption.equals,
    this.allowedCharPattern,
    this.maxNumConditions = 2,
    this.defaultJoinOperator = OsJoinOperator.and,
    this.inRangeInclusive = false,
    this.includeBlanksInEquals = false,
    this.includeBlanksInNotEqual = false,
    this.includeBlanksInLessThan = false,
    this.includeBlanksInGreaterThan = false,
    this.includeBlanksInRange = false,
    this.debounceMs,
  });

  /// Available filter operations. If null, all options are available.
  final List<OsNumberFilterOption>? filterOptions;

  /// The default filter operation.
  final OsNumberFilterOption defaultOption;

  /// Regex pattern for allowed characters in the filter input.
  final String? allowedCharPattern;

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

  /// Whether blank/null values pass 'greaterThan'/'greaterThanOrEqual'
  /// operations.
  final bool includeBlanksInGreaterThan;

  /// Whether blank/null values pass the 'inRange' operation.
  final bool includeBlanksInRange;

  /// Debounce window (milliseconds) for filter input before it is applied.
  ///
  /// When `null` (default), input applies immediately on every change.
  /// When set, rapid keystrokes are coalesced and the filter applies once
  /// after this many milliseconds of quiet.
  final int? debounceMs;
}

/// Available number filter operations.
enum OsNumberFilterOption {
  equals,
  notEqual,
  greaterThan,
  greaterThanOrEqual,
  lessThan,
  lessThanOrEqual,
  inRange,
  blank,
  notBlank,
}
