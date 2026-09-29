import 'os_select_cell_editor.dart';

/// Parameters supplied to [OsRichSelectCellEditor.valuesProvider] when the
/// editor resolves its option list at edit time.
class OsRichSelectValuesParams<TData> {
  /// Creates params describing the cell being edited.
  const OsRichSelectValuesParams({
    required this.value,
    this.data,
    this.rowIndex = 0,
    this.column = '',
  });

  /// The current value of the cell being edited.
  final dynamic value;

  /// The row data of the cell being edited.
  final TData? data;

  /// The index of the row being edited.
  final int rowIndex;

  /// The field (or column ID) of the column being edited.
  final String column;
}

/// A searchable dropdown cell editor mirroring AG Grid's
/// `agRichSelectCellEditor`.
///
/// Renders a popup below the cell with a search input above the value list.
/// Typing filters the list case-insensitively (debounced by [debounceMs]),
/// ArrowUp/ArrowDown navigate the filtered list, Enter selects and commits,
/// Escape cancels, and Tab commits — matching [OsSelectCellEditor]'s
/// keyboard contract.
///
/// Because this editor extends [OsSelectCellEditor], it flows through the
/// grid's existing select-editor dispatch; users opt in per column:
///
/// ```dart
/// OsColumnDef(
///   field: 'country',
///   editable: true,
///   cellEditor: OsRichSelectCellEditor(values: ['UK', 'US', 'DE']),
/// )
/// ```
class OsRichSelectCellEditor extends OsSelectCellEditor {
  /// Creates a rich select editor. Supply either [values] or
  /// [valuesProvider]; the provider wins when both are given.
  const OsRichSelectCellEditor({
    super.values,
    this.valuesProvider,
    this.allowTyping = true,
    this.searchPlaceholder = 'Search...',
    this.debounceMs = 200,
    super.valueListGap,
    super.valueListMaxHeight,
    super.valueListMaxWidth,
    this.valueFormatter,
  });

  /// Callback producing the option list when editing starts. Receives
  /// [OsRichSelectValuesParams] for the cell being edited.
  final List<dynamic> Function(OsRichSelectValuesParams<dynamic> params)?
  valuesProvider;

  /// Whether the search input is shown and typing filters the list.
  ///
  /// Defaults to true. When false the editor behaves like a plain select
  /// dropdown with keyboard navigation only.
  final bool allowTyping;

  /// Placeholder text for the search input. Defaults to `'Search...'`.
  final String searchPlaceholder;

  /// Debounce applied to the filter input before the list re-filters.
  /// Defaults to 200ms. Use 0 to filter immediately on each keystroke.
  final int debounceMs;

  /// Optional formatter applied to each option value for display in the
  /// list. Falls back to `value.toString()` when omitted.
  final String Function(dynamic value)? valueFormatter;
}
