import 'package:flutter/material.dart';

/// Shared UI kit for the community-features showcase.
///
/// One source of truth for the demo chrome so every page presents the same
/// controls: [DemoToggle] (labelled switch), [DemoActionButton]
/// (standardised action button) and [DemoControlBar] (the surface above
/// the grid that hosts them).

/// A labelled switch, used for every boolean demo option.
class DemoToggle extends StatelessWidget {
  const DemoToggle({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label),
        const SizedBox(width: 4),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}

/// Standardised action button for demo toolbars (tonal + icon).
class DemoActionButton extends StatelessWidget {
  const DemoActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

/// The control surface above a demo grid: a bordered, padded bar that
/// wraps its children, with a subtle bottom separator.
class DemoControlBar extends StatelessWidget {
  const DemoControlBar({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      child: Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        width: double.infinity,
        child: Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: children,
        ),
      ),
    );
  }
}
