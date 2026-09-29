import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';
import 'package:os_grid_flutter/src/utils/grid_diagnostics.dart';

/// Quality program v3 item 29 — fuzz testing edge-case data shapes.
///
/// Adversarial generators feed the existing property-style assertions
/// (sort pipeline, filter evaluator, transaction bookkeeping). Every case
/// derives its data from a fixed seed so failures are reproducible.
///
/// ## Generator inventory
///
/// Values — `_numberShapes` / `_stringShapes`:
///   null, NaN, +infinity, -infinity, max int, min int, 0, -1, 3.14;
///   empty string, whitespace-only (incl. NBSP), RTL Arabic, RTL Hebrew,
///   combining chars (NFD 'e'+U+0301 vs NFC precomposed), single emoji,
///   ZWJ emoji sequence, mixed bidi marks, 10KB string.
///
/// ColIds — groups under `ColId edge cases`:
///   duplicate field names across groups, reserved `__checkbox__` field,
///   special characters in field/colId, null field with valueGetter.
///
/// Transactions — groups under `Transactions × edge-case shapes`:
///   remove-all-then-add, update of a removed row, add with an existing id,
///   empty/null add/remove/update lists, seeded op sequences over
///   adversarial values.
///
/// Filters — groups under `FilterEvaluator × adversarial values` and the
///   widget-level pipeline group:
///   NaN/null/±infinity with the number filter, null/blank with the text
///   filter, max/min int boundaries, RTL/combining/emoji/10KB text ops.

// ---------------------------------------------------------------------------
// Generators
// ---------------------------------------------------------------------------

const int _maxInt = 9223372036854775807;
const int _minInt = -9223372036854775808;

/// Value shapes fed into numeric columns (index-stable).
const List<Object?> _numberShapes = [
  null,
  double.nan,
  double.infinity,
  double.negativeInfinity,
  _maxInt,
  _minInt,
  0,
  -1,
  3.14,
];

/// Value shapes fed into text columns (index-stable).
final List<String> _stringShapes = [
  '', // empty string
  ' \t\n\u00a0', // whitespace-only (incl. NBSP)
  'مرحبا بالعالم', // RTL Arabic
  'שלום עולם', // RTL Hebrew
  'cafe\u0301', // NFD: 'e' + combining acute
  'café', // NFC: precomposed é
  '🚀', // single emoji
  '👨‍👩‍👧‍👦', // ZWJ family sequence
  'a\u200eb\u200f', // mixed LTR/RTL marks
  'x' * 10240, // 10KB string
];

Object? _adversarialNumber(Random rng) =>
    _numberShapes[rng.nextInt(_numberShapes.length)];

String _adversarialString(Random rng) =>
    _stringShapes[rng.nextInt(_stringShapes.length)];

List<Map<String, Object?>> _generateFuzzRows(Random rng, int count) {
  return List.generate(count, (i) {
    return <String, Object?>{
      'id': 'row-$i',
      'name': _adversarialString(rng),
      'value': _adversarialNumber(rng),
    };
  });
}

/// Rows whose text column is adversarial but whose numeric column is a
/// small-int domain (tie-stress for stability assertions).
List<Map<String, Object?>> _generateTextFuzzRows(Random rng, int count) {
  const values = [0, 10, 20, 30, 40];
  return List.generate(count, (i) {
    return <String, Object?>{
      'id': 'row-$i',
      'name': _adversarialString(rng),
      'value': values[rng.nextInt(values.length)],
    };
  });
}

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: SizedBox(width: 800, height: 600, child: child)),
);

List<Map<String, dynamic>> _displayRows(WidgetTester tester) {
  final grid = tester.widget<VirtualisedGrid>(find.byType(VirtualisedGrid));
  return [for (final row in grid.rowData) row];
}

bool _isLeaf(Map<String, dynamic> row) => row['__isGroupRow'] != true;

bool _passesGreaterThanZero(Object? value) {
  // Documented FilterEvaluator number semantics: nulls follow the
  // includeBlanksIn* flags (all false by default); NaN fails every ordered
  // comparison; everything else is a plain numeric comparison.
  return value is num && !value.isNaN && value > 0;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('Adversarial values — sort invariants', () {
    test('numeric column: multiset preserved, deterministic, nulls first, '
        'num.compareTo ordering', () {
      for (var seed = 0; seed < 30; seed++) {
        final rng = Random(seed);
        final rows = _generateFuzzRows(rng, 40);

        final service = SortService<Map<String, Object?>>();
        service.setSortModel([
          const OsSortModel(colId: 'value', sort: OsSortDirection.ascending),
        ]);
        const columns = [OsColumnDef<Map<String, Object?>>(field: 'value')];

        final sorted1 = service.sortData(data: rows, columns: columns);
        final sorted2 = service.sortData(data: rows, columns: columns);

        // Deterministic.
        expect(
          sorted1.map((r) => r['id']),
          sorted2.map((r) => r['id']),
          reason: 'seed=$seed: sort must be deterministic',
        );

        // Multiset preserved.
        expect(
          sorted1.map((r) => r['id']).toSet(),
          rows.map((r) => r['id']).toSet(),
          reason: 'seed=$seed',
        );
        expect(sorted1.length, rows.length, reason: 'seed=$seed');

        // Documented ordering: nulls occupy a prefix; non-null values are
        // ascending per num.compareTo (NaN sorts above +infinity).
        var seenNonNull = false;
        for (var i = 1; i < sorted1.length; i++) {
          final a = sorted1[i - 1]['value'];
          final b = sorted1[i]['value'];
          if (a == null) {
            expect(
              seenNonNull,
              isFalse,
              reason:
                  'seed=$seed: null before '
                  'non-null at $i',
            );
            if (b != null) seenNonNull = true;
            continue;
          }
          seenNonNull = true;
          expect(b, isNotNull, reason: 'seed=$seed: null after non-null at $i');
          expect(
            (a as num).compareTo(b as num),
            lessThanOrEqualTo(0),
            reason: 'seed=$seed: adjacent order violated at $i',
          );
        }
      }
    });

    test('text column: multiset preserved and deterministic for RTL, '
        'combining chars, emoji and 10KB strings', () {
      for (var seed = 0; seed < 30; seed++) {
        final rng = Random(seed);
        final rows = _generateFuzzRows(rng, 40);

        final service = SortService<Map<String, Object?>>();
        service.setSortModel([
          const OsSortModel(colId: 'name', sort: OsSortDirection.ascending),
        ]);
        const columns = [OsColumnDef<Map<String, Object?>>(field: 'name')];

        final sorted = service.sortData(data: rows, columns: columns);

        expect(sorted.length, rows.length, reason: 'seed=$seed');
        expect(
          sorted.map((r) => r['id']).toSet(),
          rows.map((r) => r['id']).toSet(),
          reason: 'seed=$seed',
        );

        for (var i = 1; i < sorted.length; i++) {
          final a = sorted[i - 1]['name'] as String;
          final b = sorted[i]['name'] as String;
          expect(
            a.compareTo(b),
            lessThanOrEqualTo(0),
            reason: 'seed=$seed: string order violated at $i',
          );
        }
      }
    });

    test('heterogeneous column (null/int/double/String/NaN) never throws '
        'and preserves the multiset', () {
      for (var seed = 0; seed < 20; seed++) {
        final rng = Random(seed);
        final mixed = <Object?>[
          null,
          double.nan,
          double.infinity,
          _maxInt,
          _minInt,
          3.14,
          '',
          'مرحبا',
          '🚀',
          'x' * 10240,
        ];
        final rows = List.generate(30, (i) {
          return <String, Object?>{
            'id': 'row-$i',
            'v': mixed[rng.nextInt(mixed.length)],
          };
        });

        final service = SortService<Map<String, Object?>>();
        service.setSortModel([
          const OsSortModel(colId: 'v', sort: OsSortDirection.descending),
        ]);
        final sorted = service.sortData(
          data: rows,
          columns: const [OsColumnDef<Map<String, Object?>>(field: 'v')],
        );

        expect(sorted.length, rows.length, reason: 'seed=$seed');
        expect(
          sorted.map((r) => r['id']).toSet(),
          rows.map((r) => r['id']).toSet(),
          reason: 'seed=$seed: mixed-type sort must preserve the multiset',
        );
      }
    });
  });

  group('FilterEvaluator × adversarial values', () {
    bool evalNumber(
      Object? cell, {
      required String type,
      Object? filter,
      OsNumberFilter config = const OsNumberFilter(),
    }) {
      return FilterEvaluator.evaluate(
        cellValue: cell,
        filterConfig: config,
        model: OsColumnFilterModel(
          filterType: 'number',
          conditions: [OsFilterCondition(type: type, filter: filter)],
        ),
      );
    }

    bool evalText(Object? cell, String type, String filter) {
      return FilterEvaluator.evaluate(
        cellValue: cell,
        filterConfig: const OsTextFilter(),
        model: OsColumnFilterModel(
          filterType: 'text',
          conditions: [OsFilterCondition(type: type, filter: filter)],
        ),
      );
    }

    test('NaN with the number filter is blank; fails all comparisons', () {
      expect(evalNumber(double.nan, type: 'blank'), isTrue);
      expect(evalNumber(double.nan, type: 'notBlank'), isFalse);
      expect(evalNumber(double.nan, type: 'equals', filter: 0), isFalse);
      expect(
        evalNumber(double.nan, type: 'equals', filter: double.nan),
        isFalse,
      );
      expect(evalNumber(double.nan, type: 'greaterThan', filter: 0), isFalse);
      expect(evalNumber(double.nan, type: 'lessThan', filter: 0), isFalse);
    });

    test(
      'null with the number filter: blank/notBlank and includeBlanksIn*',
      () {
        expect(evalNumber(null, type: 'blank'), isTrue);
        expect(evalNumber(null, type: 'notBlank'), isFalse);
        // Default config excludes blanks from every operation.
        expect(evalNumber(null, type: 'greaterThan', filter: 0), isFalse);
        expect(evalNumber(null, type: 'equals', filter: 0), isFalse);
        // Opting in flips the verdict.
        expect(
          evalNumber(
            null,
            type: 'greaterThan',
            filter: 0,
            config: const OsNumberFilter(includeBlanksInGreaterThan: true),
          ),
          isTrue,
        );
      },
    );

    test('±infinity with greaterThan/lessThan/equals', () {
      expect(
        evalNumber(double.infinity, type: 'greaterThan', filter: 0),
        isTrue,
      );
      expect(
        evalNumber(double.infinity, type: 'greaterThan', filter: _maxInt),
        isTrue,
      );
      expect(
        evalNumber(
          double.infinity,
          type: 'greaterThan',
          filter: double.infinity,
        ),
        isFalse,
      );
      expect(evalNumber(double.infinity, type: 'lessThan', filter: 0), isFalse);
      expect(
        evalNumber(double.infinity, type: 'equals', filter: double.infinity),
        isTrue,
      );
      expect(
        evalNumber(double.negativeInfinity, type: 'lessThan', filter: 0),
        isTrue,
      );
      expect(
        evalNumber(double.negativeInfinity, type: 'greaterThan', filter: 0),
        isFalse,
      );
      expect(evalNumber(0, type: 'lessThan', filter: double.infinity), isTrue);
    });

    test('max/min int boundaries', () {
      expect(evalNumber(_maxInt, type: 'equals', filter: _maxInt), isTrue);
      expect(evalNumber(_minInt, type: 'equals', filter: _minInt), isTrue);
      expect(
        evalNumber(_maxInt, type: 'greaterThan', filter: _maxInt - 1),
        isTrue,
      );
      expect(
        evalNumber(_minInt, type: 'lessThan', filter: _minInt + 1),
        isTrue,
      );
      expect(evalNumber(_maxInt, type: 'equals', filter: _minInt), isFalse);
    });

    test('null/empty/whitespace with the text filter blank/notBlank', () {
      expect(evalText(null, 'blank', ''), isTrue);
      expect(evalText(null, 'notBlank', ''), isFalse);
      expect(evalText('', 'blank', ''), isTrue);
      expect(evalText('', 'notBlank', ''), isFalse);
      // Whitespace-only strings are NOT blank (AG Grid semantics).
      expect(evalText(' \t\n\u00a0', 'blank', ''), isFalse);
      expect(evalText(' \t\n\u00a0', 'notBlank', ''), isTrue);
    });

    test('RTL / combining chars / emoji / 10KB with text operations', () {
      // RTL contains and equals.
      expect(evalText('مرحبا بالعالم', 'contains', 'بالعالم'), isTrue);
      expect(evalText('مرحبا بالعالم', 'equals', 'مرحبا بالعالم'), isTrue);
      expect(evalText('שלום עולם', 'startsWith', 'שלום'), isTrue);
      expect(evalText('مرحبا', 'contains', 'שלום'), isFalse);

      // Combining chars: exact match per form; no unicode normalisation.
      expect(evalText('cafe\u0301', 'equals', 'cafe\u0301'), isTrue);
      expect(evalText('café', 'equals', 'café'), isTrue);
      expect(evalText('cafe\u0301', 'equals', 'café'), isFalse);
      expect(evalText('cafe\u0301', 'contains', 'e'), isTrue);

      // Emoji: single and ZWJ sequences.
      expect(evalText('🚀', 'equals', '🚀'), isTrue);
      expect(evalText('👨‍👩‍👧‍👦', 'contains', '👨‍👩‍👧'), isTrue);
      expect(evalText('👨‍👩‍👧‍👦', 'contains', '🚀'), isFalse);

      // 10KB strings.
      final tenKb = 'x' * 10240;
      expect(evalText('$tenKb-needle', 'contains', 'needle'), isTrue);
      expect(evalText(tenKb, 'contains', 'needle'), isFalse);
      expect(evalText(tenKb, 'equals', tenKb), isTrue);
      expect(evalText(tenKb, 'startsWith', 'xxx'), isTrue);
    });
  });

  group('Filter → sort pipeline with adversarial rows', () {
    testWidgets('number greaterThan(0) + desc sort equals independent '
        'composition', (tester) async {
      for (final seed in [7, 21, 42]) {
        final rng = Random(seed);
        final rows = _generateFuzzRows(rng, 30);
        final controller = OsGridController<Map<String, Object?>>();

        await tester.pumpWidget(
          _wrap(
            OsGrid<Map<String, Object?>>(
              controller: controller,
              columnDefs: const [
                OsColumnDef<Map<String, Object?>>(field: 'id', width: 80),
                OsColumnDef<Map<String, Object?>>(
                  field: 'name',
                  width: 90,
                  filter: OsTextFilter(),
                ),
                OsColumnDef<Map<String, Object?>>(
                  field: 'value',
                  width: 90,
                  sortable: true,
                  filter: OsNumberFilter(),
                ),
              ],
              rowData: rows,
              getRowId: (r) => r['id'] as String,
              initialSort: const [
                OsSortModel(colId: 'value', sort: OsSortDirection.descending),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        controller.setFilterModel({
          'value': const OsColumnFilterModel(
            filterType: 'number',
            conditions: [OsFilterCondition(type: 'greaterThan', filter: 0)],
          ).toJson(),
        });
        await tester.pumpAndSettle();

        final displayed = _displayRows(
          tester,
        ).where(_isLeaf).map((r) => r['id']).toList();

        // Independent expectation: filter first (documented number
        // semantics), then stable descending sort.
        final expected =
            rows.where((r) => _passesGreaterThanZero(r['value'])).toList()
              ..sort((a, b) {
                final result = (b['value'] as num).compareTo(a['value'] as num);
                if (result != 0) return result;
                return rows.indexOf(a) - rows.indexOf(b);
              });

        expect(
          displayed,
          expected.map((r) => r['id']).toList(),
          reason: 'seed=$seed: pipeline must be filter->sort',
        );

        await tester.pumpWidget(const SizedBox.shrink());
      }
    });

    testWidgets('text equals with adversarial strings + tie-stressed sort '
        'is stable', (tester) async {
      for (final seed in [3, 17]) {
        final rng = Random(seed);
        final rows = _generateTextFuzzRows(rng, 40);
        const target = 'مرحبا بالعالم';
        // Guarantee the filter has matches regardless of seed.
        rows[0] = <String, Object?>{'id': 'row-0', 'name': target, 'value': 20};
        rows[5] = <String, Object?>{'id': 'row-5', 'name': target, 'value': 20};

        final controller = OsGridController<Map<String, Object?>>();

        await tester.pumpWidget(
          _wrap(
            OsGrid<Map<String, Object?>>(
              controller: controller,
              columnDefs: const [
                OsColumnDef<Map<String, Object?>>(field: 'id', width: 80),
                OsColumnDef<Map<String, Object?>>(
                  field: 'name',
                  width: 90,
                  filter: OsTextFilter(),
                ),
                OsColumnDef<Map<String, Object?>>(
                  field: 'value',
                  width: 90,
                  sortable: true,
                ),
              ],
              rowData: rows,
              getRowId: (r) => r['id'] as String,
              initialSort: const [
                OsSortModel(colId: 'value', sort: OsSortDirection.descending),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        controller.setFilterModel({
          'name': const OsColumnFilterModel(
            filterType: 'text',
            conditions: [OsFilterCondition(type: 'equals', filter: target)],
          ).toJson(),
        });
        await tester.pumpAndSettle();

        final displayed = _displayRows(
          tester,
        ).where(_isLeaf).map((r) => r['id']).toList();

        // Independent expectation: filter equals (exact match), then stable
        // desc sort by value.
        final expected = rows.where((r) => r['name'] == target).toList()
          ..sort((a, b) {
            final result = (b['value'] as int).compareTo(a['value'] as int);
            if (result != 0) return result;
            return rows.indexOf(a) - rows.indexOf(b);
          });

        expect(expected.length, greaterThanOrEqualTo(2), reason: 'seed=$seed');
        expect(
          displayed,
          expected.map((r) => r['id']).toList(),
          reason: 'seed=$seed',
        );

        await tester.pumpWidget(const SizedBox.shrink());
      }
    });
  });

  group('Transactions × edge-case shapes', () {
    test('remove all rows then add restores a consistent model', () {
      for (var seed = 0; seed < 10; seed++) {
        final rng = Random(seed);
        final rows = _generateFuzzRows(rng, 12);
        final controller = OsGridController<Map<String, Object?>>();
        controller.getRowId = (r) => r['id'] as String;
        controller.setRowData(rows);

        const selectedIds = {'row-1', 'row-5'};
        controller.selectRowsById(selectedIds.toList());

        controller.applyTransaction(
          OsRowTransaction<Map<String, Object?>>(remove: List.of(rows)),
        );
        expect(controller.rowCount, 0, reason: 'seed=$seed');
        expect(controller.rawRowData, isEmpty, reason: 'seed=$seed');
        for (final row in rows) {
          expect(
            controller.getNode(row['id'] as String),
            isNull,
            reason: 'seed=$seed',
          );
        }
        expect(
          controller.getSelectedIds(),
          isEmpty,
          reason: 'seed=$seed: removing rows must clear their selection',
        );

        final adds = List.generate(7, (i) {
          return <String, Object?>{
            'id': 'new-$i',
            'name': _adversarialString(rng),
            'value': _adversarialNumber(rng),
          };
        });
        controller.applyTransaction(
          OsRowTransaction<Map<String, Object?>>(add: adds),
        );
        expect(controller.rowCount, adds.length, reason: 'seed=$seed');
        for (final row in adds) {
          final node = controller.getNode(row['id'] as String);
          expect(node, isNotNull, reason: 'seed=$seed');
          expect(
            identical(node!.data, row),
            isTrue,
            reason: 'seed=$seed: node must wrap the added instance',
          );
        }
        expect(controller.getSelectedIds(), isEmpty, reason: 'seed=$seed');
        expect(
          controller.rawRowData.map((r) => r['id']).toSet(),
          adds.map((r) => r['id']).toSet(),
          reason: 'seed=$seed',
        );

        controller.dispose();
      }
    });

    test('updating a removed row is a no-op', () {
      for (var seed = 0; seed < 10; seed++) {
        final rng = Random(seed);
        final rows = _generateFuzzRows(rng, 10);
        final controller = OsGridController<Map<String, Object?>>();
        controller.getRowId = (r) => r['id'] as String;
        controller.setRowData(rows);

        final victim = rows[3];
        controller.applyTransaction(
          OsRowTransaction<Map<String, Object?>>(remove: [victim]),
        );
        expect(controller.getNode('row-3'), isNull);

        // Update the removed row (same id, adversarial replacement).
        final phantom = <String, Object?>{
          'id': 'row-3',
          'name': _adversarialString(rng),
          'value': double.nan,
        };
        controller.applyTransaction(
          OsRowTransaction<Map<String, Object?>>(update: [phantom]),
        );

        expect(controller.rowCount, rows.length - 1, reason: 'seed=$seed');
        expect(
          controller.getNode('row-3'),
          isNull,
          reason: 'seed=$seed: update must not resurrect the removed row',
        );
        expect(
          controller.rawRowData.contains(phantom),
          isFalse,
          reason: 'seed=$seed',
        );
        expect(
          controller.rawRowData.map((r) => r['id']).toSet(),
          rows.where((r) => !identical(r, victim)).map((r) => r['id']).toSet(),
          reason: 'seed=$seed',
        );

        controller.dispose();
      }
    });

    test('adding a row with an existing id appends; the node map keeps the '
        'last instance', () {
      for (var seed = 0; seed < 10; seed++) {
        final rng = Random(seed);
        final rows = _generateFuzzRows(rng, 8);
        final controller = OsGridController<Map<String, Object?>>();
        controller.getRowId = (r) => r['id'] as String;
        controller.setRowData(rows);

        final duplicate = <String, Object?>{
          'id': 'row-2',
          'name': _adversarialString(rng),
          'value': double.infinity,
        };
        controller.applyTransaction(
          OsRowTransaction<Map<String, Object?>>(add: [duplicate]),
        );

        expect(controller.rowCount, rows.length + 1, reason: 'seed=$seed');
        expect(
          controller.rawRowData.where((r) => r['id'] == 'row-2').length,
          2,
          reason: 'seed=$seed: raw data must hold both instances',
        );
        final node = controller.getNode('row-2');
        expect(node, isNotNull, reason: 'seed=$seed');
        expect(
          identical(node!.data, duplicate),
          isTrue,
          reason: 'seed=$seed: last added instance must win the node map',
        );

        var visited = 0;
        controller.forEachRowNode((node) {
          if (node.id == 'row-2') visited++;
        });
        expect(visited, 2, reason: 'seed=$seed');

        controller.dispose();
      }
    });

    test('empty and null transaction lists are no-ops', () {
      final rng = Random(9);
      final rows = _generateFuzzRows(rng, 6);
      final controller = OsGridController<Map<String, Object?>>();
      controller.getRowId = (r) => r['id'] as String;
      controller.setRowData(rows);
      const selectedIds = {'row-0', 'row-3'};
      controller.selectRowsById(selectedIds.toList());

      final baselineIds = controller.rawRowData.map((r) => r['id']).toList();

      controller.applyTransaction(
        const OsRowTransaction<Map<String, Object?>>(),
      );
      expect(controller.rowCount, rows.length);
      expect(controller.rawRowData.map((r) => r['id']), baselineIds);
      expect(controller.getSelectedIds(), selectedIds);

      controller.applyTransaction(
        const OsRowTransaction<Map<String, Object?>>(
          add: [],
          remove: [],
          update: [],
        ),
      );
      expect(controller.rowCount, rows.length);
      expect(controller.rawRowData.map((r) => r['id']), baselineIds);
      expect(controller.getSelectedIds(), selectedIds);
      expect(controller.getNode('row-0'), isNotNull);
      expect(controller.getNode('row-3'), isNotNull);

      controller.dispose();
    });

    test('seeded op sequences with adversarial values keep the model '
        'consistent', () {
      for (var seed = 0; seed < 15; seed++) {
        final rng = Random(seed);
        final rows = _generateFuzzRows(rng, 30);
        final controller = OsGridController<Map<String, Object?>>();
        controller.getRowId = (r) => r['id'] as String;
        controller.setRowData(rows);

        var expectedById = {for (final row in rows) row['id'] as String: row};

        const selectedIds = {'row-2', 'row-9'};
        controller.selectRowsById(selectedIds.toList());

        for (var round = 0; round < 6; round++) {
          final tag = 's${seed}r$round';
          final removablePool = expectedById.keys
              .where((id) => !selectedIds.contains(id))
              .toList();
          final removedIds = <String>{
            for (final id in removablePool)
              if (rng.nextDouble() < 0.25) id,
          };
          final updateIds = <String>{
            for (final id in expectedById.keys)
              if (!removedIds.contains(id) && rng.nextDouble() < 0.25) id,
          };
          final updates = [
            for (final id in updateIds)
              <String, Object?>{
                'id': id,
                'name': _adversarialString(rng),
                'value': _adversarialNumber(rng),
              },
          ];
          final adds = List.generate(rng.nextInt(3), (k) {
            return <String, Object?>{
              'id': 'add-$tag-$k',
              'name': _adversarialString(rng),
              'value': _adversarialNumber(rng),
            };
          });

          controller.applyTransaction(
            OsRowTransaction<Map<String, Object?>>(
              add: adds.isEmpty ? null : adds,
              remove: removedIds.isEmpty
                  ? null
                  : [for (final id in removedIds) expectedById[id]!],
              update: updates.isEmpty ? null : updates,
            ),
          );

          final nextById = Map.of(expectedById);
          for (final id in removedIds) {
            nextById.remove(id);
          }
          for (final row in updates) {
            nextById[row['id'] as String] = row;
          }
          for (final row in adds) {
            nextById[row['id'] as String] = row;
          }
          expectedById = nextById;

          // Row-count consistency.
          expect(
            controller.rowCount,
            expectedById.length,
            reason: 'seed=$seed round=$round',
          );

          // Removed ids absent; survivors present.
          for (final id in removedIds) {
            expect(
              controller.getNode(id),
              isNull,
              reason: 'seed=$seed round=$round: $id',
            );
          }
          for (final id in expectedById.keys) {
            expect(
              controller.getNode(id),
              isNotNull,
              reason: 'seed=$seed round=$round: $id',
            );
          }

          // Updated nodes wrap the exact replacement instance.
          for (final row in updates) {
            final node = controller.getNode(row['id'] as String)!;
            expect(
              identical(node.data, row),
              isTrue,
              reason: 'seed=$seed round=$round: ${row['id']}',
            );
          }

          // Selection survives non-remove operations.
          expect(
            controller.getSelectedIds(),
            selectedIds.where((id) => expectedById.containsKey(id)).toSet(),
            reason: 'seed=$seed round=$round',
          );

          // Raw data mirrors the expected id set exactly.
          expect(
            controller.rawRowData.map((r) => r['id']).toSet(),
            expectedById.keys.toSet(),
            reason: 'seed=$seed round=$round',
          );
        }
        controller.dispose();
      }
    });
  });

  group('ColId edge cases', () {
    testWidgets('duplicate field names across groups build and render', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, Object?>>();
      final rows = List.generate(6, (i) {
        return <String, Object?>{'id': 'row-$i', 'v': i};
      });

      // Duplicate colIds are only WARNED about, never deduped: the
      // diagnostic must fire even though the grid keeps rendering.
      final diagnostics = <GridDiagnostic>[];
      GridDiagnostics.addListener(diagnostics.add);
      try {
        await tester.pumpWidget(
          _wrap(
            OsGrid<Map<String, Object?>>(
              controller: controller,
              columnDefs: const [
                OsColumnGroup(
                  headerName: 'G1',
                  children: [OsColumnDef<Map<String, Object?>>(field: 'v')],
                ),
                OsColumnGroup(
                  headerName: 'G2',
                  children: [OsColumnDef<Map<String, Object?>>(field: 'v')],
                ),
                OsColumnDef<Map<String, Object?>>(field: 'id'),
              ],
              rowData: rows,
              getRowId: (r) => r['id'] as String,
            ),
          ),
        );
        await tester.pumpAndSettle();
      } finally {
        GridDiagnostics.removeListener(diagnostics.add);
      }

      expect(
        diagnostics.where((d) => d.code == GridErrorCode.duplicateColId),
        isNotEmpty,
        reason:
            'duplicate field names across groups must raise the '
            'duplicateColId diagnostic',
      );

      // Group children are not pushed into the controller's column defs
      // (only non-group leaves are), so they are not controller-addressable.
      expect(controller.getColumns().length, 1);

      // Rendering is unaffected: every leaf row still displays.
      final leaves = _displayRows(tester).where(_isLeaf).length;
      expect(leaves, rows.length);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('reserved __checkbox__ user field coexists with the '
        'synthetic checkbox column', (tester) async {
      final controller = OsGridController<Map<String, Object?>>();
      final rows = List.generate(5, (i) {
        return <String, Object?>{
          'id': 'row-$i',
          '__checkbox__': i.isEven,
          'label': 'n$i',
        };
      });

      await tester.pumpWidget(
        _wrap(
          OsGrid<Map<String, Object?>>(
            controller: controller,
            columnDefs: const [
              OsColumnDef<Map<String, Object?>>(
                field: '__checkbox__',
                headerName: 'Mine',
                width: 70,
              ),
              OsColumnDef<Map<String, Object?>>(field: 'label', width: 90),
            ],
            rowData: rows,
            getRowId: (r) => r['id'] as String,
            rowSelection: OsRowSelection.multiple(checkboxes: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The composed display model carries BOTH the synthetic checkbox
      // column and the user's column with the same reserved field.
      final composed = tester
          .widget<VirtualisedGrid>(find.byType(VirtualisedGrid))
          .columns;
      expect(composed.where((c) => c.field == '__checkbox__').length, 2);
      // The controller only sees the user column (synthetic columns are
      // composed at widget level, not pushed into the controller).
      expect(
        controller.getColumns().where((c) => c.field == '__checkbox__').length,
        1,
      );
      // Selection APIs remain functional despite the name collision.
      controller.selectRowsById(['row-1', 'row-3']);
      await tester.pumpAndSettle();
      expect(controller.getSelectedIds(), {'row-1', 'row-3'});

      final leaves = _displayRows(tester).where(_isLeaf).length;
      expect(leaves, rows.length);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('special characters in field/colId round-trip through '
        'getColumnDef', (tester) async {
      final controller = OsGridController<Map<String, Object?>>();
      final rows = List.generate(5, (i) {
        return <String, Object?>{'id': 'row-$i', 'a.b/c': i};
      });
      const weirdColId = r'x:y[0]|z';

      await tester.pumpWidget(
        _wrap(
          OsGrid<Map<String, Object?>>(
            controller: controller,
            columnDefs: const [
              OsColumnDef<Map<String, Object?>>(
                field: 'a.b/c',
                colId: weirdColId,
                width: 90,
              ),
              OsColumnDef<Map<String, Object?>>(field: 'id', width: 80),
            ],
            rowData: rows,
            getRowId: (r) => r['id'] as String,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final col = controller.getColumnDef(weirdColId);
      expect(col, isNotNull);
      expect(col!.field, 'a.b/c');

      final leaves = _displayRows(tester).where(_isLeaf).length;
      expect(leaves, rows.length);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('null field with valueGetter gets a generated colId that '
        'round-trips', (tester) async {
      final controller = OsGridController<Map<String, Object?>>();
      final rows = List.generate(5, (i) {
        return <String, Object?>{'id': 'row-$i', 'n': i};
      });

      await tester.pumpWidget(
        _wrap(
          OsGrid<Map<String, Object?>>(
            controller: controller,
            columnDefs: [
              OsColumnDef<Map<String, Object?>>(
                valueGetter: (params) => (params.data['n'] as int) * 2,
                width: 90,
                headerName: 'Doubled',
              ),
              const OsColumnDef<Map<String, Object?>>(field: 'id', width: 80),
            ],
            rowData: rows,
            getRowId: (r) => r['id'] as String,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // NOTE: reading `c.valueGetter` through the type-erased
      // List<OsColumnDef> throws a covariant TypeError for typed getters,
      // so the getter is probed via getValueGetterAsFunction() instead.
      final fieldless = controller
          .getColumns()
          .where((c) => c.field == null && c.getValueGetterAsFunction() != null)
          .toList();
      expect(fieldless.length, 1);
      expect(fieldless.first.effectiveColId, startsWith('col_'));
      expect(
        controller.getColumnDef(fieldless.first.effectiveColId),
        isNotNull,
      );

      final leaves = _displayRows(tester).where(_isLeaf).length;
      expect(leaves, rows.length);

      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
