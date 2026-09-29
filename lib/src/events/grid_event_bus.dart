import 'dart:async';

/// Typed publish/subscribe bus for grid events.
///
/// Replaces 40+ individual StreamController fields with a single
/// type-indexed registry. Individual stream getters are retained as
/// derived views for backward compatibility.
///
/// Semantics:
/// - Every event type is backed by a broadcast controller, so any number
///   of listeners may subscribe simultaneously.
/// - No replay: a listener only receives events emitted after it has
///   subscribed.
/// - Delivery is asynchronous (scheduled in a microtask), matching plain
///   `StreamController.broadcast()` behaviour.
/// - [dispose] closes every controller the bus has created. The bus is
///   single-use; any use after disposal throws a [StateError].
///
/// The type parameter is unconstrained so that every event stream on
/// `OsGridController` — including non-`OsGridEvent` payloads such as
/// structured diagnostics — is backed by this single registry.
class GridEventBus {
  final Map<Type, StreamController<dynamic>> _controllers = {};

  bool _isClosed = false;

  /// Whether [dispose] has been called.
  bool get isClosed => _isClosed;

  /// The broadcast stream of events of type [T].
  ///
  /// May be called any number of times; every returned stream delivers
  /// the same event sequence, each with its own set of listeners.
  Stream<T> on<T>() {
    // ignore: close_sinks
    final controller = _controllerFor<T>();
    return controller.stream as Stream<T>;
  }

  /// Publishes [event] to every current listener of type [T].
  ///
  /// The type argument [T] must match the type used to subscribe via
  /// [on]. Emit methods pass the event's static type, which the getters
  /// mirror, so inference is always consistent.
  void emit<T>(T event) {
    _controllerFor<T>().add(event);
  }

  /// The underlying controller for [T], for the few internal call sites
  /// that push events directly instead of going through [emit].
  StreamController<T> controller<T>() {
    // ignore: close_sinks
    final controller = _controllerFor<T>();
    return controller as StreamController<T>;
  }

  /// Closes every controller created by this bus.
  ///
  /// Safe to call multiple times; subsequent calls return an already
  /// complete future.
  Future<void> dispose() {
    if (_isClosed) {
      return Future<void>.value();
    }
    _isClosed = true;
    final closing = _controllers.values.map((c) => c.close()).toList();
    return Future.wait(closing);
  }

  StreamController<dynamic> _controllerFor<T>() {
    if (_isClosed) {
      throw StateError('GridEventBus must not be used after dispose');
    }
    // Created with the concrete type argument so the reified stream type
    // matches the static type returned by [on] and [controller].
    return _controllers.putIfAbsent(T, () {
      return StreamController<T>.broadcast();
    });
  }
}
