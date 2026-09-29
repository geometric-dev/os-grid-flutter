import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';
import 'package:os_grid_flutter/src/theming/grid_popup_surface.dart';

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: SizedBox(width: 400, height: 400, child: child)),
);

GridPopupSurface _surface({double blurSigma = 0, bool showBarrier = true}) {
  return GridPopupSurface(
    anchorRect: Rect.zero,
    anchorMode: PopupAnchorMode.atOrigin,
    gridSize: const Size(400, 400),
    popupWidth: 120,
    estimatedHeight: 80,
    showBarrier: showBarrier,
    blurSigma: blurSigma,
    contentBuilder: (context) => const Material(child: Text('Menu')),
  );
}

ColumnMenuPopup _columnMenu(OsGridTheme? theme) {
  return ColumnMenuPopup(
    columnIndex: 0,
    colDef: const OsColumnDef(field: 'name'),
    anchorRect: const Rect.fromLTWH(10, 10, 24, 24),
    gridSize: const Size(400, 400),
    onAction: (_) {},
    onDismiss: () {},
    theme: theme,
  );
}

void main() {
  group('popup blur opt-in', () {
    testWidgets('default sigma renders no BackdropFilter', (tester) async {
      await tester.pumpWidget(_host(_surface()));
      await tester.pumpAndSettle();

      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.text('Menu'), findsOneWidget);
    });

    testWidgets('sigma > 0 installs a backdrop blur beneath the surface', (
      tester,
    ) async {
      await tester.pumpWidget(_host(_surface(blurSigma: 8)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(BackdropFilter), findsWidgets);
      // Surface content still renders above the blur layer.
      expect(find.text('Menu'), findsOneWidget);
    });

    testWidgets('blur applies even when the barrier is disabled', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(_surface(blurSigma: 6, showBarrier: false)),
      );
      await tester.pumpAndSettle();

      expect(find.byType(BackdropFilter), findsWidgets);
    });

    testWidgets('ColumnMenuPopup picks blur up from OsGridTheme', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(_columnMenu(const OsGridTheme(popupBlurSigma: 12))),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(BackdropFilter), findsWidgets);
    });

    testWidgets('ColumnMenuPopup with default theme has no blur', (
      tester,
    ) async {
      await tester.pumpWidget(_host(_columnMenu(const OsGridTheme())));
      await tester.pumpAndSettle();

      expect(find.byType(BackdropFilter), findsNothing);
    });

    testWidgets('theme presets keep blur off by default', (tester) async {
      expect(OsGridTheme.quartz().popupBlurSigma, 0);
      expect(OsGridTheme.quartzDark().popupBlurSigma, 0);
      expect(OsGridTheme.highContrast().popupBlurSigma, 0);
      expect(OsGridTheme.balham().popupBlurSigma, 0);
      expect(OsGridTheme.alpine().popupBlurSigma, 0);
      expect(OsGridTheme.fromThemeData(ThemeData.light()).popupBlurSigma, 0);
    });
  });
}
