import 'os_cell_editor.dart';

/// A date input cell editor.
///
/// When activated, displays Flutter's native date picker (calendar) below
/// the cell. The user selects a date from the calendar and the value is
/// committed as a [DateTime] object.
///
/// Set [useNativePicker] to `false` to fall back to a text input where
/// the user types a date string in ISO format (`yyyy-MM-dd`).
///
/// The cell value should be a [DateTime] object. For string-based date
/// values, use `OsDateStringCellEditor` instead.
///
/// Mirrors OS Grid's `OsDateCellEditor` with `IDateCellEditorParams`.
///
/// ```dart
/// OsColumnDef(
///   field: 'startDate',
///   editable: true,
///   cellEditor: OsDateCellEditor(
///     min: DateTime(2020, 1, 1),
///     max: DateTime(2030, 12, 31),
///   ),
/// )
/// ```
class OsDateCellEditor extends OsCellEditor {
  const OsDateCellEditor({
    this.min,
    this.max,
    this.step,
    this.includeTime = false,
    this.useNativePicker = true,
  });

  /// Minimum allowed date (inclusive).
  ///
  /// Can be a [DateTime] object or a [String] in `yyyy-MM-dd` format.
  final Object? min;

  /// Maximum allowed date (inclusive).
  ///
  /// Can be a [DateTime] object or a [String] in `yyyy-MM-dd` format.
  final Object? max;

  /// Step in days between valid values, starting from [min] or the
  /// initial value.
  ///
  /// When set, the committed date must be a whole number of [step]
  /// days from the reference date. If not, the edit is rejected.
  final int? step;

  /// Whether to include time when editing dates.
  ///
  /// When `true`, the editor displays and accepts `yyyy-MM-ddTHH:mm:ss`.
  /// When `false` (default), only the date portion (`yyyy-MM-dd`) is used.
  ///
  /// When [useNativePicker] is `true` and [includeTime] is `true`, a time
  /// picker is shown after the date is selected.
  final bool includeTime;

  /// Whether to use Flutter's native date picker (calendar UI).
  ///
  /// When `true` (default), a calendar picker is shown below the cell.
  /// When `false`, a text input is shown where the user types the date
  /// in ISO format.
  final bool useNativePicker;

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Resolves [min] to a [DateTime], parsing strings as needed.
  DateTime? get minDate => resolve(min);

  /// Resolves [max] to a [DateTime], parsing strings as needed.
  DateTime? get maxDate => resolve(max);

  /// Resolves a value to a [DateTime].
  ///
  /// Accepts [DateTime] objects directly, or parses [String] values
  /// using `DateTime.tryParse`. Returns `null` for other types or
  /// unparseable strings.
  static DateTime? resolve(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  /// Serialises a [DateTime] to the appropriate string format.
  ///
  /// Returns `yyyy-MM-dd` when [includeTime] is `false`, or
  /// `yyyy-MM-ddTHH:mm:ss` when `true`.
  String serialiseDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    if (!includeTime) return '$y-$m-$d';
    final hh = date.hour.toString().padLeft(2, '0');
    final mm = date.minute.toString().padLeft(2, '0');
    final ss = date.second.toString().padLeft(2, '0');
    return '$y-$m-${d}T$hh:$mm:$ss';
  }

  /// Parses a date string in `yyyy-MM-dd` or `yyyy-MM-ddTHH:mm:ss` format.
  ///
  /// Returns `null` if the string cannot be parsed.
  static DateTime? parseDate(String? text) {
    if (text == null || text.isEmpty) return null;
    // Normalise space separator to T for DateTime.parse compatibility
    final normalised = text.contains(' ') ? text.replaceFirst(' ', 'T') : text;
    return DateTime.tryParse(normalised);
  }

  /// Validates [date] against [min], [max], and [step] constraints.
  ///
  /// Returns a list of validation error messages, or `null` if valid.
  List<String>? validate(DateTime date) {
    final errors = <String>[];

    final minD = minDate;
    if (minD != null) {
      final minCompare = includeTime
          ? date.compareTo(minD)
          : _dateOnly(date).compareTo(_dateOnly(minD));
      if (minCompare < 0) {
        errors.add('Date must be on or after ${serialiseDate(minD)}');
      }
    }

    final maxD = maxDate;
    if (maxD != null) {
      final maxCompare = includeTime
          ? date.compareTo(maxD)
          : _dateOnly(date).compareTo(_dateOnly(maxD));
      if (maxCompare > 0) {
        errors.add('Date must be on or before ${serialiseDate(maxD)}');
      }
    }

    if (step != null && step! > 0) {
      final reference = minD ?? date;
      final diff = _dateOnly(date).difference(_dateOnly(reference)).inDays;
      if (diff % step! != 0) {
        errors.add(
          'Date must be a multiple of $step days from ${serialiseDate(reference)}',
        );
      }
    }

    return errors.isEmpty ? null : errors;
  }

  static DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
}
