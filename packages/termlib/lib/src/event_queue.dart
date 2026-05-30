import 'dart:async';
import 'dart:collection';

import 'package:meta/meta.dart';
import 'package:termparser/termparser_events.dart';

const _defaultQueueSize = 5000;

/// Thrown from pending `awaitEvent` futures when the queue is disposed.
class TermDisposed implements Exception {
  /// Const constructor for the disposal marker exception.
  const TermDisposed();
  @override
  String toString() => 'TermDisposed: event queue disposed while awaiting event';
}

/// Thrown when an interactive-only API is called on a piped terminal.
///
/// Most call sites are now compile-time prevented by the `InteractiveTerm` /
/// `PipedTerm` split, but this exception remains for the few runtime-checked
/// surfaces (e.g. `TermRunner.build()`).
class TerminalNotInteractive implements Exception {
  /// Optional human-readable context.
  final String? message;

  /// Const constructor.
  const TerminalNotInteractive([this.message]);

  @override
  String toString() => message == null ? 'TerminalNotInteractive: requires a tty' : 'TerminalNotInteractive: $message';
}

/// Emitted on the broadcast `events` stream when the queue evicts events
/// under drop-oldest pressure. Rate-limited: between successive `dequeue`
/// calls all evictions are coalesced into a single `QueueOverflowEvent`
/// carrying the total [dropped] count and the [type] of the last evicted
/// event.
///
/// Push-only consumers (`events.listen`) observe this directly. Pull-only
/// consumers should subscribe to `events` separately if they care.
final class QueueOverflowEvent extends Event {
  /// Runtime type of the most recently evicted event in this batch.
  final Type type;

  /// Number of events dropped since the previous `QueueOverflowEvent` (or
  /// since the queue started, whichever is more recent).
  final int dropped;

  /// Const constructor.
  const QueueOverflowEvent({required this.type, required this.dropped});

  @override
  String toString() => 'QueueOverflowEvent(type: $type, dropped: $dropped)';
}

/// Internal event queue for interactive terminal mode.
///
/// FIFO with bounded capacity ([maxSize], default 5000). Drop-oldest on
/// overflow; drops are coalesced and reported via [onOverflow] on the next
/// [dequeue] call.
///
/// Two side-paths reduce buffering pressure:
///   * Per-waiter direct hand-off: an `awaitEvent<T>` waiter receives the
///     next matching event without it ever entering the queue.
///   * Coalesce-at-enqueue (when [coalesceMotion] is true): consecutive
///     `MouseEvent` motion samples sharing button-state, and consecutive
///     `WindowResizeEvent`s, replace the previous tail rather than appending.
///
/// Note: Public for internal use only. Not exported in public API.
@internal
class EventQueue {
  final Queue<Event> _queue = Queue<Event>();
  final List<_Waiter<Event>> _waiters = [];
  bool _disposed = false;
  int _pendingDrops = 0;
  Type? _lastDroppedType;

  /// Maximum queue capacity (default 5000).
  final int maxSize;

  /// When true, consecutive `MouseEvent` motion samples (same button-state)
  /// and consecutive `WindowResizeEvent`s collapse to the latest at enqueue.
  /// Defaults to true.
  final bool coalesceMotion;

  /// Invoked from [dequeue] when at least one event has been dropped since
  /// the previous call. Receives `(lastDroppedType, droppedCount)`.
  /// Wiring lives in `InteractiveTerm` (forwards to the events broadcast).
  final void Function(Type type, int dropped)? onOverflow;

  /// Creates an event queue.
  EventQueue({
    this.maxSize = _defaultQueueSize,
    this.coalesceMotion = true,
    this.onOverflow,
  });

  /// Add an event.
  ///
  /// Order: waiter hand-off → coalesce → drop-oldest → append.
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
    if (coalesceMotion && _queue.isNotEmpty) {
      final last = _queue.last;
      if (event is MouseEvent && last is MouseEvent && _coalesceMouse(event, last)) {
        _queue
          ..removeLast()
          ..add(event);
        return;
      }
      if (event is WindowResizeEvent && last is WindowResizeEvent) {
        _queue
          ..removeLast()
          ..add(event);
        return;
      }
    }
    if (_queue.length >= maxSize) {
      final dropped = _queue.removeFirst();
      _pendingDrops++;
      _lastDroppedType = dropped.runtimeType;
    }
    _queue.add(event);
  }

  /// Find and remove the first buffered event matching type [T].
  ///
  /// Returns null if no matching event is found. With `T == Event`, returns
  /// the first event regardless of subtype.
  ///
  /// Performance: O(n) scan over the queue. Acceptable because (a) the
  /// per-waiter hand-off keeps the queue empty whenever a consumer is
  /// actively waiting, (b) `coalesceMotion` collapses the two highest-rate
  /// event types so single-type buildup is unrealistic, and (c) the typical
  /// queue depth in interactive use is tens, not thousands. Worst-case
  /// 5000-element scan is ~50–200µs in Dart — cheaper than a per-type
  /// hash-of-queues alloc.
  // TODO(perf): revisit if profiling shows scan time, or if a real bug
  // demonstrates queue-fill under coalesce. See PLAN.md Phase 3.
  T? dequeue<T extends Event>() {
    _flushPendingOverflow();
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
  /// Fast path: if a matching event is already buffered, return it
  /// immediately. Otherwise register a waiter; the future completes when
  /// [enqueue] receives a matching event, the optional [timeout] elapses
  /// (returns null), or the queue is disposed (throws [TermDisposed]).
  Future<T?> awaitEvent<T extends Event>({Duration? timeout}) {
    if (_disposed) {
      return Future<T?>.error(const TermDisposed());
    }
    final buffered = dequeue<T>();
    if (buffered != null) return Future<T?>.value(buffered);

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

  /// True if any buffered event matches type [T].
  bool hasEvent<T extends Event>() => _queue.any((event) => event is T);

  /// Remove all buffered events.
  void clear() => _queue.clear();

  /// Current buffered length (for testing / diagnostics).
  int get length => _queue.length;

  /// Dispose. Pending `awaitEvent` futures complete with [TermDisposed].
  Future<void> dispose() async {
    _disposed = true;
    for (final w in _waiters) {
      w.disposeWith(const TermDisposed());
    }
    _waiters.clear();
    _queue.clear();
  }

  void _flushPendingOverflow() {
    if (_pendingDrops == 0 || onOverflow == null) return;
    final type = _lastDroppedType ?? Event;
    final count = _pendingDrops;
    _pendingDrops = 0;
    _lastDroppedType = null;
    onOverflow!(type, count);
  }

  bool _coalesceMouse(MouseEvent next, MouseEvent prev) {
    final action = next.button.action;
    if (action != MouseButtonAction.moved && action != MouseButtonAction.drag) return false;
    return prev.button.action == action && prev.button.button == next.button.button && prev.modifiers == next.modifiers;
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
