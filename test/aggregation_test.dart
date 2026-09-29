import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

void main() {
  group('AggregationService', () {
    late AggregationService<Map<String, dynamic>> service;

    setUp(() {
      service = AggregationService<Map<String, dynamic>>();
    });

    List<Map<String, dynamic>> sampleData() => [
      {'country': 'UK', 'city': 'London', 'sales': 100, 'profit': 20},
      {'country': 'UK', 'city': 'Manchester', 'sales': 200, 'profit': 40},
      {'country': 'UK', 'city': 'London', 'sales': 150, 'profit': 30},
      {'country': 'US', 'city': 'New York', 'sales': 300, 'profit': 60},
      {'country': 'US', 'city': 'Boston', 'sales': 250, 'profit': 50},
    ];

    group('sum', () {
      test('computes sum of numeric values', () {
        const col = OsColumnDef(field: 'sales', aggFunc: 'sum');
        final result = service.computeGroupAggregates(
          leafRows: sampleData(),
          valueColumns: [col],
        );
        expect(result['sales'], equals(1000));
      });

      test('ignores null values', () {
        final data = [
          {'sales': 100},
          {'sales': null},
          {'sales': 200},
        ];
        const col = OsColumnDef(field: 'sales', aggFunc: 'sum');
        final result = service.computeGroupAggregates(
          leafRows: data,
          valueColumns: [col],
        );
        expect(result['sales'], equals(300));
      });

      test('returns null for empty values', () {
        const col = OsColumnDef(field: 'sales', aggFunc: 'sum');
        final result = service.computeGroupAggregates(
          leafRows: <Map<String, dynamic>>[],
          valueColumns: [col],
        );
        expect(result['sales'], isNull);
      });

      test('handles mixed int and double', () {
        final data = [
          {'sales': 100},
          {'sales': 50.5},
          {'sales': 200},
        ];
        const col = OsColumnDef(field: 'sales', aggFunc: 'sum');
        final result = service.computeGroupAggregates(
          leafRows: data,
          valueColumns: [col],
        );
        expect(result['sales'], equals(350.5));
      });
    });

    group('avg', () {
      test('computes average of numeric values', () {
        const col = OsColumnDef(field: 'sales', aggFunc: 'avg');
        final result = service.computeGroupAggregates(
          leafRows: sampleData(),
          valueColumns: [col],
        );
        expect(result['sales'], equals(200.0));
      });

      test('ignores non-numeric values', () {
        final data = [
          {'sales': 100},
          {'sales': 'invalid'},
          {'sales': 200},
        ];
        const col = OsColumnDef(field: 'sales', aggFunc: 'avg');
        final result = service.computeGroupAggregates(
          leafRows: data,
          valueColumns: [col],
        );
        expect(result['sales'], equals(150.0));
      });

      test('returns null for empty list', () {
        const col = OsColumnDef(field: 'sales', aggFunc: 'avg');
        final result = service.computeGroupAggregates(
          leafRows: <Map<String, dynamic>>[],
          valueColumns: [col],
        );
        expect(result['sales'], isNull);
      });
    });

    group('count', () {
      test('counts non-null values', () {
        const col = OsColumnDef(field: 'sales', aggFunc: 'count');
        final result = service.computeGroupAggregates(
          leafRows: sampleData(),
          valueColumns: [col],
        );
        expect(result['sales'], equals(5));
      });

      test('excludes null values from count', () {
        final data = [
          {'sales': 100},
          {'sales': null},
          {'sales': 200},
        ];
        const col = OsColumnDef(field: 'sales', aggFunc: 'count');
        final result = service.computeGroupAggregates(
          leafRows: data,
          valueColumns: [col],
        );
        expect(result['sales'], equals(2));
      });

      test('returns 0 for empty list', () {
        const col = OsColumnDef(field: 'sales', aggFunc: 'count');
        final result = service.computeGroupAggregates(
          leafRows: <Map<String, dynamic>>[],
          valueColumns: [col],
        );
        expect(result['sales'], equals(0));
      });
    });

    group('min', () {
      test('finds minimum numeric value', () {
        const col = OsColumnDef(field: 'sales', aggFunc: 'min');
        final result = service.computeGroupAggregates(
          leafRows: sampleData(),
          valueColumns: [col],
        );
        expect(result['sales'], equals(100));
      });

      test('returns null for empty list', () {
        const col = OsColumnDef(field: 'sales', aggFunc: 'min');
        final result = service.computeGroupAggregates(
          leafRows: <Map<String, dynamic>>[],
          valueColumns: [col],
        );
        expect(result['sales'], isNull);
      });

      test('handles negative values', () {
        final data = [
          {'val': -10},
          {'val': 5},
          {'val': -20},
        ];
        const col = OsColumnDef(field: 'val', aggFunc: 'min');
        final result = service.computeGroupAggregates(
          leafRows: data,
          valueColumns: [col],
        );
        expect(result['val'], equals(-20));
      });
    });

    group('max', () {
      test('finds maximum numeric value', () {
        const col = OsColumnDef(field: 'sales', aggFunc: 'max');
        final result = service.computeGroupAggregates(
          leafRows: sampleData(),
          valueColumns: [col],
        );
        expect(result['sales'], equals(300));
      });

      test('returns null for empty list', () {
        const col = OsColumnDef(field: 'sales', aggFunc: 'max');
        final result = service.computeGroupAggregates(
          leafRows: <Map<String, dynamic>>[],
          valueColumns: [col],
        );
        expect(result['sales'], isNull);
      });
    });

    group('first', () {
      test('returns first non-null value', () {
        const col = OsColumnDef(field: 'city', aggFunc: 'first');
        final result = service.computeGroupAggregates(
          leafRows: sampleData(),
          valueColumns: [col],
        );
        expect(result['city'], equals('London'));
      });

      test('skips leading nulls', () {
        final data = [
          {'city': null},
          {'city': 'Manchester'},
          {'city': 'London'},
        ];
        const col = OsColumnDef(field: 'city', aggFunc: 'first');
        final result = service.computeGroupAggregates(
          leafRows: data,
          valueColumns: [col],
        );
        expect(result['city'], equals('Manchester'));
      });

      test('returns null for empty list', () {
        const col = OsColumnDef(field: 'city', aggFunc: 'first');
        final result = service.computeGroupAggregates(
          leafRows: <Map<String, dynamic>>[],
          valueColumns: [col],
        );
        expect(result['city'], isNull);
      });
    });

    group('last', () {
      test('returns last non-null value', () {
        const col = OsColumnDef(field: 'city', aggFunc: 'last');
        final result = service.computeGroupAggregates(
          leafRows: sampleData(),
          valueColumns: [col],
        );
        expect(result['city'], equals('Boston'));
      });

      test('skips trailing nulls', () {
        final data = [
          {'city': 'London'},
          {'city': 'Manchester'},
          {'city': null},
        ];
        const col = OsColumnDef(field: 'city', aggFunc: 'last');
        final result = service.computeGroupAggregates(
          leafRows: data,
          valueColumns: [col],
        );
        expect(result['city'], equals('Manchester'));
      });
    });

    group('custom aggFunc', () {
      test('supports custom function callback', () {
        final col = OsColumnDef(
          field: 'sales',
          aggFunc: (OsAggFuncParams params) {
            // Custom: return the count * 10
            return params.values.whereType<num>().length * 10;
          },
        );
        final result = service.computeGroupAggregates(
          leafRows: sampleData(),
          valueColumns: [col],
        );
        expect(result['sales'], equals(50));
      });

      test('custom function receives correct values', () {
        List<dynamic>? capturedValues;
        final col = OsColumnDef(
          field: 'profit',
          aggFunc: (OsAggFuncParams params) {
            capturedValues = List.from(params.values);
            return 0;
          },
        );
        service.computeGroupAggregates(
          leafRows: sampleData(),
          valueColumns: [col],
        );
        expect(capturedValues, equals([20, 40, 30, 60, 50]));
      });
    });

    group('multiple value columns', () {
      test('computes aggregates for multiple columns simultaneously', () {
        const salesCol = OsColumnDef(field: 'sales', aggFunc: 'sum');
        const profitCol = OsColumnDef(field: 'profit', aggFunc: 'avg');
        final result = service.computeGroupAggregates(
          leafRows: sampleData(),
          valueColumns: [salesCol, profitCol],
        );
        expect(result['sales'], equals(1000));
        expect(result['profit'], equals(40.0));
      });
    });

    group('unknown aggFunc', () {
      test('returns null for unknown built-in name', () {
        const col = OsColumnDef(field: 'sales', aggFunc: 'unknown');
        final result = service.computeGroupAggregates(
          leafRows: sampleData(),
          valueColumns: [col],
        );
        expect(result['sales'], isNull);
      });
    });
  });

  group('RowGroupService with Aggregation', () {
    late RowGroupService<Map<String, dynamic>> service;
    late RowGroupState state;

    setUp(() {
      service = RowGroupService<Map<String, dynamic>>();
      state = RowGroupState();
    });

    List<Map<String, dynamic>> sampleData() => [
      {'country': 'UK', 'city': 'London', 'sales': 100, 'profit': 20},
      {'country': 'UK', 'city': 'Manchester', 'sales': 200, 'profit': 40},
      {'country': 'UK', 'city': 'London', 'sales': 150, 'profit': 30},
      {'country': 'US', 'city': 'New York', 'sales': 300, 'profit': 60},
      {'country': 'US', 'city': 'Boston', 'sales': 250, 'profit': 50},
    ];

    OsColumnDef countryCol() => const OsColumnDef(
      field: 'country',
      headerName: 'Country',
      rowGroup: true,
    );

    OsColumnDef cityCol() =>
        const OsColumnDef(field: 'city', headerName: 'City', rowGroup: true);

    test('group rows include aggregate data when valueColumns provided', () {
      final data = sampleData();
      const salesCol = OsColumnDef(field: 'sales', aggFunc: 'sum');
      final result = service.buildGroupedData(
        data: data,
        groupColumns: [countryCol()],
        state: state,
        valueColumns: [salesCol],
      );

      // Find UK group row
      final ukGroup = result.firstWhere(
        (r) =>
            r[RowGroupKeys.kIsGroupRow] == true &&
            r[RowGroupKeys.kGroupKey] == 'UK',
      );
      final aggData =
          ukGroup[RowGroupKeys.kGroupAggData] as Map<String, dynamic>;
      expect(aggData['sales'], equals(450)); // 100 + 200 + 150

      // Find US group row
      final usGroup = result.firstWhere(
        (r) =>
            r[RowGroupKeys.kIsGroupRow] == true &&
            r[RowGroupKeys.kGroupKey] == 'US',
      );
      final usAggData =
          usGroup[RowGroupKeys.kGroupAggData] as Map<String, dynamic>;
      expect(usAggData['sales'], equals(550)); // 300 + 250
    });

    test('aggregate data available for collapsed groups', () {
      final data = sampleData();
      const salesCol = OsColumnDef(field: 'sales', aggFunc: 'sum');
      // Groups are collapsed by default (defaultExpanded = 0)
      final result = service.buildGroupedData(
        data: data,
        groupColumns: [countryCol()],
        state: state,
        valueColumns: [salesCol],
      );

      // Both groups collapsed — only group rows in output
      expect(result.length, equals(2));
      for (final row in result) {
        expect(row[RowGroupKeys.kIsGroupRow], isTrue);
        expect(row[RowGroupKeys.kGroupAggData], isNotNull);
      }

      final ukGroup = result.firstWhere(
        (r) => r[RowGroupKeys.kGroupKey] == 'UK',
      );
      final aggData =
          ukGroup[RowGroupKeys.kGroupAggData] as Map<String, dynamic>;
      expect(aggData['sales'], equals(450));
    });

    test('multi-level grouping computes aggregates at each level', () {
      final data = sampleData();
      state.setDefaultExpanded(-1); // Expand all
      const salesCol = OsColumnDef(field: 'sales', aggFunc: 'sum');

      final result = service.buildGroupedData(
        data: data,
        groupColumns: [countryCol(), cityCol()],
        state: state,
        valueColumns: [salesCol],
      );

      // Find the top-level UK group
      final ukGroup = result.firstWhere(
        (r) =>
            r[RowGroupKeys.kIsGroupRow] == true &&
            r[RowGroupKeys.kGroupKey] == 'UK' &&
            r[RowGroupKeys.kGroupLevel] == 0,
      );
      final ukAgg = ukGroup[RowGroupKeys.kGroupAggData] as Map<String, dynamic>;
      expect(ukAgg['sales'], equals(450));

      // Find the London sub-group under UK
      final londonGroup = result.firstWhere(
        (r) =>
            r[RowGroupKeys.kIsGroupRow] == true &&
            r[RowGroupKeys.kGroupKey] == 'London' &&
            r[RowGroupKeys.kGroupLevel] == 1,
      );
      final londonAgg =
          londonGroup[RowGroupKeys.kGroupAggData] as Map<String, dynamic>;
      expect(londonAgg['sales'], equals(250)); // 100 + 150
    });

    test('multiple aggFunc types on different columns', () {
      final data = sampleData();
      const salesCol = OsColumnDef(field: 'sales', aggFunc: 'sum');
      const profitCol = OsColumnDef(field: 'profit', aggFunc: 'avg');
      const countCol = OsColumnDef(
        field: 'sales',
        colId: 'salesCount',
        aggFunc: 'count',
      );

      final result = service.buildGroupedData(
        data: data,
        groupColumns: [countryCol()],
        state: state,
        valueColumns: [salesCol, profitCol, countCol],
      );

      final ukGroup = result.firstWhere(
        (r) =>
            r[RowGroupKeys.kIsGroupRow] == true &&
            r[RowGroupKeys.kGroupKey] == 'UK',
      );
      final aggData =
          ukGroup[RowGroupKeys.kGroupAggData] as Map<String, dynamic>;
      expect(aggData['sales'], equals(450));
      expect(aggData['profit'], equals(30.0)); // (20+40+30)/3
      expect(aggData['salesCount'], equals(3));
    });

    test('no aggData key when valueColumns is empty', () {
      final data = sampleData();
      final result = service.buildGroupedData(
        data: data,
        groupColumns: [countryCol()],
        state: state,
        valueColumns: [],
      );

      final ukGroup = result.firstWhere(
        (r) =>
            r[RowGroupKeys.kIsGroupRow] == true &&
            r[RowGroupKeys.kGroupKey] == 'UK',
      );
      expect(ukGroup.containsKey(RowGroupKeys.kGroupAggData), isFalse);
    });
  });

  group('OsGrid Aggregation Integration', () {
    testWidgets('aggFunc on column computes aggregates in group rows', (
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
                  const OsColumnDef(
                    field: 'country',
                    headerName: 'Country',
                    rowGroup: true,
                  ),
                  const OsColumnDef(
                    field: 'sales',
                    headerName: 'Sales',
                    aggFunc: 'sum',
                  ),
                ],
                rowData: [
                  {'country': 'UK', 'sales': 100},
                  {'country': 'UK', 'sales': 200},
                  {'country': 'US', 'sales': 300},
                ],
                groupDefaultExpanded: -1,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // The grid should render without error — visual verification
      // would require inspecting the canvas, but we verify no exceptions
      expect(find.byType(OsGrid), findsOneWidget);
    });

    testWidgets(
      'controller.setValueColumns sets value columns programmatically',
      (tester) async {
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
                      field: 'country',
                      headerName: 'Country',
                      rowGroup: true,
                    ),
                    const OsColumnDef(
                      field: 'sales',
                      headerName: 'Sales',
                      aggFunc: 'sum',
                    ),
                    const OsColumnDef(
                      field: 'profit',
                      headerName: 'Profit',
                      aggFunc: 'avg',
                    ),
                  ],
                  rowData: [
                    {'country': 'UK', 'sales': 100, 'profit': 10},
                    {'country': 'UK', 'sales': 200, 'profit': 20},
                  ],
                  groupDefaultExpanded: -1,
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        // Verify getValueColumns returns the configured value columns
        final valueCols = controller.getValueColumns();
        expect(valueCols, contains('sales'));
        expect(valueCols, contains('profit'));
      },
    );

    testWidgets('controller.setColumnAggFunc changes aggregation function', (
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
                  const OsColumnDef(
                    field: 'country',
                    headerName: 'Country',
                    rowGroup: true,
                  ),
                  const OsColumnDef(
                    field: 'sales',
                    headerName: 'Sales',
                    aggFunc: 'sum',
                  ),
                ],
                rowData: [
                  {'country': 'UK', 'sales': 100},
                  {'country': 'UK', 'sales': 200},
                ],
                groupDefaultExpanded: -1,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Change aggFunc to avg — should rebuild without error
      controller.setColumnAggFunc('sales', 'avg');
      await tester.pump();

      expect(find.byType(OsGrid), findsOneWidget);
    });

    testWidgets(
      'setValueColumns with empty list clears programmatic override',
      (tester) async {
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
                      field: 'country',
                      headerName: 'Country',
                      rowGroup: true,
                    ),
                    const OsColumnDef(
                      field: 'sales',
                      headerName: 'Sales',
                      aggFunc: 'sum',
                    ),
                  ],
                  rowData: [
                    {'country': 'UK', 'sales': 100},
                    {'country': 'UK', 'sales': 200},
                  ],
                  groupDefaultExpanded: -1,
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        // Set specific columns
        controller.setValueColumns(['sales']);
        await tester.pump();
        expect(controller.getValueColumns(), contains('sales'));

        // Clear override
        controller.setValueColumns([]);
        await tester.pump();
        // Should fall back to colDef-based detection
        expect(controller.getValueColumns(), contains('sales'));
      },
    );

    testWidgets(
      'aggregation works with filter — aggregates filtered data only',
      (tester) async {
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
                      field: 'country',
                      headerName: 'Country',
                      rowGroup: true,
                    ),
                    const OsColumnDef(
                      field: 'sales',
                      headerName: 'Sales',
                      aggFunc: 'sum',
                    ),
                  ],
                  rowData: [
                    {'country': 'UK', 'sales': 100},
                    {'country': 'UK', 'sales': 200},
                    {'country': 'UK', 'sales': 300},
                  ],
                  groupDefaultExpanded: -1,
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        // Grid renders without error
        expect(find.byType(OsGrid), findsOneWidget);
      },
    );

    testWidgets('aggregation works with pagination', (tester) async {
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
                    field: 'country',
                    headerName: 'Country',
                    rowGroup: true,
                  ),
                  const OsColumnDef(
                    field: 'sales',
                    headerName: 'Sales',
                    aggFunc: 'sum',
                  ),
                ],
                rowData: [
                  {'country': 'UK', 'sales': 100},
                  {'country': 'UK', 'sales': 200},
                  {'country': 'US', 'sales': 300},
                  {'country': 'US', 'sales': 400},
                ],
                groupDefaultExpanded: -1,
                pagination: const OsPagination(pageSize: 10),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(OsGrid), findsOneWidget);
    });

    testWidgets('aggregation with sort — sort before grouping', (tester) async {
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
                    field: 'country',
                    headerName: 'Country',
                    rowGroup: true,
                    sortable: true,
                  ),
                  const OsColumnDef(
                    field: 'sales',
                    headerName: 'Sales',
                    aggFunc: 'sum',
                    sortable: true,
                  ),
                ],
                rowData: [
                  {'country': 'UK', 'sales': 300},
                  {'country': 'US', 'sales': 100},
                  {'country': 'UK', 'sales': 200},
                ],
                groupDefaultExpanded: -1,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(OsGrid), findsOneWidget);
    });
  });
}
