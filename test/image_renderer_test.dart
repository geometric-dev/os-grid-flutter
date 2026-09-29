import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';

/// Creates a real (software-rendered) `ui.Image` for cache/paint tests.
Future<ui.Image> createTestImage(int width, int height, Color color) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    Offset.zero & Size(width.toDouble(), height.toDouble()),
    Paint()..color = color,
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  picture.dispose();
  return image;
}

void main() {
  group('OsImageOptions', () {
    test('defaults', () {
      const OsImageOptions opts = OsImageOptions();
      expect(opts.imageForCell, isNull);
      expect(opts.fit, OsImageFit.contain);
      expect(opts.cornerRadius, 0.0);
      expect(opts.paddingH, 3.0);
      expect(opts.paddingV, 3.0);
      expect(opts.placeholderColor, isNull);
    });

    test('rejects negative corner radius and padding', () {
      expect(
        () => OsImageOptions(cornerRadius: -1),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => OsImageOptions(paddingH: -1),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => OsImageOptions(paddingV: -1),
        throwsA(isA<AssertionError>()),
      );
    });

    test('copyWith replaces only provided fields', () {
      const OsImageOptions opts = OsImageOptions();
      final copied = opts.copyWith(
        fit: OsImageFit.cover,
        cornerRadius: 8,
        placeholderColor: Colors.red,
      );
      expect(copied.fit, OsImageFit.cover);
      expect(copied.cornerRadius, 8);
      expect(copied.placeholderColor, Colors.red);
      // Untouched fields keep their values.
      expect(copied.paddingH, opts.paddingH);
      expect(copied.paddingV, opts.paddingV);
      expect(copied.imageForCell, isNull);
    });
  });

  group('OsImageOptions.resolveDestRect', () {
    const Rect cell = Rect.fromLTWH(10, 20, 100, 50);

    test('fill stretches to the exact cell rect', () {
      expect(
        OsImageOptions.resolveDestRect(cell, 40, 30, OsImageFit.fill),
        cell,
      );
    });

    test('contain letterboxes a wide image into the cell (height-limited)', () {
      final rect = OsImageOptions.resolveDestRect(
        cell,
        200,
        50,
        OsImageFit.contain,
      );
      // Scale limited by width? No — 100/200 = 0.5 vs 50/50 = 1 → width-bound.
      expect(rect.width, 100);
      expect(rect.height, 25);
      expect(rect.top, 20 + 12.5);
    });

    test('contain letterboxes a tall image (height-bound, centred)', () {
      final rect = OsImageOptions.resolveDestRect(
        cell,
        50,
        200,
        OsImageFit.contain,
      );
      expect(rect.width, 12.5);
      expect(rect.height, 50);
      expect(rect.left, 10 + 43.75);
    });

    test('cover overflows the cell (caller clips)', () {
      final rect = OsImageOptions.resolveDestRect(
        cell,
        200,
        50,
        OsImageFit.cover,
      );
      // Height-bound scale of 1 → 200×50, overflowing horizontally.
      expect(rect.width, 200);
      expect(rect.height, 50);
      expect(rect.left, lessThan(cell.left));
    });

    test('scaleDown keeps natural size when the image fits', () {
      final rect = OsImageOptions.resolveDestRect(
        cell,
        40,
        30,
        OsImageFit.scaleDown,
      );
      expect(rect.width, 40);
      expect(rect.height, 30);
      expect(rect.left, 40);
      expect(rect.top, 30);
    });

    test('scaleDown shrinks like contain when the image overflows', () {
      final rect = OsImageOptions.resolveDestRect(
        cell,
        200,
        50,
        OsImageFit.scaleDown,
      );
      expect(rect.width, 100);
      expect(rect.height, 25);
    });

    test('degenerate image size falls back to the cell rect', () {
      expect(
        OsImageOptions.resolveDestRect(cell, 0, 30, OsImageFit.contain),
        cell,
      );
      expect(
        OsImageOptions.resolveDestRect(cell, 40, 0, OsImageFit.cover),
        cell,
      );
    });
  });

  group('ImageCellCache', () {
    setUp(() {
      ImageCellCache.clear();
    });

    test(
      'load stores the fetched image and dedupes concurrent loads',
      () async {
        var fetchCount = 0;
        final image = await createTestImage(2, 2, const Color(0xFF00FF00));

        Future<ui.Image?> fetch() async {
          fetchCount++;
          return image;
        }

        final first = ImageCellCache.load('k', fetch);
        final second = ImageCellCache.load('k', fetch);
        expect(
          identical(first, second),
          isTrue,
          reason: 'concurrent loads share one future',
        );
        await first;

        expect(fetchCount, 1);
        expect(ImageCellCache.length, 1);
        expect(ImageCellCache.get('k'), same(image));

        // A subsequent load resolves from the cache without re-fetching.
        await ImageCellCache.load('k', fetch);
        expect(fetchCount, 1);
      },
    );

    test(
      'load reports null for a null fetch and marks the key failed',
      () async {
        var fetchCount = 0;
        Future<ui.Image?> fetch() async {
          fetchCount++;
          return null;
        }

        expect(await ImageCellCache.load('missing', fetch), isNull);
        expect(ImageCellCache.hasFailed('missing'), isTrue);
        expect(ImageCellCache.length, 0);

        // Failed loads short-circuit: the fetcher is not invoked again.
        await ImageCellCache.load('missing', fetch);
        expect(fetchCount, 1);
      },
    );

    test('load swallows fetch errors and marks the key failed', () async {
      Future<ui.Image?> fetch() async => throw StateError('boom');
      expect(await ImageCellCache.load('boom', fetch), isNull);
      expect(ImageCellCache.hasFailed('boom'), isTrue);
      expect(ImageCellCache.pendingCount, 0);
    });

    test('onLoaded fires after every completion, success or failure', () async {
      var completions = 0;
      await ImageCellCache.load(
        'a',
        () async => null,
        onLoaded: () => completions++,
      );
      final image = await createTestImage(2, 2, const Color(0xFF0000FF));
      await ImageCellCache.load(
        'b',
        () async => image,
        onLoaded: () => completions++,
      );
      expect(completions, 2);
    });

    test(
      'put evicts the oldest entry beyond capacity without disposing',
      () async {
        final image = await createTestImage(1, 1, Colors.red);
        for (int i = 0; i < ImageCellCache.maxSize; i++) {
          ImageCellCache.put('k$i', image);
        }
        ImageCellCache.put('newest', image);
        expect(ImageCellCache.length, ImageCellCache.maxSize);
        expect(ImageCellCache.get('k0'), isNull, reason: 'oldest evicted');
        expect(ImageCellCache.get('newest'), same(image));
      },
    );

    test('LRU get refreshes recency', () async {
      final image = await createTestImage(1, 1, Colors.green);
      // Fill the cache, then refresh 'k0' so 'k1' becomes the oldest.
      for (int i = 0; i < ImageCellCache.maxSize; i++) {
        ImageCellCache.put('k$i', image);
      }
      expect(ImageCellCache.get('k0'), same(image));
      ImageCellCache.put('newest', image);
      expect(
        ImageCellCache.get('k1'),
        isNull,
        reason: 'k1 was oldest after refresh',
      );
      expect(ImageCellCache.get('k0'), same(image));
    });

    test(
      'clear disposes each distinct image once and resets failures',
      () async {
        final shared = await createTestImage(1, 1, Colors.red);
        final other = await createTestImage(1, 1, Colors.blue);
        ImageCellCache.put('a', shared);
        ImageCellCache.put('b', shared); // same instance under two keys
        ImageCellCache.put('c', other);
        ImageCellCache.load('x', () async => null); // marks 'x' failed

        ImageCellCache.clear();
        expect(ImageCellCache.length, 0);
        expect(shared.debugDisposed, isTrue);
        expect(other.debugDisposed, isTrue);
      },
    );
  });

  group('ImageRenderer Widget Tests', () {
    tearDown(() {
      ImageCellCache.clear();
    });

    Future<void> pumpImageGrid(
      WidgetTester tester, {
      required List<Map<String, dynamic>> rowData,
      OsImageOptions? options,
    }) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OsGrid(
              key: const Key('grid'),
              columnDefs: [
                OsColumnDef(
                  field: 'photo',
                  headerName: 'Photo',
                  width: 60,
                  builtInCellRenderer: OsBuiltInCellRenderer.image,
                  imageOptions: options,
                ),
              ],
              rowData: rowData,
            ),
          ),
        ),
      );
    }

    testWidgets('paints a ui.Image cell value directly without caching', (
      tester,
    ) async {
      final image = await tester.runAsync(
        () => createTestImage(8, 8, const Color(0xFFFF0000)),
      );
      await pumpImageGrid(
        tester,
        rowData: [
          {'photo': image},
        ],
      );
      await tester.pumpAndSettle();

      expect(find.byType(VirtualisedGrid), findsOneWidget);
      expect(
        ImageCellCache.length,
        0,
        reason: 'direct ui.Image values bypass the cache',
      );
    });

    testWidgets('loads via imageForCell exactly once and repaints', (
      tester,
    ) async {
      final image = await tester.runAsync(
        () => createTestImage(8, 8, const Color(0xFF00FF00)),
      );
      var fetchCount = 0;
      await pumpImageGrid(
        tester,
        rowData: [
          {'photo': 'user-1'},
        ],
        options: OsImageOptions(
          imageForCell: (params) async {
            fetchCount++;
            return image;
          },
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(fetchCount, 1, reason: 'loader invoked exactly once');
      expect(ImageCellCache.length, 1);
      expect(find.byType(VirtualisedGrid), findsOneWidget);
    });

    testWidgets('failed loads fall back to placeholder without retry loops', (
      tester,
    ) async {
      var fetchCount = 0;
      await pumpImageGrid(
        tester,
        rowData: [
          {'photo': 'broken'},
        ],
        options: OsImageOptions(
          imageForCell: (params) async {
            fetchCount++;
            throw StateError('network down');
          },
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();

      expect(fetchCount, 1, reason: 'no retry after failure');
      expect(find.byType(VirtualisedGrid), findsOneWidget);
    });

    testWidgets('handles missing options and null values without crashing', (
      tester,
    ) async {
      await pumpImageGrid(
        tester,
        rowData: [
          {'photo': null},
          {'photo': 'no-loader-configured'},
        ],
      );
      await tester.pumpAndSettle();
      expect(find.byType(VirtualisedGrid), findsOneWidget);
      expect(ImageCellCache.length, 0);
    });
  });
}
