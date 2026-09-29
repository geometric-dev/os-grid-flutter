import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../locale/os_locale_text.dart';

/// Describes the kind of popup hosted by [GridPopupSurface] so screen readers
/// can announce it with a localized role label.
///
/// Each role maps to an [OsLocaleText] key resolved when the popup opens.
/// For full control pass [GridPopupSurface.semanticsLabel] instead.
///
/// ```dart
/// GridPopupSurface(
///   anchorRect: cellRect,
///   popupWidth: 220,
///   estimatedHeight: 180,
///   contentBuilder: (_) => const Column(children: [Text('Menu')]),
///   popupRole: GridPopupRole.menu,
/// )
/// ```
enum GridPopupRole {
  /// A generic popup menu (context menu, column menu).
  menu('menu', 'Menu'),

  /// A filter popup.
  filter('filter', 'Filter'),

  /// A modal dialog-like surface.
  dialog('dialog', 'Dialog');

  const GridPopupRole(this.localeKey, this.fallbackLabel);

  /// The [OsLocaleText] key resolving this role's label.
  final String localeKey;

  /// English fallback used when the key is not recognised.
  final String fallbackLabel;
}

/// Hosts a transient popup's visible content in the nearest [Overlay] via an
/// [OverlayPortal], anchored to a rect expressed in the widget's own local
/// coordinate space.
///
/// The widget itself renders only an invisible anchor; all visible chrome is
/// built by [contentBuilder] into the overlay, so the popup can escape narrow
/// grid bounds while staying aligned with its anchor. An optional full-screen
/// barrier captures outside taps for dismissal.
///
/// Placement is clamped against the window (not the grid) so menus remain
/// usable on narrow layouts. When a below-anchor popup does not fit under its
/// anchor it flips above; the flip decision uses the measured content height
/// once the first frame has laid out the content (falling back to
/// [estimatedHeight] before that).
///
/// Must be placed below an [Overlay] ancestor (any `MaterialApp` provides
/// one).
///
/// ```dart
/// GridPopupSurface.belowAnchor(
///   anchorRect: headerRect,
///   gridSize: const Size(1200, 600),
///   popupWidth: 240,
///   estimatedHeight: 200,
///   contentBuilder: (context) => menuItems,
///   onBarrierTap: dismissMenu,
/// )
/// ```
class GridPopupSurface extends StatefulWidget {
  const GridPopupSurface({
    super.key,
    required this.anchorRect,
    required this.popupWidth,
    required this.estimatedHeight,
    required this.contentBuilder,
    this.anchorMode = PopupAnchorMode.belowAnchor,
    this.gridSize = Size.zero,
    this.gap = 2,
    this.showBarrier = true,
    this.onBarrierTap,
    this.useRootOverlay = false,
    this.maxHeightFactor = 0.85,
    this.popupRole,
    this.semanticsLabel,
    this.localeText = OsLocaleText.defaultLocale,
    this.blurSigma = 0,
  });

  /// Places the popup below (or above, when flipped) [anchorRect], aligned to
  /// the anchor's right edge — the classic menu placement.
  const GridPopupSurface.belowAnchor({
    Key? key,
    required Rect anchorRect,
    required Size gridSize,
    required double popupWidth,
    required double estimatedHeight,
    required WidgetBuilder contentBuilder,
    bool showBarrier = true,
    VoidCallback? onBarrierTap,
    bool useRootOverlay = false,
    double blurSigma = 0,
  }) : this(
         key: key,
         anchorRect: anchorRect,
         gridSize: gridSize,
         popupWidth: popupWidth,
         estimatedHeight: estimatedHeight,
         contentBuilder: contentBuilder,
         anchorMode: PopupAnchorMode.belowAnchor,
         showBarrier: showBarrier,
         onBarrierTap: onBarrierTap,
         useRootOverlay: useRootOverlay,
         blurSigma: blurSigma,
       );

  /// Places the popup with its top-left at this widget's own top-left. Use
  /// when the parent already positioned this widget at the desired origin
  /// (e.g. filter popups anchored by a `Positioned`).
  const GridPopupSurface.atOrigin({
    Key? key,
    required double popupWidth,
    required double estimatedHeight,
    required WidgetBuilder contentBuilder,
    bool showBarrier = false,
    bool useRootOverlay = false,
    double blurSigma = 0,
  }) : this(
         key: key,
         anchorRect: Rect.zero,
         popupWidth: popupWidth,
         estimatedHeight: estimatedHeight,
         contentBuilder: contentBuilder,
         anchorMode: PopupAnchorMode.atOrigin,
         showBarrier: showBarrier,
         useRootOverlay: useRootOverlay,
         blurSigma: blurSigma,
       );

  /// Anchor rect in grid-local coordinates ([PopupAnchorMode.belowAnchor]) or
  /// ignored ([PopupAnchorMode.atOrigin]).
  final Rect anchorRect;

  /// Size of the surrounding grid area, used for the legacy in-grid clamp and
  /// flip pass that runs before the global window-aware correction.
  final Size gridSize;

  /// Fixed popup width in logical pixels.
  final double popupWidth;

  /// Height estimate used before the real content height has been measured.
  final double estimatedHeight;

  /// Builds the visible panel content (including any `Material` wrapper).
  final WidgetBuilder contentBuilder;

  /// How [anchorRect] maps onto this widget's own coordinate space.
  final PopupAnchorMode anchorMode;

  /// Vertical gap between the anchor edge and the popup edge.
  final double gap;

  /// Whether a full-screen tap-capturing barrier sits behind the popup.
  final bool showBarrier;

  /// Called when the barrier is tapped (outside-tap dismissal).
  final VoidCallback? onBarrierTap;

  /// Whether the overlay child goes to the root overlay instead of the
  /// nearest one.
  final bool useRootOverlay;

  /// Maximum popup height as a fraction of the window height.
  final double maxHeightFactor;

  /// Kind of popup, used to resolve a localized role label for the scoped
  /// [Semantics] wrapper around the popup content (item: popups lack scoped
  /// semantics). When null and [semanticsLabel] is also null, no wrapper is
  /// added and behaviour is unchanged from before the parameter existed.
  final GridPopupRole? popupRole;

  /// Explicit semantics label overriding the [popupRole]-derived one
  /// (e.g. "Filter on Name"). Takes precedence over the role label.
  final String? semanticsLabel;

  /// Locale used to resolve [GridPopupRole] labels.
  final OsLocaleText localeText;

  /// Gaussian blur sigma for a full-screen backdrop installed beneath the
  /// popup content. 0 (default) renders no blur layer at all. Applied via a
  /// non-hit-testable [BackdropFilter], independent of [showBarrier], so
  /// barrier-less popups (filter/date-picker) blur too.
  final double blurSigma;

  /// Resolves the label for the popup's semantics wrapper, or null when no
  /// wrapper should be added.
  String? get _resolvedSemanticsLabel {
    if (semanticsLabel != null) return semanticsLabel;
    final role = popupRole;
    if (role == null) return null;
    return localeText.getLocaleText(role.localeKey, role.fallbackLabel);
  }

  @override
  State<GridPopupSurface> createState() => _GridPopupSurfaceState();
}

/// How the anchor rect relates to the host widget's own box.
///
/// ```dart
/// GridPopupSurface(
///   anchorRect: Rect.zero,
///   anchorMode: PopupAnchorMode.atOrigin,
///   // ...
/// )
/// ```
enum PopupAnchorMode {
  /// Anchor is expressed in the host box's coordinates (host covers grid).
  belowAnchor,

  /// Anchor at the host box's own top-left (parent already positioned us).
  atOrigin,
}

class _GridPopupSurfaceState extends State<GridPopupSurface> {
  final OverlayPortalController _controller = OverlayPortalController();
  final LayerLink _link = LayerLink();
  final GlobalKey _contentKey = GlobalKey();

  static const _screenMargin = 8.0;

  Offset? _globalOrigin;
  double? _measuredHeight;

  @override
  void initState() {
    super.initState();
    // Safe before attach: the portal picks up the flag when first mounted.
    _controller.show();
    WidgetsBinding.instance.addPostFrameCallback((_) => _afterFrame());
  }

  @override
  void didUpdateWidget(covariant GridPopupSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _afterFrame());
  }

  void _afterFrame() {
    if (!mounted) return;
    var changed = false;

    final box = context.findRenderObject();
    if (box is RenderBox && box.hasSize) {
      final origin = box.localToGlobal(Offset.zero);
      if (_globalOrigin != origin) {
        _globalOrigin = origin;
        changed = true;
      }
    }

    final contentContext = _contentKey.currentContext;
    if (contentContext != null) {
      final contentBox = contentContext.findRenderObject();
      if (contentBox is RenderBox && contentBox.hasSize) {
        final measured = contentBox.size.height;
        if (_measuredHeight == null ||
            (measured - _measuredHeight!).abs() > 0.5) {
          _measuredHeight = measured;
          changed = true;
        }
      }
    }

    if (changed) setState(() {});
  }

  /// Computes the target-box position inside our own coordinate space.
  ///
  /// Pass 1 replicates the legacy in-grid maths (clamp/flip within
  /// [GridPopupSurface.gridSize]); pass 2 corrects against the window using
  /// the last known global origin so popups escape narrow grids without
  /// leaving the screen.
  Offset _computeTargetLocal(Size size) {
    final mode = widget.anchorMode;
    final anchor = widget.anchorRect;
    final gap = widget.gap;

    // --- Pass 1: legacy grid-local placement -------------------------------
    var left = 0.0;
    var top = 0.0;
    if (mode == PopupAnchorMode.belowAnchor) {
      final gridW = widget.gridSize.width;
      left = (anchor.right - size.width).clamp(
        0.0,
        (gridW - size.width).clamp(0.0, double.infinity),
      );
      top = anchor.bottom + gap;
      if (top + size.height > widget.gridSize.height &&
          widget.gridSize.height > 0) {
        final flippedUpper = math.max(0.0, widget.gridSize.height - 50);
        final flipped = (anchor.top - gap - size.height)
            .clamp(0.0, flippedUpper)
            .clamp(0.0, top);
        top = flipped;
      }
      top = top.clamp(0.0, double.infinity);
    }

    // --- Pass 2: window-aware correction -----------------------------------
    final origin = _globalOrigin;
    if (origin != null) {
      final screen = MediaQuery.sizeOf(context);
      final maxX = (screen.width - size.width - _screenMargin).clamp(
        _screenMargin,
        double.infinity,
      );

      final globalLeft = (origin.dx + left).clamp(_screenMargin, maxX);

      final maxBottom = screen.height - _screenMargin;
      var globalTop = origin.dy + top;
      if (globalTop + size.height > maxBottom) {
        // Prefer flipping above the anchor when there is more room there.
        final aboveTop = mode == PopupAnchorMode.belowAnchor
            ? origin.dy + anchor.top - gap - size.height
            : origin.dy - size.height - gap * 4;
        if (aboveTop >= _screenMargin && aboveTop + size.height <= origin.dy) {
          globalTop = aboveTop;
        } else {
          globalTop = globalTop.clamp(_screenMargin, maxBottom);
        }
      }

      final newLeft = globalLeft - origin.dx;
      top = globalTop - origin.dy;
      left = newLeft;
    }

    return Offset(left, top);
  }

  @override
  Widget build(BuildContext context) {
    final height = _measuredHeight ?? widget.estimatedHeight;
    final size = Size(widget.popupWidth, height);
    final targetLocal = _computeTargetLocal(size);

    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        // Invisible anchor target placed where the popup belongs.
        Positioned(
          left: targetLocal.dx,
          top: targetLocal.dy,
          width: size.width,
          height: size.height,
          child: CompositedTransformTarget(
            link: _link,
            child: const SizedBox.shrink(),
          ),
        ),
        OverlayPortal(
          controller: _controller,
          overlayLocation: widget.useRootOverlay
              ? OverlayChildLocation.rootOverlay
              : OverlayChildLocation.nearestOverlay,
          overlayChildBuilder: (overlayContext) {
            final maxHeight =
                MediaQuery.sizeOf(overlayContext).height *
                widget.maxHeightFactor;
            final semanticsLabel = widget._resolvedSemanticsLabel;
            return Stack(
              textDirection: TextDirection.ltr,
              children: [
                if (widget.blurSigma > 0)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(
                          sigmaX: widget.blurSigma,
                          sigmaY: widget.blurSigma,
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                if (widget.showBarrier)
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: widget.onBarrierTap,
                      child: const SizedBox.expand(),
                    ),
                  ),
                CompositedTransformFollower(
                  link: _link,
                  targetAnchor: Alignment.topLeft,
                  followerAnchor: Alignment.topLeft,
                  showWhenUnlinked: false,
                  child: KeyedSubtree(
                    key: _contentKey,
                    child: SizedBox(
                      width: widget.popupWidth,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxHeight: maxHeight),
                        child: semanticsLabel == null
                            ? widget.contentBuilder(overlayContext)
                            : Semantics(
                                container: true,
                                scopesRoute: true,
                                explicitChildNodes: true,
                                label: semanticsLabel,
                                textDirection:
                                    Directionality.maybeOf(overlayContext) ??
                                    TextDirection.ltr,
                                child: widget.contentBuilder(overlayContext),
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
