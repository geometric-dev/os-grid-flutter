import 'package:flutter/painting.dart';
import 'package:flutter/scheduler.dart';

/// Reference font size used to compare [TextScaler] instances for cache-key
/// equality. For linear scalers the resolved value at any probe size fully
/// determines scaling; for accessibility scalers it is a close proxy.
const double _kScalerProbeFontSize = 16.0;

/// A cache key combining row index, column ID, display value, text style,
/// and text scaler.
///
/// Two keys are equal when all components match, meaning the TextPainter can
/// be reused without re-layout.
class _TextPainterCacheKey {
  const _TextPainterCacheKey({
    this.rowIndex,
    this.colId,
    required this.displayValue,
    required this.style,
    required this.textScaler,
    this.direction,
    this.overflow,
    this.color,
  });

  final int? rowIndex;
  final String? colId;
  final String displayValue;

  /// Resolved cell text style (compared by identity).
  final TextStyle? style;

  /// Active text scaler (compared by scaled value at the probe font size).
  final TextScaler textScaler;

  final TextDirection? direction;
  final TextOverflow? overflow;

  /// Per-paint text colour applied on top of [style], compared by value.
  ///
  /// Renderers that tint text per cell (e.g. the avatar's contrast-aware
  /// initials) pass the colour here instead of `style.copyWith(color: ...)`
  /// — a per-frame `copyWith` creates a fresh style instance, which never
  /// matches the identity-based [style] comparison and would defeat the
  /// cache entirely.
  final Color? color;

  bool _scalerEquals(TextScaler a, TextScaler b) =>
      identical(a, b) ||
      a.scale(_kScalerProbeFontSize) == b.scale(_kScalerProbeFontSize);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _TextPainterCacheKey &&
          rowIndex == other.rowIndex &&
          colId == other.colId &&
          displayValue == other.displayValue &&
          identical(style, other.style) &&
          _scalerEquals(textScaler, other.textScaler) &&
          direction == other.direction &&
          overflow == other.overflow &&
          color == other.color;

  @override
  int get hashCode => Object.hash(
    rowIndex,
    colId,
    displayValue,
    identityHashCode(style),
    textScaler.scale(_kScalerProbeFontSize),
    direction,
    overflow,
    color,
  );
}

/// LRU cache for [TextPainter] instances, keyed by (rowIndex, colId,
/// displayValue, style, textScaler) or generalised text styling.
class TextPainterCache {
  /// Creates a cache with the given [maxSize] (default 2000 entries).
  TextPainterCache({this.maxSize = 2000});

  /// Maximum number of entries before LRU eviction kicks in.
  final int maxSize;

  /// Internal storage: insertion-ordered map for LRU eviction.
  final Map<_TextPainterCacheKey, _CacheEntry> _cache = {};

  final List<TextPainter> _disposalQueue = [];
  bool _disposalScheduled = false;

  /// Counters for instrumentation/testing.
  int hits = 0;
  int misses = 0;

  /// Number of entries currently in the cache.
  int get length => _cache.length;

  /// Whether the cache is empty.
  bool get isEmpty => _cache.isEmpty;

  void _queueForDisposal(TextPainter painter) {
    _disposalQueue.add(painter);
    if (!_disposalScheduled) {
      _disposalScheduled = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _flushDisposalQueue();
      });
    }
  }

  void _flushDisposalQueue() {
    for (final painter in _disposalQueue) {
      painter.dispose();
    }
    _disposalQueue.clear();
    _disposalScheduled = false;
  }

  /// Retrieves a cached TextPainter for the given cell, or creates one using
  /// [create] if not found.
  TextPainter getOrCreate({
    required int rowIndex,
    required String colId,
    required String displayValue,
    required double maxWidth,
    required TextPainter Function() create,
    TextStyle? style,
    TextScaler textScaler = TextScaler.noScaling,
  }) {
    final key = _TextPainterCacheKey(
      rowIndex: rowIndex,
      colId: colId,
      displayValue: displayValue,
      style: style,
      textScaler: textScaler,
    );

    final existing = _cache[key];
    if (existing != null && (existing.maxWidth - maxWidth).abs() < 0.5) {
      // Move to end for LRU (remove and re-insert)
      _cache.remove(key);
      _cache[key] = existing;
      hits++;
      return existing.painter;
    }

    misses++;
    // Create new entry
    final painter = create();
    final entry = _CacheEntry(painter: painter, maxWidth: maxWidth);

    // Evict oldest entries if at capacity
    if (_cache.length >= maxSize) {
      _evict();
    }

    // If an entry exists for this key with a different maxWidth, queue
    // its old painter for disposal.
    final oldEntry = _cache[key];
    if (oldEntry != null) {
      _queueForDisposal(oldEntry.painter);
    }
    _cache[key] = entry;
    return painter;
  }

  /// Retrieves a laid-out [TextPainter] for generalised text parameters
  /// (e.g. for cell renderers like Avatar and Progress Bar).
  ///
  /// On cache miss, creates and lays out a new [TextPainter]. On cache hit,
  /// re-uses the existing painter, re-laying it out only when [maxWidth]
  /// differs from the width it was last laid out with.
  ///
  /// [color] tints the text on top of [style] without creating a new style
  /// instance: it participates in the cache key by value while [style]
  /// stays identity-compared, so per-cell colour variation (contrast-aware
  /// initials, status-coloured labels) still hits the cache as long as the
  /// base style instance is stable.
  TextPainter getPainter({
    required String text,
    required TextStyle style,
    Color? color,
    required TextDirection direction,
    required TextOverflow overflow,
    required TextScaler textScaler,
    required double maxWidth,
  }) {
    final key = _TextPainterCacheKey(
      displayValue: text,
      style: style,
      direction: direction,
      overflow: overflow,
      textScaler: textScaler,
      color: color,
    );

    _CacheEntry? entry = _cache[key];

    if (entry != null) {
      // Hit: Move to end (most recently used)
      _cache.remove(key);
      _cache[key] = entry;
      hits++;

      if (entry.maxWidth != maxWidth) {
        entry.painter.layout(maxWidth: maxWidth);
        entry.maxWidth = maxWidth;
      }
    } else {
      // Miss
      misses++;
      final effectiveStyle = color == null
          ? style
          : style.copyWith(color: color);
      final painter = TextPainter(
        text: TextSpan(text: text, style: effectiveStyle),
        textDirection: direction,
        maxLines: 1, // single-line cell renderers
        ellipsis: overflow == TextOverflow.ellipsis ? '\u2026' : null,
        textScaler: textScaler,
      );
      painter.layout(maxWidth: maxWidth);

      entry = _CacheEntry(painter: painter, maxWidth: maxWidth);
      _cache[key] = entry;

      if (_cache.length >= maxSize) {
        _evict();
      }
    }

    return entry.painter;
  }

  /// Clears the entire cache. Call on `setRowData()`, `applyTransaction()`,
  /// or theme changes.
  void clear() {
    for (final entry in _cache.values) {
      _queueForDisposal(entry.painter);
    }
    _cache.clear();
  }

  /// Clears all entries for a specific row. Call when a row is edited.
  void clearRow(int rowIndex) {
    _cache.removeWhere((key, entry) {
      if (key.rowIndex == rowIndex) {
        _queueForDisposal(entry.painter);
        return true;
      }
      return false;
    });
  }

  /// Clears all entries for a specific column. Call when column width changes
  /// (since the TextPainter needs re-layout with a new maxWidth).
  void clearColumn(String colId) {
    _cache.removeWhere((key, entry) {
      if (key.colId == colId) {
        _queueForDisposal(entry.painter);
        return true;
      }
      return false;
    });
  }

  /// Evicts the oldest ~10% of entries to make room for new ones.
  void _evict() {
    final evictCount = (maxSize * 0.1).ceil().clamp(1, _cache.length);
    final keysToRemove = _cache.keys.take(evictCount).toList();
    for (final key in keysToRemove) {
      final entry = _cache.remove(key);
      if (entry != null) {
        _queueForDisposal(entry.painter);
      }
    }
  }

  /// Disposes all cached TextPainters. Call when the cache is no longer needed.
  void dispose() {
    for (final entry in _cache.values) {
      entry.painter.dispose();
    }
    _cache.clear();
    _flushDisposalQueue();
  }
}

/// Internal cache entry storing the painter and the maxWidth it was laid out with.
class _CacheEntry {
  _CacheEntry({required this.painter, required this.maxWidth});

  final TextPainter painter;
  double maxWidth;
}
