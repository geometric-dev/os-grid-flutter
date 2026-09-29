import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_grid_flutter/src/rendering/rtl_geometry.dart';

void main() {
  const vw = 600.0;
  const leftWidth = 150.0;
  const rightWidth = 100.0;

  RtlGeometry ltr() => RtlGeometry.of(
    TextDirection.ltr,
    viewportWidth: vw,
    leadingWidth: leftWidth,
    trailingWidth: rightWidth,
  );

  RtlGeometry rtl() => RtlGeometry.of(
    TextDirection.rtl,
    viewportWidth: vw,
    leadingWidth: leftWidth,
    trailingWidth: rightWidth,
  );

  // Legacy LTR formulas (pre-item-48 painter/hit-test maths) that the
  // resolver must reproduce exactly under TextDirection.ltr.
  double legacyPinnedLtr(double sectionX, double offset) => sectionX + offset;
  double legacyCenterLtr(double offset, double scrollX) =>
      leftWidth + offset - scrollX;

  group('RtlGeometry — section anchors', () {
    test('LTR anchors leading pinned to the left edge', () {
      final g = ltr();
      expect(g.isRtl, isFalse);
      expect(g.leadingSectionX, 0.0);
      expect(g.trailingSectionX, vw - rightWidth);
      expect(g.centerViewportLeft, leftWidth);
      expect(g.centerViewportRight, vw - rightWidth);
      expect(g.leadingBorderX, leftWidth);
      expect(g.trailingBorderX, vw - rightWidth);
    });

    test('RTL anchors leading pinned to the right edge and swaps sides', () {
      final g = rtl();
      expect(g.isRtl, isTrue);
      expect(g.leadingSectionX, vw - leftWidth);
      expect(g.trailingSectionX, 0.0);
      expect(g.centerViewportLeft, rightWidth);
      expect(g.centerViewportRight, vw - leftWidth);
      expect(g.leadingBorderX, vw - leftWidth);
      expect(g.trailingBorderX, rightWidth);
    });

    test('null direction resolves as LTR', () {
      final g = RtlGeometry.of(
        null,
        viewportWidth: vw,
        leadingWidth: leftWidth,
        trailingWidth: rightWidth,
      );
      expect(g.isRtl, isFalse);
      expect(g.leadingSectionX, 0.0);
    });
  });

  group('RtlGeometry — pinnedX matches legacy accumulation under LTR', () {
    test('leading section', () {
      final g = ltr();
      expect(
        g.pinnedX(
          sectionX: g.leadingSectionX,
          sectionWidth: g.leadingWidth,
          offset: 150,
          width: 100,
        ),
        legacyPinnedLtr(0, 150),
      );
    });

    test('trailing section', () {
      final g = ltr();
      expect(
        g.pinnedX(
          sectionX: g.trailingSectionX,
          sectionWidth: g.trailingWidth,
          offset: 50,
          width: 50,
        ),
        legacyPinnedLtr(vw - rightWidth, 50),
      );
    });

    test('RTL mirrors the cell within its section (first column at right)', () {
      final g = rtl();
      // First leading-pinned cell (offset 0) hugs the viewport right edge.
      expect(
        g.pinnedX(
          sectionX: g.leadingSectionX,
          sectionWidth: g.leadingWidth,
          offset: 0,
          width: 150,
        ),
        vw - leftWidth,
      );
      // Second cell sits immediately to its left.
      expect(
        g.pinnedX(
          sectionX: g.leadingSectionX,
          sectionWidth: g.leadingWidth,
          offset: 150,
          width: 150,
        ),
        vw - 300,
      );
      // Trailing pinned first cell hugs the viewport left edge.
      expect(
        g.pinnedX(
          sectionX: g.trailingSectionX,
          sectionWidth: g.trailingWidth,
          offset: 0,
          width: 100,
        ),
        0.0,
      );
    });
  });

  group('RtlGeometry — centerX', () {
    test('LTR matches the legacy left + offset - scroll formula', () {
      final g = ltr();
      for (final scrollX in [0.0, 40.0, 120.5]) {
        expect(
          g.centerX(offset: 75, width: 150, scrollX: scrollX),
          legacyCenterLtr(75, scrollX),
        );
      }
    });

    test(
      'RTL anchors reading-order start at the center-section right edge',
      () {
        final g = rtl();
        // At scrollX 0 the first displayed column's RIGHT edge is flush with
        // the center viewport's right border (reading start).
        expect(
          g.centerX(offset: 0, width: 150, scrollX: 0),
          vw - leftWidth - 150,
        );
        // Scrolling advances content rightward (mirrored direction).
        expect(
          g.centerX(offset: 0, width: 150, scrollX: 50),
          vw - leftWidth - 100,
        );
        // Later reading-order columns sit progressively further left.
        expect(
          g.centerX(offset: 150, width: 150, scrollX: 0),
          vw - leftWidth - 300,
        );
      },
    );
  });

  group('RtlGeometry — mirrorInCell', () {
    test('LTR keeps the leading-edge offset', () {
      expect(
        ltr().mirrorInCell(
          cellLeft: 100,
          cellWidth: 80,
          leadingOffset: 12,
          elementWidth: 20,
        ),
        112,
      );
    });

    test('RTL mirrors the element to hug the trailing visual edge', () {
      expect(
        rtl().mirrorInCell(
          cellLeft: 100,
          cellWidth: 80,
          leadingOffset: 12,
          elementWidth: 20,
        ),
        100 + 80 - 12 - 20,
      );
    });
  });

  group('RtlGeometry — horizontal scrollbar thumb', () {
    test('LTR thumb position matches the legacy formula', () {
      final g = ltr();
      const trackLeft = 0.0;
      const trackWidth = 592.0;
      const thumbWidth = 60.0;
      expect(
        g.horizontalThumbLeft(
          trackLeft: trackLeft,
          trackWidth: trackWidth,
          thumbWidth: thumbWidth,
          scrollRatio: 0.25,
        ),
        trackLeft + 0.25 * (trackWidth - thumbWidth),
      );
    });

    test('RTL mirrors travel: ratio 0 at right end, 1 at left end', () {
      final g = rtl();
      const trackWidth = 592.0;
      const thumbWidth = 60.0;
      const travel = trackWidth - thumbWidth;
      expect(
        g.horizontalThumbLeft(
          trackLeft: 0,
          trackWidth: trackWidth,
          thumbWidth: thumbWidth,
          scrollRatio: 0,
        ),
        travel,
      );
      expect(
        g.horizontalThumbLeft(
          trackLeft: 0,
          trackWidth: trackWidth,
          thumbWidth: thumbWidth,
          scrollRatio: 1,
        ),
        0.0,
      );
    });

    test('scrollRatioAtTrackX reads track position in reading order', () {
      const trackWidth = 592.0;
      // LTR: ratio grows left→right.
      final gLtr = ltr();
      expect(
        gLtr.scrollRatioAtTrackX(trackLeft: 0, trackWidth: trackWidth, x: 0),
        0.0,
      );
      expect(
        gLtr.scrollRatioAtTrackX(
          trackLeft: 0,
          trackWidth: trackWidth,
          x: trackWidth,
        ),
        1.0,
      );
      expect(
        gLtr.scrollRatioAtTrackX(
          trackLeft: 0,
          trackWidth: trackWidth,
          x: trackWidth / 2,
        ),
        0.5,
      );
      // RTL: mirrored — ratio 1 at the left end, 0 at the right end.
      final gRtl = rtl();
      expect(
        gRtl.scrollRatioAtTrackX(trackLeft: 0, trackWidth: trackWidth, x: 0),
        1.0,
      );
      expect(
        gRtl.scrollRatioAtTrackX(
          trackLeft: 0,
          trackWidth: trackWidth,
          x: trackWidth,
        ),
        0.0,
      );
      expect(
        gRtl.scrollRatioAtTrackX(
          trackLeft: 0,
          trackWidth: trackWidth,
          x: trackWidth / 2,
        ),
        0.5,
      );
    });

    test('scrollRatioAtTrackX guards zero-width tracks', () {
      expect(ltr().scrollRatioAtTrackX(trackLeft: 0, trackWidth: 0, x: 5), 0.0);
    });
  });

  group('RtlGeometry — paint/hit-test parity invariant', () {
    // THE invariant of item 48: building the resolver from the same inputs
    // must yield identical x-mapping regardless of caller.
    test('same inputs produce identical geometry instances output', () {
      final a = RtlGeometry.of(
        TextDirection.rtl,
        viewportWidth: vw,
        leadingWidth: leftWidth,
        trailingWidth: rightWidth,
      );
      final b = RtlGeometry.of(
        TextDirection.rtl,
        viewportWidth: vw,
        leadingWidth: leftWidth,
        trailingWidth: rightWidth,
      );
      const offset = 90.0;
      const width = 45.0;
      const scrollX = 33.0;
      expect(
        a.centerX(offset: offset, width: width, scrollX: scrollX),
        b.centerX(offset: offset, width: width, scrollX: scrollX),
      );
      expect(a.leadingBorderX, b.leadingBorderX);
      expect(a.trailingSectionX, b.trailingSectionX);
    });
  });
}
