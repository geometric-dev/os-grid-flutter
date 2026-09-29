import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';
import 'package:os_grid_flutter/src/row_grouping/row_group_panel.dart';

void main() {
  group('Row Group Panel (Phase 1)', () {
    testWidgets('addRowGroupColumn no-op contract avoids duplicate callbacks', (
      WidgetTester tester,
    ) async {
      int callbackCount = 0;
      List<String>? lastColumns;

      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              columnDefs: [
                const OsColumnDef(field: 'country'),
                const OsColumnDef(field: 'city'),
              ],
              rowData: const [],
              rowGroupPanelVisibility: OsRowGroupPanelVisibility.always,
              onRowGroupColumnsChanged: (cols) {
                callbackCount++;
                lastColumns = cols;
              },
            ),
          ),
        ),
      );

      // Add a column
      controller.addRowGroupColumn('country');
      await tester.pump();

      expect(callbackCount, 1);
      expect(lastColumns, ['country']);

      // Add the SAME column again (should be a no-op)
      controller.addRowGroupColumn('country');
      await tester.pump();

      // Callback count should not increase
      expect(callbackCount, 1);

      // Add another column
      controller.addRowGroupColumn('city');
      await tester.pump();

      expect(callbackCount, 2);
      expect(lastColumns, ['country', 'city']);

      // Remove a column
      controller.removeRowGroupColumn('country');
      await tester.pump();

      expect(callbackCount, 3);
      expect(lastColumns, ['city']);

      // Remove a non-existent column (should be a no-op)
      controller.removeRowGroupColumn('country');
      await tester.pump();

      expect(callbackCount, 3);
    });

    testWidgets('Panel renders with chips when grouping is active', (
      WidgetTester tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              columnDefs: [
                const OsColumnDef(field: 'country', headerName: 'Country Name'),
                const OsColumnDef(field: 'city'),
              ],
              rowData: const [],
              rowGroupPanelVisibility: OsRowGroupPanelVisibility.always,
            ),
          ),
        ),
      );

      // Initially shows placeholder
      expect(find.text('Drag here to set row groups'), findsOneWidget);
      expect(find.text('Country Name'), findsNothing);

      // Group by country
      controller.addRowGroupColumn('country');
      await tester.pump();

      // Chip appears
      expect(find.text('Drag here to set row groups'), findsNothing);
      expect(find.text('Country Name'), findsOneWidget);
    });

    testWidgets('Dragging column header into panel adds row group', (
      WidgetTester tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              columnDefs: [
                const OsColumnDef(field: 'country', headerName: 'Country Name'),
              ],
              rowData: const [],
              rowGroupPanelVisibility: OsRowGroupPanelVisibility.always,
            ),
          ),
        ),
      );

      // Wait for grid to render
      await tester.pumpAndSettle();

      // Ensure panel is empty
      expect(controller.getRowGroupColumns(), isEmpty);

      // Simulate a drag from the header to the panel
      // Row group panel takes up the first 40 pixels height, the grid follows.
      // Header row is below the panel. First column header center is roughly at (50, 40 + 16)
      final headerCenter = tester
          .getTopLeft(find.byType(OsGrid<Map<String, dynamic>>))
          .translate(50, 56);
      final panelCenter = tester
          .getTopLeft(find.text('Drag here to set row groups'))
          .translate(50, 10);

      final gesture = await tester.startGesture(
        headerCenter,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump(
        const Duration(milliseconds: 100),
      ); // allow drag to start

      // Move slightly to trigger drag threshold
      await gesture.moveTo(headerCenter.translate(10, 0));
      await tester.pump(const Duration(milliseconds: 100));

      // Move to panel
      await gesture.moveTo(panelCenter);
      await tester.pump(const Duration(milliseconds: 100));

      // Release drop
      await gesture.up();
      await tester.pumpAndSettle();

      // Check if it was added
      expect(controller.getRowGroupColumns(), ['country']);
    });

    testWidgets('Chip interactions (remove, drag out, reorder)', (
      WidgetTester tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              columnDefs: [
                const OsColumnDef(field: 'country', headerName: 'Country'),
                const OsColumnDef(field: 'year', headerName: 'Year'),
              ],
              rowData: [
                {'country': 'USA', 'year': 2020},
              ],
              rowGroupPanelVisibility: OsRowGroupPanelVisibility.always,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      controller.setRowGroupColumns(['country', 'year']);
      await tester.pumpAndSettle();

      // Tap 'x' on 'Country' chip to remove it
      final countryText = find.descendant(
        of: find.byType(RowGroupPanel),
        matching: find.text('Country'),
      );
      final countryChipRow = find
          .ancestor(of: countryText, matching: find.byType(Row))
          .first;
      final closeIcon = find.descendant(
        of: countryChipRow,
        matching: find.byIcon(Icons.close),
      );
      await tester.tap(closeIcon);
      await tester.pumpAndSettle();

      expect(controller.getRowGroupColumns(), ['year']);

      // Add 'country' back to test reorder
      controller.setRowGroupColumns(['year', 'country']);
      await tester.pumpAndSettle();

      // Drag 'year' (index 0) over 'country'      // Reorder 'year' to after 'country'
      final yearChip = find.descendant(
        of: find.byType(RowGroupPanel),
        matching: find.text('Year'),
      );
      final countryChip = find.descendant(
        of: find.byType(RowGroupPanel),
        matching: find.text('Country'),
      );

      final startPos = tester.getCenter(yearChip);
      final endPos = tester.getCenter(countryChip);
      final gesture = await tester.startGesture(startPos);
      await tester.pump(const Duration(milliseconds: 100));
      // Move in increments to ensure updates fire
      await gesture.moveTo(
        Offset(startPos.dx + (endPos.dx - startPos.dx) / 2, startPos.dy),
      );
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.moveTo(endPos);
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.up();
      await tester.pumpAndSettle();

      // Verify reorder
      expect(controller.getRowGroupColumns(), ['country', 'year']);

      // Drag out 'country' to remove it
      final countryChipNew = find.descendant(
        of: find.byType(RowGroupPanel),
        matching: find.text('Country'),
      );
      final gesture2 = await tester.startGesture(
        tester.getCenter(countryChipNew),
        pointer: 2,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump(const Duration(milliseconds: 500));
      // Move far outside the panel (e.g. to bottom of screen)
      await gesture2.moveTo(const Offset(0, 500));
      await tester.pump(const Duration(milliseconds: 100));
      await gesture2.up();
      await tester.pumpAndSettle();

      // Add 'year' back to test toggle sort
      controller.setRowGroupColumns(['year']);
      await tester.pumpAndSettle();

      final yearText = find.descendant(
        of: find.byType(RowGroupPanel),
        matching: find.text('Year'),
      );

      // Initially not sorted
      expect(controller.getSortModel(), isEmpty);

      // Tap to sort ascending
      await tester.tap(yearText);
      await tester.pumpAndSettle();
      expect(controller.getSortModel().length, 1);
      expect(controller.getSortModel()[0].colId, 'year');
      expect(controller.getSortModel()[0].sort, OsSortDirection.ascending);

      // Tap to sort descending
      await tester.tap(yearText);
      await tester.pumpAndSettle();
      expect(controller.getSortModel()[0].sort, OsSortDirection.descending);

      // Tap to remove sort
      await tester.tap(yearText);
      await tester.pumpAndSettle();
      expect(controller.getSortModel(), isEmpty);
    });

    testWidgets(
      'Row Group Panel (Phase 1) Invariant: grouped column auto-removed when def deleted',
      (WidgetTester tester) async {
        final controller = OsGridController();
        final List<OsColumnDef> columnDefs = [
          const OsColumnDef(
            headerName: 'Country',
            field: 'country',
            rowGroup: true,
          ),
          const OsColumnDef(headerName: 'Year', field: 'year', rowGroup: true),
        ];

        int callbackCount = 0;
        List<String>? lastColumns;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: OsGrid(
                controller: controller,
                columnDefs: columnDefs,
                rowData: const [
                  {'country': 'US', 'year': 2020},
                  {'country': 'US', 'year': 2021},
                ],
                rowGroupPanelVisibility: OsRowGroupPanelVisibility.always,
                onRowGroupColumnsChanged: (cols) {
                  callbackCount++;
                  lastColumns = cols;
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Both grouped
        expect(controller.getRowGroupColumns(), ['country', 'year']);

        // Simulate a state change where 'year' column def is removed
        final List<OsColumnDef> updatedDefs = [
          const OsColumnDef(
            headerName: 'Country',
            field: 'country',
            rowGroup: true,
          ),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: OsGrid(
                controller: controller,
                columnDefs: updatedDefs,
                rowData: const [
                  {'country': 'US', 'year': 2020},
                  {'country': 'US', 'year': 2021},
                ],
                rowGroupPanelVisibility: OsRowGroupPanelVisibility.always,
                onRowGroupColumnsChanged: (cols) {
                  callbackCount++;
                  lastColumns = cols;
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 'year' should be automatically removed from group columns
        expect(controller.getRowGroupColumns(), ['country']);
        expect(callbackCount, greaterThan(0));
        expect(lastColumns, ['country']);
      },
    );
  });
}
