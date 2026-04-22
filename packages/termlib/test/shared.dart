import 'dart:async';
import 'dart:convert';

import 'package:termlib/src/event_queue.dart';
import 'package:termlib/termlib.dart';
import 'package:termparser/termparser_events.dart';

import 'termlib_mock.dart';

/// Byte stream literal helper. `π` → ESC (0x1b).
Stream<List<int>> streamString(String value) {
  final buffer = value.replaceAll('π', '\x1b');
  return Stream.value(utf8.encode(buffer)).asBroadcastStream();
}

/// Signature of a test body launched by [mockedTest]. Receives a pre-built
/// [TermLib], the captured stdout sink, and the raw-mode FFI mock.
typedef AssertFunction =
    FutureOr<void> Function(
      TermLib term,
      BufferTermSink stdout,
      TermOsMock termOsMock,
    );

/// Build a fake backend + [TermLib] and run [fx]. Pass bytes on [stdin],
/// pre-parsed events on [eventSource], or a pre-seeded queue on [eventQueue].
Future<void> mockedTest(
  AssertFunction fx, {
  Stream<List<int>>? stdin,
  BufferTermSink? stdout,
  TermOsMock? termOsMock,
  EnvironmentData env = const {},
  int columns = 80,
  int rows = 24,
  bool hasTerminal = true,
  ProfileEnum? profile,
  EventQueue? eventQueue,
  Stream<Event>? eventSource,
}) async {
  final iStdout = stdout ?? BufferTermSink(columns: columns, rows: rows, hasTerminal: hasTerminal);
  final iTermOsMock = termOsMock ?? TermOsMock();

  final backend = TermBackend.fake(
    stdin: stdin,
    stdout: iStdout,
    env: env,
    termOs: iTermOsMock,
    hasTerminal: hasTerminal,
    eventQueue: eventQueue,
    eventSource: eventSource,
  );

  final term = TermLib(backend: backend, profile: profile);
  await fx(term, iStdout, iTermOsMock);
}

/// Inject single event into event queue
void injectEvent(EventQueue queue, Event event) {
  queue.enqueue(event);
}

/// Inject multiple events into event queue
void injectEvents(EventQueue queue, List<Event> events) {
  events.forEach(queue.enqueue);
}

/// Create StreamController for event injection in tests
StreamController<Event> createEventController() {
  return StreamController<Event>.broadcast();
}
