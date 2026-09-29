import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';
import 'package:os_grid_flutter/src/utils/grid_diagnostics.dart';

/// Records lifecycle calls for custom-module assertions.
class _RecordingModule extends OsModule {
  final List<OsGridController<Object?>> attachedControllers = [];
  int detachCount = 0;

  @override
  String get moduleName => 'Recording';

  @override
  String get version => '0.0.1';

  @override
  void attach(OsGridController<Object?> controller) {
    attachedControllers.add(controller);
  }

  @override
  void detach() {
    detachCount++;
  }
}

void main() {
  final diagnosticKeys = <String>[];
  bool sawDiagnostic(String key) => diagnosticKeys.contains(key);

  setUp(() {
    GridDiagnostics.resetWarnedKeys();
    GridDiagnostics.resetListeners();
    OsGrid.clearRegisteredModules();
    diagnosticKeys.clear();
    GridDiagnostics.addListener((d) => diagnosticKeys.add(d.key));
  });

  tearDown(() {
    GridDiagnostics.removeListener((d) => diagnosticKeys.add(d.key));
    GridDiagnostics.resetWarnedKeys();
    GridDiagnostics.resetListeners();
    OsGrid.clearRegisteredModules();
  });

  Widget buildGrid({
    List<OsModule>? modules,
    OsGridController<Map<String, dynamic>>? controller,
    bool treeData = false,
    bool sparklineColumn = false,
    bool setFilterColumn = false,
    void Function(OsClipboardCopyEvent event)? onClipboardCopy,
    void Function(OsCellEditingStartedEvent<Map<String, dynamic>> event)?
    onCellEditingStarted,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: OsGrid<Map<String, dynamic>>(
          controller: controller,
          modules: modules,
          treeData: treeData,
          getDataPath: treeData ? (data) => data['path'] as List<String> : null,
          onClipboardCopy: onClipboardCopy,
          onCellEditingStarted: onCellEditingStarted,
          columnDefs: [
            const OsColumnDef(
              field: 'name',
              headerName: 'Name',
              editable: true,
            ),
            if (sparklineColumn)
              const OsColumnDef(
                field: 'trend',
                headerName: 'Trend',
                builtInCellRenderer: OsBuiltInCellRenderer.sparkline,
              ),
            if (setFilterColumn)
              const OsColumnDef(
                field: 'country',
                headerName: 'Country',
                filter: OsSetFilter(),
              ),
          ],
          rowData: const [
            {
              'id': 1,
              'name': 'Alice',
              'path': <String>['A'],
              'trend': <double>[1, 2, 3],
              'country': 'NZ',
            },
            {
              'id': 2,
              'name': 'Bob',
              'path': <String>['A', 'B'],
              'trend': <double>[3, 2, 1],
              'country': 'AU',
            },
          ],
        ),
      ),
    );
  }

  group('default (no modules registered)', () {
    testWidgets('all features are implicitly enabled', (tester) async {
      var copies = 0;
      var edits = 0;
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(
        buildGrid(
          controller: controller,
          treeData: true,
          sparklineColumn: true,
          setFilterColumn: true,
          onClipboardCopy: (_) => copies++,
          onCellEditingStarted: (_) => edits++,
        ),
      );
      await tester.pumpAndSettle();

      controller.copyToClipboard();
      await tester.pump();
      controller.startEditingCell(rowIndex: 0, colId: 'name');
      await tester.pump();

      expect(copies, 1);
      expect(edits, 1);
      expect(
        diagnosticKeys.where((k) => k.startsWith('module:gated:')),
        isEmpty,
      );
    });
  });

  group('per-instance module subset', () {
    testWidgets('ClipboardModule enables clipboard only', (tester) async {
      var copies = 0;
      var edits = 0;
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(
        buildGrid(
          controller: controller,
          treeData: true,
          modules: [ClipboardModule()],
          onClipboardCopy: (_) => copies++,
          onCellEditingStarted: (_) => edits++,
        ),
      );
      await tester.pumpAndSettle();

      controller.copyToClipboard();
      await tester.pump();
      controller.startEditingCell(rowIndex: 0, colId: 'name');
      await tester.pump();

      expect(copies, 1, reason: 'registered feature stays enabled');
      expect(edits, 0, reason: 'unregistered feature is gated off');
      expect(sawDiagnostic('module:gated:editing'), isTrue);
      expect(sawDiagnostic('module:gated:treeData'), isTrue);
      expect(sawDiagnostic('module:gated:clipboard'), isFalse);
    });

    testWidgets('EditingModule enables editing only', (tester) async {
      var copies = 0;
      var edits = 0;
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(
        buildGrid(
          controller: controller,
          modules: [EditingModule()],
          onClipboardCopy: (_) => copies++,
          onCellEditingStarted: (_) => edits++,
        ),
      );
      await tester.pumpAndSettle();

      controller.startEditingCell(rowIndex: 0, colId: 'name');
      await tester.pump();
      controller.copyToClipboard();
      await tester.pump();

      expect(edits, 1, reason: 'registered feature stays enabled');
      expect(copies, 0, reason: 'unregistered feature is gated off');
      expect(sawDiagnostic('module:gated:clipboard'), isTrue);
      expect(sawDiagnostic('module:gated:editing'), isFalse);
    });

    testWidgets('unregistered gated column params are stripped with warning', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildGrid(
          modules: [EditingModule()],
          sparklineColumn: true,
          setFilterColumn: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(sawDiagnostic('module:gated:sparkline'), isTrue);
      expect(sawDiagnostic('module:gated:setFilter'), isTrue);
    });

    testWidgets('registered gated column params keep working', (tester) async {
      await tester.pumpWidget(
        buildGrid(
          modules: [
            EditingModule(),
            const SparklineModule(),
            const SetFilterModule(),
          ],
          sparklineColumn: true,
          setFilterColumn: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(sawDiagnostic('module:gated:sparkline'), isFalse);
      expect(sawDiagnostic('module:gated:setFilter'), isFalse);
    });
  });

  group('global module registry', () {
    testWidgets('registerModules applies to every grid instance', (
      tester,
    ) async {
      OsGrid.registerModules(const [TreeDataModule()]);
      var copies = 0;
      var edits = 0;
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(
        buildGrid(
          controller: controller,
          treeData: true,
          onClipboardCopy: (_) => copies++,
          onCellEditingStarted: (_) => edits++,
        ),
      );
      await tester.pumpAndSettle();

      controller.copyToClipboard();
      await tester.pump();
      controller.startEditingCell(rowIndex: 0, colId: 'name');
      await tester.pump();

      expect(sawDiagnostic('module:gated:treeData'), isFalse);
      expect(copies, 0);
      expect(edits, 0);
      expect(sawDiagnostic('module:gated:clipboard'), isTrue);
      expect(sawDiagnostic('module:gated:editing'), isTrue);
    });
  });

  group('module lifecycle', () {
    testWidgets('attach receives the grid controller; detach on dispose', (
      tester,
    ) async {
      final recording = _RecordingModule();
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(
        buildGrid(controller: controller, modules: [recording]),
      );
      await tester.pumpAndSettle();

      expect(recording.attachedControllers, hasLength(1));
      expect(
        identical(recording.attachedControllers.single, controller),
        isTrue,
      );
      expect(recording.detachCount, 0);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();

      expect(recording.detachCount, 1);
    });

    testWidgets('ClipboardModule attach wires copy; detach unwires it', (
      tester,
    ) async {
      var copies = 0;
      final controller = OsGridController<Map<String, dynamic>>();

      await tester.pumpWidget(
        buildGrid(
          controller: controller,
          modules: [ClipboardModule()],
          onClipboardCopy: (_) => copies++,
        ),
      );
      await tester.pumpAndSettle();

      controller.copyToClipboard();
      await tester.pump();
      expect(copies, 1, reason: 'module attach wired the coordinator');

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();

      controller.copyToClipboard();
      await tester.pump();
      expect(copies, 1, reason: 'module detach unwired the controller');
    });
  });
}
