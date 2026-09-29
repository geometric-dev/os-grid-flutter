import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../columns/os_column_def.dart';
import '../events/cell_events.dart';
import '../events/editing_events.dart';
import '../locale/os_locale_text.dart';
import '../os_grid_controller.dart';
import '../params/navigation_params.dart';
import '../params/value_parser_params.dart';
import '../params/value_setter_params.dart';
import '../rendering/column_group_layout.dart';
import '../rendering/grid_hit_test.dart';
import '../rendering/special_columns.dart';
import '../rendering/text_painter_cache.dart';
import '../selection/os_row_selection.dart';
import '../theming/os_grid_theme.dart';
import 'os_checkbox_cell_editor.dart';
import 'os_custom_cell_editor.dart';
import 'os_date_cell_editor.dart';
import 'os_date_string_cell_editor.dart';
import 'os_large_text_cell_editor.dart';
import 'os_rich_select_cell_editor.dart';
import 'os_select_cell_editor.dart';
import 'overlays/custom_editor_overlay.dart';
import 'overlays/date_editor_overlay.dart';
import 'overlays/large_text_editor_overlay.dart';
import 'overlays/select_editor_overlay.dart';
import 'undo_redo_service.dart';

/// Type-aware equality for edit change detection.
///
/// Determines whether a committed edit value differs from the original cell
/// value without relying on string forms:
///
/// - identical instances are equal;
/// - `==` equality short-circuits (covers strings, bools, equal nums);
/// - two [num]s compare numerically, so `int`/`double` representations of
///   the same value (`1` vs `1.0`) are considered unchanged;
/// - two [DateTime]s compare with [DateTime.isAtSameMomentAs], so the same
///   instant in different zone representations is unchanged;
/// - anything else falls back to `toString()` comparison.
bool editValuesEqual(dynamic a, dynamic b) {
  if (identical(a, b)) return true;
  if (a == b) return true;
  if (a is num && b is num) {
    // `num ==` already compares numerically across int/double; this branch
    // keeps NaN unequal to itself (a genuine change) instead of letting the
    // toString fallback treat 'NaN' == 'NaN' as unchanged.
    return a == b;
  }
  if (a is DateTime && b is DateTime) {
    return a.isAtSameMomentAs(b);
  }
  return a?.toString() == b?.toString();
}

/// Owns the cell-editing session lifecycle for the grid.
///
/// Extracted from `_OsGridState`. The coordinator owns the active edit
/// session state (rect, row/col indices, original value, editor kind) plus
/// the typed editors (text, select, date, date-string, custom, large text)
/// and the checkbox toggle path.
///
/// All grid-owned collaborators are supplied as closures/getters so they
/// always read live state from the owning `State`.
class EditingCoordinator<TData> {
  /// Creates a coordinator.
  ///
  /// [mutate] wraps the owning State's `setState`. [resolveRows] supplies the
  /// effective data rows. The `onXxx` getters supply the current widget
  /// callbacks so `didUpdateWidget` replacements are honoured.
  EditingCoordinator({
    required OsGridController<TData> controller,
    required UndoRedoService? Function() undoRedoService,
    required List<TData>? Function() resolveRows,
    required List<OsColumnDef> Function() flatColumnsCache,
    required void Function(VoidCallback) mutate,
    required bool Function() mounted,
    required bool Function() suppressClickEdit,
    required bool Function() enableCellEditingOnBackspace,
    required bool Function() readOnlyEdit,
    required bool Function() enterNavigatesVerticallyAfterEdit,
    required bool Function() stopEditingWhenCellsLoseFocus,
    required OsRowSelection? Function() rowSelection,
    required bool Function() rowNumbers,
    required bool Function() rowDrag,
    required bool Function() floatingFilter,
    required double Function() floatingFilterHeight,
    required OsGridTheme? Function() theme,
    required OsLocaleText? Function() localeText,
    required List<OsColumnDefBase> Function() columnDefs,
    required Set<String> Function() hiddenIds,
    required List<String>? Function() order,
    required Map<String, double> Function() widths,
    required double Function() effectiveHeaderHeight,
    required double Function() effectiveRowHeight,
    required TextPainterCache textPainterCache,
    required void Function(
      List<OsColumnDefBase> defs,
      List<OsColumnDef> outColumns,
      List<ColumnGroupSpan> outSpans,
    )
    flattenColumnDefs,
    required bool Function(OsColumnDef col, TData rowData, int rowIndex)
    isCellEditable,
    required void Function(int rowIndex, OsColumnDef col, TData rowData)
    clearCellValue,
    required void Function(OsCellEditingStartedEvent<TData>)?
    onCellEditingStarted,
    required void Function(OsCellEditingStoppedEvent<TData>)?
    onCellEditingStopped,
    required void Function(OsCellValueChangedEvent<TData>)? onCellValueChanged,
    required void Function(OsCellEditRequestEvent<TData>)? onCellEditRequest,
    required BuildContext Function() context,
    NavCellPosition? Function(TabToNextCellParams params)? tabToNextCell,
  }) : _controller = controller,
       _undoRedoService = undoRedoService,
       _resolveRows = resolveRows,
       _flatColumnsCache = flatColumnsCache,
       _mutate = mutate,
       _mounted = mounted,
       _suppressClickEdit = suppressClickEdit,
       _enableCellEditingOnBackspace = enableCellEditingOnBackspace,
       _readOnlyEdit = readOnlyEdit,
       _enterNavigatesVerticallyAfterEdit = enterNavigatesVerticallyAfterEdit,
       _stopEditingWhenCellsLoseFocus = stopEditingWhenCellsLoseFocus,
       _rowSelection = rowSelection,
       _rowNumbers = rowNumbers,
       _rowDrag = rowDrag,
       _floatingFilter = floatingFilter,
       _floatingFilterHeight = floatingFilterHeight,
       _theme = theme,
       _localeText = localeText,
       _columnDefs = columnDefs,
       _hiddenColumnIds = hiddenIds,
       _columnOrder = order,
       _columnWidths = widths,
       _effectiveHeaderHeight = effectiveHeaderHeight,
       _effectiveRowHeight = effectiveRowHeight,
       _textPainterCache = textPainterCache,
       _flattenColumnDefs = flattenColumnDefs,
       _isCellEditableFn = isCellEditable,
       _clearCellValueFn = clearCellValue,
       _onCellEditingStarted = onCellEditingStarted,
       _onCellEditingStopped = onCellEditingStopped,
       _onCellValueChanged = onCellValueChanged,
       _onCellEditRequest = onCellEditRequest,
       _context = context,
       _tabToNextCell = tabToNextCell {
    _editFocusNode.addListener(_onEditFocusChanged);
    _richSearchFocusNode.onKeyEvent = _handleRichSelectFieldKeyEvent;
  }

  /// The live controller. Mutable only for runtime controller swaps —
  /// see [rebind].
  OsGridController<TData> _controller;

  /// Re-points the coordinator at [controller] after a runtime controller
  /// swap. Editing request hooks are wired by the owning state (which
  /// re-binds them itself via `_wireEditingApiCallbacks`), and the
  /// coordinator only emits events and queries state on the controller —
  /// so reassigning the reference is sufficient. Any active edit session
  /// keeps editing the same row data either way.
  void rebind(OsGridController<TData> controller) {
    _controller = controller;
  }

  final UndoRedoService? Function() _undoRedoService;
  final List<TData>? Function() _resolveRows;
  final List<OsColumnDef> Function() _flatColumnsCache;
  final void Function(VoidCallback) _mutate;
  final bool Function() _mounted;
  final bool Function() _suppressClickEdit;
  final bool Function() _enableCellEditingOnBackspace;
  final bool Function() _readOnlyEdit;
  final bool Function() _enterNavigatesVerticallyAfterEdit;
  final bool Function() _stopEditingWhenCellsLoseFocus;
  final OsRowSelection? Function() _rowSelection;
  final bool Function() _rowNumbers;
  final bool Function() _rowDrag;
  final bool Function() _floatingFilter;
  final double Function() _floatingFilterHeight;
  final OsGridTheme? Function() _theme;
  final OsLocaleText? Function() _localeText;
  final List<OsColumnDefBase> Function() _columnDefs;
  final Set<String> Function() _hiddenColumnIds;
  final List<String>? Function() _columnOrder;
  final Map<String, double> Function() _columnWidths;
  final double Function() _effectiveHeaderHeight;
  final double Function() _effectiveRowHeight;
  final TextPainterCache _textPainterCache;
  final void Function(
    List<OsColumnDefBase> defs,
    List<OsColumnDef> outColumns,
    List<ColumnGroupSpan> outSpans,
  )
  _flattenColumnDefs;
  final bool Function(OsColumnDef col, TData rowData, int rowIndex)
  _isCellEditableFn;
  final void Function(int rowIndex, OsColumnDef col, TData rowData)
  _clearCellValueFn;
  final void Function(OsCellEditingStartedEvent<TData>)? _onCellEditingStarted;
  final void Function(OsCellEditingStoppedEvent<TData>)? _onCellEditingStopped;
  final void Function(OsCellValueChangedEvent<TData>)? _onCellValueChanged;
  final void Function(OsCellEditRequestEvent<TData>)? _onCellEditRequest;
  final BuildContext Function() _context;

  /// Optional custom Tab navigation consulted after committing an edit
  /// with Tab. Falls back to the built-in next-editable-cell scan when
  /// null or when the callback returns null.
  final NavCellPosition? Function(TabToNextCellParams params)? _tabToNextCell;

  // --- Cell editing session state ---

  Rect? _editCellRect;
  int? _editRowIndex;
  int? _editColIndex;
  String? _editField;
  dynamic _editOriginalValue;

  /// The row object the session was opened on. Commits resolve the CURRENT
  /// index by identity so reorders between open and commit stay correct, and
  /// removals are detected instead of writing into an unrelated row.
  TData? _sessionRow;
  OsColumnDef? _editingColDef;
  final TextEditingController _editTextController = TextEditingController();
  final FocusNode _editFocusNode = FocusNode();

  /// Focus node for the inline text editor overlay's KeyboardListener.
  ///
  /// Distinct from [_editFocusNode] (owned by the overlay's TextField — a
  /// FocusNode may only attach to one widget at a time). State-owned so
  /// overlay rebuilds reuse it instead of leaking a new node per rebuild.
  final FocusNode _editOverlayFocusNode = FocusNode(skipTraversal: true);

  // --- Select cell editor state ---

  /// Whether the current edit is using a select (dropdown) editor.
  bool _isSelectEditing = false;

  /// The highlighted index in the select dropdown list.
  int _selectHighlightedIndex = 0;

  /// Focus node for the select dropdown overlay.
  final FocusNode _selectFocusNode = FocusNode();

  /// Scroll controller for the select dropdown list.
  final ScrollController _selectScrollController = ScrollController();

  // --- Rich select cell editor state ---

  /// Resolved option values for the active rich-select session
  /// (from [OsRichSelectCellEditor.values] or its valuesProvider).
  List<dynamic> _richResolvedValues = const [];

  /// The filtered subset of [_richResolvedValues] currently shown.
  List<dynamic> _richFilteredValues = const [];

  /// Text controller backing the rich-select search input.
  late final TextEditingController _richSearchController =
      TextEditingController();

  /// Focus node backing the rich-select search input. Its [FocusNode.onKeyEvent]
  /// intercepts navigation keys before the text field's own handling.
  late final FocusNode _richSearchFocusNode = FocusNode();

  /// Pending debounce timer for the rich-select filter input.
  Timer? _richDebounceTimer;

  // --- Custom cell editor state ---

  /// Whether the current edit is using a custom editor widget.
  bool _isCustomEditing = false;

  /// The current value held by the custom editor (updated via onValueChanged).
  dynamic _customEditorValue;

  /// Focus node for the custom editor overlay.
  final FocusNode _customEditorFocusNode = FocusNode();

  // --- Large text cell editor state ---

  /// Whether the current edit is using a large text (textarea) editor.
  bool _isLargeTextEditing = false;

  /// Text controller for the large text editor textarea.
  late final TextEditingController _largeTextController =
      TextEditingController();

  /// Focus node for the large text editor overlay.
  final FocusNode _largeTextFocusNode = FocusNode();

  // --- Date cell editor state ---

  /// Whether the current edit is using a date picker editor.
  bool _isDateEditing = false;

  /// Track the desired selection to apply after TextField gains focus.
  /// This prevents TextField's default select-all-on-focus from overriding
  /// our intended cursor position.
  TextSelection? _pendingEditSelection;

  // --- Session accessors (compat surface for the owning State) ---

  /// Rect of the active edit overlay cell, or null when not editing.
  Rect? get editCellRect => _editCellRect;

  /// Row index of the active edit session, or null when not editing.
  int? get editRowIndex => _editRowIndex;

  /// Column index of the active edit session, or null when not editing.
  int? get editColIndex => _editColIndex;

  /// Text controller backing the inline text editor overlay.
  TextEditingController get editTextController => _editTextController;

  /// Focus node backing the inline text editor overlay.
  FocusNode get editFocusNode => _editFocusNode;

  /// Focus node for the inline text editor overlay's KeyboardListener
  /// (see [_editOverlayFocusNode]).
  FocusNode get editOverlayFocusNode => _editOverlayFocusNode;

  /// Whether the active edit session uses the select dropdown editor.
  bool get isSelectEditing => _isSelectEditing;

  /// Whether the active edit session uses a custom editor widget.
  bool get isCustomEditing => _isCustomEditing;

  /// Whether the active edit session uses the large text editor.
  bool get isLargeTextEditing => _isLargeTextEditing;

  /// Whether the active edit session uses the date picker editor.
  bool get isDateEditing => _isDateEditing;

  /// Releases focus nodes and controllers owned by this coordinator.
  /// Call from the owning State's dispose.
  void dispose() {
    _editFocusNode.removeListener(_onEditFocusChanged);
    _editFocusNode.dispose();
    _editOverlayFocusNode.dispose();
    _editTextController.dispose();
    _selectFocusNode.dispose();
    _selectScrollController.dispose();
    _customEditorFocusNode.dispose();
    _largeTextController.dispose();
    _largeTextFocusNode.dispose();
    _richDebounceTimer?.cancel();
    _richSearchController.dispose();
    _richSearchFocusNode.dispose();
  }

  /// Attaches the coordinator to [controller] as part of the module
  /// lifecycle.
  ///
  /// All collaborators are supplied via the constructor, so attach
  /// currently performs no additional wiring; it exists to make the
  /// lifecycle explicit and to give future module-driven setup a stable
  /// seam. Called by `EditingModule` (or the grid directly) once the
  /// coordinator is constructed.
  void attach(OsGridController<TData> controller) {}

  /// Detaches the coordinator as part of the module lifecycle: drops any
  /// active edit session so no editor state outlives the module.
  ///
  /// Session state is cleared directly (no rebuild is scheduled) so detach
  /// is safe to call from the owning State's dispose.
  void detach() {
    if (_editCellRect == null) return;
    _richDebounceTimer?.cancel();
    _richDebounceTimer = null;
    _editCellRect = null;
    _editRowIndex = null;
    _editColIndex = null;
    _editField = null;
    _editOriginalValue = null;
    _editingColDef = null;
    _sessionRow = null;
    _isSelectEditing = false;
    _isCustomEditing = false;
    _isLargeTextEditing = false;
    _isDateEditing = false;
    _customEditorValue = null;
    _richResolvedValues = const [];
    _richFilteredValues = const [];
  }

  void handleCellEditRequest(
    DataCellHit hit,
    Rect cellRect, {
    String? triggerKey,
  }) {
    // Suppress click-initiated editing if suppressClickEdit is enabled.
    // This method is called from double-tap and single-click paths.
    // API-initiated editing (startEditingCell) bypasses this check.
    // Checkbox editors bypass suppressClickEdit — they always toggle on click.
    if (triggerKey == null &&
        _suppressClickEdit() &&
        hit.colDef.cellEditor is! OsCheckboxCellEditor) {
      return;
    }

    // Check if the column is editable (static flag or per-row callback)
    final col = hit.colDef;
    final effectiveData = _resolveRows();
    if (effectiveData == null || hit.rowIndex >= effectiveData.length) return;

    final rowData = effectiveData[hit.rowIndex];
    final isEditable = _isCellEditableFn(col, rowData, hit.rowIndex);
    if (!isEditable) return;

    // For Delete/Backspace, clear the value directly without opening the editor
    // (matching TypeScript behaviour: setDataValue with 'cellClear' source).
    // Exception: when enableCellEditingOnBackspace is true, Backspace starts
    // editing with empty value instead of clearing directly.
    // Checkbox editors ignore Delete/Backspace — they only respond to click/Space/Enter.
    if (triggerKey == 'delete') {
      if (col.cellEditor is OsCheckboxCellEditor) return;
      _clearCellValueFn(hit.rowIndex, col, rowData);
      return;
    }
    if (triggerKey == 'backspace') {
      if (col.cellEditor is OsCheckboxCellEditor) return;
      if (_enableCellEditingOnBackspace()) {
        // Start editing with empty value (fall through to editor opening below)
        // The triggerKey will be handled as a special case for initial text.
      } else {
        _clearCellValueFn(hit.rowIndex, col, rowData);
        return;
      }
    }

    // Store original value for Escape cancel
    _editOriginalValue = hit.value;
    _editingColDef = col;

    // Check if this column uses a checkbox cell editor — toggle in-place.
    // Only click (null triggerKey), Enter, and Space should toggle.
    // Printable characters, F2, etc. are ignored for checkbox cells.
    if (col.cellEditor is OsCheckboxCellEditor) {
      if (triggerKey == null || triggerKey == 'enter' || triggerKey == ' ') {
        toggleCheckboxCell(
          hit.rowIndex,
          col,
          col.cellEditor as OsCheckboxCellEditor,
          rowData,
        );
      }
      return;
    }

    // Check if this column uses a select cell editor
    if (col.cellEditor is OsSelectCellEditor) {
      _openSelectEditor(
        hit,
        cellRect,
        col.cellEditor as OsSelectCellEditor,
        rowData,
      );
      return;
    }

    // Check if this column uses a date cell editor with native picker
    if (col.cellEditor is OsDateCellEditor) {
      final dateEditor = col.cellEditor as OsDateCellEditor;
      if (dateEditor.useNativePicker) {
        _openDateEditor(hit, cellRect, dateEditor, rowData);
        return;
      }
      // Fall through to text editor for useNativePicker: false
    }

    // Check if this column uses a date string cell editor with native picker
    if (col.cellEditor is OsDateStringCellEditor) {
      final dateStringEditor = col.cellEditor as OsDateStringCellEditor;
      if (dateStringEditor.useNativePicker) {
        _openDateStringEditor(hit, cellRect, dateStringEditor, rowData);
        return;
      }
      // Fall through to text editor for useNativePicker: false
    }

    // Check if this column uses a large text cell editor
    if (col.cellEditor is OsLargeTextCellEditor) {
      _openLargeTextEditor(
        hit,
        cellRect,
        col.cellEditor as OsLargeTextCellEditor,
        rowData,
        triggerKey,
      );
      return;
    }

    // Check if this column uses a custom cell editor
    if (col.cellEditor is OsCustomCellEditor) {
      _openCustomEditor(
        hit,
        cellRect,
        col.cellEditor as OsCustomCellEditor,
        rowData,
        triggerKey,
      );
      return;
    }

    // Determine initial text based on trigger
    final String initialText;
    if (triggerKey == 'backspace' && _enableCellEditingOnBackspace()) {
      // Backspace with enableCellEditingOnBackspace: start with empty value
      initialText = '';
    } else if (triggerKey != null && triggerKey.length == 1) {
      // Printable character — set as initial text (key event is consumed,
      // so the character won't arrive via text input).
      initialText = triggerKey;
    } else {
      // Enter, F2, double-click, single-click — show existing value.
      // For date editors, format DateTime values as ISO date strings.
      if (col.cellEditor is OsDateCellEditor && hit.value is DateTime) {
        final dateEditor = col.cellEditor as OsDateCellEditor;
        initialText = dateEditor.serialiseDate(hit.value as DateTime);
      } else if (col.cellEditor is OsDateStringCellEditor) {
        // Date string editor: show the raw string value
        initialText = hit.value?.toString() ?? '';
      } else {
        initialText = hit.value?.toString() ?? '';
      }
    }

    _mutate(() {
      // Bind the session to the row OBJECT so later reorders/removals
      // cannot misroute the commit (AG Grid binds edits to row nodes).
      _sessionRow = rowData;
      _editCellRect = cellRect;
      _editRowIndex = hit.rowIndex;
      _editColIndex = hit.columnIndex;
      _editField = col.field;
      _isSelectEditing = false;
      _editTextController.text = initialText;
    });

    // Emit cellEditingStarted event
    final startEvent = OsCellEditingStartedEvent<TData>(
      data: rowData,
      rowIndex: hit.rowIndex,
      colDef: OsColumnDef<TData>(field: col.field, headerName: col.headerName),
      value: hit.value,
    );
    _onCellEditingStarted?.call(startEvent);
    _controller.emitCellEditingStarted(startEvent);
    _undoRedoService()?.onCellEditingStarted();

    // Focus the text field after the frame with appropriate selection.
    // Store the desired selection — it will be applied by _onEditFocusChanged
    // after TextField's internal focus handling (which selects all) completes.
    if (triggerKey == 'backspace' && _enableCellEditingOnBackspace()) {
      // Empty text — caret at start
      _pendingEditSelection = const TextSelection.collapsed(offset: 0);
    } else if (triggerKey == 'f2') {
      _pendingEditSelection = TextSelection.collapsed(
        offset: initialText.length,
      );
    } else if (triggerKey != null && triggerKey.length == 1) {
      _pendingEditSelection = TextSelection.collapsed(
        offset: initialText.length,
      );
    } else {
      // Enter, double-click, single-click: select all
      _pendingEditSelection = TextSelection(
        baseOffset: 0,
        extentOffset: initialText.length,
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_mounted() && _editCellRect != null) {
        _editFocusNode.requestFocus();
      }
    });
  }

  /// Opens the select (dropdown) editor for a cell.
  void _openSelectEditor(
    DataCellHit hit,
    Rect cellRect,
    OsSelectCellEditor selectEditor,
    TData rowData,
  ) {
    final isRichSelect = selectEditor is OsRichSelectCellEditor;

    // Resolve the option list: a rich select may compute it per edit via
    // valuesProvider; otherwise fall back to the static values list.
    var resolvedValues = List<dynamic>.from(selectEditor.values);
    if (isRichSelect) {
      final provider = selectEditor.valuesProvider;
      if (provider != null) {
        resolvedValues = List<dynamic>.from(
          provider(
            OsRichSelectValuesParams<TData>(
              value: hit.value,
              data: rowData,
              rowIndex: hit.rowIndex,
              column: hit.colDef.field ?? '',
            ),
          ),
        );
      }
    }

    // Find the index of the current value in the resolved list
    final currentValue = hit.value;
    int highlightIndex = 0;
    for (int i = 0; i < resolvedValues.length; i++) {
      if (resolvedValues[i]?.toString() == currentValue?.toString()) {
        highlightIndex = i;
        break;
      }
    }

    _mutate(() {
      // Bind the session to the row OBJECT so later reorders/removals
      // cannot misroute the commit (AG Grid binds edits to row nodes).
      _sessionRow = rowData;
      _editCellRect = cellRect;
      _editRowIndex = hit.rowIndex;
      _editColIndex = hit.columnIndex;
      _editField = hit.colDef.field;
      _isSelectEditing = true;
      _selectHighlightedIndex = highlightIndex;
      if (isRichSelect) {
        _richResolvedValues = resolvedValues;
        _richFilteredValues = resolvedValues;
        _richSearchController.text = '';
      } else {
        _richResolvedValues = const [];
        _richFilteredValues = const [];
      }
    });

    // Emit cellEditingStarted event
    final startEvent = OsCellEditingStartedEvent<TData>(
      data: rowData,
      rowIndex: hit.rowIndex,
      colDef: OsColumnDef<TData>(
        field: hit.colDef.field,
        headerName: hit.colDef.headerName,
      ),
      value: hit.value,
    );
    _onCellEditingStarted?.call(startEvent);
    _controller.emitCellEditingStarted(startEvent);
    _undoRedoService()?.onCellEditingStarted();

    // Focus after the frame: the search input for typable rich selects
    // (so typing filters immediately), otherwise the plain dropdown overlay.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_mounted() && _editCellRect != null && _isSelectEditing) {
        if (isRichSelect && selectEditor.allowTyping) {
          _richSearchFocusNode.requestFocus();
        } else {
          _selectFocusNode.requestFocus();
        }
      }
    });
  }

  /// Opens the date picker editor for a cell with DateTime values.
  void _openDateEditor(
    DataCellHit hit,
    Rect cellRect,
    OsDateCellEditor dateEditor,
    TData rowData,
  ) {
    _mutate(() {
      // Bind the session to the row OBJECT so later reorders/removals
      // cannot misroute the commit (AG Grid binds edits to row nodes).
      _sessionRow = rowData;
      _editCellRect = cellRect;
      _editRowIndex = hit.rowIndex;
      _editColIndex = hit.columnIndex;
      _editField = hit.colDef.field;
      _isSelectEditing = false;
      _isCustomEditing = false;
      _isLargeTextEditing = false;
      _isDateEditing = true;
    });

    // Emit cellEditingStarted event
    final startEvent = OsCellEditingStartedEvent<TData>(
      data: rowData,
      rowIndex: hit.rowIndex,
      colDef: OsColumnDef<TData>(
        field: hit.colDef.field,
        headerName: hit.colDef.headerName,
      ),
      value: hit.value,
    );
    _onCellEditingStarted?.call(startEvent);
    _controller.emitCellEditingStarted(startEvent);
    _undoRedoService()?.onCellEditingStarted();
  }

  /// Opens the date picker editor for a cell with String date values.
  void _openDateStringEditor(
    DataCellHit hit,
    Rect cellRect,
    OsDateStringCellEditor dateStringEditor,
    TData rowData,
  ) {
    _mutate(() {
      // Bind the session to the row OBJECT so later reorders/removals
      // cannot misroute the commit (AG Grid binds edits to row nodes).
      _sessionRow = rowData;
      _editCellRect = cellRect;
      _editRowIndex = hit.rowIndex;
      _editColIndex = hit.columnIndex;
      _editField = hit.colDef.field;
      _isSelectEditing = false;
      _isCustomEditing = false;
      _isLargeTextEditing = false;
      _isDateEditing = true;
    });

    // Emit cellEditingStarted event
    final startEvent = OsCellEditingStartedEvent<TData>(
      data: rowData,
      rowIndex: hit.rowIndex,
      colDef: OsColumnDef<TData>(
        field: hit.colDef.field,
        headerName: hit.colDef.headerName,
      ),
      value: hit.value,
    );
    _onCellEditingStarted?.call(startEvent);
    _controller.emitCellEditingStarted(startEvent);
    _undoRedoService()?.onCellEditingStarted();
  }

  /// Commits the date selected from the date picker.
  void _commitDateEdit(DateTime selectedDate) {
    if (_editRowIndex == null || _editField == null) return;

    final effectiveData = _resolveRows();
    if (effectiveData == null) return;

    // Bind to the session row (see [_resolveSessionRow]) so a reorder or
    // transaction between session start and commit cannot misroute the
    // write; a removed row cancels the session instead.
    final resolved = _resolveSessionRow(effectiveData);
    if (resolved == null) {
      cancelEditRevert();
      return;
    }
    final (row, rowIndex) = resolved;
    final col = _editingColDef;
    final oldValue = _editOriginalValue;

    // Determine the committed value based on editor type
    dynamic parsedValue;
    if (col?.cellEditor is OsDateStringCellEditor) {
      final dateStringEditor = col!.cellEditor as OsDateStringCellEditor;
      // Validate constraints
      final errors = dateStringEditor.validate(selectedDate);
      if (errors != null) {
        // Validation failed — cancel
        cancelEditRevert();
        return;
      }
      parsedValue = dateStringEditor.formatDate(selectedDate);
    } else if (col?.cellEditor is OsDateCellEditor) {
      final dateEditor = col!.cellEditor as OsDateCellEditor;
      // Validate constraints
      final errors = dateEditor.validate(selectedDate);
      if (errors != null) {
        // Validation failed — cancel
        cancelEditRevert();
        return;
      }
      parsedValue = selectedDate;
    } else {
      parsedValue = selectedDate;
    }

    // Check if value actually changed
    final valueChanged = !editValuesEqual(oldValue, parsedValue);

    if (valueChanged) {
      // readOnlyEdit mode: fire cellEditRequest instead of writing to data
      if (_readOnlyEdit()) {
        final requestEvent = OsCellEditRequestEvent<TData>(
          data: row,
          rowIndex: rowIndex,
          colDef: OsColumnDef<TData>(field: _editField),
          oldValue: oldValue,
          newValue: parsedValue,
          source: 'edit',
        );
        _onCellEditRequest?.call(requestEvent);
        _controller.emitCellEditRequest(requestEvent);
      } else {
        // Write value using valueSetter or default Map write
        bool dataChanged;
        if ((col as dynamic)?.valueSetter != null) {
          dataChanged = ((col as dynamic).valueSetter as Function)(
            ValueSetterParams<TData>(
              data: row,
              colDef: col!,
              oldValue: oldValue,
              newValue: parsedValue,
              rowIndex: rowIndex,
            ),
          );
        } else if (row is Map<String, dynamic> && _editField != null) {
          row[_editField!] = parsedValue;
          dataChanged = true;
        } else {
          dataChanged = false;
        }

        if (dataChanged) {
          // Record for undo/redo
          _undoRedoService()?.onCellValueChanged(
            rowIndex: rowIndex,
            rowId: _controller.rowIdFor(row),
            columnId: _editField!,
            oldValue: oldValue,
            newValue: parsedValue,
          );

          // Emit cellValueChanged event
          final event = OsCellValueChangedEvent<TData>(
            data: row,
            rowIndex: rowIndex,
            colDef: OsColumnDef<TData>(field: _editField),
            oldValue: oldValue,
            newValue: parsedValue,
          );
          _onCellValueChanged?.call(event);
          _controller.emitCellValueChanged(event);
        }
      }
    }

    // Emit cellEditingStopped event
    final stopEvent = OsCellEditingStoppedEvent<TData>(
      data: row,
      rowIndex: rowIndex,
      colDef: OsColumnDef<TData>(
        field: _editField,
        headerName: col?.headerName,
      ),
      oldValue: oldValue,
      newValue: parsedValue,
      cancelled: !valueChanged,
    );
    _onCellEditingStopped?.call(stopEvent);
    _controller.emitCellEditingStopped(stopEvent);

    _closeEditOverlay();
  }

  /// Builds the date picker overlay widget.
  ///
  /// Widget construction lives in [DateEditorOverlay]; this factory only
  /// reads session state.
  Widget buildDateEditorOverlay() {
    return DateEditorOverlay(
      cellRect: _editCellRect!,
      colDef: _editingColDef,
      originalValue: _editOriginalValue,
      onDateSelected: _commitDateEdit,
      onCancel: cancelEditRevert,
      theme: _theme(),
      localeText: _localeText(),
    );
  }

  /// Opens a custom editor widget for a cell.
  void _openCustomEditor(
    DataCellHit hit,
    Rect cellRect,
    OsCustomCellEditor customEditor,
    TData rowData,
    String? triggerKey,
  ) {
    _mutate(() {
      // Bind the session to the row OBJECT so later reorders/removals
      // cannot misroute the commit (AG Grid binds edits to row nodes).
      _sessionRow = rowData;
      _editCellRect = cellRect;
      _editRowIndex = hit.rowIndex;
      _editColIndex = hit.columnIndex;
      _editField = hit.colDef.field;
      _isSelectEditing = false;
      _isCustomEditing = true;
      _customEditorValue = hit.value;
    });

    // Emit cellEditingStarted event
    final startEvent = OsCellEditingStartedEvent<TData>(
      data: rowData,
      rowIndex: hit.rowIndex,
      colDef: OsColumnDef<TData>(
        field: hit.colDef.field,
        headerName: hit.colDef.headerName,
      ),
      value: hit.value,
    );
    _onCellEditingStarted?.call(startEvent);
    _controller.emitCellEditingStarted(startEvent);
    _undoRedoService()?.onCellEditingStarted();

    // Focus the custom editor after the frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_mounted() && _editCellRect != null && _isCustomEditing) {
        _customEditorFocusNode.requestFocus();
      }
    });
  }

  /// Commits the current value from the custom editor.
  void _commitCustomEdit() {
    if (_editRowIndex == null || _editField == null) return;

    final effectiveData = _resolveRows();
    if (effectiveData == null) return;

    // Bind to the session row (see [_resolveSessionRow]) so a reorder or
    // transaction between session start and commit cannot misroute the
    // write; a removed row cancels the session instead.
    final resolved = _resolveSessionRow(effectiveData);
    if (resolved == null) {
      cancelEditRevert();
      return;
    }
    final (row, rowIndex) = resolved;
    final col = _editingColDef;
    final oldValue = _editOriginalValue;
    final newValue = _customEditorValue;

    // Check if value actually changed
    final valueChanged = !editValuesEqual(oldValue, newValue);

    if (valueChanged) {
      // readOnlyEdit mode: fire cellEditRequest instead of writing to data
      if (_readOnlyEdit()) {
        final requestEvent = OsCellEditRequestEvent<TData>(
          data: row,
          rowIndex: rowIndex,
          colDef: OsColumnDef<TData>(field: _editField),
          oldValue: oldValue,
          newValue: newValue,
          source: 'edit',
        );
        _onCellEditRequest?.call(requestEvent);
        _controller.emitCellEditRequest(requestEvent);
      } else {
        // Write value using valueSetter or default Map write
        bool dataChanged;
        if ((col as dynamic)?.valueSetter != null) {
          dataChanged = ((col as dynamic).valueSetter as Function)(
            ValueSetterParams<TData>(
              data: row,
              colDef: col!,
              oldValue: oldValue,
              newValue: newValue,
              rowIndex: rowIndex,
              source: 'edit',
            ),
          );
        } else if (row is Map<String, dynamic> && _editField != null) {
          (row as Map<String, dynamic>)[_editField!] = newValue;
          dataChanged = true;
        } else {
          dataChanged = false;
        }

        if (dataChanged) {
          // Notify undo/redo service of the value change
          _undoRedoService()?.onCellValueChanged(
            rowIndex: rowIndex,
            rowId: _controller.rowIdFor(row),
            columnId: _editField!,
            oldValue: oldValue,
            newValue: newValue,
          );

          // Emit cellValueChanged event
          final event = OsCellValueChangedEvent<TData>(
            data: row,
            rowIndex: rowIndex,
            colDef: OsColumnDef<TData>(field: _editField),
            oldValue: oldValue,
            newValue: newValue,
          );
          _onCellValueChanged?.call(event);
          _controller.emitCellValueChanged(event);
        }
      }
    }

    // Notify undo/redo service that editing stopped
    _undoRedoService()?.onCellEditingStopped(
      valueChanged: valueChanged && !_readOnlyEdit(),
    );

    // Emit cellEditingStopped event (committed)
    final stopEvent = OsCellEditingStoppedEvent<TData>(
      data: row,
      rowIndex: rowIndex,
      colDef: OsColumnDef<TData>(field: _editField),
      oldValue: oldValue,
      newValue: newValue,
      cancelled: false,
    );
    _onCellEditingStopped?.call(stopEvent);
    _controller.emitCellEditingStopped(stopEvent);

    _closeEditOverlay();
  }

  /// Builds the custom editor overlay widget.
  ///
  /// Widget construction lives in [CustomEditorOverlay]; this factory
  /// resolves session state and applies the early-out guards.
  Widget buildCustomEditorOverlay() {
    final col = _editingColDef;
    if (col?.cellEditor is! OsCustomCellEditor) return const SizedBox.shrink();
    final customEditor = col!.cellEditor as OsCustomCellEditor;

    final effectiveData = _resolveRows();
    if (effectiveData == null ||
        _editRowIndex == null ||
        _editRowIndex! >= effectiveData.length) {
      return const SizedBox.shrink();
    }

    return CustomEditorOverlay<TData>(
      cellRect: _editCellRect!,
      editor: customEditor,
      editorContext: _context(),
      colDef: col,
      // Prefer the captured session row so a mid-session reorder shows the
      // editor bound to the row being edited, not whatever moved into its
      // index.
      rowData: _sessionRow ?? effectiveData[_editRowIndex!],
      rowIndex: _editRowIndex!,
      originalValue: _editOriginalValue,
      field: _editField,
      focusNode: _customEditorFocusNode,
      onKeyEvent: _handleCustomEditorKeyEvent,
      onValueChanged: (value) {
        _customEditorValue = value;
      },
      onStopEditing: (cancel) {
        if (cancel) {
          cancelEditRevert();
        } else {
          _commitCustomEdit();
        }
      },
    );
  }

  /// Handles keyboard events for the custom editor.
  KeyEventResult _handleCustomEditorKeyEvent(FocusNode node, KeyEvent event) {
    if (!_isCustomEditing || _editCellRect == null) {
      return KeyEventResult.ignored;
    }
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final col = _editingColDef;
    if (col?.cellEditor is! OsCustomCellEditor) return KeyEventResult.ignored;
    final customEditor = col!.cellEditor as OsCustomCellEditor;

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (!customEditor.suppressEscapeCancel) {
        cancelEditRevert();
        return KeyEventResult.handled;
      }
    }

    if (event.logicalKey == LogicalKeyboardKey.enter) {
      if (!customEditor.suppressEnterCommit) {
        _commitCustomEdit();
        return KeyEventResult.handled;
      }
    }

    if (event.logicalKey == LogicalKeyboardKey.tab) {
      final isShift = HardwareKeyboard.instance.logicalKeysPressed.any(
        (key) =>
            key == LogicalKeyboardKey.shiftLeft ||
            key == LogicalKeyboardKey.shiftRight,
      );
      // Capture indices before commit (which clears them)
      final rowIndex = _editRowIndex;
      final colIndex = _editColIndex;
      _commitCustomEdit();
      // Navigate to next/previous editable cell
      if (rowIndex != null && colIndex != null) {
        final offset = isShift ? -1 : 1;
        startEditingCellAt(rowIndex, colIndex + offset);
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  // --- Large text cell editor ---

  /// Opens the large text (textarea) editor as a popup below the cell.
  void _openLargeTextEditor(
    DataCellHit hit,
    Rect cellRect,
    OsLargeTextCellEditor largeTextEditor,
    TData rowData,
    String? triggerKey,
  ) {
    // Determine initial text based on trigger key (same logic as text editor)
    final String initialText;
    if (triggerKey == 'backspace' && _enableCellEditingOnBackspace()) {
      initialText = '';
    } else if (triggerKey == 'delete' || triggerKey == 'backspace') {
      initialText = '';
    } else if (triggerKey != null && triggerKey.length == 1) {
      initialText = triggerKey;
    } else {
      initialText = hit.value?.toString() ?? '';
    }

    _mutate(() {
      // Bind the session to the row OBJECT so later reorders/removals
      // cannot misroute the commit (AG Grid binds edits to row nodes).
      _sessionRow = rowData;
      _editCellRect = cellRect;
      _editRowIndex = hit.rowIndex;
      _editColIndex = hit.columnIndex;
      _editField = hit.colDef.field;
      _isSelectEditing = false;
      _isCustomEditing = false;
      _isLargeTextEditing = true;
      _largeTextController.text = initialText;
    });

    // Emit cellEditingStarted event
    final startEvent = OsCellEditingStartedEvent<TData>(
      data: rowData,
      rowIndex: hit.rowIndex,
      colDef: OsColumnDef<TData>(
        field: hit.colDef.field,
        headerName: hit.colDef.headerName,
      ),
      value: hit.value,
    );
    _onCellEditingStarted?.call(startEvent);
    _controller.emitCellEditingStarted(startEvent);
    _undoRedoService()?.onCellEditingStarted();

    // Focus the textarea after the frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_mounted() && _editCellRect != null && _isLargeTextEditing) {
        _largeTextFocusNode.requestFocus();
        // Select all text if opened via Enter/F2/click, position at end for char trigger
        if (triggerKey == null || triggerKey == 'enter' || triggerKey == 'f2') {
          _largeTextController.selection = TextSelection(
            baseOffset: 0,
            extentOffset: _largeTextController.text.length,
          );
        } else {
          _largeTextController.selection = TextSelection.collapsed(
            offset: _largeTextController.text.length,
          );
        }
      }
    });
  }

  /// Commits the large text editor value.
  void commitLargeTextEdit() {
    if (_editRowIndex == null || _editField == null) return;

    final col = _editingColDef;
    final oldValue = _editOriginalValue;
    final newValue = _largeTextController.text;

    // Check if value actually changed
    if (newValue == (oldValue?.toString() ?? '')) {
      // No change — just close
      _closeLargeTextEditWithEvent(oldValue, oldValue);
      return;
    }

    // Apply valueParser if defined
    final effectiveData = _resolveRows();
    if (effectiveData == null) return;
    // Bind to the session row (see [_resolveSessionRow]) so a reorder or
    // transaction between session start and commit cannot misroute the
    // write; a removed row cancels the session instead.
    final resolved = _resolveSessionRow(effectiveData);
    if (resolved == null) {
      cancelEditRevert();
      return;
    }
    final (rowData, rowIndex) = resolved;

    dynamic parsedValue = newValue;
    if ((col as dynamic)?.valueParser != null) {
      parsedValue = ((col as dynamic).valueParser as Function)(
        ValueParserParams<TData>(
          data: rowData,
          colDef: col!,
          oldValue: oldValue,
          newValue: newValue,
          rowIndex: rowIndex,
          source: 'edit',
        ),
      );
    }

    // readOnlyEdit mode — fire cellEditRequest instead of mutating data
    if (_readOnlyEdit()) {
      final editRequestEvent = OsCellEditRequestEvent<TData>(
        data: rowData,
        rowIndex: rowIndex,
        colDef: OsColumnDef<TData>(
          field: _editField!,
          headerName: col?.headerName,
        ),
        oldValue: oldValue,
        newValue: parsedValue,
      );
      _onCellEditRequest?.call(editRequestEvent);
      _controller.emitCellEditRequest(editRequestEvent);
      _closeLargeTextEditWithEvent(oldValue, parsedValue);
      return;
    }

    // Apply valueSetter or direct field assignment
    bool valueSet = false;
    if ((col as dynamic)?.valueSetter != null) {
      valueSet = ((col as dynamic).valueSetter as Function)(
        ValueSetterParams<TData>(
          data: rowData,
          colDef: col!,
          oldValue: oldValue,
          newValue: parsedValue,
          rowIndex: rowIndex,
          source: 'edit',
        ),
      );
    } else {
      // Direct field assignment via map
      if (rowData is Map) {
        (rowData as Map<String, dynamic>)[_editField!] = parsedValue;
        valueSet = true;
      }
    }

    if (valueSet) {
      // Emit cellValueChanged event
      final changeEvent = OsCellValueChangedEvent<TData>(
        data: rowData,
        rowIndex: rowIndex,
        colDef: OsColumnDef<TData>(
          field: _editField!,
          headerName: col?.headerName,
        ),
        oldValue: oldValue,
        newValue: parsedValue,
      );
      _onCellValueChanged?.call(changeEvent);
      _controller.emitCellValueChanged(changeEvent);
      _undoRedoService()?.onCellValueChanged(
        rowIndex: rowIndex,
        rowId: _controller.rowIdFor(rowData),
        columnId: _editField!,
        oldValue: oldValue,
        newValue: parsedValue,
      );
    }

    _closeLargeTextEditWithEvent(oldValue, parsedValue);
  }

  /// Closes the large text editor and emits the cellEditingStopped event.
  void _closeLargeTextEditWithEvent(dynamic oldValue, dynamic newValue) {
    final effectiveData = _resolveRows();
    final rowData =
        (effectiveData != null &&
            _editRowIndex != null &&
            _editRowIndex! < effectiveData.length)
        ? effectiveData[_editRowIndex!]
        : null;

    final stopEvent = OsCellEditingStoppedEvent<TData>(
      data: rowData as TData,
      rowIndex: _editRowIndex ?? 0,
      colDef: OsColumnDef<TData>(
        field: _editField ?? '',
        headerName: _editingColDef?.headerName,
      ),
      oldValue: oldValue,
      newValue: newValue,
      cancelled: false,
    );
    _onCellEditingStopped?.call(stopEvent);
    _controller.emitCellEditingStopped(stopEvent);

    _closeEditOverlay();
  }

  /// Builds the large text editor popup overlay widget.
  ///
  /// Widget construction lives in [LargeTextEditorOverlay]; this factory
  /// only reads session state.
  Widget buildLargeTextEditorOverlay() {
    final col = _editingColDef;
    if (col?.cellEditor is! OsLargeTextCellEditor) {
      return const SizedBox.shrink();
    }
    final largeTextEditor = col!.cellEditor as OsLargeTextCellEditor;

    return LargeTextEditorOverlay(
      cellRect: _editCellRect!,
      editor: largeTextEditor,
      controller: _largeTextController,
      focusNode: _largeTextFocusNode,
      onKeyEvent: _handleLargeTextKeyEvent,
      theme: _theme(),
    );
  }

  /// Handles keyboard events for the large text editor.
  KeyEventResult _handleLargeTextKeyEvent(FocusNode node, KeyEvent event) {
    if (!_isLargeTextEditing || _editCellRect == null) {
      return KeyEventResult.ignored;
    }
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      cancelEditRevert();
      return KeyEventResult.handled;
    }

    // Tab commits and navigates to next cell
    if (event.logicalKey == LogicalKeyboardKey.tab) {
      final isShift = HardwareKeyboard.instance.logicalKeysPressed.any(
        (key) =>
            key == LogicalKeyboardKey.shiftLeft ||
            key == LogicalKeyboardKey.shiftRight,
      );
      final rowIndex = _editRowIndex;
      final colIndex = _editColIndex;
      commitLargeTextEdit();
      if (rowIndex != null && colIndex != null) {
        final offset = isShift ? -1 : 1;
        startEditingCellAt(rowIndex, colIndex + offset);
      }
      return KeyEventResult.handled;
    }

    // Arrow keys and Shift+Enter are consumed by the textarea (allow navigation
    // within the text and newline insertion). They should NOT propagate to the
    // grid's navigation handler.
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
        event.logicalKey == LogicalKeyboardKey.arrowRight ||
        event.logicalKey == LogicalKeyboardKey.arrowUp ||
        event.logicalKey == LogicalKeyboardKey.arrowDown) {
      return KeyEventResult.ignored; // Let TextField handle cursor movement
    }

    // Shift+Enter inserts a newline (handled by TextField), plain Enter does nothing special
    // (also handled by TextField for multi-line). We don't commit on Enter for large text.

    return KeyEventResult.ignored;
  }

  /// Commits the selected value from the select editor.
  void _commitSelectEdit(dynamic selectedValue) {
    if (_editRowIndex == null || _editField == null) return;

    final effectiveData = _resolveRows();
    if (effectiveData == null || _editRowIndex! >= effectiveData.length) return;

    final row = effectiveData[_editRowIndex!];
    final col = _editingColDef;
    final oldValue = _editOriginalValue;

    // Use valueParser if provided, otherwise use the raw selected value
    dynamic parsedValue;
    if ((col as dynamic)?.valueParser != null) {
      parsedValue = ((col as dynamic).valueParser as Function)(
        ValueParserParams<TData>(
          data: row,
          colDef: col!,
          oldValue: oldValue,
          newValue: selectedValue?.toString() ?? '',
          rowIndex: _editRowIndex!,
          source: 'edit',
        ),
      );
    } else {
      parsedValue = selectedValue;
    }

    // Check if value actually changed
    final valueChanged = !editValuesEqual(oldValue, parsedValue);

    if (valueChanged) {
      // Write value using valueSetter or default Map write
      bool dataChanged;
      if ((col as dynamic)?.valueSetter != null) {
        dataChanged = ((col as dynamic).valueSetter as Function)(
          ValueSetterParams<TData>(
            data: row,
            colDef: col!,
            oldValue: oldValue,
            newValue: parsedValue,
            rowIndex: _editRowIndex!,
            source: 'edit',
          ),
        );
      } else if (row is Map<String, dynamic> && _editField != null) {
        (row as Map<String, dynamic>)[_editField!] = parsedValue;
        dataChanged = true;
      } else {
        dataChanged = false;
      }

      if (dataChanged) {
        // Notify undo/redo service of the value change
        _undoRedoService()?.onCellValueChanged(
          rowIndex: _editRowIndex!,
          rowId: _controller.rowIdFor(row),
          columnId: _editField!,
          oldValue: oldValue,
          newValue: parsedValue,
        );

        // Emit cellValueChanged event
        final event = OsCellValueChangedEvent<TData>(
          data: row,
          rowIndex: _editRowIndex!,
          colDef: OsColumnDef<TData>(field: _editField),
          oldValue: oldValue,
          newValue: parsedValue,
        );
        _onCellValueChanged?.call(event);
        _controller.emitCellValueChanged(event);
      }
    }

    // Notify undo/redo service that editing stopped
    _undoRedoService()?.onCellEditingStopped(valueChanged: valueChanged);

    // Emit cellEditingStopped event (committed)
    final stopEvent = OsCellEditingStoppedEvent<TData>(
      data: row,
      rowIndex: _editRowIndex!,
      colDef: OsColumnDef<TData>(field: _editField),
      oldValue: oldValue,
      newValue: parsedValue,
      cancelled: false,
    );
    _onCellEditingStopped?.call(stopEvent);
    _controller.emitCellEditingStopped(stopEvent);

    _closeEditOverlay();
  }

  /// The values the active select-style session operates on. For a plain
  /// [OsSelectCellEditor] this is its static list; for a
  /// [OsRichSelectCellEditor] it is the current filtered subset.
  List<dynamic> get _activeSelectValues {
    final editor = _editingColDef?.cellEditor;
    if (editor is OsRichSelectCellEditor) return _richFilteredValues;
    if (editor is OsSelectCellEditor) return editor.values;
    return const [];
  }

  /// Handles keyboard events for the select dropdown editor.
  KeyEventResult _handleSelectKeyEvent(KeyEvent event) {
    if (!_isSelectEditing || _editCellRect == null) {
      return KeyEventResult.ignored;
    }

    final col = _editingColDef;
    if (col?.cellEditor is! OsSelectCellEditor) return KeyEventResult.ignored;
    final values = _activeSelectValues;

    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        cancelEditRevert();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.enter) {
        if (values.isNotEmpty && _selectHighlightedIndex < values.length) {
          _commitSelectEdit(values[_selectHighlightedIndex]);
        } else {
          cancelEditRevert();
        }
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.tab) {
        // Tab commits the highlighted value and navigates
        if (values.isNotEmpty && _selectHighlightedIndex < values.length) {
          _commitSelectEdit(values[_selectHighlightedIndex]);
        }
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        if (values.isEmpty) return KeyEventResult.handled;
        _mutate(() {
          _selectHighlightedIndex = (_selectHighlightedIndex + 1).clamp(
            0,
            values.length - 1,
          );
        });
        _ensureSelectItemVisible();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        if (values.isEmpty) return KeyEventResult.handled;
        _mutate(() {
          _selectHighlightedIndex = (_selectHighlightedIndex - 1).clamp(
            0,
            values.length - 1,
          );
        });
        _ensureSelectItemVisible();
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  /// Key interceptor installed on the rich-select search input's focus node.
  ///
  /// Runs before the text field's own cursor-movement handling so that
  /// ArrowUp/ArrowDown navigate the dropdown list instead of moving the
  /// caret, while unhandled keys (characters) fall through to text input.
  KeyEventResult _handleRichSelectFieldKeyEvent(
    FocusNode node,
    KeyEvent event,
  ) {
    if (!_isSelectEditing || _editCellRect == null) {
      return KeyEventResult.ignored;
    }
    if (_editingColDef?.cellEditor is! OsRichSelectCellEditor) {
      return KeyEventResult.ignored;
    }
    return _handleRichSelectKeyEvent(event);
  }

  /// Handles navigation/commit keys for the rich select editor.
  KeyEventResult _handleRichSelectKeyEvent(KeyEvent event) {
    final values = _richFilteredValues;

    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        cancelEditRevert();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.enter) {
        if (values.isNotEmpty && _selectHighlightedIndex < values.length) {
          _commitSelectEdit(values[_selectHighlightedIndex]);
        } else {
          cancelEditRevert();
        }
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.tab) {
        if (values.isNotEmpty && _selectHighlightedIndex < values.length) {
          _commitSelectEdit(values[_selectHighlightedIndex]);
        }
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowDown ||
          event.logicalKey == LogicalKeyboardKey.arrowUp) {
        if (values.isEmpty) return KeyEventResult.handled;
        final delta = event.logicalKey == LogicalKeyboardKey.arrowDown ? 1 : -1;
        _mutate(() {
          _selectHighlightedIndex = (_selectHighlightedIndex + delta).clamp(
            0,
            values.length - 1,
          );
        });
        _ensureSelectItemVisible();
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  /// Scrolls the select dropdown to ensure the highlighted item is visible.
  void _ensureSelectItemVisible() {
    if (!_selectScrollController.hasClients) return;
    const itemHeight = 32.0;
    final targetOffset = _selectHighlightedIndex * itemHeight;
    final viewportHeight = _selectScrollController.position.viewportDimension;
    final currentOffset = _selectScrollController.offset;

    if (targetOffset < currentOffset) {
      _selectScrollController.jumpTo(targetOffset);
    } else if (targetOffset + itemHeight > currentOffset + viewportHeight) {
      _selectScrollController.jumpTo(
        targetOffset + itemHeight - viewportHeight,
      );
    }
  }

  /// Builds the select editor dropdown overlay widget.
  ///
  /// Widget construction lives in [SelectEditorOverlay] (plain) and
  /// [RichSelectEditorOverlay] (searchable); this factory only reads session
  /// state and dispatches on the editor kind.
  Widget buildSelectEditorOverlay() {
    final col = _editingColDef;
    if (col?.cellEditor is! OsSelectCellEditor) return const SizedBox.shrink();
    final selectEditor = col!.cellEditor as OsSelectCellEditor;
    if (selectEditor is OsRichSelectCellEditor) {
      return RichSelectEditorOverlay(
        cellRect: _editCellRect!,
        editor: selectEditor,
        values: _richFilteredValues,
        highlightedIndex: _selectHighlightedIndex,
        originalValue: _editOriginalValue,
        scrollController: _selectScrollController,
        selectFocusNode: _selectFocusNode,
        onKeyEvent: _handleRichSelectKeyEvent,
        searchController: _richSearchController,
        searchFocusNode: _richSearchFocusNode,
        onSearchChanged: _onRichSearchChanged,
        onSelect: _commitSelectEdit,
        onHoverIndex: (index) => _mutate(() => _selectHighlightedIndex = index),
        theme: _theme(),
      );
    }
    return SelectEditorOverlay(
      cellRect: _editCellRect!,
      editor: selectEditor,
      values: selectEditor.values,
      highlightedIndex: _selectHighlightedIndex,
      originalValue: _editOriginalValue,
      scrollController: _selectScrollController,
      focusNode: _selectFocusNode,
      onKeyEvent: _handleSelectKeyEvent,
      onSelect: _commitSelectEdit,
      onHoverIndex: (index) => _mutate(() => _selectHighlightedIndex = index),
      theme: _theme(),
    );
  }

  /// Handles changes to the rich-select search input, re-filtering the list
  /// after [OsRichSelectCellEditor.debounceMs].
  void _onRichSearchChanged(String query) {
    final col = _editingColDef;
    if (!_isSelectEditing || col?.cellEditor is! OsRichSelectCellEditor) return;
    final editor = col!.cellEditor as OsRichSelectCellEditor;

    _richDebounceTimer?.cancel();
    void applyFilter() {
      if (!_isSelectEditing || _editCellRect == null) return;
      final q = query.toLowerCase();
      _mutate(() {
        _richFilteredValues = _richResolvedValues
            .where((v) => (v?.toString() ?? '').toLowerCase().contains(q))
            .toList(growable: false);
        _selectHighlightedIndex = 0;
      });
    }

    if (editor.debounceMs <= 0) {
      applyFilter();
    } else {
      _richDebounceTimer = Timer(
        Duration(milliseconds: editor.debounceMs),
        applyFilter,
      );
    }
  }

  /// Resolves the checkbox cell value injected into a row's display map
  /// under [SpecialColumns.checkbox].
  ///
  /// Returns a single-entry map holding the tri-state `bool?` value:
  /// - `true` if the row is selected
  /// - `false` if the row is not selected and should show a checkbox
  /// - `null` if the row is not selectable and should show a disabled
  ///   checkbox (greyed out)
  ///
  /// Returns an empty map when the checkbox is hidden entirely for this row
  /// (checkboxesCallback returns false, or hideDisabledCheckboxes hides a
  /// non-selectable row) — the key is omitted so nothing is painted.
  Map<String, dynamic> resolveCheckboxCell(
    Map<String, dynamic> rowData,
    int displayIndex,
  ) {
    final selection = _rowSelection();
    if (selection == null) return const {};

    // Check if the checkboxesCallback hides this row's checkbox
    if (selection.checkboxesCallback != null) {
      if (!selection.checkboxesCallback!(rowData, displayIndex)) {
        return const {}; // Hidden — callback says no checkbox for this row
      }
    }

    // Check if the row is selectable
    final isSelectable =
        selection.isRowSelectable == null ||
        selection.isRowSelectable!(rowData);

    if (!isSelectable) {
      // Row is not selectable — hide or disable the checkbox
      if (selection.hideDisabledCheckboxes) {
        return const {}; // Hidden
      }
      return const {SpecialColumns.checkbox: null}; // Disabled (greyed out)
    }

    // Normal case: show checked or unchecked
    return {SpecialColumns.checkbox: _controller.isRowSelected(displayIndex)};
  }

  /// Toggles a checkbox cell value in-place (no overlay editor).
  ///
  /// Mirrors OS Grid's CheckboxCellRenderer behaviour: fires
  /// cellEditingStarted, sets the new value, fires cellEditingStopped.
  /// Supports readOnlyEdit mode (fires cellEditRequest instead of mutating).
  void toggleCheckboxCell(
    int rowIndex,
    OsColumnDef col,
    OsCheckboxCellEditor editor,
    TData rowData,
  ) {
    dynamic oldValue;
    if (col.field != null && rowData is Map<String, dynamic>) {
      oldValue = rowData[col.field];
    }

    final newValue = editor.nextValue(oldValue);

    // Emit cellEditingStarted event
    final startEvent = OsCellEditingStartedEvent<TData>(
      data: rowData,
      rowIndex: rowIndex,
      colDef: OsColumnDef<TData>(field: col.field, headerName: col.headerName),
      value: oldValue,
    );
    _onCellEditingStarted?.call(startEvent);
    _controller.emitCellEditingStarted(startEvent);
    _undoRedoService()?.onCellEditingStarted();

    // readOnlyEdit mode: fire cellEditRequest instead of mutating data
    if (_readOnlyEdit()) {
      final requestEvent = OsCellEditRequestEvent<TData>(
        data: rowData,
        rowIndex: rowIndex,
        colDef: OsColumnDef<TData>(
          field: col.field,
          headerName: col.headerName,
        ),
        oldValue: oldValue,
        newValue: newValue,
        source: 'checkboxToggle',
      );
      _onCellEditRequest?.call(requestEvent);
      _controller.emitCellEditRequest(requestEvent);

      // Emit cellEditingStopped (cancelled since we didn't mutate)
      final stopEvent = OsCellEditingStoppedEvent<TData>(
        data: rowData,
        rowIndex: rowIndex,
        colDef: OsColumnDef<TData>(
          field: col.field,
          headerName: col.headerName,
        ),
        oldValue: oldValue,
        newValue: newValue,
        cancelled: false,
      );
      _onCellEditingStopped?.call(stopEvent);
      _controller.emitCellEditingStopped(stopEvent);
      return;
    }

    // Write the new value using valueSetter or default Map write
    bool dataChanged;
    if ((col as dynamic).valueSetter != null) {
      dataChanged = ((col as dynamic).valueSetter as Function)(
        ValueSetterParams<TData>(
          data: rowData,
          colDef: OsColumnDef<TData>(
            field: col.field,
            headerName: col.headerName,
          ),
          oldValue: oldValue,
          newValue: newValue,
          rowIndex: rowIndex,
          source: 'checkboxToggle',
        ),
      );
    } else if (rowData is Map<String, dynamic> && col.field != null) {
      (rowData as Map<String, dynamic>)[col.field!] = newValue;
      dataChanged = true;
    } else {
      dataChanged = false;
    }

    if (dataChanged && oldValue != newValue && col.field != null) {
      // Notify undo/redo service of the value change
      _undoRedoService()?.onCellValueChanged(
        rowIndex: rowIndex,
        rowId: _controller.rowIdFor(rowData),
        columnId: col.field!,
        oldValue: oldValue,
        newValue: newValue,
      );
    }

    // Notify undo/redo service that editing stopped
    _undoRedoService()?.onCellEditingStopped(
      valueChanged: dataChanged && oldValue != newValue,
    );

    // Emit cellEditingStopped event
    final stopEvent = OsCellEditingStoppedEvent<TData>(
      data: rowData,
      rowIndex: rowIndex,
      colDef: OsColumnDef<TData>(field: col.field, headerName: col.headerName),
      oldValue: oldValue,
      newValue: dataChanged ? newValue : oldValue,
      cancelled: !dataChanged,
    );
    _onCellEditingStopped?.call(stopEvent);
    _controller.emitCellEditingStopped(stopEvent);

    if (dataChanged && oldValue != newValue) {
      // Emit cellValueChanged event
      final event = OsCellValueChangedEvent<TData>(
        data: rowData,
        rowIndex: rowIndex,
        colDef: OsColumnDef<TData>(
          field: col.field,
          headerName: col.headerName,
        ),
        oldValue: oldValue,
        newValue: newValue,
      );
      _onCellValueChanged?.call(event);
      _controller.emitCellValueChanged(event);
    }

    // Trigger repaint
    _mutate(() {});
  }

  /// Handles keyboard-initiated edit requests from VirtualisedGrid.
  void handleEditStartRequested(
    int rowIndex,
    int columnIndex,
    String triggerKey,
  ) {
    final effectiveData = _resolveRows();
    if (effectiveData == null || rowIndex >= effectiveData.length) return;
    if (columnIndex >= _flatColumnsCache().length) return;

    final col = _flatColumnsCache()[columnIndex];
    final row = effectiveData[rowIndex];

    // Check editability — non-editable cells ignore keyboard triggers
    if (!_isCellEditableFn(col, row, rowIndex)) return;

    // Get the cell value
    dynamic value;
    if (col.field != null && row is Map<String, dynamic>) {
      value = row[col.field];
    }

    final hit = DataCellHit(
      rowIndex: rowIndex,
      columnIndex: columnIndex,
      colDef: col,
      value: value,
    );

    final cellRect = calculateCellRect(rowIndex, columnIndex);
    if (cellRect != null) {
      handleCellEditRequest(hit, cellRect, triggerKey: triggerKey);
    }
  }

  /// Resolves the currently edited session row from [effectiveData].
  ///
  /// Prefers the row object captured at session start (AG Grid binds edits
  /// to row nodes): if the dataset was reordered/filtered/transactioned
  /// since the session opened, the recorded index may now point at a
  /// different row. Returns the row and its CURRENT index, or null when the
  /// row was removed from the dataset or no valid session position exists.
  (TData, int)? _resolveSessionRow(List<TData> effectiveData) {
    final sessionRow = _sessionRow;
    if (sessionRow != null) {
      final idx = effectiveData.indexWhere((r) => identical(r, sessionRow));
      if (idx < 0) return null;
      return (effectiveData[idx], idx);
    }
    if (_editRowIndex == null || _editRowIndex! >= effectiveData.length) {
      return null;
    }
    return (effectiveData[_editRowIndex!], _editRowIndex!);
  }

  void commitEdit() {
    if (_editRowIndex == null || _editField == null) return;

    final effectiveData = _resolveRows();
    if (effectiveData == null) return;

    // Resolve the edited row by IDENTITY (AG Grid binds edits to row nodes):
    // if the dataset was reordered/filtered/transactioned since the session
    // opened, the original index may now point at a different row.
    final originalIndex = _editRowIndex!;
    var rowIndex = originalIndex;
    late final TData row;
    var rowRemoved = false;
    if (_sessionRow != null) {
      final idx = effectiveData.indexWhere((r) => identical(r, _sessionRow));
      if (idx >= 0) {
        rowIndex = idx;
        row = effectiveData[idx];
      } else {
        rowRemoved = true;
      }
    } else {
      if (originalIndex >= effectiveData.length) return;
      row = effectiveData[originalIndex];
    }

    if (rowRemoved) {
      // The edited row no longer exists — discard the input the way AG Grid
      // does when a node is removed mid-edit: no write, cancelled stop event.
      _undoRedoService()?.onCellEditingStopped(valueChanged: false);
      final stopEvent = OsCellEditingStoppedEvent<TData>(
        data: _sessionRow as TData,
        rowIndex: originalIndex,
        colDef: OsColumnDef<TData>(field: _editField),
        oldValue: _editOriginalValue,
        newValue: _editOriginalValue,
        cancelled: true,
      );
      _onCellEditingStopped?.call(stopEvent);
      _controller.emitCellEditingStopped(stopEvent);
      _closeEditOverlay();
      return;
    }

    final col = _editingColDef;
    final oldValue = _editOriginalValue;
    final rawText = _editTextController.text;

    // Parse value using valueParser or default type inference
    dynamic parsedValue;
    if ((col as dynamic)?.valueParser != null) {
      parsedValue = ((col as dynamic).valueParser as Function)(
        ValueParserParams<TData>(
          data: row,
          colDef: col!,
          oldValue: oldValue,
          newValue: rawText,
          rowIndex: rowIndex,
          source: 'edit',
        ),
      );
    } else if (col?.cellEditor is OsDateCellEditor) {
      // Date editor: parse text as DateTime, validate constraints.
      final dateEditor = col!.cellEditor as OsDateCellEditor;
      if (rawText.isEmpty) {
        parsedValue = null;
      } else {
        final parsed = OsDateCellEditor.parseDate(rawText);
        if (parsed != null) {
          final errors = dateEditor.validate(parsed);
          if (errors == null) {
            parsedValue = parsed;
          } else {
            // Validation failed — revert to original value (don't commit).
            parsedValue = oldValue;
          }
        } else {
          // Unparseable text — revert to original value.
          parsedValue = oldValue;
        }
      }
    } else if (col?.cellEditor is OsDateStringCellEditor) {
      // Date string editor (text-input fallback): parse text, validate, format back.
      final dateStringEditor = col!.cellEditor as OsDateStringCellEditor;
      if (rawText.isEmpty) {
        parsedValue = null;
      } else {
        final parsed = dateStringEditor.parseCellValue(rawText);
        if (parsed != null) {
          final errors = dateStringEditor.validate(parsed);
          if (errors == null) {
            parsedValue = dateStringEditor.formatDate(parsed);
          } else {
            // Validation failed — revert to original value.
            parsedValue = oldValue;
          }
        } else {
          // Unparseable text — revert to original value.
          parsedValue = oldValue;
        }
      }
    } else {
      parsedValue = _tryParseValue(oldValue, rawText);
    }

    // Check if value actually changed
    final valueChanged = !editValuesEqual(oldValue, parsedValue);

    if (valueChanged) {
      // readOnlyEdit mode: fire cellEditRequest instead of writing to data
      if (_readOnlyEdit()) {
        final requestEvent = OsCellEditRequestEvent<TData>(
          data: row,
          rowIndex: rowIndex,
          colDef: OsColumnDef<TData>(field: _editField),
          oldValue: oldValue,
          newValue: parsedValue,
          source: 'edit',
        );
        _onCellEditRequest?.call(requestEvent);
        _controller.emitCellEditRequest(requestEvent);
      } else {
        // Write value using valueSetter or default Map write
        bool dataChanged;
        if ((col as dynamic)?.valueSetter != null) {
          dataChanged = ((col as dynamic).valueSetter as Function)(
            ValueSetterParams<TData>(
              data: row,
              colDef: col!,
              oldValue: oldValue,
              newValue: parsedValue,
              rowIndex: rowIndex,
              source: 'edit',
            ),
          );
        } else if (row is Map<String, dynamic> && _editField != null) {
          (row as Map<String, dynamic>)[_editField!] = parsedValue;
          dataChanged = true;
        } else {
          dataChanged = false;
        }

        if (dataChanged) {
          // Invalidate TextPainter cache for the edited row
          _textPainterCache.clearRow(rowIndex);

          // Notify undo/redo service of the value change
          _undoRedoService()?.onCellValueChanged(
            rowIndex: rowIndex,
            rowId: _controller.rowIdFor(row),
            columnId: _editField!,
            oldValue: oldValue,
            newValue: parsedValue,
          );

          // Emit cellValueChanged event
          final event = OsCellValueChangedEvent<TData>(
            data: row,
            rowIndex: rowIndex,
            colDef: OsColumnDef<TData>(field: _editField),
            oldValue: oldValue,
            newValue: parsedValue,
          );
          _onCellValueChanged?.call(event);
          _controller.emitCellValueChanged(event);
        }
      }
    }

    // Notify undo/redo service that editing stopped
    _undoRedoService()?.onCellEditingStopped(
      valueChanged: valueChanged && !_readOnlyEdit(),
    );

    // Emit cellEditingStopped event (committed)
    final stopEvent = OsCellEditingStoppedEvent<TData>(
      data: row,
      rowIndex: rowIndex,
      colDef: OsColumnDef<TData>(field: _editField),
      oldValue: oldValue,
      newValue: parsedValue,
      cancelled: false,
    );
    _onCellEditingStopped?.call(stopEvent);
    _controller.emitCellEditingStopped(stopEvent);

    _closeEditOverlay();
  }

  /// Cancels the current edit, reverting to the original value.
  /// Called when the user presses Escape.
  void cancelEditRevert() {
    if (_editCellRect == null || _editRowIndex == null) return;

    // Prefer the captured session row so a removed row still yields a
    // meaningful cancelled-stop event payload.
    final effectiveData = _resolveRows();
    final row =
        _sessionRow ??
        ((effectiveData != null && _editRowIndex! < effectiveData.length)
            ? effectiveData[_editRowIndex!]
            : null);

    // Notify undo/redo service that editing was cancelled (no value change)
    _undoRedoService()?.onCellEditingStopped(valueChanged: false);

    // Emit cellEditingStopped event (cancelled)
    if (row != null) {
      final stopEvent = OsCellEditingStoppedEvent<TData>(
        data: row,
        rowIndex: _editRowIndex!,
        colDef: OsColumnDef<TData>(field: _editField),
        oldValue: _editOriginalValue,
        newValue: _editOriginalValue,
        cancelled: true,
      );
      _onCellEditingStopped?.call(stopEvent);
      _controller.emitCellEditingStopped(stopEvent);
    }

    _closeEditOverlay();
  }

  /// Closes the edit overlay without committing or emitting events.
  void _closeEditOverlay() {
    if (_editCellRect == null) return;
    _richDebounceTimer?.cancel();
    _richDebounceTimer = null;
    _mutate(() {
      _editCellRect = null;
      _editRowIndex = null;
      _editColIndex = null;
      _editField = null;
      _editOriginalValue = null;
      _editingColDef = null;
      _sessionRow = null;
      _isSelectEditing = false;
      _isCustomEditing = false;
      _isLargeTextEditing = false;
      _isDateEditing = false;
      _customEditorValue = null;
      _richResolvedValues = const [];
      _richFilteredValues = const [];
    });
    _richSearchController.clear();
  }

  /// Commits the current edit and navigates to the next editable cell.
  /// Called when Tab is pressed during editing.
  void _commitAndNavigateToNextCell({bool backwards = false}) {
    if (_editRowIndex == null || _editColIndex == null) return;

    final currentRowIndex = _editRowIndex!;
    final currentColIndex = _editColIndex!;

    // Commit the current edit
    commitEdit();

    // Find the default next editable cell
    final nextCell = _findNextEditableCell(
      currentRowIndex,
      currentColIndex,
      backwards: backwards,
    );

    // Consult the custom tabToNextCell callback when provided. Returning
    // null falls back to the built-in behaviour below.
    final tabCallback = _tabToNextCell;
    if (tabCallback != null) {
      final effectiveData = _resolveRows();
      final maxRow = effectiveData == null || effectiveData.isEmpty
          ? currentRowIndex
          : effectiveData.length - 1;
      final overridden = tabCallback(
        TabToNextCellParams(
          previousCell: NavCellPosition(
            rowIndex: currentRowIndex,
            columnIndex: currentColIndex,
          ),
          nextCell: NavCellPosition(
            rowIndex: (nextCell?.$1 ?? currentRowIndex).clamp(0, maxRow),
            columnIndex: nextCell?.$2 ?? currentColIndex,
          ),
          key: backwards ? 'shift+tab' : 'tab',
          shift: backwards,
        ),
      );
      if (overridden != null) {
        startEditingCellAt(
          overridden.rowIndex.clamp(0, maxRow),
          overridden.columnIndex,
        );
        return;
      }
    }

    if (nextCell != null) {
      // Start editing the next cell
      startEditingCellAt(nextCell.$1, nextCell.$2);
    }
  }

  /// Commits the current edit and navigates vertically (up or down).
  /// Called when Enter is pressed during editing with
  /// `enterNavigatesVerticallyAfterEdit` enabled.
  void commitAndNavigateVertically({bool up = false}) {
    if (_editRowIndex == null || _editColIndex == null) return;

    final currentRowIndex = _editRowIndex!;
    final currentColIndex = _editColIndex!;

    // Commit the current edit
    commitEdit();

    // Navigate to the cell above or below in the same column
    final effectiveData = _resolveRows();
    if (effectiveData == null) return;

    final nextRow = up ? currentRowIndex - 1 : currentRowIndex + 1;
    if (nextRow < 0 || nextRow >= effectiveData.length) return;

    // Start editing the cell in the same column, next row
    startEditingCellAt(nextRow, currentColIndex);
  }

  /// Finds the next (or previous) editable cell from the given position.
  /// Scans columns in the current row first, then wraps to subsequent rows.
  /// Returns (rowIndex, columnIndex) or null if no editable cell found.
  (int, int)? _findNextEditableCell(
    int fromRow,
    int fromCol, {
    bool backwards = false,
  }) {
    final flatCols = <OsColumnDef>[];
    final tempSpans = <ColumnGroupSpan>[];
    _flattenColumnDefs(_columnDefs(), flatCols, tempSpans);

    // Filter to visible columns only
    final displayOrder =
        _columnOrder() ?? flatCols.map((c) => c.effectiveColId).toList();
    final visibleOrder = displayOrder
        .where((id) => !_hiddenColumnIds().contains(id))
        .toList();
    final visibleCols = visibleOrder
        .map(
          (id) => flatCols.cast<OsColumnDef?>().firstWhere(
            (c) => c!.effectiveColId == id,
            orElse: () => null,
          ),
        )
        .whereType<OsColumnDef>()
        .toList();

    // Account for prepended columns (checkbox, row numbers)
    int offset = 0;
    if (_rowSelection()?.hasCheckboxes == true) offset++;
    if (_rowNumbers()) offset++;
    if (_rowDrag()) offset++;

    final effectiveData = _resolveRows();
    if (effectiveData == null || effectiveData.isEmpty) return null;

    final totalRows = effectiveData.length;
    final totalCols = visibleCols.length;
    if (totalCols == 0) return null;

    // Convert from display column index (which includes offset) to data column index
    final dataColIndex = fromCol - offset;

    // Iterate through cells in order
    int row = fromRow;
    int col = dataColIndex;

    // Move to the next position first
    if (backwards) {
      col--;
      if (col < 0) {
        col = totalCols - 1;
        row--;
      }
    } else {
      col++;
      if (col >= totalCols) {
        col = 0;
        row++;
      }
    }

    // Search through all cells (wrap around once)
    final totalCells = totalRows * totalCols;
    for (int i = 0; i < totalCells; i++) {
      if (row < 0 || row >= totalRows) break;

      final colDef = visibleCols[col];
      final rowData = effectiveData[row];
      if (_isCellEditableFn(colDef, rowData, row)) {
        return (row, col + offset);
      }

      // Move to next position
      if (backwards) {
        col--;
        if (col < 0) {
          col = totalCols - 1;
          row--;
        }
      } else {
        col++;
        if (col >= totalCols) {
          col = 0;
          row++;
        }
      }
    }

    return null;
  }

  /// Starts editing a cell at the given row and column display index.
  /// Used by Tab navigation and the controller's startEditingCell API.
  void startEditingCellAt(int rowIndex, int columnIndex) {
    final effectiveData = _resolveRows();
    if (effectiveData == null || rowIndex >= effectiveData.length) return;

    // Resolve the column definition
    final flatCols = <OsColumnDef>[];
    final tempSpans = <ColumnGroupSpan>[];
    _flattenColumnDefs(_columnDefs(), flatCols, tempSpans);

    final displayOrder =
        _columnOrder() ?? flatCols.map((c) => c.effectiveColId).toList();
    final visibleOrder = displayOrder
        .where((id) => !_hiddenColumnIds().contains(id))
        .toList();
    final visibleCols = visibleOrder
        .map(
          (id) => flatCols.cast<OsColumnDef?>().firstWhere(
            (c) => c!.effectiveColId == id,
            orElse: () => null,
          ),
        )
        .whereType<OsColumnDef>()
        .toList();

    // Account for prepended columns
    int offset = 0;
    if (_rowSelection()?.hasCheckboxes == true) offset++;
    if (_rowNumbers()) offset++;
    if (_rowDrag()) offset++;

    final dataColIndex = columnIndex - offset;
    if (dataColIndex < 0 || dataColIndex >= visibleCols.length) return;

    final col = visibleCols[dataColIndex];
    final row = effectiveData[rowIndex];

    // Get the cell value
    dynamic value;
    if (col.field != null && row is Map<String, dynamic>) {
      value = row[col.field];
    }

    // Calculate cell rect — we need the VirtualisedGrid's scroll state
    // Use a synthetic DataCellHit and call handleCellEditRequest
    final hit = DataCellHit(
      rowIndex: rowIndex,
      columnIndex: columnIndex,
      colDef: col,
      value: value,
    );

    // Calculate the cell rect (approximate — uses current scroll position)
    final cellRect = calculateCellRect(rowIndex, columnIndex);
    if (cellRect != null) {
      handleCellEditRequest(hit, cellRect);
    }
  }

  /// Calculates the cell rect for a given row and column index.
  /// Returns null if the cell is not currently visible.
  Rect? calculateCellRect(int rowIndex, int columnIndex) {
    // We need to access the VirtualisedGrid's scroll state.
    // Since we don't have direct access, we'll compute from the grid layout.
    // The VirtualisedGrid passes the cellRect when it triggers editing,
    // but for programmatic editing we need to compute it ourselves.
    //
    // For now, use a simplified calculation based on the grid's layout.
    final flatCols = <OsColumnDef>[];
    final tempSpans = <ColumnGroupSpan>[];
    _flattenColumnDefs(_columnDefs(), flatCols, tempSpans);

    final displayOrder =
        _columnOrder() ?? flatCols.map((c) => c.effectiveColId).toList();
    final visibleOrder = displayOrder
        .where((id) => !_hiddenColumnIds().contains(id))
        .toList();

    // Build column widths list (including prepended columns)
    final colWidths = <double>[];
    if (_rowSelection()?.hasCheckboxes == true) {
      colWidths.add(32);
    }
    if (_rowNumbers()) {
      colWidths.add(42);
    }
    for (int i = 0; i < visibleOrder.length; i++) {
      final colId = visibleOrder[i];
      final col = flatCols.cast<OsColumnDef?>().firstWhere(
        (c) => c!.effectiveColId == colId,
        orElse: () => null,
      );
      final width = _columnWidths()[colId] ?? col?.width ?? 150.0;
      colWidths.add(width);
    }

    if (columnIndex >= colWidths.length) return null;

    // Calculate X position
    double colX = 0;
    for (int c = 0; c < columnIndex; c++) {
      colX += colWidths[c];
    }
    final colWidth = colWidths[columnIndex];

    // Calculate Y position (header height + floating filter + row offset)
    final floatingH = _floatingFilter() ? _floatingFilterHeight() : 0.0;
    final rowTop =
        _effectiveHeaderHeight() +
        floatingH +
        (rowIndex * _effectiveRowHeight());

    return Rect.fromLTWH(colX, rowTop, colWidth, _effectiveRowHeight());
  }

  /// Handles keyboard events during cell editing.
  /// Returns KeyEventResult.handled if the event was consumed.
  KeyEventResult handleEditKeyEvent(KeyEvent event) {
    if (_editCellRect == null) return KeyEventResult.ignored;

    // Delegate to select editor handler if in select mode
    if (_isSelectEditing) {
      return _handleSelectKeyEvent(event);
    }

    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        cancelEditRevert();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.tab) {
        final isShiftHeld = HardwareKeyboard.instance.logicalKeysPressed.any(
          (key) =>
              key == LogicalKeyboardKey.shiftLeft ||
              key == LogicalKeyboardKey.shiftRight,
        );
        _commitAndNavigateToNextCell(backwards: isShiftHeld);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.enter) {
        if (_enterNavigatesVerticallyAfterEdit()) {
          final isShiftHeld = HardwareKeyboard.instance.logicalKeysPressed.any(
            (key) =>
                key == LogicalKeyboardKey.shiftLeft ||
                key == LogicalKeyboardKey.shiftRight,
          );
          commitAndNavigateVertically(up: isShiftHeld);
        } else {
          commitEdit();
        }
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  void _onEditFocusChanged() {
    if (_editFocusNode.hasFocus && _pendingEditSelection != null) {
      // Apply the pending selection now that focus is established.
      // Use a microtask to ensure TextField's internal focus handling
      // (which selects all) has completed first.
      final selection = _pendingEditSelection!;
      _pendingEditSelection = null;
      Future.microtask(() {
        if (_mounted() && _editCellRect != null) {
          _editTextController.selection = selection;
        }
      });
    } else if (!_editFocusNode.hasFocus && _editCellRect != null) {
      if (_stopEditingWhenCellsLoseFocus()) {
        commitEdit();
      }
      // When stopEditingWhenCellsLoseFocus is false (default), editing
      // persists until explicit commit (Enter/Tab) or cancel (Escape).
    }
  }

  /// Try to preserve the original type when parsing the edited string.
  dynamic _tryParseValue(dynamic originalValue, String newText) {
    if (originalValue is int) return int.tryParse(newText) ?? newText;
    if (originalValue is double) return double.tryParse(newText) ?? newText;
    if (originalValue is num) return num.tryParse(newText) ?? newText;
    return newText;
  }
}
