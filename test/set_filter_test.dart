import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

/// Typed row model exercising the valueGetter code paths.
class _Country {
  _Country(this.name, this.country);

  final String name;
  final String country;
}

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

const _countryRows = [
  {'name': 'Alice', 'country': 'France'},
  {'name': 'Bob', 'country': 'Japan'},
  {'name': 'Carol', 'country': 'France'},
  {'name': 'Dave', 'country': 'Brazil'},
];

void main() {
  group('osSetFilterValueKey', () {
    test('null and empty string share the blank key', () {
      expect(osSetFilterValueKey(null), '');
      expect(osSetFilterValueKey(''), '');
    });

    test('non-blank values use their toString representation', () {
      expect(osSetFilterValueKey('France'), 'France');
      expect(osSetFilterValueKey(42), '42');
      expect(osSetFilterValueKey(3.14), '3.14');
    });
  });

  group('deriveSetFilterKeys', () {
    test('derives unique sorted keys, folding case variants by default', () {
      final keys = deriveSetFilterKeys([
        'brazil',
        'Japan',
        'France',
        'japan',
        'France',
      ]);
      // Case variants share one entry; first-encountered casing is kept.
      expect(keys, ['brazil', 'France', 'Japan']);
    });

    test('caseSensitive derivation keeps case variants distinct', () {
      final keys = deriveSetFilterKeys([
        'brazil',
        'Japan',
        'France',
        'japan',
        'France',
      ], caseSensitive: true);
      expect(keys, ['brazil', 'France', 'Japan', 'japan']);
    });

    test('collapses null and empty string onto one blank key', () {
      final keys = deriveSetFilterKeys(['UK', null, '', 'US']);
      expect(keys, ['', 'UK', 'US']);
    });

    test('caps unique entries', () {
      final keys = deriveSetFilterKeys(
        List<String>.generate(10, (i) => 'v$i'),
        maxUniqueValues: 3,
      );

      // Cap plus one sentinel entry; emits a debugPrint warning.
      expect(keys.length, 4);
    });
  });

  group('OsSetFilter evaluation', () {
    const config = OsSetFilter();

    OsColumnFilterModel setModel(List<String> values) =>
        OsColumnFilterModel(filterType: 'set', values: values);

    bool passes(dynamic cellValue, OsColumnFilterModel model) =>
        FilterEvaluator.evaluate(
          cellValue: cellValue,
          model: model,
          filterConfig: config,
        );

    test('passes when value key is selected, fails otherwise', () {
      final model = setModel(['France', 'Japan']);
      expect(passes('France', model), isTrue);
      expect(passes('Japan', model), isTrue);
      expect(passes('Brazil', model), isFalse);
    });

    test('matches numeric cells via toString key', () {
      final model = setModel(['30']);
      expect(passes(30, model), isTrue);
      expect(passes(25, model), isFalse);
    });

    test('blank cell passes only when blank key explicitly selected', () {
      final withBlanks = setModel(['', 'France']);
      expect(passes(null, withBlanks), isTrue);
      expect(passes('', withBlanks), isTrue);

      final withoutBlanks = setModel(['France']);
      expect(passes(null, withoutBlanks), isFalse);
      expect(passes('', withoutBlanks), isFalse);
    });

    test('empty selection excludes every row', () {
      final model = setModel([]);
      expect(model.isActive, isTrue);
      expect(passes('France', model), isFalse);
      expect(passes(null, model), isFalse);
    });

    test('inactive model (no selection state) passes everything', () {
      const inactive = OsColumnFilterModel(filterType: 'set');
      expect(inactive.isActive, isFalse);
      expect(passes('France', inactive), isTrue);
      expect(passes(null, inactive), isTrue);
    });

    test('case variants pass when a variant is selected (default)', () {
      final model = setModel(['Black']);
      expect(passes('Black', model), isTrue);
      expect(passes('black', model), isTrue);
      expect(passes('BLACK', model), isTrue);
      expect(passes('Blue', model), isFalse);
    });

    test('caseSensitive config matches keys exactly', () {
      const strict = OsSetFilter(caseSensitive: true);
      bool passesStrict(dynamic cellValue, OsColumnFilterModel model) =>
          FilterEvaluator.evaluate(
            cellValue: cellValue,
            model: model,
            filterConfig: strict,
          );

      final model = setModel(['Black']);
      expect(passesStrict('Black', model), isTrue);
      expect(passesStrict('black', model), isFalse);
      expect(passesStrict('BLACK', model), isFalse);
    });
  });

  group('set filter model JSON round-trip', () {
    test('toJson produces AG Grid shape', () {
      const model = OsColumnFilterModel(
        filterType: 'set',
        values: ['France', 'Japan'],
      );
      final json = model.toJson();
      expect(json['filterType'], 'set');
      expect(json['values'], ['France', 'Japan']);
    });

    test('toJson keeps empty selection (active filter)', () {
      const model = OsColumnFilterModel(filterType: 'set', values: []);
      final json = model.toJson();
      expect(json['values'], isEmpty);
      expect(model.isActive, isTrue);
    });

    test('fromJson parses values array', () {
      final model = OsColumnFilterModel.fromJson({
        'filterType': 'set',
        'values': ['a', 'b'],
      });
      expect(model.filterType, 'set');
      expect(model.values, ['a', 'b']);
      expect(model.isActive, isTrue);
    });

    test('fromJson coerces non-string entries to keys', () {
      final model = OsColumnFilterModel.fromJson({
        'filterType': 'set',
        'values': [1, 2.5, null],
      });
      expect(model.values, ['1', '2.5', '']);
    });

    test('round-trips through JSON', () {
      const original = OsColumnFilterModel(
        filterType: 'set',
        values: ['France', 'Japan', ''],
      );
      final restored = OsColumnFilterModel.fromJson(original.toJson());
      expect(restored, equals(original));
    });

    test('equality and copyWith account for values', () {
      const a = OsColumnFilterModel(filterType: 'set', values: ['x']);
      const b = OsColumnFilterModel(filterType: 'set', values: ['x']);
      const c = OsColumnFilterModel(filterType: 'set', values: ['y']);
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a.copyWith(values: ['z']).values, ['z']);
      expect(a.copyWith().values, ['x']);
    });
  });

  group('FilterPopup set filter UI', () {
    testWidgets('renders derived checklist from valuesProvider', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          FilterPopup(
            colId: 'country',
            headerName: 'Country',
            filter: const OsSetFilter(),
            currentModel: null,
            valuesProvider: () => ['Japan', 'France', 'France', null],
            onApply: (_, __) {},
            onDismiss: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Unique sorted entries; blanks render with localised label.
      expect(find.text('(Blanks)'), findsOneWidget);
      expect(find.text('France'), findsOneWidget);
      expect(find.text('Japan'), findsOneWidget);

      // Search box and Select All are present.
      final searchField = tester.widget<TextField>(find.byType(TextField));
      expect(searchField.decoration?.hintText, 'Search...');
      expect(find.text('Select All'), findsOneWidget);

      // defaultToAllSelected → all three entries checked.
      final checkboxes = find.byType(Checkbox);
      expect(checkboxes, findsNWidgets(4)); // select-all + 3 entries
      for (final cb in tester.widgetList<Checkbox>(checkboxes)) {
        expect(cb.value ?? true, isTrue);
      }
    });

    testWidgets('uses fixed supply values instead of provider when provided', (
      tester,
    ) async {
      var providerCalled = false;
      await tester.pumpWidget(
        _wrap(
          FilterPopup(
            colId: 'country',
            headerName: 'Country',
            filter: const OsSetFilter(values: ['Norway', 'Chile']),
            currentModel: null,
            valuesProvider: () {
              providerCalled = true;
              return const [];
            },
            onApply: (_, __) {},
            onDismiss: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(providerCalled, isFalse);
      expect(find.text('Norway'), findsOneWidget);
      expect(find.text('Chile'), findsOneWidget);
    });

    testWidgets('deselects two entries then Apply emits set model', (
      tester,
    ) async {
      OsColumnFilterModel? applied;
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 400,
            height: 600,
            child: FilterPopup(
              colId: 'country',
              headerName: 'Country',
              filter: const OsSetFilter(values: ['Brazil', 'France', 'Japan']),
              currentModel: null,
              onApply: (_, m) => applied = m,
              onDismiss: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Uncheck two of the three entries.
      await tester.tap(find.text('Brazil'));
      await tester.pump();
      await tester.tap(find.text('Japan'));
      await tester.pump();

      // Apply
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      expect(applied, isNotNull);
      expect(applied!.filterType, 'set');
      expect(applied!.isActive, isTrue);
      expect(applied!.values, ['France']);
    });

    testWidgets('Clear removes the model and resets selection', (tester) async {
      OsColumnFilterModel? applied;
      const initial = OsColumnFilterModel(
        filterType: 'set',
        values: ['France'],
      );
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 400,
            height: 600,
            child: FilterPopup(
              colId: 'country',
              headerName: 'Country',
              filter: const OsSetFilter(values: ['Brazil', 'France']),
              currentModel: initial,
              onApply: (_, m) => applied = m,
              onDismiss: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Only France checked initially.
      final franceRow = find.ancestor(
        of: find.text('France'),
        matching: find.byType(Row),
      );
      final franceCheckbox = tester.widget<Checkbox>(
        find.descendant(of: franceRow, matching: find.byType(Checkbox)),
      );
      expect(franceCheckbox.value, isTrue);

      await tester.tap(find.text('Clear'));
      await tester.pump();

      expect(applied, isNull);
    });

    testWidgets('search box narrows visible checklist entries', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FilterPopup(
            colId: 'country',
            headerName: 'Country',
            filter: const OsSetFilter(values: ['Brazil', 'France', 'Japan']),
            currentModel: null,
            onApply: (_, __) {},
            onDismiss: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Brazil'), findsOneWidget);
      expect(find.text('Japan'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'fra');
      // Search narrows after the 150ms debounce quiet period.
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump();

      expect(find.text('France'), findsOneWidget);
      expect(find.text('Brazil'), findsNothing);
      expect(find.text('Japan'), findsNothing);
    });

    testWidgets('search box debounce coalesces rapid keystrokes', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          FilterPopup(
            colId: 'country',
            headerName: 'Country',
            filter: const OsSetFilter(values: ['Brazil', 'France', 'Japan']),
            currentModel: null,
            onApply: (_, __) {},
            onDismiss: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Burst of keystrokes — nothing narrows while input keeps arriving.
      await tester.enterText(find.byType(TextField), 'f');
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Brazil'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'fr');
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Brazil'), findsOneWidget);

      // Quiet period elapses → single narrowing to the final query.
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pump();
      expect(find.text('France'), findsOneWidget);
      expect(find.text('Brazil'), findsNothing);
      expect(find.text('Japan'), findsNothing);
    });

    testWidgets('Select All tri-state toggles every entry', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FilterPopup(
            colId: 'country',
            headerName: 'Country',
            filter: const OsSetFilter(values: ['Brazil', 'France']),
            currentModel: null,
            onApply: (_, __) {},
            onDismiss: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // All selected → Select All shows checked.
      Checkbox selectAll() => tester.widget<Checkbox>(
        find.descendant(
          of: find.ancestor(
            of: find.text('Select All'),
            matching: find.byType(Row),
          ),
          matching: find.byType(Checkbox),
        ),
      );
      expect(selectAll().value, isTrue);

      // Tap → clears all.
      await tester.tap(find.text('Select All'));
      await tester.pump();
      expect(selectAll().value, isFalse);

      // Tap again → selects all.
      await tester.tap(find.text('Select All'));
      await tester.pump();
      expect(selectAll().value, isTrue);
    });

    testWidgets('defaultToAllSelected false starts with nothing selected', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          FilterPopup(
            colId: 'country',
            headerName: 'Country',
            filter: const OsSetFilter(
              values: ['Brazil', 'France'],
              defaultToAllSelected: false,
            ),
            currentModel: null,
            onApply: (_, __) {},
            onDismiss: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (final cb in tester.widgetList<Checkbox>(find.byType(Checkbox))) {
        expect(cb.value, anyOf(isFalse, isNull));
      }
    });

    testWidgets('case variants share one checklist entry by default', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          FilterPopup(
            colId: 'colour',
            headerName: 'Colour',
            filter: const OsSetFilter(
              values: ['Black', 'black', 'BLACK', 'Blue'],
            ),
            currentModel: null,
            onApply: (_, __) {},
            onDismiss: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // One merged entry (first-encountered casing) per case group.
      expect(find.text('Black'), findsOneWidget);
      expect(find.text('black'), findsNothing);
      expect(find.text('BLACK'), findsNothing);
      expect(find.text('Blue'), findsOneWidget);
    });

    testWidgets('caseSensitive keeps case variants distinct in the checklist', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          FilterPopup(
            colId: 'colour',
            headerName: 'Colour',
            filter: const OsSetFilter(
              values: ['Black', 'black', 'BLACK'],
              caseSensitive: true,
            ),
            currentModel: null,
            onApply: (_, __) {},
            onDismiss: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Black'), findsOneWidget);
      expect(find.text('black'), findsOneWidget);
      expect(find.text('BLACK'), findsOneWidget);
    });

    testWidgets('caseSensitive search matches exact casing only', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          FilterPopup(
            colId: 'colour',
            headerName: 'Colour',
            filter: const OsSetFilter(
              values: ['Black', 'black', 'BLACK'],
              caseSensitive: true,
            ),
            currentModel: null,
            onApply: (_, __) {},
            onDismiss: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'black');
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump();

      // Scope to the checklist: the search box itself now contains 'black'.
      final checklist = find.byType(ListView);
      expect(
        find.descendant(of: checklist, matching: find.text('black')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: checklist, matching: find.text('Black')),
        findsNothing,
      );
      expect(
        find.descendant(of: checklist, matching: find.text('BLACK')),
        findsNothing,
      );
    });

    testWidgets('default search matches case-insensitively across variants', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          FilterPopup(
            colId: 'colour',
            headerName: 'Colour',
            filter: const OsSetFilter(values: ['Black', 'black', 'BLACK']),
            currentModel: null,
            onApply: (_, __) {},
            onDismiss: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'BLACK');
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump();

      // The folded entry 'Black' still matches an upper-case query.
      expect(find.text('Black'), findsOneWidget);
    });

    testWidgets('reopen matches model values case-insensitively by default', (
      tester,
    ) async {
      const initial = OsColumnFilterModel(filterType: 'set', values: ['BLACK']);
      await tester.pumpWidget(
        _wrap(
          FilterPopup(
            colId: 'colour',
            headerName: 'Colour',
            filter: const OsSetFilter(values: ['Black', 'Blue']),
            currentModel: initial,
            onApply: (_, __) {},
            onDismiss: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      Checkbox entryCheckbox(String label) => tester.widget<Checkbox>(
        find.descendant(
          of: find.ancestor(of: find.text(label), matching: find.byType(Row)),
          matching: find.byType(Checkbox),
        ),
      );
      expect(entryCheckbox('Black').value, isTrue);
      expect(entryCheckbox('Blue').value, isFalse);
    });

    testWidgets('Select All with active search checks only visible entries', (
      tester,
    ) async {
      OsColumnFilterModel? applied;
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 400,
            height: 600,
            child: FilterPopup(
              colId: 'country',
              headerName: 'Country',
              filter: const OsSetFilter(values: ['Brazil', 'France', 'Japan']),
              currentModel: null,
              onApply: (_, m) => applied = m,
              onDismiss: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Deselect everything first.
      await tester.tap(find.text('Select All'));
      await tester.pump();

      // Search narrows to Japan only, then Select All checks just the
      // visible entry — hidden entries stay unchecked.
      await tester.enterText(find.byType(TextField), 'Jap');
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump();
      expect(find.text('Brazil'), findsNothing);
      expect(find.text('France'), findsNothing);

      await tester.tap(find.text('Select All'));
      await tester.pump();

      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(applied, isNotNull);
      expect(applied!.values, ['Japan']);
    });

    testWidgets('Select All with active search clears only visible entries', (
      tester,
    ) async {
      OsColumnFilterModel? applied;
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 400,
            height: 600,
            child: FilterPopup(
              colId: 'country',
              headerName: 'Country',
              filter: const OsSetFilter(values: ['Brazil', 'France', 'Japan']),
              currentModel: null,
              onApply: (_, m) => applied = m,
              onDismiss: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Everything starts selected. Narrow to Japan and tap Select All:
      // only the visible entry is deselected.
      await tester.enterText(find.byType(TextField), 'Jap');
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump();

      await tester.tap(find.text('Select All'));
      await tester.pump();

      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(applied, isNotNull);
      expect(applied!.values, ['Brazil', 'France']);
    });

    testWidgets('Ctrl+A in the search box selects all filtered values', (
      tester,
    ) async {
      OsColumnFilterModel? applied;
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 400,
            height: 600,
            child: FilterPopup(
              colId: 'country',
              headerName: 'Country',
              filter: const OsSetFilter(values: ['Brazil', 'France', 'Japan']),
              currentModel: null,
              onApply: (_, m) => applied = m,
              onDismiss: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Deselect everything, then narrow to France.
      await tester.tap(find.text('Select All'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'fra');
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump();

      // Ctrl+A inside the focused search box.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      // The filtered entry is checked and the query text is untouched.
      final franceRow = find.ancestor(
        of: find.text('France'),
        matching: find.byType(Row),
      );
      final franceCheckbox = tester.widget<Checkbox>(
        find.descendant(of: franceRow, matching: find.byType(Checkbox)),
      );
      expect(franceCheckbox.value, isTrue);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'fra',
      );

      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(applied, isNotNull);
      expect(applied!.values, ['France']);
    });

    testWidgets('10k values render lazily without jank', (tester) async {
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 400,
            height: 600,
            child: FilterPopup(
              colId: 'values',
              headerName: 'Values',
              filter: OsSetFilter(
                values: List<String>.generate(
                  10000,
                  (i) => 'value${i.toString().padLeft(5, '0')}',
                ),
              ),
              currentModel: null,
              onApply: (_, __) {},
              onDismiss: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Derivation caps the checklist (5,001 keys with a debugPrint
      // warning); the virtualised ListView builds only the viewport's
      // worth of rows.
      expect(find.text('value00000'), findsOneWidget);
      expect(
        tester.widgetList<Checkbox>(find.byType(Checkbox)).length,
        lessThan(40),
      );
      expect(find.text('value05000'), findsNothing);

      // Sliding the window builds fresh rows on demand while the rendered
      // row count stays bounded.
      await tester.drag(find.text('value00000'), const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(find.text('value00025'), findsOneWidget);
      expect(find.text('value00000'), findsNothing);
      expect(
        tester.widgetList<Checkbox>(find.byType(Checkbox)).length,
        lessThan(40),
      );
    });
  });

  group('set filter integration with OsGrid', () {
    Future<void> pumpGrid(
      WidgetTester tester, {
      required OsGridController<Map<String, dynamic>> controller,
    }) async {
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 800,
            height: 600,
            child: OsGrid<Map<String, dynamic>>(
              controller: controller,
              columnDefs: const [
                OsColumnDef(field: 'name', headerName: 'Name', width: 200),
                OsColumnDef(
                  field: 'country',
                  headerName: 'Country',
                  width: 200,
                  filter: OsSetFilter(),
                ),
              ],
              rowData: List.of(_countryRows),
              theme: OsGridTheme.quartzDark(),
              floatingFilter: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    List<Map<String, dynamic>> rowsAfterFilter(
      OsGridController<Map<String, dynamic>> controller,
    ) {
      final rows = <Map<String, dynamic>>[];
      controller.forEachNodeAfterFilter((data, _) {
        rows.add(data);
      });
      return rows;
    }

    testWidgets(
      'popup checklist filters rows on Apply and Clear restores them',
      (tester) async {
        final controller = OsGridController<Map<String, dynamic>>();
        await pumpGrid(tester, controller: controller);
        expect(rowsAfterFilter(controller).length, 4);

        // Open the popup via the country column's header filter icon.
        await tester.tapAt(const Offset(366, 24));
        await tester.pumpAndSettle();
        expect(find.byType(FilterPopup), findsOneWidget);

        // Derived from grid data: four countries present.
        expect(find.text('Brazil'), findsOneWidget);
        expect(find.text('France'), findsOneWidget);
        expect(find.text('Japan'), findsOneWidget);

        // Deselect all, then check France only.
        await tester.tap(find.text('Select All'));
        await tester.pump();
        await tester.tap(find.text('France'));
        await tester.pump();

        await tester.tap(find.text('Apply'));
        await tester.pumpAndSettle();

        expect(find.byType(FilterPopup), findsNothing);
        final filtered = rowsAfterFilter(controller);
        expect(filtered.length, 2);
        expect(filtered.every((r) => r['country'] == 'France'), isTrue);

        // Floating filter row surfaces the read-only selection count.
        final grid = tester.widget<VirtualisedGrid>(
          find.byType(VirtualisedGrid),
        );
        expect(grid.floatingFilterTexts?['country'], '1 selected');

        // Reopen and Clear → unfiltered.
        await tester.tapAt(const Offset(366, 24));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Clear'));
        await tester.pumpAndSettle();

        expect(rowsAfterFilter(controller).length, 4);
        expect(
          tester
                  .widget<VirtualisedGrid>(find.byType(VirtualisedGrid))
                  .floatingFilterTexts
                  ?.containsKey('country') ??
              false,
          isFalse,
        );

        controller.dispose();
      },
    );

    testWidgets('controller.setFilterModel applies a JSON set model', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();
      await pumpGrid(tester, controller: controller);

      controller.setFilterModel({
        'country': {
          'filterType': 'set',
          'values': ['France', 'Japan'],
        },
      });
      await tester.pumpAndSettle();

      final rows = rowsAfterFilter(controller);
      expect(rows.length, 3);
      expect(
        rows.map((r) => r['country']).toSet(),
        equals({'France', 'Japan'}),
      );

      // Round-trip through getFilterModel.
      final exported = controller.getFilterModel();
      expect(exported?['country'], {
        'filterType': 'set',
        'values': ['France', 'Japan'],
      });

      controller.dispose();
    });

    testWidgets('empty selection excludes all rows until cleared', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();
      await pumpGrid(tester, controller: controller);

      controller.setFilterModel({
        'country': {'filterType': 'set', 'values': <String>[]},
      });
      await tester.pumpAndSettle();
      // Note: forEachNodeAfterFilter falls back to raw data when the
      // processed result is empty, so observe via getDisplayedRowCount.
      expect(controller.getDisplayedRowCount(), 0);

      controller.setFilterModel(null);
      await tester.pumpAndSettle();
      expect(controller.getDisplayedRowCount(), 4);

      controller.dispose();
    });

    testWidgets('typed rows resolve through valueGetter', (tester) async {
      final controller = OsGridController<_Country>();
      final data = [
        _Country('Alice', 'France'),
        _Country('Bob', 'Japan'),
        _Country('Carol', 'Brazil'),
      ];

      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 800,
            height: 600,
            child: OsGrid<_Country>(
              controller: controller,
              columnDefs: [
                OsColumnDef<_Country>(
                  field: 'country',
                  headerName: 'Country',
                  width: 200,
                  valueGetter: (params) => params.data.country.toUpperCase(),
                  filter: const OsSetFilter(),
                ),
              ],
              rowData: data,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Keys derive from resolved (upper-cased) values.
      controller.setFilterModel({
        'country': {
          'filterType': 'set',
          'values': ['FRANCE'],
        },
      });
      await tester.pumpAndSettle();

      final rows = <_Country>[];
      controller.forEachNodeAfterFilter((d, _) => rows.add(d));
      expect(rows.length, 1);
      expect(rows.single.name, 'Alice');

      controller.dispose();
    });
  });
}
