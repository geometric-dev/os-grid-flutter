import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';
import 'package:os_grid_flutter/src/columns/column_api_coordinator.dart';

ColumnApiCoordinator<Map<String, dynamic>> _buildCoordinator(
  OsGridController<Map<String, dynamic>> controller,
  List<OsColumnDef> cols,
) {
  return ColumnApiCoordinator<Map<String, dynamic>>(
    controller: controller,
    allFlatColumns: () => cols,
    syntheticOffset: () => 0,
    resolveRows: () => null,
    resolveCellValue: (col, row, _) => row[col.field],
    clearTextCacheFor: (_) {},
    setSortModel: (_) {},
    clearSort: () {},
    invalidateDeltaSort: () {},
    resetLegacySortIndex: () {},
    emitSortChanged: () {},
    reprocess: () {},
    initHiddenFromDefs: () {},
    notifyStateChanged: (_) {},
    mutate: (fn) => fn(),
    headerTextStyle: () => const TextStyle(),
    cellTextStyle: () => const TextStyle(),
    textScaler: () => TextScaler.noScaling,
    onColumnVisible: null,
    onColumnPinned: null,
    onColumnResized: null,
    onColumnMoved: null,
  );
}

void main() {
  group('moveColumnToPinnedSection (column drag between pin sections)', () {
    test('moves center column to left pin at index', () async {
      final controller = OsGridController<Map<String, dynamic>>();
      const cols = [
        OsColumnDef(field: 'a'),
        OsColumnDef(field: 'b'),
        OsColumnDef(field: 'c'),
      ];
      final coord = _buildCoordinator(controller, cols);
      final pinnedEvents = <OsColumnPinnedEvent>[];
      final movedEvents = <OsColumnMovedEvent>[];
      final pinnedSub = controller.onColumnPinned.listen(pinnedEvents.add);
      final movedSub = controller.onColumnMoved.listen(movedEvents.add);

      coord.moveColumnToPinnedSection('c', OsColumnPin.left, 0);
      await Future<void>.delayed(Duration.zero);

      expect(coord.pins['c'], OsColumnPin.left);
      expect(pinnedEvents, hasLength(1));
      expect(pinnedEvents.first.pinned, OsColumnPin.left);
      expect(pinnedEvents.first.source, 'uiColumnDragged');
      expect(movedEvents, hasLength(1));
      expect(movedEvents.first.source, 'uiColumnDragged');

      final flattened = coord
          .displayedColumnsPinnedOrder()
          .map((c) => c.effectiveColId)
          .toList();
      expect(flattened.first, 'c');

      await pinnedSub.cancel();
      await movedSub.cancel();
      coord.dispose();
      controller.dispose();
    });

    test('reorders within the same section without pin event', () async {
      final controller = OsGridController<Map<String, dynamic>>();
      const cols = [
        OsColumnDef(field: 'a'),
        OsColumnDef(field: 'b'),
        OsColumnDef(field: 'c'),
      ];
      final coord = _buildCoordinator(controller, cols);
      final pinnedEvents = <OsColumnPinnedEvent>[];
      final movedEvents = <OsColumnMovedEvent>[];
      final pinnedSub = controller.onColumnPinned.listen(pinnedEvents.add);
      final movedSub = controller.onColumnMoved.listen(movedEvents.add);

      coord.moveColumnToPinnedSection('a', null, 2);
      await Future<void>.delayed(Duration.zero);

      expect(pinnedEvents, isEmpty);
      expect(movedEvents, hasLength(1));
      final flattened = coord
          .displayedColumnsPinnedOrder()
          .map((c) => c.effectiveColId)
          .toList();
      expect(flattened, ['b', 'c', 'a']);

      await pinnedSub.cancel();
      await movedSub.cancel();
      coord.dispose();
      controller.dispose();
    });

    test('no-op re-insert at same spot emits nothing', () async {
      final controller = OsGridController<Map<String, dynamic>>();
      const cols = [OsColumnDef(field: 'a'), OsColumnDef(field: 'b')];
      final coord = _buildCoordinator(controller, cols);
      final pinnedEvents = <OsColumnPinnedEvent>[];
      final movedEvents = <OsColumnMovedEvent>[];
      final pinnedSub = controller.onColumnPinned.listen(pinnedEvents.add);
      final movedSub = controller.onColumnMoved.listen(movedEvents.add);

      coord.moveColumnToPinnedSection('a', null, 0);
      await Future<void>.delayed(Duration.zero);

      expect(pinnedEvents, isEmpty);
      expect(movedEvents, isEmpty);
      expect(coord.order, isNull);

      await pinnedSub.cancel();
      await movedSub.cancel();
      coord.dispose();
      controller.dispose();
    });

    test(
      'guards: unknown col, suppressMovable, lockPosition, lockPinned',
      () async {
        final controller = OsGridController<Map<String, dynamic>>();
        const cols = [
          OsColumnDef(field: 'a'),
          OsColumnDef(field: 'b', suppressMovable: true),
          OsColumnDef(field: 'c', lockPosition: true),
          OsColumnDef(field: 'd', lockPinned: true),
        ];
        final coord = _buildCoordinator(controller, cols);
        final pinnedEvents = <OsColumnPinnedEvent>[];
        final movedEvents = <OsColumnMovedEvent>[];
        final pinnedSub = controller.onColumnPinned.listen(pinnedEvents.add);
        final movedSub = controller.onColumnMoved.listen(movedEvents.add);

        coord.moveColumnToPinnedSection('missing', OsColumnPin.left, 0);
        coord.moveColumnToPinnedSection('b', OsColumnPin.left, 0);
        coord.moveColumnToPinnedSection('c', OsColumnPin.left, 0);
        coord.moveColumnToPinnedSection('d', OsColumnPin.left, 0);
        await Future<void>.delayed(Duration.zero);

        expect(pinnedEvents, isEmpty);
        expect(movedEvents, isEmpty);
        expect(coord.pins, isEmpty);
        expect(coord.order, isNull);

        await pinnedSub.cancel();
        await movedSub.cancel();
        coord.dispose();
        controller.dispose();
      },
    );
  });
}
