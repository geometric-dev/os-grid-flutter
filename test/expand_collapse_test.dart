import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

void main() {
  group('expandAll / collapseAll', () {
    test(
      'expandAll emits onExpandOrCollapseAll event with expandedAll=true',
      () async {
        final controller = OsGridController<Map<String, dynamic>>();
        final events = <OsExpandOrCollapseAllEvent>[];
        controller.onExpandOrCollapseAll.listen(events.add);

        controller.expandAll();

        // Allow the stream event to propagate.
        await Future<void>.delayed(Duration.zero);

        expect(events, hasLength(1));
        expect(events.first.expandedAll, isTrue);
        expect(events.first.source, 'api');

        controller.dispose();
      },
    );

    test(
      'collapseAll emits onExpandOrCollapseAll event with expandedAll=false',
      () async {
        final controller = OsGridController<Map<String, dynamic>>();
        final events = <OsExpandOrCollapseAllEvent>[];
        controller.onExpandOrCollapseAll.listen(events.add);

        controller.collapseAll();

        await Future<void>.delayed(Duration.zero);

        expect(events, hasLength(1));
        expect(events.first.expandedAll, isFalse);
        expect(events.first.source, 'api');

        controller.dispose();
      },
    );

    test('expandAll followed by collapseAll emits two events', () async {
      final controller = OsGridController<Map<String, dynamic>>();
      final events = <OsExpandOrCollapseAllEvent>[];
      controller.onExpandOrCollapseAll.listen(events.add);

      controller.expandAll();
      controller.collapseAll();

      await Future<void>.delayed(Duration.zero);

      expect(events, hasLength(2));
      expect(events[0].expandedAll, isTrue);
      expect(events[1].expandedAll, isFalse);

      controller.dispose();
    });

    test('expandAll invokes widget callback', () async {
      final controller = OsGridController<Map<String, dynamic>>();
      OsExpandOrCollapseAllEvent? received;
      controller.onExpandOrCollapseAllCallback = (event) {
        received = event;
      };

      controller.expandAll();

      expect(received, isNotNull);
      expect(received!.expandedAll, isTrue);
      expect(received!.source, 'api');

      controller.dispose();
    });

    test('collapseAll invokes widget callback', () async {
      final controller = OsGridController<Map<String, dynamic>>();
      OsExpandOrCollapseAllEvent? received;
      controller.onExpandOrCollapseAllCallback = (event) {
        received = event;
      };

      controller.collapseAll();

      expect(received, isNotNull);
      expect(received!.expandedAll, isFalse);
      expect(received!.source, 'api');

      controller.dispose();
    });
  });

  group('isRowGroupExpanded', () {
    test('returns false for any rowId (no tree data configured)', () {
      final controller = OsGridController<Map<String, dynamic>>();

      expect(controller.isRowGroupExpanded('group-1'), isFalse);
      expect(controller.isRowGroupExpanded('group-2'), isFalse);
      expect(controller.isRowGroupExpanded('nonexistent'), isFalse);
      expect(controller.isRowGroupExpanded(''), isFalse);

      controller.dispose();
    });
  });

  group('setRowNodeExpanded', () {
    test('is a no-op that does not throw', () {
      final controller = OsGridController<Map<String, dynamic>>();

      // Should not throw.
      expect(
        () => controller.setRowNodeExpanded('group-1', true),
        returnsNormally,
      );
      expect(
        () => controller.setRowNodeExpanded('group-1', false),
        returnsNormally,
      );
      expect(
        () => controller.setRowNodeExpanded('nonexistent', true),
        returnsNormally,
      );

      controller.dispose();
    });

    test('does not affect isRowGroupExpanded (no tree data)', () {
      final controller = OsGridController<Map<String, dynamic>>();

      controller.setRowNodeExpanded('group-1', true);
      expect(controller.isRowGroupExpanded('group-1'), isFalse);

      controller.setRowNodeExpanded('group-1', false);
      expect(controller.isRowGroupExpanded('group-1'), isFalse);

      controller.dispose();
    });
  });

  group('OsExpandOrCollapseAllEvent', () {
    test('is an OsGridEvent', () {
      const event = OsExpandOrCollapseAllEvent(
        source: 'api',
        expandedAll: true,
      );
      expect(event, isA<OsGridEvent>());
    });

    test('stores source and expandedAll correctly', () {
      const expandEvent = OsExpandOrCollapseAllEvent(
        source: 'api',
        expandedAll: true,
      );
      expect(expandEvent.source, 'api');
      expect(expandEvent.expandedAll, isTrue);

      const collapseEvent = OsExpandOrCollapseAllEvent(
        source: 'api',
        expandedAll: false,
      );
      expect(collapseEvent.source, 'api');
      expect(collapseEvent.expandedAll, isFalse);
    });
  });

  group('stream lifecycle', () {
    test('onExpandOrCollapseAll stream closes on controller dispose', () async {
      final controller = OsGridController<Map<String, dynamic>>();
      var done = false;
      controller.onExpandOrCollapseAll.listen(
        (_) {},
        onDone: () => done = true,
      );

      controller.dispose();
      await Future<void>.delayed(Duration.zero);

      expect(done, isTrue);
    });
  });
}
