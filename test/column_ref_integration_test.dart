import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

/// Quality program v3 item 38-expansion — `ColumnRef<T>` integration test.
///
/// Verifies the phantom-typed column reference end-to-end against a
/// registered schema, derived columns, the live grid controller and the
/// typo-prevention contract.

class Employee {
  const Employee(this.name, this.age, this.city);

  final String name;
  final int age;
  final String city;
}

/// An unrelated row type used to prove cross-entity accessors are rejected.
class Timesheet {
  const Timesheet(this.hours);

  final int hours;
}

// Identity-stable top-level accessors (required for registry matching).
Object? employeeName(Employee e) => e.name;
Object? employeeAge(Employee e) => e.age;
Object? employeeCity(Employee e) => e.city;
Object? timesheetHours(Timesheet t) => t.hours;

/// Loosely typed mirror of [timesheetHours]: a `dynamic` parameter makes it
/// assignable to every entity's accessor slot, so only the registry's
/// identity check can reject it.
Object? anyHours(dynamic row) => row.hours;

OsColumnRegistry get _registry => OsColumnRegistry.instance;

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: SizedBox(width: 800, height: 600, child: child)),
);

List<Map<String, dynamic>> _displayRows(WidgetTester tester) {
  final grid = tester.widget<VirtualisedGrid>(find.byType(VirtualisedGrid));
  return [for (final row in grid.rowData) row];
}

void main() {
  setUp(() {
    _registry
      ..clear()
      ..register<Employee>(const [
        OsColumnField.text(
          'name',
          employeeName,
          meta: OsColumn(headerName: 'Full name'),
        ),
        OsColumnField.integer('age', employeeAge),
        OsColumnField.text('city', employeeCity),
      ], config: const OsGridColumn(colIdPrefix: 'employee.'))
      ..register<Timesheet>(const [
        OsColumnField.integer('hours', timesheetHours),
      ]);
  });

  tearDown(_registry.clear);

  group('ColumnRef × registry × derived columns', () {
    test('schema registration + fromType derive columns with prefixed '
        'colIds', () {
      expect(_registry.isRegistered<Employee>(), isTrue);

      final columns = OsColumnDefs.fromType<Employee>();
      expect(columns.map((c) => c.effectiveColId), [
        'employee.name',
        'employee.age',
        'employee.city',
      ]);
    });

    test('columnRef resolves a typed accessor to the derived colId', () {
      final nameRef = columnRef<Employee>(employeeName);
      expect(nameRef.colId, 'employee.name');
      expect(nameRef, isA<ColumnRef<Employee>>());

      final ageRef = columnRef<Employee>(employeeAge);
      expect(ageRef.colId, 'employee.age');
    });

    testWidgets('getColumnDef via ref.colId returns the right derived '
        'column', (tester) async {
      const rows = [
        Employee('Ada', 36, 'London'),
        Employee('Grace', 45, 'New York'),
      ];
      final controller = OsGridController<Employee>();

      await tester.pumpWidget(
        _wrap(
          OsGrid<Employee>(
            controller: controller,
            columnDefs: OsColumnDefs.fromType<Employee>(),
            rowData: rows,
            getRowId: (e) => e.name,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final nameRef = columnRef<Employee>(employeeName);
      final col = controller.getColumnDef(nameRef.colId);

      expect(col, isNotNull);
      expect(col!.field, 'name');
      expect(col.headerName, 'Full name');
      expect(col.effectiveColId, 'employee.name');

      // The derived column reads the right typed value through its getter.
      final getter = col.getValueGetterAsFunction();
      expect(getter, isNotNull);
      final value = Function.apply(getter!, [
        ValueGetterParams<Employee>(data: rows[1], rowIndex: 1),
      ]);
      expect(value, 'Grace');

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('sorting through ref.colId reorders the displayed rows', (
      tester,
    ) async {
      const rows = [
        Employee('Ada', 36, 'London'),
        Employee('Grace', 45, 'New York'),
        Employee('Alan', 28, 'London'),
      ];
      final controller = OsGridController<Employee>();

      await tester.pumpWidget(
        _wrap(
          OsGrid<Employee>(
            controller: controller,
            columnDefs: OsColumnDefs.fromType<Employee>(
              overrides: {
                'age': const OsColumnDef<Employee>(sortable: true, width: 90),
              },
            ),
            rowData: rows,
            getRowId: (e) => e.name,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final ageRef = columnRef<Employee>(employeeAge);
      controller.setSortModel([
        OsSortModel(colId: ageRef.colId, sort: OsSortDirection.ascending),
      ]);
      await tester.pumpAndSettle();

      final displayed = _displayRows(tester).map((r) => r['age']).toList();
      expect(displayed, [28, 36, 45]);
      expect(controller.getSortModel().single.colId, ageRef.colId);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('unchecked refs act as colId carriers for grid APIs', (
      tester,
    ) async {
      const rows = [Employee('Ada', 36, 'London')];
      final controller = OsGridController<Employee>();

      await tester.pumpWidget(
        _wrap(
          OsGrid<Employee>(
            controller: controller,
            columnDefs: OsColumnDefs.fromType<Employee>(),
            rowData: rows,
            getRowId: (e) => e.name,
          ),
        ),
      );
      await tester.pumpAndSettle();

      const cityRef = ColumnRef<Employee>.unchecked('employee.city');
      final col = controller.getColumnDef(cityRef.colId);
      expect(col, isNotNull);
      expect(col!.field, 'city');
      expect(col.effectiveColId, cityRef.colId);

      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('Typo prevention contract', () {
    test('anonymous closure throws ArgumentError', () {
      expect(
        () => columnRef<Employee>((e) => e.name),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('unregistered type throws ArgumentError', () {
      Object? projectCode(Object row) => null;
      expect(() => columnRef<Project>(projectCode), throwsArgumentError);
      // Sanity: the same accessor resolves once registered.
      _registry.register<Project>([OsColumnField.text('code', projectCode)]);
      expect(columnRef<Project>(projectCode).colId, 'code');
    });

    test('wrong-entity accessor compiles only when loosely typed, then '
        'throws ArgumentError', () {
      // Statically distinct accessors cannot even be passed across types:
      //   columnRef<Employee>(timesheetHours)
      // is a COMPILE error (Object? Function(Timesheet) is not an
      // Object? Function(Employee)) — the phantom-type protection itself.
      //
      // A loosely typed mirror compiles against any row type, so the
      // registry rejection is what stands between it and a silent mix-up:
      // its identity is registered under Timesheet, never under Employee.
      expect(
        () => columnRef<Employee>(anyHours),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('No registered OsColumnField accessor for Employee'),
          ),
        ),
      );
      // The exact registered accessor still resolves; the mirror's identity
      // was never registered, so it is rejected everywhere.
      expect(columnRef<Timesheet>(timesheetHours).colId, 'hours');
      expect(() => columnRef<Timesheet>(anyHours), throwsArgumentError);
    });

    test('unknown hand-built colIds fail lookups instead of silently '
        'returning the wrong column', () {
      final nameRef = columnRef<Employee>(employeeName);
      // A one-character typo in the colId string must not resolve.
      expect(nameRef.colId.endsWith('nam'), isFalse);
      expect(_registry.hasColId<Employee>(nameRef.colId), isTrue);
      expect(_registry.hasColId<Employee>('employee.nam'), isFalse);
    });
  });

  group('Phantom typing end-to-end', () {
    test('refs of different row types are never interchangeable', () {
      final employeeRef = columnRef<Employee>(employeeName);
      final timesheetRef = columnRef<Timesheet>(timesheetHours);

      expect(employeeRef, isA<ColumnRef<Employee>>());
      expect(employeeRef, isNot(isA<ColumnRef<Timesheet>>()));
      expect(employeeRef.runtimeType.toString(), contains('Employee'));
      expect(employeeRef, isNot(timesheetRef));

      // Same id string, different reified types — still distinct.
      const fake = ColumnRef<Timesheet>.unchecked('employee.name');
      expect(employeeRef.colId, fake.colId);
      expect(employeeRef, isNot(fake));
      expect(employeeRef, isNot(isA<ColumnRef<Timesheet>>()));
    });

    test('equality is colId-based within one row type', () {
      final a = columnRef<Employee>(employeeName);
      final b = columnRef<Employee>(employeeName);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a == columnRef<Employee>(employeeAge), isFalse);
    });
  });
}

/// Third row type for the unregistered-type case.
class Project {
  const Project(this.code);

  final String code;
}
