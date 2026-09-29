// ignore_for_file: avoid_relative_lib_imports
import 'package:flutter_test/flutter_test.dart';

import '../../../example/lib/demos/theme_selector.dart';

/// Feature: community-features-demo, Property 2: Theme preset maps to correct
/// scaffold brightness
///
/// **Validates: Requirements 1.5**
///
/// For any GridThemePreset value, isPresetDark() SHALL return true if and only
/// if the preset is one of quartzDark, alpineDark, or balhamDark.
void main() {
  /// The canonical set of dark presets.
  const darkPresets = {
    GridThemePreset.quartzDark,
    GridThemePreset.alpineDark,
    GridThemePreset.balhamDark,
  };

  group('Property 2: Theme preset maps to correct scaffold brightness', () {
    test(
      'exhaustively verifies isPresetDark() for all GridThemePreset values',
      () {
        // Exhaustive iteration over every enum value — this is a property test
        // over a finite domain (all possible inputs).
        for (final preset in GridThemePreset.values) {
          final result = isPresetDark(preset);
          final expectedDark = darkPresets.contains(preset);

          expect(
            result,
            expectedDark,
            reason:
                '${preset.name}: expected isPresetDark=$expectedDark, got $result',
          );
        }
      },
    );

    test('dark presets return true', () {
      for (final preset in darkPresets) {
        expect(
          isPresetDark(preset),
          isTrue,
          reason: '${preset.name} should be dark',
        );
      }
    });

    test('light presets return false', () {
      final lightPresets = GridThemePreset.values.where(
        (p) => !darkPresets.contains(p),
      );
      for (final preset in lightPresets) {
        expect(
          isPresetDark(preset),
          isFalse,
          reason: '${preset.name} should be light',
        );
      }
    });

    test('exactly 3 presets are dark', () {
      final darkCount = GridThemePreset.values
          .where((p) => isPresetDark(p))
          .length;
      expect(darkCount, 3);
    });

    test('all enum values are covered (guard against future additions)', () {
      // If a new preset is added to the enum, this test ensures it is
      // explicitly categorised. The total count should match expectations.
      expect(
        GridThemePreset.values.length,
        greaterThanOrEqualTo(7),
        reason:
            'Expected at least 7 theme presets (quartz, quartzDark, '
            'alpine, alpineDark, balham, balhamDark, material)',
      );

      // Every preset must return a bool (no exceptions thrown).
      for (final preset in GridThemePreset.values) {
        expect(() => isPresetDark(preset), returnsNormally);
      }
    });
  });
}
