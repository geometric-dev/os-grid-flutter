import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';
import 'package:os_grid_flutter/src/data/lazy_row_map.dart';
import 'package:os_grid_flutter/src/rendering/grid_model_resolver.dart';

/// Cell-level lazy evaluation for typed rows (quality program v3 item 15).
///
/// Contract: wrapping a typed row in [LazyValueRowMap] defers every
/// valueGetter until its field is first read and memoizes the result per
/// map lifetime; the key surface (keys / containsKey / reads / writes) is
/// value-compatible with the eager `GridModelResolver.typedRowToMap`; and a
/// wired [ValueCache] serves repeat evaluations across map instances until
/// the pipeline expires it.
void main() {
  /// Columns whose getters count their invocations per field.
  (List<OsColumnDef<Person>>, Map<String, int>) countingColumns() {
    final counter = <String, int>{};
    final cols = [
      OsColumnDef<Person>(
        field: 'name',
        headerName: 'Name',
        valueGetter: (params) {
          counter['name'] = (counter['name'] ?? 0) + 1;
          return params.data.name;
        },
      ),
      OsColumnDef<Person>(
        field: 'age',
        headerName: 'Age',
        valueGetter: (params) {
          counter['age'] = (counter['age'] ?? 0) + 1;
          return params.data.age;
        },
      ),
      // Getter-less and __-prefixed fields are absent from the display map.
      const OsColumnDef<Person>(field: 'unused', headerName: 'Unused'),
      const OsColumnDef<Person>(field: '__internal', headerName: 'Internal'),
    ];
    return (cols, counter);
  }

  List<OsColumnDef> plainColumns() => [
    OsColumnDef<Person>(
      field: 'name',
      headerName: 'Name',
      valueGetter: (params) => params.data.name,
    ),
    OsColumnDef<Person>(
      field: 'age',
      headerName: 'Age',
      valueGetter: (params) => params.data.age,
    ),
    const OsColumnDef<Person>(field: 'unused', headerName: 'Unused'),
    const OsColumnDef<Person>(field: '__internal', headerName: 'Internal'),
  ];

  group('LazyValueRowMap vs eager typedRowToMap', () {
    test('produces identical values and keys', () {
      const person = Person(name: 'Alice', age: 30);
      final index = GridModelResolver.buildLazyFieldIndex(plainColumns());
      final lazy = GridModelResolver.lazyRowToMap<Person>(person, 4, index);
      final eager = GridModelResolver.typedRowToMap<Person>(
        person,
        4,
        plainColumns(),
      );

      expect(lazy.keys, unorderedEquals(eager.keys));
      for (final key in eager.keys) {
        expect(lazy[key], eager[key]);
      }
      expect(lazy.length, eager.length);
      expect(lazy.containsKey('name'), eager.containsKey('name'));
      expect(lazy.containsKey('unused'), isFalse);
      expect(lazy.containsKey('__internal'), isFalse);
      expect(lazy['__internal'], isNull);
    });
  });

  group('laziness and per-instance memoization', () {
    test('construction evaluates nothing; reads evaluate once per field', () {
      final (cols, counter) = countingColumns();
      const person = Person(name: 'Alice', age: 30);
      final index = GridModelResolver.buildLazyFieldIndex(cols);
      final lazy = LazyValueRowMap<Person>(
        row: person,
        rowIndex: 0,
        columnsByField: index,
      );

      // Construction: zero getter calls.
      expect(counter, isEmpty);

      // First read of 'name': exactly one call; second read: memo hit.
      expect(lazy['name'], 'Alice');
      expect(counter['name'], 1);
      expect(lazy['name'], 'Alice');
      expect(counter['name'], 1);

      // Other fields are independent.
      expect(lazy['age'], 30);
      expect(counter['age'], 1);
      expect(counter, {'name': 1, 'age': 1});
    });

    test('key surface does not evaluate getters', () {
      final (cols, counter) = countingColumns();
      final index = GridModelResolver.buildLazyFieldIndex(cols);
      final lazy = LazyValueRowMap<Person>(
        row: const Person(name: 'Alice', age: 30),
        rowIndex: 0,
        columnsByField: index,
      );

      expect(lazy.length, 2);
      expect(lazy.keys.toList(), unorderedEquals(['name', 'age']));
      expect(lazy.containsKey('name'), isTrue);
      expect(counter, isEmpty, reason: 'keys/containsKey must not evaluate');

      expect(lazy.containsValue(30), isTrue);
      expect(counter['age'], 1);
    });
  });

  group('write-through surface', () {
    test('assignment shadows the getter; remove/clear restore absence', () {
      final (cols, counter) = countingColumns();
      final index = GridModelResolver.buildLazyFieldIndex(cols);
      final lazy = LazyValueRowMap<Person>(
        row: const Person(name: 'Alice', age: 30),
        rowIndex: 0,
        columnsByField: index,
      );

      lazy['name'] = 'Bob';
      expect(lazy['name'], 'Bob');
      expect(counter['name'], isNull, reason: 'override skips the getter');
      expect(lazy.containsKey('name'), isTrue);

      expect(lazy.remove('name'), 'Bob');
      expect(lazy.containsKey('name'), isFalse);
      expect(lazy['name'], isNull);

      lazy['extra'] = 42;
      expect(lazy.keys.toList(), unorderedEquals(['age', 'extra']));

      lazy.clear();
      expect(lazy.keys, isEmpty);
      expect(lazy['age'], isNull);
    });
  });

  group('grid-level ValueCache integration', () {
    test('second map instance is served from the cache', () {
      final (cols, counter) = countingColumns();
      final cache = ValueCache();
      final index = GridModelResolver.buildLazyFieldIndex(cols);

      LazyValueRowMap<Person> build() => LazyValueRowMap<Person>(
        row: const Person(name: 'Alice', age: 30),
        rowIndex: 0,
        columnsByField: index,
        valueCache: cache,
        rowId: 'p1',
      );

      final first = build();
      expect(first['name'], 'Alice');
      expect(first['age'], 30);
      expect(counter, {'name': 1, 'age': 1});

      // A fresh map over the same row id reuses the cached values.
      final second = build();
      expect(second['name'], 'Alice');
      expect(second['age'], 30);
      expect(counter, {
        'name': 1,
        'age': 1,
      }, reason: 'valueGetter must not re-run on a cache hit');
      expect(cache.length, 2);
    });

    test('expire() forces re-evaluation in the next build pass', () {
      final (cols, counter) = countingColumns();
      final cache = ValueCache();
      final index = GridModelResolver.buildLazyFieldIndex(cols);
      LazyValueRowMap<Person> build() => LazyValueRowMap<Person>(
        row: const Person(name: 'Alice', age: 30),
        rowIndex: 0,
        columnsByField: index,
        valueCache: cache,
        rowId: 'p1',
      );

      final first = build();
      expect(first['name'], 'Alice');
      expect(counter['name'], 1);

      // The pipeline expires the cache on every data/sort/filter reprocess;
      // the next build wraps rows in fresh maps, whose reads re-evaluate.
      cache.expire();
      final second = build();
      expect(second['name'], 'Alice');
      expect(counter['name'], 2);
    });

    test('without a rowId the cache is bypassed (per-instance memo only)', () {
      final (cols, counter) = countingColumns();
      final cache = ValueCache();
      final index = GridModelResolver.buildLazyFieldIndex(cols);
      final lazy = LazyValueRowMap<Person>(
        row: const Person(name: 'Alice', age: 30),
        rowIndex: 0,
        columnsByField: index,
        valueCache: cache,
      );

      expect(lazy['name'], 'Alice');
      expect(cache.isActive, isFalse);
      expect(counter['name'], 1);
    });
  });

  group('widget: getters fire only for visible-window cells', () {
    testWidgets('initial frame evaluates far fewer than all cells', (
      tester,
    ) async {
      var getterCalls = 0;
      final people = [
        for (var i = 0; i < 300; i++) Person(name: 'Person $i', age: i),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Person>(
              columnDefs: [
                OsColumnDef<Person>(
                  field: 'name',
                  headerName: 'Name',
                  valueGetter: (params) {
                    getterCalls++;
                    return params.data.name;
                  },
                ),
                OsColumnDef<Person>(
                  field: 'age',
                  headerName: 'Age',
                  valueGetter: (params) {
                    getterCalls++;
                    return params.data.age;
                  },
                ),
              ],
              rowData: people,
              rowHeight: 40,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 300 rows × 2 columns would be 600 eager getter calls per build on
      // master; only visible cells may evaluate.
      expect(getterCalls, lessThan(600));
      expect(getterCalls, greaterThan(0));
    });

    testWidgets('map rows are untouched (identity pass-through)', (
      tester,
    ) async {
      final rows = [
        for (var i = 0; i < 5; i++) <String, dynamic>{'a': i, 'b': 'row $i'},
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              columnDefs: [
                const OsColumnDef<Map<String, dynamic>>(
                  field: 'a',
                  headerName: 'A',
                ),
                const OsColumnDef<Map<String, dynamic>>(
                  field: 'b',
                  headerName: 'B',
                ),
              ],
              rowData: rows,
              rowHeight: 40,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final grid = tester.widget<VirtualisedGrid>(find.byType(VirtualisedGrid));
      // Map rows pass through by identity; only typed rows are wrapped.
      expect(identical(grid.rowData[0], rows[0]), isTrue);
      expect(grid.rowData[0]['b'], 'row 0');
    });
  });
}

/// Typed row model.
class Person {
  const Person({required this.name, required this.age});

  final String name;
  final int age;
}
