import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

/// Quality program v2 item 50 — seeded-random property tests for
/// transactions and undo/redo.
///
/// Each case derives its data and operations from a fixed seed so
/// failures are reproducible.

List<Map<String, Object>> _generateRows(Random rng, int count) {
  const groups = ['A', 'B', 'C'];
  return List.generate(count, (i) {
    return <String, Object>{
      'id': 'row-$i',
      'group': groups[rng.nextInt(groups.length)],
      'name': 'n${rng.nextInt(8)}',
      'value': rng.nextInt(5) * 10,
    };
  });
}

Map<String, Object> _generatedAdd(Random rng, String id) {
  return <String, Object>{
    'id': id,
    'group': ['A', 'B', 'C'][rng.nextInt(3)],
    'name': 'n${rng.nextInt(8)}',
    'value': rng.nextInt(5) * 10,
  };
}

/// One randomly generated transaction plan over [liveIds]. Removals never
/// touch [protectedIds] (the selection under test), and remove/update id
/// sets are disjoint.
({
  Set<String> removedIds,
  Map<String, Map<String, Object>> updatesById,
  List<Map<String, Object>> adds,
})
_generatePlan(
  Random rng, {
  required List<String> liveIds,
  required Set<String> protectedIds,
  required String tag,
}) {
  final removablePool = liveIds.where((id) => !protectedIds.contains(id));
  final removedIds = <String>{
    for (final id in removablePool)
      if (rng.nextDouble() < 0.25) id,
  }.take(rng.nextInt(3)).toSet();

  final updateIds = <String>{
    for (final id in liveIds)
      if (!removedIds.contains(id) && rng.nextDouble() < 0.25) id,
  }.take(rng.nextInt(3)).toSet();

  // New instance, same stable id — mirrors immutable-style updates.
  final updatesById = <String, Map<String, Object>>{
    for (final id in updateIds) id: {'id': id, 'mutated': rng.nextInt(100)},
  };

  final addCount = rng.nextInt(3);
  final adds = [
    for (var k = 0; k < addCount; k++) _generatedAdd(rng, 'add-$tag-$k'),
  ];

  return (removedIds: removedIds, updatesById: updatesById, adds: adds);
}

void main() {
  group('applyTransaction invariants', () {
    test('rowCount, getNode membership, update identity, selection', () {
      for (var seed = 0; seed < 25; seed++) {
        final rng = Random(seed);
        final rows = _generateRows(rng, 40);
        final controller = OsGridController<Map<String, Object>>();
        controller.getRowId = (r) => r['id'] as String;
        controller.setRowData(rows);

        var expectedById = {for (final row in rows) row['id'] as String: row};

        // Selection under test: must survive every non-remove operation.
        const selectedIds = {'row-2', 'row-7', 'row-19'};
        controller.selectRowsById(selectedIds.toList());

        for (var round = 0; round < 6; round++) {
          final plan = _generatePlan(
            rng,
            liveIds: expectedById.keys.toList(),
            protectedIds: selectedIds,
            tag: 's${seed}r$round',
          );
          final removedInstances = [
            for (final id in plan.removedIds) expectedById[id]!,
          ];
          controller.applyTransaction(
            OsRowTransaction<Map<String, Object>>(
              add: plan.adds.isEmpty ? null : plan.adds,
              remove: removedInstances.isEmpty ? null : removedInstances,
              update: plan.updatesById.isEmpty
                  ? null
                  : plan.updatesById.values.toList(),
            ),
          );

          // Model update.
          final nextById = Map.of(expectedById);
          for (final id in plan.removedIds) {
            nextById.remove(id);
          }
          nextById.addAll(plan.updatesById);
          for (final row in plan.adds) {
            nextById[row['id'] as String] = row;
          }
          expectedById = nextById;

          // 1. Row-count consistency.
          expect(
            controller.rowCount,
            expectedById.length,
            reason: 'seed=$seed round=$round',
          );

          // 2. Removed ids absent from the node map; survivors present.
          for (final id in plan.removedIds) {
            expect(
              controller.getNode(id),
              isNull,
              reason: 'seed=$seed round=$round: $id',
            );
          }
          for (final id in expectedById.keys) {
            expect(
              controller.getNode(id),
              isNotNull,
              reason: 'seed=$seed round=$round: $id',
            );
          }

          // 3. Updated rows keep identity via getRowId: the node's data
          // is the exact replacement instance.
          for (final entry in plan.updatesById.entries) {
            final node = controller.getNode(entry.key)!;
            expect(
              identical(node.data, entry.value),
              isTrue,
              reason: 'seed=$seed round=$round: ${entry.key}',
            );
            expect(node.id, entry.key);
          }

          // 4. Selection-by-id survives non-removed transactions.
          expect(
            controller.getSelectedIds(),
            selectedIds.where((id) => expectedById.containsKey(id)).toSet(),
            reason: 'seed=$seed round=$round',
          );

          // Raw data mirrors the expected id set exactly.
          expect(
            controller.rawRowData.map((r) => r['id'] as String).toSet(),
            expectedById.keys.toSet(),
            reason: 'seed=$seed round=$round',
          );
        }
        controller.dispose();
      }
    });
  });

  group('UndoRedoService — seeded edit sequences', () {
    test('undo unwinds exactly; redo reapplies; clearStacks empties', () {
      const columns = ['name', 'value'];
      for (var seed = 0; seed < 30; seed++) {
        final rng = Random(seed);
        const rowCount = 12;
        const editCount = 15;

        final service = UndoRedoService(limit: 100);

        // snapshots[t] is the full cell state after t edits.
        final state = {
          for (var r = 0; r < rowCount; r++)
            for (final c in columns) '$r|$c': 'init-$r-$c',
        };
        final snapshots = <Map<String, String>>[Map.of(state)];

        for (var t = 1; t <= editCount; t++) {
          final row = rng.nextInt(rowCount);
          final col = columns[rng.nextInt(columns.length)];
          final key = '$row|$col';
          var newValue = 'v$t-${rng.nextInt(50)}';
          while (newValue == state[key]) {
            newValue = 'v$t-${rng.nextInt(50)}';
          }

          service.onCellEditingStarted();
          final changed = newValue != state[key];
          if (changed) {
            service.onCellValueChanged(
              rowIndex: row,
              columnId: col,
              oldValue: state[key],
              newValue: newValue,
            );
          }
          service.onCellEditingStopped(valueChanged: changed);

          state[key] = newValue;
          snapshots.add(Map.of(state));
        }

        expect(service.currentUndoSize, editCount);

        // Full unwind: every undo restores the previous snapshot exactly.
        var t = editCount;
        while (service.currentUndoSize > 0) {
          final action = service.undo();
          expect(action, isNotNull, reason: 'seed=$seed');
          t--;
          for (final change in action!.cellValueChanges) {
            final key = '${change.rowIndex}|${change.columnId}';
            expect(
              change.oldValue,
              snapshots[t][key],
              reason: 'seed=$seed undo-to=$t key=$key',
            );
            state[key] = change.oldValue as String;
          }
          expect(service.currentRedoSize, editCount - t, reason: 'seed=$seed');
        }
        expect(state, snapshots[0], reason: 'seed=$seed');
        expect(service.undo(), isNull);

        // Full reapply: redo walks the snapshots forward again.
        while (service.currentRedoSize > 0) {
          final action = service.redo();
          expect(action, isNotNull, reason: 'seed=$seed');
          for (final change in action!.cellValueChanges) {
            final key = '${change.rowIndex}|${change.columnId}';
            expect(
              change.newValue,
              snapshots[t + 1][key],
              reason: 'seed=$seed redo-to=${t + 1} key=$key',
            );
            state[key] = change.newValue as String;
          }
          t++;
          expect(state, snapshots[t], reason: 'seed=$seed redo-to=$t');
        }
        expect(t, editCount);
        expect(state, snapshots[editCount], reason: 'seed=$seed');
        expect(service.redo(), isNull);

        // Structural clear empties both stacks.
        service.clearStacks();
        expect(service.currentUndoSize, 0);
        expect(service.currentRedoSize, 0);
        expect(service.undo(), isNull);
        expect(service.redo(), isNull);
      }
    });
  });

  group('widget-level editing commits drive undo/redo', () {
    Widget buildGrid({
      required OsGridController<Map<String, Object>> controller,
      required List<Map<String, Object>> rows,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: OsGrid<Map<String, Object>>(
              controller: controller,
              columnDefs: const [
                OsColumnDef<Map<String, Object>>(field: 'id', width: 120),
                OsColumnDef<Map<String, Object>>(
                  field: 'name',
                  width: 140,
                  editable: true,
                ),
                OsColumnDef<Map<String, Object>>(
                  field: 'city',
                  width: 140,
                  editable: true,
                ),
              ],
              rowData: rows,
              getRowId: (r) => r['id'] as String,
              undoRedoCellEditing: true,
            ),
          ),
        ),
      );
    }

    Future<void> commitEdit(
      WidgetTester tester,
      OsGridController<Map<String, Object>> controller,
      int rowIndex,
      String colId,
      String newValue,
    ) async {
      controller.startEditingCell(rowIndex: rowIndex, colId: colId);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText).last, newValue);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
    }

    /// Snapshot of every (row, editable-column) cell value.
    Map<String, Object> snapshotCells(List<Map<String, Object>> rows) => {
      for (var i = 0; i < rows.length; i++) ...{
        '$i|name': rows[i]['name']!,
        '$i|city': rows[i]['city']!,
      },
    };

    testWidgets('undo after N edits restores prior values exactly; '
        'redo reapplies', (tester) async {
      const seeds = [4, 13, 27];
      const editCount = 5;

      for (final seed in seeds) {
        final rng = Random(seed);
        final rows = _generateRows(rng, 8)
            .map(
              (row) => <String, Object>{...row, 'city': 'c${rng.nextInt(9)}'},
            )
            .toList();
        final controller = OsGridController<Map<String, Object>>();

        await tester.pumpWidget(buildGrid(controller: controller, rows: rows));
        await tester.pumpAndSettle();

        // snapshots[t] = cell state after t committed edits.
        final snapshots = <Map<String, Object>>[snapshotCells(rows)];

        for (var t = 1; t <= editCount; t++) {
          final rowIndex = rng.nextInt(rows.length);
          final colId = rng.nextBool() ? 'name' : 'city';
          var newValue = 'e$t-${rng.nextInt(90)}';
          while (newValue == rows[rowIndex][colId]) {
            newValue = 'e$t-${rng.nextInt(90)}';
          }

          await commitEdit(tester, controller, rowIndex, colId, newValue);

          expect(
            rows[rowIndex][colId],
            newValue,
            reason: 'seed=$seed edit=$t: commit must write the value',
          );
          expect(controller.getCurrentUndoSize(), t, reason: 'seed=$seed');
          snapshots.add(snapshotCells(rows));
        }

        // Undo everything: each step restores the exact prior snapshot.
        for (var t = editCount - 1; t >= 0; t--) {
          controller.undoCellEditing();
          await tester.pumpAndSettle();
          expect(
            snapshotCells(rows),
            snapshots[t],
            reason: 'seed=$seed undone-to=$t',
          );
          expect(controller.getCurrentUndoSize(), t, reason: 'seed=$seed');
          expect(
            controller.getCurrentRedoSize(),
            editCount - t,
            reason: 'seed=$seed',
          );
        }

        // Redo everything: reapplies each recorded new value exactly.
        for (var t = 1; t <= editCount; t++) {
          controller.redoCellEditing();
          await tester.pumpAndSettle();
          expect(
            snapshotCells(rows),
            snapshots[t],
            reason: 'seed=$seed redone-to=$t',
          );
        }
        expect(controller.getCurrentRedoSize(), 0, reason: 'seed=$seed');

        await tester.pumpWidget(const SizedBox.shrink());
      }
    });

    testWidgets('structural rowData change empties stacks', (tester) async {
      final controller = OsGridController<Map<String, Object>>();
      final rows = _generateRows(
        Random(6),
        6,
      ).map((row) => <String, Object>{...row, 'city': 'x'}).toList();

      await tester.pumpWidget(buildGrid(controller: controller, rows: rows));
      await tester.pumpAndSettle();

      await commitEdit(tester, controller, 0, 'name', 'edited-a');
      await commitEdit(tester, controller, 2, 'city', 'edited-b');
      expect(controller.getCurrentUndoSize(), 2);

      // Replace rowData — structural change must invalidate both stacks.
      await tester.pumpWidget(
        buildGrid(
          controller: controller,
          rows: [
            for (final row in rows) <String, Object>{...row},
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(controller.getCurrentUndoSize(), 0);
      expect(controller.getCurrentRedoSize(), 0);
    });
  });
}
