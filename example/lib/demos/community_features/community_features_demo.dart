/// Community Features Demo — showcases the community (MIT/free) features of
/// the os_grid_flutter package across categorised demo pages.
///
/// Run standalone: `flutter run -t lib/demos/community_features/community_features_demo.dart`
library;

import 'package:flutter/material.dart';

import 'demo_pages.dart';
import 'pages/home_page.dart';
import '../theme_selector.dart';

void main() => runApp(const CommunityFeaturesDemoApp());

/// Root widget for the Community Features Demo application.
///
/// Single source of truth for the selected [GridThemePreset]: the theme is
/// chosen on the Home page and flows down to every demo page. Navigation is
/// page-index based — -1 means Home.
class CommunityFeaturesDemoApp extends StatefulWidget {
  const CommunityFeaturesDemoApp({super.key});

  @override
  State<CommunityFeaturesDemoApp> createState() =>
      _CommunityFeaturesDemoAppState();
}

class _CommunityFeaturesDemoAppState extends State<CommunityFeaturesDemoApp> {
  GridThemePreset _themePreset = GridThemePreset.quartzDark;
  int _currentPageIndex = -1;

  void _openPage(int index) => setState(() => _currentPageIndex = index);
  void _goHome() => setState(() => _currentPageIndex = -1);

  @override
  Widget build(BuildContext context) {
    final isDark = isPresetDark(_themePreset);
    return MaterialApp(
      title: 'OS Grid Flutter — Community Features Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      home: _NavigationShell(
        themePreset: _themePreset,
        currentPageIndex: _currentPageIndex,
        onThemeChanged: (preset) => setState(() => _themePreset = preset),
        onOpenPage: _openPage,
        onGoHome: _goHome,
      ),
    );
  }
}

/// The navigation shell: AppBar with a Home button and page stepper, a
/// category-grouped drawer, and Home as the landing page.
class _NavigationShell extends StatelessWidget {
  const _NavigationShell({
    required this.themePreset,
    required this.currentPageIndex,
    required this.onThemeChanged,
    required this.onOpenPage,
    required this.onGoHome,
  });

  final GridThemePreset themePreset;
  final int currentPageIndex;

  /// The one-way theme flow: Home is the only place that changes it.
  final ValueChanged<GridThemePreset> onThemeChanged;
  final ValueChanged<int> onOpenPage;
  final VoidCallback onGoHome;

  bool get _isHome => currentPageIndex < 0;

  @override
  Widget build(BuildContext context) {
    final onDemoPage = !_isHome;
    final canPrev = onDemoPage && currentPageIndex > 0;
    final canNext = onDemoPage && currentPageIndex < demoPages.length - 1;

    return Scaffold(
      appBar: AppBar(
        leading: onDemoPage
            ? IconButton(
                tooltip: 'Back to Home',
                icon: const Icon(Icons.home_outlined),
                onPressed: onGoHome,
              )
            : const Icon(Icons.apps),
        title: Text(
          _isHome ? 'Community Features' : demoPages[currentPageIndex].title,
        ),
        actions: [
          if (onDemoPage) ...[
            IconButton(
              tooltip: 'Previous page',
              icon: const Icon(Icons.chevron_left),
              onPressed: canPrev
                  ? () => onOpenPage(currentPageIndex - 1)
                  : null,
            ),
            IconButton(
              tooltip: 'Next page',
              icon: const Icon(Icons.chevron_right),
              onPressed: canNext
                  ? () => onOpenPage(currentPageIndex + 1)
                  : null,
            ),
            // Theme stays visible for reference on demo pages; changing it
            // is Home's job — tapping navigates there.
            TextButton.icon(
              onPressed: onGoHome,
              icon: Icon(
                isPresetDark(themePreset) ? Icons.dark_mode : Icons.light_mode,
                size: 18,
              ),
              label: Text(
                themePreset.label,
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
          const SizedBox(width: 8),
        ],
      ),
      drawer: _buildDrawer(context),
      body: _isHome
          ? ShowcaseHomePage(
              themePreset: themePreset,
              onThemeChanged: onThemeChanged,
              onOpenPage: onOpenPage,
            )
          : demoPages[currentPageIndex].builder(themePreset, onThemeChanged),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final categories = <String>[];
    for (final page in demoPages) {
      if (!categories.contains(page.category)) categories.add(page.category);
    }

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: scheme.primaryContainer),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Community Features',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                FilledButton.tonalIcon(
                  onPressed: () {
                    Navigator.pop(context);
                    onGoHome();
                  },
                  icon: const Icon(Icons.home_outlined, size: 18),
                  label: const Text('Home'),
                ),
              ],
            ),
          ),
          for (final category in categories) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                category.toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.primary,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            for (var i = 0; i < demoPages.length; i++)
              if (demoPages[i].category == category)
                ListTile(
                  leading: Icon(demoPages[i].icon),
                  title: Text(demoPages[i].title),
                  dense: true,
                  selected: i == currentPageIndex,
                  onTap: () {
                    Navigator.pop(context);
                    onOpenPage(i);
                  },
                ),
          ],
        ],
      ),
    );
  }
}
