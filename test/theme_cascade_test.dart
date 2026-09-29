import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';
import 'package:os_grid_flutter/src/theming/resolved_grid_theme.dart';

const _base = OsGridTheme(
  cellTextStyle: TextStyle(
    fontFamily: 'BaseFont',
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: Color(0xFF111111),
  ),
);

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: SizedBox(width: 800, height: 600, child: child)),
);

List<OsColumnDef> _displayColumns(WidgetTester tester) =>
    tester.widget<VirtualisedGrid>(find.byType(VirtualisedGrid)).columns;

void main() {
  group('Theme cascade: static levels (ResolvedGridTheme.forColumn)', () {
    test('falls back to base when no overrides at any level', () {
      final theme = ResolvedGridTheme.forColumn(
        const OsColumnDef<dynamic>(field: 'a'),
        _base,
      );

      // Identical instance — keeps the identity-keyed text layout cache warm.
      expect(identical(theme.cellTextStyle, _base.cellTextStyle), isTrue);
      expect(theme.cellTextStyle.fontSize, 14);
      expect(theme.cellTextStyle.color, const Color(0xFF111111));
    });

    test('falls back to the painter default when base theme is null', () {
      final theme = ResolvedGridTheme.forColumn(
        const OsColumnDef<dynamic>(field: 'a'),
        null,
      );

      expect(theme.cellTextStyle.fontSize, 13);
      expect(theme.cellTextStyle.color, const Color(0xFF424242));
    });

    test('column type theme overrides base', () {
      const typeTheme = OsGridTheme(cellTextColor: Color(0xFF00AA00));
      final resolved = ColumnDefResolver.resolve(
        columns: const [OsColumnDef<dynamic>(field: 'price', type: 'currency')],
        defaultColDef: null,
        columnTypes: {'currency': const OsColumnDef<dynamic>(theme: typeTheme)},
      );

      final style = ResolvedGridTheme.forColumn(
        resolved.single,
        _base,
      ).cellTextStyle;

      // Type theme token wins over the base theme.
      expect(style.color, const Color(0xFF00AA00));
      // Tokens the type theme omits fall through to the base theme.
      expect(style.fontFamily, 'BaseFont');
      expect(style.fontSize, 14);
    });

    test('colDef cellStyle callback overrides the column type theme', () {
      const typeTheme = OsGridTheme(cellTextColor: Color(0xFF00AA00));
      final resolved = ColumnDefResolver.resolve(
        columns: [
          OsColumnDef<Map<String, dynamic>>(
            field: 'price',
            type: 'currency',
            cellStyle: (params) => const OsCellStyle(color: Color(0xFF0000FF)),
          ),
        ],
        defaultColDef: null,
        columnTypes: {'currency': const OsColumnDef<dynamic>(theme: typeTheme)},
      );

      final columnTheme = ResolvedGridTheme.forColumn(resolved.single, _base);
      const cellStyle = OsCellStyle(color: Color(0xFF0000FF));

      // Painter composition: per-cell callback beats the column cascade.
      expect(
        columnTheme.compose(cellStyle: cellStyle).color,
        const Color(0xFF0000FF),
      );
    });

    test('colDef theme overrides the column type theme', () {
      const colTheme = OsGridTheme(cellTextColor: Color(0xFFFF0000));
      const typeTheme = OsGridTheme(cellTextColor: Color(0xFF00AA00));
      final resolved = ColumnDefResolver.resolve(
        columns: [
          const OsColumnDef<dynamic>(
            field: 'price',
            type: 'currency',
            theme: colTheme,
          ),
        ],
        defaultColDef: null,
        columnTypes: {'currency': const OsColumnDef<dynamic>(theme: typeTheme)},
      );

      final style = ResolvedGridTheme.forColumn(
        resolved.single,
        _base,
      ).cellTextStyle;
      expect(style.color, const Color(0xFFFF0000));
    });

    test('defaultColDef theme applies when nothing more specific is set', () {
      const defaultTheme = OsGridTheme(cellTextColor: Color(0xFF123456));
      final resolved = ColumnDefResolver.resolve(
        columns: const [OsColumnDef<dynamic>(field: 'a')],
        defaultColDef: const OsColumnDef<dynamic>(theme: defaultTheme),
        columnTypes: null,
      );

      final style = ResolvedGridTheme.forColumn(
        resolved.single,
        _base,
      ).cellTextStyle;
      expect(style.color, const Color(0xFF123456));
    });

    test('theme.cellTextStyle replaces the base style wholesale', () {
      const typeTheme = OsGridTheme(
        cellTextStyle: TextStyle(fontFamily: 'TypeFont', fontSize: 16),
      );
      final resolved = ColumnDefResolver.resolve(
        columns: const [OsColumnDef<dynamic>(field: 'a', type: 't')],
        defaultColDef: null,
        columnTypes: {'t': const OsColumnDef<dynamic>(theme: typeTheme)},
      );

      final style = ResolvedGridTheme.forColumn(
        resolved.single,
        _base,
      ).cellTextStyle;
      expect(style.fontFamily, 'TypeFont');
      expect(style.fontSize, 16);
    });

    test('cellFontSize knob overlays onto the base style', () {
      const typeTheme = OsGridTheme(cellFontSize: 18);
      final resolved = ColumnDefResolver.resolve(
        columns: const [OsColumnDef<dynamic>(field: 'a', type: 't')],
        defaultColDef: null,
        columnTypes: {'t': const OsColumnDef<dynamic>(theme: typeTheme)},
      );

      final style = ResolvedGridTheme.forColumn(
        resolved.single,
        _base,
      ).cellTextStyle;
      expect(style.fontSize, 18);
      expect(style.fontFamily, 'BaseFont');
      expect(style.color, const Color(0xFF111111));
    });

    test('theme on a plain colDef resolves without the column resolver', () {
      const colTheme = OsGridTheme(cellTextColor: Color(0xFFFF0000));

      // No columnTypes/defaultColDef → the resolver never runs; the colDef
      // carries its theme straight to the painter.
      final style = ResolvedGridTheme.forColumn(
        const OsColumnDef<dynamic>(field: 'a', theme: colTheme),
        _base,
      ).cellTextStyle;
      expect(style.color, const Color(0xFFFF0000));
      expect(style.fontFamily, 'BaseFont');
    });

    test('base-level cellFontSize knob behaviour is unchanged', () {
      // The base theme's cellFontSize has never participated in canvas cell
      // painting (cellTextStyle does); the cascade must not change that.
      const base = OsGridTheme(cellFontSize: 99);
      final style = ResolvedGridTheme.forColumn(
        const OsColumnDef<dynamic>(field: 'a'),
        base,
      ).cellTextStyle;
      expect(style.fontSize, 13);
      expect(style.color, const Color(0xFF424242));
    });
  });

  group('Theme cascade: dynamic levels (ResolvedColumnTheme.compose)', () {
    final columnTheme = ResolvedGridTheme.forColumn(
      const OsColumnDef<dynamic>(
        field: 'price',
        theme: OsGridTheme(cellTextColor: Color(0xFF00AA00)),
      ),
      _base,
    );

    test('row style overrides the column cascade', () {
      const rowStyle = OsRowStyle(foregroundColor: Color(0xFF0000FF));
      expect(
        columnTheme.compose(rowStyle: rowStyle).color,
        const Color(0xFF0000FF),
      );
    });

    test('per-cell style overrides the row style', () {
      const rowStyle = OsRowStyle(foregroundColor: Color(0xFF0000FF));
      const cellStyle = OsCellStyle(color: Color(0xFFFF0000));
      final style = columnTheme.compose(
        cellStyle: cellStyle,
        rowStyle: rowStyle,
      );
      expect(style.color, const Color(0xFFFF0000));
    });

    test('row fontWeight/fontStyle override the column cascade', () {
      const rowStyle = OsRowStyle(
        fontWeight: FontWeight.bold,
        fontStyle: FontStyle.italic,
      );
      final style = columnTheme.compose(rowStyle: rowStyle);
      expect(style.fontWeight, FontWeight.bold);
      expect(style.fontStyle, FontStyle.italic);
      // Column text colour still applies (row style does not set one).
      expect(style.color, const Color(0xFF00AA00));
    });

    test('no dynamic overrides leaves the column cascade untouched', () {
      final style = columnTheme.compose();
      expect(style.color, const Color(0xFF00AA00));
      expect(style.fontFamily, 'BaseFont');
      expect(style.fontSize, 14);
    });
  });

  group('ColumnDefResolver theme merge', () {
    test('last listed type with a theme wins', () {
      const firstTheme = OsGridTheme(cellTextColor: Color(0xFF111111));
      const secondTheme = OsGridTheme(cellTextColor: Color(0xFF222222));
      final resolved = ColumnDefResolver.resolve(
        columns: const [
          OsColumnDef<dynamic>(field: 'a', type: ['t1', 't2']),
        ],
        defaultColDef: null,
        columnTypes: {
          't1': const OsColumnDef<dynamic>(theme: firstTheme),
          't2': const OsColumnDef<dynamic>(theme: secondTheme),
        },
      );

      expect(
        resolved.single.theme?.cellTextColor,
        const Color(0xFF222222),
        reason: 'types merge in listed order like every other field',
      );
    });

    test('column without a themed type keeps theme null', () {
      final resolved = ColumnDefResolver.resolve(
        columns: const [
          OsColumnDef<dynamic>(field: 'a'),
          OsColumnDef<dynamic>(field: 'b', type: 'plain'),
        ],
        defaultColDef: null,
        columnTypes: {'plain': const OsColumnDef<dynamic>(editable: false)},
      );

      expect(resolved[0].theme, isNull);
      expect(resolved[1].theme, isNull);
    });

    test('explicit colDef without theme inherits the type theme', () {
      const typeTheme = OsGridTheme(cellTextColor: Color(0xFF333333));
      final resolved = ColumnDefResolver.resolve(
        columns: const [OsColumnDef<dynamic>(field: 'a', type: 't')],
        defaultColDef: null,
        columnTypes: {'t': const OsColumnDef<dynamic>(theme: typeTheme)},
      );

      expect(identical(resolved.single.theme, typeTheme), isTrue);
    });
  });

  group('OsGrid with themed columnTypes', () {
    testWidgets('renders with a column type theme', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const OsGrid<Map<String, dynamic>>(
            columnDefs: [
              OsColumnDef(field: 'price', type: 'currency'),
              OsColumnDef(field: 'name'),
            ],
            columnTypes: {
              'currency': OsColumnDef<dynamic>(
                theme: OsGridTheme(cellTextColor: Color(0xFF00AA00)),
              ),
            },
            rowData: [
              {'price': 10, 'name': 'Alice'},
              {'price': 20, 'name': 'Bob'},
            ],
          ),
        ),
      );
      await tester.pump();

      final cols = _displayColumns(tester);
      final themed = cols.firstWhere((c) => c.field == 'price');
      expect(themed.theme?.cellTextColor, const Color(0xFF00AA00));
      expect(cols.firstWhere((c) => c.field == 'name').theme, isNull);
      expect(find.byType(VirtualisedGrid), findsOneWidget);
    });

    testWidgets('renders with cellStyle and row style above the cascade', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          OsGrid(
            columnDefs: [
              // Untyped colDef: the painter invokes the per-cell callback
              // with CellRendererParams<dynamic>, so typed closures are
              // unsupported by the paint path (pre-existing limitation).
              OsColumnDef<dynamic>(
                field: 'price',
                type: 'currency',
                cellStyle: (params) => params.value! > 15
                    ? const OsCellStyle(color: Color(0xFFFF0000))
                    : const OsCellStyle(),
              ),
            ],
            columnTypes: {
              'currency': const OsColumnDef<dynamic>(
                theme: OsGridTheme(cellTextColor: Color(0xFF00AA00)),
              ),
            },
            rowData: [
              {'price': 10},
              {'price': 20},
            ],
            getRowStyle: (params) =>
                const OsRowStyle(fontWeight: FontWeight.bold),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(VirtualisedGrid), findsOneWidget);
    });

    testWidgets('renders with a theme on a plain colDef (no types)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const OsGrid<Map<String, dynamic>>(
            columnDefs: [
              OsColumnDef(
                field: 'name',
                theme: OsGridTheme(cellTextColor: Color(0xFFFF0000)),
              ),
            ],
            rowData: [
              {'name': 'Alice'},
            ],
          ),
        ),
      );
      await tester.pump();

      final cols = _displayColumns(tester);
      expect(cols.single.theme?.cellTextColor, const Color(0xFFFF0000));
      expect(find.byType(VirtualisedGrid), findsOneWidget);
    });
  });
}
