import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../locale/os_locale_text.dart';
import '../theming/grid_popup_surface.dart';
import '../theming/os_grid_theme.dart';
import '../theming/resolved_grid_theme.dart';
import 'filter_evaluator.dart';
import 'filter_model.dart';
import 'os_bigint_filter.dart';
import 'os_date_filter.dart';
import 'os_filter.dart';
import 'os_number_filter.dart';
import 'os_set_filter.dart';
import 'os_text_filter.dart';

/// Callback signature for when the filter popup applies a new filter model.
typedef FilterPopupApplyCallback =
    void Function(String colId, OsColumnFilterModel? model);

/// Callback signature for when the filter popup is dismissed.
typedef FilterPopupDismissCallback = void Function();

/// Localised display label for a filter operation type.
///
/// Mirrors the English defaults of the filter evaluator's display-name
/// helper (including the date-specific Before/After variants) while routing
/// through [OsLocaleText] so hosts can translate them.
String filterPopupOperationLabel(
  OsLocaleText lt,
  String type, {
  OsFilter? filter,
}) {
  final isDate = filter is OsDateFilter;
  switch (type) {
    case 'contains':
      return lt.contains;
    case 'notContains':
      return lt.notContains;
    case 'equals':
      return lt.equals;
    case 'notEqual':
      return lt.notEqual;
    case 'startsWith':
      return lt.startsWith;
    case 'endsWith':
      return lt.endsWith;
    case 'greaterThan':
      return isDate ? lt.after : lt.greaterThan;
    case 'greaterThanOrEqual':
      return isDate ? lt.afterOrOn : lt.greaterThanOrEqual;
    case 'lessThan':
      return isDate ? lt.before : lt.lessThan;
    case 'lessThanOrEqual':
      return isDate ? lt.beforeOrOn : lt.lessThanOrEqual;
    case 'inRange':
      return lt.inRange;
    case 'blank':
      return lt.blank;
    case 'notBlank':
      return lt.notBlank;
    default:
      return type;
  }
}

/// A popup panel for configuring a column's filter.
///
/// Mirrors OS Grid's provided filter popup UI. Shows:
/// - A dropdown to select the filter operation (Equals, Contains, etc.)
/// - A text input for the filter value
/// - For 'inRange' operations, a second input for the upper bound
/// - AND/OR join operator when multiple conditions are supported
/// - Clear and Apply buttons (hidable via [showClearButton]/
///   [showApplyButton]; [closeOnApply] keeps the popup open on Apply)
///
/// Condition inputs apply per keystroke unless the filter configures a
/// `debounceMs` quiet period; the set-filter search box always debounces.
///
/// The visible panel renders into the nearest [Overlay] via an
/// [OverlayPortal], so it can escape narrow grid bounds. Outside-tap and
/// scroll dismissal stay the host's responsibility (no barrier is drawn).
/// Styling resolves from [theme]; labels come from [localeText].
class FilterPopup extends StatefulWidget {
  const FilterPopup({
    super.key,
    required this.colId,
    required this.headerName,
    required this.filter,
    required this.currentModel,
    required this.onApply,
    required this.onDismiss,
    this.theme,
    this.localeText,
    this.valuesProvider,
    this.showApplyButton,
    this.showClearButton,
    this.closeOnApply,
  });

  /// The column ID this filter applies to.
  final String colId;

  /// The column's display name (shown in the popup header).
  final String headerName;

  /// The column's filter configuration (OsTextFilter or OsNumberFilter).
  final OsFilter filter;

  /// The current filter model for this column (null if no filter active).
  final OsColumnFilterModel? currentModel;

  /// Called when the user changes the filter (applies immediately on input).
  final FilterPopupApplyCallback onApply;

  /// Called when the popup should be dismissed.
  final FilterPopupDismissCallback onDismiss;

  /// The grid's theme for styling the popup.
  final OsGridTheme? theme;

  /// Localised labels (defaults to English).
  final OsLocaleText? localeText;

  /// Supplies the raw cell values used to derive the set filter checklist.
  ///
  /// Only consulted when the column's filter is an [OsSetFilter] without a
  /// fixed [OsSetFilter.values] supply. The grid injects a valueGetter-aware
  /// provider over its row data; each popup open resolves it once.
  final List<Object?> Function()? valuesProvider;

  /// Whether the Apply button is shown.
  ///
  /// When `null` (default) the button is shown, matching the historical
  /// behaviour. Set to `false` to hide it — input then applies directly
  /// (or via the filter's `debounceMs`) and Clear still commits.
  final bool? showApplyButton;

  /// Whether the Clear button is shown.
  ///
  /// When `null` (default) the button is shown, matching the historical
  /// behaviour.
  final bool? showClearButton;

  /// Whether tapping Apply dismisses the popup.
  ///
  /// When `null` (default) the popup closes on Apply, matching the
  /// historical behaviour. Set to `false` to keep the popup open so users
  /// can refine the filter.
  final bool? closeOnApply;

  @override
  State<FilterPopup> createState() => _FilterPopupState();
}

class _FilterPopupState extends State<FilterPopup> {
  static const _popupWidth = 240.0;
  static const _setListRowHeight = 28.0;
  static const _setMaxListHeight = 240.0;

  late String _operationType;
  late TextEditingController _valueController;
  late TextEditingController _valueToController;
  late OsJoinOperator _joinOperator;
  late String _operationType2;
  late TextEditingController _valueController2;

  /// Whether to show the second condition (for combined filters).
  bool _showSecondCondition = false;

  /// Pending debounced apply — fires once input has been quiet for
  /// [OsTextFilter.debounceMs]/equivalent (set search: fixed 150ms).
  Timer? _applyDebounceTimer;

  bool get _isSetFilter => widget.filter is OsSetFilter;

  OsLocaleText get _locale => widget.localeText ?? OsLocaleText.defaultLocale;

  // --- Apply/Clear visibility + apply-on-close behaviour (item: popup UX) ---

  bool get _applyVisible => widget.showApplyButton ?? true;
  bool get _clearVisible => widget.showClearButton ?? true;
  bool get _closesOnApply => widget.closeOnApply ?? true;

  // --- Set filter state ---
  late TextEditingController _searchController;

  /// All derived checklist keys, sorted (blanks share the '' key).
  List<String> _setKeys = const [];

  /// Currently selected keys.
  Set<String> _selectedKeys = {};

  String _searchQuery = '';

  @override
  void initState() {
    super.initState();

    if (_isSetFilter) {
      _initSetFilterState();
      return;
    }

    final defaultOp = getDefaultFilterType(widget.filter);
    final maxConditions = _getMaxConditions();

    // Initialise from current model if present
    if (widget.currentModel != null && widget.currentModel!.isActive) {
      final model = widget.currentModel!;
      final firstCondition = model.conditions.isNotEmpty
          ? model.conditions.first
          : null;

      _operationType = firstCondition?.type ?? defaultOp;
      _valueController = TextEditingController(
        text: firstCondition?.filter?.toString() ?? '',
      );
      _valueToController = TextEditingController(
        text: firstCondition?.filterTo?.toString() ?? '',
      );

      // Second condition
      if (model.conditions.length > 1 && maxConditions > 1) {
        _showSecondCondition = true;
        final secondCondition = model.conditions[1];
        _operationType2 = secondCondition.type;
        _valueController2 = TextEditingController(
          text: secondCondition.filter?.toString() ?? '',
        );
        _joinOperator = model.operator ?? OsJoinOperator.and;
      } else {
        _operationType2 = defaultOp;
        _valueController2 = TextEditingController();
        _joinOperator = _getDefaultJoinOperator();
      }
    } else {
      _operationType = defaultOp;
      _valueController = TextEditingController();
      _valueToController = TextEditingController();
      _operationType2 = defaultOp;
      _valueController2 = TextEditingController();
      _joinOperator = _getDefaultJoinOperator();
    }
  }

  @override
  void dispose() {
    _applyDebounceTimer?.cancel();
    if (_isSetFilter) {
      _searchController.dispose();
    } else {
      _valueController.dispose();
      _valueToController.dispose();
      _valueController2.dispose();
    }
    super.dispose();
  }

  /// Debounced apply for the condition value inputs.
  ///
  /// Applies immediately when the filter has no [OsTextFilter.debounceMs]
  /// (and equivalents), preserving the historical per-keystroke behaviour.
  void _scheduleValueApply() {
    final ms = getFilterDebounceMs(widget.filter);
    if (ms == null || ms <= 0) {
      _applyFilter();
      return;
    }
    _applyDebounceTimer?.cancel();
    _applyDebounceTimer = Timer(Duration(milliseconds: ms), () {
      if (mounted) _applyFilter();
    });
  }

  /// Debounced search-box update for the set filter checklist.
  ///
  /// Uses the filter's [OsSetFilter.debounceMs] when set, otherwise a fixed
  /// 150ms quiet period so the checklist narrows without a setState per
  /// keystroke.
  void _scheduleSearchUpdate(String value) {
    final config = widget.filter is OsSetFilter
        ? widget.filter as OsSetFilter
        : null;
    final ms = config?.debounceMs ?? 150;
    _applyDebounceTimer?.cancel();
    if (ms <= 0) {
      setState(() => _searchQuery = value);
      return;
    }
    _applyDebounceTimer = Timer(Duration(milliseconds: ms), () {
      if (mounted) setState(() => _searchQuery = value);
    });
  }

  /// Derives the checklist keys and initial selection for a set filter.
  ///
  /// Values come from the filter's fixed supply when provided, otherwise
  /// from the grid-injected [FilterPopup.valuesProvider]. Resolution happens
  /// once per popup open (lazy derivation). With [OsSetFilter.caseSensitive]
  /// disabled (the default) case variants share one entry, and an existing
  /// model's values are matched onto the checklist case-insensitively.
  void _initSetFilterState() {
    final config = widget.filter as OsSetFilter;
    _searchController = TextEditingController();

    Iterable<Object?> source = const [];
    if (config.values != null) {
      source = config.values!;
    } else {
      final provider = widget.valuesProvider;
      if (provider != null) source = provider();
    }
    _setKeys = deriveSetFilterKeys(source, caseSensitive: config.caseSensitive);

    final model = widget.currentModel;
    if (model != null && model.isActive && model.values != null) {
      if (config.caseSensitive) {
        _selectedKeys = Set<String>.of(model.values!);
      } else {
        final foldedModel = model.values!
            .map((value) => value.toLowerCase())
            .toSet();
        _selectedKeys = {
          for (final key in _setKeys)
            if (foldedModel.contains(key.toLowerCase())) key,
        };
      }
    } else {
      _selectedKeys = config.defaultToAllSelected
          ? Set<String>.of(_setKeys)
          : <String>{};
    }
  }

  /// Checklist keys visible after applying the search box filter.
  ///
  /// Matching is case-insensitive unless the filter's
  /// [OsSetFilter.caseSensitive] is set.
  List<String> _filteredSetKeys(OsLocaleText lt) {
    final query = _searchQuery.trim();
    if (query.isEmpty) return _setKeys;
    final caseSensitive = (widget.filter as OsSetFilter).caseSensitive;
    final needle = caseSensitive ? query : query.toLowerCase();
    return _setKeys.where((key) {
      final display = key.isEmpty ? lt.blanks : key;
      final haystack = caseSensitive ? display : display.toLowerCase();
      return haystack.contains(needle);
    }).toList();
  }

  /// Tri-state Select All computed over the search-filtered scope.
  ///
  /// With an active search the checkbox reflects only the visible
  /// (filtered) entries — hidden entries are ignored, matching AG Grid.
  bool? get _selectAllState {
    final visible = _filteredSetKeys(_locale);
    if (visible.isEmpty) return true;
    var selectedCount = 0;
    for (final key in visible) {
      if (_selectedKeys.contains(key)) selectedCount++;
    }
    if (selectedCount >= visible.length) return true;
    if (selectedCount == 0) return false;
    return null;
  }

  /// Select All toggles only the visible (search-filtered) scope: with an
  /// active search, hidden entries keep their current selection state.
  void _toggleSelectAll() {
    final visible = _filteredSetKeys(_locale);
    setState(() {
      if (_selectAllState == true) {
        _selectedKeys.removeAll(visible);
      } else {
        _selectedKeys.addAll(visible);
      }
    });
  }

  /// Selects every visible (search-filtered) checklist entry. Bound to
  /// Ctrl+A / Cmd+A while the search box has focus.
  void _selectAllFiltered() {
    final visible = _filteredSetKeys(_locale);
    if (visible.isEmpty) return;
    setState(() => _selectedKeys.addAll(visible));
  }

  void _toggleSetKey(String key) {
    setState(() {
      if (_selectedKeys.contains(key)) {
        _selectedKeys.remove(key);
      } else {
        _selectedKeys.add(key);
      }
    });
  }

  void _applySetFilter() {
    widget.onApply(
      widget.colId,
      OsColumnFilterModel(
        filterType: 'set',
        values: List<String>.of(_selectedKeys),
      ),
    );
  }

  void _clearSetFilter() {
    final config = widget.filter as OsSetFilter;
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _selectedKeys = config.defaultToAllSelected
          ? Set<String>.of(_setKeys)
          : <String>{};
    });
    widget.onApply(widget.colId, null);
  }

  double _estimateSetHeight() {
    var height = 34.0; // header
    height += 48; // search field + padding
    height += 36; // select-all row
    height +=
        math.min(_setKeys.length * _setListRowHeight, _setMaxListHeight) + 8;
    if (_clearVisible || _applyVisible) {
      height += 52; // action buttons row
    }
    return height;
  }

  int _getMaxConditions() {
    if (widget.filter is OsTextFilter) {
      return (widget.filter as OsTextFilter).maxNumConditions;
    }
    if (widget.filter is OsNumberFilter) {
      return (widget.filter as OsNumberFilter).maxNumConditions;
    }
    if (widget.filter is OsBigIntFilter) {
      return (widget.filter as OsBigIntFilter).maxNumConditions;
    }
    if (widget.filter is OsDateFilter) {
      return (widget.filter as OsDateFilter).maxNumConditions;
    }
    return 1;
  }

  OsJoinOperator _getDefaultJoinOperator() {
    if (widget.filter is OsTextFilter) {
      return (widget.filter as OsTextFilter).defaultJoinOperator;
    }
    if (widget.filter is OsNumberFilter) {
      return (widget.filter as OsNumberFilter).defaultJoinOperator;
    }
    if (widget.filter is OsBigIntFilter) {
      return (widget.filter as OsBigIntFilter).defaultJoinOperator;
    }
    if (widget.filter is OsDateFilter) {
      return (widget.filter as OsDateFilter).defaultJoinOperator;
    }
    return OsJoinOperator.and;
  }

  List<String> _getAvailableOptions() {
    return getAvailableFilterOptions(widget.filter);
  }

  void _applyFilter() {
    final conditions = <OsFilterCondition>[];

    // First condition
    final numInputs1 = getNumberOfInputs(_operationType);
    if (numInputs1 == 0) {
      // blank/notBlank — no value needed
      conditions.add(OsFilterCondition(type: _operationType));
    } else {
      final value1 = _valueController.text.trim();
      if (value1.isNotEmpty) {
        if (numInputs1 == 2) {
          final valueTo = _valueToController.text.trim();
          conditions.add(
            OsFilterCondition(
              type: _operationType,
              filter: value1,
              filterTo: valueTo.isNotEmpty ? valueTo : null,
            ),
          );
        } else {
          conditions.add(
            OsFilterCondition(type: _operationType, filter: value1),
          );
        }
      }
    }

    // Second condition (if visible and has content)
    if (_showSecondCondition) {
      final numInputs2 = getNumberOfInputs(_operationType2);
      if (numInputs2 == 0) {
        conditions.add(OsFilterCondition(type: _operationType2));
      } else {
        final value2 = _valueController2.text.trim();
        if (value2.isNotEmpty) {
          conditions.add(
            OsFilterCondition(type: _operationType2, filter: value2),
          );
        }
      }
    }

    if (conditions.isEmpty) {
      // No active filter — clear
      widget.onApply(widget.colId, null);
    } else {
      final filterType = widget.filter is OsNumberFilter
          ? 'number'
          : widget.filter is OsBigIntFilter
          ? 'bigint'
          : widget.filter is OsDateFilter
          ? 'date'
          : 'text';
      widget.onApply(
        widget.colId,
        OsColumnFilterModel(
          filterType: filterType,
          conditions: conditions,
          operator: conditions.length > 1 ? _joinOperator : null,
        ),
      );
    }
  }

  void _clearFilter() {
    setState(() {
      _operationType = getDefaultFilterType(widget.filter);
      _valueController.clear();
      _valueToController.clear();
      _showSecondCondition = false;
      _operationType2 = getDefaultFilterType(widget.filter);
      _valueController2.clear();
      _joinOperator = _getDefaultJoinOperator();
    });
    widget.onApply(widget.colId, null);
  }

  double _estimateHeight() {
    var height = 46.0; // header + dropdown paddings baseline
    height += 40; // operation dropdown row

    final numInputs1 = getNumberOfInputs(_operationType);
    if (numInputs1 > 0) height += 38;
    if (numInputs1 > 1) height += 38;

    final maxConditions = _getMaxConditions();
    if (maxConditions > 1) {
      height += _showSecondCondition ? 96 : 42;
    }
    if (_clearVisible || _applyVisible) {
      height += 52; // action buttons row
    }
    return height;
  }

  @override
  Widget build(BuildContext context) {
    final resolved = ResolvedGridTheme.from(widget.theme);
    final lt = _locale;
    final textStyle = resolved.text(12);

    if (_isSetFilter) {
      return _buildSetFilterSurface(resolved, lt, textStyle);
    }

    final isDate = widget.filter is OsDateFilter;
    final availableOptions = _getAvailableOptions();
    final maxConditions = _getMaxConditions();
    final numInputs1 = getNumberOfInputs(_operationType);

    return GridPopupSurface.atOrigin(
      popupWidth: _popupWidth,
      estimatedHeight: _estimateHeight(),
      blurSigma: widget.theme?.popupBlurSigma ?? 0,
      contentBuilder: (context) => Material(
        elevation: resolved.popupElevation,
        borderRadius: BorderRadius.circular(resolved.panelRadius),
        color: resolved.background,
        child: Container(
          width: _popupWidth,
          decoration: BoxDecoration(
            border: Border.all(color: resolved.border, width: 1),
            borderRadius: BorderRadius.circular(resolved.panelRadius),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              _buildPopupHeader(resolved, textStyle),

              // First condition
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: _buildOperationDropdown(
                  value: _operationType,
                  options: availableOptions,
                  textStyle: textStyle,
                  resolved: resolved,
                  onChanged: (value) {
                    setState(() => _operationType = value);
                    _applyFilter();
                  },
                ),
              ),

              // First value input (hidden for blank/notBlank)
              if (numInputs1 > 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: _buildTextInput(
                    controller: _valueController,
                    placeholder: numInputs1 > 1
                        ? (isDate ? lt.dateFormatOoo : lt.fromOoo)
                        : (isDate ? lt.dateFormatOoo : lt.filterValueOoo),
                    textStyle: textStyle,
                    resolved: resolved,
                    onChanged: (_) => _scheduleValueApply(),
                  ),
                ),

              // Second value input for inRange
              if (numInputs1 > 1)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: _buildTextInput(
                    controller: _valueToController,
                    placeholder: isDate ? lt.dateFormatOoo : lt.toOoo,
                    textStyle: textStyle,
                    resolved: resolved,
                    onChanged: (_) => _scheduleValueApply(),
                  ),
                ),

              // Join operator + second condition (if maxConditions > 1)
              if (maxConditions > 1) ...[
                // AND/OR selector
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _buildJoinButton(
                        label: lt.andCondition,
                        isSelected: _joinOperator == OsJoinOperator.and,
                        resolved: resolved,
                        textStyle: textStyle,
                        onTap: () {
                          setState(() => _joinOperator = OsJoinOperator.and);
                          if (_showSecondCondition) _applyFilter();
                        },
                      ),
                      _buildJoinButton(
                        label: lt.orCondition,
                        isSelected: _joinOperator == OsJoinOperator.or,
                        resolved: resolved,
                        textStyle: textStyle,
                        onTap: () {
                          setState(() => _joinOperator = OsJoinOperator.or);
                          if (_showSecondCondition) _applyFilter();
                        },
                      ),
                      if (!_showSecondCondition)
                        GestureDetector(
                          onTap: () =>
                              setState(() => _showSecondCondition = true),
                          child: Text(
                            lt.plusCondition,
                            style: textStyle.copyWith(
                              color: resolved.accent,
                              fontSize: 11,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Second condition
                if (_showSecondCondition) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: _buildOperationDropdown(
                      value: _operationType2,
                      options: availableOptions,
                      textStyle: textStyle,
                      resolved: resolved,
                      onChanged: (value) {
                        setState(() => _operationType2 = value);
                        _applyFilter();
                      },
                    ),
                  ),
                  if (getNumberOfInputs(_operationType2) > 0)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      child: _buildTextInput(
                        controller: _valueController2,
                        placeholder: lt.filterValueOoo,
                        textStyle: textStyle,
                        resolved: resolved,
                        onChanged: (_) => _scheduleValueApply(),
                      ),
                    ),
                ],
              ],

              // Action buttons
              if (_clearVisible || _applyVisible)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      if (_clearVisible) ...[
                        Expanded(
                          child: _buildActionButton(
                            label: lt.clear,
                            resolved: resolved,
                            textColor: resolved.foreground,
                            textStyle: textStyle,
                            onTap: _clearFilter,
                          ),
                        ),
                        if (_applyVisible) const SizedBox(width: 8),
                      ],
                      if (_applyVisible)
                        Expanded(
                          child: _buildActionButton(
                            label: lt.apply,
                            resolved: resolved,
                            bgColor: resolved.accent,
                            borderCol: resolved.accent,
                            textColor: Colors.white,
                            textStyle: textStyle,
                            onTap: () {
                              _applyFilter();
                              if (_closesOnApply) widget.onDismiss();
                            },
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the set filter popup: search box, tri-state Select All and the
  /// checklist. The checklist always renders through a virtualised
  /// `ListView.builder` (viewport-bound), so 10k+ unique values scroll
  /// without jank. Apply commits `{filterType: 'set', values}`.
  Widget _buildSetFilterSurface(
    ResolvedGridTheme resolved,
    OsLocaleText lt,
    TextStyle textStyle,
  ) {
    final visibleKeys = _filteredSetKeys(lt);
    final listHeight = math.min(
      visibleKeys.length * _setListRowHeight,
      _setMaxListHeight,
    );

    return GridPopupSurface.atOrigin(
      popupWidth: _popupWidth,
      estimatedHeight: _estimateSetHeight(),
      blurSigma: widget.theme?.popupBlurSigma ?? 0,
      contentBuilder: (context) => Material(
        elevation: resolved.popupElevation,
        borderRadius: BorderRadius.circular(resolved.panelRadius),
        color: resolved.background,
        child: Container(
          width: _popupWidth,
          decoration: BoxDecoration(
            border: Border.all(color: resolved.border, width: 1),
            borderRadius: BorderRadius.circular(resolved.panelRadius),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              _buildPopupHeader(resolved, textStyle),

              // Search box (filters the visible checklist entries).
              // Ctrl+A / Cmd+A inside the box selects all filtered values
              // instead of the field's text.
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: SizedBox(
                  height: 30,
                  child: CallbackShortcuts(
                    bindings: {
                      const SingleActivator(
                        LogicalKeyboardKey.keyA,
                        control: true,
                      ): _selectAllFiltered,
                      const SingleActivator(
                        LogicalKeyboardKey.keyA,
                        meta: true,
                      ): _selectAllFiltered,
                    },
                    child: TextField(
                      controller: _searchController,
                      style: textStyle.copyWith(fontSize: 12),
                      cursorColor: resolved.accent,
                      decoration: InputDecoration(
                        hintText: lt.searchOoo,
                        hintStyle: textStyle.copyWith(
                          color: resolved.hintForeground,
                          fontSize: 12,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          size: 16,
                          color: resolved.mutedForeground,
                        ),
                        filled: true,
                        fillColor: resolved.chrome,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            resolved.controlRadius,
                          ),
                          borderSide: BorderSide(color: resolved.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            resolved.controlRadius,
                          ),
                          borderSide: BorderSide(color: resolved.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            resolved.controlRadius,
                          ),
                          borderSide: BorderSide(
                            color: resolved.accent,
                            width: 1.5,
                          ),
                        ),
                        isDense: true,
                      ),
                      onChanged: _scheduleSearchUpdate,
                    ),
                  ),
                ),
              ),

              // Select All (tri-state)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 2, 4, 0),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _toggleSelectAll,
                  child: SizedBox(
                    height: 32,
                    child: Row(
                      children: [
                        Checkbox(
                          value: _selectAllState,
                          tristate: true,
                          onChanged: (_) => _toggleSelectAll(),
                        ),
                        Expanded(
                          child: Text(
                            lt.selectAll,
                            style: textStyle.copyWith(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Checklist
              if (visibleKeys.isNotEmpty)
                SizedBox(
                  height: listHeight,
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 4),
                    itemCount: visibleKeys.length,
                    itemBuilder: (context, index) =>
                        _buildSetEntryRow(visibleKeys[index], lt, textStyle),
                  ),
                ),

              // Action buttons
              if (_clearVisible || _applyVisible)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      if (_clearVisible) ...[
                        Expanded(
                          child: _buildActionButton(
                            label: lt.clear,
                            resolved: resolved,
                            textColor: resolved.foreground,
                            textStyle: textStyle,
                            onTap: _clearSetFilter,
                          ),
                        ),
                        if (_applyVisible) const SizedBox(width: 8),
                      ],
                      if (_applyVisible)
                        Expanded(
                          child: _buildActionButton(
                            label: lt.apply,
                            resolved: resolved,
                            bgColor: resolved.accent,
                            borderCol: resolved.accent,
                            textColor: Colors.white,
                            textStyle: textStyle,
                            onTap: () {
                              _applySetFilter();
                              if (_closesOnApply) widget.onDismiss();
                            },
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// One tappable checklist row: checkbox + display label ("(Blanks)" for
  /// the shared blank key).
  Widget _buildSetEntryRow(String key, OsLocaleText lt, TextStyle textStyle) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _toggleSetKey(key),
      child: SizedBox(
        height: _setListRowHeight,
        child: Row(
          children: [
            Checkbox(
              value: _selectedKeys.contains(key),
              onChanged: (_) => _toggleSetKey(key),
            ),
            Expanded(
              child: Text(
                key.isEmpty ? lt.blanks : key,
                style: textStyle.copyWith(fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Shared popup header: column name + close icon.
  Widget _buildPopupHeader(ResolvedGridTheme resolved, TextStyle textStyle) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: resolved.chrome,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(resolved.panelRadius - 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.headerName,
              style: textStyle.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          GestureDetector(
            onTap: widget.onDismiss,
            child: Icon(Icons.close, size: 16, color: resolved.mutedForeground),
          ),
        ],
      ),
    );
  }

  Widget _buildOperationDropdown({
    required String value,
    required List<String> options,
    required TextStyle textStyle,
    required ResolvedGridTheme resolved,
    required ValueChanged<String> onChanged,
  }) {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: resolved.chrome,
        border: Border.all(color: resolved.border),
        borderRadius: BorderRadius.circular(resolved.controlRadius),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: options.contains(value) ? value : options.first,
          isExpanded: true,
          isDense: true,
          icon: Icon(
            Icons.arrow_drop_down,
            size: 16,
            color: resolved.mutedForeground,
          ),
          dropdownColor: resolved.background,
          style: textStyle,
          items: options.map((option) {
            return DropdownMenuItem<String>(
              value: option,
              child: Text(
                filterPopupOperationLabel(
                  widget.localeText ?? OsLocaleText.defaultLocale,
                  option,
                  filter: widget.filter,
                ),
                style: textStyle.copyWith(fontSize: 12),
              ),
            );
          }).toList(),
          onChanged: (newValue) {
            if (newValue != null) onChanged(newValue);
          },
        ),
      ),
    );
  }

  Widget _buildTextInput({
    required TextEditingController controller,
    required String placeholder,
    required TextStyle textStyle,
    required ResolvedGridTheme resolved,
    required ValueChanged<String> onChanged,
  }) {
    return SizedBox(
      height: 30,
      child: TextField(
        controller: controller,
        style: textStyle.copyWith(fontSize: 12),
        cursorColor: resolved.accent,
        decoration: InputDecoration(
          hintText: placeholder,
          hintStyle: textStyle.copyWith(
            color: resolved.hintForeground,
            fontSize: 12,
          ),
          filled: true,
          fillColor: resolved.chrome,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 6,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(resolved.controlRadius),
            borderSide: BorderSide(color: resolved.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(resolved.controlRadius),
            borderSide: BorderSide(color: resolved.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(resolved.controlRadius),
            borderSide: BorderSide(color: resolved.accent, width: 1.5),
          ),
          isDense: true,
        ),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildJoinButton({
    required String label,
    required bool isSelected,
    required ResolvedGridTheme resolved,
    required TextStyle textStyle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? resolved.accent.withValues(alpha: 0.2)
              : resolved.chrome,
          border: Border.all(
            color: isSelected ? resolved.accent : resolved.border,
          ),
          borderRadius: BorderRadius.circular(resolved.controlRadius),
        ),
        child: Text(
          label,
          style: textStyle.copyWith(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? resolved.accent : null,
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required ResolvedGridTheme resolved,
    required Color textColor,
    required TextStyle textStyle,
    required VoidCallback onTap,
    Color? bgColor,
    Color? borderCol,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bgColor ?? resolved.chrome,
          border: Border.all(color: borderCol ?? resolved.border),
          borderRadius: BorderRadius.circular(resolved.controlRadius),
        ),
        child: Text(
          label,
          style: textStyle.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ),
    );
  }
}
