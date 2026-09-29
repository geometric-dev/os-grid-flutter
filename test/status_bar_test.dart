import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:os_grid_flutter/os_grid_flutter.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(body: SizedBox(width: 800, height: 600, child: child)),
  );
}

const _valueColumn = OsColumnDef(field: 'value', headerName: 'Value');

const _fiveRows = [
  {'name': 'A', 'value': 100},
  {'name': 'B', 'value': 200},
  {'name': 'C', 'value': 300},
  {'name': 'D', 'value': 400},
  {'name': 'E', 'value': 500},
];

void main() {
  group('Status bar aggregations', () {
    group('Configured panels', () {
      testWidgets('renders all built-in aggregates over page rows', (
        tester,
      ) async {
        await tester.pumpWidget(
          _wrap(
            const OsGrid(
              columnDefs: [_valueColumn],
              rowData: [
                {'value': 10},
                {'value': 20},
                {'value': 30},
              ],
              statusBarConfig: OsStatusBarConfig(
                statusPanels: [
                  OsStatusPanelDef(aggregationFunc: 'sum', valueColId: 'value'),
                  OsStatusPanelDef(aggregationFunc: 'avg', valueColId: 'value'),
                  OsStatusPanelDef(aggregationFunc: 'min', valueColId: 'value'),
                  OsStatusPanelDef(aggregationFunc: 'max', valueColId: 'value'),
                  OsStatusPanelDef(
                    aggregationFunc: 'count',
                    valueColId: 'value',
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Sum:'), findsOneWidget);
        expect(find.text('60'), findsOneWidget);
        expect(find.text('Avg:'), findsOneWidget);
        // Avg returns a double, rendered via toString().
        expect(find.text('20.0'), findsOneWidget);
        expect(find.text('Min:'), findsOneWidget);
        expect(find.text('10'), findsOneWidget);
        expect(find.text('Max:'), findsOneWidget);
        expect(find.text('30'), findsOneWidget);
        expect(find.text('Count:'), findsOneWidget);
        expect(find.text('3'), findsOneWidget);
      });

      testWidgets('recomputes when the pagination slice changes', (
        tester,
      ) async {
        await tester.pumpWidget(
          _wrap(
            const OsGrid(
              columnDefs: [_valueColumn],
              rowData: _fiveRows,
              pagination: OsPagination(pageSize: 2),
              statusBarConfig: OsStatusBarConfig(
                statusPanels: [
                  OsStatusPanelDef(aggregationFunc: 'sum', valueColId: 'value'),
                  OsStatusPanelDef(
                    aggregationFunc: 'count',
                    valueColId: 'value',
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Page 1 shows rows 1-2.
        expect(find.text('300'), findsOneWidget); // 100 + 200
        expect(find.text('2'), findsOneWidget);

        // Navigate to page 2 (rows 3-4).
        await tester.tap(find.byIcon(Icons.chevron_right));
        await tester.pumpAndSettle();

        expect(find.text('700'), findsOneWidget); // 300 + 400
        expect(find.text('2'), findsOneWidget);
        expect(find.text('300'), findsNothing);
      });

      testWidgets('applies the column valueFormatter to the aggregate', (
        tester,
      ) async {
        await tester.pumpWidget(
          _wrap(
            const OsGrid(
              columnDefs: [
                OsColumnDef(
                  field: 'value',
                  headerName: 'Value',
                  valueFormatter: _currencyFormatter,
                ),
              ],
              rowData: [
                {'value': 100},
                {'value': 250},
              ],
              statusBarConfig: OsStatusBarConfig(
                statusPanels: [
                  OsStatusPanelDef(aggregationFunc: 'sum', valueColId: 'value'),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(r'$350'), findsOneWidget);
      });

      testWidgets('supports custom labels overriding localized defaults', (
        tester,
      ) async {
        await tester.pumpWidget(
          _wrap(
            const OsGrid(
              columnDefs: [_valueColumn],
              rowData: [
                {'value': 5},
              ],
              statusBarConfig: OsStatusBarConfig(
                statusPanels: [
                  OsStatusPanelDef(
                    aggregationFunc: 'sum',
                    valueColId: 'value',
                    label: 'Total',
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Total:'), findsOneWidget);
        expect(find.text('Sum:'), findsNothing);
        expect(find.text('5'), findsOneWidget);
      });

      testWidgets('uses localized default labels', (tester) async {
        await tester.pumpWidget(
          _wrap(
            const OsGrid(
              columnDefs: [_valueColumn],
              rowData: [
                {'value': 5},
              ],
              localeText: OsLocaleText(summed: 'Summe'),
              statusBarConfig: OsStatusBarConfig(
                statusPanels: [
                  OsStatusPanelDef(aggregationFunc: 'sum', valueColId: 'value'),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Summe:'), findsOneWidget);
        expect(find.text('5'), findsOneWidget);
      });

      testWidgets('resolves values through valueGetter', (tester) async {
        await tester.pumpWidget(
          _wrap(
            OsGrid<Map<String, dynamic>>(
              columnDefs: [
                const OsColumnDef(field: 'a', headerName: 'A'),
                OsColumnDef(
                  colId: 'doubled',
                  headerName: 'Doubled',
                  valueGetter:
                      (ValueGetterParams<Map<String, dynamic>> params) =>
                          (params.data['a'] as int) * 2,
                ),
              ],
              rowData: const [
                {'a': 10},
                {'a': 15},
              ],
              statusBarConfig: const OsStatusBarConfig(
                statusPanels: [
                  OsStatusPanelDef(
                    aggregationFunc: 'sum',
                    valueColId: 'doubled',
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('50'), findsOneWidget); // (10*2) + (15*2)
      });

      testWidgets('align right renders the panel on the opposite side', (
        tester,
      ) async {
        await tester.pumpWidget(
          _wrap(
            const OsGrid(
              columnDefs: [_valueColumn],
              rowData: [
                {'value': 1},
              ],
              statusBarConfig: OsStatusBarConfig(
                statusPanels: [
                  OsStatusPanelDef(aggregationFunc: 'sum', valueColId: 'value'),
                  OsStatusPanelDef(
                    aggregationFunc: 'count',
                    valueColId: 'value',
                    align: OsStatusPanelAlign.right,
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final leftRect = tester.getRect(find.text('Sum:'));
        final rightRect = tester.getRect(find.text('Count:'));

        // The right-aligned panel is pushed to the far end of the bar while
        // the left-aligned panel stays at the start.
        expect(rightRect.left, greaterThan(leftRect.right));
        expect(leftRect.left, lessThan(400));
        expect(rightRect.right, greaterThan(600));
      });

      testWidgets('unknown valueColId renders label without a value', (
        tester,
      ) async {
        await tester.pumpWidget(
          _wrap(
            const OsGrid(
              columnDefs: [_valueColumn],
              rowData: [
                {'value': 1},
              ],
              statusBarConfig: OsStatusBarConfig(
                statusPanels: [
                  OsStatusPanelDef(aggregationFunc: 'sum', valueColId: 'nope'),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Sum:'), findsOneWidget);
      });

      testWidgets('empty data renders zero count without crashing', (
        tester,
      ) async {
        await tester.pumpWidget(
          _wrap(
            const OsGrid(
              columnDefs: [_valueColumn],
              rowData: [],
              statusBarConfig: OsStatusBarConfig(
                statusPanels: [
                  OsStatusPanelDef(aggregationFunc: 'sum', valueColId: 'value'),
                  OsStatusPanelDef(
                    aggregationFunc: 'count',
                    valueColId: 'value',
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Count:'), findsOneWidget);
        expect(find.text('0'), findsOneWidget);
      });
    });

    group('Legacy bool status bar', () {
      testWidgets('statusBar true alone keeps the legacy count display', (
        tester,
      ) async {
        await tester.pumpWidget(
          _wrap(
            OsGrid(
              columnDefs: const [_valueColumn],
              rowData: const [
                {'value': 1},
                {'value': 2},
              ],
              rowSelection: OsRowSelection.single(),
              statusBar: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Rows: '), findsOneWidget);
        expect(find.text('2'), findsOneWidget);
        expect(find.text('Sum:'), findsNothing);
        expect(find.byType(OsStatusBarPanelRow), findsNothing);
      });

      testWidgets('config wins over legacy bool when both provided', (
        tester,
      ) async {
        await tester.pumpWidget(
          _wrap(
            const OsGrid(
              columnDefs: [_valueColumn],
              rowData: [
                {'value': 7},
              ],
              statusBar: true,
              statusBarConfig: OsStatusBarConfig(
                statusPanels: [
                  OsStatusPanelDef(aggregationFunc: 'sum', valueColId: 'value'),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Rows: '), findsNothing);
        expect(find.text('Filtered: '), findsNothing);
        expect(find.byType(OsStatusBarPanelRow), findsOneWidget);
        expect(find.text('Sum:'), findsOneWidget);
        expect(find.text('7'), findsOneWidget);
      });
    });
  });
}

String _currencyFormatter(ValueFormatterParams params) => '\$${params.value}';
