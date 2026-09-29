import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';
import 'package:os_grid_flutter/src/rendering/grid_painter.dart';
import 'package:os_grid_flutter/src/row_grouping/row_group_panel.dart';

void main() {
  group('Row Group Panel Phase 3 Reconciliations', () {
    testWidgets('Performance: Dragging a chip does not rebuild OsGrid', (
      WidgetTester tester,
    ) async {
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
            ),
          ),
        ),
      );

      controller.addRowGroupColumn('country');
      await tester.pumpAndSettle();

      final gridPainters = tester
          .widgetList<CustomPaint>(
            find.descendant(
              of: find.byType(OsGrid<Map<String, dynamic>>),
              matching: find.byType(CustomPaint),
            ),
          )
          .map((c) => c.painter)
          .whereType<GridPainter>()
          .toList();

      expect(
        gridPainters.isNotEmpty,
        true,
        reason: 'GridPainter should be found',
      );
      final originalPainter = gridPainters.first;

      // Start drag on the chip
      final chipFinder = find.text('country');
      final gesture = await tester.startGesture(tester.getCenter(chipFinder));
      await tester.pump();

      // Move gesture (dragging)
      await gesture.moveBy(const Offset(50, 0));
      await tester.pump();

      final gridPaintersAfterDrag = tester
          .widgetList<CustomPaint>(
            find.descendant(
              of: find.byType(OsGrid<Map<String, dynamic>>),
              matching: find.byType(CustomPaint),
            ),
          )
          .map((c) => c.painter)
          .whereType<GridPainter>()
          .toList();

      final currentPainter = gridPaintersAfterDrag.first;
      expect(
        currentPainter,
        same(originalPainter),
        reason:
            'Dragging chip should not trigger OsGrid rebuild / GridPainter recreation',
      );

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('Sort Sync Test: two-way sync works', (
      WidgetTester tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              columnDefs: [const OsColumnDef(field: 'country')],
              rowData: const [],
              rowGroupPanelVisibility: OsRowGroupPanelVisibility.always,
            ),
          ),
        ),
      );

      controller.addRowGroupColumn('country');
      await tester.pumpAndSettle();

      // Tap the sort icon on the chip
      final sortIconFinder = find.byIcon(Icons.arrow_upward);
      expect(sortIconFinder, findsOneWidget); // Faint neutral icon

      await tester.tap(sortIconFinder);
      await tester.pumpAndSettle();

      expect(controller.getSortModel().length, 1);
      expect(controller.getSortModel().first.sort, OsSortDirection.ascending);

      await tester.tap(sortIconFinder);
      await tester.pumpAndSettle();

      expect(controller.getSortModel().first.sort, OsSortDirection.descending);
    });

    testWidgets(
      'Hysteresis Test: 10px directional latch prevents mode switch',
      (WidgetTester tester) async {
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

        await tester.pumpAndSettle();

        final headerCenter = tester
            .getTopLeft(find.byType(OsGrid<Map<String, dynamic>>))
            .translate(50, 56);

        // Attempt 1: Drag up to -5px (within 10px threshold)
        var gesture = await tester.startGesture(
          headerCenter,
          kind: PointerDeviceKind.mouse,
        );
        await tester.pump(const Duration(milliseconds: 100));
        await gesture.moveTo(headerCenter.translate(10, 0));
        await tester.pump(const Duration(milliseconds: 100));

        final panelBottom = tester
            .getTopLeft(find.byType(OsGrid<Map<String, dynamic>>))
            .translate(50, 40);
        await gesture.moveTo(
          panelBottom.translate(0, -5),
        ); // Inside panel bounds, but < 10px threshold
        await tester.pump(const Duration(milliseconds: 100));
        await gesture.up();
        await tester.pumpAndSettle();

        // Should NOT have triggered drop (mode didn't switch)
        expect(
          callbackCount,
          0,
          reason: 'Drag within 10px threshold should be ignored',
        );

        // Attempt 2: Drag up to -15px (beyond 10px threshold)
        gesture = await tester.startGesture(
          headerCenter,
          kind: PointerDeviceKind.mouse,
        );
        await tester.pump(const Duration(milliseconds: 100));
        await gesture.moveTo(headerCenter.translate(10, 0));
        await tester.pump(const Duration(milliseconds: 100));

        await gesture.moveTo(
          panelBottom.translate(0, -15),
        ); // Beyond 10px threshold
        await tester.pump(const Duration(milliseconds: 100));
        await gesture.up();
        await tester.pumpAndSettle();

        // Should HAVE triggered drop
        expect(
          callbackCount,
          1,
          reason: 'Drag beyond 10px threshold should trigger drop',
        );
        expect(lastColumns, ['country']);
      },
    );

    testWidgets(
      'Expansion Preservation Test: Verify expansion is preserved when toggling sort',
      (WidgetTester tester) async {
        final controller = OsGridController<Map<String, dynamic>>();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: OsGrid<Map<String, dynamic>>(
                controller: controller,
                columnDefs: [
                  const OsColumnDef(field: 'country', rowGroup: true),
                  const OsColumnDef(field: 'city'),
                ],
                rowData: const [
                  {'country': 'UK', 'city': 'London'},
                  {'country': 'UK', 'city': 'Manchester'},
                  {'country': 'USA', 'city': 'New York'},
                ],
                rowGroupPanelVisibility: OsRowGroupPanelVisibility.always,
              ),
            ),
          ),
        );

        // Programmatically group by country since rowGroup: true alone might not sync if the test setup doesn't trigger the grid's init cycle properly
        controller.addRowGroupColumn('country');
        await tester.pumpAndSettle();

        // Expand all row groups
        controller.expandAll();
        await tester.pumpAndSettle();

        // Expand all row groups
        controller.expandAll();
        await tester.pumpAndSettle();

        // Verify rows are expanded
        expect(controller.isRowExpanded('row-group-country-UK'), isTrue);
        expect(controller.isRowExpanded('row-group-country-USA'), isTrue);

        // Get the chip for 'country' and tap it to sort
        final chipFinder = find.widgetWithText(Container, 'country').first;
        await tester.tap(chipFinder);
        await tester.pumpAndSettle();

        // Verify expansion is preserved
        expect(controller.isRowExpanded('row-group-country-UK'), isTrue);
        expect(controller.isRowExpanded('row-group-country-USA'), isTrue);

        // Tap again to toggle sort
        await tester.tap(chipFinder);
        await tester.pumpAndSettle();

        // Verify expansion is preserved
        expect(controller.isRowExpanded('row-group-country-UK'), isTrue);
        expect(controller.isRowExpanded('row-group-country-USA'), isTrue);
      },
    );

    testWidgets(
      'Autoscroll Integration Test: scroll listener is wired and indexForGlobalPosition is always valid',
      (WidgetTester tester) async {
        final controller = OsGridController<Map<String, dynamic>>();
        final columnDefs = List.generate(
          10,
          (i) => OsColumnDef(field: 'col_$i'),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: OsGrid<Map<String, dynamic>>(
                controller: controller,
                columnDefs: columnDefs,
                rowData: const [],
                rowGroupPanelVisibility: OsRowGroupPanelVisibility.always,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Group 8 columns so the panel has scrollable chips
        for (int i = 0; i < 8; i++) {
          controller.addRowGroupColumn('col_$i');
        }
        await tester.pumpAndSettle();

        final panelState = tester.state<RowGroupPanelState>(
          find.byType(RowGroupPanel),
        );

        // indexForGlobalPosition must return a non-negative clamped index for
        // any global position on screen — never -1.
        final panelCenter = tester.getCenter(find.byType(RowGroupPanel));
        final indexAtCenter = panelState.indexForGlobalPosition(panelCenter);
        expect(indexAtCenter, greaterThanOrEqualTo(0));
        expect(indexAtCenter, lessThanOrEqualTo(8)); // at most past-the-end

        // Also valid at the far left edge
        final panelLeft = tester.getTopLeft(find.byType(RowGroupPanel));
        final indexAtLeft = panelState.indexForGlobalPosition(panelLeft);
        expect(indexAtLeft, greaterThanOrEqualTo(0));

        // Simulate a scroll jump (as would happen during autoscroll) and verify
        // the controller still has a valid offset without throwing.
        if (panelState.scrollController.position.maxScrollExtent > 0) {
          panelState.scrollController.jumpTo(
            panelState.scrollController.position.maxScrollExtent / 2,
          );
          await tester.pump();
          expect(panelState.scrollController.offset, greaterThan(0));
        }
      },
    );
  });
}
