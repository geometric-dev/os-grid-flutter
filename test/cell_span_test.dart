import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

void main() {
  group('CellSpanService', () {
    late CellSpanService service;

    setUp(() {
      service = CellSpanService();
    });

    group('spanRows (auto-merge equal values)', () {
      test('merges consecutive rows with equal values', () {
        final columns = [
          const OsColumnDef<Map<String, dynamic>>(
            field: 'category',
            spanRows: true,
          ),
        ];
        final rowData = [
          {'category': 'A', 'value': 1},
          {'category': 'A', 'value': 2},
          {'category': 'A', 'value': 3},
          {'category': 'B', 'value': 4},
          {'category': 'B', 'value': 5},
        ];

        service.buildCache(
          columns: columns,
          rowData: rowData,
          enableCellSpan: true,
        );

        // Rows 0-2 should be merged (category 'A')
        expect(service.isRowSpanHead(0, 'category'), isTrue);
        expect(service.isConsumedByRowSpan(1, 'category'), isTrue);
        expect(service.isConsumedByRowSpan(2, 'category'), isTrue);
        expect(service.getRowSpanCount(0, 'category'), 3);

        // Rows 3-4 should be merged (category 'B')
        expect(service.isRowSpanHead(3, 'category'), isTrue);
        expect(service.isConsumedByRowSpan(4, 'category'), isTrue);
        expect(service.getRowSpanCount(3, 'category'), 2);
      });

      test('does not merge different values', () {
        final columns = [
          const OsColumnDef<Map<String, dynamic>>(
            field: 'category',
            spanRows: true,
          ),
        ];
        final rowData = [
          {'category': 'A'},
          {'category': 'B'},
          {'category': 'C'},
        ];

        service.buildCache(
          columns: columns,
          rowData: rowData,
          enableCellSpan: true,
        );

        expect(service.isRowSpanHead(0, 'category'), isFalse);
        expect(service.isRowSpanHead(1, 'category'), isFalse);
        expect(service.isRowSpanHead(2, 'category'), isFalse);
        expect(service.getRowSpanCount(0, 'category'), 1);
        expect(service.getRowSpanCount(1, 'category'), 1);
        expect(service.getRowSpanCount(2, 'category'), 1);
      });

      test('handles single row (no span possible)', () {
        final columns = [
          const OsColumnDef<Map<String, dynamic>>(
            field: 'category',
            spanRows: true,
          ),
        ];
        final rowData = [
          {'category': 'A'},
        ];

        service.buildCache(
          columns: columns,
          rowData: rowData,
          enableCellSpan: true,
        );

        expect(service.isRowSpanHead(0, 'category'), isFalse);
        expect(service.getRowSpanCount(0, 'category'), 1);
      });

      test('handles empty data', () {
        final columns = [
          const OsColumnDef<Map<String, dynamic>>(
            field: 'category',
            spanRows: true,
          ),
        ];

        service.buildCache(columns: columns, rowData: [], enableCellSpan: true);

        expect(service.allRowSpanGroups, isEmpty);
      });

      test('handles null values (merges nulls together)', () {
        final columns = [
          const OsColumnDef<Map<String, dynamic>>(
            field: 'category',
            spanRows: true,
          ),
        ];
        final rowData = [
          {'category': null},
          {'category': null},
          {'category': 'A'},
        ];

        service.buildCache(
          columns: columns,
          rowData: rowData,
          enableCellSpan: true,
        );

        expect(service.isRowSpanHead(0, 'category'), isTrue);
        expect(service.isConsumedByRowSpan(1, 'category'), isTrue);
        expect(service.getRowSpanCount(0, 'category'), 2);
      });

      test('custom spanRows function controls merging', () {
        final columns = [
          OsColumnDef<Map<String, dynamic>>(
            field: 'value',
            spanRows: (SpanRowsParams params) {
              // Merge if both values are even or both are odd
              final a = params.valueA as int?;
              final b = params.valueB as int?;
              if (a == null || b == null) return false;
              return a.isEven == b.isEven;
            },
          ),
        ];
        final rowData = [
          {'value': 2},
          {'value': 4},
          {'value': 6},
          {'value': 3},
          {'value': 5},
        ];

        service.buildCache(
          columns: columns,
          rowData: rowData,
          enableCellSpan: true,
        );

        // Rows 0-2 merged (all even)
        expect(service.getRowSpanCount(0, 'value'), 3);
        // Rows 3-4 merged (all odd)
        expect(service.getRowSpanCount(3, 'value'), 2);
      });

      test('multiple columns can have independent spans', () {
        final columns = [
          const OsColumnDef<Map<String, dynamic>>(
            field: 'category',
            spanRows: true,
          ),
          const OsColumnDef<Map<String, dynamic>>(
            field: 'region',
            spanRows: true,
          ),
        ];
        final rowData = [
          {'category': 'A', 'region': 'North'},
          {'category': 'A', 'region': 'North'},
          {'category': 'A', 'region': 'South'},
          {'category': 'B', 'region': 'South'},
        ];

        service.buildCache(
          columns: columns,
          rowData: rowData,
          enableCellSpan: true,
        );

        // Category: rows 0-2 merged
        expect(service.getRowSpanCount(0, 'category'), 3);
        // Region: rows 0-1 merged, rows 2-3 merged
        expect(service.getRowSpanCount(0, 'region'), 2);
        expect(service.getRowSpanCount(2, 'region'), 2);
      });
    });

    group('rowSpan (explicit callback)', () {
      test('creates spans based on callback return value', () {
        final columns = [
          OsColumnDef<Map<String, dynamic>>(
            field: 'name',
            rowSpan: (RowSpanParams params) {
              if (params.rowIndex == 0) return 3;
              return 1;
            },
          ),
        ];
        final rowData = [
          {'name': 'Header'},
          {'name': 'Row 1'},
          {'name': 'Row 2'},
          {'name': 'Row 3'},
          {'name': 'Row 4'},
        ];

        service.buildCache(
          columns: columns,
          rowData: rowData,
          enableCellSpan: true,
        );

        expect(service.isRowSpanHead(0, 'name'), isTrue);
        expect(service.isConsumedByRowSpan(1, 'name'), isTrue);
        expect(service.isConsumedByRowSpan(2, 'name'), isTrue);
        expect(service.isConsumedByRowSpan(3, 'name'), isFalse);
        expect(service.getRowSpanCount(0, 'name'), 3);
      });

      test('rowSpan of 1 means no spanning', () {
        final columns = [
          OsColumnDef<Map<String, dynamic>>(
            field: 'name',
            rowSpan: (RowSpanParams params) => 1,
          ),
        ];
        final rowData = [
          {'name': 'A'},
          {'name': 'B'},
        ];

        service.buildCache(
          columns: columns,
          rowData: rowData,
          enableCellSpan: true,
        );

        expect(service.allRowSpanGroups, isEmpty);
      });

      test('rowSpan clamps to available rows', () {
        final columns = [
          OsColumnDef<Map<String, dynamic>>(
            field: 'name',
            rowSpan: (RowSpanParams params) => 10, // More than available
          ),
        ];
        final rowData = [
          {'name': 'A'},
          {'name': 'B'},
          {'name': 'C'},
        ];

        service.buildCache(
          columns: columns,
          rowData: rowData,
          enableCellSpan: true,
        );

        // Should clamp to 3 (all available rows)
        expect(service.getRowSpanCount(0, 'name'), 3);
      });

      test('consumed rows are skipped for subsequent spans', () {
        final columns = [
          OsColumnDef<Map<String, dynamic>>(
            field: 'name',
            rowSpan: (RowSpanParams params) {
              if (params.rowIndex == 0) return 2;
              if (params.rowIndex == 2) return 2;
              return 1;
            },
          ),
        ];
        final rowData = [
          {'name': 'A'},
          {'name': 'B'},
          {'name': 'C'},
          {'name': 'D'},
          {'name': 'E'},
        ];

        service.buildCache(
          columns: columns,
          rowData: rowData,
          enableCellSpan: true,
        );

        // Row 0 spans 2 (rows 0-1)
        expect(service.getRowSpanCount(0, 'name'), 2);
        // Row 1 is consumed
        expect(service.isConsumedByRowSpan(1, 'name'), isTrue);
        // Row 2 spans 2 (rows 2-3)
        expect(service.getRowSpanCount(2, 'name'), 2);
        // Row 3 is consumed
        expect(service.isConsumedByRowSpan(3, 'name'), isTrue);
        // Row 4 is normal
        expect(service.getRowSpanCount(4, 'name'), 1);
      });
    });

    group('colSpan', () {
      test('returns 1 when no colSpan configured', () {
        const column = OsColumnDef<Map<String, dynamic>>(field: 'name');
        final rowData = {'name': 'test'};

        final result = service.getColSpan(
          column: column,
          rowData: rowData,
          rowIndex: 0,
        );

        expect(result, 1);
      });

      test('returns callback result', () {
        final column = OsColumnDef<Map<String, dynamic>>(
          field: 'name',
          colSpan: (ColSpanParams params) => 3,
        );
        final rowData = {'name': 'test'};

        final result = service.getColSpan(
          column: column,
          rowData: rowData,
          rowIndex: 0,
        );

        expect(result, 3);
      });

      test('clamps values less than 1 to 1', () {
        final column = OsColumnDef<Map<String, dynamic>>(
          field: 'name',
          colSpan: (ColSpanParams params) => 0,
        );
        final rowData = {'name': 'test'};

        final result = service.getColSpan(
          column: column,
          rowData: rowData,
          rowIndex: 0,
        );

        expect(result, 1);
      });

      test('passes correct params to callback', () {
        ColSpanParams? capturedParams;
        final column = OsColumnDef<Map<String, dynamic>>(
          field: 'name',
          colSpan: (ColSpanParams params) {
            capturedParams = params;
            return 1;
          },
        );
        final rowData = {'name': 'test', 'other': 42};

        service.getColSpan(column: column, rowData: rowData, rowIndex: 5);

        expect(capturedParams, isNotNull);
        expect(capturedParams!.rowIndex, 5);
        expect(capturedParams!.column, 'name');
        expect(capturedParams!.data, rowData);
      });
    });

    group('enableCellSpan gate', () {
      test('does nothing when enableCellSpan is false', () {
        final columns = [
          const OsColumnDef<Map<String, dynamic>>(
            field: 'category',
            spanRows: true,
          ),
        ];
        final rowData = [
          {'category': 'A'},
          {'category': 'A'},
          {'category': 'A'},
        ];

        service.buildCache(
          columns: columns,
          rowData: rowData,
          enableCellSpan: false,
        );

        expect(service.allRowSpanGroups, isEmpty);
        expect(service.isRowSpanHead(0, 'category'), isFalse);
        expect(service.isConsumedByRowSpan(1, 'category'), isFalse);
      });
    });

    group('RowSpanGroup', () {
      test('rowCount returns correct value', () {
        final group = RowSpanGroup(
          firstRowIndex: 2,
          lastRowIndex: 5,
          colId: 'test',
        );
        expect(group.rowCount, 4);
      });

      test('isConsumedRow returns true for non-head rows in span', () {
        final group = RowSpanGroup(
          firstRowIndex: 2,
          lastRowIndex: 5,
          colId: 'test',
        );
        expect(group.isConsumedRow(2), isFalse); // head
        expect(group.isConsumedRow(3), isTrue);
        expect(group.isConsumedRow(4), isTrue);
        expect(group.isConsumedRow(5), isTrue);
        expect(group.isConsumedRow(6), isFalse); // outside
      });

      test('isHead returns true only for first row', () {
        final group = RowSpanGroup(
          firstRowIndex: 2,
          lastRowIndex: 5,
          colId: 'test',
        );
        expect(group.isHead(1), isFalse);
        expect(group.isHead(2), isTrue);
        expect(group.isHead(3), isFalse);
      });

      test('contains returns true for all rows in span', () {
        final group = RowSpanGroup(
          firstRowIndex: 2,
          lastRowIndex: 5,
          colId: 'test',
        );
        expect(group.contains(1), isFalse);
        expect(group.contains(2), isTrue);
        expect(group.contains(3), isTrue);
        expect(group.contains(5), isTrue);
        expect(group.contains(6), isFalse);
      });
    });

    group('cache rebuild', () {
      test('rebuilding cache clears previous spans', () {
        final columns = [
          const OsColumnDef<Map<String, dynamic>>(
            field: 'category',
            spanRows: true,
          ),
        ];

        // First build: rows 0-2 merged
        service.buildCache(
          columns: columns,
          rowData: [
            {'category': 'A'},
            {'category': 'A'},
            {'category': 'A'},
          ],
          enableCellSpan: true,
        );
        expect(service.getRowSpanCount(0, 'category'), 3);

        // Second build: no merging
        service.buildCache(
          columns: columns,
          rowData: [
            {'category': 'A'},
            {'category': 'B'},
            {'category': 'C'},
          ],
          enableCellSpan: true,
        );
        expect(service.getRowSpanCount(0, 'category'), 1);
        expect(service.allRowSpanGroups, isEmpty);
      });
    });

    group('getRowSpanGroup', () {
      test('returns the group for a cell in a span', () {
        final columns = [
          const OsColumnDef<Map<String, dynamic>>(
            field: 'category',
            spanRows: true,
          ),
        ];
        final rowData = [
          {'category': 'A'},
          {'category': 'A'},
          {'category': 'A'},
        ];

        service.buildCache(
          columns: columns,
          rowData: rowData,
          enableCellSpan: true,
        );

        final group = service.getRowSpanGroup(1, 'category');
        expect(group, isNotNull);
        expect(group!.firstRowIndex, 0);
        expect(group.lastRowIndex, 2);
        expect(group.colId, 'category');
      });

      test('returns null for cells not in a span', () {
        final columns = [
          const OsColumnDef<Map<String, dynamic>>(
            field: 'category',
            spanRows: true,
          ),
        ];
        final rowData = [
          {'category': 'A'},
          {'category': 'B'},
        ];

        service.buildCache(
          columns: columns,
          rowData: rowData,
          enableCellSpan: true,
        );

        expect(service.getRowSpanGroup(0, 'category'), isNull);
        expect(service.getRowSpanGroup(1, 'category'), isNull);
      });

      test('returns null for unknown column', () {
        final columns = [
          const OsColumnDef<Map<String, dynamic>>(
            field: 'category',
            spanRows: true,
          ),
        ];
        final rowData = [
          {'category': 'A'},
          {'category': 'A'},
        ];

        service.buildCache(
          columns: columns,
          rowData: rowData,
          enableCellSpan: true,
        );

        expect(service.getRowSpanGroup(0, 'unknown'), isNull);
      });
    });
  });

  group('CellSpanModule widget integration', () {
    testWidgets('enableCellSpan property is accepted by OsGrid', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              enableCellSpan: true,
              columnDefs: [
                OsColumnDef(field: 'category', spanRows: true),
                OsColumnDef(field: 'value'),
              ],
              rowData: [
                {'category': 'A', 'value': 1},
                {'category': 'A', 'value': 2},
                {'category': 'B', 'value': 3},
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Grid should render without errors
      expect(find.byType(OsGrid<Map<String, dynamic>>), findsOneWidget);
    });

    testWidgets('colSpan property is accepted by OsColumnDef', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              enableCellSpan: true,
              columnDefs: [
                OsColumnDef(
                  field: 'name',
                  colSpan: (params) => params.rowIndex == 0 ? 2 : 1,
                ),
                const OsColumnDef(field: 'value'),
              ],
              rowData: [
                {'name': 'Header', 'value': 1},
                {'name': 'Row 1', 'value': 2},
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(OsGrid<Map<String, dynamic>>), findsOneWidget);
    });

    testWidgets('rowSpan property is accepted by OsColumnDef', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              enableCellSpan: true,
              columnDefs: [
                OsColumnDef(
                  field: 'name',
                  rowSpan: (params) => params.rowIndex == 0 ? 3 : 1,
                ),
                const OsColumnDef(field: 'value'),
              ],
              rowData: [
                {'name': 'Merged', 'value': 1},
                {'name': 'Row 1', 'value': 2},
                {'name': 'Row 2', 'value': 3},
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(OsGrid<Map<String, dynamic>>), findsOneWidget);
    });

    testWidgets('grid renders without enableCellSpan (default false)', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              columnDefs: [
                OsColumnDef(
                  field: 'name',
                  spanRows:
                      true, // Should be ignored when enableCellSpan is false
                ),
              ],
              rowData: [
                {'name': 'A'},
                {'name': 'A'},
                {'name': 'B'},
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(OsGrid<Map<String, dynamic>>), findsOneWidget);
    });
  });
}
