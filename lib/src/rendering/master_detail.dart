/// Wire-format keys and expansion state for master/detail rows
/// (quality program v3 item 4).
///
/// Master/detail follows the same display-list strategy as row grouping:
/// expanded master rows are followed by a synthetic detail row in the
/// display list, marked with [MasterDetailKeys.isDetailRow]. Master rows
/// themselves are annotated with [MasterDetailKeys.isMasterRow] so hit
/// testing and the painter can identify them without re-invoking the
/// user's `isMasterRow` callback.
library;

/// Keys used to identify master/detail metadata in Map-based display data.
///
/// Regular data rows do not have [isMasterRow] or [isDetailRow] set.
abstract final class MasterDetailKeys {
  /// Whether this display row is a master row (can expand a detail area).
  static const String isMasterRow = '__isMasterRow';

  /// Whether this display row is a synthetic detail row.
  static const String isDetailRow = '__isDetailRow';

  /// The source data (TData) of the master row that owns a detail row.
  static const String detailSource = '__detailSource';

  /// Display index of the master row that owns a detail row.
  static const String detailMasterIndex = '__detailMasterIndex';

  /// Stable row id of the master row that owns a detail row.
  ///
  /// Used as the widget key for the detail overlay so detail state
  /// survives scroll rebuilds.
  static const String detailRowId = '__detailRowId';
}

/// Default height of a detail row when the `detailRowHeight` grid option
/// is not provided.
const double kDefaultDetailRowHeight = 300.0;

/// Tracks which master rows currently have their detail area expanded.
///
/// Mirrors the `RowGroupState` pattern (quality program v3 item 4): state
/// is keyed by stable row id so it survives sort/filter/rebuilds as long
/// as the same row identity exists.
class DetailExpansionState {
  final Set<String> _expandedRowIds = {};

  /// Returns whether the master row with [rowId] is expanded.
  bool isExpanded(String rowId) => _expandedRowIds.contains(rowId);

  /// Expands the detail area of the master row with [rowId].
  void expand(String rowId) => _expandedRowIds.add(rowId);

  /// Collapses the detail area of the master row with [rowId].
  void collapse(String rowId) => _expandedRowIds.remove(rowId);

  /// Sets the expansion state of the master row with [rowId].
  void setExpanded(String rowId, {required bool expanded}) {
    if (expanded) {
      expand(rowId);
    } else {
      collapse(rowId);
    }
  }

  /// Collapses every expanded detail area.
  void clear() => _expandedRowIds.clear();

  /// IDs of the currently expanded master rows (for diagnostics).
  Set<String> get expandedRowIds => Set.unmodifiable(_expandedRowIds);
}
