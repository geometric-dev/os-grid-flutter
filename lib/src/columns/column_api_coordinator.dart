import 'dart:async';

import 'package:flutter/material.dart';

import '../columns/column_state.dart';
import '../columns/os_column_def.dart';
import '../columns/os_column_pin.dart';
import '../events/column_events.dart';
import '../os_grid_controller.dart';
import '../sorting/sort_direction.dart';
import '../sorting/sort_model.dart';

/// Cached autosize measurement for a single column (quality program v3
/// item 42).
///
/// Stores the widest measured content width (header + cells) together with
/// a fingerprint of the inputs that produced it: the row-list identity,
/// its length, the text styles and the active [TextScaler]. A cached entry
/// is reused only when every input still matches, so repeated autosize
/// calls on unchanged data skip all `TextPainter.layout()` work.
class _AutosizeMeasurement {
  const _AutosizeMeasurement({
    required this.rowsIdentity,
    required this.rowCount,
    required this.maxContentWidth,
    required this.headerStyle,
    required this.cellStyle,
    required this.scaler,
    required this.includesHeader,
  });

  /// Identity of the row list that was measured (`null` = no row data).
  ///
  /// Any `setRowData` / `applyTransaction` produces a fresh list instance
  /// (and the coordinator additionally clears the whole cache when the
  /// controller emits those changes, which also covers in-place edits), so
  /// an identity mismatch forces a re-measure.
  final Object? rowsIdentity;

  /// Length of the measured row list (guards against in-place resizes).
  final int rowCount;

  /// Widest single-line content width across header and cells.
  final double maxContentWidth;

  final TextStyle headerStyle;
  final TextStyle cellStyle;
  final TextScaler scaler;

  /// Whether the header text contributed to [maxContentWidth].
  ///
  /// A `skipHeader: true` measurement must never be served to a call that
  /// does include the header, so the flag is part of the fingerprint.
  final bool includesHeader;

  /// Whether this entry can be reused for [rows] rendered with the given
  /// styles and scaler.
  bool matches(
    List<Object?>? rows,
    TextStyle headerStyle,
    TextStyle cellStyle,
    TextScaler scaler, {
    required bool includesHeader,
  }) {
    if (!identical(rowsIdentity, rows)) return false;
    if (rows != null && rowCount != rows.length) return false;
    if (this.includesHeader != includesHeader) return false;
    return this.headerStyle == headerStyle &&
        this.cellStyle == cellStyle &&
        this.scaler == scaler;
  }
}

/// Owns column view-state (widths / pins / visibility / order) and the
/// column-API behaviours that manipulate it.
///
/// Extracted from `_OsGridState`. The four maps are owned here; the owning
/// State exposes compatibility getters so existing call sites keep working.
class ColumnApiCoordinator<TData> {
  /// Creates a coordinator.
  ///
  /// All grid-owned collaborators are supplied as closures/getters so they
  /// always read live state from the owning `State`.
  ColumnApiCoordinator({
    required OsGridController<TData> controller,
    required List<OsColumnDef> Function() allFlatColumns,
    required int Function() syntheticOffset,
    required List<TData>? Function() resolveRows,
    required dynamic Function(OsColumnDef col, TData row, int rowIndex)
    resolveCellValue,
    required void Function(String colId) clearTextCacheFor,
    required void Function(List<OsSortModel> model) setSortModel,
    required void Function() clearSort,
    required void Function() invalidateDeltaSort,
    required void Function() resetLegacySortIndex,
    required void Function() emitSortChanged,
    required void Function() reprocess,
    required void Function() initHiddenFromDefs,
    required void Function(String source) notifyStateChanged,
    required void Function(VoidCallback) mutate,
    required TextStyle Function() headerTextStyle,
    required TextStyle Function() cellTextStyle,
    required TextScaler Function() textScaler,
    required void Function(OsColumnVisibleEvent)? onColumnVisible,
    required void Function(OsColumnPinnedEvent)? onColumnPinned,
    required void Function(OsColumnResizedEvent)? onColumnResized,
    required void Function(OsColumnMovedEvent)? onColumnMoved,
  }) : _controller = controller,
       _allFlatColumns = allFlatColumns,
       _syntheticOffset = syntheticOffset,
       _resolveRows = resolveRows,
       _resolveCellValue = resolveCellValue,
       _clearTextCacheFor = clearTextCacheFor,
       _setSortModel = setSortModel,
       _clearSort = clearSort,
       _invalidateDeltaSort = invalidateDeltaSort,
       _resetLegacySortIndex = resetLegacySortIndex,
       _emitSortChanged = emitSortChanged,
       _reprocess = reprocess,
       _initHiddenFromDefs = initHiddenFromDefs,
       _notifyStateChanged = notifyStateChanged,
       _mutate = mutate,
       _headerTextStyle = headerTextStyle,
       _cellTextStyle = cellTextStyle,
       _textScaler = textScaler,
       _onColumnVisible = onColumnVisible,
       _onColumnPinned = onColumnPinned,
       _onColumnResized = onColumnResized,
       _onColumnMoved = onColumnMoved {
    _subscribeDataChanges();
  }

  /// Subscribes autosize invalidation to the live controller's data-change
  /// streams.
  ///
  /// `onRowDataUpdated` fires for setRowData / applyTransaction,
  /// `onCellValueChanged` for committed cell edits (which mutate row maps
  /// in place and would otherwise be invisible to identity checks).
  void _subscribeDataChanges() {
    _dataChangeSubscriptions
      ..add(
        _controller.onRowDataUpdated.listen(
          (_) => _autosizeMeasurements.clear(),
        ),
      )
      ..add(
        _controller.onCellValueChanged.listen(
          (_) => _autosizeMeasurements.clear(),
        ),
      );
  }

  /// The live controller. Mutable only for runtime controller swaps —
  /// see [rebind].
  OsGridController<TData> _controller;

  /// Re-points the coordinator at [controller] after a runtime controller
  /// swap: clears the request hooks this coordinator owns on the outgoing
  /// controller, cancels its data subscriptions, then re-subscribes and
  /// re-runs [attach] against the new one. Column state (widths, pins,
  /// visibility, order) survives the swap — it tracks columns, not the
  /// controller instance.
  void rebind(OsGridController<TData> controller) {
    _controller
      ..onSetColumnsVisibleRequested = null
      ..onSetColumnsPinnedRequested = null
      ..onApplyColumnStateRequested = null
      ..onResetColumnStateRequested = null
      ..onGetDisplayedColAfterRequested = null
      ..onGetDisplayedColBeforeRequested = null
      ..onSetColumnWidthsRequested = null
      ..onAutoSizeColumnsRequested = null
      ..onMoveColumnByIndexRequested = null
      ..onMoveColumnsRequested = null;
    dispose();
    _controller = controller;
    _subscribeDataChanges();
    attach();
  }

  final List<OsColumnDef> Function() _allFlatColumns;
  final int Function() _syntheticOffset;
  final List<TData>? Function() _resolveRows;
  final dynamic Function(OsColumnDef col, TData row, int rowIndex)
  _resolveCellValue;
  final void Function(String colId) _clearTextCacheFor;
  final void Function(List<OsSortModel> model) _setSortModel;
  final void Function() _clearSort;
  final void Function() _invalidateDeltaSort;
  final void Function() _resetLegacySortIndex;
  final void Function() _emitSortChanged;
  final void Function() _reprocess;
  final void Function() _initHiddenFromDefs;
  final void Function(String source) _notifyStateChanged;
  final void Function(VoidCallback) _mutate;
  final TextStyle Function() _headerTextStyle;
  final TextStyle Function() _cellTextStyle;
  final TextScaler Function() _textScaler;
  final void Function(OsColumnVisibleEvent)? _onColumnVisible;
  final void Function(OsColumnPinnedEvent)? _onColumnPinned;
  final void Function(OsColumnResizedEvent)? _onColumnResized;
  final void Function(OsColumnMovedEvent)? _onColumnMoved;

  /// Column width overrides keyed by colId.
  final Map<String, double> widths = {};

  /// Pin overrides keyed by colId (null value = explicitly unpinned).
  final Map<String, OsColumnPin?> pins = {};

  /// Hidden column IDs.
  final Set<String> hiddenIds = {};

  /// Autosize measurement cache keyed by colId (quality program v3 item
  /// 42). Owned per-coordinator rather than static/global so two grids
  /// with the same colIds can never serve each other stale widths.
  final Map<String, _AutosizeMeasurement> _autosizeMeasurements = {};

  /// Number of `TextPainter.layout()` calls issued by autosize paths.
  ///
  /// Exposed for tests: a second autosize over unchanged data must not
  /// grow this counter (measurement cache hit).
  @visibleForTesting
  int get autosizeLayoutCount => _autosizeLayoutCount;
  int _autosizeLayoutCount = 0;

  /// Cache invalidation subscriptions — cleared on any controller-side
  /// data change (`setRowData`, `applyTransaction`, cell edits) so cached
  /// measurements never outlive the data they were measured from.
  final List<StreamSubscription<void>> _dataChangeSubscriptions = [];

  /// Current display order (null = original definition order).
  List<String>? order;

  /// Resolves a display index (after synthetic columns) to a colId using
  /// the current visible ordering. Returns null when out of bounds.
  String? _colIdForDisplayIndex(int columnIndex) {
    final flatCols = _allFlatColumns();
    final adjustedIndex = columnIndex - _syntheticOffset();
    if (adjustedIndex < 0 || adjustedIndex >= flatCols.length) return null;

    final displayOrder =
        order ?? flatCols.map((c) => c.effectiveColId).toList();
    final visibleOrder = displayOrder
        .where((id) => !hiddenIds.contains(id))
        .toList();
    if (adjustedIndex >= visibleOrder.length) return null;

    return visibleOrder[adjustedIndex];
  }

  /// Handles a header drag-resize of the column at [columnIndex].
  void handleResize(int columnIndex, double newWidth) {
    final colId = _colIdForDisplayIndex(columnIndex);
    if (colId == null) return; // Synthetic column or out of range

    _mutate(() {
      widths[colId] = newWidth;
      _clearTextCacheFor(colId);
      syncToController();
    });

    // Emit column resized event
    final event = OsColumnResizedEvent(
      columns: [ColumnResizeEntry(colId: colId, width: newWidth)],
      finished: true,
      source: 'uiColumnDragged',
    );
    _onColumnResized?.call(event);
    _controller.emitColumnResized(event);
    _notifyStateChanged('columnSizing');
  }

  /// Mirrors the current column state into the controller for API queries.
  void syncToController() {
    _controller.columnWidthState = widths;
    _controller.columnPinState = pins;
    _controller.hiddenColumnIds = hiddenIds;
    _controller.columnOrder = order;
  }

  /// Wires the column-API controller callbacks (visibility, pinning,
  /// apply/reset state, width setting, moves).
  void attach() {
    _controller.onSetColumnsVisibleRequested = (colIds, visible) {
      // Filter out columns with lockVisible set
      final effectiveColIds = colIds.where((colId) {
        final col = _controller.getColumnDef(colId);
        return col?.lockVisible != true;
      }).toList();

      if (effectiveColIds.isEmpty) return;

      _mutate(() {
        if (visible) {
          hiddenIds.removeAll(effectiveColIds);
        } else {
          hiddenIds.addAll(effectiveColIds);
        }
        syncToController();
      });
      final event = OsColumnVisibleEvent(
        columns: effectiveColIds,
        visible: visible,
      );
      _onColumnVisible?.call(event);
      _controller.emitColumnVisible(event);
      _notifyStateChanged('columnVisibility');
    };

    _controller.onSetColumnsPinnedRequested = (colIds, pinned) {
      // Filter out columns with lockPinned set
      final effectiveColIds = colIds.where((colId) {
        final col = _controller.getColumnDef(colId);
        return col?.lockPinned != true;
      }).toList();
      if (effectiveColIds.isEmpty) return;

      _mutate(() {
        for (final colId in effectiveColIds) {
          pins[colId] = pinned;
        }
        syncToController();
      });
      final event = OsColumnPinnedEvent(
        columns: effectiveColIds,
        pinned: pinned,
      );
      _onColumnPinned?.call(event);
      _controller.emitColumnPinned(event);
      _notifyStateChanged('columnPinning');
    };

    _controller.onApplyColumnStateRequested = (params) {
      return applyState(params);
    };

    _controller.onResetColumnStateRequested = () {
      reset();
    };

    _controller.onGetDisplayedColAfterRequested = displayedColAfter;
    _controller.onGetDisplayedColBeforeRequested = displayedColBefore;

    _controller.onSetColumnWidthsRequested = (widths, finished) {
      _mutate(() {
        for (final entry in widths) {
          // Respect min/max constraints
          final col = _controller.getColumnDef(entry.colId);
          final minW = col?.minWidth ?? 50.0;
          final maxW = col?.maxWidth ?? double.infinity;
          this.widths[entry.colId] = entry.newWidth.clamp(minW, maxW);
        }
        syncToController();
      });
      final event = OsColumnResizedEvent(
        columns: widths
            .map(
              (w) => ColumnResizeEntry(
                colId: w.colId,
                width: this.widths[w.colId] ?? w.newWidth,
              ),
            )
            .toList(),
        finished: finished,
      );
      _onColumnResized?.call(event);
      _controller.emitColumnResized(event);
      _notifyStateChanged('columnSizing');
    };

    _controller.onMoveColumnByIndexRequested = (fromIndex, toIndex) {
      moveByIndex(fromIndex, toIndex);
    };

    _controller.onMoveColumnsRequested = (colIds, toIndex) {
      moveColumns(colIds, toIndex);
    };

    _controller.onAutoSizeColumnsRequested = (colIds, skipHeader) {
      autosizeByColIds(colIds, skipHeader: skipHeader);
    };
  }

  /// Applies column state from the controller API.
  ///
  /// When [ApplyColumnStateParams.purge] is true, all existing overrides
  /// (widths, pins, visibility, order) and the sort model are removed
  /// before [ApplyColumnStateParams.state] is applied — the equivalent of
  /// [reset] followed by applying only the given subset.
  bool applyState(ApplyColumnStateParams params) {
    final flatCols = _allFlatColumns();
    final allColIds = flatCols.map((c) => c.effectiveColId).toSet();

    bool allMatched = true;

    _mutate(() {
      // Purge: discard every stored override and the sort model before
      // applying the given state. Hidden columns are re-initialised from
      // their definitions so `hide: true` colDefs stay hidden, matching
      // resetColumnState semantics.
      if (params.purge) {
        widths.clear();
        pins.clear();
        hiddenIds.clear();
        order = null;
        _clearSort();
        _invalidateDeltaSort();
        _resetLegacySortIndex();
        _initHiddenFromDefs();
      }

      // Collect sort state from the column state entries
      final sortEntries =
          <({String colId, OsSortDirection direction, int? sortIndex})>[];

      if (params.state != null) {
        for (final state in params.state!) {
          if (!allColIds.contains(state.colId)) {
            allMatched = false;
            continue;
          }

          // Apply hide
          if (state.hide == true) {
            hiddenIds.add(state.colId);
          } else if (state.hide == false) {
            hiddenIds.remove(state.colId);
          }

          // Apply width
          if (state.width != null) {
            widths[state.colId] = state.width!;
          }

          // Apply pinned
          if (state.pinned != null) {
            pins[state.colId] = state.pinned;
          } else {
            // Explicitly null means unpin (remove override)
            pins.remove(state.colId);
          }

          // Collect sort state
          if (state.sort != null) {
            sortEntries.add((
              colId: state.colId,
              direction: state.sort!,
              sortIndex: state.sortIndex,
            ));
          }
        }

        // Apply order if requested
        if (params.applyOrder) {
          final stateColIds = params.state!.map((s) => s.colId).toList();
          final remainingIds = flatCols
              .map((c) => c.effectiveColId)
              .where((id) => !stateColIds.contains(id))
              .toList();
          order = [...stateColIds.where(allColIds.contains), ...remainingIds];
        }
      }

      // Apply default state to columns not in the state list
      if (params.defaultState != null && params.state != null) {
        final stateColIds = params.state!.map((s) => s.colId).toSet();
        for (final colId in allColIds) {
          if (stateColIds.contains(colId)) continue;
          final def = params.defaultState!;
          if (def.hide == true) {
            hiddenIds.add(colId);
          } else if (def.hide == false) {
            hiddenIds.remove(colId);
          }
          if (def.width != null) {
            widths[colId] = def.width!;
          }
          if (def.pinned != null) {
            pins[colId] = def.pinned;
          }
        }
      }

      // Apply sort state: build a new sort model from the collected entries
      if (sortEntries.isNotEmpty) {
        // Sort by sortIndex (entries without sortIndex go at the end)
        sortEntries.sort((a, b) {
          final aIdx = a.sortIndex ?? 999999;
          final bIdx = b.sortIndex ?? 999999;
          return aIdx.compareTo(bIdx);
        });
        final newSortModel = sortEntries
            .map((e) => OsSortModel(colId: e.colId, sort: e.direction))
            .toList();
        _setSortModel(newSortModel);
        _invalidateDeltaSort();
        _resetLegacySortIndex();
      } else if (params.state != null) {
        // If state was provided but no sort entries, clear sort
        _clearSort();
        _invalidateDeltaSort();
        _resetLegacySortIndex();
      }

      syncToController();
      _reprocess();
    });

    if (params.state != null || params.purge) {
      _emitSortChanged();
    }

    return allMatched;
  }

  /// Returns the displayed column immediately after [colId] in the
  /// flattened display order, or `null` when [colId] is not displayed or
  /// is already the last displayed column.
  ///
  /// The flattened order is the left-pinned section, then the centre
  /// (unpinned) section, then the right-pinned section — each in current
  /// display order with hidden columns excluded. This matches AG Grid's
  /// `getDisplayedColAfter`, whose neighbours cross pin-section boundaries.
  OsColumnDef? displayedColAfter(String colId) => _displayedNeighbour(colId, 1);

  /// Returns the displayed column immediately before [colId] in the
  /// flattened display order, or `null` when [colId] is not displayed or
  /// is already the first displayed column.
  ///
  /// See [displayedColAfter] for the ordering semantics.
  OsColumnDef? displayedColBefore(String colId) =>
      _displayedNeighbour(colId, -1);

  /// Resolves the displayed neighbour of [colId] at offset [delta].
  OsColumnDef? _displayedNeighbour(String colId, int delta) {
    final cols = displayedColumnsPinnedOrder();
    final index = cols.indexWhere((c) => c.effectiveColId == colId);
    if (index < 0) return null;
    final target = index + delta;
    if (target < 0 || target >= cols.length) return null;
    return cols[target];
  }

  /// All displayed columns flattened left → centre → right.
  ///
  /// Starts from the same basis as the controller's getAllDisplayedColumns
  /// (current order overrides minus hidden columns), then partitions by
  /// resolved pin state so neighbours cross section boundaries exactly as
  /// the grid renders them.
  List<OsColumnDef> displayedColumnsPinnedOrder() {
    final flatCols = _allFlatColumns();
    final displayOrder =
        order ?? flatCols.map((c) => c.effectiveColId).toList();

    final visible = <OsColumnDef>[];
    for (final id in displayOrder) {
      if (hiddenIds.contains(id)) continue;
      for (final col in flatCols) {
        if (col.effectiveColId == id) {
          visible.add(col);
          break;
        }
      }
    }

    final left = <OsColumnDef>[];
    final center = <OsColumnDef>[];
    final right = <OsColumnDef>[];
    for (final col in visible) {
      final pin = pins[col.effectiveColId] ?? col.pinned;
      switch (pin) {
        case OsColumnPin.left:
          left.add(col);
        case OsColumnPin.right:
          right.add(col);
        case null:
          center.add(col);
      }
    }
    return [...left, ...center, ...right];
  }

  /// Moves a column from one display index to another.
  void moveByIndex(int fromIndex, int toIndex) {
    final flatCols = _allFlatColumns();

    // Get the current order
    final currentOrder =
        order ?? flatCols.map((c) => c.effectiveColId).toList();
    if (fromIndex < 0 || fromIndex >= currentOrder.length) return;
    if (toIndex < 0 || toIndex >= currentOrder.length) return;

    // Enforce lockPosition — cannot move a locked column, and cannot move
    // another column past a locked column.
    final colIdToMove = currentOrder[fromIndex];
    final movingCol = flatCols.firstWhere(
      (c) => c.effectiveColId == colIdToMove,
      orElse: () => flatCols[fromIndex],
    );
    if (movingCol.lockPosition == true) return;

    // Check if any locked column sits between from and to (would be displaced)
    final start = fromIndex < toIndex ? fromIndex + 1 : toIndex;
    final end = fromIndex < toIndex ? toIndex : fromIndex - 1;
    for (int i = start; i <= end; i++) {
      if (i < 0 || i >= currentOrder.length) continue;
      final id = currentOrder[i];
      final col = flatCols.firstWhere(
        (c) => c.effectiveColId == id,
        orElse: () => flatCols[i],
      );
      if (col.lockPosition == true) return;
    }

    _mutate(() {
      final colId = currentOrder.removeAt(fromIndex);
      currentOrder.insert(toIndex, colId);
      order = List.of(currentOrder);
      syncToController();
    });

    final movedColId = (order ?? currentOrder)[toIndex];
    final event = OsColumnMovedEvent(columns: [movedColId], toIndex: toIndex);
    _onColumnMoved?.call(event);
    _controller.emitColumnMoved(event);
    _notifyStateChanged('columnOrder');
  }

  /// Moves columns (by ID) to a target display index.
  void moveColumns(List<String> colIds, int toIndex) {
    final flatCols = _allFlatColumns();

    // Get the current order
    final currentOrder =
        order ?? flatCols.map((c) => c.effectiveColId).toList();

    // Enforce lockPosition — cannot move locked columns
    for (final colId in colIds) {
      final col = flatCols.firstWhere(
        (c) => c.effectiveColId == colId,
        orElse: () => flatCols.first,
      );
      if (col.lockPosition == true) return;
    }

    // Check if any locked column would be displaced by this move
    final insertAt = toIndex.clamp(0, currentOrder.length);
    final remainingAfterRemove = currentOrder
        .where((id) => !colIds.contains(id))
        .toList();
    for (int i = 0; i < remainingAfterRemove.length; i++) {
      final id = remainingAfterRemove[i];
      final col = flatCols.firstWhere(
        (c) => c.effectiveColId == id,
        orElse: () => flatCols.first,
      );
      if (col.lockPosition == true) {
        // If the locked column's position would change, abort
        final originalIdx = currentOrder.indexOf(id);
        final newIdx = i < insertAt ? i : i + colIds.length;
        if (newIdx != originalIdx) return;
      }
    }

    _mutate(() {
      // Remove the columns to move
      currentOrder.removeWhere((id) => colIds.contains(id));
      // Insert at the target index (clamped)
      final clampedInsert = toIndex.clamp(0, currentOrder.length);
      currentOrder.insertAll(clampedInsert, colIds);
      order = List.of(currentOrder);
      syncToController();
    });

    final event = OsColumnMovedEvent(columns: colIds, toIndex: toIndex);
    _onColumnMoved?.call(event);
    _controller.emitColumnMoved(event);
    _notifyStateChanged('columnOrder');
  }

  /// Moves [colId] to [targetPin] at [targetIndexInSection] within that
  /// pinned section's visible order (quality program v3 item 12 — column drag
  /// between pin sections).
  ///
  /// The global [order] is rebuilt as `left + center + right + hidden` so that
  /// the partitioned display order matches the requested insertion. Both column
  /// pin and column moved events are emitted with `source: 'uiColumnDragged'`.
  void moveColumnToPinnedSection(
    String colId,
    OsColumnPin? targetPin,
    int targetIndexInSection,
  ) {
    final flatCols = _allFlatColumns();
    OsColumnDef? colDef;
    for (final col in flatCols) {
      if (col.effectiveColId == colId) {
        colDef = col;
        break;
      }
    }
    if (colDef == null) return;
    if (colDef.suppressMovable == true) return;
    if (colDef.lockPosition == true) return;
    final currentPin = pins[colId] ?? colDef.pinned;
    if (currentPin != targetPin && colDef.lockPinned == true) return;

    // Build partitioned visible lists excluding the dragged column.
    final partitioned = displayedColumnsPinnedOrder();
    final left = <String>[];
    final center = <String>[];
    final right = <String>[];
    for (final col in partitioned) {
      if (col.effectiveColId == colId) continue;
      final pin = pins[col.effectiveColId] ?? col.pinned;
      switch (pin) {
        case OsColumnPin.left:
          left.add(col.effectiveColId);
          break;
        case OsColumnPin.right:
          right.add(col.effectiveColId);
          break;
        case null:
          center.add(col.effectiveColId);
          break;
      }
    }
    final targetList = switch (targetPin) {
      OsColumnPin.left => left,
      OsColumnPin.right => right,
      null => center,
    };
    final int clamped = targetIndexInSection
        .clamp(0, targetList.length)
        .toInt();
    // No-op when re-inserting at the same spot in same section.
    // We check by simulating insertion and comparing to original partitioned.
    final originalPartitionedIds = partitioned
        .map((col) => col.effectiveColId)
        .toList();
    // Quick no-op check: if pin unchanged, simulate the insertion and
    // compare against the original partitioned order.
    if (currentPin == targetPin) {
      // Build hypothetical target partitioned order and compare to original.
      final hypoLeft = List<String>.of(left);
      final hypoCenter = List<String>.of(center);
      final hypoRight = List<String>.of(right);
      final hypoTarget = switch (targetPin) {
        OsColumnPin.left => hypoLeft,
        OsColumnPin.right => hypoRight,
        null => hypoCenter,
      };
      hypoTarget.insert(clamped, colId);
      final hypoPartitioned = [...hypoLeft, ...hypoCenter, ...hypoRight];
      var same = hypoPartitioned.length == originalPartitionedIds.length;
      if (same) {
        for (var i = 0; i < hypoPartitioned.length; i++) {
          if (hypoPartitioned[i] != originalPartitionedIds[i]) {
            same = false;
            break;
          }
        }
      }
      if (same) return;
    }

    targetList.insert(clamped, colId);

    final hiddenList = <String>[];
    final currentOrder =
        order ?? flatCols.map((col) => col.effectiveColId).toList();
    for (final id in currentOrder) {
      if (hiddenIds.contains(id) && id != colId) hiddenList.add(id);
    }

    final newOrder = [...left, ...center, ...right, ...hiddenList];
    // Ensure every colId appears (covers hidden not in currentOrder ordering edge).
    final allIds = flatCols.map((col) => col.effectiveColId).toSet();
    for (final id in allIds) {
      if (!newOrder.contains(id)) newOrder.add(id);
    }

    final pinChanged = currentPin != targetPin;
    _mutate(() {
      pins[colId] = targetPin;
      order = newOrder;
      syncToController();
    });

    if (pinChanged) {
      final pinEvent = OsColumnPinnedEvent(
        columns: [colId],
        pinned: targetPin,
        source: 'uiColumnDragged',
      );
      _onColumnPinned?.call(pinEvent);
      _controller.emitColumnPinned(pinEvent);
      _notifyStateChanged('columnPinning');
    }
    final moveEvent = OsColumnMovedEvent(
      columns: [colId],
      toIndex: clamped,
      source: 'uiColumnDragged',
    );
    _onColumnMoved?.call(moveEvent);
    _controller.emitColumnMoved(moveEvent);
    _notifyStateChanged('columnOrder');
  }

  /// Applies a pin override from the column menu.
  void pinFromMenu(int columnIndex, OsColumnPin? pin) {
    final colId = _colIdForDisplayIndex(columnIndex);
    if (colId == null) return;

    _mutate(() {
      pins[colId] = pin;
      syncToController();
    });

    // Emit column pinned event
    final event = OsColumnPinnedEvent(
      columns: [colId],
      pinned: pin,
      source: 'uiColumnMenu',
    );
    _onColumnPinned?.call(event);
    _controller.emitColumnPinned(event);
  }

  /// Auto-sizes a single column to fit its content.
  ///
  /// Measures the widest cell value (including header) and sets the column
  /// width accordingly. Measurements are cached per column (item 42) so
  /// repeated calls over unchanged data skip `TextPainter` layout work.
  void autosize(int columnIndex) {
    final flatCols = _allFlatColumns();
    final colId = _colIdForDisplayIndex(columnIndex);
    if (colId == null) return;

    final col = flatCols.firstWhere((c) => c.effectiveColId == colId);
    if (col.field == null) return;

    _autosizeColumns([col]);
  }

  /// Auto-sizes all displayed columns to fit their content.
  ///
  /// Batched into a single pass over the rows measuring every column at
  /// once, instead of one full row scan per column (quality program v3
  /// item 42). Hidden columns are skipped — matching the previous
  /// index-walking behaviour, which could only ever resolve visible ids.
  void autosizeAll() {
    final cols = displayedColumnsPinnedOrder()
        .where((c) => c.field != null)
        .toList();
    if (cols.isEmpty) return;

    _autosizeColumns(cols);
  }

  /// Auto-sizes the columns named by [colIds], or every displayed column
  /// when [colIds] is null.
  ///
  /// Backs `controller.autoSizeColumns`. Unknown colIds are ignored, hidden
  /// columns are skipped (they have no measurable content on screen) and
  /// columns without a `field` are skipped because their values cannot be
  /// resolved. When [skipHeader] is true the header text does not
  /// contribute to the measured maximum, so a column can be sized purely to
  /// its cell content.
  void autosizeByColIds(Set<String>? colIds, {bool skipHeader = false}) {
    final cols = displayedColumnsPinnedOrder()
        .where((c) => c.field != null)
        .where((c) => colIds == null || colIds.contains(c.effectiveColId))
        .toList();
    if (cols.isEmpty) return;

    _autosizeColumns(cols, skipHeader: skipHeader);
  }

  /// Distributes [availableWidth] across the displayed unpinned columns so
  /// they exactly fill the centre viewport.
  ///
  /// Backs `controller.sizeColumnsToFit`. Widths are scaled proportionally
  /// to their current values and then clamped to each column's
  /// `minWidth`/`maxWidth`; any slack or overflow left by clamped columns
  /// is redistributed over the columns that are still free to move, so the
  /// total lands on [availableWidth] whenever the constraints allow. Pinned
  /// (left/right) and hidden columns are left untouched — they do not share
  /// the centre viewport.
  void sizeColumnsToFit(double availableWidth) {
    if (availableWidth <= 0 || !availableWidth.isFinite) return;

    // The centre section only holds unpinned columns.
    final cols = displayedColumnsPinnedOrder()
        .where((c) => (pins[c.effectiveColId] ?? c.pinned) == null)
        .toList();
    if (cols.isEmpty) return;

    final minWidths = <double>[];
    final maxWidths = <double>[];
    final current = <double>[];
    for (final col in cols) {
      final colId = col.effectiveColId;
      minWidths.add(col.minWidth ?? 50.0);
      maxWidths.add(col.maxWidth ?? double.infinity);
      current.add(widths[colId] ?? col.width ?? 150.0);
    }

    final total = current.fold<double>(0, (a, b) => a + b);
    if (total <= 0) return;

    // Proportional scale, clamped to the per-column constraints.
    final next = List<double>.generate(cols.length, (i) {
      final scaled = current[i] * (availableWidth / total);
      return scaled.clamp(minWidths[i], maxWidths[i]);
    });

    // Redistribute the residual (left over by clamped columns) over the
    // columns that can still move in the direction the grid needs. Each
    // pass either closes the gap or pins a column against a bound, and
    // there are finitely many columns to pin.
    for (var pass = 0; pass <= cols.length; pass++) {
      final residual = availableWidth - next.fold<double>(0, (a, b) => a + b);
      if (residual.abs() < 0.01) break;
      // A column can only grow below its max, and only shrink above its
      // min — a column sitting on the bound the residual pushes towards is
      // not flexible and must not absorb (or pretend to absorb) the slack.
      final flexible = <int>[
        for (var i = 0; i < cols.length; i++)
          if (residual > 0
              ? next[i] < maxWidths[i] - 0.01
              : next[i] > minWidths[i] + 0.01)
            i,
      ];
      if (flexible.isEmpty) break;
      final share = residual / flexible.length;
      for (final i in flexible) {
        next[i] = (next[i] + share).clamp(minWidths[i], maxWidths[i]);
      }
    }

    _mutate(() {
      for (var i = 0; i < cols.length; i++) {
        widths[cols[i].effectiveColId] = next[i];
        _clearTextCacheFor(cols[i].effectiveColId);
      }
      syncToController();
    });

    final event = OsColumnResizedEvent(
      columns: [
        for (var i = 0; i < cols.length; i++)
          ColumnResizeEntry(colId: cols[i].effectiveColId, width: next[i]),
      ],
      finished: true,
      source: 'apiSizeColumnsToFit',
    );
    _onColumnResized?.call(event);
    _controller.emitColumnResized(event);
    _notifyStateChanged('columnSizing');
  }

  /// Drops width/pin/visibility/order overrides and cached measurements
  /// for columns that are no longer defined.
  ///
  /// Called after a runtime column-definition swap so state for removed
  /// columns can never leak onto a later column that reuses the colId, and
  /// so a stale `order` never references a column that no longer exists.
  /// State belonging to columns that survive the swap is preserved.
  void pruneTo(Iterable<OsColumnDef> columns) {
    final keep = columns.map((c) => c.effectiveColId).toSet();
    _mutate(() {
      widths.removeWhere((id, _) => !keep.contains(id));
      pins.removeWhere((id, _) => !keep.contains(id));
      hiddenIds.removeWhere((id) => !keep.contains(id));
      order?.removeWhere((id) => !keep.contains(id));
      _autosizeMeasurements.removeWhere((id, _) => !keep.contains(id));
      syncToController();
    });
  }

  /// Shared autosize implementation: consults the measurement cache, then
  /// measures every pending column's header and sweeps the rows once,
  /// tracking all pending columns' maxima in that single pass, and applies
  /// all resulting widths in one mutation.
  ///
  /// When [skipHeader] is true the header is not measured, so a column with
  /// no data at all keeps its narrowest legal width.
  void _autosizeColumns(List<OsColumnDef> cols, {bool skipHeader = false}) {
    final scaler = _textScaler();
    final headerStyle = _headerTextStyle();
    final cellStyle = _cellTextStyle();
    final rows = _resolveRows();

    // Cache consultation — columns with a valid measurement skip layout.
    final maxima = List<double?>.filled(cols.length, null);
    final pending = <int>[];
    for (var i = 0; i < cols.length; i++) {
      final col = cols[i];
      final cached = _autosizeMeasurements[col.effectiveColId];
      if (cached != null &&
          cached.matches(
            rows,
            headerStyle,
            cellStyle,
            scaler,
            includesHeader: !skipHeader,
          )) {
        maxima[i] = cached.maxContentWidth;
      } else {
        // Floor for the row sweep (and for a skipHeader call with no data).
        maxima[i] = 0;
        pending.add(i);
      }
    }

    // Header measurement for every pending column (honours the active
    // TextScaler — item 8).
    if (!skipHeader) {
      for (final i in pending) {
        _autosizeLayoutCount++;
        final tp = TextPainter(
          text: TextSpan(text: cols[i].effectiveHeaderName, style: headerStyle),
          maxLines: 1,
          textDirection: TextDirection.ltr,
          textScaler: scaler,
        )..layout();
        maxima[i] = tp.width;
      }
    }

    // One shared sweep over the rows measuring every pending column's
    // cell value in the same pass.
    if (rows != null && pending.isNotEmpty) {
      for (var r = 0; r < rows.length; r++) {
        final row = rows[r];
        for (final i in pending) {
          final value = _resolveCellValue(cols[i], row, r);
          if (value == null) continue;
          _autosizeLayoutCount++;
          final tp = TextPainter(
            text: TextSpan(text: value.toString(), style: cellStyle),
            maxLines: 1,
            textDirection: TextDirection.ltr,
            textScaler: scaler,
          )..layout();
          if (tp.width > maxima[i]!) maxima[i] = tp.width;
        }
      }
    }

    // Store measurements so repeated autosize calls on unchanged data are
    // cache hits.
    for (final i in pending) {
      _autosizeMeasurements[cols[i].effectiveColId] = _AutosizeMeasurement(
        rowsIdentity: rows,
        rowCount: rows?.length ?? 0,
        maxContentWidth: maxima[i]!,
        headerStyle: headerStyle,
        cellStyle: cellStyle,
        scaler: scaler,
        includesHeader: !skipHeader,
      );
    }

    _mutate(() {
      for (var i = 0; i < cols.length; i++) {
        final col = cols[i];
        // Add padding (cell padding + sort indicator + menu icon space)
        widths[col.effectiveColId] = (maxima[i]! + 24 + 20 + 20).clamp(
          col.minWidth ?? 50.0,
          col.maxWidth ?? 800.0,
        );
      }
      syncToController();
    });
  }

  /// Releases autosize cache invalidation subscriptions.
  ///
  /// Called by the owning State on dispose. The subscriptions target the
  /// controller's broadcast streams, which close with the controller, but
  /// cancelling explicitly keeps the coordinator's lifetime self-contained.
  void dispose() {
    for (final subscription in _dataChangeSubscriptions) {
      subscription.cancel();
    }
    _dataChangeSubscriptions.clear();
    _autosizeMeasurements.clear();
  }

  /// Resets all columns to their default widths and clears overrides.
  void reset() {
    _mutate(() {
      widths.clear();
      pins.clear();
      hiddenIds.clear();
      order = null;
      _clearSort();
      _resetLegacySortIndex();

      // Re-initialise hidden columns from definitions
      _initHiddenFromDefs();
      syncToController();
      _reprocess();
    });

    // Emit sort cleared event
    _emitSortChanged();
  }
}
