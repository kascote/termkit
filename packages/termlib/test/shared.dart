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

/// Signature of an interactive-mode test body. Receives an [InteractiveTerm],
/// the captured stdout sink, and the raw-mode FFI mock.
typedef AssertFunction =
    FutureOr<void> Function(
      InteractiveTerm term,
      BufferTermSink stdout,
      TermOsMock termOsMock,
    );

/// Signature of a piped-mode test body. Receives a [PipedTerm].
typedef PipedAssertFunction =
    FutureOr<void> Function(
      PipedTerm term,
      BufferTermSink stdout,
      TermOsMock termOsMock,
    );

/// Build a fake backend + interactive [Term] and run [fx]. Requires
/// `hasTerminal: true` (the default); use [mockedPipedTest] for piped mode.
Future<void> mockedTest(
  AssertFunction fx, {
  Stream<List<int>>? stdin,
  BufferTermSink? stdout,
  TermOsMock? termOsMock,
  EnvironmentData env = const {},
  int columns = 80,
  int rows = 24,
  ProfileEnum? profile,
  EventQueue? eventQueue,
  Stream<Event>? eventSource,
}) async {
  final iStdout = stdout ?? BufferTermSink(columns: columns, rows: rows);
  final iTermOsMock = termOsMock ?? TermOsMock();

  final backend = TermBackend.fake(
    stdin: stdin,
    stdout: iStdout,
    env: env,
    termOs: iTermOsMock,
    eventQueue: eventQueue,
    eventSource: eventSource,
  );

  final term = Term.open(backend: backend, profile: profile);
  if (term is! InteractiveTerm) {
    throw StateError('mockedTest expected InteractiveTerm; use mockedPipedTest for piped mode.');
  }
  await fx(term, iStdout, iTermOsMock);
}

/// Build a fake backend in piped mode (`hasTerminal: false`) and run [fx].
Future<void> mockedPipedTest(
  PipedAssertFunction fx, {
  Stream<List<int>>? stdin,
  BufferTermSink? stdout,
  TermOsMock? termOsMock,
  EnvironmentData env = const {},
  int columns = 80,
  int rows = 24,
  ProfileEnum? profile,
}) async {
  final iStdout = stdout ?? BufferTermSink(columns: columns, rows: rows, hasTerminal: false);
  final iTermOsMock = termOsMock ?? TermOsMock();

  final backend = TermBackend.fake(
    stdin: stdin,
    stdout: iStdout,
    env: env,
    termOs: iTermOsMock,
    hasTerminal: false,
  );

  final term = Term.open(backend: backend, profile: profile);
  if (term is! PipedTerm) {
    throw StateError('mockedPipedTest expected PipedTerm.');
  }
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
