import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

import 'gestures_test_utils.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: SizedBox(width: 800, height: 600, child: child)),
);

OsGrid<Map<String, dynamic>> _grid({
  required OsGridController<Map<String, dynamic>> controller,
  required List<Map<String, dynamic>> rows,
}) {
  return OsGrid<Map<String, dynamic>>(
    controller: controller,
    getRowId: (row) => row['id'] as String,
    columnDefs: [
      const OsColumnDef(
        field: 'sel',
        headerName: '',
        checkboxSelection: true,
        headerCheckboxSelection: true,
      ),
      const OsColumnDef(field: 'name'),
    ],
    rowData: rows,
    rowSelection: OsRowSelection.multiple(),
  );
}

void main() {
  testWidgets('per-column flag suppresses synthetic column and paints flag', (
    tester,
  ) async {
    final controller = OsGridController<Map<String, dynamic>>();
    await tester.pumpWidget(
      _wrap(
        _grid(
          controller: controller,
          rows: const [
            {'id': '1', 'name': 'Alice'},
            {'id': '2', 'name': 'Bob'},
          ],
        ),
      ),
    );
    await tester.pump();

    final grid = tester.widget<VirtualisedGrid>(find.byType(VirtualisedGrid));
    expect(
      grid.columns.any((c) => c.field == '__checkbox__'),
      isFalse,
      reason: 'synthetic checkbox column suppressed in per-column mode',
    );
    final flagged = grid.columns.firstWhere((c) => c.field == 'sel');
    expect(flagged.checkboxSelection, isTrue);
    expect(flagged.headerCheckboxSelection, isTrue);
  });

  testWidgets('tapping a flagged cell toggles that row only', (tester) async {
    final controller = OsGridController<Map<String, dynamic>>();
    await tester.pumpWidget(
      _wrap(
        _grid(
          controller: controller,
          rows: const [
            {'id': '1', 'name': 'Alice'},
            {'id': '2', 'name': 'Bob'},
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    // First data cell of the flagged column: x=75 (col width default 150),
    // y = header(48) + rowHeight/2(21) = 69.
    await tapCanvasCell(tester, localOffset: const Offset(75, 69));

    expect(controller.getSelectedIds(), {'1'});

    // Tapping again deselects.
    await tapCanvasCell(tester, localOffset: const Offset(75, 69));
    expect(controller.getSelectedIds(), isEmpty);
  });

  testWidgets('header select-all on flagged column toggles scoped selection', (
    tester,
  ) async {
    final controller = OsGridController<Map<String, dynamic>>();
    await tester.pumpWidget(
      _wrap(
        _grid(
          controller: controller,
          rows: const [
            {'id': '1', 'name': 'Alice'},
            {'id': '2', 'name': 'Bob'},
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Header centre of the flagged column.
    await tapHeader(tester, const Offset(75, 24));
    expect(controller.getSelectedIds(), {'1', '2'});

    await tapHeader(tester, const Offset(75, 24));
    expect(controller.getSelectedIds(), isEmpty);
  });

  testWidgets('legacy synthetic path unchanged when no flags used', (
    tester,
  ) async {
    final controller = OsGridController<Map<String, dynamic>>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: OsGrid<Map<String, dynamic>>(
              controller: controller,
              getRowId: (row) => row['id'] as String,
              columnDefs: const [OsColumnDef(field: 'name')],
              rowData: const [
                {'id': '1', 'name': 'Alice'},
              ],
              rowSelection: OsRowSelection.multiple(checkboxes: true),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final grid = tester.widget<VirtualisedGrid>(find.byType(VirtualisedGrid));
    expect(
      grid.columns.any((c) => c.field == '__checkbox__'),
      isTrue,
      reason: 'legacy synthetic checkbox column still present',
    );
  });
}
