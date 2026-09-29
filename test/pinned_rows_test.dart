import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:os_grid_flutter/os_grid_flutter.dart';

void main() {
  group('Pinned Rows', () {
    group('Widget parameters', () {
      testWidgets('accepts pinnedTopRowData', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 800,
                height: 600,
                child: OsGrid(
                  columnDefs: [
                    OsColumnDef(field: 'name', headerName: 'Name'),
                    OsColumnDef(field: 'value', headerName: 'Value'),
                  ],
                  rowData: [
                    {'name': 'Row 1', 'value': 100},
                    {'name': 'Row 2', 'value': 200},
                  ],
                  pinnedTopRowData: [
                    {'name': 'Total', 'value': 300},
                  ],
                ),
              ),
            ),
          ),
        );

        // Should render without error
        expect(find.byType(VirtualisedGrid), findsOneWidget);
      });

      testWidgets('accepts pinnedBottomRowData', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 800,
                height: 600,
                child: OsGrid(
                  columnDefs: [
                    OsColumnDef(field: 'name', headerName: 'Name'),
                    OsColumnDef(field: 'value', headerName: 'Value'),
                  ],
                  rowData: [
                    {'name': 'Row 1', 'value': 100},
                    {'name': 'Row 2', 'value': 200},
                  ],
                  pinnedBottomRowData: [
                    {'name': 'Summary', 'value': 300},
                  ],
                ),
              ),
            ),
          ),
        );

        expect(find.byType(VirtualisedGrid), findsOneWidget);
      });

      testWidgets('accepts both pinnedTopRowData and pinnedBottomRowData', (
        tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 800,
                height: 600,
                child: OsGrid(
                  columnDefs: [
                    OsColumnDef(field: 'name', headerName: 'Name'),
                    OsColumnDef(field: 'value', headerName: 'Value'),
                  ],
                  rowData: [
                    {'name': 'Row 1', 'value': 100},
                    {'name': 'Row 2', 'value': 200},
                  ],
                  pinnedTopRowData: [
                    {'name': 'Header Total', 'value': 300},
                  ],
                  pinnedBottomRowData: [
                    {'name': 'Footer Total', 'value': 300},
                  ],
                ),
              ),
            ),
          ),
        );

        expect(find.byType(VirtualisedGrid), findsOneWidget);
      });

      testWidgets('empty pinned data arrays render no pinned section', (
        tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 800,
                height: 600,
                child: OsGrid(
                  columnDefs: [OsColumnDef(field: 'name', headerName: 'Name')],
                  rowData: [
                    {'name': 'Row 1'},
                  ],
                  pinnedTopRowData: [],
                  pinnedBottomRowData: [],
                ),
              ),
            ),
          ),
        );

        expect(find.byType(VirtualisedGrid), findsOneWidget);
      });

      testWidgets('null pinned data renders no pinned section', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 800,
                height: 600,
                child: OsGrid(
                  columnDefs: [OsColumnDef(field: 'name', headerName: 'Name')],
                  rowData: [
                    {'name': 'Row 1'},
                  ],
                ),
              ),
            ),
          ),
        );

        expect(find.byType(VirtualisedGrid), findsOneWidget);
      });
    });

    group('Controller API', () {
      testWidgets('getPinnedTopRowCount returns correct count', (tester) async {
        final controller = OsGridController();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 800,
                height: 600,
                child: OsGrid(
                  controller: controller,
                  columnDefs: [
                    const OsColumnDef(field: 'name', headerName: 'Name'),
                  ],
                  rowData: [
                    {'name': 'Row 1'},
                  ],
                  pinnedTopRowData: [
                    {'name': 'Top 1'},
                    {'name': 'Top 2'},
                  ],
                ),
              ),
            ),
          ),
        );

        expect(controller.getPinnedTopRowCount(), 2);
      });

      testWidgets('getPinnedBottomRowCount returns correct count', (
        tester,
      ) async {
        final controller = OsGridController();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 800,
                height: 600,
                child: OsGrid(
                  controller: controller,
                  columnDefs: [
                    const OsColumnDef(field: 'name', headerName: 'Name'),
                  ],
                  rowData: [
                    {'name': 'Row 1'},
                  ],
                  pinnedBottomRowData: [
                    {'name': 'Bottom 1'},
                    {'name': 'Bottom 2'},
                    {'name': 'Bottom 3'},
                  ],
                ),
              ),
            ),
          ),
        );

        expect(controller.getPinnedBottomRowCount(), 3);
      });

      testWidgets('getPinnedTopRow returns data at index', (tester) async {
        final controller = OsGridController();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 800,
                height: 600,
                child: OsGrid(
                  controller: controller,
                  columnDefs: [
                    const OsColumnDef(field: 'name', headerName: 'Name'),
                  ],
                  rowData: [
                    {'name': 'Row 1'},
                  ],
                  pinnedTopRowData: [
                    {'name': 'Top 1'},
                    {'name': 'Top 2'},
                  ],
                ),
              ),
            ),
          ),
        );

        final row0 = controller.getPinnedTopRow(0) as Map<String, dynamic>;
        expect(row0['name'], 'Top 1');

        final row1 = controller.getPinnedTopRow(1) as Map<String, dynamic>;
        expect(row1['name'], 'Top 2');
      });

      testWidgets('getPinnedBottomRow returns data at index', (tester) async {
        final controller = OsGridController();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 800,
                height: 600,
                child: OsGrid(
                  controller: controller,
                  columnDefs: [
                    const OsColumnDef(field: 'name', headerName: 'Name'),
                  ],
                  rowData: [
                    {'name': 'Row 1'},
                  ],
                  pinnedBottomRowData: [
                    {'name': 'Bottom 1'},
                  ],
                ),
              ),
            ),
          ),
        );

        final row = controller.getPinnedBottomRow(0) as Map<String, dynamic>;
        expect(row['name'], 'Bottom 1');
      });

      testWidgets('getPinnedTopRow returns null for out-of-bounds index', (
        tester,
      ) async {
        final controller = OsGridController();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 800,
                height: 600,
                child: OsGrid(
                  controller: controller,
                  columnDefs: [
                    const OsColumnDef(field: 'name', headerName: 'Name'),
                  ],
                  rowData: [
                    {'name': 'Row 1'},
                  ],
                  pinnedTopRowData: [
                    {'name': 'Top 1'},
                  ],
                ),
              ),
            ),
          ),
        );

        expect(controller.getPinnedTopRow(-1), isNull);
        expect(controller.getPinnedTopRow(1), isNull);
        expect(controller.getPinnedTopRow(99), isNull);
      });

      testWidgets('getPinnedBottomRow returns null for out-of-bounds index', (
        tester,
      ) async {
        final controller = OsGridController();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 800,
                height: 600,
                child: OsGrid(
                  controller: controller,
                  columnDefs: [
                    const OsColumnDef(field: 'name', headerName: 'Name'),
                  ],
                  rowData: [
                    {'name': 'Row 1'},
                  ],
                  pinnedBottomRowData: [
                    {'name': 'Bottom 1'},
                  ],
                ),
              ),
            ),
          ),
        );

        expect(controller.getPinnedBottomRow(-1), isNull);
        expect(controller.getPinnedBottomRow(1), isNull);
      });

      testWidgets('counts are zero when no pinned data', (tester) async {
        final controller = OsGridController();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 800,
                height: 600,
                child: OsGrid(
                  controller: controller,
                  columnDefs: [
                    const OsColumnDef(field: 'name', headerName: 'Name'),
                  ],
                  rowData: [
                    {'name': 'Row 1'},
                  ],
                ),
              ),
            ),
          ),
        );

        expect(controller.getPinnedTopRowCount(), 0);
        expect(controller.getPinnedBottomRowCount(), 0);
      });
    });

    group('Pinned rows excluded from sort/filter', () {
      testWidgets('pinned rows are not affected by sorting', (tester) async {
        final controller = OsGridController();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 800,
                height: 600,
                child: OsGrid(
                  controller: controller,
                  columnDefs: [
                    const OsColumnDef(
                      field: 'name',
                      headerName: 'Name',
                      sortable: true,
                    ),
                    const OsColumnDef(field: 'value', headerName: 'Value'),
                  ],
                  rowData: [
                    {'name': 'Charlie', 'value': 3},
                    {'name': 'Alice', 'value': 1},
                    {'name': 'Bob', 'value': 2},
                  ],
                  pinnedTopRowData: [
                    {'name': 'Total', 'value': 6},
                  ],
                  pinnedBottomRowData: [
                    {'name': 'Average', 'value': 2},
                  ],
                  initialSort: [
                    const OsSortModel(
                      colId: 'name',
                      sort: OsSortDirection.ascending,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        // Pinned rows should remain unchanged regardless of sort
        final topRow = controller.getPinnedTopRow(0) as Map<String, dynamic>;
        expect(topRow['name'], 'Total');
        expect(topRow['value'], 6);

        final bottomRow =
            controller.getPinnedBottomRow(0) as Map<String, dynamic>;
        expect(bottomRow['name'], 'Average');
        expect(bottomRow['value'], 2);
      });

      testWidgets('pinned rows are not affected by quick filter', (
        tester,
      ) async {
        final controller = OsGridController();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 800,
                height: 600,
                child: OsGrid(
                  controller: controller,
                  columnDefs: [
                    const OsColumnDef(field: 'name', headerName: 'Name'),
                  ],
                  rowData: [
                    {'name': 'Alice'},
                    {'name': 'Bob'},
                    {'name': 'Charlie'},
                  ],
                  pinnedTopRowData: [
                    {'name': 'Total'},
                  ],
                  quickFilterText: 'Alice',
                ),
              ),
            ),
          ),
        );

        // Pinned rows should still be present regardless of filter
        expect(controller.getPinnedTopRowCount(), 1);
        final topRow = controller.getPinnedTopRow(0) as Map<String, dynamic>;
        expect(topRow['name'], 'Total');
      });
    });

    group('Events', () {
      testWidgets('pinnedRowDataChanged fires when pinned data changes', (
        tester,
      ) async {
        final controller = OsGridController();
        final events = <OsPinnedRowDataChangedEvent>[];

        controller.onPinnedRowDataChanged.listen(events.add);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 800,
                height: 600,
                child: OsGrid(
                  controller: controller,
                  columnDefs: [
                    const OsColumnDef(field: 'name', headerName: 'Name'),
                  ],
                  rowData: [
                    {'name': 'Row 1'},
                  ],
                  pinnedTopRowData: [
                    {'name': 'Top 1'},
                  ],
                ),
              ),
            ),
          ),
        );

        // Update pinned data
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 800,
                height: 600,
                child: OsGrid(
                  controller: controller,
                  columnDefs: [
                    const OsColumnDef(field: 'name', headerName: 'Name'),
                  ],
                  rowData: [
                    {'name': 'Row 1'},
                  ],
                  pinnedTopRowData: [
                    {'name': 'Top 1'},
                    {'name': 'Top 2'},
                  ],
                  pinnedBottomRowData: [
                    {'name': 'Bottom 1'},
                  ],
                ),
              ),
            ),
          ),
        );

        await tester.pump();

        expect(events, hasLength(1));
        expect(events.first.pinnedTopRowCount, 2);
        expect(events.first.pinnedBottomRowCount, 1);
      });

      testWidgets('onPinnedRowDataChanged widget callback fires', (
        tester,
      ) async {
        final events = <OsPinnedRowDataChangedEvent>[];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 800,
                height: 600,
                child: OsGrid(
                  columnDefs: [
                    const OsColumnDef(field: 'name', headerName: 'Name'),
                  ],
                  rowData: [
                    {'name': 'Row 1'},
                  ],
                  pinnedTopRowData: [
                    {'name': 'Top 1'},
                  ],
                  onPinnedRowDataChanged: events.add,
                ),
              ),
            ),
          ),
        );

        // Update pinned data
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 800,
                height: 600,
                child: OsGrid(
                  columnDefs: [
                    const OsColumnDef(field: 'name', headerName: 'Name'),
                  ],
                  rowData: [
                    {'name': 'Row 1'},
                  ],
                  pinnedTopRowData: [
                    {'name': 'Top 1'},
                    {'name': 'Top 2'},
                  ],
                  onPinnedRowDataChanged: events.add,
                ),
              ),
            ),
          ),
        );

        expect(events, hasLength(1));
        expect(events.first.pinnedTopRowCount, 2);
      });
    });

    group('Rendering', () {
      testWidgets('renders with many pinned rows', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 800,
                height: 600,
                child: OsGrid(
                  columnDefs: [
                    const OsColumnDef(field: 'name', headerName: 'Name'),
                    const OsColumnDef(field: 'value', headerName: 'Value'),
                  ],
                  rowData: List.generate(
                    100,
                    (i) => {'name': 'Row $i', 'value': i},
                  ),
                  pinnedTopRowData: [
                    {'name': 'Top 1', 'value': 'A'},
                    {'name': 'Top 2', 'value': 'B'},
                    {'name': 'Top 3', 'value': 'C'},
                  ],
                  pinnedBottomRowData: [
                    {'name': 'Bottom 1', 'value': 'X'},
                    {'name': 'Bottom 2', 'value': 'Y'},
                  ],
                ),
              ),
            ),
          ),
        );

        expect(find.byType(VirtualisedGrid), findsOneWidget);
      });

      testWidgets('renders with pinned columns and pinned rows', (
        tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 800,
                height: 600,
                child: OsGrid(
                  columnDefs: [
                    OsColumnDef(
                      field: 'id',
                      headerName: 'ID',
                      pinned: OsColumnPin.left,
                      width: 60,
                    ),
                    OsColumnDef(field: 'name', headerName: 'Name'),
                    OsColumnDef(field: 'value', headerName: 'Value'),
                    OsColumnDef(
                      field: 'status',
                      headerName: 'Status',
                      pinned: OsColumnPin.right,
                      width: 80,
                    ),
                  ],
                  rowData: [
                    {
                      'id': 1,
                      'name': 'Alice',
                      'value': 100,
                      'status': 'Active',
                    },
                    {
                      'id': 2,
                      'name': 'Bob',
                      'value': 200,
                      'status': 'Inactive',
                    },
                  ],
                  pinnedTopRowData: [
                    {'id': '-', 'name': 'Header', 'value': '-', 'status': '-'},
                  ],
                  pinnedBottomRowData: [
                    {'id': '-', 'name': 'Total', 'value': 300, 'status': '-'},
                  ],
                ),
              ),
            ),
          ),
        );

        expect(find.byType(VirtualisedGrid), findsOneWidget);
      });

      testWidgets('renders with value formatters on pinned rows', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 800,
                height: 600,
                child: OsGrid(
                  columnDefs: [
                    const OsColumnDef(field: 'name', headerName: 'Name'),
                    OsColumnDef(
                      field: 'value',
                      headerName: 'Value',
                      valueFormatter: (params) => '\$${params.value}',
                    ),
                  ],
                  rowData: [
                    {'name': 'Row 1', 'value': 100},
                  ],
                  pinnedTopRowData: [
                    {'name': 'Total', 'value': 100},
                  ],
                ),
              ),
            ),
          ),
        );

        expect(find.byType(VirtualisedGrid), findsOneWidget);
      });
    });

    group('Interaction with other features', () {
      testWidgets('works with pagination', (tester) async {
        final controller = OsGridController();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 800,
                height: 600,
                child: OsGrid(
                  controller: controller,
                  columnDefs: [
                    const OsColumnDef(field: 'name', headerName: 'Name'),
                  ],
                  rowData: List.generate(50, (i) => {'name': 'Row $i'}),
                  pinnedTopRowData: [
                    {'name': 'Total'},
                  ],
                  pinnedBottomRowData: [
                    {'name': 'Summary'},
                  ],
                  pagination: const OsPagination(pageSize: 10),
                ),
              ),
            ),
          ),
        );

        // Pinned rows should be present regardless of pagination
        expect(controller.getPinnedTopRowCount(), 1);
        expect(controller.getPinnedBottomRowCount(), 1);

        // Navigate to page 2
        controller.paginationGoToPage(1);
        await tester.pump();

        // Pinned rows should still be present
        expect(controller.getPinnedTopRowCount(), 1);
        expect(controller.getPinnedBottomRowCount(), 1);
      });

      testWidgets('works with row selection', (tester) async {
        final controller = OsGridController();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 800,
                height: 600,
                child: OsGrid(
                  controller: controller,
                  columnDefs: [
                    const OsColumnDef(field: 'name', headerName: 'Name'),
                  ],
                  rowData: [
                    {'name': 'Row 1'},
                    {'name': 'Row 2'},
                  ],
                  pinnedTopRowData: [
                    {'name': 'Total'},
                  ],
                  rowSelection: OsRowSelection.multiple(),
                ),
              ),
            ),
          ),
        );

        // Select all body rows
        controller.selectAll();
        await tester.pump();

        // Should select body rows (pinned rows are separate)
        expect(controller.getSelectedRows(), hasLength(2));
      });

      testWidgets('works with floating filter', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 800,
                height: 600,
                child: OsGrid(
                  columnDefs: [
                    OsColumnDef(
                      field: 'name',
                      headerName: 'Name',
                      filter: OsTextFilter(),
                    ),
                  ],
                  rowData: [
                    {'name': 'Alice'},
                    {'name': 'Bob'},
                  ],
                  pinnedTopRowData: [
                    {'name': 'Total'},
                  ],
                  floatingFilter: true,
                ),
              ),
            ),
          ),
        );

        expect(find.byType(VirtualisedGrid), findsOneWidget);
      });
    });

    group('Edge cases', () {
      testWidgets('handles pinned rows with missing column fields', (
        tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 800,
                height: 600,
                child: OsGrid(
                  columnDefs: [
                    OsColumnDef(field: 'name', headerName: 'Name'),
                    OsColumnDef(field: 'age', headerName: 'Age'),
                    OsColumnDef(field: 'email', headerName: 'Email'),
                  ],
                  rowData: [
                    {'name': 'Alice', 'age': 30, 'email': 'alice@example.com'},
                  ],
                  pinnedTopRowData: [
                    // Missing 'email' field — should render blank for that column
                    {'name': 'Total', 'age': 30},
                  ],
                ),
              ),
            ),
          ),
        );

        expect(find.byType(VirtualisedGrid), findsOneWidget);
      });

      testWidgets('handles updating pinned data to empty', (tester) async {
        final controller = OsGridController();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 800,
                height: 600,
                child: OsGrid(
                  controller: controller,
                  columnDefs: [
                    const OsColumnDef(field: 'name', headerName: 'Name'),
                  ],
                  rowData: [
                    {'name': 'Row 1'},
                  ],
                  pinnedTopRowData: [
                    {'name': 'Top 1'},
                  ],
                ),
              ),
            ),
          ),
        );

        expect(controller.getPinnedTopRowCount(), 1);

        // Update to empty
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 800,
                height: 600,
                child: OsGrid(
                  controller: controller,
                  columnDefs: [
                    const OsColumnDef(field: 'name', headerName: 'Name'),
                  ],
                  rowData: [
                    {'name': 'Row 1'},
                  ],
                  pinnedTopRowData: const [],
                ),
              ),
            ),
          ),
        );

        expect(controller.getPinnedTopRowCount(), 0);
      });

      testWidgets('handles large number of pinned rows', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 800,
                height: 600,
                child: OsGrid(
                  columnDefs: [
                    const OsColumnDef(field: 'name', headerName: 'Name'),
                  ],
                  rowData: List.generate(10, (i) => {'name': 'Row $i'}),
                  pinnedTopRowData: List.generate(5, (i) => {'name': 'Top $i'}),
                  pinnedBottomRowData: List.generate(
                    5,
                    (i) => {'name': 'Bottom $i'},
                  ),
                ),
              ),
            ),
          ),
        );

        expect(find.byType(VirtualisedGrid), findsOneWidget);
      });
    });
  });
}
