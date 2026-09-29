import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

/// Transaction replay test fixtures (quality program v3 item 45).
///
/// Three recorded production-shaped transaction sequences are stored as JSON
/// fixtures under `test/fixtures/transaction_replay/` and replayed through
/// `OsGridController.applyTransaction` (plus the selection API for
/// selection-change steps), asserting state consistency after EVERY step and
/// the recorded final state at the end:
/// - row count matches the recorded expectation,
/// - the node map holds exactly one node per raw row, with `node.data`
///   identical to the corresponding raw row instance,
/// - selection contains no dangling ids (removed rows are auto-deselected)
///   and every selected id resolves to a live row,
/// - node `selected` flags agree with the id-based selection set.
///
/// Fixture schema:
/// ```jsonc
/// {
///   "initialRows":      [{ "id": "r0", ... }],
///   "initialSelection": ["r3"],
///   "steps": [
///     { "op": "transaction", "add": [...], "addIndex": 0,
///       "update": [...], "removeIds": ["r2"] },
///     { "op": "select", "ids": ["r7"] },
///     { "op": "deselect", "ids": ["r7"] },
///     { "op": "deselectAll" }
///   ],
///   "expected": {
///     "rowCount": 43,
///     "rowIds":   ["r0", ...],       // exact final row-id order
///     "selectedIds": ["r17"],
///     "fieldChecks": { "r0": { "name": "...", "price": 999 } }
///   }
/// }
/// ```
void main() {
  OsGridController<Map<String, dynamic>> newController() {
    final controller = OsGridController<Map<String, dynamic>>();
    controller.getRowId = (data) => data['id'].toString();
    return controller;
  }

  /// Replays one fixture step through the controller API.
  void applyStep(
    OsGridController<Map<String, dynamic>> controller,
    Map<String, dynamic> step,
  ) {
    switch (step['op'] as String) {
      case 'transaction':
        final removeIds = (step['removeIds'] as List?)?.cast<String>();
        controller.applyTransaction(
          OsRowTransaction<Map<String, dynamic>>(
            add: (step['add'] as List?)?.cast<Map<String, dynamic>>(),
            addIndex: step['addIndex'] as int?,
            update: (step['update'] as List?)?.cast<Map<String, dynamic>>(),
            // Removes are matched by row identity for Map rows, so the ids
            // recorded in the fixture are resolved to the current row
            // instances the controller holds — the same thing a production
            // client does when it holds references to its row objects.
            remove: removeIds == null
                ? null
                : controller.rawRowData
                      .where((row) => removeIds.contains(row['id'].toString()))
                      .toList(),
          ),
        );
      case 'select':
        controller.selectRowsById((step['ids'] as List).cast<String>());
      case 'deselect':
        controller.deselectRowsById(
          (step['ids'] as List).cast<String>().toSet(),
        );
      case 'deselectAll':
        controller.deselectAll();
      default:
        fail('unknown step op: ${step['op']}');
    }
  }

  /// Asserts model consistency after every replay step.
  void checkInvariants(OsGridController<Map<String, dynamic>> controller) {
    final raw = controller.rawRowData;
    final ids = <String>{};

    // Node map integrity: exactly one node per raw row, reachable both via
    // the id map and iteration, each holding its raw row instance.
    controller.forEachRowNode((node) {
      expect(ids.add(node.id), isTrue, reason: 'duplicate node id ${node.id}');
      expect(controller.getNode(node.id), same(node));
    });
    expect(ids.length, raw.length, reason: 'node count == raw row count');
    for (final row in raw) {
      final id = row['id'].toString();
      final node = controller.getNode(id);
      expect(node, isNotNull, reason: 'node for $id exists');
      expect(node!.data, same(row), reason: 'node $id holds its raw row');
    }

    // Displayed row model consistency: the controller-level model has no
    // filter/sort of its own, so rendered nodes mirror the raw rows.
    expect(controller.getRenderedNodes().length, raw.length);
    expect(controller.rowCount, raw.length);

    // Selection integrity: no dangling ids, all resolvable to live rows.
    final survivingIds = raw.map((row) => row['id'].toString()).toSet();
    expect(
      controller.getSelectedIds().difference(survivingIds),
      isEmpty,
      reason: 'selection has no dangling ids',
    );
    expect(
      controller.getSelectedRows().length,
      controller.getSelectedIds().length,
    );

    // Node selected flags agree with the id-based selection set.
    for (final id in ids) {
      final node = controller.getNode(id)!;
      expect(
        node.selected,
        controller.getSelectedIds().contains(id),
        reason: 'node $id selected flag matches selection set',
      );
    }
    expect(
      controller.getSelectedNodes().length,
      controller.getSelectedIds().length,
    );
  }

  /// Replays a fixture end-to-end and asserts the recorded final state.
  void replayFixture(String fileName) {
    final fixtureJson = File(
      'test/fixtures/transaction_replay/$fileName',
    ).readAsStringSync();
    final fixture = jsonDecode(fixtureJson) as Map<String, dynamic>;

    final controller = newController();
    addTearDown(controller.dispose);
    controller.setRowData(
      (fixture['initialRows'] as List).cast<Map<String, dynamic>>(),
    );

    final initialSelection =
        (fixture['initialSelection'] as List?)?.cast<String>() ?? const [];
    if (initialSelection.isNotEmpty) {
      controller.selectRowsById(initialSelection);
    }
    checkInvariants(controller);

    final steps = (fixture['steps'] as List).cast<Map<String, dynamic>>();
    for (var i = 0; i < steps.length; i++) {
      applyStep(controller, steps[i]);
      checkInvariants(controller);
    }

    final expected = fixture['expected'] as Map<String, dynamic>;
    expect(
      controller.rowCount,
      expected['rowCount'],
      reason: '${fixture['name']}: final rowCount',
    );

    final expectedIds = (expected['rowIds'] as List).cast<String>();
    expect(
      controller.rawRowData.map((row) => row['id'].toString()).toList(),
      expectedIds,
      reason: '${fixture['name']}: final row-id order',
    );

    final expectedSelection = ((expected['selectedIds'] as List?) ?? const [])
        .cast<String>()
        .toSet();
    expect(
      controller.getSelectedIds(),
      expectedSelection,
      reason: '${fixture['name']}: surviving selection ids',
    );
    expect(
      controller.getSelectedRows().map((row) => row['id'].toString()).toSet(),
      expectedSelection,
    );

    final fieldChecks =
        (expected['fieldChecks'] as Map<String, dynamic>?) ?? const {};
    fieldChecks.forEach((id, fields) {
      final row = controller.rawRowData.firstWhere(
        (row) => row['id'].toString() == id,
      );
      (fields as Map<String, dynamic>).forEach((field, value) {
        expect(row[field], value, reason: '${fixture['name']}: $id.$field');
      });
    });

    // Node map integrity against the recorded final state: every surviving
    // id has a node, removed ids do not.
    for (final id in expectedIds) {
      expect(controller.getNode(id), isNotNull, reason: 'node $id survives');
    }
  }

  test('replay realtime-updates-50tx.json', () {
    replayFixture('realtime_updates.json');
  });

  test('replay bulk_reload.json', () {
    replayFixture('bulk_reload.json');
  });

  test('replay mixed_ops.json', () {
    replayFixture('mixed_ops.json');
  });
}
