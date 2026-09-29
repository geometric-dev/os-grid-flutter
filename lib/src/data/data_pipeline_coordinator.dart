import '../cache/value_cache.dart';
import '../cell_span/cell_span_service.dart';
import '../columns/os_column_def.dart';
import '../filtering/filter_evaluator.dart';
import '../filtering/filter_model.dart';
import '../filtering/os_custom_filter.dart';
import '../os_grid_controller.dart';
import '../params/get_quick_filter_text_params.dart';
import '../params/value_getter_params.dart';
import '../rendering/text_painter_cache.dart';
import '../row_model/delta_sort_service.dart';
import '../sorting/sort_service.dart';

/// Owns the client-side row-model pipeline: quick filter → external filter
/// → per-column filters → custom filters → multi-column sort (+ delta sort)
/// → postSortRows.
///
/// Extracted from `_OsGridState`. The coordinator is inert apart from the
/// [reprocess] methods; all grid collaborators are supplied as live getters.
class DataPipelineCoordinator<TData> {
  /// Creates a coordinator.
  DataPipelineCoordinator({
    required OsGridController<TData> controller,
    required List<TData>? Function() rowData,
    required List<OsColumnDef> Function() allFlatColumns,
    required Set<String> Function() hiddenIds,
    required Map<String, OsColumnFilterModel> columnFilterModels,
    required Map<String, dynamic> customFilterModels,
    required SortService<TData> sortService,
    required DeltaSortService<TData>? Function() deltaSortService,
    required Set<TData>? Function() lastTouchedRows,
    required void Function(Set<TData>? rows) setLastTouchedRows,
    required ValueCache valueCache,
    required CellSpanService cellSpanService,
    required TextPainterCache textPainterCache,
    required String? Function() quickFilterOverride,
    required String? Function() quickFilterText,
    required List<String>? Function(String)? quickFilterParser,
    required bool Function(List<String>, String)? quickFilterMatcher,
    required bool includeHiddenColumnsInQuickFilter,
    required bool cacheQuickFilter,
    required bool Function()? isExternalFilterPresent,
    required bool Function(TData)? doesExternalFilterPass,
    required List<TData> Function(List<TData> rows)? postSortRows,
    required bool valueCacheEnabled,
    required bool enableCellSpan,
    required String? Function(TData) getRowId,
    required dynamic Function(OsColumnDef col, TData row, int rowIndex)
    resolveColumnValue,
    required List<TData> Function() controllerRowData,
    required void Function(List<TData>? rows) setProcessedRowData,
  }) : _controller = controller,
       _rowData = rowData,
       _allFlatColumns = allFlatColumns,
       _hiddenIds = hiddenIds,
       _columnFilterModels = columnFilterModels,
       _customFilterModels = customFilterModels,
       _sortService = sortService,
       _deltaSortService = deltaSortService,
       _lastTouchedRows = lastTouchedRows,
       _setLastTouchedRows = setLastTouchedRows,
       _valueCache = valueCache,
       _cellSpanService = cellSpanService,
       _textPainterCache = textPainterCache,
       _quickFilterOverride = quickFilterOverride,
       _quickFilterText = quickFilterText,
       _quickFilterParser = quickFilterParser,
       _quickFilterMatcher = quickFilterMatcher,
       _includeHiddenColumnsInQuickFilter = includeHiddenColumnsInQuickFilter,
       _cacheQuickFilterEnabled = cacheQuickFilter,
       _isExternalFilterPresent = isExternalFilterPresent,
       _doesExternalFilterPass = doesExternalFilterPass,
       _postSortRows = postSortRows,
       _valueCacheEnabled = valueCacheEnabled,
       _enableCellSpan = enableCellSpan,
       _getRowId = getRowId,
       _resolveColumnValue = resolveColumnValue,
       _controllerRowData = controllerRowData,
       _setProcessedRowData = setProcessedRowData;

  /// The live controller. Mutable only for runtime controller swaps —
  /// see [rebind].
  OsGridController<TData> _controller;

  /// Re-points the coordinator at [controller] after a runtime controller
  /// swap. The pipeline owns no request hooks or stream subscriptions — it
  /// only writes [OsGridController.processedData] — so reassigning the
  /// reference is sufficient.
  void rebind(OsGridController<TData> controller) {
    _controller = controller;
  }

  final List<TData>? Function() _rowData;
  final List<OsColumnDef> Function() _allFlatColumns;
  final Set<String> Function() _hiddenIds;
  final Map<String, OsColumnFilterModel> _columnFilterModels;
  final Map<String, dynamic> _customFilterModels;
  final SortService<TData> _sortService;
  final DeltaSortService<TData>? Function() _deltaSortService;
  final Set<TData>? Function() _lastTouchedRows;
  final void Function(Set<TData>? rows) _setLastTouchedRows;
  final ValueCache _valueCache;
  final CellSpanService _cellSpanService;
  final TextPainterCache _textPainterCache;
  final String? Function() _quickFilterOverride;
  final String? Function() _quickFilterText;
  final List<String>? Function(String)? _quickFilterParser;
  final bool Function(List<String>, String)? _quickFilterMatcher;
  final bool _includeHiddenColumnsInQuickFilter;
  final bool _cacheQuickFilterEnabled;
  final bool Function()? _isExternalFilterPresent;
  final bool Function(TData)? _doesExternalFilterPass;
  final List<TData> Function(List<TData> rows)? _postSortRows;
  final bool _valueCacheEnabled;
  final bool _enableCellSpan;
  final dynamic Function(OsColumnDef col, TData row, int rowIndex)
  _resolveColumnValue;
  final String? Function(TData) _getRowId;
  final List<TData> Function() _controllerRowData;
  final void Function(List<TData>? rows) _setProcessedRowData;

  // --- Quick filter cache (cacheQuickFilter) ---

  /// Per-cell uppercased quick-filter text, keyed by
  /// `<rowKey>\u0000<colId>`. An empty string encodes a null column text
  /// so misses stay distinguishable from cached "no text" results.
  ///
  /// Only populated when `_cacheQuickFilterEnabled` is true.
  final Map<String, String> _quickFilterTextCache = {};

  /// The rowData source instance the current cache was built from.
  /// A different instance means the source changed → invalidate.
  Object? _quickFilterCacheSource;

  /// Hidden-column id snapshot taken when the cache was last built.
  Set<String> _quickFilterCacheHiddenIds = const {};

  /// Column instances the cached texts were computed from. Compared
  /// element-wise by identity so swapped colDefs (e.g. new valueGetter)
  /// invalidate even when colIds are unchanged.
  List<OsColumnDef> _quickFilterCacheColumns = const <OsColumnDef>[];

  /// Clears the per-row quick-filter aggregate/getter text cache.
  ///
  /// The cache repopulates lazily on the next quick-filter pass.
  void invalidateQuickFilterCache() {
    _quickFilterTextCache.clear();
  }

  /// Applies quick filter, per-column filters, and sort to produce the
  /// processed row data (source: widget rowData).
  void reprocess() {
    if (_rowData() == null) {
      _setProcessedRowData(null);
      _controller.processedData = [];
      return;
    }
    _runPipeline(_rowData()!);
  }

  /// Reprocesses data using the controller's internal row data as source.
  ///
  /// Used when `applyTransaction` is called directly on the controller or
  /// when `refreshClientSideRowModel` is requested. Mirrors the widget-path
  /// pipeline (`_runPipeline`) including custom filters; value cache is
  /// invalidated but the TextPainter cache is not.
  void reprocessFromController() {
    if (_valueCacheEnabled) {
      _valueCache.expire();
    }
    // Transactions mutate rows in place (identity checks cannot detect
    // that) and refreshClientSideRowModel implies externally-mutated
    // derived state — always invalidate the quick-filter cache here.
    if (_cacheQuickFilterEnabled) {
      _quickFilterTextCache.clear();
      _quickFilterCacheSource = null;
    }

    List<TData> data = List.from(_controllerRowData());

    data = _applyQuickFilter(data, _quickFilterOverride());
    data = _applyExternalFilter(data);
    data = _applyColumnFilters(data);
    data = _applyCustomFilters(data);
    data = _applySort(data);

    if (_postSortRows != null) {
      data = _postSortRows(List.of(data));
    }

    _setProcessedRowData(data);
    _controller.processedData = data;

    _rebuildCellSpanCache(data);
  }

  List<TData> _applyQuickFilter(List<TData> data, String? override) {
    final filterText = override ?? _quickFilterText();
    if (filterText == null || filterText.isEmpty) return data;

    final List<String> filterParts;
    // Custom matchers receive the raw parsed parts so case-sensitive
    // matching is possible; only the built-in default matcher path
    // normalises casing via toUpperCase.
    if (_quickFilterMatcher != null) {
      if (_quickFilterParser != null) {
        filterParts = _quickFilterParser(
          filterText,
        )!.where((s) => s.isNotEmpty).toList();
      } else {
        filterParts = filterText.split(' ').where((s) => s.isNotEmpty).toList();
      }
    } else if (_quickFilterParser != null) {
      filterParts = _quickFilterParser(
        filterText,
      )!.where((s) => s.isNotEmpty).map((s) => s.toUpperCase()).toList();
    } else {
      filterParts = filterText
          .toUpperCase()
          .split(' ')
          .where((s) => s.isNotEmpty)
          .toList();
    }

    if (filterParts.isEmpty) return data;

    final colsToSearch = _allFlatColumns().where((col) {
      if (col.field == null && col.valueGetter == null) return false;
      if (_includeHiddenColumnsInQuickFilter) return true;
      return !_hiddenIds().contains(col.effectiveColId);
    }).toList();

    // Structural sync: hidden-column or column-definition changes
    // invalidate cached texts even though the data source is unchanged.
    if (_cacheQuickFilterEnabled &&
        (!_identicalColumns(colsToSearch, _quickFilterCacheColumns) ||
            !_sameStrings(_hiddenIds(), _quickFilterCacheHiddenIds))) {
      _quickFilterTextCache.clear();
      _quickFilterCacheColumns = List.of(colsToSearch);
      _quickFilterCacheHiddenIds = Set.of(_hiddenIds());
    }

    if (_quickFilterMatcher != null) {
      // Custom matcher: build aggregate text and delegate
      return data.where((row) {
        final aggregateText = _aggregateQuickFilterText(row, colsToSearch);
        return _quickFilterMatcher(filterParts, aggregateText);
      }).toList();
    }

    // Default matching: ALL parts must match at least one column
    // (AND between parts, OR between columns)
    return data.where((row) {
      return filterParts.every((part) {
        return colsToSearch.any((col) {
          final text = _resolveQuickFilterText(col, row);
          return text != null && text.contains(part);
        });
      });
    }).toList();
  }

  List<TData> _applyExternalFilter(List<TData> data) {
    if (_isExternalFilterPresent != null &&
        _isExternalFilterPresent() &&
        _doesExternalFilterPass != null) {
      return data.where((row) => _doesExternalFilterPass(row)).toList();
    }
    return data;
  }

  List<TData> _applyColumnFilters(List<TData> data) {
    if (_columnFilterModels.isEmpty) return data;

    // Resolve the column definition per active colId once (not per row).
    final flatCols = _allFlatColumns();
    final activeFilters = <(OsColumnDef, OsColumnFilterModel)>[];
    for (final entry in _columnFilterModels.entries) {
      if (!entry.value.isActive) continue;
      final col = flatCols.cast<OsColumnDef?>().firstWhere(
        (c) => c!.effectiveColId == entry.key,
        orElse: () => null,
      );
      if (col == null || col.filter == null) continue;
      activeFilters.add((col, entry.value));
    }

    // Value resolution supports Map rows and typed rows via valueGetter.
    final filtered = <TData>[];
    for (int i = 0; i < data.length; i++) {
      final row = data[i];
      var passes = true;
      for (final (col, model) in activeFilters) {
        final cellValue = _resolveColumnValue(col, row, i);
        if (!FilterEvaluator.evaluate(
          cellValue: cellValue,
          model: model,
          filterConfig: col.filter!,
        )) {
          passes = false;
          break;
        }
      }
      if (passes) filtered.add(row);
    }
    return filtered;
  }

  List<TData> _applyCustomFilters(List<TData> data) {
    if (_customFilterModels.isEmpty) return data;

    final flatCols = _allFlatColumns();
    final activeCustomFilters = <(OsCustomFilter, OsColumnDef)>[];
    for (final entry in _customFilterModels.entries) {
      final col = flatCols.cast<OsColumnDef?>().firstWhere(
        (c) => c!.effectiveColId == entry.key,
        orElse: () => null,
      );
      if (col == null) continue;
      final filterConfig = col.filter;
      if (filterConfig is! OsCustomFilter) continue;
      if (!filterConfig.isFilterActive(entry.value)) continue;
      activeCustomFilters.add((filterConfig, col));
    }

    final filtered = <TData>[];
    for (int i = 0; i < data.length; i++) {
      final row = data[i];
      var passes = true;
      for (final (filterConfig, col) in activeCustomFilters) {
        final cellValue = _resolveColumnValue(col, row, i);
        if (!filterConfig.doesFilterPass(
          cellValue,
          _customFilterModels[col.effectiveColId],
        )) {
          passes = false;
          break;
        }
      }
      if (passes) filtered.add(row);
    }
    return filtered;
  }

  List<TData> _applySort(List<TData> data) {
    if (!_sortService.isSortActive) {
      // No sort active — clear delta sort state.
      _setLastTouchedRows(null);
      _deltaSortService()?.invalidate();
      return data;
    }

    final flatCols = _allFlatColumns();

    // Try delta sort if enabled and we have touched rows from a transaction.
    // Delta sort is skipped when postSortRows is configured, since the
    // callback may reorder rows in ways that invalidate the merge baseline.
    List<TData>? deltaSorted;
    if (_deltaSortService() != null &&
        _lastTouchedRows() != null &&
        _postSortRows == null) {
      deltaSorted = _deltaSortService()!.tryDeltaSort(
        allRows: data,
        touchedRows: _lastTouchedRows()!,
        sortService: _sortService,
        columns: flatCols,
        valueResolver: _valueCacheEnabled
            ? (row, col) => getCachedValue(row, col)
            : null,
      );
    }

    List<TData> result;
    if (deltaSorted != null) {
      result = deltaSorted;
    } else {
      result = _sortService.sortData(
        data: data,
        columns: flatCols,
        valueResolver: _valueCacheEnabled
            ? (row, col) => getCachedValue(row, col)
            : null,
      );
      // Store the full sort result for future delta sorts.
      _deltaSortService()?.setPreviousResult(result);
    }

    // Clear touched rows after processing.
    _setLastTouchedRows(null);
    return result;
  }

  void _runPipeline(List<TData> source) {
    // Invalidate caches on data/sort/filter change
    _textPainterCache.clear();
    if (_valueCacheEnabled) {
      _valueCache.expire();
    }
    // The quick-filter cache must survive quick-filter-text-only
    // reprocesses (its whole purpose), so it is keyed on the source list
    // identity: a new rowData instance invalidates, the same instance
    // re-filtered/sorted does not.
    if (_cacheQuickFilterEnabled &&
        !identical(source, _quickFilterCacheSource)) {
      _quickFilterTextCache.clear();
      _quickFilterCacheSource = source;
    }

    List<TData> data = List.from(source);

    data = _applyQuickFilter(data, _quickFilterOverride());
    data = _applyExternalFilter(data);
    data = _applyColumnFilters(data);
    data = _applyCustomFilters(data);
    data = _applySort(data);

    if (_postSortRows != null) {
      data = _postSortRows(List.of(data));
    }

    _setProcessedRowData(data);
    _controller.processedData = data;

    _rebuildCellSpanCache(data);
  }

  void _rebuildCellSpanCache(List<TData> data) {
    if (_enableCellSpan) {
      _cellSpanService.buildCache(
        columns: _allFlatColumns(),
        rowData: data
            .map(
              (row) => row is Map<String, dynamic> ? row : <String, dynamic>{},
            )
            .toList(),
        enableCellSpan: true,
      );
    } else {
      _cellSpanService.buildCache(
        columns: const [],
        rowData: const [],
        enableCellSpan: false,
      );
    }
  }

  /// Returns the cached value for (row, column), computing via
  /// valueGetter/field lookup on miss.
  dynamic getCachedValue(TData row, OsColumnDef column) {
    final colId = column.effectiveColId;
    final rowId = _resolveRowIdForCache(row);

    final cached = _valueCache.getValue(rowId, colId);
    if (!identical(cached, ValueCache.notCached)) {
      return cached;
    }

    // Compute the value
    final valueGetter = column.getValueGetterAsFunction();
    dynamic value;
    if (valueGetter != null) {
      value = valueGetter(ValueGetterParams<TData>(data: row, rowIndex: -1));
    } else if (column.field != null && row is Map<String, dynamic>) {
      value = row[column.field];
    }

    _valueCache.setValue(rowId, colId, value);
    return value;
  }

  /// Resolves a row ID for cache keying.
  ///
  /// Uses the grid's `getRowId` if available, otherwise falls back to
  /// the object's identity hash code.
  String _resolveRowIdForCache(TData row) {
    final rowId = _getRowId(row);
    if (rowId != null) {
      return rowId;
    }
    return identityHashCode(row).toString();
  }

  /// Gets the uppercased text for a column's cell value, used for quick
  /// filter matching. Returns `null` if the value is null/empty.
  String? getQuickFilterTextForColumn(OsColumnDef col, TData row) {
    // Resolve value: use valueGetter if available, otherwise field lookup on Map
    dynamic value;
    if (col.valueGetter != null) {
      value = col.valueGetter!(ValueGetterParams(data: row, rowIndex: -1));
    } else if (col.field != null && row is Map<String, dynamic>) {
      value = row[col.field];
    }

    if (col.getQuickFilterText != null) {
      final params = GetQuickFilterTextParams(
        value: value,
        data: row,
        colDef: col,
      );
      final customText = col.getQuickFilterText!(params);
      return customText.isEmpty ? null : customText.toUpperCase();
    }

    if (value == null) return null;
    final text = value.toString();
    if (text.isEmpty) return null;
    return text.toUpperCase();
  }

  /// Builds the aggregate quick-filter text for a row across [cols].
  String buildQuickFilterAggregateText(TData row, List<OsColumnDef> cols) {
    final parts = <String>[];
    for (final col in cols) {
      final text = getQuickFilterTextForColumn(col, row);
      if (text != null) parts.add(text);
    }
    return parts.join('\n');
  }

  /// Cache-aware variant of [buildQuickFilterAggregateText]: per-column
  /// texts are served from the quick-filter cache when enabled.
  String _aggregateQuickFilterText(TData row, List<OsColumnDef> cols) {
    if (!_cacheQuickFilterEnabled) {
      return buildQuickFilterAggregateText(row, cols);
    }
    final parts = <String>[];
    for (final col in cols) {
      final text = _resolveQuickFilterText(col, row);
      if (text != null) parts.add(text);
    }
    return parts.join('\n');
  }

  /// Cache-aware wrapper around [getQuickFilterTextForColumn].
  ///
  /// On a miss the getter runs once and its (uppercased) result is
  /// stored; an empty string encodes a null column text.
  String? _resolveQuickFilterText(OsColumnDef col, TData row) {
    if (!_cacheQuickFilterEnabled) {
      return getQuickFilterTextForColumn(col, row);
    }
    final key = '${_resolveRowIdForCache(row)}\u0000${col.effectiveColId}';
    final cached = _quickFilterTextCache[key];
    if (cached != null) {
      return cached.isEmpty ? null : cached;
    }
    final computed = getQuickFilterTextForColumn(col, row) ?? '';
    _quickFilterTextCache[key] = computed;
    return computed.isEmpty ? null : computed;
  }

  bool _identicalColumns(List<OsColumnDef> a, List<OsColumnDef> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!identical(a[i], b[i])) return false;
    }
    return true;
  }

  bool _sameStrings(Set<String> a, Set<String> b) {
    if (a.length != b.length) return false;
    for (final value in a) {
      if (!b.contains(value)) return false;
    }
    return true;
  }
}
