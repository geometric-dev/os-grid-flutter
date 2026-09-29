@Tags(['golden'])

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

/// Goldens for interactive widget-level states (quality program: visual
/// testing gaps).
///
/// The main matrix in grid_golden_test.dart covers painter content only;
/// these six scenarios capture widget-level UI that lives in the grid's
/// Stack above the canvas (cell editor, body overlays) or canvas features
/// driven by interaction state (fill handle, per-column checkboxes,
/// tooltips):
///
/// - `quartz_editor_active` — a double-tapped editable cell with the
///   default TextField editor open.
/// - `quartz_fill_handle` — cellSelection active with a range whose end
///   corner renders the 8x8 fill handle.
/// - `quartz_loading_overlay` — `loading: true` with the default overlay
///   panel above the rows.
/// - `quartz_no_rows_overlay` — empty rowData with the default overlay
///   panel.
/// - `quartz_tooltip_visible` — a mouse hover held past `tooltipShowDelay`
///   with the TooltipOverlay visible.
/// - `quartz_checkbox_column` — per-column `checkboxSelection` with
///   in-canvas selection checkboxes (header + body).
///
/// Quartz theme only, to bound the golden count: these states paint with
/// theme-independent widget chrome plus theme tokens already locked by the
/// main matrix.
///
/// Determinism: the cell editor's cursor blink and the tooltip timers are
/// driven by the fake test clock, and every capture uses a fixed pump
/// schedule (no pumpAndSettle after interaction), so repeated runs are
/// byte-stable.
///
/// Regenerate after an intentional visual change:
///
/// ```bash
/// flutter test --update-goldens test/goldens/interactive_golden_test.dart
/// ```
void main() {
  final boundaryKey = GlobalKey();

  final rows = List<Map<String, Object>>.generate(6, (i) {
    return {
      'name': 'Item ${i + 1}',
      'value': (i * 137) % 500,
      'description': 'Tooltip for row ${i + 1}',
    };
  });

  Widget wrap(Widget grid) => MaterialApp(
    theme: ThemeData(fontFamily: 'FlutterTest'),
    home: Scaffold(
      body: RepaintBoundary(
        key: boundaryKey,
        child: SizedBox(width: 420, height: 300, child: grid),
      ),
    ),
  );

  RenderBox gridBox(WidgetTester tester) =>
      tester.renderObject<RenderBox>(find.byType(VirtualisedGrid));

  testWidgets('golden quartz_editor_active', (tester) async {
    await tester.pumpWidget(
      wrap(
        OsGrid<Map<String, Object>>(
          theme: OsGridTheme.quartz(),
          columnDefs: const [
            OsColumnDef<Map<String, Object>>(
              field: 'name',
              headerName: 'Name',
              width: 140,
            ),
            OsColumnDef<Map<String, Object>>(
              field: 'value',
              headerName: 'Value',
              width: 110,
              editable: true,
            ),
          ],
          rowData: rows,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Double-tap the first data cell of the editable value column
    // (x = 140 + 55, y = header 48 + rowHeight/2 = 69). Both taps land
    // inside the double-tap window.
    final cell = gridBox(tester).localToGlobal(const Offset(195, 69));
    await tester.tapAt(cell);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(cell);
    await tester.pump(const Duration(milliseconds: 50));
    // Well inside the cursor's first blink half-period: solid cursor.
    await tester.pump(const Duration(milliseconds: 100));

    // Sanity guard: a broken editor must fail loudly, not silently emit a
    // golden without the TextField.
    expect(find.byType(TextField), findsOneWidget);

    await expectLater(
      find.byKey(boundaryKey),
      matchesGoldenFile('goldens/quartz_editor_active.png'),
    );
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets('golden quartz_fill_handle', (tester) async {
    final controller = OsGridController<Map<String, Object>>();

    await tester.pumpWidget(
      wrap(
        OsGrid<Map<String, Object>>(
          controller: controller,
          theme: OsGridTheme.quartz(),
          columnDefs: const [
            OsColumnDef<Map<String, Object>>(
              field: 'name',
              headerName: 'Name',
              width: 140,
            ),
            OsColumnDef<Map<String, Object>>(
              field: 'value',
              headerName: 'Value',
              width: 110,
              editable: true,
            ),
          ],
          rowData: rows,
          cellSelection: const OsCellSelection(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    controller.addCellRange(
      const CellRangeParams(
        rowStartIndex: 0,
        rowEndIndex: 2,
        columnStartIndex: 1,
        columnEndIndex: 1,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await expectLater(
      find.byKey(boundaryKey),
      matchesGoldenFile('goldens/quartz_fill_handle.png'),
    );
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets('golden quartz_loading_overlay', (tester) async {
    await tester.pumpWidget(
      wrap(
        OsGrid<Map<String, Object>>(
          theme: OsGridTheme.quartz(),
          columnDefs: const [
            OsColumnDef<Map<String, Object>>(
              field: 'name',
              headerName: 'Name',
              width: 140,
            ),
            OsColumnDef<Map<String, Object>>(
              field: 'value',
              headerName: 'Value',
              width: 110,
            ),
          ],
          rowData: rows,
          loading: true,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Sanity guard: the default "Loading..." panel must be up.
    expect(find.text('Loading...'), findsOneWidget);

    await expectLater(
      find.byKey(boundaryKey),
      matchesGoldenFile('goldens/quartz_loading_overlay.png'),
    );
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets('golden quartz_no_rows_overlay', (tester) async {
    await tester.pumpWidget(
      wrap(
        OsGrid<Map<String, Object>>(
          theme: OsGridTheme.quartz(),
          columnDefs: const [
            OsColumnDef<Map<String, Object>>(
              field: 'name',
              headerName: 'Name',
              width: 140,
            ),
            OsColumnDef<Map<String, Object>>(
              field: 'value',
              headerName: 'Value',
              width: 110,
            ),
          ],
          rowData: const [],
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Sanity guard: the default "No Rows To Show" panel must be up.
    expect(find.text('No Rows To Show'), findsOneWidget);

    await expectLater(
      find.byKey(boundaryKey),
      matchesGoldenFile('goldens/quartz_no_rows_overlay.png'),
    );
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets('golden quartz_tooltip_visible', (tester) async {
    await tester.pumpWidget(
      wrap(
        OsGrid<Map<String, Object>>(
          theme: OsGridTheme.quartz(),
          columnDefs: const [
            OsColumnDef<Map<String, Object>>(
              field: 'name',
              headerName: 'Name',
              width: 140,
              tooltipField: 'description',
            ),
            OsColumnDef<Map<String, Object>>(
              field: 'value',
              headerName: 'Value',
              width: 110,
            ),
          ],
          rowData: rows,
          // Short delay so the show timer lands inside the fixed pump
          // schedule.
          tooltipShowDelay: 200,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Mouse hover onto the first data cell (header 48 + rowHeight/2 = 69).
    final gesture = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
      pointer: 7,
    );
    await gesture.addPointer(
      location: gridBox(tester).localToGlobal(Offset.zero),
    );
    addTearDown(gesture.removePointer);
    await tester.pump();
    await gesture.moveTo(gridBox(tester).localToGlobal(const Offset(70, 69)));
    await tester.pump();
    // Advance past the 200 ms show delay — the tooltip is up and its
    // auto-hide (10 s) is far beyond the capture.
    await tester.pump(const Duration(milliseconds: 300));

    // Sanity guard: the tooltip text is rendered above the canvas.
    expect(find.text('Tooltip for row 1'), findsOneWidget);

    await expectLater(
      find.byKey(boundaryKey),
      matchesGoldenFile('goldens/quartz_tooltip_visible.png'),
    );
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets('golden quartz_checkbox_column', (tester) async {
    await tester.pumpWidget(
      wrap(
        OsGrid<Map<String, Object>>(
          theme: OsGridTheme.quartz(),
          columnDefs: const [
            OsColumnDef<Map<String, Object>>(
              field: 'select',
              headerName: '',
              width: 60,
              checkboxSelection: true,
              headerCheckboxSelection: true,
            ),
            OsColumnDef<Map<String, Object>>(
              field: 'name',
              headerName: 'Name',
              width: 140,
            ),
            OsColumnDef<Map<String, Object>>(
              field: 'value',
              headerName: 'Value',
              width: 110,
            ),
          ],
          rowData: rows,
          rowSelection: OsRowSelection.multiple(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await expectLater(
      find.byKey(boundaryKey),
      matchesGoldenFile('goldens/quartz_checkbox_column.png'),
    );
  }, timeout: const Timeout(Duration(minutes: 2)));
}
