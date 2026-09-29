import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

void main() {
  group('RowHeightLayout', () {
    group('uniform', () {
      test('creates layout with uniform height', () {
        final layout = RowHeightLayout.uniform(rowCount: 5, rowHeight: 42.0);
        expect(layout.isUniform, isTrue);
        expect(layout.rowCount, 5);
        expect(layout.totalHeight, 210.0);
      });

      test('getRowHeight returns uniform height for all rows', () {
        final layout = RowHeightLayout.uniform(rowCount: 3, rowHeight: 50.0);
        expect(layout.getRowHeight(0), 50.0);
        expect(layout.getRowHeight(1), 50.0);
        expect(layout.getRowHeight(2), 50.0);
      });

      test('getRowTop returns correct offsets', () {
        final layout = RowHeightLayout.uniform(rowCount: 3, rowHeight: 42.0);
        expect(layout.getRowTop(0), 0.0);
        expect(layout.getRowTop(1), 42.0);
        expect(layout.getRowTop(2), 84.0);
      });

      test('getRowBottom returns correct offsets', () {
        final layout = RowHeightLayout.uniform(rowCount: 3, rowHeight: 42.0);
        expect(layout.getRowBottom(0), 42.0);
        expect(layout.getRowBottom(1), 84.0);
        expect(layout.getRowBottom(2), 126.0);
      });

      test('getRowIndexAtY finds correct row', () {
        final layout = RowHeightLayout.uniform(rowCount: 5, rowHeight: 42.0);
        expect(layout.getRowIndexAtY(0.0), 0);
        expect(layout.getRowIndexAtY(41.9), 0);
        expect(layout.getRowIndexAtY(42.0), 1);
        expect(layout.getRowIndexAtY(84.0), 2);
        expect(layout.getRowIndexAtY(209.9), 4);
      });

      test('getRowIndexAtY returns -1 for out-of-bounds', () {
        final layout = RowHeightLayout.uniform(rowCount: 3, rowHeight: 42.0);
        expect(layout.getRowIndexAtY(-1.0), -1);
        expect(layout.getRowIndexAtY(126.0), -1);
      });

      test('getFirstVisibleRow and getLastVisibleRow', () {
        final layout = RowHeightLayout.uniform(rowCount: 100, rowHeight: 42.0);
        expect(layout.getFirstVisibleRow(84.0), 2); // scrollY=84 → row 2
        expect(layout.getLastVisibleRow(84.0, 200.0), 6); // 84+200=284 → row 6
      });
    });

    group('variable', () {
      test('creates layout with variable heights', () {
        final layout = RowHeightLayout.variable(heights: [30.0, 50.0, 40.0]);
        expect(layout.isUniform, isFalse);
        expect(layout.rowCount, 3);
        expect(layout.totalHeight, 120.0);
      });

      test('getRowHeight returns per-row height', () {
        final layout = RowHeightLayout.variable(heights: [30.0, 50.0, 40.0]);
        expect(layout.getRowHeight(0), 30.0);
        expect(layout.getRowHeight(1), 50.0);
        expect(layout.getRowHeight(2), 40.0);
      });

      test('getRowTop returns cumulative offsets', () {
        final layout = RowHeightLayout.variable(heights: [30.0, 50.0, 40.0]);
        expect(layout.getRowTop(0), 0.0);
        expect(layout.getRowTop(1), 30.0);
        expect(layout.getRowTop(2), 80.0);
      });

      test('getRowBottom returns correct bottom edges', () {
        final layout = RowHeightLayout.variable(heights: [30.0, 50.0, 40.0]);
        expect(layout.getRowBottom(0), 30.0);
        expect(layout.getRowBottom(1), 80.0);
        expect(layout.getRowBottom(2), 120.0);
      });

      test('getRowIndexAtY uses binary search', () {
        final layout = RowHeightLayout.variable(
          heights: [30.0, 50.0, 40.0, 60.0, 20.0],
        );
        // Row 0: 0-30, Row 1: 30-80, Row 2: 80-120, Row 3: 120-180, Row 4: 180-200
        expect(layout.getRowIndexAtY(0.0), 0);
        expect(layout.getRowIndexAtY(29.9), 0);
        expect(layout.getRowIndexAtY(30.0), 1);
        expect(layout.getRowIndexAtY(79.9), 1);
        expect(layout.getRowIndexAtY(80.0), 2);
        expect(layout.getRowIndexAtY(119.9), 2);
        expect(layout.getRowIndexAtY(120.0), 3);
        expect(layout.getRowIndexAtY(179.9), 3);
        expect(layout.getRowIndexAtY(180.0), 4);
        expect(layout.getRowIndexAtY(199.9), 4);
      });

      test('getRowIndexAtY returns -1 for out-of-bounds', () {
        final layout = RowHeightLayout.variable(heights: [30.0, 50.0, 40.0]);
        expect(layout.getRowIndexAtY(-1.0), -1);
        expect(layout.getRowIndexAtY(120.0), -1);
      });

      test('getFirstVisibleRow with variable heights', () {
        final layout = RowHeightLayout.variable(
          heights: [30.0, 50.0, 40.0, 60.0, 20.0],
        );
        expect(layout.getFirstVisibleRow(0.0), 0);
        expect(layout.getFirstVisibleRow(30.0), 1);
        expect(layout.getFirstVisibleRow(80.0), 2);
      });

      test('getLastVisibleRow with variable heights', () {
        final layout = RowHeightLayout.variable(
          heights: [30.0, 50.0, 40.0, 60.0, 20.0],
        );
        // scrollY=0, viewport=100 → y=100 is in row 2 (80-120)
        expect(layout.getLastVisibleRow(0.0, 100.0), 2);
        // scrollY=30, viewport=100 → y=130 is in row 3 (120-180)
        expect(layout.getLastVisibleRow(30.0, 100.0), 3);
      });

      test('empty layout', () {
        final layout = RowHeightLayout.variable(heights: []);
        expect(layout.rowCount, 0);
        expect(layout.totalHeight, 0.0);
        expect(layout.getRowIndexAtY(0.0), -1);
      });

      test('single row', () {
        final layout = RowHeightLayout.variable(heights: [75.0]);
        expect(layout.rowCount, 1);
        expect(layout.totalHeight, 75.0);
        expect(layout.getRowTop(0), 0.0);
        expect(layout.getRowBottom(0), 75.0);
        expect(layout.getRowIndexAtY(50.0), 0);
      });
    });
  });

  group('AutoHeightCalculator', () {
    test('returns null when no variable height mechanism is active', () {
      final result = AutoHeightCalculator.computeLayout<Map<String, dynamic>>(
        rowData: [
          {'name': 'Alice'},
          {'name': 'Bob'},
        ],
        columns: [const OsColumnDef(field: 'name', headerName: 'Name')],
        defaultRowHeight: 42.0,
        columnWidths: {},
      );
      expect(result, isNull);
    });

    test('computes layout from getRowHeight callback', () {
      final result = AutoHeightCalculator.computeLayout<Map<String, dynamic>>(
        rowData: [
          {'name': 'Alice', 'expanded': true},
          {'name': 'Bob', 'expanded': false},
          {'name': 'Charlie', 'expanded': true},
        ],
        columns: [const OsColumnDef(field: 'name', headerName: 'Name')],
        defaultRowHeight: 42.0,
        columnWidths: {},
        getRowHeight: (params) {
          final data = params.data;
          return data['expanded'] == true ? 84.0 : null;
        },
      );
      expect(result, isNotNull);
      expect(result!.getRowHeight(0), 84.0); // expanded
      expect(result.getRowHeight(1), 42.0); // default
      expect(result.getRowHeight(2), 84.0); // expanded
    });

    test('returns null when getRowHeight always returns null', () {
      final result = AutoHeightCalculator.computeLayout<Map<String, dynamic>>(
        rowData: [
          {'name': 'Alice'},
          {'name': 'Bob'},
        ],
        columns: [const OsColumnDef(field: 'name', headerName: 'Name')],
        defaultRowHeight: 42.0,
        columnWidths: {},
        getRowHeight: (params) => null,
      );
      expect(result, isNull);
    });

    test('computes layout from autoHeight columns', () {
      final result = AutoHeightCalculator.computeLayout<Map<String, dynamic>>(
        rowData: [
          {'desc': 'Short'},
          {
            'desc':
                'This is a much longer description that should wrap to multiple lines when the column is narrow',
          },
          {'desc': 'Medium length text here'},
        ],
        columns: [
          const OsColumnDef(
            field: 'desc',
            headerName: 'Description',
            autoHeight: true,
            wrapText: true,
            width: 100.0,
          ),
        ],
        defaultRowHeight: 42.0,
        columnWidths: {},
      );
      expect(result, isNotNull);
      // Row 0 should be default height (short text fits in one line)
      // Row 1 should be taller (long text wraps)
      expect(result!.getRowHeight(0), 42.0);
      expect(result.getRowHeight(1), greaterThan(42.0));
    });

    test('uses max height across multiple autoHeight columns', () {
      final result = AutoHeightCalculator.computeLayout<Map<String, dynamic>>(
        rowData: [
          {
            'col1': 'Short',
            'col2':
                'This is a very long text that will definitely wrap to multiple lines in a narrow column',
          },
        ],
        columns: [
          const OsColumnDef(
            field: 'col1',
            headerName: 'Col 1',
            autoHeight: true,
            wrapText: true,
            width: 100.0,
          ),
          const OsColumnDef(
            field: 'col2',
            headerName: 'Col 2',
            autoHeight: true,
            wrapText: true,
            width: 80.0,
          ),
        ],
        defaultRowHeight: 42.0,
        columnWidths: {},
      );
      expect(result, isNotNull);
      // Height should be determined by the taller column (col2)
      expect(result!.getRowHeight(0), greaterThan(42.0));
    });

    test('getRowHeight callback takes precedence over autoHeight', () {
      final result = AutoHeightCalculator.computeLayout<Map<String, dynamic>>(
        rowData: [
          {'desc': 'This is a very long text that would normally wrap'},
        ],
        columns: [
          const OsColumnDef(
            field: 'desc',
            headerName: 'Description',
            autoHeight: true,
            wrapText: true,
            width: 50.0,
          ),
        ],
        defaultRowHeight: 42.0,
        columnWidths: {},
        getRowHeight: (params) => 60.0, // Fixed height overrides auto
      );
      expect(result, isNotNull);
      expect(result!.getRowHeight(0), 60.0);
    });

    test('respects columnWidths override', () {
      // With a very narrow column, text should wrap more
      final narrowResult = AutoHeightCalculator.computeLayout<Map<String, dynamic>>(
        rowData: [
          {
            'desc':
                'This text should wrap differently based on column width setting',
          },
        ],
        columns: [
          const OsColumnDef(
            field: 'desc',
            headerName: 'Description',
            autoHeight: true,
            wrapText: true,
            width: 200.0, // Default width
          ),
        ],
        defaultRowHeight: 42.0,
        columnWidths: {0: 60.0}, // Override to narrow
      );

      final wideResult = AutoHeightCalculator.computeLayout<Map<String, dynamic>>(
        rowData: [
          {
            'desc':
                'This text should wrap differently based on column width setting',
          },
        ],
        columns: [
          const OsColumnDef(
            field: 'desc',
            headerName: 'Description',
            autoHeight: true,
            wrapText: true,
            width: 200.0,
          ),
        ],
        defaultRowHeight: 42.0,
        columnWidths: {0: 400.0}, // Override to wide
      );

      // Narrow column should produce taller rows
      if (narrowResult != null && wideResult != null) {
        expect(
          narrowResult.getRowHeight(0),
          greaterThanOrEqualTo(wideResult.getRowHeight(0)),
        );
      }
    });
  });

  group('OsColumnDef autoHeight/wrapText properties', () {
    test('autoHeight defaults to false', () {
      const col = OsColumnDef(field: 'test');
      expect(col.autoHeight, isFalse);
    });

    test('wrapText defaults to false', () {
      const col = OsColumnDef(field: 'test');
      expect(col.wrapText, isFalse);
    });

    test('autoHeight can be set to true', () {
      const col = OsColumnDef(field: 'test', autoHeight: true);
      expect(col.autoHeight, isTrue);
    });

    test('wrapText can be set to true', () {
      const col = OsColumnDef(field: 'test', wrapText: true);
      expect(col.wrapText, isTrue);
    });
  });

  group('OsRowAutoHeightModule', () {
    test('has correct module name', () {
      const module = OsRowAutoHeightModule();
      expect(module.moduleName, 'RowAutoHeight');
    });

    test('has version', () {
      const module = OsRowAutoHeightModule();
      expect(module.version, isNotEmpty);
    });

    test('has no dependencies', () {
      const module = OsRowAutoHeightModule();
      expect(module.dependsOn, isEmpty);
    });
  });

  group('OsGrid with getRowHeight', () {
    testWidgets('renders with variable row heights', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 300,
              child: OsGrid<Map<String, dynamic>>(
                columnDefs: [
                  const OsColumnDef(
                    field: 'name',
                    headerName: 'Name',
                    width: 200.0,
                  ),
                ],
                rowData: [
                  {'name': 'Alice'},
                  {'name': 'Bob'},
                  {'name': 'Charlie'},
                ],
                getRowHeight: (params) {
                  return params.rowIndex == 1 ? 80.0 : null;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Grid should render without errors
      expect(find.byType(OsGrid<Map<String, dynamic>>), findsOneWidget);
    });

    testWidgets('renders with autoHeight columns', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 300,
              child: OsGrid<Map<String, dynamic>>(
                columnDefs: [
                  OsColumnDef(
                    field: 'desc',
                    headerName: 'Description',
                    autoHeight: true,
                    wrapText: true,
                    width: 100.0,
                  ),
                ],
                rowData: [
                  {'desc': 'Short'},
                  {
                    'desc':
                        'This is a much longer description that should wrap to multiple lines',
                  },
                  {'desc': 'Medium'},
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Grid should render without errors
      expect(find.byType(OsGrid<Map<String, dynamic>>), findsOneWidget);
    });

    testWidgets('works with sorting and variable heights', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 400,
              child: OsGrid<Map<String, dynamic>>(
                controller: controller,
                columnDefs: [
                  const OsColumnDef(
                    field: 'name',
                    headerName: 'Name',
                    sortable: true,
                    width: 200.0,
                  ),
                ],
                rowData: [
                  {'name': 'Charlie'},
                  {'name': 'Alice'},
                  {'name': 'Bob'},
                ],
                getRowHeight: (params) {
                  final name = (params.data)['name'];
                  return name == 'Alice' ? 80.0 : 42.0;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Grid should render without errors
      expect(find.byType(OsGrid<Map<String, dynamic>>), findsOneWidget);
    });

    testWidgets('works with pagination and variable heights', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 400,
              child: OsGrid<Map<String, dynamic>>(
                columnDefs: [
                  const OsColumnDef(
                    field: 'name',
                    headerName: 'Name',
                    width: 200.0,
                  ),
                ],
                rowData: List.generate(20, (i) => {'name': 'Row $i'}),
                pagination: const OsPagination(pageSize: 5),
                getRowHeight: (params) {
                  return params.rowIndex.isEven ? 60.0 : 42.0;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Grid should render without errors
      expect(find.byType(OsGrid<Map<String, dynamic>>), findsOneWidget);
    });

    testWidgets('works with pinned columns and variable heights', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              height: 400,
              child: OsGrid<Map<String, dynamic>>(
                columnDefs: [
                  const OsColumnDef(
                    field: 'id',
                    headerName: 'ID',
                    width: 80.0,
                    pinned: OsColumnPin.left,
                  ),
                  const OsColumnDef(
                    field: 'name',
                    headerName: 'Name',
                    width: 200.0,
                  ),
                  const OsColumnDef(
                    field: 'status',
                    headerName: 'Status',
                    width: 100.0,
                    pinned: OsColumnPin.right,
                  ),
                ],
                rowData: [
                  {'id': '1', 'name': 'Alice', 'status': 'Active'},
                  {'id': '2', 'name': 'Bob', 'status': 'Inactive'},
                  {'id': '3', 'name': 'Charlie', 'status': 'Active'},
                ],
                getRowHeight: (params) {
                  return params.rowIndex == 0 ? 70.0 : 42.0;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Grid should render without errors
      expect(find.byType(OsGrid<Map<String, dynamic>>), findsOneWidget);
    });
  });
}
