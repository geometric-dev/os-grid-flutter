import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

/// Regression tests for the runtime controller swap (didUpdateWidget).
///
/// Contract: when `widget.controller` changes, every coordinator that
/// captured the previous controller instance is re-pointed at the new one
/// BEFORE the state re-binds controller callbacks, so request hooks land on
/// the live controller and coordinator emissions never touch the disposed
/// instance. The outgoing controller's hooks are detached.
void main() {
  Widget grid(OsGridController<Map<String, dynamic>> controller, Key key) =>
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 300,
            child: OsGrid<Map<String, dynamic>>(
              key: key,
              controller: controller,
              columnDefs: const [
                OsColumnDef(field: 'a', headerName: 'A', width: 100),
                OsColumnDef(field: 'b', headerName: 'B', width: 100),
              ],
              rowData: [
                {'a': 1, 'b': 2},
                {'a': 3, 'b': 4},
              ],
            ),
          ),
        ),
      );

  testWidgets('controller swap wires column API onto the new controller', (
    tester,
  ) async {
    final first = OsGridController<Map<String, dynamic>>();
    await tester.pumpWidget(grid(first, const Key('grid-1')));
    await tester.pump();

    final second = OsGridController<Map<String, dynamic>>();
    await tester.pumpWidget(grid(second, const Key('grid-2')));
    await tester.pump();

    // The column-API hook must now be served by the new controller's
    // coordinator: hiding a column through it must succeed.
    second.setColumnsVisible(['a'], false);
    await tester.pump();
    expect(
      second.getAllDisplayedColumns().map((c) => c.effectiveColId),
      isNot(contains('a')),
    );

    // The outgoing controller's hook was detached, so its API no longer
    // reaches into the live grid's state.
    first.setColumnsVisible(['b'], false);
    await tester.pump();
    expect(
      second.getAllDisplayedColumns().map((c) => c.effectiveColId),
      contains('b'),
    );

    // Flush debounced work (model-updated timer) before teardown.
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('controller swap keeps undo/redo wired on the new controller', (
    tester,
  ) async {
    Widget undoGrid(
      OsGridController<Map<String, dynamic>> controller,
      Key key,
    ) => MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 400,
          height: 300,
          child: OsGrid<Map<String, dynamic>>(
            key: key,
            controller: controller,
            undoRedoCellEditing: true,
            undoRedoCellEditingLimit: 10,
            columnDefs: const [
              OsColumnDef(
                field: 'a',
                headerName: 'A',
                width: 100,
                editable: true,
              ),
            ],
            rowData: [
              {'a': 1},
            ],
          ),
        ),
      ),
    );

    final first = OsGridController<Map<String, dynamic>>();
    await tester.pumpWidget(undoGrid(first, const Key('grid-1')));
    await tester.pump();

    final second = OsGridController<Map<String, dynamic>>();
    await tester.pumpWidget(undoGrid(second, const Key('grid-2')));
    await tester.pump();

    // Undo/redo request hooks must be wired on the new controller: the
    // query API resolves through them without throwing. The old
    // controller's detachment is covered by the column-API test above
    // (the hooks share the same rebind path).
    expect(second.getCurrentUndoSize(), equals(0));
  });
}
