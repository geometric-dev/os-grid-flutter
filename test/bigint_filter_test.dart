import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

void main() {
  group('OsBigIntFilter configuration', () {
    test('default values', () {
      const filter = OsBigIntFilter();
      expect(filter.defaultOption, OsBigIntFilterOption.equals);
      expect(filter.maxNumConditions, 2);
      expect(filter.defaultJoinOperator, OsJoinOperator.and);
      expect(filter.inRangeInclusive, isFalse);
      expect(filter.filterOptions, isNull);
      expect(filter.allowedCharPattern, isNull);
      expect(filter.includeBlanksInEquals, isFalse);
      expect(filter.includeBlanksInNotEqual, isFalse);
      expect(filter.includeBlanksInLessThan, isFalse);
      expect(filter.includeBlanksInGreaterThan, isFalse);
      expect(filter.includeBlanksInRange, isFalse);
      expect(filter.debounceMs, isNull);
    });

    test('custom configuration', () {
      const filter = OsBigIntFilter(
        filterOptions: [
          OsBigIntFilterOption.greaterThan,
          OsBigIntFilterOption.lessThan,
        ],
        defaultOption: OsBigIntFilterOption.greaterThan,
        maxNumConditions: 3,
        defaultJoinOperator: OsJoinOperator.or,
        inRangeInclusive: true,
        allowedCharPattern: r'[\d\-]',
      );
      expect(filter.filterOptions!.length, 2);
      expect(filter.defaultOption, OsBigIntFilterOption.greaterThan);
      expect(filter.maxNumConditions, 3);
      expect(filter.defaultJoinOperator, OsJoinOperator.or);
      expect(filter.inRangeInclusive, isTrue);
      expect(filter.allowedCharPattern, r'[\d\-]');
    });
  });

  group('FilterEvaluator — BigInt filter', () {
    const bigIntFilter = OsBigIntFilter();

    test('equals matches BigInt value', () {
      const model = OsColumnFilterModel(
        filterType: 'bigint',
        conditions: [OsFilterCondition(type: 'equals', filter: '42')],
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: BigInt.from(42),
          model: model,
          filterConfig: bigIntFilter,
        ),
        isTrue,
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: BigInt.from(43),
          model: model,
          filterConfig: bigIntFilter,
        ),
        isFalse,
      );
    });

    test('equals works with int cell values', () {
      const model = OsColumnFilterModel(
        filterType: 'bigint',
        conditions: [OsFilterCondition(type: 'equals', filter: '100')],
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: 100,
          model: model,
          filterConfig: bigIntFilter,
        ),
        isTrue,
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: 101,
          model: model,
          filterConfig: bigIntFilter,
        ),
        isFalse,
      );
    });

    test('notEqual excludes matching value', () {
      const model = OsColumnFilterModel(
        filterType: 'bigint',
        conditions: [OsFilterCondition(type: 'notEqual', filter: '42')],
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: BigInt.from(42),
          model: model,
          filterConfig: bigIntFilter,
        ),
        isFalse,
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: BigInt.from(43),
          model: model,
          filterConfig: bigIntFilter,
        ),
        isTrue,
      );
    });

    test('greaterThan compares correctly', () {
      const model = OsColumnFilterModel(
        filterType: 'bigint',
        conditions: [OsFilterCondition(type: 'greaterThan', filter: '30')],
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: BigInt.from(40),
          model: model,
          filterConfig: bigIntFilter,
        ),
        isTrue,
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: BigInt.from(30),
          model: model,
          filterConfig: bigIntFilter,
        ),
        isFalse,
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: BigInt.from(20),
          model: model,
          filterConfig: bigIntFilter,
        ),
        isFalse,
      );
    });

    test('greaterThanOrEqual includes boundary', () {
      const model = OsColumnFilterModel(
        filterType: 'bigint',
        conditions: [
          OsFilterCondition(type: 'greaterThanOrEqual', filter: '30'),
        ],
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: BigInt.from(30),
          model: model,
          filterConfig: bigIntFilter,
        ),
        isTrue,
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: BigInt.from(29),
          model: model,
          filterConfig: bigIntFilter,
        ),
        isFalse,
      );
    });

    test('lessThan compares correctly', () {
      const model = OsColumnFilterModel(
        filterType: 'bigint',
        conditions: [OsFilterCondition(type: 'lessThan', filter: '30')],
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: BigInt.from(20),
          model: model,
          filterConfig: bigIntFilter,
        ),
        isTrue,
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: BigInt.from(30),
          model: model,
          filterConfig: bigIntFilter,
        ),
        isFalse,
      );
    });

    test('lessThanOrEqual includes boundary', () {
      const model = OsColumnFilterModel(
        filterType: 'bigint',
        conditions: [OsFilterCondition(type: 'lessThanOrEqual', filter: '30')],
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: BigInt.from(30),
          model: model,
          filterConfig: bigIntFilter,
        ),
        isTrue,
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: BigInt.from(31),
          model: model,
          filterConfig: bigIntFilter,
        ),
        isFalse,
      );
    });

    test('inRange exclusive by default', () {
      const model = OsColumnFilterModel(
        filterType: 'bigint',
        conditions: [
          OsFilterCondition(type: 'inRange', filter: '10', filterTo: '50'),
        ],
      );
      // Inside range passes
      expect(
        FilterEvaluator.evaluate(
          cellValue: BigInt.from(25),
          model: model,
          filterConfig: bigIntFilter,
        ),
        isTrue,
      );
      // Boundaries excluded (exclusive)
      expect(
        FilterEvaluator.evaluate(
          cellValue: BigInt.from(10),
          model: model,
          filterConfig: bigIntFilter,
        ),
        isFalse,
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: BigInt.from(50),
          model: model,
          filterConfig: bigIntFilter,
        ),
        isFalse,
      );
      // Just inside passes
      expect(
        FilterEvaluator.evaluate(
          cellValue: BigInt.from(11),
          model: model,
          filterConfig: bigIntFilter,
        ),
        isTrue,
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: BigInt.from(49),
          model: model,
          filterConfig: bigIntFilter,
        ),
        isTrue,
      );
      // Outside fails
      expect(
        FilterEvaluator.evaluate(
          cellValue: BigInt.from(5),
          model: model,
          filterConfig: bigIntFilter,
        ),
        isFalse,
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: BigInt.from(55),
          model: model,
          filterConfig: bigIntFilter,
        ),
        isFalse,
      );
    });

    test('inRange inclusive with inRangeInclusive: true', () {
      const inclusiveFilter = OsBigIntFilter(inRangeInclusive: true);
      const model = OsColumnFilterModel(
        filterType: 'bigint',
        conditions: [
          OsFilterCondition(type: 'inRange', filter: '10', filterTo: '50'),
        ],
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: BigInt.from(10),
          model: model,
          filterConfig: inclusiveFilter,
        ),
        isTrue,
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: BigInt.from(50),
          model: model,
          filterConfig: inclusiveFilter,
        ),
        isTrue,
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: BigInt.from(25),
          model: model,
          filterConfig: inclusiveFilter,
        ),
        isTrue,
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: BigInt.from(5),
          model: model,
          filterConfig: inclusiveFilter,
        ),
        isFalse,
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: BigInt.from(55),
          model: model,
          filterConfig: inclusiveFilter,
        ),
        isFalse,
      );
    });

    test('blank matches null', () {
      const model = OsColumnFilterModel(
        filterType: 'bigint',
        conditions: [OsFilterCondition(type: 'blank')],
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: null,
          model: model,
          filterConfig: bigIntFilter,
        ),
        isTrue,
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: BigInt.from(42),
          model: model,
          filterConfig: bigIntFilter,
        ),
        isFalse,
      );
    });

    test('notBlank matches non-null values', () {
      const model = OsColumnFilterModel(
        filterType: 'bigint',
        conditions: [OsFilterCondition(type: 'notBlank')],
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: BigInt.from(42),
          model: model,
          filterConfig: bigIntFilter,
        ),
        isTrue,
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: null,
          model: model,
          filterConfig: bigIntFilter,
        ),
        isFalse,
      );
    });

    test('null cell value fails most operations', () {
      const model = OsColumnFilterModel(
        filterType: 'bigint',
        conditions: [OsFilterCondition(type: 'greaterThan', filter: '30')],
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: null,
          model: model,
          filterConfig: bigIntFilter,
        ),
        isFalse,
      );
    });

    test('null cell value is excluded from notEqual by default', () {
      // Mirrors the date filter + AG Grid: blanks fail every operation
      // unless the matching includeBlanksIn* flag is set.
      const model = OsColumnFilterModel(
        filterType: 'bigint',
        conditions: [OsFilterCondition(type: 'notEqual', filter: '30')],
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: null,
          model: model,
          filterConfig: bigIntFilter,
        ),
        isFalse,
      );
      const includeBlanks = OsBigIntFilter(includeBlanksInNotEqual: true);
      expect(
        FilterEvaluator.evaluate(
          cellValue: null,
          model: model,
          filterConfig: includeBlanks,
        ),
        isTrue,
      );
    });

    test('non-integer string cell value fails comparisons', () {
      const model = OsColumnFilterModel(
        filterType: 'bigint',
        conditions: [OsFilterCondition(type: 'equals', filter: '42')],
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: 'not a number',
          model: model,
          filterConfig: bigIntFilter,
        ),
        isFalse,
      );
    });

    test('decimal string cell value fails (integer-only)', () {
      const model = OsColumnFilterModel(
        filterType: 'bigint',
        conditions: [OsFilterCondition(type: 'equals', filter: '42')],
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: '42.5',
          model: model,
          filterConfig: bigIntFilter,
        ),
        isFalse,
      );
    });

    test('handles very large integers beyond 64-bit range', () {
      // 2^100 = 1267650600228229401496703205376
      final largeValue = BigInt.two.pow(100);
      final threshold = BigInt.two.pow(99);
      const model = OsColumnFilterModel(
        filterType: 'bigint',
        conditions: [
          OsFilterCondition(
            type: 'greaterThan',
            filter: '633825300114114700748351602688', // 2^99
          ),
        ],
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: largeValue,
          model: model,
          filterConfig: bigIntFilter,
        ),
        isTrue,
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: threshold,
          model: model,
          filterConfig: bigIntFilter,
        ),
        isFalse,
      );
    });

    test('handles negative BigInt values', () {
      const model = OsColumnFilterModel(
        filterType: 'bigint',
        conditions: [OsFilterCondition(type: 'lessThan', filter: '0')],
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: BigInt.from(-5),
          model: model,
          filterConfig: bigIntFilter,
        ),
        isTrue,
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: BigInt.from(5),
          model: model,
          filterConfig: bigIntFilter,
        ),
        isFalse,
      );
    });

    test('parses filter value with trailing n suffix', () {
      // JavaScript BigInt literals end with 'n' (e.g. 42n)
      const model = OsColumnFilterModel(
        filterType: 'bigint',
        conditions: [OsFilterCondition(type: 'equals', filter: '42n')],
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: BigInt.from(42),
          model: model,
          filterConfig: bigIntFilter,
        ),
        isTrue,
      );
    });

    test('parses int cell values correctly', () {
      const model = OsColumnFilterModel(
        filterType: 'bigint',
        conditions: [OsFilterCondition(type: 'equals', filter: '999')],
      );
      // int cell value should be converted to BigInt for comparison
      expect(
        FilterEvaluator.evaluate(
          cellValue: 999,
          model: model,
          filterConfig: bigIntFilter,
        ),
        isTrue,
      );
    });

    test('parses double cell values with no fractional part', () {
      const model = OsColumnFilterModel(
        filterType: 'bigint',
        conditions: [OsFilterCondition(type: 'equals', filter: '100')],
      );
      // 100.0 has no fractional part, should convert to BigInt
      expect(
        FilterEvaluator.evaluate(
          cellValue: 100.0,
          model: model,
          filterConfig: bigIntFilter,
        ),
        isTrue,
      );
      // 100.5 has a fractional part, should fail
      expect(
        FilterEvaluator.evaluate(
          cellValue: 100.5,
          model: model,
          filterConfig: bigIntFilter,
        ),
        isFalse,
      );
    });

    test('string cell values parsed as BigInt', () {
      const model = OsColumnFilterModel(
        filterType: 'bigint',
        conditions: [
          OsFilterCondition(type: 'greaterThan', filter: '1000000000000'),
        ],
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: '2000000000000',
          model: model,
          filterConfig: bigIntFilter,
        ),
        isTrue,
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: '500000000000',
          model: model,
          filterConfig: bigIntFilter,
        ),
        isFalse,
      );
    });
  });

  group('FilterEvaluator — BigInt combined conditions', () {
    const bigIntFilter = OsBigIntFilter();

    test('AND requires all conditions to pass', () {
      const model = OsColumnFilterModel(
        filterType: 'bigint',
        operator: OsJoinOperator.and,
        conditions: [
          OsFilterCondition(type: 'greaterThan', filter: '10'),
          OsFilterCondition(type: 'lessThan', filter: '50'),
        ],
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: BigInt.from(25),
          model: model,
          filterConfig: bigIntFilter,
        ),
        isTrue,
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: BigInt.from(5),
          model: model,
          filterConfig: bigIntFilter,
        ),
        isFalse,
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: BigInt.from(55),
          model: model,
          filterConfig: bigIntFilter,
        ),
        isFalse,
      );
    });

    test('OR requires at least one condition to pass', () {
      const model = OsColumnFilterModel(
        filterType: 'bigint',
        operator: OsJoinOperator.or,
        conditions: [
          OsFilterCondition(type: 'equals', filter: '10'),
          OsFilterCondition(type: 'equals', filter: '20'),
        ],
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: BigInt.from(10),
          model: model,
          filterConfig: bigIntFilter,
        ),
        isTrue,
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: BigInt.from(20),
          model: model,
          filterConfig: bigIntFilter,
        ),
        isTrue,
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: BigInt.from(30),
          model: model,
          filterConfig: bigIntFilter,
        ),
        isFalse,
      );
    });
  });

  group('FilterEvaluator — BigInt filter blanks (includeBlanksIn*)', () {
    OsColumnFilterModel modelOf(String type, {String? filterTo}) =>
        OsColumnFilterModel(
          filterType: 'bigint',
          conditions: [
            OsFilterCondition(type: type, filter: '30', filterTo: filterTo),
          ],
        );

    test('null cell fails every comparison operation by default', () {
      const filter = OsBigIntFilter();
      for (final type in [
        'equals',
        'notEqual',
        'lessThan',
        'lessThanOrEqual',
        'greaterThan',
        'greaterThanOrEqual',
        'inRange',
      ]) {
        expect(
          FilterEvaluator.evaluate(
            cellValue: null,
            model: modelOf(type, filterTo: '50'),
            filterConfig: filter,
          ),
          isFalse,
          reason: 'null should fail $type by default',
        );
      }
    });

    test('includeBlanksInEquals allows null to pass equals', () {
      const filter = OsBigIntFilter(includeBlanksInEquals: true);
      expect(
        FilterEvaluator.evaluate(
          cellValue: null,
          model: modelOf('equals'),
          filterConfig: filter,
        ),
        isTrue,
      );
    });

    test('includeBlanksInNotEqual allows null to pass notEqual', () {
      const filter = OsBigIntFilter(includeBlanksInNotEqual: true);
      expect(
        FilterEvaluator.evaluate(
          cellValue: null,
          model: modelOf('notEqual'),
          filterConfig: filter,
        ),
        isTrue,
      );
    });

    test('includeBlanksInLessThan covers lessThan and lessThanOrEqual', () {
      const filter = OsBigIntFilter(includeBlanksInLessThan: true);
      for (final type in ['lessThan', 'lessThanOrEqual']) {
        expect(
          FilterEvaluator.evaluate(
            cellValue: null,
            model: modelOf(type),
            filterConfig: filter,
          ),
          isTrue,
          reason: 'null should pass $type with includeBlanksInLessThan',
        );
      }
    });

    test(
      'includeBlanksInGreaterThan covers greaterThan/greaterThanOrEqual',
      () {
        const filter = OsBigIntFilter(includeBlanksInGreaterThan: true);
        for (final type in ['greaterThan', 'greaterThanOrEqual']) {
          expect(
            FilterEvaluator.evaluate(
              cellValue: null,
              model: modelOf(type),
              filterConfig: filter,
            ),
            isTrue,
            reason: 'null should pass $type with includeBlanksInGreaterThan',
          );
        }
      },
    );

    test('includeBlanksInRange allows null to pass inRange', () {
      const filter = OsBigIntFilter(includeBlanksInRange: true);
      expect(
        FilterEvaluator.evaluate(
          cellValue: null,
          model: modelOf('inRange', filterTo: '50'),
          filterConfig: filter,
        ),
        isTrue,
      );
    });

    test('non-blank cells are unaffected by the flags', () {
      const withFlag = OsBigIntFilter(includeBlanksInRange: true);
      final model = modelOf('inRange', filterTo: '50');
      expect(
        FilterEvaluator.evaluate(
          cellValue: BigInt.from(40),
          model: model,
          filterConfig: withFlag,
        ),
        isTrue,
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: BigInt.from(60),
          model: model,
          filterConfig: withFlag,
        ),
        isFalse,
      );
    });
  });

  group('BigInt filter utility functions', () {
    test('getDefaultFilterType returns equals for BigInt filter', () {
      expect(getDefaultFilterType(const OsBigIntFilter()), 'equals');
      expect(
        getDefaultFilterType(
          const OsBigIntFilter(defaultOption: OsBigIntFilterOption.greaterThan),
        ),
        'greaterThan',
      );
    });

    test('getAvailableFilterOptions returns all options by default', () {
      final options = getAvailableFilterOptions(const OsBigIntFilter());
      expect(options, contains('equals'));
      expect(options, contains('notEqual'));
      expect(options, contains('greaterThan'));
      expect(options, contains('greaterThanOrEqual'));
      expect(options, contains('lessThan'));
      expect(options, contains('lessThanOrEqual'));
      expect(options, contains('inRange'));
      expect(options, contains('blank'));
      expect(options, contains('notBlank'));
      expect(options.length, 9);
    });

    test('getAvailableFilterOptions respects filterOptions', () {
      const filter = OsBigIntFilter(
        filterOptions: [
          OsBigIntFilterOption.greaterThan,
          OsBigIntFilterOption.lessThan,
        ],
      );
      final options = getAvailableFilterOptions(filter);
      expect(options, ['greaterThan', 'lessThan']);
    });
  });

  group('BigInt filter JSON model compatibility', () {
    test('filter model with bigint filterType serialises correctly', () {
      const model = OsColumnFilterModel(
        filterType: 'bigint',
        conditions: [
          OsFilterCondition(type: 'greaterThan', filter: '999999999999999999'),
        ],
      );
      final json = model.toJson();
      expect(json['filterType'], 'bigint');
      expect(json['type'], 'greaterThan');
      expect(json['filter'], '999999999999999999');
    });

    test('filter model round-trips through JSON', () {
      final json = {
        'filterType': 'bigint',
        'type': 'inRange',
        'filter': '100000000000000000',
        'filterTo': '999999999999999999',
      };
      final model = OsColumnFilterModel.fromJson(json);
      expect(model.filterType, 'bigint');
      expect(model.conditions.length, 1);
      expect(model.conditions.first.type, 'inRange');
      expect(model.conditions.first.filter, '100000000000000000');
      expect(model.conditions.first.filterTo, '999999999999999999');

      // Verify the model evaluates correctly
      const bigIntFilter = OsBigIntFilter();
      expect(
        FilterEvaluator.evaluate(
          cellValue: BigInt.parse('500000000000000000'),
          model: model,
          filterConfig: bigIntFilter,
        ),
        isTrue,
      );
    });

    test('combined model JSON round-trip', () {
      final json = {
        'filterType': 'bigint',
        'operator': 'AND',
        'conditions': [
          {'type': 'greaterThan', 'filter': '0'},
          {'type': 'lessThan', 'filter': '1000000000000000000'},
        ],
      };
      final model = OsColumnFilterModel.fromJson(json);
      expect(model.filterType, 'bigint');
      expect(model.operator, OsJoinOperator.and);
      expect(model.conditions.length, 2);
    });
  });

  group('BigInt filter edge cases', () {
    const bigIntFilter = OsBigIntFilter();

    test('empty string filter value means no filtering', () {
      const model = OsColumnFilterModel(
        filterType: 'bigint',
        conditions: [OsFilterCondition(type: 'equals', filter: '')],
      );
      // Empty filter value = no filtering, everything passes
      expect(
        FilterEvaluator.evaluate(
          cellValue: BigInt.from(42),
          model: model,
          filterConfig: bigIntFilter,
        ),
        isTrue,
      );
    });

    test('null filter value means no filtering', () {
      const model = OsColumnFilterModel(
        filterType: 'bigint',
        conditions: [OsFilterCondition(type: 'greaterThan')],
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: BigInt.from(42),
          model: model,
          filterConfig: bigIntFilter,
        ),
        isTrue,
      );
    });

    test('inRange with missing filterTo means no filtering', () {
      const model = OsColumnFilterModel(
        filterType: 'bigint',
        conditions: [OsFilterCondition(type: 'inRange', filter: '10')],
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: BigInt.from(5),
          model: model,
          filterConfig: bigIntFilter,
        ),
        isTrue,
      );
    });

    test('NaN double cell value fails', () {
      const model = OsColumnFilterModel(
        filterType: 'bigint',
        conditions: [OsFilterCondition(type: 'equals', filter: '42')],
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: double.nan,
          model: model,
          filterConfig: bigIntFilter,
        ),
        isFalse,
      );
    });

    test('infinity double cell value fails', () {
      const model = OsColumnFilterModel(
        filterType: 'bigint',
        conditions: [OsFilterCondition(type: 'equals', filter: '42')],
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: double.infinity,
          model: model,
          filterConfig: bigIntFilter,
        ),
        isFalse,
      );
    });

    test('hex string is rejected (digits only)', () {
      const model = OsColumnFilterModel(
        filterType: 'bigint',
        conditions: [OsFilterCondition(type: 'equals', filter: '0xFF')],
      );
      // Invalid filter value = no filtering, passes
      expect(
        FilterEvaluator.evaluate(
          cellValue: BigInt.from(255),
          model: model,
          filterConfig: bigIntFilter,
        ),
        isTrue,
      );
    });

    test('filter value with leading/trailing whitespace is trimmed', () {
      const model = OsColumnFilterModel(
        filterType: 'bigint',
        conditions: [OsFilterCondition(type: 'equals', filter: '  42  ')],
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: BigInt.from(42),
          model: model,
          filterConfig: bigIntFilter,
        ),
        isTrue,
      );
    });

    test('filter value with sign prefix works', () {
      const model = OsColumnFilterModel(
        filterType: 'bigint',
        conditions: [OsFilterCondition(type: 'equals', filter: '-100')],
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: BigInt.from(-100),
          model: model,
          filterConfig: bigIntFilter,
        ),
        isTrue,
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: BigInt.from(100),
          model: model,
          filterConfig: bigIntFilter,
        ),
        isFalse,
      );
    });

    test('inactive model passes all values', () {
      const model = OsColumnFilterModel(filterType: 'bigint', conditions: []);
      expect(
        FilterEvaluator.evaluate(
          cellValue: BigInt.from(42),
          model: model,
          filterConfig: bigIntFilter,
        ),
        isTrue,
      );
    });
  });
}
