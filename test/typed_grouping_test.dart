import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

class _Athlete {
  _Athlete(this.name, this.country);
  final String name;
  final String country;
}

List<String> _names(WidgetTester tester) {
  final grid = tester.widget<VirtualisedGrid>(find.byType(VirtualisedGrid));
  return [
    for (final row in grid.rowData)
      if (row['name'] != null) row['name'] as String,
  ];
}

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: SizedBox(width: 800, height: 600, child: child)),
);

void main() {
  testWidgets('typed rows render leaf values under grouping', (tester) async {
    await tester.pumpWidget(
      _wrap(
        OsGrid<_Athlete>(
          columnDefs: [
            const OsColumnDef<_Athlete>(
              field: 'country',
              headerName: 'Country',
              rowGroup: true,
            ),
            OsColumnDef<_Athlete>(
              field: 'name',
              headerName: 'Name',
              valueGetter: (params) => params.data.name,
            ),
          ],
          rowData: [_Athlete('Alice', 'UK'), _Athlete('Bob', 'US')],
          groupDefaultExpanded: -1,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final grid = tester.widget<VirtualisedGrid>(find.byType(VirtualisedGrid));
    // ignore: avoid_print
    print('PROBE rows=${grid.rowData.length}');
    for (final r in grid.rowData) {
      // ignore: avoid_print
      print('PROBE keys=${r.keys.toList()}');
    }

    // Leaf rows must carry valueGetter-resolved names instead of blank maps.
    expect(_names(tester), containsAll(['Alice', 'Bob']));
  });
}
