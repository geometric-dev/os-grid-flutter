import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';
import 'package:os_grid_flutter/src/utils/grid_diagnostics.dart';

/// Minimal typed row class for data-shape checks.
class _Person {
  const _Person(this.name, this.age);
  final String name;
  final int age;
}

void main() {
  /// Captures debugPrint output during a callback.
  List<String> captureWarnings(void Function() fn) {
    final warnings = <String>[];
    final originalDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) warnings.add(message);
    };
    try {
      fn();
    } finally {
      debugPrint = originalDebugPrint;
    }
    return warnings;
  }

  /// Default params for validate() — a valid configuration with no warnings.
  void validateWith<TData>({
    List<OsColumnDefBase>? columnDefs,
    List<TData>? rowData,
    OsRowSelection? rowSelection,
    OsCellSelection? cellSelection,
    OsPagination? pagination,
    bool undoRedoCellEditing = false,
    bool singleClickEdit = false,
    bool suppressClickEdit = false,
    bool enterNavigatesVertically = false,
    bool enterNavigatesVerticallyAfterEdit = false,
    bool floatingFilter = false,
    bool rowDrag = false,
    bool rowDragManaged = true,
    String? Function(dynamic data)? getRowId,
    ValueChanged<dynamic>? onRowDragEnd,
  }) {
    OsGridValidator.validate(
      columnDefs: columnDefs ?? [const OsColumnDef(field: 'name')],
      rowData: rowData,
      rowSelection: rowSelection,
      cellSelection: cellSelection,
      pagination: pagination,
      undoRedoCellEditing: undoRedoCellEditing,
      singleClickEdit: singleClickEdit,
      suppressClickEdit: suppressClickEdit,
      enterNavigatesVertically: enterNavigatesVertically,
      enterNavigatesVerticallyAfterEdit: enterNavigatesVerticallyAfterEdit,
      floatingFilter: floatingFilter,
      rowDrag: rowDrag,
      rowDragManaged: rowDragManaged,
      getRowId: getRowId,
      onRowDragEnd: onRowDragEnd,
    );
  }

  group('OsGridValidator', () {
    // Validator warnings are once-per-key per process lifetime (item 28);
    // reset the memory between tests so each test starts from a clean slate.
    setUp(GridDiagnostics.resetWarnedKeys);

    test('no warnings for valid configuration', () {
      final warnings = captureWarnings(() {
        validateWith(
          columnDefs: [
            const OsColumnDef(field: 'name', headerName: 'Name'),
            const OsColumnDef(field: 'age', headerName: 'Age'),
          ],
        );
      });

      expect(warnings, isEmpty);
    });

    test('warns when columnDefs is empty', () {
      final warnings = captureWarnings(() {
        validateWith(columnDefs: []);
      });

      expect(warnings, hasLength(1));
      expect(warnings.first, contains('[OS Grid]'));
      expect(warnings.first, contains('columnDefs is empty'));
    });

    test('warns when editable column has no cellEditor', () {
      final warnings = captureWarnings(() {
        validateWith(
          columnDefs: [const OsColumnDef(field: 'name', editable: true)],
        );
      });

      expect(warnings, hasLength(1));
      expect(warnings.first, contains('[OS Grid]'));
      expect(warnings.first, contains('editable: true'));
      expect(warnings.first, contains('no cellEditor'));
      expect(warnings.first, contains('name'));
    });

    test('no warning when editable column has cellEditor', () {
      final warnings = captureWarnings(() {
        validateWith(
          columnDefs: [
            const OsColumnDef(
              field: 'name',
              editable: true,
              cellEditor: OsTextCellEditor(),
            ),
          ],
        );
      });

      expect(warnings, isEmpty);
    });

    test('warns when filter set but floatingFilter not enabled', () {
      final warnings = captureWarnings(() {
        validateWith(
          columnDefs: [
            const OsColumnDef(field: 'name', filter: OsTextFilter()),
          ],
          floatingFilter: false,
        );
      });

      expect(warnings, hasLength(1));
      expect(warnings.first, contains('[OS Grid]'));
      expect(warnings.first, contains('filter'));
      expect(warnings.first, contains('floatingFilter'));
    });

    test('no warning when filter set and floatingFilter enabled', () {
      final warnings = captureWarnings(() {
        validateWith(
          columnDefs: [
            const OsColumnDef(field: 'name', filter: OsTextFilter()),
          ],
          floatingFilter: true,
        );
      });

      expect(warnings, isEmpty);
    });

    test('warns when rowSelection set but getRowId not provided', () {
      final warnings = captureWarnings(() {
        validateWith(rowSelection: OsRowSelection.single());
      });

      expect(warnings, hasLength(1));
      expect(warnings.first, contains('[OS Grid]'));
      expect(warnings.first, contains('rowSelection'));
      expect(warnings.first, contains('getRowId'));
    });

    test('no warning when rowSelection set with getRowId', () {
      final warnings = captureWarnings(() {
        validateWith(
          rowSelection: OsRowSelection.single(),
          getRowId: (data) => data['id'].toString(),
        );
      });

      expect(warnings, isEmpty);
    });

    test('warns when undoRedoCellEditing enabled but no editable columns', () {
      final warnings = captureWarnings(() {
        validateWith(
          columnDefs: [
            const OsColumnDef(field: 'name'),
            const OsColumnDef(field: 'age'),
          ],
          undoRedoCellEditing: true,
        );
      });

      expect(warnings, hasLength(1));
      expect(warnings.first, contains('[OS Grid]'));
      expect(warnings.first, contains('undoRedoCellEditing'));
      expect(warnings.first, contains('no columns have editable'));
    });

    test('no warning when undoRedoCellEditing with editable column', () {
      final warnings = captureWarnings(() {
        validateWith(
          columnDefs: [const OsColumnDef(field: 'name', editable: true)],
          undoRedoCellEditing: true,
        );
      });

      // Only the editable-without-editor warning, not the undo/redo one
      expect(warnings.where((w) => w.contains('undoRedoCellEditing')), isEmpty);
    });

    test('warns when pagination pageSize is zero', () {
      final warnings = captureWarnings(() {
        validateWith(pagination: const OsPagination(pageSize: 0));
      });

      expect(warnings, hasLength(1));
      expect(warnings.first, contains('[OS Grid]'));
      expect(warnings.first, contains('pageSize'));
      expect(warnings.first, contains('0'));
    });

    test('warns when pagination pageSize is negative', () {
      final warnings = captureWarnings(() {
        validateWith(pagination: const OsPagination(pageSize: -5));
      });

      expect(warnings, hasLength(1));
      expect(warnings.first, contains('[OS Grid]'));
      expect(warnings.first, contains('pageSize'));
      expect(warnings.first, contains('-5'));
    });

    test('no warning when pagination pageSize is positive', () {
      final warnings = captureWarnings(() {
        validateWith(pagination: const OsPagination(pageSize: 50));
      });

      expect(warnings, isEmpty);
    });

    test('warns when rowDrag unmanaged without onRowDragEnd', () {
      final warnings = captureWarnings(() {
        validateWith(rowDrag: true, rowDragManaged: false);
      });

      expect(warnings, hasLength(1));
      expect(warnings.first, contains('[OS Grid]'));
      expect(warnings.first, contains('rowDrag'));
      expect(warnings.first, contains('rowDragManaged: false'));
      expect(warnings.first, contains('onRowDragEnd'));
    });

    test('no warning when rowDrag unmanaged with onRowDragEnd', () {
      final warnings = captureWarnings(() {
        validateWith(
          rowDrag: true,
          rowDragManaged: false,
          onRowDragEnd: (_) {},
        );
      });

      expect(warnings, isEmpty);
    });

    test('no warning when rowDrag managed (default)', () {
      final warnings = captureWarnings(() {
        validateWith(rowDrag: true, rowDragManaged: true);
      });

      expect(warnings, isEmpty);
    });

    test('warns when cellSelection with multiple rowSelection', () {
      final warnings = captureWarnings(() {
        validateWith(
          cellSelection: const OsCellSelection(),
          rowSelection: OsRowSelection.multiple(),
          getRowId: (data) => data['id'].toString(),
        );
      });

      expect(warnings, hasLength(1));
      expect(warnings.first, contains('[OS Grid]'));
      expect(warnings.first, contains('cellSelection'));
      expect(warnings.first, contains('multiple'));
    });

    test('no warning when cellSelection with single rowSelection', () {
      final warnings = captureWarnings(() {
        validateWith(
          cellSelection: const OsCellSelection(),
          rowSelection: OsRowSelection.single(),
          getRowId: (data) => data['id'].toString(),
        );
      });

      expect(warnings, isEmpty);
    });

    test('warns when singleClickEdit and suppressClickEdit both true', () {
      final warnings = captureWarnings(() {
        validateWith(singleClickEdit: true, suppressClickEdit: true);
      });

      expect(warnings, hasLength(1));
      expect(warnings.first, contains('[OS Grid]'));
      expect(warnings.first, contains('singleClickEdit'));
      expect(warnings.first, contains('suppressClickEdit'));
    });

    test('warns when both enterNavigatesVertically options are true', () {
      final warnings = captureWarnings(() {
        validateWith(
          enterNavigatesVertically: true,
          enterNavigatesVerticallyAfterEdit: true,
        );
      });

      expect(warnings, hasLength(1));
      expect(warnings.first, contains('[OS Grid]'));
      expect(warnings.first, contains('enterNavigatesVertically'));
      expect(warnings.first, contains('enterNavigatesVerticallyAfterEdit'));
    });

    test('handles nested column groups', () {
      final warnings = captureWarnings(() {
        validateWith(
          columnDefs: [
            const OsColumnGroup(
              headerName: 'Personal',
              children: [
                OsColumnDef(field: 'name', editable: true),
                OsColumnGroup(
                  headerName: 'Details',
                  children: [OsColumnDef(field: 'age', editable: true)],
                ),
              ],
            ),
          ],
        );
      });

      // Should find both editable columns without cellEditor
      expect(warnings, hasLength(2));
      expect(warnings[0], contains('name'));
      expect(warnings[1], contains('age'));
    });

    test('all warnings use [OS Grid] prefix', () {
      final warnings = captureWarnings(() {
        validateWith(columnDefs: []);
      });

      for (final warning in warnings) {
        expect(warning, startsWith('[OS Grid]'));
      }
    });

    test('multiple warnings can fire simultaneously', () {
      final warnings = captureWarnings(() {
        validateWith(
          columnDefs: [const OsColumnDef(field: 'name', editable: true)],
          singleClickEdit: true,
          suppressClickEdit: true,
          undoRedoCellEditing: false,
        );
      });

      // editable without editor + contradictory click edit
      expect(warnings, hasLength(2));
    });

    test(
      'filter warning only fires once even with multiple filter columns',
      () {
        final warnings = captureWarnings(() {
          validateWith(
            columnDefs: [
              const OsColumnDef(field: 'name', filter: OsTextFilter()),
              const OsColumnDef(field: 'age', filter: OsNumberFilter()),
              const OsColumnDef(field: 'date', filter: OsDateFilter()),
            ],
            floatingFilter: false,
          );
        });

        final filterWarnings = warnings
            .where((w) => w.contains('floatingFilter'))
            .toList();
        expect(filterWarnings, hasLength(1));
      },
    );
  });

  group('OsGridValidator map row data without getRowId', () {
    setUp(GridDiagnostics.resetWarnedKeys);

    List<String> warningsFor(List<String> warnings, String needle) =>
        warnings.where((w) => w.contains(needle)).toList();

    test('warns for Map rows without getRowId', () {
      final warnings = captureWarnings(() {
        validateWith<Map<String, dynamic>>(
          rowData: [
            {'name': 'Alice'},
            {'name': 'Bob'},
          ],
        );
      });

      final mapWarnings = warningsFor(warnings, 'Consider providing getRowId');
      expect(mapWarnings, hasLength(1));
      expect(mapWarnings.single, startsWith('[OS Grid] '));
      // Steering message names both recommended patterns.
      expect(mapWarnings.single, contains('OsGrid<TData>'));
      expect(mapWarnings.single, contains('getRowId'));
    });

    test('does not warn when getRowId is provided with Map rows', () {
      final warnings = captureWarnings(() {
        validateWith<Map<String, dynamic>>(
          rowData: [
            {'name': 'Alice'},
          ],
          getRowId: (data) => data['name'].toString(),
        );
      });

      expect(warningsFor(warnings, 'Consider providing getRowId'), isEmpty);
    });

    test('does not warn for typed rows without getRowId', () {
      final warnings = captureWarnings(() {
        validateWith<_Person>(
          rowData: const [_Person('Alice', 32), _Person('Bob', 28)],
        );
      });

      expect(warnings, isEmpty);
    });

    test('does not warn for typed rows even with getRowId absent and '
        'mixed config', () {
      final warnings = captureWarnings(() {
        validateWith<_Person>(
          rowData: const [_Person('Alice', 32)],
          rowSelection: OsRowSelection.multiple(),
        );
      });

      // Only the selection-without-getRowId warning may fire; never the
      // Map-row-data warning.
      expect(warningsFor(warnings, 'Consider providing getRowId'), isEmpty);
      expect(warningsFor(warnings, 'rowSelection'), hasLength(1));
    });

    test('does not warn when rowData is null or empty', () {
      final warningsNull = captureWarnings(() {
        validateWith(rowData: null);
      });
      final warningsEmpty = captureWarnings(() {
        validateWith<Map<String, dynamic>>(rowData: const []);
      });

      expect(warningsNull, isEmpty);
      expect(warningsEmpty, isEmpty);
    });

    test('warns at most once across repeated validations (warnOnce)', () {
      late List<String> warnings;
      warnings = captureWarnings(() {
        for (var i = 0; i < 3; i++) {
          validateWith<Map<String, dynamic>>(
            rowData: [
              {'name': 'Alice'},
            ],
          );
        }
      });

      expect(
        warningsFor(warnings, 'Consider providing getRowId'),
        hasLength(1),
      );
    });
  });

  group('OsGrid Map row data warning — widget integration', () {
    setUp(GridDiagnostics.resetWarnedKeys);

    /// Pumps a minimal grid with Map row data and captures debugPrint output.
    Future<List<String>> pumpMapRowGrid(
      WidgetTester tester, {
      required bool suppressValidation,
      String Function(Map<String, dynamic>)? getRowId,
    }) async {
      final warnings = <String>[];
      final originalDebugPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) warnings.add(message);
      };
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: OsGrid<Map<String, dynamic>>(
                columnDefs: [
                  const OsColumnDef<Map<String, dynamic>>(field: 'name'),
                ],
                rowData: const [
                  {'name': 'Alice'},
                ],
                getRowId: getRowId,
                suppressGridOptionsValidation: suppressValidation,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      } finally {
        debugPrint = originalDebugPrint;
      }
      return warnings;
    }

    testWidgets('warns once for Map rows without getRowId', (tester) async {
      final warnings = await pumpMapRowGrid(tester, suppressValidation: false);

      final mapWarnings = warnings
          .where((w) => w.contains('Consider providing getRowId'))
          .toList();
      expect(mapWarnings, hasLength(1));
      expect(mapWarnings.single, startsWith('[OS Grid] '));
    });

    testWidgets('does not warn when getRowId is provided', (tester) async {
      final warnings = await pumpMapRowGrid(
        tester,
        suppressValidation: false,
        getRowId: (row) => row['name'].toString(),
      );

      expect(
        warnings.where((w) => w.contains('Consider providing getRowId')),
        isEmpty,
      );
    });

    testWidgets('does not warn when validation is suppressed', (tester) async {
      final warnings = await pumpMapRowGrid(tester, suppressValidation: true);

      expect(warnings.where((w) => w.startsWith('[OS Grid]')), isEmpty);
    });

    testWidgets('does not warn for typed rows without getRowId', (
      tester,
    ) async {
      final warnings = <String>[];
      final originalDebugPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) warnings.add(message);
      };
      try {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: OsGrid<_Person>(
                columnDefs: [OsColumnDef<_Person>(field: 'name')],
                rowData: [_Person('Alice', 32)],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      } finally {
        debugPrint = originalDebugPrint;
      }

      expect(
        warnings.where((w) => w.contains('Consider providing getRowId')),
        isEmpty,
      );
    });
  });
}
