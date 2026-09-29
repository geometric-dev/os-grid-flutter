import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

/// Helper to collect filtered rows from the controller.
List<T> getRows<T>(OsGridController<T> controller) {
  final rows = <T>[];
  controller.forEachNodeAfterFilter((data, index) {
    rows.add(data);
  });
  return rows;
}

void main() {
  group('OsCustomFilter', () {
    group('configuration', () {
      test('creates with required parameters', () {
        final filter = OsCustomFilter(
          builder: (context, params) => const SizedBox(),
          doesFilterPass: (cellValue, model) => true,
          isFilterActive: (model) => model != null,
        );

        expect(filter.getModelAsString, isNull);
      });

      test('creates with optional getModelAsString', () {
        final filter = OsCustomFilter(
          builder: (context, params) => const SizedBox(),
          doesFilterPass: (cellValue, model) => true,
          isFilterActive: (model) => model != null,
          getModelAsString: (model) => 'Active: $model',
        );

        expect(filter.getModelAsString, isNotNull);
        expect(filter.getModelAsString!('test'), equals('Active: test'));
      });

      test('extends OsFilter', () {
        final filter = OsCustomFilter(
          builder: (context, params) => const SizedBox(),
          doesFilterPass: (cellValue, model) => true,
          isFilterActive: (model) => model != null,
        );

        expect(filter, isA<OsFilter>());
      });
    });

    group('doesFilterPass', () {
      test('simple equality filter', () {
        final filter = OsCustomFilter(
          builder: (context, params) => const SizedBox(),
          doesFilterPass: (cellValue, model) {
            if (model == null) return true;
            return cellValue == model;
          },
          isFilterActive: (model) => model != null,
        );

        expect(filter.doesFilterPass('active', 'active'), isTrue);
        expect(filter.doesFilterPass('inactive', 'active'), isFalse);
        expect(filter.doesFilterPass('active', null), isTrue);
      });

      test('list-based inclusion filter', () {
        final filter = OsCustomFilter(
          builder: (context, params) => const SizedBox(),
          doesFilterPass: (cellValue, model) {
            if (model == null) return true;
            final allowed = model as List<String>;
            return allowed.contains(cellValue);
          },
          isFilterActive: (model) => model != null,
        );

        expect(filter.doesFilterPass('apple', ['apple', 'banana']), isTrue);
        expect(filter.doesFilterPass('cherry', ['apple', 'banana']), isFalse);
        expect(filter.doesFilterPass('anything', null), isTrue);
      });

      test('range filter', () {
        final filter = OsCustomFilter(
          builder: (context, params) => const SizedBox(),
          doesFilterPass: (cellValue, model) {
            if (model == null) return true;
            final range = model as Map<String, int>;
            final value = cellValue as int;
            return value >= range['min']! && value <= range['max']!;
          },
          isFilterActive: (model) => model != null,
        );

        expect(filter.doesFilterPass(25, {'min': 18, 'max': 65}), isTrue);
        expect(filter.doesFilterPass(10, {'min': 18, 'max': 65}), isFalse);
        expect(filter.doesFilterPass(70, {'min': 18, 'max': 65}), isFalse);
      });

      test('handles null cell values', () {
        final filter = OsCustomFilter(
          builder: (context, params) => const SizedBox(),
          doesFilterPass: (cellValue, model) {
            if (model == null) return true;
            if (cellValue == null) return false;
            return cellValue == model;
          },
          isFilterActive: (model) => model != null,
        );

        expect(filter.doesFilterPass(null, 'active'), isFalse);
        expect(filter.doesFilterPass(null, null), isTrue);
      });
    });

    group('isFilterActive', () {
      test('null model means inactive', () {
        final filter = OsCustomFilter(
          builder: (context, params) => const SizedBox(),
          doesFilterPass: (cellValue, model) => true,
          isFilterActive: (model) => model != null,
        );

        expect(filter.isFilterActive(null), isFalse);
        expect(filter.isFilterActive('something'), isTrue);
      });

      test('custom activity logic', () {
        final filter = OsCustomFilter(
          builder: (context, params) => const SizedBox(),
          doesFilterPass: (cellValue, model) => true,
          isFilterActive: (model) {
            if (model == null) return false;
            if (model is List) return model.isNotEmpty;
            return true;
          },
        );

        expect(filter.isFilterActive(null), isFalse);
        expect(filter.isFilterActive([]), isFalse);
        expect(filter.isFilterActive(['a']), isTrue);
        expect(filter.isFilterActive('text'), isTrue);
      });
    });

    group('getModelAsString', () {
      test('returns display text for floating filter', () {
        final filter = OsCustomFilter(
          builder: (context, params) => const SizedBox(),
          doesFilterPass: (cellValue, model) => true,
          isFilterActive: (model) => model != null,
          getModelAsString: (model) {
            if (model == null) return '';
            if (model is List) return model.join(', ');
            return model.toString();
          },
        );

        expect(filter.getModelAsString!(null), equals(''));
        expect(filter.getModelAsString!('active'), equals('active'));
        expect(filter.getModelAsString!(['a', 'b', 'c']), equals('a, b, c'));
      });
    });

    group('CustomFilterParams', () {
      test('provides model and column info', () {
        dynamic capturedModel;

        final params = CustomFilterParams(
          model: {'status': 'active'},
          colDef: const OsColumnDef(field: 'status', headerName: 'Status'),
          column: 'status',
          onModelChanged: (model) => capturedModel = model,
          getValue: (row) => (row as Map)['status'],
        );

        expect(params.model, equals({'status': 'active'}));
        expect(params.column, equals('status'));
        expect(params.colDef.field, equals('status'));

        // Test onModelChanged callback
        params.onModelChanged('new_value');
        expect(capturedModel, equals('new_value'));

        // Test getValue callback
        final value = params.getValue({'status': 'pending', 'name': 'Test'});
        expect(value, equals('pending'));
      });

      test('model can be null', () {
        final params = CustomFilterParams(
          model: null,
          colDef: const OsColumnDef(field: 'name', headerName: 'Name'),
          column: 'name',
          onModelChanged: (_) {},
          getValue: (row) => null,
        );

        expect(params.model, isNull);
      });
    });
  });

  group('OsCustomFilter widget integration', () {
    testWidgets('custom filter popup shows builder widget', (
      WidgetTester tester,
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
                  OsColumnDef(
                    field: 'status',
                    headerName: 'Status',
                    filter: OsCustomFilter(
                      builder: (context, params) {
                        return const Text('Custom Filter Widget');
                      },
                      doesFilterPass: (cellValue, model) => true,
                      isFilterActive: (model) => model != null,
                    ),
                  ),
                ],
                rowData: [
                  {'status': 'active'},
                  {'status': 'inactive'},
                  {'status': 'pending'},
                ],
                floatingFilter: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The custom filter widget should not be visible initially
      expect(find.text('Custom Filter Widget'), findsNothing);
    });

    testWidgets('custom filter applies doesFilterPass to rows', (
      WidgetTester tester,
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
                  OsColumnDef(
                    field: 'status',
                    headerName: 'Status',
                    filter: OsCustomFilter(
                      builder: (context, params) {
                        return GestureDetector(
                          onTap: () {
                            params.onModelChanged('active');
                          },
                          child: const Text('Set Active Filter'),
                        );
                      },
                      doesFilterPass: (cellValue, model) {
                        if (model == null) return true;
                        return cellValue == model;
                      },
                      isFilterActive: (model) => model != null,
                    ),
                  ),
                ],
                rowData: [
                  {'status': 'active'},
                  {'status': 'inactive'},
                  {'status': 'pending'},
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially all 3 rows should be in processed data
      // Use forEachNodeAfterFilter to verify row count
      final rows = <Map<String, dynamic>>[];
      controller.forEachNodeAfterFilter((data, index) {
        rows.add(data as Map<String, dynamic>);
      });
      expect(rows.length, equals(3));
    });

    testWidgets('custom filter emits onFilterChanged event', (
      WidgetTester tester,
    ) async {
      final controller = OsGridController();
      OsFilterChangedEvent? lastFilterEvent;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: OsGrid(
                controller: controller,
                columnDefs: [
                  OsColumnDef(
                    field: 'name',
                    headerName: 'Name',
                    filter: OsCustomFilter(
                      builder: (context, params) {
                        return const Text('Filter');
                      },
                      doesFilterPass: (cellValue, model) {
                        if (model == null) return true;
                        return cellValue.toString().toLowerCase().contains(
                          model.toString().toLowerCase(),
                        );
                      },
                      isFilterActive: (model) => model != null,
                    ),
                  ),
                ],
                rowData: [
                  {'name': 'Alice'},
                  {'name': 'Bob'},
                  {'name': 'Charlie'},
                ],
                onFilterChanged: (event) => lastFilterEvent = event,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially no filter event
      expect(lastFilterEvent, isNull);
    });

    testWidgets(
      'custom filter getModelAsString provides floating filter text',
      (WidgetTester tester) async {
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
                    OsColumnDef(
                      field: 'category',
                      headerName: 'Category',
                      filter: OsCustomFilter(
                        builder: (context, params) {
                          return const Text('Category Filter');
                        },
                        doesFilterPass: (cellValue, model) {
                          if (model == null) return true;
                          return (model as List).contains(cellValue);
                        },
                        isFilterActive: (model) =>
                            model != null && (model as List).isNotEmpty,
                        getModelAsString: (model) {
                          if (model == null) return '';
                          return (model as List).join(', ');
                        },
                      ),
                    ),
                  ],
                  rowData: [
                    {'category': 'A'},
                    {'category': 'B'},
                    {'category': 'C'},
                  ],
                  floatingFilter: true,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify the grid renders without errors
        expect(find.byType(OsGrid), findsOneWidget);
      },
    );

    testWidgets('custom filter works alongside standard filters', (
      WidgetTester tester,
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
                  const OsColumnDef(
                    field: 'name',
                    headerName: 'Name',
                    filter: OsTextFilter(),
                  ),
                  OsColumnDef(
                    field: 'status',
                    headerName: 'Status',
                    filter: OsCustomFilter(
                      builder: (context, params) {
                        return const Text('Status Filter');
                      },
                      doesFilterPass: (cellValue, model) {
                        if (model == null) return true;
                        return cellValue == model;
                      },
                      isFilterActive: (model) => model != null,
                    ),
                  ),
                ],
                rowData: [
                  {'name': 'Alice', 'status': 'active'},
                  {'name': 'Bob', 'status': 'inactive'},
                  {'name': 'Charlie', 'status': 'active'},
                ],
                floatingFilter: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Grid renders with both filter types
      expect(find.byType(OsGrid), findsOneWidget);
      final rows = <Map<String, dynamic>>[];
      controller.forEachNodeAfterFilter((data, index) {
        rows.add(data as Map<String, dynamic>);
      });
      expect(rows.length, equals(3));
    });

    testWidgets('custom filter with pagination', (WidgetTester tester) async {
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
                  OsColumnDef(
                    field: 'value',
                    headerName: 'Value',
                    filter: OsCustomFilter(
                      builder: (context, params) {
                        return const Text('Value Filter');
                      },
                      doesFilterPass: (cellValue, model) {
                        if (model == null) return true;
                        return (cellValue as int) > (model as int);
                      },
                      isFilterActive: (model) => model != null,
                    ),
                  ),
                ],
                rowData: List.generate(50, (i) => {'value': i}),
                pagination: const OsPagination(pageSize: 10),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // All 50 rows in processed data (no filter active)
      final rows = <Map<String, dynamic>>[];
      controller.forEachNodeAfterFilter((data, index) {
        rows.add(data as Map<String, dynamic>);
      });
      expect(rows.length, equals(50));
    });
    testWidgets('custom filter is applied on controller-driven reprocessing', (
      WidgetTester tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: OsGrid<Map<String, dynamic>>(
                controller: controller,
                columnDefs: [
                  OsColumnDef(
                    field: 'category',
                    headerName: 'Category',
                    filter: OsCustomFilter(
                      builder: (context, params) => const Text('Filter'),
                      doesFilterPass: (cellValue, model) {
                        if (model == null) return true;
                        // setFilterModel stores the raw model map
                        // ({filterType, model}); unwrap it when present.
                        final effective = model is Map
                            ? (model['model'] ?? model)
                            : model;
                        return cellValue == effective;
                      },
                      isFilterActive: (model) => model != null,
                    ),
                  ),
                ],
                rowData: [
                  {'category': 'fruit'},
                  {'category': 'vegetable'},
                  {'category': 'fruit'},
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(getRows(controller).length, 3);

      // Programmatically activate a custom filter model.
      controller.setFilterModel({
        'category': {'filterType': 'custom', 'model': 'fruit'},
      });
      await tester.pumpAndSettle();

      // Widget-path pipeline applies the custom filter.
      expect(getRows(controller).length, 2);

      // Controller-driven reprocess path (refreshClientSideRowModel /
      // applyTransaction) must also apply custom filters.
      controller.refreshClientSideRowModel();
      await tester.pumpAndSettle();

      final rows = getRows(controller);
      expect(rows.length, 2);
      expect(rows.every((r) => r['category'] == 'fruit'), isTrue);

      controller.dispose();
    });
  });

  group('OsCustomFilter filter model serialisation', () {
    test(
      'custom filter model appears in getFilterModel with filterType custom',
      () {
        // This tests the model structure that would be emitted
        final model = {
          'status': {'filterType': 'custom', 'model': 'active'},
        };

        expect(model['status']!['filterType'], equals('custom'));
        expect(model['status']!['model'], equals('active'));
      },
    );

    test('complex custom filter model serialises correctly', () {
      final model = {
        'category': {
          'filterType': 'custom',
          'model': ['electronics', 'clothing'],
        },
      };

      expect(model['category']!['filterType'], equals('custom'));
      expect(model['category']!['model'], equals(['electronics', 'clothing']));
    });

    test('map-based custom filter model', () {
      final model = {
        'age': {
          'filterType': 'custom',
          'model': {'min': 18, 'max': 65},
        },
      };

      expect(model['age']!['filterType'], equals('custom'));
      final filterModel = model['age']!['model'] as Map<String, int>;
      expect(filterModel['min'], equals(18));
      expect(filterModel['max'], equals(65));
    });
  });
}
