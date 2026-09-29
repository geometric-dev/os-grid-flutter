import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: SizedBox(width: 800, height: 600, child: child)),
);

List<OsColumnDef> _displayColumns(WidgetTester tester) =>
    tester.widget<VirtualisedGrid>(find.byType(VirtualisedGrid)).columns;

void main() {
  group('defaultColDef', () {
    testWidgets('applies width/minWidth when colDef omits them', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const OsGrid<Map<String, dynamic>>(
            columnDefs: [
              OsColumnDef(field: 'a'),
              OsColumnDef(field: 'b', width: 200),
            ],
            defaultColDef: OsColumnDef<dynamic>(width: 120, minWidth: 60),
            rowData: [
              {'a': 1, 'b': 2},
            ],
          ),
        ),
      );
      await tester.pump();

      final cols = _displayColumns(tester);
      expect(cols.firstWhere((c) => c.field == 'a').width, 120);
      expect(cols.firstWhere((c) => c.field == 'a').minWidth, 60);
      // Explicit value wins over the default.
      expect(cols.firstWhere((c) => c.field == 'b').width, 200);
    });

    testWidgets('editable applies to all columns; explicit false overrides', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const OsGrid<Map<String, dynamic>>(
            columnDefs: [
              OsColumnDef(field: 'a'),
              OsColumnDef(field: 'b', editable: false),
            ],
            defaultColDef: OsColumnDef<dynamic>(editable: true),
            rowData: [
              {'a': 1, 'b': 2},
            ],
          ),
        ),
      );
      await tester.pump();

      final cols = _displayColumns(tester);
      expect(cols.firstWhere((c) => c.field == 'a').editable, isTrue);
      expect(cols.firstWhere((c) => c.field == 'b').editable, isFalse);
    });

    testWidgets('valueGetter from defaultColDef resolves typed rows', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          OsGrid<_Row>(
            columnDefs: const [OsColumnDef<_Row>(field: 'name')],
            defaultColDef: OsColumnDef<dynamic>(
              valueGetter: (params) => (params.data as _Row).name.toUpperCase(),
            ),
            rowData: [const _Row('alice')],
          ),
        ),
      );
      await tester.pump();

      final grid = tester.widget<VirtualisedGrid>(find.byType(VirtualisedGrid));
      expect(grid.rowData.single['name'], 'ALICE');
    });
  });

  group('columnTypes', () {
    testWidgets('single type name merges over defaultColDef', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const OsGrid<Map<String, dynamic>>(
            columnDefs: [
              OsColumnDef(field: 'a', type: 'nonEditable'),
              OsColumnDef(field: 'b'),
            ],
            defaultColDef: OsColumnDef<dynamic>(editable: true, width: 100),
            columnTypes: {'nonEditable': OsColumnDef<dynamic>(editable: false)},
            rowData: [
              {'a': 1, 'b': 2},
            ],
          ),
        ),
      );
      await tester.pump();

      final cols = _displayColumns(tester);
      // Type overrides defaultColDef...
      expect(cols.firstWhere((c) => c.field == 'a').editable, isFalse);
      // ...and inherits defaultColDef fields the type does not set.
      expect(cols.firstWhere((c) => c.field == 'a').width, 100);
      expect(cols.firstWhere((c) => c.field == 'b').editable, isTrue);
    });

    testWidgets('list of types merges in listed order; explicit wins last', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const OsGrid<Map<String, dynamic>>(
            columnDefs: [
              OsColumnDef(
                field: 'a',
                type: ['narrow', 'pinnedLeft'],
                width: 300, // explicit beats both types
              ),
            ],
            columnTypes: {
              'narrow': OsColumnDef<dynamic>(width: 80),
              'pinnedLeft': OsColumnDef<dynamic>(pinned: OsColumnPin.left),
            },
            rowData: [
              {'a': 1},
            ],
          ),
        ),
      );
      await tester.pump();

      final col = _displayColumns(tester).single;
      expect(col.width, 300, reason: 'explicit colDef beats type');
      expect(col.pinned, OsColumnPin.left);
    });

    testWidgets('unknown type names do not crash', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const OsGrid<Map<String, dynamic>>(
            columnDefs: [OsColumnDef(field: 'a', type: 'doesNotExist')],
            rowData: [
              {'a': 1},
            ],
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(OsGrid<Map<String, dynamic>>), findsOneWidget);
    });
  });
}

class _Row {
  const _Row(this.name);
  final String name;
}
