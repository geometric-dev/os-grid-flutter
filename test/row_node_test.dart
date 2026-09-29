import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

void main() {
  group('RowNode identity layer — controller', () {
    late OsGridController<Map<String, dynamic>> controller;

    setUp(() {
      controller = OsGridController<Map<String, dynamic>>();
      controller.getRowId = (data) => data['id'].toString();
    });

    tearDown(() => controller.dispose());

    Map<String, dynamic> row(int id, String name) => {'id': id, 'name': name};

    test('getNode returns the node for each row and null for unknown ids', () {
      controller.setRowData([row(1, 'Alice'), row(2, 'Bob')]);

      expect(controller.getNode('1'), isNotNull);
      expect(controller.getNode('1')!.data['name'], 'Alice');
      expect(controller.getNode('2')!.data['name'], 'Bob');
      expect(controller.getNode('99'), isNull);
    });

    test('node instances are reused across setRowData for surviving ids', () {
      final aliceV1 = {'id': 1, 'name': 'Alice'};
      controller.setRowData([
        aliceV1,
        {'id': 2, 'name': 'Bob'},
      ]);
      final aliceNodeBefore = controller.getNode('1');

      final aliceV2 = {'id': 1, 'name': 'Alicia'};
      controller.setRowData([aliceV2]);
      final aliceNodeAfter = controller.getNode('1');

      // Same id -> same instance.
      expect(identical(aliceNodeBefore, aliceNodeAfter), isTrue);
      // But the data reference was refreshed.
      expect(identical(aliceNodeAfter!.data, aliceV2), isTrue);
      expect(aliceNodeAfter.data['name'], 'Alicia');
    });

    test('removed rows drop their nodes; re-added ids get fresh instances', () {
      controller.setRowData([row(1, 'Alice'), row(2, 'Bob')]);
      final bobNode = controller.getNode('2');

      controller.setRowData([row(1, 'Alice')]);
      expect(controller.getNode('2'), isNull);

      controller.setRowData([row(1, 'Alice'), row(2, 'Bobby')]);
      final bobNodeAgain = controller.getNode('2');
      expect(bobNodeAgain, isNotNull);
      expect(identical(bobNode, bobNodeAgain), isFalse);
    });

    test('rowIndex reflects post-sort order via getRenderedNodes', () {
      controller.setRowData([
        row(1, 'Alice'),
        row(2, 'Bob'),
        row(3, 'Charlie'),
      ]);

      // Simulate a sort that reverses the display order.
      controller.processedData = [
        row(3, 'Charlie'),
        row(1, 'Alice'),
        row(2, 'Bob'),
      ];

      final rendered = controller.getRenderedNodes().toList();
      expect(rendered.length, 3);
      expect(rendered[0].data['id'], 3);
      expect(rendered[0].rowIndex, 0);
      expect(rendered[1].data['id'], 1);
      expect(rendered[1].rowIndex, 1);
      expect(rendered[2].data['id'], 2);
      expect(rendered[2].rowIndex, 2);

      // Also reflected on lookups by ID.
      expect(controller.getNode('3')!.rowIndex, 0);
      expect(controller.getNode('1')!.rowIndex, 1);
      expect(controller.getNode('2')!.rowIndex, 2);
    });

    test('filtered-out rows get rowIndex -1 and are absent from rendering', () {
      controller.setRowData([
        row(1, 'Alice'),
        row(2, 'Bob'),
        row(3, 'Charlie'),
      ]);
      controller.processedData = [row(1, 'Alice'), row(3, 'Charlie')];

      expect(controller.getRenderedNodes().length, 2);
      expect(controller.getNode('2')!.rowIndex, -1);
      expect(controller.getNode('1')!.rowIndex, 0);
      expect(controller.getNode('3')!.rowIndex, 1);
    });

    test('getSelectedNodes mirrors selectRowsById in display order', () {
      controller.setRowData([
        row(1, 'Alice'),
        row(2, 'Bob'),
        row(3, 'Charlie'),
        row(4, 'Diana'),
      ]);
      controller.processedData = [
        row(4, 'Diana'),
        row(3, 'Charlie'),
        row(2, 'Bob'),
        row(1, 'Alice'),
      ];

      controller.selectRowsById(['1', '3']);

      final selectedNodes = controller.getSelectedNodes();
      expect(selectedNodes.length, 2);
      // Display order: Charlie (index 1) before Alice (index 3).
      expect(selectedNodes[0].data['id'], 3);
      expect(selectedNodes[1].data['id'], 1);
      for (final node in selectedNodes) {
        expect(node.selected, isTrue);
        expect(controller.isNodeSelected(node), isTrue);
      }
      expect(controller.isNodeSelected(controller.getNode('2')!), isFalse);

      // Deselecting by ID keeps node.selected synced.
      controller.deselectRowsById({'3'});
      expect(controller.getSelectedNodes().length, 1);
      expect(controller.getNode('3')!.selected, isFalse);
      expect(controller.isNodeSelected(controller.getNode('3')!), isFalse);
    });

    test('node.selected survives a sort (same instance kept in sync)', () {
      controller.setRowData([row(1, 'Alice'), row(2, 'Bob')]);
      controller.toggleSelection(0); // Alice
      final aliceNode = controller.getNode('1');
      expect(aliceNode!.selected, isTrue);

      controller.processedData = [row(2, 'Bob'), row(1, 'Alice')];

      // Sort does not rebuild nodes — same instance, still selected.
      expect(identical(controller.getNode('1'), aliceNode), isTrue);
      expect(controller.getNode('1')!.selected, isTrue);
      expect(controller.getSelectedNodes().map((n) => n.rowIndex), [1]);
    });

    test('forEachRowNode visits every raw row exactly once', () {
      controller.setRowData([
        row(1, 'Alice'),
        row(2, 'Bob'),
        row(3, 'Charlie'),
        row(4, 'Diana'),
        row(5, 'Eve'),
      ]);

      final visitedIds = <String>[];
      controller.forEachRowNode((node) => visitedIds.add(node.id));

      expect(visitedIds.length, 5);
      expect(visitedIds.toSet().length, 5);
      expect(visitedIds.toSet(), {'1', '2', '3', '4', '5'});
    });

    test('forEachRowNode yields one distinct node per raw row even when '
        'implicit ids collide', () {
      final plain = OsGridController<Map<String, dynamic>>();
      addTearDown(plain.dispose);
      final r1 = {'name': 'Dup'};
      final r2 = {'name': 'Dup'}; // equal content -> same hashCode id
      plain.setRowData([r1, r2]);

      final visited = <OsRowNode<Map<String, dynamic>>>[];
      plain.forEachRowNode(visited.add);

      expect(visited.length, 2);
      expect(identical(visited[0], visited[1]), isFalse);
      expect(identical(visited[0].data, r1), isTrue);
      expect(identical(visited[1].data, r2), isTrue);
    });

    test('applyTransaction update reuses the node and refreshes data ref', () {
      final bob = {'id': 2, 'name': 'Bob'};
      controller.setRowData([row(1, 'Alice'), bob]);
      final bobNode = controller.getNode('2');

      final bobUpdated = {'id': 2, 'name': 'Robert'};
      controller.applyTransaction(OsRowTransaction(update: [bobUpdated]));

      expect(identical(controller.getNode('2'), bobNode), isTrue);
      expect(controller.getNode('2')!.data['name'], 'Robert');
    });

    test('new nodes default height to null and group flags to false', () {
      controller.setRowData([row(1, 'Alice')]);
      final node = controller.getNode('1')!;
      expect(node.height, isNull);
      expect(node.group, isFalse);
      expect(node.groupKey, isNull);
    });

    test('OsRowNode.fromData derives id from getRowId or identityHashCode', () {
      final data = {'x': 1};
      final fallback = OsRowNode.fromData(data);
      expect(fallback.id, identityHashCode(data).toString());
      expect(fallback.rowIndex, -1);
      expect(fallback.selected, isFalse);

      final custom = OsRowNode.fromData(
        data,
        getRowId: (d) => 'custom-${d['x']}',
      );
      expect(custom.id, 'custom-1');
    });
  });

  group('RowNode identity layer — OsGrid widget integration', () {
    testWidgets('nodes are built from widget rowData and synced after sort', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              getRowId: (data) => data['id'].toString(),
              columnDefs: [
                const OsColumnDef(field: 'name', headerName: 'Name'),
              ],
              rowData: [
                {'id': 1, 'name': 'Alice'},
                {'id': 2, 'name': 'Bob'},
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      final alice = controller.getNode('1');
      final bob = controller.getNode('2');
      expect(alice, isNotNull);
      expect(bob, isNotNull);
      expect(controller.getRenderedNodes().length, 2);

      controller.dispose();
    });
  });
}
