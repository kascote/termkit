import 'dart:async';

import 'engine/engine.dart';
import 'engine/event_queue.dart';
import 'events/event_base.dart';
import 'events/raw_key_event.dart';

/// The ANSI escape sequence parser
///
/// This class implements the ANSI escape sequence parser allowing to parse
/// data coming from the terminal (stdin) and dispatching events based on the
/// input.
///
/// Data is fed to the parser using the [advance] method. Events can be
/// retrieved using [nextEvent], [peekEvent], or [drainEvents].
///
/// ```dart
///   final parser = Parser();
///   // ESC [ 20 ; 10 R
///   parser.advance([0x1B, 0x5B, 0x32, 0x30, 0x3B, 0x31, 0x30, 0x52]);
///   assert(parser.hasEvents, 'has events');
///   final event = parser.nextEvent();
///   assert(event == const CursorPositionEvent(20, 10), 'retrieve event');
/// ```
///
final class Parser {
  final Engine _engine;
  final EventQueue _queue;

  /// Creates a new parser instance.
  Parser() : _engine = Engine(), _queue = EventQueue();

  /// Advances parser state machine with additional input data.
  ///
  /// [buffer] - input data (stdin in raw mode, etc.)
  /// [hasMore] - more input data available right now
  void advance(List<int> buffer, {bool hasMore = false}) {
    for (var i = 0; i < buffer.length; i++) {
      _engine.advance(_queue, buffer[i], hasMore: i < buffer.length - 1 || hasMore);
    }
  }

  /// Whether the parser has pending events.
  bool get hasEvents => _queue.hasEvents;

  /// The number of pending events.
  int get eventCount => _queue.count;

  /// Retrieves and removes the next event from the queue.
  ///
  /// Returns `null` if there are no pending events.
  Event? nextEvent() => _queue.poll();

  /// Retrieves the next event without removing it from the queue.
  ///
  /// Returns `null` if there are no pending events.
  Event? peekEvent() => _queue.peek();

  /// Retrieves all pending events and clears the queue.
  ///
  /// Returns an empty list if there are no pending events.
  List<Event> drainEvents() => _queue.drain();
}

/// A stream transformer that converts a stream of bytes into a stream of events.
StreamTransformer<List<int>, T> eventTransformer<T extends Event>({bool rawKeys = false}) {
  final parser = Parser();

  return StreamTransformer<List<int>, T>.fromHandlers(
    handleData: (data, syncSink) {
      if (rawKeys) return syncSink.add(RawKeyEvent(data) as T);

      parser.advance(data);

      for (final event in parser.drainEvents()) {
        if (event is T) syncSink.add(event);
      }
    },
  );
}
