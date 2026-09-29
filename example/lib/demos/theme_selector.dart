import 'package:flutter/material.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

/// Available grid theme presets.
enum GridThemePreset {
  quartzDark('Quartz Dark'),
  quartz('Quartz'),
  alpineDark('Alpine Dark'),
  alpine('Alpine'),
  balhamDark('Balham Dark'),
  balham('Balham'),
  material('Material');

  const GridThemePreset(this.label);
  final String label;
}

/// Returns the [OsGridTheme] for a given preset.
OsGridTheme getThemeForPreset(GridThemePreset preset, [BuildContext? context]) {
  switch (preset) {
    case GridThemePreset.quartz:
      return OsGridTheme.quartz();
    case GridThemePreset.quartzDark:
      return OsGridTheme.quartzDark();
    case GridThemePreset.alpine:
      return OsGridTheme.alpine();
    case GridThemePreset.alpineDark:
      return OsGridTheme.alpineDark();
    case GridThemePreset.balham:
      return OsGridTheme.balham();
    case GridThemePreset.balhamDark:
      return OsGridTheme.balhamDark();
    case GridThemePreset.material:
      if (context != null) {
        return OsGridTheme.fromThemeData(Theme.of(context));
      }
      return OsGridTheme.quartz();
  }
}

/// Whether a preset is a dark theme (for app scaffold theming).
bool isPresetDark(GridThemePreset preset) {
  switch (preset) {
    case GridThemePreset.quartzDark:
    case GridThemePreset.alpineDark:
    case GridThemePreset.balhamDark:
      return true;
    default:
      return false;
  }
}
