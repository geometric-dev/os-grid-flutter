/// Callback type for conditionally showing checkboxes per row.
///
/// Return `true` to show a checkbox for the row, `false` to hide it.
/// This is distinct from [OsRowSelection.isRowSelectable] — a row can be
/// selectable (via click) but not show a checkbox.
typedef CheckboxVisibleCallback = bool Function(dynamic data, int rowIndex);

/// Configuration for row selection behaviour.
///
/// Use the named constructors for common configurations:
/// ```dart
/// rowSelection: OsRowSelection.single()
/// rowSelection: OsRowSelection.multiple(checkboxes: true)
/// ```
///
/// ## Desktop modifier-key matrix (multiple mode)
///
/// Mirrors AG Grid's click-selection behaviour:
///
/// | Input             | Behaviour                                                        |
/// |-------------------|------------------------------------------------------------------|
/// | Plain click       | Clear others, select clicked row, move the range anchor          |
/// | Ctrl/Cmd+click    | Toggle clicked row, PRESERVE existing selection, move the anchor |
/// | Shift+click       | Replace selection with the anchor→clicked row range              |
/// | Ctrl/Cmd+Shift    | Extend the selection with the anchor→clicked row range           |
/// | +click            | (rows outside the range keep their state)                        |
///
/// The Shift+click anchor is the last non-shift clicked row. It is tracked
/// by stable row ID (`getRowId`), so it persists across sort and filter and
/// resolves to the anchor row's new display index on demand. It resets only
/// on explicit `deselectAll` or a page change.
///
/// In [OsRowSelectionMode.single] all modifier keys are ignored — every
/// click selects only the clicked row. With
/// [enableSelectionWithoutKeys] enabled, a plain click behaves like
/// Ctrl+click (toggle) instead of replacing the selection.
class OsRowSelection {
  const OsRowSelection._({
    required this.mode,
    this.checkboxes = false,
    this.checkboxesCallback,
    this.headerCheckbox = false,
    this.isRowSelectable,
    this.enableClickSelection = true,
    this.enableSelectionWithoutKeys = false,
    this.hideDisabledCheckboxes = false,
    this.selectAll = SelectAllMode.all,
  });

  /// Single row selection — clicking a row selects it and deselects others.
  factory OsRowSelection.single({
    bool Function(dynamic data)? isRowSelectable,
    bool enableClickSelection = true,
  }) {
    return OsRowSelection._(
      mode: OsRowSelectionMode.single,
      isRowSelectable: isRowSelectable,
      enableClickSelection: enableClickSelection,
    );
  }

  /// Multiple row selection — click to toggle, shift-click for range.
  factory OsRowSelection.multiple({
    bool checkboxes = false,
    CheckboxVisibleCallback? checkboxesCallback,
    bool headerCheckbox = false,
    bool Function(dynamic data)? isRowSelectable,
    bool enableClickSelection = true,
    bool enableSelectionWithoutKeys = false,
    bool hideDisabledCheckboxes = false,
    SelectAllMode selectAll = SelectAllMode.all,
  }) {
    return OsRowSelection._(
      mode: OsRowSelectionMode.multiple,
      checkboxes: checkboxes,
      checkboxesCallback: checkboxesCallback,
      headerCheckbox: headerCheckbox,
      isRowSelectable: isRowSelectable,
      enableClickSelection: enableClickSelection,
      enableSelectionWithoutKeys: enableSelectionWithoutKeys,
      hideDisabledCheckboxes: hideDisabledCheckboxes,
      selectAll: selectAll,
    );
  }

  /// The selection mode.
  final OsRowSelectionMode mode;

  /// Whether to show a checkbox column for selection.
  ///
  /// When `true`, all rows display a selection checkbox.
  /// For per-row control, use [checkboxesCallback] instead.
  final bool checkboxes;

  /// Optional callback to conditionally show checkboxes per row.
  ///
  /// When provided, this is evaluated for each row to determine whether
  /// a checkbox should be displayed. This is distinct from [isRowSelectable]:
  /// a row can be selectable (via click) but not show a checkbox.
  ///
  /// Takes precedence over the boolean [checkboxes] property when non-null.
  ///
  /// ```dart
  /// rowSelection: OsRowSelection.multiple(
  ///   checkboxesCallback: (data, rowIndex) => data['type'] != 'group',
  /// )
  /// ```
  final CheckboxVisibleCallback? checkboxesCallback;

  /// Whether to show a select-all checkbox in the header (only with [checkboxes]).
  final bool headerCheckbox;

  /// Optional callback to determine if a row is selectable.
  ///
  /// When provided, rows for which this returns false cannot be selected
  /// (via click, checkbox, or API). Their checkboxes are rendered as disabled
  /// (or hidden if [hideDisabledCheckboxes] is `true`).
  ///
  /// ```dart
  /// rowSelection: OsRowSelection.multiple(
  ///   isRowSelectable: (data) => data['status'] != 'archived',
  /// )
  /// ```
  final bool Function(dynamic data)? isRowSelectable;

  /// Whether clicking a row selects it.
  ///
  /// When false, selection is only possible via checkboxes or the API.
  /// Defaults to true.
  final bool enableClickSelection;

  /// Whether clicking a row toggles its selection without requiring Ctrl/Cmd.
  ///
  /// When `true` in [OsRowSelectionMode.multiple], each click toggles the
  /// row's selection state independently — no modifier key needed.
  /// When `false` (default), clicking a row without Ctrl replaces the
  /// current selection (standard multi-select behaviour).
  ///
  /// Has no effect in [OsRowSelectionMode.single] mode.
  /// Defaults to `false`.
  final bool enableSelectionWithoutKeys;

  /// Whether to hide checkboxes for rows where [isRowSelectable] returns false.
  ///
  /// When `true`, non-selectable rows show no checkbox at all (the cell is
  /// empty). When `false` (default), non-selectable rows show a greyed-out
  /// disabled checkbox.
  ///
  /// Only has an effect when [isRowSelectable] is provided and checkboxes
  /// are enabled.
  /// Defaults to `false`.
  final bool hideDisabledCheckboxes;

  /// Controls which rows are affected by `selectAll()` and the header checkbox.
  ///
  /// Only applies to [OsRowSelectionMode.multiple].
  /// - [SelectAllMode.all] — selects all rows regardless of filter/pagination.
  /// - [SelectAllMode.filtered] — selects only rows passing the current filter.
  /// - [SelectAllMode.currentPage] — selects only rows on the current page.
  ///
  /// Defaults to [SelectAllMode.all].
  final SelectAllMode selectAll;

  /// Whether checkboxes should be shown for a given row.
  ///
  /// Evaluates [checkboxesCallback] if provided, otherwise returns [checkboxes].
  bool shouldShowCheckbox(dynamic data, int rowIndex) {
    if (checkboxesCallback != null) {
      return checkboxesCallback!(data, rowIndex);
    }
    return checkboxes;
  }

  /// Whether any form of checkbox display is enabled.
  bool get hasCheckboxes => checkboxes || checkboxesCallback != null;
}

/// The row selection mode.
enum OsRowSelectionMode {
  /// Only one row can be selected at a time.
  single,

  /// Multiple rows can be selected simultaneously.
  multiple,
}

/// Controls the scope of select-all operations.
enum SelectAllMode {
  /// Select all rows in the dataset (ignoring filter/pagination).
  all,

  /// Select only rows that pass the current filter.
  filtered,

  /// Select only rows visible on the current page.
  currentPage,
}
