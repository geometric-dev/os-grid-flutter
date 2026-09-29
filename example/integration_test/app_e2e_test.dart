import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';
import 'package:os_grid_flutter_example/demos/community_features/community_features_demo.dart';

/// End-to-end integration test for the community features demo app
/// (quality program v3 item 9).
///
/// Boots the full example app and drives real interactions through the
/// widget tree: navigation, feature toggles, grid rendering, popup bounds,
/// row selection and the clipboard pipeline.
///
/// Run on a device/window:
/// ```
/// flutter test integration_test/app_e2e_test.dart -d windows
/// ```
///
/// It also runs under a plain `flutter test integration_test/` host run;
/// screenshots are best-effort there (no driver attached) and never fail
/// the test.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// Best-effort screenshot. `takeScreenshot` requires the driver side
  /// (present with `-d <device>`); on host runs the future never completes,
  /// so it is bounded by a timeout and never fails the test.
  Future<void> screenshot(String name) async {
    try {
      await binding.takeScreenshot(name).timeout(const Duration(seconds: 5));
    } catch (_) {
      // Driver not attached — screenshot skipped.
    }
  }

  /// Right-clicks a grid-local point (mouse secondary button).
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

  /// Render boxes of the visible popup panels (the `Material` descendants of
  /// the `CompositedTransformFollower`s used exclusively by popup overlay
  /// children — see test/popup_bounds_test.dart for the full rationale).
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

  /// Taps a grid-local point through a real down → pump → up sequence and
  /// waits out the double-tap recognizer's 300ms window (data-cell taps
  /// resolve only once it expires; host tests cover this via their settle
  /// pumps, but the live binding needs a real-time wait).
  Future<void> tapGridPoint(WidgetTester tester, Offset localOffset) async {
    final gridBox = tester.renderObject<RenderBox>(
      find.byType(VirtualisedGrid),
    );
    final gesture = await tester.startGesture(
      gridBox.localToGlobal(localOffset),
    );
    await tester.pump();
    await gesture.up();
    await Future<void>.delayed(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
  }

  testWidgets('community features demo: navigate, tree data, context menu, '
      'selection + clipboard', (tester) async {
    // 1. Boot the full example app (lands on the What's New page).
    await tester.pumpWidget(const CommunityFeaturesDemoApp());
    await tester.pumpAndSettle();
    expect(find.text("What's New"), findsWidgets);
    await screenshot('01-app-launched');

    // 2. Navigate to the Enterprise Features page via the drawer.
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enterprise Features'));
    await tester.pumpAndSettle();
    expect(find.text('Enterprise Features'), findsWidgets);
    expect(find.byType(VirtualisedGrid), findsOneWidget);
    await screenshot('02-enterprise-page');

    // 3. Verify the flat grid renders leaf rows (paginated, 25 per page)
    //    and record them for comparison.
    Map<String, dynamic> firstFlatRow = tester
        .widget<VirtualisedGrid>(find.byType(VirtualisedGrid))
        .rowData
        .first;
    expect(firstFlatRow['id'], 'emp-0');
    expect(firstFlatRow[RowGroupKeys.kIsGroupRow], isNull);

    // 4. Toggle tree data — rows must change to grouped display rows.
    await tester.tap(find.byKey(const Key('enterprise-tree-data-toggle')));
    await tester.pumpAndSettle();
    final treeRows = tester
        .widget<VirtualisedGrid>(find.byType(VirtualisedGrid))
        .rowData;
    expect(
      treeRows.first[RowGroupKeys.kIsGroupRow],
      isTrue,
      reason: 'tree mode renders a synthetic group row first',
    );
    await screenshot('03-tree-data-on');

    // 5. Restore flat mode for the selection + clipboard flow.
    await tester.tap(find.byKey(const Key('enterprise-tree-data-toggle')));
    await tester.pumpAndSettle();
    final flatRows = tester
        .widget<VirtualisedGrid>(find.byType(VirtualisedGrid))
        .rowData;
    expect(flatRows.first[RowGroupKeys.kIsGroupRow], isNull);

    // 6. Open the context menu on the first data cell and verify its
    //    rendered panel stays within sane bounds while open.
    await rightClickCell(tester, const Offset(75, 69));
    expect(find.text('Copy'), findsOneWidget);
    expect(find.text('Export'), findsOneWidget);
    final boxes = popupMaterialBoxes(tester);
    expect(boxes, hasLength(1), reason: 'exactly the context menu panel');
    expect(boxes.single.size.width, inInclusiveRange(1, 250));
    expect(boxes.single.size.height, inInclusiveRange(1, 500));
    await screenshot('04-context-menu-open');

    // 7. Close it with Escape.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Copy'), findsNothing);

    // 8. Select the first two rows via their per-column checkboxes
    //    (department column, default 150 wide; row centres at y = 69, 111).
    await tapGridPoint(tester, const Offset(75, 69));
    await tapGridPoint(tester, const Offset(75, 111));

    final demoGrid = tester.widget<OsGrid<Map<String, dynamic>>>(
      find.byWidgetPredicate((w) => w is OsGrid<Map<String, dynamic>>),
    );
    final demoController = demoGrid.controller!;
    expect(
      demoController.getSelectedIds(),
      {'emp-0', 'emp-1'},
      reason: 'both checkbox taps selected their rows',
    );
    // 9. Copy via the context menu and verify the clipboard received the
    //    selected rows.
    await rightClickCell(tester, const Offset(150, 69));
    expect(find.text('Copy'), findsOneWidget);
    await tester.tap(find.text('Copy'));
    await tester.pumpAndSettle();
    expect(find.text('Copy'), findsNothing);

    final clip = await Clipboard.getData(Clipboard.kTextPlain);
    final text = clip?.text ?? '';
    expect(text, contains('Alice Johnson'), reason: 'row 0 (emp-0) copied');
    expect(text, contains('Bob Smith'), reason: 'row 1 (emp-1) copied');
    await screenshot('05-copied-selection');
  });
}
