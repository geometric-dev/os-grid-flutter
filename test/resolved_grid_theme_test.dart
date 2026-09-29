import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/src/theming/os_grid_theme.dart';
import 'package:os_grid_flutter/src/theming/resolved_grid_theme.dart';

void main() {
  group('ResolvedGridTheme', () {
    test('falls back to Material defaults when theme is null', () {
      final t = ResolvedGridTheme.from(null);

      expect(t.background, Colors.white);
      expect(t.foreground, Colors.black87);
      expect(t.accent, Colors.blue);
      expect(t.border, Colors.grey.shade300);
      expect(t.panelRadius, 6);
      expect(t.controlRadius, 4);
      expect(t.fontFamily, isNull);
    });

    test('resolves core tokens from an explicit theme', () {
      const theme = OsGridTheme(
        backgroundColor: Color(0xFF111111),
        foregroundColor: Color(0xFFEEEEEE),
        accentColor: Color(0xFFFF8800),
        borderColor: Color(0xFF333333),
        chromeBackgroundColor: Color(0xFF222222),
        hoverRowColor: Color(0xFF2A2A2A),
      );
      final t = ResolvedGridTheme.from(theme);

      expect(t.background, const Color(0xFF111111));
      expect(t.foreground, const Color(0xFFEEEEEE));
      expect(t.accent, const Color(0xFFFF8800));
      expect(t.border, const Color(0xFF333333));
      expect(t.chrome, const Color(0xFF222222));
      expect(t.hover, const Color(0xFF2A2A2A));
    });

    test('derives chrome and hover from the palette when not overridden', () {
      const theme = OsGridTheme(
        backgroundColor: Color(0xFFFFFFFF),
        foregroundColor: Color(0xFF000000),
      );
      final t = ResolvedGridTheme.from(theme);

      // Chrome sits between background and foreground.
      expect(t.chrome, isNot(t.background));
      expect(
        Color.lerp(const Color(0xFFFFFFFF), const Color(0xFF000000), 1.0),
        isNot(t.chrome),
      );
    });

    test('derives alpha-based text tiers from foreground', () {
      final t = ResolvedGridTheme.from(null);

      expect(t.mutedForeground, t.foreground.withValues(alpha: 0.62));
      expect(t.hintForeground, t.foreground.withValues(alpha: 0.40));
      expect(t.disabledForeground, t.foreground.withValues(alpha: 0.38));
    });

    test('inherits font family from cell text style', () {
      const theme = OsGridTheme(
        cellTextStyle: TextStyle(fontFamily: 'TestFont'),
      );

      expect(ResolvedGridTheme.from(theme).fontFamily, 'TestFont');
      expect(ResolvedGridTheme.from(null).fontFamily, isNull);
    });

    test('text() applies size, weight, colour and family', () {
      const theme = OsGridTheme(
        cellTextStyle: TextStyle(fontFamily: 'TestFont'),
      );
      final t = ResolvedGridTheme.from(theme);

      final style = t.text(12, fontWeight: FontWeight.w600);
      expect(style.fontSize, 12);
      expect(style.fontWeight, FontWeight.w600);
      expect(style.color, t.foreground);
      expect(style.fontFamily, 'TestFont');

      expect(t.text(11, color: t.accent).color, t.accent);
    });
  });
}
