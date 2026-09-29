@Tags(['golden'])
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

/// Golden coverage for the raster-cached paint primitives (quality program
/// v3 item 6): checkbox cells (checked/unchecked/indeterminate), header
/// select-all checkboxes, star ratings (0-5), and sparklines.
///
/// These goldens were generated BEFORE the raster caches landed and must
/// stay byte-stable afterwards: a cached `ui.Picture` blit must produce
/// pixels identical to direct path painting.
///
/// Regenerate only after an intentional visual change:
///
/// ```bash
/// flutter test --update-goldens test/goldens/raster_glyph_golden_test.dart
/// ```
void main() {
  final boundaryKey = GlobalKey();
  final theme = OsGridTheme.quartz();

  Future<void> pumpAndCapture(
    WidgetTester tester, {
    required String goldenName,
    required WidgetBuilder grid,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'FlutterTest'),
        home: Scaffold(
          body: RepaintBoundary(
            key: boundaryKey,
            child: SizedBox(
              width: 420,
              height: 300,
              child: Builder(builder: grid),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await expectLater(
      find.byKey(boundaryKey),
      matchesGoldenFile('goldens/$goldenName.png'),
    );
  }

  testWidgets('golden raster_checkbox_states', (tester) async {
    await pumpAndCapture(
      tester,
      goldenName: 'raster_checkbox_states',
      grid: (context) => OsGrid<Map<String, Object?>>(
        theme: theme,
        columnDefs: const [
          OsColumnDef<Map<String, Object?>>(
            field: 'done',
            headerName: 'Done',
            width: 90,
            checkboxSelection: true,
          ),
          OsColumnDef<Map<String, Object?>>(
            field: 'pending',
            headerName: 'Pending',
            width: 90,
            cellEditor: OsCheckboxCellEditor(),
          ),
          OsColumnDef<Map<String, Object?>>(
            field: 'name',
            headerName: 'Name',
            width: 140,
          ),
        ],
        rowData: [
          {'done': true, 'pending': true, 'name': 'Row 1'},
          {'done': false, 'pending': false, 'name': 'Row 2'},
          {'done': true, 'pending': null, 'name': 'Row 3'},
          {'done': false, 'pending': null, 'name': 'Row 4'},
          {'done': true, 'pending': true, 'name': 'Row 5'},
          {'done': false, 'pending': false, 'name': 'Row 6'},
        ],
      ),
    );
  });

  testWidgets('golden raster_star_ratings', (tester) async {
    await pumpAndCapture(
      tester,
      goldenName: 'raster_star_ratings',
      grid: (context) => OsGrid<Map<String, Object?>>(
        theme: theme,
        columnDefs: const [
          OsColumnDef<Map<String, Object?>>(
            field: 'rating',
            headerName: 'Rating',
            width: 160,
            builtInCellRenderer: OsBuiltInCellRenderer.starRating,
          ),
          OsColumnDef<Map<String, Object?>>(
            field: 'name',
            headerName: 'Name',
            width: 140,
          ),
        ],
        rowData: [
          {'rating': 0, 'name': 'Zero'},
          {'rating': 1, 'name': 'One'},
          {'rating': 2, 'name': 'Two'},
          {'rating': 3, 'name': 'Three'},
          {'rating': 4, 'name': 'Four'},
          {'rating': 5, 'name': 'Five'},
        ],
      ),
    );
  });

  testWidgets('golden raster_sparkline_types', (tester) async {
    await pumpAndCapture(
      tester,
      goldenName: 'raster_sparkline_types',
      grid: (context) => OsGrid<Map<String, Object?>>(
        theme: theme,
        columnDefs: const [
          OsColumnDef<Map<String, Object?>>(
            field: 'line',
            headerName: 'Line',
            width: 90,
            builtInCellRenderer: OsBuiltInCellRenderer.sparkline,
          ),
          OsColumnDef<Map<String, Object?>>(
            field: 'area',
            headerName: 'Area',
            width: 90,
            builtInCellRenderer: OsBuiltInCellRenderer.sparkline,
            sparklineOptions: OsSparklineOptions(type: OsSparklineType.area),
          ),
          OsColumnDef<Map<String, Object?>>(
            field: 'bar',
            headerName: 'Bar',
            width: 90,
            builtInCellRenderer: OsBuiltInCellRenderer.sparkline,
            sparklineOptions: OsSparklineOptions(type: OsSparklineType.bar),
          ),
          OsColumnDef<Map<String, Object?>>(
            field: 'name',
            headerName: 'Name',
            width: 140,
          ),
        ],
        rowData: [
          {
            'line': <num>[1, 3, 2, 5, 4],
            'area': <num>[5, 2, 4, 1, 3],
            'bar': <num>[-2, 3, -1, 4, 2],
            'name': 'Row 1',
          },
          {
            'line': <num>[2, 1, 4, 2, 5],
            'area': <num>[3, 5, 1, 4, 2],
            'bar': <num>[1, -3, 2, -2, 4],
            'name': 'Row 2',
          },
        ],
      ),
    );
  });
}
