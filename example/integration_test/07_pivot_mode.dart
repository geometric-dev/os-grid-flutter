// ignore_for_file: file_names
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

import 'helpers/integration_helpers.dart';

/// Pivot mode integration scenarios (previously untested by the QA suite).
///
/// Covers: enabling pivot mode, generating result columns from pivot +
/// value columns, the pivot-mode-changed event, and toggling pivot off.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  List<Map<String, dynamic>> rows() => [
    {'country': 'UK', 'city': 'London', 'sales': 100},
    {'country': 'UK', 'city': 'Manchester', 'sales': 200},
    {'country': 'US', 'city': 'NY', 'sales': 300},
    {'country': 'US', 'city': 'Boston', 'sales': 150},
    {'country': 'FR', 'city': 'Paris', 'sales': 80},
  ];

  OsGrid<Map<String, dynamic>> buildGrid(
    OsGridController<Map<String, dynamic>> controller,
  ) {
    return OsGrid<Map<String, dynamic>>(
      controller: controller,
      columnDefs: [
        const OsColumnDef(field: 'country', headerName: 'Country'),
        const OsColumnDef(field: 'city', headerName: 'City'),
        const OsColumnDef(field: 'sales', headerName: 'Sales', aggFunc: 'sum'),
      ],
      rowData: rows(),
    );
  }

  group('Pivot mode', () {
    testWidgets('enabling pivot generates result columns from unique values', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();
      var pivotEventCount = 0;
      await tester.pumpWidget(
        wrapGrid(
          OsGrid<Map<String, dynamic>>(
            controller: controller,
            onPivotModeChanged: (_) => pivotEventCount++,
            columnDefs: [
              const OsColumnDef(field: 'country', headerName: 'Country'),
              const OsColumnDef(field: 'city', headerName: 'City'),
              const OsColumnDef(
                field: 'sales',
                headerName: 'Sales',
                aggFunc: 'sum',
              ),
            ],
            rowData: rows(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(controller.isPivotMode(), isFalse);
      expect(controller.getPivotResultColumns(), isEmpty);

      // Pivot transforms the GROUPED display data, so row-group columns
      // must be set as well (pivot = group rows x pivot values).
      controller.setRowGroupColumns(['country']);
      controller.setPivotColumns(['city']);
      controller.setValueColumns(['sales']);
      controller.setPivotMode(true);
      await tester.pumpAndSettle();

      expect(controller.isPivotMode(), isTrue);
      expect(pivotEventCount, 1);
      expect(controller.getPivotColumns(), ['city']);

      // One result column per unique pivot value: 5 cities.
      final resultCols = controller.getPivotResultColumns();
      expect(resultCols, isNotEmpty);
      expect(resultCols.length, 5);
      for (final city in ['London', 'Manchester', 'NY', 'Boston', 'Paris']) {
        expect(
          resultCols.join('|'),
          contains(city),
          reason: 'result columns should reference pivot value $city',
        );
      }

      // The grid still paints grouped rows without throwing.
      expect(displayRows(tester), isNotEmpty);
    });

    testWidgets('toggling pivot off clears result columns', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();
      await tester.pumpWidget(wrapGrid(buildGrid(controller)));
      await tester.pumpAndSettle();

      controller.setRowGroupColumns(['country']);
      controller.setPivotColumns(['city']);
      controller.setValueColumns(['sales']);
      controller.setPivotMode(true);
      await tester.pumpAndSettle();
      expect(controller.getPivotResultColumns(), isNotEmpty);

      controller.setPivotMode(false);
      await tester.pumpAndSettle();

      expect(controller.isPivotMode(), isFalse);
      expect(controller.getPivotResultColumns(), isEmpty);
      expect(displayRows(tester), isNotEmpty);
    });

    testWidgets('pivot mode survives a re-render of the grid', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();
      await tester.pumpWidget(wrapGrid(buildGrid(controller)));
      await tester.pumpAndSettle();

      controller.setRowGroupColumns(['country']);
      controller.setPivotColumns(['city']);
      controller.setPivotMode(true);
      await tester.pumpAndSettle();

      // Rebuild the same widget subtree (identical key/tree position): the
      // Element/State are retained, so pivot mode must survive the rebuild
      // with the controller reference intact.
      await tester.pumpWidget(
        wrapGrid(
          OsGrid<Map<String, dynamic>>(
            controller: controller,
            columnDefs: [
              const OsColumnDef(field: 'country', headerName: 'Country'),
              const OsColumnDef(field: 'city', headerName: 'City'),
              const OsColumnDef(
                field: 'sales',
                headerName: 'Sales',
                aggFunc: 'sum',
              ),
            ],
            rowData: rows(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(controller.isPivotMode(), isTrue);
    });
  });
}
