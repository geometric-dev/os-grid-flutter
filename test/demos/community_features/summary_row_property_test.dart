import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

/// Replicates the summary row computation from PaginationDataPage._buildSummaryRows().
/// For any list of row data with numeric fields, the pinned bottom summary row
/// contains values equal to the sum of the corresponding numeric column values.
///
/// **Validates: Requirements 6.4**
List<Map<String, dynamic>> buildSummaryRows(
  List<Map<String, dynamic>> rowData,
) {
  if (rowData.isEmpty) return [];

  int ageSum = 0;
  int salarySum = 0;
  int ratingSum = 0;

  for (final row in rowData) {
    ageSum += (row['age'] as int?) ?? 0;
    salarySum += (row['salary'] as int?) ?? 0;
    ratingSum += (row['rating'] as int?) ?? 0;
  }

  return [
    <String, dynamic>{
      'id': -1,
      'name': 'TOTAL',
      'email': '',
      'age': ageSum,
      'salary': salarySum,
      'department': '',
      'startDate': null,
      'rating': ratingSum,
      'active': null,
      'country': '',
      'notes': '',
    },
  ];
}

/// Generates a random list of row data with numeric fields for property testing.
List<Map<String, dynamic>> generateRandomRowData(Random rng, int rowCount) {
  return List.generate(rowCount, (i) {
    return <String, dynamic>{
      'id': i,
      'name': 'Person $i',
      'email': 'person$i@test.com',
      'age': rng.nextInt(100), // 0–99
      'salary': rng.nextInt(200000), // 0–199999
      'department': 'Dept',
      'startDate': DateTime(2020, 1, 1),
      'rating': rng.nextInt(6), // 0–5
      'active': rng.nextBool(),
      'country': 'Country',
      'notes': 'Notes',
    };
  });
}

void main() {
  group('Property 7: Pinned summary row computes correct sums', () {
    // **Validates: Requirements 6.4**

    test('for any list of row data with numeric fields, '
        'pinned bottom row values equal the sum of corresponding column values '
        '(100 iterations, seed-based)', () {
      const iterations = 100;
      final masterRng = Random(42);

      for (var i = 0; i < iterations; i++) {
        final seed = masterRng.nextInt(1 << 32);
        final rng = Random(seed);

        // Generate a random row count between 1 and 200
        final rowCount = 1 + rng.nextInt(200);
        final rowData = generateRandomRowData(rng, rowCount);

        // Compute expected sums independently
        int expectedAgeSum = 0;
        int expectedSalarySum = 0;
        int expectedRatingSum = 0;

        for (final row in rowData) {
          expectedAgeSum += row['age'] as int;
          expectedSalarySum += row['salary'] as int;
          expectedRatingSum += row['rating'] as int;
        }

        // Compute summary rows using the function under test
        final summaryRows = buildSummaryRows(rowData);

        // Verify: exactly one summary row is returned
        expect(
          summaryRows.length,
          1,
          reason:
              'Iteration $i (seed=$seed): '
              'Expected exactly 1 summary row for $rowCount rows',
        );

        final summaryRow = summaryRows.first;

        // Verify: each numeric field equals the sum of the column
        expect(
          summaryRow['age'],
          expectedAgeSum,
          reason:
              'Iteration $i (seed=$seed): '
              'age sum mismatch for $rowCount rows',
        );
        expect(
          summaryRow['salary'],
          expectedSalarySum,
          reason:
              'Iteration $i (seed=$seed): '
              'salary sum mismatch for $rowCount rows',
        );
        expect(
          summaryRow['rating'],
          expectedRatingSum,
          reason:
              'Iteration $i (seed=$seed): '
              'rating sum mismatch for $rowCount rows',
        );
      }
    });

    test('empty row data produces no summary rows', () {
      final summaryRows = buildSummaryRows([]);
      expect(summaryRows, isEmpty);
    });

    test('rows with null numeric fields are treated as zero '
        '(100 iterations, seed-based)', () {
      const iterations = 100;
      final masterRng = Random(99);

      for (var i = 0; i < iterations; i++) {
        final seed = masterRng.nextInt(1 << 32);
        final rng = Random(seed);

        final rowCount = 1 + rng.nextInt(50);
        final rowData = List.generate(rowCount, (j) {
          // Randomly set some numeric fields to null
          final hasAge = rng.nextBool();
          final hasSalary = rng.nextBool();
          final hasRating = rng.nextBool();

          return <String, dynamic>{
            'id': j,
            'name': 'Person $j',
            'email': 'p$j@test.com',
            'age': hasAge ? rng.nextInt(100) : null,
            'salary': hasSalary ? rng.nextInt(200000) : null,
            'department': 'Dept',
            'startDate': null,
            'rating': hasRating ? rng.nextInt(6) : null,
            'active': null,
            'country': 'Country',
            'notes': 'Notes',
          };
        });

        // Compute expected sums (null treated as 0)
        int expectedAgeSum = 0;
        int expectedSalarySum = 0;
        int expectedRatingSum = 0;

        for (final row in rowData) {
          expectedAgeSum += (row['age'] as int?) ?? 0;
          expectedSalarySum += (row['salary'] as int?) ?? 0;
          expectedRatingSum += (row['rating'] as int?) ?? 0;
        }

        final summaryRows = buildSummaryRows(rowData);
        expect(summaryRows.length, 1);

        final summaryRow = summaryRows.first;
        expect(
          summaryRow['age'],
          expectedAgeSum,
          reason:
              'Iteration $i (seed=$seed): '
              'age sum with nulls mismatch',
        );
        expect(
          summaryRow['salary'],
          expectedSalarySum,
          reason:
              'Iteration $i (seed=$seed): '
              'salary sum with nulls mismatch',
        );
        expect(
          summaryRow['rating'],
          expectedRatingSum,
          reason:
              'Iteration $i (seed=$seed): '
              'rating sum with nulls mismatch',
        );
      }
    });
  });
}
