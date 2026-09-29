import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

/// Golden matrix for the grid renderer (GridPainter path).
///
/// Themes {quartz, quartzDark, highContrast} x pinning {none, left+right}
/// x scenarios {groupRows, spans, rangeSelection, flash} == 24 goldens,
/// plus a sparkline matrix {line, area, bar} x {quartz, quartzDark} == 6
/// goldens, a tree-data matrix {collapsed, expandedAll} x {quartz,
/// quartzDark} == 4 goldens, a pinned/group/span intersection matrix
/// (quality program v3 item 39) == 5 goldens and a high-contrast/locale
/// matrix (quality program v3 item 49) == 4 goldens, generated once locally
/// and committed as PNGs under test/goldens/.
///
/// Status-bar panels are deliberately NOT covered by this suite: panels
/// render as widgets laid out below the grid canvas, so they are not
/// painter content and cannot be captured by a canvas RepaintBoundary
/// golden (quality program v2 item 37).
///
/// Font determinism: none of the preset families ('IBM Plex Sans',
/// 'Segoe UI') exist in the test environment, so text always resolves to
/// the bundled deterministic FlutterTest face on every platform. The
/// harness also pins the app-level font family to 'FlutterTest'
/// (test-side only, never in lib/).
///
/// Regenerate goldens after an intentional visual change:
///
/// ```bash
/// flutter test --update-goldens test/goldens/grid_golden_test.dart
/// ```
void main() {
  final boundaryKey = GlobalKey();

  final rows = List<Map<String, Object>>.generate(8, (i) {
    return {
      'region': i.isEven ? 'EU' : 'US',
      'name': 'Item ${i + 1}',
      'value': (i * 137) % 500,
    };
  });

  Widget buildGrid({
    required OsGridTheme theme,
    required bool pinned,
    required _Scenario scenario,
    OsGridController<Map<String, Object>>? controller,
  }) {
    final regionCol = OsColumnDef<Map<String, Object>>(
      field: 'region',
      width: 90,
      pinned: pinned ? OsColumnPin.left : null,
      rowGroup: scenario == _Scenario.groupRows,
      valueGetter: (p) => p.data['region'],
    );
    final nameCol = OsColumnDef<Map<String, Object>>(
      field: 'name',
      width: 140,
      colSpan: scenario == _Scenario.spans
          ? (p) => p.rowIndex == 0 ? 2 : 1
          : null,
      valueGetter: (p) => p.data['name'],
    );
    final valueCol = OsColumnDef<Map<String, Object>>(
      field: 'value',
      width: 110,
      valueGetter: (p) => p.data['value'],
    );

    return OsGrid<Map<String, Object>>(
      controller: controller,
      theme: theme,
      columnDefs: [regionCol, nameCol, valueCol],
      rowData: rows,
      getRowId: (r) => 'row-${r['value']}-${r['name']}',
      groupDefaultExpanded: scenario == _Scenario.groupRows ? -1 : null,
      cellSelection: scenario == _Scenario.rangeSelection
          ? const OsCellSelection()
          : null,
    );
  }

  Future<void> pumpAndCapture(
    WidgetTester tester, {
    required String goldenName,
    required OsGridTheme theme,
    required bool pinned,
    required _Scenario scenario,
    bool rtl = false,
    TextDirection? explicitDirection,
  }) async {
    final controller =
        scenario == _Scenario.flash || scenario == _Scenario.rangeSelection
        ? OsGridController<Map<String, Object>>()
        : null;

    Widget grid() => buildGrid(
      theme: theme,
      pinned: pinned,
      scenario: scenario,
      controller: controller,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'FlutterTest'),
        home: Scaffold(
          // RTL variants host the same grid under Directionality.rtl to lock
          // the mirrored geometry (quality program v2 item 48).
          body: rtl
              ? Directionality(
                  textDirection: explicitDirection ?? TextDirection.rtl,
                  child: RepaintBoundary(
                    key: boundaryKey,
                    child: SizedBox(width: 420, height: 300, child: grid()),
                  ),
                )
              : RepaintBoundary(
                  key: boundaryKey,
                  child: SizedBox(width: 420, height: 300, child: grid()),
                ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    if (scenario == _Scenario.rangeSelection && controller != null) {
      controller.addCellRange(
        const CellRangeParams(
          rowStartIndex: 0,
          rowEndIndex: 2,
          columnStartIndex: 1,
          columnEndIndex: 2,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }
    if (scenario == _Scenario.flash && controller != null) {
      controller.flashCells(
        const FlashCellsParams(rowIndices: [1, 3], columns: ['value']),
      );
      // Stay inside the 500 ms full-opacity window: deterministic paint.
      await tester.pump(const Duration(milliseconds: 100));
    }

    await expectLater(
      find.byKey(boundaryKey),
      matchesGoldenFile('goldens/$goldenName.png'),
    );
  }

  final themes = <String, OsGridTheme>{
    'quartz': OsGridTheme.quartz(),
    'quartzDark': OsGridTheme.quartzDark(),
    'highContrast': OsGridTheme.highContrast(),
  };

  final scenarios = {
    _Scenario.groupRows: 'grouped',
    _Scenario.spans: 'spans',
    _Scenario.rangeSelection: 'range',
    _Scenario.flash: 'flash',
  };

  for (final themeEntry in themes.entries) {
    for (final pin in const [false, true]) {
      for (final scenarioEntry in scenarios.entries) {
        final name =
            '${themeEntry.key}_'
            '${pin ? 'pinned' : 'none'}_'
            '${scenarioEntry.value}';
        testWidgets('golden $name', (tester) async {
          await pumpAndCapture(
            tester,
            goldenName: name,
            theme: themeEntry.value,
            pinned: pin,
            scenario: scenarioEntry.key,
          );
        }, timeout: const Timeout(Duration(minutes: 2)));
      }
    }
  }

  // --- RTL matrix (item 48): quartz only to bound golden count.
  // Mirrored geometry for the base scenarios: {groupRows, spans,
  // rangeSelection} x pinning {none, pinned} == 6 goldens, generated with
  // an explicit Directionality.rtl host.
  final rtlScenarios = {
    _Scenario.groupRows: 'grouped',
    _Scenario.spans: 'spans',
    _Scenario.rangeSelection: 'range',
  };

  for (final pin in const [false, true]) {
    for (final scenarioEntry in rtlScenarios.entries) {
      final name =
          'quartz_'
          '${pin ? 'pinned' : 'none'}_'
          '${scenarioEntry.value}_rtl';
      testWidgets('golden $name', (tester) async {
        await pumpAndCapture(
          tester,
          goldenName: name,
          theme: OsGridTheme.quartz(),
          pinned: pin,
          scenario: scenarioEntry.key,
          rtl: true,
        );
      }, timeout: const Timeout(Duration(minutes: 2)));
    }
  }

  // Sanity guard: an explicit LTR Directionality inside the RTL harness must
  // still resolve as LTR (direction comes from the nearest Directionality).
  testWidgets(
    'golden quartz_none_grouped_ltr_host',
    (tester) async {
      await pumpAndCapture(
        tester,
        goldenName: 'quartz_none_grouped',
        theme: OsGridTheme.quartz(),
        pinned: false,
        scenario: _Scenario.groupRows,
        rtl: true,
        explicitDirection: TextDirection.ltr,
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  // --- Sparkline matrix: {line, area, bar} x {quartz, quartzDark} ---
  // Data is fixed and deterministic; each row shows the same series.
  const trendData = <num>[1, 3, 2, 5, 4];

  final sparklineThemes = <String, OsGridTheme>{
    'quartz': OsGridTheme.quartz(),
    'quartzDark': OsGridTheme.quartzDark(),
  };

  final sparklineTypes = <String, OsSparklineType>{
    'line': OsSparklineType.line,
    'area': OsSparklineType.area,
    'bar': OsSparklineType.bar,
  };

  final sparklineRows = List<Map<String, Object>>.generate(3, (i) {
    return {'name': 'Row ${i + 1}', 'trend': List<num>.of(trendData)};
  });

  Future<void> pumpSparklineAndCapture(
    WidgetTester tester, {
    required String goldenName,
    required OsGridTheme theme,
    required OsSparklineType type,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'FlutterTest'),
        home: Scaffold(
          body: RepaintBoundary(
            key: boundaryKey,
            child: SizedBox(
              width: 420,
              height: 300,
              child: OsGrid<Map<String, Object>>(
                theme: theme,
                columnDefs: [
                  const OsColumnDef<Map<String, Object>>(
                    field: 'name',
                    headerName: 'Name',
                    width: 140,
                  ),
                  OsColumnDef<Map<String, Object>>(
                    field: 'trend',
                    headerName: 'Trend',
                    width: 160,
                    builtInCellRenderer: OsBuiltInCellRenderer.sparkline,
                    sparklineOptions: OsSparklineOptions(type: type),
                  ),
                ],
                rowData: sparklineRows,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await expectLater(
      find.byKey(boundaryKey),
      matchesGoldenFile('goldens/$goldenName.png'),
    );
  }

  for (final themeEntry in sparklineThemes.entries) {
    for (final typeEntry in sparklineTypes.entries) {
      final name = 'sparkline_${typeEntry.key}_${themeEntry.key}';
      testWidgets('golden $name', (tester) async {
        await pumpSparklineAndCapture(
          tester,
          goldenName: name,
          theme: themeEntry.value,
          type: typeEntry.value,
        );
      }, timeout: const Timeout(Duration(minutes: 2)));
    }
  }

  // --- Tree-data matrix (item 37): {collapsed, expandedAll} x
  // {quartz, quartzDark} == 4 goldens.
  //
  // Uses OsGrid(treeData: true, getDataPath: ...) exactly like
  // test/tree_data_test.dart: the painter renders the synthetic group rows
  // (chevron + "key (count)" + level indentation) via _paintGroupRow. The
  // chain below exercises two nesting levels plus sibling leaves.
  final treeRows = <Map<String, Object>>[
    {
      'id': 't1',
      'name': 'Leaf One',
      'value': 120,
      'path': <Object>['Corporate'],
    },
    {
      'id': 't2',
      'name': 'Leaf Two',
      'value': 240,
      'path': <Object>['Corporate', 'Engineering'],
    },
    {
      'id': 't3',
      'name': 'Leaf Three',
      'value': 90,
      'path': <Object>['Corporate', 'Engineering'],
    },
    {
      'id': 't4',
      'name': 'Leaf Four',
      'value': 60,
      'path': <Object>['Sales'],
    },
  ];

  Future<void> pumpTreeAndCapture(
    WidgetTester tester, {
    required String goldenName,
    required OsGridTheme theme,
    required bool expandAll,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'FlutterTest'),
        home: Scaffold(
          body: RepaintBoundary(
            key: boundaryKey,
            child: SizedBox(
              width: 420,
              height: 300,
              child: OsGrid<Map<String, Object>>(
                theme: theme,
                columnDefs: const [
                  OsColumnDef<Map<String, Object>>(
                    field: 'name',
                    headerName: 'Name',
                    width: 160,
                  ),
                  OsColumnDef<Map<String, Object>>(
                    field: 'value',
                    headerName: 'Value',
                    width: 110,
                  ),
                ],
                rowData: treeRows,
                getRowId: (r) => r['id'] as String,
                treeData: true,
                getDataPath: (r) => r['path'] as List<Object>?,
                groupDefaultExpanded: expandAll ? -1 : null,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await expectLater(
      find.byKey(boundaryKey),
      matchesGoldenFile('goldens/$goldenName.png'),
    );
  }

  final treeThemes = <String, OsGridTheme>{
    'quartz': OsGridTheme.quartz(),
    'quartzDark': OsGridTheme.quartzDark(),
  };

  for (final themeEntry in treeThemes.entries) {
    for (final entry in const {'collapsed': false, 'expanded': true}.entries) {
      final name = 'tree_${themeEntry.key}_${entry.key}';
      testWidgets('golden $name', (tester) async {
        await pumpTreeAndCapture(
          tester,
          goldenName: name,
          theme: themeEntry.value,
          expandAll: entry.value,
        );
      }, timeout: const Timeout(Duration(minutes: 2)));
    }
  }

  // --- Pinned/group/span intersection matrix (quality program v3 item 39).
  //
  // The scenario matrices above toggle ONE feature at a time; these five
  // combinations force the painter bands to interact:
  // - range selection borders crossing a pin boundary,
  // - a col-span cell painted while flash and range overlays are live,
  // - flash on a pinned column of a grouped grid,
  // - an expanded tree rendered under both pins.
  // Unlike the base matrix the span combinations set `enableCellSpan: true`
  // so the colSpan callback actually reaches the body painter. The colSpan
  // closure is typed over ColSpanParams<dynamic> on purpose:
  // CellSpanService.getColSpan reads `colSpan` through the raw OsColumnDef
  // getter, whose covariance check rejects closures typed over a concrete
  // TData at paint time (valueGetter is unaffected — it is only read
  // internally through the untyped getValueGetterAsFunction hop).
  final intersectionSpecs = <_IntersectionSpec>[
    // 1. Left-pinned region column + col-span (name -> value on row 0) +
    //    a range that starts ON the pinned column, so its border crosses
    //    the left pin boundary through the spanned cell band.
    _IntersectionSpec(
      name: 'quartz_pinned_span_range',
      theme: OsGridTheme.quartz(),
      pinLeft: true,
      spans: true,
      range: true,
      rangeColStart: 0,
    ),
    // 2. Right-pinned value column + grouped rows (expanded) + flash on the
    //    pinned column while group rows occupy the same row band.
    _IntersectionSpec(
      name: 'quartz_pinned_right_grouped_flash',
      theme: OsGridTheme.quartz(),
      pinRight: true,
      grouped: true,
      flash: true,
    ),
    // 3. Both pins + fully expanded tree data + a range spanning all three
    //    sections (left pin, center, right pin) across group and leaf rows.
    _IntersectionSpec(
      name: 'quartzDark_pinned_both_tree_range',
      theme: OsGridTheme.quartzDark(),
      pinLeft: true,
      pinRight: true,
      treeExpanded: true,
      range: true,
      rangeRowStart: 1,
      rangeRowEnd: 4,
      rangeColStart: 0,
      rangeColEnd: 2,
    ),
    // 4. No pins + col-span + flash INSIDE the range rectangle (row 1 /
    //    value column is both flashing and range-selected) — locks the
    //    z-order of the flash band above the range band.
    _IntersectionSpec(
      name: 'quartzDark_span_flash_range',
      theme: OsGridTheme.quartzDark(),
      spans: true,
      flash: true,
      range: true,
    ),
    // 5. Left-pinned region column + grouped rows + floating filter row +
    //    a range starting on the group row and crossing the pin boundary.
    _IntersectionSpec(
      name: 'quartz_pinned_grouped_filter_range',
      theme: OsGridTheme.quartz(),
      pinLeft: true,
      grouped: true,
      floatingFilter: true,
      range: true,
      rangeColStart: 0,
    ),
  ];

  /// Expanded tree rows for the intersection matrix: two nesting levels,
  /// plus a third (`qty`) column so the right pin has a real column to pin.
  final intersectionTreeRows = <Map<String, Object>>[
    {
      'id': 'i1',
      'name': 'Leaf One',
      'value': 120,
      'qty': 4,
      'path': <Object>['Corporate'],
    },
    {
      'id': 'i2',
      'name': 'Leaf Two',
      'value': 240,
      'qty': 2,
      'path': <Object>['Corporate', 'Engineering'],
    },
    {
      'id': 'i3',
      'name': 'Leaf Three',
      'value': 90,
      'qty': 7,
      'path': <Object>['Corporate', 'Engineering'],
    },
    {
      'id': 'i4',
      'name': 'Leaf Four',
      'value': 60,
      'qty': 5,
      'path': <Object>['Sales'],
    },
  ];

  /// Builds the OsGrid widget for one intersection combination: shared
  /// {region, name, value} columns for the flat-row specs, dedicated
  /// {name, value, qty} columns + treeData wiring for the tree spec.
  Widget buildIntersectionGrid(
    _IntersectionSpec spec,
    OsGridController<Map<String, Object>>? controller,
  ) {
    if (spec.treeExpanded) {
      return OsGrid<Map<String, Object>>(
        controller: controller,
        theme: spec.theme,
        columnDefs: [
          OsColumnDef<Map<String, Object>>(
            field: 'name',
            headerName: 'Name',
            width: 150,
            pinned: spec.pinLeft ? OsColumnPin.left : null,
          ),
          const OsColumnDef<Map<String, Object>>(
            field: 'value',
            headerName: 'Value',
            width: 100,
          ),
          OsColumnDef<Map<String, Object>>(
            field: 'qty',
            headerName: 'Qty',
            width: 90,
            pinned: spec.pinRight ? OsColumnPin.right : null,
          ),
        ],
        rowData: intersectionTreeRows,
        getRowId: (r) => r['id'] as String,
        treeData: true,
        getDataPath: (r) => r['path'] as List<Object>?,
        groupDefaultExpanded: -1,
        cellSelection: spec.range ? const OsCellSelection() : null,
      );
    }

    final regionCol = OsColumnDef<Map<String, Object>>(
      field: 'region',
      width: 90,
      pinned: spec.pinLeft ? OsColumnPin.left : null,
      rowGroup: spec.grouped,
      valueGetter: (p) => p.data['region'],
    );
    final nameCol = OsColumnDef<Map<String, Object>>(
      field: 'name',
      width: 140,
      colSpan: spec.spans
          // ColSpanParams<dynamic> parameter: see the matrix comment above.
          ? (ColSpanParams<dynamic> p) => p.rowIndex == 0 ? 2 : 1
          : null,
      valueGetter: (p) => p.data['name'],
    );
    final valueCol = OsColumnDef<Map<String, Object>>(
      field: 'value',
      width: 110,
      pinned: spec.pinRight ? OsColumnPin.right : null,
      valueGetter: (p) => p.data['value'],
    );

    return OsGrid<Map<String, Object>>(
      controller: controller,
      theme: spec.theme,
      columnDefs: [regionCol, nameCol, valueCol],
      rowData: rows,
      getRowId: (r) => 'row-${r['value']}-${r['name']}',
      groupDefaultExpanded: spec.grouped ? -1 : null,
      enableCellSpan: spec.spans,
      floatingFilter: spec.floatingFilter,
      cellSelection: spec.range ? const OsCellSelection() : null,
    );
  }

  Future<void> pumpIntersectionAndCapture(
    WidgetTester tester, {
    required _IntersectionSpec spec,
  }) async {
    final controller = spec.flash || spec.range
        ? OsGridController<Map<String, Object>>()
        : null;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'FlutterTest'),
        home: Scaffold(
          body: RepaintBoundary(
            key: boundaryKey,
            child: SizedBox(
              width: 420,
              height: 300,
              child: buildIntersectionGrid(spec, controller),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    if (spec.range && controller != null) {
      controller.addCellRange(
        CellRangeParams(
          rowStartIndex: spec.rangeRowStart,
          rowEndIndex: spec.rangeRowEnd,
          columnStartIndex: spec.rangeColStart,
          columnEndIndex: spec.rangeColEnd,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }
    if (spec.flash && controller != null) {
      controller.flashCells(
        const FlashCellsParams(rowIndices: [1, 3], columns: ['value']),
      );
      // Stay inside the 500 ms full-opacity window: deterministic paint.
      await tester.pump(const Duration(milliseconds: 100));
    }

    await expectLater(
      find.byKey(boundaryKey),
      matchesGoldenFile('goldens/${spec.name}.png'),
    );
  }

  group('pinnedGroupSpanMatrix', () {
    for (final spec in intersectionSpecs) {
      testWidgets('golden ${spec.name}', (tester) async {
        await pumpIntersectionAndCapture(tester, spec: spec);
      }, timeout: const Timeout(Duration(minutes: 2)));
    }
  });

  // --- High-contrast + locale matrix (quality program v3 item 49):
  // {high-contrast theme, German locale} x {pinned, tree-data} == 4 goldens.
  //
  // The high-contrast variants lock the accessibility preset
  // (`OsGridTheme.highContrast()` — the preset implemented by
  // lib/src/accessibility/high_contrast_theme.dart) against left-pinned
  // columns and expanded tree data. The locale variants run a German
  // `OsLocaleText` override with umlaut content (München, Straße, Größe)
  // exercising non-ASCII text shaping under pinning and tree data; note
  // that canvas-painted strings are English-only today, so the locale
  // override is exercised through the locale resolver plumbing (semantics)
  // while the umlaut data drives the visible difference.
  const germanLocale = OsLocaleText(
    noRowsToShow: 'Keine Zeilen vorhanden',
    loadingOoo: 'Lädt…',
    page: 'Seite',
    of: 'von',
    selectAll: 'Alles auswählen',
    searchOoo: 'Suchen…',
    filterOoo: 'Filtern…',
    applyFilter: 'Filter anwenden',
    resetFilter: 'Filter zurücksetzen',
    clearFilter: 'Filter löschen',
    equals: 'Gleich',
    notEqual: 'Ungleich',
    contains: 'Enthält',
    notContains: 'Enthält nicht',
    startsWith: 'Beginnt mit',
    endsWith: 'Endet mit',
    lessThan: 'Kleiner als',
    greaterThan: 'Größer als',
    blank: 'Leer',
    notBlank: 'Nicht leer',
    andCondition: 'Und',
    orCondition: 'Oder',
    pinLeft: 'Nach links fixieren',
    pinRight: 'Nach rechts fixieren',
    noPin: 'Fixierung aufheben',
    autosizeThisColumn: 'Spalte automatisch skalieren',
    autosizeAllColumns: 'Alle Spalten automatisch skalieren',
    resetColumns: 'Spalten zurücksetzen',
    sortAscending: 'Aufsteigend sortieren',
    sortDescending: 'Absteigend sortieren',
    clearSort: 'Sortierung aufheben',
    expandAll: 'Alle erweitern',
    collapseAll: 'Alle einklappen',
    cancel: 'Abbrechen',
    ok: 'OK',
  );

  final germanRows = List<Map<String, Object>>.generate(8, (i) {
    return {
      'region': ['Bayern', 'Zürich', 'Österreich'][i % 3],
      'name': [
        'München',
        'Große Straße',
        'Köln',
        'Düsseldorf',
        'Aßlar',
        'Wörth',
        'Gröbenzell',
        'Überlingen',
      ][i],
      'value': (i * 137) % 500,
    };
  });

  final germanTreeRows = <Map<String, Object>>[
    {
      'id': 'd1',
      'name': 'München',
      'value': 120,
      'path': <Object>['Konzern'],
    },
    {
      'id': 'd2',
      'name': 'Größte Abteilung',
      'value': 240,
      'path': <Object>['Konzern', 'Entwicklung'],
    },
    {
      'id': 'd3',
      'name': 'Aßlar Standort',
      'value': 90,
      'path': <Object>['Konzern', 'Entwicklung'],
    },
    {
      'id': 'd4',
      'name': 'Straße 7',
      'value': 60,
      'path': <Object>['Vertrieb'],
    },
  ];

  Widget buildHcLocalePinnedGrid({
    required bool german,
    OsGridTheme? theme,
    OsLocaleText? localeText,
  }) {
    return OsGrid<Map<String, Object>>(
      theme: theme,
      localeText: localeText,
      columnDefs: [
        OsColumnDef<Map<String, Object>>(
          field: 'region',
          headerName: 'Region',
          width: 110,
          pinned: OsColumnPin.left,
          valueGetter: (p) => p.data['region'],
        ),
        OsColumnDef<Map<String, Object>>(
          field: 'name',
          headerName: 'Name',
          width: 140,
          valueGetter: (p) => p.data['name'],
        ),
        OsColumnDef<Map<String, Object>>(
          field: 'value',
          headerName: german ? 'Wert' : 'Value',
          width: 110,
          valueGetter: (p) => p.data['value'],
        ),
      ],
      rowData: german ? germanRows : rows,
      getRowId: (r) => 'row-${r['value']}-${r['name']}',
    );
  }

  Widget buildHcLocaleTreeGrid({
    required bool german,
    OsGridTheme? theme,
    OsLocaleText? localeText,
  }) {
    return OsGrid<Map<String, Object>>(
      theme: theme,
      localeText: localeText,
      columnDefs: [
        const OsColumnDef<Map<String, Object>>(
          field: 'name',
          headerName: 'Name',
          width: 160,
          pinned: OsColumnPin.left,
        ),
        OsColumnDef<Map<String, Object>>(
          field: 'value',
          headerName: german ? 'Wert' : 'Value',
          width: 110,
        ),
      ],
      rowData: german ? germanTreeRows : treeRows,
      getRowId: (r) => r['id'] as String,
      treeData: true,
      getDataPath: (r) => r['path'] as List<Object>?,
      groupDefaultExpanded: -1,
    );
  }

  Future<void> pumpHcLocaleAndCapture(
    WidgetTester tester, {
    required String goldenName,
    required bool tree,
    required bool german,
    OsGridTheme? theme,
    OsLocaleText? localeText,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'FlutterTest'),
        home: Scaffold(
          body: RepaintBoundary(
            key: boundaryKey,
            child: SizedBox(
              width: 420,
              height: 300,
              child: tree
                  ? buildHcLocaleTreeGrid(
                      german: german,
                      theme: theme,
                      localeText: localeText,
                    )
                  : buildHcLocalePinnedGrid(
                      german: german,
                      theme: theme,
                      localeText: localeText,
                    ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await expectLater(
      find.byKey(boundaryKey),
      matchesGoldenFile('goldens/$goldenName.png'),
    );
  }

  testWidgets('golden highContrast_pinned', (tester) async {
    await pumpHcLocaleAndCapture(
      tester,
      goldenName: 'highContrast_pinned',
      tree: false,
      german: false,
      theme: OsGridTheme.highContrast(),
    );
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets(
    'golden highContrast_tree_expanded',
    (tester) async {
      await pumpHcLocaleAndCapture(
        tester,
        goldenName: 'highContrast_tree_expanded',
        tree: true,
        german: false,
        theme: OsGridTheme.highContrast(),
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  testWidgets('golden localeDe_pinned', (tester) async {
    await pumpHcLocaleAndCapture(
      tester,
      goldenName: 'localeDe_pinned',
      tree: false,
      german: true,
      localeText: germanLocale,
    );
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets('golden localeDe_tree_expanded', (tester) async {
    await pumpHcLocaleAndCapture(
      tester,
      goldenName: 'localeDe_tree_expanded',
      tree: true,
      german: true,
      localeText: germanLocale,
    );
  }, timeout: const Timeout(Duration(minutes: 2)));
}

enum _Scenario { groupRows, spans, rangeSelection, flash }

/// One combination of the pinned/group/span intersection matrix (quality
/// program v3 item 39): [name] is the golden file stem, the booleans enable
/// the features to combine, and the range* fields place the selection
/// rectangle (display row/column indices) for the specs that use it.
class _IntersectionSpec {
  const _IntersectionSpec({
    required this.name,
    required this.theme,
    this.pinLeft = false,
    this.pinRight = false,
    this.grouped = false,
    this.treeExpanded = false,
    this.spans = false,
    this.flash = false,
    this.range = false,
    this.floatingFilter = false,
    this.rangeRowStart = 0,
    this.rangeRowEnd = 2,
    this.rangeColStart = 1,
    this.rangeColEnd = 2,
  });

  final String name;
  final OsGridTheme theme;
  final bool pinLeft;
  final bool pinRight;
  final bool grouped;
  final bool treeExpanded;
  final bool spans;
  final bool flash;
  final bool range;
  final bool floatingFilter;
  final int rangeRowStart;
  final int rangeRowEnd;
  final int rangeColStart;
  final int rangeColEnd;
}
