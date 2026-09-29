import 'package:flutter_test/flutter_test.dart';

// Import the sample data generator using a relative path from test/.
// ignore: avoid_relative_lib_imports
import '../../../example/lib/demos/community_features/sample_data.dart';

void main() {
  group('generateSampleData', () {
    group('structure and field types', () {
      late List<Map<String, dynamic>> data;

      setUp(() {
        data = generateSampleData(rowCount: 20);
      });

      test('returns the requested number of rows', () {
        expect(data.length, 20);
      });

      test('each row contains all expected fields', () {
        const expectedFields = [
          'id',
          'name',
          'email',
          'age',
          'salary',
          'department',
          'startDate',
          'rating',
          'active',
          'country',
          'notes',
        ];

        for (final row in data) {
          for (final field in expectedFields) {
            expect(
              row.containsKey(field),
              isTrue,
              reason: 'Row missing field: $field',
            );
          }
        }
      });

      test('id field is an int matching the row index', () {
        for (var i = 0; i < data.length; i++) {
          expect(data[i]['id'], isA<int>());
          expect(data[i]['id'], i);
        }
      });

      test('name field is a non-empty String', () {
        for (final row in data) {
          expect(row['name'], isA<String>());
          expect((row['name'] as String).isNotEmpty, isTrue);
        }
      });

      test('email field is a String containing @', () {
        for (final row in data) {
          expect(row['email'], isA<String>());
          expect((row['email'] as String).contains('@'), isTrue);
        }
      });

      test('age field is an int in range 18–65', () {
        for (final row in data) {
          expect(row['age'], isA<int>());
          final age = row['age'] as int;
          expect(age, greaterThanOrEqualTo(18));
          expect(age, lessThanOrEqualTo(65));
        }
      });

      test('salary field is an int in range 30000–150000', () {
        for (final row in data) {
          expect(row['salary'], isA<int>());
          final salary = row['salary'] as int;
          expect(salary, greaterThanOrEqualTo(30000));
          expect(salary, lessThanOrEqualTo(150000));
        }
      });

      test('department field is one of the valid departments', () {
        const validDepartments = [
          'Engineering',
          'Sales',
          'Marketing',
          'HR',
          'Finance',
        ];
        for (final row in data) {
          expect(row['department'], isA<String>());
          expect(validDepartments, contains(row['department']));
        }
      });

      test('startDate field is a DateTime in range 2015–2024', () {
        for (final row in data) {
          expect(row['startDate'], isA<DateTime>());
          final date = row['startDate'] as DateTime;
          expect(date.year, greaterThanOrEqualTo(2015));
          expect(date.year, lessThanOrEqualTo(2024));
        }
      });

      test('rating field is an int in range 0–5', () {
        for (final row in data) {
          expect(row['rating'], isA<int>());
          final rating = row['rating'] as int;
          expect(rating, greaterThanOrEqualTo(0));
          expect(rating, lessThanOrEqualTo(5));
        }
      });

      test('active field is a bool', () {
        for (final row in data) {
          expect(row['active'], isA<bool>());
        }
      });

      test('country field is a non-empty String', () {
        for (final row in data) {
          expect(row['country'], isA<String>());
          expect((row['country'] as String).isNotEmpty, isTrue);
        }
      });

      test('notes field is a non-empty String', () {
        for (final row in data) {
          expect(row['notes'], isA<String>());
          expect((row['notes'] as String).isNotEmpty, isTrue);
        }
      });
    });

    group('row count parameter', () {
      test('defaults to 100 rows when no rowCount specified', () {
        final data = generateSampleData();
        expect(data.length, 100);
      });

      test('generates 0 rows when rowCount is 0', () {
        final data = generateSampleData(rowCount: 0);
        expect(data.length, 0);
      });

      test('generates 1 row when rowCount is 1', () {
        final data = generateSampleData(rowCount: 1);
        expect(data.length, 1);
      });

      test('generates large datasets correctly', () {
        final data = generateSampleData(rowCount: 500);
        expect(data.length, 500);
      });
    });

    group('seed-based reproducibility', () {
      test('same seed produces identical data', () {
        final data1 = generateSampleData(rowCount: 50, seed: 123);
        final data2 = generateSampleData(rowCount: 50, seed: 123);

        for (var i = 0; i < data1.length; i++) {
          expect(data1[i]['id'], data2[i]['id']);
          expect(data1[i]['name'], data2[i]['name']);
          expect(data1[i]['email'], data2[i]['email']);
          expect(data1[i]['age'], data2[i]['age']);
          expect(data1[i]['salary'], data2[i]['salary']);
          expect(data1[i]['department'], data2[i]['department']);
          expect(data1[i]['startDate'], data2[i]['startDate']);
          expect(data1[i]['rating'], data2[i]['rating']);
          expect(data1[i]['active'], data2[i]['active']);
          expect(data1[i]['country'], data2[i]['country']);
          expect(data1[i]['notes'], data2[i]['notes']);
        }
      });

      test('different seeds produce different data', () {
        final data1 = generateSampleData(rowCount: 20, seed: 1);
        final data2 = generateSampleData(rowCount: 20, seed: 2);

        // With different seeds, at least some rows should differ
        var hasDifference = false;
        for (var i = 0; i < data1.length; i++) {
          if (data1[i]['name'] != data2[i]['name'] ||
              data1[i]['age'] != data2[i]['age'] ||
              data1[i]['salary'] != data2[i]['salary']) {
            hasDifference = true;
            break;
          }
        }
        expect(
          hasDifference,
          isTrue,
          reason: 'Different seeds should produce different data',
        );
      });

      test('default seed is 42', () {
        final dataDefault = generateSampleData(rowCount: 10);
        final dataExplicit = generateSampleData(rowCount: 10, seed: 42);

        for (var i = 0; i < dataDefault.length; i++) {
          expect(dataDefault[i]['name'], dataExplicit[i]['name']);
          expect(dataDefault[i]['age'], dataExplicit[i]['age']);
          expect(dataDefault[i]['salary'], dataExplicit[i]['salary']);
        }
      });
    });
  });
}
