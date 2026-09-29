import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

/// Row data used across the runtime factory tests.
class Person {
  Person(this.name, this.age, this.active, this.joined);

  final String name;
  final int age;
  final bool active;
  final DateTime joined;
}

/// Mutable row used to verify write-back wiring.
class MutableRow {
  MutableRow(this.score);

  double score;
}

Object? _personName(Person p) => p.name;

OsColumnRegistry get _registry => OsColumnRegistry.instance;

ValueGetterParams<Person> _params(Person p) =>
    ValueGetterParams<Person>(data: p, rowIndex: 0);

void _registerPerson() {
  _registry.register<Person>(
    [
      const OsColumnField.text(
        'name',
        _personName,
        meta: OsColumn(headerName: 'Full name', width: 150),
      ),
      OsColumnField.integer('age', (p) => p.age),
      OsColumnField.boolean('active', (p) => p.active),
      OsColumnField.date('joined', (p) => p.joined),
    ],
    config: const OsGridColumn(
      colIdPrefix: 'person.',
      defaultWidth: 90,
      exclude: {'joined'},
    ),
  );
}

void main() {
  setUp(() {
    _registry.clear();
    _registerPerson();
  });
  tearDown(_registry.clear);

  group('OsColumnDefs.fromSchema / OsColumnDef.fromType (runtime factory)', () {
    test('derives one typed def per registered field, preserving order', () {
      final columns = OsColumnDef.fromType<Person>();
      // 'joined' is excluded via class-level config.
      expect(columns, hasLength(3));
      expect(columns.map((c) => c.field), ['name', 'age', 'active']);
    });

    test('defs are typed List<OsColumnDef<T>> and unmodifiable', () {
      final columns = OsColumnDefs.fromType<Person>();
      expect(columns, isA<List<OsColumnDef<Person>>>());
      expect(() => columns.add(columns.first), throwsUnsupportedError);
    });

    test('applies field annotation metadata over class defaults', () {
      final columns = OsColumnDefs.fromType<Person>();
      final name = columns[0];
      expect(name.headerName, 'Full name');
      expect(name.width, 150);
      expect(name.colId, 'person.name');

      final age = columns[1];
      expect(age.headerName, 'Age'); // capitalised from field name
      expect(age.width, 90); // class-level default
      expect(age.colId, 'person.age'); // prefix + field
    });

    test('infers filters from declared kinds', () {
      final columns = OsColumnDefs.fromType<Person>();
      expect(columns[0].filter, isA<OsTextFilter>());
      expect(columns[1].filter, isA<OsNumberFilter>());
      // Boolean columns default to no filter.
      expect(columns[2].filter, isNull);
    });

    test('boolean fields render the built-in checkbox when not editable', () {
      final columns = OsColumnDefs.fromType<Person>();
      expect(columns[2].builtInCellRenderer, OsBuiltInCellRenderer.checkbox);
      expect(columns[0].builtInCellRenderer, isNull);
    });

    test('valueGetter reads through the registered accessor', () {
      final columns = OsColumnDefs.fromType<Person>();
      final person = Person('Ada', 36, true, DateTime(2020, 1, 2));
      final getter = columns[0].getValueGetterAsFunction();
      expect(getter, isNotNull);
      expect(getter!(_params(person)), 'Ada');
    });

    test('explicit filter hint overrides kind inference', () {
      _registry.register<MutableRow>([
        OsColumnField.number(
          'score',
          (r) => r.score,
          setValue: (r, v) => r.score = v as double,
          meta: const OsColumn(
            headerName: 'Score',
            editable: true,
            filter: OsColumnFilterHint.text,
          ),
        ),
        OsColumnField.date(
          'stamp',
          (r) => DateTime.now(),
          meta: const OsColumn(filter: OsColumnFilterHint.none),
        ),
      ]);
      final columns = OsColumnDefs.fromType<MutableRow>();
      expect(columns[0].filter, isA<OsTextFilter>());
      expect(columns[1].filter, isNull); // explicit none beats date inference
    });

    test('editable fields with write-back gain editor + valueSetter', () {
      _registry.register<MutableRow>([
        OsColumnField.number(
          'score',
          (r) => r.score,
          setValue: (r, v) => r.score = v as double,
          meta: const OsColumn(headerName: 'Score', editable: true),
        ),
      ]);
      final columns = OsColumnDefs.fromType<MutableRow>();
      final row = MutableRow(1.5);

      expect(columns.single.cellEditor, isA<OsNumberCellEditor>());

      final setter = columns.single.valueSetter!;
      final ok = setter(
        ValueSetterParams<MutableRow>(
          data: row,
          colDef: columns.single,
          oldValue: 1.5,
          newValue: 42.0,
          rowIndex: 3,
        ),
      );
      expect(ok, isTrue);
      expect(row.score, 42.0);
    });

    test('editable without write-back yields editor but no setter', () {
      _registry.register<MutableRow>([
        OsColumnField.number(
          'score',
          (r) => r.score,
          meta: const OsColumn(editable: true),
        ),
      ]);
      final columns = OsColumnDefs.fromType<MutableRow>();
      expect(columns.single.valueSetter, isNull);
      expect(columns.single.cellEditor, isNotNull);
    });

    test('non-editable boolean skips editor, keeps checkbox renderer', () {
      final columns = OsColumnDefs.fromType<Person>();
      expect(columns[2].cellEditor, isNull);
      expect(columns[2].builtInCellRenderer, OsBuiltInCellRenderer.checkbox);
    });

    test('date fields infer the date filter', () {
      _registry.register<MutableRow>([
        OsColumnField.date('stamp', (r) => DateTime(2024)),
      ]);
      expect(
        OsColumnDefs.fromType<MutableRow>().single.filter,
        isA<OsDateFilter>(),
      );
    });

    test(
      'overrides replace a definition but are back-filled with plumbing',
      () {
        final columns = OsColumnDef.fromType<Person>(
          overrides: {
            'age': OsColumnDef<Person>(
              headerName: 'Years',
              width: 200,
              valueFormatter: (p) => '${p.value}y',
            ),
          },
        );
        final age = columns[1];
        expect(age.headerName, 'Years');
        expect(age.width, 200);
        expect(age.field, 'age');
        expect(age.colId, 'person.age');
        // Back-filled accessor still resolves values.
        final getter = age.getValueGetterAsFunction()!;
        expect(getter(_params(Person('Bo', 7, false, DateTime(2021)))), 7);
        expect(age.filter, isA<OsNumberFilter>()); // inference preserved
      },
    );

    test('unregistered types throw a descriptive StateError', () {
      expect(
        () => OsColumnDef.fromType<int>(),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('No OsColumnSchema registered for int'),
          ),
        ),
      );
    });

    test('registry exposes registration state', () {
      expect(_registry.isRegistered<Person>(), isTrue);
      expect(_registry.isRegistered<MutableRow>(), isFalse);
      expect(_registry.registeredTypes, contains(Person));
      _registry.unregister<Person>();
      expect(_registry.isRegistered<Person>(), isFalse);
    });

    test('re-registration replaces the prior schema', () {
      _registry.register<Person>(const [OsColumnField.text('only', empty)]);
      final columns = OsColumnDef.fromType<Person>();
      expect(columns, hasLength(1));
      expect(columns.single.field, 'only');
    });
  });
}

/// Trivial accessor for re-registration test.
Object? empty(Object? _) => null;
