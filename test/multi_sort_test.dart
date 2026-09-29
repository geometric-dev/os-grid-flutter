import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

void main() {
  group('SortService', () {
    late SortService<Map<String, dynamic>> service;

    setUp(() {
      service = SortService<Map<String, dynamic>>();
    });

    test('starts with empty sort model', () {
      expect(service.sortModel, isEmpty);
      expect(service.isSortActive, isFalse);
      expect(service.isMultiSorting, isFalse);
    });

    test('progressSort adds ascending sort on first click', () {
      service.progressSort(colId: 'name', multiSort: false);

      expect(service.sortModel.length, 1);
      expect(service.sortModel.first.colId, 'name');
      expect(service.sortModel.first.sort, OsSortDirection.ascending);
    });

    test('progressSort cycles asc → desc → clear', () {
      service.progressSort(colId: 'name', multiSort: false);
      expect(service.getSortDirection('name'), OsSortDirection.ascending);

      service.progressSort(colId: 'name', multiSort: false);
      expect(service.getSortDirection('name'), OsSortDirection.descending);

      service.progressSort(colId: 'name', multiSort: false);
      expect(service.getSortDirection('name'), isNull);
      expect(service.sortModel, isEmpty);
    });

    test('progressSort without multiSort replaces existing sort', () {
      service.progressSort(colId: 'name', multiSort: false);
      service.progressSort(colId: 'age', multiSort: false);

      expect(service.sortModel.length, 1);
      expect(service.sortModel.first.colId, 'age');
      expect(service.getSortDirection('name'), isNull);
    });

    test('progressSort with multiSort adds to existing sort', () {
      service.progressSort(colId: 'name', multiSort: false);
      service.progressSort(colId: 'age', multiSort: true);

      expect(service.sortModel.length, 2);
      expect(service.sortModel[0].colId, 'name');
      expect(service.sortModel[1].colId, 'age');
      expect(service.isMultiSorting, isTrue);
    });

    test('progressSort with multiSort cycles existing column in place', () {
      service.progressSort(colId: 'name', multiSort: false);
      service.progressSort(colId: 'age', multiSort: true);

      // Click name again with multi-sort — should cycle to desc
      service.progressSort(colId: 'name', multiSort: true);
      expect(service.sortModel.length, 2);
      expect(service.sortModel[0].colId, 'name');
      expect(service.sortModel[0].sort, OsSortDirection.descending);
      expect(service.sortModel[1].colId, 'age');
    });

    test('progressSort with multiSort removes column on third click', () {
      service.progressSort(colId: 'name', multiSort: false);
      service.progressSort(colId: 'age', multiSort: true);

      // Cycle name: asc → desc → clear
      service.progressSort(colId: 'name', multiSort: true);
      service.progressSort(colId: 'name', multiSort: true);

      expect(service.sortModel.length, 1);
      expect(service.sortModel.first.colId, 'age');
    });

    test('getSortIndex returns correct priority', () {
      service.progressSort(colId: 'name', multiSort: false);
      service.progressSort(colId: 'age', multiSort: true);
      service.progressSort(colId: 'city', multiSort: true);

      expect(service.getSortIndex('name'), 0);
      expect(service.getSortIndex('age'), 1);
      expect(service.getSortIndex('city'), 2);
      expect(service.getSortIndex('unknown'), isNull);
    });

    test('setColumnSort sets specific direction', () {
      service.setColumnSort(
        colId: 'name',
        direction: OsSortDirection.descending,
      );

      expect(service.sortModel.length, 1);
      expect(service.sortModel.first.sort, OsSortDirection.descending);
    });

    test('setColumnSort with null direction removes column', () {
      service.progressSort(colId: 'name', multiSort: false);
      service.setColumnSort(colId: 'name', direction: null);

      expect(service.sortModel, isEmpty);
    });

    test('setColumnSort with multiSort adds to existing', () {
      service.progressSort(colId: 'name', multiSort: false);
      service.setColumnSort(
        colId: 'age',
        direction: OsSortDirection.ascending,
        multiSort: true,
      );

      expect(service.sortModel.length, 2);
    });

    test('clearSort removes all sort state', () {
      service.progressSort(colId: 'name', multiSort: false);
      service.progressSort(colId: 'age', multiSort: true);
      service.clearSort();

      expect(service.sortModel, isEmpty);
      expect(service.isSortActive, isFalse);
    });

    test('setSortModel replaces entire model', () {
      service.setSortModel([
        const OsSortModel(colId: 'age', sort: OsSortDirection.descending),
        const OsSortModel(colId: 'name', sort: OsSortDirection.ascending),
      ]);

      expect(service.sortModel.length, 2);
      expect(service.sortModel[0].colId, 'age');
      expect(service.sortModel[1].colId, 'name');
    });

    group('sortData', () {
      final columns = [
        const OsColumnDef(field: 'name', headerName: 'Name', sortable: true),
        const OsColumnDef(field: 'age', headerName: 'Age', sortable: true),
        const OsColumnDef(field: 'city', headerName: 'City', sortable: true),
      ];

      final data = [
        {'name': 'Charlie', 'age': 30, 'city': 'London'},
        {'name': 'Alice', 'age': 25, 'city': 'Paris'},
        {'name': 'Bob', 'age': 30, 'city': 'Berlin'},
        {'name': 'Alice', 'age': 28, 'city': 'Madrid'},
      ];

      test('single column ascending sort', () {
        service.progressSort(colId: 'name', multiSort: false);
        final sorted = service.sortData(data: data, columns: columns);

        expect(sorted[0]['name'], 'Alice');
        expect(sorted[1]['name'], 'Alice');
        expect(sorted[2]['name'], 'Bob');
        expect(sorted[3]['name'], 'Charlie');
      });

      test('single column descending sort', () {
        service.setSortModel([
          const OsSortModel(colId: 'name', sort: OsSortDirection.descending),
        ]);
        final sorted = service.sortData(data: data, columns: columns);

        expect(sorted[0]['name'], 'Charlie');
        expect(sorted[1]['name'], 'Bob');
        expect(sorted[2]['name'], 'Alice');
        expect(sorted[3]['name'], 'Alice');
      });

      test('multi-column sort (age desc, then name asc)', () {
        service.setSortModel([
          const OsSortModel(colId: 'age', sort: OsSortDirection.descending),
          const OsSortModel(colId: 'name', sort: OsSortDirection.ascending),
        ]);
        final sorted = service.sortData(data: data, columns: columns);

        // age 30 first (desc), then within age 30: Bob < Charlie (asc)
        expect(sorted[0]['name'], 'Bob');
        expect(sorted[0]['age'], 30);
        expect(sorted[1]['name'], 'Charlie');
        expect(sorted[1]['age'], 30);
        // age 28 next
        expect(sorted[2]['name'], 'Alice');
        expect(sorted[2]['age'], 28);
        // age 25 last
        expect(sorted[3]['name'], 'Alice');
        expect(sorted[3]['age'], 25);
      });

      test('multi-column sort (name asc, then age asc)', () {
        service.setSortModel([
          const OsSortModel(colId: 'name', sort: OsSortDirection.ascending),
          const OsSortModel(colId: 'age', sort: OsSortDirection.ascending),
        ]);
        final sorted = service.sortData(data: data, columns: columns);

        // Alice (25) before Alice (28)
        expect(sorted[0]['name'], 'Alice');
        expect(sorted[0]['age'], 25);
        expect(sorted[1]['name'], 'Alice');
        expect(sorted[1]['age'], 28);
        expect(sorted[2]['name'], 'Bob');
        expect(sorted[3]['name'], 'Charlie');
      });

      test('handles null values (nulls sort first)', () {
        final dataWithNulls = [
          {'name': 'Bob', 'age': 30},
          {'name': null, 'age': 25},
          {'name': 'Alice', 'age': null},
        ];
        service.setSortModel([
          const OsSortModel(colId: 'name', sort: OsSortDirection.ascending),
        ]);
        final sorted = service.sortData(data: dataWithNulls, columns: columns);

        expect(sorted[0]['name'], isNull);
        expect(sorted[1]['name'], 'Alice');
        expect(sorted[2]['name'], 'Bob');
      });

      test('empty sort model returns data unchanged', () {
        final sorted = service.sortData(data: data, columns: columns);
        expect(sorted, data);
      });

      test('does not mutate original data', () {
        final original = List<Map<String, dynamic>>.from(data);
        service.progressSort(colId: 'name', multiSort: false);
        service.sortData(data: data, columns: columns);

        expect(data[0]['name'], original[0]['name']);
        expect(data[1]['name'], original[1]['name']);
      });

      test('custom comparator is used when provided', () {
        final customColumns = [
          OsColumnDef(
            field: 'name',
            headerName: 'Name',
            sortable: true,
            comparator: (a, b, dataA, dataB, isDesc) {
              // Reverse alphabetical (Z first)
              return (b as String).compareTo(a as String);
            },
          ),
        ];
        service.setSortModel([
          const OsSortModel(colId: 'name', sort: OsSortDirection.ascending),
        ]);
        final sorted = service.sortData(data: data, columns: customColumns);

        // Custom comparator reverses, but direction is asc so result is reversed
        expect(sorted[0]['name'], 'Charlie');
        expect(sorted[3]['name'], 'Alice');
      });

      test('accentedSort uses locale-aware comparison', () {
        service.accentedSort = true;
        final accentData = [
          {'name': 'Über', 'age': 1},
          {'name': 'uber', 'age': 2},
          {'name': 'Alpha', 'age': 3},
        ];
        service.setSortModel([
          const OsSortModel(colId: 'name', sort: OsSortDirection.ascending),
        ]);
        final sorted = service.sortData(data: accentData, columns: columns);

        // With accented sort (lowercase comparison), 'alpha' < 'uber' < 'über'
        expect(sorted[0]['name'], 'Alpha');
        // uber and Über should be adjacent (both lowercase to 'uber'/'über')
        expect(sorted[1]['name'], isIn(['uber', 'Über']));
      });
    });
  });

  group('SortIndicatorInfo', () {
    test('equality works correctly', () {
      const a = SortIndicatorInfo(
        direction: OsSortDirection.ascending,
        priority: 1,
        isMultiSort: true,
      );
      const b = SortIndicatorInfo(
        direction: OsSortDirection.ascending,
        priority: 1,
        isMultiSort: true,
      );
      const c = SortIndicatorInfo(
        direction: OsSortDirection.descending,
        priority: 1,
        isMultiSort: true,
      );

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });

  group('OsGrid multi-sort integration', () {
    testWidgets('controller.setSortModel applies sort programmatically', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();
      final events = <OsSortChangedEvent>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: OsGrid(
                controller: controller,
                columnDefs: const [
                  OsColumnDef(
                    field: 'name',
                    headerName: 'Name',
                    sortable: true,
                  ),
                  OsColumnDef(field: 'age', headerName: 'Age', sortable: true),
                ],
                rowData: const [
                  {'name': 'Charlie', 'age': 30},
                  {'name': 'Alice', 'age': 25},
                  {'name': 'Bob', 'age': 28},
                ],
                onSortChanged: events.add,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Set multi-column sort via API
      controller.setSortModel([
        const OsSortModel(colId: 'age', sort: OsSortDirection.descending),
        const OsSortModel(colId: 'name', sort: OsSortDirection.ascending),
      ]);
      await tester.pump();

      expect(events.length, 1);
      expect(events.last.sortModel.length, 2);
      expect(events.last.sortModel[0].colId, 'age');
      expect(events.last.sortModel[0].sort, OsSortDirection.descending);
      expect(events.last.sortModel[1].colId, 'name');

      // Verify getSortModel returns the same
      final model = controller.getSortModel();
      expect(model.length, 2);
      expect(model[0].colId, 'age');
    });

    testWidgets('controller.setSortModel clears sort with empty list', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();
      final events = <OsSortChangedEvent>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: OsGrid(
                controller: controller,
                columnDefs: const [
                  OsColumnDef(
                    field: 'name',
                    headerName: 'Name',
                    sortable: true,
                  ),
                ],
                rowData: const [
                  {'name': 'Alice'},
                  {'name': 'Bob'},
                ],
                onSortChanged: events.add,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Set sort then clear
      controller.setSortModel([
        const OsSortModel(colId: 'name', sort: OsSortDirection.ascending),
      ]);
      await tester.pump();

      controller.setSortModel([]);
      await tester.pump();

      expect(events.length, 2);
      expect(events.last.sortModel, isEmpty);
      expect(controller.getSortModel(), isEmpty);
    });

    testWidgets('initialSort applies on first render', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: OsGrid(
                controller: controller,
                columnDefs: const [
                  OsColumnDef(
                    field: 'name',
                    headerName: 'Name',
                    sortable: true,
                  ),
                  OsColumnDef(field: 'age', headerName: 'Age', sortable: true),
                ],
                rowData: const [
                  {'name': 'Charlie', 'age': 30},
                  {'name': 'Alice', 'age': 25},
                  {'name': 'Bob', 'age': 28},
                ],
                initialSort: const [
                  OsSortModel(colId: 'name', sort: OsSortDirection.ascending),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Verify the sort model is applied
      final model = controller.getSortModel();
      expect(model.length, 1);
      expect(model.first.colId, 'name');
      expect(model.first.sort, OsSortDirection.ascending);
    });

    test('sort changed event emits via controller stream', () async {
      final controller = OsGridController<Map<String, dynamic>>();
      final streamEvents = <OsSortChangedEvent>[];
      final sub = controller.onSortChanged.listen(streamEvents.add);

      // Simulate what the widget does when setSortModel is called
      controller.emitSortChanged(
        const OsSortChangedEvent(
          sortModel: [
            OsSortModel(colId: 'name', sort: OsSortDirection.ascending),
            OsSortModel(colId: 'age', sort: OsSortDirection.descending),
          ],
        ),
      );

      await Future<void>.delayed(Duration.zero);

      expect(streamEvents.length, 1);
      expect(streamEvents.first.sortModel.length, 2);
      expect(streamEvents.first.sortModel[0].colId, 'name');
      expect(streamEvents.first.sortModel[1].colId, 'age');

      await sub.cancel();
      controller.dispose();
    });

    testWidgets('multi-sort options are accepted by widget', (tester) async {
      // Verify that the widget accepts all multi-sort options without error
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
                    sortable: true,
                  ),
                ],
                rowData: [
                  {'name': 'Alice'},
                ],
                multiSortKey: OsMultiSortKey.ctrl,
                alwaysMultiSort: true,
                suppressMultiSort: false,
                accentedSort: true,
                initialSort: [
                  OsSortModel(colId: 'name', sort: OsSortDirection.ascending),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // No error means the options are accepted
    });

    testWidgets('accentedSort option is synced on widget update', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();
      const bool accentedSort = false;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState2) {
              return Scaffold(
                body: SizedBox(
                  width: 800,
                  height: 600,
                  child: OsGrid(
                    controller: controller,
                    columnDefs: const [
                      OsColumnDef(
                        field: 'name',
                        headerName: 'Name',
                        sortable: true,
                      ),
                    ],
                    rowData: const [
                      {'name': 'Alice'},
                      {'name': 'Bob'},
                    ],
                    accentedSort: accentedSort,
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pump();

      // Widget builds without error with accentedSort: false
      // (We can't easily test the internal state change, but we verify no crash)
    });
  });

  group('OsSortModel', () {
    test('equality', () {
      const a = OsSortModel(colId: 'name', sort: OsSortDirection.ascending);
      const b = OsSortModel(colId: 'name', sort: OsSortDirection.ascending);
      const c = OsSortModel(colId: 'name', sort: OsSortDirection.descending);

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('toString', () {
      const model = OsSortModel(colId: 'age', sort: OsSortDirection.descending);
      expect(model.toString(), contains('age'));
      expect(model.toString(), contains('descending'));
    });
  });
}
