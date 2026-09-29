import 'dart:ui' as ui;

/// Static LRU cache of decoded `ui.Image`s for the image cell renderer.
///
/// The body painter is synchronous, so asynchronously decoded images follow
/// a three-state flow per cache key:
///
/// 1. **Miss** — the painter paints a placeholder and calls [load], which
///    starts the fetch exactly once (in-flight requests are deduplicated,
///    so painting every frame never re-triggers the loader).
/// 2. **In flight** — subsequent paints see the pending future and keep
///    painting the placeholder.
/// 3. **Loaded** — the decoded image is stored, and the grid's repaint hook
///    fires so the next frame blits the pixels. Failures are recorded in a
///    failed set so a broken source cannot cause a load-retry loop on every
///    frame; [clear] resets them.
///
/// Eviction drops entries without calling `ui.Image.dispose()`: the image
/// may still be referenced by another paint pass (or another grid sharing
/// this static cache), and Dart finalises unreachable images natively.
/// [clear] does dispose — it is meant for explicit teardown (tests, grid
/// disposal) and disposes each distinct image instance once even if it was
/// stored under multiple keys.
///
/// Keys are caller-defined strings; the image renderer uses
/// `colId + row-data identity`. Bound: [maxSize] entries (LRU refresh on
/// hit).
class ImageCellCache {
  ImageCellCache._();

  /// Maximum entries before the oldest is evicted.
  static const int maxSize = 200;

  static final Map<String, ui.Image> _entries = <String, ui.Image>{};
  static final Map<String, Future<ui.Image?>> _inFlight =
      <String, Future<ui.Image?>>{};
  static final Set<String> _failed = <String>{};

  /// Number of decoded images currently cached (test instrumentation).
  static int get length => _entries.length;

  /// Number of loads currently in flight (test instrumentation).
  static int get pendingCount => _inFlight.length;

  /// Whether a load previously failed for [key] (test instrumentation).
  static bool hasFailed(String key) => _failed.contains(key);

  /// Returns the cached image for [key], refreshing its LRU position.
  static ui.Image? get(String key) {
    final ui.Image? image = _entries[key];
    if (image == null) return null;
    _entries.remove(key);
    _entries[key] = image;
    return image;
  }

  /// Stores [image] under [key], evicting the oldest entry when at
  /// capacity. Evicted images are dropped without dispose (see class docs).
  static void put(String key, ui.Image image) {
    _entries.remove(key);
    while (_entries.length >= maxSize) {
      _entries.remove(_entries.keys.first);
    }
    _entries[key] = image;
  }

  /// Ensures [fetch] runs at most once per key until completion.
  ///
  /// Returns immediately with the cached image when present, the pending
  /// future when a load is already in flight, or null-future when a
  /// previous load failed. [onLoaded] fires after every completion (success
  /// or failure) so the host can schedule a repaint.
  static Future<ui.Image?> load(
    String key,
    Future<ui.Image?> Function() fetch, {
    void Function()? onLoaded,
  }) {
    final ui.Image? cached = _entries[key];
    if (cached != null) return Future<ui.Image?>.value(cached);
    if (_failed.contains(key)) return Future<ui.Image?>.value(null);
    final Future<ui.Image?>? pending = _inFlight[key];
    if (pending != null) return pending;

    final Future<ui.Image?> future = () async {
      try {
        final ui.Image? image = await fetch();
        if (image != null) {
          put(key, image);
          return image;
        }
        _failed.add(key);
        return null;
      } catch (_) {
        _failed.add(key);
        return null;
      } finally {
        _inFlight.remove(key);
        onLoaded?.call();
      }
    }();
    _inFlight[key] = future;
    return future;
  }

  /// Disposes and drops every entry and resets failed markers.
  ///
  /// In-flight futures may still complete afterwards and re-populate the
  /// cache; callers that need a fully empty state should ensure no loads
  /// are pending. Each distinct image instance is disposed once even if it
  /// was stored under multiple keys.
  static void clear() {
    for (final ui.Image image in _entries.values.toSet()) {
      image.dispose();
    }
    _entries.clear();
    _failed.clear();
  }
}
