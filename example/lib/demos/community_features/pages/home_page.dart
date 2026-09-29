import 'package:flutter/material.dart';

import '../../theme_selector.dart';
import '../demo_pages.dart';

/// The showcase Home: pick the grid theme once (it flows down to every
/// page), then jump into any demo by category.
///
/// The hub is deliberately compact and eagerly built (a
/// [SingleChildScrollView] over a [Column], not a lazy [ListView]) so every
/// page card exists in the tree regardless of scroll position, and the
/// first categories stay reachable without scrolling in a small window.
class ShowcaseHomePage extends StatelessWidget {
  const ShowcaseHomePage({
    super.key,
    required this.themePreset,
    required this.onThemeChanged,
    required this.onOpenPage,
  });

  final GridThemePreset themePreset;
  final ValueChanged<GridThemePreset> onThemeChanged;
  final ValueChanged<int> onOpenPage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // Group pages by category, preserving navigation order.
    final categories = <String, List<int>>{};
    for (var i = 0; i < demoPages.length; i++) {
      categories.putIfAbsent(demoPages[i].category, () => []).add(i);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('Grid theme', style: theme.textTheme.titleMedium),
              const SizedBox(width: 10),
              Text(
                'Applies to every page of the showcase',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final preset in GridThemePreset.values)
                _ThemeCard(
                  preset: preset,
                  selected: preset == themePreset,
                  onTap: () => onThemeChanged(preset),
                ),
            ],
          ),
          const SizedBox(height: 18),
          for (final entry in categories.entries) ...[
            Text(
              entry.key,
              style: theme.textTheme.titleSmall?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final pageIndex in entry.value)
                  _PageCard(
                    page: demoPages[pageIndex],
                    onTap: () => onOpenPage(pageIndex),
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}

/// A compact theme chip: three swatches, the preset name and a check when
/// selected. Tapping it is the only place the grid theme is changed.
class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  final GridThemePreset preset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final gridTheme = getThemeForPreset(preset, context);
    final scheme = Theme.of(context).colorScheme;
    final swatches = <Color>[
      gridTheme.accentColor ?? scheme.primary,
      gridTheme.backgroundColor ?? scheme.surface,
      gridTheme.foregroundColor ?? scheme.onSurface,
    ];

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
          color: selected
              ? scheme.primaryContainer.withValues(alpha: 0.35)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final c in swatches)
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(right: 2),
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: Border.all(color: scheme.outlineVariant),
                ),
              ),
            const SizedBox(width: 6),
            Text(preset.label, style: Theme.of(context).textTheme.bodyMedium),
            if (selected) ...[
              const SizedBox(width: 4),
              Icon(Icons.check, size: 14, color: scheme.primary),
            ],
          ],
        ),
      ),
    );
  }
}

/// A compact page card: icon, title and a one-line description.
class _PageCard extends StatelessWidget {
  const _PageCard({required this.page, required this.onTap});

  final DemoPage page;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        constraints: const BoxConstraints(minWidth: 190, maxWidth: 240),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(page.icon, size: 18, color: scheme.onSurface),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(page.title, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    page.description,
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
