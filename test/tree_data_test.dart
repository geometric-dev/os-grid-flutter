import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

List<Map<String, dynamic>> _chainData() => [
  // Path ["A"]         -> leaf directly under group A
  {
    'id': 'r1',
    'name': 'r1',
    'path': <Object>['A'],
  },
  // Path ["A", "B"]    -> leaf under A > B
  {
    'id': 'r2',
    'name': 'r2',
    'path': <Object>['A', 'B'],
  },
  // Path ["A", "B", "C"] -> leaf under A > B > C
  {
    'id': 'r3',
    'name': 'r3',
    'path': <Object>['A', 'B', 'C'],
  },
];

List<Object>? _mapPath(Map<String, dynamic> row) =>
    row['path'] as List<Object>?;

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: SizedBox(width: 800, height: 600, child: child)),
);

List<Map<String, dynamic>> _displayRows(WidgetTester tester) {
  final grid = tester.widget<VirtualisedGrid>(find.byType(VirtualisedGrid));
  return grid.rowData;
}

void main() {
  group('TreeDataService', () {
    late TreeDataService<Map<String, dynamic>> service;
    late RowGroupState state;

    setUp(() {
      service = TreeDataService<Map<String, dynamic>>();
      state = RowGroupState();
    });

    test('builds hierarchy from paths; collapsed by default', () {
      final result = service.buildTreeData(
        data: _chainData(),
        getDataPath: _mapPath,
        state: state,
      );

      // All collapsed: only the top-level synthetic group is visible.
      expect(result, hasLength(1));
      final groupRow = result[0];
      expect(groupRow[RowGroupKeys.kIsGroupRow], isTrue);
      expect(groupRow[RowGroupKeys.kGroupKey], equals('A'));
      expect(groupRow[RowGroupKeys.kGroupLevel], equals(0));
      expect(groupRow[RowGroupKeys.kGroupChildCount], equals(3));
      expect(groupRow[RowGroupKeys.kGroupExpanded], isFalse);
      expect(
        groupRow[RowGroupKeys.kGroupNodeId],
        equals(TreeDataService.makeTreeNodeIdForPath(['A'])),
      );
    });

    test('groupDefaultExpanded -1 shows all leaves in encounter order', () {
      state.setDefaultExpanded(-1);
      final data = _chainData();
      final result = service.buildTreeData(
        data: data,
        getDataPath: _mapPath,
        state: state,
      );

      // grpA, r1, grpB, r2, grpC, r3
      expect(result, hasLength(6));
      expect(result[0][RowGroupKeys.kIsGroupRow], isTrue);
      expect(result[0][RowGroupKeys.kGroupKey], equals('A'));
      expect(result[0][RowGroupKeys.kGroupLevel], equals(0));
      // Leaves are shallow copies stamped with their hierarchy depth.
      expect(result[1]['name'], equals('r1'));
      expect(result[1][RowGroupKeys.kRowDepth], equals(1));

      expect(result[2][RowGroupKeys.kIsGroupRow], isTrue);
      expect(result[2][RowGroupKeys.kGroupKey], equals('B'));
      expect(result[2][RowGroupKeys.kGroupLevel], equals(1));
      expect(result[2][RowGroupKeys.kGroupChildCount], equals(2));
      expect(result[3]['name'], equals('r2'));

      expect(result[4][RowGroupKeys.kIsGroupRow], isTrue);
      expect(result[4][RowGroupKeys.kGroupKey], equals('C'));
      expect(result[4][RowGroupKeys.kGroupLevel], equals(2));
      expect(result[5]['name'], equals('r3'));
    });

    test('level-based default expansion stops after n levels', () {
      state.setDefaultExpanded(2); // Levels 0 and 1 expanded, level 2 not.
      final result = service.buildTreeData(
        data: _chainData(),
        getDataPath: _mapPath,
        state: state,
      );

      // grpA(expanded), r1, grpB(expanded), r2, grpC(collapsed)
      expect(result, hasLength(5));
      expect(result[0][RowGroupKeys.kGroupKey], equals('A'));
      expect(result[0][RowGroupKeys.kGroupExpanded], isTrue);
      expect(result[2][RowGroupKeys.kGroupKey], equals('B'));
      expect(result[2][RowGroupKeys.kGroupExpanded], isTrue);
      expect(result[4][RowGroupKeys.kGroupKey], equals('C'));
      expect(result[4][RowGroupKeys.kGroupExpanded], isFalse);
    });

    test('setRowExpanded-style toggling via exposed node id scheme', () {
      final resultCollapsed = service.buildTreeData(
        data: _chainData(),
        getDataPath: _mapPath,
        state: state,
      );
      expect(resultCollapsed, hasLength(1));

      // Expand A only, addressing it by its path-derived node id.
      final idA = TreeDataService.makeTreeNodeIdForPath(['A']);
      state.setExpanded(idA, expanded: true);

      final resultExpanded = service.buildTreeData(
        data: _chainData(),
        getDataPath: _mapPath,
        state: state,
      );
      // grpA, r1, grpB (B still collapsed)
      expect(resultExpanded.map((r) => r['name']), equals([null, 'r1', null]));

      state.setExpanded(idA, expanded: false);
      final resultRecollapsed = service.buildTreeData(
        data: _chainData(),
        getDataPath: _mapPath,
        state: state,
      );
      expect(resultRecollapsed, hasLength(1));
    });

    test('rows sharing a full path all remain leaves', () {
      final data = [
        {
          'name': 'x1',
          'path': <Object>['X'],
        },
        {
          'name': 'x2',
          'path': <Object>['X'],
        },
      ];
      final result = service.buildTreeData(
        data: data,
        getDataPath: _mapPath,
        state: state,
      );
      expect(result, hasLength(1));
      expect(result[0][RowGroupKeys.kGroupChildCount], equals(2));

      state.setDefaultExpanded(-1);
      final expanded = service.buildTreeData(
        data: data,
        getDataPath: _mapPath,
        state: state,
      );
      expect(expanded, hasLength(3));
      expect(expanded[1]['name'], equals('x1'));
      expect(expanded[2]['name'], equals('x2'));
    });

    test('rows with null or empty path sit at root without a group header', () {
      final data = [
        {'name': 'orphan', 'path': null},
        {'name': 'empty', 'path': <String>[]},
      ];
      final result = service.buildTreeData(
        data: data,
        getDataPath: (row) => row['path'] as List<Object>?,
        state: state,
      );
      expect(result, hasLength(2));
      expect(result.every((r) => r[RowGroupKeys.kIsGroupRow] != true), isTrue);
      expect(result[0]['name'], equals('orphan'));
      expect(result[1]['name'], equals('empty'));
    });

    test('node ids escape dashes and cannot collide across nesting', () {
      final flatDash = TreeDataService.makeTreeNodeIdForPath(['a-b']);
      final nested = TreeDataService.makeTreeNodeIdForPath(['a', 'b']);
      expect(flatDash, isNot(equals(nested)));
      // Same escaping scheme as RowGroupService.makeNodeId.
      expect(
        flatDash,
        equals(
          RowGroupService.makeNodeId('', TreeDataService.treeFieldId, 'a-b'),
        ),
      );
      expect(nested, equals('row-group-__tree-a-__tree-b'));
    });

    test('typed leaves convert via typedLeafToMap', () {
      final personService = TreeDataService<_Person>();
      final data = [
        _Person('Alice', ['Team']),
        _Person('Bob', ['Team']),
      ];
      final result = personService.buildTreeData(
        data: data,
        getDataPath: (p) => p.path,
        state: state..setDefaultExpanded(-1),
        typedLeafToMap: (row, index) => {'name': row.name, 'index': index},
      );
      expect(result, hasLength(3)); // grp Team + 2 converted leaves
      expect(result[1]['name'], equals('Alice'));
      expect(result[2]['name'], equals('Bob'));
    });

    test('typed leaves fall back to empty maps without a converter', () {
      final personService = TreeDataService<_Person>();
      final data = [
        _Person('Alice', ['Team']),
      ];
      final result = personService.buildTreeData(
        data: data,
        getDataPath: (p) => p.path,
        state: state..setDefaultExpanded(-1),
      );
      expect(result, hasLength(2));
      // Fallback map plus the leaf depth stamp (leaf sits one level under
      // its parent node).
      expect(result[1], equals(<String, dynamic>{RowGroupKeys.kRowDepth: 1}));
    });
  });

  group('TreeData widget', () {
    List<OsColumnDef> columns() => const [
      OsColumnDef(field: 'name', headerName: 'Name'),
    ];

    testWidgets('renders collapsed by default with child counts', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          OsGrid<Map<String, dynamic>>(
            columnDefs: columns(),
            rowData: _chainData(),
            treeData: true,
            getDataPath: _mapPath,
          ),
        ),
      );
      await tester.pump();

      final rows = _displayRows(tester);
      expect(rows, hasLength(1));
      expect(rows[0][RowGroupKeys.kIsGroupRow], isTrue);
      expect(rows[0][RowGroupKeys.kGroupChildCount], equals(3));
    });

    testWidgets('groupDefaultExpanded:-1 shows all leaves in order', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          OsGrid<Map<String, dynamic>>(
            columnDefs: columns(),
            rowData: _chainData(),
            treeData: true,
            getDataPath: _mapPath,
            groupDefaultExpanded: -1,
          ),
        ),
      );
      await tester.pump();

      final names = _displayRows(tester)
          .where((r) => r[RowGroupKeys.kIsGroupRow] != true)
          .map((r) => r['name'])
          .toList();
      expect(names, equals(['r1', 'r2', 'r3']));
    });

    testWidgets('controller setRowExpanded toggles tree nodes by node id', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();
      await tester.pumpWidget(
        _wrap(
          OsGrid<Map<String, dynamic>>(
            controller: controller,
            columnDefs: columns(),
            rowData: _chainData(),
            treeData: true,
            getDataPath: _mapPath,
          ),
        ),
      );
      await tester.pump();
      expect(_displayRows(tester), hasLength(1));

      final idA = TreeDataService.makeTreeNodeIdForPath(['A']);
      controller.setRowExpanded(idA, expanded: true);
      await tester.pump();

      // grpA + r1 + grpB (nested B stays collapsed).
      var rows = _displayRows(tester);
      expect(rows, hasLength(3));
      expect(rows[1]['name'], equals('r1'));
      expect(controller.isRowExpanded(idA), isTrue);

      controller.setRowExpanded(idA, expanded: false);
      await tester.pump();
      rows = _displayRows(tester);
      expect(rows, hasLength(1));
      expect(controller.isRowExpanded(idA), isFalse);
    });

    testWidgets('controller expandAll/collapseAll affect tree nodes', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();
      await tester.pumpWidget(
        _wrap(
          OsGrid<Map<String, dynamic>>(
            controller: controller,
            columnDefs: columns(),
            rowData: _chainData(),
            treeData: true,
            getDataPath: _mapPath,
          ),
        ),
      );
      await tester.pump();
      expect(_displayRows(tester), hasLength(1));

      controller.expandAll();
      await tester.pump();
      expect(_displayRows(tester), hasLength(6));

      controller.collapseAll();
      await tester.pump();
      expect(_displayRows(tester), hasLength(1));
    });

    testWidgets('quick filter composes before tree flatten', (tester) async {
      await tester.pumpWidget(
        _wrap(
          OsGrid<Map<String, dynamic>>(
            columnDefs: columns(),
            rowData: _chainData(),
            treeData: true,
            getDataPath: _mapPath,
            groupDefaultExpanded: -1,
            quickFilterText: 'r2',
          ),
        ),
      );
      await tester.pump();

      final rows = _displayRows(tester);
      // Only grpA > grpB > r2 survives filtering.
      expect(rows, hasLength(3));
      expect(rows[0][RowGroupKeys.kGroupChildCount], equals(1));
      expect(rows[2]['name'], equals('r2'));
    });

    testWidgets('sorting composes before tree flatten (sibling order)', (
      tester,
    ) async {
      final data = [
        {
          'name': 'banana',
          'path': <Object>['P'],
        },
        {
          'name': 'apple',
          'path': <Object>['P'],
        },
      ];
      await tester.pumpWidget(
        _wrap(
          OsGrid<Map<String, dynamic>>(
            columnDefs: columns(),
            rowData: data,
            treeData: true,
            getDataPath: _mapPath,
            groupDefaultExpanded: -1,
            initialSort: const [
              OsSortModel(colId: 'name', sort: OsSortDirection.ascending),
            ],
          ),
        ),
      );
      await tester.pump();

      final names = _displayRows(tester)
          .where((r) => r[RowGroupKeys.kIsGroupRow] != true)
          .map((r) => r['name'])
          .toList();
      expect(names, equals(['apple', 'banana']));
    });

    testWidgets('pagination slices the flattened display list', (tester) async {
      await tester.pumpWidget(
        _wrap(
          OsGrid<Map<String, dynamic>>(
            columnDefs: columns(),
            rowData: _chainData(),
            treeData: true,
            getDataPath: _mapPath,
            groupDefaultExpanded: -1,
            pagination: const OsPagination(pageSize: 2),
          ),
        ),
      );
      await tester.pump();

      // Full flattened list is 6 rows; page size 2 -> first slice.
      final rows = _displayRows(tester);
      expect(rows, hasLength(2));
      expect(rows[0][RowGroupKeys.kIsGroupRow], isTrue);
      expect(rows[1]['name'], equals('r1'));
    });

    testWidgets('typed rows render values via valueGetter', (tester) async {
      await tester.pumpWidget(
        _wrap(
          OsGrid<_Person>(
            columnDefs: [
              OsColumnDef<_Person>(
                field: 'name',
                headerName: 'Name',
                valueGetter: (params) => params.data.name,
              ),
            ],
            rowData: [
              _Person('Alice', ['Team']),
              _Person('Bob', ['Team']),
            ],
            treeData: true,
            getDataPath: (p) => p.path,
            groupDefaultExpanded: -1,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final names = _displayRows(
        tester,
      ).where((r) => r['__isGroupRow'] != true).map((r) => r['name']).toList();
      expect(names, containsAll(['Alice', 'Bob']));
    });

    testWidgets('selection by getRowId works on tree leaves', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();
      await tester.pumpWidget(
        _wrap(
          OsGrid<Map<String, dynamic>>(
            controller: controller,
            columnDefs: columns(),
            rowData: _chainData(),
            treeData: true,
            getDataPath: _mapPath,
            groupDefaultExpanded: -1,
            getRowId: (row) => row['id'].toString(),
          ),
        ),
      );
      await tester.pump();

      controller.selectRowsById(['r2']);
      await tester.pump();

      expect(controller.getSelectedIds(), equals({'r2'}));
      // Leaf nodes are TData-backed data rows, not group nodes.
      final node = controller.getNode('r2');
      expect(node, isNotNull);
      expect(node!.group, isFalse);
    });

    testWidgets('treeData without getDataPath warns once', (tester) async {
      final logs = <String>[];
      final originalDebugPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) logs.add(message);
      };
      try {
        await tester.pumpWidget(
          _wrap(
            OsGrid<Map<String, dynamic>>(
              columnDefs: columns(),
              rowData: _chainData(),
              treeData: true,
              // getDataPath intentionally omitted.
            ),
          ),
        );
        await tester.pump();
      } finally {
        debugPrint = originalDebugPrint;
      }

      expect(
        logs.any(
          (l) =>
              l.startsWith('[OS Grid]') &&
              l.contains('getDataPath is not provided'),
        ),
        isTrue,
      );
    });

    testWidgets(
      // DECISION (documented precedence): treeData WINS over row grouping.
      // Per spec ("when treeData: SKIP normal grouping pipeline"), the
      // grouping pipeline is skipped entirely and the validator emits a
      // debug-mode warning about the ignored grouping configuration.
      'treeData combined with groupBy warns and tree data takes precedence',
      (tester) async {
        final logs = <String>[];
        final originalDebugPrint = debugPrint;
        debugPrint = (String? message, {int? wrapWidth}) {
          if (message != null) logs.add(message);
        };
        try {
          await tester.pumpWidget(
            _wrap(
              OsGrid<Map<String, dynamic>>(
                columnDefs: columns(),
                rowData: _chainData(),
                treeData: true,
                getDataPath: _mapPath,
                groupBy: const ['name'],
              ),
            ),
          );
          await tester.pump();
        } finally {
          debugPrint = originalDebugPrint;
        }

        expect(
          logs.any(
            (l) =>
                l.startsWith('[OS Grid]') &&
                l.contains('treeData takes precedence'),
          ),
          isTrue,
        );
        // The displayed hierarchy comes from the PATHS ('A'), not from the
        // grouped column values ('r1'/'r2'/'r3').
        final rows = _displayRows(tester);
        expect(rows, hasLength(1));
        expect(rows[0][RowGroupKeys.kGroupKey], equals('A'));
      },
    );
  });
}

class _Person {
  _Person(this.name, this.path);
  final String name;
  final List<Object> path;
}
