import 'dart:async';
import 'dart:collection';

import 'package:termparser/termparser_events.dart';

const _defaultQueueSize = 1000;

/// Thrown from pending `awaitEvent` futures when the queue is disposed.
class TermDisposed implements Exception {
  /// Const constructor for the disposal marker exception.
  const TermDisposed();
  @override
  String toString() => 'TermDisposed: event queue disposed while awaiting event';
}

/// Internal event queue for interactive terminal mode.
///
/// Stores events in FIFO order with bounded capacity. When queue reaches
/// [maxSize], oldest events are dropped to prevent unbounded growth.
///
/// Supports per-waiter signalling: `awaitEvent<T>` registers a typed waiter;
/// the next `enqueue` of a matching event hands the event directly to the
/// waiter (bypassing the buffer). No match → the event is buffered.
///
/// Note: Public for internal use only. Not exported in public API.
class EventQueue {
  final Queue<Event> _queue = Queue<Event>();
  final List<_Waiter<Event>> _waiters = [];
  bool _disposed = false;

  /// Maximum queue capacity (default 1000)
  final int maxSize;

  /// Creates event queue with specified [maxSize]
  EventQueue({this.maxSize = _defaultQueueSize});

  /// Add event to queue. If a registered waiter matches the event's type,
  /// the waiter is completed directly and the event is not buffered. Else
  /// the event is appended; oldest events are dropped when at capacity.
  void enqueue(Event event) {
    if (_disposed) return;
    for (var i = 0; i < _waiters.length; i++) {
      final w = _waiters[i];
      if (w.matches(event)) {
        _waiters.removeAt(i);
        w.deliver(event);
        return;
      }
    }
    if (_queue.length >= maxSize) {
      _queue.removeFirst();
    }
    _queue.add(event);
  }

  /// Find and remove first buffered event matching type [T].
  ///
  /// Returns null if no matching event found.
  /// If T is Event (base type), returns first event regardless of subtype.
  Event? dequeue<T extends Event>() {
    final iterator = _queue.iterator;
    while (iterator.moveNext()) {
      final event = iterator.current;
      if (event is T) {
        _queue.remove(event);
        return event;
      }
    }
    return null;
  }

  /// Wait for the next event of type [T].
  ///
  /// Fast path: if a matching event is already buffered, return it immediately.
  /// Otherwise register a waiter and return a Future that completes when
  /// [enqueue] receives a matching event, the optional [timeout] elapses
  /// (returns null), or the queue is disposed (throws [TermDisposed]).
  Future<T?> awaitEvent<T extends Event>({Duration? timeout}) {
    if (_disposed) {
      return Future<T?>.error(const TermDisposed());
    }
    final buffered = dequeue<T>();
    if (buffered != null) return Future<T?>.value(buffered as T);

    final waiter = _Waiter<T>();
    _waiters.add(waiter);

    if (timeout != null) {
      return waiter.future.timeout(
        timeout,
        onTimeout: () {
          _waiters.remove(waiter);
          return null;
        },
      );
    }
    return waiter.future;
  }

  /// Check if queue contains event of type [T]
  bool hasEvent<T extends Event>() => _queue.any((event) => event is T);

  /// Remove all events from queue
  void clear() => _queue.clear();

  /// Current queue length (for testing/debugging)
  int get length => _queue.length;

  /// Dispose resources. Pending `awaitEvent` futures complete with
  /// [TermDisposed]. Call when done with the queue.
  Future<void> dispose() async {
    _disposed = true;
    for (final w in _waiters) {
      w.disposeWith(const TermDisposed());
    }
    _waiters.clear();
    _queue.clear();
  }
}

class _Waiter<T extends Event> {
  final Completer<T?> _completer = Completer<T?>();

  bool matches(Event e) => e is T;

  Future<T?> get future => _completer.future;

  void deliver(Event e) {
    if (!_completer.isCompleted) _completer.complete(e as T);
  }

  void disposeWith(Object error) {
    if (!_completer.isCompleted) _completer.completeError(error);
  }
}
