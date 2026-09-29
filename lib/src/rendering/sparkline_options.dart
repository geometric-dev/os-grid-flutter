import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theming/os_grid_theme.dart';

/// Visual style of the built-in sparkline cell renderer.
enum OsSparklineType {
  /// Polyline through the data points (evenly spaced horizontally).
  line,

  /// Vertical bars measured from the baseline (0 when the range spans zero,
  /// otherwise the minimum value).
  bar,

  /// Line with a filled area between the line and the bottom of the plot.
  area,
}

/// Configuration for the built-in `OsBuiltInCellRenderer.sparkline` cell
/// renderer.
///
/// All colours are nullable and fall back to the active [OsGridTheme]:
/// [OsSparklineOptions.lineColor] → [OsGridTheme.accentColor],
/// [OsSparklineOptions.fillColor] → accent colour at low opacity and
/// [OsSparklineOptions.highlightColor] → [OsGridTheme.cellTextColor].
///
/// ```dart
/// OsColumnDef(
///   field: 'trend',
///   headerName: 'Trend',
///   width: 120,
///   builtInCellRenderer: OsBuiltInCellRenderer.sparkline,
///   sparklineOptions: const OsSparklineOptions(
///     type: OsSparklineType.area,
///     lineWidth: 2,
///   ),
/// )
/// ```
///
/// The cell value is expected to be a `List<num>` (ints and doubles can be
/// mixed). Non-numeric entries are ignored; an empty or missing list paints
/// nothing but keeps the cell borders.
///
/// Series much wider than the cell are downsampled before path construction
/// (see [lttbDecimate]): decimation preserves the visual shape because LTTB
/// selects the most visually important points — peaks and valleys survive
/// even at 100:1 reduction.
class OsSparklineOptions {
  /// Creates a sparkline configuration.
  ///
  /// All parameters are optional; defaults produce a thin accent-coloured
  /// line with 2 px of padding on all sides.
  const OsSparklineOptions({
    this.type = OsSparklineType.line,
    this.lineColor,
    this.fillColor,
    this.highlightColor,
    this.lineWidth = 1.5,
    this.paddingH = 2.0,
    this.paddingV = 2.0,
    this.minY,
    this.maxY,
    this.baseline,
  }) : assert(paddingH >= 0),
       assert(paddingV >= 0),
       assert(lineWidth > 0);

  /// Visual style of the sparkline.
  final OsSparklineType type;

  /// Colour of the polyline (and of bar strokes).
  ///
  /// Falls back to [OsGridTheme.accentColor] when null.
  final Color? lineColor;

  /// Fill colour used for the area under an [OsSparklineType.area] curve and
  /// for [OsSparklineType.bar] bars.
  ///
  /// Falls back to a low-opacity version of the theme accent colour when null.
  final Color? fillColor;

  /// Colour of the last-point marker dot.
  ///
  /// Falls back to [OsGridTheme.cellTextColor] when null.
  final Color? highlightColor;

  /// Stroke width of the polyline in logical pixels.
  final double lineWidth;

  /// Horizontal padding (left + right) inside the cell in logical pixels.
  final double paddingH;

  /// Vertical padding (top + bottom) inside the cell in logical pixels.
  final double paddingV;

  /// Fixed lower bound of the value axis. Derived from the data when null.
  final double? minY;

  /// Fixed upper bound of the value axis. Derived from the data when null.
  final double? maxY;

  /// Zero-line origin for [OsSparklineType.bar]. When null, 0 is used if the
  /// value range spans it, otherwise the bottom of the plot is used.
  final double? baseline;

  /// Extracts the numeric series from a raw cell value.
  ///
  /// Accepts any `List`; only `num` elements are kept (converted to
  /// [double]). Returns an empty list for null values or non-list values so
  /// callers can skip painting entirely.
  static List<double> extractData(Object? value) {
    if (value is! List) return const <double>[];
    return List<double>.unmodifiable(<double>[
      for (final Object? element in value)
        if (element is num) element.toDouble(),
    ]);
  }

  /// Resolves the effective value bounds for the series.
  ///
  /// Explicit [minY]/[maxY] win; otherwise the data extremes are used. A
  /// degenerate (empty or flat) series expands to a symmetric ±1 window so
  /// geometry never divides by zero.
  static (double, double) resolveMinMax(
    List<double> data, {
    double? minY,
    double? maxY,
  }) {
    if (data.isEmpty) return (0, 1);
    double lo = minY ?? data.reduce(math.min);
    double hi = maxY ?? data.reduce(math.max);
    if (lo >= hi) {
      lo -= 1;
      hi += 1;
    }
    return (lo, hi);
  }

  /// Resolves the baseline origin used by [OsSparklineType.bar].
  ///
  /// Precedence: explicit [baseline] → 0 (clamped into range when the range
  /// spans it) → the bottom of the range.
  double resolveBaseline(double min, double max) {
    final double resolved;
    if (baseline != null) {
      resolved = baseline!;
    } else if (min <= 0 && max >= 0) {
      resolved = 0;
    } else {
      resolved = min;
    }
    return resolved.clamp(min, max);
  }

  /// Pure geometry helper: maps [data] to cell-local offsets.
  ///
  /// Points are evenly spaced across `width - 2 * paddingH` and scaled
  /// vertically between `min` and `max` within `height - 2 * paddingV`.
  /// A single point is centred horizontally. Returned coordinates are relative
  /// to the top-left corner of the cell being painted.
  List<Offset> pointsFor(
    double width,
    double height,
    List<double> data,
    double min,
    double max,
  ) {
    final int n = data.length;
    if (n == 0) return const <Offset>[];
    final double innerW = math.max(0.0, width - paddingH * 2);
    final double innerH = math.max(0.0, height - paddingV * 2);
    final double range = max - min;
    Offset pointAt(int i) {
      final double x = paddingH + (n == 1 ? innerW / 2 : innerW * i / (n - 1));
      final double t = range <= 0 ? 0.5 : (data[i] - min) / range;
      final double y = paddingV + innerH * (1 - t);
      return Offset(x, y);
    }

    return List<Offset>.generate(n, pointAt);
  }

  /// Downsampling for wide sparkline series — the Largest-Triangle-Three-
  /// Bucket algorithm (LTTB, Sveinn Steinarsson) — quality program v3 item 43.
  ///
  /// Returns at most [targetPoints] values that preserve the visual shape of
  /// [data]: the first and last points are always kept, and each remaining
  /// slot takes, from one horizontal bucket of the source series, the point
  /// forming the largest triangle with the previously selected point and the
  /// next bucket's average point. That heuristic is what keeps peaks and
  /// valleys a human eye would notice. X positions are the list indices,
  /// matching the evenly spaced geometry of [pointsFor].
  ///
  /// The mapping is deterministic: identical [data] and [targetPoints]
  /// always produce an identical result (no randomness, strict `>` tie-break
  /// keeps the leftmost of equal-area candidates). A new list is returned
  /// when downsampling occurs; series no longer than [targetPoints] are
  /// returned as-is. Requests below 3 points cannot describe a shape and
  /// also return the series unchanged — the paint path clamps
  /// [targetPoints] to `4..500`, so this only guards direct callers.
  static List<double> lttbDecimate(List<double> data, int targetPoints) {
    final int n = data.length;
    if (n <= targetPoints || targetPoints < 3) return data;

    // Width of each source bucket. Bucket i (0-based, excluding the fixed
    // first point) spans indices [floor(i * bucketSize) + 1,
    // floor((i + 1) * bucketSize) + 1), so the final point is never a bucket
    // member — it is selected outright below.
    final double bucketSize = (n - 2) / (targetPoints - 2);
    final List<double> out = List<double>.filled(targetPoints, 0);
    out[0] = data[0];
    out[targetPoints - 1] = data[n - 1];

    int a = 0; // index of the previously selected point
    for (int i = 0; i < targetPoints - 2; i++) {
      // Average of the next bucket (the "c" triangle vertex). With the
      // `min(..., n)` clamp this range always covers at least one index; for
      // the final bucket it degenerates to the last point itself.
      final int avgStart = ((i + 1) * bucketSize).floor() + 1;
      final int avgEnd = math.min(((i + 2) * bucketSize).floor() + 1, n);
      double avgX = 0;
      double avgY = 0;
      for (int j = avgStart; j < avgEnd; j++) {
        avgX += j;
        avgY += data[j];
      }
      avgX /= avgEnd - avgStart;
      avgY /= avgEnd - avgStart;

      // Largest triangle between the previous point, this candidate and the
      // average point wins the bucket.
      final int rangeStart = (i * bucketSize).floor() + 1;
      final int rangeEnd = ((i + 1) * bucketSize).floor() + 1;
      final double aX = a.toDouble();
      final double aY = data[a];
      double maxArea = -1.0;
      int nextA = rangeStart;
      for (int j = rangeStart; j < rangeEnd; j++) {
        final double area =
            ((aX - avgX) * (data[j] - aY) - (aX - j) * (aY - avgY)).abs() * 0.5;
        if (area > maxArea) {
          maxArea = area;
          nextA = j;
        }
      }
      out[i + 1] = data[nextA];
      a = nextA;
    }
    return out;
  }

  /// Returns a copy with the given fields replaced (null keeps current value).
  OsSparklineOptions copyWith({
    OsSparklineType? type,
    Color? lineColor,
    Color? fillColor,
    Color? highlightColor,
    double? lineWidth,
    double? paddingH,
    double? paddingV,
    double? minY,
    double? maxY,
    double? baseline,
  }) {
    return OsSparklineOptions(
      type: type ?? this.type,
      lineColor: lineColor ?? this.lineColor,
      fillColor: fillColor ?? this.fillColor,
      highlightColor: highlightColor ?? this.highlightColor,
      lineWidth: lineWidth ?? this.lineWidth,
      paddingH: paddingH ?? this.paddingH,
      paddingV: paddingV ?? this.paddingV,
      minY: minY ?? this.minY,
      maxY: maxY ?? this.maxY,
      baseline: baseline ?? this.baseline,
    );
  }
}
