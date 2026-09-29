/// Grid state model for save/restore functionality.
///
/// Captures a snapshot of the grid's current state (sort, filter, columns,
/// pagination, selection, scroll) that can be serialised and later restored.
///
/// Mirrors the OS Grid TypeScript `GridState` interface, including only
/// the sub-states relevant to the Flutter port.
library;

import '../sorting/sort_model.dart';

/// Complete grid state snapshot.
///
/// Each property is optional — a partial state can be provided to
/// `OsGridController.setState` to restore only specific aspects.
///
/// ```dart
/// // Save state
/// final state = controller.getState();
///
/// // Restore later
/// controller.setState(state);
///
/// // Restore only sort and filter
/// controller.setState(OsGridState(
///   sort: state.sort,
///   filter: state.filter,
/// ));
/// ```
class OsGridState {
  /// Creates a grid state snapshot.
  const OsGridState({
    this.sort,
    this.filter,
    this.columnPinning,
    this.columnVisibility,
    this.columnSizing,
    this.columnOrder,
    this.pagination,
    this.rowSelection,
    this.cellSelection,
    this.scroll,
  });

  /// Current sort columns and directions.
  final SortState? sort;

  /// Current filter model (column filters).
  final FilterState? filter;

  /// Columns pinned left and right.
  final ColumnPinningState? columnPinning;

  /// Hidden column IDs.
  final ColumnVisibilityState? columnVisibility;

  /// Column width/flex overrides.
  final ColumnSizingState? columnSizing;

  /// Column display order.
  final ColumnOrderState? columnOrder;

  /// Current pagination page and page size.
  final PaginationState? pagination;

  /// Currently selected row IDs.
  final RowSelectionState? rowSelection;

  /// Currently selected cell ranges.
  final CellSelectionState? cellSelection;

  /// Current scroll position.
  final ScrollState? scroll;

  /// Creates a state from a JSON map (for deserialisation).
  ///
  /// The JSON structure matches the OS Grid TypeScript format for
  /// interoperability.
  factory OsGridState.fromJson(Map<String, dynamic> json) {
    return OsGridState(
      sort: json['sort'] != null
          ? SortState.fromJson(json['sort'] as Map<String, dynamic>)
          : null,
      filter: json['filter'] != null
          ? FilterState.fromJson(json['filter'] as Map<String, dynamic>)
          : null,
      columnPinning: json['columnPinning'] != null
          ? ColumnPinningState.fromJson(
              json['columnPinning'] as Map<String, dynamic>,
            )
          : null,
      columnVisibility: json['columnVisibility'] != null
          ? ColumnVisibilityState.fromJson(
              json['columnVisibility'] as Map<String, dynamic>,
            )
          : null,
      columnSizing: json['columnSizing'] != null
          ? ColumnSizingState.fromJson(
              json['columnSizing'] as Map<String, dynamic>,
            )
          : null,
      columnOrder: json['columnOrder'] != null
          ? ColumnOrderState.fromJson(
              json['columnOrder'] as Map<String, dynamic>,
            )
          : null,
      pagination: json['pagination'] != null
          ? PaginationState.fromJson(json['pagination'] as Map<String, dynamic>)
          : null,
      rowSelection: json['rowSelection'] != null
          ? RowSelectionState.fromJson(
              json['rowSelection'] as Map<String, dynamic>,
            )
          : null,
      cellSelection: json['cellSelection'] != null
          ? CellSelectionState.fromJson(
              json['cellSelection'] as Map<String, dynamic>,
            )
          : null,
      scroll: json['scroll'] != null
          ? ScrollState.fromJson(json['scroll'] as Map<String, dynamic>)
          : null,
    );
  }

  /// Converts this state to a JSON map (for serialisation).
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (sort != null) map['sort'] = sort!.toJson();
    if (filter != null) map['filter'] = filter!.toJson();
    if (columnPinning != null) {
      map['columnPinning'] = columnPinning!.toJson();
    }
    if (columnVisibility != null) {
      map['columnVisibility'] = columnVisibility!.toJson();
    }
    if (columnSizing != null) map['columnSizing'] = columnSizing!.toJson();
    if (columnOrder != null) map['columnOrder'] = columnOrder!.toJson();
    if (pagination != null) map['pagination'] = pagination!.toJson();
    if (rowSelection != null) map['rowSelection'] = rowSelection!.toJson();
    if (cellSelection != null) map['cellSelection'] = cellSelection!.toJson();
    if (scroll != null) map['scroll'] = scroll!.toJson();
    return map;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OsGridState &&
          sort == other.sort &&
          filter == other.filter &&
          columnPinning == other.columnPinning &&
          columnVisibility == other.columnVisibility &&
          columnSizing == other.columnSizing &&
          columnOrder == other.columnOrder &&
          pagination == other.pagination &&
          rowSelection == other.rowSelection &&
          cellSelection == other.cellSelection &&
          scroll == other.scroll;

  @override
  int get hashCode => Object.hash(
    sort,
    filter,
    columnPinning,
    columnVisibility,
    columnSizing,
    columnOrder,
    pagination,
    rowSelection,
    cellSelection,
    scroll,
  );
}

// --- Sub-state classes ---

/// Sort state: sorted columns and directions in priority order.
class SortState {
  const SortState({required this.sortModel});

  /// Sorted columns and directions in order (index 0 = primary sort).
  final List<OsSortModel> sortModel;

  factory SortState.fromJson(Map<String, dynamic> json) {
    final list = (json['sortModel'] as List<dynamic>?) ?? [];
    return SortState(
      sortModel: list
          .map((e) => OsSortModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'sortModel': sortModel.map((m) => m.toJson()).toList(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SortState && _listEquals(sortModel, other.sortModel);

  @override
  int get hashCode => Object.hashAll(sortModel);
}

/// Filter state: column filter model.
class FilterState {
  const FilterState({this.filterModel});

  /// Filter model — map of column IDs to filter configuration.
  /// Matches the OS Grid TypeScript filter model format.
  final Map<String, dynamic>? filterModel;

  factory FilterState.fromJson(Map<String, dynamic> json) {
    return FilterState(
      filterModel: json['filterModel'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
    if (filterModel != null) 'filterModel': filterModel,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FilterState && _mapEquals(filterModel, other.filterModel);

  @override
  int get hashCode => filterModel?.hashCode ?? 0;
}

/// Column pinning state: which columns are pinned left/right.
class ColumnPinningState {
  const ColumnPinningState({
    this.leftColIds = const [],
    this.rightColIds = const [],
  });

  /// Column IDs pinned to the left.
  final List<String> leftColIds;

  /// Column IDs pinned to the right.
  final List<String> rightColIds;

  factory ColumnPinningState.fromJson(Map<String, dynamic> json) {
    return ColumnPinningState(
      leftColIds:
          (json['leftColIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      rightColIds:
          (json['rightColIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
    'leftColIds': leftColIds,
    'rightColIds': rightColIds,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ColumnPinningState &&
          _listEquals(leftColIds, other.leftColIds) &&
          _listEquals(rightColIds, other.rightColIds);

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(leftColIds), Object.hashAll(rightColIds));
}

/// Column visibility state: which columns are hidden.
class ColumnVisibilityState {
  const ColumnVisibilityState({this.hiddenColIds = const []});

  /// Column IDs that are currently hidden.
  final List<String> hiddenColIds;

  factory ColumnVisibilityState.fromJson(Map<String, dynamic> json) {
    return ColumnVisibilityState(
      hiddenColIds:
          (json['hiddenColIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {'hiddenColIds': hiddenColIds};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ColumnVisibilityState &&
          _listEquals(hiddenColIds, other.hiddenColIds);

  @override
  int get hashCode => Object.hashAll(hiddenColIds);
}

/// Individual column size entry.
class ColumnSizeEntry {
  const ColumnSizeEntry({required this.colId, this.width, this.flex});

  /// Column identifier.
  final String colId;

  /// Fixed width in logical pixels (mutually exclusive with [flex]).
  final double? width;

  /// Flex factor (mutually exclusive with [width]).
  final double? flex;

  factory ColumnSizeEntry.fromJson(Map<String, dynamic> json) {
    return ColumnSizeEntry(
      colId: json['colId'] as String,
      width: (json['width'] as num?)?.toDouble(),
      flex: (json['flex'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'colId': colId,
    if (width != null) 'width': width,
    if (flex != null) 'flex': flex,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ColumnSizeEntry &&
          colId == other.colId &&
          width == other.width &&
          flex == other.flex;

  @override
  int get hashCode => Object.hash(colId, width, flex);
}

/// Column sizing state: width/flex for each column.
class ColumnSizingState {
  const ColumnSizingState({this.columnSizingModel = const []});

  /// List of column size entries.
  final List<ColumnSizeEntry> columnSizingModel;

  factory ColumnSizingState.fromJson(Map<String, dynamic> json) {
    final list = (json['columnSizingModel'] as List<dynamic>?) ?? [];
    return ColumnSizingState(
      columnSizingModel: list
          .map((e) => ColumnSizeEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'columnSizingModel': columnSizingModel.map((e) => e.toJson()).toList(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ColumnSizingState &&
          _listEquals(columnSizingModel, other.columnSizingModel);

  @override
  int get hashCode => Object.hashAll(columnSizingModel);
}

/// Column order state: display order of all columns.
class ColumnOrderState {
  const ColumnOrderState({this.orderedColIds = const []});

  /// All column IDs in display order.
  final List<String> orderedColIds;

  factory ColumnOrderState.fromJson(Map<String, dynamic> json) {
    return ColumnOrderState(
      orderedColIds:
          (json['orderedColIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {'orderedColIds': orderedColIds};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ColumnOrderState &&
          _listEquals(orderedColIds, other.orderedColIds);

  @override
  int get hashCode => Object.hashAll(orderedColIds);
}

/// Pagination state: current page and page size.
class PaginationState {
  const PaginationState({this.page, this.pageSize});

  /// Current page (0-indexed).
  final int? page;

  /// Current page size.
  final int? pageSize;

  factory PaginationState.fromJson(Map<String, dynamic> json) {
    return PaginationState(
      page: json['page'] as int?,
      pageSize: json['pageSize'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
    if (page != null) 'page': page,
    if (pageSize != null) 'pageSize': pageSize,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaginationState &&
          page == other.page &&
          pageSize == other.pageSize;

  @override
  int get hashCode => Object.hash(page, pageSize);
}

/// Row selection state: selected row IDs.
class RowSelectionState {
  const RowSelectionState({this.selectedRowIds = const []});

  /// IDs of currently selected rows.
  final List<String> selectedRowIds;

  factory RowSelectionState.fromJson(Map<String, dynamic> json) {
    return RowSelectionState(
      selectedRowIds:
          (json['selectedRowIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {'selectedRowIds': selectedRowIds};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RowSelectionState &&
          _listEquals(selectedRowIds, other.selectedRowIds);

  @override
  int get hashCode => Object.hashAll(selectedRowIds);
}

/// Individual cell range in the state.
class CellSelectionCellState {
  const CellSelectionCellState({
    required this.startRow,
    required this.endRow,
    required this.startColumn,
    required this.endColumn,
  });

  /// Start row index of the range.
  final int startRow;

  /// End row index of the range.
  final int endRow;

  /// Start column index of the range.
  final int startColumn;

  /// End column index of the range.
  final int endColumn;

  factory CellSelectionCellState.fromJson(Map<String, dynamic> json) {
    return CellSelectionCellState(
      startRow: json['startRow'] as int,
      endRow: json['endRow'] as int,
      startColumn: json['startColumn'] as int,
      endColumn: json['endColumn'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
    'startRow': startRow,
    'endRow': endRow,
    'startColumn': startColumn,
    'endColumn': endColumn,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CellSelectionCellState &&
          startRow == other.startRow &&
          endRow == other.endRow &&
          startColumn == other.startColumn &&
          endColumn == other.endColumn;

  @override
  int get hashCode => Object.hash(startRow, endRow, startColumn, endColumn);
}

/// Cell selection state: all active cell ranges.
class CellSelectionState {
  const CellSelectionState({this.cellRanges = const []});

  /// List of active cell ranges.
  final List<CellSelectionCellState> cellRanges;

  factory CellSelectionState.fromJson(Map<String, dynamic> json) {
    final list = (json['cellRanges'] as List<dynamic>?) ?? [];
    return CellSelectionState(
      cellRanges: list
          .map(
            (e) => CellSelectionCellState.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'cellRanges': cellRanges.map((e) => e.toJson()).toList(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CellSelectionState && _listEquals(cellRanges, other.cellRanges);

  @override
  int get hashCode => Object.hashAll(cellRanges);
}

/// Scroll position state.
class ScrollState {
  const ScrollState({this.top = 0, this.left = 0});

  /// Vertical scroll offset in logical pixels.
  final double top;

  /// Horizontal scroll offset in logical pixels.
  final double left;

  factory ScrollState.fromJson(Map<String, dynamic> json) {
    return ScrollState(
      top: (json['top'] as num?)?.toDouble() ?? 0,
      left: (json['left'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {'top': top, 'left': left};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScrollState && top == other.top && left == other.left;

  @override
  int get hashCode => Object.hash(top, left);
}

// --- Utility helpers ---

bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool _mapEquals(Map<String, dynamic>? a, Map<String, dynamic>? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null) return a == b;
  if (a.length != b.length) return false;
  for (final key in a.keys) {
    if (!b.containsKey(key) || a[key] != b[key]) return false;
  }
  return true;
}
