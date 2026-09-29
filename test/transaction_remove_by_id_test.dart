import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

/// Regression tests for ID-based transaction removal.
///
/// Contract: `applyTransaction(remove: [...])` matches rows by resolved row
/// ID (subsumed by object identity), so rows reconstructed as equal-but-not-
/// identical instances — the standard immutable-data pattern — are removed
/// when getRowId is configured. Without the fix, only object identity (via
/// List.contains' ==) matched, and reconstructed rows silently survived.
void main() {
  test('remove matches reconstructed rows by getRowId', () {
    final controller = OsGridController<Map<String, dynamic>>();
    controller.getRowId = (row) => row['id'].toString();
    controller.setRowData([
      {'id': 1, 'name': 'a'},
      {'id': 2, 'name': 'b'},
      {'id': 3, 'name': 'c'},
    ]);

    // Reconstructed copies: equal content, different object identity.
    final removed = [
      {'id': 2, 'name': 'b'},
    ];

    controller.applyTransaction(OsRowTransaction(remove: removed));

    expect(controller.rowCount, equals(2));
    expect(controller.rawRowData.map((r) => r['id']), unorderedEquals([1, 3]));
  });

  test('remove by identity still works without getRowId', () {
    final controller = OsGridController<Map<String, dynamic>>();
    final b = {'id': 2, 'name': 'b'};
    controller.setRowData([
      {'id': 1, 'name': 'a'},
      b,
      {'id': 3, 'name': 'c'},
    ]);

    controller.applyTransaction(OsRowTransaction(remove: [b]));

    expect(controller.rowCount, equals(2));
    expect(controller.rawRowData, isNot(contains(b)));
  });

  test('removing a selected row deselects it', () {
    final controller = OsGridController<Map<String, dynamic>>();
    controller.getRowId = (row) => row['id'].toString();
    final rows = [
      {'id': 1, 'name': 'a'},
      {'id': 2, 'name': 'b'},
    ];
    controller.setRowData(rows);
    // Select via the node layer by row index.
    controller.selectRowsById(['2']);

    controller.applyTransaction(
      const OsRowTransaction(
        remove: [
          {'id': 2, 'name': 'b'}, // reconstructed
        ],
      ),
    );

    expect(controller.getSelectedRows(), isEmpty);
  });
}
