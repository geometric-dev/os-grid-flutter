import 'dart:async';

import 'row_transaction.dart';

/// Callback type for async transaction completion notification.
typedef AsyncTransactionCallback<TData> =
    void Function(OsRowTransaction<TData> transaction);

/// Service that batches multiple `applyTransaction` calls within a time window
/// into a single processing pass.
///
/// Useful when receiving rapid-fire updates (e.g. from a WebSocket). Collects
/// transactions for [waitMillis] milliseconds then applies them all at once.
///
/// This mirrors OS Grid's `asyncTransactionWaitMillis` grid option and the
/// `batchUpdateRowData` / `flushAsyncTransactions` API.
class AsyncTransactionService<TData> {
  AsyncTransactionService({required this.waitMillis, required this.onFlush});

  /// The number of milliseconds to wait before flushing batched transactions.
  final int waitMillis;

  /// Callback invoked when the batch is flushed. Receives the merged
  /// transaction containing all adds/removes/updates from the batch window.
  final void Function(OsRowTransaction<TData> mergedTransaction) onFlush;

  /// Pending transactions waiting to be flushed.
  final List<_PendingTransaction<TData>> _pending = [];

  /// The timer that triggers the flush.
  Timer? _timer;

  /// Whether there are pending transactions waiting to be flushed.
  bool get hasPending => _pending.isNotEmpty;

  /// The number of pending transactions in the current batch.
  int get pendingCount => _pending.length;

  /// Add a transaction to the current batch.
  ///
  /// If this is the first transaction in a new batch, starts the timer.
  /// The [callback] (if provided) will be invoked after the batch is flushed.
  void addTransaction(
    OsRowTransaction<TData> transaction, {
    AsyncTransactionCallback<TData>? callback,
  }) {
    _pending.add(
      _PendingTransaction(transaction: transaction, callback: callback),
    );

    // Start the timer on the first transaction in the batch.
    _timer ??= Timer(Duration(milliseconds: waitMillis), _executeBatch);
  }

  /// Immediately flush all pending transactions without waiting for the timer.
  ///
  /// This is a no-op if there are no pending transactions.
  void flush() {
    if (_pending.isEmpty) return;
    _timer?.cancel();
    _timer = null;
    _executeBatch();
  }

  /// Cancels any pending batch without applying it.
  ///
  /// Useful when the grid is being disposed.
  void cancel() {
    _timer?.cancel();
    _timer = null;
    _pending.clear();
  }

  /// Disposes the service, cancelling any pending batch.
  void dispose() {
    cancel();
  }

  /// Merges all pending transactions and invokes the flush callback.
  void _executeBatch() {
    _timer = null;

    if (_pending.isEmpty) return;

    // Merge all pending transactions into one.
    final allAdds = <TData>[];
    final allRemoves = <TData>[];
    final allUpdates = <TData>[];
    int? firstAddIndex;

    for (final pending in _pending) {
      final tx = pending.transaction;
      if (tx.add != null) {
        allAdds.addAll(tx.add!);
        firstAddIndex ??= tx.addIndex;
      }
      if (tx.remove != null) {
        allRemoves.addAll(tx.remove!);
      }
      if (tx.update != null) {
        allUpdates.addAll(tx.update!);
      }
    }

    final merged = OsRowTransaction<TData>(
      add: allAdds.isEmpty ? null : allAdds,
      remove: allRemoves.isEmpty ? null : allRemoves,
      update: allUpdates.isEmpty ? null : allUpdates,
      addIndex: firstAddIndex,
    );

    // Capture callbacks before clearing.
    final callbacks = _pending
        .where((p) => p.callback != null)
        .map((p) => p.callback!)
        .toList();

    _pending.clear();

    // Apply the merged transaction.
    onFlush(merged);

    // Invoke callbacks asynchronously (matches OS Grid behaviour).
    if (callbacks.isNotEmpty) {
      Future.microtask(() {
        for (final cb in callbacks) {
          cb(merged);
        }
      });
    }
  }
}

/// Internal wrapper for a pending transaction with its optional callback.
class _PendingTransaction<TData> {
  const _PendingTransaction({required this.transaction, this.callback});

  final OsRowTransaction<TData> transaction;
  final AsyncTransactionCallback<TData>? callback;
}
