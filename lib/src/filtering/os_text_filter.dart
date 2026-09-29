import 'filter_model.dart';
import 'os_filter.dart';

/// Formats a raw filter input value before it is compared against cells.
///
/// Mirrors AG Grid's `textFormatter`: use it to normalise the user's input
/// (e.g. strip accents, lowercase). Returning `null` is treated as an empty
/// filter (no filtering).
typedef OsTextFormatter = String? Function(String? input);

/// Custom predicate deciding whether a cell passes a text filter condition.
///
/// When provided and it returns a non-null verdict, the built-in
/// contains/equals/startsWith/... logic is bypassed entirely for that
/// condition. Returning `null` falls back to the built-in behaviour.
///
/// [filterValue] is the filter input after [OsTextFilter.textFormatter] has
/// been applied; [cellValue] is the cell's string representation;
/// [filterOption] is the operation type string (e.g. 'contains', 'equals').
typedef OsTextMatcher =
    bool? Function({
      String? filterValue,
      String? cellValue,
      String filterOption,
    });

/// Filter configuration for text/string columns.
///
/// Mirrors OS Grid's `TextFilter` with support for multiple conditions,
/// configurable operations, and case sensitivity.
///
/// ```dart
/// OsColumnDef(
///   field: 'name',
///   filter: OsTextFilter(
///     filterOptions: [OsTextFilterOption.contains, OsTextFilterOption.startsWith],
///     defaultOption: OsTextFilterOption.contains,
///     maxNumConditions: 2,
///   ),
/// )
/// ```
class OsTextFilter extends OsFilter {
  const OsTextFilter({
    this.filterOptions,
    this.defaultOption = OsTextFilterOption.contains,
    this.caseSensitive = false,
    this.trimInput = false,
    this.maxNumConditions = 2,
    this.defaultJoinOperator = OsJoinOperator.and,
    this.textFormatter,
    this.textMatcher,
    this.debounceMs,
  });

  /// Available filter operations. If null, all options are available.
  final List<OsTextFilterOption>? filterOptions;

  /// The default filter operation.
  final OsTextFilterOption defaultOption;

  /// Whether filtering is case-sensitive.
  final bool caseSensitive;

  /// Whether to trim whitespace from filter input.
  final bool trimInput;

  /// Maximum number of conditions allowed in the filter.
  ///
  /// Defaults to 2, matching OS Grid's default. Set to 1 to disable
  /// combined conditions.
  final int maxNumConditions;

  /// The default join operator when combining multiple conditions.
  ///
  /// Defaults to [OsJoinOperator.and].
  final OsJoinOperator defaultJoinOperator;

  /// Formats the filter value before comparison (AG Grid `textFormatter`).
  ///
  /// Applied only to the filter input, not to cell values. Typical use:
  /// removing accents or normalising punctuation so 'Cafe' matches 'Café'
  /// cells via the case-insensitive built-ins.
  ///
  /// Returning `null` is treated as an empty filter (no filtering).
  final OsTextFormatter? textFormatter;

  /// Custom predicate overriding the built-in text operations.
  ///
  /// When it returns a non-null verdict for a condition, that verdict is used
  /// and the built-in contains/equals/startsWith/endsWith/notContains/
  /// notEqual logic is skipped. Return `null` to fall back to the built-ins.
  /// `blank`/`notBlank` conditions never consult the matcher.
  final OsTextMatcher? textMatcher;

  /// Debounce window (milliseconds) for filter input before it is applied.
  ///
  /// When `null` (default), input applies immediately on every change.
  /// When set, rapid keystrokes are coalesced and the filter applies once
  /// after this many milliseconds of quiet.
  final int? debounceMs;
}

/// Available text filter operations.
enum OsTextFilterOption {
  contains,
  notContains,
  equals,
  notEqual,
  startsWith,
  endsWith,
  blank,
  notBlank,
}
