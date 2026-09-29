import 'package:flutter/material.dart';

import '../columns/os_column_def.dart';
import '../columns/os_column_pin.dart';
import '../filtering/filter_evaluator.dart';
import '../filtering/filter_model.dart';
import '../filtering/os_custom_filter.dart';
import '../filtering/os_date_filter.dart';
import '../filtering/os_number_filter.dart';
import '../filtering/os_set_filter.dart';
import '../filtering/os_text_filter.dart';
import '../locale/os_locale_text.dart';
import '../menu/column_menu_popup.dart';
import '../menu/os_column_menu_def.dart';
import '../menu/tabbed_column_menu.dart';
import '../rendering/column_group_layout.dart';
import '../rendering/grid_hit_test.dart';
import '../sorting/sort_direction.dart';
import '../theming/os_grid_theme.dart';

/// Owns the popup/filter/menu overlay UI state for the grid.
///
/// Extracted from `_OsGridState`. The coordinator owns:
///
/// - the filter popup visibility/anchor/target state;
/// - the floating-filter inline input overlay state;
/// - a small reuse pool of floating-filter input popups so fast scrolling
///   across many columns recycles popup entries instead of rebuilding the
///   input from scratch on every tap;
/// - the per-column filter display texts and operation types shown in
///   painted floating-filter cells;
/// - the column menu popup visibility/anchor/target state;
///
/// plus the show/dismiss/handler methods driving them.
///
/// All grid-owned collaborators are supplied as closures/getters so they
/// always read live state from the owning `State` (same closure pattern as
/// the editing coordinator); widget-config getters honour `didUpdateWidget`
/// replacements without recreating the coordinator.
class PopupUiCoordinator {
  /// Creates a coordinator.
  ///
  /// [mutate] wraps the owning State's `setState`. The `onXxx` getters
  /// supply live collaborators owned by the State (editing session,
  /// floating-filter text input, typed filter models) and the callbacks
  /// keep side effects that belong to other coordinators (data pipeline,
  /// filter event emission, column API) in their owners.
  PopupUiCoordinator({
    required void Function(VoidCallback) mutate,
    required bool Function() hasActiveEdit,
    required VoidCallback commitEdit,
    required TextEditingController Function() floatingFilterTextController,
    required FocusNode Function() floatingFilterFocusNode,
    required Map<String, OsColumnFilterModel> Function() columnFilterModels,
    required List<OsColumnDefBase> Function() columnDefs,
    required OsColumnMenuDef? Function() columnMenu,
    required OsGridTheme? Function() theme,
    required OsLocaleText? Function() localeText,
    required List<OsColumnDef> Function() flatColumnsCache,
    required Set<String> Function() hiddenIds,
    required OsSortDirection? Function(int columnIndex) columnSortDirection,
    required void Function(
      List<OsColumnDefBase> defs,
      List<OsColumnDef> outColumns,
      List<ColumnGroupSpan> outSpans,
    )
    flattenColumnDefs,
    required VoidCallback reprocessData,
    required VoidCallback emitFilterChangedEvent,
    required void Function(String colId, OsColumnFilterModel? model)
    onFilterPopupApply,
    required void Function(String colId, bool visible)
    onColumnVisibilityChanged,
    required void Function(int columnIndex, {bool ascending, bool clear})
    applySortFromMenu,
    required void Function(int columnIndex, OsColumnPin? pin) applyPinFromMenu,
    required void Function(int columnIndex) autosizeColumn,
    required VoidCallback autosizeAllColumns,
    required VoidCallback resetColumns,
  }) : _mutate = mutate,
       _hasActiveEdit = hasActiveEdit,
       _commitEdit = commitEdit,
       _floatingFilterTextController = floatingFilterTextController,
       _floatingFilterFocusNode = floatingFilterFocusNode,
       _columnFilterModels = columnFilterModels,
       _columnDefs = columnDefs,
       _columnMenuDef = columnMenu,
       _theme = theme,
       _localeText = localeText,
       _flatColumnsCache = flatColumnsCache,
       _hiddenIds = hiddenIds,
       _columnSortDirection = columnSortDirection,
       _flattenColumnDefs = flattenColumnDefs,
       _reprocessData = reprocessData,
       _emitFilterChangedEvent = emitFilterChangedEvent,
       _onFilterPopupApply = onFilterPopupApply,
       _onColumnVisibilityChanged = onColumnVisibilityChanged,
       _applySortFromMenu = applySortFromMenu,
       _applyPinFromMenu = applyPinFromMenu,
       _autosizeColumn = autosizeColumn,
       _autosizeAllColumns = autosizeAllColumns,
       _resetColumns = resetColumns;

  final void Function(VoidCallback) _mutate;
  final bool Function() _hasActiveEdit;
  final VoidCallback _commitEdit;
  final TextEditingController Function() _floatingFilterTextController;
  final FocusNode Function() _floatingFilterFocusNode;
  final Map<String, OsColumnFilterModel> Function() _columnFilterModels;
  final List<OsColumnDefBase> Function() _columnDefs;
  final OsColumnMenuDef? Function() _columnMenuDef;
  final OsGridTheme? Function() _theme;
  final OsLocaleText? Function() _localeText;
  final List<OsColumnDef> Function() _flatColumnsCache;
  final Set<String> Function() _hiddenIds;
  final OsSortDirection? Function(int columnIndex) _columnSortDirection;
  final void Function(
    List<OsColumnDefBase> defs,
    List<OsColumnDef> outColumns,
    List<ColumnGroupSpan> outSpans,
  )
  _flattenColumnDefs;
  final VoidCallback _reprocessData;
  final VoidCallback _emitFilterChangedEvent;
  final void Function(String colId, OsColumnFilterModel? model)
  _onFilterPopupApply;
  final void Function(String colId, bool visible) _onColumnVisibilityChanged;
  final void Function(int columnIndex, {bool ascending, bool clear})
  _applySortFromMenu;
  final void Function(int columnIndex, OsColumnPin? pin) _applyPinFromMenu;
  final void Function(int columnIndex) _autosizeColumn;
  final VoidCallback _autosizeAllColumns;
  final VoidCallback _resetColumns;

  // --- Owned popup/filter/menu UI state ---

  /// Per-column filter text (colId → filter text) for display in painted cells.
  final Map<String, String> _columnFilterTexts = {};

  /// Per-column active operation type (colId → operation type string).
  /// Tracks the currently selected operation for each column's floating filter.
  final Map<String, String> _columnFilterOperations = {};

  /// Whether the filter popup is currently visible.
  bool _filterPopupVisible = false;

  /// The Rect (in local grid coordinates) where the popup should be anchored.
  Rect? _filterPopupAnchorRect;

  /// The column ID the filter popup is targeting.
  String? _filterPopupColId;

  /// The column definition the filter popup is targeting.
  OsColumnDef? _filterPopupColDef;

  /// Whether the column menu popup is currently visible.
  bool _columnMenuVisible = false;

  /// The Rect (in local grid coordinates) where the menu should be anchored.
  Rect? _columnMenuAnchorRect;

  /// The column index the menu is targeting.
  int? _columnMenuColIndex;

  /// The column definition the menu is targeting.
  OsColumnDef? _columnMenuColDef;

  /// Rect of the currently active floating filter input overlay.
  Rect? _floatingFilterRect;

  /// Column ID of the currently active floating filter input.
  String? _floatingFilterColId;

  /// Maximum number of floating-filter popup entries kept in the reuse pool.
  static const int _floatingFilterPopupPoolMax = 3;

  /// Idle floating-filter popup entries available for reuse.
  final List<FloatingFilterPopupEntry> _floatingFilterPopupPool = [];

  // --- Read access for the owning State's build method ---

  /// Per-column filter text for display in painted cells.
  ///
  /// The returned map is live: mutations made through it are visible to the
  /// coordinator and vice versa.
  Map<String, String> get columnFilterTexts => _columnFilterTexts;

  /// Per-column active operation type for each column's floating filter.
  ///
  /// The returned map is live: mutations made through it are visible to the
  /// coordinator and vice versa.
  Map<String, String> get columnFilterOperations => _columnFilterOperations;

  /// Whether the filter popup is currently visible.
  bool get filterPopupVisible => _filterPopupVisible;

  /// Anchor rect of the filter popup, or null when positioned by column.
  Rect? get filterPopupAnchorRect => _filterPopupAnchorRect;

  /// The column ID the filter popup is targeting.
  String? get filterPopupColId => _filterPopupColId;

  /// The column definition the filter popup is targeting.
  OsColumnDef? get filterPopupColDef => _filterPopupColDef;

  /// Whether the column menu popup is currently visible.
  bool get columnMenuVisible => _columnMenuVisible;

  /// Anchor rect of the column menu popup.
  Rect? get columnMenuAnchorRect => _columnMenuAnchorRect;

  /// The column index the menu is targeting.
  int? get columnMenuColIndex => _columnMenuColIndex;

  /// The column definition the menu is targeting.
  OsColumnDef? get columnMenuColDef => _columnMenuColDef;

  /// Rect of the currently active floating filter input overlay.
  Rect? get floatingFilterRect => _floatingFilterRect;

  // --- Floating filter interaction ---

  /// Handles a tap on a floating filter cell.
  void handleFloatingFilterTap(FloatingFilterCellHit hit, Rect cellRect) {
    // Only allow filtering on columns with a filter configured
    if (hit.colDef.filter == null) return;

    // Dismiss any active cell edit
    if (_hasActiveEdit()) _commitEdit();

    final colId = hit.colDef.effectiveColId;
    final filter = hit.colDef.filter!;

    // Custom and set filters open the popup directly (no inline text input)
    if (filter is OsCustomFilter || filter is OsSetFilter) {
      if (_floatingFilterRect != null) commitFloatingFilter();
      showFilterPopupForColumn(hit.colDef);
      return;
    }

    // Ensure we have an operation type for this column
    if (!_columnFilterOperations.containsKey(colId)) {
      _columnFilterOperations[colId] = getDefaultFilterType(filter);
    }

    _mutate(() {
      _floatingFilterRect = cellRect;
      _floatingFilterColId = colId;
      _floatingFilterTextController().text = _columnFilterTexts[colId] ?? '';
    });

    // Focus the text field after the frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _floatingFilterFocusNode().requestFocus();
      _floatingFilterTextController().selection = TextSelection(
        baseOffset: 0,
        extentOffset: _floatingFilterTextController().text.length,
      );
    });
  }

  /// Commits the active floating filter input and applies its model.
  void commitFloatingFilter() {
    if (_floatingFilterColId == null) return;

    final colId = _floatingFilterColId!;
    final text = _floatingFilterTextController().text.trim();
    final operationType = _columnFilterOperations[colId] ?? 'contains';

    // Update the per-column filter model
    if (text.isEmpty) {
      _columnFilterTexts.remove(colId);
      _columnFilterModels().remove(colId);
    } else {
      _columnFilterTexts[colId] = text;
      updateColumnFilterModel(colId, text, operationType);
    }

    cancelFloatingFilter();
    _reprocessData();
    _emitFilterChangedEvent();
  }

  /// Dismisses the floating filter input without applying anything further.
  void cancelFloatingFilter() {
    if (_floatingFilterRect == null) return;
    _mutate(() {
      _floatingFilterRect = null;
      _floatingFilterColId = null;
    });
  }

  // --- Floating filter popup reuse pool ---

  /// Number of floating-filter popup entries currently sitting in the pool.
  int get pooledFloatingFilterPopupCount => _floatingFilterPopupPool.length;

  /// Acquires a floating-filter popup entry anchored at [rect].
  ///
  /// Pops the most recently released entry from the pool (LIFO — the hottest
  /// entry) when one is available and otherwise creates a new one. The
  /// returned entry has an empty text buffer, a collapsed selection and an
  /// overlay tree positioned at [rect]; the caller mounts
  /// [FloatingFilterPopupEntry.overlay] to show the popup.
  FloatingFilterPopupEntry acquireFloatingFilterPopup(Rect rect) {
    final entry = _floatingFilterPopupPool.isNotEmpty
        ? _floatingFilterPopupPool.removeLast()
        : _createFloatingFilterPopupEntry();
    entry.controller
      ..clear()
      ..selection = const TextSelection.collapsed(offset: 0);
    entry.reposition(rect);
    return entry;
  }

  /// Returns a floating-filter popup entry to the pool after use.
  ///
  /// The entry's text is cleared; hiding happens by simply not mounting its
  /// overlay. When the pool is already at capacity the entry is disposed
  /// instead of pooled. Disposed or already-pooled entries are ignored so
  /// double releases are harmless.
  void releaseFloatingFilterPopup(FloatingFilterPopupEntry entry) {
    if (entry.isDisposed || _floatingFilterPopupPool.contains(entry)) return;
    entry.controller.clear();
    if (entry.focusNode.hasFocus) entry.focusNode.unfocus();
    if (_floatingFilterPopupPool.length >= _floatingFilterPopupPoolMax) {
      entry.dispose();
    } else {
      _floatingFilterPopupPool.add(entry);
    }
  }

  /// Disposes every pooled floating-filter popup entry and empties the pool.
  ///
  /// Called from the owning State's `dispose()` so pooled text controllers
  /// and focus nodes never outlive the grid. Entries currently checked out
  /// (acquired but not yet released) must be released before this is called.
  void dispose() {
    for (final entry in _floatingFilterPopupPool) {
      entry.dispose();
    }
    _floatingFilterPopupPool.clear();
  }

  FloatingFilterPopupEntry _createFloatingFilterPopupEntry() {
    return FloatingFilterPopupEntry(
      controller: TextEditingController(),
      focusNode: FocusNode(),
      overlayBuilder: _buildFloatingFilterPopupOverlay,
    );
  }

  /// Builds the positioned floating-filter input overlay for [entry].
  ///
  /// Mirrors the overlay inlined in the owning State's build method so the
  /// pooled popup is visually identical to a freshly-created one.
  Widget _buildFloatingFilterPopupOverlay(
    FloatingFilterPopupEntry entry,
    Rect rect,
  ) {
    final theme = _theme();
    return Positioned(
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      child: Container(
        decoration: BoxDecoration(
          color: theme?.backgroundColor ?? Colors.white,
          border: Border.all(
            color: theme?.accentColor ?? Colors.blue,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(3),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: EditableText(
          controller: entry.controller,
          focusNode: entry.focusNode,
          style:
              theme?.cellTextStyle?.copyWith(fontSize: 12) ??
              const TextStyle(fontSize: 12, color: Colors.black),
          cursorColor: theme?.accentColor ?? Colors.blue,
          backgroundCursorColor: Colors.grey,
          scrollPhysics: const NeverScrollableScrollPhysics(),
          onChanged: onFloatingFilterTextChanged,
          onSubmitted: (_) => commitFloatingFilter(),
        ),
      ),
    );
  }

  /// Updates the filter model in real time as the user types.
  void onFloatingFilterTextChanged(String text) {
    if (_floatingFilterColId == null) return;

    final colId = _floatingFilterColId!;
    final trimmed = text.trim();
    final operationType = _columnFilterOperations[colId] ?? 'contains';

    // Update filter model in real-time as user types
    if (trimmed.isEmpty) {
      _columnFilterTexts.remove(colId);
      _columnFilterModels().remove(colId);
    } else {
      _columnFilterTexts[colId] = trimmed;
      updateColumnFilterModel(colId, trimmed, operationType);
    }

    _mutate(() {
      _reprocessData();
    });
    _emitFilterChangedEvent();
  }

  /// Updates the filter model for a column based on the floating filter input.
  void updateColumnFilterModel(
    String colId,
    String filterText,
    String operationType,
  ) {
    // Determine the filter type from the column config
    final flatCols = <OsColumnDef>[];
    final tempSpans = <ColumnGroupSpan>[];
    _flattenColumnDefs(_columnDefs(), flatCols, tempSpans);
    final col = flatCols.cast<OsColumnDef?>().firstWhere(
      (c) => c!.effectiveColId == colId,
      orElse: () => null,
    );
    if (col == null) return;

    final filter = col.filter;
    String filterType = 'text';
    if (filter is OsTextFilter) {
      filterType = 'text';
    } else if (filter is OsNumberFilter) {
      filterType = 'number';
    } else if (filter is OsDateFilter) {
      filterType = 'date';
    }

    _columnFilterModels()[colId] = OsColumnFilterModel(
      filterType: filterType,
      conditions: [OsFilterCondition(type: operationType, filter: filterText)],
    );
  }

  /// Cycles the filter operation for the currently active floating filter column.
  ///
  /// Called when the user taps the operation indicator in the floating filter.
  ///
  /// Shows the filter popup for the column, allowing the user to select
  /// an operation and enter a filter value.
  void cycleFilterOperation(String colId) {
    final flatCols = <OsColumnDef>[];
    final tempSpans = <ColumnGroupSpan>[];
    _flattenColumnDefs(_columnDefs(), flatCols, tempSpans);
    final col = flatCols.cast<OsColumnDef?>().firstWhere(
      (c) => c!.effectiveColId == colId,
      orElse: () => null,
    );
    if (col == null || col.filter == null) return;

    // Dismiss any active floating filter input first
    if (_floatingFilterRect != null) commitFloatingFilter();

    // Show the filter popup anchored to the floating filter cell
    showFilterPopupForColumn(col);
  }

  /// Shows the filter popup when the header filter icon is tapped.
  void handleHeaderFilterIconTap(HeaderFilterIconHit hit, Rect iconRect) {
    // Dismiss any active overlays
    if (_hasActiveEdit()) _commitEdit();
    if (_floatingFilterRect != null) commitFloatingFilter();

    final col = hit.colDef;
    if (col.filter == null) return;

    _mutate(() {
      _filterPopupVisible = true;
      _filterPopupAnchorRect = iconRect;
      _filterPopupColId = col.effectiveColId;
      _filterPopupColDef = col;
    });
  }

  /// Shows the filter popup for a given column definition.
  void showFilterPopupForColumn(OsColumnDef col) {
    _mutate(() {
      _filterPopupVisible = true;
      // Anchor below the header — use a default rect if we don't have one
      _filterPopupAnchorRect = null; // Will be positioned based on column
      _filterPopupColId = col.effectiveColId;
      _filterPopupColDef = col;
    });
  }

  /// Dismisses the filter popup.
  void dismissFilterPopup() {
    if (!_filterPopupVisible) return;
    _mutate(() {
      _filterPopupVisible = false;
      _filterPopupAnchorRect = null;
      _filterPopupColId = null;
      _filterPopupColDef = null;
    });
  }

  // --- Column menu handlers ---

  /// Shows the column menu when the ⋮ icon is tapped.
  void handleHeaderMenuIconTap(HeaderMenuIconHit hit, Rect iconRect) {
    // Dismiss any active overlays
    if (_hasActiveEdit()) _commitEdit();
    if (_floatingFilterRect != null) commitFloatingFilter();
    if (_filterPopupVisible) dismissFilterPopup();

    _mutate(() {
      _columnMenuVisible = true;
      _columnMenuAnchorRect = iconRect;
      _columnMenuColIndex = hit.columnIndex;
      _columnMenuColDef = hit.colDef;
    });
  }

  /// Dismisses the column menu popup.
  void dismissColumnMenu() {
    if (!_columnMenuVisible) return;
    _mutate(() {
      _columnMenuVisible = false;
      _columnMenuAnchorRect = null;
      _columnMenuColIndex = null;
      _columnMenuColDef = null;
    });
  }

  /// Handles a column menu action.
  void handleColumnMenuAction(ColumnMenuEvent event) {
    dismissColumnMenu();

    switch (event.action) {
      case ColumnMenuAction.sortAscending:
        _applySortFromMenu(event.columnIndex, ascending: true);
      case ColumnMenuAction.sortDescending:
        _applySortFromMenu(event.columnIndex, ascending: false);
      case ColumnMenuAction.sortClear:
        _applySortFromMenu(event.columnIndex, clear: true);
      case ColumnMenuAction.pinLeft:
        _applyPinFromMenu(event.columnIndex, OsColumnPin.left);
      case ColumnMenuAction.pinRight:
        _applyPinFromMenu(event.columnIndex, OsColumnPin.right);
      case ColumnMenuAction.pinNone:
        _applyPinFromMenu(event.columnIndex, null);
      case ColumnMenuAction.autosizeThis:
        _autosizeColumn(event.columnIndex);
      case ColumnMenuAction.autosizeAll:
        _autosizeAllColumns();
      case ColumnMenuAction.resetColumns:
        _resetColumns();
    }
  }

  /// Builds the tabbed column menu widget.
  Widget buildTabbedColumnMenu(Size gridSize) {
    final menuDef = _columnMenuDef()!;
    final colDef = _columnMenuColDef!;
    final hasFilter = colDef.filter != null;
    final tabs = menuDef.effectiveTabs(hasFilter: hasFilter);
    final colId = colDef.effectiveColId;

    return TabbedColumnMenu(
      columnIndex: _columnMenuColIndex!,
      colDef: colDef,
      anchorRect: _columnMenuAnchorRect!,
      gridSize: gridSize,
      menuDef: menuDef,
      tabs: tabs,
      theme: _theme(),
      localeText: _localeText(),
      currentColumnSortDirection: _columnSortDirection(_columnMenuColIndex!),
      onAction: handleColumnMenuAction,
      onDismiss: dismissColumnMenu,
      // Filter tab
      filter: colDef.filter,
      colId: colId,
      currentFilterModel: _columnFilterModels()[colId],
      onFilterApply: onTabbedMenuFilterApply,
      // Columns tab
      allColumns: _flatColumnsCache(),
      columnDefs: _columnDefs(),
      hiddenColumnIds: _hiddenIds(),
      onColumnVisibilityChanged: onTabbedMenuColumnVisibilityChanged,
    );
  }

  /// Handles filter changes from the tabbed column menu's Filter tab.
  void onTabbedMenuFilterApply(String colId, OsColumnFilterModel? model) {
    // Reuse the same filter apply logic as the standalone filter popup.
    _onFilterPopupApply(colId, model);
  }

  /// Handles column visibility changes from the tabbed column menu's
  /// Columns tab.
  void onTabbedMenuColumnVisibilityChanged(String colId, bool visible) {
    _onColumnVisibilityChanged(colId, visible);
  }
}

/// A recyclable floating-filter popup: text controller, focus node and the
/// positioned overlay widget tree, kept alive across show/dismiss cycles.
///
/// Handed out by [PopupUiCoordinator.acquireFloatingFilterPopup] and returned
/// via [PopupUiCoordinator.releaseFloatingFilterPopup] so fast scrolling
/// across many columns reuses one of a handful of pre-created popups instead
/// of rebuilding the input (controller, focus node, decoration) on every tap.
class FloatingFilterPopupEntry {
  /// Creates an entry bound to [controller] and [focusNode].
  ///
  /// [overlayBuilder] rebuilds the positioned overlay tree for whatever rect
  /// the popup is next shown at ([reposition]).
  FloatingFilterPopupEntry({
    required this.controller,
    required this.focusNode,
    required Widget Function(FloatingFilterPopupEntry entry, Rect rect)
    overlayBuilder,
  }) : _overlayBuilder = overlayBuilder {
    _overlay = _overlayBuilder(this, Rect.zero);
  }

  /// Text controller bound to the entry's input.
  final TextEditingController controller;

  /// Focus node bound to the entry's input.
  final FocusNode focusNode;

  final Widget Function(FloatingFilterPopupEntry entry, Rect rect)
  _overlayBuilder;

  Widget _overlay = const SizedBox.shrink();
  bool _disposed = false;

  /// The positioned overlay widget tree for this popup.
  ///
  /// Mounted by the owner to show the popup and unmounted to hide it;
  /// rebuilt by [reposition] when the popup is reused at another position.
  Widget get overlay => _overlay;

  /// Whether [dispose] has been called on this entry.
  bool get isDisposed => _disposed;

  /// Rebuilds the overlay for a new [rect] (reuse at a different position).
  void reposition(Rect rect) {
    assert(!_disposed, 'Cannot reposition a disposed popup entry');
    _overlay = _overlayBuilder(this, rect);
  }

  /// Disposes the controller and focus node. Idempotent.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    controller.dispose();
    focusNode.dispose();
  }
}
