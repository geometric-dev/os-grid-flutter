import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

void main() {
  group('Filter icon in column header', () {
    testWidgets('renders without error when columns have filters', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: OsGrid<Map<String, dynamic>>(
                columnDefs: [
                  OsColumnDef(
                    field: 'name',
                    headerName: 'Name',
                    width: 200,
                    filter: OsTextFilter(),
                  ),
                  OsColumnDef(
                    field: 'age',
                    headerName: 'Age',
                    width: 100,
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
        ),
      );

      expect(find.byType(VirtualisedGrid), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders without error when some columns have no filter', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: OsGrid<Map<String, dynamic>>(
                columnDefs: [
                  OsColumnDef(
                    field: 'name',
                    headerName: 'Name',
                    width: 200,
                    filter: OsTextFilter(),
                  ),
                  OsColumnDef(
                    field: 'age',
                    headerName: 'Age',
                    width: 100,
                    // No filter — should not show icon
                  ),
                  OsColumnDef(
                    field: 'country',
                    headerName: 'Country',
                    width: 150,
                    filter: OsTextFilter(),
                  ),
                ],
                rowData: [
                  {'name': 'Alice', 'age': 32, 'country': 'UK'},
                  {'name': 'Bob', 'age': 28, 'country': 'US'},
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byType(VirtualisedGrid), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders with filter icon and sort indicator together', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: OsGrid<Map<String, dynamic>>(
                columnDefs: [
                  OsColumnDef(
                    field: 'name',
                    headerName: 'Name',
                    width: 200,
                    sortable: true,
                    filter: OsTextFilter(),
                  ),
                  OsColumnDef(
                    field: 'age',
                    headerName: 'Age',
                    width: 100,
                    sortable: true,
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
        ),
      );

      // Tap the 'Name' header to activate sort (which shows sort indicator)
      // The header is at the top of the grid
      await tester.tapAt(const Offset(100, 22));
      await tester.pumpAndSettle();

      expect(find.byType(VirtualisedGrid), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders with filter icon in narrow columns without overflow', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: OsGrid<Map<String, dynamic>>(
                columnDefs: [
                  OsColumnDef(
                    field: 'name',
                    headerName: 'Very Long Column Header Name',
                    width: 80, // Narrow column — text should ellipsis
                    filter: OsTextFilter(),
                  ),
                  OsColumnDef(
                    field: 'age',
                    headerName: 'Age',
                    width: 50, // Very narrow
                    filter: OsNumberFilter(),
                  ),
                ],
                rowData: [
                  {'name': 'Alice', 'age': 32},
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byType(VirtualisedGrid), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders with filter icon and custom theme', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: OsGrid<Map<String, dynamic>>(
                columnDefs: [
                  const OsColumnDef(
                    field: 'name',
                    headerName: 'Name',
                    width: 200,
                    filter: OsTextFilter(),
                  ),
                ],
                rowData: [
                  {'name': 'Alice'},
                ],
                theme: OsGridTheme.quartzDark(),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(VirtualisedGrid), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders with filter icon on pinned columns', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: OsGrid<Map<String, dynamic>>(
                columnDefs: [
                  OsColumnDef(
                    field: 'id',
                    headerName: 'ID',
                    width: 80,
                    pinned: OsColumnPin.left,
                    filter: OsNumberFilter(),
                  ),
                  OsColumnDef(
                    field: 'name',
                    headerName: 'Name',
                    width: 200,
                    filter: OsTextFilter(),
                  ),
                  OsColumnDef(
                    field: 'status',
                    headerName: 'Status',
                    width: 100,
                    pinned: OsColumnPin.right,
                    filter: OsTextFilter(),
                  ),
                ],
                rowData: [
                  {'id': 1, 'name': 'Alice', 'status': 'Active'},
                  {'id': 2, 'name': 'Bob', 'status': 'Inactive'},
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byType(VirtualisedGrid), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
