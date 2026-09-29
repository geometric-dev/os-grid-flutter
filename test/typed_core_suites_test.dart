import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

/// Typed-data variants of core suites (sorting, text filter, selection,
/// clipboard round-trip, editing commits).
///
/// Each scenario runs twice against the same logical dataset â€” once as
/// untyped `Map<String, dynamic>` rows and once as a typed row class
/// resolved via `valueGetter` â€” asserting identical behaviour (mirrors the
/// pattern from typed_grouping_test.dart).

class _Person {
  const _Person(this.id, this.name, this.country, this.age);
  final String id;
  final String name;
  final String country;
  final int age;
}

const _typedPeople = [
  _Person('p1', 'Alice', 'UK', 32),
  _Person('p2', 'Bob', 'US', 28),
  _Person('p3', 'Alice', 'CA', 45),
  _Person('p4', 'Dana', 'UK', 21),
  _Person('p5', 'Bob', 'US', 36),
];

final _mapPeople = <Map<String, dynamic>>[
  {'id': 'p1', 'name': 'Alice', 'country': 'UK', 'age': 32},
  {'id': 'p2', 'name': 'Bob', 'country': 'US', 'age': 28},
  {'id': 'p3', 'name': 'Alice', 'country': 'CA', 'age': 45},
  {'id': 'p4', 'name': 'Dana', 'country': 'UK', 'age': 21},
  {'id': 'p5', 'name': 'Bob', 'country': 'US', 'age': 36},
];

/// Mutable twin of [_Person] for the write-path suites (clipboard paste,
/// editing commits): the grid writes through `valueSetter`, so row fields
/// must be assignable â€” final DTOs need a setter that rebuilds a store.
class _EditablePerson {
  _EditablePerson(this.id, this.name, this.age);
  final String id;
  String name;
  int age;
}

String _nameOf(Object? row) => switch (row) {
  final Map<String, dynamic> m => m['name'] as String,
  final _EditablePerson e => e.name,
  _ => throw ArgumentError.value(row, 'row', 'unknown row kind'),
};

/// Separate id resolver: the shared [_rowIdOf] casts to [_Person], which
/// would reject [_EditablePerson] rows.
String _editableRowIdOf(Object? row) => switch (row) {
  final Map<String, dynamic> m => m['id'] as String,
  final _EditablePerson e => e.id,
  _ => throw ArgumentError.value(row, 'row', 'unknown row kind'),
};

int _ageOf(Object? row) => switch (row) {
  final Map<String, dynamic> m => m['age'] as int,
  final _EditablePerson e => e.age,
  _ => throw ArgumentError.value(row, 'row', 'unknown row kind'),
};

/// Installs an in-memory platform-channel clipboard for the current test
/// so `Clipboard.setData` / `Clipboard.getData` round-trip without a
/// real platform.
void _installClipboardMock(WidgetTester tester, StringBuffer buffer) {
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (MethodCall call) async {
      switch (call.method) {
        case 'Clipboard.setData':
          buffer
            ..clear()
            ..write(
              (call.arguments as Map<Object?, Object?>)['text'] as String,
            );
        case 'Clipboard.getData':
          final text = buffer.toString();
          return text.isEmpty ? null : <String, Object?>{'text': text};
      }
      return null;
    },
  );
}

void _resetClipboardMock(WidgetTester tester) {
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    null,
  );
}

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: SizedBox(width: 800, height: 600, child: child)),
);

String _personId(ValueGetterParams<_Person> params) => params.data.id;
String _personName(ValueGetterParams<_Person> params) => params.data.name;
int _personAge(ValueGetterParams<_Person> params) => params.data.age;

String _rowIdOf(dynamic row) =>
    row is Map<String, dynamic> ? row['id'] as String : (row as _Person).id;

List<String> _displayIds(WidgetTester tester) {
  final grid = tester.widget<VirtualisedGrid>(find.byType(VirtualisedGrid));
  return [for (final row in grid.rowData) _rowIdOf(row)];
}

void main() {
  group('Sorting suite (Map vs typed)', () {
    Future<List<String>> pumpAndRead(
      WidgetTester tester, {
      required List<OsSortModel> sort,
    }) async {
      await tester.pumpWidget(
        _wrap(
          OsGrid<Map<String, dynamic>>(
            columnDefs: const [
              OsColumnDef(field: 'id', width: 80),
              OsColumnDef(field: 'name', width: 100, sortable: true),
              OsColumnDef(field: 'age', width: 80, sortable: true),
            ],
            rowData: _mapPeople,
            getRowId: (r) => r['id'] as String,
            initialSort: sort,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final mapOrder = _displayIds(tester);
      await tester.pumpWidget(const SizedBox.shrink());

      await tester.pumpWidget(
        _wrap(
          OsGrid<_Person>(
            columnDefs: const [
              OsColumnDef<_Person>(
                field: 'id',
                width: 80,
                valueGetter: _personId,
              ),
              OsColumnDef<_Person>(
                field: 'name',
                width: 100,
                sortable: true,
                valueGetter: _personName,
              ),
              OsColumnDef<_Person>(
                field: 'age',
                width: 80,
                sortable: true,
                valueGetter: _personAge,
              ),
            ],
            rowData: _typedPeople,
            getRowId: (p) => p.id,
            initialSort: sort,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final typedOrder = _displayIds(tester);
      await tester.pumpWidget(const SizedBox.shrink());

      expect(typedOrder, mapOrder);
      return mapOrder;
    }

    testWidgets('single ascending sort matches across data kinds', (
      tester,
    ) async {
      final order = await pumpAndRead(
        tester,
        sort: const [
          OsSortModel(colId: 'name', sort: OsSortDirection.ascending),
        ],
      );
      // Stable: ties keep original order.
      expect(order, ['p1', 'p3', 'p2', 'p5', 'p4']);
    });

    testWidgets('descending numeric sort matches across data kinds', (
      tester,
    ) async {
      final order = await pumpAndRead(
        tester,
        sort: const [
          OsSortModel(colId: 'age', sort: OsSortDirection.descending),
        ],
      );
      expect(order.first, 'p3');
      expect(order.last, 'p4');
    });

    testWidgets('multi-sort priority matches across data kinds', (
      tester,
    ) async {
      final order = await pumpAndRead(
        tester,
        sort: const [
          OsSortModel(colId: 'name', sort: OsSortDirection.ascending),
          OsSortModel(colId: 'age', sort: OsSortDirection.descending),
        ],
      );
      expect(order, ['p3', 'p1', 'p5', 'p2', 'p4']);
    });
  });

  group('Text filter suite (Map vs typed)', () {
    testWidgets('equals filter resolves typed values identically', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();
      await tester.pumpWidget(
        _wrap(
          OsGrid<Map<String, dynamic>>(
            controller: controller,
            columnDefs: const [
              OsColumnDef(field: 'id', width: 80),
              OsColumnDef(field: 'name', width: 100, filter: OsTextFilter()),
            ],
            rowData: _mapPeople,
            getRowId: (r) => r['id'] as String,
          ),
        ),
      );
      await tester.pumpAndSettle();
      controller.setFilterModel({
        'name': const OsColumnFilterModel(
          filterType: 'text',
          conditions: [OsFilterCondition(type: 'equals', filter: 'Bob')],
        ).toJson(),
      });
      await tester.pumpAndSettle();
      final mapResult = _displayIds(tester);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(mapResult, ['p2', 'p5']);

      final typedController = OsGridController<_Person>();
      await tester.pumpWidget(
        _wrap(
          OsGrid<_Person>(
            controller: typedController,
            columnDefs: const [
              OsColumnDef<_Person>(
                field: 'id',
                width: 80,
                valueGetter: _personId,
              ),
              OsColumnDef<_Person>(
                field: 'name',
                width: 100,
                filter: OsTextFilter(),
                valueGetter: _personName,
              ),
            ],
            rowData: _typedPeople,
            getRowId: (p) => p.id,
          ),
        ),
      );
      await tester.pumpAndSettle();
      typedController.setFilterModel({
        'name': const OsColumnFilterModel(
          filterType: 'text',
          conditions: [OsFilterCondition(type: 'equals', filter: 'Bob')],
        ).toJson(),
      });
      await tester.pumpAndSettle();

      expect(_displayIds(tester), mapResult);
    });

    testWidgets('contains filter resolves typed values identically', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();
      await tester.pumpWidget(
        _wrap(
          OsGrid<Map<String, dynamic>>(
            controller: controller,
            columnDefs: const [
              OsColumnDef(field: 'id', width: 80),
              OsColumnDef(field: 'name', width: 100, filter: OsTextFilter()),
            ],
            rowData: _mapPeople,
            getRowId: (r) => r['id'] as String,
          ),
        ),
      );
      await tester.pumpAndSettle();
      controller.setFilterModel({
        'name': const OsColumnFilterModel(
          filterType: 'text',
          conditions: [OsFilterCondition(type: 'contains', filter: 'li')],
        ).toJson(),
      });
      await tester.pumpAndSettle();
      final mapResult = _displayIds(tester);
      expect(mapResult, ['p1', 'p3']);
      await tester.pumpWidget(const SizedBox.shrink());

      final typedController = OsGridController<_Person>();
      await tester.pumpWidget(
        _wrap(
          OsGrid<_Person>(
            controller: typedController,
            columnDefs: const [
              OsColumnDef<_Person>(
                field: 'id',
                width: 80,
                valueGetter: _personId,
              ),
              OsColumnDef<_Person>(
                field: 'name',
                width: 100,
                filter: OsTextFilter(),
                valueGetter: _personName,
              ),
            ],
            rowData: _typedPeople,
            getRowId: (p) => p.id,
          ),
        ),
      );
      await tester.pumpAndSettle();
      typedController.setFilterModel({
        'name': const OsColumnFilterModel(
          filterType: 'text',
          conditions: [OsFilterCondition(type: 'contains', filter: 'li')],
        ).toJson(),
      });
      await tester.pumpAndSettle();

      expect(_displayIds(tester), mapResult);
    });
  });

  group('Selection suite (Map vs typed)', () {
    testWidgets('select-by-id survives reorder for both data kinds', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();
      Widget buildMaps(List<Map<String, dynamic>> data) => _wrap(
        OsGrid<Map<String, dynamic>>(
          controller: controller,
          columnDefs: const [OsColumnDef(field: 'id', width: 120)],
          rowData: data,
          getRowId: (r) => r['id'] as String,
          rowSelection: OsRowSelection.multiple(),
        ),
      );

      await tester.pumpWidget(buildMaps(_mapPeople));
      await tester.pumpAndSettle();
      controller.selectRowsById(['p1', 'p4']);
      await tester.pumpAndSettle();

      final shuffledMaps = [..._mapPeople]..shuffle(Random(9));
      await tester.pumpWidget(buildMaps(shuffledMaps));
      await tester.pumpAndSettle();

      final mapSelection = controller.getSelectedIds();
      expect(mapSelection, {'p1', 'p4'});
      await tester.pumpWidget(const SizedBox.shrink());

      final typedController = OsGridController<_Person>();
      Widget buildTyped(List<_Person> data) => _wrap(
        OsGrid<_Person>(
          controller: typedController,
          columnDefs: const [
            OsColumnDef<_Person>(
              field: 'id',
              width: 120,
              valueGetter: _personId,
            ),
          ],
          rowData: data,
          getRowId: (p) => p.id,
          rowSelection: OsRowSelection.multiple(),
        ),
      );

      await tester.pumpWidget(buildTyped(_typedPeople));
      await tester.pumpAndSettle();
      typedController.selectRowsById(['p1', 'p4']);
      await tester.pumpAndSettle();

      final shuffledTyped = [..._typedPeople]..shuffle(Random(9));
      await tester.pumpWidget(buildTyped(shuffledTyped));
      await tester.pumpAndSettle();

      expect(typedController.getSelectedIds().toSet(), mapSelection.toSet());
      expect(typedController.getSelectedRows().map((p) => p.id).toSet(), {
        'p1',
        'p4',
      });
    });
  });

  group('Clipboard suite (Map vs typed)', () {
    // Local fixtures: the round-trip mutates rows, so shared top-level
    // lists must never be touched.
    List<_EditablePerson> editablePeople() => [
      _EditablePerson('p1', 'Alice', 32),
      _EditablePerson('p2', 'Bob', 28),
      _EditablePerson('p3', 'Carol', 45),
      _EditablePerson('p4', 'Dana', 21),
    ];

    List<Map<String, dynamic>> editableMaps() => const [
      {'id': 'p1', 'name': 'Alice', 'age': 32},
      {'id': 'p2', 'name': 'Bob', 'age': 28},
      {'id': 'p3', 'name': 'Carol', 'age': 45},
      {'id': 'p4', 'name': 'Dana', 'age': 21},
    ].map((r) => Map<String, dynamic>.of(r)).toList();

    Widget buildGrid({
      required OsGridController<Object?> controller,
      required List<Object?> data,
    }) {
      List<OsColumnDef<Object?>> columns() => [
        const OsColumnDef<Object?>(field: 'id', width: 80),
        OsColumnDef<Object?>(
          field: 'name',
          width: 100,
          editable: true,
          valueGetter: (p) => switch (p.data) {
            final Map<String, dynamic> m => m['name'],
            final _EditablePerson e => e.name,
            _ => null,
          },
          valueSetter: (p) {
            switch (p.data) {
              case final Map<String, dynamic> m:
                m['name'] = p.newValue;
              case final _EditablePerson e:
                e.name = p.newValue as String;
            }
            return true;
          },
        ),
        OsColumnDef<Object?>(
          field: 'age',
          width: 80,
          editable: true,
          valueGetter: (p) => switch (p.data) {
            final Map<String, dynamic> m => m['age'],
            final _EditablePerson e => e.age,
            _ => null,
          },
          valueSetter: (p) {
            switch (p.data) {
              case final Map<String, dynamic> m:
                m['age'] = p.newValue;
              case final _EditablePerson e:
                e.age = p.newValue as int;
            }
            return true;
          },
        ),
      ];

      return _wrap(
        OsGrid<Object?>(
          controller: controller,
          columnDefs: columns(),
          rowData: data,
          getRowId: _editableRowIdOf,
          cellSelection: const OsCellSelection(),
        ),
      );
    }

    testWidgets('copy range then paste elsewhere round-trips identically', (
      tester,
    ) async {
      Future<(String, ({String n3, int a3, String n4, int a4}))> run(
        String kind,
      ) async {
        final controller = OsGridController<Object?>();
        final data = kind == 'map'
            ? editableMaps().cast<Object?>().toList()
            : editablePeople().cast<Object?>().toList();
        final clipboard = StringBuffer();
        _installClipboardMock(tester, clipboard);
        addTearDown(() => _resetClipboardMock(tester));

        await tester.pumpWidget(buildGrid(controller: controller, data: data));
        await tester.pumpAndSettle();

        controller.addCellRange(
          const CellRangeParams(
            rowStartIndex: 0,
            rowEndIndex: 1,
            columnStartIndex: 1,
            columnEndIndex: 2,
          ),
        );
        await tester.pumpAndSettle();
        controller.copyToClipboard();
        await tester.pump();
        final tsv = clipboard.toString();

        // Paste the same block onto rows p3/p4 starting at 'name'
        // (the mock clipboard still holds the copied TSV). The copied range
        // is cleared first: with an active range a multi-cell clipboard
        // pastes into the range (quality program v3 item 10), while this
        // test exercises the focused-cell path.
        controller.clearRangeSelection();
        controller.setFocusedCell(rowIndex: 2, columnIndex: 1);
        await tester.pumpAndSettle();
        controller.pasteFromClipboard();
        await tester.pump();
        await tester.pump();

        await tester.pumpWidget(const SizedBox.shrink());
        return (
          tsv,
          (
            n3: _nameOf(data[2]),
            a3: _ageOf(data[2]),
            n4: _nameOf(data[3]),
            a4: _ageOf(data[3]),
          ),
        );
      }

      final mapResult = await run('map');
      final typedResult = await run('typed');

      expect(mapResult.$1, typedResult.$1);
      expect(mapResult.$1, 'Alice\t32\nBob\t28');
      expect(mapResult.$2.n3, 'Alice');
      expect(mapResult.$2.a3, 32);
      expect(mapResult.$2.n4, 'Bob');
      expect(mapResult.$2.a4, 28);
      expect(typedResult.$2.a3, isA<int>(), reason: 'paste keeps int type');
    });
  });

  group('Editing commit suite (Map vs typed)', () {
    testWidgets('enterText + stopEditing commits through valueSetter', (
      tester,
    ) async {
      Future<String> editNameOfFirstRow(String kind) async {
        final controller = OsGridController<Object?>();
        final maps = <Object?>[
          Map<String, dynamic>.of(const {'id': 'p1', 'name': 'Alice'}),
        ];
        final people = <Object?>[_EditablePerson('p1', 'Alice', 32)];
        final data = kind == 'map' ? maps : people;

        await tester.pumpWidget(
          _wrap(
            OsGrid<Object?>(
              controller: controller,
              columnDefs: [
                // Typed rows are not Maps: without a valueSetter the
                // default commit path cannot write, so provide one
                // (this is the write-through under test).
                OsColumnDef<Object?>(
                  field: 'name',
                  width: 120,
                  editable: true,
                  valueSetter: (p) {
                    switch (p.data) {
                      case final Map<String, dynamic> m:
                        m['name'] = p.newValue;
                      case final _EditablePerson e:
                        e.name = p.newValue as String;
                    }
                    return true;
                  },
                ),
              ],
              rowData: data,
              getRowId: _editableRowIdOf,
              singleClickEdit: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        controller.startEditingCell(rowIndex: 0, colId: 'name');
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(EditableText).last, 'Alicia');
        controller.stopEditing();
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox.shrink());

        return _nameOf(data.single);
      }

      expect(await editNameOfFirstRow('map'), 'Alicia');
      expect(await editNameOfFirstRow('typed'), 'Alicia');
    });
  });
}
