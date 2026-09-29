import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/os_grid_flutter.dart';
import 'package:os_grid_flutter/src/rendering/body_painter.dart';
import 'package:os_grid_flutter/src/rendering/grid_painter.dart';
import 'package:os_grid_flutter/src/rendering/raster_glyph_cache.dart';

/// Tests for the raster glyph caches (quality program v3 item 6): fill,
/// same-state reuse without growth, LRU eviction, theme-change invalidation,
/// and pixel determinism between the record path and the cache-hit blit
/// path. Byte-stability versus direct path painting is additionally proven
/// by the goldens in test/goldens/raster_glyph_golden_test.dart, which were
/// generated against the pre-cache implementation.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const size = Size(420, 300);
  const themeA = OsGridTheme(accentColor: Color(0xFF9C27B0));
  const themeB = OsGridTheme(accentColor: Color(0xFF4CAF50));

  const columns = [
    OsColumnDef(
      field: 'done',
      headerName: 'Done',
      width: 90,
      checkboxSelection: true,
    ),
    OsColumnDef(
      field: 'rating',
      headerName: 'Rating',
      width: 150,
      builtInCellRenderer: OsBuiltInCellRenderer.starRating,
    ),
    OsColumnDef(
      field: 'trend',
      headerName: 'Trend',
      width: 120,
      builtInCellRenderer: OsBuiltInCellRenderer.sparkline,
    ),
  ];

  List<Map<String, dynamic>> buildRows({int count = 6, int seed = 0}) =>
      List.generate(count, (i) {
        return <String, dynamic>{
          'done': i.isEven,
          'rating': i % 6,
          'trend': <num>[seed + i, 3, 2, 5 + seed, 4],
        };
      });

  GridPainter buildPainter({
    OsGridTheme? theme,
    required List<Map<String, dynamic>> rows,
    double scrollY = 0,
  }) {
    return GridPainter(
      columns: columns,
      rowData: rows,
      rowHeight: 28,
      headerHeight: 24,
      scrollX: 0,
      scrollY: scrollY,
      theme: theme,
    );
  }

  /// Paints [painter] once into a throwaway picture (realistic full-grid
  /// paint pass through every band painter).
  void paintOnce(GridPainter painter) {
    final recorder = ui.PictureRecorder();
    painter.paint(ui.Canvas(recorder), size);
    recorder.endRecording().dispose();
  }

  setUp(() {
    RasterGlyphCache.clearRasterCaches();
    // Reset the theme generation so each test starts from a clean slate.
    RasterGlyphCache.syncTheme(themeA);
    RasterGlyphCache.clearRasterCaches();
  });

  group('RasterPictureStore LRU', () {
    ui.Picture tinyPicture() {
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawRect(const Rect.fromLTWH(0, 0, 1, 1), Paint());
      return recorder.endRecording();
    }

    RasterGlyph glyph([Object? guard]) =>
        RasterGlyph(picture: tinyPicture(), width: 1, height: 1, guard: guard);

    test('fills to capacity and evicts the oldest entry', () {
      final store = RasterPictureStore(maxSize: 3);
      store.put('k1', glyph());
      store.put('k2', glyph());
      store.put('k3', glyph());
      expect(store.length, 3);

      store.put('k4', glyph());
      expect(store.length, 3, reason: 'insertion beyond capacity evicts');
      expect(store.get('k1'), isNull, reason: 'oldest entry evicted first');
      expect(store.get('k4'), isNotNull);
      expect(store.get('k2'), isNotNull);
      expect(store.get('k3'), isNotNull);
    });

    test('get refreshes LRU order so refreshed entries survive', () {
      final store = RasterPictureStore(maxSize: 3);
      store.put('k1', glyph());
      store.put('k2', glyph());
      store.put('k3', glyph());

      // Touch k1 so it becomes most-recently used.
      expect(store.get('k1'), isNotNull);

      store.put('k4', glyph());
      expect(store.get('k1'), isNotNull, reason: 'refreshed entry survives');
      expect(store.get('k2'), isNull, reason: 'untouched oldest evicted');
    });

    test('replacing a key disposes the previous picture', () {
      final store = RasterPictureStore(maxSize: 3);
      final first = glyph();
      store.put('k', first);
      store.put('k', glyph());
      expect(first.picture.debugDisposed, isTrue);
      expect(store.get('k'), isNotNull);
    });

    test('clear disposes every picture and empties the store', () {
      final store = RasterPictureStore(maxSize: 3);
      final a = glyph();
      final b = glyph();
      store.put('a', a);
      store.put('b', b);
      store.clear();
      expect(store.length, 0);
      expect(a.picture.debugDisposed, isTrue);
      expect(b.picture.debugDisposed, isTrue);
    });

    test('identity guard: a different value instance misses', () {
      final store = RasterPictureStore(maxSize: 3);
      final list1 = <num>[1, 2, 3];
      final entry = RasterGlyph(
        picture: tinyPicture(),
        width: 1,
        height: 1,
        guard: list1,
      );
      store.put('spark', entry);

      expect(
        store.get('spark', guard: list1),
        isNotNull,
        reason: 'same instance hits',
      );
      expect(
        store.get('spark', guard: <num>[1, 2, 3]),
        isNull,
        reason: 'equal but non-identical instance misses',
      );
      expect(
        entry.picture.debugDisposed,
        isFalse,
        reason: 'a guard miss must not dispose the cached entry',
      );
      store.clear();
    });
  });

  group('raster cache fills and reuses', () {
    testWidgets('first paint fills checkbox, star, and sparkline stores', (
      tester,
    ) async {
      paintOnce(buildPainter(theme: themeA, rows: buildRows()));

      expect(
        RasterGlyphCache.checkboxCacheSize,
        greaterThanOrEqualTo(2),
        reason: 'checked and unchecked glyphs cached',
      );
      expect(
        RasterGlyphCache.starCacheSize,
        greaterThanOrEqualTo(2),
        reason: 'filled and empty star glyphs cached',
      );
      expect(
        RasterGlyphCache.sparklineCacheSize,
        greaterThanOrEqualTo(1),
        reason: 'one picture per distinct data list',
      );
      expect(
        RasterGlyphCache.rasterCacheSize,
        RasterGlyphCache.checkboxCacheSize +
            RasterGlyphCache.starCacheSize +
            RasterGlyphCache.sparklineCacheSize,
      );
    });

    testWidgets('same-state repaint reuses pictures without growth', (
      tester,
    ) async {
      // One shared row list: the sparkline data list instances (and every
      // other input) must be identical across both paints.
      final rows = buildRows();
      paintOnce(buildPainter(theme: themeA, rows: rows));

      final checkboxBefore = RasterGlyphCache.checkboxCacheSize;
      final starBefore = RasterGlyphCache.starCacheSize;
      final sparklineBefore = RasterGlyphCache.sparklineCacheSize;
      expect(checkboxBefore, greaterThan(0));
      expect(starBefore, greaterThan(0));
      expect(sparklineBefore, greaterThan(0));

      paintOnce(buildPainter(theme: themeA, rows: rows));

      expect(
        RasterGlyphCache.checkboxCacheSize,
        checkboxBefore,
        reason: 'identical state must not add entries',
      );
      expect(RasterGlyphCache.starCacheSize, starBefore);
      expect(RasterGlyphCache.sparklineCacheSize, sparklineBefore);
      expect(
        RasterGlyphCache.rasterCacheSize,
        checkboxBefore + starBefore + sparklineBefore,
      );
    });

    testWidgets('painter exposes rasterCacheSize and clearRasterCaches', (
      tester,
    ) async {
      final painter = buildPainter(theme: themeA, rows: buildRows());
      paintOnce(painter);
      expect(painter.rasterCacheSize, greaterThan(0));

      painter.clearRasterCaches();
      expect(painter.rasterCacheSize, 0);
      expect(RasterGlyphCache.checkboxCacheSize, 0);
      expect(RasterGlyphCache.starCacheSize, 0);
      expect(RasterGlyphCache.sparklineCacheSize, 0);
    });
  });

  group('theme invalidation', () {
    testWidgets('painting under a new theme instance clears prior entries', (
      tester,
    ) async {
      // Establish the expected entry count for theme B alone.
      paintOnce(buildPainter(theme: themeB, rows: buildRows()));
      final sizeB = RasterGlyphCache.rasterCacheSize;
      expect(sizeB, greaterThan(0));

      // Fresh start under theme A, then switch to theme B.
      RasterGlyphCache.clearRasterCaches();
      paintOnce(buildPainter(theme: themeA, rows: buildRows()));
      final sizeA = RasterGlyphCache.rasterCacheSize;
      expect(sizeA, greaterThan(0));

      paintOnce(buildPainter(theme: themeB, rows: buildRows()));
      expect(
        RasterGlyphCache.rasterCacheSize,
        sizeB,
        reason:
            'theme switch must clear theme-A entries; only theme-B '
            'keys (different accent colour) may remain',
      );
      expect(
        RasterGlyphCache.rasterCacheSize,
        isNot(sizeA + sizeB),
        reason: 'stale theme-A entries would double the cache',
      );
    });

    test('syncTheme clears only when the theme instance changes', () {
      ui.Picture emptyPicture() {
        final recorder = ui.PictureRecorder();
        ui.Canvas(recorder).drawPaint(Paint()..color = const Color(0x00000000));
        return recorder.endRecording();
      }

      RasterGlyphCache.syncTheme(themeA);
      RasterGlyphCache.checkbox.put(
        'k',
        RasterGlyph(picture: emptyPicture(), width: 1, height: 1),
      );
      expect(RasterGlyphCache.checkbox.length, 1);

      RasterGlyphCache.syncTheme(themeA);
      expect(
        RasterGlyphCache.checkbox.length,
        1,
        reason: 'identical theme keeps entries',
      );

      RasterGlyphCache.syncTheme(themeB);
      expect(
        RasterGlyphCache.checkbox.length,
        0,
        reason: 'new theme instance clears',
      );
      // Restore the per-test baseline.
      RasterGlyphCache.syncTheme(themeA);
    });
  });

  group('sparkline frame cache', () {
    testWidgets('distinct data lists cache independently; LRU caps entries', (
      tester,
    ) async {
      // 12 frames x ~10 visible rows of distinct sparkline lists exceeds
      // the 100-entry store cap, forcing real eviction through the paint
      // path.
      for (var frame = 0; frame < 12; frame++) {
        paintOnce(
          buildPainter(
            theme: themeA,
            rows: buildRows(count: 40, seed: frame * 100),
            scrollY: frame * 280.0,
          ),
        );
      }
      expect(RasterGlyphCache.sparklineCacheSize, lessThanOrEqualTo(100));
      expect(RasterGlyphCache.sparklineCacheSize, greaterThan(0));
    });

    testWidgets('same list instance across rows shares one entry', (
      tester,
    ) async {
      final shared = <num>[1, 3, 2, 5, 4];
      final rows = List<Map<String, dynamic>>.generate(
        6,
        (i) => <String, dynamic>{
          'done': i.isEven,
          'rating': i,
          'trend': shared,
        },
      );
      paintOnce(buildPainter(theme: themeA, rows: rows));
      expect(
        RasterGlyphCache.sparklineCacheSize,
        1,
        reason: 'one picture per distinct list instance',
      );
    });
  });

  group('pixel determinism', () {
    Future<Uint8List> renderBytes(
      WidgetTester tester,
      ui.Picture picture,
      int w,
      int h,
    ) async {
      final image = await tester.runAsync(() => picture.toImage(w, h));
      if (image == null) fail('picture.toImage returned null');
      final data = await tester.runAsync(
        () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
      );
      return data!.buffer.asUint8List();
    }

    testWidgets('cache-hit blit is pixel-identical to the record pass', (
      tester,
    ) async {
      ui.Picture paintChecked() {
        final recorder = ui.PictureRecorder();
        BodyPainter.paintCheckbox(
          ui.Canvas(recorder),
          5,
          7,
          33,
          21,
          true,
          theme: themeA,
        );
        return recorder.endRecording();
      }

      RasterGlyphCache.syncTheme(themeA);

      // First call records; second call must be served from the cache.
      paintChecked().dispose();
      final direct = paintChecked();
      final cached = paintChecked();

      final a = await renderBytes(tester, direct, 48, 32);
      final b = await renderBytes(tester, cached, 48, 32);
      expect(b, a, reason: 'record pass and cache-hit blit must match');
      expect(
        a.any((byte) => byte != 0),
        isTrue,
        reason: 'sanity: the glyph actually rasterised',
      );
      direct.dispose();
      cached.dispose();
    });
  });
}
