import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

String? _lowercaseFormatter(String? input) => input?.toLowerCase();

String? _trimFormatter(String? input) => input?.trim();

String? _nullFormatter(String? input) => null;

bool? _alwaysNullMatcher({
  String? filterValue,
  String? cellValue,
  String filterOption = '',
}) => null;

bool? _alwaysFalseMatcher({
  String? filterValue,
  String? cellValue,
  String filterOption = '',
}) => false;

bool? _reversedCellMatcher({
  String? filterValue,
  String? cellValue,
  String filterOption = '',
}) => (cellValue ?? '').split('').reversed.join().contains(filterValue ?? '');

void main() {
  group('OsTextFilter configuration', () {
    test('default values', () {
      const filter = OsTextFilter();
      expect(filter.defaultOption, OsTextFilterOption.contains);
      expect(filter.caseSensitive, isFalse);
      expect(filter.trimInput, isFalse);
      expect(filter.maxNumConditions, 2);
      expect(filter.defaultJoinOperator, OsJoinOperator.and);
      expect(filter.textFormatter, isNull);
      expect(filter.textMatcher, isNull);
      expect(filter.debounceMs, isNull);
    });

    test('custom configuration', () {
      bool? matcher({
        String? filterValue,
        String? cellValue,
        String filterOption = '',
      }) => null;
      final filter = OsTextFilter(
        caseSensitive: true,
        trimInput: true,
        maxNumConditions: 1,
        textFormatter: _lowercaseFormatter,
        textMatcher: matcher,
        debounceMs: 120,
      );
      expect(filter.caseSensitive, isTrue);
      expect(filter.trimInput, isTrue);
      expect(filter.maxNumConditions, 1);
      expect(filter.textFormatter, same(_lowercaseFormatter));
      expect(filter.textMatcher, same(matcher));
      expect(filter.debounceMs, 120);
    });
  });

  group('FilterEvaluator — textFormatter', () {
    test('formatter lowercases the filter while cell keeps its case', () {
      // caseSensitive: true so the framework performs no normalisation —
      // only the filter value passes through the formatter.
      const filter = OsTextFilter(
        caseSensitive: true,
        textFormatter: _lowercaseFormatter,
      );
      const model = OsColumnFilterModel(
        filterType: 'text',
        conditions: [OsFilterCondition(type: 'contains', filter: 'STRAW')],
      );

      // Without the formatter this would fail ('strawberry' keeps its case
      // and contains() is case-sensitive here).
      expect(
        FilterEvaluator.evaluate(
          cellValue: 'strawberry',
          model: model,
          filterConfig: filter,
        ),
        isTrue,
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: 'raspberry',
          model: model,
          filterConfig: filter,
        ),
        isFalse,
      );
    });

    test('formatter runs before trimming', () {
      const filter = OsTextFilter(
        trimInput: true,
        textFormatter: _trimFormatter,
      );
      const model = OsColumnFilterModel(
        filterType: 'text',
        conditions: [OsFilterCondition(type: 'equals', filter: '  Alice  ')],
      );
      // Formatter strips whitespace; without it the equals fails.
      expect(
        FilterEvaluator.evaluate(
          cellValue: 'Alice',
          model: model,
          filterConfig: filter,
        ),
        isTrue,
      );
    });

    test('formatter returning null means no filtering', () {
      const filter = OsTextFilter(textFormatter: _nullFormatter);
      const model = OsColumnFilterModel(
        filterType: 'text',
        conditions: [OsFilterCondition(type: 'contains', filter: 'lic')],
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: 'Alice',
          model: model,
          filterConfig: filter,
        ),
        isTrue,
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: 'Bob',
          model: model,
          filterConfig: filter,
        ),
        isTrue,
      );
    });

    test('blank/notBlank conditions ignore the formatter', () {
      const filter = OsTextFilter(textFormatter: _lowercaseFormatter);
      const blankModel = OsColumnFilterModel(
        filterType: 'text',
        conditions: [OsFilterCondition(type: 'blank')],
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: null,
          model: blankModel,
          filterConfig: filter,
        ),
        isTrue,
      );
    });
  });

  group('FilterEvaluator — textMatcher', () {
    test('custom matcher overrides the built-in contains', () {
      const filter = OsTextFilter(textMatcher: _reversedCellMatcher);
      const model = OsColumnFilterModel(
        filterType: 'text',
        conditions: [OsFilterCondition(type: 'contains', filter: 'lic')],
      );
      // Cell reversed is 'Alice'; direct contains would be false.
      expect(
        FilterEvaluator.evaluate(
          cellValue: 'ecilA',
          model: model,
          filterConfig: filter,
        ),
        isTrue,
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: 'Bob',
          model: model,
          filterConfig: filter,
        ),
        isFalse,
      );
    });

    test('matcher overrides every built-in operation type it is given', () {
      String? seenOption;
      final filter = OsTextFilter(
        textMatcher: ({filterValue, cellValue, filterOption = ''}) {
          seenOption = filterOption;
          return filterOption == 'startsWith';
        },
      );
      for (final type in ['equals', 'notEqual', 'endsWith']) {
        final model = OsColumnFilterModel(
          filterType: 'text',
          conditions: [OsFilterCondition(type: type, filter: 'x')],
        );
        expect(
          FilterEvaluator.evaluate(
            cellValue: 'x',
            model: model,
            filterConfig: filter,
          ),
          isFalse,
          reason: 'matcher verdict should override $type',
        );
      }
      expect(seenOption, 'endsWith');
    });

    test('matcher returning null falls back to built-in logic', () {
      const filter = OsTextFilter(textMatcher: _alwaysNullMatcher);
      const model = OsColumnFilterModel(
        filterType: 'text',
        conditions: [OsFilterCondition(type: 'contains', filter: 'lic')],
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: 'Alice',
          model: model,
          filterConfig: filter,
        ),
        isTrue,
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: 'Bob',
          model: model,
          filterConfig: filter,
        ),
        isFalse,
      );
    });

    test('blank/notBlank conditions never consult the matcher', () {
      const filter = OsTextFilter(textMatcher: _alwaysFalseMatcher);
      const blankModel = OsColumnFilterModel(
        filterType: 'text',
        conditions: [OsFilterCondition(type: 'blank')],
      );
      const notBlankModel = OsColumnFilterModel(
        filterType: 'text',
        conditions: [OsFilterCondition(type: 'notBlank')],
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: null,
          model: blankModel,
          filterConfig: filter,
        ),
        isTrue,
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: 'Alice',
          model: notBlankModel,
          filterConfig: filter,
        ),
        isTrue,
      );
    });

    test('matcher receives the formatted filter value', () {
      String? seen;
      final filter = OsTextFilter(
        textFormatter: _lowercaseFormatter,
        textMatcher: ({filterValue, cellValue, filterOption = ''}) {
          seen = filterValue;
          return null;
        },
      );
      const model = OsColumnFilterModel(
        filterType: 'text',
        conditions: [OsFilterCondition(type: 'contains', filter: 'LIC')],
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: 'Alice',
          model: model,
          filterConfig: filter,
        ),
        isTrue,
      );
      expect(seen, 'lic');
    });

    test('combined conditions route through the matcher per condition', () {
      const filter = OsTextFilter(textMatcher: _reversedCellMatcher);
      const andModel = OsColumnFilterModel(
        filterType: 'text',
        operator: OsJoinOperator.and,
        conditions: [
          OsFilterCondition(type: 'contains', filter: 'lic'),
          OsFilterCondition(type: 'contains', filter: 'Ali'),
        ],
      );
      // Reversed cell of 'ecilA' is 'Alice': both conditions match.
      expect(
        FilterEvaluator.evaluate(
          cellValue: 'ecilA',
          model: andModel,
          filterConfig: filter,
        ),
        isTrue,
      );
      const failingModel = OsColumnFilterModel(
        filterType: 'text',
        operator: OsJoinOperator.and,
        conditions: [
          OsFilterCondition(type: 'contains', filter: 'lic'),
          OsFilterCondition(type: 'contains', filter: 'zzz'),
        ],
      );
      expect(
        FilterEvaluator.evaluate(
          cellValue: 'ecilA',
          model: failingModel,
          filterConfig: filter,
        ),
        isFalse,
      );
    });
  });
}
