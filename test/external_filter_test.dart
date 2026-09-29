import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

/// Helper to collect filtered rows from the controller.
List<T> getFilteredRows<T>(OsGridController<T> controller) {
  final rows = <T>[];
  controller.forEachNodeAfterFilter((data, index) {
    rows.add(data);
  });
  return rows;
}

void main() {
  group('External filter — widget properties', () {
    testWidgets('filters rows when isExternalFilterPresent returns true', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              columnDefs: [
                const OsColumnDef(field: 'name', headerName: 'Name'),
                const OsColumnDef(field: 'category', headerName: 'Category'),
              ],
              rowData: [
                {'name': 'Apple', 'category': 'fruit'},
                {'name': 'Carrot', 'category': 'vegetable'},
                {'name': 'Banana', 'category': 'fruit'},
              ],
              isExternalFilterPresent: () => true,
              doesExternalFilterPass: (row) => row['category'] == 'fruit',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Only fruit rows should be in processed data
      final rows = getFilteredRows(controller);
      expect(rows.length, 2);
      expect(rows[0]['name'], 'Apple');
      expect(rows[1]['name'], 'Banana');

      controller.dispose();
    });

    testWidgets('does not filter when isExternalFilterPresent returns false', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              columnDefs: [
                const OsColumnDef(field: 'name', headerName: 'Name'),
                const OsColumnDef(field: 'category', headerName: 'Category'),
              ],
              rowData: [
                {'name': 'Apple', 'category': 'fruit'},
                {'name': 'Carrot', 'category': 'vegetable'},
                {'name': 'Banana', 'category': 'fruit'},
              ],
              isExternalFilterPresent: () => false,
              doesExternalFilterPass: (row) => row['category'] == 'fruit',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // All rows should be present since external filter is not active
      final rows = getFilteredRows(controller);
      expect(rows.length, 3);

      controller.dispose();
    });

    testWidgets('does not filter when doesExternalFilterPass is null', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              columnDefs: [
                const OsColumnDef(field: 'name', headerName: 'Name'),
              ],
              rowData: [
                {'name': 'Apple'},
                {'name': 'Carrot'},
              ],
              isExternalFilterPresent: () => true,
              doesExternalFilterPass: null,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // All rows should be present since doesExternalFilterPass is null
      final rows = getFilteredRows(controller);
      expect(rows.length, 2);

      controller.dispose();
    });

    testWidgets('does not filter when isExternalFilterPresent is null', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              columnDefs: [
                const OsColumnDef(field: 'name', headerName: 'Name'),
              ],
              rowData: [
                {'name': 'Apple'},
                {'name': 'Carrot'},
              ],
              isExternalFilterPresent: null,
              doesExternalFilterPass: (row) => false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // All rows should be present since isExternalFilterPresent is null
      final rows = getFilteredRows(controller);
      expect(rows.length, 2);

      controller.dispose();
    });
  });

  group('External filter — controller.onExternalFilterChanged()', () {
    testWidgets('triggers re-evaluation when external state changes', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();
      String? selectedCategory;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: Column(
                  children: [
                    TextButton(
                      key: const Key('filter-btn'),
                      onPressed: () {
                        setState(() {
                          selectedCategory = 'fruit';
                        });
                        controller.onExternalFilterChanged();
                      },
                      child: const Text('Filter'),
                    ),
                    TextButton(
                      key: const Key('clear-btn'),
                      onPressed: () {
                        setState(() {
                          selectedCategory = null;
                        });
                        controller.onExternalFilterChanged();
                      },
                      child: const Text('Clear'),
                    ),
                    Expanded(
                      child: OsGrid<Map<String, dynamic>>(
                        controller: controller,
                        columnDefs: [
                          const OsColumnDef(field: 'name', headerName: 'Name'),
                          const OsColumnDef(
                            field: 'category',
                            headerName: 'Category',
                          ),
                        ],
                        rowData: [
                          {'name': 'Apple', 'category': 'fruit'},
                          {'name': 'Carrot', 'category': 'vegetable'},
                          {'name': 'Banana', 'category': 'fruit'},
                          {'name': 'Broccoli', 'category': 'vegetable'},
                        ],
                        isExternalFilterPresent: () => selectedCategory != null,
                        doesExternalFilterPass: (row) =>
                            row['category'] == selectedCategory,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially no filter — all 4 rows
      expect(getFilteredRows(controller).length, 4);

      // Tap filter button to activate external filter
      await tester.tap(find.byKey(const Key('filter-btn')));
      await tester.pumpAndSettle();

      // Only fruit rows
      final filtered = getFilteredRows(controller);
      expect(filtered.length, 2);
      expect(filtered[0]['name'], 'Apple');
      expect(filtered[1]['name'], 'Banana');

      // Tap clear button to deactivate external filter
      await tester.tap(find.byKey(const Key('clear-btn')));
      await tester.pumpAndSettle();

      // All rows again
      expect(getFilteredRows(controller).length, 4);

      controller.dispose();
    });

    testWidgets(
      'emits onFilterChanged widget callback when external filter changes',
      (tester) async {
        final controller = OsGridController<Map<String, dynamic>>();
        final filterEvents = <OsFilterChangedEvent>[];
        bool filterActive = false;

        await tester.pumpWidget(
          MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                return Scaffold(
                  body: Column(
                    children: [
                      TextButton(
                        key: const Key('toggle-btn'),
                        onPressed: () {
                          setState(() {
                            filterActive = !filterActive;
                          });
                          controller.onExternalFilterChanged();
                        },
                        child: const Text('Toggle'),
                      ),
                      Expanded(
                        child: OsGrid<Map<String, dynamic>>(
                          controller: controller,
                          columnDefs: [
                            const OsColumnDef(
                              field: 'name',
                              headerName: 'Name',
                            ),
                          ],
                          rowData: [
                            {'name': 'Apple'},
                            {'name': 'Carrot'},
                          ],
                          isExternalFilterPresent: () => filterActive,
                          doesExternalFilterPass: (row) =>
                              (row['name'] as String).startsWith('A'),
                          onFilterChanged: (event) {
                            filterEvents.add(event);
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(filterEvents, isEmpty);

        // Toggle filter on — onExternalFilterChanged fires the event
        await tester.tap(find.byKey(const Key('toggle-btn')));
        await tester.pumpAndSettle();

        // At least one filter event should have been emitted
        expect(filterEvents, isNotEmpty);

        controller.dispose();
      },
    );
  });

  group('External filter — interaction with other filters', () {
    testWidgets('works alongside quick filter (both applied)', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              columnDefs: [
                const OsColumnDef(field: 'name', headerName: 'Name'),
                const OsColumnDef(field: 'category', headerName: 'Category'),
              ],
              rowData: [
                {'name': 'Apple', 'category': 'fruit'},
                {'name': 'Apricot', 'category': 'fruit'},
                {'name': 'Avocado', 'category': 'vegetable'},
                {'name': 'Banana', 'category': 'fruit'},
              ],
              quickFilterText: 'ap',
              isExternalFilterPresent: () => true,
              doesExternalFilterPass: (row) => row['category'] == 'fruit',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Quick filter matches: Apple, Apricot (both contain 'ap')
      // External filter matches: Apple, Apricot, Banana (category == fruit)
      // Combined (AND): Apple, Apricot
      final rows = getFilteredRows(controller);
      expect(rows.length, 2);
      expect(rows[0]['name'], 'Apple');
      expect(rows[1]['name'], 'Apricot');

      controller.dispose();
    });

    testWidgets('works with sorting (filter applied before sort)', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              columnDefs: [
                const OsColumnDef(field: 'name', headerName: 'Name'),
                const OsColumnDef(field: 'category', headerName: 'Category'),
              ],
              rowData: [
                {'name': 'Cherry', 'category': 'fruit'},
                {'name': 'Carrot', 'category': 'vegetable'},
                {'name': 'Apple', 'category': 'fruit'},
                {'name': 'Banana', 'category': 'fruit'},
              ],
              initialSort: [
                const OsSortModel(
                  colId: 'name',
                  sort: OsSortDirection.ascending,
                ),
              ],
              isExternalFilterPresent: () => true,
              doesExternalFilterPass: (row) => row['category'] == 'fruit',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // External filter: Cherry, Apple, Banana (fruit only)
      // Sort ascending by name: Apple, Banana, Cherry
      final rows = getFilteredRows(controller);
      expect(rows.length, 3);
      expect(rows[0]['name'], 'Apple');
      expect(rows[1]['name'], 'Banana');
      expect(rows[2]['name'], 'Cherry');

      controller.dispose();
    });

    testWidgets('works with pagination (filter applied before pagination)', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              columnDefs: [
                const OsColumnDef(field: 'name', headerName: 'Name'),
                const OsColumnDef(field: 'category', headerName: 'Category'),
              ],
              rowData: [
                {'name': 'Apple', 'category': 'fruit'},
                {'name': 'Carrot', 'category': 'vegetable'},
                {'name': 'Banana', 'category': 'fruit'},
                {'name': 'Broccoli', 'category': 'vegetable'},
                {'name': 'Cherry', 'category': 'fruit'},
              ],
              pagination: const OsPagination(pageSize: 2),
              isExternalFilterPresent: () => true,
              doesExternalFilterPass: (row) => row['category'] == 'fruit',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // External filter: Apple, Banana, Cherry (3 fruit rows)
      // Pagination: page size 2, so total pages = 2
      expect(controller.paginationGetRowCount(), 3);
      expect(controller.paginationGetTotalPages(), 2);

      controller.dispose();
    });
  });

  group('External filter — didUpdateWidget', () {
    testWidgets('reprocesses when isExternalFilterPresent callback changes', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();
      bool filterActive = false;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: Column(
                  children: [
                    TextButton(
                      key: const Key('toggle-btn'),
                      onPressed: () {
                        setState(() {
                          filterActive = !filterActive;
                        });
                      },
                      child: const Text('Toggle'),
                    ),
                    Expanded(
                      child: OsGrid<Map<String, dynamic>>(
                        controller: controller,
                        columnDefs: [
                          const OsColumnDef(field: 'name', headerName: 'Name'),
                        ],
                        rowData: [
                          {'name': 'Apple'},
                          {'name': 'Carrot'},
                        ],
                        isExternalFilterPresent: () => filterActive,
                        doesExternalFilterPass: (row) =>
                            (row['name'] as String).startsWith('A'),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially filter is not active — all rows visible
      expect(getFilteredRows(controller).length, 2);

      // Toggle — this rebuilds the widget, triggering didUpdateWidget
      await tester.tap(find.byKey(const Key('toggle-btn')));
      await tester.pumpAndSettle();

      // Filter is now active — only 'Apple' passes
      expect(getFilteredRows(controller).length, 1);
      expect(getFilteredRows(controller)[0]['name'], 'Apple');

      controller.dispose();
    });

    testWidgets('reprocesses when doesExternalFilterPass callback changes', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();
      String filterLetter = 'A';

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: Column(
                  children: [
                    TextButton(
                      key: const Key('change-btn'),
                      onPressed: () {
                        setState(() {
                          filterLetter = 'B';
                        });
                      },
                      child: const Text('Change'),
                    ),
                    Expanded(
                      child: OsGrid<Map<String, dynamic>>(
                        controller: controller,
                        columnDefs: [
                          const OsColumnDef(field: 'name', headerName: 'Name'),
                        ],
                        rowData: [
                          {'name': 'Apple'},
                          {'name': 'Banana'},
                          {'name': 'Carrot'},
                        ],
                        isExternalFilterPresent: () => true,
                        doesExternalFilterPass: (row) =>
                            (row['name'] as String).startsWith(filterLetter),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially filters to 'A' — Apple only
      final initial = getFilteredRows(controller);
      expect(initial.length, 1);
      expect(initial[0]['name'], 'Apple');

      // Change filter to 'B'
      await tester.tap(find.byKey(const Key('change-btn')));
      await tester.pumpAndSettle();

      // Now filters to 'B' — Banana only
      final updated = getFilteredRows(controller);
      expect(updated.length, 1);
      expect(updated[0]['name'], 'Banana');

      controller.dispose();
    });
  });

  group('External filter — edge cases', () {
    testWidgets('handles empty row data', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              columnDefs: [
                const OsColumnDef(field: 'name', headerName: 'Name'),
              ],
              rowData: const [],
              isExternalFilterPresent: () => true,
              doesExternalFilterPass: (row) => true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(getFilteredRows(controller).length, 0);

      controller.dispose();
    });

    testWidgets('handles filter that excludes all rows', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              columnDefs: [
                const OsColumnDef(field: 'name', headerName: 'Name'),
              ],
              rowData: [
                {'name': 'Apple'},
                {'name': 'Banana'},
              ],
              isExternalFilterPresent: () => true,
              doesExternalFilterPass: (row) => false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // When all rows are filtered out, processedData is empty.
      // forEachNodeAfterFilter falls back to _rowData when processedData is empty,
      // so we verify via pagination which correctly reports the filtered count.
      // Use a separate test with pagination to verify zero-row filtering.
      // Here we verify the controller's raw row count is unchanged (data not lost).
      expect(controller.rowCount, 2);

      controller.dispose();
    });

    testWidgets(
      'filter that excludes all rows shows zero in pagination count',
      (tester) async {
        final controller = OsGridController<Map<String, dynamic>>();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: OsGrid<Map<String, dynamic>>(
                controller: controller,
                columnDefs: [
                  const OsColumnDef(field: 'name', headerName: 'Name'),
                ],
                rowData: [
                  {'name': 'Apple'},
                  {'name': 'Banana'},
                ],
                pagination: const OsPagination(pageSize: 10),
                isExternalFilterPresent: () => true,
                doesExternalFilterPass: (row) => false,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Pagination correctly reports 0 rows after filtering
        expect(controller.paginationGetRowCount(), 0);

        controller.dispose();
      },
    );

    testWidgets('handles filter that includes all rows', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              columnDefs: [
                const OsColumnDef(field: 'name', headerName: 'Name'),
              ],
              rowData: [
                {'name': 'Apple'},
                {'name': 'Banana'},
              ],
              isExternalFilterPresent: () => true,
              doesExternalFilterPass: (row) => true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(getFilteredRows(controller).length, 2);

      controller.dispose();
    });

    testWidgets('handles null rowData gracefully', (tester) async {
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              columnDefs: [
                const OsColumnDef(field: 'name', headerName: 'Name'),
              ],
              rowData: null,
              isExternalFilterPresent: () => true,
              doesExternalFilterPass: (row) => true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(getFilteredRows(controller).length, 0);

      controller.dispose();
    });

    testWidgets('selection survives external filter toggle with getRowId', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();
      bool filterActive = false;

      // Define rowData outside the builder so the same instance is reused
      // across rebuilds (avoids didUpdateWidget calling setRowData which
      // clears selection).
      final rowData = <Map<String, dynamic>>[
        {'id': 1, 'name': 'Apple', 'category': 'fruit'},
        {'id': 2, 'name': 'Carrot', 'category': 'vegetable'},
        {'id': 3, 'name': 'Banana', 'category': 'fruit'},
      ];

      final columnDefs = <OsColumnDefBase>[
        const OsColumnDef(field: 'name', headerName: 'Name'),
        const OsColumnDef(field: 'category', headerName: 'Category'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: Column(
                  children: [
                    TextButton(
                      key: const Key('toggle-btn'),
                      onPressed: () {
                        setState(() {
                          filterActive = !filterActive;
                        });
                        controller.onExternalFilterChanged();
                      },
                      child: const Text('Toggle'),
                    ),
                    Expanded(
                      child: OsGrid<Map<String, dynamic>>(
                        controller: controller,
                        getRowId: (row) => row['id'].toString(),
                        rowSelection: OsRowSelection.multiple(),
                        columnDefs: columnDefs,
                        rowData: rowData,
                        isExternalFilterPresent: () => filterActive,
                        doesExternalFilterPass: (row) =>
                            row['category'] == 'fruit',
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Select Apple by ID
      controller.selectRowsById(['1']);
      await tester.pumpAndSettle();

      expect(controller.getSelectedRows().length, 1);
      expect(controller.getSelectedRows()[0]['name'], 'Apple');

      // Activate filter — Carrot is filtered out
      await tester.tap(find.byKey(const Key('toggle-btn')));
      await tester.pumpAndSettle();

      // Apple should still be selected (ID-based selection survives filter)
      expect(controller.getSelectedRows().length, 1);
      expect(controller.getSelectedRows()[0]['name'], 'Apple');

      // Deactivate filter
      await tester.tap(find.byKey(const Key('toggle-btn')));
      await tester.pumpAndSettle();

      // Apple still selected, all rows visible again
      expect(getFilteredRows(controller).length, 3);
      expect(controller.getSelectedRows().length, 1);
      expect(controller.getSelectedRows()[0]['name'], 'Apple');

      controller.dispose();
    });
  });

  group('External filter — controller stream', () {
    test(
      'onFilterChanged stream receives events from emitFilterChanged',
      () async {
        final controller = OsGridController<Map<String, dynamic>>();
        final events = <OsFilterChangedEvent>[];
        final sub = controller.onFilterChanged.listen(events.add);

        expect(events, isEmpty);

        // Emit a filter changed event directly.
        controller.emitFilterChanged(
          const OsFilterChangedEvent(filterModel: {'test': 'value'}),
        );

        // Broadcast streams deliver asynchronously (microtask). Await to
        // allow the event to propagate.
        await Future<void>.delayed(Duration.zero);

        expect(events, hasLength(1));
        expect(events.first.filterModel, containsPair('test', 'value'));

        await sub.cancel();
        controller.dispose();
      },
    );
  });

  group('Quick filter — custom matcher receives raw parsed parts', () {
    testWidgets(
      'parser output keeps original casing when a custom matcher is supplied',
      (tester) async {
        final controller = OsGridController<Map<String, dynamic>>();
        List<String>? receivedParts;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: OsGrid<Map<String, dynamic>>(
                controller: controller,
                columnDefs: [
                  const OsColumnDef(field: 'name', headerName: 'Name'),
                ],
                rowData: [
                  {'name': 'Apple'},
                  {'name': 'Banana'},
                ],
                quickFilterText: 'ApP',
                quickFilterParser: (text) => text.split(','),
                quickFilterMatcher: (parts, rowText) {
                  receivedParts ??= List.of(parts);
                  return true;
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Raw parsed parts are passed through unmodified — previously they
        // were uppercased to ['APP'], making case-sensitive custom matching
        // impossible.
        expect(receivedParts, ['ApP']);

        controller.dispose();
      },
    );

    testWidgets(
      'case-sensitive custom matcher can reject differently-cased parts',
      (tester) async {
        final controller = OsGridController<Map<String, dynamic>>();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: OsGrid<Map<String, dynamic>>(
                controller: controller,
                columnDefs: [
                  const OsColumnDef(field: 'name', headerName: 'Name'),
                ],
                rowData: [
                  {'name': 'Apple'},
                  {'name': 'Banana'},
                ],
                pagination: const OsPagination(pageSize: 10),
                quickFilterText: 'app',
                quickFilterMatcher: (parts, rowText) =>
                    parts.every((part) => rowText.contains(part)),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 'APPLE' does not contain 'app' — a case-sensitive matcher can now
        // reject it (before the fix, parts were uppercased and it matched).
        expect(controller.paginationGetRowCount(), 0);
        // Underlying data is untouched by filtering.
        expect(controller.rowCount, 2);

        controller.dispose();
      },
    );

    testWidgets('case-sensitive custom matcher accepts exactly-cased parts', (
      tester,
    ) async {
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid<Map<String, dynamic>>(
              controller: controller,
              columnDefs: [
                const OsColumnDef(field: 'name', headerName: 'Name'),
              ],
              rowData: [
                {'name': 'Apple'},
                {'name': 'Banana'},
              ],
              quickFilterText: 'APP',
              quickFilterMatcher: (parts, rowText) =>
                  parts.every((part) => rowText.contains(part)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final rows = getFilteredRows(controller);
      expect(rows.length, 1);
      expect(rows[0]['name'], 'Apple');

      controller.dispose();
    });
  });
}
