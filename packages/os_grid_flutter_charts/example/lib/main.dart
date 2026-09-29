import 'package:flutter/material.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';
import 'package:os_grid_flutter_charts/os_grid_flutter_charts.dart';

void main() => runApp(const ChartsDemoApp());

/// Integrated Charts demo: select a cell range, tap the chart button at
/// the range corner, pick a chart type, and the extracted definition
/// renders live in the panel below via the fl_chart backend.
///
/// The grid's Integrated Charts support lives in the dependency-free core;
/// the renderers live in this companion package, so the demo is packaged
/// here rather than in the main example app.
class ChartsDemoApp extends StatelessWidget {
  const ChartsDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'OS Grid — Integrated Charts',
      home: ChartsDemoPage(),
    );
  }
}

class ChartsDemoPage extends StatefulWidget {
  const ChartsDemoPage({super.key});

  @override
  State<ChartsDemoPage> createState() => _ChartsDemoPageState();
}

class _ChartsDemoPageState extends State<ChartsDemoPage> {
  final _controller = OsGridController<Map<String, dynamic>>();

  static const _rowData = <Map<String, dynamic>>[
    {'quarter': 'Q1', 'revenue': 182, 'cost': 121, 'profit': 61},
    {'quarter': 'Q2', 'revenue': 214, 'cost': 130, 'profit': 84},
    {'quarter': 'Q3', 'revenue': 198, 'cost': 145, 'profit': 53},
    {'quarter': 'Q4', 'revenue': 246, 'cost': 158, 'profit': 88},
    {'quarter': 'Q5', 'revenue': 232, 'cost': 149, 'profit': 83},
    {'quarter': 'Q6', 'revenue': 261, 'cost': 171, 'profit': 90},
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Integrated Charts')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Drag-select cells, then tap the chart button at the '
                    "range's corner to extract a chart.",
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: () {
                    _controller.addCellRange(
                      const CellRangeParams(
                        rowStartIndex: 0,
                        rowEndIndex: 5,
                        columnStartIndex: 0,
                        columnEndIndex: 3,
                      ),
                    );
                    _controller.createChartRange(type: OsChartType.bar);
                  },
                  child: const Text('Chart all quarters'),
                ),
              ],
            ),
          ),
          Expanded(
            child: OsGrid<Map<String, dynamic>>(
              controller: _controller,
              cellSelection: const OsCellSelection(),
              enableIntegratedCharts: true,
              columnDefs: const [
                OsColumnDef(
                  field: 'quarter',
                  headerName: 'Quarter',
                  width: 130,
                ),
                OsColumnDef(
                  field: 'revenue',
                  headerName: 'Revenue',
                  width: 130,
                ),
                OsColumnDef(field: 'cost', headerName: 'Cost', width: 130),
                OsColumnDef(field: 'profit', headerName: 'Profit', width: 130),
              ],
              rowData: _rowData,
            ),
          ),
          const Divider(height: 1),
          OsIntegratedChart(
            controller: _controller,
            height: 280,
            renderer: const FlChartRenderer(),
          ),
        ],
      ),
    );
  }
}
