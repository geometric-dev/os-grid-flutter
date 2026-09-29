import 'os_cell_editor.dart';
import 'os_date_cell_editor.dart';

/// A date input cell editor for string-based date values.
///
/// Similar to [OsDateCellEditor] but works with cell values that are
/// stored as strings (e.g. `'2024-03-15'`) rather than [DateTime] objects.
///
/// When the user selects a date, the value is committed as a formatted
/// string. The [dateParser] and [dateFormatter] callbacks allow custom
/// string↔DateTime conversion for non-ISO formats.
///
/// Mirrors OS Grid's `OsDateStringCellEditor` with `IDateStringCellEditorParams`.
///
/// ```dart
/// OsColumnDef(
///   field: 'birthDate',
///   editable: true,
///   cellEditor: OsDateStringCellEditor(
///     min: '1900-01-01',
///     max: '2024-12-31',
///   ),
/// )
/// ```
class OsDateStringCellEditor extends OsCellEditor {
  const OsDateStringCellEditor({
    this.min,
    this.max,
    this.step,
    this.includeTime = false,
    this.useNativePicker = true,
    this.dateParser,
    this.dateFormatter,
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

  /// Custom parser to convert a string cell value to a [DateTime].
  ///
  /// When `null`, the default ISO 8601 parser is used (`DateTime.tryParse`).
  ///
  /// ```dart
  /// OsDateStringCellEditor(
  ///   dateParser: (value) {
  ///     // Parse 'dd/MM/yyyy' format
  ///     final parts = value.split('/');
  ///     return DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
  ///   },
  /// )
  /// ```
  final DateTime? Function(String value)? dateParser;

  /// Custom formatter to convert a [DateTime] back to a string for storage.
  ///
  /// When `null`, the default ISO format is used (`yyyy-MM-dd` or
  /// `yyyy-MM-ddTHH:mm:ss` depending on [includeTime]).
  ///
  /// ```dart
  /// OsDateStringCellEditor(
  ///   dateFormatter: (date) =>
  ///       '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}',
  /// )
  /// ```
  final String Function(DateTime date)? dateFormatter;

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Resolves [min] to a [DateTime], parsing strings as needed.
  DateTime? get minDate => OsDateCellEditor.resolve(min);

  /// Resolves [max] to a [DateTime], parsing strings as needed.
  DateTime? get maxDate => OsDateCellEditor.resolve(max);

  /// Parses a string cell value to a [DateTime] using [dateParser] or
  /// the default ISO parser.
  DateTime? parseCellValue(String? value) {
    if (value == null || value.isEmpty) return null;
    if (dateParser != null) return dateParser!(value);
    return OsDateCellEditor.parseDate(value);
  }

  /// Formats a [DateTime] to a string using [dateFormatter] or the
  /// default ISO format.
  String formatDate(DateTime date) {
    if (dateFormatter != null) return dateFormatter!(date);
    return _defaultSerialise(date);
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
        errors.add('Date must be on or after ${_defaultSerialise(minD)}');
      }
    }

    final maxD = maxDate;
    if (maxD != null) {
      final maxCompare = includeTime
          ? date.compareTo(maxD)
          : _dateOnly(date).compareTo(_dateOnly(maxD));
      if (maxCompare > 0) {
        errors.add('Date must be on or before ${_defaultSerialise(maxD)}');
      }
    }

    if (step != null && step! > 0) {
      final reference = minD ?? date;
      final diff = _dateOnly(date).difference(_dateOnly(reference)).inDays;
      if (diff % step! != 0) {
        errors.add(
          'Date must be a multiple of $step days from ${_defaultSerialise(reference)}',
        );
      }
    }

    return errors.isEmpty ? null : errors;
  }

  String _defaultSerialise(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    if (!includeTime) return '$y-$m-$d';
    final hh = date.hour.toString().padLeft(2, '0');
    final mm = date.minute.toString().padLeft(2, '0');
    final ss = date.second.toString().padLeft(2, '0');
    return '$y-$m-${d}T$hh:$mm:$ss';
  }

  static DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
}
