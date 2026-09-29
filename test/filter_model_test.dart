import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

void main() {
  group('OsFilterCondition', () {
    test('creates with required type', () {
      const condition = OsFilterCondition(type: 'contains', filter: 'test');
      expect(condition.type, 'contains');
      expect(condition.filter, 'test');
      expect(condition.filterTo, isNull);
    });

    test('creates with filterTo for range', () {
      const condition = OsFilterCondition(
        type: 'inRange',
        filter: 10,
        filterTo: 50,
      );
      expect(condition.type, 'inRange');
      expect(condition.filter, 10);
      expect(condition.filterTo, 50);
    });

    test('toJson produces correct map', () {
      const condition = OsFilterCondition(type: 'greaterThan', filter: 42);
      final json = condition.toJson();
      expect(json['type'], 'greaterThan');
      expect(json['filter'], 42);
      expect(json.containsKey('filterTo'), isFalse);
    });

    test('fromJson round-trips correctly', () {
      const original = OsFilterCondition(
        type: 'inRange',
        filter: 10,
        filterTo: 50,
      );
      final json = original.toJson();
      final restored = OsFilterCondition.fromJson(json);
      expect(restored, equals(original));
    });

    test('equality works', () {
      const a = OsFilterCondition(type: 'contains', filter: 'hello');
      const b = OsFilterCondition(type: 'contains', filter: 'hello');
      const c = OsFilterCondition(type: 'contains', filter: 'world');
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('copyWith replaces fields', () {
      const original = OsFilterCondition(type: 'contains', filter: 'hello');
      final copy = original.copyWith(type: 'equals');
      expect(copy.type, 'equals');
      expect(copy.filter, 'hello');
    });
  });

  group('OsColumnFilterModel', () {
    test('single condition model', () {
      const model = OsColumnFilterModel(
        filterType: 'text',
        conditions: [OsFilterCondition(type: 'contains', filter: 'alice')],
      );
      expect(model.isActive, isTrue);
      expect(model.isCombined, isFalse);
    });

    test('combined model with AND', () {
      const model = OsColumnFilterModel(
        filterType: 'text',
        operator: OsJoinOperator.and,
        conditions: [
          OsFilterCondition(type: 'contains', filter: 'alice'),
          OsFilterCondition(type: 'startsWith', filter: 'a'),
        ],
      );
      expect(model.isActive, isTrue);
      expect(model.isCombined, isTrue);
      expect(model.operator, OsJoinOperator.and);
    });

    test('empty model is not active', () {
      const model = OsColumnFilterModel(filterType: 'text', conditions: []);
      expect(model.isActive, isFalse);
    });

    test('model with only empty type is not active', () {
      const model = OsColumnFilterModel(
        filterType: 'text',
        conditions: [OsFilterCondition(type: 'empty')],
      );
      expect(model.isActive, isFalse);
    });

    test('blank/notBlank conditions are active without filter value', () {
      const model = OsColumnFilterModel(
        filterType: 'text',
        conditions: [OsFilterCondition(type: 'blank')],
      );
      expect(model.isActive, isTrue);
    });

    test('toJson single condition produces flat format', () {
      const model = OsColumnFilterModel(
        filterType: 'text',
        conditions: [OsFilterCondition(type: 'contains', filter: 'alice')],
      );
      final json = model.toJson();
      expect(json['filterType'], 'text');
      expect(json['type'], 'contains');
      expect(json['filter'], 'alice');
      expect(json.containsKey('operator'), isFalse);
      expect(json.containsKey('conditions'), isFalse);
    });

    test('toJson combined model produces nested format', () {
      const model = OsColumnFilterModel(
        filterType: 'number',
        operator: OsJoinOperator.or,
        conditions: [
          OsFilterCondition(type: 'equals', filter: 10),
          OsFilterCondition(type: 'equals', filter: 20),
        ],
      );
      final json = model.toJson();
      expect(json['filterType'], 'number');
      expect(json['operator'], 'OR');
      expect(json['conditions'], isList);
      expect((json['conditions'] as List).length, 2);
    });

    test('fromJson single condition', () {
      final json = {'filterType': 'text', 'type': 'startsWith', 'filter': 'A'};
      final model = OsColumnFilterModel.fromJson(json);
      expect(model.filterType, 'text');
      expect(model.conditions.length, 1);
      expect(model.conditions.first.type, 'startsWith');
      expect(model.conditions.first.filter, 'A');
    });

    test('fromJson combined model', () {
      final json = {
        'filterType': 'number',
        'operator': 'AND',
        'conditions': [
          {'type': 'greaterThan', 'filter': 10},
          {'type': 'lessThan', 'filter': 50},
        ],
      };
      final model = OsColumnFilterModel.fromJson(json);
      expect(model.filterType, 'number');
      expect(model.operator, OsJoinOperator.and);
      expect(model.conditions.length, 2);
      expect(model.conditions[0].type, 'greaterThan');
      expect(model.conditions[1].type, 'lessThan');
    });

    test('round-trip serialisation', () {
      const original = OsColumnFilterModel(
        filterType: 'text',
        operator: OsJoinOperator.or,
        conditions: [
          OsFilterCondition(type: 'contains', filter: 'hello'),
          OsFilterCondition(type: 'endsWith', filter: 'world'),
        ],
      );
      final json = original.toJson();
      final restored = OsColumnFilterModel.fromJson(json);
      expect(restored.filterType, original.filterType);
      expect(restored.operator, original.operator);
      expect(restored.conditions.length, original.conditions.length);
      expect(restored.conditions[0], original.conditions[0]);
      expect(restored.conditions[1], original.conditions[1]);
    });
  });

  group('FilterEvaluator — text filter', () {
    const textFilter = OsTextFilter();

    test('contains matches substring', () {
      const model = OsColumnFilterModel(
        filterType: 'text',
        conditions: [OsFilterCondition(type: 'contains', filter: 'lic')],
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: 'Alice',
          model: model,
          filterConfig: textFilter,
        ),
        isTrue,
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: 'Bob',
          model: model,
          filterConfig: textFilter,
        ),
        isFalse,
      );
    });

    test('notContains excludes substring', () {
      const model = OsColumnFilterModel(
        filterType: 'text',
        conditions: [OsFilterCondition(type: 'notContains', filter: 'lic')],
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: 'Alice',
          model: model,
          filterConfig: textFilter,
        ),
        isFalse,
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: 'Bob',
          model: model,
          filterConfig: textFilter,
        ),
        isTrue,
      );
    });

    test('equals matches exact value (case-insensitive)', () {
      const model = OsColumnFilterModel(
        filterType: 'text',
        conditions: [OsFilterCondition(type: 'equals', filter: 'alice')],
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: 'Alice',
          model: model,
          filterConfig: textFilter,
        ),
        isTrue,
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: 'ALICE',
          model: model,
          filterConfig: textFilter,
        ),
        isTrue,
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: 'Bob',
          model: model,
          filterConfig: textFilter,
        ),
        isFalse,
      );
    });

    test('equals with caseSensitive=true', () {
      const sensitiveFilter = OsTextFilter(caseSensitive: true);
      const model = OsColumnFilterModel(
        filterType: 'text',
        conditions: [OsFilterCondition(type: 'equals', filter: 'Alice')],
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: 'Alice',
          model: model,
          filterConfig: sensitiveFilter,
        ),
        isTrue,
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: 'alice',
          model: model,
          filterConfig: sensitiveFilter,
        ),
        isFalse,
      );
    });

    test('notEqual excludes exact match', () {
      const model = OsColumnFilterModel(
        filterType: 'text',
        conditions: [OsFilterCondition(type: 'notEqual', filter: 'alice')],
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: 'Alice',
          model: model,
          filterConfig: textFilter,
        ),
        isFalse,
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: 'Bob',
          model: model,
          filterConfig: textFilter,
        ),
        isTrue,
      );
    });

    test('startsWith matches prefix', () {
      const model = OsColumnFilterModel(
        filterType: 'text',
        conditions: [OsFilterCondition(type: 'startsWith', filter: 'ali')],
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: 'Alice',
          model: model,
          filterConfig: textFilter,
        ),
        isTrue,
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: 'Balice',
          model: model,
          filterConfig: textFilter,
        ),
        isFalse,
      );
    });

    test('endsWith matches suffix', () {
      const model = OsColumnFilterModel(
        filterType: 'text',
        conditions: [OsFilterCondition(type: 'endsWith', filter: 'ice')],
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: 'Alice',
          model: model,
          filterConfig: textFilter,
        ),
        isTrue,
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: 'Bob',
          model: model,
          filterConfig: textFilter,
        ),
        isFalse,
      );
    });

    test('blank matches null and empty string', () {
      const model = OsColumnFilterModel(
        filterType: 'text',
        conditions: [OsFilterCondition(type: 'blank')],
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: null,
          model: model,
          filterConfig: textFilter,
        ),
        isTrue,
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: '',
          model: model,
          filterConfig: textFilter,
        ),
        isTrue,
      );
      // Whitespace-only strings are non-blank values (AG Grid semantics).
      expect(
        FilterEvaluator.evaluate(
          cellValue: '  ',
          model: model,
          filterConfig: textFilter,
        ),
        isFalse,
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: 'Alice',
          model: model,
          filterConfig: textFilter,
        ),
        isFalse,
      );
    });

    test('notBlank matches non-empty values', () {
      const model = OsColumnFilterModel(
        filterType: 'text',
        conditions: [OsFilterCondition(type: 'notBlank')],
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: 'Alice',
          model: model,
          filterConfig: textFilter,
        ),
        isTrue,
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: null,
          model: model,
          filterConfig: textFilter,
        ),
        isFalse,
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: '',
          model: model,
          filterConfig: textFilter,
        ),
        isFalse,
      );
      // Whitespace-only strings are non-blank values (AG Grid semantics).
      expect(
        FilterEvaluator.evaluate(
          cellValue: '  ',
          model: model,
          filterConfig: textFilter,
        ),
        isTrue,
      );
    });

    test('null cell value fails most filters', () {
      const model = OsColumnFilterModel(
        filterType: 'text',
        conditions: [OsFilterCondition(type: 'contains', filter: 'test')],
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: null,
          model: model,
          filterConfig: textFilter,
        ),
        isFalse,
      );
    });

    test('null cell value passes notEqual and notContains', () {
      const notEqualModel = OsColumnFilterModel(
        filterType: 'text',
        conditions: [OsFilterCondition(type: 'notEqual', filter: 'test')],
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: null,
          model: notEqualModel,
          filterConfig: textFilter,
        ),
        isTrue,
      );

      const notContainsModel = OsColumnFilterModel(
        filterType: 'text',
        conditions: [OsFilterCondition(type: 'notContains', filter: 'test')],
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: null,
          model: notContainsModel,
          filterConfig: textFilter,
        ),
        isTrue,
      );
    });

    test('trimInput trims filter value', () {
      const trimFilter = OsTextFilter(trimInput: true);
      const model = OsColumnFilterModel(
        filterType: 'text',
        conditions: [OsFilterCondition(type: 'contains', filter: '  alice  ')],
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: 'Alice',
          model: model,
          filterConfig: trimFilter,
        ),
        isTrue,
      );
    });
  });

  group('FilterEvaluator — number filter', () {
    const numberFilter = OsNumberFilter();

    test('equals matches numeric value', () {
      const model = OsColumnFilterModel(
        filterType: 'number',
        conditions: [OsFilterCondition(type: 'equals', filter: '42')],
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: 42,
          model: model,
          filterConfig: numberFilter,
        ),
        isTrue,
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: 43,
          model: model,
          filterConfig: numberFilter,
        ),
        isFalse,
      );
    });

    test('greaterThan compares correctly', () {
      const model = OsColumnFilterModel(
        filterType: 'number',
        conditions: [OsFilterCondition(type: 'greaterThan', filter: '30')],
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: 40,
          model: model,
          filterConfig: numberFilter,
        ),
        isTrue,
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: 30,
          model: model,
          filterConfig: numberFilter,
        ),
        isFalse,
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: 20,
          model: model,
          filterConfig: numberFilter,
        ),
        isFalse,
      );
    });

    test('greaterThanOrEqual includes boundary', () {
      const model = OsColumnFilterModel(
        filterType: 'number',
        conditions: [
          OsFilterCondition(type: 'greaterThanOrEqual', filter: '30'),
        ],
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: 30,
          model: model,
          filterConfig: numberFilter,
        ),
        isTrue,
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: 29,
          model: model,
          filterConfig: numberFilter,
        ),
        isFalse,
      );
    });

    test('lessThan compares correctly', () {
      const model = OsColumnFilterModel(
        filterType: 'number',
        conditions: [OsFilterCondition(type: 'lessThan', filter: '30')],
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: 20,
          model: model,
          filterConfig: numberFilter,
        ),
        isTrue,
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: 30,
          model: model,
          filterConfig: numberFilter,
        ),
        isFalse,
      );
    });

    test('lessThanOrEqual includes boundary', () {
      const model = OsColumnFilterModel(
        filterType: 'number',
        conditions: [OsFilterCondition(type: 'lessThanOrEqual', filter: '30')],
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: 30,
          model: model,
          filterConfig: numberFilter,
        ),
        isTrue,
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: 31,
          model: model,
          filterConfig: numberFilter,
        ),
        isFalse,
      );
    });

    test('inRange checks between two values', () {
      const model = OsColumnFilterModel(
        filterType: 'number',
        conditions: [
          OsFilterCondition(type: 'inRange', filter: '10', filterTo: '50'),
        ],
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: 25,
          model: model,
          filterConfig: numberFilter,
        ),
        isTrue,
      );
      // Default is exclusive: boundary values do NOT pass
      expect(
        FilterEvaluator.evaluate(
          cellValue: 10,
          model: model,
          filterConfig: numberFilter,
        ),
        isFalse,
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: 50,
          model: model,
          filterConfig: numberFilter,
        ),
        isFalse,
      );
      // Values just inside the range pass
      expect(
        FilterEvaluator.evaluate(
          cellValue: 11,
          model: model,
          filterConfig: numberFilter,
        ),
        isTrue,
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: 49,
          model: model,
          filterConfig: numberFilter,
        ),
        isTrue,
      );
      // Values outside fail
      expect(
        FilterEvaluator.evaluate(
          cellValue: 5,
          model: model,
          filterConfig: numberFilter,
        ),
        isFalse,
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: 55,
          model: model,
          filterConfig: numberFilter,
        ),
        isFalse,
      );
    });

    test('inRange with inRangeInclusive includes boundaries', () {
      const inclusiveFilter = OsNumberFilter(inRangeInclusive: true);
      const model = OsColumnFilterModel(
        filterType: 'number',
        conditions: [
          OsFilterCondition(type: 'inRange', filter: '10', filterTo: '50'),
        ],
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: 10,
          model: model,
          filterConfig: inclusiveFilter,
        ),
        isTrue,
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: 50,
          model: model,
          filterConfig: inclusiveFilter,
        ),
        isTrue,
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: 25,
          model: model,
          filterConfig: inclusiveFilter,
        ),
        isTrue,
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: 5,
          model: model,
          filterConfig: inclusiveFilter,
        ),
        isFalse,
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: 55,
          model: model,
          filterConfig: inclusiveFilter,
        ),
        isFalse,
      );
    });

    test('notEqual excludes matching value', () {
      const model = OsColumnFilterModel(
        filterType: 'number',
        conditions: [OsFilterCondition(type: 'notEqual', filter: '42')],
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: 42,
          model: model,
          filterConfig: numberFilter,
        ),
        isFalse,
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: 43,
          model: model,
          filterConfig: numberFilter,
        ),
        isTrue,
      );
    });

    test('blank matches null and NaN', () {
      const model = OsColumnFilterModel(
        filterType: 'number',
        conditions: [OsFilterCondition(type: 'blank')],
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: null,
          model: model,
          filterConfig: numberFilter,
        ),
        isTrue,
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: double.nan,
          model: model,
          filterConfig: numberFilter,
        ),
        isTrue,
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: 42,
          model: model,
          filterConfig: numberFilter,
        ),
        isFalse,
      );
    });

    test('non-numeric cell value fails numeric comparisons', () {
      const model = OsColumnFilterModel(
        filterType: 'number',
        conditions: [OsFilterCondition(type: 'greaterThan', filter: '30')],
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: 'not a number',
          model: model,
          filterConfig: numberFilter,
        ),
        isFalse,
      );
    });

    test('numeric filter value as num type', () {
      const model = OsColumnFilterModel(
        filterType: 'number',
        conditions: [OsFilterCondition(type: 'equals', filter: 42)],
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: 42,
          model: model,
          filterConfig: numberFilter,
        ),
        isTrue,
      );
    });
  });

  group('FilterEvaluator — number filter blanks (includeBlanksIn*)', () {
    OsColumnFilterModel modelOf(String type, {String? filterTo}) =>
        OsColumnFilterModel(
          filterType: 'number',
          conditions: [
            OsFilterCondition(type: type, filter: '30', filterTo: filterTo),
          ],
        );

    test('null cell fails every comparison operation by default', () {
      const filter = OsNumberFilter();
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
      const filter = OsNumberFilter(includeBlanksInEquals: true);
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
      const filter = OsNumberFilter(includeBlanksInNotEqual: true);
      expect(
        FilterEvaluator.evaluate(
          cellValue: null,
          model: modelOf('notEqual'),
          filterConfig: filter,
        ),
        isTrue,
      );
    });

    test('includeBlanksInLessThan covers lessThanOrEqual too', () {
      const filter = OsNumberFilter(includeBlanksInLessThan: true);
      expect(
        FilterEvaluator.evaluate(
          cellValue: null,
          model: modelOf('lessThan'),
          filterConfig: filter,
        ),
        isTrue,
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: null,
          model: modelOf('lessThanOrEqual'),
          filterConfig: filter,
        ),
        isTrue,
      );
    });

    test('includeBlanksInGreaterThan covers greaterThanOrEqual too', () {
      const filter = OsNumberFilter(includeBlanksInGreaterThan: true);
      expect(
        FilterEvaluator.evaluate(
          cellValue: null,
          model: modelOf('greaterThan'),
          filterConfig: filter,
        ),
        isTrue,
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: null,
          model: modelOf('greaterThanOrEqual'),
          filterConfig: filter,
        ),
        isTrue,
      );
    });

    test('includeBlanksInRange allows null to pass inRange', () {
      const filter = OsNumberFilter(includeBlanksInRange: true);
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
      const withFlag = OsNumberFilter(includeBlanksInEquals: true);
      final model = modelOf('equals');
      expect(
        FilterEvaluator.evaluate(
          cellValue: 30,
          model: model,
          filterConfig: withFlag,
        ),
        isTrue,
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: 31,
          model: model,
          filterConfig: withFlag,
        ),
        isFalse,
      );
    });
  });

  group('FilterEvaluator — combined conditions', () {
    const textFilter = OsTextFilter();
    const numberFilter = OsNumberFilter();

    test('AND requires all conditions to pass', () {
      const model = OsColumnFilterModel(
        filterType: 'text',
        operator: OsJoinOperator.and,
        conditions: [
          OsFilterCondition(type: 'contains', filter: 'a'),
          OsFilterCondition(type: 'endsWith', filter: 'e'),
        ],
      );
      // 'Alice' contains 'a' AND ends with 'e' → true
      expect(
        FilterEvaluator.evaluate(
          cellValue: 'Alice',
          model: model,
          filterConfig: textFilter,
        ),
        isTrue,
      );
      // 'Anna' contains 'a' but doesn't end with 'e' → false
      expect(
        FilterEvaluator.evaluate(
          cellValue: 'Anna',
          model: model,
          filterConfig: textFilter,
        ),
        isFalse,
      );
    });

    test('OR requires at least one condition to pass', () {
      const model = OsColumnFilterModel(
        filterType: 'text',
        operator: OsJoinOperator.or,
        conditions: [
          OsFilterCondition(type: 'equals', filter: 'alice'),
          OsFilterCondition(type: 'equals', filter: 'bob'),
        ],
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: 'Alice',
          model: model,
          filterConfig: textFilter,
        ),
        isTrue,
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: 'Bob',
          model: model,
          filterConfig: textFilter,
        ),
        isTrue,
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: 'Charlie',
          model: model,
          filterConfig: textFilter,
        ),
        isFalse,
      );
    });

    test('number filter with AND: range simulation', () {
      const model = OsColumnFilterModel(
        filterType: 'number',
        operator: OsJoinOperator.and,
        conditions: [
          OsFilterCondition(type: 'greaterThan', filter: '10'),
          OsFilterCondition(type: 'lessThan', filter: '50'),
        ],
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: 25,
          model: model,
          filterConfig: numberFilter,
        ),
        isTrue,
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: 5,
          model: model,
          filterConfig: numberFilter,
        ),
        isFalse,
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: 55,
          model: model,
          filterConfig: numberFilter,
        ),
        isFalse,
      );
    });

    test('inactive model passes all values', () {
      const model = OsColumnFilterModel(filterType: 'text', conditions: []);
      expect(
        FilterEvaluator.evaluate(
          cellValue: 'anything',
          model: model,
          filterConfig: textFilter,
        ),
        isTrue,
      );
    });
  });

  group('Filter utility functions', () {
    test('getDefaultFilterType returns correct defaults', () {
      expect(getDefaultFilterType(const OsTextFilter()), 'contains');
      expect(
        getDefaultFilterType(
          const OsTextFilter(defaultOption: OsTextFilterOption.startsWith),
        ),
        'startsWith',
      );
      expect(getDefaultFilterType(const OsNumberFilter()), 'equals');
      expect(
        getDefaultFilterType(
          const OsNumberFilter(defaultOption: OsNumberFilterOption.greaterThan),
        ),
        'greaterThan',
      );
    });

    test('getAvailableFilterOptions returns all options by default', () {
      final textOptions = getAvailableFilterOptions(const OsTextFilter());
      expect(textOptions, contains('contains'));
      expect(textOptions, contains('notContains'));
      expect(textOptions, contains('equals'));
      expect(textOptions, contains('startsWith'));
      expect(textOptions, contains('endsWith'));
      expect(textOptions, contains('blank'));
      expect(textOptions, contains('notBlank'));

      final numberOptions = getAvailableFilterOptions(const OsNumberFilter());
      expect(numberOptions, contains('equals'));
      expect(numberOptions, contains('greaterThan'));
      expect(numberOptions, contains('lessThan'));
      expect(numberOptions, contains('inRange'));
    });

    test('getAvailableFilterOptions respects filterOptions', () {
      const filter = OsTextFilter(
        filterOptions: [OsTextFilterOption.contains, OsTextFilterOption.equals],
      );
      final options = getAvailableFilterOptions(filter);
      expect(options, ['contains', 'equals']);
    });

    test('getFilterOperationLabel returns symbols', () {
      expect(getFilterOperationLabel('contains'), '≈');
      expect(getFilterOperationLabel('equals'), '=');
      expect(getFilterOperationLabel('greaterThan'), '>');
      expect(getFilterOperationLabel('lessThan'), '<');
      expect(getFilterOperationLabel('inRange'), '⇔');
    });

    test('getNumberOfInputs returns correct counts', () {
      expect(getNumberOfInputs('contains'), 1);
      expect(getNumberOfInputs('equals'), 1);
      expect(getNumberOfInputs('inRange'), 2);
      expect(getNumberOfInputs('blank'), 0);
      expect(getNumberOfInputs('notBlank'), 0);
    });
  });

  group('OsTextFilter configuration', () {
    test('default values', () {
      const filter = OsTextFilter();
      expect(filter.defaultOption, OsTextFilterOption.contains);
      expect(filter.caseSensitive, isFalse);
      expect(filter.trimInput, isFalse);
      expect(filter.maxNumConditions, 2);
      expect(filter.defaultJoinOperator, OsJoinOperator.and);
    });

    test('custom configuration', () {
      const filter = OsTextFilter(
        filterOptions: [
          OsTextFilterOption.equals,
          OsTextFilterOption.startsWith,
        ],
        defaultOption: OsTextFilterOption.equals,
        caseSensitive: true,
        trimInput: false,
        maxNumConditions: 3,
        defaultJoinOperator: OsJoinOperator.or,
      );
      expect(filter.filterOptions!.length, 2);
      expect(filter.defaultOption, OsTextFilterOption.equals);
      expect(filter.caseSensitive, isTrue);
      expect(filter.trimInput, isFalse);
      expect(filter.maxNumConditions, 3);
      expect(filter.defaultJoinOperator, OsJoinOperator.or);
    });
  });

  group('OsNumberFilter configuration', () {
    test('default values', () {
      const filter = OsNumberFilter();
      expect(filter.defaultOption, OsNumberFilterOption.equals);
      expect(filter.maxNumConditions, 2);
      expect(filter.defaultJoinOperator, OsJoinOperator.and);
      expect(filter.inRangeInclusive, isFalse);
      expect(filter.includeBlanksInEquals, isFalse);
      expect(filter.includeBlanksInNotEqual, isFalse);
      expect(filter.includeBlanksInLessThan, isFalse);
      expect(filter.includeBlanksInGreaterThan, isFalse);
      expect(filter.includeBlanksInRange, isFalse);
      expect(filter.debounceMs, isNull);
    });

    test('custom configuration', () {
      const filter = OsNumberFilter(
        filterOptions: [
          OsNumberFilterOption.greaterThan,
          OsNumberFilterOption.lessThan,
        ],
        defaultOption: OsNumberFilterOption.greaterThan,
        maxNumConditions: 1,
        defaultJoinOperator: OsJoinOperator.or,
        inRangeInclusive: true,
        includeBlanksInEquals: true,
        debounceMs: 250,
      );
      expect(filter.filterOptions!.length, 2);
      expect(filter.defaultOption, OsNumberFilterOption.greaterThan);
      expect(filter.maxNumConditions, 1);
      expect(filter.inRangeInclusive, isTrue);
      expect(filter.includeBlanksInEquals, isTrue);
      expect(filter.debounceMs, 250);
    });
  });
}
