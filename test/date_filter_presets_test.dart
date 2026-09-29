import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

void main() {
  setUp(() {
    // Clear the cache before each test to ensure fresh calculations
    DateFilterPresets.clearCache();
    // Reset to default first day of week
    DateFilterPresets.firstDayOfWeek = DateTime.monday;
  });

  group('DateFilterPresets — basic range calculations', () {
    test('today returns start of today to start of tomorrow', () {
      final now = DateTime(2024, 6, 15, 14, 30, 0);
      final range = DateFilterPresets.getPresetRange('today', now: now)!;
      expect(range.from, DateTime(2024, 6, 15));
      expect(range.to, DateTime(2024, 6, 16));
    });

    test('yesterday returns start of yesterday to start of today', () {
      final now = DateTime(2024, 6, 15, 14, 30, 0);
      final range = DateFilterPresets.getPresetRange('yesterday', now: now)!;
      expect(range.from, DateTime(2024, 6, 14));
      expect(range.to, DateTime(2024, 6, 15));
    });

    test('tomorrow returns start of tomorrow to start of day after', () {
      final now = DateTime(2024, 6, 15, 14, 30, 0);
      final range = DateFilterPresets.getPresetRange('tomorrow', now: now)!;
      expect(range.from, DateTime(2024, 6, 16));
      expect(range.to, DateTime(2024, 6, 17));
    });

    test('thisWeek returns start of current week to start of next week', () {
      // 2024-06-15 is a Saturday. With Monday as first day, week starts 2024-06-10.
      final now = DateTime(2024, 6, 15, 14, 30, 0);
      final range = DateFilterPresets.getPresetRange('thisWeek', now: now)!;
      expect(range.from, DateTime(2024, 6, 10)); // Monday
      expect(range.to, DateTime(2024, 6, 17)); // Next Monday
    });

    test(
      'lastWeek returns start of previous week to start of current week',
      () {
        final now = DateTime(2024, 6, 15, 14, 30, 0);
        final range = DateFilterPresets.getPresetRange('lastWeek', now: now)!;
        expect(range.from, DateTime(2024, 6, 3)); // Previous Monday
        expect(range.to, DateTime(2024, 6, 10)); // This Monday
      },
    );

    test('nextWeek returns start of next week to start of week after', () {
      final now = DateTime(2024, 6, 15, 14, 30, 0);
      final range = DateFilterPresets.getPresetRange('nextWeek', now: now)!;
      expect(range.from, DateTime(2024, 6, 17)); // Next Monday
      expect(range.to, DateTime(2024, 6, 24)); // Monday after next
    });

    test('thisMonth returns start of current month to start of next month', () {
      final now = DateTime(2024, 6, 15, 14, 30, 0);
      final range = DateFilterPresets.getPresetRange('thisMonth', now: now)!;
      expect(range.from, DateTime(2024, 6, 1));
      expect(range.to, DateTime(2024, 7, 1));
    });

    test(
      'lastMonth returns start of previous month to start of current month',
      () {
        final now = DateTime(2024, 6, 15, 14, 30, 0);
        final range = DateFilterPresets.getPresetRange('lastMonth', now: now)!;
        expect(range.from, DateTime(2024, 5, 1));
        expect(range.to, DateTime(2024, 6, 1));
      },
    );

    test('nextMonth returns start of next month to start of month after', () {
      final now = DateTime(2024, 6, 15, 14, 30, 0);
      final range = DateFilterPresets.getPresetRange('nextMonth', now: now)!;
      expect(range.from, DateTime(2024, 7, 1));
      expect(range.to, DateTime(2024, 8, 1));
    });

    test('thisQuarter returns start of current quarter to start of next', () {
      // June is in Q2 (Apr-Jun)
      final now = DateTime(2024, 6, 15, 14, 30, 0);
      final range = DateFilterPresets.getPresetRange('thisQuarter', now: now)!;
      expect(range.from, DateTime(2024, 4, 1));
      expect(range.to, DateTime(2024, 7, 1));
    });

    test(
      'lastQuarter returns start of previous quarter to start of current',
      () {
        // June is in Q2, so last quarter is Q1 (Jan-Mar)
        final now = DateTime(2024, 6, 15, 14, 30, 0);
        final range = DateFilterPresets.getPresetRange(
          'lastQuarter',
          now: now,
        )!;
        expect(range.from, DateTime(2024, 1, 1));
        expect(range.to, DateTime(2024, 4, 1));
      },
    );

    test(
      'nextQuarter returns start of next quarter to start of quarter after',
      () {
        // June is in Q2, so next quarter is Q3 (Jul-Sep)
        final now = DateTime(2024, 6, 15, 14, 30, 0);
        final range = DateFilterPresets.getPresetRange(
          'nextQuarter',
          now: now,
        )!;
        expect(range.from, DateTime(2024, 7, 1));
        expect(range.to, DateTime(2024, 10, 1));
      },
    );

    test('thisYear returns start of current year to start of next year', () {
      final now = DateTime(2024, 6, 15, 14, 30, 0);
      final range = DateFilterPresets.getPresetRange('thisYear', now: now)!;
      expect(range.from, DateTime(2024, 1, 1));
      expect(range.to, DateTime(2025, 1, 1));
    });

    test(
      'lastYear returns start of previous year to start of current year',
      () {
        final now = DateTime(2024, 6, 15, 14, 30, 0);
        final range = DateFilterPresets.getPresetRange('lastYear', now: now)!;
        expect(range.from, DateTime(2023, 1, 1));
        expect(range.to, DateTime(2024, 1, 1));
      },
    );

    test('nextYear returns start of next year to start of year after', () {
      final now = DateTime(2024, 6, 15, 14, 30, 0);
      final range = DateFilterPresets.getPresetRange('nextYear', now: now)!;
      expect(range.from, DateTime(2025, 1, 1));
      expect(range.to, DateTime(2026, 1, 1));
    });

    test('yearToDate returns start of year to start of tomorrow', () {
      final now = DateTime(2024, 6, 15, 14, 30, 0);
      final range = DateFilterPresets.getPresetRange('yearToDate', now: now)!;
      expect(range.from, DateTime(2024, 1, 1));
      expect(range.to, DateTime(2024, 6, 16));
    });

    test('last7Days returns 7 days ago to start of tomorrow', () {
      final now = DateTime(2024, 6, 15, 14, 30, 0);
      final range = DateFilterPresets.getPresetRange('last7Days', now: now)!;
      expect(range.from, DateTime(2024, 6, 8));
      expect(range.to, DateTime(2024, 6, 16));
    });

    test('last30Days returns 30 days ago to start of tomorrow', () {
      final now = DateTime(2024, 6, 15, 14, 30, 0);
      final range = DateFilterPresets.getPresetRange('last30Days', now: now)!;
      expect(range.from, DateTime(2024, 5, 16));
      expect(range.to, DateTime(2024, 6, 16));
    });

    test('last90Days returns 90 days ago to start of tomorrow', () {
      final now = DateTime(2024, 6, 15, 14, 30, 0);
      final range = DateFilterPresets.getPresetRange('last90Days', now: now)!;
      expect(range.from, DateTime(2024, 3, 17));
      expect(range.to, DateTime(2024, 6, 16));
    });

    test('last6Months returns 6 months ago to start of tomorrow', () {
      final now = DateTime(2024, 6, 15, 14, 30, 0);
      final range = DateFilterPresets.getPresetRange('last6Months', now: now)!;
      expect(range.from, DateTime(2023, 12, 15));
      expect(range.to, DateTime(2024, 6, 16));
    });

    test('last12Months returns 12 months ago to start of tomorrow', () {
      final now = DateTime(2024, 6, 15, 14, 30, 0);
      final range = DateFilterPresets.getPresetRange('last12Months', now: now)!;
      expect(range.from, DateTime(2023, 6, 15));
      expect(range.to, DateTime(2024, 6, 16));
    });

    test('last24Months returns 24 months ago to start of tomorrow', () {
      final now = DateTime(2024, 6, 15, 14, 30, 0);
      final range = DateFilterPresets.getPresetRange('last24Months', now: now)!;
      expect(range.from, DateTime(2022, 6, 15));
      expect(range.to, DateTime(2024, 6, 16));
    });
  });

  group('DateFilterPresets — week start configuration', () {
    test('thisWeek with Sunday as first day', () {
      DateFilterPresets.firstDayOfWeek = DateTime.sunday;
      // 2024-06-15 is a Saturday. With Sunday as first day, week starts 2024-06-09.
      final now = DateTime(2024, 6, 15, 14, 30, 0);
      final range = DateFilterPresets.getPresetRange('thisWeek', now: now)!;
      expect(range.from, DateTime(2024, 6, 9)); // Sunday
      expect(range.to, DateTime(2024, 6, 16)); // Next Sunday
    });

    test('thisWeek when today is the first day of week', () {
      DateFilterPresets.firstDayOfWeek = DateTime.monday;
      // 2024-06-10 is a Monday
      final now = DateTime(2024, 6, 10, 14, 30, 0);
      final range = DateFilterPresets.getPresetRange('thisWeek', now: now)!;
      expect(range.from, DateTime(2024, 6, 10)); // Monday (today)
      expect(range.to, DateTime(2024, 6, 17)); // Next Monday
    });
  });

  group('DateFilterPresets — caching', () {
    test('returns cached result for same day', () {
      final now = DateTime(2024, 6, 15, 10, 0, 0);
      final range1 = DateFilterPresets.getPresetRange('today', now: now);
      final range2 = DateFilterPresets.getPresetRange('today', now: now);
      expect(identical(range1, range2), isTrue);
    });

    test('unknown preset type returns null', () {
      final range = DateFilterPresets.getPresetRange('unknownPreset');
      expect(range, isNull);
    });

    test('isPresetType identifies valid presets', () {
      expect(DateFilterPresets.isPresetType('today'), isTrue);
      expect(DateFilterPresets.isPresetType('yesterday'), isTrue);
      expect(DateFilterPresets.isPresetType('thisWeek'), isTrue);
      expect(DateFilterPresets.isPresetType('last30Days'), isTrue);
      expect(DateFilterPresets.isPresetType('equals'), isFalse);
      expect(DateFilterPresets.isPresetType('inRange'), isFalse);
      expect(DateFilterPresets.isPresetType('unknown'), isFalse);
    });
  });

  group('DateFilterPresets — edge cases', () {
    test('month boundary: last day of month', () {
      final now = DateTime(2024, 1, 31, 14, 30, 0);
      final range = DateFilterPresets.getPresetRange('thisMonth', now: now)!;
      expect(range.from, DateTime(2024, 1, 1));
      expect(range.to, DateTime(2024, 2, 1));
    });

    test('year boundary: December 31', () {
      final now = DateTime(2024, 12, 31, 23, 59, 59);
      final range = DateFilterPresets.getPresetRange('thisYear', now: now)!;
      expect(range.from, DateTime(2024, 1, 1));
      expect(range.to, DateTime(2025, 1, 1));
    });

    test('leap year: February 29', () {
      final now = DateTime(2024, 2, 29, 12, 0, 0);
      final range = DateFilterPresets.getPresetRange('today', now: now)!;
      expect(range.from, DateTime(2024, 2, 29));
      expect(range.to, DateTime(2024, 3, 1));
    });

    test('Q1 quarter calculation (January)', () {
      final now = DateTime(2024, 1, 15);
      final range = DateFilterPresets.getPresetRange('thisQuarter', now: now)!;
      expect(range.from, DateTime(2024, 1, 1));
      expect(range.to, DateTime(2024, 4, 1));
    });

    test('Q3 quarter calculation (September)', () {
      final now = DateTime(2024, 9, 15);
      final range = DateFilterPresets.getPresetRange('thisQuarter', now: now)!;
      expect(range.from, DateTime(2024, 7, 1));
      expect(range.to, DateTime(2024, 10, 1));
    });

    test('Q4 quarter calculation (December)', () {
      final now = DateTime(2024, 12, 15);
      final range = DateFilterPresets.getPresetRange('thisQuarter', now: now)!;
      expect(range.from, DateTime(2024, 10, 1));
      expect(range.to, DateTime(2025, 1, 1));
    });
  });

  group('FilterEvaluator — preset date range evaluation', () {
    const dateFilter = OsDateFilter();

    test('today preset matches dates from today', () {
      // We need to use a fixed "now" for testing. Since the evaluator uses
      // DateFilterPresets internally which uses DateTime.now(), we test
      // with dates that are definitely today.
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);

      const model = OsColumnFilterModel(
        filterType: 'date',
        conditions: [OsFilterCondition(type: 'today')],
      );

      expect(
        FilterEvaluator.evaluate(
          cellValue: todayStart,
          model: model,
          filterConfig: dateFilter,
        ),
        isTrue,
      );

      // Yesterday should not match
      final yesterday = todayStart.subtract(const Duration(days: 1));
      expect(
        FilterEvaluator.evaluate(
          cellValue: yesterday,
          model: model,
          filterConfig: dateFilter,
        ),
        isFalse,
      );

      // Tomorrow should not match
      final tomorrow = todayStart.add(const Duration(days: 1));
      expect(
        FilterEvaluator.evaluate(
          cellValue: tomorrow,
          model: model,
          filterConfig: dateFilter,
        ),
        isFalse,
      );
    });

    test('yesterday preset matches dates from yesterday', () {
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);
      final yesterday = todayStart.subtract(const Duration(days: 1));

      const model = OsColumnFilterModel(
        filterType: 'date',
        conditions: [OsFilterCondition(type: 'yesterday')],
      );

      expect(
        FilterEvaluator.evaluate(
          cellValue: yesterday,
          model: model,
          filterConfig: dateFilter,
        ),
        isTrue,
      );

      expect(
        FilterEvaluator.evaluate(
          cellValue: todayStart,
          model: model,
          filterConfig: dateFilter,
        ),
        isFalse,
      );
    });

    test('thisYear preset matches dates in current year', () {
      final today = DateTime.now();
      final startOfYear = DateTime(today.year, 1, 1);
      final midYear = DateTime(today.year, 6, 15);

      const model = OsColumnFilterModel(
        filterType: 'date',
        conditions: [OsFilterCondition(type: 'thisYear')],
      );

      expect(
        FilterEvaluator.evaluate(
          cellValue: startOfYear,
          model: model,
          filterConfig: dateFilter,
        ),
        isTrue,
      );

      expect(
        FilterEvaluator.evaluate(
          cellValue: midYear,
          model: model,
          filterConfig: dateFilter,
        ),
        isTrue,
      );

      // Last year should not match
      final lastYear = DateTime(today.year - 1, 6, 15);
      expect(
        FilterEvaluator.evaluate(
          cellValue: lastYear,
          model: model,
          filterConfig: dateFilter,
        ),
        isFalse,
      );
    });

    test('preset with null cell value respects includeBlanksInRange', () {
      const model = OsColumnFilterModel(
        filterType: 'date',
        conditions: [OsFilterCondition(type: 'today')],
      );

      // Default: null fails
      expect(
        FilterEvaluator.evaluate(
          cellValue: null,
          model: model,
          filterConfig: dateFilter,
        ),
        isFalse,
      );

      // With includeBlanksInRange: null passes
      const filterWithBlanks = OsDateFilter(includeBlanksInRange: true);
      expect(
        FilterEvaluator.evaluate(
          cellValue: null,
          model: model,
          filterConfig: filterWithBlanks,
        ),
        isTrue,
      );
    });

    test('unknown preset type passes all values', () {
      const model = OsColumnFilterModel(
        filterType: 'date',
        conditions: [OsFilterCondition(type: 'unknownPreset')],
      );

      // Unknown type falls through to default (passes)
      expect(
        FilterEvaluator.evaluate(
          cellValue: DateTime(2024, 3, 15),
          model: model,
          filterConfig: dateFilter,
        ),
        isTrue,
      );
    });
  });

  group('FilterEvaluator — includeTime option', () {
    test('includeTime: false (default) ignores time in comparison', () {
      const dateFilter = OsDateFilter();
      const model = OsColumnFilterModel(
        filterType: 'date',
        conditions: [OsFilterCondition(type: 'equals', filter: '2024-03-15')],
      );

      // Different times on same day should match
      expect(
        FilterEvaluator.evaluate(
          cellValue: DateTime(2024, 3, 15, 0, 0, 0),
          model: model,
          filterConfig: dateFilter,
        ),
        isTrue,
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: DateTime(2024, 3, 15, 23, 59, 59),
          model: model,
          filterConfig: dateFilter,
        ),
        isTrue,
      );
    });

    test('includeTime: true compares full date-time', () {
      const dateFilter = OsDateFilter(includeTime: true);
      const model = OsColumnFilterModel(
        filterType: 'date',
        conditions: [
          OsFilterCondition(type: 'equals', filter: '2024-03-15T10:30:00'),
        ],
      );

      // Exact match
      expect(
        FilterEvaluator.evaluate(
          cellValue: DateTime(2024, 3, 15, 10, 30, 0),
          model: model,
          filterConfig: dateFilter,
        ),
        isTrue,
      );

      // Different time should NOT match
      expect(
        FilterEvaluator.evaluate(
          cellValue: DateTime(2024, 3, 15, 10, 30, 1),
          model: model,
          filterConfig: dateFilter,
        ),
        isFalse,
      );
    });

    test('includeTime: true with greaterThan compares full date-time', () {
      const dateFilter = OsDateFilter(includeTime: true);
      const model = OsColumnFilterModel(
        filterType: 'date',
        conditions: [
          OsFilterCondition(type: 'greaterThan', filter: '2024-03-15T10:30:00'),
        ],
      );

      // Later time on same day should pass
      expect(
        FilterEvaluator.evaluate(
          cellValue: DateTime(2024, 3, 15, 10, 30, 1),
          model: model,
          filterConfig: dateFilter,
        ),
        isTrue,
      );

      // Earlier time on same day should fail
      expect(
        FilterEvaluator.evaluate(
          cellValue: DateTime(2024, 3, 15, 10, 29, 59),
          model: model,
          filterConfig: dateFilter,
        ),
        isFalse,
      );
    });

    test('includeTime: true with inRange compares full date-time', () {
      const dateFilter = OsDateFilter(includeTime: true);
      const model = OsColumnFilterModel(
        filterType: 'date',
        conditions: [
          OsFilterCondition(
            type: 'inRange',
            filter: '2024-03-15T08:00:00',
            filterTo: '2024-03-15T17:00:00',
          ),
        ],
      );

      // Within range (exclusive boundaries by default)
      expect(
        FilterEvaluator.evaluate(
          cellValue: DateTime(2024, 3, 15, 12, 0, 0),
          model: model,
          filterConfig: dateFilter,
        ),
        isTrue,
      );

      // At boundary (exclusive)
      expect(
        FilterEvaluator.evaluate(
          cellValue: DateTime(2024, 3, 15, 8, 0, 0),
          model: model,
          filterConfig: dateFilter,
        ),
        isFalse,
      );

      // Outside range
      expect(
        FilterEvaluator.evaluate(
          cellValue: DateTime(2024, 3, 15, 18, 0, 0),
          model: model,
          filterConfig: dateFilter,
        ),
        isFalse,
      );
    });
  });

  group('FilterEvaluator — preset combined with standard conditions', () {
    test('preset AND standard condition', () {
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);

      // This tests that presets work in combined conditions
      const model = OsColumnFilterModel(
        filterType: 'date',
        operator: OsJoinOperator.and,
        conditions: [
          OsFilterCondition(type: 'thisYear'),
          OsFilterCondition(type: 'greaterThan', filter: '2020-01-01'),
        ],
      );

      // Today is in this year and after 2020-01-01
      expect(
        FilterEvaluator.evaluate(
          cellValue: todayStart,
          model: model,
          filterConfig: const OsDateFilter(),
        ),
        isTrue,
      );

      // A date from 2019 is after 2020-01-01? No. And not in this year.
      expect(
        FilterEvaluator.evaluate(
          cellValue: DateTime(2019, 6, 15),
          model: model,
          filterConfig: const OsDateFilter(),
        ),
        isFalse,
      );
    });
  });
}
