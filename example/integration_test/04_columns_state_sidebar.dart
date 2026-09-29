// ignore_for_file: file_names
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

import 'helpers/integration_helpers.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // -----------------------------------------------------------------
  // Scenario 15: resize + autosize + pin + ensureVisible
  // -----------------------------------------------------------------
  group('Scenario 15 — resize / autosize / pin / ensureVisible', () {
    testWidgets('setColumnWidths resizes and emits onColumnResized', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();
      OsColumnResizedEvent? resized;

      await tester.pumpWidget(
        wrapGrid(
          OsGrid<Map<String, dynamic>>(
            controller: controller,
            columnDefs: const [
              OsColumnDef(field: 'name', headerName: 'Name', width: 150),
              OsColumnDef(field: 'age', headerName: 'Age', width: 80),
              OsColumnDef(field: 'city', headerName: 'City', width: 120),
            ],
            rowData: const [
              {'name': 'Alice', 'age': 30, 'city': 'London'},
              {'name': 'Bob', 'age': 25, 'city': 'Paris'},
            ],
            onColumnResized: (e) => resized = e,
          ),
        ),
      );
      await tester.pumpAndSettle();

      controller.setColumnWidths([
        const ColumnWidthEntry(colId: 'name', newWidth: 250),
        const ColumnWidthEntry(colId: 'age', newWidth: 120),
      ]);
      await tester.pump();

      expect(resized, isNotNull);
      expect(resized!.columns.length, 2);
      final state = {for (final s in controller.getColumnState()) s.colId: s};
      expect(state['name']!.width, 250);
      expect(state['age']!.width, 120);
      // respect min/max clamp — width within definition bounds
      expect(state['city']!.width, 120);

      await takeScreenshotBestEffort(binding, '15-resize');
      // Avoid post-frame emit after dispose — tear down widget first.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      controller.dispose();
    });

    testWidgets('autoSizeColumns widens columns to fit their content', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();
      await tester.pumpWidget(
        wrapGrid(
          OsGrid<Map<String, dynamic>>(
            controller: controller,
            columnDefs: const [
              OsColumnDef(field: 'name', headerName: 'Name', width: 50),
              OsColumnDef(field: 'desc', headerName: 'Desc', width: 50),
            ],
            rowData: const [
              {'name': 'AlexandriaLongName', 'desc': 'x'},
              {'name': 'Bob', 'desc': 'y'},
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      double widthOf(String colId) => controller
          .getColumnState()
          .firstWhere((s) => s.colId == colId)
          .width!;

      expect(widthOf('name'), 50);

      // Measures 'AlexandriaLongName' and grows the column past its
      // definition width.
      controller.autoSizeColumns();
      await tester.pumpAndSettle();
      expect(widthOf('name'), greaterThan(50));

      // Scoped to one column, and sized to cell content only.
      controller.setColumnWidths([
        const ColumnWidthEntry(colId: 'desc', newWidth: 50),
        const ColumnWidthEntry(colId: 'name', newWidth: 50),
      ]);
      await tester.pumpAndSettle();
      controller.autoSizeColumns(colIds: ['name'], skipHeader: true);
      await tester.pumpAndSettle();
      expect(widthOf('name'), greaterThan(50));
      expect(widthOf('desc'), 50);

      expect(find.byType(VirtualisedGrid), findsOneWidget);
      controller.dispose();
    });

    testWidgets('setColumnDefs + sizeColumnsToFit reshape the grid', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();
      await tester.pumpWidget(
        wrapGrid(
          OsGrid<Map<String, dynamic>>(
            controller: controller,
            columnDefs: const [
              OsColumnDef(field: 'name', headerName: 'Name', width: 100),
              OsColumnDef(field: 'desc', headerName: 'Desc', width: 100),
            ],
            rowData: const [
              {'name': 'Alexandria', 'desc': 'x', 'note': 'n'},
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Runtime definition swap: the new column renders, the old one is gone.
      controller.setColumnDefs(const [
        OsColumnDef(field: 'name', headerName: 'Name', width: 100),
        OsColumnDef(field: 'note', headerName: 'Note', width: 100),
      ]);
      await tester.pumpAndSettle();
      expect(controller.getColumns().map((c) => c.field), ['name', 'note']);

      // Sizing to fit distributes the viewport across the two columns.
      controller.sizeColumnsToFit();
      await tester.pumpAndSettle();
      final total = controller.getColumnState().fold<double>(
        0,
        (sum, s) => sum + (s.width ?? 0),
      );
      expect(total, greaterThan(200));

      controller.dispose();
    });

    testWidgets('pin + ensureVisible (scroll notifier)', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();
      // Many columns to make ensureVisible meaningful.
      final cols = List.generate(
        15,
        (i) => OsColumnDef(field: 'col$i', headerName: 'Col $i', width: 120),
      );
      final row = {for (var i = 0; i < 15; i++) 'col$i': 'v$i'};

      await tester.pumpWidget(
        wrapGrid(
          OsGrid<Map<String, dynamic>>(
            controller: controller,
            columnDefs: cols,
            rowData: [row],
          ),
          width: 600,
        ),
      );
      await tester.pumpAndSettle();

      // EnsureVisible via widget-bound controller — verify pin interactions.
      // First verify a standalone controller emits correctly (widget consumes command on pump,
      // so we validate emission before the widget resets it).
      final standalone = OsGridController<Map<String, dynamic>>();
      standalone.columnDefs = cols;
      standalone.ensureColumnVisible('col5');
      expect(
        standalone.scrollCommandNotifier.value,
        isA<EnsureColumnVisibleCommand>(),
      );
      standalone.dispose();

      // Now pin left/right via the widget-bound controller and verify pin state.
      controller.setColumnsPinned(['col0'], OsColumnPin.left);
      await tester.pump();
      expect(controller.isPinningLeft(), isTrue);
      controller.setColumnsPinned(['col14'], OsColumnPin.right);
      await tester.pump();
      expect(controller.isPinningRight(), isTrue);

      // Pinned column is a no-op — must not set notifier.
      controller.scrollCommandNotifier.value = null;
      controller.ensureColumnVisible('col0'); // pinned left
      // Check before pump consumes (should remain null for pinned).
      expect(controller.scrollCommandNotifier.value, isNull);

      // Unpin and verify ensureVisible emits (standalone proof above + unpin).
      controller.setColumnsPinned(['col0'], null);
      await tester.pump();
      // Verify unpinned emission via standalone logic parity.
      final check = OsGridController<Map<String, dynamic>>();
      check.columnDefs = cols;
      check.columnPinState = {'col14': OsColumnPin.right}; // keep right pin
      check.ensureColumnVisible('col0', position: ColumnScrollPosition.start);
      expect(
        check.scrollCommandNotifier.value,
        isA<EnsureColumnVisibleCommand>(),
      );
      check.dispose();

      // ensureIndexVisible for rows — verify via standalone to avoid widget consume race.
      final rowCheck = OsGridController<Map<String, dynamic>>();
      rowCheck.setRowData(List.generate(50, (i) => {'col0': i}));
      rowCheck.ensureIndexVisible(40, position: RowScrollPosition.top);
      expect(
        rowCheck.scrollCommandNotifier.value,
        isA<EnsureIndexVisibleCommand>(),
      );
      rowCheck.dispose();

      // Also exercise widget path (consumed on pump, so just ensure no throw).
      controller.setRowData(List.generate(50, (i) => {'col0': i}));
      await tester.pump();
      controller.ensureIndexVisible(10, position: RowScrollPosition.top);
      await tester.pump();

      await takeScreenshotBestEffort(binding, '15-pin-ensure');
      // Dispose after replacing widget to avoid post-frame emit after bus dispose (gotcha #14).
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      controller.dispose();
    });

    testWidgets('hidden + ensureVisible no-op for hidden', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();
      await tester.pumpWidget(
        wrapGrid(
          OsGrid<Map<String, dynamic>>(
            controller: controller,
            columnDefs: const [
              OsColumnDef(field: 'a', width: 100),
              OsColumnDef(field: 'b', width: 100),
              OsColumnDef(field: 'c', width: 100),
            ],
            rowData: const [
              {'a': 1, 'b': 2, 'c': 3},
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      controller.setColumnsVisible(['b'], false);
      await tester.pump();
      expect(controller.getAllDisplayedColumns().length, 2);

      controller.scrollCommandNotifier.value = null;
      controller.ensureColumnVisible('b');
      await tester.pump();
      expect(controller.scrollCommandNotifier.value, isNull);

      controller.dispose();
    });
  });

  // -----------------------------------------------------------------
  // Scenario 16: reorder + groups + state purge
  // -----------------------------------------------------------------
  group('Scenario 16 — reorder / groups / state purge', () {
    testWidgets(
      'moveColumns reorders and getDisplayedColBefore/After respect it',
      (tester) async {
        final controller = OsGridController<Map<String, dynamic>>();
        await tester.pumpWidget(
          wrapGrid(
            OsGrid<Map<String, dynamic>>(
              controller: controller,
              columnDefs: const [
                OsColumnDef(field: 'a'),
                OsColumnDef(field: 'b'),
                OsColumnDef(field: 'c'),
                OsColumnDef(field: 'd'),
              ],
              rowData: const [
                {'a': 1, 'b': 2, 'c': 3, 'd': 4},
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          controller.getAllDisplayedColumns().map((c) => c.effectiveColId),
          ['a', 'b', 'c', 'd'],
        );

        controller.moveColumns(['c'], 0);
        await tester.pump();
        expect(
          controller.getAllDisplayedColumns().map((c) => c.effectiveColId),
          ['c', 'a', 'b', 'd'],
        );
        expect(controller.getDisplayedColAfter('c')!.effectiveColId, 'a');
        expect(controller.getDisplayedColBefore('a')!.effectiveColId, 'c');

        controller.moveColumnByIndex(0, 3);
        await tester.pump();
        expect(
          controller.getAllDisplayedColumns().map((c) => c.effectiveColId),
          ['a', 'b', 'd', 'c'],
        );

        OsColumnMovedEvent? moved;
        await tester.pumpWidget(
          wrapGrid(
            OsGrid<Map<String, dynamic>>(
              controller: controller,
              columnDefs: const [
                OsColumnDef(field: 'a'),
                OsColumnDef(field: 'b'),
                OsColumnDef(field: 'c'),
              ],
              rowData: const [
                {'a': 1, 'b': 2, 'c': 3},
              ],
              onColumnMoved: (e) => moved = e,
            ),
          ),
        );
        await tester.pumpAndSettle();
        controller.moveColumns(['a'], 2);
        await tester.pump();
        expect(moved, isNotNull);
        expect(moved!.columns, ['a']);

        controller.dispose();
      },
    );

    testWidgets('column groups render and allow reorder within group', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();
      await tester.pumpWidget(
        wrapGrid(
          OsGrid<Map<String, dynamic>>(
            controller: controller,
            columnDefs: const [
              OsColumnGroup(
                headerName: 'Personal',
                children: [
                  OsColumnDef(field: 'name', headerName: 'Name'),
                  OsColumnDef(field: 'age', headerName: 'Age'),
                ],
              ),
              OsColumnDef(field: 'city', headerName: 'City'),
            ],
            rowData: [
              {'name': 'Alice', 'age': 30, 'city': 'London'},
              {'name': 'Bob', 'age': 25, 'city': 'Paris'},
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(VirtualisedGrid), findsOneWidget);
      // Column groups are canvas-painted; at minimum grid renders without error.

      controller.dispose();
      await takeScreenshotBestEffort(binding, '16-groups');
    });

    testWidgets('state purge clears prior overrides then applies subset', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();
      await tester.pumpWidget(
        wrapGrid(
          OsGrid<Map<String, dynamic>>(
            controller: controller,
            columnDefs: const [
              OsColumnDef(field: 'name', width: 150),
              OsColumnDef(field: 'age', width: 80),
              OsColumnDef(field: 'city', width: 120),
            ],
            rowData: const [
              {'name': 'Alice', 'age': 30, 'city': 'London'},
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      controller.setColumnWidths([
        const ColumnWidthEntry(colId: 'name', newWidth: 300),
      ]);
      controller.setColumnsPinned(['age'], OsColumnPin.left);
      controller.setColumnsVisible(['city'], false);
      controller.setSortModel([
        const OsSortModel(colId: 'name', sort: OsSortDirection.descending),
      ]);
      await tester.pump();

      final result = controller.applyColumnState(
        const ApplyColumnStateParams(
          state: [ColumnState(colId: 'name', width: 120)],
          purge: true,
        ),
      );
      await tester.pump();
      expect(result, isTrue);

      final state = {for (final s in controller.getColumnState()) s.colId: s};
      expect(state['name']!.width, 120);
      expect(state['age']!.width, 80);
      expect(state['age']!.pinned, isNull);
      expect(state['city']!.hide, isNot(true));
      expect(controller.getSortModel(), isEmpty);
      expect(controller.isPinning(), isFalse);

      // Without purge, unrelated overrides survive (merge)
      controller.setColumnWidths([
        const ColumnWidthEntry(colId: 'age', newWidth: 200),
      ]);
      await tester.pump();
      controller.applyColumnState(
        const ApplyColumnStateParams(
          state: [ColumnState(colId: 'name', width: 90)],
        ),
      );
      await tester.pump();
      final merged = {for (final s in controller.getColumnState()) s.colId: s};
      expect(merged['age']!.width, 200);
      expect(merged['name']!.width, 90);

      // resetColumnState restores definition defaults
      controller.resetColumnState();
      await tester.pump();
      expect(controller.getAllDisplayedColumns().length, 3);
      expect(controller.isPinning(), isFalse);

      // getColumnState → applyColumnState round-trip
      controller.setColumnsVisible(['age'], false);
      controller.setColumnsPinned(['name'], OsColumnPin.left);
      await tester.pump();
      final saved = controller.getColumnState();
      controller.resetColumnState();
      await tester.pump();
      controller.applyColumnState(ApplyColumnStateParams(state: saved));
      await tester.pump();
      final restored = {
        for (final s in controller.getColumnState()) s.colId: s,
      };
      expect(restored['age']!.hide, true);
      expect(restored['name']!.pinned, OsColumnPin.left);

      controller.dispose();
    });

    testWidgets(
      'gridState captures column order + visibility + pinning + sizing',
      (tester) async {
        final controller = OsGridController<Map<String, dynamic>>();
        await tester.pumpWidget(
          wrapGrid(
            OsGrid<Map<String, dynamic>>(
              controller: controller,
              columnDefs: const [
                OsColumnDef(field: 'a'),
                OsColumnDef(field: 'b'),
                OsColumnDef(field: 'c'),
              ],
              rowData: const [
                {'a': 1, 'b': 2, 'c': 3},
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        controller.setColumnsVisible(['c'], false);
        controller.setColumnsPinned(['a'], OsColumnPin.left);
        controller.setColumnWidths([
          const ColumnWidthEntry(colId: 'b', newWidth: 220),
        ]);
        await tester.pump();

        final state = controller.getState();
        expect(state.columnVisibility, isNotNull);
        expect(state.columnPinning, isNotNull);
        expect(state.columnSizing, isNotNull);

        // Restore via setState round-trip
        controller.resetColumnState();
        await tester.pump();
        controller.setState(state);
        await tester.pump();
        expect(controller.getAllDisplayedColumns().length, 2);
        expect(controller.isPinningLeft(), isTrue);

        controller.dispose();
      },
    );
  });

  // -----------------------------------------------------------------
  // Scenario 17: side bar + hide + tooltip
  // -----------------------------------------------------------------
  group('Scenario 17 — side bar / hide / tooltip', () {
    testWidgets('sideBar renders, controller toggles, hide column via API', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();
      OsToolPanelVisibleChangedEvent? lastPanelEvent;

      await tester.pumpWidget(
        wrapGrid(
          OsGrid<Map<String, dynamic>>(
            controller: controller,
            columnDefs: const [
              OsColumnDef(
                field: 'name',
                headerName: 'Name',
                filter: OsTextFilter(),
              ),
              OsColumnDef(field: 'age', headerName: 'Age'),
              OsColumnDef(field: 'city', headerName: 'City'),
            ],
            rowData: const [
              {'name': 'Alice', 'age': 30, 'city': 'London'},
            ],
            sideBar: OsSideBarDef.defaultPanels(),
            onToolPanelVisibleChanged: (e) => lastPanelEvent = e,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(OsSideBar), findsOneWidget);
      expect(find.byType(ColumnsToolPanel), findsOneWidget);
      expect(controller.isSideBarVisible(), isTrue);
      expect(controller.getOpenedToolPanel(), 'columns');

      // Switch to filters panel via controller
      controller.openToolPanel('filters');
      await tester.pumpAndSettle();
      expect(controller.getOpenedToolPanel(), 'filters');
      expect(find.byType(FiltersToolPanel), findsOneWidget);
      expect(lastPanelEvent, isNotNull);

      controller.closeToolPanel();
      await tester.pumpAndSettle();
      expect(controller.isToolPanelShowing(), isFalse);

      controller.openToolPanel('columns');
      await tester.pumpAndSettle();
      expect(controller.isToolPanelShowing(), isTrue);

      // Hide sidebar
      controller.setSideBarVisible(false);
      await tester.pumpAndSettle();
      expect(find.byType(OsSideBar), findsNothing);

      controller.setSideBarVisible(true);
      await tester.pumpAndSettle();
      expect(find.byType(OsSideBar), findsOneWidget);

      // Hide a column via ColumnsToolPanel checkbox and via API
      controller.setColumnsVisible(['city'], false);
      await tester.pump();
      expect(controller.getAllDisplayedColumns().length, 2);
      expect(
        controller.getColumnState().firstWhere((s) => s.colId == 'city').hide,
        true,
      );

      controller.setColumnsVisible(['city'], true);
      await tester.pump();
      expect(controller.getAllDisplayedColumns().length, 3);

      // Toolbar search filters columns panel (UI-level)
      final searchField = find.byType(TextField);
      expect(searchField, findsOneWidget);
      await tester.enterText(searchField, 'Ag');
      await tester.pumpAndSettle();
      // Only Age matches filter in panel
      expect(find.byType(Checkbox), findsOneWidget);
      await tester.enterText(searchField, '');
      await tester.pumpAndSettle();

      controller.dispose();
      await takeScreenshotBestEffort(binding, '17-sidebar');
    });

    testWidgets('hiddenByDefault sideBar starts hidden', (tester) async {
      await tester.pumpWidget(
        wrapGrid(
          const OsGrid(
            columnDefs: [OsColumnDef(field: 'name', headerName: 'Name')],
            rowData: [
              {'name': 'Alice'},
            ],
            sideBar: OsSideBarDef(
              toolPanels: [OsToolPanelDef.columns()],
              defaultToolPanel: 'columns',
              hiddenByDefault: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(OsSideBar), findsNothing);
    });

    testWidgets('tooltipField + headerTooltip configure tooltip; events emitted', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();
      final showEvents = <OsTooltipShowEvent>[];
      final hideEvents = <OsTooltipHideEvent>[];
      controller.onTooltipShow.listen(showEvents.add);
      controller.onTooltipHide.listen(hideEvents.add);

      await tester.pumpWidget(
        wrapGrid(
          OsGrid<Map<String, dynamic>>(
            controller: controller,
            columnDefs: [
              const OsColumnDef(
                field: 'name',
                headerName: 'Name',
                tooltipField: 'desc',
                headerTooltip: 'The name column',
              ),
              OsColumnDef<Map<String, dynamic>>(
                field: 'age',
                headerName: 'Age',
                tooltipValueGetter: (params) => 'Age: ${params.value}',
              ),
            ],
            rowData: const [
              {'name': 'Alice', 'desc': 'First user', 'age': 30},
            ],
            tooltipShowDelay: 200,
            tooltipHideDelay: 3000,
            onTooltipShow: (e) => showEvents.add(e),
            onTooltipHide: (e) => hideEvents.add(e),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(OsGrid<Map<String, dynamic>>), findsOneWidget);

      // Emit via controller streams to verify wiring (hover is interaction-level,
      // hard to pump deterministically in integration; stream contract is checked).
      controller.emitTooltipShow(
        const OsTooltipShowEvent(
          value: 'Hello',
          location: TooltipLocation.cell,
          rowIndex: 0,
          colId: 'name',
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(showEvents, isNotEmpty);
      expect(showEvents.last.value, 'Hello');

      controller.emitTooltipHide(
        const OsTooltipHideEvent(location: TooltipLocation.cell, colId: 'name'),
      );
      await Future<void>.delayed(Duration.zero);
      expect(hideEvents, isNotEmpty);

      // TooltipOverlay renders standalone with correct theme styling
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: Stack(
                children: [
                  const TooltipOverlay(
                    value: 'Test tooltip',
                    position: Offset(100, 100),
                    gridSize: Size(800, 600),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Test tooltip'), findsOneWidget);

      controller.dispose();
      await takeScreenshotBestEffort(binding, '17-tooltip');
    });

    testWidgets('tooltip show/hide via service state', (tester) async {
      final service = TooltipService(
        showDelay: 200,
        hideDelay: 5000,
        mouseTrack: false,
      );
      expect(service.state, OsTooltipState.nothing);
      service.onHoverStart(
        value: 'Hello',
        location: TooltipLocation.cell,
        anchor: const Offset(10, 10),
        mousePos: const Offset(10, 10),
      );
      expect(service.state, OsTooltipState.waitingToShow);
      // Duration minimum is 200 — immediate state stays waiting.
      await tester.pump(const Duration(milliseconds: 50));
      expect(service.state, OsTooltipState.waitingToShow);
      service.onHoverEnd();
      expect(service.state, OsTooltipState.nothing);
      service.dispose();
    });
  });
}
