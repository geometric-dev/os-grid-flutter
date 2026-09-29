import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';
import 'package:os_grid_flutter/src/theming/grid_popup_surface.dart';

Widget _host(Widget popup) {
  return MaterialApp(
    home: Scaffold(body: SizedBox(width: 400, height: 400, child: popup)),
  );
}

Future<void> pumpPopup(WidgetTester tester, GridPopupSurface surface) async {
  await tester.pumpWidget(_host(surface));
  await tester.pumpAndSettle();
}

GridPopupSurface _surface({
  required WidgetBuilder content,
  GridPopupRole? role,
  String? label,
  OsLocaleText localeText = OsLocaleText.defaultLocale,
}) {
  return GridPopupSurface(
    anchorRect: Rect.zero,
    anchorMode: PopupAnchorMode.atOrigin,
    gridSize: const Size(400, 400),
    popupWidth: 120,
    estimatedHeight: 80,
    showBarrier: false,
    popupRole: role,
    semanticsLabel: label,
    localeText: localeText,
    contentBuilder: content,
  );
}

void main() {
  group('GridPopupSurface semantics', () {
    testWidgets('menu role wraps content in a labeled scoped container', (
      tester,
    ) async {
      await pumpPopup(
        tester,
        _surface(
          role: GridPopupRole.menu,
          content: (context) => const Text('Cut'),
        ),
      );

      final scope = tester.getSemantics(find.bySemanticsLabel('Menu'));
      expect(scope.label, 'Menu');
      expect(scope.getSemanticsData().flagsCollection.scopesRoute, isTrue);
      // Content remains traversable inside the scope with its own label.
      final item = tester.getSemantics(find.text('Cut'));
      expect(item.label, 'Cut');
    });

    testWidgets('filter role resolves the Filter label', (tester) async {
      await pumpPopup(
        tester,
        _surface(
          role: GridPopupRole.filter,
          content: (context) => const Text('Equals'),
        ),
      );

      expect(find.bySemanticsLabel('Filter'), findsOneWidget);
    });

    testWidgets('role labels localize through localeText', (tester) async {
      await pumpPopup(
        tester,
        _surface(
          role: GridPopupRole.menu,
          localeText: const OsLocaleText(menu: 'Menü'),
          content: (context) => const Text('Ausschneiden'),
        ),
      );

      expect(find.bySemanticsLabel('Menü'), findsOneWidget);
    });

    testWidgets('explicit semanticsLabel overrides the role label', (
      tester,
    ) async {
      await pumpPopup(
        tester,
        _surface(
          role: GridPopupRole.menu,
          label: 'Filter on Name',
          content: (context) => const Text('Contains'),
        ),
      );

      expect(find.bySemanticsLabel('Filter on Name'), findsOneWidget);
      expect(find.bySemanticsLabel('Menu'), findsNothing);
    });

    testWidgets('content stays traversable inside the scope', (tester) async {
      await pumpPopup(
        tester,
        _surface(
          role: GridPopupRole.menu,
          content: (context) =>
              const Column(children: [Text('Copy'), Text('Paste')]),
        ),
      );

      expect(tester.getSemantics(find.text('Copy')).label, 'Copy');
      expect(tester.getSemantics(find.text('Paste')).label, 'Paste');
    });

    testWidgets('no wrapper without role or explicit label', (tester) async {
      await pumpPopup(
        tester,
        _surface(content: (context) => const Text('Plain')),
      );

      final semantics = tester.getSemantics(find.text('Plain'));
      expect(semantics.label, 'Plain');
      expect(find.bySemanticsLabel('Dialog'), findsNothing);
    });
  });
}
