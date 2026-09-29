import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';
import 'package:os_grid_flutter/src/columns/column_api_coordinator.dart';

/// Coverage for the column-sizing controller API that used to be silent
/// stubs: `setColumnDefs`, `autoSizeColumns` and `sizeColumnsToFit`.
///
/// Two layers are exercised — the coordinator in isolation (deterministic
/// Ahem font metrics, exact width arithmetic) and the public controller
/// against a real grid (wiring, geometry and lifecycle).
void main() {
  group('ColumnApiCoordinator sizing behaviour', () {
    late OsGridController<Map<String, dynamic>> controller;
    late List<OsColumnDef> columns;
    var rows = <Map<String, dynamic>>[];
    late ColumnApiCoordinator<Map<String, dynamic>> coordinator;

    ColumnApiCoordinator<Map<String, dynamic>> buildCoordinator() {
      return ColumnApiCoordinator<Map<String, dynamic>>(
        controller: controller,
        allFlatColumns: () => columns,
        syntheticOffset: () => 0,
        resolveRows: () => rows,
        resolveCellValue: (col, row, _) => row[col.field],
        clearTextCacheFor: (_) {},
        setSortModel: (_) {},
        clearSort: () {},
        invalidateDeltaSort: () {},
        resetLegacySortIndex: () {},
        emitSortChanged: () {},
        reprocess: () {},
        initHiddenFromDefs: () {},
        notifyStateChanged: (_) {},
        mutate: (fn) => fn(),
        headerTextStyle: () => const TextStyle(fontSize: 10),
        cellTextStyle: () => const TextStyle(fontSize: 10),
        textScaler: () => TextScaler.noScaling,
        onColumnVisible: null,
        onColumnPinned: null,
        onColumnResized: null,
        onColumnMoved: null,
      );
    }

    setUp(() {
      controller = OsGridController<Map<String, dynamic>>();
      rows = [
        {'a': 'ww', 'b': null},
        {'a': 'www', 'b': 12345},
      ];
      columns = const [OsColumnDef(field: 'a'), OsColumnDef(field: 'b')];
      coordinator = buildCoordinator();
    });

    tearDown(() {
      coordinator.dispose();
      controller.dispose();
    });

    group('autosizeByColIds', () {
      test('null colIds autosizes every displayed column', () {
        coordinator.autosizeByColIds(null);

        expect(coordinator.widths['a'], 30 + 64);
        expect(coordinator.widths['b'], 50 + 64);
      });

      test('restricts the operation to the named columns', () {
        coordinator.autosizeByColIds({'a'});

        expect(coordinator.widths['a'], 30 + 64);
        expect(coordinator.widths.containsKey('b'), isFalse);
      });

      test('ignores unknown colIds instead of failing', () {
        coordinator.autosizeByColIds({'nope'});

        expect(coordinator.widths, isEmpty);
      });

      test('skips hidden columns', () {
        coordinator.hiddenIds.add('a');

        coordinator.autosizeByColIds(null);

        expect(coordinator.widths.containsKey('a'), isFalse);
        expect(coordinator.widths['b'], 50 + 64);
      });

      test('skipHeader ignores the header text', () {
        // 'b' has a 10px header and a 50px cell; 'a' has a 10px header and
        // a 30px cell. Skipping the header only changes 'b' here, so use a
        // column whose header is wider than its content instead.
        columns = const [
          OsColumnDef(field: 'a', headerName: 'a very wide header name'),
        ];
        rows = [
          {'a': 'w'},
        ];

        coordinator.autosizeByColIds(null);
        final withHeader = coordinator.widths['a']!;

        // A fresh coordinator so the cached header measurement is not
        // reused for the skipHeader pass.
        coordinator.dispose();
        coordinator = buildCoordinator();
        coordinator.autosizeByColIds(null, skipHeader: true);

        expect(coordinator.widths['a'], 10 + 64); // cell only
        expect(withHeader, greaterThan(coordinator.widths['a']!));
      });

      test('a skipHeader measurement is never served to a header pass', () {
        columns = const [OsColumnDef(field: 'a', headerName: 'wide header')];
        rows = [
          {'a': 'w'},
        ];

        coordinator.autosizeByColIds(null, skipHeader: true);
        final skipOnly = coordinator.widths['a']!;
        // No new layouts needed for the second call *only* if the flag
        // matched; here it must re-measure because the header is included.
        final layoutsAfterSkip = coordinator.autosizeLayoutCount;

        coordinator.autosizeByColIds(null);

        expect(coordinator.widths['a'], greaterThan(skipOnly));
        expect(coordinator.autosizeLayoutCount, greaterThan(layoutsAfterSkip));
      });
    });

    group('sizeColumnsToFit', () {
      test('scales unpinned columns to fill the available width', () {
        columns = const [
          OsColumnDef(field: 'a', width: 100),
          OsColumnDef(field: 'b', width: 300),
        ];

        coordinator.sizeColumnsToFit(800);

        // Proportional: 100/400 and 300/400 of 800.
        expect(coordinator.widths['a'], closeTo(200, 0.01));
        expect(coordinator.widths['b'], closeTo(600, 0.01));
      });

      test('leaves pinned columns at their own width', () {
        columns = const [
          OsColumnDef(field: 'a', pinned: OsColumnPin.left, width: 120),
          OsColumnDef(field: 'b', width: 100),
          OsColumnDef(field: 'c', width: 100),
        ];

        // The caller passes the centre viewport (800 total - 120 pinned).
        coordinator.sizeColumnsToFit(680);

        expect(coordinator.widths['a'], isNull);
        expect(coordinator.widths['b'], closeTo(340, 0.01));
        expect(coordinator.widths['c'], closeTo(340, 0.01));
      });

      test('redistributes slack left by maxWidth-clamped columns', () {
        columns = const [
          OsColumnDef(field: 'a', width: 100, maxWidth: 150),
          OsColumnDef(field: 'b', width: 100),
        ];

        coordinator.sizeColumnsToFit(800);

        // 'a' is capped at 150, so the remaining 650 all goes to 'b'.
        expect(coordinator.widths['a'], 150);
        expect(coordinator.widths['b'], closeTo(650, 0.01));
      });

      test(
        'respects minWidth when the target is narrower than the columns',
        () {
          columns = const [
            OsColumnDef(field: 'a', width: 300, minWidth: 250),
            OsColumnDef(field: 'b', width: 300, minWidth: 250),
          ];

          coordinator.sizeColumnsToFit(200);

          // Neither column may go below 250, so the total stays above the
          // target instead of producing an under-filled or negative layout.
          expect(coordinator.widths['a'], 250);
          expect(coordinator.widths['b'], 250);
        },
      );

      test('uses the resolved pin override, not the definition', () {
        columns = const [
          OsColumnDef(field: 'a', width: 100),
          OsColumnDef(field: 'b', width: 100),
        ];
        coordinator.pins['a'] = OsColumnPin.left;

        coordinator.sizeColumnsToFit(600);

        expect(coordinator.widths['a'], isNull);
        expect(coordinator.widths['b'], 600);
      });

      test('does nothing without a positive target width', () {
        columns = const [OsColumnDef(field: 'a', width: 100)];

        coordinator.sizeColumnsToFit(0);

        expect(coordinator.widths, isEmpty);
      });

      test('emits a single column-resized event covering every column', () {
        final events = <OsColumnResizedEvent>[];
        coordinator = ColumnApiCoordinator<Map<String, dynamic>>(
          controller: controller,
          allFlatColumns: () => columns,
          syntheticOffset: () => 0,
          resolveRows: () => rows,
          resolveCellValue: (col, row, _) => row[col.field],
          clearTextCacheFor: (_) {},
          setSortModel: (_) {},
          clearSort: () {},
          invalidateDeltaSort: () {},
          resetLegacySortIndex: () {},
          emitSortChanged: () {},
          reprocess: () {},
          initHiddenFromDefs: () {},
          notifyStateChanged: (_) {},
          mutate: (fn) => fn(),
          headerTextStyle: () => const TextStyle(fontSize: 10),
          cellTextStyle: () => const TextStyle(fontSize: 10),
          textScaler: () => TextScaler.noScaling,
          onColumnVisible: null,
          onColumnPinned: null,
          onColumnResized: events.add,
          onColumnMoved: null,
        );
        addTearDown(coordinator.dispose);
        columns = const [
          OsColumnDef(field: 'a', width: 100),
          OsColumnDef(field: 'b', width: 100),
        ];

        coordinator.sizeColumnsToFit(400);

        expect(events, hasLength(1));
        expect(events.single.finished, isTrue);
        expect(events.single.columns.map((c) => c.colId), ['a', 'b']);
      });
    });

    group('pruneTo', () {
      test('drops state for removed columns and keeps the rest', () {
        columns = const [OsColumnDef(field: 'a'), OsColumnDef(field: 'b')];
        coordinator.widths.addAll({'a': 111, 'b': 222, 'gone': 333});
        coordinator.pins.addAll({
          'a': OsColumnPin.left,
          'gone': OsColumnPin.left,
        });
        coordinator.hiddenIds.addAll(['b', 'gone']);
        coordinator.order = ['b', 'a', 'gone'];
        coordinator.autosizeByColIds(null);

        coordinator.pruneTo(columns);

        expect(coordinator.widths.keys, containsAll(['a', 'b']));
        expect(coordinator.widths.containsKey('gone'), isFalse);
        expect(coordinator.pins.containsKey('gone'), isFalse);
        expect(coordinator.hiddenIds.contains('gone'), isFalse);
        expect(coordinator.order, ['b', 'a']);
        expect(coordinator.hiddenIds.contains('b'), isTrue);
      });
    });
  });

  group('controller.autoSizeColumns', () {
    Widget buildGrid(
      OsGridController<Map<String, dynamic>> controller, {
      List<OsColumnDefBase> columnDefs = const [
        OsColumnDef(field: 'name', width: 100),
        OsColumnDef(field: 'age', width: 100),
      ],
      List<Map<String, dynamic>> rowData = const [
        {'name': 'Alexandria', 'age': 7},
      ],
    }) {
      return MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: OsGrid<Map<String, dynamic>>(
              controller: controller,
              columnDefs: columnDefs,
              rowData: rowData,
            ),
          ),
        ),
      );
    }

    double widthOf(
      OsGridController<Map<String, dynamic>> controller,
      String colId,
    ) {
      final state = {
        for (final s in controller.getColumnState()) s.colId: s.width,
      };
      return state[colId]!;
    }

    testWidgets('sizes every column to its content', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();
      addTearDown(controller.dispose);

      await tester.pumpWidget(buildGrid(controller));
      await tester.pumpAndSettle();

      controller.autoSizeColumns();
      await tester.pumpAndSettle();

      final name = widthOf(controller, 'name');
      final age = widthOf(controller, 'age');
      expect(name, greaterThan(100));
      expect(age, greaterThan(100));
      // 'Alexandria' is far wider than 'Quarter'-style content, so the
      // columns must not all collapse to the same width.
      expect(name, greaterThan(age));
    });

    testWidgets('restricts measurement to the named columns', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();
      addTearDown(controller.dispose);

      await tester.pumpWidget(buildGrid(controller));
      await tester.pumpAndSettle();

      controller.autoSizeColumns(colIds: ['name']);
      await tester.pumpAndSettle();

      expect(widthOf(controller, 'name'), greaterThan(100));
      expect(widthOf(controller, 'age'), 100);
    });

    testWidgets('skipHeader sizes to cell content only', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        buildGrid(
          controller,
          columnDefs: const [
            OsColumnDef(field: 'name', width: 100, headerName: 'Full name'),
            OsColumnDef(field: 'age', width: 100),
          ],
          rowData: const [
            {'name': 'Alexandria', 'age': 7},
          ],
        ),
      );
      await tester.pumpAndSettle();

      controller.autoSizeColumns(colIds: ['age'], skipHeader: true);
      await tester.pumpAndSettle();

      // '7' is one glyph; the column lands on the minimum width rather
      // than growing to fit the 'Age' header.
      final tp = TextPainter(
        text: const TextSpan(text: '7', style: TextStyle(fontSize: 14)),
        maxLines: 1,
        textDirection: TextDirection.ltr,
      )..layout();
      expect(
        widthOf(controller, 'age'),
        lessThanOrEqualTo(tp.width + 64 + 0.01),
      );
    });

    testWidgets('an unknown colId leaves every width untouched', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();
      addTearDown(controller.dispose);

      await tester.pumpWidget(buildGrid(controller));
      await tester.pumpAndSettle();

      controller.autoSizeColumns(colIds: ['does-not-exist']);
      await tester.pumpAndSettle();

      expect(widthOf(controller, 'name'), 100);
      expect(widthOf(controller, 'age'), 100);
    });

    testWidgets('resizes a column that was previously drag-sized', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();
      addTearDown(controller.dispose);

      await tester.pumpWidget(buildGrid(controller));
      await tester.pumpAndSettle();

      // Drag the first separator to commit a local width, then confirm the
      // API call is not shadowed by the drag's cached value. The first move
      // must be small so the pan starts while the pointer is still inside
      // the separator's 5px hit zone, and the drag is delivered as a
      // sequence of moves (a single jump after the pan starts is not
      // enough to complete the gesture).
      final gesture = await tester.startGesture(
        const Offset(100, 24),
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveBy(const Offset(3, 0));
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.moveBy(const Offset(57, 0));
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.moveBy(const Offset(10, 0));
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(widthOf(controller, 'name'), greaterThan(140));

      controller.setColumnWidths([
        const ColumnWidthEntry(colId: 'name', newWidth: 400),
      ]);
      await tester.pumpAndSettle();
      expect(widthOf(controller, 'name'), 400);

      controller.setColumnWidths([
        const ColumnWidthEntry(colId: 'name', newWidth: 400),
      ]);
      await tester.pumpAndSettle();
      expect(widthOf(controller, 'name'), 400);
    });
  });

  group('controller.sizeColumnsToFit', () {
    Widget buildGrid(
      OsGridController<Map<String, dynamic>> controller, {
      List<OsColumnDefBase> columnDefs = const [
        OsColumnDef(field: 'name', width: 100),
        OsColumnDef(field: 'age', width: 100),
      ],
      void Function(OsGridController<Map<String, dynamic>>)? onReady,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: OsGrid<Map<String, dynamic>>(
              controller: controller,
              columnDefs: columnDefs,
              rowData: const [
                {'name': 'Alexandria', 'age': 7},
              ],
              onGridReady: onReady,
            ),
          ),
        ),
      );
    }

    double totalWidth(OsGridController<Map<String, dynamic>> controller) {
      return controller.getColumnState().fold<double>(
        0,
        (sum, s) => sum + (s.width ?? 0),
      );
    }

    testWidgets('fills the viewport with the centre columns', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();
      addTearDown(controller.dispose);

      await tester.pumpWidget(buildGrid(controller));
      await tester.pumpAndSettle();

      controller.sizeColumnsToFit();
      await tester.pumpAndSettle();

      expect(totalWidth(controller), closeTo(800, 0.5));
    });

    testWidgets('excludes the pinned section from the distributed width', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        buildGrid(
          controller,
          columnDefs: const [
            OsColumnDef(field: 'name', width: 120, pinned: OsColumnPin.left),
            OsColumnDef(field: 'age', width: 100),
            OsColumnDef(field: 'city', width: 100),
          ],
        ),
      );
      await tester.pumpAndSettle();

      controller.sizeColumnsToFit();
      await tester.pumpAndSettle();

      final state = {for (final s in controller.getColumnState()) s.colId: s};
      expect(state['name']!.width, 120);
      expect(
        state['age']!.width! + state['city']!.width!,
        closeTo(800 - 120, 0.5),
      );
    });

    testWidgets('applies when called before the first layout pass', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();
      addTearDown(controller.dispose);

      // onGridReady fires during initState, before the grid has a viewport.
      await tester.pumpWidget(
        buildGrid(controller, onReady: (c) => c.sizeColumnsToFit()),
      );
      await tester.pumpAndSettle();

      expect(totalWidth(controller), closeTo(800, 0.5));
    });
  });

  group('controller.setColumnDefs', () {
    List<String> fieldsOf(OsGridController<Map<String, dynamic>> controller) {
      return controller.getColumns().map((c) => c.field!).toList();
    }

    testWidgets('swaps the rendered columns at runtime', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: OsGrid<Map<String, dynamic>>(
                controller: controller,
                columnDefs: const [
                  OsColumnDef(field: 'name', width: 100),
                  OsColumnDef(field: 'age', width: 100),
                ],
                rowData: const [
                  {'name': 'Alexandria', 'age': 7, 'city': 'Alexandria'},
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(fieldsOf(controller), ['name', 'age']);

      controller.setColumnDefs(const [
        OsColumnDef(field: 'city', headerName: 'City', width: 200),
      ]);
      await tester.pumpAndSettle();

      expect(fieldsOf(controller), ['city']);
      expect(controller.getColumnDef('name'), isNull);
      expect(controller.getColumnDef('city')!.headerName, 'City');
    });

    testWidgets('keeps state for surviving columns and drops the rest', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: OsGrid<Map<String, dynamic>>(
                controller: controller,
                columnDefs: const [
                  OsColumnDef(field: 'name', width: 100),
                  OsColumnDef(field: 'age', width: 100),
                ],
                rowData: const [
                  {'name': 'Alexandria', 'age': 7},
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      controller.setColumnWidths([
        const ColumnWidthEntry(colId: 'name', newWidth: 321),
        const ColumnWidthEntry(colId: 'age', newWidth: 222),
      ]);
      controller.setColumnsPinned(['name'], OsColumnPin.left);
      await tester.pumpAndSettle();

      controller.setColumnDefs(const [
        OsColumnDef(field: 'name', width: 100),
        OsColumnDef(field: 'city', width: 100),
      ]);
      await tester.pumpAndSettle();

      final state = {for (final s in controller.getColumnState()) s.colId: s};
      // The surviving column keeps the user's width and pin.
      expect(state['name']!.width, 321);
      expect(state['name']!.pinned, OsColumnPin.left);
      // The removed column's width is gone — it cannot resurface on a
      // later column reusing the colId.
      expect(state.containsKey('age'), isFalse);
      // The new column starts from its definition width.
      expect(state['city']!.width, 100);
    });

    testWidgets('applies hide: true from the new definitions', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: OsGrid<Map<String, dynamic>>(
                controller: controller,
                columnDefs: const [
                  OsColumnDef(field: 'name', width: 100),
                  OsColumnDef(field: 'age', width: 100),
                ],
                rowData: const [
                  {'name': 'Alexandria', 'age': 7},
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      controller.setColumnDefs(const [
        OsColumnDef(field: 'name', width: 100),
        OsColumnDef(field: 'age', width: 100, hide: true),
      ]);
      await tester.pumpAndSettle();

      expect(controller.getAllDisplayedColumns().map((c) => c.field), ['name']);
    });

    testWidgets('a host rebuild with new defs overrides the API swap', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();
      addTearDown(controller.dispose);

      Widget build(String field) {
        return MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: OsGrid<Map<String, dynamic>>(
                controller: controller,
                columnDefs: [OsColumnDef(field: field, width: 100)],
                rowData: const [
                  {'name': 'Alexandria', 'age': 7, 'city': 'Rome'},
                ],
              ),
            ),
          ),
        );
      }

      await tester.pumpWidget(build('name'));
      await tester.pumpAndSettle();

      controller.setColumnDefs(const [OsColumnDef(field: 'age', width: 100)]);
      await tester.pumpAndSettle();
      expect(fieldsOf(controller), ['age']);

      // The host now declares a different set: it wins.
      await tester.pumpWidget(build('city'));
      await tester.pumpAndSettle();
      expect(fieldsOf(controller), ['city']);
    });

    testWidgets('is a no-op before the grid is mounted', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();
      addTearDown(controller.dispose);

      expect(
        () => controller.setColumnDefs(const [OsColumnDef(field: 'a')]),
        returnsNormally,
      );
      expect(() => controller.autoSizeColumns(), returnsNormally);
      expect(controller.sizeColumnsToFit, returnsNormally);
    });
  });
}
