import 'dart:async';
import 'dart:io' show exit, stderr;

import 'package:termparser/termparser.dart';
import 'package:termparser/termparser_events.dart';

import './colors.dart';
import './event_queue.dart';
import './extensions/cursor.dart';
import './extensions/term.dart';
import './probe/probe.dart';
import './probe/term_info.dart';
import './readline.dart';
import './shared/color_util.dart';
import './shared/term_backend.dart';
import './style.dart';

export './event_queue.dart' show QueueOverflowEvent, TermDisposed, TerminalNotInteractive;
export './shared/term_backend.dart' show EnvironmentData, TermBackend;
export './shared/term_sink.dart' show BufferTermSink, TermSink;

/// Record that represent a coordinate position
typedef Pos = ({int row, int col});

/// Enumeration representing different profiles.
enum ProfileEnum {
  /// Represents a no color profile.
  noColor,

  /// Represents an ANSI 16 color.
  ansi16,

  /// Represents an ANSI 256 color.
  ansi256,

  /// Represents an RGB color.
  trueColor,
}

const _defaultColumns = 80;
const _defaultRows = 25;

/// Terminal handle. Use [Term.open] to construct.
///
/// At runtime the returned instance is either [InteractiveTerm] (stdin is a
/// tty — events, raw mode, queries) or [PipedTerm] (stdin is piped — raw
/// byte stream only). Dispatch via pattern matching:
///
/// ```dart
/// final term = Term.open();
/// switch (term) {
///   case InteractiveTerm(): /* events / poll / raw mode */
///   case PipedTerm():       /* stdinBytes */
/// }
/// ```
sealed class Term {
  Term._(TermBackend backend, ProfileEnum? profile) : _b = backend {
    this.profile = profile ?? envColorProfile();
  }

  final TermBackend _b;

  /// The current terminal profile to use.
  late ProfileEnum profile;

  /// Open a terminal. Returns [InteractiveTerm] when
  /// `backend.hasTerminal == true`, else [PipedTerm].
  ///
  /// [backend] defaults to [TermBackend.io] (real stdin/stdout). Tests pass
  /// [TermBackend.fake] to inject stdin bytes, capture stdout, and control
  /// tty / env / termOs.
  factory Term.open({TermBackend? backend, ProfileEnum? profile}) {
    final b = backend ?? TermBackend.io();
    if (b.hasTerminal) return InteractiveTerm._(b, profile);
    return PipedTerm._(b, profile);
  }

  /// Underlying transport. Exposed for tests that need to seed the event queue
  /// or inspect captured stdout.
  TermBackend get backend => _b;

  /// True if stdout is connected to an interactive terminal.
  bool get hasOutputTerminal => _b.stdout.hasTerminal;

  /// Returns a [Style] object for the current profile.
  Style style([String content = '']) => Style(content, profile: profile);

  /// Write the object's string representation to stdout.
  void write(Object s) => _b.stdout.write(s);

  /// Write the object's string representation followed by a newline.
  void writeln(Object s) => _b.stdout.write('$s$_newLine');

  /// Newline sequence. Plain `\n` on [Term]; overridden in [InteractiveTerm]
  /// to respect raw mode.
  String get _newLine => '\n';

  /// EnvNoColor returns true if the terminal should not emit colors based on
  /// the environment. `NO_COLOR` wins; `CLICOLOR=="0"` requires `CLICOLOR_FORCE`
  /// to flip back on. Piped stdout also forces no-color.
  bool envNoColor() {
    if (_b.env.containsKey('NO_COLOR')) return true;
    if (_b.env['CLICOLOR'] != null || isColorForced) return false;
    return !hasOutputTerminal;
  }

  /// True if `CLICOLOR_FORCE` is set in the environment.
  bool get isColorForced => _b.env['CLICOLOR_FORCE'] != null;

  /// Resolve the color profile from environment variables.
  ProfileEnum envColorProfile() {
    if (envNoColor()) return ProfileEnum.noColor;
    final cp = colorProfile();
    if (isColorForced && cp == ProfileEnum.noColor) {
      return ProfileEnum.ansi16;
    }
    return cp;
  }

  /// Width of the terminal in characters. Falls back to `COLUMNS` or 80.
  int get terminalColumns {
    final envCols = int.tryParse(_b.env['COLUMNS'] ?? '');
    if (hasOutputTerminal) {
      return envCols ?? (_b.stdout.terminalColumns == 0 ? _defaultColumns : _b.stdout.terminalColumns);
    }
    return envCols ?? _defaultColumns;
  }

  /// Height of the terminal in rows. Falls back to `LINES` or 25.
  int get terminalLines {
    final envRows = int.tryParse(_b.env['LINES'] ?? '');
    if (hasOutputTerminal) {
      return envRows ?? (_b.stdout.terminalLines == 0 ? _defaultRows : _b.stdout.terminalLines);
    }
    return envRows ?? _defaultRows;
  }

  /// Flush stdout and stderr, then exit with [status]. Never returns.
  Future<void> flushThenExit(int status) {
    return Future.wait<void>([_b.stdout.close(), stderr.close()]).then<void>((_) => exit(status));
  }

  /// Dispose resources. Subclasses override to cancel event plumbing.
  Future<void> dispose() async {}

  /// Resolve the color profile from `TERM`/`COLORTERM` without checking
  /// `NO_COLOR`/`CLICOLOR_FORCE`.
  ProfileEnum colorProfile() {
    if (!hasOutputTerminal) return ProfileEnum.noColor;

    if (_b.env['GOOGLE_CLOUD_SHELL'] == 'true') {
      return ProfileEnum.trueColor;
    }

    final envTerm = _b.env['TERM'] ?? '';

    switch (_b.env['COLORTERM']) {
      case 'truecolor':
      case '24bit':
        return ProfileEnum.trueColor;
      case '256color':
      case 'yes':
      case 'true':
        return ProfileEnum.ansi256;
    }

    switch (envTerm) {
      case 'kitty':
      case 'xterm-kitty':
      case 'wezterm':
      case 'alacritty':
      case 'contour':
        return ProfileEnum.trueColor;
      case 'linux':
        return ProfileEnum.ansi16;
    }

    if (envTerm.contains('256color')) return ProfileEnum.ansi256;
    if (envTerm.contains('color')) return ProfileEnum.ansi16;
    if (envTerm.contains('ansi')) return ProfileEnum.ansi16;

    return ProfileEnum.noColor;
  }

  final _fgIdx = 0;
  final _bgIdx = 1;

  Color? _parseFGBG(int fgbg) {
    assert(fgbg == _fgIdx || fgbg == _bgIdx, 'fgbg must be 0 or 1');

    final envColorFgBg = _b.env['COLORFGBG'];
    if (envColorFgBg == null) return null;

    final colors = envColorFgBg.split(';');
    if ((colors.length > 2) || (fgbg > colors.length - 1)) return null;

    final colorFg = colors[fgbg].trim();
    final color = int.tryParse(colorFg);
    return color != null ? Color.ansi(color) : null;
  }
}

/// Terminal handle for interactive (tty) input.
///
/// Owns a background parser subscription that feeds both an [EventQueue]
/// (pull API: [tryEvent], [awaitEvent], [nextEvent]) and a broadcast
/// [events] stream (push API). Also holds raw-mode state.
final class InteractiveTerm extends Term {
  InteractiveTerm._(TermBackend b, ProfileEnum? profile) : super._(b, profile) {
    _eventBroadcastController = StreamController<Event>.broadcast();
    if (b.eventQueue != null) {
      _eventQueue = b.eventQueue;
      if (b.eventSource != null) {
        _eventSubscription = b.eventSource!.listen(_onEventParsed);
      }
    } else {
      _eventQueue = EventQueue(
        maxSize: b.maxQueueSize,
        coalesceMotion: b.coalesceMotion,
        onOverflow: _emitOverflow,
      );
      if (b.eventSource != null) {
        _eventSubscription = b.eventSource!.listen(_onEventParsed);
      } else {
        _eventSubscription = b.stdin.transform(eventTransformer()).listen(_onEventParsed, onError: _onParserError);
      }
    }
  }

  bool _isRawMode = false;
  EventQueue? _eventQueue;
  StreamSubscription<Event>? _eventSubscription;
  StreamController<Event>? _eventBroadcastController;

  /// Always `true` for [InteractiveTerm]. Retained for ergonomic parity with
  /// [hasOutputTerminal] and for conditional logic in code that holds a [Term].
  bool get hasTerminal => true;

  /// True if both stdin and stdout are ttys.
  bool get isFullyInteractive => hasOutputTerminal;

  /// Enables raw mode.
  ///
  /// Raw mode is useful for console applications like text editors. When
  /// enabled, `\n` does not also perform `\r`; use [writeln] or [newLine].
  void enableRawMode() => _setRawMode(true);

  /// Disables raw mode.
  void disableRawMode() => _setRawMode(false);

  /// Newline sequence honoring raw-mode state (`\r\n` in raw mode, else `\n`).
  String get newLine => _isRawMode ? '\r\n' : '\n';

  @override
  String get _newLine => newLine;

  @override
  void writeln(Object s) {
    var text = s.toString();
    if (_isRawMode) {
      text = text.replaceAll('\n', '\r\n');
    }
    _b.stdout.write('$text$newLine');
  }

  /// True if the background is dark (luminance < [factor]). Null if
  /// background color cannot be determined.
  Future<bool?> isBackgroundDark({double factor = 0.5}) async {
    final color = await backgroundColor;
    if (color == null) return null;
    final bgColor = color.convert(ColorKind.rgb);
    return colorLuminance(bgColor) < factor;
  }

  /// Read cursor position on the terminal. Returns null if unavailable.
  Future<Pos?> get cursorPosition async {
    final position = await queryCursorPosition();
    return position != null ? (row: position.x, col: position.y) : null;
  }

  /// Terminal foreground color. OSC 10 first, then `COLORFGBG`.
  Future<Color?> get foregroundColor async {
    final result = await queryOSCStatus(10);
    return result ?? _parseFGBG(_fgIdx);
  }

  /// Terminal background color. OSC 11 first, then `COLORFGBG`.
  Future<Color?> get backgroundColor async {
    final result = await queryOSCStatus(11);
    return result ?? _parseFGBG(_bgIdx);
  }

  /// Poll for an event of type [T] without blocking.
  ///
  /// Returns the first buffered event matching [T], or null if none.
  T? tryEvent<T extends Event>() => _eventQueue!.dequeue<T>();

  /// Wait for an event of type [T], up to [timeout].
  ///
  /// Returns null on timeout. With [timeout] unset, waits forever (prefer
  /// [nextEvent] in that case for the non-null return type).
  Future<T?> awaitEvent<T extends Event>({Duration? timeout}) {
    return _eventQueue!.awaitEvent<T>(timeout: timeout);
  }

  /// Wait indefinitely for the next event of type [T].
  ///
  /// Completes only when a matching event arrives. Throws [TermDisposed] if
  /// the terminal is disposed while waiting.
  Future<T> nextEvent<T extends Event>() async {
    final event = await _eventQueue!.awaitEvent<T>();
    // awaitEvent without a timeout only returns null on dispose (which throws),
    // or never — so the bang is safe.
    return event!;
  }

  /// Broadcast stream of parsed events. Multiple subscribers supported.
  ///
  /// Also carries [QueueOverflowEvent] when the buffered queue evicts events
  /// under drop-oldest pressure.
  Stream<Event> get events => _eventBroadcastController!.stream;

  /// Current buffered length of the internal event queue. Read-only diagnostic.
  int get queueLength => _eventQueue?.length ?? 0;

  /// Run [fn] with raw mode enabled, restoring prior state on return.
  T withRawMode<T>(T Function() fn) {
    final original = _setRawMode(true);
    try {
      return fn();
    } finally {
      _setRawMode(original);
    }
  }

  /// Async variant of [withRawMode].
  Future<T> withRawModeAsync<T>(Future<T> Function() fn) async {
    final original = _setRawMode(true);
    return fn().whenComplete(() => _setRawMode(original));
  }

  /// Read a line from the terminal with basic editing. Returns null on ESC.
  Future<String?> readLine([String initBuffer = '']) async {
    return (await Readline.create(this, initBuffer)).read();
  }

  /// Probe terminal capabilities.
  Future<TermInfo> probe({
    Set<ProbeQuery> skip = const {},
    int timeout = 500,
  }) => probeTerminal(this, skip: skip, timeout: timeout);

  /// Dispose event plumbing. Pending [awaitEvent]/[nextEvent] futures
  /// complete with [TermDisposed].
  @override
  Future<void> dispose() async {
    await _eventSubscription?.cancel();
    await _eventQueue?.dispose();
    await _eventBroadcastController?.close();
    _eventQueue = null;
    _eventSubscription = null;
    _eventBroadcastController = null;
  }

  void _onEventParsed(Event event) {
    _eventQueue!.enqueue(event);
    _eventBroadcastController?.add(event);
  }

  void _onParserError(Object error, StackTrace stack) {
    _onEventParsed(EngineErrorEvent(const [], message: error.toString()));
  }

  void _emitOverflow(Type type, int dropped) {
    _eventBroadcastController?.add(QueueOverflowEvent(type: type, dropped: dropped));
  }

  bool _setRawMode(bool value) {
    final original = _isRawMode;
    _isRawMode = value;
    if (value) {
      _b.termOs.enableRawMode();
    } else {
      _b.termOs.disableRawMode();
    }
    return original;
  }
}

/// Terminal handle for piped / redirected stdin.
///
/// Exposes [stdinBytes] for composition with `utf8.decoder` and
/// `LineSplitter`. Cannot produce parsed events — use [Term.open] on a tty
/// for that.
final class PipedTerm extends Term {
  PipedTerm._(super.backend, super.profile) : super._();

  /// Always `false` for [PipedTerm].
  bool get hasTerminal => false;

  /// Raw byte stream from stdin. Compose with `utf8.decoder` and `LineSplitter`
  /// for line-by-line processing.
  ///
  /// ```dart
  /// await for (final line in term.stdinBytes
  ///     .transform(utf8.decoder)
  ///     .transform(LineSplitter())) {
  ///   processLine(line);
  /// }
  /// ```
  Stream<List<int>> get stdinBytes => _b.stdin;
}
