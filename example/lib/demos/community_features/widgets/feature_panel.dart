import 'package:flutter/material.dart';

/// A reusable collapsible panel for interactive feature controls.
///
/// Renders as an [ExpansionTile]-based container that can be positioned above
/// or beside the grid on each demo page. Each page uses this to expose
/// toggles, sliders, and buttons for the demonstrated features.
class FeaturePanel extends StatefulWidget {
  const FeaturePanel({
    super.key,
    required this.children,
    this.title = 'Feature Controls',
    this.initiallyExpanded = true,
  });

  /// The interactive control widgets displayed inside the panel.
  final List<Widget> children;

  /// The title displayed in the panel header.
  final String title;

  /// Whether the panel starts in the expanded state.
  final bool initiallyExpanded;

  @override
  State<FeaturePanel> createState() => _FeaturePanelState();
}

class _FeaturePanelState extends State<FeaturePanel> {
  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: Text(widget.title),
      initiallyExpanded: widget.initiallyExpanded,
      childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: widget.children,
        ),
      ],
    );
  }
}
