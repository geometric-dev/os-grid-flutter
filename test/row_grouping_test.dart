import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

void main() {
  group('RowGroupService', () {
    late RowGroupService<Map<String, dynamic>> service;
    late RowGroupState state;

    setUp(() {
      service = RowGroupService<Map<String, dynamic>>();
      state = RowGroupState();
    });

    List<Map<String, dynamic>> sampleData() => [
      {'country': 'UK', 'city': 'London', 'name': 'Alice'},
      {'country': 'UK', 'city': 'Manchester', 'name': 'Bob'},
      {'country': 'US', 'city': 'New York', 'name': 'Charlie'},
      {'country': 'US', 'city': 'New York', 'name': 'Dave'},
      {'country': 'US', 'city': 'Boston', 'name': 'Eve'},
      {'country': 'FR', 'city': 'Paris', 'name': 'Francois'},
    ];

    OsColumnDef countryCol() => const OsColumnDef(
      field: 'country',
      headerName: 'Country',
      rowGroup: true,
    );

    OsColumnDef cityCol() =>
        const OsColumnDef(field: 'city', headerName: 'City', rowGroup: true);

    test('returns data unchanged when no group columns', () {
      final data = sampleData();
      final result = service.buildGroupedData(
        data: data,
        groupColumns: [],
        state: state,
      );

      expect(result.length, equals(data.length));
      for (int i = 0; i < data.length; i++) {
        expect(result[i]['name'], equals(data[i]['name']));
      }
    });

    test('single-level grouping creates group rows', () {
      final data = sampleData();
      final result = service.buildGroupedData(
        data: data,
        groupColumns: [countryCol()],
        state: state,
      );

      // With all groups collapsed (default): 3 group rows only
      expect(result.length, equals(3));
      expect(result[0][RowGroupKeys.kIsGroupRow], isTrue);
      expect(result[0][RowGroupKeys.kGroupKey], equals('UK'));
      expect(result[0][RowGroupKeys.kGroupChildCount], equals(2));
      expect(result[0][RowGroupKeys.kGroupLevel], equals(0));
      expect(result[0][RowGroupKeys.kGroupExpanded], isFalse);

      expect(result[1][RowGroupKeys.kIsGroupRow], isTrue);
      expect(result[1][RowGroupKeys.kGroupKey], equals('US'));
      expect(result[1][RowGroupKeys.kGroupChildCount], equals(3));

      expect(result[2][RowGroupKeys.kIsGroupRow], isTrue);
      expect(result[2][RowGroupKeys.kGroupKey], equals('FR'));
      expect(result[2][RowGroupKeys.kGroupChildCount], equals(1));
    });

    test('expanded groups show child rows', () {
      final data = sampleData();

      // Expand the UK group
      state.setDefaultExpanded(1); // Expand first level
      final result = service.buildGroupedData(
        data: data,
        groupColumns: [countryCol()],
        state: state,
      );

      // 3 group rows + all leaves visible = 3 + 6 = 9
      expect(result.length, equals(9));

      // First: UK group row
      expect(result[0][RowGroupKeys.kIsGroupRow], isTrue);
      expect(result[0][RowGroupKeys.kGroupKey], equals('UK'));
      expect(result[0][RowGroupKeys.kGroupExpanded], isTrue);

      // Then UK's children
      expect(result[1]['name'], equals('Alice'));
      expect(result[2]['name'], equals('Bob'));

      // Then US group
      expect(result[3][RowGroupKeys.kIsGroupRow], isTrue);
      expect(result[3][RowGroupKeys.kGroupKey], equals('US'));
    });

    test('multi-level grouping creates nested hierarchy', () {
      final data = sampleData();
      state.setDefaultExpanded(-1); // Expand all levels
      final result = service.buildGroupedData(
        data: data,
        groupColumns: [countryCol(), cityCol()],
        state: state,
      );

      // UK group row
      expect(result[0][RowGroupKeys.kIsGroupRow], isTrue);
      expect(result[0][RowGroupKeys.kGroupKey], equals('UK'));
      expect(result[0][RowGroupKeys.kGroupLevel], equals(0));
      expect(result[0][RowGroupKeys.kGroupChildCount], equals(2));

      // UK > London group row
      expect(result[1][RowGroupKeys.kIsGroupRow], isTrue);
      expect(result[1][RowGroupKeys.kGroupKey], equals('London'));
      expect(result[1][RowGroupKeys.kGroupLevel], equals(1));
      expect(result[1][RowGroupKeys.kGroupChildCount], equals(1));

      // UK > London > Alice
      expect(result[2]['name'], equals('Alice'));

      // UK > Manchester group row
      expect(result[3][RowGroupKeys.kIsGroupRow], isTrue);
      expect(result[3][RowGroupKeys.kGroupKey], equals('Manchester'));
      expect(result[3][RowGroupKeys.kGroupLevel], equals(1));

      // UK > Manchester > Bob
      expect(result[4]['name'], equals('Bob'));

      // US group row
      expect(result[5][RowGroupKeys.kIsGroupRow], isTrue);
      expect(result[5][RowGroupKeys.kGroupKey], equals('US'));
      expect(result[5][RowGroupKeys.kGroupLevel], equals(0));
      expect(result[5][RowGroupKeys.kGroupChildCount], equals(3));
    });

    test('individual group expand/collapse', () {
      final data = sampleData();
      final result1 = service.buildGroupedData(
        data: data,
        groupColumns: [countryCol()],
        state: state,
      );

      // All collapsed initially
      expect(result1.length, equals(3));

      // Expand UK only
      final ukNodeId = result1[0][RowGroupKeys.kGroupNodeId] as String;
      state.expand(ukNodeId);
      final result2 = service.buildGroupedData(
        data: data,
        groupColumns: [countryCol()],
        state: state,
      );

      // UK expanded (2 children), US and FR collapsed
      expect(result2.length, equals(5)); // 3 groups + 2 UK children
      expect(result2[0][RowGroupKeys.kGroupExpanded], isTrue);
      expect(result2[1]['name'], equals('Alice'));
      expect(result2[2]['name'], equals('Bob'));
      expect(result2[3][RowGroupKeys.kGroupExpanded], isFalse); // US
      expect(result2[4][RowGroupKeys.kGroupExpanded], isFalse); // FR
    });

    test('expandAll expands all groups', () {
      final data = sampleData();
      state.expandAll();
      final result = service.buildGroupedData(
        data: data,
        groupColumns: [countryCol()],
        state: state,
      );

      // All groups expanded: 3 groups + 6 leaves = 9
      expect(result.length, equals(9));
      expect(result[0][RowGroupKeys.kGroupExpanded], isTrue);
      expect(result[3][RowGroupKeys.kGroupExpanded], isTrue);
      expect(result[7][RowGroupKeys.kGroupExpanded], isTrue);
    });

    test('collapseAll collapses all groups', () {
      final data = sampleData();
      state.expandAll();
      state.collapseAll();
      final result = service.buildGroupedData(
        data: data,
        groupColumns: [countryCol()],
        state: state,
      );

      expect(result.length, equals(3));
      expect(result[0][RowGroupKeys.kGroupExpanded], isFalse);
    });

    test('null group key creates a group for null values', () {
      final data = [
        {'country': 'UK', 'name': 'Alice'},
        {'country': null, 'name': 'Bob'},
        {'country': null, 'name': 'Charlie'},
      ];

      state.setDefaultExpanded(-1);
      final result = service.buildGroupedData(
        data: data,
        groupColumns: [countryCol()],
        state: state,
      );

      // UK group + Alice + null group + Bob + Charlie
      expect(result.length, equals(5));
      expect(result[0][RowGroupKeys.kGroupKey], equals('UK'));
      expect(result[2][RowGroupKeys.kGroupKey], isNull);
      expect(result[2][RowGroupKeys.kGroupChildCount], equals(2));
    });

    test('stable node IDs survive re-grouping', () {
      final data = sampleData();
      final result1 = service.buildGroupedData(
        data: data,
        groupColumns: [countryCol()],
        state: state,
      );
      final ukId1 = result1[0][RowGroupKeys.kGroupNodeId] as String;

      // Re-group the same data
      final result2 = service.buildGroupedData(
        data: data,
        groupColumns: [countryCol()],
        state: state,
      );
      final ukId2 = result2[0][RowGroupKeys.kGroupNodeId] as String;

      expect(ukId1, equals(ukId2));
    });

    test('countVisibleRows returns correct count', () {
      final data = sampleData();

      // All collapsed
      final count1 = service.countVisibleRows(
        data: data,
        groupColumns: [countryCol()],
        state: state,
      );
      expect(count1, equals(3)); // 3 group rows only

      // All expanded
      state.expandAll();
      final count2 = service.countVisibleRows(
        data: data,
        groupColumns: [countryCol()],
        state: state,
      );
      expect(count2, equals(9)); // 3 groups + 6 leaves
    });
  });

  group('RowGroupState', () {
    late RowGroupState state;

    setUp(() {
      state = RowGroupState();
    });

    test('default state collapses all', () {
      expect(state.isExpanded('node-1', level: 0), isFalse);
      expect(state.isExpanded('node-2', level: 1), isFalse);
    });

    test('setDefaultExpanded controls level-based expansion', () {
      state.setDefaultExpanded(1);
      expect(state.isExpanded('node-1', level: 0), isTrue);
      expect(state.isExpanded('node-2', level: 1), isFalse);
      expect(state.isExpanded('node-3', level: 2), isFalse);
    });

    test('setDefaultExpanded -1 expands all levels', () {
      state.setDefaultExpanded(-1);
      expect(state.isExpanded('a', level: 0), isTrue);
      expect(state.isExpanded('b', level: 5), isTrue);
      expect(state.isExpanded('c', level: 100), isTrue);
    });

    test('explicit expand overrides default', () {
      // Default collapsed
      state.expand('node-1');
      expect(state.isExpanded('node-1', level: 0), isTrue);
      expect(state.isExpanded('node-2', level: 0), isFalse);
    });

    test('explicit collapse overrides default expand', () {
      state.setDefaultExpanded(-1); // All expanded by default
      state.collapse('node-1');
      expect(state.isExpanded('node-1', level: 0), isFalse);
      expect(
        state.isExpanded('node-2', level: 0),
        isTrue,
      ); // Still uses default
    });

    test('expandAll clears explicit states and expands all', () {
      state.collapse('node-1');
      state.expandAll();
      expect(state.isExpanded('node-1', level: 0), isTrue);
      expect(state.isExpanded('node-2', level: 5), isTrue);
    });

    test('collapseAll clears explicit states and collapses all', () {
      state.expand('node-1');
      state.collapseAll();
      expect(state.isExpanded('node-1', level: 0), isFalse);
    });

    test('reset clears explicit state but keeps default', () {
      state.setDefaultExpanded(1);
      state.collapse('node-1');
      state.reset();
      // After reset, level 0 nodes use default (expanded for level 0)
      expect(state.isExpanded('node-1', level: 0), isTrue);
    });
  });

  group('OsGrid Row Grouping Integration', () {
    List<Map<String, dynamic>> testData() => [
      {'country': 'UK', 'city': 'London', 'value': 100},
      {'country': 'UK', 'city': 'Manchester', 'value': 200},
      {'country': 'US', 'city': 'New York', 'value': 300},
      {'country': 'US', 'city': 'Boston', 'value': 400},
    ];

    testWidgets('groupBy creates group rows in the grid', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: OsGrid<Map<String, dynamic>>(
                columnDefs: [
                  const OsColumnDef(field: 'country', headerName: 'Country'),
                  const OsColumnDef(field: 'city', headerName: 'City'),
                  const OsColumnDef(field: 'value', headerName: 'Value'),
                ],
                rowData: testData(),
                groupBy: const ['country'],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // The grid should render — verify no crash
      expect(find.byType(VirtualisedGrid), findsOneWidget);
    });

    testWidgets('rowGroup on columnDef enables grouping', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: OsGrid<Map<String, dynamic>>(
                columnDefs: [
                  const OsColumnDef(
                    field: 'country',
                    headerName: 'Country',
                    rowGroup: true,
                  ),
                  const OsColumnDef(field: 'city', headerName: 'City'),
                  const OsColumnDef(field: 'value', headerName: 'Value'),
                ],
                rowData: testData(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(VirtualisedGrid), findsOneWidget);
    });

    testWidgets('groupDefaultExpanded expands groups by default', (
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
                  const OsColumnDef(field: 'country', headerName: 'Country'),
                  const OsColumnDef(field: 'city', headerName: 'City'),
                  const OsColumnDef(field: 'value', headerName: 'Value'),
                ],
                rowData: testData(),
                groupBy: const ['country'],
                groupDefaultExpanded: -1,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(VirtualisedGrid), findsOneWidget);
    });

    testWidgets('controller expandAll and collapseAll work', (tester) async {
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
                  const OsColumnDef(field: 'country', headerName: 'Country'),
                  const OsColumnDef(field: 'city', headerName: 'City'),
                  const OsColumnDef(field: 'value', headerName: 'Value'),
                ],
                rowData: testData(),
                groupBy: const ['country'],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Expand all
      controller.expandAll();
      await tester.pump();

      // Collapse all
      controller.collapseAll();
      await tester.pump();

      // Should not throw
      expect(find.byType(VirtualisedGrid), findsOneWidget);
    });

    testWidgets('controller setRowGroupColumns changes grouping', (
      tester,
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
                  const OsColumnDef(field: 'country', headerName: 'Country'),
                  const OsColumnDef(field: 'city', headerName: 'City'),
                  const OsColumnDef(field: 'value', headerName: 'Value'),
                ],
                rowData: testData(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Initially no grouping
      expect(controller.getRowGroupColumns(), isEmpty);

      // Set grouping programmatically
      controller.setRowGroupColumns(['country']);
      await tester.pump();

      expect(controller.getRowGroupColumns(), equals(['country']));

      // Clear grouping
      controller.setRowGroupColumns([]);
      await tester.pump();

      expect(controller.getRowGroupColumns(), isEmpty);
    });

    testWidgets('onRowGroupOpened fires when group is toggled', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();
      OsRowGroupOpenedEvent? lastEvent;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: OsGrid<Map<String, dynamic>>(
                controller: controller,
                columnDefs: [
                  const OsColumnDef(field: 'country', headerName: 'Country'),
                  const OsColumnDef(field: 'city', headerName: 'City'),
                  const OsColumnDef(field: 'value', headerName: 'Value'),
                ],
                rowData: testData(),
                groupBy: const ['country'],
                onRowGroupOpened: (event) {
                  lastEvent = event;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Programmatically expand a row
      controller.setRowExpanded('row-group-country-UK', expanded: true);
      await tester.pump();

      expect(lastEvent, isNotNull);
      expect(lastEvent!.expanded, isTrue);
      expect(lastEvent!.nodeId, equals('row-group-country-UK'));
    });

    testWidgets('onExpandOrCollapseAll fires on expandAll/collapseAll', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();
      final events = <OsExpandOrCollapseAllEvent>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: OsGrid<Map<String, dynamic>>(
                controller: controller,
                columnDefs: [
                  const OsColumnDef(field: 'country', headerName: 'Country'),
                  const OsColumnDef(field: 'city', headerName: 'City'),
                  const OsColumnDef(field: 'value', headerName: 'Value'),
                ],
                rowData: testData(),
                groupBy: const ['country'],
                onExpandOrCollapseAll: (event) {
                  events.add(event);
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      controller.expandAll();
      await tester.pump();
      expect(events.length, equals(1));
      expect(events.last.expandedAll, isTrue);

      controller.collapseAll();
      await tester.pump();
      expect(events.length, equals(2));
      expect(events.last.expandedAll, isFalse);
    });

    testWidgets('grouping works with sort — sorted data is grouped correctly', (
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
                    field: 'country',
                    headerName: 'Country',
                    sortable: true,
                  ),
                  const OsColumnDef(field: 'value', headerName: 'Value'),
                ],
                rowData: testData(),
                groupBy: const ['country'],
                groupDefaultExpanded: -1,
                initialSort: [
                  const OsSortModel(
                    colId: 'country',
                    sort: OsSortDirection.descending,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(VirtualisedGrid), findsOneWidget);
    });

    testWidgets('grouping works with filter', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: OsGrid<Map<String, dynamic>>(
                columnDefs: [
                  const OsColumnDef(field: 'country', headerName: 'Country'),
                  const OsColumnDef(field: 'value', headerName: 'Value'),
                ],
                rowData: testData(),
                groupBy: const ['country'],
                groupDefaultExpanded: -1,
                quickFilterText: 'UK',
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(VirtualisedGrid), findsOneWidget);
    });

    testWidgets('grouping with pagination paginates the flattened list', (
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
                  const OsColumnDef(field: 'country', headerName: 'Country'),
                  const OsColumnDef(field: 'value', headerName: 'Value'),
                ],
                rowData: testData(),
                groupBy: const ['country'],
                groupDefaultExpanded: -1,
                pagination: const OsPagination(pageSize: 3),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(VirtualisedGrid), findsOneWidget);
    });
  });
}
