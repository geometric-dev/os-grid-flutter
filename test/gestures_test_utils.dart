import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

RenderBox _gridBox(WidgetTester tester) =>
    tester.renderObject(find.byType(VirtualisedGrid)) as RenderBox;

/// Taps a grid-local canvas point and flushes gesture timers.
///
/// Wraps the recurring renderObject lookup + [WidgetTester.tapAt] +
/// timed pump + `pumpAndSettle` pattern: [settleMs] lets double-tap
/// recognizers resolve before assertions run (defaults to 350ms, safely past
/// the framework's double-tap timeout).
Future<void> tapCanvasCell(
  WidgetTester tester, {
  required Offset localOffset,
  int settleMs = 350,
}) async {
  await tester.tapAt(_gridBox(tester).localToGlobal(localOffset));
  await tester.pump(Duration(milliseconds: settleMs));
  await tester.pumpAndSettle();
}

/// Variant of [tapCanvasCell] for points inside the header row.
Future<void> tapHeader(WidgetTester tester, Offset localOffset) =>
    tapCanvasCell(tester, localOffset: localOffset);
