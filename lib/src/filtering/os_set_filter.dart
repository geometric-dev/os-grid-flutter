import 'package:flutter/foundation.dart';

import 'os_filter.dart';

/// Filter configuration for set-style (checklist) filtering.
///
/// Mirrors AG Grid Community's `agSetColumnFilter`: the popup shows a
/// searchable checklist of unique values and rows pass when their value's
/// string key is among the selected keys.
///
/// ```dart
/// OsColumnDef(
///   field: 'country',
///   headerName: 'Country',
///   filter: OsSetFilter(),
/// )
/// ```
///
/// The checklist values are derived lazily from the column's resolved cell
/// values when the popup opens, unless a fixed supply is provided via
/// [values]. The checklist is rendered through a virtualised list, so large
/// datasets (10k+ unique values) scroll without jank.
class OsSetFilter extends OsFilter {
  const OsSetFilter({
    this.values,
    this.defaultToAllSelected = true,
    this.caseSensitive = false,
    this.debounceMs,
  });

  /// Fixed supply of candidate values.
  ///
  /// When provided, the checklist shows exactly these values instead of
  /// deriving them from the grid data. Keys are compared using each value's
  /// `toString()` representation.
  final List<Object?>? values;

  /// Whether every checklist entry starts selected when no filter model
  /// exists yet.
  ///
  /// Defaults to `true`, matching AG Grid. When `false`, the checklist
  /// starts empty (applying immediately would exclude all rows).
  final bool defaultToAllSelected;

  /// Whether the checklist and its search box treat values case-sensitively.
  ///
  /// Defaults to `false`, matching AG Grid's Set Filter: cell values that
  /// differ only by case (`Black`, `black`, `BLACK`) are treated as
  /// identical for matching purposes and share one checklist entry — the
  /// first-encountered casing is displayed. The search box matches
  /// case-insensitively and programmatic filter models are matched onto the
  /// checklist case-insensitively too.
  ///
  /// When `true`, key derivation keeps case variants as distinct entries,
  /// the search box matches exactly, and evaluation compares keys exactly.
  final bool caseSensitive;

  /// Debounce window (milliseconds) for the checklist search box.
  ///
  /// Defaults to a fixed 150ms quiet period; pass an explicit value to
  /// override it.
  final int? debounceMs;
}

/// Computes the string key used to compare a cell value against the set
/// filter model.
///
/// Null values and empty strings share the blank key (`''`), matching AG
/// Grid's blanks-as-entries behaviour: blanks appear in the checklist as a
/// single "(Blanks)" entry and only pass the filter when that entry is
/// selected.
String osSetFilterValueKey(Object? value) {
  if (value == null) return '';
  if (value is String && value.isEmpty) return '';
  return value.toString();
}

/// Case-insensitive ordering approximating JavaScript's `localeCompare`
/// for checklist display. Ties fall back to a case-sensitive comparison so
/// entries differing only by case keep a stable order.
int compareSetFilterKeys(String a, String b) {
  final lowerA = a.toLowerCase();
  final lowerB = b.toLowerCase();
  final result = lowerA.compareTo(lowerB);
  if (result != 0) return result;
  return a.compareTo(b);
}

/// Derives the unique, sorted checklist keys from resolved cell values.
///
/// Blank values collapse onto the shared `''` key. When [caseSensitive] is
/// false (the default, matching AG Grid), values differing only by case are
/// treated as identical for matching purposes: a single checklist entry is
/// emitted, displaying the first-encountered casing. When true, every
/// case variant becomes its own entry.
///
/// The list is capped at [maxUniqueValues] entries; exceeding it emits a
/// `debugPrint` warning and truncates, protecting the popup from
/// pathological datasets.
List<String> deriveSetFilterKeys(
  Iterable<Object?> cellValues, {
  int maxUniqueValues = 5000,
  bool caseSensitive = false,
}) {
  final keys = <String>{};
  // Folded forms already seen — only tracked when case folding is active.
  final folded = caseSensitive ? null : <String>{};
  for (final value in cellValues) {
    final key = osSetFilterValueKey(value);
    if (folded == null || folded.add(key.toLowerCase())) {
      keys.add(key);
    }
    if (keys.length > maxUniqueValues) {
      debugPrint(
        '[OS Grid] Set filter: unique value count exceeded '
        '$maxUniqueValues; truncating the checklist.',
      );
      break;
    }
  }
  final sorted = keys.toList()..sort(compareSetFilterKeys);
  return sorted;
}
