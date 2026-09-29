import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

/// Row type used for phantom-typing tests.
class Person {
  const Person(this.name, this.age);

  final String name;
  final int age;
}

/// A second, unrelated row type.
class Order {
  const Order(this.id);

  final int id;
}

/// Identity-stable top-level accessor for [Person.name].
Object? personNameAccessor(Person p) => p.name;

/// Identity-stable top-level accessor for [Person.age].
Object? personAgeAccessor(Person p) => p.age;

OsColumnRegistry get _registry => OsColumnRegistry.instance;

void main() {
  setUp(() {
    _registry.clear();
    _registry.register<Person>(const [
      OsColumnField.text(
        'name',
        personNameAccessor,
        meta: OsColumn(headerName: 'Full name'),
      ),
      OsColumnField.integer('age', personAgeAccessor),
    ], config: const OsGridColumn(colIdPrefix: 'person.'));
  });
  tearDown(_registry.clear);

  group('columnRef (registry-validated construction)', () {
    test('resolves a registered top-level accessor to its colId', () {
      final ref = columnRef<Person>(personNameAccessor);
      expect(ref.colId, 'person.name');
      expect(ref, isA<ColumnRef<Person>>());
    });

    test('resolves each field independently', () {
      expect(columnRef<Person>(personAgeAccessor).colId, 'person.age');
    });

    test('accepts an injected registry', () {
      Object? orderIdAccessor(Order o) => o.id; // top-level: identity-stable
      final local = OsColumnRegistry();
      local.register<Order>([OsColumnField.integer('id', orderIdAccessor)]);
      final ref = columnRef<Order>(orderIdAccessor, registry: local);
      expect(ref.colId, 'id');

      // Shared registry knows nothing about it.
      expect(() => columnRef<Order>(orderIdAccessor), throwsArgumentError);

      local.clear();
    });

    test('rejects anonymous closures with a helpful ArgumentError', () {
      expect(
        () => columnRef<Person>((p) => p.name),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('anonymous closures'),
          ),
        ),
      );
    });

    test('rejects accessors of an unregistered type', () {
      Object? orderAccessor(Order o) => o.id;
      expect(() => columnRef<Order>(orderAccessor), throwsArgumentError);
    });
  });

  group('ColumnRef phantom typing', () {
    test('keeps the row type in the type parameter', () {
      const ref = ColumnRef<Person>.unchecked('name');
      expect(ref, isA<ColumnRef<Person>>());
      // The generic argument is reified: an Order ref is a different type.
      expect(ref, isNot(isA<ColumnRef<Order>>()));
    });

    test('type parameter prevents cross-entity misuse', () {
      // In real code the following is a COMPILE error:
      //   ColumnRef<Order> broken = personRef;
      const personRef = ColumnRef<Person>.unchecked('name');
      const orderRef = ColumnRef<Order>.unchecked('name');
      // Same id string, distinct reified types — never interchangeable.
      expect(personRef.runtimeType, isNot(orderRef.runtimeType));
      expect(personRef.runtimeType.toString(), contains('Person'));
      expect(orderRef.runtimeType.toString(), contains('Order'));
    });
  });

  group('ColumnRef value semantics', () {
    test('equality and hashCode are colId-based within a type', () {
      const a = ColumnRef<Person>.unchecked('name');
      const b = ColumnRef<Person>.unchecked('name');
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a == const ColumnRef<Person>.unchecked('age'), isFalse);
    });

    test('toString carries type and id', () {
      const ref = ColumnRef<Person>.unchecked('name');
      expect(ref.toString(), 'ColumnRef<Person>(name)');
    });

    test('unchecked refs work as plain colId carriers', () {
      const ref = ColumnRef<Order>.unchecked('order-42');
      expect(ref.colId, 'order-42');
    });
  });

  group('registry validation helpers', () {
    test('hasColId honours prefix and explicit meta ids', () {
      expect(_registry.hasColId<Person>('person.name'), isTrue);
      expect(_registry.hasColId<Person>('person.age'), isTrue);
      expect(_registry.hasColId<Person>('name'), isFalse); // missing prefix
      expect(_registry.hasColId<Person>('nope'), isFalse);
      expect(_registry.hasColId<Order>('anything'), isFalse);
    });

    test('colIdForAccessor returns null for unknown functions', () {
      expect(_registry.colIdForAccessor<Person>((p) => p.name), isNull);
    });
  });
}
