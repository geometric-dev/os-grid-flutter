import 'package:os_grid_flutter/os_grid_flutter.dart' show OsGridController;
import 'package:os_grid_flutter/src/os_grid_controller.dart'
    show OsGridController;

import '../row_model/row_transaction.dart';
import 'os_grid_event.dart';

/// Emitted when row data is updated via [OsGridController.setRowData]
/// or [OsGridController.applyTransaction].
///
/// ```dart
/// controller.onRowDataUpdated.listen((event) {
///   print('${event.rowCount} rows in the grid');
/// });
/// ```
class OsRowDataUpdatedEvent<TData> extends OsGridEvent {
  const OsRowDataUpdatedEvent({required this.rowData, required this.rowCount});

  /// The current row data after the update.
  final List<TData> rowData;

  /// The total number of rows after the update.
  final int rowCount;
}

/// Emitted when batched async transactions are flushed.
///
/// Contains the merged transaction that was applied and the number of
/// individual transactions that were batched together.
///
/// ```dart
/// controller.onAsyncTransactionsFlushed.listen((event) {
///   print('flushed ${event.transactionCount} transactions');
/// });
/// ```
class OsAsyncTransactionsFlushedEvent<TData> extends OsGridEvent {
  const OsAsyncTransactionsFlushedEvent({
    required this.transaction,
    required this.transactionCount,
  });

  /// The merged transaction that was applied.
  final OsRowTransaction<TData> transaction;

  /// The number of individual transactions that were batched.
  final int transactionCount;
}
