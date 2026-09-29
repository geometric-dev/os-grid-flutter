import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../params/cell_renderer_params.dart';

/// How a decoded image is fitted into its cell.
///
/// Mirrors [BoxFit] semantics for the subset that makes sense inside a grid
/// cell.
enum OsImageFit {
  /// Scales the image uniformly until it fits entirely inside the cell
  /// (letterboxed), centred.
  contain,

  /// Scales the image uniformly until it covers the cell, cropping the
  /// overflow. Overflow is clipped to the cell (and the corner radius).
  cover,

  /// Stretches the image to exactly the cell's inner rect, ignoring the
  /// aspect ratio.
  fill,

  /// Natural image size, centred; shrinks with [OsImageFit.contain]
  /// semantics only when the image is larger than the cell.
  scaleDown,
}

/// Configuration for the built-in `OsBuiltInCellRenderer.image` cell
/// renderer.
///
/// The cell value can already be a decoded `ui.Image` (painted directly,
/// never cached or disposed by the grid), or any value resolved
/// asynchronously through [imageForCell]. Loader results are stored in
/// `ImageCellCache` (LRU, keyed per column + row-data identity); while a
/// load is in flight (or after it fails) a subtle placeholder rect is
/// painted instead.
///
/// ```dart
/// OsColumnDef(
///   field: 'avatarUrl',
///   headerName: 'Photo',
///   width: 56,
///   builtInCellRenderer: OsBuiltInCellRenderer.image,
///   imageOptions: OsImageOptions(
///     imageForCell: (params) => loadUserPhoto(params.value as String),
///     cornerRadius: 6,
///   ),
/// )
/// ```
///
/// The loader is invoked at most once per (column, row-data instance) until
/// the cache entry is evicted or `ImageCellCache.clear()` is called. Failed
/// loads are final for the session (no per-frame retry loops); clearing the
/// cache resets them. Images returned by the loader are owned by the cache
/// and disposed when `ImageCellCache.clear()` is called.
class OsImageOptions<TData> {
  /// Creates an image cell configuration.
  ///
  /// [cornerRadius] must be non-negative; padding values must be
  /// non-negative.
  const OsImageOptions({
    this.imageForCell,
    this.fit = OsImageFit.contain,
    this.cornerRadius = 0,
    this.paddingH = 3.0,
    this.paddingV = 3.0,
    this.placeholderColor,
  }) : assert(cornerRadius >= 0),
       assert(paddingH >= 0),
       assert(paddingV >= 0);

  /// Resolves the decoded image for a cell.
  ///
  /// Receives the standard cell renderer params (`value` is the raw cell
  /// value). Return null to paint only the placeholder. Failures thrown
  /// from this callback are treated like a null result (placeholder, no
  /// retry).
  ///
  /// Not used when the cell value itself is a `ui.Image`.
  final Future<ui.Image?> Function(CellRendererParams<TData> params)?
  imageForCell;

  /// How the image is fitted into the cell's inner rect.
  final OsImageFit fit;

  /// Corner radius applied to the painted image and placeholder.
  final double cornerRadius;

  /// Horizontal padding (left + right) inside the cell in logical pixels.
  final double paddingH;

  /// Vertical padding (top + bottom) inside the cell in logical pixels.
  final double paddingV;

  /// Colour of the placeholder painted while a load is in flight or after
  /// it failed. Falls back to the theme border colour at 35% opacity.
  final Color? placeholderColor;

  /// Computes the destination [Rect] inside [cell] for an image of
  /// [imageWidth] × [imageHeight] under [fit].
  ///
  /// Pure geometry helper (unit-testable): the result is always centred in
  /// [cell]; for [OsImageFit.cover] it may exceed [cell] (callers clip).
  static Rect resolveDestRect(
    Rect cell,
    double imageWidth,
    double imageHeight,
    OsImageFit fit,
  ) {
    if (imageWidth <= 0 || imageHeight <= 0) return cell;
    final double cellRatio = cell.width / cell.height;
    final double imageRatio = imageWidth / imageHeight;
    switch (fit) {
      case OsImageFit.fill:
        return cell;
      case OsImageFit.contain:
        final double scale = math.min(
          cell.width / imageWidth,
          cell.height / imageHeight,
        );
        return _centred(cell, imageWidth * scale, imageHeight * scale);
      case OsImageFit.cover:
        final double scale = math.max(
          cell.width / imageWidth,
          cell.height / imageHeight,
        );
        return _centred(cell, imageWidth * scale, imageHeight * scale);
      case OsImageFit.scaleDown:
        final bool fits = imageRatio <= cellRatio
            ? imageHeight <= cell.height
            : imageWidth <= cell.width;
        if (fits) return _centred(cell, imageWidth, imageHeight);
        final double scale = math.min(
          cell.width / imageWidth,
          cell.height / imageHeight,
        );
        return _centred(cell, imageWidth * scale, imageHeight * scale);
    }
  }

  static Rect _centred(Rect cell, double width, double height) {
    return Rect.fromLTWH(
      cell.left + (cell.width - width) / 2,
      cell.top + (cell.height - height) / 2,
      width,
      height,
    );
  }

  /// Returns a copy with the given fields replaced (null keeps current
  /// value).
  OsImageOptions<TData> copyWith({
    Future<ui.Image?> Function(CellRendererParams<TData> params)? imageForCell,
    OsImageFit? fit,
    double? cornerRadius,
    double? paddingH,
    double? paddingV,
    Color? placeholderColor,
  }) {
    return OsImageOptions<TData>(
      imageForCell: imageForCell ?? this.imageForCell,
      fit: fit ?? this.fit,
      cornerRadius: cornerRadius ?? this.cornerRadius,
      paddingH: paddingH ?? this.paddingH,
      paddingV: paddingV ?? this.paddingV,
      placeholderColor: placeholderColor ?? this.placeholderColor,
    );
  }
}
