import 'dart:async';
import 'dart:convert';

import 'package:termlib/src/event_queue.dart';
import 'package:termlib/src/shared/terminal_overrides.dart';
import 'package:termlib/termlib.dart';
import 'package:termparser/termparser_events.dart';

import 'termlib_mock.dart';

Stream<List<int>> streamString(String value) {
  final buffer = value.replaceAll('π', '\x1b');
  return Stream.value(utf8.encode(buffer)).asBroadcastStream();
}

typedef AssertFunction = void Function(MockStdout stdout, MockStdin? stdin, TermOsMock termOsMock);

Future<void> mockedTest(
  AssertFunction fx, {
  MockStdout? stdout,
  MockStdin? stdin,
  TermOsMock? termOsMock,
  EnvironmentData? env,
}) async {
  final iStdout = stdout ?? MockStdout();
  final iStdin = stdin ?? MockStdin(streamString(''));
  final iTermOsMock = termOsMock ?? TermOsMock();

  await TerminalOverrides.runZoned(
    () async {
      fx(iStdout, iStdin, iTermOsMock);
    },
    stdout: iStdout,
    stdin: iStdin,
    termOs: iTermOsMock,
    environmentData: env,
  );
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
