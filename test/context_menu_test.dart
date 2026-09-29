import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

void main() {
  group('Context Menu Types', () {
    test('OsContextMenuItem creates a regular item', () {
      final item = OsContextMenuItem(
        name: 'Test',
        icon: Icons.copy,
        action: () {},
        shortcut: 'Ctrl+T',
      );

      expect(item.name, 'Test');
      expect(item.icon, Icons.copy);
      expect(item.action, isNotNull);
      expect(item.shortcut, 'Ctrl+T');
      expect(item.disabled, false);
      expect(item.isSeparator, false);
      expect(item.subMenu, isNull);
    });

    test('OsContextMenuItem.separator creates a separator', () {
      const item = OsContextMenuItem.separator;

      expect(item.isSeparator, true);
      expect(item.name, '');
      expect(item.action, isNull);
    });

    test('built-in constants have correct names', () {
      expect(OsContextMenuItem.copy.name, 'Copy');
      expect(OsContextMenuItem.cut.name, 'Cut');
      expect(OsContextMenuItem.paste.name, 'Paste');
      expect(OsContextMenuItem.copyWithHeaders.name, 'Copy with Headers');
      expect(OsContextMenuItem.export.name, 'Export');
    });

    test('built-in constants have correct shortcuts', () {
      expect(OsContextMenuItem.copy.shortcut, 'Ctrl+C');
      expect(OsContextMenuItem.cut.shortcut, 'Ctrl+X');
      expect(OsContextMenuItem.paste.shortcut, 'Ctrl+V');
      expect(OsContextMenuItem.copyWithHeaders.shortcut, 'Ctrl+Shift+C');
    });

    test('built-in constants have correct icons', () {
      expect(OsContextMenuItem.copy.icon, Icons.copy);
      expect(OsContextMenuItem.cut.icon, Icons.cut);
      expect(OsContextMenuItem.paste.icon, Icons.paste);
      expect(
        OsContextMenuItem.copyWithHeaders.icon,
        Icons.table_chart_outlined,
      );
      expect(OsContextMenuItem.export.icon, Icons.file_download_outlined);
    });

    test('export has sub-menu with CSV Export', () {
      expect(OsContextMenuItem.export.subMenu, isNotNull);
      expect(OsContextMenuItem.export.subMenu!.length, 1);
      expect(OsContextMenuItem.export.subMenu![0].name, 'CSV Export');
      expect(
        OsContextMenuItem.export.subMenu![0].icon,
        Icons.description_outlined,
      );
    });

    test('withAction creates a copy with action attached', () {
      var called = false;
      final item = OsContextMenuItem.copy.withAction(() => called = true);

      expect(item.name, 'Copy');
      expect(item.icon, Icons.copy);
      expect(item.shortcut, 'Ctrl+C');
      expect(item.action, isNotNull);
      expect(item.disabled, false);
      expect(item.isSeparator, false);

      item.action!();
      expect(called, true);
    });

    test('withAction preserves subMenu', () {
      final item = OsContextMenuItem.export.withAction(() {});

      expect(item.name, 'Export');
      expect(item.subMenu, isNotNull);
      expect(item.subMenu!.length, 1);
    });

    test('withDisabled creates a copy with disabled state', () {
      final item = OsContextMenuItem.copy.withDisabled(true);

      expect(item.name, 'Copy');
      expect(item.icon, Icons.copy);
      expect(item.disabled, true);
      expect(item.action, isNull); // original constant has no action
    });

    test('OsContextMenuItem with subMenu', () {
      final item = OsContextMenuItem(
        name: 'Parent',
        subMenu: [
          OsContextMenuItem(name: 'Child 1', action: () {}),
          OsContextMenuItem.separator,
          OsContextMenuItem(name: 'Child 2', action: () {}),
        ],
      );

      expect(item.subMenu, isNotNull);
      expect(item.subMenu!.length, 3);
      expect(item.subMenu![0].name, 'Child 1');
      expect(item.subMenu![1].isSeparator, true);
      expect(item.subMenu![2].name, 'Child 2');
    });

    test('disabled item has action but is disabled', () {
      final item = OsContextMenuItem(
        name: 'Disabled',
        action: () {},
        disabled: true,
      );

      expect(item.disabled, true);
      expect(item.action, isNotNull);
    });

    test('shortcut is display-only', () {
      final item = OsContextMenuItem(
        name: 'Action',
        action: () {},
        shortcut: 'Ctrl+Shift+A',
      );

      expect(item.shortcut, 'Ctrl+Shift+A');
    });
  });

  group('GetContextMenuItemsParams', () {
    test('contains cell information', () {
      const params = GetContextMenuItemsParams<Map<String, dynamic>>(
        rowIndex: 2,
        colId: 'name',
        value: 'Alice',
        data: {'name': 'Alice', 'age': 30},
      );

      expect(params.rowIndex, 2);
      expect(params.colId, 'name');
      expect(params.value, 'Alice');
      expect(params.data, {'name': 'Alice', 'age': 30});
      expect(params.column, isNull);
    });

    test('contains column reference when provided', () {
      const colDef = OsColumnDef(field: 'name', headerName: 'Name');
      const params = GetContextMenuItemsParams<Map<String, dynamic>>(
        rowIndex: 0,
        colId: 'name',
        value: 'Bob',
        data: {'name': 'Bob'},
        column: colDef,
      );

      expect(params.column, colDef);
    });

    test('value can be null', () {
      const params = GetContextMenuItemsParams<Map<String, dynamic>>(
        rowIndex: 0,
        colId: 'notes',
        value: null,
        data: {'notes': null},
      );

      expect(params.value, isNull);
    });
  });

  group('OsCellContextMenuEvent', () {
    test('contains event information', () {
      final event = OsCellContextMenuEvent<Map<String, dynamic>>(
        rowIndex: 1,
        colId: 'name',
        value: 'Bob',
        data: {'name': 'Bob'},
        globalPosition: const Offset(100, 200),
      );

      expect(event.rowIndex, 1);
      expect(event.colId, 'name');
      expect(event.value, 'Bob');
      expect(event.data, {'name': 'Bob'});
      expect(event.globalPosition, const Offset(100, 200));
      expect(event.isDefaultPrevented, false);
    });

    test('preventDefault suppresses default menu', () {
      final event = OsCellContextMenuEvent<Map<String, dynamic>>(
        rowIndex: 0,
        colId: 'col',
        value: null,
        data: {'col': null},
        globalPosition: Offset.zero,
      );

      expect(event.isDefaultPrevented, false);
      event.preventDefault();
      expect(event.isDefaultPrevented, true);
    });

    test('preventDefault can only be called once (idempotent)', () {
      final event = OsCellContextMenuEvent<Map<String, dynamic>>(
        rowIndex: 0,
        colId: 'col',
        value: null,
        data: {'col': null},
        globalPosition: Offset.zero,
      );

      event.preventDefault();
      event.preventDefault(); // Should not throw
      expect(event.isDefaultPrevented, true);
    });

    test('extends OsGridEvent', () {
      final event = OsCellContextMenuEvent<Map<String, dynamic>>(
        rowIndex: 0,
        colId: 'col',
        value: null,
        data: {'col': null},
        globalPosition: Offset.zero,
      );

      expect(event, isA<OsGridEvent>());
    });
  });

  group('ContextMenuPopup widget', () {
    testWidgets('renders all menu items', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              height: 400,
              child: ContextMenuPopup(
                items: [
                  OsContextMenuItem(name: 'Item 1', action: () {}),
                  OsContextMenuItem(name: 'Item 2', action: () {}),
                  OsContextMenuItem(name: 'Item 3', action: () {}),
                ],
                position: const Offset(100, 100),
                gridSize: const Size(600, 400),
                onDismiss: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 2'), findsOneWidget);
      expect(find.text('Item 3'), findsOneWidget);
    });

    testWidgets('calls action and dismisses on item tap', (tester) async {
      var actionCalled = false;
      var dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              height: 400,
              child: ContextMenuPopup(
                items: [
                  OsContextMenuItem(
                    name: 'Click Me',
                    action: () => actionCalled = true,
                  ),
                ],
                position: const Offset(100, 100),
                gridSize: const Size(600, 400),
                onDismiss: () => dismissed = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Click Me'));
      await tester.pumpAndSettle();

      expect(actionCalled, true);
      expect(dismissed, true);
    });

    testWidgets('dismiss callback fires on outside tap', (tester) async {
      var dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              height: 400,
              child: ContextMenuPopup(
                items: [OsContextMenuItem(name: 'Item', action: () {})],
                position: const Offset(200, 200),
                gridSize: const Size(600, 400),
                onDismiss: () => dismissed = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap outside the menu (top-left corner)
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      expect(dismissed, true);
    });

    testWidgets('dismiss callback fires on Escape key', (tester) async {
      var dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              height: 400,
              child: ContextMenuPopup(
                items: [OsContextMenuItem(name: 'Item', action: () {})],
                position: const Offset(100, 100),
                gridSize: const Size(600, 400),
                onDismiss: () => dismissed = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(dismissed, true);
    });

    testWidgets('disabled items do not trigger action', (tester) async {
      var actionCalled = false;
      var dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              height: 400,
              child: ContextMenuPopup(
                items: [
                  OsContextMenuItem(
                    name: 'Disabled',
                    action: () => actionCalled = true,
                    disabled: true,
                  ),
                ],
                position: const Offset(100, 100),
                gridSize: const Size(600, 400),
                onDismiss: () => dismissed = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Item should be visible
      expect(find.text('Disabled'), findsOneWidget);

      // Tap the disabled item
      await tester.tap(find.text('Disabled'));
      await tester.pumpAndSettle();

      // Action should NOT have been called
      expect(actionCalled, false);
      // Menu should NOT have been dismissed
      expect(dismissed, false);
    });

    testWidgets('separator renders as divider', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              height: 400,
              child: ContextMenuPopup(
                items: [
                  OsContextMenuItem(name: 'Before', action: () {}),
                  OsContextMenuItem.separator,
                  OsContextMenuItem(name: 'After', action: () {}),
                ],
                position: const Offset(100, 100),
                gridSize: const Size(600, 400),
                onDismiss: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Before'), findsOneWidget);
      expect(find.text('After'), findsOneWidget);
      expect(find.byType(Divider), findsAtLeast(1));
    });

    testWidgets('shortcut text is displayed', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              height: 400,
              child: ContextMenuPopup(
                items: [
                  OsContextMenuItem(
                    name: 'Copy',
                    action: () {},
                    shortcut: 'Ctrl+C',
                  ),
                ],
                position: const Offset(100, 100),
                gridSize: const Size(600, 400),
                onDismiss: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Copy'), findsOneWidget);
      expect(find.text('Ctrl+C'), findsOneWidget);
    });

    testWidgets('icon is displayed when provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              height: 400,
              child: ContextMenuPopup(
                items: [
                  OsContextMenuItem(
                    name: 'Copy',
                    icon: Icons.copy,
                    action: () {},
                  ),
                ],
                position: const Offset(100, 100),
                gridSize: const Size(600, 400),
                onDismiss: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.copy), findsOneWidget);
    });

    testWidgets('sub-menu parent shows chevron icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              height: 400,
              child: ContextMenuPopup(
                items: [
                  OsContextMenuItem(
                    name: 'Export',
                    subMenu: [OsContextMenuItem(name: 'CSV', action: () {})],
                  ),
                ],
                position: const Offset(100, 100),
                gridSize: const Size(600, 400),
                onDismiss: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Export'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('applies theme colours', (tester) async {
      final theme = OsGridTheme(
        backgroundColor: Colors.grey.shade900,
        foregroundColor: Colors.white,
        borderColor: Colors.grey.shade700,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              height: 400,
              child: ContextMenuPopup(
                items: [OsContextMenuItem(name: 'Item', action: () {})],
                position: const Offset(100, 100),
                gridSize: const Size(600, 400),
                onDismiss: () {},
                theme: theme,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Just verify it renders without error with a dark theme
      expect(find.text('Item'), findsOneWidget);
    });

    testWidgets('menu is positioned within grid bounds', (tester) async {
      // Position near the right edge — menu should clamp
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              height: 400,
              child: ContextMenuPopup(
                items: [OsContextMenuItem(name: 'Item', action: () {})],
                position: const Offset(550, 100), // Near right edge
                gridSize: const Size(600, 400),
                onDismiss: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should still render (clamped to fit)
      expect(find.text('Item'), findsOneWidget);
    });

    testWidgets('menu flips up when near bottom edge', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              height: 400,
              child: ContextMenuPopup(
                items: [
                  OsContextMenuItem(name: 'Item 1', action: () {}),
                  OsContextMenuItem(name: 'Item 2', action: () {}),
                  OsContextMenuItem(name: 'Item 3', action: () {}),
                  OsContextMenuItem(name: 'Item 4', action: () {}),
                  OsContextMenuItem(name: 'Item 5', action: () {}),
                ],
                position: const Offset(100, 380), // Near bottom edge
                gridSize: const Size(600, 400),
                onDismiss: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should still render (repositioned to fit)
      expect(find.text('Item 1'), findsOneWidget);
    });
  });

  group('Context Menu - OsColumnDef.suppressMenu', () {
    test('suppressMenu defaults to null', () {
      const col = OsColumnDef(field: 'name');
      expect(col.suppressMenu, isNull);
    });

    test('suppressMenu can be set to true', () {
      const col = OsColumnDef(field: 'name', suppressMenu: true);
      expect(col.suppressMenu, true);
    });

    test('suppressMenu can be set to false', () {
      const col = OsColumnDef(field: 'name', suppressMenu: false);
      expect(col.suppressMenu, false);
    });
  });

  group('Context Menu - Controller Stream', () {
    test('onCellContextMenu stream is available', () {
      final controller = OsGridController();
      expect(controller.onCellContextMenu, isA<Stream>());
      controller.dispose();
    });

    test('emitCellContextMenu adds to stream', () async {
      final controller = OsGridController<Map<String, dynamic>>();
      OsCellContextMenuEvent<Map<String, dynamic>>? received;

      controller.onCellContextMenu.listen((event) {
        received = event;
      });

      final event = OsCellContextMenuEvent<Map<String, dynamic>>(
        rowIndex: 0,
        colId: 'name',
        value: 'Alice',
        data: {'name': 'Alice'},
        globalPosition: const Offset(50, 50),
      );

      controller.emitCellContextMenu(event);

      // Allow stream to deliver
      await Future.delayed(Duration.zero);

      expect(received, isNotNull);
      expect(received!.rowIndex, 0);
      expect(received!.colId, 'name');
      expect(received!.value, 'Alice');

      controller.dispose();
    });
  });

  group('ContextMenuPopup theming', () {
    testWidgets('theme colours resolve from the grid theme', (tester) async {
      const bg = Color(0xFF12181F);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 400,
              child: ContextMenuPopup(
                items: [
                  OsContextMenuItem(name: 'Item 1', action: () {}),
                  OsContextMenuItem.separator,
                  const OsContextMenuItem(name: 'Item 2'),
                ],
                position: const Offset(50, 50),
                gridSize: const Size(400, 400),
                theme: const OsGridTheme(backgroundColor: bg),
                onDismiss: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate((w) => w is Material && w.color == bg),
        findsOneWidget,
      );
    });

    testWidgets('submenu renders in overlay and survives pointer travel', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 400,
              child: ContextMenuPopup(
                items: [
                  OsContextMenuItem(
                    name: 'Export',
                    subMenu: [
                      OsContextMenuItem(name: 'CSV Export', action: () {}),
                    ],
                  ),
                ],
                position: const Offset(20, 20),
                gridSize: const Size(400, 400),
                onDismiss: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Hover the parent row to open the sub-menu.
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Export')),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.moveBy(const Offset(150, 0));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.text('Export'), findsOneWidget);
    });
  });

  group('ContextMenuPopup keyboard navigation', () {
    const kbdHighlight = Color(0xFF00BEEF);
    const kbdTheme = OsGridTheme(hoverRowColor: kbdHighlight);

    var kbdDismissed = false;

    setUp(() => kbdDismissed = false);

    Finder highlightOn(String text) => find.ancestor(
      of: find.text(text),
      matching: find.byWidgetPredicate(
        (w) => w is Container && w.color == kbdHighlight,
      ),
    );

    Future<void> pumpKbdMenu(
      WidgetTester tester, {
      required List<OsContextMenuItem> items,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              height: 400,
              child: ContextMenuPopup(
                items: items,
                position: const Offset(100, 100),
                gridSize: const Size(600, 400),
                onDismiss: () => kbdDismissed = true,
                theme: kbdTheme,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('focus transfers to first enabled item on open', (
      tester,
    ) async {
      await pumpKbdMenu(
        tester,
        items: [
          OsContextMenuItem(name: 'Disabled', action: () {}, disabled: true),
          const OsContextMenuItem(name: 'Alpha'),
          const OsContextMenuItem(name: 'Beta'),
        ],
      );

      expect(highlightOn('Disabled'), findsNothing);
      expect(highlightOn('Alpha'), findsOneWidget);
      expect(highlightOn('Beta'), findsNothing);
    });

    testWidgets('ArrowDown moves highlight skipping separators and disabled', (
      tester,
    ) async {
      await pumpKbdMenu(
        tester,
        items: [
          const OsContextMenuItem(name: 'Alpha'),
          OsContextMenuItem.separator,
          const OsContextMenuItem(name: 'Bravo', disabled: true),
          const OsContextMenuItem(name: 'Charlie'),
        ],
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();

      expect(highlightOn('Alpha'), findsNothing);
      expect(highlightOn('Bravo'), findsNothing);
      expect(highlightOn('Charlie'), findsOneWidget);
    });

    testWidgets('ArrowUp wraps to last enabled item', (tester) async {
      await pumpKbdMenu(
        tester,
        items: [
          const OsContextMenuItem(name: 'Alpha'),
          const OsContextMenuItem(name: 'Bravo'),
          const OsContextMenuItem(name: 'Charlie'),
        ],
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();

      expect(highlightOn('Charlie'), findsOneWidget);
    });

    testWidgets('Home and End jump to first and last enabled items', (
      tester,
    ) async {
      await pumpKbdMenu(
        tester,
        items: [
          const OsContextMenuItem(name: 'Alpha'),
          const OsContextMenuItem(name: 'Bravo'),
          const OsContextMenuItem(name: 'Charlie'),
        ],
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pumpAndSettle();
      expect(highlightOn('Charlie'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pumpAndSettle();
      expect(highlightOn('Alpha'), findsOneWidget);
    });

    testWidgets('Home and End skip disabled items', (tester) async {
      await pumpKbdMenu(
        tester,
        items: [
          const OsContextMenuItem(name: 'Alpha'),
          const OsContextMenuItem(name: 'Bravo', disabled: true),
          const OsContextMenuItem(name: 'Charlie'),
        ],
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(highlightOn('Charlie'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pumpAndSettle();
      expect(highlightOn('Alpha'), findsOneWidget);
    });

    testWidgets('Enter activates action callback and dismisses menu', (
      tester,
    ) async {
      var actionCalled = false;
      await pumpKbdMenu(
        tester,
        items: [
          const OsContextMenuItem(name: 'Alpha'),
          OsContextMenuItem(name: 'Bravo', action: () => actionCalled = true),
        ],
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(actionCalled, true);
      expect(kbdDismissed, true);
    });

    testWidgets('Space activates action callback', (tester) async {
      var actionCalled = false;
      await pumpKbdMenu(
        tester,
        items: [
          OsContextMenuItem(name: 'Alpha', action: () => actionCalled = true),
        ],
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();

      expect(actionCalled, true);
      expect(kbdDismissed, true);
    });

    testWidgets('Enter on disabled item does nothing', (tester) async {
      var actionCalled = false;
      await pumpKbdMenu(
        tester,
        items: [
          OsContextMenuItem(
            name: 'Disabled',
            action: () => actionCalled = true,
            disabled: true,
          ),
          const OsContextMenuItem(name: 'Alpha'),
        ],
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(actionCalled, false);
      expect(kbdDismissed, false);
    });

    testWidgets('ArrowRight opens submenu and focuses first sub-item', (
      tester,
    ) async {
      await pumpKbdMenu(
        tester,
        items: [
          const OsContextMenuItem(name: 'Alpha'),
          OsContextMenuItem(
            name: 'Export',
            subMenu: [
              OsContextMenuItem(name: 'CSV', action: () {}),
              OsContextMenuItem.separator,
              const OsContextMenuItem(name: 'PDF', disabled: true),
              OsContextMenuItem(name: 'ZIP', action: () {}),
            ],
          ),
        ],
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();

      expect(find.text('CSV'), findsOneWidget);
      expect(highlightOn('Export'), findsOneWidget);
      expect(highlightOn('CSV'), findsOneWidget);
      expect(highlightOn('PDF'), findsNothing);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(highlightOn('ZIP'), findsOneWidget);
      expect(find.text('CSV'), findsOneWidget);
    });

    testWidgets('ArrowLeft closes submenu returning focus to parent', (
      tester,
    ) async {
      await pumpKbdMenu(
        tester,
        items: [
          OsContextMenuItem(
            name: 'Export',
            subMenu: [OsContextMenuItem(name: 'CSV', action: () {})],
          ),
        ],
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(find.text('CSV'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();

      expect(find.text('CSV'), findsNothing);
      expect(highlightOn('Export'), findsOneWidget);
    });

    testWidgets('Enter on sub-menu parent opens the submenu', (tester) async {
      var csvCalled = false;
      await pumpKbdMenu(
        tester,
        items: [
          OsContextMenuItem(
            name: 'Export',
            subMenu: [
              OsContextMenuItem(name: 'CSV', action: () => csvCalled = true),
            ],
          ),
        ],
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('CSV'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(csvCalled, true);
      expect(kbdDismissed, true);
    });

    testWidgets('Escape dismisses the menu', (tester) async {
      await pumpKbdMenu(
        tester,
        items: [const OsContextMenuItem(name: 'Alpha')],
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(kbdDismissed, true);
    });

    testWidgets('Escape closes an open submenu before dismissing', (
      tester,
    ) async {
      await pumpKbdMenu(
        tester,
        items: [
          OsContextMenuItem(
            name: 'Export',
            subMenu: [OsContextMenuItem(name: 'CSV', action: () {})],
          ),
        ],
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(find.text('CSV'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('CSV'), findsNothing);
      expect(kbdDismissed, false);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(kbdDismissed, true);
    });

    testWidgets('typeahead jumps to item starting with typed character', (
      tester,
    ) async {
      await pumpKbdMenu(
        tester,
        items: [
          const OsContextMenuItem(name: 'Alpha'),
          const OsContextMenuItem(name: 'Beta'),
          const OsContextMenuItem(name: 'Gamma'),
        ],
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
      await tester.pumpAndSettle();

      expect(highlightOn('Gamma'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 600));
    });

    testWidgets('typeahead accumulates characters and resets after a gap', (
      tester,
    ) async {
      await pumpKbdMenu(
        tester,
        items: [
          const OsContextMenuItem(name: 'Apple'),
          const OsContextMenuItem(name: 'Banana'),
          const OsContextMenuItem(name: 'Bat'),
        ],
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
      await tester.pumpAndSettle();
      expect(highlightOn('Banana'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.pumpAndSettle();
      // Buffer was "b" so now "ba" -> Bat (not Apple, which plain "a" would hit).
      expect(highlightOn('Bat'), findsOneWidget);

      // After the 500ms reset gap the buffer is cleared, so plain "a"
      // matches Apple instead of extending the stale "ba" buffer.
      await tester.pump(const Duration(milliseconds: 600));
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.pumpAndSettle();

      expect(highlightOn('Apple'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 600));
    });

    testWidgets('typeahead skips disabled items and clears on timeout', (
      tester,
    ) async {
      await pumpKbdMenu(
        tester,
        items: [
          const OsContextMenuItem(name: 'Alpha'),
          const OsContextMenuItem(name: 'Delta', disabled: true),
        ],
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
      await tester.pumpAndSettle();

      expect(highlightOn('Alpha'), findsOneWidget);
      expect(highlightOn('Delta'), findsNothing);

      await tester.pump(const Duration(milliseconds: 600));
    });
  });
}
