import 'package:os_grid_flutter/os_grid_flutter.dart'
    show OsColumnDef, OsGridController;

import '../sorting/sort_direction.dart';
import 'os_column_pin.dart';

/// Serialisable snapshot of a single column's state.
///
/// Used by [OsGridController.getColumnState] and [OsGridController.applyColumnState]
/// to save and restore column configuration (visibility, width, pinning, order, sort).
///
/// Mirrors OS Grid's `ColumnState` interface.
class ColumnState {
  /// Creates a column state snapshot.
  const ColumnState({
    required this.colId,
    this.hide,
    this.width,
    this.flex,
    this.pinned,
    this.sort,
    this.sortIndex,
  });

  /// The column identifier (matches [OsColumnDef.effectiveColId]).
  final String colId;

  /// Whether the column is hidden. Null means use the column definition default.
  final bool? hide;

  /// The column width in logical pixels. Null means use the column definition default.
  final double? width;

  /// The column flex factor. Null means no flex override.
  final int? flex;

  /// The column pin state. Null means not pinned.
  final OsColumnPin? pinned;

  /// The sort direction for this column. Null means not sorted.
  final OsSortDirection? sort;

  /// The sort priority index (0-based) for multi-column sort.
  ///
  /// Only meaningful when multiple columns are sorted. Lower values
  /// indicate higher priority (sorted first).
  final int? sortIndex;

  /// Creates a copy with the given fields replaced.
  ColumnState copyWith({
    String? colId,
    bool? hide,
    double? width,
    int? flex,
    OsColumnPin? pinned,
    OsSortDirection? sort,
    int? sortIndex,
    bool clearHide = false,
    bool clearWidth = false,
    bool clearFlex = false,
    bool clearPinned = false,
    bool clearSort = false,
    bool clearSortIndex = false,
  }) {
    return ColumnState(
      colId: colId ?? this.colId,
      hide: clearHide ? null : (hide ?? this.hide),
      width: clearWidth ? null : (width ?? this.width),
      flex: clearFlex ? null : (flex ?? this.flex),
      pinned: clearPinned ? null : (pinned ?? this.pinned),
      sort: clearSort ? null : (sort ?? this.sort),
      sortIndex: clearSortIndex ? null : (sortIndex ?? this.sortIndex),
    );
  }

  /// Converts this state to a JSON-compatible map.
  Map<String, dynamic> toJson() {
    return {
      'colId': colId,
      if (hide != null) 'hide': hide,
      if (width != null) 'width': width,
      if (flex != null) 'flex': flex,
      if (pinned != null)
        'pinned': pinned == OsColumnPin.left ? 'left' : 'right',
      if (sort != null)
        'sort': sort == OsSortDirection.ascending ? 'asc' : 'desc',
      if (sortIndex != null) 'sortIndex': sortIndex,
    };
  }

  /// Creates a [ColumnState] from a JSON-compatible map.
  factory ColumnState.fromJson(Map<String, dynamic> json) {
    OsColumnPin? pinned;
    final pinnedValue = json['pinned'];
    if (pinnedValue == 'left' || pinnedValue == true) {
      pinned = OsColumnPin.left;
    } else if (pinnedValue == 'right') {
      pinned = OsColumnPin.right;
    }

    OsSortDirection? sort;
    final sortValue = json['sort'];
    if (sortValue == 'asc') {
      sort = OsSortDirection.ascending;
    } else if (sortValue == 'desc') {
      sort = OsSortDirection.descending;
    }

    return ColumnState(
      colId: json['colId'] as String,
      hide: json['hide'] as bool?,
      width: (json['width'] as num?)?.toDouble(),
      flex: json['flex'] as int?,
      pinned: pinned,
      sort: sort,
      sortIndex: json['sortIndex'] as int?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ColumnState &&
          runtimeType == other.runtimeType &&
          colId == other.colId &&
          hide == other.hide &&
          width == other.width &&
          flex == other.flex &&
          pinned == other.pinned &&
          sort == other.sort &&
          sortIndex == other.sortIndex;

  @override
  int get hashCode =>
      Object.hash(colId, hide, width, flex, pinned, sort, sortIndex);

  @override
  String toString() =>
      'ColumnState(colId: $colId, hide: $hide, width: $width, flex: $flex, pinned: $pinned, sort: $sort, sortIndex: $sortIndex)';
}

/// Parameters for [OsGridController.applyColumnState].
///
/// Mirrors OS Grid's `ApplyColumnStateParams` interface.
class ApplyColumnStateParams {
  /// Creates parameters for applying column state.
  const ApplyColumnStateParams({
    this.state,
    this.applyOrder = false,
    this.defaultState,
    this.purge = false,
  });

  /// The column states to apply. Each entry targets a column by [ColumnState.colId].
  final List<ColumnState>? state;

  /// Whether to reorder columns to match the order of [state].
  ///
  /// When true, columns are reordered so their display order matches the
  /// order of entries in [state]. Columns not present in [state] are
  /// appended at the end.
  final bool applyOrder;

  /// Default state to apply to columns not present in [state].
  ///
  /// When provided, any column whose colId is not found in [state] will
  /// have this default state applied (e.g., to reset all other columns
  /// to a known state).
  final ColumnState? defaultState;

  /// Whether to remove ALL existing column state before applying [state].
  ///
  /// When true, every width override, pin override, visibility override,
  /// column-order override and the sort model are discarded first —
  /// equivalent to calling [OsGridController.resetColumnState] and then
  /// applying [state] on top. Columns absent from [state] therefore end
  /// up at their definition defaults rather than keeping prior overrides.
  ///
  /// Defaults to `false` (merge semantics: only listed fields change).
  final bool purge;
}
