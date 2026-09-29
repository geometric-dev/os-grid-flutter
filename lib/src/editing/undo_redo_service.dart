/// Undo/redo service for cell editing operations.
///
/// Captures cell value changes during editing and provides undo/redo
/// functionality with bounded stacks. Mirrors OS Grid TypeScript's
/// `UndoRedoStack`/`UndoRedoService` and adds transactional composition
/// (quality program v3 item 35):
///
/// - [UndoRedoService.pushComposite] wraps multiple [CellValueChange]s into
///   ONE [UndoRedoAction] (paste, cut and range fill already collect their
///   changes and push them as a single action this way).
/// - [UndoRedoService.beginBatch]/[UndoRedoService.endBatch] accumulate
///   consecutive edit sessions into a single action pushed at `endBatch`.
/// - A [UndoRedoService.batchWindow] automatically merges edit sessions that
///   commit within the window of each other into one action (500 ms window
///   recommended) unless an undo/redo/structural change intervenes.
/// - Stacks are bounded by both action count and estimated memory
///   ([UndoRedoService.maxUndoMemory], default 1 MiB); the oldest actions are
///   evicted when the cap is exceeded.
library;

import 'dart:async';

/// Base byte estimate for one [CellValueChange]: object header, the int
/// row index, the column-id reference and the two dynamic value slots.
const int _kChangeBaseBytes = 48;

/// Byte estimate for a string object header (before its characters).
const int _kStringHeaderBytes = 16;

/// Byte estimate for an opaque (non-primitive) value reference.
const int _kOpaqueValueBytes = 32;

/// Returns an approximate memory footprint, in bytes, for [value] as stored
/// in a [CellValueChange]. Strings are sized by their UTF-16 length,
/// numbers/bools by their boxed size and any other object by a flat
/// reference estimate.
int estimateValueMemory(Object? value) {
  if (value == null) return 0;
  if (value is String) return _kStringHeaderBytes + 2 * value.length;
  if (value is num) return 8;
  if (value is bool) return 4;
  return _kOpaqueValueBytes;
}

/// Returns an approximate memory footprint, in bytes, of [change]:
/// fixed overhead plus the column-id, row-id and old/new value sizes.
int estimateChangeMemory(CellValueChange change) =>
    _kChangeBaseBytes +
    _kStringHeaderBytes +
    2 * change.columnId.length +
    (change.rowId == null
        ? 0
        : _kStringHeaderBytes + 2 * change.rowId!.length) +
    estimateValueMemory(change.oldValue) +
    estimateValueMemory(change.newValue);

/// Returns an approximate memory footprint, in bytes, of [action] — the sum
/// of the estimated sizes of its changes.
int estimateActionMemory(UndoRedoAction action) => action.cellValueChanges.fold(
  0,
  (sum, change) => sum + estimateChangeMemory(change),
);

/// Represents a single cell value change that can be undone/redone.
class CellValueChange {
  const CellValueChange({
    required this.rowIndex,
    this.rowId,
    required this.columnId,
    required this.oldValue,
    required this.newValue,
  });

  /// The row index at the time of the edit.
  final int rowIndex;

  /// The stable row identity (`getRowId`, or object-identity hash when the
  /// grid has no ID callback) captured at edit time. When set, undo/redo
  /// resolves the target row by this ID first, so a re-sort or filter
  /// between edit and undo cannot retarget the write to whatever row now
  /// occupies [rowIndex].
  final String? rowId;

  /// The column ID (field name) of the edited cell.
  final String columnId;

  /// The value before the edit.
  final dynamic oldValue;

  /// The value after the edit.
  final dynamic newValue;

  @override
  String toString() =>
      'CellValueChange(row: $rowIndex, id: $rowId, col: $columnId, '
      'old: $oldValue, new: $newValue)';
}

/// A group of cell value changes that form a single undoable action.
///
/// Most actions contain a single change (one cell edit), but composed
/// operations — paste, cut, range fill, multi-edit batches — group many
/// changes into one action so they are undone/redone together.
class UndoRedoAction {
  UndoRedoAction(this.cellValueChanges);

  /// The cell value changes in this action.
  final List<CellValueChange> cellValueChanges;

  @override
  String toString() => 'UndoRedoAction(${cellValueChanges.length} changes)';
}

/// A bounded stack of undo/redo actions.
///
/// Two independent ceilings are enforced on push, evicting the oldest
/// action first (FIFO):
///
/// - [maxSize] — maximum number of actions.
/// - [maxMemory] — maximum estimated memory ([estimateActionMemory]).
///   `null` means unbounded. The newest action is always retained even when
///   it alone exceeds the cap.
class UndoRedoStack {
  UndoRedoStack({this.maxSize = 10, int? maxMemory}) : _maxMemory = maxMemory;

  /// Maximum number of actions the stack can hold.
  final int maxSize;

  final int? _maxMemory;

  /// Maximum estimated memory (bytes) the stack may hold, or `null` when
  /// unbounded.
  int? get maxMemory => _maxMemory;

  final List<UndoRedoAction> _actions = [];
  final List<int> _sizes = [];
  int _totalBytes = 0;

  /// Approximate memory (bytes) currently held by this stack.
  int get estimatedMemory => _totalBytes;

  /// Push an action onto the stack.
  ///
  /// Only pushes if the action contains at least one cell value change.
  /// Oldest actions are evicted while the stack is over either ceiling.
  void push(UndoRedoAction action) {
    if (action.cellValueChanges.isEmpty) return;
    if (maxSize <= 0) return;

    if (_actions.length >= maxSize) {
      _removeAt(0);
    }
    _actions.add(action);
    final bytes = estimateActionMemory(action);
    _sizes.add(bytes);
    _totalBytes += bytes;
    _evictOverMemory();
  }

  /// Evicts the oldest actions until the stack fits the memory cap. The
  /// most recent action is always retained.
  void _evictOverMemory() {
    final cap = _maxMemory;
    if (cap == null) return;
    while (_totalBytes > cap && _actions.length > 1) {
      _removeAt(0);
    }
  }

  void _removeAt(int index) {
    _totalBytes -= _sizes.removeAt(index);
    _actions.removeAt(index);
  }

  /// Pop the most recent action from the stack.
  ///
  /// Returns `null` if the stack is empty.
  UndoRedoAction? pop() {
    if (_actions.isEmpty) return null;
    _totalBytes -= _sizes.removeLast();
    return _actions.removeLast();
  }

  /// Clear all actions from the stack.
  void clear() {
    _actions.clear();
    _sizes.clear();
    _totalBytes = 0;
  }

  /// The current number of actions on the stack.
  int get size => _actions.length;

  /// Whether the stack is empty.
  bool get isEmpty => _actions.isEmpty;

  /// Whether the stack is not empty.
  bool get isNotEmpty => _actions.isNotEmpty;
}

/// Manages undo/redo state for cell editing operations.
///
/// Usage:
/// 1. Call [onCellValueChanged] when a cell edit is committed.
/// 2. Call [undo] / [redo] to revert/reapply changes.
/// 3. Call [clearStacks] when structural changes occur.
///
/// The service does not directly modify data — it returns the
/// [CellValueChange] objects and the caller (the grid widget)
/// is responsible for applying the old/new values.
///
/// Composition (quality program v3 item 35):
/// - Batch operations pass a pre-collected change list to [pushComposite]
///   (or wrap it in an [UndoRedoAction] for [pushAction]) so the whole
///   operation is ONE undoable action.
/// - Call [beginBatch] before a run of edits and [endBatch] afterwards to
///   commit the run as a single action.
/// - Set [batchWindow] to auto-batch committed edit sessions that follow
///   each other within the window; the accumulated action is pushed when
///   the window elapses, when [endBatch] is called, or when [undo] /
///   [redo] / a direct push intervenes.
class UndoRedoService {
  /// Creates a service.
  ///
  /// [limit] bounds both stacks by action count (0 disables the service).
  /// [maxUndoMemory] bounds the stacks by estimated memory; values <= 0
  /// disable the memory cap. [batchWindow] enables time-windowed multi-edit
  /// batching (e.g. 500 ms); `null` keeps the one-action-per-edit-session
  /// behaviour.
  UndoRedoService({
    int limit = 10,
    int maxUndoMemory = defaultMaxUndoMemory,
    this.batchWindow,
  }) : _limit = limit,
       _maxUndoMemory = maxUndoMemory {
    final memoryCap = _maxUndoMemory > 0 ? _maxUndoMemory : null;
    _undoStack = UndoRedoStack(maxSize: limit, maxMemory: memoryCap);
    _redoStack = UndoRedoStack(maxSize: limit, maxMemory: memoryCap);
  }

  /// Default estimated-memory ceiling for the undo stacks: 1 MiB.
  static const int defaultMaxUndoMemory = 1024 * 1024;

  final int _limit;
  final int _maxUndoMemory;
  late final UndoRedoStack _undoStack;
  late final UndoRedoStack _redoStack;

  /// Accumulated cell value changes for the current edit session.
  /// These are grouped into a single action when editing stops.
  final List<CellValueChange> _pendingChanges = [];

  /// Whether the service is currently capturing changes
  /// (between cellEditingStarted and cellEditingStopped).
  bool _isCapturing = false;

  /// Changes accumulated across edit sessions for the open manual batch or
  /// the pending batch window, committed as one action when the batch ends.
  final List<CellValueChange> _accumulatedChanges = [];

  /// Whether a manual batch is open ([beginBatch] without [endBatch] yet).
  bool _manualBatchOpen = false;

  /// Timer that flushes [_accumulatedChanges] when [batchWindow] elapses.
  Timer? _windowTimer;

  /// Whether the feature is effectively enabled.
  bool get isEnabled => _limit > 0;

  /// The current number of actions on the undo stack.
  int get currentUndoSize => _undoStack.size;

  /// The current number of actions on the redo stack.
  int get currentRedoSize => _redoStack.size;

  /// The configured estimated-memory ceiling (bytes) for both stacks.
  /// Values <= 0 mean unbounded.
  int get maxUndoMemory => _maxUndoMemory;

  /// The configured time window for multi-edit auto-batching, or `null`
  /// when batching is manual/opt-in only.
  final Duration? batchWindow;

  /// Approximate memory (bytes) currently held by the undo and redo stacks.
  int get estimatedMemoryUsage =>
      _undoStack.estimatedMemory + _redoStack.estimatedMemory;

  /// Whether a manual batch is currently open.
  bool get isBatching => _manualBatchOpen;

  /// Number of changes accumulated but not yet committed to the undo stack
  /// (open manual batch or pending batch window).
  int get pendingChangeCount => _accumulatedChanges.length;

  /// Called when cell editing starts.
  ///
  /// Begins capturing cell value changes for the current edit session.
  /// An open batch or pending window is intentionally left alone so that
  /// consecutive sessions join the same undo unit.
  void onCellEditingStarted() {
    _isCapturing = true;
    _pendingChanges.clear();
  }

  /// Called when a cell value changes during editing.
  ///
  /// The change is accumulated and will be grouped into an action
  /// when [onCellEditingStopped] is called.
  void onCellValueChanged({
    required int rowIndex,
    String? rowId,
    required String columnId,
    required dynamic oldValue,
    required dynamic newValue,
  }) {
    if (!_isCapturing) return;

    _pendingChanges.add(
      CellValueChange(
        rowIndex: rowIndex,
        rowId: rowId,
        columnId: columnId,
        oldValue: oldValue,
        newValue: newValue,
      ),
    );
  }

  /// Called when cell editing stops.
  ///
  /// If the value actually changed, the accumulated session changes become
  /// part of the current undo unit:
  ///
  /// - manual batch open → joined into the batch, pushed by [endBatch];
  /// - [batchWindow] set → joined into the window and pushed when the
  ///   window elapses (or earlier via [undo]/[redo]/[endBatch]);
  /// - otherwise → pushed immediately as a single action (legacy
  ///   one-action-per-edit-session behaviour).
  ///
  /// [valueChanged] indicates whether the edit resulted in a
  /// different value. If `false`, no change is recorded.
  void onCellEditingStopped({required bool valueChanged}) {
    _isCapturing = false;

    if (valueChanged && _pendingChanges.isNotEmpty) {
      if (_manualBatchOpen) {
        _accumulatedChanges.addAll(_pendingChanges);
      } else if (batchWindow != null) {
        _accumulatedChanges.addAll(_pendingChanges);
        _restartWindowTimer();
      } else {
        final action = UndoRedoAction(List.of(_pendingChanges));
        _undoStack.push(action);
        _redoStack.clear();
      }
    }

    _pendingChanges.clear();
  }

  /// Opens a manual multi-edit batch.
  ///
  /// While the batch is open, every committed edit session accumulates and
  /// [endBatch] pushes them all as ONE action. Any pending batch window is
  /// flushed first so previously-committed edits keep their own action.
  /// Calling [beginBatch] while a batch is open is a no-op (idempotent).
  void beginBatch() {
    if (_manualBatchOpen) return;
    _cutPendingBatch();
    _manualBatchOpen = true;
  }

  /// Closes the manual batch and pushes all accumulated changes as ONE
  /// undo action (clearing the redo stack).
  ///
  /// Returns the pushed action, or `null` when no batch was open or no
  /// changes had accumulated. Undo/redo remain exact: a single undo
  /// reverts every change made during the batch.
  UndoRedoAction? endBatch() {
    if (!_manualBatchOpen) return null;
    _manualBatchOpen = false;
    _windowTimer?.cancel();
    _windowTimer = null;
    return _pushAccumulated();
  }

  /// Pushes [changes] wrapped as ONE composite [UndoRedoAction].
  ///
  /// This is the canonical API for batch operations (paste, cut, range
  /// fill): collect every [CellValueChange] first, then push once so the
  /// whole operation undoes/redoes as a unit. Clears the redo stack.
  /// Any pending batch/window is flushed first to preserve action order.
  ///
  /// Returns the pushed action, or `null` when [changes] is empty
  /// (nothing is pushed and the redo stack is left untouched).
  UndoRedoAction? pushComposite(List<CellValueChange> changes) {
    if (changes.isEmpty) return null;
    _cutPendingBatch();
    final action = UndoRedoAction(List.of(changes));
    _undoStack.push(action);
    _redoStack.clear();
    return action;
  }

  /// Closes any pending batch unit, committing accumulated changes as
  /// their own action so subsequent pushes keep chronological order.
  void _cutPendingBatch() {
    _windowTimer?.cancel();
    _windowTimer = null;
    _manualBatchOpen = false;
    _pushAccumulated();
  }

  UndoRedoAction? _pushAccumulated() {
    if (_accumulatedChanges.isEmpty) return null;
    final action = UndoRedoAction(List.of(_accumulatedChanges));
    _accumulatedChanges.clear();
    _undoStack.push(action);
    _redoStack.clear();
    return action;
  }

  void _restartWindowTimer() {
    _windowTimer?.cancel();
    _windowTimer = Timer(batchWindow!, _flushWindow);
  }

  void _flushWindow() {
    _windowTimer = null;
    if (_manualBatchOpen) return;
    _pushAccumulated();
  }

  /// Perform an undo operation.
  ///
  /// Returns the action that was undone, or `null` if the undo stack
  /// was empty. The caller is responsible for applying the old values
  /// from [UndoRedoAction.cellValueChanges].
  ///
  /// Any open batch or pending window is flushed first, so the most recent
  /// edits are always immediately undoable and an undo cuts the batch short.
  UndoRedoAction? undo() {
    _cutPendingBatch();
    final action = _undoStack.pop();
    if (action == null) return null;

    _redoStack.push(action);
    return action;
  }

  /// Perform a redo operation.
  ///
  /// Returns the action that was redone, or `null` if the redo stack
  /// was empty. The caller is responsible for applying the new values
  /// from [UndoRedoAction.cellValueChanges].
  ///
  /// Any open batch or pending window is flushed first; the flush follows
  /// the standard rule that new edits invalidate the redo stack.
  UndoRedoAction? redo() {
    _cutPendingBatch();
    final action = _redoStack.pop();
    if (action == null) return null;

    _undoStack.push(action);
    return action;
  }

  /// Clear both undo and redo stacks.
  ///
  /// Should be called when structural changes occur that would
  /// invalidate the stored cell references (e.g. row data replaced,
  /// columns moved/hidden, rows reordered via drag). Pending batch
  /// accumulation is discarded rather than committed.
  void clearStacks() {
    _windowTimer?.cancel();
    _windowTimer = null;
    _manualBatchOpen = false;
    _accumulatedChanges.clear();
    _undoStack.clear();
    _redoStack.clear();
    _pendingChanges.clear();
    _isCapturing = false;
  }

  /// Push an action directly onto the undo stack.
  ///
  /// Used by batch operations (paste, cut) that modify multiple cells
  /// in a single logical action. Clears the redo stack. Any pending
  /// batch/window is flushed first to preserve action order.
  void pushAction(UndoRedoAction action) {
    if (action.cellValueChanges.isEmpty) return;
    _cutPendingBatch();
    _undoStack.push(action);
    _redoStack.clear();
  }

  /// Cancels pending batch timers and clears all state.
  ///
  /// Call when the owning widget is disposed.
  void dispose() {
    clearStacks();
  }
}
