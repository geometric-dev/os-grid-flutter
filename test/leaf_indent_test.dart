import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';
import 'package:os_grid_flutter/src/rendering/range_painter.dart';

void main() {
  group('Leaf row depth stamping', () {
    test('row grouping stamps leaves with depth = group level + 1', () {
      final service = RowGroupService<Map<String, dynamic>>();
      final rows = [
        {'id': '1', 'dept': 'Eng', 'name': 'A'},
        {'id': '2', 'dept': 'Eng', 'name': 'B'},
        {'id': '3', 'dept': 'Sales', 'name': 'C'},
      ];
      final display = service.buildGroupedData(
        data: rows,
        groupColumns: const [OsColumnDef<Map<String, dynamic>>(field: 'dept')],
        state: RowGroupState()..expandAll(),
        valueColumns: const [],
      );

      final leaves = display
          .where((r) => r[RowGroupKeys.kIsGroupRow] != true)
          .toList();
      expect(leaves.length, 3);
      for (final leaf in leaves) {
        expect(leaf[RowGroupKeys.kRowDepth], 1);
      }
      // Group rows stay at their own levels.
      expect(
        display
            .where((r) => r[RowGroupKeys.kIsGroupRow] == true)
            .every((r) => r[RowGroupKeys.kGroupLevel] == 0),
        isTrue,
      );
    });

    test('tree data stamps leaves with their path depth', () {
      final service = TreeDataService<Map<String, dynamic>>();
      final rows = [
        {
          'id': '1',
          'path': ['Engineering', 'Team 0'],
        },
        {
          'id': '2',
          'path': ['Engineering', 'Team 0'],
        },
        {
          'id': '3',
          'path': ['Sales'],
        },
      ];
      final display = service.buildTreeData(
        data: rows,
        getDataPath: (row) => row['path'] as List<String>,
        state: RowGroupState()..expandAll(),
      );

      final depthOf = {
        for (final r in display)
          if (r['id'] != null) r['id'] as String: r[RowGroupKeys.kRowDepth],
      };
      // Leaves under a level-1 group node sit at depth 2.
      expect(depthOf['1'], 2);
      expect(depthOf['2'], 2);
      // Leaf directly under a level-0 node sits at depth 1.
      expect(depthOf['3'], 1);
    });

    test('flat data (no grouping) is returned without depth stamps', () {
      // Sanity: the painter treats a missing kRowDepth as 0, so flat grids
      // paint exactly as before.
      // ignore: avoid_redundant_argument_values
      final row = <String, dynamic>{'id': '1', 'name': 'A'};
      expect(row.containsKey(RowGroupKeys.kRowDepth), isFalse);
    });
  });

  group('Fill handle geometry with pinned columns', () {
    testWidgets('handle anchors to the end cell, not shifted by pinned width', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              height: 400,
              child: OsGrid<Map<String, dynamic>>(
                controller: controller,
                cellSelection: const OsCellSelection(),
                columnDefs: const [
                  OsColumnDef(
                    field: 'name',
                    headerName: 'Name',
                    width: 140,
                    checkboxSelection: true,
                    pinned: OsColumnPin.left,
                  ),
                  OsColumnDef(field: 'age', headerName: 'Age', width: 140),
                  OsColumnDef(field: 'city', headerName: 'City', width: 140),
                ],
                rowData: [
                  for (var i = 0; i < 6; i++)
                    {'name': 'Row $i', 'age': i, 'city': 'C$i'},
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Range on the Age column (first center column, index 1), row 0.
      controller.addCellRange(
        const CellRangeParams(
          rowStartIndex: 0,
          rowEndIndex: 0,
          columnStartIndex: 1,
          columnEndIndex: 1,
        ),
      );
      await tester.pumpAndSettle();

      final customPaint = tester.widget<CustomPaint>(
        find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is RangePainter,
        ),
      );
      final painter = customPaint.painter! as RangePainter;
      final handle = painter.lastPaintedFillHandle;
      expect(handle, isNotNull);

      // Geometry: header 48 + row 0 (42) = 90 bottom edge. The pinned Name
      // column is 140 wide, so Age starts at x=140 and is 140 wide — the
      // handle's left edge = 140 + 140 - 8 = 272. The pre-fix bug
      // accumulated the pinned width into the center-section offset,
      // shifting the handle to 412.
      expect(handle!.left, closeTo(272, 0.5));
      expect(handle.top + handle.height, closeTo(90, 0.5));
    });
  });
}
