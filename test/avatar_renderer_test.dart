import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

String? _mockInitialsGetter(dynamic row) => 'XX';

void main() {
  group('OsAvatarOptions', () {
    test('defaults', () {
      const opts = OsAvatarOptions();
      expect(opts.radius, 14.0);
      expect(opts.gap, 8.0);
      expect(opts.color, isNull);
      expect(opts.palette, isNull);
      expect(opts.textStyle, isNull);
      expect(opts.initialsGetter, isNull);
      expect(opts.showLabel, isTrue);
    });

    test('copyWith replaces provided fields', () {
      const opts = OsAvatarOptions();
      final copied = opts.copyWith(
        radius: 20,
        gap: 12,
        color: Colors.red,
        palette: [Colors.blue, Colors.green],
        showLabel: false,
      );
      expect(copied.radius, 20);
      expect(copied.gap, 12);
      expect(copied.color, Colors.red);
      expect(copied.palette, [Colors.blue, Colors.green]);
      expect(copied.showLabel, false);
    });

    test('equality checks values and ignores functions', () {
      const opts1 = OsAvatarOptions(radius: 20, color: Colors.red);
      const opts2 = OsAvatarOptions(radius: 20, color: Colors.red);
      expect(opts1, equals(opts2));
      expect(opts1.hashCode, equals(opts2.hashCode));

      final optsWithFunc1 = opts1.copyWith(initialsGetter: (v) => 'AB');
      final optsWithFunc2 = opts1.copyWith(initialsGetter: (v) => 'CD');

      expect(optsWithFunc1, equals(optsWithFunc2));
    });
  });

  group('AvatarRenderer Widget Tests', () {
    Future<void> pumpAvatarGrid(
      WidgetTester tester, {
      dynamic value = 'John Doe',
      OsGridTheme theme = const OsGridTheme(),
      double columnWidth = 120,
      OsAvatarOptions? options,
      bool isRtl = false,
    }) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Directionality(
              textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
              child: OsGrid(
                key: const Key('grid'),
                theme: theme,
                columnDefs: [
                  OsColumnDef(
                    field: 'avatar',
                    headerName: 'Avatar',
                    width: columnWidth,
                    builtInCellRenderer: OsBuiltInCellRenderer.avatar,
                    avatarOptions: options,
                  ),
                ],
                rowData: [
                  {'avatar': value},
                ],
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('renders basic avatar with inferred initials', (tester) async {
      await pumpAvatarGrid(tester, value: 'Alice Smith');
      await tester.pumpAndSettle();

      final customPaint = tester.widget<CustomPaint>(
        find.byType(CustomPaint).first,
      );
      expect(customPaint, isNotNull);
      await expectLater(
        find.byKey(const Key('grid')),
        matchesGoldenFile('goldens/avatar_basic.png'),
      );
    });

    testWidgets('extracts first grapheme if single word', (tester) async {
      await pumpAvatarGrid(tester, value: 'John');
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(const Key('grid')),
        matchesGoldenFile('goldens/avatar_single_word.png'),
      );
    });

    testWidgets('extracts first graphemes of first two words', (tester) async {
      await pumpAvatarGrid(tester, value: 'John Smith');
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(const Key('grid')),
        matchesGoldenFile('goldens/avatar_two_words.png'),
      );
    });

    testWidgets('respects RTL text direction', (tester) async {
      await pumpAvatarGrid(tester, isRtl: true);
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(const Key('grid')),
        matchesGoldenFile('goldens/avatar_rtl.png'),
      );
    });

    testWidgets('respects initialsGetter', (tester) async {
      await pumpAvatarGrid(
        tester,
        value: {'name': 'John'}, // Data might be a complex object
        options: const OsAvatarOptions(initialsGetter: _mockInitialsGetter),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(const Key('grid')),
        matchesGoldenFile('goldens/avatar_initials_getter.png'),
      );
    });

    testWidgets('skips rendering if value is empty and no initials provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OsGrid(
              key: Key('grid'),
              columnDefs: [
                OsColumnDef(
                  field: 'avatar',
                  headerName: 'Avatar',
                  builtInCellRenderer: OsBuiltInCellRenderer.avatar,
                ),
              ],
              rowData: [
                {'avatar': ''},
                {'avatar': null},
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(const Key('grid')),
        matchesGoldenFile('goldens/avatar_empty.png'),
      );
    });

    testWidgets('handles narrow columns gracefully', (tester) async {
      await pumpAvatarGrid(tester, columnWidth: 20); // Not enough room for text
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(const Key('grid')),
        matchesGoldenFile('goldens/avatar_narrow.png'),
      );
    });

    testWidgets('warm scroll achieves high TextPainterCache hit rate', (
      tester,
    ) async {
      final List<Map<String, dynamic>> rows = List.generate(
        100,
        (i) => {'avatar': 'User $i'},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 400,
              child: OsGrid(
                key: const Key('grid'),
                columnDefs: const [
                  OsColumnDef(
                    field: 'avatar',
                    headerName: 'Avatar',
                    builtInCellRenderer: OsBuiltInCellRenderer.avatar,
                  ),
                ],
                rowData: rows,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final state = tester.state(find.byKey(const Key('grid'))) as dynamic;
      final cache = state.textPainterCacheForTesting;

      final initialMisses = cache.misses as int;
      expect(initialMisses, greaterThan(0));

      cache.hits = 0;

      await tester.fling(
        find.byKey(const Key('grid')),
        const Offset(0, -500),
        2000,
      );

      // Pump several frames to simulate the scroll animation
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      final hits = cache.hits as int;
      // Many frames * many visible cells = hundreds of hits
      expect(hits, greaterThan(50));
    });
  });
}
