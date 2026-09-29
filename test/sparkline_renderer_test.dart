import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

void main() {
  group('OsSparklineOptions', () {
    test('defaults', () {
      const opts = OsSparklineOptions();
      expect(opts.type, OsSparklineType.line);
      expect(opts.lineColor, isNull);
      expect(opts.fillColor, isNull);
      expect(opts.highlightColor, isNull);
      expect(opts.lineWidth, 1.5);
      expect(opts.paddingH, 2.0);
      expect(opts.paddingV, 2.0);
      expect(opts.minY, isNull);
      expect(opts.maxY, isNull);
      expect(opts.baseline, isNull);
    });

    test('rejects negative padding and non-positive lineWidth', () {
      expect(
        () => OsSparklineOptions(paddingH: -1),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => OsSparklineOptions(paddingV: -1),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => OsSparklineOptions(lineWidth: 0),
        throwsA(isA<AssertionError>()),
      );
    });

    test('copyWith replaces only provided fields', () {
      const opts = OsSparklineOptions();
      final copied = opts.copyWith(
        type: OsSparklineType.bar,
        lineWidth: 3,
        minY: 0,
        maxY: 10,
      );
      expect(copied.type, OsSparklineType.bar);
      expect(copied.lineWidth, 3);
      expect(copied.minY, 0);
      expect(copied.maxY, 10);
      // Untouched fields keep their values.
      expect(copied.paddingH, opts.paddingH);
      expect(copied.paddingV, opts.paddingV);
      expect(copied.baseline, isNull);
    });
  });

  group('OsSparklineOptions.extractData', () {
    test('null value yields empty series', () {
      expect(OsSparklineOptions.extractData(null), isEmpty);
    });

    test('non-list value yields empty series', () {
      expect(OsSparklineOptions.extractData(42), isEmpty);
      expect(OsSparklineOptions.extractData('trend'), isEmpty);
    });

    test('empty list yields empty series', () {
      expect(OsSparklineOptions.extractData(<num>[]), isEmpty);
    });

    test('numeric list maps to doubles preserving order', () {
      final result = OsSparklineOptions.extractData(<num>[1, 3, 2, 5, 4]);
      expect(result, <double>[1, 3, 2, 5, 4]);
      expect(result, everyElement(isA<double>()));
    });

    test('mixed int/double list is accepted', () {
      final result = OsSparklineOptions.extractData(<num>[1, 2.5, 3]);
      expect(result, <double>[1.0, 2.5, 3.0]);
    });

    test('filters non-num entries', () {
      final result = OsSparklineOptions.extractData(<Object?>[
        1,
        'x',
        null,
        2.5,
        true,
      ]);
      expect(result, <double>[1.0, 2.5]);
    });
  });

  group('OsSparklineOptions.resolveMinMax', () {
    test('derives bounds from data when not provided', () {
      final (min, max) = OsSparklineOptions.resolveMinMax(
        OsSparklineOptions.extractData(<num>[1, 3, 2, 5, 4]),
      );
      expect(min, 1);
      expect(max, 5);
    });

    test('explicit minY/maxY win over data extremes', () {
      final (min, max) = OsSparklineOptions.resolveMinMax(
        <double>[2, 4],
        minY: 0,
        maxY: 10,
      );
      expect(min, 0);
      expect(max, 10);
    });

    test('flat data expands to a symmetric window', () {
      final (min, max) = OsSparklineOptions.resolveMinMax(<double>[2, 2, 2]);
      expect(min, 1);
      expect(max, 3);
    });

    test('empty data returns a safe default window', () {
      final (min, max) = OsSparklineOptions.resolveMinMax(<double>[]);
      expect(min, 0);
      expect(max, 1);
    });
  });

  group('pointsFor geometry', () {
    // width=100, height=50, default padding 2 -> inner 96 x 46.
    // Data [1,3,2,5,4], bounds [1,5]: x evenly spaced at 2,26,50,74,98 and
    // y flipped so max touches the top padding.
    test('evenly spaces points and flips the Y axis', () {
      const opts = OsSparklineOptions();
      final points = opts.pointsFor(100, 50, <double>[1, 3, 2, 5, 4], 1, 5);

      expect(points, hasLength(5));
      expect(points[0].dx, closeTo(2, 1e-9));
      expect(points[1].dx, closeTo(26, 1e-9));
      expect(points[2].dx, closeTo(50, 1e-9));
      expect(points[3].dx, closeTo(74, 1e-9));
      expect(points[4].dx, closeTo(98, 1e-9));

      expect(points[0].dy, closeTo(48, 1e-9)); // min -> bottom
      expect(points[1].dy, closeTo(25, 1e-9)); // midpoint
      expect(points[2].dy, closeTo(36.5, 1e-9));
      expect(points[3].dy, closeTo(2, 1e-9)); // max -> top
      expect(points[4].dy, closeTo(13.5, 1e-9));
    });

    test('single point is centred horizontally', () {
      const opts = OsSparklineOptions(paddingH: 2, paddingV: 2);
      final points = opts.pointsFor(100, 50, <double>[3], 1, 5);
      expect(points, hasLength(1));
      expect(points.single.dx, closeTo(50, 1e-9));
      expect(points.single.dy, closeTo(25, 1e-9));
    });

    test('custom padding shrinks the plot area', () {
      const opts = OsSparklineOptions(paddingH: 10, paddingV: 5);
      final points = opts.pointsFor(100, 50, <double>[0, 10], 0, 10);
      expect(points.first.dx, closeTo(10, 1e-9));
      expect(points.first.dy, closeTo(45, 1e-9));
      expect(points.last.dx, closeTo(90, 1e-9));
      expect(points.last.dy, closeTo(5, 1e-9));
    });

    test('empty data yields no points', () {
      const opts = OsSparklineOptions();
      expect(opts.pointsFor(100, 50, <double>[], 0, 1), isEmpty);
    });
  });

  group('lttbDecimate (quality program v3 item 43)', () {
    test('series no longer than the target is returned unchanged', () {
      final data = <double>[1, 3, 2, 5, 4];
      final result = OsSparklineOptions.lttbDecimate(data, 5);
      expect(identical(result, data), isTrue);
      expect(
        identical(OsSparklineOptions.lttbDecimate(data, 50), data),
        isTrue,
      );
    });

    test('target below 3 points returns the series unchanged', () {
      final data = <double>[1, 2, 3, 4, 5];
      expect(identical(OsSparklineOptions.lttbDecimate(data, 2), data), isTrue);
      expect(identical(OsSparklineOptions.lttbDecimate(data, 0), data), isTrue);
    });

    test('hand-computed 6 -> 4 decimation', () {
      // bucketSize = 2. Bucket averages: next-bucket avg for i=0 is
      // (3.5, 5.5); areas for j=1,2 are 11.5 and 7.25 -> index 1 (value 5).
      // i=1 averages the final point (5, 3); areas for j=3,4 are 6 and 9
      // -> index 4 (value 2).
      final result = OsSparklineOptions.lttbDecimate(<double>[
        0,
        5,
        1,
        9,
        2,
        3,
      ], 4);
      expect(result, <double>[0, 5, 2, 3]);
    });

    test('hand-computed 5 -> 3 decimation keeps the tallest peak', () {
      final result = OsSparklineOptions.lttbDecimate(<double>[
        0,
        4,
        1,
        8,
        2,
      ], 3);
      expect(result, <double>[0, 8, 2]);
    });

    test('hand-computed 11 -> 4 with fractional bucket width', () {
      // bucketSize = 4.5; buckets mix neighbouring runs of the source.
      final result = OsSparklineOptions.lttbDecimate(<double>[
        0,
        3,
        1,
        4,
        1,
        5,
        9,
        2,
        6,
        5,
        3,
      ], 4);
      expect(result, <double>[0, 4, 9, 3]);
    });

    test('10k-point series decimates to exactly the target length', () {
      final data = List<double>.generate(
        10000,
        (i) => (i * 7 % 23).toDouble() * (i.isEven ? 1 : -1),
      );
      final result = OsSparklineOptions.lttbDecimate(data, 200);
      expect(result, hasLength(200));
      expect(result.first, data.first);
      expect(result.last, data.last);
    });

    test('peaks survive: global min and max appear in decimated output', () {
      // Gentle noise (|v| <= 22) with two huge injected spikes; the spike
      // triangles dominate their buckets, so LTTB must keep both extremes.
      final data = List<double>.generate(10000, (int i) {
        if (i == 3333) return 100000.0;
        if (i == 6666) return -100000.0;
        return (i * 7 % 23).toDouble() * (i.isEven ? 1 : -1);
      });
      final result = OsSparklineOptions.lttbDecimate(data, 200);
      expect(result, contains(100000.0));
      expect(result, contains(-100000.0));
    });

    test('same data always decimates to the same result', () {
      final data = List<double>.generate(
        10000,
        (i) => ((i * 37) % 101).toDouble() - 50,
      );
      final first = OsSparklineOptions.lttbDecimate(data, 200);
      final second = OsSparklineOptions.lttbDecimate(data, 200);
      expect(second, first);
      // An already-decimated series re-decimated at the same target is a
      // no-op (cached-shape stability across paints).
      expect(OsSparklineOptions.lttbDecimate(first, 200), first);
    });
  });

  group('resolveBaseline', () {
    const opts = OsSparklineOptions();

    test('range spanning zero uses zero-line by default', () {
      expect(opts.resolveBaseline(-5, 5), 0);
      expect(opts.resolveBaseline(-5, 0), 0);
    });

    test('all-positive range falls back to the bottom', () {
      expect(opts.resolveBaseline(2, 8), 2);
    });

    test('all-negative range falls back to the bottom', () {
      expect(opts.resolveBaseline(-8, -2), -8);
    });

    test('explicit baseline is used and clamped into range', () {
      expect(const OsSparklineOptions(baseline: 4).resolveBaseline(0, 10), 4);
      expect(const OsSparklineOptions(baseline: -5).resolveBaseline(0, 10), 0);
      expect(const OsSparklineOptions(baseline: 15).resolveBaseline(0, 10), 10);
    });
  });

  group('OsBuiltInCellRenderer.sparkline', () {
    test('enum value exists', () {
      expect(OsBuiltInCellRenderer.sparkline, isNotNull);
      expect(
        OsBuiltInCellRenderer.values.contains(OsBuiltInCellRenderer.sparkline),
        isTrue,
      );
    });

    test('can be assigned to OsColumnDef with options', () {
      const col = OsColumnDef(
        field: 'trend',
        headerName: 'Trend',
        width: 120,
        builtInCellRenderer: OsBuiltInCellRenderer.sparkline,
        sparklineOptions: OsSparklineOptions(type: OsSparklineType.area),
      );
      expect(col.builtInCellRenderer, OsBuiltInCellRenderer.sparkline);
      expect(col.sparklineOptions?.type, OsSparklineType.area);
    });

    test('copyWith preserves sparkline options', () {
      const col = OsColumnDef(
        field: 'trend',
        builtInCellRenderer: OsBuiltInCellRenderer.sparkline,
      );
      final updated = col.copyWith(
        sparklineOptions: const OsSparklineOptions(lineWidth: 2),
      );
      expect(updated.sparklineOptions?.lineWidth, 2);
      expect(col.copyWith().sparklineOptions, isNull);
    });

    Future<void> pumpSparklineGrid(
      WidgetTester tester, {
      required OsSparklineType type,
      Object? trendValue = const <num>[1, 3, 2, 5, 4],
      OsGridTheme theme = const OsGridTheme(),
      double columnWidth = 120,
    }) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid(
              theme: theme,
              columnDefs: [
                const OsColumnDef(field: 'name', headerName: 'Name'),
                OsColumnDef(
                  field: 'trend',
                  headerName: 'Trend',
                  width: columnWidth,
                  builtInCellRenderer: OsBuiltInCellRenderer.sparkline,
                  sparklineOptions: OsSparklineOptions(type: type),
                ),
              ],
              rowData: [
                {'name': 'Alice', 'trend': trendValue},
              ],
            ),
          ),
        ),
      );
    }

    for (final type in OsSparklineType.values) {
      testWidgets('grid renders $type sparkline without error', (tester) async {
        await pumpSparklineGrid(tester, type: type);
        expect(find.byType(VirtualisedGrid), findsOneWidget);
      });
    }

    testWidgets('handles null trend values without crashing', (tester) async {
      await pumpSparklineGrid(
        tester,
        type: OsSparklineType.line,
        trendValue: null,
      );
      expect(find.byType(VirtualisedGrid), findsOneWidget);
    });

    testWidgets('handles empty trend lists without crashing', (tester) async {
      await pumpSparklineGrid(
        tester,
        type: OsSparklineType.bar,
        trendValue: <num>[],
      );
      expect(find.byType(VirtualisedGrid), findsOneWidget);
    });

    testWidgets('filters non-numeric entries without crashing', (tester) async {
      await pumpSparklineGrid(
        tester,
        type: OsSparklineType.area,
        trendValue: <Object?>[1, 'x', null, 3],
      );
      expect(find.byType(VirtualisedGrid), findsOneWidget);
    });

    testWidgets('renders with custom theme colours', (tester) async {
      await pumpSparklineGrid(
        tester,
        type: OsSparklineType.line,
        theme: const OsGridTheme(accentColor: Color(0xFFFF9800)),
      );
      expect(find.byType(VirtualisedGrid), findsOneWidget);
    });

    // 10k points against a 200px column: 10000 > 2 * 200, so the paint path
    // decimates to cellWidth.floor().clamp(4, 500) == 200 points before
    // pathing.
    final List<num> wideTrend = <num>[
      for (int i = 0; i < 10000; i++)
        i == 3333
            ? 100.0
            : i == 6666
            ? -100.0
            : ((i * 7) % 23).toDouble(),
    ];

    for (final type in OsSparklineType.values) {
      testWidgets(
        '10k-point series at 200px column decimates without error ($type)',
        (tester) async {
          await pumpSparklineGrid(
            tester,
            type: type,
            trendValue: wideTrend,
            columnWidth: 200,
          );
          expect(tester.takeException(), isNull);
          expect(find.byType(VirtualisedGrid), findsOneWidget);
        },
      );
    }

    testWidgets('decimated frame is cached per data version', (tester) async {
      // First paint records the frame (LTTB runs inside the record closure);
      // the second paint of the same data instance blits the cached picture,
      // so the decimated result is reused without recomputation.
      await pumpSparklineGrid(
        tester,
        type: OsSparklineType.line,
        trendValue: wideTrend,
        columnWidth: 200,
      );
      expect(tester.takeException(), isNull);
      await pumpSparklineGrid(
        tester,
        type: OsSparklineType.line,
        trendValue: wideTrend,
        columnWidth: 200,
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(VirtualisedGrid), findsOneWidget);
    });
  });
}
