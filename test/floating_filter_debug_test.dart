import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

void main() {
  testWidgets('debug: floating filter tap triggers overlay', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 600,
          height: 400,
          child: OsGrid(
            floatingFilter: true,
            floatingFilterHeight: 32.0,
            headerHeight: 48.0,
            rowHeight: 42.0,
            columnDefs: [
              OsColumnDef(
                field: 'name',
                headerName: 'Name',
                filter: OsTextFilter(),
                width: 200,
              ),
            ],
            rowData: [
              {'name': 'Alice'},
              {'name': 'Bob'},
            ],
          ),
        ),
      ),
    );

    // Get the VirtualisedGrid's position
    final gridFinder = find.byType(VirtualisedGrid);
    expect(gridFinder, findsOneWidget);

    final gridBox = tester.renderObject(gridFinder) as RenderBox;
    final gridTopLeft = gridBox.localToGlobal(Offset.zero);
    final gridSize = gridBox.size;

    // Debug: print grid position and size
    debugPrint('Grid top-left: $gridTopLeft');
    debugPrint('Grid size: $gridSize');

    // The floating filter row should be at y=48..80 (headerHeight=48, filterHeight=32)
    // Tap in the middle of the floating filter row
    final tapPosition = gridTopLeft + const Offset(100, 64);
    debugPrint('Tap position: $tapPosition');

    await tester.tapAt(tapPosition);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Check if EditableText appeared
    final editableTextFinder = find.byType(EditableText);
    debugPrint('EditableText count: ${editableTextFinder.evaluate().length}');

    // Verify the EditableText overlay appeared
    expect(editableTextFinder, findsOneWidget);
  });
}
