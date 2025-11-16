import 'dart:async';
import 'dart:convert';

import 'engine/engine.dart';
import 'engine/event_queue.dart';
import 'engine/sequence_data.dart';
import 'events/error_event.dart';
import 'events/event_base.dart';
import 'events/paste_event.dart';
import 'events/raw_key_event.dart';
import 'parsers/char_parser.dart';
import 'parsers/csi_parser.dart';
import 'parsers/dcs_parser.dart';
import 'parsers/esc_parser.dart';
import 'parsers/osc_parser.dart';

/// The ANSI escape sequence parser
///
/// This class implements the ANSI escape sequence parser allowing to parse
/// data coming from the terminal (stdin) and dispatching events based on the
/// input.
///
/// Translates SequenceData from the Engine into Events.
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
      final sequence = _engine.advance(buffer[i], hasMore: i < buffer.length - 1 || hasMore);
      if (sequence != null) {
        _handleSequence(sequence);
      }
    }
  }

  /// Translates SequenceData to Events and adds to queue.
  void _handleSequence(SequenceData sequence) {
    final event = switch (sequence) {
      CharData(:final char, :final escO) => parseChar(char, escO: escO),
      EscSequenceData(:final char) => parseESCSequence(char),
      CsiSequenceData(:final params, :final finalChar) => parseCSISequence(params, finalChar),
      OscSequenceData(:final params) => parseOscSequence(params, ''),
      DcsSequenceData(:final params, :final contentBytes) => parseDcsSequence(params, '', contentBytes),
      TextBlockSequenceData(:final contentBytes) => _handleTextBlock(contentBytes),
      ErrorSequenceData() => _handleError(sequence),
    };
    _queue.add(event);
  }

  /// Handles ErrorSequenceData and creates EngineErrorEvent.
  Event _handleError(ErrorSequenceData error) {
    return EngineErrorEvent(
      error.partialParameters,
      message: error.message,
      rawBytes: error.rawBytes,
      stateAtError: error.state,
    );
  }

  /// Handles TextBlockSequenceData (bracketed paste).
  Event _handleTextBlock(List<int> contentBytes) {
    final content = utf8.decode(contentBytes, allowMalformed: true);
    return PasteEvent(content);
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
