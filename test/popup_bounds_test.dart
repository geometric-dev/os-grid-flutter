import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

import 'gestures_test_utils.dart';

/// Popup bounds assertions (quality program v3 item 9).
///
/// Every popup type the grid can open is triggered through its real gesture
/// path (right-click, header icon taps, double-tap) and its rendered panel
/// size is asserted against sane maximums. This directly catches the
/// "popup fills the window" class of layout bug: a popup that ignores its
/// content sizing (or an OverlayPortal child that stretches to the overlay)
/// immediately fails the width/height ceilings below.
///
/// The visible panel of every popup renders through a `Material` inside the
/// nearest `Overlay` (via `OverlayPortal`), which is a sibling of the route
/// pages — NOT a descendant of the app's `Scaffold`. Filtering `Material`
/// elements by Scaffold ancestry therefore isolates exactly the popup panel
/// boxes, however the host app is structured.
void main() {
  /// Maximum bounds each popup type must respect (logical pixels).
  const popupBounds = <String, ({double width, double height})>{
    'context menu': (width: 250, height: 500),
    'context menu submenu': (width: 220, height: 300),
    'filter popup': (width: 300, height: 500),
    'column menu popup': (width: 250, height: 500),
    'tabbed column menu': (width: 400, height: 450),
    'date picker overlay': (width: 350, height: 400),
  };

  Widget wrap(Widget child) => MaterialApp(
    home: Scaffold(body: SizedBox(width: 800, height: 600, child: child)),
  );

  OsGrid<Map<String, dynamic>> grid({
    List<OsColumnDef> columns = const [OsColumnDef(field: 'name')],
    List<Map<String, dynamic>> rows = const [
      {'id': '1', 'name': 'Alice'},
      {'id': '2', 'name': 'Bob'},
    ],
    OsColumnMenuDef? columnMenu,
  }) {
    return OsGrid<Map<String, dynamic>>(
      getRowId: (row) => row['id'] as String,
      columnDefs: columns,
      rowData: rows,
      columnMenu: columnMenu,
    );
  }

  /// Render boxes of every popup panel currently shown in the overlay.
  ///
  /// Each popup's visible panel is wrapped in a `CompositedTransformFollower`
  /// inside its `OverlayPortal` overlay child (see [GridPopupSurface] and the
  /// context-menu submenu). App chrome (routes, Scaffold) never uses one, so
  /// the `Material` descendants of every follower are exactly the popup
  /// panels currently on screen.
  List<RenderBox> popupMaterialBoxes(WidgetTester tester) {
    final followers = find.byWidgetPredicate(
      (w) => w is CompositedTransformFollower,
    );
    if (followers.evaluate().isEmpty) return const [];
    final panels = find.descendant(
      of: followers,
      matching: find.byType(Material),
    );
    return [
      for (final element in tester.elementList(panels))
        if (element.renderObject is RenderBox &&
            (element.renderObject as RenderBox).hasSize)
          element.renderObject as RenderBox,
    ];
  }

  void expectWithinBounds(
    RenderBox box,
    String label, {
    required double maxWidth,
    required double maxHeight,
  }) {
    final size = box.size;
    expect(
      size.width,
      inInclusiveRange(1, maxWidth),
      reason:
          '$label popup rendered ${size.width}x${size.height} — width must be '
          'within [1, $maxWidth] (a width of 0 means it never laid out; a '
          'width above the ceiling means the popup fills its container)',
    );
    expect(
      size.height,
      inInclusiveRange(1, maxHeight),
      reason:
          '$label popup rendered ${size.width}x${size.height} — height must '
          'be within [1, $maxHeight]',
    );
  }

  /// Right-clicks a grid-local point (mouse secondary tap).
  Future<void> rightClickCell(WidgetTester tester, Offset localOffset) async {
    final gridBox = tester.renderObject<RenderBox>(
      find.byType(VirtualisedGrid),
    );
    final gesture = await tester.startGesture(
      gridBox.localToGlobal(localOffset),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
  }

  group('Popup bounds — context menu', () {
    testWidgets('menu panel stays within bounds', (tester) async {
      await tester.pumpWidget(wrap(grid()));
      await tester.pumpAndSettle();

      await rightClickCell(tester, const Offset(75, 69));

      // Default menu opened with its built-in items.
      expect(find.text('Copy'), findsOneWidget);
      expect(find.text('Export'), findsOneWidget);

      final bounds = popupBounds['context menu']!;
      final boxes = popupMaterialBoxes(tester);
      expect(boxes, hasLength(1), reason: 'exactly the context menu panel');
      expectWithinBounds(
        boxes.single,
        'Context menu',
        maxWidth: bounds.width,
        maxHeight: bounds.height,
      );
    });

    testWidgets('submenu panel stays within bounds', (tester) async {
      await tester.pumpWidget(wrap(grid()));
      await tester.pumpAndSettle();

      await rightClickCell(tester, const Offset(75, 69));
      expect(find.text('Export'), findsOneWidget);

      // Tap the Export parent row to open its CSV submenu.
      await tester.tap(find.text('Export'));
      await tester.pumpAndSettle();
      expect(find.text('CSV Export'), findsOneWidget);

      final menuBounds = popupBounds['context menu']!;
      final subBounds = popupBounds['context menu submenu']!;
      final boxes = popupMaterialBoxes(tester);
      expect(
        boxes,
        hasLength(2),
        reason: 'main menu panel + open submenu panel',
      );
      // The submenu renders narrower than the main menu (200 vs 220), so
      // order by width descending to identify them without relying on
      // overlay child order.
      boxes.sort((a, b) => b.size.width.compareTo(a.size.width));
      expectWithinBounds(
        boxes.first,
        'Context menu',
        maxWidth: menuBounds.width,
        maxHeight: menuBounds.height,
      );
      expectWithinBounds(
        boxes.last,
        'Context menu submenu',
        maxWidth: subBounds.width,
        maxHeight: subBounds.height,
      );
    });
  });

  group('Popup bounds — filter popup', () {
    testWidgets('filter panel stays within bounds', (tester) async {
      await tester.pumpWidget(
        wrap(
          grid(
            columns: const [
              OsColumnDef(
                field: 'name',
                headerName: 'Name',
                width: 200,
                filter: OsTextFilter(),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Filter icon sits left of the ⋮ menu icon at the header's right edge:
      // for a 200px column the tap target spans x∈[156, 176], y=24.
      await tapHeader(tester, const Offset(166, 24));
      await tester.pumpAndSettle();

      expect(find.text('Apply'), findsOneWidget);

      final bounds = popupBounds['filter popup']!;
      final boxes = popupMaterialBoxes(tester);
      expect(boxes, hasLength(1), reason: 'exactly the filter popup panel');
      expectWithinBounds(
        boxes.single,
        'Filter popup',
        maxWidth: bounds.width,
        maxHeight: bounds.height,
      );
    });

    testWidgets('set filter panel stays within bounds', (tester) async {
      await tester.pumpWidget(
        wrap(
          grid(
            columns: const [
              OsColumnDef(
                field: 'name',
                headerName: 'Name',
                width: 200,
                filter: OsSetFilter(),
              ),
            ],
            rows: const [
              {'id': '1', 'name': 'Alice'},
              {'id': '2', 'name': 'Bob'},
              {'id': '3', 'name': 'Carol'},
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tapHeader(tester, const Offset(166, 24));
      await tester.pumpAndSettle();

      expect(find.text('Select All'), findsOneWidget);

      final bounds = popupBounds['filter popup']!;
      final boxes = popupMaterialBoxes(tester);
      expect(boxes, hasLength(1), reason: 'exactly the set filter panel');
      expectWithinBounds(
        boxes.single,
        'Filter popup (set filter)',
        maxWidth: bounds.width,
        maxHeight: bounds.height,
      );
    });
  });

  group('Popup bounds — column menus', () {
    testWidgets('flat column menu popup stays within bounds', (tester) async {
      await tester.pumpWidget(
        wrap(
          grid(
            columns: const [
              OsColumnDef(
                field: 'name',
                headerName: 'Name',
                width: 200,
                sortable: true,
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // ⋮ menu icon centre for a 200px column: x = 200 - 8 - 2 = 190, y = 24.
      await tapHeader(tester, const Offset(190, 24));
      await tester.pumpAndSettle();

      expect(find.text('Sort Ascending'), findsOneWidget);

      final bounds = popupBounds['column menu popup']!;
      final boxes = popupMaterialBoxes(tester);
      expect(boxes, hasLength(1), reason: 'exactly the column menu panel');
      expectWithinBounds(
        boxes.single,
        'Column menu popup',
        maxWidth: bounds.width,
        maxHeight: bounds.height,
      );
    });

    testWidgets('tabbed column menu stays within bounds', (tester) async {
      await tester.pumpWidget(
        wrap(
          grid(
            columns: const [
              OsColumnDef(
                field: 'name',
                headerName: 'Name',
                width: 200,
                filter: OsTextFilter(),
              ),
            ],
            columnMenu: const OsColumnMenuDef(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tapHeader(tester, const Offset(190, 24));
      await tester.pumpAndSettle();

      expect(find.text('General'), findsOneWidget);

      final bounds = popupBounds['tabbed column menu']!;
      final boxes = popupMaterialBoxes(tester);
      expect(boxes, hasLength(1), reason: 'exactly the tabbed menu panel');
      expectWithinBounds(
        boxes.single,
        'Tabbed column menu',
        maxWidth: bounds.width,
        maxHeight: bounds.height,
      );
    });
  });

  group('Popup bounds — date picker overlay', () {
    testWidgets('calendar overlay stays within bounds', (tester) async {
      await tester.pumpWidget(
        wrap(
          grid(
            columns: const [
              OsColumnDef(
                field: 'date',
                headerName: 'Date',
                width: 200,
                editable: true,
                cellEditor: OsDateCellEditor(),
              ),
            ],
            rows: [
              {'id': '1', 'date': DateTime(2024, 3, 15)},
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Double-tap the first data cell (header 48 + row height 42/2 = 69).
      const cell = Offset(100, 69);
      final gridBox = tester.renderObject<RenderBox>(
        find.byType(VirtualisedGrid),
      );
      final globalCell = gridBox.localToGlobal(cell);
      await tester.tapAt(globalCell);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(globalCell);
      await tester.pumpAndSettle();

      expect(find.text('March 2024'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);

      final bounds = popupBounds['date picker overlay']!;
      final boxes = popupMaterialBoxes(tester);
      expect(boxes, hasLength(1), reason: 'exactly the calendar panel');
      expectWithinBounds(
        boxes.single,
        'Date picker overlay',
        maxWidth: bounds.width,
        maxHeight: bounds.height,
      );
    });
  });
}
