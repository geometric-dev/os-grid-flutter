import 'dart:collection' show MapBase;

import '../cache/value_cache.dart';
import '../columns/os_column_def.dart';
import '../params/value_getter_params.dart';

/// Per-cell lazy display map for typed (non-Map) rows (quality program v3
/// item 15).
///
/// The canvas renderer reads `Map<String, dynamic>` rows; typed rows are
/// converted via their columns' valueGetters on the way into the widget.
/// Before this class that conversion ran EVERY column's getter for EVERY row
/// on EVERY build — for the whole data set, long before paint needed a cell.
/// Wrapping a typed row in this map defers each valueGetter until its cell's
/// value is first read — typically when the cell enters the visible window
/// and the body painter paints it — and memoizes the result for the map's
/// lifetime, so the three per-frame section passes (leading / center /
/// trailing) share one evaluation per cell.
///
/// When a [ValueCache] and a `rowId` are supplied, evaluations are
/// additionally served from and mirrored into the grid-level (rowId, colId)
/// cache. The pipeline expires that cache on every data/sort/filter
/// reprocess, giving the memoize-per-(rowId, colId, dataVersion) contract;
/// without it, only the per-instance memo applies.
///
/// Writes are write-through: an assignment records an override shadowing the
/// getter for subsequent reads (same-build read-after-write parity with
/// eager maps; cross-build persistence stays the pipeline's job, exactly as
/// with the eager conversion this class replaces).
///
/// Only getter-bearing, non-`__`-prefixed fields appear in [keys] and
/// [containsKey] — identical key semantics to the eager
/// `GridModelResolver.typedRowToMap`, whose output this map is
/// value-compatible with for every read.
class LazyValueRowMap<TData> extends MapBase<String, dynamic> {
  /// Wraps [row]. [columnsByField] must map field name → column for exactly
  /// the getter-bearing, non-`__`-prefixed fields (see the static
  /// `GridModelResolver.buildLazyFieldIndex`); it is shared across all rows
  /// of one conversion pass.
  LazyValueRowMap({
    required TData row,
    required this.rowIndex,
    required Map<String, OsColumnDef> columnsByField,
    ValueCache? valueCache,
    String? rowId,
  }) : _row = row,
       _columnsByField = columnsByField,
       _valueCache = valueCache,
       _rowId = rowId;

  /// The row's display index, forwarded to every valueGetter params object.
  final int rowIndex;

  final TData _row;
  final Map<String, OsColumnDef> _columnsByField;
  final ValueCache? _valueCache;
  final String? _rowId;

  /// Values written through `operator []=`, shadowing the getters.
  final Map<String, dynamic> _overrides = {};

  /// Per-instance memoization: one valueGetter call per (row, field) per
  /// map lifetime — shared by every reader of the row within a build.
  final Map<String, dynamic> _memo = {};

  /// Getter-bearing fields hidden by [remove] / [clear].
  final Set<String> _removed = {};

  @override
  Iterable<String> get keys {
    final getterFields = _columnsByField.keys.where(
      (field) => !_removed.contains(field),
    );
    final extraOverrides = _overrides.keys.where(
      (field) => !_columnsByField.containsKey(field),
    );
    return getterFields.followedBy(extraOverrides);
  }

  @override
  bool containsKey(Object? key) =>
      key is String &&
      !_removed.contains(key) &&
      (_overrides.containsKey(key) || _columnsByField.containsKey(key));

  @override
  dynamic operator [](Object? key) {
    if (key is! String) return null;
    final override = _overrides[key];
    if (override != null || _overrides.containsKey(key)) return override;
    if (_removed.contains(key)) return null;
    if (!_columnsByField.containsKey(key)) return null;
    if (_memo.containsKey(key)) return _memo[key];
    return _evaluate(key);
  }

  /// Runs the field's valueGetter (at most once per map lifetime per field)
  /// and memoizes the result, round-tripping through the grid-level
  /// [ValueCache] when one is wired in.
  dynamic _evaluate(String field) {
    final column = _columnsByField[field]!;
    final getter = column.getValueGetterAsFunction();
    if (getter == null) return _memo[field] = null;

    final cache = _valueCache;
    final rowId = _rowId;
    if (cache != null && rowId != null) {
      final cached = cache.getValue(rowId, column.effectiveColId);
      if (!identical(cached, ValueCache.notCached)) {
        return _memo[field] = cached;
      }
      final value = Function.apply(getter, [
        ValueGetterParams<TData>(data: _row, rowIndex: rowIndex),
      ]);
      cache.setValue(rowId, column.effectiveColId, value);
      return _memo[field] = value;
    }

    return _memo[field] = Function.apply(getter, [
      ValueGetterParams<TData>(data: _row, rowIndex: rowIndex),
    ]);
  }

  @override
  void operator []=(String key, dynamic value) {
    _removed.remove(key);
    _overrides[key] = value;
    _memo[key] = value;
  }

  @override
  dynamic remove(Object? key) {
    if (key is! String || !containsKey(key)) return null;
    final value = this[key];
    _overrides.remove(key);
    _memo.remove(key);
    if (_columnsByField.containsKey(key)) _removed.add(key);
    return value;
  }

  @override
  void clear() {
    _overrides.clear();
    _memo.clear();
    _removed.addAll(_columnsByField.keys);
  }
}
