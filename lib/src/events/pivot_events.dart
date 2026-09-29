/// Event emitted when pivot mode is toggled on or off.
///
/// ```dart
/// controller.onPivotModeChanged.listen((event) {
///   print('pivot mode: ${event.pivotMode}');
/// });
/// ```
class OsPivotModeChangedEvent {
  const OsPivotModeChangedEvent({required this.pivotMode});

  /// Whether pivot mode is now active.
  final bool pivotMode;

  @override
  String toString() => 'OsPivotModeChangedEvent(pivotMode: $pivotMode)';
}
