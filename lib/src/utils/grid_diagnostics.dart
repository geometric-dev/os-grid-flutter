import 'package:flutter/foundation.dart';

import 'grid_error.dart';

/// Signature for callbacks that receive structured [GridDiagnostic]s.
///
/// Typically registered by an `OsGridController` so warnings raised
/// anywhere in grid internals are forwarded onto its `onDiagnostic`
/// stream.
typedef GridDiagnosticListener = void Function(GridDiagnostic diagnostic);

/// Centralised debug-mode diagnostics for OS Grid internals.
///
/// Provides a single choke point for warning messages emitted from
/// defensive catch sites (value getters, comparators, aggregation
/// callbacks) and configuration validation so failures are observable in
/// debug builds without flooding the console.
///
/// - Debug builds: emits `[OS Grid] <message>` via `debugPrint`, at most
///   once per unique key per process lifetime, and forwards the same
///   event as a [GridDiagnostic] to every registered listener (a
///   controller re-emits these on its `onDiagnostic` stream).
/// - Release builds: a complete no-op (zero cost beyond the call).
abstract final class GridDiagnostics {
  /// Keys already warned about during this process lifetime.
  static final Set<String> _warnedKeys = <String>{};

  /// Registered diagnostic sinks. Iterated over a copy on emit so
  /// listeners may unregister synchronously from within a callback.
  static final Set<GridDiagnosticListener> _listeners =
      <GridDiagnosticListener>{};

  /// Registers [listener] to receive every subsequently emitted
  /// [GridDiagnostic].
  ///
  /// Listeners are typically controllers; pair with [removeListener] in
  /// dispose.
  static void addListener(GridDiagnosticListener listener) {
    _listeners.add(listener);
  }

  /// Unregisters [listener]; no-op if it is not currently registered.
  static void removeListener(GridDiagnosticListener listener) {
    _listeners.remove(listener);
  }

  /// Emits [message] for the given [code], at most once per unique
  /// [key].
  ///
  /// This is the preferred, typed entry point: the diagnostic is printed
  /// with the `[OS Grid] ` prefix and forwarded to all listeners as a
  /// [GridDiagnostic] carrying [code].
  ///
  /// [key] identifies the diagnostic site (e.g. `'sort:comparator'`) so
  /// repeated failures at the same site log once while distinct sites
  /// still report independently.
  static void warn(GridErrorCode code, String key, String message) {
    if (!kDebugMode) return;
    if (!_warnedKeys.add(key)) return;
    debugPrint('[OS Grid] $message');
    emit(GridDiagnostic(code: code, message: message, key: key));
  }

  /// Emits [message], at most once per unique [key], mapping [key] to a
  /// [GridErrorCode] for structured reporting.
  ///
  /// Legacy string-keyed entry point retained for existing call sites;
  /// new sites should prefer [warn] with an explicit code. Keys that do
  /// not match a known site map to [GridErrorCode.unspecified].
  static void warnOnce(String key, String message) {
    warn(_codeForKey(key), key, message);
  }

  /// Forwards [diagnostic] to all registered listeners.
  @visibleForTesting
  static void emit(GridDiagnostic diagnostic) {
    if (_listeners.isEmpty) return;
    for (final listener in List.of(_listeners)) {
      listener(diagnostic);
    }
  }

  /// Resolves legacy string keys to their structured codes.
  static GridErrorCode _codeForKey(String key) {
    // Dynamic per-site prefixes (suffix varies per column/type name).
    if (key.startsWith('validation:duplicateColIds')) {
      return GridErrorCode.duplicateColId;
    }
    if (key.startsWith('columnType:')) return GridErrorCode.unknownColumnType;
    if (key.startsWith('nofield:')) return GridErrorCode.missingFieldOrGetter;

    // Fixed sites.
    switch (key) {
      case 'sort:comparator':
      case 'pivot:comparator':
        return GridErrorCode.invalidComparator;
      case 'aggregation:valueGetter':
      case 'pivot:valueGetter':
      case 'statusBar:valueGetter':
      case 'rowGroup:groupKey':
        return GridErrorCode.valueGetterThrew;
      case 'aggregation:aggFunc':
        return GridErrorCode.aggFuncThrew;
    }
    return GridErrorCode.unspecified;
  }

  /// Clears the once-per-key memory so tests can exercise [warnOnce]
  /// repeatedly for the same keys.
  @visibleForTesting
  static void resetWarnedKeys() => _warnedKeys.clear();

  /// Clears all registered listeners so tests start from a clean slate.
  @visibleForTesting
  static void resetListeners() => _listeners.clear();
}
