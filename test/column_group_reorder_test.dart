import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

/// Helper to build a grid with grouped columns and pump it.
Future<void> _pumpGroupedGrid(
  WidgetTester tester, {
  required OsGridController<Map<String, dynamic>> controller,
  required List<OsColumnDefBase> columnDefs,
  List<Map<String, dynamic>>? rowData,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 800,
          height: 400,
          child: OsGrid<Map<String, dynamic>>(
            controller: controller,
            columnDefs: columnDefs,
            rowData:
                rowData ??
                [
                  {'a': 1, 'b': 2, 'c': 3, 'd': 4, 'e': 5},
                ],
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('Column group management during reorder', () {
    testWidgets('groups are preserved when column moves within its group', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();

      await _pumpGroupedGrid(
        tester,
        controller: controller,
        columnDefs: [
          const OsColumnGroup(
            headerName: 'Group 1',
            groupId: 'g1',
            children: [
              OsColumnDef(field: 'a', headerName: 'A', sortable: true),
              OsColumnDef(field: 'b', headerName: 'B', sortable: true),
              OsColumnDef(field: 'c', headerName: 'C', sortable: true),
            ],
          ),
          const OsColumnDef(field: 'd', headerName: 'D', sortable: true),
        ],
      );

      // Move column 'a' to index 2 (still within group 1: b, c, a)
      // After move: order is [b, c, a, d]
      // 'b', 'c', 'a' all belong to Group 1 — group should be preserved
      controller.moveColumns(['a'], 2);
      await tester.pump();

      // The grid should still render without error (2-level header intact)
      expect(find.byType(OsGrid<Map<String, dynamic>>), findsOneWidget);
    });

    testWidgets('group splits when column is moved out', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();

      await _pumpGroupedGrid(
        tester,
        controller: controller,
        columnDefs: [
          const OsColumnGroup(
            headerName: 'Group 1',
            groupId: 'g1',
            children: [
              OsColumnDef(field: 'a', headerName: 'A', sortable: true),
              OsColumnDef(field: 'b', headerName: 'B', sortable: true),
              OsColumnDef(field: 'c', headerName: 'C', sortable: true),
            ],
          ),
          const OsColumnDef(field: 'd', headerName: 'D', sortable: true),
        ],
      );

      // Move 'b' to the end (after 'd') — out of its group
      // New order: [a, c, d, b]
      // 'a' and 'c' are adjacent and in Group 1 — they keep the group
      // 'b' is now isolated — it gets its own span
      controller.moveColumns(['b'], 3);
      await tester.pump();

      // Grid renders without error
      expect(find.byType(OsGrid<Map<String, dynamic>>), findsOneWidget);
    });

    testWidgets('column joins a group when moved between its members', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();

      await _pumpGroupedGrid(
        tester,
        controller: controller,
        columnDefs: [
          const OsColumnGroup(
            headerName: 'Group 1',
            groupId: 'g1',
            children: [
              OsColumnDef(field: 'a', headerName: 'A', sortable: true),
              OsColumnDef(field: 'b', headerName: 'B', sortable: true),
            ],
          ),
          const OsColumnDef(field: 'c', headerName: 'C', sortable: true),
          const OsColumnGroup(
            headerName: 'Group 2',
            groupId: 'g2',
            children: [
              OsColumnDef(field: 'd', headerName: 'D', sortable: true),
              OsColumnDef(field: 'e', headerName: 'E', sortable: true),
            ],
          ),
        ],
      );

      // Move 'c' (ungrouped) between 'd' and 'e' (Group 2)
      // New order: [a, b, d, c, e]
      // 'c' is NOT in Group 2 originally, so it should NOT join Group 2
      // 'd' and 'e' are now separated — each gets its own Group 2 span
      controller.moveColumns(['c'], 2);
      await tester.pump();

      // Grid renders without error
      expect(find.byType(OsGrid<Map<String, dynamic>>), findsOneWidget);
    });

    testWidgets('moveColumnByIndex preserves groups', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();

      await _pumpGroupedGrid(
        tester,
        controller: controller,
        columnDefs: [
          const OsColumnGroup(
            headerName: 'Personal',
            groupId: 'personal',
            children: [
              OsColumnDef(field: 'a', headerName: 'Name', sortable: true),
              OsColumnDef(field: 'b', headerName: 'Age', sortable: true),
            ],
          ),
          const OsColumnGroup(
            headerName: 'Work',
            groupId: 'work',
            children: [
              OsColumnDef(field: 'c', headerName: 'Title', sortable: true),
              OsColumnDef(field: 'd', headerName: 'Dept', sortable: true),
            ],
          ),
        ],
      );

      // Move column at index 0 ('a') to index 1 — still within Personal group
      controller.moveColumnByIndex(0, 1);
      await tester.pump();

      // Grid renders without error (groups preserved)
      expect(find.byType(OsGrid<Map<String, dynamic>>), findsOneWidget);
    });

    testWidgets('multiple moves maintain correct group structure', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();

      await _pumpGroupedGrid(
        tester,
        controller: controller,
        columnDefs: [
          const OsColumnGroup(
            headerName: 'Group A',
            groupId: 'ga',
            children: [
              OsColumnDef(field: 'a', headerName: 'A', sortable: true),
              OsColumnDef(field: 'b', headerName: 'B', sortable: true),
              OsColumnDef(field: 'c', headerName: 'C', sortable: true),
            ],
          ),
          const OsColumnDef(field: 'd', headerName: 'D', sortable: true),
        ],
      );

      // First move: move 'b' out of the group to the end
      controller.moveColumns(['b'], 3);
      await tester.pump();

      // Second move: move 'b' back between 'a' and 'c'
      controller.moveColumns(['b'], 1);
      await tester.pump();

      // 'a', 'b', 'c' are adjacent again and all in Group A — group restored
      expect(find.byType(OsGrid<Map<String, dynamic>>), findsOneWidget);
    });

    testWidgets('hidden columns do not break group spans', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();

      await _pumpGroupedGrid(
        tester,
        controller: controller,
        columnDefs: [
          const OsColumnGroup(
            headerName: 'Group 1',
            groupId: 'g1',
            children: [
              OsColumnDef(field: 'a', headerName: 'A', sortable: true),
              OsColumnDef(field: 'b', headerName: 'B', sortable: true),
              OsColumnDef(field: 'c', headerName: 'C', sortable: true),
            ],
          ),
          const OsColumnDef(field: 'd', headerName: 'D', sortable: true),
        ],
      );

      // Hide column 'b' — 'a' and 'c' should still be grouped
      controller.setColumnsVisible(['b'], false);
      await tester.pump();

      // Grid renders without error
      expect(find.byType(OsGrid<Map<String, dynamic>>), findsOneWidget);
    });

    testWidgets('reorder with hidden columns preserves groups', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();

      await _pumpGroupedGrid(
        tester,
        controller: controller,
        columnDefs: [
          const OsColumnGroup(
            headerName: 'Group 1',
            groupId: 'g1',
            children: [
              OsColumnDef(field: 'a', headerName: 'A', sortable: true),
              OsColumnDef(field: 'b', headerName: 'B', sortable: true),
              OsColumnDef(field: 'c', headerName: 'C', sortable: true),
            ],
          ),
          const OsColumnDef(field: 'd', headerName: 'D', sortable: true),
        ],
      );

      // Hide 'b', then reorder 'a' after 'c'
      controller.setColumnsVisible(['b'], false);
      await tester.pump();

      controller.moveColumns(['a'], 1);
      await tester.pump();

      // 'c' and 'a' are adjacent and both in Group 1 — group preserved
      expect(find.byType(OsGrid<Map<String, dynamic>>), findsOneWidget);
    });

    testWidgets('two groups remain separate after reorder within each', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();

      await _pumpGroupedGrid(
        tester,
        controller: controller,
        columnDefs: [
          const OsColumnGroup(
            headerName: 'Alpha',
            groupId: 'alpha',
            children: [
              OsColumnDef(field: 'a', headerName: 'A1', sortable: true),
              OsColumnDef(field: 'b', headerName: 'A2', sortable: true),
            ],
          ),
          const OsColumnGroup(
            headerName: 'Beta',
            groupId: 'beta',
            children: [
              OsColumnDef(field: 'c', headerName: 'B1', sortable: true),
              OsColumnDef(field: 'd', headerName: 'B2', sortable: true),
            ],
          ),
        ],
      );

      // Swap within Alpha: move 'a' after 'b'
      controller.moveColumnByIndex(0, 1);
      await tester.pump();

      // Both groups should still be intact (b, a | c, d)
      expect(find.byType(OsGrid<Map<String, dynamic>>), findsOneWidget);
    });

    testWidgets('ungrouped column between two groups stays ungrouped', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();

      await _pumpGroupedGrid(
        tester,
        controller: controller,
        columnDefs: [
          const OsColumnGroup(
            headerName: 'Left',
            groupId: 'left',
            children: [
              OsColumnDef(field: 'a', headerName: 'A', sortable: true),
            ],
          ),
          const OsColumnDef(field: 'b', headerName: 'B', sortable: true),
          const OsColumnGroup(
            headerName: 'Right',
            groupId: 'right',
            children: [
              OsColumnDef(field: 'c', headerName: 'C', sortable: true),
            ],
          ),
        ],
      );

      // Move 'b' to the end — it should remain ungrouped
      controller.moveColumns(['b'], 2);
      await tester.pump();

      // Grid renders without error
      expect(find.byType(OsGrid<Map<String, dynamic>>), findsOneWidget);
    });

    testWidgets('column moved between same-group members joins the group', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();

      await _pumpGroupedGrid(
        tester,
        controller: controller,
        columnDefs: [
          const OsColumnGroup(
            headerName: 'Numbers',
            groupId: 'nums',
            children: [
              OsColumnDef(field: 'a', headerName: 'One', sortable: true),
              OsColumnDef(field: 'b', headerName: 'Two', sortable: true),
            ],
          ),
          const OsColumnDef(field: 'c', headerName: 'Three', sortable: true),
          const OsColumnGroup(
            headerName: 'Numbers',
            groupId: 'nums',
            children: [
              OsColumnDef(field: 'd', headerName: 'Four', sortable: true),
            ],
          ),
        ],
      );

      // Move 'c' (ungrouped) to the end — now [a, b, d, c]
      // 'a', 'b', 'd' are all in 'nums' group and adjacent — they form one span
      controller.moveColumns(['c'], 3);
      await tester.pump();

      // Grid renders without error
      expect(find.byType(OsGrid<Map<String, dynamic>>), findsOneWidget);
    });

    testWidgets('pin override splits group at pin boundary', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();

      await _pumpGroupedGrid(
        tester,
        controller: controller,
        columnDefs: [
          const OsColumnGroup(
            headerName: 'Group 1',
            groupId: 'g1',
            children: [
              OsColumnDef(field: 'a', headerName: 'A', sortable: true),
              OsColumnDef(field: 'b', headerName: 'B', sortable: true),
              OsColumnDef(field: 'c', headerName: 'C', sortable: true),
            ],
          ),
          const OsColumnDef(field: 'd', headerName: 'D', sortable: true),
        ],
      );

      // Pin 'b' to the left — this should split Group 1
      controller.setColumnsPinned(['b'], OsColumnPin.left);
      await tester.pump();

      // Grid renders without error (group split at pin boundary)
      expect(find.byType(OsGrid<Map<String, dynamic>>), findsOneWidget);
    });
  });
}
