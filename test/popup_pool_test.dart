import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/src/popup/popup_ui_coordinator.dart';

PopupUiCoordinator _makeCoordinator() {
  return PopupUiCoordinator(
    mutate: (callback) => callback(),
    hasActiveEdit: () => false,
    commitEdit: () {},
    floatingFilterTextController: () => TextEditingController(),
    floatingFilterFocusNode: () => FocusNode(),
    columnFilterModels: () => {},
    columnDefs: () => const [],
    columnMenu: () => null,
    theme: () => null,
    localeText: () => null,
    flatColumnsCache: () => const [],
    hiddenIds: () => const {},
    columnSortDirection: (_) => null,
    flattenColumnDefs: (defs, outColumns, outSpans) {},
    reprocessData: () {},
    emitFilterChangedEvent: () {},
    onFilterPopupApply: (colId, model) {},
    onColumnVisibilityChanged: (colId, visible) {},
    applySortFromMenu: (columnIndex, {ascending = false, clear = false}) {},
    applyPinFromMenu: (columnIndex, pin) {},
    autosizeColumn: (columnIndex) {},
    autosizeAllColumns: () {},
    resetColumns: () {},
  );
}

void main() {
  group('FloatingFilterPopupEntry pool', () {
    test('pool size grows to max 3 then stops', () {
      final coordinator = _makeCoordinator();
      addTearDown(coordinator.dispose);

      // Hold five entries at once, then return them one by one.
      final outstanding = <FloatingFilterPopupEntry>[
        for (var i = 0; i < 5; i++)
          coordinator.acquireFloatingFilterPopup(
            Rect.fromLTWH(i * 120, 0, 100, 24),
          ),
      ];
      expect(coordinator.pooledFloatingFilterPopupCount, 0);

      for (var i = 0; i < outstanding.length; i++) {
        coordinator.releaseFloatingFilterPopup(outstanding[i]);
        expect(
          coordinator.pooledFloatingFilterPopupCount,
          i < 3 ? i + 1 : 3,
          reason: 'pool must cap at 3 entries',
        );
      }

      // Entries released once the pool was full are disposed, not pooled.
      expect(outstanding[3].isDisposed, isTrue);
      expect(outstanding[4].isDisposed, isTrue);
      for (final entry in outstanding.take(3)) {
        expect(entry.isDisposed, isFalse);
      }
    });

    test('pooled popup is reused (same controller instance)', () {
      final coordinator = _makeCoordinator();
      addTearDown(coordinator.dispose);

      final first = coordinator.acquireFloatingFilterPopup(
        const Rect.fromLTWH(0, 0, 100, 24),
      );
      first.controller.text = 'filter text';
      coordinator.releaseFloatingFilterPopup(first);

      final second = coordinator.acquireFloatingFilterPopup(
        const Rect.fromLTWH(150, 0, 120, 24),
      );

      expect(identical(first, second), isTrue);
      expect(identical(first.controller, second.controller), isTrue);
      expect(identical(first.focusNode, second.focusNode), isTrue);

      // Text is cleared on reuse and the overlay is repositioned.
      expect(second.controller.text, isEmpty);
      final positioned = second.overlay as Positioned;
      expect(positioned.left, 150);
      expect(positioned.width, 120);
    });

    test('pool is cleared and entries disposed on dispose', () {
      final coordinator = _makeCoordinator();

      final pooled = <FloatingFilterPopupEntry>[
        for (var i = 0; i < 2; i++)
          coordinator.acquireFloatingFilterPopup(Rect.zero),
      ];
      for (final entry in pooled) {
        coordinator.releaseFloatingFilterPopup(entry);
      }
      expect(coordinator.pooledFloatingFilterPopupCount, 2);

      coordinator.dispose();

      expect(coordinator.pooledFloatingFilterPopupCount, 0);
      for (final entry in pooled) {
        expect(entry.isDisposed, isTrue);
      }

      // Disposing twice is harmless.
      coordinator.dispose();
      expect(coordinator.pooledFloatingFilterPopupCount, 0);
    });

    test('double release and release of disposed entry are harmless', () {
      final coordinator = _makeCoordinator();
      addTearDown(coordinator.dispose);

      final first = coordinator.acquireFloatingFilterPopup(Rect.zero);
      final second = coordinator.acquireFloatingFilterPopup(Rect.zero);
      coordinator.releaseFloatingFilterPopup(first);
      coordinator.releaseFloatingFilterPopup(first);
      expect(coordinator.pooledFloatingFilterPopupCount, 1);

      final spare = FloatingFilterPopupEntry(
        controller: TextEditingController(),
        focusNode: FocusNode(),
        overlayBuilder: (_, rect) =>
            Positioned.fromRect(rect: rect, child: const SizedBox.shrink()),
      );
      spare.dispose();
      coordinator.releaseFloatingFilterPopup(spare);
      expect(coordinator.pooledFloatingFilterPopupCount, 1);
      expect(spare.isDisposed, isTrue);

      coordinator.releaseFloatingFilterPopup(second);
      expect(coordinator.pooledFloatingFilterPopupCount, 2);
    });

    testWidgets(
      'pooled overlay renders an EditableText bound to the pooled controller',
      (tester) async {
        final coordinator = _makeCoordinator();
        final entry = coordinator.acquireFloatingFilterPopup(
          const Rect.fromLTWH(0, 0, 100, 24),
        );

        await tester.pumpWidget(
          MaterialApp(home: Stack(children: [entry.overlay])),
        );

        final editable = tester.widget<EditableText>(find.byType(EditableText));
        expect(identical(editable.controller, entry.controller), isTrue);
        expect(identical(editable.focusNode, entry.focusNode), isTrue);

        // Typing routes through the coordinator's live handler (no active
        // floating-filter column in this harness, so it is a no-op) without
        // disturbing the pooled lifecycle.
        await tester.enterText(find.byType(EditableText), 'ab');
        await tester.pump();
        expect(entry.controller.text, 'ab');

        coordinator.releaseFloatingFilterPopup(entry);
        expect(entry.isDisposed, isFalse);
        expect(coordinator.pooledFloatingFilterPopupCount, 1);
        await tester.pump();

        // Unmount, flush focus teardown, then dispose the pool.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        coordinator.dispose();
        expect(entry.isDisposed, isTrue);
      },
    );
  });
}
