import 'package:flutter/painting.dart';

/// Shared directional X-geometry resolver (quality program v2 item 48).
///
/// Single source of truth mapping content-order column offsets to on-screen
/// X positions for BOTH painting and hit-testing, so visuals and pointer
/// interaction can never disagree under RTL directionality.
///
/// Content order is always reading order: index 0 is the first displayed
/// column, which sits at the visual left edge under LTR and at the visual
/// right edge under RTL. Pinned sections swap sides: leading-pinned columns
/// (`leftCols`) anchor to the right edge and trailing-pinned columns
/// (`rightCols`) anchor to the left edge when [isRtl] is true.
///
/// `scrollX` keeps its existing convention — distance from the reading-order
/// start of the center section — so all scroll clamping and
/// ensure-column-visible maths stays direction-independent; only this
/// resolver interprets it visually.
class RtlGeometry {
  const RtlGeometry({
    required this.isRtl,
    required this.viewportWidth,
    required this.leadingWidth,
    required this.trailingWidth,
  });

  /// Builds the resolver from the ambient reading direction (`null` = LTR),
  /// the grid viewport width, and the total widths of the two pinned
  /// sections in content order.
  factory RtlGeometry.of(
    TextDirection? direction, {
    required double viewportWidth,
    required double leadingWidth,
    required double trailingWidth,
  }) {
    return RtlGeometry(
      isRtl: direction == TextDirection.rtl,
      viewportWidth: viewportWidth,
      leadingWidth: leadingWidth,
      trailingWidth: trailingWidth,
    );
  }

  /// Whether the reading direction is right-to-left.
  final bool isRtl;

  /// Total width of the grid viewport (all three sections).
  final double viewportWidth;

  /// Total width of the leading pinned section in content order (`leftCols`).
  final double leadingWidth;

  /// Total width of the trailing pinned section in content order
  /// (`rightCols`).
  final double trailingWidth;

  /// Visual left edge of the leading pinned section.
  ///
  /// Under LTR this is 0; under RTL the section anchors to the right edge.
  double get leadingSectionX => isRtl ? viewportWidth - leadingWidth : 0.0;

  /// Visual left edge of the trailing pinned section.
  ///
  /// Under LTR this is `viewportWidth - trailingWidth`; under RTL it anchors
  /// to the left edge.
  double get trailingSectionX => isRtl ? 0.0 : viewportWidth - trailingWidth;

  /// Visual left edge of the center (scrollable) viewport.
  double get centerViewportLeft => isRtl ? trailingWidth : leadingWidth;

  /// Visible width of the center (scrollable) viewport.
  double get centerViewportWidth =>
      viewportWidth - leadingWidth - trailingWidth;

  /// Visual right edge of the center (scrollable) viewport.
  double get centerViewportRight => centerViewportLeft + centerViewportWidth;

  /// Visual X of the border between the leading pinned section and the
  /// center section.
  double get leadingBorderX =>
      isRtl ? leadingSectionX : leadingSectionX + leadingWidth;

  /// Visual X of the border between the center section and the trailing
  /// pinned section.
  double get trailingBorderX =>
      isRtl ? trailingSectionX + trailingWidth : trailingSectionX;

  /// Visual left edge of a cell occupying content range
  /// `[offset, offset + width)` inside a FIXED (non-scrolling) section whose
  /// visual anchor is [sectionX] and whose total width is [sectionWidth].
  ///
  /// Use [leadingSectionX]/[trailingSectionX] for the two pinned sections.
  double pinnedX({
    required double sectionX,
    required double sectionWidth,
    required double offset,
    required double width,
  }) {
    return isRtl ? sectionX + sectionWidth - offset - width : sectionX + offset;
  }

  /// Visual left edge of a cell occupying content range
  /// `[offset, offset + width)` inside the scrolling center section given
  /// the current horizontal scroll offset.
  double centerX({
    required double offset,
    required double width,
    required double scrollX,
  }) {
    return isRtl
        ? centerViewportRight - offset - width + scrollX
        : centerViewportLeft + offset - scrollX;
  }

  /// Mirrors a cell-local element anchored to the cell's LEADING edge.
  ///
  /// [leadingOffset] is the distance from the cell's left edge to the
  /// element's left edge under LTR; under RTL the same distance is measured
  /// from the right edge instead, so the element hugs the visual edge that
  /// matches the reading direction.
  double mirrorInCell({
    required double cellLeft,
    required double cellWidth,
    required double leadingOffset,
    required double elementWidth,
  }) {
    return isRtl
        ? cellLeft + cellWidth - leadingOffset - elementWidth
        : cellLeft + leadingOffset;
  }

  /// Visual left edge of the horizontal scrollbar thumb for the current
  /// scroll ratio (0 = reading-order start, 1 = end).
  ///
  /// The track spans `[trackLeft, trackLeft + trackWidth]`; only the thumb's
  /// position mirrors with direction.
  double horizontalThumbLeft({
    required double trackLeft,
    required double trackWidth,
    required double thumbWidth,
    required double scrollRatio,
  }) {
    final travel = trackWidth - thumbWidth;
    return isRtl
        ? trackLeft + travel - scrollRatio * travel
        : trackLeft + scrollRatio * travel;
  }

  /// Scroll ratio (0..1) implied by a pointer [x] on the horizontal
  /// scrollbar track — the inverse of [horizontalThumbLeft] for track taps,
  /// used by both directions so jump-to-position matches the painted thumb.
  double scrollRatioAtTrackX({
    required double trackLeft,
    required double trackWidth,
    required double x,
  }) {
    if (trackWidth <= 0) return 0.0;
    final ratio = ((x - trackLeft) / trackWidth).clamp(0.0, 1.0);
    return isRtl ? 1.0 - ratio : ratio;
  }
}
