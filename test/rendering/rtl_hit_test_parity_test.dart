import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

/// Paint/hit-test parity tests for RTL directionality
/// (quality program v2 item 48).
///
/// The painter and the hit-test paths share one directional x-resolver
/// (`rtl_geometry.dart`); these tests prove pointer interaction resolves the
/// SAME geometry: tapping where a header or cell is VISUALLY anchored under
/// `Directionality.rtl` must hit that column — not the column that would sit
/// there under LTR.
void main() {
  // 600-wide viewport: pinned 'p' (150) + center a/b/c (150 each).
  // LTR visual order:   p [0,150) | a [150,300) b [300,450) c [450,600)
  // RTL visual order:   c [0,150) b [150,300) a [300,450) | p [450,600)
  const columnDefs = [
    OsColumnDef(
      field: 'p',
      headerName: 'Pinned',
      width: 150,
      pinned: OsColumnPin.left,
      sortable: true,
    ),
    OsColumnDef(field: 'a', headerName: 'A', width: 150, sortable: true),
    OsColumnDef(field: 'b', headerName: 'B', width: 150, sortable: true),
    OsColumnDef(field: 'c', headerName: 'C', width: 150, sortable: true),
  ];
  final rowData = List.generate(3, (i) {
    return <String, dynamic>{'p': i, 'a': i, 'b': i, 'c': i};
  });

  /// A single tap needs the double-tap arena (300 ms) to resolve before
  /// tap handlers fire.
  Future<void> settleTap(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
  }

  Future<void> pumpGrid(
    WidgetTester tester, {
    TextDirection direction = TextDirection.ltr,
    void Function(OsSortChangedEvent)? onSortChanged,
    void Function(OsCellClickedEvent<Map<String, dynamic>>)? onCellClicked,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: direction,
          child: Center(
            child: SizedBox(
              width: 600,
              height: 400,
              child: OsGrid<Map<String, dynamic>>(
                columnDefs: columnDefs,
                rowData: rowData,
                onSortChanged: onSortChanged,
                onCellClicked: onCellClicked,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Offset gridOrigin(WidgetTester tester) =>
      (tester.renderObject(find.byType(VirtualisedGrid)) as RenderBox)
          .localToGlobal(Offset.zero);

  group('header hit-testing mirrors pinned sections and center walk', () {
    testWidgets('LTR control: pinned left, then a/b/c left-to-right', (
      tester,
    ) async {
      final sorted = <String>[];
      await pumpGrid(
        tester,
        onSortChanged: (e) => sorted.add(e.sortModel.first.colId),
      );
      final origin = gridOrigin(tester);

      await tester.tapAt(origin + const Offset(75, 24));
      await settleTap(tester);
      expect(sorted.last, 'p');

      await tester.tapAt(origin + const Offset(225, 24));
      await settleTap(tester);
      expect(sorted.last, 'a');

      await tester.tapAt(origin + const Offset(525, 24));
      await settleTap(tester);
      expect(sorted.last, 'c');
    });

    testWidgets(
      'RTL: leading-pinned anchors right, center walks right-to-left',
      (tester) async {
        final sorted = <String>[];
        await pumpGrid(
          tester,
          direction: TextDirection.rtl,
          onSortChanged: (e) => sorted.add(e.sortModel.first.colId),
        );
        final origin = gridOrigin(tester);

        // Leading-pinned section now occupies the RIGHT edge [450,600).
        await tester.tapAt(origin + const Offset(525, 24));
        await settleTap(tester);
        expect(sorted.last, 'p');

        // Center reading order runs right-to-left from the pinned border:
        // a at [300,450), b at [150,300), c at [0,150).
        await tester.tapAt(origin + const Offset(375, 24));
        await settleTap(tester);
        expect(sorted.last, 'a');

        await tester.tapAt(origin + const Offset(225, 24));
        await settleTap(tester);
        expect(sorted.last, 'b');

        await tester.tapAt(origin + const Offset(75, 24));
        await settleTap(tester);
        expect(sorted.last, 'c');
      },
    );
  });

  group('cell hit-testing parity', () {
    testWidgets('RTL cell taps report the visually clicked column', (
      tester,
    ) async {
      final clicked = <String>[];
      await pumpGrid(
        tester,
        direction: TextDirection.rtl,
        onCellClicked: (e) => clicked.add(e.colDef.effectiveColId),
      );
      final origin = gridOrigin(tester);
      // Data row 0 spans y in [48, 90).
      const rowY = 69.0;

      await tester.tapAt(origin + const Offset(525, rowY));
      await settleTap(tester);
      expect(clicked.last, 'p');

      await tester.tapAt(origin + const Offset(375, rowY));
      await settleTap(tester);
      expect(clicked.last, 'a');

      await tester.tapAt(origin + const Offset(75, rowY));
      await settleTap(tester);
      expect(clicked.last, 'c');
    });

    testWidgets('LTR cell taps are unchanged by the refactor', (tester) async {
      final clicked = <String>[];
      await pumpGrid(
        tester,
        onCellClicked: (e) => clicked.add(e.colDef.effectiveColId),
      );
      final origin = gridOrigin(tester);
      const rowY = 69.0;

      await tester.tapAt(origin + const Offset(75, rowY));
      await settleTap(tester);
      expect(clicked.last, 'p');

      await tester.tapAt(origin + const Offset(375, rowY));
      await settleTap(tester);
      expect(clicked.last, 'b');

      await tester.tapAt(origin + const Offset(525, rowY));
      await settleTap(tester);
      expect(clicked.last, 'c');
    });
  });
}
