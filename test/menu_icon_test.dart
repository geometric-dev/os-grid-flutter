import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

void main() {
  group('Column menu icon (⋮) in header', () {
    testWidgets('renders without error on standard columns', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: OsGrid<Map<String, dynamic>>(
                columnDefs: [
                  OsColumnDef(field: 'name', headerName: 'Name', width: 200),
                  OsColumnDef(field: 'age', headerName: 'Age', width: 100),
                  OsColumnDef(
                    field: 'country',
                    headerName: 'Country',
                    width: 150,
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

    testWidgets('renders without error alongside filter icons', (tester) async {
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

    testWidgets('does not crash with checkbox selection column', (
      tester,
    ) async {
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
                  ),
                ],
                rowData: [
                  {'name': 'Alice'},
                  {'name': 'Bob'},
                ],
                rowSelection: OsRowSelection.multiple(checkboxes: true),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(VirtualisedGrid), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('does not crash with row number column', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: OsGrid<Map<String, dynamic>>(
                columnDefs: [
                  OsColumnDef(field: 'name', headerName: 'Name', width: 200),
                ],
                rowData: [
                  {'name': 'Alice'},
                  {'name': 'Bob'},
                ],
                rowNumbers: true,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(VirtualisedGrid), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders in narrow columns without overflow', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: OsGrid<Map<String, dynamic>>(
                columnDefs: [
                  // Very narrow column — text should be truncated, not overflow
                  OsColumnDef(
                    field: 'name',
                    headerName: 'Very Long Header Name',
                    width: 60,
                  ),
                  OsColumnDef(field: 'x', headerName: 'X', width: 40),
                ],
                rowData: [
                  {'name': 'Alice', 'x': 1},
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byType(VirtualisedGrid), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders with pinned columns', (tester) async {
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
                  ),
                  OsColumnDef(field: 'name', headerName: 'Name', width: 200),
                  OsColumnDef(
                    field: 'status',
                    headerName: 'Status',
                    width: 100,
                    pinned: OsColumnPin.right,
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

    testWidgets('renders with dark theme', (tester) async {
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
  });
}
