// ignore_for_file: file_names
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

/// Deterministic seeded rows for integration harness.
///
/// Every row has a stable `id` (`row-0`, `row-1`, …), `name`, `age`, `city`.
///
/// Use [getRowId] always — map rows without it use identityHashCode and become
/// unstable across copies (gotcha 17).
List<Map<String, dynamic>> seededRows({int count = 20}) {
  const names = [
    'Alice',
    'Bob',
    'Charlie',
    'Diana',
    'Eve',
    'Frank',
    'Grace',
    'Heidi',
    'Ivan',
    'Judy',
  ];
  const cities = ['London', 'Paris', 'Berlin', 'Madrid', 'Rome'];
  return List.generate(count, (i) {
    return <String, dynamic>{
      'id': 'row-$i',
      'name': names[i % names.length],
      'age': 20 + (i * 7) % 40,
      'city': cities[i % cities.length],
      'score': (i * 13) % 100,
    };
  });
}

/// Default column set for the harness (uniform width 150, sortable).
List<OsColumnDef> defaultColumns({
  double width = 150,
  bool sortable = true,
  bool filterable = false,
}) {
  return [
    OsColumnDef(
      field: 'name',
      headerName: 'Name',
      width: width,
      sortable: sortable,
      filter: filterable ? const OsTextFilter() : null,
    ),
    OsColumnDef(
      field: 'age',
      headerName: 'Age',
      width: width,
      sortable: sortable,
      filter: filterable ? const OsNumberFilter() : null,
    ),
    OsColumnDef(
      field: 'city',
      headerName: 'City',
      width: width,
      sortable: sortable,
      filter: filterable ? const OsTextFilter() : null,
    ),
    OsColumnDef(
      field: 'score',
      headerName: 'Score',
      width: width,
      sortable: sortable,
    ),
  ];
}

/// Deterministic 800x600 harness widget.
///
/// MaterialApp + Scaffold + SizedBox(800,600) + OsGrid. `getRowId` is always
/// provided and every keyed widget is tagged for stable finding.
///
/// Use [pumpHarness] to mount it.
class Harness extends StatelessWidget {
  const Harness({
    super.key,
    required this.controller,
    required this.rows,
    required this.columns,
    this.pagination,
    this.rowSelection,
    this.cellSelection,
    this.quickFilterText,
    this.floatingFilter = false,
    this.floatingFilterHeight = 32.0,
    this.headerHeight = 48.0,
    this.rowHeight = 42.0,
    this.accentedSort = false,
    this.multiSortKey = OsMultiSortKey.shift,
    this.alwaysMultiSort = false,
    this.suppressMultiSort = false,
    this.initialSort,
    this.undoRedoCellEditing = false,
    this.undoRedoCellEditingLimit = 10,
    this.readOnlyEdit = false,
    this.singleClickEdit = false,
    this.copyHeadersToClipboard = false,
    this.clipboardDelimiter = '\t',
    this.suppressClipboardPaste = false,
    this.enableCellSpan = false,
    this.suppressColumnVirtualisation = false,
    this.onCellEditRequest,
    this.onCellValueChanged,
    this.processCellForClipboard,
    this.processHeaderForClipboard,
  });

  final OsGridController<Map<String, dynamic>> controller;
  final List<Map<String, dynamic>> rows;
  final List<OsColumnDef> columns;
  final OsPagination? pagination;
  final OsRowSelection? rowSelection;
  final OsCellSelection? cellSelection;
  final String? quickFilterText;
  final bool floatingFilter;
  final double floatingFilterHeight;
  final double headerHeight;
  final double rowHeight;
  final bool accentedSort;
  final OsMultiSortKey multiSortKey;
  final bool alwaysMultiSort;
  final bool suppressMultiSort;
  final List<OsSortModel>? initialSort;
  final bool undoRedoCellEditing;
  final int undoRedoCellEditingLimit;
  final bool readOnlyEdit;
  final bool singleClickEdit;
  final bool copyHeadersToClipboard;
  final String clipboardDelimiter;
  final bool suppressClipboardPaste;
  final bool enableCellSpan;
  final bool suppressColumnVirtualisation;
  final ValueChanged<OsCellEditRequestEvent<Map<String, dynamic>>>?
  onCellEditRequest;
  final ValueChanged<OsCellValueChangedEvent<Map<String, dynamic>>>?
  onCellValueChanged;
  final String Function(ProcessCellForClipboardParams<Map<String, dynamic>>)?
  processCellForClipboard;
  final String Function(ProcessHeaderForClipboardParams)?
  processHeaderForClipboard;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      key: const Key('harness-app'),
      home: Scaffold(
        key: const Key('harness-scaffold'),
        body: SizedBox(
          key: const Key('harness-box'),
          width: 800,
          height: 600,
          child: OsGrid<Map<String, dynamic>>(
            key: const Key('harness-grid'),
            controller: controller,
            getRowId: (row) => row['id'] as String,
            columnDefs: columns,
            rowData: rows,
            pagination: pagination,
            rowSelection: rowSelection,
            cellSelection: cellSelection,
            quickFilterText: quickFilterText,
            floatingFilter: floatingFilter,
            floatingFilterHeight: floatingFilterHeight,
            headerHeight: headerHeight,
            rowHeight: rowHeight,
            accentedSort: accentedSort,
            multiSortKey: multiSortKey,
            alwaysMultiSort: alwaysMultiSort,
            suppressMultiSort: suppressMultiSort,
            initialSort: initialSort,
            undoRedoCellEditing: undoRedoCellEditing,
            undoRedoCellEditingLimit: undoRedoCellEditingLimit,
            readOnlyEdit: readOnlyEdit,
            singleClickEdit: singleClickEdit,
            copyHeadersToClipboard: copyHeadersToClipboard,
            clipboardDelimiter: clipboardDelimiter,
            suppressClipboardPaste: suppressClipboardPaste,
            enableCellSpan: enableCellSpan,
            suppressColumnVirtualisation: suppressColumnVirtualisation,
            onCellEditRequest: onCellEditRequest,
            onCellValueChanged: onCellValueChanged,
            processCellForClipboard: processCellForClipboard,
            processHeaderForClipboard: processHeaderForClipboard,
          ),
        ),
      ),
    );
  }
}

/// Pump the harness with deterministic defaults.
///
/// Returns nothing; the controller is mutated in-place and remains usable after
/// the pump for API-level assertions.
Future<void> pumpHarness(
  WidgetTester tester, {
  OsGridController<Map<String, dynamic>>? controller,
  List<Map<String, dynamic>>? rows,
  int? rowCount,
  List<OsColumnDef>? columns,
  OsPagination? pagination,
  OsRowSelection? rowSelection,
  OsCellSelection? cellSelection,
  String? quickFilterText,
  bool floatingFilter = false,
  double floatingFilterHeight = 32.0,
  double headerHeight = 48.0,
  double rowHeight = 42.0,
  bool accentedSort = false,
  OsMultiSortKey multiSortKey = OsMultiSortKey.shift,
  bool alwaysMultiSort = false,
  bool suppressMultiSort = false,
  List<OsSortModel>? initialSort,
  bool undoRedoCellEditing = false,
  int undoRedoCellEditingLimit = 10,
  bool readOnlyEdit = false,
  bool singleClickEdit = false,
  bool copyHeadersToClipboard = false,
  String clipboardDelimiter = '\t',
  bool suppressClipboardPaste = false,
  bool enableCellSpan = false,
  bool suppressColumnVirtualisation = false,
  ValueChanged<OsCellEditRequestEvent<Map<String, dynamic>>>? onCellEditRequest,
  ValueChanged<OsCellValueChangedEvent<Map<String, dynamic>>>?
  onCellValueChanged,
  String Function(ProcessCellForClipboardParams<Map<String, dynamic>>)?
  processCellForClipboard,
  String Function(ProcessHeaderForClipboardParams)? processHeaderForClipboard,
}) async {
  final c = controller ?? OsGridController<Map<String, dynamic>>();
  final r = rows ?? seededRows(count: rowCount ?? 20);
  final cols = columns ?? defaultColumns();
  await tester.pumpWidget(
    Harness(
      controller: c,
      rows: r,
      columns: cols,
      pagination: pagination,
      rowSelection: rowSelection,
      cellSelection: cellSelection,
      quickFilterText: quickFilterText,
      floatingFilter: floatingFilter,
      floatingFilterHeight: floatingFilterHeight,
      headerHeight: headerHeight,
      rowHeight: rowHeight,
      accentedSort: accentedSort,
      multiSortKey: multiSortKey,
      alwaysMultiSort: alwaysMultiSort,
      suppressMultiSort: suppressMultiSort,
      initialSort: initialSort,
      undoRedoCellEditing: undoRedoCellEditing,
      undoRedoCellEditingLimit: undoRedoCellEditingLimit,
      readOnlyEdit: readOnlyEdit,
      singleClickEdit: singleClickEdit,
      copyHeadersToClipboard: copyHeadersToClipboard,
      clipboardDelimiter: clipboardDelimiter,
      suppressClipboardPaste: suppressClipboardPaste,
      enableCellSpan: enableCellSpan,
      suppressColumnVirtualisation: suppressColumnVirtualisation,
      onCellEditRequest: onCellEditRequest,
      onCellValueChanged: onCellValueChanged,
      processCellForClipboard: processCellForClipboard,
      processHeaderForClipboard: processHeaderForClipboard,
    ),
  );
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Helpers — mirroring test/gestures_test_utils.dart + test/popup_bounds_test.dart
// plus the QA program gotcha fixes.
// ---------------------------------------------------------------------------

RenderBox _gridBox(WidgetTester tester) =>
    tester.renderObject(find.byType(VirtualisedGrid)) as RenderBox;

/// Tap a data cell at [row]/[col] using computed offsets.
///
/// Offsets are derived from [headerHeight]/[rowHeight]/[colWidth] and
/// [floatingFilterHeight]. The tap flushes the double-tap arena with a 350 ms
/// pump (gotcha 4) before settling.
Future<void> tapGridCell(
  WidgetTester tester,
  int row,
  int col, {
  double colWidth = 150,
  double headerHeight = 48,
  double rowHeight = 42,
  double floatingFilterHeight = 0,
}) async {
  final box = _gridBox(tester);
  final local = Offset(
    col * colWidth + colWidth / 2,
    headerHeight + floatingFilterHeight + row * rowHeight + rowHeight / 2,
  );
  await tester.tapAt(box.localToGlobal(local));
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pumpAndSettle();
}

/// Tap a header cell at column [col].
///
/// Header taps are used for sorting and opening the column menu / filter popups.
Future<void> tapHeader(
  WidgetTester tester,
  int col, {
  double colWidth = 150,
  double headerHeight = 48,
}) async {
  final box = _gridBox(tester);
  final local = Offset(col * colWidth + colWidth / 2, headerHeight / 2);
  await tester.tapAt(box.localToGlobal(local));
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pumpAndSettle();
}

/// Tap the header filter icon for column [col] with width [colWidth].
///
/// Filter icon sits ~ 30 px left of the right edge of the header cell (the
/// ⋮ menu icon occupies the last ~16 px). For a 150 px column the icon is
/// around x = col*width + width - 34.
Future<void> tapFilterIcon(
  WidgetTester tester,
  int col, {
  double colWidth = 150,
  double headerHeight = 48,
}) async {
  final box = _gridBox(tester);
  // 150 px col → icon at +116 from col origin (see popup_bounds_test.dart: 166,24 for 200px)
  // For generic width: width - 34 keeps inside the filter icon hit area.
  final local = Offset(col * colWidth + colWidth - 34, headerHeight / 2);
  await tester.tapAt(box.localToGlobal(local));
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pumpAndSettle();
}

/// Tap the column menu (⋮) icon for column [col].
Future<void> tapColumnMenuIcon(
  WidgetTester tester,
  int col, {
  double colWidth = 150,
  double headerHeight = 48,
}) async {
  final box = _gridBox(tester);
  // ⋮ icon is at right edge - ~10 px
  final local = Offset(col * colWidth + colWidth - 10, headerHeight / 2);
  await tester.tapAt(box.localToGlobal(local));
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pumpAndSettle();
}

/// Right-click a data cell (mouse secondary button) — gotcha 6.
Future<void> rightClickCell(
  WidgetTester tester,
  int row,
  int col, {
  double colWidth = 150,
  double headerHeight = 48,
  double rowHeight = 42,
  double floatingFilterHeight = 0,
}) async {
  final box = _gridBox(tester);
  final local = Offset(
    col * colWidth + colWidth / 2,
    headerHeight + floatingFilterHeight + row * rowHeight + rowHeight / 2,
  );
  final gesture = await tester.startGesture(
    box.localToGlobal(local),
    kind: PointerDeviceKind.mouse,
    buttons: kSecondaryMouseButton,
  );
  await tester.pump();
  await gesture.up();
  await tester.pumpAndSettle();
}

/// Drag gesture: startGesture → moveBy steps → up with pumps — gotcha 7.
Future<void> dragFromTo(
  WidgetTester tester,
  Offset start,
  Offset end, {
  int steps = 10,
}) async {
  final box = _gridBox(tester);
  final startGlobal = box.localToGlobal(start);
  final endGlobal = box.localToGlobal(end);
  final delta = endGlobal - startGlobal;
  final step = delta / steps.toDouble();
  final gesture = await tester.startGesture(startGlobal);
  await tester.pump();
  for (int i = 0; i < steps; i++) {
    await gesture.moveBy(step);
    await tester.pump(const Duration(milliseconds: 16));
  }
  await gesture.up();
  await tester.pumpAndSettle();
}

/// Mock the platform clipboard channel before pumpWidget — gotcha 22.
///
/// Returns the [StringBuffer] that backs the mock so tests can assert on it.
StringBuffer mockClipboard([WidgetTester? tester]) {
  final buffer = StringBuffer();
  final binding = tester?.binding ?? TestDefaultBinaryMessengerBinding.instance;
  binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (MethodCall call) async {
      switch (call.method) {
        case 'Clipboard.setData':
          buffer.clear();
          buffer.write(
            (call.arguments as Map<Object?, Object?>)['text'] as String,
          );
          return null;
        case 'Clipboard.getData':
          final text = buffer.toString();
          return text.isEmpty ? null : <String, Object?>{'text': text};
      }
      return null;
    },
  );
  return buffer;
}

void clearMockClipboard(WidgetTester tester) {
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    null,
  );
}

/// Popup locating: Material descendants of CompositedTransformFollower — gotchas 11,12.
List<RenderBox> popupMaterialBoxes(WidgetTester tester) {
  final followers = find.byWidgetPredicate(
    (w) => w is CompositedTransformFollower,
  );
  if (followers.evaluate().isEmpty) return const [];
  final panels = find.descendant(
    of: followers,
    matching: find.byType(Material),
  );
  return [
    for (final element in tester.elementList(panels))
      if (element.renderObject is RenderBox &&
          (element.renderObject as RenderBox).hasSize)
        element.renderObject as RenderBox,
  ];
}

/// Real-time wait for integration binding — gotcha 5.
///
/// pump(Duration) does not fast-forward real gestures on the integration
/// binding; a real [Future.delayed] is required.
Future<void> waitReal(WidgetTester tester, int ms) async {
  await Future<void>.delayed(Duration(milliseconds: ms));
  await tester.pump(Duration(milliseconds: ms));
}

Future<void> takeScreenshotBestEffort(
  IntegrationTestWidgetsFlutterBinding binding,
  String name,
) async {
  try {
    await binding.takeScreenshot(name).timeout(const Duration(seconds: 5));
  } catch (_) {
    // Driver not attached — skip.
  }
}

Widget wrapGrid(Widget grid, {double width = 800, double height = 600}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(width: width, height: height, child: grid),
    ),
  );
}

List<Map<String, dynamic>> displayRows(WidgetTester tester) {
  return tester.widget<VirtualisedGrid>(find.byType(VirtualisedGrid)).rowData;
}

/// Compatibility alias for tests that call mockClipboard without a tester.

Future<void> rightClickGridPoint(
  WidgetTester tester,
  Offset globalOffset,
) async {
  final gesture = await tester.startGesture(
    globalOffset,
    kind: PointerDeviceKind.mouse,
    buttons: kSecondaryMouseButton,
  );
  await gesture.up();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pumpAndSettle();
}
