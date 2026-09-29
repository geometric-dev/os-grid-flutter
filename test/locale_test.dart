import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

void main() {
  group('OsLocaleText', () {
    test('default constructor provides English defaults', () {
      const locale = OsLocaleText();

      expect(locale.noRowsToShow, 'No Rows To Show');
      expect(locale.page, 'Page');
      expect(locale.of, 'of');
      expect(locale.to, 'to');
      expect(locale.more, 'more');
      expect(locale.next, 'Next');
      expect(locale.previous, 'Previous');
      expect(locale.first, 'First');
      expect(locale.last, 'Last');
      expect(locale.loadingOoo, 'Loading...');
      expect(locale.selectAll, 'Select All');
      expect(locale.searchOoo, 'Search...');
      expect(locale.filterOoo, 'Filter...');
      expect(locale.applyFilter, 'Apply Filter');
      expect(locale.resetFilter, 'Reset Filter');
      expect(locale.clearFilter, 'Clear Filter');
      expect(locale.equals, 'Equals');
      expect(locale.notEqual, 'Not equal');
      expect(locale.contains, 'Contains');
      expect(locale.notContains, 'Not contains');
      expect(locale.startsWith, 'Starts with');
      expect(locale.endsWith, 'Ends with');
      expect(locale.lessThan, 'Less than');
      expect(locale.lessThanOrEqual, 'Less than or equal');
      expect(locale.greaterThan, 'Greater than');
      expect(locale.greaterThanOrEqual, 'Greater than or equal');
      expect(locale.inRange, 'In range');
      expect(locale.blank, 'Blank');
      expect(locale.notBlank, 'Not blank');
      expect(locale.andCondition, 'AND');
      expect(locale.orCondition, 'OR');
      expect(locale.pinLeft, 'Pin Left');
      expect(locale.pinRight, 'Pin Right');
      expect(locale.noPin, 'No Pin');
      expect(locale.autosizeThisColumn, 'Autosize This Column');
      expect(locale.autosizeAllColumns, 'Autosize All Columns');
      expect(locale.resetColumns, 'Reset Columns');
      expect(locale.sortAscending, 'Sort Ascending');
      expect(locale.sortDescending, 'Sort Descending');
      expect(locale.clearSort, 'Clear Sort');
    });

    test('constructor allows overriding individual keys', () {
      const locale = OsLocaleText(
        noRowsToShow: 'Keine Zeilen',
        page: 'Seite',
        sortAscending: 'Aufsteigend sortieren',
      );

      expect(locale.noRowsToShow, 'Keine Zeilen');
      expect(locale.page, 'Seite');
      expect(locale.sortAscending, 'Aufsteigend sortieren');
      // Non-overridden keys remain English
      expect(locale.next, 'Next');
      expect(locale.contains, 'Contains');
    });

    test('fromMap creates instance from string map', () {
      final locale = OsLocaleText.fromMap({
        'noRowsToShow': 'Aucune ligne',
        'page': 'Page',
        'equals': 'Égal',
      });

      expect(locale.noRowsToShow, 'Aucune ligne');
      expect(locale.page, 'Page');
      expect(locale.equals, 'Égal');
      // Non-overridden keys remain English
      expect(locale.next, 'Next');
    });

    test('fromMap ignores unknown keys', () {
      final locale = OsLocaleText.fromMap({
        'unknownKey': 'some value',
        'anotherUnknown': 'another value',
        'noRowsToShow': 'Custom',
      });

      expect(locale.noRowsToShow, 'Custom');
      // Should not throw, unknown keys are silently ignored
    });

    test('toMap returns all keys with current values', () {
      const locale = OsLocaleText(
        noRowsToShow: 'Custom No Rows',
        page: 'Custom Page',
      );

      final map = locale.toMap();

      expect(map['noRowsToShow'], 'Custom No Rows');
      expect(map['page'], 'Custom Page');
      expect(map['next'], 'Next'); // Default
      expect(
        map.length,
        OsLocaleText.defaultLocale.toMap().length,
      ); // All keys present
    });

    test('getLocaleText resolves known key', () {
      const locale = OsLocaleText(noRowsToShow: 'Nada');

      expect(locale.getLocaleText('noRowsToShow', 'fallback'), 'Nada');
    });

    test('getLocaleText returns defaultValue for unknown key', () {
      const locale = OsLocaleText();

      expect(locale.getLocaleText('unknownKey', 'my fallback'), 'my fallback');
    });

    test('defaultLocale is the English instance', () {
      expect(OsLocaleText.defaultLocale.noRowsToShow, 'No Rows To Show');
      expect(OsLocaleText.defaultLocale.page, 'Page');
    });

    test('equality works correctly', () {
      const a = OsLocaleText(noRowsToShow: 'A');
      const b = OsLocaleText(noRowsToShow: 'A');
      const c = OsLocaleText(noRowsToShow: 'B');

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a.hashCode, b.hashCode);
    });

    test('roundtrip through toMap and fromMap preserves values', () {
      const original = OsLocaleText(
        noRowsToShow: 'Custom 1',
        page: 'Custom 2',
        sortAscending: 'Custom 3',
      );

      final roundtripped = OsLocaleText.fromMap(original.toMap());

      expect(roundtripped, equals(original));
    });
  });

  group('OsLocaleText accessibility keys', () {
    test('semantics keys have English defaults', () {
      const locale = OsLocaleText();

      expect(locale.sortedAscending, 'sorted ascending');
      expect(locale.sortedDescending, 'sorted descending');
      expect(locale.selected, 'Selected');
      expect(locale.notSelected, 'Not selected');
      expect(locale.rowGroup, 'Row Group');
      expect(locale.children, 'children');
      expect(locale.rowsSelected, '{n} rows selected');
      expect(locale.gridSummary, '{rows} rows, {selected} selected');
      expect(locale.menu, 'Menu');
      expect(locale.dialog, 'Dialog');
    });

    test('semantics keys are overridable individually', () {
      final locale = OsLocaleText.fromMap({
        'sortedAscending': 'aufsteigend sortiert',
        'sortedDescending': 'absteigend sortiert',
        'selected': 'Ausgewählt',
        'notSelected': 'Nicht ausgewählt',
        'rowGroup': 'Zeilengruppe',
        'children': 'Kinder',
        'rowsSelected': '{n} Zeilen ausgewählt',
        'gridSummary': '{rows} Zeilen, {selected} ausgewählt',
        'menu': 'Menü',
        'dialog': 'Dialog',
      });

      expect(locale.sortedAscending, 'aufsteigend sortiert');
      expect(locale.sortedDescending, 'absteigend sortiert');
      expect(locale.selected, 'Ausgewählt');
      expect(locale.notSelected, 'Nicht ausgewählt');
      expect(locale.rowGroup, 'Zeilengruppe');
      expect(locale.children, 'Kinder');
      expect(locale.rowsSelected, '{n} Zeilen ausgewählt');
      expect(locale.gridSummary, '{rows} Zeilen, {selected} ausgewählt');
      expect(locale.menu, 'Menü');
      expect(locale.dialog, 'Dialog');
    });

    test('semantics keys participate in equality and round-trip', () {
      const original = OsLocaleText(menu: 'Menu', dialog: 'Dialog');
      final restored = OsLocaleText.fromMap(original.toMap());

      expect(restored, equals(original));
      expect(original.hashCode, restored.hashCode);

      const a = OsLocaleText(children: 'Kinder');
      const b = OsLocaleText();
      expect(a, isNot(equals(b)));
    });
  });

  group('OsGridController - locale resolution', () {
    test('getLocaleText returns default English when no locale set', () {
      final controller = OsGridController<Map<String, dynamic>>();

      expect(
        controller.getLocaleText('noRowsToShow', 'No Rows To Show'),
        'No Rows To Show',
      );
    });

    test('getLocaleText returns value from localeText', () {
      final controller = OsGridController<Map<String, dynamic>>();
      controller.localeText = const OsLocaleText(noRowsToShow: 'Nix da');

      expect(
        controller.getLocaleText('noRowsToShow', 'No Rows To Show'),
        'Nix da',
      );
    });

    test('getLocaleText falls back to defaultValue for unknown key', () {
      final controller = OsGridController<Map<String, dynamic>>();
      controller.localeText = const OsLocaleText();

      expect(controller.getLocaleText('unknownKey', 'Fallback'), 'Fallback');
    });

    test('getLocaleText callback overrides localeText value', () {
      final controller = OsGridController<Map<String, dynamic>>();
      controller.localeText = const OsLocaleText(noRowsToShow: 'From locale');
      controller.getLocaleTextCallback = (key, defaultValue) {
        if (key == 'noRowsToShow') return 'From callback';
        return defaultValue;
      };

      expect(
        controller.getLocaleText('noRowsToShow', 'English'),
        'From callback',
      );
    });

    test('getLocaleText callback receives localeText value as default', () {
      final controller = OsGridController<Map<String, dynamic>>();
      controller.localeText = const OsLocaleText(page: 'Seite');

      String? receivedDefault;
      controller.getLocaleTextCallback = (key, defaultValue) {
        if (key == 'page') receivedDefault = defaultValue;
        return defaultValue;
      };

      controller.getLocaleText('page', 'Page');
      expect(receivedDefault, 'Seite');
    });

    test('setting localeText to null resets to defaults', () {
      final controller = OsGridController<Map<String, dynamic>>();
      controller.localeText = const OsLocaleText(noRowsToShow: 'Custom');
      expect(
        controller.getLocaleText('noRowsToShow', 'No Rows To Show'),
        'Custom',
      );

      controller.localeText = null;
      expect(
        controller.getLocaleText('noRowsToShow', 'No Rows To Show'),
        'No Rows To Show',
      );
    });
  });

  group('OsGrid widget - locale integration', () {
    testWidgets('localeText is passed to controller', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              localeText: const OsLocaleText(noRowsToShow: 'Leer'),
              columnDefs: [
                const OsColumnDef<Map<String, dynamic>>(field: 'name'),
              ],
              rowData: const [],
            ),
          ),
        ),
      );

      expect(
        controller.getLocaleText('noRowsToShow', 'No Rows To Show'),
        'Leer',
      );
    });

    testWidgets('getLocaleText callback is passed to controller', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              getLocaleText: (key, defaultValue) =>
                  key == 'page' ? 'Pagina' : defaultValue,
              columnDefs: [
                const OsColumnDef<Map<String, dynamic>>(field: 'name'),
              ],
              rowData: const [],
            ),
          ),
        ),
      );

      expect(controller.getLocaleText('page', 'Page'), 'Pagina');
      expect(controller.getLocaleText('next', 'Next'), 'Next');
    });

    testWidgets('locale updates when widget rebuilds', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              localeText: const OsLocaleText(noRowsToShow: 'Version 1'),
              columnDefs: [
                const OsColumnDef<Map<String, dynamic>>(field: 'name'),
              ],
              rowData: const [],
            ),
          ),
        ),
      );

      expect(
        controller.getLocaleText('noRowsToShow', 'No Rows To Show'),
        'Version 1',
      );

      // Rebuild with different locale
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              localeText: const OsLocaleText(noRowsToShow: 'Version 2'),
              columnDefs: [
                const OsColumnDef<Map<String, dynamic>>(field: 'name'),
              ],
              rowData: const [],
            ),
          ),
        ),
      );

      expect(
        controller.getLocaleText('noRowsToShow', 'No Rows To Show'),
        'Version 2',
      );
    });

    testWidgets('works without localeText (defaults)', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              columnDefs: [
                const OsColumnDef<Map<String, dynamic>>(field: 'name'),
              ],
              rowData: const [],
            ),
          ),
        ),
      );

      expect(
        controller.getLocaleText('noRowsToShow', 'No Rows To Show'),
        'No Rows To Show',
      );
      expect(controller.getLocaleText('page', 'Page'), 'Page');
    });
  });

  group('OsLocaleText popup surface keys', () {
    test('new keys have English defaults', () {
      const locale = OsLocaleText();

      // Tabs and panel titles.
      expect(locale.general, 'General');
      expect(locale.columns, 'Columns');
      expect(locale.filters, 'Filters');
      expect(locale.filter, 'Filter');

      // Common actions.
      expect(locale.clear, 'Clear');
      expect(locale.apply, 'Apply');
      expect(locale.pinColumn, 'Pin Column');
      expect(locale.plusCondition, '+ Condition');
      expect(locale.expandAll, 'Expand All');
      expect(locale.collapseAll, 'Collapse All');
      expect(locale.deselectAll, 'Deselect All');

      // Placeholders.
      expect(locale.fromOoo, 'From...');
      expect(locale.toOoo, 'To...');
      expect(locale.filterValueOoo, 'Filter value...');
      expect(locale.dateFormatOoo, 'YYYY-MM-DD');

      // Filters tool panel summaries.
      expect(locale.noActiveFilter, 'No active filter');
      expect(locale.active, 'Active');
      expect(locale.isBlank, 'Is blank');
      expect(locale.isNotBlank, 'Is not blank');

      // Date-specific operations (parity with filter evaluator labels).
      expect(locale.before, 'Before');
      expect(locale.beforeOrOn, 'Before or on');
      expect(locale.after, 'After');
      expect(locale.afterOrOn, 'After or on');

      // Date picker.
      expect(locale.today, 'Today');
      expect(locale.selectTime, 'Select time');
      expect(locale.cancel, 'Cancel');
      expect(locale.ok, 'OK');

      expect(locale.monthNames.first, 'January');
      expect(locale.monthNames.last, 'December');
      expect(locale.monthNames.length, 12);
      expect(locale.dayOfWeekInitials, [
        'Mo',
        'Tu',
        'We',
        'Th',
        'Fr',
        'Sa',
        'Su',
      ]);
    });

    test('fromMap overrides new keys', () {
      final locale = OsLocaleText.fromMap({
        'general': 'Allgemein',
        'columns': 'Spalten',
        'today': 'Heute',
        'cancel': 'Abbrechen',
        'ok': 'Los',
      });

      expect(locale.general, 'Allgemein');
      expect(locale.columns, 'Spalten');
      expect(locale.today, 'Heute');
      expect(locale.cancel, 'Abbrechen');
      expect(locale.ok, 'Los');
    });

    test('toMap round-trips new keys through fromMap', () {
      const locale = OsLocaleText();
      final restored = OsLocaleText.fromMap(locale.toMap());

      expect(restored, locale);
    });

    test('equality accounts for the new keys', () {
      const a = OsLocaleText();
      final b = OsLocaleText.fromMap({'today': 'Morgen'});
      const c = OsLocaleText();

      expect(a, c);
      expect(a, isNot(b));
      expect(a.hashCode, c.hashCode);
    });
  });
}
