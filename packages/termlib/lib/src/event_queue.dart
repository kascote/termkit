import 'dart:async';
import 'dart:collection';

import 'package:termparser/termparser_events.dart';

const _defaultQueueSize = 1000;

/// Internal event queue for interactive terminal mode.
///
/// Stores events in FIFO order with bounded capacity. When queue reaches
/// [maxSize], oldest events are dropped to prevent unbounded growth.
///
/// Note: Public for internal use only. Not exported in public API.
class EventQueue {
  final Queue<Event> _queue = Queue<Event>();
  final _eventNotifier = StreamController<void>.broadcast();

  /// Maximum queue capacity (default 1000)
  final int maxSize;

  /// Creates event queue with specified [maxSize]
  EventQueue({this.maxSize = _defaultQueueSize});

  /// Add event to queue. Drops oldest event if queue at capacity.
  /// Notifies waiters via [onEvent] stream.
  void enqueue(Event event) {
    if (_queue.length >= maxSize) {
      _queue.removeFirst();
    }
    _queue.add(event);
    _eventNotifier.add(null);
  }

  /// Signal stream for new event arrivals. Internal use only.
  Stream<void> get onEvent => _eventNotifier.stream;

  /// Find and remove first event matching type [T].
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

  /// Check if queue contains event of type [T]
  bool hasEvent<T extends Event>() => _queue.any((event) => event is T);

  /// Remove all events from queue
  void clear() => _queue.clear();

  /// Current queue length (for testing/debugging)
  int get length => _queue.length;

  /// Dispose resources. Call when done with queue.
  Future<void> dispose() async {
    await _eventNotifier.close();
    _queue.clear();
  }
}
