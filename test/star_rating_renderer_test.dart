import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

void main() {
  group('OsBuiltInCellRenderer.starRating', () {
    test('enum value exists', () {
      expect(OsBuiltInCellRenderer.starRating, isNotNull);
      expect(
        OsBuiltInCellRenderer.values.contains(OsBuiltInCellRenderer.starRating),
        isTrue,
      );
    });

    test('can be assigned to OsColumnDef', () {
      const col = OsColumnDef(
        field: 'rating',
        headerName: 'Rating',
        width: 100,
        builtInCellRenderer: OsBuiltInCellRenderer.starRating,
      );
      expect(col.builtInCellRenderer, OsBuiltInCellRenderer.starRating);
    });

    testWidgets('grid renders without error with starRating renderer', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OsGrid(
              columnDefs: [
                OsColumnDef(field: 'name', headerName: 'Name'),
                OsColumnDef(
                  field: 'rating',
                  headerName: 'Rating',
                  width: 100,
                  builtInCellRenderer: OsBuiltInCellRenderer.starRating,
                ),
              ],
              rowData: [
                {'name': 'Alice', 'rating': 5},
                {'name': 'Bob', 'rating': 3},
                {'name': 'Charlie', 'rating': 0},
              ],
            ),
          ),
        ),
      );

      expect(find.byType(VirtualisedGrid), findsOneWidget);
    });

    testWidgets('handles null rating values without crashing', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OsGrid(
              columnDefs: [
                OsColumnDef(field: 'name', headerName: 'Name'),
                OsColumnDef(
                  field: 'rating',
                  headerName: 'Rating',
                  width: 100,
                  builtInCellRenderer: OsBuiltInCellRenderer.starRating,
                ),
              ],
              rowData: [
                {'name': 'Alice', 'rating': null},
                {'name': 'Bob'},
              ],
            ),
          ),
        ),
      );

      expect(find.byType(VirtualisedGrid), findsOneWidget);
    });

    testWidgets('handles out-of-range values without crashing', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OsGrid(
              columnDefs: [
                OsColumnDef(field: 'name', headerName: 'Name'),
                OsColumnDef(
                  field: 'rating',
                  headerName: 'Rating',
                  width: 100,
                  builtInCellRenderer: OsBuiltInCellRenderer.starRating,
                ),
              ],
              rowData: [
                {'name': 'Alice', 'rating': -1},
                {'name': 'Bob', 'rating': 10},
                {'name': 'Charlie', 'rating': 3.7},
              ],
            ),
          ),
        ),
      );

      expect(find.byType(VirtualisedGrid), findsOneWidget);
    });

    testWidgets('renders with custom theme accent colour', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OsGrid(
              theme: OsGridTheme(accentColor: Color(0xFFFF9800)),
              columnDefs: [
                OsColumnDef(field: 'name', headerName: 'Name'),
                OsColumnDef(
                  field: 'rating',
                  headerName: 'Rating',
                  width: 100,
                  builtInCellRenderer: OsBuiltInCellRenderer.starRating,
                ),
              ],
              rowData: [
                {'name': 'Alice', 'rating': 4},
              ],
            ),
          ),
        ),
      );

      expect(find.byType(VirtualisedGrid), findsOneWidget);
    });
  });
}
