import 'dart:async';

import 'package:os_grid_flutter/os_grid_flutter.dart';
import 'package:flutter/material.dart';

import '../../theme_selector.dart';
import '../sample_data.dart';
import '../widgets/feature_panel.dart';
import '../widgets/demo_ui.dart';

/// Demonstrates the grid body overlays.
///
/// Shows the loading overlay (both the declarative [OsGrid.loading]
/// parameter and the imperative overlay API), the no-rows overlay for an
/// empty data set, and show/hide overlay control via
/// [OsGridController.showLoadingOverlay] / [OsGridController.showNoRowsOverlay]
/// / [OsGridController.hideOverlay].
class OverlaysPage extends StatefulWidget {
  const OverlaysPage({
    super.key,
    required this.themePreset,
    this.onThemeChanged,
  });

  final GridThemePreset themePreset;
  final ValueChanged<GridThemePreset>? onThemeChanged;

  @override
  State<OverlaysPage> createState() => _OverlaysPageState();
}

class _OverlaysPageState extends State<OverlaysPage> {
  final _controller = OsGridController<Map<String, dynamic>>();
  late final List<Map<String, dynamic>> _rowData;

  /// Tri-state `loading` parameter: null = automatic resolution.
  bool? _declarativeLoading;
  bool _emptyData = false;
  Timer? _simulatedLoadTimer;

  @override
  void initState() {
    super.initState();
    _rowData = generateSampleData(rowCount: 30);
  }

  @override
  void dispose() {
    _simulatedLoadTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// Simulates an async fetch: shows the loading overlay for 1.5 s via the
  /// imperative API, then returns control to the automatic resolution.
  void _simulateAsyncLoad() {
    _simulatedLoadTimer?.cancel();
    _controller.showLoadingOverlay();
    _simulatedLoadTimer = Timer(const Duration(milliseconds: 1500), () {
      _controller.hideOverlay();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = getThemeForPreset(widget.themePreset, context);

    return Column(
      children: [
        FeaturePanel(
          title: 'Overlay Controls',
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'auto', label: Text('Auto')),
                ButtonSegment(value: 'on', label: Text('Loading')),
                ButtonSegment(value: 'off', label: Text('Off')),
              ],
              selected: {
                switch (_declarativeLoading) {
                  null => 'auto',
                  true => 'on',
                  false => 'off',
                },
              },
              onSelectionChanged: (selection) {
                setState(() {
                  _declarativeLoading = switch (selection.first) {
                    'auto' => null,
                    'on' => true,
                    _ => false,
                  };
                });
              },
            ),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.cloud_download, size: 16),
              label: const Text('Simulate Async Load'),
              onPressed: _simulateAsyncLoad,
            ),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.hourglass_top, size: 16),
              label: const Text('showLoadingOverlay'),
              onPressed: () => _controller.showLoadingOverlay(),
            ),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.hourglass_empty, size: 16),
              label: const Text('showNoRowsOverlay'),
              onPressed: () => _controller.showNoRowsOverlay(),
            ),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.layers_clear, size: 16),
              label: const Text('hideOverlay'),
              onPressed: () => _controller.hideOverlay(),
            ),
            DemoToggle(
              label: 'Empty data (no-rows overlay)',
              value: _emptyData,
              onChanged: (v) => setState(() => _emptyData = v),
            ),
          ],
        ),
        Expanded(
          child: OsGrid<Map<String, dynamic>>(
            controller: _controller,
            theme: theme,
            rowData: _emptyData ? const [] : _rowData,
            getRowId: (row) => 'row-${row['id']}',
            loading: _declarativeLoading,
            columnDefs: _buildColumnDefs(),
          ),
        ),
      ],
    );
  }

  List<OsColumnDef<Map<String, dynamic>>> _buildColumnDefs() {
    return [
      OsColumnDef<Map<String, dynamic>>(
        field: 'name',
        headerName: 'Name',
        sortable: true,
        flex: 2,
      ),
      OsColumnDef<Map<String, dynamic>>(
        field: 'email',
        headerName: 'Email',
        sortable: true,
        flex: 2,
      ),
      OsColumnDef<Map<String, dynamic>>(
        field: 'department',
        headerName: 'Department',
        sortable: true,
        width: 140,
      ),
      OsColumnDef<Map<String, dynamic>>(
        field: 'salary',
        headerName: 'Salary',
        sortable: true,
        width: 120,
      ),
    ];
  }
}
