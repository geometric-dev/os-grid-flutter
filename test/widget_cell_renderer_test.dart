import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: SizedBox(width: 600, height: 400, child: child)),
);

List<Map<String, dynamic>> _rows(int count) => [
  for (var i = 0; i < count; i++) {'name': 'Row $i', 'score': i},
];

void main() {
  group('Hybrid widget cell rendering', () {
    testWidgets(
      'no overlay builder is wired without a widget renderer column',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            OsGrid<Map<String, dynamic>>(
              columnDefs: const [
                OsColumnDef(field: 'name', headerName: 'Name'),
              ],
              rowData: _rows(3),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final grid = tester.widget<VirtualisedGrid>(
          find.byType(VirtualisedGrid),
        );
        expect(grid.cellWidgetBuilder, isNull);
      },
    );

    testWidgets('cellRenderer widgets render inside their cell rects', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          OsGrid<Map<String, dynamic>>(
            rowHeight: 40,
            headerHeight: 48,
            columnDefs: [
              const OsColumnDef<Map<String, dynamic>>(
                field: 'name',
                headerName: 'Name',
                width: 300,
              ),
              OsColumnDef<Map<String, dynamic>>(
                field: 'score',
                headerName: 'Score',
                width: 300,
                cellRenderer: (params) => Text('W-${params.value}'),
              ),
            ],
            rowData: _rows(3),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Widget cells receive the raw field value.
      expect(find.text('W-0'), findsOneWidget);
      expect(find.text('W-1'), findsOneWidget);

      // Row 1's widget sits inside its cell rect: top = 48 (header) +
      // 40 (row 0) = 88, height = 40, in the second 300px column.
      final gridBox =
          tester.renderObject(find.byType(VirtualisedGrid)) as RenderBox;
      final gridTopLeft = gridBox.localToGlobal(Offset.zero);
      final rect = tester.getRect(find.text('W-1'));

      expect(rect.top, greaterThanOrEqualTo(gridTopLeft.dy + 88));
      expect(rect.bottom, lessThanOrEqualTo(gridTopLeft.dy + 128));
      expect(rect.left, greaterThanOrEqualTo(gridTopLeft.dx + 300));
    });

    testWidgets('columns without a renderer keep canvas-only cells', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          OsGrid<Map<String, dynamic>>(
            rowHeight: 40,
            headerHeight: 48,
            columnDefs: [
              const OsColumnDef<Map<String, dynamic>>(
                field: 'name',
                headerName: 'Name',
                width: 300,
              ),
              OsColumnDef<Map<String, dynamic>>(
                field: 'score',
                headerName: 'Score',
                width: 300,
                cellRenderer: (params) => Text('W-${params.value}'),
              ),
            ],
            rowData: _rows(3),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The overlay band is wired (one column has a renderer)…
      final grid = tester.widget<VirtualisedGrid>(find.byType(VirtualisedGrid));
      expect(grid.cellWidgetBuilder, isNotNull);

      // …but only the renderer column emits widgets — the plain column's
      // content stays canvas-painted (not findable as a Text widget).
      expect(find.text('Row 0'), findsNothing);
      expect(find.text('W-0'), findsOneWidget);
    });

    testWidgets('cellRendererBuilder receives BuildContext', (tester) async {
      await tester.pumpWidget(
        _wrap(
          OsGrid<Map<String, dynamic>>(
            rowHeight: 40,
            headerHeight: 48,
            columnDefs: [
              OsColumnDef<Map<String, dynamic>>(
                field: 'score',
                headerName: 'Score',
                width: 300,
                cellRendererBuilder: (context, params) => Icon(
                  Icons.star,
                  color: Theme.of(context).colorScheme.primary,
                  key: ValueKey('star-${params.rowIndex}'),
                ),
              ),
            ],
            rowData: _rows(3),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('star-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('star-2')), findsOneWidget);
    });

    testWidgets('widget cells are interactive', (tester) async {
      final taps = <int>[];

      await tester.pumpWidget(
        _wrap(
          OsGrid<Map<String, dynamic>>(
            rowHeight: 40,
            headerHeight: 48,
            columnDefs: [
              OsColumnDef<Map<String, dynamic>>(
                field: 'score',
                headerName: 'Score',
                width: 300,
                cellRenderer: (params) => TextButton(
                  onPressed: () => taps.add(params.rowIndex),
                  child: Text('BTN-${params.rowIndex}'),
                ),
              ),
            ],
            rowData: _rows(3),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('BTN-0'));
      // Advance past the grid's double-tap arena timeout so the tap
      // resolves in favour of the button.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(taps, [0]);
    });

    testWidgets('widget cells reposition with scroll', (tester) async {
      await tester.pumpWidget(
        _wrap(
          OsGrid<Map<String, dynamic>>(
            rowHeight: 40,
            headerHeight: 48,
            columnDefs: [
              OsColumnDef<Map<String, dynamic>>(
                field: 'score',
                headerName: 'Score',
                width: 600,
                cellRenderer: (params) => Text(
                  'W-${params.rowIndex}',
                  key: ValueKey('w-${params.rowIndex}'),
                ),
              ),
            ],
            rowData: _rows(60),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Rows 0..8-ish visible initially; row 0's widget exists.
      expect(find.byKey(const ValueKey('w-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('w-30')), findsNothing);

      // Scroll down ~600px (15 rows at 40px).
      await tester.drag(find.byType(VirtualisedGrid), const Offset(0, -600));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('w-0')), findsNothing);
      expect(find.byKey(const ValueKey('w-15')), findsOneWidget);
    });
  });
}
