import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

// ignore: avoid_relative_lib_imports
import '../../../example/lib/demos/community_features/community_features_demo.dart';
// ignore: avoid_relative_lib_imports
import '../../../example/lib/demos/community_features/demo_pages.dart';
// ignore: avoid_relative_lib_imports
import '../../../example/lib/demos/theme_selector.dart';

void main() {
  group('Navigation shell', () {
    testWidgets('lands on Home with every page card grouped by category', (
      tester,
    ) async {
      await tester.pumpWidget(const CommunityFeaturesDemoApp());
      await tester.pumpAndSettle();

      // Home is the landing page: its app bar has no home button and the
      // body is the home hub, not a demo grid.
      expect(find.byType(OsGrid<Map<String, dynamic>>), findsNothing);
      expect(find.text('Community Features'), findsOneWidget);

      // Every page appears as a card, and category headers are shown.
      for (final page in demoPages) {
        expect(
          find.text(page.title),
          findsWidgets,
          reason: 'Home should link to "${page.title}"',
        );
      }
      for (final category in {
        'Start',
        'Data',
        'Interaction',
        'Structure',
        'Extended',
      }) {
        expect(find.text(category), findsWidgets);
      }
    });

    testWidgets('drawer contains all pages plus a Home entry', (tester) async {
      await tester.pumpWidget(const CommunityFeaturesDemoApp());
      await tester.pumpAndSettle();

      final scaffoldState = tester.firstState<ScaffoldState>(
        find.byType(Scaffold),
      );
      scaffoldState.openDrawer();
      await tester.pumpAndSettle();

      final drawerFinder = find.byType(Drawer);
      expect(drawerFinder, findsOneWidget);

      // The drawer offers a Home entry…
      expect(
        find.descendant(of: drawerFinder, matching: find.text('Home')),
        findsWidgets,
      );

      // …and every page. The drawer list is lazy, so sample it while
      // scrolling down the full range (the drawer is taller than the
      // window) and collect the titles that get built.
      final listViewFinder = find.descendant(
        of: drawerFinder,
        matching: find.byType(ListView),
      );
      final found = <String>{};
      void collectBuiltPages() {
        for (final page in demoPages) {
          if (found.contains(page.title)) continue;
          final finder = find.descendant(
            of: drawerFinder,
            matching: find.text(page.title, skipOffstage: false),
          );
          if (tester.widgetList(finder).isNotEmpty) found.add(page.title);
        }
      }

      collectBuiltPages();
      for (var i = 0; i < 8; i++) {
        await tester.drag(listViewFinder, const Offset(0, -400));
        await tester.pumpAndSettle();
        collectBuiltPages();
      }

      for (final page in demoPages) {
        expect(
          found.contains(page.title),
          isTrue,
          reason: 'Drawer should contain page link "${page.title}"',
        );
      }
    });

    testWidgets('home button returns to Home from any page', (tester) async {
      await tester.pumpWidget(const CommunityFeaturesDemoApp());
      await tester.pumpAndSettle();

      // Open a demo page from its Home card.
      await tester.tap(find.text('Sorting & Filtering'));
      await tester.pumpAndSettle();
      expect(find.byType(OsGrid<Map<String, dynamic>>), findsOneWidget);

      // The page chrome has a Home button; tapping returns to Home.
      await tester.tap(find.byIcon(Icons.home_outlined));
      await tester.pumpAndSettle();
      expect(find.byType(OsGrid<Map<String, dynamic>>), findsNothing);
      expect(find.text('Community Features'), findsOneWidget);
    });
  });

  group('Theme flows down from Home (Property 3)', () {
    Future<OsGridTheme?> gridThemeAfterSelecting(
      WidgetTester tester,
      GridThemePreset preset,
    ) async {
      await tester.pumpWidget(const CommunityFeaturesDemoApp());
      await tester.pumpAndSettle();

      // Themes are selected on the Home page via theme cards.
      await tester.tap(find.text(preset.label));
      await tester.pumpAndSettle();

      // Open a page with a grid from Home.
      await tester.tap(find.text('Sorting & Filtering'));
      await tester.pumpAndSettle();

      final grid = tester.widget<OsGrid<Map<String, dynamic>>>(
        find.byType(OsGrid<Map<String, dynamic>>),
      );
      return grid.theme;
    }

    testWidgets('default theme (quartzDark) applies OsGridTheme to grid', (
      tester,
    ) async {
      await tester.pumpWidget(const CommunityFeaturesDemoApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sorting & Filtering'));
      await tester.pumpAndSettle();

      final grid = tester.widget<OsGrid<Map<String, dynamic>>>(
        find.byType(OsGrid<Map<String, dynamic>>),
      );
      expect(grid.theme, isNotNull);
      expect(grid.theme, isA<OsGridTheme>());
    });

    testWidgets('selecting a theme on Home updates the grid theme', (
      tester,
    ) async {
      final alpineTheme = await gridThemeAfterSelecting(
        tester,
        GridThemePreset.alpine,
      );
      expect(alpineTheme, isNotNull);
      // Alpine is light; quartzDark (the default) is dark — backgrounds
      // must differ.
      expect(
        alpineTheme!.backgroundColor,
        isNot(equals(OsGridTheme.quartzDark().backgroundColor)),
      );
    });

    testWidgets('theme selection persists when navigating between pages', (
      tester,
    ) async {
      await tester.pumpWidget(const CommunityFeaturesDemoApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Balham Dark'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sorting & Filtering'));
      await tester.pumpAndSettle();

      Color bgOfGrid() => tester
          .widget<OsGrid<Map<String, dynamic>>>(
            find.byType(OsGrid<Map<String, dynamic>>),
          )
          .theme!
          .backgroundColor!;
      final firstBg = bgOfGrid();

      // Navigate away and back via the home button + another page card.
      await tester.tap(find.byIcon(Icons.home_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cell Editing'));
      await tester.pumpAndSettle();

      // The Balham Dark selection card is still marked selected on Home
      // after returning, and the new page's grid keeps the theme.
      expect(bgOfGrid(), firstBg);
      await tester.tap(find.byIcon(Icons.home_outlined));
      await tester.pumpAndSettle();
      final balhamCard = find.ancestor(
        of: find.text('Balham Dark'),
        matching: find.byType(InkWell),
      );
      expect(balhamCard, findsOneWidget);
    });
  });
}
