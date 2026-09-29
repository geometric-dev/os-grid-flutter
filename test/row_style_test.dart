import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

void main() {
  group('OsRowStyle', () {
    test('const constructor creates instance with all null fields', () {
      const style = OsRowStyle();
      expect(style.backgroundColor, isNull);
      expect(style.foregroundColor, isNull);
      expect(style.fontWeight, isNull);
      expect(style.fontStyle, isNull);
    });

    test('const constructor accepts all parameters', () {
      const style = OsRowStyle(
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        fontWeight: FontWeight.bold,
        fontStyle: FontStyle.italic,
      );
      expect(style.backgroundColor, Colors.red);
      expect(style.foregroundColor, Colors.white);
      expect(style.fontWeight, FontWeight.bold);
      expect(style.fontStyle, FontStyle.italic);
    });

    test('equality works correctly', () {
      const a = OsRowStyle(backgroundColor: Colors.red);
      const b = OsRowStyle(backgroundColor: Colors.red);
      const c = OsRowStyle(backgroundColor: Colors.blue);

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('merge returns this when other is null', () {
      const style = OsRowStyle(backgroundColor: Colors.red);
      final merged = style.merge(null);
      expect(merged, equals(style));
    });

    test('merge applies other values over this', () {
      const base = OsRowStyle(
        backgroundColor: Colors.red,
        foregroundColor: Colors.black,
        fontWeight: FontWeight.normal,
      );
      const override = OsRowStyle(
        backgroundColor: Colors.blue,
        fontStyle: FontStyle.italic,
      );

      final merged = base.merge(override);

      // backgroundColor overridden
      expect(merged.backgroundColor, Colors.blue);
      // foregroundColor kept from base (other is null)
      expect(merged.foregroundColor, Colors.black);
      // fontWeight kept from base (other is null)
      expect(merged.fontWeight, FontWeight.normal);
      // fontStyle from override
      expect(merged.fontStyle, FontStyle.italic);
    });

    test('merge with all-null other returns this values', () {
      const base = OsRowStyle(
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      );
      const empty = OsRowStyle();

      final merged = base.merge(empty);
      expect(merged.backgroundColor, Colors.red);
      expect(merged.foregroundColor, Colors.white);
    });
  });

  group('RowStyleParams', () {
    test('creates instance with required parameters', () {
      const params = RowStyleParams<Map<String, dynamic>>(
        data: {'name': 'Alice', 'age': 30},
        rowIndex: 0,
      );
      expect(params.data, {'name': 'Alice', 'age': 30});
      expect(params.rowIndex, 0);
    });

    test('works with typed data', () {
      const params = RowStyleParams<String>(data: 'hello', rowIndex: 5);
      expect(params.data, 'hello');
      expect(params.rowIndex, 5);
    });
  });

  group('OsGridController.redrawRows', () {
    test('notifies listeners when called', () {
      final controller = OsGridController<Map<String, dynamic>>();
      int notifyCount = 0;
      controller.addListener(() => notifyCount++);

      controller.redrawRows();
      expect(notifyCount, 1);

      controller.redrawRows();
      expect(notifyCount, 2);

      controller.dispose();
    });
  });

  group('OsGrid with rowStyle', () {
    testWidgets('accepts static rowStyle parameter', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OsGrid(
              columnDefs: [OsColumnDef(field: 'name', headerName: 'Name')],
              rowData: [
                {'name': 'Alice'},
                {'name': 'Bob'},
              ],
              rowStyle: OsRowStyle(
                backgroundColor: Colors.yellow,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      );

      // Grid should render without error
      expect(find.byType(VirtualisedGrid), findsOneWidget);
    });

    testWidgets('accepts getRowStyle callback', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              columnDefs: [
                const OsColumnDef(field: 'name', headerName: 'Name'),
                const OsColumnDef(field: 'status', headerName: 'Status'),
              ],
              rowData: [
                {'name': 'Alice', 'status': 'active'},
                {'name': 'Bob', 'status': 'overdue'},
                {'name': 'Charlie', 'status': 'active'},
              ],
              getRowStyle: (params) {
                if (params.data['status'] == 'overdue') {
                  return const OsRowStyle(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  );
                }
                return null;
              },
            ),
          ),
        ),
      );

      expect(find.byType(VirtualisedGrid), findsOneWidget);
    });

    testWidgets('accepts both rowStyle and getRowStyle', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              columnDefs: [
                const OsColumnDef(field: 'name', headerName: 'Name'),
              ],
              rowData: [
                {'name': 'Alice'},
                {'name': 'Bob'},
              ],
              rowStyle: const OsRowStyle(fontWeight: FontWeight.w500),
              getRowStyle: (params) {
                if (params.rowIndex == 0) {
                  return const OsRowStyle(backgroundColor: Colors.green);
                }
                return null;
              },
            ),
          ),
        ),
      );

      expect(find.byType(VirtualisedGrid), findsOneWidget);
    });

    testWidgets('getRowStyle receives correct params', (tester) async {
      final receivedParams = <RowStyleParams<Map<String, dynamic>>>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 300,
              child: OsGrid<Map<String, dynamic>>(
                columnDefs: [
                  const OsColumnDef(field: 'name', headerName: 'Name'),
                ],
                rowData: [
                  {'name': 'Alice'},
                  {'name': 'Bob'},
                  {'name': 'Charlie'},
                ],
                getRowStyle: (params) {
                  receivedParams.add(params);
                  return null;
                },
              ),
            ),
          ),
        ),
      );

      // The callback should have been called for visible rows
      expect(receivedParams.isNotEmpty, isTrue);

      // Verify data and indices are correct
      final aliceParams = receivedParams.where(
        (p) => p.data['name'] == 'Alice',
      );
      expect(aliceParams.isNotEmpty, isTrue);
      expect(aliceParams.first.rowIndex, 0);

      final bobParams = receivedParams.where((p) => p.data['name'] == 'Bob');
      expect(bobParams.isNotEmpty, isTrue);
      expect(bobParams.first.rowIndex, 1);
    });

    testWidgets('redrawRows triggers rebuild', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();
      int callCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 300,
              child: OsGrid<Map<String, dynamic>>(
                controller: controller,
                columnDefs: [
                  const OsColumnDef(field: 'name', headerName: 'Name'),
                ],
                rowData: [
                  {'name': 'Alice'},
                ],
                getRowStyle: (params) {
                  callCount++;
                  return null;
                },
              ),
            ),
          ),
        ),
      );

      final initialCallCount = callCount;

      // Trigger redraw
      controller.redrawRows();
      await tester.pump();

      // The callback should have been called again
      expect(callCount, greaterThan(initialCallCount));

      controller.dispose();
    });

    testWidgets('getRowStyle returning null uses default styling', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              columnDefs: [
                const OsColumnDef(field: 'name', headerName: 'Name'),
              ],
              rowData: [
                {'name': 'Alice'},
              ],
              getRowStyle: (params) => null,
            ),
          ),
        ),
      );

      // Should render without error (default styling applies)
      expect(find.byType(VirtualisedGrid), findsOneWidget);
    });
  });

  group('VirtualisedGrid with rowStyles', () {
    testWidgets('accepts rowStyles parameter', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 300,
              child: VirtualisedGrid(
                columns: [OsColumnDef(field: 'name', headerName: 'Name')],
                rowData: [
                  {'name': 'Alice'},
                  {'name': 'Bob'},
                ],
                rowStyles: {
                  0: OsRowStyle(backgroundColor: Colors.red),
                  1: OsRowStyle(backgroundColor: Colors.blue),
                },
              ),
            ),
          ),
        ),
      );

      expect(find.byType(VirtualisedGrid), findsOneWidget);
    });

    testWidgets('renders without rowStyles (null)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 300,
              child: VirtualisedGrid(
                columns: [OsColumnDef(field: 'name', headerName: 'Name')],
                rowData: [
                  {'name': 'Alice'},
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byType(VirtualisedGrid), findsOneWidget);
    });
  });

  group('Row style merge behaviour (mirrors TypeScript Object.assign)', () {
    test('callback overrides static for same property', () {
      const staticStyle = OsRowStyle(
        backgroundColor: Colors.grey,
        foregroundColor: Colors.black,
      );
      const callbackStyle = OsRowStyle(backgroundColor: Colors.red);

      // Mirrors: Object.assign({}, rowStyle, rowStyleFuncResult)
      final merged = staticStyle.merge(callbackStyle);
      expect(merged.backgroundColor, Colors.red); // overridden
      expect(merged.foregroundColor, Colors.black); // kept from static
    });

    test('callback with all null does not override static', () {
      const staticStyle = OsRowStyle(
        backgroundColor: Colors.grey,
        fontWeight: FontWeight.bold,
      );
      const callbackStyle = OsRowStyle();

      final merged = staticStyle.merge(callbackStyle);
      expect(merged.backgroundColor, Colors.grey);
      expect(merged.fontWeight, FontWeight.bold);
    });

    test('full override replaces all properties', () {
      const staticStyle = OsRowStyle(
        backgroundColor: Colors.grey,
        foregroundColor: Colors.black,
        fontWeight: FontWeight.normal,
        fontStyle: FontStyle.normal,
      );
      const callbackStyle = OsRowStyle(
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        fontWeight: FontWeight.bold,
        fontStyle: FontStyle.italic,
      );

      final merged = staticStyle.merge(callbackStyle);
      expect(merged.backgroundColor, Colors.red);
      expect(merged.foregroundColor, Colors.white);
      expect(merged.fontWeight, FontWeight.bold);
      expect(merged.fontStyle, FontStyle.italic);
    });
  });
}
