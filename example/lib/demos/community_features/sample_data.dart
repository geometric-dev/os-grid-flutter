/// Shared sample data generators for the Community Features Demo.
///
/// Provides reproducible, seed-based data generation used across all demo pages.
library;

import 'dart:math';

/// Generates sample data with text, number, date, and boolean columns.
///
/// Returns a list of [rowCount] rows, each a `Map<String, dynamic>` with fields:
/// id, name, email, age, salary, department, startDate, rating, active, country,
/// notes.
///
/// Uses [seed]-based random generation for reproducibility — the same seed and
/// row count always produces identical data.
List<Map<String, dynamic>> generateSampleData({
  int rowCount = 100,
  int seed = 42,
}) {
  final rng = Random(seed);
  return List.generate(rowCount, (index) {
    final firstName = _firstNames[rng.nextInt(_firstNames.length)];
    final lastName = _lastNames[rng.nextInt(_lastNames.length)];
    final name = '$firstName $lastName';
    final email =
        '${firstName.toLowerCase()}.${lastName.toLowerCase()}@example.com';
    final age = 18 + rng.nextInt(48); // 18–65
    final salary = 30000 + rng.nextInt(120001); // 30000–150000
    final department = _departments[rng.nextInt(_departments.length)];
    final startDate = DateTime(
      2015 + rng.nextInt(10), // 2015–2024
      1 + rng.nextInt(12),
      1 + rng.nextInt(28),
    );
    final rating = rng.nextInt(6); // 0–5
    final active = rng.nextBool();
    final country = _countries[rng.nextInt(_countries.length)];
    final notes = _generateNotes(rng);

    return {
      'id': index,
      'name': name,
      'email': email,
      'age': age,
      'salary': salary,
      'department': department,
      'startDate': startDate,
      'rating': rating,
      'active': active,
      'country': country,
      'notes': notes,
    };
  });
}

// ---------------------------------------------------------------------------
// Private data pools
// ---------------------------------------------------------------------------

const _firstNames = [
  'Alice',
  'Bob',
  'Charlie',
  'Diana',
  'Edward',
  'Fiona',
  'George',
  'Hannah',
  'Ivan',
  'Julia',
  'Kevin',
  'Laura',
  'Michael',
  'Nina',
  'Oscar',
  'Patricia',
  'Quentin',
  'Rachel',
  'Samuel',
  'Tina',
];

const _lastNames = [
  'Anderson',
  'Brown',
  'Clark',
  'Davis',
  'Evans',
  'Foster',
  'Garcia',
  'Harris',
  'Irwin',
  'Johnson',
  'King',
  'Lee',
  'Martinez',
  'Nelson',
  'Owen',
  'Patel',
  'Quinn',
  'Roberts',
  'Smith',
  'Taylor',
];

const _departments = ['Engineering', 'Sales', 'Marketing', 'HR', 'Finance'];

const _countries = [
  'United States',
  'United Kingdom',
  'Germany',
  'France',
  'Canada',
  'Australia',
  'Japan',
  'Brazil',
  'India',
  'Spain',
];

const _noteFragments = [
  'Excellent team player.',
  'Consistently meets deadlines.',
  'Strong technical skills.',
  'Great communication abilities.',
  'Needs improvement in time management.',
  'Shows leadership potential.',
  'Reliable and dependable.',
  'Creative problem solver.',
  'Works well under pressure.',
  'Actively mentors junior staff.',
];

String _generateNotes(Random rng) {
  final lineCount = 1 + rng.nextInt(3); // 1–3 lines
  final lines = List.generate(
    lineCount,
    (_) => _noteFragments[rng.nextInt(_noteFragments.length)],
  );
  return lines.join('\n');
}
