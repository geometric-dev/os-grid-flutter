import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

// ignore: avoid_relative_lib_imports
import '../../../example/lib/demos/community_features/pages/sorting_filtering_page.dart';
// ignore: avoid_relative_lib_imports
import '../../../example/lib/demos/community_features/widgets/feature_panel.dart';
// ignore: avoid_relative_lib_imports
import '../../../example/lib/demos/theme_selector.dart';

void main() {
  group('FeaturePanel widget', () {
    testWidgets('renders as an ExpansionTile with given title', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FeaturePanel(
              title: 'Test Panel',
              children: [Text('Child 1'), Text('Child 2')],
            ),
          ),
        ),
      );

      expect(find.byType(ExpansionTile), findsOneWidget);
      expect(find.text('Test Panel'), findsOneWidget);
    });

    testWidgets('displays children when initially expanded', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FeaturePanel(
              title: 'Controls',
              initiallyExpanded: true,
              children: [Text('Toggle A'), Text('Toggle B')],
            ),
          ),
        ),
      );

      expect(find.text('Toggle A'), findsOneWidget);
      expect(find.text('Toggle B'), findsOneWidget);
    });

    testWidgets('hides children when initially collapsed', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FeaturePanel(
              title: 'Controls',
              initiallyExpanded: false,
              children: [Text('Hidden Child')],
            ),
          ),
        ),
      );

      // The child should not be visible when collapsed
      expect(find.text('Hidden Child'), findsNothing);
    });

    testWidgets('uses default title when none provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: FeaturePanel(children: [Text('Content')])),
        ),
      );

      expect(find.text('Feature Controls'), findsOneWidget);
    });

    testWidgets('wraps children in a Wrap widget for layout', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FeaturePanel(
              title: 'Layout Test',
              children: [Text('A'), Text('B'), Text('C')],
            ),
          ),
        ),
      );

      expect(find.byType(Wrap), findsOneWidget);
    });
  });

  group('SortingFilteringPage feature panel controls', () {
    Widget buildSortingFilteringPage() {
      return MaterialApp(
        home: Scaffold(
          body: SortingFilteringPage(
            themePreset: GridThemePreset.quartz,
            onThemeChanged: (_) {},
          ),
        ),
      );
    }

    testWidgets('contains the expected toggle labels', (tester) async {
      await tester.pumpWidget(buildSortingFilteringPage());
      await tester.pumpAndSettle();

      // Requirement 2.8: Feature panel with toggles for accentedSort,
      // alwaysMultiSort, and suppressMultiSort
      expect(find.text('Accented Sort'), findsOneWidget);
      expect(find.text('Always Multi Sort'), findsOneWidget);
      expect(find.text('Suppress Multi Sort'), findsOneWidget);
    });

    testWidgets('contains Switch widgets for each toggle', (tester) async {
      await tester.pumpWidget(buildSortingFilteringPage());
      await tester.pumpAndSettle();

      // 3 toggles + quick filter text field
      expect(find.byType(Switch), findsNWidgets(3));
    });

    testWidgets('contains a quick filter text input', (tester) async {
      await tester.pumpWidget(buildSortingFilteringPage());
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Quick Filter'), findsOneWidget);
    });

    testWidgets(
      'toggle changes update grid configuration immediately (Property 4)',
      (tester) async {
        await tester.pumpWidget(buildSortingFilteringPage());
        await tester.pumpAndSettle();

        // Initially all toggles should be off (false)
        final switches = tester
            .widgetList<Switch>(find.byType(Switch))
            .toList();
        expect(switches[0].value, isFalse); // Accented Sort
        expect(switches[1].value, isFalse); // Always Multi Sort
        expect(switches[2].value, isFalse); // Suppress Multi Sort

        // Verify the OsGrid initially has accentedSort = false
        final gridFinder = find.byType(OsGrid<Map<String, dynamic>>);
        var grid = tester.widget<OsGrid<Map<String, dynamic>>>(gridFinder);
        expect(grid.accentedSort, isFalse);
        expect(grid.alwaysMultiSort, isFalse);
        expect(grid.suppressMultiSort, isFalse);

        // Toggle "Accented Sort" on
        await tester.tap(find.byType(Switch).first);
        await tester.pumpAndSettle();

        // Verify the grid configuration updated immediately without page reload
        grid = tester.widget<OsGrid<Map<String, dynamic>>>(gridFinder);
        expect(grid.accentedSort, isTrue);

        // Toggle "Always Multi Sort" on
        await tester.tap(find.byType(Switch).at(1));
        await tester.pumpAndSettle();

        grid = tester.widget<OsGrid<Map<String, dynamic>>>(gridFinder);
        expect(grid.alwaysMultiSort, isTrue);

        // Toggle "Suppress Multi Sort" on
        await tester.tap(find.byType(Switch).at(2));
        await tester.pumpAndSettle();

        grid = tester.widget<OsGrid<Map<String, dynamic>>>(gridFinder);
        expect(grid.suppressMultiSort, isTrue);
      },
    );

    testWidgets('toggling a switch off reverts the grid configuration', (
      tester,
    ) async {
      await tester.pumpWidget(buildSortingFilteringPage());
      await tester.pumpAndSettle();

      final gridFinder = find.byType(OsGrid<Map<String, dynamic>>);

      // Toggle "Accented Sort" on
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();

      var grid = tester.widget<OsGrid<Map<String, dynamic>>>(gridFinder);
      expect(grid.accentedSort, isTrue);

      // Toggle "Accented Sort" off
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();

      grid = tester.widget<OsGrid<Map<String, dynamic>>>(gridFinder);
      expect(grid.accentedSort, isFalse);
    });
  });
}
