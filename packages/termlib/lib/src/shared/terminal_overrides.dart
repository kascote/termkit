import 'dart:async';
import 'dart:io' as dart_io;

import 'package:termlib/src/event_queue.dart';
import 'package:termlib/src/ffi/termos.dart';
import 'package:termlib/termlib.dart';
import 'package:termparser/termparser_events.dart';

//
// ignore: specify_nonobvious_property_types
const _asyncRunZoned = runZoned;

/// Provides dependency injection for terminal I/O operations.
///
/// This class enables testing and custom terminal implementations by allowing
/// to override stdin, stdout, environment variables, and OS-level
/// terminal operations.
///
/// borrowed from https://github.com/felangel/mason/blob/master/packages/mason_logger/lib/src/terminal_overrides.dart
///
/// See also:
/// - [runZoned] for creating override contexts
/// - Test files in `test/` directory for examples
abstract class TerminalOverrides {
  static final _token = Object();

  ///
  static TerminalOverrides? get current {
    return Zone.current[_token] as TerminalOverrides?;
  }

  ///
  static R runZoned<R>(
    R Function() body, {
    TermOs? termOs,
    EnvironmentData? environmentData,
    dart_io.Stdout? stdout,
    dart_io.Stdin? stdin,
    EventQueue? eventQueue,
    bool? hasTerminal,
    StreamController<Event>? eventStream,
    Stream<Event>? events,
  }) {
    final overrides = _TerminalOverridesScope(
      termOs,
      environmentData,
      stdout,
      stdin,
      eventQueue,
      hasTerminal: hasTerminal,
      eventStream: eventStream,
      events: events,
    );
    return dart_io.IOOverrides.runZoned(
      () => _asyncRunZoned(body, zoneValues: {_token: overrides}),
      stdout: () => overrides.stdout,
      stdin: () => overrides.stdin,
    );
  }

  /// OS-level terminal operations
  TermOs get termOs => TermOs();

  /// Get Environment variables
  EnvironmentData get environmentData => dart_io.Platform.environment;

  /// Return the standard output stream
  dart_io.Stdout get stdout => dart_io.stdout;

  /// Return the standard input stream
  dart_io.Stdin get stdin => dart_io.stdin;

  /// Event queue for testing (zone-local override)
  EventQueue? get eventQueue => null;

  /// Terminal detection for testing (zone-local override)
  bool? get hasTerminal => null;

  /// Event stream for testing (zone-local override)
  StreamController<Event>? get eventStream => null;

  /// Events broadcast stream override for testing (zone-local override)
  ///
  /// When set, TermLib.events returns this stream instead of internal broadcast.
  /// Use for testing event subscribers without real terminal input.
  Stream<Event>? get events => null;
}

class _TerminalOverridesScope extends TerminalOverrides {
  _TerminalOverridesScope(
    this._termOs,
    this._environmentData,
    this._stdout,
    this._stdin,
    this._eventQueue, {
    required bool? hasTerminal,
    required StreamController<Event>? eventStream,
    required Stream<Event>? events,
  }) : _hasTerminal = hasTerminal,
       _eventStream = eventStream,
       _events = events;

  final TerminalOverrides? _previous = TerminalOverrides.current;
  final TermOs? _termOs;
  final EnvironmentData? _environmentData;
  final dart_io.Stdout? _stdout;
  final dart_io.Stdin? _stdin;
  final EventQueue? _eventQueue;
  final bool? _hasTerminal;
  final StreamController<Event>? _eventStream;
  final Stream<Event>? _events;

  @override
  TermOs get termOs => _termOs ?? _previous?.termOs ?? super.termOs;

  @override
  EnvironmentData get environmentData => _environmentData ?? _previous?.environmentData ?? super.environmentData;

  @override
  dart_io.Stdout get stdout => _stdout ?? _previous?.stdout ?? super.stdout;

  @override
  dart_io.Stdin get stdin => _stdin ?? _previous?.stdin ?? super.stdin;

  @override
  EventQueue? get eventQueue => _eventQueue ?? _previous?.eventQueue ?? super.eventQueue;

  @override
  bool? get hasTerminal => _hasTerminal ?? _previous?.hasTerminal ?? super.hasTerminal;

  @override
  StreamController<Event>? get eventStream => _eventStream ?? _previous?.eventStream ?? super.eventStream;

  @override
  Stream<Event>? get events => _events ?? _previous?.events ?? super.events;
}
