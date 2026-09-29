import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';
import 'package:os_grid_flutter/src/utils/grid_diagnostics.dart';

/// Quality program v3 item 28 — structured error reporting.
///
/// Verifies that diagnostics raised through [GridDiagnostics] (the
/// `debugPrint` choke point) are also emitted as typed [GridDiagnostic]s
/// on the owning controller's `onDiagnostic` stream, covering:
/// - duplicate colIds (validator),
/// - unknown column type names + missing field/valueGetter (widget),
/// - throwing comparators and value getters (runtime catch sites),
/// - stream lifecycle (dispose unregistration, no-listener safety).
void main() {
  /// Captures debugPrint output during a callback.
  List<String> captureWarnings(void Function() fn) {
    final warnings = <String>[];
    final originalDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) warnings.add(message);
    };
    try {
      fn();
    } finally {
      debugPrint = originalDebugPrint;
    }
    return warnings;
  }

  void validateWith(
    List<OsColumnDefBase> columnDefs, {
    bool treeData = false,
  }) => OsGridValidator.validate(
    columnDefs: columnDefs,
    rowSelection: null,
    cellSelection: null,
    pagination: null,
    undoRedoCellEditing: false,
    singleClickEdit: false,
    suppressClickEdit: false,
    enterNavigatesVertically: false,
    enterNavigatesVerticallyAfterEdit: false,
    floatingFilter: false,
    rowDrag: false,
    rowDragManaged: true,
    getRowId: null,
    treeData: treeData,
  );

  late OsGridController<Map<String, Object>> controller;
  var controllerDisposedByTest = false;

  setUp(() {
    GridDiagnostics.resetWarnedKeys();
    controllerDisposedByTest = false;
    controller = OsGridController<Map<String, Object>>();
  });

  tearDown(() {
    GridDiagnostics.resetListeners();
    if (!controllerDisposedByTest) {
      controller.dispose();
    }
  });

  group('GridDiagnostic payload', () {
    test('exposes code, message and key', () {
      const diagnostic = GridDiagnostic(
        code: GridErrorCode.duplicateColId,
        message: 'boom',
        key: 'validation:duplicateColIds',
      );
      expect(diagnostic.code, GridErrorCode.duplicateColId);
      expect(diagnostic.message, 'boom');
      expect(diagnostic.key, 'validation:duplicateColIds');
      expect(diagnostic.toString(), startsWith('[OS Grid] boom'));
      expect(diagnostic.toString(), contains('duplicateColId'));
    });
  });

  group('onDiagnostic — validator emissions', () {
    test(
      'duplicate colIds emit duplicateColId on stream and console',
      () async {
        final events = <GridDiagnostic>[];
        final sub = controller.onDiagnostic.listen(events.add);

        final console = captureWarnings(() {
          validateWith([
            const OsColumnGroup(
              headerName: 'A',
              children: [OsColumnDef(field: 'amount')],
            ),
            const OsColumnGroup(
              headerName: 'B',
              children: [OsColumnDef(field: 'amount')],
            ),
          ]);
        });
        await Future<void>.delayed(Duration.zero);

        await sub.cancel();
        expect(events, hasLength(1));
        expect(events.single.code, GridErrorCode.duplicateColId);
        expect(events.single.key, 'validation:duplicateColIds');
        expect(
          events.single.message,
          contains('Duplicate column IDs detected'),
        );
        // The existing debugPrint path still fires alongside the stream.
        expect(console.where((w) => w.startsWith('[OS Grid] ')), hasLength(1));
      },
    );

    test('unique colIds emit nothing on the stream', () async {
      final events = <GridDiagnostic>[];
      final sub = controller.onDiagnostic.listen(events.add);
      captureWarnings(() {
        validateWith([
          const OsColumnDef(field: 'a'),
          const OsColumnDef(field: 'b'),
        ]);
      });
      await Future<void>.delayed(Duration.zero);

      await sub.cancel();
      expect(events, isEmpty);
    });

    test('treeData without getDataPath emits treeDataWithoutPath', () async {
      final events = <GridDiagnostic>[];
      final sub = controller.onDiagnostic.listen(events.add);
      captureWarnings(
        () => validateWith([const OsColumnDef(field: 'a')], treeData: true),
      );
      await Future<void>.delayed(Duration.zero);

      await sub.cancel();
      expect(
        events.map((d) => d.code),
        contains(GridErrorCode.treeDataWithoutPath),
      );
      expect(
        events
            .firstWhere((d) => d.code == GridErrorCode.treeDataWithoutPath)
            .key,
        'validation:treeDataWithoutPath',
      );
    });
  });

  group('onDiagnostic — runtime catch sites', () {
    test('throwing comparator emits invalidComparator', () async {
      final events = <GridDiagnostic>[];
      final sub = controller.onDiagnostic.listen(events.add);
      final service = SortService<Map<String, dynamic>>();
      final columns = [
        OsColumnDef(
          field: 'age',
          comparator: (valueA, valueB, dataA, dataB, isDescending) {
            throw StateError('comparator exploded');
          },
        ),
      ];
      service.setSortModel([
        const OsSortModel(colId: 'age', sort: OsSortDirection.ascending),
      ]);
      final data = [
        {'age': 30},
        {'age': 10},
        {'age': 20},
      ];

      late List<int> ages;
      captureWarnings(() {
        final sorted = service.sortData(data: data, columns: columns);
        ages = sorted.map((r) => r['age'] as int).toList();
      });
      await Future<void>.delayed(Duration.zero);

      await sub.cancel();
      // Fallback comparison still produced a correct ordering.
      expect(ages, [10, 20, 30]);
      expect(events, hasLength(1));
      expect(events.single.code, GridErrorCode.invalidComparator);
      expect(events.single.key, 'sort:comparator');
      expect(events.single.message, contains('comparator exploded'));
    });

    test(
      'throwing valueGetter in aggregation emits valueGetterThrew',
      () async {
        final events = <GridDiagnostic>[];
        final sub = controller.onDiagnostic.listen(events.add);
        final service = AggregationService<Map<String, dynamic>>();
        final col = OsColumnDef<Map<String, dynamic>>(
          field: 'sales',
          colId: 'brokenGetter',
          valueGetter: (params) => throw StateError('getter blew up'),
          aggFunc: 'sum',
        );

        captureWarnings(() {
          service.computeGroupAggregates(
            leafRows: [
              {'sales': 5},
              {'sales': 7},
            ],
            valueColumns: [col],
          );
        });
        await Future<void>.delayed(Duration.zero);

        await sub.cancel();
        expect(events, hasLength(1));
        expect(events.single.code, GridErrorCode.valueGetterThrew);
        expect(events.single.key, 'aggregation:valueGetter');
        expect(events.single.message, contains('getter blew up'));
      },
    );
  });

  group('legacy key mapping', () {
    test('unknown legacy keys map to unspecified', () async {
      final events = <GridDiagnostic>[];
      final sub = controller.onDiagnostic.listen(events.add);
      captureWarnings(() => GridDiagnostics.warnOnce('mystery:site', 'odd'));
      await Future<void>.delayed(Duration.zero);

      await sub.cancel();
      expect(events.single.code, GridErrorCode.unspecified);
      expect(events.single.key, 'mystery:site');
    });

    test('resetWarnedKeys allows re-emission onto the stream', () async {
      final events = <GridDiagnostic>[];
      final sub = controller.onDiagnostic.listen(events.add);
      captureWarnings(() => GridDiagnostics.warnOnce('k:a', 'first'));
      GridDiagnostics.resetWarnedKeys();
      captureWarnings(() => GridDiagnostics.warnOnce('k:a', 'second'));
      await Future<void>.delayed(Duration.zero);

      await sub.cancel();
      expect(events.map((d) => d.message), ['first', 'second']);
    });
  });

  group('stream lifecycle', () {
    test('emitting with no listeners does not throw', () {
      expect(
        captureWarnings(
          () => GridDiagnostics.warnOnce('lonely:key', 'nobody listens'),
        ),
        hasLength(1),
      );
    });

    test(
      'diagnostics after dispose are not delivered and do not throw',
      () async {
        final events = <GridDiagnostic>[];
        final sub = controller.onDiagnostic.listen(events.add);
        captureWarnings(
          () => GridDiagnostics.warnOnce('pre:dispose', 'before'),
        );
        await Future<void>.delayed(Duration.zero);
        expect(events, hasLength(1));

        await sub.cancel();
        controller.dispose();
        controllerDisposedByTest = true;
        expect(
          () => captureWarnings(
            () => GridDiagnostics.warnOnce('post:dispose', 'after'),
          ),
          returnsNormally,
        );
        await Future<void>.delayed(Duration.zero);
        expect(events, hasLength(1));
      },
    );
  });

  group('onDiagnostic — widget-level emissions', () {
    testWidgets('unknown column type name emits unknownColumnType', (
      tester,
    ) async {
      final events = <GridDiagnostic>[];
      // NOTE: intentionally not cancelled — awaiting StreamSubscription
      // .cancel() inside testWidgets deadlocks teardown on this SDK.
      controller.onDiagnostic.listen(events.add);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 300,
              child: OsGrid<Map<String, Object>>(
                controller: controller,
                columnTypes: {
                  'known': const OsColumnDef<Map<String, Object>>(
                    field: 'known',
                  ),
                },
                columnDefs: const [
                  OsColumnDef<Map<String, Object>>(field: 'a', type: 'mystery'),
                ],
                rowData: const [],
              ),
            ),
          ),
        ),
      );
      // Flushes the broadcast delivery of diagnostics emitted during build.
      await tester.pump();

      expect(
        events.map((d) => d.code),
        contains(GridErrorCode.unknownColumnType),
      );
      final diagnostic = events.firstWhere(
        (d) => d.code == GridErrorCode.unknownColumnType,
      );
      expect(diagnostic.key, 'columnType:mystery');
      expect(diagnostic.message, contains('mystery'));
    });

    testWidgets(
      'column without field or valueGetter emits missingFieldOrGetter',
      (tester) async {
        final events = <GridDiagnostic>[];
        // NOTE: intentionally not cancelled — awaiting StreamSubscription
        // .cancel() inside testWidgets deadlocks teardown on this SDK.
        controller.onDiagnostic.listen(events.add);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                height: 300,
                child: OsGrid<Map<String, Object>>(
                  controller: controller,
                  // The missing-field check only runs when defaultColDef or
                  // columnTypes is configured; provide a types map to arm it.
                  columnTypes: {
                    'known': const OsColumnDef<Map<String, Object>>(
                      field: 'known',
                    ),
                  },
                  columnDefs: const [OsColumnDef<Map<String, Object>>()],
                  rowData: const [],
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(
          events.map((d) => d.code),
          contains(GridErrorCode.missingFieldOrGetter),
        );
        final diagnostic = events.firstWhere(
          (d) => d.code == GridErrorCode.missingFieldOrGetter,
        );
        expect(diagnostic.key, startsWith('nofield:'));
        expect(diagnostic.message, contains('neither field nor valueGetter'));
      },
    );
  });
}
