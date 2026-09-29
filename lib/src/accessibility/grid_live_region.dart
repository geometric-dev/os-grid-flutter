import 'package:flutter/material.dart';

import '../locale/os_locale_text.dart';

/// Lightweight semantics-only widget that announces grid model updates.
///
/// Mount it anywhere inside the grid's widget tree (e.g. beside the canvas in
/// the grid build method) with a [message] derived from the current model
/// state. The node is marked `liveRegion: true`, so whenever the message
/// changes — typically after an `onModelUpdated` cycle following a
/// transaction, filter, or sort — assistive technologies announce the new
/// text without moving focus.
///
/// Mechanism note: this uses a declarative `Semantics(liveRegion: true)` node
/// rather than pushing an `announce` semantics event through
/// `SystemChannels.accessibility`. The live-region node is testable with
/// plain widget tests (no platform-channel mocking), survives rebuilds, and
/// lets the engine coalesce announcements with semantics updates.
///
/// Build the localized message with [gridSummaryMessage] or
/// [rowsSelectedMessage]:
///
/// ```dart
/// GridLiveRegion(
///   message: gridSummaryMessage(
///     rowCount: controller.getDisplayedRowCount(),
///     selectedCount: controller.getSelectedRows().length,
///   ),
/// )
/// ```
class GridLiveRegion extends StatelessWidget {
  const GridLiveRegion({super.key, required this.message});

  /// The announcement text. Changing it triggers the live-region
  /// announcement; keeping it identical across rebuilds is silent.
  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: message,
      textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
      child: const SizedBox.shrink(),
    );
  }
}

/// Builds the localized post-update summary announced via [GridLiveRegion].
///
/// Resolves the `gridSummary` key and interpolates the literal tokens
/// `{rows}` and `{selected}` with [rowCount] and [selectedCount]. No plural
/// rules are applied — overrides needing pluralisation should provide fully
/// formatted strings per language upstream.
String gridSummaryMessage({
  required int rowCount,
  required int selectedCount,
  OsLocaleText localeText = OsLocaleText.defaultLocale,
}) {
  return localeText
      .getLocaleText('gridSummary', localeText.gridSummary)
      .replaceAll('{rows}', '$rowCount')
      .replaceAll('{selected}', '$selectedCount');
}

/// Builds a localized "N rows selected" announcement.
///
/// Resolves the `rowsSelected` key and interpolates the literal token `{n}`
/// with [count]. No plural rules are applied.
String rowsSelectedMessage({
  required int count,
  OsLocaleText localeText = OsLocaleText.defaultLocale,
}) {
  return localeText
      .getLocaleText('rowsSelected', localeText.rowsSelected)
      .replaceAll('{n}', '$count');
}
