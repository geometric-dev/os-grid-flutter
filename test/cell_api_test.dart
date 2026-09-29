import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

void main() {
  group('CellApiModule - getCellValue', () {
    test('returns value for field-based column', () {
      final controller = OsGridController<Map<String, dynamic>>();
      controller.columnDefs = [
        const OsColumnDef<Map<String, dynamic>>(field: 'name'),
        const OsColumnDef<Map<String, dynamic>>(field: 'age'),
      ];
      controller.setRowData([
        {'name': 'Alice', 'age': 30},
        {'name': 'Bob', 'age': 25},
        {'name': 'Charlie', 'age': 35},
      ]);
      // processedData is set by the widget; simulate it here.
      controller.processedData = [
        {'name': 'Alice', 'age': 30},
        {'name': 'Bob', 'age': 25},
        {'name': 'Charlie', 'age': 35},
      ];

      expect(controller.getCellValue(rowIndex: 0, colId: 'name'), 'Alice');
      expect(controller.getCellValue(rowIndex: 1, colId: 'age'), 25);
      expect(controller.getCellValue(rowIndex: 2, colId: 'name'), 'Charlie');
    });

    test('returns value for valueGetter-based column', () {
      final controller = OsGridController<Map<String, dynamic>>();
      controller.columnDefs = [
        const OsColumnDef<Map<String, dynamic>>(field: 'first', colId: 'first'),
        OsColumnDef<Map<String, dynamic>>(
          colId: 'fullName',
          valueGetter: (params) =>
              '${params.data['first']} ${params.data['last']}',
        ),
      ];
      final data = [
        {'first': 'Alice', 'last': 'Smith'},
        {'first': 'Bob', 'last': 'Jones'},
      ];
      controller.setRowData(data);
      controller.processedData = data;

      expect(
        controller.getCellValue(rowIndex: 0, colId: 'fullName'),
        'Alice Smith',
      );
      expect(
        controller.getCellValue(rowIndex: 1, colId: 'fullName'),
        'Bob Jones',
      );
    });

    test('returns null for out-of-bounds row index', () {
      final controller = OsGridController<Map<String, dynamic>>();
      controller.columnDefs = [
        const OsColumnDef<Map<String, dynamic>>(field: 'name'),
      ];
      controller.setRowData([
        {'name': 'Alice'},
      ]);
      controller.processedData = [
        {'name': 'Alice'},
      ];

      expect(controller.getCellValue(rowIndex: -1, colId: 'name'), isNull);
      expect(controller.getCellValue(rowIndex: 5, colId: 'name'), isNull);
    });

    test('returns null for unknown column ID', () {
      final controller = OsGridController<Map<String, dynamic>>();
      controller.columnDefs = [
        const OsColumnDef<Map<String, dynamic>>(field: 'name'),
      ];
      controller.setRowData([
        {'name': 'Alice'},
      ]);
      controller.processedData = [
        {'name': 'Alice'},
      ];

      expect(
        controller.getCellValue(rowIndex: 0, colId: 'nonexistent'),
        isNull,
      );
    });

    test('resolves column by field when colId not set', () {
      final controller = OsGridController<Map<String, dynamic>>();
      controller.columnDefs = [
        const OsColumnDef<Map<String, dynamic>>(field: 'price'),
      ];
      final data = [
        {'price': 9.99},
      ];
      controller.setRowData(data);
      controller.processedData = data;

      // effectiveColId falls back to field, so 'price' should work.
      expect(controller.getCellValue(rowIndex: 0, colId: 'price'), 9.99);
    });

    test('uses processed data (filtered/sorted order)', () {
      final controller = OsGridController<Map<String, dynamic>>();
      controller.columnDefs = [
        const OsColumnDef<Map<String, dynamic>>(field: 'name'),
      ];
      // Raw data in original order
      controller.setRowData([
        {'name': 'Charlie'},
        {'name': 'Alice'},
        {'name': 'Bob'},
      ]);
      // Processed data is sorted
      controller.processedData = [
        {'name': 'Alice'},
        {'name': 'Bob'},
        {'name': 'Charlie'},
      ];

      expect(controller.getCellValue(rowIndex: 0, colId: 'name'), 'Alice');
      expect(controller.getCellValue(rowIndex: 2, colId: 'name'), 'Charlie');
    });

    test('falls back to raw data when processedData is empty', () {
      final controller = OsGridController<Map<String, dynamic>>();
      controller.columnDefs = [
        const OsColumnDef<Map<String, dynamic>>(field: 'name'),
      ];
      controller.setRowData([
        {'name': 'Alice'},
        {'name': 'Bob'},
      ]);
      // processedData not set (empty list)

      expect(controller.getCellValue(rowIndex: 0, colId: 'name'), 'Alice');
      expect(controller.getCellValue(rowIndex: 1, colId: 'name'), 'Bob');
    });

    test('returns null when columnDefs is null', () {
      final controller = OsGridController<Map<String, dynamic>>();
      controller.setRowData([
        {'name': 'Alice'},
      ]);
      controller.processedData = [
        {'name': 'Alice'},
      ];

      expect(controller.getCellValue(rowIndex: 0, colId: 'name'), isNull);
    });

    test('valueGetter receives correct rowIndex', () {
      int? receivedIndex;
      final controller = OsGridController<Map<String, dynamic>>();
      controller.columnDefs = [
        OsColumnDef<Map<String, dynamic>>(
          colId: 'indexed',
          valueGetter: (params) {
            receivedIndex = params.rowIndex;
            return params.rowIndex * 10;
          },
        ),
      ];
      final data = [
        {'x': 1},
        {'x': 2},
        {'x': 3},
      ];
      controller.setRowData(data);
      controller.processedData = data;

      final value = controller.getCellValue(rowIndex: 2, colId: 'indexed');
      expect(value, 20);
      expect(receivedIndex, 2);
    });
  });

  group('CellApiModule - getValue', () {
    test('returns value for field-based column', () {
      final controller = OsGridController<Map<String, dynamic>>();
      controller.columnDefs = [
        const OsColumnDef<Map<String, dynamic>>(field: 'name'),
        const OsColumnDef<Map<String, dynamic>>(field: 'age'),
      ];

      final row = {'name': 'Alice', 'age': 30};
      expect(controller.getValue(row, 'name'), 'Alice');
      expect(controller.getValue(row, 'age'), 30);
    });

    test('returns value for valueGetter-based column', () {
      final controller = OsGridController<Map<String, dynamic>>();
      controller.columnDefs = [
        OsColumnDef<Map<String, dynamic>>(
          colId: 'fullName',
          valueGetter: (params) =>
              '${params.data['first']} ${params.data['last']}',
        ),
      ];

      final row = {'first': 'Alice', 'last': 'Smith'};
      expect(controller.getValue(row, 'fullName'), 'Alice Smith');
    });

    test('returns null for unknown column ID', () {
      final controller = OsGridController<Map<String, dynamic>>();
      controller.columnDefs = [
        const OsColumnDef<Map<String, dynamic>>(field: 'name'),
      ];

      expect(controller.getValue({'name': 'Alice'}, 'nonexistent'), isNull);
    });

    test('returns null when columnDefs is null', () {
      final controller = OsGridController<Map<String, dynamic>>();
      expect(controller.getValue({'name': 'Alice'}, 'name'), isNull);
    });

    test('works with typed data and valueGetter', () {
      final controller = OsGridController<_Person>();
      controller.columnDefs = [
        OsColumnDef<_Person>(
          colId: 'name',
          valueGetter: (params) => params.data.name,
        ),
        OsColumnDef<_Person>(
          colId: 'age',
          valueGetter: (params) => params.data.age,
        ),
      ];

      final person = _Person('Alice', 30);
      expect(controller.getValue(person, 'name'), 'Alice');
      expect(controller.getValue(person, 'age'), 30);
    });
  });
}

class _Person {
  _Person(this.name, this.age);
  final String name;
  final int age;
}
