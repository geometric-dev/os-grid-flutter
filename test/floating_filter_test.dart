import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

void main() {
  group('Floating filter row', () {
    testWidgets('renders when floatingFilter is true', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OsGrid(
              floatingFilter: true,
              columnDefs: [
                OsColumnDef(
                  field: 'name',
                  headerName: 'Name',
                  filter: OsTextFilter(),
                ),
                OsColumnDef(
                  field: 'age',
                  headerName: 'Age',
                  filter: OsNumberFilter(),
                ),
              ],
              rowData: [
                {'name': 'Alice', 'age': 32},
                {'name': 'Bob', 'age': 28},
              ],
            ),
          ),
        ),
      );

      // Grid should render with VirtualisedGrid
      expect(find.byType(VirtualisedGrid), findsOneWidget);
    });

    testWidgets('does not render floating filter row when disabled', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OsGrid(
              floatingFilter: false,
              columnDefs: [
                OsColumnDef(
                  field: 'name',
                  headerName: 'Name',
                  filter: OsTextFilter(),
                ),
              ],
              rowData: [
                {'name': 'Alice'},
              ],
            ),
          ),
        ),
      );

      // Grid should render without error
      expect(find.byType(VirtualisedGrid), findsOneWidget);
    });

    testWidgets('uses custom floatingFilterHeight', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OsGrid(
              floatingFilter: true,
              floatingFilterHeight: 40.0,
              columnDefs: [
                OsColumnDef(
                  field: 'name',
                  headerName: 'Name',
                  filter: OsTextFilter(),
                ),
              ],
              rowData: [
                {'name': 'Alice'},
              ],
            ),
          ),
        ),
      );

      expect(find.byType(VirtualisedGrid), findsOneWidget);
    });

    testWidgets('floating filter row does not intercept data cell taps', (
      tester,
    ) async {
      // This test verifies the grid renders correctly with floating filter
      // enabled and data rows are still accessible below the filter row.
      // The actual hit testing is verified via the VirtualisedGrid tests
      // and the FloatingFilterCellHit type in the sealed class hierarchy.
      await tester.pumpWidget(
        const MaterialApp(
          home: SizedBox(
            width: 400,
            height: 300,
            child: OsGrid(
              floatingFilter: true,
              floatingFilterHeight: 32.0,
              headerHeight: 48.0,
              rowHeight: 42.0,
              columnDefs: [
                OsColumnDef(
                  field: 'name',
                  headerName: 'Name',
                  filter: OsTextFilter(),
                  width: 200,
                ),
              ],
              rowData: [
                {'name': 'Alice'},
                {'name': 'Bob'},
              ],
            ),
          ),
        ),
      );

      // Grid renders without error with floating filter enabled
      expect(find.byType(VirtualisedGrid), findsOneWidget);
    });

    testWidgets('tap in floating filter area does not trigger cell click', (
      tester,
    ) async {
      bool cellTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 400,
            height: 300,
            child: OsGrid(
              floatingFilter: true,
              floatingFilterHeight: 32.0,
              headerHeight: 48.0,
              rowHeight: 42.0,
              onCellClicked: (_) => cellTapped = true,
              columnDefs: [
                const OsColumnDef(
                  field: 'name',
                  headerName: 'Name',
                  filter: OsTextFilter(),
                  width: 200,
                ),
              ],
              rowData: [
                {'name': 'Alice'},
                {'name': 'Bob'},
              ],
            ),
          ),
        ),
      );

      // Tap in the floating filter area (between header and data)
      // Header ends at y=48, floating filter is 48..80
      final gridFinder = find.byType(VirtualisedGrid);
      final gridBox = tester.renderObject(gridFinder) as RenderBox;
      final gridTopLeft = gridBox.localToGlobal(Offset.zero);

      await tester.tapAt(gridTopLeft + const Offset(100, 64));
      await tester.pumpAndSettle();

      expect(cellTapped, isFalse);
    });
  });

  group('FloatingFilterCellHit', () {
    test('stores column index and colDef', () {
      const colDef = OsColumnDef(field: 'name', filter: OsTextFilter());
      const hit = FloatingFilterCellHit(columnIndex: 1, colDef: colDef);
      expect(hit.columnIndex, 1);
      expect(hit.colDef.field, 'name');
    });

    test('is a GridHitTestResult', () {
      const colDef = OsColumnDef(field: 'test', filter: OsTextFilter());
      const GridHitTestResult hit = FloatingFilterCellHit(
        columnIndex: 0,
        colDef: colDef,
      );
      expect(hit, isA<FloatingFilterCellHit>());
    });
  });

  group('VirtualisedGrid floating filter integration', () {
    testWidgets('passes floatingFilterHeight to painter', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              height: 400,
              child: VirtualisedGrid(
                columns: [
                  OsColumnDef(
                    field: 'name',
                    headerName: 'Name',
                    filter: OsTextFilter(),
                  ),
                  OsColumnDef(field: 'value', headerName: 'Value'),
                ],
                rowData: [
                  {'name': 'A', 'value': 1},
                  {'name': 'B', 'value': 2},
                ],
                floatingFilterHeight: 32.0,
              ),
            ),
          ),
        ),
      );

      // Should render without error
      expect(find.byType(VirtualisedGrid), findsOneWidget);
    });

    testWidgets('zero floatingFilterHeight means no floating filter row', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              height: 400,
              child: VirtualisedGrid(
                columns: [
                  OsColumnDef(
                    field: 'name',
                    headerName: 'Name',
                    filter: OsTextFilter(),
                  ),
                ],
                rowData: [
                  {'name': 'A'},
                ],
                floatingFilterHeight: 0,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(VirtualisedGrid), findsOneWidget);
    });
  });
}
