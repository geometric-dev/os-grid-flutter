import 'package:flutter/material.dart';

import '../theming/os_grid_theme.dart';
import 'tooltip_service.dart';

/// A tooltip overlay widget that displays above the grid canvas.
///
/// Positioned relative to the anchor point (cell/header location) or
/// following the mouse when [TooltipService.mouseTrack] is enabled.
///
/// Styled using the grid's [OsGridTheme] with a dark background and
/// light text (or inverted for dark themes).
class TooltipOverlay extends StatelessWidget {
  const TooltipOverlay({
    super.key,
    required this.value,
    required this.position,
    required this.gridSize,
    this.theme,
  });

  /// The tooltip text to display.
  final String value;

  /// Position to anchor the tooltip (in grid-local coordinates).
  ///
  /// The tooltip is placed below this point with a small vertical offset.
  final Offset position;

  /// The total size of the grid widget (for boundary clamping).
  final Size gridSize;

  /// Theme for styling the tooltip.
  final OsGridTheme? theme;

  @override
  Widget build(BuildContext context) {
    // Tooltip styling — dark background with light text by default,
    // inverted for dark themes.
    final isDark =
        theme != null &&
        (theme!.backgroundColor?.computeLuminance() ?? 1.0) < 0.5;

    final bgColor = isDark ? const Color(0xFFF5F5F5) : const Color(0xFF1E1E1E);
    final textColor = isDark
        ? const Color(0xFF1E1E1E)
        : const Color(0xFFF5F5F5);
    final borderColor = isDark
        ? const Color(0xFFE0E0E0)
        : const Color(0xFF424242);

    // Measure text to determine tooltip width
    const maxWidth = 300.0;
    const padding = EdgeInsets.symmetric(horizontal: 8, vertical: 4);
    const verticalOffset = 18.0;

    // Calculate position: below the anchor, clamped to grid bounds
    var left = position.dx;
    var top = position.dy + verticalOffset;

    // Clamp to grid bounds (approximate — we don't know exact tooltip size
    // until layout, but we can prevent obvious overflow)
    if (left + maxWidth > gridSize.width) {
      left = gridSize.width - maxWidth - 4;
    }
    if (left < 4) left = 4;

    // If tooltip would go below the grid, show it above the anchor
    if (top + 40 > gridSize.height) {
      top = position.dy - 30;
    }

    return Positioned(
      left: left,
      top: top,
      child: IgnorePointer(
        child: Container(
          constraints: const BoxConstraints(maxWidth: maxWidth),
          padding: padding,
          decoration: BoxDecoration(
            color: bgColor,
            border: Border.all(color: borderColor, width: 0.5),
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF000000).withValues(alpha: 0.15),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            value,
            style: TextStyle(fontSize: 12, color: textColor, height: 1.3),
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}
