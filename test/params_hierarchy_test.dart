import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

/// Params object consolidation (quality program v3 item 41).
///
/// Verifies the shared params hierarchies keep their public surface: the
/// same const constructors, named parameters and field types the params
/// exposed before the consolidation, with the shared storage living on the
/// `OsGridCallbackParams` / `OsGridEditCallbackParams` base classes.
void main() {
  const column = OsColumnDef<Map<String, dynamic>>(
    field: 'name',
    headerName: 'Name',
  );
  const data = <String, dynamic>{'id': 1, 'name': 'Alice'};

  group('OsGridCallbackParams — CellRendererParams', () {
    const params = CellRendererParams<Map<String, dynamic>>(
      value: 'Alice',
      data: data,
      rowIndex: 3,
      colDef: column,
    );

    test('extends the shared base', () {
      expect(params, isA<OsGridCallbackParams<Map<String, dynamic>>>());
    });

    test('keeps the public field surface', () {
      expect(params.value, 'Alice');
      expect(params.data, same(data));
      expect(params.rowIndex, 3);
      expect(params.colDef, same(column));
    });

    test('base-typed reference sees the same values', () {
      const OsGridCallbackParams<Map<String, dynamic>> base = params;
      expect(base.value, 'Alice');
      expect(base.data, same(data));
      expect(base.rowIndex, 3);
      expect(base.colDef, same(column));
    });

    test('stays const-constructible', () {
      const CellRendererParams<Map<String, dynamic>> other = CellRendererParams(
        value: 'Alice',
        data: data,
        rowIndex: 3,
        colDef: column,
      );
      expect(identical(params, other), isTrue);
    });

    test('works with dynamic data (painter call sites)', () {
      const dynamicParams = CellRendererParams(
        value: 42,
        data: <String, dynamic>{'id': 2},
        rowIndex: 0,
        colDef: OsColumnDef(field: 'value'),
      );
      expect(dynamicParams.value, 42);
      expect(dynamicParams.rowIndex, 0);
      expect(dynamicParams.colDef.field, 'value');
    });
  });

  group('OsGridCallbackParams — GetQuickFilterTextParams', () {
    test('extends the shared base and keeps the field surface', () {
      const params = GetQuickFilterTextParams<Map<String, dynamic>>(
        value: 'Alice',
        data: data,
        colDef: column,
      );
      expect(params, isA<OsGridCallbackParams<Map<String, dynamic>>>());
      expect(params.value, 'Alice');
      expect(params.data, same(data));
      expect(params.colDef, same(column));
      // rowIndex defaults to the "unknown index" convention.
      expect(params.rowIndex, -1);
    });

    test('accepts an explicit rowIndex (optional, non-breaking)', () {
      const params = GetQuickFilterTextParams<Map<String, dynamic>>(
        value: 'Alice',
        data: data,
        colDef: column,
        rowIndex: 7,
      );
      expect(params.rowIndex, 7);
    });
  });

  group('OsGridEditCallbackParams — ValueSetterParams', () {
    const params = ValueSetterParams<Map<String, dynamic>>(
      data: data,
      colDef: column,
      oldValue: 'Alicia',
      newValue: 'Alice',
      rowIndex: 1,
      source: 'edit',
    );

    test('extends the shared edit base', () {
      expect(params, isA<OsGridEditCallbackParams<Map<String, dynamic>>>());
    });

    test('keeps the public field surface', () {
      expect(params.data, same(data));
      expect(params.colDef, same(column));
      expect(params.oldValue, 'Alicia');
      expect(params.newValue, 'Alice');
      expect(params.rowIndex, 1);
      expect(params.source, 'edit');
    });

    test('base-typed reference sees the same values', () {
      const OsGridEditCallbackParams<Map<String, dynamic>> base = params;
      expect(base.data, same(data));
      expect(base.oldValue, 'Alicia');
      expect(base.rowIndex, 1);
      expect(base.source, 'edit');
    });

    test('source stays optional', () {
      const params = ValueSetterParams<Map<String, dynamic>>(
        data: data,
        colDef: column,
        oldValue: null,
        newValue: 'Bob',
        rowIndex: 2,
      );
      expect(params.source, isNull);
      expect(params.newValue, 'Bob');
    });
  });

  group('OsGridEditCallbackParams — ValueParserParams', () {
    const params = ValueParserParams<Map<String, dynamic>>(
      data: data,
      colDef: column,
      oldValue: 'Alicia',
      newValue: 'Alice',
      rowIndex: 4,
    );

    test('extends the shared edit base', () {
      expect(params, isA<OsGridEditCallbackParams<Map<String, dynamic>>>());
    });

    test('keeps the public field surface with String newValue', () {
      expect(params.data, same(data));
      expect(params.oldValue, 'Alicia');
      expect(params.newValue, isA<String>());
      expect(params.newValue, 'Alice');
      expect(params.rowIndex, 4);
      expect(params.source, isNull);
    });

    test('stays const-constructible', () {
      const ValueParserParams<Map<String, dynamic>> other = ValueParserParams(
        data: data,
        colDef: column,
        oldValue: 'Alicia',
        newValue: 'Alice',
        rowIndex: 4,
      );
      expect(identical(params, other), isTrue);
    });
  });

  group('params in grid callbacks still receive consolidated params', () {
    // The paint path invokes per-cell callbacks through the raw OsColumnDef
    // with CellRendererParams<dynamic>, so the closures must be typed over
    // `dynamic` (pre-existing limitation, see theme_cascade_test.dart).
    testWidgets('cellStyle receives an OsGridCallbackParams', (tester) async {
      CellRendererParams<dynamic>? received;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid(
              columnDefs: [
                OsColumnDef<dynamic>(
                  field: 'name',
                  headerName: 'Name',
                  cellStyle: (params) {
                    received = params;
                    return const OsCellStyle();
                  },
                ),
              ],
              rowData: const [data],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The body painter invokes cellStyle once per painted cell with the
      // consolidated params object.
      expect(received, isNotNull);
      expect(received, isA<OsGridCallbackParams<dynamic>>());
      expect(received!.data, same(data));
      expect(received!.value, 'Alice');
      expect(received!.rowIndex, 0);
      expect(received!.colDef.field, 'name');
    });

    testWidgets('editableCallback receives an OsGridCallbackParams', (
      tester,
    ) async {
      CellRendererParams<dynamic>? received;
      final controller = OsGridController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid(
              controller: controller,
              columnDefs: [
                OsColumnDef<dynamic>(
                  field: 'name',
                  headerName: 'Name',
                  editable: true,
                  editableCallback: (params) {
                    received = params;
                    return true;
                  },
                ),
              ],
              rowData: const [data],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Programmatic edit start checks editability via editableCallback
      // with the consolidated params.
      controller.startEditingCell(rowIndex: 0, colId: 'name');
      await tester.pumpAndSettle();

      expect(received, isNotNull);
      expect(received, isA<OsGridCallbackParams<dynamic>>());
      expect(received!.data, same(data));
      expect(received!.rowIndex, 0);
    });
  });
}
