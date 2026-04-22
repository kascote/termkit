import 'dart:async';
import 'dart:io' as dart_io;

import 'package:termparser/termparser_events.dart';

import '../event_queue.dart';
import '../ffi/termos.dart';
import 'term_sink.dart';

/// Platform-like environment map.
typedef EnvironmentData = Map<String, String>;

/// Transport seam between TermLib and the OS/terminal.
///
/// Holds every side-effectful surface termlib uses: stdin bytes, stdout sink,
/// environment map, raw-mode FFI, tty flag. Tests build fakes via
/// [TermBackend.fake]; production uses [TermBackend.io].
class TermBackend {
  TermBackend._({
    required this.stdin,
    required this.stdout,
    required this.env,
    required this.termOs,
    required this.hasTerminal,
    this.eventQueue,
    this.eventSource,
  });

  /// Raw byte stream from stdin. Must be a broadcast stream.
  final Stream<List<int>> stdin;

  /// Narrow output sink (see [TermSink]).
  final TermSink stdout;

  /// Environment variable map.
  final EnvironmentData env;

  /// OS-level raw-mode FFI.
  final TermOs termOs;

  /// True if stdin is a tty.
  final bool hasTerminal;

  /// Optional pre-built event queue. When set, TermLib uses this queue
  /// instead of creating a new one. For test injection.
  final EventQueue? eventQueue;

  /// Optional pre-parsed event stream. When set, TermLib subscribes to this
  /// instead of parsing [stdin] bytes. For test injection.
  final Stream<Event>? eventSource;

  /// Real backend: wraps `dart:io` stdin/stdout and `Platform.environment`.
  factory TermBackend.io({TermSink? stdout, TermOs? termOs}) {
    return TermBackend._(
      stdin: dart_io.stdin.asBroadcastStream(),
      stdout: stdout ?? TermSink.io(),
      env: dart_io.Platform.environment,
      termOs: termOs ?? TermOs(),
      hasTerminal: dart_io.stdin.hasTerminal,
    );
  }

  /// Test backend. All fields optional with sensible defaults.
  ///
  /// - [stdin]: bytes to feed the parser. Defaults to an empty broadcast stream.
  /// - [eventSource]: pre-parsed events, bypasses parser. Mutually useful with
  ///   or instead of [stdin] injection.
  /// - [eventQueue]: pre-built queue (useful to seed events before `TermLib` starts).
  factory TermBackend.fake({
    Stream<List<int>>? stdin,
    TermSink? stdout,
    EnvironmentData env = const {},
    TermOs? termOs,
    bool hasTerminal = true,
    EventQueue? eventQueue,
    Stream<Event>? eventSource,
  }) {
    // Normalize to Stream<List<int>> explicitly — `utf8.encode` returns
    // Uint8List, and Stream<Uint8List> is not a subtype of Stream<List<int>>
    // (generics are invariant). Without .cast(), the downstream .transform()
    // call fails at runtime with a StreamTransformer type mismatch.
    final raw = stdin ?? const Stream<List<int>>.empty();
    final typed = raw.cast<List<int>>();
    final bytes = typed.isBroadcast ? typed : typed.asBroadcastStream();
    return TermBackend._(
      stdin: bytes,
      stdout: stdout ?? TermSink.buffer(),
      env: env,
      termOs: termOs ?? TermOs(),
      hasTerminal: hasTerminal,
      eventQueue: eventQueue,
      eventSource: eventSource,
    );
  }
}
