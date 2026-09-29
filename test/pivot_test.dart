import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

void main() {
  group('PivotService', () {
    group('extractUniqueValues', () {
      test('extracts unique values from single pivot column', () {
        final service = PivotService<Map<String, dynamic>>();
        final data = [
          {'country': 'UK', 'year': '2020', 'sales': 100},
          {'country': 'UK', 'year': '2021', 'sales': 200},
          {'country': 'US', 'year': '2020', 'sales': 300},
          {'country': 'US', 'year': '2021', 'sales': 400},
          {'country': 'US', 'year': '2022', 'sales': 500},
        ];

        final pivotCols = [
          const OsColumnDef(field: 'year', headerName: 'Year'),
        ];

        final result = service.extractUniqueValues(
          data: data,
          pivotColumns: pivotCols,
        );

        expect(result.keys.toSet(), {'2020', '2021', '2022'});
      });

      test(
        'extracts unique values from multiple pivot columns (multi-level)',
        () {
          final service = PivotService<Map<String, dynamic>>();
          final data = [
            {'country': 'UK', 'year': '2020', 'quarter': 'Q1', 'sales': 100},
            {'country': 'UK', 'year': '2020', 'quarter': 'Q2', 'sales': 150},
            {'country': 'UK', 'year': '2021', 'quarter': 'Q1', 'sales': 200},
            {'country': 'US', 'year': '2020', 'quarter': 'Q1', 'sales': 300},
          ];

          final pivotCols = [
            const OsColumnDef(field: 'year', headerName: 'Year'),
            const OsColumnDef(field: 'quarter', headerName: 'Quarter'),
          ];

          final result = service.extractUniqueValues(
            data: data,
            pivotColumns: pivotCols,
          );

          expect(result.keys.toSet(), {'2020', '2021'});
          expect((result['2020'] as Map).keys.toSet(), {'Q1', 'Q2'});
          expect((result['2021'] as Map).keys.toSet(), {'Q1'});
        },
      );

      test('handles null/empty pivot values', () {
        final service = PivotService<Map<String, dynamic>>();
        final data = [
          {'country': 'UK', 'year': null, 'sales': 100},
          {'country': 'US', 'year': '2020', 'sales': 200},
          {'country': 'DE', 'year': '', 'sales': 300},
        ];

        final pivotCols = [
          const OsColumnDef(field: 'year', headerName: 'Year'),
        ];

        final result = service.extractUniqueValues(
          data: data,
          pivotColumns: pivotCols,
        );

        // null and empty both become '' key
        expect(result.keys.toSet(), {'', '2020'});
      });

      test('returns empty map when no data', () {
        final service = PivotService<Map<String, dynamic>>();
        final pivotCols = [
          const OsColumnDef(field: 'year', headerName: 'Year'),
        ];

        final result = service.extractUniqueValues(
          data: [],
          pivotColumns: pivotCols,
        );

        expect(result, isEmpty);
      });

      test('returns empty map when no pivot columns', () {
        final service = PivotService<Map<String, dynamic>>();
        final data = [
          {'year': '2020', 'sales': 100},
        ];

        final result = service.extractUniqueValues(
          data: data,
          pivotColumns: [],
        );

        expect(result, isEmpty);
      });
    });

    group('generatePivotColumns', () {
      test(
        'generates one column per unique value with single value column',
        () {
          final service = PivotService<Map<String, dynamic>>();
          final uniqueValues = <String, dynamic>{
            '2020': null,
            '2021': null,
            '2022': null,
          };

          final pivotCols = [
            const OsColumnDef(field: 'year', headerName: 'Year'),
          ];
          final valueCols = [
            const OsColumnDef(
              field: 'sales',
              headerName: 'Sales',
              aggFunc: 'sum',
            ),
          ];

          final result = service.generatePivotColumns(
            uniqueValues: uniqueValues,
            pivotColumns: pivotCols,
            valueColumns: valueCols,
          );

          expect(result.columns.length, 3);
          expect(result.columnDefs.length, 3);

          // With single value column, headers are just pivot values.
          expect(result.columnDefs[0].headerName, '2020');
          expect(result.columnDefs[1].headerName, '2021');
          expect(result.columnDefs[2].headerName, '2022');

          // Each has a unique colId.
          final colIds = result.columnDefs.map((c) => c.colId).toSet();
          expect(colIds.length, 3);
        },
      );

      test(
        'generates columns with combined header when multiple value columns',
        () {
          final service = PivotService<Map<String, dynamic>>();
          final uniqueValues = <String, dynamic>{'2020': null, '2021': null};

          final pivotCols = [
            const OsColumnDef(field: 'year', headerName: 'Year'),
          ];
          final valueCols = [
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
          ];

          final result = service.generatePivotColumns(
            uniqueValues: uniqueValues,
            pivotColumns: pivotCols,
            valueColumns: valueCols,
          );

          // 2 unique values × 2 value columns = 4 columns
          expect(result.columns.length, 4);
          expect(result.columnDefs.length, 4);

          // Headers include both pivot value and value column name.
          final headers = result.columnDefs.map((c) => c.headerName).toList();
          expect(headers, contains('2020 - Sales'));
          expect(headers, contains('2020 - Profit'));
          expect(headers, contains('2021 - Sales'));
          expect(headers, contains('2021 - Profit'));
        },
      );

      test('generates nested columns for multi-level pivot', () {
        final service = PivotService<Map<String, dynamic>>();
        final uniqueValues = <String, dynamic>{
          '2020': {'Q1': null, 'Q2': null},
          '2021': {'Q1': null},
        };

        final pivotCols = [
          const OsColumnDef(field: 'year', headerName: 'Year'),
          const OsColumnDef(field: 'quarter', headerName: 'Quarter'),
        ];
        final valueCols = [
          const OsColumnDef(
            field: 'sales',
            headerName: 'Sales',
            aggFunc: 'sum',
          ),
        ];

        final result = service.generatePivotColumns(
          uniqueValues: uniqueValues,
          pivotColumns: pivotCols,
          valueColumns: valueCols,
        );

        // 2020:Q1, 2020:Q2, 2021:Q1 = 3 columns
        expect(result.columns.length, 3);
        expect(result.columnDefs.length, 3);

        // With single value column, headers are the leaf pivot value.
        final headers = result.columnDefs.map((c) => c.headerName).toList();
        expect(headers, contains('Q1'));
        expect(headers, contains('Q2'));
      });

      test('generates placeholder column when no value columns', () {
        final service = PivotService<Map<String, dynamic>>();
        final uniqueValues = <String, dynamic>{'2020': null, '2021': null};

        final pivotCols = [
          const OsColumnDef(field: 'year', headerName: 'Year'),
        ];

        final result = service.generatePivotColumns(
          uniqueValues: uniqueValues,
          pivotColumns: pivotCols,
          valueColumns: [],
        );

        // One placeholder per unique value.
        expect(result.columns.length, 2);
        expect(result.columnDefs[0].headerName, '2020');
        expect(result.columnDefs[1].headerName, '2021');
      });

      test('pivot result columns have correct metadata', () {
        final service = PivotService<Map<String, dynamic>>();
        final uniqueValues = <String, dynamic>{'2020': null};

        final pivotCols = [
          const OsColumnDef(field: 'year', headerName: 'Year'),
        ];
        final valueCols = [
          const OsColumnDef(
            field: 'sales',
            headerName: 'Sales',
            aggFunc: 'sum',
          ),
        ];

        final result = service.generatePivotColumns(
          uniqueValues: uniqueValues,
          pivotColumns: pivotCols,
          valueColumns: valueCols,
        );

        final col = result.columns.first;
        expect(col.pivotKeys, ['2020']);
        expect(col.valueColId, 'sales');
        expect(col.valueColAggFunc, 'sum');
        expect(col.colId, contains('pivot_'));
        expect(col.colId, contains('2020'));
        expect(col.colId, contains('sales'));
      });
    });

    group('computePivotAggregation', () {
      test('computes aggregates per pivot bucket for group rows', () {
        final service = PivotService<Map<String, dynamic>>();

        final rawData = <Map<String, dynamic>>[
          {'country': 'UK', 'year': '2020', 'sales': 100},
          {'country': 'UK', 'year': '2020', 'sales': 50},
          {'country': 'UK', 'year': '2021', 'sales': 200},
          {'country': 'US', 'year': '2020', 'sales': 300},
          {'country': 'US', 'year': '2021', 'sales': 400},
        ];

        final groupCols = [
          const OsColumnDef(field: 'country', headerName: 'Country'),
        ];
        final pivotCols = [
          const OsColumnDef(field: 'year', headerName: 'Year'),
        ];
        final valueCols = [
          const OsColumnDef(
            field: 'sales',
            headerName: 'Sales',
            aggFunc: 'sum',
          ),
        ];

        // Generate pivot columns first.
        final uniqueValues = service.extractUniqueValues(
          data: rawData,
          pivotColumns: pivotCols,
        );
        final pivotResult = service.generatePivotColumns(
          uniqueValues: uniqueValues,
          pivotColumns: pivotCols,
          valueColumns: valueCols,
        );

        // Build a simple grouped display (manually constructed).
        final displayData = <Map<String, dynamic>>[
          {
            '__isGroupRow': true,
            '__groupKey': 'UK',
            '__groupField': 'country',
            '__groupLevel': 0,
            '__groupExpanded': true,
            '__groupChildCount': 3,
            '__groupNodeId': 'row-group-country-UK',
          },
          {'country': 'UK', 'year': '2020', 'sales': 100},
          {'country': 'UK', 'year': '2020', 'sales': 50},
          {'country': 'UK', 'year': '2021', 'sales': 200},
          {
            '__isGroupRow': true,
            '__groupKey': 'US',
            '__groupField': 'country',
            '__groupLevel': 0,
            '__groupExpanded': true,
            '__groupChildCount': 2,
            '__groupNodeId': 'row-group-country-US',
          },
          {'country': 'US', 'year': '2020', 'sales': 300},
          {'country': 'US', 'year': '2021', 'sales': 400},
        ];

        final result = service.computePivotAggregation(
          displayData: displayData,
          rawData: rawData,
          pivotColumns: pivotCols,
          valueColumns: valueCols,
          groupColumns: groupCols,
          pivotResultColumns: pivotResult.columns,
        );

        // Find the UK group row.
        final ukGroup = result.firstWhere(
          (r) => r['__groupNodeId'] == 'row-group-country-UK',
        );

        // The UK group should have aggregated values for 2020 and 2021.
        // Find the colId for 2020 sales.
        final col2020 = pivotResult.columns.firstWhere(
          (c) => c.pivotKeys.contains('2020'),
        );
        final col2021 = pivotResult.columns.firstWhere(
          (c) => c.pivotKeys.contains('2021'),
        );

        // UK 2020: 100 + 50 = 150
        expect(ukGroup[col2020.colId], 150);
        // UK 2021: 200
        expect(ukGroup[col2021.colId], 200);

        // Find the US group row.
        final usGroup = result.firstWhere(
          (r) => r['__groupNodeId'] == 'row-group-country-US',
        );

        // US 2020: 300
        expect(usGroup[col2020.colId], 300);
        // US 2021: 400
        expect(usGroup[col2021.colId], 400);
      });

      test('leaf rows get values placed at correct pivot column', () {
        final service = PivotService<Map<String, dynamic>>();

        final rawData = <Map<String, dynamic>>[
          {'country': 'UK', 'year': '2020', 'sales': 100},
          {'country': 'UK', 'year': '2021', 'sales': 200},
        ];

        final groupCols = [
          const OsColumnDef(field: 'country', headerName: 'Country'),
        ];
        final pivotCols = [
          const OsColumnDef(field: 'year', headerName: 'Year'),
        ];
        final valueCols = [
          const OsColumnDef(
            field: 'sales',
            headerName: 'Sales',
            aggFunc: 'sum',
          ),
        ];

        final uniqueValues = service.extractUniqueValues(
          data: rawData,
          pivotColumns: pivotCols,
        );
        final pivotResult = service.generatePivotColumns(
          uniqueValues: uniqueValues,
          pivotColumns: pivotCols,
          valueColumns: valueCols,
        );

        final displayData = <Map<String, dynamic>>[
          {'country': 'UK', 'year': '2020', 'sales': 100},
          {'country': 'UK', 'year': '2021', 'sales': 200},
        ];

        final result = service.computePivotAggregation(
          displayData: displayData,
          rawData: rawData,
          pivotColumns: pivotCols,
          valueColumns: valueCols,
          groupColumns: groupCols,
          pivotResultColumns: pivotResult.columns,
        );

        final col2020 = pivotResult.columns.firstWhere(
          (c) => c.pivotKeys.contains('2020'),
        );
        final col2021 = pivotResult.columns.firstWhere(
          (c) => c.pivotKeys.contains('2021'),
        );

        // First row (year=2020) should have value at 2020 column.
        expect(result[0][col2020.colId], 100);
        expect(result[0].containsKey(col2021.colId), false);

        // Second row (year=2021) should have value at 2021 column.
        expect(result[1][col2021.colId], 200);
        expect(result[1].containsKey(col2020.colId), false);
      });

      test('works with avg aggregation function', () {
        final service = PivotService<Map<String, dynamic>>();

        final rawData = <Map<String, dynamic>>[
          {'country': 'UK', 'year': '2020', 'sales': 100},
          {'country': 'UK', 'year': '2020', 'sales': 200},
          {'country': 'UK', 'year': '2021', 'sales': 300},
        ];

        final groupCols = [
          const OsColumnDef(field: 'country', headerName: 'Country'),
        ];
        final pivotCols = [
          const OsColumnDef(field: 'year', headerName: 'Year'),
        ];
        final valueCols = [
          const OsColumnDef(
            field: 'sales',
            headerName: 'Sales',
            aggFunc: 'avg',
          ),
        ];

        final uniqueValues = service.extractUniqueValues(
          data: rawData,
          pivotColumns: pivotCols,
        );
        final pivotResult = service.generatePivotColumns(
          uniqueValues: uniqueValues,
          pivotColumns: pivotCols,
          valueColumns: valueCols,
        );

        final displayData = <Map<String, dynamic>>[
          {
            '__isGroupRow': true,
            '__groupKey': 'UK',
            '__groupField': 'country',
            '__groupLevel': 0,
            '__groupExpanded': false,
            '__groupChildCount': 3,
            '__groupNodeId': 'row-group-country-UK',
          },
        ];

        final result = service.computePivotAggregation(
          displayData: displayData,
          rawData: rawData,
          pivotColumns: pivotCols,
          valueColumns: valueCols,
          groupColumns: groupCols,
          pivotResultColumns: pivotResult.columns,
        );

        final col2020 = pivotResult.columns.firstWhere(
          (c) => c.pivotKeys.contains('2020'),
        );
        final col2021 = pivotResult.columns.firstWhere(
          (c) => c.pivotKeys.contains('2021'),
        );

        // UK 2020 avg: (100 + 200) / 2 = 150.0
        expect(result[0][col2020.colId], 150.0);
        // UK 2021 avg: 300 / 1 = 300.0
        expect(result[0][col2021.colId], 300.0);
      });

      test('group keys containing dashes still match pivot buckets', () {
        final service = PivotService<Map<String, dynamic>>();

        final rawData = <Map<String, dynamic>>[
          {'region': 'North-America', 'year': '2020', 'sales': 100},
          {'region': 'North-America', 'year': '2021', 'sales': 250},
        ];

        final groupCols = [
          const OsColumnDef(field: 'region', headerName: 'Region'),
        ];
        final pivotCols = [
          const OsColumnDef(field: 'year', headerName: 'Year'),
        ];
        final valueCols = [
          const OsColumnDef(
            field: 'sales',
            headerName: 'Sales',
            aggFunc: 'sum',
          ),
        ];

        final uniqueValues = service.extractUniqueValues(
          data: rawData,
          pivotColumns: pivotCols,
        );
        final pivotResult = service.generatePivotColumns(
          uniqueValues: uniqueValues,
          pivotColumns: pivotCols,
          valueColumns: valueCols,
        );

        // The display row's node ID uses RowGroupService's escaping scheme:
        // the dash inside 'North-America' becomes '--'.
        const nodeId = 'row-group-region-North--America';
        expect(
          RowGroupService.makeNodeId('', 'region', 'North-America'),
          nodeId,
        );
        expect(
          RowGroupService.makeNodeId('', 'region', 'North-America'),
          isNot('row-group-region-North-America'),
        );

        final displayData = <Map<String, dynamic>>[
          {
            '__isGroupRow': true,
            '__groupKey': 'North-America',
            '__groupField': 'region',
            '__groupLevel': 0,
            '__groupExpanded': false,
            '__groupChildCount': 2,
            '__groupNodeId': nodeId,
          },
        ];

        final result = service.computePivotAggregation(
          displayData: displayData,
          rawData: rawData,
          pivotColumns: pivotCols,
          valueColumns: valueCols,
          groupColumns: groupCols,
          pivotResultColumns: pivotResult.columns,
        );

        // Aggregates must be non-empty — bucket lookups must find rows
        // whose group key contains '-'.
        expect(result[0][RowGroupKeys.kGroupAggData], isNotEmpty);

        final col2020 = pivotResult.columns.firstWhere(
          (c) => c.pivotKeys.contains('2020'),
        );
        final col2021 = pivotResult.columns.firstWhere(
          (c) => c.pivotKeys.contains('2021'),
        );

        // North-America 2020: 100
        expect(result[0][col2020.colId], 100);
        // North-America 2021: 250
        expect(result[0][col2021.colId], 250);
      });

      test('multi-level pivot computes correctly', () {
        final service = PivotService<Map<String, dynamic>>();

        final rawData = <Map<String, dynamic>>[
          {'country': 'UK', 'year': '2020', 'quarter': 'Q1', 'sales': 100},
          {'country': 'UK', 'year': '2020', 'quarter': 'Q2', 'sales': 150},
          {'country': 'UK', 'year': '2021', 'quarter': 'Q1', 'sales': 200},
        ];

        final groupCols = [
          const OsColumnDef(field: 'country', headerName: 'Country'),
        ];
        final pivotCols = [
          const OsColumnDef(field: 'year', headerName: 'Year'),
          const OsColumnDef(field: 'quarter', headerName: 'Quarter'),
        ];
        final valueCols = [
          const OsColumnDef(
            field: 'sales',
            headerName: 'Sales',
            aggFunc: 'sum',
          ),
        ];

        final uniqueValues = service.extractUniqueValues(
          data: rawData,
          pivotColumns: pivotCols,
        );
        final pivotResult = service.generatePivotColumns(
          uniqueValues: uniqueValues,
          pivotColumns: pivotCols,
          valueColumns: valueCols,
        );

        // Multi-level: 2020-Q1, 2020-Q2, 2021-Q1 = 3 columns
        expect(pivotResult.columns.length, 3);

        final displayData = <Map<String, dynamic>>[
          {
            '__isGroupRow': true,
            '__groupKey': 'UK',
            '__groupField': 'country',
            '__groupLevel': 0,
            '__groupExpanded': false,
            '__groupChildCount': 3,
            '__groupNodeId': 'row-group-country-UK',
          },
        ];

        final result = service.computePivotAggregation(
          displayData: displayData,
          rawData: rawData,
          pivotColumns: pivotCols,
          valueColumns: valueCols,
          groupColumns: groupCols,
          pivotResultColumns: pivotResult.columns,
        );

        // Find 2020-Q1 column.
        final col2020Q1 = pivotResult.columns.firstWhere(
          (c) => c.pivotKeys[0] == '2020' && c.pivotKeys[1] == 'Q1',
        );
        final col2020Q2 = pivotResult.columns.firstWhere(
          (c) => c.pivotKeys[0] == '2020' && c.pivotKeys[1] == 'Q2',
        );
        final col2021Q1 = pivotResult.columns.firstWhere(
          (c) => c.pivotKeys[0] == '2021' && c.pivotKeys[1] == 'Q1',
        );

        expect(result[0][col2020Q1.colId], 100);
        expect(result[0][col2020Q2.colId], 150);
        expect(result[0][col2021Q1.colId], 200);
      });

      test('leaf rows honour valueGetter on the value column', () {
        final service = PivotService<Map<String, dynamic>>();

        final rawData = <Map<String, dynamic>>[
          {'country': 'UK', 'year': '2020', 'qty': 2, 'price': 50},
          {'country': 'UK', 'year': '2021', 'qty': 3, 'price': 10},
        ];

        final groupCols = [
          const OsColumnDef(field: 'country', headerName: 'Country'),
        ];
        final pivotCols = [
          const OsColumnDef(field: 'year', headerName: 'Year'),
        ];
        // No 'revenue' field exists in the data — only a valueGetter
        // can produce it.
        final valueCols = [
          OsColumnDef(
            field: 'revenue',
            headerName: 'Revenue',
            aggFunc: 'sum',
            valueGetter: (params) {
              final data = params.data as Map<String, dynamic>;
              return (data['qty'] as int) * (data['price'] as int);
            },
          ),
        ];

        final uniqueValues = service.extractUniqueValues(
          data: rawData,
          pivotColumns: pivotCols,
        );
        final pivotResult = service.generatePivotColumns(
          uniqueValues: uniqueValues,
          pivotColumns: pivotCols,
          valueColumns: valueCols,
        );

        final displayData = <Map<String, dynamic>>[
          {'country': 'UK', 'year': '2020', 'qty': 2, 'price': 50},
          {'country': 'UK', 'year': '2021', 'qty': 3, 'price': 10},
        ];

        final result = service.computePivotAggregation(
          displayData: displayData,
          rawData: rawData,
          pivotColumns: pivotCols,
          valueColumns: valueCols,
          groupColumns: groupCols,
          pivotResultColumns: pivotResult.columns,
        );

        final col2020 = pivotResult.columns.firstWhere(
          (c) => c.pivotKeys.contains('2020'),
        );
        final col2021 = pivotResult.columns.firstWhere(
          (c) => c.pivotKeys.contains('2021'),
        );

        expect(
          result[0][col2020.colId],
          100,
          reason: 'leaf cell extracted via the value column valueGetter',
        );
        expect(result[1][col2021.colId], 30);
      });

      test('leaf rows honour valueGetter on pivot (dimension) columns', () {
        final service = PivotService<Map<String, dynamic>>();

        final rawData = <Map<String, dynamic>>[
          {'country': 'UK', 'year': 2020, 'sales': 100},
          {'country': 'UK', 'year': 2021, 'sales': 200},
        ];

        final groupCols = [
          const OsColumnDef(field: 'country', headerName: 'Country'),
        ];
        // The pivot dimension is derived by a getter ('FY2020'), not the
        // raw field value (2020).
        final pivotCols = [
          OsColumnDef(
            field: 'year',
            headerName: 'Year',
            valueGetter: (params) =>
                'FY${(params.data as Map<String, dynamic>)['year']}',
          ),
        ];
        final valueCols = [
          const OsColumnDef(
            field: 'sales',
            headerName: 'Sales',
            aggFunc: 'sum',
          ),
        ];

        final uniqueValues = service.extractUniqueValues(
          data: rawData,
          pivotColumns: pivotCols,
        );
        final pivotResult = service.generatePivotColumns(
          uniqueValues: uniqueValues,
          pivotColumns: pivotCols,
          valueColumns: valueCols,
        );

        // Column keys come from the getter ('FY2020'), not the field.
        expect(pivotResult.columns.map((c) => c.pivotKeys.last).toSet(), {
          'FY2020',
          'FY2021',
        });

        final displayData = <Map<String, dynamic>>[
          {'country': 'UK', 'year': 2020, 'sales': 100},
          {'country': 'UK', 'year': 2021, 'sales': 200},
        ];

        final result = service.computePivotAggregation(
          displayData: displayData,
          rawData: rawData,
          pivotColumns: pivotCols,
          valueColumns: valueCols,
          groupColumns: groupCols,
          pivotResultColumns: pivotResult.columns,
        );

        final colFY2020 = pivotResult.columns.firstWhere(
          (c) => c.pivotKeys.contains('FY2020'),
        );
        final colFY2021 = pivotResult.columns.firstWhere(
          (c) => c.pivotKeys.contains('FY2021'),
        );

        expect(
          result[0][colFY2020.colId],
          100,
          reason:
              'leaf bucket matching uses the same getter-aware '
              'extraction as column generation',
        );
        expect(result[1][colFY2021.colId], 200);
      });
    });
  });

  group('OsGrid pivot mode integration', () {
    testWidgets('pivot mode generates dynamic columns', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();
      final data = <Map<String, dynamic>>[
        {'country': 'UK', 'year': '2020', 'sales': 100},
        {'country': 'UK', 'year': '2021', 'sales': 200},
        {'country': 'US', 'year': '2020', 'sales': 300},
        {'country': 'US', 'year': '2021', 'sales': 400},
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: OsGrid<Map<String, dynamic>>(
                controller: controller,
                rowData: data,
                pivotMode: true,
                groupBy: const ['country'],
                columnDefs: [
                  const OsColumnDef(
                    field: 'country',
                    headerName: 'Country',
                    rowGroup: true,
                  ),
                  const OsColumnDef(
                    field: 'year',
                    headerName: 'Year',
                    pivot: true,
                  ),
                  const OsColumnDef(
                    field: 'sales',
                    headerName: 'Sales',
                    aggFunc: 'sum',
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Controller should report pivot mode is active.
      expect(controller.isPivotMode(), true);

      // Controller should report pivot columns.
      expect(controller.getPivotColumns(), ['year']);

      // Pivot result columns should be generated.
      final pivotResultCols = controller.getPivotResultColumns();
      expect(pivotResultCols.length, 2); // 2020, 2021

      controller.dispose();
    });

    testWidgets('setPivotMode toggles pivot on/off', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();
      final events = <OsPivotModeChangedEvent>[];
      final data = <Map<String, dynamic>>[
        {'country': 'UK', 'year': '2020', 'sales': 100},
        {'country': 'UK', 'year': '2021', 'sales': 200},
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: OsGrid<Map<String, dynamic>>(
                controller: controller,
                rowData: data,
                onPivotModeChanged: (e) => events.add(e),
                groupBy: const ['country'],
                columnDefs: [
                  const OsColumnDef(
                    field: 'country',
                    headerName: 'Country',
                    rowGroup: true,
                  ),
                  const OsColumnDef(
                    field: 'year',
                    headerName: 'Year',
                    pivot: true,
                  ),
                  const OsColumnDef(
                    field: 'sales',
                    headerName: 'Sales',
                    aggFunc: 'sum',
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Initially not in pivot mode.
      expect(controller.isPivotMode(), false);

      // Enable pivot mode.
      controller.setPivotMode(true);
      await tester.pump();

      expect(controller.isPivotMode(), true);
      expect(events.length, 1);
      expect(events.first.pivotMode, true);

      // Disable pivot mode.
      controller.setPivotMode(false);
      await tester.pump();

      expect(controller.isPivotMode(), false);
      expect(events.length, 2);
      expect(events.last.pivotMode, false);

      controller.dispose();
    });

    testWidgets('setPivotColumns programmatically changes pivot columns', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();
      final data = <Map<String, dynamic>>[
        {'country': 'UK', 'year': '2020', 'quarter': 'Q1', 'sales': 100},
        {'country': 'UK', 'year': '2021', 'quarter': 'Q2', 'sales': 200},
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: OsGrid<Map<String, dynamic>>(
                controller: controller,
                rowData: data,
                pivotMode: true,
                groupBy: const ['country'],
                columnDefs: [
                  const OsColumnDef(
                    field: 'country',
                    headerName: 'Country',
                    rowGroup: true,
                  ),
                  const OsColumnDef(field: 'year', headerName: 'Year'),
                  const OsColumnDef(field: 'quarter', headerName: 'Quarter'),
                  const OsColumnDef(
                    field: 'sales',
                    headerName: 'Sales',
                    aggFunc: 'sum',
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // No pivot columns initially (none marked with pivot: true).
      expect(controller.getPivotColumns(), isEmpty);
      expect(controller.getPivotResultColumns(), isEmpty);

      // Set pivot columns programmatically.
      controller.setPivotColumns(['year']);
      await tester.pump();

      expect(controller.getPivotColumns(), ['year']);
      expect(controller.getPivotResultColumns().length, 2); // 2020, 2021

      controller.dispose();
    });

    testWidgets('pivot mode without group columns produces no pivot columns', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();
      final data = <Map<String, dynamic>>[
        {'year': '2020', 'sales': 100},
        {'year': '2021', 'sales': 200},
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: OsGrid<Map<String, dynamic>>(
                controller: controller,
                rowData: data,
                pivotMode: true,
                columnDefs: [
                  const OsColumnDef(
                    field: 'year',
                    headerName: 'Year',
                    pivot: true,
                  ),
                  const OsColumnDef(
                    field: 'sales',
                    headerName: 'Sales',
                    aggFunc: 'sum',
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Without group columns, pivot doesn't activate.
      expect(controller.getPivotResultColumns(), isEmpty);

      controller.dispose();
    });

    testWidgets('OsColumnDef.pivot property is set correctly', (tester) async {
      const col = OsColumnDef(field: 'year', pivot: true);
      expect(col.pivot, true);

      const col2 = OsColumnDef(field: 'name');
      expect(col2.pivot, isNull);
    });
  });

  group('pivot ordering', () {
    test('numeric pivot keys order 1, 2, 10 (not lexicographically)', () {
      final service = PivotService<Map<String, dynamic>>();
      // Deliberately scrambled first-seen order.
      final data = [
        {'tier': 10, 'sales': 100},
        {'tier': 1, 'sales': 200},
        {'tier': 2, 'sales': 300},
      ];
      final pivotCols = [const OsColumnDef(field: 'tier')];

      final uniqueValues = service.extractUniqueValues(
        data: data,
        pivotColumns: pivotCols,
      );
      final result = service.generatePivotColumns(
        uniqueValues: uniqueValues,
        pivotColumns: pivotCols,
        valueColumns: [
          const OsColumnDef(
            field: 'sales',
            headerName: 'Sales',
            aggFunc: 'sum',
          ),
        ],
      );

      expect(result.columnDefs.map((c) => c.headerName).toList(), [
        '1',
        '2',
        '10',
      ]);
    });

    test(
      'numeric string keys with decimals and negatives order numerically',
      () {
        final service = PivotService<Map<String, dynamic>>();
        final uniqueValues = <String, dynamic>{
          '100': null,
          '-5': null,
          '2.5': null,
          '10': null,
        };

        final result = service.generatePivotColumns(
          uniqueValues: uniqueValues,
          pivotColumns: [const OsColumnDef(field: 'score')],
          valueColumns: [
            const OsColumnDef(
              field: 'sales',
              headerName: 'Sales',
              aggFunc: 'sum',
            ),
          ],
        );

        expect(result.columnDefs.map((c) => c.headerName).toList(), [
          '-5',
          '2.5',
          '10',
          '100',
        ]);
      },
    );

    test('custom comparator on the pivot column is honored', () {
      final service = PivotService<Map<String, dynamic>>();
      const monthRank = {'Mar': 0, 'Jan': 1, 'Feb': 2};
      final pivotCols = [
        OsColumnDef(
          field: 'month',
          comparator: (a, b, nodeA, nodeB, isDescending) =>
              (monthRank[a] ?? 99).compareTo(monthRank[b] ?? 99),
        ),
      ];
      final data = [
        {'month': 'Jan', 'sales': 100},
        {'month': 'Feb', 'sales': 200},
        {'month': 'Mar', 'sales': 300},
      ];

      final uniqueValues = service.extractUniqueValues(
        data: data,
        pivotColumns: pivotCols,
      );
      final result = service.generatePivotColumns(
        uniqueValues: uniqueValues,
        pivotColumns: pivotCols,
        valueColumns: [
          const OsColumnDef(
            field: 'sales',
            headerName: 'Sales',
            aggFunc: 'sum',
          ),
        ],
      );

      expect(result.columnDefs.map((c) => c.headerName).toList(), [
        'Mar',
        'Jan',
        'Feb',
      ]);
    });

    test('comparator receives coerced numeric keys as num values', () {
      final service = PivotService<Map<String, dynamic>>();
      final numericPairs = <bool>[];
      final pivotCols = [
        OsColumnDef(
          field: 'tier',
          comparator: (a, b, nodeA, nodeB, isDescending) {
            numericPairs.add(a is num && b is num);
            return (a as num).compareTo(b as num);
          },
        ),
      ];
      final data = [
        {'tier': 2, 'sales': 100},
        {'tier': 1, 'sales': 200},
      ];

      final uniqueValues = service.extractUniqueValues(
        data: data,
        pivotColumns: pivotCols,
      );
      final result = service.generatePivotColumns(
        uniqueValues: uniqueValues,
        pivotColumns: pivotCols,
        valueColumns: [
          const OsColumnDef(
            field: 'sales',
            headerName: 'Sales',
            aggFunc: 'sum',
          ),
        ],
      );

      expect(numericPairs, everyElement(isTrue));
      expect(result.columnDefs.map((c) => c.headerName).toList(), ['1', '2']);
    });

    test('ties keep first-seen (insertion) order', () {
      final service = PivotService<Map<String, dynamic>>();
      final pivotCols = [
        const OsColumnDef(
          field: 'grp',
          // Constant comparator — every comparison ties.
          comparator: _alwaysTieComparator,
        ),
      ];
      final data = [
        {'grp': 'b', 'sales': 100},
        {'grp': 'a', 'sales': 200},
        {'grp': 'c', 'sales': 300},
      ];

      final uniqueValues = service.extractUniqueValues(
        data: data,
        pivotColumns: pivotCols,
      );
      final result = service.generatePivotColumns(
        uniqueValues: uniqueValues,
        pivotColumns: pivotCols,
        valueColumns: [
          const OsColumnDef(
            field: 'sales',
            headerName: 'Sales',
            aggFunc: 'sum',
          ),
        ],
      );

      expect(result.columnDefs.map((c) => c.headerName).toList(), [
        'b',
        'a',
        'c',
      ]);
    });
  });
}

/// Comparator that always reports equality (for tie-break tests).
int _alwaysTieComparator(
  dynamic a,
  dynamic b,
  dynamic nodeA,
  dynamic nodeB,
  bool isDescending,
) => 0;
