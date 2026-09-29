import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../theming/os_grid_theme.dart';

/// A pre-rendered paint primitive (quality program v3 item 6).
///
/// Wraps a [ui.Picture] recorded in glyph-local coordinates (origin at the
/// top-left of the primitive) together with the metrics needed to place it
/// — [width]/[height] mirror the layout size the direct-painting path would
/// have measured — and an optional identity [guard].
///
/// The guard supports the sparkline cache: when set, a cache lookup only
/// hits if the requesting cell value is the SAME object instance the entry
/// was recorded from, so in-place list mutation falls back to re-recording
/// instead of blitting stale pixels.
class RasterGlyph {
  const RasterGlyph({
    required this.picture,
    required this.width,
    required this.height,
    this.guard,
  });

  final ui.Picture picture;

  /// Layout width of the primitive in logical pixels.
  final double width;

  /// Layout height of the primitive in logical pixels.
  final double height;

  /// Identity sentinel: a lookup with a different instance misses.
  final Object? guard;
}

/// LRU-bounded store of [RasterGlyph]s keyed by fully-resolved state strings.
///
/// Keys must capture every input that changes rendered pixels (variant,
/// size, resolved colours, scaler, direction) so an entry can never be
/// blitted under a state it was not recorded for. Hits are moved to the end
/// of the insertion-ordered map for LRU freshness; eviction and clearing
/// dispose the evicted pictures.
class RasterPictureStore {
  RasterPictureStore({required this.maxSize});

  /// Maximum entries before the oldest is evicted.
  final int maxSize;

  final Map<String, RasterGlyph> _entries = {};

  /// Number of entries currently cached.
  int get length => _entries.length;

  /// Returns the cached glyph for [key], or null. When [guard] is non-null
  /// (or the entry carries one) both sides must be the identical instance.
  RasterGlyph? get(String key, {Object? guard}) {
    final glyph = _entries[key];
    if (glyph == null) return null;
    if (!identical(glyph.guard, guard)) return null;
    // Refresh LRU position.
    _entries.remove(key);
    _entries[key] = glyph;
    return glyph;
  }

  /// Inserts [glyph], disposing any entry it replaces and evicting the
  /// oldest entry when at capacity.
  void put(String key, RasterGlyph glyph) {
    final replaced = _entries.remove(key);
    replaced?.picture.dispose();
    while (_entries.length >= maxSize) {
      _entries.remove(_entries.keys.first)?.picture.dispose();
    }
    _entries[key] = glyph;
  }

  /// Disposes and drops every entry.
  void clear() {
    for (final glyph in _entries.values) {
      glyph.picture.dispose();
    }
    _entries.clear();
  }
}

/// Static raster caches for the frequently repeated paint primitives
/// (quality program v3 item 6): checkbox glyphs, star-rating glyphs, and
/// whole sparkline cell frames.
///
/// Each primitive is recorded once via `PictureRecorder` in glyph-local
/// coordinates and replayed with `canvas.drawPicture` — pixel-identical to
/// the direct path painting it replaced because the recorded ops and the
/// resulting canvas transform are exactly the ones the direct path issued.
///
/// Invalidation: painting hooks route through [syncTheme], which drops every
/// cache when the active [OsGridTheme] instance changes (theme swap = new
/// instance → caches cleared → next paint re-records under the new colours).
/// Cache keys additionally carry all resolved colours so a missed sync can
/// never return stale pixels — clearing bounds memory, keying guarantees
/// correctness.
class RasterGlyphCache {
  RasterGlyphCache._();

  /// Theme instance the current cache contents were recorded under.
  static OsGridTheme? _themeGeneration;

  /// Checkbox glyphs: variant × size × resolved colours (max 50 entries).
  static final RasterPictureStore checkbox = RasterPictureStore(maxSize: 50);

  /// Star glyphs: filled/empty × font size × colour × scaler × direction
  /// (max 50 entries).
  static final RasterPictureStore star = RasterPictureStore(maxSize: 50);

  /// Whole sparkline cell frames: data identity × cell size × options hash
  /// (max 100 entries).
  static final RasterPictureStore sparkline = RasterPictureStore(maxSize: 100);

  /// Drops every cache when [theme] is not the instance the current
  /// contents were recorded under. Called at every glyph paint site.
  static void syncTheme(OsGridTheme? theme) {
    if (identical(theme, _themeGeneration)) return;
    clearRasterCaches();
    _themeGeneration = theme;
  }

  /// Records [draw] into a fresh picture in glyph-local coordinates via
  /// `ui.PictureRecorder`.
  ///
  /// No cull rect is set (defaults to the largest rect) so primitives that
  /// intentionally bleed past the cell bounds — the sparkline highlight dot
  /// does — are never clipped inside the recording.
  static RasterGlyph record({
    required double width,
    required double height,
    Object? guard,
    required void Function(Canvas canvas) draw,
  }) {
    final recorder = ui.PictureRecorder();
    draw(Canvas(recorder));
    final picture = recorder.endRecording();
    return RasterGlyph(
      picture: picture,
      width: width,
      height: height,
      guard: guard,
    );
  }

  /// Gets-or-records the glyph for [key] in [store] and blits it at
  /// [offset]. The single entry point for stateless glyphs (checkboxes,
  /// stars); the sparkline path uses [RasterPictureStore.get] with a guard
  /// before recording instead, because its create closure needs to close
  /// over per-cell data.
  static void drawGlyph({
    required Canvas canvas,
    required Offset offset,
    required RasterPictureStore store,
    required String key,
    required RasterGlyph Function() create,
  }) {
    var glyph = store.get(key);
    if (glyph == null) {
      glyph = create();
      store.put(key, glyph);
    }
    blit(canvas, offset, glyph);
  }

  /// Replays [glyph] at [offset]: translate + drawPicture, the exact CTM
  /// the direct path would have painted under.
  static void blit(Canvas canvas, Offset offset, RasterGlyph glyph) {
    canvas
      ..save()
      ..translate(offset.dx, offset.dy)
      ..drawPicture(glyph.picture)
      ..restore();
  }

  /// Total entries across all stores (test instrumentation; re-exposed on
  /// `GridPainter` as its `@visibleForTesting rasterCacheSize`).
  static int get rasterCacheSize =>
      checkbox.length + star.length + sparkline.length;

  /// Checkbox store entry count (test instrumentation).
  static int get checkboxCacheSize => checkbox.length;

  /// Star store entry count (test instrumentation).
  static int get starCacheSize => star.length;

  /// Sparkline store entry count (test instrumentation).
  static int get sparklineCacheSize => sparkline.length;

  /// Disposes and clears every store (test instrumentation; re-exposed on
  /// `GridPainter` as its `@visibleForTesting clearRasterCaches`).
  static void clearRasterCaches() {
    checkbox.clear();
    star.clear();
    sparkline.clear();
  }
}
