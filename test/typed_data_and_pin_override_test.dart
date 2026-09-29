import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

/// Typed row model exercising the non-Map code paths.
class _Athlete {
  _Athlete(this.name, this.age, this.country);

  final String name;
  final int age;
  final String country;
}

List<String> _displayValues(WidgetTester tester, String field) {
  final grid = tester.widget<VirtualisedGrid>(find.byType(VirtualisedGrid));
  return [
    for (final row in grid.rowData)
      if (row[field] != null) row[field] as String,
  ];
}

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  final athletes = [
    _Athlete('Alice', 32, 'UK'),
    _Athlete('Bob', 28, 'US'),
    _Athlete('Carol', 35, 'Canada'),
  ];

  group('typed (non-Map) row data', () {
    testWidgets('typed rows render via valueGetter without crashing', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          OsGrid<_Athlete>(
            columnDefs: [
              OsColumnDef<_Athlete>(
                field: 'name',
                headerName: 'Name',
                valueGetter: (params) => params.data.name,
                filter: const OsTextFilter(),
              ),
              OsColumnDef<_Athlete>(
                field: 'age',
                headerName: 'Age',
                valueGetter: (params) => params.data.age,
              ),
            ],
            rowData: athletes,
          ),
        ),
      );
      await tester.pump();

      expect(_displayValues(tester, 'name'), ['Alice', 'Bob', 'Carol']);
    });

    testWidgets('setFilterModel on typed rows keeps only matching rows', (
      tester,
    ) async {
      final controller = OsGridController<_Athlete>();

      await tester.pumpWidget(
        _wrap(
          OsGrid<_Athlete>(
            controller: controller,
            columnDefs: [
              OsColumnDef<_Athlete>(
                field: 'country',
                headerName: 'Country',
                valueGetter: (params) => params.data.country,
                filter: const OsTextFilter(),
              ),
            ],
            rowData: athletes,
          ),
        ),
      );
      await tester.pump();

      // Apply a text "equals" filter through the public API.
      controller.setFilterModel({
        'country': const OsColumnFilterModel(
          filterType: 'text',
          conditions: [OsFilterCondition(type: 'equals', filter: 'UK')],
        ).toJson(),
      });
      await tester.pumpAndSettle();

      expect(_displayValues(tester, 'country'), ['UK']);
    });

    testWidgets('custom filter receives resolved values for typed rows', (
      tester,
    ) async {
      final controller = OsGridController<_Athlete>();
      final seenValues = <dynamic>[];

      await tester.pumpWidget(
        _wrap(
          OsGrid<_Athlete>(
            controller: controller,
            columnDefs: [
              OsColumnDef<_Athlete>(
                field: 'name',
                headerName: 'Name',
                valueGetter: (params) => params.data.name,
                filter: OsCustomFilter(
                  builder: (context, params) => const SizedBox.shrink(),
                  doesFilterPass: (value, model) {
                    seenValues.add(value);
                    return value == 'Bob';
                  },
                  isFilterActive: (model) => true,
                ),
              ),
            ],
            rowData: athletes,
          ),
        ),
      );
      await tester.pump();

      controller.setFilterModel({
        'name': <String, dynamic>{'filterType': 'custom'},
      });
      await tester.pumpAndSettle();

      expect(seenValues, containsAll(['Alice', 'Bob', 'Carol']));
      expect(_displayValues(tester, 'name'), ['Bob']);
    });
  });

  group('pin override preserves column configuration', () {
    testWidgets('pinned columns keep wrapText/autoHeight/tooltip config', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(
        _wrap(
          OsGrid<Map<String, dynamic>>(
            controller: controller,
            columnDefs: [
              const OsColumnDef(field: 'name', headerName: 'Name', width: 100),
              const OsColumnDef(
                field: 'notes',
                headerName: 'Notes',
                width: 120,
                autoHeight: true,
                wrapText: true,
                tooltipField: 'notesTip',
                headerTooltip: 'Notes header tip',
              ),
            ],
            rowData: [
              {'name': 'A', 'notes': 'x'},
            ],
          ),
        ),
      );
      await tester.pump();

      // Pin the notes column programmatically.
      controller.setColumnsPinned(['notes'], OsColumnPin.right);
      await tester.pumpAndSettle();

      final virtualisedGrid = tester.widget<VirtualisedGrid>(
        find.byType(VirtualisedGrid),
      );
      final notesCol = virtualisedGrid.columns.firstWhere(
        (c) => c.effectiveColId == 'notes',
      );

      expect(notesCol.pinned, OsColumnPin.right);
      expect(notesCol.autoHeight, isTrue);
      expect(notesCol.wrapText, isTrue);
      expect(notesCol.tooltipField, 'notesTip');
      expect(notesCol.headerTooltip, 'Notes header tip');
    });

    testWidgets('unpinning clears an existing pin', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(
        _wrap(
          OsGrid<Map<String, dynamic>>(
            controller: controller,
            columnDefs: [
              const OsColumnDef(field: 'a', headerName: 'A', width: 80),
            ],
            rowData: [
              {'a': 1},
            ],
          ),
        ),
      );
      await tester.pump();

      controller.setColumnsPinned(['a'], OsColumnPin.left);
      await tester.pumpAndSettle();
      var col = tester
          .widget<VirtualisedGrid>(find.byType(VirtualisedGrid))
          .columns
          .first;
      expect(col.pinned, OsColumnPin.left);

      controller.setColumnsPinned(['a'], null);
      await tester.pumpAndSettle();
      col = tester
          .widget<VirtualisedGrid>(find.byType(VirtualisedGrid))
          .columns
          .first;
      expect(col.pinned, isNull);
    });
  });
}
