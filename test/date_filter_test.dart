import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

void main() {
  group('OsDateFilter configuration', () {
    test('default values', () {
      const filter = OsDateFilter();
      expect(filter.defaultOption, OsDateFilterOption.equals);
      expect(filter.maxNumConditions, 2);
      expect(filter.defaultJoinOperator, OsJoinOperator.and);
      expect(filter.inRangeInclusive, isFalse);
      expect(filter.includeBlanksInEquals, isFalse);
      expect(filter.includeBlanksInNotEqual, isFalse);
      expect(filter.includeBlanksInLessThan, isFalse);
      expect(filter.includeBlanksInGreaterThan, isFalse);
      expect(filter.includeBlanksInRange, isFalse);
      expect(filter.comparator, isNull);
      expect(filter.minValidDate, isNull);
      expect(filter.maxValidDate, isNull);
      expect(filter.minValidYear, 1000);
      expect(filter.maxValidYear, isNull);
      expect(filter.debounceMs, isNull);
    });

    test('custom configuration', () {
      final filter = OsDateFilter(
        filterOptions: [OsDateFilterOption.equals, OsDateFilterOption.lessThan],
        defaultOption: OsDateFilterOption.lessThan,
        maxNumConditions: 3,
        defaultJoinOperator: OsJoinOperator.or,
        inRangeInclusive: true,
        includeBlanksInEquals: true,
        minValidDate: DateTime(2020, 1, 1),
        maxValidDate: DateTime(2030, 12, 31),
      );
      expect(filter.filterOptions!.length, 2);
      expect(filter.defaultOption, OsDateFilterOption.lessThan);
      expect(filter.maxNumConditions, 3);
      expect(filter.defaultJoinOperator, OsJoinOperator.or);
      expect(filter.inRangeInclusive, isTrue);
      expect(filter.includeBlanksInEquals, isTrue);
    });
  });

  group('FilterEvaluator — date filter basics', () {
    const dateFilter = OsDateFilter();

    test('equals matches same date (DateTime cell value)', () {
      const model = OsColumnFilterModel(
        filterType: 'date',
        conditions: [OsFilterCondition(type: 'equals', filter: '2024-03-15')],
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: DateTime(2024, 3, 15),
          model: model,
          filterConfig: dateFilter,
        ),
        isTrue,
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: DateTime(2024, 3, 16),
          model: model,
          filterConfig: dateFilter,
        ),
        isFalse,
      );
    });

    test('equals matches same date (String cell value)', () {
      const model = OsColumnFilterModel(
        filterType: 'date',
        conditions: [OsFilterCondition(type: 'equals', filter: '2024-03-15')],
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: '2024-03-15',
          model: model,
          filterConfig: dateFilter,
        ),
        isTrue,
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: '2024-03-16',
          model: model,
          filterConfig: dateFilter,
        ),
        isFalse,
      );
    });

    test('equals ignores time component by default', () {
      const model = OsColumnFilterModel(
        filterType: 'date',
        conditions: [OsFilterCondition(type: 'equals', filter: '2024-03-15')],
      );
      // Same date with different times should still match
      expect(
        FilterEvaluator.evaluate(
          cellValue: DateTime(2024, 3, 15, 14, 30, 0),
          model: model,
          filterConfig: dateFilter,
        ),
        isTrue,
      );
    });

    test('notEqual excludes matching date', () {
      const model = OsColumnFilterModel(
        filterType: 'date',
        conditions: [OsFilterCondition(type: 'notEqual', filter: '2024-03-15')],
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: DateTime(2024, 3, 15),
          model: model,
          filterConfig: dateFilter,
        ),
        isFalse,
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: DateTime(2024, 3, 16),
          model: model,
          filterConfig: dateFilter,
        ),
        isTrue,
      );
    });

    test('lessThan (Before) filters dates before filter value', () {
      const model = OsColumnFilterModel(
        filterType: 'date',
        conditions: [OsFilterCondition(type: 'lessThan', filter: '2024-03-15')],
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: DateTime(2024, 3, 14),
          model: model,
          filterConfig: dateFilter,
        ),
        isTrue,
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: DateTime(2024, 3, 15),
          model: model,
          filterConfig: dateFilter,
        ),
        isFalse,
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: DateTime(2024, 3, 16),
          model: model,
          filterConfig: dateFilter,
        ),
        isFalse,
      );
    });

    test('lessThanOrEqual includes boundary date', () {
      const model = OsColumnFilterModel(
        filterType: 'date',
        conditions: [
          OsFilterCondition(type: 'lessThanOrEqual', filter: '2024-03-15'),
        ],
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: DateTime(2024, 3, 15),
          model: model,
          filterConfig: dateFilter,
        ),
        isTrue,
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: DateTime(2024, 3, 14),
          model: model,
          filterConfig: dateFilter,
        ),
        isTrue,
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: DateTime(2024, 3, 16),
          model: model,
          filterConfig: dateFilter,
        ),
        isFalse,
      );
    });

    test('greaterThan (After) filters dates after filter value', () {
      const model = OsColumnFilterModel(
        filterType: 'date',
        conditions: [
          OsFilterCondition(type: 'greaterThan', filter: '2024-03-15'),
        ],
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: DateTime(2024, 3, 16),
          model: model,
          filterConfig: dateFilter,
        ),
        isTrue,
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: DateTime(2024, 3, 15),
          model: model,
          filterConfig: dateFilter,
        ),
        isFalse,
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: DateTime(2024, 3, 14),
          model: model,
          filterConfig: dateFilter,
        ),
        isFalse,
      );
    });

    test('greaterThanOrEqual includes boundary date', () {
      const model = OsColumnFilterModel(
        filterType: 'date',
        conditions: [
          OsFilterCondition(type: 'greaterThanOrEqual', filter: '2024-03-15'),
        ],
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: DateTime(2024, 3, 15),
          model: model,
          filterConfig: dateFilter,
        ),
        isTrue,
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: DateTime(2024, 3, 16),
          model: model,
          filterConfig: dateFilter,
        ),
        isTrue,
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: DateTime(2024, 3, 14),
          model: model,
          filterConfig: dateFilter,
        ),
        isFalse,
      );
    });

    test('inRange checks between two dates (exclusive by default)', () {
      const model = OsColumnFilterModel(
        filterType: 'date',
        conditions: [
          OsFilterCondition(
            type: 'inRange',
            filter: '2024-03-10',
            filterTo: '2024-03-20',
          ),
        ],
      );
      // Inside range
      expect(
        FilterEvaluator.evaluate(
          cellValue: DateTime(2024, 3, 15),
          model: model,
          filterConfig: dateFilter,
        ),
        isTrue,
      );
      // Boundaries excluded
      expect(
        FilterEvaluator.evaluate(
          cellValue: DateTime(2024, 3, 10),
          model: model,
          filterConfig: dateFilter,
        ),
        isFalse,
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: DateTime(2024, 3, 20),
          model: model,
          filterConfig: dateFilter,
        ),
        isFalse,
      );
      // Outside range
      expect(
        FilterEvaluator.evaluate(
          cellValue: DateTime(2024, 3, 5),
          model: model,
          filterConfig: dateFilter,
        ),
        isFalse,
      );
    });

    test('inRange with inRangeInclusive includes boundaries', () {
      const inclusiveFilter = OsDateFilter(inRangeInclusive: true);
      const model = OsColumnFilterModel(
        filterType: 'date',
        conditions: [
          OsFilterCondition(
            type: 'inRange',
            filter: '2024-03-10',
            filterTo: '2024-03-20',
          ),
        ],
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: DateTime(2024, 3, 10),
          model: model,
          filterConfig: inclusiveFilter,
        ),
        isTrue,
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: DateTime(2024, 3, 20),
          model: model,
          filterConfig: inclusiveFilter,
        ),
        isTrue,
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: DateTime(2024, 3, 15),
          model: model,
          filterConfig: inclusiveFilter,
        ),
        isTrue,
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: DateTime(2024, 3, 5),
          model: model,
          filterConfig: inclusiveFilter,
        ),
        isFalse,
      );
    });

    test('blank matches null cell value', () {
      const model = OsColumnFilterModel(
        filterType: 'date',
        conditions: [OsFilterCondition(type: 'blank')],
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: null,
          model: model,
          filterConfig: dateFilter,
        ),
        isTrue,
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: DateTime(2024, 3, 15),
          model: model,
          filterConfig: dateFilter,
        ),
        isFalse,
      );
    });

    test('notBlank matches non-null cell value', () {
      const model = OsColumnFilterModel(
        filterType: 'date',
        conditions: [OsFilterCondition(type: 'notBlank')],
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: DateTime(2024, 3, 15),
          model: model,
          filterConfig: dateFilter,
        ),
        isTrue,
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: null,
          model: model,
          filterConfig: dateFilter,
        ),
        isFalse,
      );
    });
  });

  group('FilterEvaluator — date filter null handling', () {
    test('null cell value fails all operations by default', () {
      const dateFilter = OsDateFilter();
      const model = OsColumnFilterModel(
        filterType: 'date',
        conditions: [OsFilterCondition(type: 'equals', filter: '2024-03-15')],
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: null,
          model: model,
          filterConfig: dateFilter,
        ),
        isFalse,
      );
    });

    test('includeBlanksInEquals allows null to pass equals', () {
      const filter = OsDateFilter(includeBlanksInEquals: true);
      const model = OsColumnFilterModel(
        filterType: 'date',
        conditions: [OsFilterCondition(type: 'equals', filter: '2024-03-15')],
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: null,
          model: model,
          filterConfig: filter,
        ),
        isTrue,
      );
    });

    test('includeBlanksInLessThan allows null to pass lessThan', () {
      const filter = OsDateFilter(includeBlanksInLessThan: true);
      const model = OsColumnFilterModel(
        filterType: 'date',
        conditions: [OsFilterCondition(type: 'lessThan', filter: '2024-03-15')],
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: null,
          model: model,
          filterConfig: filter,
        ),
        isTrue,
      );
    });

    test('includeBlanksInGreaterThan allows null to pass greaterThan', () {
      const filter = OsDateFilter(includeBlanksInGreaterThan: true);
      const model = OsColumnFilterModel(
        filterType: 'date',
        conditions: [
          OsFilterCondition(type: 'greaterThan', filter: '2024-03-15'),
        ],
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: null,
          model: model,
          filterConfig: filter,
        ),
        isTrue,
      );
    });

    test('includeBlanksInRange allows null to pass inRange', () {
      const filter = OsDateFilter(includeBlanksInRange: true);
      const model = OsColumnFilterModel(
        filterType: 'date',
        conditions: [
          OsFilterCondition(
            type: 'inRange',
            filter: '2024-03-10',
            filterTo: '2024-03-20',
          ),
        ],
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: null,
          model: model,
          filterConfig: filter,
        ),
        isTrue,
      );
    });

    test('empty string cell value treated as blank', () {
      const dateFilter = OsDateFilter();
      const model = OsColumnFilterModel(
        filterType: 'date',
        conditions: [OsFilterCondition(type: 'blank')],
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: '',
          model: model,
          filterConfig: dateFilter,
        ),
        isTrue,
      );
    });
  });

  group('FilterEvaluator — date filter combined conditions', () {
    const dateFilter = OsDateFilter();

    test('AND requires all conditions to pass', () {
      const model = OsColumnFilterModel(
        filterType: 'date',
        operator: OsJoinOperator.and,
        conditions: [
          OsFilterCondition(type: 'greaterThan', filter: '2024-03-10'),
          OsFilterCondition(type: 'lessThan', filter: '2024-03-20'),
        ],
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: DateTime(2024, 3, 15),
          model: model,
          filterConfig: dateFilter,
        ),
        isTrue,
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: DateTime(2024, 3, 5),
          model: model,
          filterConfig: dateFilter,
        ),
        isFalse,
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: DateTime(2024, 3, 25),
          model: model,
          filterConfig: dateFilter,
        ),
        isFalse,
      );
    });

    test('OR requires at least one condition to pass', () {
      const model = OsColumnFilterModel(
        filterType: 'date',
        operator: OsJoinOperator.or,
        conditions: [
          OsFilterCondition(type: 'equals', filter: '2024-03-15'),
          OsFilterCondition(type: 'equals', filter: '2024-03-20'),
        ],
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: DateTime(2024, 3, 15),
          model: model,
          filterConfig: dateFilter,
        ),
        isTrue,
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: DateTime(2024, 3, 20),
          model: model,
          filterConfig: dateFilter,
        ),
        isTrue,
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: DateTime(2024, 3, 16),
          model: model,
          filterConfig: dateFilter,
        ),
        isFalse,
      );
    });
  });

  group('Date filter JSON model compatibility', () {
    test('toJson outputs dateFrom/dateTo for date filterType', () {
      const model = OsColumnFilterModel(
        filterType: 'date',
        conditions: [OsFilterCondition(type: 'equals', filter: '2024-03-15')],
      );
      final json = model.toJson();
      expect(json['filterType'], 'date');
      expect(json['type'], 'equals');
      expect(json['dateFrom'], '2024-03-15');
      expect(json.containsKey('filter'), isFalse);
    });

    test('toJson outputs dateFrom/dateTo for inRange', () {
      const model = OsColumnFilterModel(
        filterType: 'date',
        conditions: [
          OsFilterCondition(
            type: 'inRange',
            filter: '2024-03-10',
            filterTo: '2024-03-20',
          ),
        ],
      );
      final json = model.toJson();
      expect(json['dateFrom'], '2024-03-10');
      expect(json['dateTo'], '2024-03-20');
      expect(json.containsKey('filter'), isFalse);
      expect(json.containsKey('filterTo'), isFalse);
    });

    test('fromJson reads dateFrom/dateTo for date models', () {
      final json = {
        'filterType': 'date',
        'type': 'greaterThan',
        'dateFrom': '2024-06-01',
      };
      final model = OsColumnFilterModel.fromJson(json);
      expect(model.filterType, 'date');
      expect(model.conditions.length, 1);
      expect(model.conditions.first.type, 'greaterThan');
      expect(model.conditions.first.filter, '2024-06-01');
    });

    test('fromJson reads dateFrom/dateTo for inRange', () {
      final json = {
        'filterType': 'date',
        'type': 'inRange',
        'dateFrom': '2024-01-01',
        'dateTo': '2024-12-31',
      };
      final model = OsColumnFilterModel.fromJson(json);
      expect(model.conditions.first.filter, '2024-01-01');
      expect(model.conditions.first.filterTo, '2024-12-31');
    });

    test('fromJson combined date model', () {
      final json = {
        'filterType': 'date',
        'operator': 'AND',
        'conditions': [
          {'type': 'greaterThan', 'dateFrom': '2024-01-01'},
          {'type': 'lessThan', 'dateFrom': '2024-12-31'},
        ],
      };
      final model = OsColumnFilterModel.fromJson(json);
      expect(model.filterType, 'date');
      expect(model.operator, OsJoinOperator.and);
      expect(model.conditions.length, 2);
      expect(model.conditions[0].filter, '2024-01-01');
      expect(model.conditions[1].filter, '2024-12-31');
    });

    test('toJson combined date model uses dateFrom/dateTo', () {
      const model = OsColumnFilterModel(
        filterType: 'date',
        operator: OsJoinOperator.or,
        conditions: [
          OsFilterCondition(type: 'equals', filter: '2024-03-15'),
          OsFilterCondition(type: 'equals', filter: '2024-06-15'),
        ],
      );
      final json = model.toJson();
      expect(json['operator'], 'OR');
      final conditions = json['conditions'] as List;
      expect(conditions[0]['dateFrom'], '2024-03-15');
      expect(conditions[1]['dateFrom'], '2024-06-15');
      expect(conditions[0].containsKey('filter'), isFalse);
    });

    test('round-trip: toJson then fromJson preserves date model', () {
      const original = OsColumnFilterModel(
        filterType: 'date',
        conditions: [
          OsFilterCondition(
            type: 'inRange',
            filter: '2024-01-01',
            filterTo: '2024-06-30',
          ),
        ],
      );
      final json = original.toJson();
      final restored = OsColumnFilterModel.fromJson(json);
      expect(restored.filterType, 'date');
      expect(restored.conditions.first.type, 'inRange');
      expect(restored.conditions.first.filter, '2024-01-01');
      expect(restored.conditions.first.filterTo, '2024-06-30');
    });

    test('text/number models still use filter/filterTo in JSON', () {
      const model = OsColumnFilterModel(
        filterType: 'number',
        conditions: [OsFilterCondition(type: 'greaterThan', filter: 42)],
      );
      final json = model.toJson();
      expect(json['filter'], 42);
      expect(json.containsKey('dateFrom'), isFalse);
    });
  });

  group('Date filter utility functions', () {
    test('getDefaultFilterType returns correct default for date filter', () {
      expect(getDefaultFilterType(const OsDateFilter()), 'equals');
      expect(
        getDefaultFilterType(
          const OsDateFilter(defaultOption: OsDateFilterOption.lessThan),
        ),
        'lessThan',
      );
    });

    test('getAvailableFilterOptions returns defaults for date filter', () {
      final options = getAvailableFilterOptions(const OsDateFilter());
      expect(options, contains('equals'));
      expect(options, contains('notEqual'));
      expect(options, contains('lessThan'));
      expect(options, contains('greaterThan'));
      expect(options, contains('inRange'));
      expect(options, contains('blank'));
      expect(options, contains('notBlank'));
      // lessThanOrEqual and greaterThanOrEqual are NOT in defaults
      expect(options, isNot(contains('lessThanOrEqual')));
      expect(options, isNot(contains('greaterThanOrEqual')));
    });

    test('getAvailableFilterOptions respects custom filterOptions', () {
      const filter = OsDateFilter(
        filterOptions: [
          OsDateFilterOption.equals,
          OsDateFilterOption.lessThan,
          OsDateFilterOption.greaterThan,
        ],
      );
      final options = getAvailableFilterOptions(filter);
      expect(options, ['equals', 'lessThan', 'greaterThan']);
    });

    test('getFilterOperationDisplayName shows date-specific labels', () {
      const dateFilter = OsDateFilter();
      expect(
        getFilterOperationDisplayName('lessThan', filter: dateFilter),
        'Before',
      );
      expect(
        getFilterOperationDisplayName('greaterThan', filter: dateFilter),
        'After',
      );
      expect(
        getFilterOperationDisplayName('lessThanOrEqual', filter: dateFilter),
        'Before or on',
      );
      expect(
        getFilterOperationDisplayName('greaterThanOrEqual', filter: dateFilter),
        'After or on',
      );
      // Non-date-specific labels still work
      expect(
        getFilterOperationDisplayName('equals', filter: dateFilter),
        'Equals',
      );
    });
  });

  group('Date filter edge cases', () {
    const dateFilter = OsDateFilter();

    test('invalid date string in filter value does not crash', () {
      const model = OsColumnFilterModel(
        filterType: 'date',
        conditions: [OsFilterCondition(type: 'equals', filter: 'not-a-date')],
      );
      // Invalid filter value = no filtering (passes)
      expect(
        FilterEvaluator.evaluate(
          cellValue: DateTime(2024, 3, 15),
          model: model,
          filterConfig: dateFilter,
        ),
        isTrue,
      );
    });

    test('invalid date string in cell value fails filter', () {
      const model = OsColumnFilterModel(
        filterType: 'date',
        conditions: [OsFilterCondition(type: 'equals', filter: '2024-03-15')],
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: 'not-a-date',
          model: model,
          filterConfig: dateFilter,
        ),
        isFalse,
      );
    });

    test('date string with time component parses correctly', () {
      const model = OsColumnFilterModel(
        filterType: 'date',
        conditions: [
          OsFilterCondition(type: 'equals', filter: '2024-03-15 10:30:00'),
        ],
      );
      // Default comparator strips time, so this should match
      expect(
        FilterEvaluator.evaluate(
          cellValue: DateTime(2024, 3, 15, 23, 59, 59),
          model: model,
          filterConfig: dateFilter,
        ),
        isTrue,
      );
    });

    test('date string with T separator parses correctly', () {
      const model = OsColumnFilterModel(
        filterType: 'date',
        conditions: [
          OsFilterCondition(type: 'equals', filter: '2024-03-15T10:30:00'),
        ],
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: DateTime(2024, 3, 15),
          model: model,
          filterConfig: dateFilter,
        ),
        isTrue,
      );
    });

    test('custom comparator is used when provided', () {
      // Custom comparator that compares only year and month (ignores day)
      final filter = OsDateFilter(
        comparator: (DateTime filterDate, dynamic cellValue) {
          final cell = cellValue as DateTime;
          final filterYM = filterDate.year * 12 + filterDate.month;
          final cellYM = cell.year * 12 + cell.month;
          return cellYM.compareTo(filterYM);
        },
      );
      const model = OsColumnFilterModel(
        filterType: 'date',
        conditions: [OsFilterCondition(type: 'equals', filter: '2024-03-01')],
      );
      // Same month, different day — should match with custom comparator
      expect(
        FilterEvaluator.evaluate(
          cellValue: DateTime(2024, 3, 28),
          model: model,
          filterConfig: filter,
        ),
        isTrue,
      );
      // Different month — should not match
      expect(
        FilterEvaluator.evaluate(
          cellValue: DateTime(2024, 4, 1),
          model: model,
          filterConfig: filter,
        ),
        isFalse,
      );
    });

    test('no filter value means no filtering (passes all)', () {
      const model = OsColumnFilterModel(
        filterType: 'date',
        conditions: [OsFilterCondition(type: 'equals', filter: '')],
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: DateTime(2024, 3, 15),
          model: model,
          filterConfig: dateFilter,
        ),
        isTrue,
      );
    });

    test('inRange with missing filterTo passes all', () {
      const model = OsColumnFilterModel(
        filterType: 'date',
        conditions: [OsFilterCondition(type: 'inRange', filter: '2024-03-10')],
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: DateTime(2024, 3, 5),
          model: model,
          filterConfig: dateFilter,
        ),
        isTrue,
      );
    });
  });

  group('FilterEvaluator — date filter timezone normalisation', () {
    // Contract: date-only calendar comparison in the cell's own parsed
    // zone; Z-suffixed cells compare by their UTC calendar day. Filter
    // inputs without zone info are local calendar dates.
    const dateFilter = OsDateFilter();

    OsColumnFilterModel rangeModel(String from, String to) =>
        OsColumnFilterModel(
          filterType: 'date',
          conditions: [
            OsFilterCondition(type: 'inRange', filter: from, filterTo: to),
          ],
        );

    test("Z-suffixed cell passes equals by its UTC calendar day", () {
      const model = OsColumnFilterModel(
        filterType: 'date',
        conditions: [OsFilterCondition(type: 'equals', filter: '2024-01-01')],
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: '2024-01-01T23:30:00Z',
          model: model,
          filterConfig: dateFilter,
        ),
        isTrue,
        reason: '23:30Z is still the 2024-01-01 UTC calendar day',
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: '2024-01-02T00:30:00Z',
          model: model,
          filterConfig: dateFilter,
        ),
        isFalse,
        reason: 'the UTC calendar day has rolled over to Jan 2',
      );
    });

    test('local timestamp (no Z) also passes equals the same day', () {
      const model = OsColumnFilterModel(
        filterType: 'date',
        conditions: [OsFilterCondition(type: 'equals', filter: '2024-01-01')],
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: '2024-01-01T23:30:00',
          model: model,
          filterConfig: dateFilter,
        ),
        isTrue,
        reason: 'local calendar day is 2024-01-01 regardless of machine TZ',
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: '2024-01-02T00:30:00',
          model: model,
          filterConfig: dateFilter,
        ),
        isFalse,
      );
    });

    test('DateTime cells keep their own zone representation', () {
      const model = OsColumnFilterModel(
        filterType: 'date',
        conditions: [OsFilterCondition(type: 'equals', filter: '2024-01-01')],
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: DateTime.utc(2024, 1, 1, 23, 30),
          model: model,
          filterConfig: dateFilter,
        ),
        isTrue,
        reason: 'UTC calendar day of a UTC DateTime is Jan 1',
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: DateTime(2024, 1, 1, 23, 30),
          model: model,
          filterConfig: dateFilter,
        ),
        isTrue,
        reason: 'local calendar day of a local DateTime is Jan 1',
      );
    });

    test(
      'inRange boundaries use each side’s own calendar day across zones',
      () {
        // Exclusive range (default): [2024-01-02, 2024-01-31).
        const exclusive = OsDateFilter();
        final model = rangeModel('2024-01-02', '2024-01-31');

        expect(
          FilterEvaluator.evaluate(
            cellValue: '2024-01-15T10:00:00Z',
            model: model,
            filterConfig: exclusive,
          ),
          isTrue,
        );
        // Below-range boundary (UTC day Jan 1) excluded.
        expect(
          FilterEvaluator.evaluate(
            cellValue: '2024-01-01T12:00:00Z',
            model: model,
            filterConfig: exclusive,
          ),
          isFalse,
        );
        // Upper boundary (UTC day Jan 31 == filterTo day) excluded when
        // inRangeInclusive is false.
        expect(
          FilterEvaluator.evaluate(
            cellValue: '2024-01-31T23:59:59Z',
            model: model,
            filterConfig: exclusive,
          ),
          isFalse,
        );
        // A Z-suffixed instant whose UTC calendar day already rolled into
        // February stays outside the January range on any host timezone.
        expect(
          FilterEvaluator.evaluate(
            cellValue: '2024-02-01T00:30:00Z',
            model: model,
            filterConfig: exclusive,
          ),
          isFalse,
        );

        // Inclusive range admits both boundary days.
        const inclusive = OsDateFilter(inRangeInclusive: true);
        expect(
          FilterEvaluator.evaluate(
            cellValue: '2024-01-02T00:00:01Z',
            model: model,
            filterConfig: inclusive,
          ),
          isTrue,
        );
        expect(
          FilterEvaluator.evaluate(
            cellValue: '2024-01-31T23:59:59Z',
            model: model,
            filterConfig: inclusive,
          ),
          isTrue,
        );
      },
    );
  });
}
