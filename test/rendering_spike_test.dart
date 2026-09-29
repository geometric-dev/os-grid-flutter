import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

void main() {
  group('VirtualisedGrid rendering spike', () {
    testWidgets('renders with 10 rows without error', (tester) async {
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
                  const OsColumnDef(
                    field: 'age',
                    headerName: 'Age',
                    width: 100,
                  ),
                  const OsColumnDef(
                    field: 'country',
                    headerName: 'Country',
                    width: 150,
                  ),
                ],
                rowData: List.generate(
                  10,
                  (i) => {
                    'name': 'Person $i',
                    'age': 20 + i,
                    'country': 'Country ${i % 5}',
                  },
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(VirtualisedGrid), findsOneWidget);
      // The grid should have rendered without throwing
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders with 100,000 rows without error', (tester) async {
      // This test validates that creating the widget with 100k rows
      // doesn't crash or take excessive time. The virtualisation means
      // only visible rows are painted.
      final rowData = List.generate(
        100000,
        (i) => {'id': i, 'name': 'Person $i', 'value': i * 1.5},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: OsGrid<Map<String, dynamic>>(
                columnDefs: [
                  const OsColumnDef(field: 'id', headerName: 'ID', width: 80),
                  const OsColumnDef(
                    field: 'name',
                    headerName: 'Name',
                    width: 200,
                  ),
                  const OsColumnDef(
                    field: 'value',
                    headerName: 'Value',
                    width: 100,
                  ),
                ],
                rowData: rowData,
                rowHeight: 36,
                headerHeight: 44,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(VirtualisedGrid), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders with custom theme', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: Builder(
                builder: (context) => OsGrid<Map<String, dynamic>>(
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
                  theme: OsGridTheme.fromThemeData(Theme.of(context)),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(VirtualisedGrid), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('handles empty row data', (tester) async {
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
                rowData: <Map<String, dynamic>>[],
              ),
            ),
          ),
        ),
      );

      expect(find.byType(VirtualisedGrid), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('handles null row data', (tester) async {
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
              ),
            ),
          ),
        ),
      );

      expect(find.byType(VirtualisedGrid), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('handles many columns (horizontal virtualisation)', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: OsGrid<Map<String, dynamic>>(
                columnDefs: List.generate(
                  50,
                  (i) => OsColumnDef(
                    field: 'col$i',
                    headerName: 'Column $i',
                    width: 120,
                  ),
                ),
                rowData: List.generate(
                  100,
                  (r) => Map.fromEntries(
                    List.generate(50, (c) => MapEntry('col$c', 'R${r}C$c')),
                  ),
                ),
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
