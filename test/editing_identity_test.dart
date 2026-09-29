import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

import 'gestures_test_utils.dart';

/// Regression tests: edit sessions are bound to the ROW OBJECT, not the
/// display index, so reorders/removals between session-open and commit
/// cannot misroute writes (AG Grid binds edits to row nodes).
void main() {
  testWidgets('commit after reorder writes to the edited row, not the index', (
    tester,
  ) async {
    final alice = <String, dynamic>{'name': 'Alice', 'value': 'A0'};
    final bob = <String, dynamic>{'name': 'Bob', 'value': 'B0'};
    final carol = <String, dynamic>{'name': 'Carol', 'value': 'C0'};
    final controller = OsGridController<Map<String, dynamic>>();
    var sawStopped = false;
    var wasCancelled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: OsGrid<Map<String, dynamic>>(
              controller: controller,
              columnDefs: const [
                OsColumnDef(field: 'name', editable: true),
                OsColumnDef(field: 'value', editable: true),
              ],
              rowData: [alice, bob, carol],
              singleClickEdit: true,
              onCellEditingStopped: (e) {
                sawStopped = true;
                wasCancelled = e.cancelled;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Open an edit session on Alice (row index 0) via double-tap at the
    // first data cell's centre (header 48px + rowHeight/2 = 69).
    const cell = Offset(225, 69);
    await tapCanvasCell(tester, localOffset: cell, settleMs: 50);
    await tapCanvasCell(tester, localOffset: cell);

    // Mutate the buffered text while the session is open.
    final textField = find.byType(TextField);
    expect(textField, findsOneWidget);
    await tester.enterText(textField, 'A-EDITED');

    // Underneath the session, reverse the dataset (Alice moves to index 2)
    // using the SAME map instances so identity survives.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: OsGrid<Map<String, dynamic>>(
              controller: controller,
              columnDefs: const [
                OsColumnDef(field: 'name', editable: true),
                OsColumnDef(field: 'value', editable: true),
              ],
              rowData: [carol, bob, alice],
              singleClickEdit: true,
              onCellEditingStopped: (e) {
                sawStopped = true;
                wasCancelled = e.cancelled;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Commit via the public editing API.
    controller.stopEditing();
    await tester.pumpAndSettle();

    // debug: ignore('sawStopped=$sawStopped cancelled=$wasCancelled');
    expect(sawStopped, isTrue, reason: 'stop event must fire');
    expect(
      wasCancelled,
      isFalse,
      reason: 'row still exists; identity resolution should find it',
    );
    expect(
      alice['value'],
      'A-EDITED',
      reason: 'the edited row object receives the committed value',
    );
    expect(
      bob['value'],
      'B0',
      reason: 'rows shifted under the session keep their values',
    );
    expect(carol['value'], 'C0');
  });

  testWidgets('commit after row removal discards input with cancelled stop', (
    tester,
  ) async {
    final alice = <String, dynamic>{'name': 'Alice', 'value': 'A0'};
    final bob = <String, dynamic>{'name': 'Bob', 'value': 'B0'};
    final controller = OsGridController<Map<String, dynamic>>();
    var stoppedCancelled = false;
    Object? stoppedNewValue;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: OsGrid<Map<String, dynamic>>(
              controller: controller,
              columnDefs: const [
                OsColumnDef(field: 'name', editable: true),
                OsColumnDef(field: 'value', editable: true),
              ],
              rowData: [alice, bob],
              singleClickEdit: true,
              onCellEditingStopped: (event) {
                stoppedCancelled = event.cancelled;
                stoppedNewValue = event.newValue;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    const cell = Offset(225, 69);
    await tapCanvasCell(tester, localOffset: cell, settleMs: 50);
    await tapCanvasCell(tester, localOffset: cell);
    await tester.enterText(find.byType(TextField), 'SHOULD-NOT-LAND');

    // Remove the edited row from the dataset entirely.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: OsGrid<Map<String, dynamic>>(
              controller: controller,
              columnDefs: const [
                OsColumnDef(field: 'name', editable: true),
                OsColumnDef(field: 'value', editable: true),
              ],
              rowData: [bob],
              singleClickEdit: true,
              onCellEditingStopped: (event) {
                stoppedCancelled = event.cancelled;
                stoppedNewValue = event.newValue;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    controller.stopEditing();
    await tester.pumpAndSettle();

    expect(
      stoppedCancelled,
      isTrue,
      reason: 'removing the edited row yields a cancelled stop',
    );
    expect(
      stoppedNewValue,
      'A0',
      reason: 'no partial write leaks out; original value reported',
    );
    expect(alice['value'], 'A0', reason: 'removed row is never written');
    expect(bob['value'], 'B0');
  });
}
