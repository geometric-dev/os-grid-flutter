import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

void main() {
  group('CellRange model', () {
    test('normalised accessors return min/max correctly', () {
      // Range dragged upward and leftward (end < start)
      const range = CellRange(
        startRow: 5,
        endRow: 2,
        startColumn: 4,
        endColumn: 1,
      );

      expect(range.normalizedStartRow, 2);
      expect(range.normalizedEndRow, 5);
      expect(range.normalizedStartColumn, 1);
      expect(range.normalizedEndColumn, 4);
    });

    test('normalised accessors work when start < end', () {
      const range = CellRange(
        startRow: 1,
        endRow: 3,
        startColumn: 0,
        endColumn: 2,
      );

      expect(range.normalizedStartRow, 1);
      expect(range.normalizedEndRow, 3);
      expect(range.normalizedStartColumn, 0);
      expect(range.normalizedEndColumn, 2);
    });

    test('rowCount and columnCount are correct', () {
      const range = CellRange(
        startRow: 2,
        endRow: 5,
        startColumn: 1,
        endColumn: 3,
      );

      expect(range.rowCount, 4); // rows 2, 3, 4, 5
      expect(range.columnCount, 3); // cols 1, 2, 3
    });

    test('isSingleCell returns true for 1x1 range', () {
      const range = CellRange(
        startRow: 3,
        endRow: 3,
        startColumn: 2,
        endColumn: 2,
      );

      expect(range.isSingleCell, true);
    });

    test('isSingleCell returns false for multi-cell range', () {
      const range = CellRange(
        startRow: 3,
        endRow: 4,
        startColumn: 2,
        endColumn: 2,
      );

      expect(range.isSingleCell, false);
    });

    test('containsCell returns true for cells inside range', () {
      const range = CellRange(
        startRow: 1,
        endRow: 3,
        startColumn: 1,
        endColumn: 3,
      );

      expect(range.containsCell(1, 1), true);
      expect(range.containsCell(2, 2), true);
      expect(range.containsCell(3, 3), true);
      expect(range.containsCell(1, 3), true);
      expect(range.containsCell(3, 1), true);
    });

    test('containsCell returns false for cells outside range', () {
      const range = CellRange(
        startRow: 1,
        endRow: 3,
        startColumn: 1,
        endColumn: 3,
      );

      expect(range.containsCell(0, 0), false);
      expect(range.containsCell(0, 2), false);
      expect(range.containsCell(2, 0), false);
      expect(range.containsCell(4, 2), false);
      expect(range.containsCell(2, 4), false);
    });

    test('containsCell works with reversed ranges (end < start)', () {
      const range = CellRange(
        startRow: 5,
        endRow: 2,
        startColumn: 4,
        endColumn: 1,
      );

      expect(range.containsCell(3, 2), true);
      expect(range.containsCell(2, 1), true);
      expect(range.containsCell(5, 4), true);
      expect(range.containsCell(1, 2), false);
      expect(range.containsCell(6, 2), false);
    });

    test('copyWithEnd creates a new range with updated end', () {
      const range = CellRange(
        startRow: 1,
        endRow: 1,
        startColumn: 1,
        endColumn: 1,
      );

      final extended = range.copyWithEnd(endRow: 5, endColumn: 3);

      expect(extended.startRow, 1);
      expect(extended.startColumn, 1);
      expect(extended.endRow, 5);
      expect(extended.endColumn, 3);
    });

    test('equality works correctly', () {
      const range1 = CellRange(
        startRow: 1,
        endRow: 3,
        startColumn: 0,
        endColumn: 2,
      );
      const range2 = CellRange(
        startRow: 1,
        endRow: 3,
        startColumn: 0,
        endColumn: 2,
      );
      const range3 = CellRange(
        startRow: 1,
        endRow: 4,
        startColumn: 0,
        endColumn: 2,
      );

      expect(range1, equals(range2));
      expect(range1, isNot(equals(range3)));
      expect(range1.hashCode, equals(range2.hashCode));
    });

    test('toString provides readable output', () {
      const range = CellRange(
        startRow: 1,
        endRow: 3,
        startColumn: 0,
        endColumn: 2,
      );

      expect(range.toString(), contains('rows: 1..3'));
      expect(range.toString(), contains('cols: 0..2'));
    });
  });

  group('OsCellSelection configuration', () {
    test('default suppressMultiRanges is true', () {
      const config = OsCellSelection();
      expect(config.suppressMultiRanges, true);
    });

    test('suppressMultiRanges can be set to false', () {
      const config = OsCellSelection(suppressMultiRanges: false);
      expect(config.suppressMultiRanges, false);
    });
  });

  group('CellRangeParams', () {
    test('holds correct values', () {
      const params = CellRangeParams(
        rowStartIndex: 0,
        rowEndIndex: 5,
        columnStartIndex: 1,
        columnEndIndex: 3,
      );

      expect(params.rowStartIndex, 0);
      expect(params.rowEndIndex, 5);
      expect(params.columnStartIndex, 1);
      expect(params.columnEndIndex, 3);
    });
  });

  group('OsRangeSelectionChangedEvent', () {
    test('holds ranges and flags', () {
      const event = OsRangeSelectionChangedEvent(
        ranges: [
          CellRange(startRow: 0, endRow: 2, startColumn: 0, endColumn: 1),
        ],
        started: true,
        finished: false,
      );

      expect(event.ranges.length, 1);
      expect(event.started, true);
      expect(event.finished, false);
    });

    test('defaults: started=false, finished=true', () {
      const event = OsRangeSelectionChangedEvent(ranges: []);

      expect(event.started, false);
      expect(event.finished, true);
    });
  });

  group('OsGridController — range selection API', () {
    test('getCellRanges returns empty list initially', () {
      final controller = OsGridController<Map<String, dynamic>>();
      expect(controller.getCellRanges(), isEmpty);
      controller.dispose();
    });

    test('addCellRange adds a range and emits event', () async {
      final controller = OsGridController<Map<String, dynamic>>();
      final events = <OsRangeSelectionChangedEvent>[];
      final sub = controller.onRangeSelectionChanged.listen(events.add);

      controller.addCellRange(
        const CellRangeParams(
          rowStartIndex: 0,
          rowEndIndex: 3,
          columnStartIndex: 1,
          columnEndIndex: 2,
        ),
      );

      await Future<void>.delayed(Duration.zero);

      expect(controller.getCellRanges().length, 1);
      final range = controller.getCellRanges().first;
      expect(range.startRow, 0);
      expect(range.endRow, 3);
      expect(range.startColumn, 1);
      expect(range.endColumn, 2);

      expect(events.length, 1);
      expect(events.first.finished, true);
      expect(events.first.ranges.length, 1);

      await sub.cancel();
      controller.dispose();
    });

    test('addCellRange supports multiple ranges', () async {
      final controller = OsGridController<Map<String, dynamic>>();

      controller.addCellRange(
        const CellRangeParams(
          rowStartIndex: 0,
          rowEndIndex: 2,
          columnStartIndex: 0,
          columnEndIndex: 1,
        ),
      );
      controller.addCellRange(
        const CellRangeParams(
          rowStartIndex: 5,
          rowEndIndex: 7,
          columnStartIndex: 2,
          columnEndIndex: 3,
        ),
      );

      expect(controller.getCellRanges().length, 2);
      controller.dispose();
    });

    test('clearRangeSelection removes all ranges and emits event', () async {
      final controller = OsGridController<Map<String, dynamic>>();
      final events = <OsRangeSelectionChangedEvent>[];
      final sub = controller.onRangeSelectionChanged.listen(events.add);

      controller.addCellRange(
        const CellRangeParams(
          rowStartIndex: 0,
          rowEndIndex: 2,
          columnStartIndex: 0,
          columnEndIndex: 1,
        ),
      );
      controller.addCellRange(
        const CellRangeParams(
          rowStartIndex: 3,
          rowEndIndex: 5,
          columnStartIndex: 1,
          columnEndIndex: 2,
        ),
      );

      controller.clearRangeSelection();

      await Future<void>.delayed(Duration.zero);

      expect(controller.getCellRanges(), isEmpty);
      // Last event should have empty ranges
      expect(events.last.ranges, isEmpty);
      expect(events.last.finished, true);

      await sub.cancel();
      controller.dispose();
    });

    test('clearRangeSelection does nothing when already empty', () async {
      final controller = OsGridController<Map<String, dynamic>>();
      final events = <OsRangeSelectionChangedEvent>[];
      final sub = controller.onRangeSelectionChanged.listen(events.add);

      controller.clearRangeSelection();

      await Future<void>.delayed(Duration.zero);

      // No event should be emitted
      expect(events, isEmpty);

      await sub.cancel();
      controller.dispose();
    });

    test('getCellRanges returns unmodifiable list', () {
      final controller = OsGridController<Map<String, dynamic>>();

      controller.addCellRange(
        const CellRangeParams(
          rowStartIndex: 0,
          rowEndIndex: 1,
          columnStartIndex: 0,
          columnEndIndex: 1,
        ),
      );

      final ranges = controller.getCellRanges();
      expect(
        () => ranges.add(
          const CellRange(startRow: 0, endRow: 0, startColumn: 0, endColumn: 0),
        ),
        throwsA(isA<UnsupportedError>()),
      );

      controller.dispose();
    });

    test(
      'onRangeSelectionChanged stream supports multiple listeners',
      () async {
        final controller = OsGridController<Map<String, dynamic>>();
        final events1 = <OsRangeSelectionChangedEvent>[];
        final events2 = <OsRangeSelectionChangedEvent>[];
        final sub1 = controller.onRangeSelectionChanged.listen(events1.add);
        final sub2 = controller.onRangeSelectionChanged.listen(events2.add);

        controller.addCellRange(
          const CellRangeParams(
            rowStartIndex: 0,
            rowEndIndex: 1,
            columnStartIndex: 0,
            columnEndIndex: 1,
          ),
        );

        await Future<void>.delayed(Duration.zero);

        expect(events1.length, 1);
        expect(events2.length, 1);

        await sub1.cancel();
        await sub2.cancel();
        controller.dispose();
      },
    );
  });

  group('OsGrid widget — range selection integration', () {
    testWidgets('cellSelection property enables range selection', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              columnDefs: [
                OsColumnDef(field: 'name', headerName: 'Name'),
                OsColumnDef(field: 'age', headerName: 'Age'),
              ],
              rowData: [
                {'name': 'Alice', 'age': 32},
                {'name': 'Bob', 'age': 28},
              ],
              cellSelection: OsCellSelection(),
            ),
          ),
        ),
      );

      // Widget should render without errors
      expect(find.byType(OsGrid<Map<String, dynamic>>), findsOneWidget);
    });

    testWidgets('onRangeSelectionChanged callback is wired up', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();
      var callbackFired = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              columnDefs: const [
                OsColumnDef(field: 'name', headerName: 'Name'),
                OsColumnDef(field: 'age', headerName: 'Age'),
              ],
              rowData: const [
                {'name': 'Alice', 'age': 32},
                {'name': 'Bob', 'age': 28},
              ],
              cellSelection: const OsCellSelection(),
              onRangeSelectionChanged: (event) => callbackFired = true,
            ),
          ),
        ),
      );

      // Programmatically add a range via controller
      controller.addCellRange(
        const CellRangeParams(
          rowStartIndex: 0,
          rowEndIndex: 1,
          columnStartIndex: 0,
          columnEndIndex: 1,
        ),
      );

      await tester.pump();

      // The controller stream should have emitted
      expect(controller.getCellRanges().length, 1);
      expect(callbackFired, isTrue);
    });

    testWidgets('grid renders without cellSelection (disabled by default)', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              columnDefs: [OsColumnDef(field: 'name', headerName: 'Name')],
              rowData: [
                {'name': 'Alice'},
              ],
            ),
          ),
        ),
      );

      expect(find.byType(OsGrid<Map<String, dynamic>>), findsOneWidget);
    });
  });
}
