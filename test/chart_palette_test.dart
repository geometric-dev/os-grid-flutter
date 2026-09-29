import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

Widget _grid({
  required OsGridController<Map<String, dynamic>> controller,
  ValueChanged<OsChartRangeCreatedEvent>? onChartRangeCreated,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 600,
        height: 400,
        child: OsGrid<Map<String, dynamic>>(
          controller: controller,
          cellSelection: const OsCellSelection(),
          enableIntegratedCharts: true,
          onChartRangeCreated: onChartRangeCreated,
          columnDefs: const [
            OsColumnDef(field: 'month', headerName: 'Month', width: 150),
            OsColumnDef(field: 'revenue', headerName: 'Revenue', width: 150),
            OsColumnDef(field: 'cost', headerName: 'Cost', width: 150),
          ],
          rowData: const [
            {'month': 'Jan', 'revenue': 100, 'cost': 60},
            {'month': 'Feb', 'revenue': 120, 'cost': 70},
            {'month': 'Mar', 'revenue': 90, 'cost': 50},
          ],
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('controller.createChartRange extracts and emits the definition', (
    tester,
  ) async {
    final controller = OsGridController<Map<String, dynamic>>();
    addTearDown(controller.dispose);
    OsChartRangeCreatedEvent? event;
    controller.onChartRangeCreated.listen((e) => event = e);

    await tester.pumpWidget(
      _grid(controller: controller, onChartRangeCreated: (e) => event = e),
    );
    await tester.pumpAndSettle();

    controller.addCellRange(
      const CellRangeParams(
        rowStartIndex: 0,
        rowEndIndex: 2,
        columnStartIndex: 0,
        columnEndIndex: 2,
      ),
    );
    await tester.pumpAndSettle();

    final definition = controller.createChartRange(type: OsChartType.bar);

    expect(definition, isNotNull);
    expect(definition!.type, OsChartType.bar);
    expect(definition.categories, ['Jan', 'Feb', 'Mar']);
    expect(definition.series.map((s) => s.name), ['Revenue', 'Cost']);
    expect(event, isNotNull);
    expect(event!.definition, definition);
  });

  testWidgets('createChartRange returns null without a range selection', (
    tester,
  ) async {
    final controller = OsGridController<Map<String, dynamic>>();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_grid(controller: controller));
    await tester.pumpAndSettle();

    expect(controller.createChartRange(type: OsChartType.line), isNull);
  });

  testWidgets('chart palette button opens the popup and selecting a type '
      'creates the chart', (tester) async {
    final controller = OsGridController<Map<String, dynamic>>();
    addTearDown(controller.dispose);
    OsChartRangeCreatedEvent? event;
    controller.onChartRangeCreated.listen((e) => event = e);

    await tester.pumpWidget(_grid(controller: controller));
    await tester.pumpAndSettle();

    controller.addCellRange(
      const CellRangeParams(
        rowStartIndex: 0,
        rowEndIndex: 1,
        columnStartIndex: 0,
        columnEndIndex: 1,
      ),
    );
    await tester.pumpAndSettle();

    // The palette button floats at the range's trailing-top corner:
    // column 1 ends at x=300, row 0 starts at y=48 → button ≈ (302, 50).
    await tester.tapAt(const Offset(311, 59));
    // Advance past the grid's double-tap arena timeout so the tap resolves.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    // The popup with four chart-type choices appears.
    expect(find.byType(ChartPalettePopup), findsOneWidget);
    expect(find.byIcon(Icons.show_chart), findsOneWidget);
    expect(find.byIcon(Icons.bar_chart), findsOneWidget);
    expect(find.byIcon(Icons.pie_chart_outline), findsOneWidget);
    expect(find.byIcon(Icons.scatter_plot), findsOneWidget);

    await tester.tap(find.byIcon(Icons.bar_chart));
    await tester.pumpAndSettle();

    expect(event, isNotNull);
    expect(event!.definition.type, OsChartType.bar);
    expect(find.byType(ChartPalettePopup), findsNothing);
  });

  testWidgets('palette does not appear when integrated charts are disabled', (
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
                OsColumnDef(field: 'month', headerName: 'Month', width: 150),
                OsColumnDef(
                  field: 'revenue',
                  headerName: 'Revenue',
                  width: 150,
                ),
              ],
              rowData: const [
                {'month': 'Jan', 'revenue': 100},
                {'month': 'Feb', 'revenue': 120},
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    controller.addCellRange(
      const CellRangeParams(
        rowStartIndex: 0,
        rowEndIndex: 1,
        columnStartIndex: 0,
        columnEndIndex: 1,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(311, 59));
    await tester.pumpAndSettle();

    expect(find.byType(ChartPalettePopup), findsNothing);
    expect(
      tester.widget<VirtualisedGrid>(find.byType(VirtualisedGrid)).enableCharts,
      isFalse,
    );
  });
}
