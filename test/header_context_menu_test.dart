import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

void main() {
  testWidgets('Header context menu shows Group/Ungroup items', (
    WidgetTester tester,
  ) async {
    final controller = OsGridController();
    final columnDefs = [
      const OsColumnDef(
        field: 'country',
        headerName: 'Country',
        rowGroup: true,
      ),
      const OsColumnDef(field: 'year', headerName: 'Year'),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OsGrid(
            controller: controller,
            columnDefs: columnDefs,
            rowData: const [
              {'country': 'US', 'year': 2020},
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Right click the 'Country' header (which is already grouped)
    // The grid paints on a canvas, so we can't use find.text() for headers.
    // 'Country' is the first column, default width is 200, so center is (100, 16)
    final gridFinder = find.byWidgetPredicate(
      (w) => w.runtimeType.toString().startsWith('OsGrid<'),
    );
    expect(gridFinder, findsOneWidget);

    // Simulate secondary tap on 'Country' header
    final gridTopLeft = tester.getTopLeft(gridFinder);
    final countryHeaderOffset = gridTopLeft + const Offset(75, 16);

    final gesture = await tester.startGesture(
      countryHeaderOffset,
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.up();
    await tester.pumpAndSettle();

    // Context menu should show 'Ungroup by Country'
    expect(find.text('Ungroup by Country'), findsOneWidget);

    // Dismiss the menu by tapping outside
    await tester.tapAt(const Offset(0, 500));
    await tester.pumpAndSettle();

    // 2. Right click the 'Year' header (which is NOT grouped)
    // 'Year' is the second column, so center is (225, 16)
    final yearHeaderOffset = gridTopLeft + const Offset(225, 16);

    // Simulate secondary tap
    final gesture2 = await tester.startGesture(
      yearHeaderOffset,
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await tester.pump(const Duration(milliseconds: 50));
    await gesture2.up();
    await tester.pumpAndSettle();

    // Context menu should show 'Group by Year'
    expect(find.text('Group by Year'), findsOneWidget);

    // Tap the 'Group by Year' option
    await tester.tap(find.text('Group by Year'));
    await tester.pumpAndSettle();

    // Now year should be in rowGroupColumns
    expect(controller.getRowGroupColumns().contains('year'), isTrue);
  });
}
