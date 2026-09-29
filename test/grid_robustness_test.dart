import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';
import 'package:os_grid_flutter/src/utils/grid_diagnostics.dart';

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

  group('GridDiagnostics.warnOnce', () {
    setUp(GridDiagnostics.resetWarnedKeys);

    test('emits message with [OS Grid] prefix at most once per key', () {
      final warnings = captureWarnings(() {
        GridDiagnostics.warnOnce('test:site', 'first warning');
        GridDiagnostics.warnOnce('test:site', 'second warning');
        GridDiagnostics.warnOnce('test:site', 'third warning');
      });
      expect(warnings, hasLength(1));
      expect(warnings.single, '[OS Grid] first warning');
    });

    test('distinct keys each emit independently', () {
      final warnings = captureWarnings(() {
        GridDiagnostics.warnOnce('test:a', 'warning a');
        GridDiagnostics.warnOnce('test:b', 'warning b');
        GridDiagnostics.warnOnce('test:a', 'warning a again');
      });
      expect(warnings, hasLength(2));
      expect(warnings, contains('[OS Grid] warning a'));
      expect(warnings, contains('[OS Grid] warning b'));
    });

    test('resetWarnedKeys allows the same key to emit again', () {
      final first = captureWarnings(() {
        GridDiagnostics.warnOnce('test:key', 'before reset');
      });
      GridDiagnostics.resetWarnedKeys();
      final second = captureWarnings(() {
        GridDiagnostics.warnOnce('test:key', 'after reset');
      });
      expect(first, hasLength(1));
      expect(second, hasLength(1));
      expect(second.single, '[OS Grid] after reset');
    });
  });

  group('OsGridValidator duplicate colId check', () {
    setUp(GridDiagnostics.resetWarnedKeys);

    List<String> validateWith(List<OsColumnDefBase> columnDefs) =>
        captureWarnings(
          () => OsGridValidator.validate(
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
          ),
        );

    test(
      'warns listing duplicate field-derived colIds across column groups',
      () {
        final warnings = validateWith([
          const OsColumnGroup(
            headerName: 'Group A',
            children: [OsColumnDef(field: 'amount')],
          ),
          const OsColumnGroup(
            headerName: 'Group B',
            children: [OsColumnDef(field: 'amount')],
          ),
        ]);

        final dupes = warnings
            .where((w) => w.contains('Duplicate column IDs detected'))
            .toList();
        expect(dupes, hasLength(1));
        expect(dupes.single, contains('[OS Grid] '));
        expect(dupes.single, contains('[amount]'));
      },
    );

    test('warns when explicit colId is duplicated on two columns', () {
      final warnings = validateWith([
        const OsColumnDef(field: 'a', colId: 'same'),
        const OsColumnDef(field: 'b', colId: 'same'),
      ]);

      final dupes = warnings
          .where((w) => w.contains('Duplicate column IDs detected'))
          .toList();
      expect(dupes, hasLength(1));
      expect(dupes.single, contains('[same]'));
    });

    test('no duplicate-colId warning for unique columns', () {
      final warnings = validateWith([
        const OsColumnDef(field: 'a'),
        const OsColumnDef(field: 'b'),
        const OsColumnGroup(
          headerName: 'G',
          children: [
            OsColumnDef(field: 'c'),
            OsColumnDef(field: 'd'),
          ],
        ),
      ]);
      expect(warnings.where((w) => w.contains('Duplicate')), isEmpty);
    });

    test('warns only once even when validation runs repeatedly', () {
      final warnings = captureWarnings(() {
        for (var i = 0; i < 3; i++) {
          OsGridValidator.validate(
            columnDefs: [
              const OsColumnDef(field: 'x'),
              const OsColumnDef(field: 'x'),
            ],
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
          );
        }
      });
      expect(
        warnings.where((w) => w.contains('Duplicate column IDs detected')),
        hasLength(1),
      );
    });
  });

  group('SortService throwing comparator guard', () {
    setUp(GridDiagnostics.resetWarnedKeys);

    test(
      'throwing comparator falls back to default comparison and warns once',
      () {
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
        final warnings = captureWarnings(() {
          final sorted = service.sortData(data: data, columns: columns);
          ages = sorted.map((r) => r['age'] as int).toList();
        });

        // Deterministic fallback: same result as the default numeric compare.
        expect(ages, [10, 20, 30]);
        expect(warnings, hasLength(1));
        expect(warnings.single, startsWith('[OS Grid] '));
        expect(warnings.single, contains('age'));
        expect(warnings.single, contains('comparator exploded'));
      },
    );

    test('fallback respects descending direction via negation', () {
      var calls = 0;
      final service = SortService<Map<String, dynamic>>();
      final columns = [
        OsColumnDef(
          field: 'age',
          comparator: (a, b, c, d, e) {
            calls++;
            throw Exception('always throws');
          },
        ),
      ];
      service.setSortModel([
        const OsSortModel(colId: 'age', sort: OsSortDirection.descending),
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

      expect(calls, greaterThanOrEqualTo(2));
      expect(ages, [30, 20, 10]);
    });
  });

  group('AggregationService valueGetter composition', () {
    setUp(GridDiagnostics.resetWarnedKeys);

    test('custom aggFunc aggregates getter-derived values', () {
      final service = AggregationService<Map<String, dynamic>>();
      final col = OsColumnDef<Map<String, dynamic>>(
        field: 'sales',
        colId: 'derivedSales',
        valueGetter: (params) => (params.data['sales'] as num) * 2,
        aggFunc: (OsAggFuncParams params) =>
            params.values.fold<num>(0, (sum, v) => sum + (v as num)),
      );
      final rows = [
        {'sales': 10},
        {'sales': 20},
        {'sales': 30},
      ];

      final result = service.computeGroupAggregates(
        leafRows: rows,
        valueColumns: [col],
      );

      // Getter doubles each value (20/40/60); custom aggFunc sums to 120.
      // Before the shim fix the getter was invoked with mismatched params
      // and silently fell back to raw field lookup (summing to 60).
      expect(result['derivedSales'], equals(120));
    });

    test('built-in sum composes with valueGetter-derived numbers', () {
      final service = AggregationService<Map<String, dynamic>>();
      final col = OsColumnDef<Map<String, dynamic>>(
        field: 'price',
        colId: 'netPrice',
        valueGetter: (params) => ((params.data['price'] as num) * 0.9).round(),
        aggFunc: 'sum',
      );
      final rows = [
        {'price': 100},
        {'price': 200},
      ];

      final result = service.computeGroupAggregates(
        leafRows: rows,
        valueColumns: [col],
      );

      expect(result['netPrice'], equals(270));
    });

    test('throwing valueGetter warns once and falls back to field lookup', () {
      final service = AggregationService<Map<String, dynamic>>();
      final col = OsColumnDef<Map<String, dynamic>>(
        field: 'sales',
        colId: 'brokenGetter',
        valueGetter: (params) => throw StateError('getter blew up'),
        aggFunc: 'sum',
      );
      final rows = [
        {'sales': 5},
        {'sales': 7},
      ];

      late Map<String, dynamic> result;
      final warnings = captureWarnings(() {
        result = service.computeGroupAggregates(
          leafRows: rows,
          valueColumns: [col],
        );
      });

      expect(result['brokenGetter'], equals(12));
      expect(warnings, hasLength(1));
      expect(warnings.single, startsWith('[OS Grid] '));
      expect(warnings.single, contains('aggregation'));
    });
  });
}
