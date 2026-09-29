import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

/// Golden pair locking the column-group header geometry under LTR and RTL.
///
/// Regression guard for the RTL group-extent bug: the group header's accent
/// bar, caption and trailing border must be laid out over the group's own
/// visual extent — the min/max visual edges of its member columns. The old
/// formula (first member's left edge + sum of widths) overshoots under RTL,
/// where columns are laid out right-to-left and the group spans from the
/// left edge of its LAST member to the right edge of its FIRST member.
///
/// Two adjacent groups with unequal widths make the overshoot visible: the
/// wide group's accent bar would land inside the narrow group's header
/// area. Regenerate with:
///
/// ```bash
/// flutter test --update-goldens test/goldens/group_header_rtl_golden_test.dart
/// ```
void main() {
  final boundaryKey = GlobalKey();

  Widget buildGroupedGrid() {
    return SizedBox(
      width: 320,
      height: 160,
      child: OsGrid(
        columnDefs: const [
          OsColumnGroup(
            headerName: 'Wide group',
            groupId: 'g1',
            children: [
              OsColumnDef(field: 'a', headerName: 'A', width: 140),
              OsColumnDef(field: 'b', headerName: 'B', width: 90),
            ],
          ),
          OsColumnGroup(
            headerName: 'Narrow',
            groupId: 'g2',
            children: [OsColumnDef(field: 'c', headerName: 'C', width: 60)],
          ),
        ],
        rowData: [
          {'a': 'a1', 'b': 'b1', 'c': 'c1'},
          {'a': 'a2', 'b': 'b2', 'c': 'c2'},
        ],
        theme: OsGridTheme.quartz(),
      ),
    );
  }

  Future<void> pumpAndCapture(WidgetTester tester, {required bool rtl}) async {
    await tester.binding.setSurfaceSize(const Size(320, 160));
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'FlutterTest'),
        home: Scaffold(
          body: RepaintBoundary(
            key: boundaryKey,
            child: rtl
                ? Directionality(
                    textDirection: TextDirection.rtl,
                    child: buildGroupedGrid(),
                  )
                : buildGroupedGrid(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await expectLater(
      find.byKey(boundaryKey),
      matchesGoldenFile('goldens/group_header_${rtl ? 'rtl' : 'ltr'}.png'),
    );
    await tester.binding.setSurfaceSize(null);
  }

  testWidgets('group headers under LTR', (tester) async {
    await pumpAndCapture(tester, rtl: false);
  });

  testWidgets(
    'group headers under RTL (accent bar hugs the group leading edge)',
    (tester) async {
      await pumpAndCapture(tester, rtl: true);
    },
  );
}
