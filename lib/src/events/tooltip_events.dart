import '../tooltip/tooltip_params.dart';
import 'os_grid_event.dart';

/// Event emitted when a tooltip is shown.
///
/// ```dart
/// controller.onTooltipShow.listen((event) {
///   print('${event.location}: ${event.value}');
/// });
/// ```
class OsTooltipShowEvent extends OsGridEvent {
  const OsTooltipShowEvent({
    required this.value,
    required this.location,
    this.rowIndex,
    this.colId,
  });

  /// The tooltip text being displayed.
  final String value;

  /// Where the tooltip is being shown (cell, header, etc.).
  final TooltipLocation location;

  /// The row index (for cell tooltips).
  final int? rowIndex;

  /// The column ID (for cell and header tooltips).
  final String? colId;
}

/// Event emitted when a tooltip is hidden.
///
/// ```dart
/// controller.onTooltipHide.listen((event) {
///   print('tooltip hidden for ${event.colId}');
/// });
/// ```
class OsTooltipHideEvent extends OsGridEvent {
  const OsTooltipHideEvent({this.location, this.colId});

  /// Where the tooltip was shown (cell, header, etc.).
  final TooltipLocation? location;

  /// The column ID (for cell and header tooltips).
  final String? colId;
}
