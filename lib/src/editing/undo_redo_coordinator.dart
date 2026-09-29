import 'dart:async';

import 'package:flutter/foundation.dart';

import '../columns/os_column_def.dart';
import '../events/cell_events.dart';
import '../events/undo_redo_events.dart';
import '../os_grid_controller.dart';
import 'undo_redo_service.dart';

/// Owns the undo/redo stack lifecycle for cell edits.
///
/// Extracted from `_OsGridState`. The coordinator wires the controller's
/// imperative undo/redo API, clears stacks on structural changes (row data
/// updates, column moves/visibility/pin changes, row drags), and performs
/// undo/redo by re-applying recorded cell values.
class UndoRedoCoordinator<TData> {
  /// Creates a coordinator.
  ///
  /// [isEnabled] reports whether undo/redo editing is configured on.
  /// [limit] reports the configured stack limit. [resolveRows] supplies the
  /// effective data rows used when re-applying values. [mutate] wraps the
  /// owning State's `setState`. The `onXxx` getters supply the current
  /// widget callbacks so `didUpdateWidget` replacements are honoured.
  UndoRedoCoordinator({
    required OsGridController<TData> controller,
    required bool Function() isEnabled,
    required int Function() limit,
    required List<TData>? Function() resolveRows,
    required void Function(VoidCallback) mutate,
    required void Function(OsUndoStartedEvent)? onUndoStarted,
    required void Function(OsUndoEndedEvent)? onUndoEnded,
    required void Function(OsRedoStartedEvent)? onRedoStarted,
    required void Function(OsRedoEndedEvent)? onRedoEnded,
    required void Function(OsCellValueChangedEvent<TData>)? onCellValueChanged,
  }) : _controller = controller,
       _isEnabled = isEnabled,
       _limit = limit,
       _resolveRows = resolveRows,
       _mutate = mutate,
       _onUndoStarted = onUndoStarted,
       _onUndoEnded = onUndoEnded,
       _onRedoStarted = onRedoStarted,
       _onRedoEnded = onRedoEnded,
       _onCellValueChanged = onCellValueChanged;

  /// The live controller. Mutable only for runtime controller swaps —
  /// see [rebind].
  OsGridController<TData> _controller;

  /// Re-points the coordinator at [controller] after a runtime controller
  /// swap: detaches the request hooks and stream subscriptions wired on the
  /// outgoing controller, then re-runs [init] against the new one. The
  /// undo/redo stack itself survives the swap (it tracks cell edits, not
  /// controller identity).
  void rebind(OsGridController<TData> controller) {
    _controller
      ..onUndoCellEditingRequested = null
      ..onRedoCellEditingRequested = null
      ..onGetCurrentUndoSizeRequested = null
      ..onGetCurrentRedoSizeRequested = null;
    dispose();
    _controller = controller;
    init();
  }

  final bool Function() _isEnabled;
  final int Function() _limit;
  final List<TData>? Function() _resolveRows;
  final void Function(VoidCallback) _mutate;
  final void Function(OsUndoStartedEvent)? _onUndoStarted;
  final void Function(OsUndoEndedEvent)? _onUndoEnded;
  final void Function(OsRedoStartedEvent)? _onRedoStarted;
  final void Function(OsRedoEndedEvent)? _onRedoEnded;
  final void Function(OsCellValueChangedEvent<TData>)? _onCellValueChanged;

  UndoRedoService? _service;
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  /// The active service, or null when undo/redo is not configured.
  UndoRedoService? get service => _service;

  /// Wires controller API callbacks and stack-clearing stream listeners.
  ///
  /// Mirrors the original `_initUndoRedoService` behaviour: when disabled,
  /// controller request hooks are nulled out.
  void init() {
    if (!_isEnabled() || _limit() <= 0) {
      _service = null;
      _controller.onUndoCellEditingRequested = null;
      _controller.onRedoCellEditingRequested = null;
      _controller.onGetCurrentUndoSizeRequested = null;
      _controller.onGetCurrentRedoSizeRequested = null;
      return;
    }

    _service = UndoRedoService(limit: _limit());

    _controller.onUndoCellEditingRequested = () {
      performUndo(source: 'api');
    };

    _controller.onRedoCellEditingRequested = () {
      performRedo(source: 'api');
    };

    _controller.onGetCurrentUndoSizeRequested = () {
      return _service?.currentUndoSize ?? 0;
    };

    _controller.onGetCurrentRedoSizeRequested = () {
      return _service?.currentRedoSize ?? 0;
    };

    // Clear stacks on structural changes via controller streams
    void clearOn(Stream<dynamic> stream) {
      _subscriptions.add(stream.listen((_) => _service?.clearStacks()));
    }

    clearOn(_controller.onRowDataUpdated);
    clearOn(_controller.onColumnMoved);
    clearOn(_controller.onColumnVisible);
    clearOn(_controller.onColumnPinned);
    clearOn(_controller.onRowDragEnd);
  }

  /// Clears both stacks (used when edits must be invalidated).
  void clearStacks() => _service?.clearStacks();

  /// Performs an undo operation, applying old values to the data.
  void performUndo({required String source}) {
    final service = _service;
    if (service == null || !service.isEnabled) return;

    final startEvent = OsUndoStartedEvent(source: source);
    _onUndoStarted?.call(startEvent);
    _controller.emitUndoStarted(startEvent);

    final action = service.undo();
    final performed = action != null;

    if (performed) {
      _applyAction(action, useOldValue: true);
    }

    final endEvent = OsUndoEndedEvent(
      source: source,
      operationPerformed: performed,
    );
    _onUndoEnded?.call(endEvent);
    _controller.emitUndoEnded(endEvent);
  }

  /// Performs a redo operation, applying new values to the data.
  void performRedo({required String source}) {
    final service = _service;
    if (service == null || !service.isEnabled) return;

    final startEvent = OsRedoStartedEvent(source: source);
    _onRedoStarted?.call(startEvent);
    _controller.emitRedoStarted(startEvent);

    final action = service.redo();
    final performed = action != null;

    if (performed) {
      _applyAction(action, useOldValue: false);
    }

    final endEvent = OsRedoEndedEvent(
      source: source,
      operationPerformed: performed,
    );
    _onRedoEnded?.call(endEvent);
    _controller.emitRedoEnded(endEvent);
  }

  /// Applies an undo/redo action by setting cell values.
  ///
  /// When [useOldValue] is true (undo), restores old values.
  /// When [useOldValue] is false (redo), applies new values.
  ///
  /// Target rows are resolved by the recorded [CellValueChange.rowId] first
  /// (the same identity selection and transactions key by), so a re-sort or
  /// filter between the edit and the undo cannot retarget the write to
  /// whatever row now occupies the recorded index. Changes without a rowId
  /// fall back to the recorded index.
  void _applyAction(UndoRedoAction action, {required bool useOldValue}) {
    final effectiveData = _resolveRows();
    if (effectiveData == null) return;

    final needsIdLookup = action.cellValueChanges.any((c) => c.rowId != null);
    Map<String, int>? indexById;
    if (needsIdLookup) {
      indexById = <String, int>{
        for (var i = 0; i < effectiveData.length; i++)
          _controller.rowIdFor(effectiveData[i]): i,
      };
    }

    _mutate(() {
      for (final change in action.cellValueChanges) {
        int rowIndex;
        if (change.rowId != null) {
          final resolved = indexById![change.rowId];
          if (resolved == null) {
            // Row no longer exists (removed or replaced by ID) — skip.
            continue;
          }
          rowIndex = resolved;
        } else {
          if (change.rowIndex < 0 || change.rowIndex >= effectiveData.length) {
            // Row no longer exists at this index (filtered out or removed) — skip.
            continue;
          }
          rowIndex = change.rowIndex;
        }

        final row = effectiveData[rowIndex];
        final value = useOldValue ? change.oldValue : change.newValue;

        // Write value to the row data
        if (row is Map<String, dynamic>) {
          row[change.columnId] = value;
        }

        // Emit cellValueChanged event for each cell
        final event = OsCellValueChangedEvent<TData>(
          data: row,
          rowIndex: rowIndex,
          colDef: OsColumnDef<TData>(field: change.columnId),
          oldValue: useOldValue ? change.newValue : change.oldValue,
          newValue: value,
        );
        _onCellValueChanged?.call(event);
        _controller.emitCellValueChanged(event);
      }
    });
  }

  /// Cancels stream subscriptions. Call from the owning State's dispose.
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
  }
}
