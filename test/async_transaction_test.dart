import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

void main() {
  group('AsyncTransactionService — unit tests', () {
    test('batches multiple transactions within wait window', () async {
      final flushed = <OsRowTransaction<Map<String, dynamic>>>[];

      final service = AsyncTransactionService<Map<String, dynamic>>(
        waitMillis: 50,
        onFlush: (tx) => flushed.add(tx),
      );

      // Add three transactions rapidly
      service.addTransaction(
        const OsRowTransaction(
          add: [
            {'id': 1, 'name': 'Alice'},
          ],
        ),
      );
      service.addTransaction(
        const OsRowTransaction(
          add: [
            {'id': 2, 'name': 'Bob'},
          ],
        ),
      );
      service.addTransaction(
        const OsRowTransaction(
          update: [
            {'id': 1, 'name': 'Alice Updated'},
          ],
        ),
      );

      expect(service.hasPending, true);
      expect(service.pendingCount, 3);
      expect(flushed, isEmpty);

      // Wait for the timer to fire
      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(flushed.length, 1);
      expect(flushed.first.add?.length, 2);
      expect(flushed.first.update?.length, 1);
      expect(service.hasPending, false);

      service.dispose();
    });

    test('flush() applies immediately without waiting', () {
      final flushed = <OsRowTransaction<Map<String, dynamic>>>[];

      final service = AsyncTransactionService<Map<String, dynamic>>(
        waitMillis: 5000, // Long wait — should not matter
        onFlush: (tx) => flushed.add(tx),
      );

      service.addTransaction(
        const OsRowTransaction(
          add: [
            {'id': 1, 'name': 'Alice'},
          ],
        ),
      );
      service.addTransaction(
        const OsRowTransaction(
          remove: [
            {'id': 2, 'name': 'Bob'},
          ],
        ),
      );

      expect(flushed, isEmpty);

      service.flush();

      expect(flushed.length, 1);
      expect(flushed.first.add?.length, 1);
      expect(flushed.first.remove?.length, 1);
      expect(service.hasPending, false);

      service.dispose();
    });

    test('flush() is no-op when no pending transactions', () {
      final flushed = <OsRowTransaction<Map<String, dynamic>>>[];

      final service = AsyncTransactionService<Map<String, dynamic>>(
        waitMillis: 50,
        onFlush: (tx) => flushed.add(tx),
      );

      service.flush(); // Should not throw or add to flushed
      expect(flushed, isEmpty);

      service.dispose();
    });

    test('cancel() discards pending transactions', () async {
      final flushed = <OsRowTransaction<Map<String, dynamic>>>[];

      final service = AsyncTransactionService<Map<String, dynamic>>(
        waitMillis: 50,
        onFlush: (tx) => flushed.add(tx),
      );

      service.addTransaction(
        const OsRowTransaction(
          add: [
            {'id': 1, 'name': 'Alice'},
          ],
        ),
      );

      service.cancel();

      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(flushed, isEmpty);
      expect(service.hasPending, false);

      service.dispose();
    });

    test('callbacks are invoked after flush', () async {
      final flushed = <OsRowTransaction<Map<String, dynamic>>>[];
      final callbacks = <OsRowTransaction<Map<String, dynamic>>>[];

      final service = AsyncTransactionService<Map<String, dynamic>>(
        waitMillis: 50,
        onFlush: (tx) => flushed.add(tx),
      );

      service.addTransaction(
        const OsRowTransaction(
          add: [
            {'id': 1, 'name': 'Alice'},
          ],
        ),
        callback: (tx) => callbacks.add(tx),
      );

      service.flush();

      // Callbacks are invoked asynchronously via microtask
      await Future<void>.delayed(Duration.zero);

      expect(callbacks.length, 1);

      service.dispose();
    });

    test('merges addIndex from first transaction only', () {
      final flushed = <OsRowTransaction<Map<String, dynamic>>>[];

      final service = AsyncTransactionService<Map<String, dynamic>>(
        waitMillis: 5000,
        onFlush: (tx) => flushed.add(tx),
      );

      service.addTransaction(
        const OsRowTransaction(
          add: [
            {'id': 1, 'name': 'Alice'},
          ],
          addIndex: 0,
        ),
      );
      service.addTransaction(
        const OsRowTransaction(
          add: [
            {'id': 2, 'name': 'Bob'},
          ],
          addIndex: 5, // This should be ignored — first addIndex wins
        ),
      );

      service.flush();

      expect(flushed.first.addIndex, 0);

      service.dispose();
    });
  });

  group('Async transactions — widget integration', () {
    testWidgets('applyTransactionAsync batches and applies after delay', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              getRowId: (data) => data['id'].toString(),
              asyncTransactionWaitMillis: 100,
              columnDefs: [
                const OsColumnDef(field: 'name', headerName: 'Name'),
              ],
              rowData: [
                {'id': 1, 'name': 'Alice'},
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Apply multiple async transactions
      controller.applyTransactionAsync(
        const OsRowTransaction(
          add: [
            {'id': 2, 'name': 'Bob'},
          ],
        ),
      );
      controller.applyTransactionAsync(
        const OsRowTransaction(
          add: [
            {'id': 3, 'name': 'Charlie'},
          ],
        ),
      );

      // Data should not have changed yet
      expect(controller.rowCount, 1);

      // Wait for the batch to flush
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();

      // Now all rows should be present
      expect(controller.rowCount, 3);
    });

    testWidgets('flushAsyncTransactions applies immediately', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              getRowId: (data) => data['id'].toString(),
              asyncTransactionWaitMillis: 5000, // Long delay
              columnDefs: [
                const OsColumnDef(field: 'name', headerName: 'Name'),
              ],
              rowData: [
                {'id': 1, 'name': 'Alice'},
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      controller.applyTransactionAsync(
        const OsRowTransaction(
          add: [
            {'id': 2, 'name': 'Bob'},
          ],
        ),
      );

      // Not applied yet
      expect(controller.rowCount, 1);

      // Flush immediately
      controller.flushAsyncTransactions();
      await tester.pumpAndSettle();

      // Now applied
      expect(controller.rowCount, 2);
    });

    testWidgets('onAsyncTransactionsFlushed callback fires', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();
      final events = <OsAsyncTransactionsFlushedEvent<Map<String, dynamic>>>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              getRowId: (data) => data['id'].toString(),
              asyncTransactionWaitMillis: 50,
              onAsyncTransactionsFlushed: (event) => events.add(event),
              columnDefs: [
                const OsColumnDef(field: 'name', headerName: 'Name'),
              ],
              rowData: [
                {'id': 1, 'name': 'Alice'},
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      controller.applyTransactionAsync(
        const OsRowTransaction(
          add: [
            {'id': 2, 'name': 'Bob'},
          ],
        ),
      );
      controller.applyTransactionAsync(
        const OsRowTransaction(
          add: [
            {'id': 3, 'name': 'Charlie'},
          ],
        ),
      );

      // Wait for flush
      await tester.pump(const Duration(milliseconds: 80));
      await tester.pumpAndSettle();

      expect(events.length, 1);
      expect(events.first.transaction.add?.length, 2);
    });

    testWidgets('fallback to sync when asyncTransactionWaitMillis not set', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              getRowId: (data) => data['id'].toString(),
              // No asyncTransactionWaitMillis
              columnDefs: [
                const OsColumnDef(field: 'name', headerName: 'Name'),
              ],
              rowData: [
                {'id': 1, 'name': 'Alice'},
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should apply synchronously
      controller.applyTransactionAsync(
        const OsRowTransaction(
          add: [
            {'id': 2, 'name': 'Bob'},
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(controller.rowCount, 2);
    });
  });
}
