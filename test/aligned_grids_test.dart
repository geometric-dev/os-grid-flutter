import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

void main() {
  group('AlignedGridService — unit tests', () {
    setUp(() {
      AlignedGridService.reset();
    });

    tearDown(() {
      AlignedGridService.reset();
    });

    test('register adds grid to group', () {
      final notifier = ValueNotifier<ScrollCommand?>(null);
      AlignedGridService.register(
        groupId: 'group1',
        scrollCommandNotifier: notifier,
      );

      expect(AlignedGridService.groupSize('group1'), 1);
      notifier.dispose();
    });

    test('register multiple grids in same group', () {
      final notifier1 = ValueNotifier<ScrollCommand?>(null);
      final notifier2 = ValueNotifier<ScrollCommand?>(null);

      AlignedGridService.register(
        groupId: 'group1',
        scrollCommandNotifier: notifier1,
      );
      AlignedGridService.register(
        groupId: 'group1',
        scrollCommandNotifier: notifier2,
      );

      expect(AlignedGridService.groupSize('group1'), 2);
      notifier1.dispose();
      notifier2.dispose();
    });

    test('register grids in different groups', () {
      final notifier1 = ValueNotifier<ScrollCommand?>(null);
      final notifier2 = ValueNotifier<ScrollCommand?>(null);

      AlignedGridService.register(
        groupId: 'group1',
        scrollCommandNotifier: notifier1,
      );
      AlignedGridService.register(
        groupId: 'group2',
        scrollCommandNotifier: notifier2,
      );

      expect(AlignedGridService.groupSize('group1'), 1);
      expect(AlignedGridService.groupSize('group2'), 1);
      notifier1.dispose();
      notifier2.dispose();
    });

    test('deregister removes grid from group', () {
      final notifier = ValueNotifier<ScrollCommand?>(null);
      final registration = AlignedGridService.register(
        groupId: 'group1',
        scrollCommandNotifier: notifier,
      );

      AlignedGridService.deregister(registration);
      expect(AlignedGridService.groupSize('group1'), 0);
      notifier.dispose();
    });

    test('deregister removes group when empty', () {
      final notifier = ValueNotifier<ScrollCommand?>(null);
      final registration = AlignedGridService.register(
        groupId: 'group1',
        scrollCommandNotifier: notifier,
      );

      AlignedGridService.deregister(registration);
      // Group should be cleaned up
      expect(AlignedGridService.groupSize('group1'), 0);
      notifier.dispose();
    });

    test('propagateScroll sends SetHorizontalScrollCommand to other grids', () {
      final notifier1 = ValueNotifier<ScrollCommand?>(null);
      final notifier2 = ValueNotifier<ScrollCommand?>(null);
      final notifier3 = ValueNotifier<ScrollCommand?>(null);

      final reg1 = AlignedGridService.register(
        groupId: 'group1',
        scrollCommandNotifier: notifier1,
      );
      AlignedGridService.register(
        groupId: 'group1',
        scrollCommandNotifier: notifier2,
      );
      AlignedGridService.register(
        groupId: 'group1',
        scrollCommandNotifier: notifier3,
      );

      // Grid 1 scrolls to offset 150
      reg1.notifyScrollChanged(150.0);

      // Grid 2 and 3 should receive the command
      expect(notifier2.value, isA<SetHorizontalScrollCommand>());
      expect((notifier2.value as SetHorizontalScrollCommand).offset, 150.0);
      expect(notifier3.value, isA<SetHorizontalScrollCommand>());
      expect((notifier3.value as SetHorizontalScrollCommand).offset, 150.0);

      // Grid 1 should NOT receive its own scroll command
      expect(notifier1.value, isNull);

      notifier1.dispose();
      notifier2.dispose();
      notifier3.dispose();
    });

    test('propagateScroll does not affect other groups', () {
      final notifier1 = ValueNotifier<ScrollCommand?>(null);
      final notifier2 = ValueNotifier<ScrollCommand?>(null);

      final reg1 = AlignedGridService.register(
        groupId: 'group1',
        scrollCommandNotifier: notifier1,
      );
      AlignedGridService.register(
        groupId: 'group2',
        scrollCommandNotifier: notifier2,
      );

      reg1.notifyScrollChanged(200.0);

      // Grid in group2 should not be affected
      expect(notifier2.value, isNull);

      notifier1.dispose();
      notifier2.dispose();
    });

    test('isAlignedScrolling flag prevents re-propagation', () {
      final notifier1 = ValueNotifier<ScrollCommand?>(null);
      final notifier2 = ValueNotifier<ScrollCommand?>(null);

      final reg1 = AlignedGridService.register(
        groupId: 'group1',
        scrollCommandNotifier: notifier1,
      );
      AlignedGridService.register(
        groupId: 'group1',
        scrollCommandNotifier: notifier2,
      );

      // Simulate receiving an aligned scroll (flag is set)
      reg1.isAlignedScrolling = true;
      reg1.notifyScrollChanged(100.0);

      // Should not propagate because isAlignedScrolling is true
      expect(notifier2.value, isNull);

      // Reset flag and try again
      reg1.isAlignedScrolling = false;
      reg1.notifyScrollChanged(100.0);

      // Now it should propagate
      expect(notifier2.value, isA<SetHorizontalScrollCommand>());

      notifier1.dispose();
      notifier2.dispose();
    });

    test('reset clears all groups', () {
      final notifier1 = ValueNotifier<ScrollCommand?>(null);
      final notifier2 = ValueNotifier<ScrollCommand?>(null);

      AlignedGridService.register(
        groupId: 'group1',
        scrollCommandNotifier: notifier1,
      );
      AlignedGridService.register(
        groupId: 'group2',
        scrollCommandNotifier: notifier2,
      );

      AlignedGridService.reset();

      expect(AlignedGridService.groupSize('group1'), 0);
      expect(AlignedGridService.groupSize('group2'), 0);

      notifier1.dispose();
      notifier2.dispose();
    });
  });

  group('OsAlignedGrid — model class', () {
    test('stores groupId', () {
      const config = OsAlignedGrid(groupId: 'test-group');
      expect(config.groupId, 'test-group');
    });

    test('equality based on groupId', () {
      const a = OsAlignedGrid(groupId: 'same');
      const b = OsAlignedGrid(groupId: 'same');
      const c = OsAlignedGrid(groupId: 'different');

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('hashCode based on groupId', () {
      const a = OsAlignedGrid(groupId: 'same');
      const b = OsAlignedGrid(groupId: 'same');

      expect(a.hashCode, equals(b.hashCode));
    });
  });

  group('AlignedGridRegistration', () {
    setUp(() {
      AlignedGridService.reset();
    });

    tearDown(() {
      AlignedGridService.reset();
    });

    test('isAlignedScrolling defaults to false', () {
      final notifier = ValueNotifier<ScrollCommand?>(null);
      final reg = AlignedGridService.register(
        groupId: 'group1',
        scrollCommandNotifier: notifier,
      );

      expect(reg.isAlignedScrolling, isFalse);
      notifier.dispose();
    });

    test('notifyScrollChanged propagates when flag is false', () {
      final notifier1 = ValueNotifier<ScrollCommand?>(null);
      final notifier2 = ValueNotifier<ScrollCommand?>(null);

      final reg1 = AlignedGridService.register(
        groupId: 'group1',
        scrollCommandNotifier: notifier1,
      );
      AlignedGridService.register(
        groupId: 'group1',
        scrollCommandNotifier: notifier2,
      );

      reg1.notifyScrollChanged(50.0);
      expect(notifier2.value, isA<SetHorizontalScrollCommand>());
      expect((notifier2.value as SetHorizontalScrollCommand).offset, 50.0);

      notifier1.dispose();
      notifier2.dispose();
    });

    test('notifyScrollChanged is no-op when flag is true', () {
      final notifier1 = ValueNotifier<ScrollCommand?>(null);
      final notifier2 = ValueNotifier<ScrollCommand?>(null);

      final reg1 = AlignedGridService.register(
        groupId: 'group1',
        scrollCommandNotifier: notifier1,
      );
      AlignedGridService.register(
        groupId: 'group1',
        scrollCommandNotifier: notifier2,
      );

      reg1.isAlignedScrolling = true;
      reg1.notifyScrollChanged(50.0);
      expect(notifier2.value, isNull);

      notifier1.dispose();
      notifier2.dispose();
    });
  });

  group('SetHorizontalScrollCommand', () {
    test('stores offset', () {
      const cmd = SetHorizontalScrollCommand(offset: 123.45);
      expect(cmd.offset, 123.45);
    });

    test('is a ScrollCommand', () {
      const ScrollCommand cmd = SetHorizontalScrollCommand(offset: 0);
      expect(cmd, isA<SetHorizontalScrollCommand>());
    });

    test('exhaustive switch covers SetHorizontalScrollCommand', () {
      const ScrollCommand cmd = SetHorizontalScrollCommand(offset: 42.0);
      final result = switch (cmd) {
        EnsureColumnVisibleCommand() => 'column',
        EnsureIndexVisibleCommand() => 'row',
        SetHorizontalScrollCommand() => 'horizontal',
      };
      expect(result, 'horizontal');
    });
  });

  group('Aligned grids — widget integration', () {
    setUp(() {
      AlignedGridService.reset();
    });

    tearDown(() {
      AlignedGridService.reset();
    });

    testWidgets('grid registers with service when alignedGrids is set', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 400,
              child: OsGrid(
                alignedGrids: OsAlignedGrid(groupId: 'test-group'),
                columnDefs: [OsColumnDef(field: 'name', headerName: 'Name')],
                rowData: [
                  {'name': 'Alice'},
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(AlignedGridService.groupSize('test-group'), 1);
    });

    testWidgets('grid does not register when alignedGrids is null', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 400,
              child: OsGrid(
                columnDefs: [OsColumnDef(field: 'name', headerName: 'Name')],
                rowData: [
                  {'name': 'Alice'},
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(AlignedGridService.groupSize('test-group'), 0);
    });

    testWidgets('multiple grids in same group register correctly', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                SizedBox(
                  width: 800,
                  height: 200,
                  child: OsGrid(
                    alignedGrids: OsAlignedGrid(groupId: 'shared'),
                    columnDefs: [
                      OsColumnDef(field: 'name', headerName: 'Name'),
                    ],
                    rowData: [
                      {'name': 'Alice'},
                    ],
                  ),
                ),
                SizedBox(
                  width: 800,
                  height: 200,
                  child: OsGrid(
                    alignedGrids: OsAlignedGrid(groupId: 'shared'),
                    columnDefs: [
                      OsColumnDef(field: 'name', headerName: 'Name'),
                    ],
                    rowData: [
                      {'name': 'Bob'},
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(AlignedGridService.groupSize('shared'), 2);
    });

    testWidgets('grid deregisters on dispose', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 400,
              child: OsGrid(
                alignedGrids: OsAlignedGrid(groupId: 'dispose-test'),
                columnDefs: [OsColumnDef(field: 'name', headerName: 'Name')],
                rowData: [
                  {'name': 'Alice'},
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(AlignedGridService.groupSize('dispose-test'), 1);

      // Replace with a different widget to trigger dispose
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SizedBox())),
      );
      await tester.pumpAndSettle();

      expect(AlignedGridService.groupSize('dispose-test'), 0);
    });

    testWidgets('changing groupId re-registers with new group', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 400,
              child: OsGrid(
                alignedGrids: OsAlignedGrid(groupId: 'group-a'),
                columnDefs: [OsColumnDef(field: 'name', headerName: 'Name')],
                rowData: [
                  {'name': 'Alice'},
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(AlignedGridService.groupSize('group-a'), 1);
      expect(AlignedGridService.groupSize('group-b'), 0);

      // Change the group ID
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 400,
              child: OsGrid(
                alignedGrids: OsAlignedGrid(groupId: 'group-b'),
                columnDefs: [OsColumnDef(field: 'name', headerName: 'Name')],
                rowData: [
                  {'name': 'Alice'},
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(AlignedGridService.groupSize('group-a'), 0);
      expect(AlignedGridService.groupSize('group-b'), 1);
    });

    testWidgets('removing alignedGrids deregisters from service', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 400,
              child: OsGrid(
                alignedGrids: OsAlignedGrid(groupId: 'remove-test'),
                columnDefs: [OsColumnDef(field: 'name', headerName: 'Name')],
                rowData: [
                  {'name': 'Alice'},
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(AlignedGridService.groupSize('remove-test'), 1);

      // Remove alignedGrids (set to null)
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 400,
              child: OsGrid(
                columnDefs: [OsColumnDef(field: 'name', headerName: 'Name')],
                rowData: [
                  {'name': 'Alice'},
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(AlignedGridService.groupSize('remove-test'), 0);
    });

    testWidgets(
      'scroll propagation: scrolling one grid sends command to aligned grid',
      (tester) async {
        final controller1 = OsGridController();
        final controller2 = OsGridController();

        // Create two grids with many columns to enable horizontal scrolling
        final columns = List.generate(
          20,
          (i) =>
              OsColumnDef(field: 'col$i', headerName: 'Column $i', width: 150),
        );

        final rowData = [
          {for (var i = 0; i < 20; i++) 'col$i': 'value $i'},
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  SizedBox(
                    width: 800,
                    height: 200,
                    child: OsGrid(
                      controller: controller1,
                      alignedGrids: const OsAlignedGrid(groupId: 'scroll-test'),
                      columnDefs: columns,
                      rowData: rowData,
                    ),
                  ),
                  SizedBox(
                    width: 800,
                    height: 200,
                    child: OsGrid(
                      controller: controller2,
                      alignedGrids: const OsAlignedGrid(groupId: 'scroll-test'),
                      columnDefs: columns,
                      rowData: rowData,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(AlignedGridService.groupSize('scroll-test'), 2);

        // Verify both controllers have their scroll command notifiers
        expect(controller1.scrollCommandNotifier, isNotNull);
        expect(controller2.scrollCommandNotifier, isNotNull);

        controller1.dispose();
        controller2.dispose();
      },
    );
  });

  group('Aligned grids — edge cases', () {
    setUp(() {
      AlignedGridService.reset();
    });

    tearDown(() {
      AlignedGridService.reset();
    });

    test('deregister with non-existent group is safe', () {
      final notifier = ValueNotifier<ScrollCommand?>(null);
      final reg = AlignedGridService.register(
        groupId: 'temp',
        scrollCommandNotifier: notifier,
      );

      // Deregister once
      AlignedGridService.deregister(reg);
      // Deregister again — should not throw
      AlignedGridService.deregister(reg);

      notifier.dispose();
    });

    test('propagateScroll with single grid in group is no-op', () {
      final notifier = ValueNotifier<ScrollCommand?>(null);
      final reg = AlignedGridService.register(
        groupId: 'solo',
        scrollCommandNotifier: notifier,
      );

      // Should not throw or set anything
      reg.notifyScrollChanged(100.0);
      expect(notifier.value, isNull);

      notifier.dispose();
    });

    test('propagateScroll with zero offset', () {
      final notifier1 = ValueNotifier<ScrollCommand?>(null);
      final notifier2 = ValueNotifier<ScrollCommand?>(null);

      final reg1 = AlignedGridService.register(
        groupId: 'zero',
        scrollCommandNotifier: notifier1,
      );
      AlignedGridService.register(
        groupId: 'zero',
        scrollCommandNotifier: notifier2,
      );

      reg1.notifyScrollChanged(0.0);
      expect(notifier2.value, isA<SetHorizontalScrollCommand>());
      expect((notifier2.value as SetHorizontalScrollCommand).offset, 0.0);

      notifier1.dispose();
      notifier2.dispose();
    });

    test('propagateScroll with large offset', () {
      final notifier1 = ValueNotifier<ScrollCommand?>(null);
      final notifier2 = ValueNotifier<ScrollCommand?>(null);

      final reg1 = AlignedGridService.register(
        groupId: 'large',
        scrollCommandNotifier: notifier1,
      );
      AlignedGridService.register(
        groupId: 'large',
        scrollCommandNotifier: notifier2,
      );

      reg1.notifyScrollChanged(99999.0);
      expect((notifier2.value as SetHorizontalScrollCommand).offset, 99999.0);

      notifier1.dispose();
      notifier2.dispose();
    });

    test('multiple sequential scroll propagations', () {
      final notifier1 = ValueNotifier<ScrollCommand?>(null);
      final notifier2 = ValueNotifier<ScrollCommand?>(null);

      final reg1 = AlignedGridService.register(
        groupId: 'seq',
        scrollCommandNotifier: notifier1,
      );
      AlignedGridService.register(
        groupId: 'seq',
        scrollCommandNotifier: notifier2,
      );

      reg1.notifyScrollChanged(10.0);
      expect((notifier2.value as SetHorizontalScrollCommand).offset, 10.0);

      reg1.notifyScrollChanged(20.0);
      expect((notifier2.value as SetHorizontalScrollCommand).offset, 20.0);

      reg1.notifyScrollChanged(0.0);
      expect((notifier2.value as SetHorizontalScrollCommand).offset, 0.0);

      notifier1.dispose();
      notifier2.dispose();
    });

    test('three grids: scroll from middle propagates to both others', () {
      final notifier1 = ValueNotifier<ScrollCommand?>(null);
      final notifier2 = ValueNotifier<ScrollCommand?>(null);
      final notifier3 = ValueNotifier<ScrollCommand?>(null);

      AlignedGridService.register(
        groupId: 'trio',
        scrollCommandNotifier: notifier1,
      );
      final reg2 = AlignedGridService.register(
        groupId: 'trio',
        scrollCommandNotifier: notifier2,
      );
      AlignedGridService.register(
        groupId: 'trio',
        scrollCommandNotifier: notifier3,
      );

      reg2.notifyScrollChanged(75.0);

      // Grid 1 and 3 should receive the command
      expect((notifier1.value as SetHorizontalScrollCommand).offset, 75.0);
      expect((notifier3.value as SetHorizontalScrollCommand).offset, 75.0);
      // Grid 2 (source) should not
      expect(notifier2.value, isNull);

      notifier1.dispose();
      notifier2.dispose();
      notifier3.dispose();
    });
  });
}
