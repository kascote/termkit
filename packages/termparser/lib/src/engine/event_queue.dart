import '../events/event_base.dart';

/// Event queue for storing parsed terminal events.
///
/// Provides a simple queue interface for managing events produced by the
/// terminal parser. Events are processed in FIFO order.
class EventQueue {
  final List<Event> _events = [];

  /// Whether the queue has any pending events.
  bool get hasEvents => _events.isNotEmpty;

  /// The number of pending events in the queue.
  int get count => _events.length;

  /// Adds an event to the end of the queue.
  void add(Event event) => _events.add(event);

  /// Retrieves and removes the next event from the queue.
  ///
  /// Returns `null` if the queue is empty.
  Event? poll() {
    if (_events.isEmpty) return null;
    return _events.removeAt(0);
  }

  /// Retrieves the next event without removing it from the queue.
  ///
  /// Returns `null` if the queue is empty.
  Event? peek() {
    if (_events.isEmpty) return null;
    return _events.first;
  }

  /// Retrieves all events and clears the queue.
  ///
  /// Returns an empty list if the queue is empty.
  List<Event> drain() {
    final events = List<Event>.from(_events);
    _events.clear();
    return events;
  }
}
