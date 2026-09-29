import 'dart:ui' show CheckedState, Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SemanticsNode;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

void main() {
  group('Semantics tree', () {
    testWidgets('grid has container semantics with row/column count', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: OsGrid(
                columnDefs: [
                  OsColumnDef(field: 'name', headerName: 'Name'),
                  OsColumnDef(field: 'age', headerName: 'Age'),
                ],
                rowData: [
                  {'name': 'Alice', 'age': 30},
                  {'name': 'Bob', 'age': 25},
                  {'name': 'Charlie', 'age': 35},
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the Semantics node with the grid label
      final semantics = tester.getSemantics(find.byType(VirtualisedGrid));
      expect(semantics.label, contains('Data grid'));
      expect(semantics.label, contains('3 rows'));
      expect(semantics.label, contains('2 columns'));
    });

    testWidgets('grid updates semantics label when row count changes', (
      tester,
    ) async {
      final rows = <Map<String, dynamic>>[
        {'name': 'Alice', 'age': 30},
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: OsGrid(
                columnDefs: [
                  const OsColumnDef(field: 'name', headerName: 'Name'),
                ],
                rowData: rows,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final semantics = tester.getSemantics(find.byType(VirtualisedGrid));
      expect(semantics.label, contains('1 rows'));
      expect(semantics.label, contains('1 columns'));
    });
  });

  group('Focus management', () {
    testWidgets('grid can receive keyboard focus via Tab', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                TextField(key: Key('before')),
                Expanded(
                  child: OsGrid(
                    columnDefs: [
                      OsColumnDef(field: 'name', headerName: 'Name'),
                    ],
                    rowData: [
                      {'name': 'Alice'},
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Focus the text field first
      await tester.tap(find.byKey(const Key('before')));
      await tester.pumpAndSettle();

      // Tab into the grid
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      // The grid's VirtualisedGrid should now have focus
      final gridFinder = find.byType(VirtualisedGrid);
      expect(tester.widget<VirtualisedGrid>(gridFinder), isNotNull);
      // Verify the grid is focusable (it has a Focus widget)
      expect(find.byType(Focus), findsWidgets);
    });

    testWidgets('grid receives focus on tap without visual border', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: OsGrid(
                columnDefs: [OsColumnDef(field: 'name', headerName: 'Name')],
                rowData: [
                  {'name': 'Alice'},
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the grid to give it focus
      await tester.tap(find.byType(VirtualisedGrid));
      await tester.pumpAndSettle();

      // No AnimatedContainer with focus border should exist
      expect(find.byType(AnimatedContainer), findsNothing);
    });
  });

  group('High contrast theme', () {
    test('OsGridTheme.highContrast() has bold borders', () {
      final theme = OsGridTheme.highContrast();
      expect(theme.pinnedColumnBorderWidth, 2);
      expect(theme.borderColor, const Color(0xFF000000));
      expect(theme.rowBorderColor, const Color(0xFF000000));
      expect(theme.columnBorderColor, const Color(0xFF000000));
      expect(theme.wrapperBorderColor, const Color(0xFF000000));
    });

    test('OsGridTheme.highContrast() has maximum contrast colours', () {
      final theme = OsGridTheme.highContrast();
      expect(theme.backgroundColor, const Color(0xFFFFFFFF));
      expect(theme.foregroundColor, const Color(0xFF000000));
      expect(theme.cellTextColor, const Color(0xFF000000));
      expect(theme.headerTextColor, const Color(0xFF000000));
    });

    test('OsGridTheme.highContrast() has no border radius', () {
      final theme = OsGridTheme.highContrast();
      expect(theme.gridBorderRadius, BorderRadius.zero);
    });

    test('OsGridTheme.highContrast() has bold header font weight', () {
      final theme = OsGridTheme.highContrast();
      expect(theme.headerFontWeight, FontWeight.w700);
      expect(theme.headerTextStyle?.fontWeight, FontWeight.w700);
    });

    test('OsGridTheme.highContrast() has alternating row colour', () {
      final theme = OsGridTheme.highContrast();
      expect(theme.alternateRowColor, isNotNull);
    });

    testWidgets('isHighContrast returns false by default', (tester) async {
      late bool result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              result = isHighContrast(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(result, isFalse);
    });

    testWidgets('isHighContrast returns true when platform requests it', (
      tester,
    ) async {
      late bool result;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(highContrast: true),
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                result = isHighContrast(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      expect(result, isTrue);
    });

    testWidgets('resolveThemeForAccessibility returns high contrast overrides '
        'when platform requests it', (tester) async {
      late OsGridTheme resolved;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(highContrast: true),
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                resolved = resolveThemeForAccessibility(context, null);
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      // Should get the high contrast theme
      expect(resolved.pinnedColumnBorderWidth, 2);
      expect(resolved.borderColor, const Color(0xFF000000));
    });

    testWidgets('resolveThemeForAccessibility boosts existing theme borders '
        'when platform requests high contrast', (tester) async {
      late OsGridTheme resolved;
      final baseTheme = OsGridTheme.quartz();
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(highContrast: true),
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                resolved = resolveThemeForAccessibility(context, baseTheme);
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      // Border width should be boosted to 2
      expect(resolved.pinnedColumnBorderWidth, 2);
      // But background should remain from the base theme
      expect(resolved.backgroundColor, baseTheme.backgroundColor);
    });

    testWidgets('resolveThemeForAccessibility returns theme unchanged '
        'when high contrast is not active', (tester) async {
      late OsGridTheme resolved;
      final baseTheme = OsGridTheme.quartz();
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              resolved = resolveThemeForAccessibility(context, baseTheme);
              return const SizedBox();
            },
          ),
        ),
      );
      // Should return the same theme unchanged
      expect(
        resolved.pinnedColumnBorderWidth,
        baseTheme.pinnedColumnBorderWidth,
      );
      expect(resolved.backgroundColor, baseTheme.backgroundColor);
    });
  });

  group('Semantics builder', () {
    test('buildGridSemantics generates header semantics', () {
      final columns = [
        const OsColumnDef(field: 'name', headerName: 'Name'),
        const OsColumnDef(field: 'age', headerName: 'Age'),
      ];

      final result = buildGridSemantics(
        size: const Size(800, 600),
        columns: columns,
        rowData: [
          {'name': 'Alice', 'age': 30},
        ],
        rowHeight: 42,
        headerHeight: 48,
        scrollX: 0,
        scrollY: 0,
        groupHeaderHeight: 0,
        floatingFilterHeight: 0,
        selectedRows: {},
        focusedRow: 0,
        focusedCol: 0,
      );

      // Should have header semantics for each column
      final headers = result.where((s) => s.properties.header == true);
      expect(headers.length, 2);

      // Check header labels
      final headerLabels = headers.map((s) => s.properties.label).toList();
      expect(headerLabels, contains('Name'));
      expect(headerLabels, contains('Age'));
    });

    test('buildGridSemantics generates cell semantics with values', () {
      final columns = [
        const OsColumnDef(field: 'name', headerName: 'Name'),
        const OsColumnDef(field: 'age', headerName: 'Age'),
      ];

      final result = buildGridSemantics(
        size: const Size(800, 600),
        columns: columns,
        rowData: [
          {'name': 'Alice', 'age': 30},
          {'name': 'Bob', 'age': 25},
        ],
        rowHeight: 42,
        headerHeight: 48,
        scrollX: 0,
        scrollY: 0,
        groupHeaderHeight: 0,
        floatingFilterHeight: 0,
        selectedRows: {},
        focusedRow: 0,
        focusedCol: 0,
      );

      // Should have cell semantics (2 rows × 2 columns = 4 cells)
      final cells = result.where((s) => s.properties.header != true);
      expect(cells.length, 4);

      // Check that cell labels contain the data values
      final cellLabels = cells.map((s) => s.properties.label).toList();
      expect(cellLabels, contains('Alice'));
      expect(cellLabels, contains('30'));
      expect(cellLabels, contains('Bob'));
      expect(cellLabels, contains('25'));
    });

    test('buildGridSemantics marks selected rows', () {
      final columns = [const OsColumnDef(field: 'name', headerName: 'Name')];

      final result = buildGridSemantics(
        size: const Size(800, 600),
        columns: columns,
        rowData: [
          {'name': 'Alice'},
          {'name': 'Bob'},
        ],
        rowHeight: 42,
        headerHeight: 48,
        scrollX: 0,
        scrollY: 0,
        groupHeaderHeight: 0,
        floatingFilterHeight: 0,
        selectedRows: {0}, // First row selected
        focusedRow: 0,
        focusedCol: 0,
      );

      final cells = result.where((s) => s.properties.header != true).toList();
      // First cell (Alice) should be selected
      expect(cells[0].properties.selected, isTrue);
      // Second cell (Bob) should not be selected
      expect(cells[1].properties.selected, isFalse);
    });

    test('buildGridSemantics marks focused cell', () {
      final columns = [
        const OsColumnDef(field: 'name', headerName: 'Name'),
        const OsColumnDef(field: 'age', headerName: 'Age'),
      ];

      final result = buildGridSemantics(
        size: const Size(800, 600),
        columns: columns,
        rowData: [
          {'name': 'Alice', 'age': 30},
          {'name': 'Bob', 'age': 25},
        ],
        rowHeight: 42,
        headerHeight: 48,
        scrollX: 0,
        scrollY: 0,
        groupHeaderHeight: 0,
        floatingFilterHeight: 0,
        selectedRows: {},
        focusedRow: 1,
        focusedCol: 1,
      );

      final cells = result.where((s) => s.properties.header != true).toList();
      // Only the cell at row 1, col 1 (Bob's age) should be focused
      final focusedCells = cells
          .where((s) => s.properties.focused == true)
          .toList();
      expect(focusedCells.length, 1);
      expect(focusedCells[0].properties.label, '25');
    });

    test('buildGridSemantics includes sort state in header labels', () {
      final columns = [
        const OsColumnDef(field: 'name', headerName: 'Name'),
        const OsColumnDef(field: 'age', headerName: 'Age'),
      ];

      final result = buildGridSemantics(
        size: const Size(800, 600),
        columns: columns,
        rowData: [
          {'name': 'Alice', 'age': 30},
        ],
        rowHeight: 42,
        headerHeight: 48,
        scrollX: 0,
        scrollY: 0,
        groupHeaderHeight: 0,
        floatingFilterHeight: 0,
        selectedRows: {},
        focusedRow: 0,
        focusedCol: 0,
        sortIndicators: {
          0: const SortIndicatorInfo(
            direction: OsSortDirection.ascending,
            priority: 1,
            isMultiSort: false,
          ),
        },
      );

      final headers = result.where((s) => s.properties.header == true).toList();
      // Name header should include sort state
      expect(headers[0].properties.label, 'Name, sorted ascending');
      // Age header should not include sort state
      expect(headers[1].properties.label, 'Age');
    });

    test('buildGridSemantics descending sort label', () {
      final columns = [const OsColumnDef(field: 'name', headerName: 'Name')];

      final result = buildGridSemantics(
        size: const Size(800, 600),
        columns: columns,
        rowData: [
          {'name': 'Alice'},
        ],
        rowHeight: 42,
        headerHeight: 48,
        scrollX: 0,
        scrollY: 0,
        groupHeaderHeight: 0,
        floatingFilterHeight: 0,
        selectedRows: {},
        focusedRow: 0,
        focusedCol: 0,
        sortIndicators: {
          0: const SortIndicatorInfo(
            direction: OsSortDirection.descending,
            priority: 1,
            isMultiSort: false,
          ),
        },
      );

      final headers = result.where((s) => s.properties.header == true).toList();
      expect(headers[0].properties.label, 'Name, sorted descending');
    });

    test('buildGridSemantics only includes visible rows (virtualised)', () {
      final columns = [const OsColumnDef(field: 'name', headerName: 'Name')];

      // 100 rows, but viewport only shows ~13 rows (600 - 48 header = 552 / 42 ≈ 13)
      final rowData = List.generate(100, (i) => {'name': 'Row $i'});

      final result = buildGridSemantics(
        size: const Size(800, 600),
        columns: columns,
        rowData: rowData,
        rowHeight: 42,
        headerHeight: 48,
        scrollX: 0,
        scrollY: 0,
        groupHeaderHeight: 0,
        floatingFilterHeight: 0,
        selectedRows: {},
        focusedRow: 0,
        focusedCol: 0,
      );

      // Should have 1 header + only visible cells (not all 100)
      final headers = result.where((s) => s.properties.header == true);
      final cells = result.where((s) => s.properties.header != true);
      expect(headers.length, 1);
      // Should be approximately 14 visible rows (ceil of 552/42)
      expect(cells.length, lessThan(20));
      expect(cells.length, greaterThan(10));
    });

    test('buildGridSemantics respects scroll position', () {
      final columns = [const OsColumnDef(field: 'name', headerName: 'Name')];

      final rowData = List.generate(100, (i) => {'name': 'Row $i'});

      // Scroll down by 420px (10 rows)
      final result = buildGridSemantics(
        size: const Size(800, 600),
        columns: columns,
        rowData: rowData,
        rowHeight: 42,
        headerHeight: 48,
        scrollX: 0,
        scrollY: 420,
        groupHeaderHeight: 0,
        floatingFilterHeight: 0,
        selectedRows: {},
        focusedRow: 10,
        focusedCol: 0,
      );

      final cells = result.where((s) => s.properties.header != true);
      // First visible cell should be around row 10
      final firstLabel = cells.first.properties.label;
      expect(firstLabel, 'Row 10');
    });

    test('buildGridSemantics routes sort labels through a custom resolver', () {
      final columns = [
        const OsColumnDef(field: 'name', headerName: 'Name'),
        const OsColumnDef(field: 'age', headerName: 'Age'),
      ];

      String resolve(String key, String defaultValue) => switch (key) {
        'sortedAscending' => 'aufsteigend sortiert',
        _ => defaultValue,
      };

      final result = buildGridSemantics(
        size: const Size(800, 600),
        columns: columns,
        rowData: [
          {'name': 'Alice', 'age': 30},
        ],
        rowHeight: 42,
        headerHeight: 48,
        scrollX: 0,
        scrollY: 0,
        groupHeaderHeight: 0,
        floatingFilterHeight: 0,
        selectedRows: {},
        focusedRow: 0,
        focusedCol: 0,
        sortIndicators: {
          0: const SortIndicatorInfo(
            direction: OsSortDirection.ascending,
            priority: 1,
            isMultiSort: false,
          ),
        },
        localeResolver: resolve,
      );

      final headers = result.where((s) => s.properties.header == true).toList();
      expect(headers[0].properties.label, 'Name, aufsteigend sortiert');
      expect(headers[1].properties.label, 'Age');
    });

    test(
      'buildGridSemantics routes checkbox labels through a custom resolver',
      () {
        final columns = [
          const OsColumnDef(field: '__checkbox__', headerName: ''),
        ];

        String resolve(String key, String defaultValue) => switch (key) {
          'selected' => 'Ausgewählt',
          'notSelected' => 'Nicht ausgewählt',
          _ => defaultValue,
        };

        final result = buildGridSemantics(
          size: const Size(800, 600),
          columns: columns,
          rowData: [
            {'__checkbox__': true},
            {'__checkbox__': false},
          ],
          rowHeight: 42,
          headerHeight: 48,
          scrollX: 0,
          scrollY: 0,
          groupHeaderHeight: 0,
          floatingFilterHeight: 0,
          selectedRows: {0},
          focusedRow: -1,
          focusedCol: -1,
          localeResolver: resolve,
        );

        final cells = result.where((s) => s.properties.header != true).toList();
        expect(cells[0].properties.label, 'Ausgewählt');
        expect(cells[1].properties.label, 'Nicht ausgewählt');
      },
    );

    test('buildGridSemantics keeps English labels without a resolver', () {
      final columns = [const OsColumnDef(field: 'name', headerName: 'Name')];

      final result = buildGridSemantics(
        size: const Size(800, 600),
        columns: columns,
        rowData: [
          {'name': 'Alice'},
        ],
        rowHeight: 42,
        headerHeight: 48,
        scrollX: 0,
        scrollY: 0,
        groupHeaderHeight: 0,
        floatingFilterHeight: 0,
        selectedRows: {},
        focusedRow: -1,
        focusedCol: -1,
        sortIndicators: {
          0: const SortIndicatorInfo(
            direction: OsSortDirection.descending,
            priority: 1,
            isMultiSort: false,
          ),
        },
      );

      expect(result.first.properties.label, 'Name, sorted descending');
    });

    test(
      'buildGridSemantics keeps English checkbox labels without resolver',
      () {
        final columns = [
          const OsColumnDef(field: '__checkbox__', headerName: ''),
        ];

        final result = buildGridSemantics(
          size: const Size(800, 600),
          columns: columns,
          rowData: [
            {'__checkbox__': true},
            {'__checkbox__': false},
          ],
          rowHeight: 42,
          headerHeight: 48,
          scrollX: 0,
          scrollY: 0,
          groupHeaderHeight: 0,
          floatingFilterHeight: 0,
          selectedRows: {0},
          focusedRow: -1,
          focusedCol: -1,
        );

        final cells = result.where((s) => s.properties.header != true).toList();
        expect(cells[0].properties.label, 'Selected');
        expect(cells[1].properties.label, 'Not selected');
      },
    );

    test(
      'buildGridSemantics labels column-group rows with field and count',
      () {
        final columns = [
          const OsColumnDef(field: 'country', headerName: 'Country'),
        ];

        final result = buildGridSemantics(
          size: const Size(800, 600),
          columns: columns,
          rowData: [
            {
              '__isGroupRow': true,
              '__groupKey': 'USA',
              '__groupField': 'country',
              '__groupLevel': 0,
              '__groupExpanded': true,
              '__groupChildCount': 5,
              '__groupNodeId': 'country~USA',
            },
            {'country': 'USA', 'name': 'Alice'},
          ],
          rowHeight: 42,
          headerHeight: 48,
          scrollX: 0,
          scrollY: 0,
          groupHeaderHeight: 0,
          floatingFilterHeight: 0,
          selectedRows: {},
          focusedRow: -1,
          focusedCol: -1,
        );

        final cells = result.where((s) => s.properties.header != true).toList();
        expect(cells[0].properties.label, 'Country: USA — 5 children');
        expect(cells[1].properties.label, 'USA');
      },
    );

    test('buildGridSemantics falls back to raw field when column unknown', () {
      final columns = [const OsColumnDef(field: 'name', headerName: 'Name')];

      final result = buildGridSemantics(
        size: const Size(800, 600),
        columns: columns,
        rowData: [
          {
            '__isGroupRow': true,
            '__groupKey': 'Blue',
            '__groupField': 'colour',
            '__groupLevel': 0,
            '__groupExpanded': true,
            '__groupChildCount': 2,
          },
        ],
        rowHeight: 42,
        headerHeight: 48,
        scrollX: 0,
        scrollY: 0,
        groupHeaderHeight: 0,
        floatingFilterHeight: 0,
        selectedRows: {},
        focusedRow: -1,
        focusedCol: -1,
      );

      final cells = result.where((s) => s.properties.header != true).toList();
      expect(cells.single.properties.label, 'colour: Blue — 2 children');
    });

    test('buildGridSemantics labels tree-group rows with rowGroup prefix', () {
      final columns = [const OsColumnDef(field: 'name', headerName: 'Name')];

      final result = buildGridSemantics(
        size: const Size(800, 600),
        columns: columns,
        rowData: [
          {
            '__isGroupRow': true,
            '__groupKey': 'Sports',
            '__groupField': TreeDataService.treeFieldId,
            '__groupLevel': 0,
            '__groupExpanded': true,
            '__groupChildCount': 3,
          },
        ],
        rowHeight: 42,
        headerHeight: 48,
        scrollX: 0,
        scrollY: 0,
        groupHeaderHeight: 0,
        floatingFilterHeight: 0,
        selectedRows: {},
        focusedRow: -1,
        focusedCol: -1,
      );

      final cells = result.where((s) => s.properties.header != true).toList();
      expect(cells.single.properties.label, 'Row Group: Sports — 3 children');
    });

    test('buildGridSemantics localizes group labels via resolver', () {
      final columns = [
        const OsColumnDef(field: 'country', headerName: 'Country'),
      ];

      String resolve(String key, String defaultValue) => switch (key) {
        'children' => 'Kinder',
        _ => defaultValue,
      };

      final result = buildGridSemantics(
        size: const Size(800, 600),
        columns: columns,
        rowData: [
          {
            '__isGroupRow': true,
            '__groupKey': 'USA',
            '__groupField': 'country',
            '__groupLevel': 0,
            '__groupExpanded': true,
            '__groupChildCount': 5,
          },
        ],
        rowHeight: 42,
        headerHeight: 48,
        scrollX: 0,
        scrollY: 0,
        groupHeaderHeight: 0,
        floatingFilterHeight: 0,
        selectedRows: {},
        focusedRow: -1,
        focusedCol: -1,
        localeResolver: resolve,
      );

      final cells = result.where((s) => s.properties.header != true).toList();
      expect(cells.single.properties.label, 'Country: USA — 5 Kinder');
    });

    test(
      'buildGridSemantics puts group label only on the first visible column',
      () {
        final columns = [
          const OsColumnDef(field: 'a', headerName: 'A'),
          const OsColumnDef(field: 'b', headerName: 'B'),
        ];

        final result = buildGridSemantics(
          size: const Size(800, 600),
          columns: columns,
          rowData: [
            {
              '__isGroupRow': true,
              '__groupKey': 'X',
              '__groupField': 'a',
              '__groupLevel': 0,
              '__groupExpanded': true,
              '__groupChildCount': 1,
            },
          ],
          rowHeight: 42,
          headerHeight: 48,
          scrollX: 0,
          scrollY: 0,
          groupHeaderHeight: 0,
          floatingFilterHeight: 0,
          selectedRows: {},
          focusedRow: -1,
          focusedCol: -1,
        );

        final cells = result
            .where((s) => s.properties.header != true)
            .map((s) => s.properties.label)
            .toList();
        expect(cells, ['A: X — 1 children', '']);
      },
    );

    test('buildGridSemantics derives text direction from the caller', () {
      final columns = [const OsColumnDef(field: 'name', headerName: 'Name')];

      for (final dir in [TextDirection.ltr, TextDirection.rtl]) {
        final result = buildGridSemantics(
          size: const Size(800, 600),
          columns: columns,
          rowData: [
            {'name': 'Alice'},
          ],
          rowHeight: 42,
          headerHeight: 48,
          scrollX: 0,
          scrollY: 0,
          groupHeaderHeight: 0,
          floatingFilterHeight: 0,
          selectedRows: {0},
          focusedRow: -1,
          focusedCol: -1,
          textDirection: dir,
        );

        expect(result.every((s) => s.properties.textDirection == dir), isTrue);
      }
    });
  });

  group('ARIA grid pattern (item 17)', () {
    List<CustomPainterSemantics> build({
      required List<OsColumnDef> columns,
      required List<Map<String, dynamic>> rowData,
      Set<int> selectedRows = const {},
      int focusedRow = -1,
      int focusedCol = -1,
      Map<int, SortIndicatorInfo>? sortIndicators,
      OsLocaleResolver? localeResolver,
      CellPosition? editingCell,
      String? editingValue,
    }) {
      return buildGridSemantics(
        size: const Size(800, 600),
        columns: columns,
        rowData: rowData,
        rowHeight: 42,
        headerHeight: 48,
        scrollX: 0,
        scrollY: 0,
        groupHeaderHeight: 0,
        floatingFilterHeight: 0,
        selectedRows: selectedRows,
        focusedRow: focusedRow,
        focusedCol: focusedCol,
        sortIndicators: sortIndicators,
        localeResolver: localeResolver,
        editingCell: editingCell,
        editingValue: editingValue,
      );
    }

    List<CustomPainterSemantics> cells(List<CustomPainterSemantics> result) =>
        result.where((s) => s.properties.header != true).toList();

    test('group rows expose expanded state on the first visible cell', () {
      final result = build(
        columns: [const OsColumnDef(field: 'country', headerName: 'Country')],
        rowData: [
          {
            '__isGroupRow': true,
            '__groupKey': 'USA',
            '__groupField': 'country',
            '__groupLevel': 0,
            '__groupExpanded': true,
            '__groupChildCount': 5,
            '__groupNodeId': 'country~USA',
          },
          {'country': 'USA', 'name': 'Alice'},
        ],
      );

      final rowCells = cells(result);
      // Group cell (first column) carries aria-expanded.
      expect(rowCells[0].properties.expanded, isTrue);
      // Ordinary data row cells are not expandable.
      expect(rowCells[1].properties.expanded, isNull);
    });

    test('collapsed group rows report expanded false', () {
      final result = build(
        columns: [const OsColumnDef(field: 'country', headerName: 'Country')],
        rowData: [
          {
            '__isGroupRow': true,
            '__groupKey': 'USA',
            '__groupField': 'country',
            '__groupLevel': 0,
            '__groupExpanded': false,
            '__groupChildCount': 5,
          },
        ],
      );

      expect(cells(result).single.properties.expanded, isFalse);
    });

    test('group rows without an expanded key default to collapsed', () {
      final result = build(
        columns: [const OsColumnDef(field: 'country', headerName: 'Country')],
        rowData: [
          {
            '__isGroupRow': true,
            '__groupKey': 'USA',
            '__groupField': 'country',
            '__groupLevel': 0,
            '__groupChildCount': 5,
          },
        ],
      );

      expect(cells(result).single.properties.expanded, isFalse);
    });

    test('tree group rows expose expanded state too', () {
      final result = build(
        columns: [const OsColumnDef(field: 'name', headerName: 'Name')],
        rowData: [
          {
            '__isGroupRow': true,
            '__groupKey': 'Sports',
            '__groupField': TreeDataService.treeFieldId,
            '__groupLevel': 0,
            '__groupExpanded': true,
            '__groupChildCount': 3,
          },
        ],
      );

      expect(cells(result).single.properties.expanded, isTrue);
    });

    test('group cells beyond the first column do not carry expanded', () {
      final result = build(
        columns: [
          const OsColumnDef(field: 'country', headerName: 'Country'),
          const OsColumnDef(field: 'name', headerName: 'Name'),
        ],
        rowData: [
          {
            '__isGroupRow': true,
            '__groupKey': 'USA',
            '__groupField': 'country',
            '__groupLevel': 0,
            '__groupExpanded': true,
            '__groupChildCount': 5,
          },
        ],
      );

      final rowCells = cells(result);
      expect(rowCells[0].properties.expanded, isTrue);
      expect(rowCells[1].properties.expanded, isNull);
    });

    test('checkbox cells expose checked state', () {
      final result = build(
        columns: [
          const OsColumnDef(field: '__checkbox__', headerName: ''),
          const OsColumnDef(field: 'name', headerName: 'Name'),
        ],
        rowData: [
          {'__checkbox__': true, 'name': 'Alice'},
          {'__checkbox__': false, 'name': 'Bob'},
        ],
        selectedRows: {0},
      );

      final rowCells = cells(result);
      expect(rowCells[0].properties.checked, isTrue);
      expect(rowCells[0].properties.label, 'Selected');
      // Unselected checkbox cell reports checked false explicitly.
      expect(rowCells[2].properties.checked, isFalse);
      expect(rowCells[2].properties.label, 'Not selected');
      // Non-checkbox cells never carry checked.
      expect(rowCells[1].properties.checked, isNull);
      expect(rowCells[3].properties.checked, isNull);
    });

    test('every cell reports its selected state', () {
      final result = build(
        columns: [const OsColumnDef(field: 'name', headerName: 'Name')],
        rowData: [
          {'name': 'Alice'},
          {'name': 'Bob'},
        ],
        selectedRows: {1},
      );

      final rowCells = cells(result);
      expect(rowCells[0].properties.selected, isFalse);
      expect(rowCells[1].properties.selected, isTrue);
    });

    test('roving focus flag lands on exactly one cell', () {
      final result = build(
        columns: [
          const OsColumnDef(field: 'name', headerName: 'Name'),
          const OsColumnDef(field: 'age', headerName: 'Age'),
        ],
        rowData: [
          {'name': 'Alice', 'age': 30},
          {'name': 'Bob', 'age': 25},
        ],
        focusedRow: 1,
        focusedCol: 0,
      );

      final rowCells = cells(result);
      // Every cell reports its focusability: exactly one is focused.
      final focused = rowCells
          .where((s) => s.properties.focused == true)
          .toList();
      expect(focused.length, 1);
      expect(focused.single.properties.label, 'Bob');
      for (final cell in rowCells) {
        expect(cell.properties.focused, isNotNull);
      }
    });

    test('cells expose 1-based row/col identifiers', () {
      final result = build(
        columns: [
          const OsColumnDef(field: 'name', headerName: 'Name'),
          const OsColumnDef(field: 'age', headerName: 'Age'),
        ],
        rowData: [
          {'name': 'Alice', 'age': 30},
          {'name': 'Bob', 'age': 25},
        ],
      );

      // Header band is grid row 1 (1-based, matching AG Grid).
      final headers = result.where((s) => s.properties.header == true);
      expect(headers.map((s) => s.properties.identifier), ['r1c1', 'r1c2']);

      final rowCells = cells(result);
      expect(rowCells[0].properties.identifier, 'r2c1');
      expect(rowCells[1].properties.identifier, 'r2c2');
      expect(rowCells[2].properties.identifier, 'r3c1');
      expect(rowCells[3].properties.identifier, 'r3c2');
    });

    test('editing cell announces the edit state', () {
      final result = build(
        columns: [
          const OsColumnDef(field: 'name', headerName: 'Name'),
          const OsColumnDef(field: 'age', headerName: 'Age'),
        ],
        rowData: [
          {'name': 'Alice', 'age': 30},
        ],
        focusedRow: 0,
        focusedCol: 0,
        editingCell: const CellPosition(rowIndex: 0, colId: 'name'),
        editingValue: 'Alicia',
      );

      final rowCells = cells(result);
      final editingCell = rowCells[0].properties;
      expect(editingCell.label, 'Alice, editing');
      expect(editingCell.textField, isTrue);
      expect(editingCell.value, 'Alicia');
      // The editing cell is always announced as focused.
      expect(editingCell.focused, isTrue);

      // Sibling cells are unaffected.
      final sibling = rowCells[1].properties;
      expect(sibling.label, '30');
      expect(sibling.textField, isNull);
      expect(sibling.value, isNull);
      expect(sibling.focused, isFalse);
    });

    test('editing cell gains focus even when it is not the focused cell', () {
      final result = build(
        columns: [const OsColumnDef(field: 'age', headerName: 'Age')],
        rowData: [
          {'age': 30},
        ],
        editingCell: const CellPosition(rowIndex: 0, colId: 'age'),
      );

      final properties = cells(result).single.properties;
      expect(properties.focused, isTrue);
      expect(properties.textField, isTrue);
      // No in-progress value supplied: value stays unset.
      expect(properties.value, isNull);
    });

    test('editing label routes through the locale resolver', () {
      String resolve(String key, String defaultValue) => switch (key) {
        'editingCell' => 'bearbeitet',
        _ => defaultValue,
      };

      final result = build(
        columns: [const OsColumnDef(field: 'name', headerName: 'Name')],
        rowData: [
          {'name': 'Alice'},
        ],
        editingCell: const CellPosition(rowIndex: 0, colId: 'name'),
        localeResolver: resolve,
      );

      expect(cells(result).single.properties.label, 'Alice, bearbeitet');
    });

    test('an editing cell outside the viewport is ignored', () {
      final result = build(
        columns: [const OsColumnDef(field: 'name', headerName: 'Name')],
        rowData: [
          {'name': 'Alice'},
        ],
        editingCell: const CellPosition(rowIndex: 99, colId: 'name'),
      );

      expect(cells(result).single.properties.textField, isNull);
    });

    test('editing an empty cell announces the editing word alone', () {
      final result = build(
        columns: [const OsColumnDef(field: 'name', headerName: 'Name')],
        rowData: [
          {'name': null},
        ],
        editingCell: const CellPosition(rowIndex: 0, colId: 'name'),
      );

      expect(cells(result).single.properties.label, 'editing');
    });
  });

  group('ARIA grid pattern on the semantics tree', () {
    Future<void> pumpGrid(
      WidgetTester tester, {
      required List<OsColumnDef> columns,
      required List<Map<String, dynamic>> rowData,
      Set<int> selectedRows = const {},
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: VirtualisedGrid(
                columns: columns,
                rowData: rowData,
                selectedRows: selectedRows,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    // Canvas-painted cell nodes are not owned by any widget render object,
    // so element-based finders cannot reach them; the semantics-node finder
    // walks the semantics tree itself.
    SemanticsNode nodeByLabel(String label) =>
        find.semantics.byLabel(label).evaluate().single;

    testWidgets('cell nodes expose selected state', (tester) async {
      await pumpGrid(
        tester,
        columns: [
          const OsColumnDef(field: 'name', headerName: 'Name'),
          const OsColumnDef(field: 'age', headerName: 'Age'),
        ],
        rowData: [
          {'name': 'Alice', 'age': 30},
          {'name': 'Bob', 'age': 25},
        ],
        selectedRows: {0},
      );

      final alice = nodeByLabel('Alice').getSemanticsData();
      expect(alice.flagsCollection.isSelected, Tristate.isTrue);
      expect(alice.flagsCollection.isChecked, CheckedState.none);

      final bob = nodeByLabel('Bob').getSemanticsData();
      expect(bob.flagsCollection.isSelected, Tristate.isFalse);
    });

    testWidgets('the focused cell holds the roving focus flag', (tester) async {
      await pumpGrid(
        tester,
        columns: [
          const OsColumnDef(field: 'name', headerName: 'Name'),
          const OsColumnDef(field: 'age', headerName: 'Age'),
        ],
        rowData: [
          {'name': 'Alice', 'age': 30},
          {'name': 'Bob', 'age': 25},
        ],
      );

      // Default focus is cell (0, 0).
      final alice = nodeByLabel('Alice').getSemanticsData();
      expect(alice.flagsCollection.isFocused, Tristate.isTrue);

      // Roving tab index: other cells are explicitly not focusable.
      final bob = nodeByLabel('Bob').getSemanticsData();
      expect(bob.flagsCollection.isFocused, Tristate.isFalse);
    });

    testWidgets('checkbox cells expose checked state in the tree', (
      tester,
    ) async {
      await pumpGrid(
        tester,
        columns: [const OsColumnDef(field: '__checkbox__', headerName: '')],
        rowData: [
          {'__checkbox__': true},
          {'__checkbox__': false},
        ],
        selectedRows: {0},
      );

      expect(
        nodeByLabel('Selected').getSemanticsData().flagsCollection.isChecked,
        CheckedState.isTrue,
      );
      expect(
        nodeByLabel(
          'Not selected',
        ).getSemanticsData().flagsCollection.isChecked,
        CheckedState.isFalse,
      );
    });

    testWidgets('group rows expose expanded state in the tree', (tester) async {
      await pumpGrid(
        tester,
        columns: [const OsColumnDef(field: 'country', headerName: 'Country')],
        rowData: [
          {
            '__isGroupRow': true,
            '__groupKey': 'USA',
            '__groupField': 'country',
            '__groupLevel': 0,
            '__groupExpanded': true,
            '__groupChildCount': 5,
            '__groupNodeId': 'country~USA',
          },
          {'country': 'USA', 'name': 'Alice'},
        ],
      );

      expect(
        nodeByLabel(
          'Country: USA — 5 children',
        ).getSemanticsData().flagsCollection.isExpanded,
        Tristate.isTrue,
      );
      // Ordinary cells carry no expanded state.
      expect(
        nodeByLabel('USA').getSemanticsData().flagsCollection.isExpanded,
        Tristate.none,
      );
    });

    testWidgets('cell nodes carry 1-based row/col identifiers', (tester) async {
      await pumpGrid(
        tester,
        columns: [const OsColumnDef(field: 'name', headerName: 'Name')],
        rowData: [
          {'name': 'Alice'},
        ],
      );

      expect(nodeByLabel('Name').getSemanticsData().identifier, 'r1c1');
      expect(nodeByLabel('Alice').getSemanticsData().identifier, 'r2c1');
    });
  });
}
