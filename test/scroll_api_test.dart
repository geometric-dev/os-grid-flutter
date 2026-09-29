import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

void main() {
  group('ScrollCommand model classes', () {
    group('EnsureColumnVisibleCommand', () {
      test('stores columnIndex and default position', () {
        const cmd = EnsureColumnVisibleCommand(columnIndex: 3);
        expect(cmd.columnIndex, 3);
        expect(cmd.position, ColumnScrollPosition.auto);
      });

      test('stores explicit position', () {
        const cmd = EnsureColumnVisibleCommand(
          columnIndex: 5,
          position: ColumnScrollPosition.middle,
        );
        expect(cmd.columnIndex, 5);
        expect(cmd.position, ColumnScrollPosition.middle);
      });

      test('all ColumnScrollPosition values are distinct', () {
        const values = ColumnScrollPosition.values;
        expect(values.length, 4);
        expect(values, contains(ColumnScrollPosition.auto));
        expect(values, contains(ColumnScrollPosition.start));
        expect(values, contains(ColumnScrollPosition.middle));
        expect(values, contains(ColumnScrollPosition.end));
      });
    });

    group('EnsureIndexVisibleCommand', () {
      test('stores rowIndex and null position (auto)', () {
        const cmd = EnsureIndexVisibleCommand(rowIndex: 10);
        expect(cmd.rowIndex, 10);
        expect(cmd.position, isNull);
      });

      test('stores explicit position', () {
        const cmd = EnsureIndexVisibleCommand(
          rowIndex: 42,
          position: RowScrollPosition.middle,
        );
        expect(cmd.rowIndex, 42);
        expect(cmd.position, RowScrollPosition.middle);
      });

      test('all RowScrollPosition values are distinct', () {
        const values = RowScrollPosition.values;
        expect(values.length, 3);
        expect(values, contains(RowScrollPosition.top));
        expect(values, contains(RowScrollPosition.middle));
        expect(values, contains(RowScrollPosition.bottom));
      });
    });

    group('ScrollCommand sealed class', () {
      test('EnsureColumnVisibleCommand is a ScrollCommand', () {
        const ScrollCommand cmd = EnsureColumnVisibleCommand(columnIndex: 0);
        expect(cmd, isA<EnsureColumnVisibleCommand>());
      });

      test('EnsureIndexVisibleCommand is a ScrollCommand', () {
        const ScrollCommand cmd = EnsureIndexVisibleCommand(rowIndex: 0);
        expect(cmd, isA<EnsureIndexVisibleCommand>());
      });

      test('exhaustive switch covers all subtypes', () {
        const ScrollCommand cmd = EnsureColumnVisibleCommand(columnIndex: 1);
        final result = switch (cmd) {
          EnsureColumnVisibleCommand() => 'column',
          EnsureIndexVisibleCommand() => 'row',
          SetHorizontalScrollCommand() => 'horizontal',
        };
        expect(result, 'column');
      });
    });
  });

  group('ValueNotifier communication pattern', () {
    test('scrollCommandNotifier starts as null', () {
      final controller = OsGridController<Map<String, dynamic>>();
      expect(controller.scrollCommandNotifier.value, isNull);
      controller.dispose();
    });

    test('ensureIndexVisible sets scrollCommandNotifier value', () {
      final controller = OsGridController<Map<String, dynamic>>();
      controller.setRowData([
        {'name': 'Alice'},
        {'name': 'Bob'},
      ]);

      controller.ensureIndexVisible(1, position: RowScrollPosition.top);

      final cmd = controller.scrollCommandNotifier.value;
      expect(cmd, isA<EnsureIndexVisibleCommand>());
      final indexCmd = cmd as EnsureIndexVisibleCommand;
      expect(indexCmd.rowIndex, 1);
      expect(indexCmd.position, RowScrollPosition.top);

      controller.dispose();
    });

    test('ensureIndexVisible with null position emits null position', () {
      final controller = OsGridController<Map<String, dynamic>>();
      controller.setRowData([
        {'x': 1},
        {'x': 2},
        {'x': 3},
      ]);

      controller.ensureIndexVisible(2);

      final cmd =
          controller.scrollCommandNotifier.value as EnsureIndexVisibleCommand;
      expect(cmd.rowIndex, 2);
      expect(cmd.position, isNull);

      controller.dispose();
    });

    test('notifier fires listener when command is set', () {
      final controller = OsGridController<Map<String, dynamic>>();
      controller.setRowData([
        {'a': 1},
      ]);

      ScrollCommand? received;
      controller.scrollCommandNotifier.addListener(() {
        received = controller.scrollCommandNotifier.value;
      });

      controller.ensureIndexVisible(0, position: RowScrollPosition.middle);
      expect(received, isA<EnsureIndexVisibleCommand>());

      controller.dispose();
    });

    test('consumer can reset notifier to null after handling', () {
      final controller = OsGridController<Map<String, dynamic>>();
      controller.setRowData([
        {'a': 1},
      ]);

      controller.ensureIndexVisible(0);
      expect(controller.scrollCommandNotifier.value, isNotNull);

      // Simulate what the virtualised grid does after executing the command.
      controller.scrollCommandNotifier.value = null;
      expect(controller.scrollCommandNotifier.value, isNull);

      controller.dispose();
    });

    test('multiple listeners can observe commands', () {
      final controller = OsGridController<Map<String, dynamic>>();
      controller.setRowData([
        {'a': 1},
      ]);

      final commands1 = <ScrollCommand?>[];
      final commands2 = <ScrollCommand?>[];

      controller.scrollCommandNotifier.addListener(() {
        commands1.add(controller.scrollCommandNotifier.value);
      });
      controller.scrollCommandNotifier.addListener(() {
        commands2.add(controller.scrollCommandNotifier.value);
      });

      controller.ensureIndexVisible(0, position: RowScrollPosition.top);

      expect(commands1.length, 1);
      expect(commands2.length, 1);
      expect(commands1.first, isA<EnsureIndexVisibleCommand>());
      expect(commands2.first, isA<EnsureIndexVisibleCommand>());

      controller.dispose();
    });

    test('setting notifier to null fires listener', () {
      final controller = OsGridController<Map<String, dynamic>>();
      controller.setRowData([
        {'a': 1},
      ]);

      int notifyCount = 0;
      controller.scrollCommandNotifier.addListener(() {
        notifyCount++;
      });

      controller.ensureIndexVisible(0);
      expect(notifyCount, 1);

      controller.scrollCommandNotifier.value = null;
      expect(notifyCount, 2);

      controller.dispose();
    });
  });

  group('ensureIndexVisible — bounds checking', () {
    test('negative index is a no-op', () {
      final controller = OsGridController<Map<String, dynamic>>();
      controller.setRowData([
        {'a': 1},
        {'a': 2},
      ]);

      controller.ensureIndexVisible(-1);
      expect(controller.scrollCommandNotifier.value, isNull);

      controller.dispose();
    });

    test('index equal to row count is a no-op', () {
      final controller = OsGridController<Map<String, dynamic>>();
      controller.setRowData([
        {'a': 1},
        {'a': 2},
      ]);

      controller.ensureIndexVisible(2); // count is 2, max valid index is 1
      expect(controller.scrollCommandNotifier.value, isNull);

      controller.dispose();
    });

    test('index greater than row count is a no-op', () {
      final controller = OsGridController<Map<String, dynamic>>();
      controller.setRowData([
        {'a': 1},
      ]);

      controller.ensureIndexVisible(100);
      expect(controller.scrollCommandNotifier.value, isNull);

      controller.dispose();
    });

    test('index 0 is valid for non-empty data', () {
      final controller = OsGridController<Map<String, dynamic>>();
      controller.setRowData([
        {'a': 1},
      ]);

      controller.ensureIndexVisible(0);
      expect(controller.scrollCommandNotifier.value, isNotNull);

      controller.dispose();
    });

    test('last valid index emits command', () {
      final controller = OsGridController<Map<String, dynamic>>();
      controller.setRowData([
        {'a': 1},
        {'a': 2},
        {'a': 3},
      ]);

      controller.ensureIndexVisible(2);
      final cmd =
          controller.scrollCommandNotifier.value as EnsureIndexVisibleCommand;
      expect(cmd.rowIndex, 2);

      controller.dispose();
    });

    test('empty row data makes any index a no-op', () {
      final controller = OsGridController<Map<String, dynamic>>();
      // No setRowData call — _rowData is empty.

      controller.ensureIndexVisible(0);
      expect(controller.scrollCommandNotifier.value, isNull);

      controller.dispose();
    });
  });

  group('ensureIndexVisible — position variants', () {
    test('null position emits command with null position', () {
      final controller = OsGridController<Map<String, dynamic>>();
      controller.setRowData([
        {'a': 1},
        {'a': 2},
      ]);

      controller.ensureIndexVisible(1);
      final cmd =
          controller.scrollCommandNotifier.value as EnsureIndexVisibleCommand;
      expect(cmd.position, isNull);

      controller.dispose();
    });

    test('RowScrollPosition.top emits command with top position', () {
      final controller = OsGridController<Map<String, dynamic>>();
      controller.setRowData([
        {'a': 1},
        {'a': 2},
      ]);

      controller.ensureIndexVisible(1, position: RowScrollPosition.top);
      final cmd =
          controller.scrollCommandNotifier.value as EnsureIndexVisibleCommand;
      expect(cmd.position, RowScrollPosition.top);

      controller.dispose();
    });

    test('RowScrollPosition.middle emits command with middle position', () {
      final controller = OsGridController<Map<String, dynamic>>();
      controller.setRowData([
        {'a': 1},
        {'a': 2},
      ]);

      controller.ensureIndexVisible(0, position: RowScrollPosition.middle);
      final cmd =
          controller.scrollCommandNotifier.value as EnsureIndexVisibleCommand;
      expect(cmd.position, RowScrollPosition.middle);

      controller.dispose();
    });

    test('RowScrollPosition.bottom emits command with bottom position', () {
      final controller = OsGridController<Map<String, dynamic>>();
      controller.setRowData([
        {'a': 1},
        {'a': 2},
      ]);

      controller.ensureIndexVisible(0, position: RowScrollPosition.bottom);
      final cmd =
          controller.scrollCommandNotifier.value as EnsureIndexVisibleCommand;
      expect(cmd.position, RowScrollPosition.bottom);

      controller.dispose();
    });
  });

  group('ensureIndexVisible — processed data awareness', () {
    test('uses processedData length when available', () {
      final controller = OsGridController<Map<String, dynamic>>();
      controller.setRowData([
        {'a': 1},
        {'a': 2},
        {'a': 3},
        {'a': 4},
        {'a': 5},
      ]);

      // Simulate filtered data (only 2 rows pass filter)
      controller.processedData = [
        {'a': 1},
        {'a': 3},
      ];

      // Index 1 is valid (within processedData bounds)
      controller.ensureIndexVisible(1);
      expect(controller.scrollCommandNotifier.value, isNotNull);

      // Reset
      controller.scrollCommandNotifier.value = null;

      // Index 2 is out of bounds for processedData (length 2)
      controller.ensureIndexVisible(2);
      expect(controller.scrollCommandNotifier.value, isNull);

      controller.dispose();
    });

    test('falls back to rowData length when processedData is empty', () {
      final controller = OsGridController<Map<String, dynamic>>();
      controller.setRowData([
        {'a': 1},
        {'a': 2},
        {'a': 3},
      ]);
      // processedData is empty by default

      // Index 2 is valid (within rowData bounds)
      controller.ensureIndexVisible(2);
      expect(controller.scrollCommandNotifier.value, isNotNull);

      controller.dispose();
    });
  });

  group('ensureIndexVisible — successive commands', () {
    test('second command overwrites first', () {
      final controller = OsGridController<Map<String, dynamic>>();
      controller.setRowData([
        {'a': 1},
        {'a': 2},
        {'a': 3},
      ]);

      controller.ensureIndexVisible(0, position: RowScrollPosition.top);
      controller.ensureIndexVisible(2, position: RowScrollPosition.bottom);

      final cmd =
          controller.scrollCommandNotifier.value as EnsureIndexVisibleCommand;
      expect(cmd.rowIndex, 2);
      expect(cmd.position, RowScrollPosition.bottom);

      controller.dispose();
    });

    test('command after reset is independent', () {
      final controller = OsGridController<Map<String, dynamic>>();
      controller.setRowData([
        {'a': 1},
        {'a': 2},
      ]);

      controller.ensureIndexVisible(0);
      controller.scrollCommandNotifier.value = null;

      controller.ensureIndexVisible(1, position: RowScrollPosition.middle);
      final cmd =
          controller.scrollCommandNotifier.value as EnsureIndexVisibleCommand;
      expect(cmd.rowIndex, 1);
      expect(cmd.position, RowScrollPosition.middle);

      controller.dispose();
    });
  });

  group('ensureColumnVisible — controller logic (unit)', () {
    // These tests set columnDefs directly on the controller to test
    // the command emission logic without a widget consuming the commands.

    test('emits command for a visible unpinned column', () {
      final controller = OsGridController<Map<String, dynamic>>();
      controller.columnDefs = const [
        OsColumnDef(field: 'a', width: 100),
        OsColumnDef(field: 'b', width: 100),
        OsColumnDef(field: 'c', width: 100),
      ];

      controller.ensureColumnVisible('c');

      final cmd =
          controller.scrollCommandNotifier.value as EnsureColumnVisibleCommand;
      expect(cmd.columnIndex, 2);
      expect(cmd.position, ColumnScrollPosition.auto);

      controller.dispose();
    });

    test('respects explicit position parameter', () {
      final controller = OsGridController<Map<String, dynamic>>();
      controller.columnDefs = const [
        OsColumnDef(field: 'a', width: 100),
        OsColumnDef(field: 'b', width: 100),
      ];

      controller.ensureColumnVisible('b', position: ColumnScrollPosition.end);

      final cmd =
          controller.scrollCommandNotifier.value as EnsureColumnVisibleCommand;
      expect(cmd.position, ColumnScrollPosition.end);

      controller.dispose();
    });

    test('pinned left column is a no-op', () {
      final controller = OsGridController<Map<String, dynamic>>();
      controller.columnDefs = const [
        OsColumnDef(field: 'a', width: 100, pinned: OsColumnPin.left),
        OsColumnDef(field: 'b', width: 100),
      ];

      controller.ensureColumnVisible('a');
      expect(controller.scrollCommandNotifier.value, isNull);

      controller.dispose();
    });

    test('pinned right column is a no-op', () {
      final controller = OsGridController<Map<String, dynamic>>();
      controller.columnDefs = const [
        OsColumnDef(field: 'a', width: 100),
        OsColumnDef(field: 'b', width: 100, pinned: OsColumnPin.right),
      ];

      controller.ensureColumnVisible('b');
      expect(controller.scrollCommandNotifier.value, isNull);

      controller.dispose();
    });

    test('unknown colId is a no-op', () {
      final controller = OsGridController<Map<String, dynamic>>();
      controller.columnDefs = const [OsColumnDef(field: 'a', width: 100)];

      controller.ensureColumnVisible('nonexistent');
      expect(controller.scrollCommandNotifier.value, isNull);

      controller.dispose();
    });

    test('hidden column is a no-op (not in displayed columns)', () {
      final controller = OsGridController<Map<String, dynamic>>();
      controller.columnDefs = const [
        OsColumnDef(field: 'a', width: 100),
        OsColumnDef(field: 'b', width: 100, hide: true),
      ];
      // The controller filters by _hiddenColumnIds (synced from widget state).
      controller.hiddenColumnIds = {'b'};

      controller.ensureColumnVisible('b');
      expect(controller.scrollCommandNotifier.value, isNull);

      controller.dispose();
    });

    test('null columnDefs is a no-op', () {
      final controller = OsGridController<Map<String, dynamic>>();
      // columnDefs is null by default

      controller.ensureColumnVisible('anything');
      expect(controller.scrollCommandNotifier.value, isNull);

      controller.dispose();
    });

    test('resolves column by field name', () {
      final controller = OsGridController<Map<String, dynamic>>();
      controller.columnDefs = const [
        OsColumnDef(field: 'name', width: 100),
        OsColumnDef(field: 'age', width: 100),
      ];

      controller.ensureColumnVisible('age');

      final cmd =
          controller.scrollCommandNotifier.value as EnsureColumnVisibleCommand;
      expect(cmd.columnIndex, 1);

      controller.dispose();
    });

    test('first column resolves to index 0', () {
      final controller = OsGridController<Map<String, dynamic>>();
      controller.columnDefs = const [
        OsColumnDef(field: 'first', width: 100),
        OsColumnDef(field: 'second', width: 100),
      ];

      controller.ensureColumnVisible('first');

      final cmd =
          controller.scrollCommandNotifier.value as EnsureColumnVisibleCommand;
      expect(cmd.columnIndex, 0);

      controller.dispose();
    });

    test('all ColumnScrollPosition variants emit correctly', () {
      final controller = OsGridController<Map<String, dynamic>>();
      controller.columnDefs = const [
        OsColumnDef(field: 'a', width: 100),
        OsColumnDef(field: 'b', width: 100),
      ];

      for (final pos in ColumnScrollPosition.values) {
        controller.ensureColumnVisible('b', position: pos);
        final cmd =
            controller.scrollCommandNotifier.value
                as EnsureColumnVisibleCommand;
        expect(cmd.position, pos, reason: 'Expected position $pos');
        // Reset for next iteration
        controller.scrollCommandNotifier.value = null;
      }

      controller.dispose();
    });

    test('ColumnScrollPosition.auto is the default', () {
      final controller = OsGridController<Map<String, dynamic>>();
      controller.columnDefs = const [
        OsColumnDef(field: 'a', width: 100),
        OsColumnDef(field: 'b', width: 100),
      ];

      controller.ensureColumnVisible('b');

      final cmd =
          controller.scrollCommandNotifier.value as EnsureColumnVisibleCommand;
      expect(cmd.position, ColumnScrollPosition.auto);

      controller.dispose();
    });

    test('second command overwrites first', () {
      final controller = OsGridController<Map<String, dynamic>>();
      controller.columnDefs = const [
        OsColumnDef(field: 'a', width: 100),
        OsColumnDef(field: 'b', width: 100),
        OsColumnDef(field: 'c', width: 100),
      ];

      controller.ensureColumnVisible('a', position: ColumnScrollPosition.start);
      controller.ensureColumnVisible('c', position: ColumnScrollPosition.end);

      final cmd =
          controller.scrollCommandNotifier.value as EnsureColumnVisibleCommand;
      expect(cmd.columnIndex, 2);
      expect(cmd.position, ColumnScrollPosition.end);

      controller.dispose();
    });
  });

  group('ensureColumnVisible — colId resolution', () {
    test('resolves column by explicit colId when colId differs from field', () {
      final controller = OsGridController<Map<String, dynamic>>();
      controller.columnDefs = const [
        OsColumnDef(field: 'firstName', colId: 'col_first', width: 100),
        OsColumnDef(field: 'lastName', colId: 'col_last', width: 100),
      ];

      controller.ensureColumnVisible('col_last');

      final cmd =
          controller.scrollCommandNotifier.value as EnsureColumnVisibleCommand;
      expect(cmd.columnIndex, 1);

      controller.dispose();
    });

    test('resolves column by field when colId is not set', () {
      final controller = OsGridController<Map<String, dynamic>>();
      controller.columnDefs = const [
        OsColumnDef(field: 'city', width: 100),
        OsColumnDef(field: 'country', width: 100),
      ];

      controller.ensureColumnVisible('country');

      final cmd =
          controller.scrollCommandNotifier.value as EnsureColumnVisibleCommand;
      expect(cmd.columnIndex, 1);

      controller.dispose();
    });

    test('field name fallback works when colId is set on other columns', () {
      final controller = OsGridController<Map<String, dynamic>>();
      controller.columnDefs = const [
        OsColumnDef(field: 'name', colId: 'col_name', width: 100),
        OsColumnDef(field: 'age', width: 100),
      ];

      // 'age' has no explicit colId, so field is used as effectiveColId.
      controller.ensureColumnVisible('age');

      final cmd =
          controller.scrollCommandNotifier.value as EnsureColumnVisibleCommand;
      expect(cmd.columnIndex, 1);

      controller.dispose();
    });

    test('colId takes priority over field for matching', () {
      // If a column has colId='x' and field='y', passing 'x' should match it.
      final controller = OsGridController<Map<String, dynamic>>();
      controller.columnDefs = const [
        OsColumnDef(field: 'data', colId: 'myCustomId', width: 100),
      ];

      controller.ensureColumnVisible('myCustomId');

      final cmd =
          controller.scrollCommandNotifier.value as EnsureColumnVisibleCommand;
      expect(cmd.columnIndex, 0);

      controller.dispose();
    });

    test('field name also matches even when colId is set', () {
      // The implementation checks both effectiveColId and field.
      final controller = OsGridController<Map<String, dynamic>>();
      controller.columnDefs = const [
        OsColumnDef(field: 'data', colId: 'myCustomId', width: 100),
      ];

      // Passing the field name should also resolve the column.
      controller.ensureColumnVisible('data');

      final cmd =
          controller.scrollCommandNotifier.value as EnsureColumnVisibleCommand;
      expect(cmd.columnIndex, 0);

      controller.dispose();
    });

    test('no-op when neither colId nor field matches', () {
      final controller = OsGridController<Map<String, dynamic>>();
      controller.columnDefs = const [
        OsColumnDef(field: 'name', colId: 'col_name', width: 100),
      ];

      controller.ensureColumnVisible('unknown_id');
      expect(controller.scrollCommandNotifier.value, isNull);

      controller.dispose();
    });
  });

  group('ensureColumnVisible — runtime pin overrides', () {
    test('column pinned at runtime via columnPinState is a no-op', () {
      final controller = OsGridController<Map<String, dynamic>>();
      controller.columnDefs = const [
        OsColumnDef(field: 'a', width: 100),
        OsColumnDef(field: 'b', width: 100),
        OsColumnDef(field: 'c', width: 100),
      ];

      // Simulate runtime pinning (as done by the widget state).
      controller.columnPinState = {'b': OsColumnPin.left};

      controller.ensureColumnVisible('b');
      expect(controller.scrollCommandNotifier.value, isNull);

      controller.dispose();
    });

    test('column pinned right at runtime via columnPinState is a no-op', () {
      final controller = OsGridController<Map<String, dynamic>>();
      controller.columnDefs = const [
        OsColumnDef(field: 'x', width: 100),
        OsColumnDef(field: 'y', width: 100),
      ];

      controller.columnPinState = {'y': OsColumnPin.right};

      controller.ensureColumnVisible('y');
      expect(controller.scrollCommandNotifier.value, isNull);

      controller.dispose();
    });

    test('unpinned column with no runtime override emits command', () {
      final controller = OsGridController<Map<String, dynamic>>();
      controller.columnDefs = const [
        OsColumnDef(field: 'a', width: 100),
        OsColumnDef(field: 'b', width: 100),
      ];

      // Only 'a' is pinned at runtime; 'b' remains unpinned.
      controller.columnPinState = {'a': OsColumnPin.left};

      controller.ensureColumnVisible('b');
      expect(controller.scrollCommandNotifier.value, isNotNull);

      final cmd =
          controller.scrollCommandNotifier.value as EnsureColumnVisibleCommand;
      expect(cmd.columnIndex, 1);

      controller.dispose();
    });

    test('runtime pin override takes precedence over definition pin', () {
      final controller = OsGridController<Map<String, dynamic>>();
      // Column 'a' is pinned left in definition but we won't override it.
      // Column 'b' is unpinned in definition but pinned at runtime.
      controller.columnDefs = const [
        OsColumnDef(field: 'a', width: 100, pinned: OsColumnPin.left),
        OsColumnDef(field: 'b', width: 100),
        OsColumnDef(field: 'c', width: 100),
      ];

      controller.columnPinState = {'b': OsColumnPin.right};

      // 'a' is pinned via definition — no-op.
      controller.ensureColumnVisible('a');
      expect(controller.scrollCommandNotifier.value, isNull);

      // 'b' is pinned via runtime override — no-op.
      controller.ensureColumnVisible('b');
      expect(controller.scrollCommandNotifier.value, isNull);

      // 'c' is not pinned anywhere — should emit command.
      controller.ensureColumnVisible('c');
      expect(controller.scrollCommandNotifier.value, isNotNull);

      controller.dispose();
    });
  });

  group('ensureColumnVisible — hidden columns via hiddenColumnIds', () {
    test('column hidden via hiddenColumnIds is a no-op', () {
      final controller = OsGridController<Map<String, dynamic>>();
      controller.columnDefs = const [
        OsColumnDef(field: 'a', width: 100),
        OsColumnDef(field: 'b', width: 100),
        OsColumnDef(field: 'c', width: 100),
      ];

      // Simulate the widget state hiding column 'b'.
      controller.hiddenColumnIds = {'b'};

      controller.ensureColumnVisible('b');
      expect(controller.scrollCommandNotifier.value, isNull);

      controller.dispose();
    });

    test('visible column still emits command when others are hidden', () {
      final controller = OsGridController<Map<String, dynamic>>();
      controller.columnDefs = const [
        OsColumnDef(field: 'a', width: 100),
        OsColumnDef(field: 'b', width: 100),
        OsColumnDef(field: 'c', width: 100),
      ];

      controller.hiddenColumnIds = {'a'};

      // 'b' is visible and should resolve to index 0 in displayed columns
      // (since 'a' is hidden, 'b' becomes the first displayed column).
      controller.ensureColumnVisible('b');

      final cmd =
          controller.scrollCommandNotifier.value as EnsureColumnVisibleCommand;
      expect(cmd.columnIndex, 0);

      controller.dispose();
    });
  });

  group('VirtualisedGrid — scroll command execution', () {
    testWidgets(
      'resets scrollCommandNotifier to null after executing command',
      (tester) async {
        final notifier = ValueNotifier<ScrollCommand?>(null);
        const columns = [
          OsColumnDef(field: 'a', width: 100),
          OsColumnDef(field: 'b', width: 100),
          OsColumnDef(field: 'c', width: 100),
        ];
        final rowData = List.generate(50, (i) => {'a': i, 'b': i, 'c': i});

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                height: 600,
                child: VirtualisedGrid(
                  columns: columns,
                  rowData: rowData,
                  scrollCommandNotifier: notifier,
                ),
              ),
            ),
          ),
        );

        // Issue a scroll command.
        notifier.value = const EnsureIndexVisibleCommand(
          rowIndex: 40,
          position: RowScrollPosition.top,
        );

        // Allow the listener to fire and the widget to rebuild.
        await tester.pump();

        // The notifier should have been reset to null by the grid.
        expect(notifier.value, isNull);
      },
    );

    testWidgets('resets notifier after column scroll command', (tester) async {
      final notifier = ValueNotifier<ScrollCommand?>(null);
      final columns = List.generate(
        20,
        (i) => OsColumnDef(field: 'col$i', width: 100),
      );
      final rowData = [
        {for (int i = 0; i < 20; i++) 'col$i': i},
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 300,
              child: VirtualisedGrid(
                columns: columns,
                rowData: rowData,
                scrollCommandNotifier: notifier,
              ),
            ),
          ),
        ),
      );

      // Issue a column scroll command to a column far to the right.
      notifier.value = const EnsureColumnVisibleCommand(
        columnIndex: 15,
        position: ColumnScrollPosition.middle,
      );

      await tester.pump();

      // The notifier should have been reset to null.
      expect(notifier.value, isNull);
    });

    testWidgets('ignores null command values', (tester) async {
      final notifier = ValueNotifier<ScrollCommand?>(null);
      const columns = [OsColumnDef(field: 'a', width: 100)];
      final rowData = [
        {'a': 1},
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 300,
              child: VirtualisedGrid(
                columns: columns,
                rowData: rowData,
                scrollCommandNotifier: notifier,
              ),
            ),
          ),
        ),
      );

      // Setting null should not cause any issues.
      notifier.value = null;
      await tester.pump();

      expect(notifier.value, isNull);
    });

    testWidgets('handles successive commands correctly', (tester) async {
      final notifier = ValueNotifier<ScrollCommand?>(null);
      final columns = List.generate(
        10,
        (i) => OsColumnDef(field: 'col$i', width: 100),
      );
      final rowData = List.generate(
        100,
        (i) => {for (int j = 0; j < 10; j++) 'col$j': i * 10 + j},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 300,
              child: VirtualisedGrid(
                columns: columns,
                rowData: rowData,
                scrollCommandNotifier: notifier,
              ),
            ),
          ),
        ),
      );

      // First command.
      notifier.value = const EnsureIndexVisibleCommand(
        rowIndex: 50,
        position: RowScrollPosition.top,
      );
      await tester.pump();
      expect(notifier.value, isNull);

      // Second command after reset.
      notifier.value = const EnsureColumnVisibleCommand(
        columnIndex: 8,
        position: ColumnScrollPosition.end,
      );
      await tester.pump();
      expect(notifier.value, isNull);
    });
  });
}
