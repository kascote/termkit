import 'dart:async';
import 'dart:io' show exit, stderr;

import 'package:termansi/termansi.dart' as ansi;
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

/// Terminal library.
class TermLib {
  final TermBackend _b;
  bool _isRawMode = false;
  EventQueue? _eventQueue;
  StreamSubscription<Event>? _eventSubscription;
  StreamController<Event>? _eventBroadcastController;

  /// The current terminal profile to use.
  /// The profile is resolved when the [TermLib] instance is created.
  /// It will use the value returned by the [envColorProfile] function.
  late ProfileEnum profile;

  /// Initialize the Terminal.
  ///
  /// [backend] defaults to [TermBackend.io] (real stdin/stdout). Tests pass
  /// [TermBackend.fake] to inject stdin bytes, capture stdout, and control
  /// tty / env / termOs.
  ///
  /// Event queue is only initialized when [TermBackend.hasTerminal] is true.
  /// In piped mode, [poll]/[read]/[events] throw [StateError]; [stdinStream]
  /// is the supported path.
  TermLib({TermBackend? backend, ProfileEnum? profile}) : _b = backend ?? TermBackend.io() {
    this.profile = profile ?? envColorProfile();

    if (_b.eventQueue != null) {
      _eventQueue = _b.eventQueue;
      _eventBroadcastController = StreamController<Event>.broadcast();
      if (_b.eventSource != null) {
        _eventSubscription = _b.eventSource!.listen(_onEventParsed);
      }
    } else if (_b.eventSource != null) {
      _eventQueue = EventQueue();
      _eventBroadcastController = StreamController<Event>.broadcast();
      _eventSubscription = _b.eventSource!.listen(_onEventParsed);
    } else if (_b.hasTerminal) {
      _eventQueue = EventQueue();
      _eventBroadcastController = StreamController<Event>.broadcast();
      _eventSubscription = _b.stdin.transform(eventTransformer()).listen(_onEventParsed, onError: _onParserError);
    }
  }

  /// Underlying transport. Exposed for tests that need to seed the event queue
  /// or inspect captured stdout.
  TermBackend get backend => _b;

  /// Returns true if stdin is connected to an interactive terminal.
  ///
  /// Use this to detect if input capabilities are available (keyboard, mouse events).
  /// For piped/redirected input, this returns false.
  bool get hasTerminal => _b.hasTerminal;

  /// Returns true if stdout is connected to an interactive terminal.
  ///
  /// Use this to detect if output capabilities are available (colors, cursor control).
  bool get hasOutputTerminal => _b.stdout.hasTerminal;

  /// Returns true if both stdin and stdout are connected to interactive terminals.
  ///
  /// This indicates full interactive terminal capabilities.
  bool get isFullyInteractive => hasTerminal && hasOutputTerminal;

  /// Enables raw mode.
  ///
  /// Raw mode is useful for console applications like text editors, which
  /// perform their own input and output processing, as well as for reading a
  /// single key from the input.
  ///
  /// In general, you should not need to enable or disable raw mode explicitly;
  /// If you use raw mode, you should disable it before your program returns, to
  /// avoid the console being left in a state unsuitable for interactive input.
  ///
  /// When raw mode is enabled, the newline command (`\n`) does not also perform
  /// a carriage return (`\r`). You can use the [newLine] property or the
  /// [writeln] function instead of explicitly using `\n` to ensure the
  /// correct results.
  void enableRawMode() => _setRawMode(true);

  /// Disables raw mode.
  void disableRawMode() => _setRawMode(false);

  /// Returns a [Style] object for the current profile
  ///
  /// If [content] is provided, it will be used as the content of the style and
  /// later and update element styles.
  Style style([String content = '']) => Style(content, profile: profile);

  /// Returns the current newline terminator honoring the raw mode status.
  String get newLine => _isRawMode ? '\r\n' : '\n';

  /// Write the Object's string representation to the terminal.
  void write(Object s) => _b.stdout.write(s);

  /// Writes the specified object followed by a line break to the standard output.
  void writeln(Object s) {
    var text = s.toString();
    if (_isRawMode) {
      text = text.replaceAll('\n', '\r\n');
    }
    _b.stdout.write('$text$newLine');
  }

  /// Write a string to the terminal at the specified position.
  void writeAt(int row, int col, Object s) {
    moveTo(row, col);
    _b.stdout.write(s);
  }

  /// Returns true or false depending if the background is dark or not.
  /// In case the color can not be determined, it will return null.
  ///
  /// The factor is a number between 0 and 1, where 0 will return true if the
  /// background is full black, and 1 will return true if the background is
  /// full white.
  Future<bool?> isBackgroundDark({double factor = 0.5}) async {
    final color = await backgroundColor;
    if (color == null) return null;
    final bgColor = color.convert(ColorKind.rgb);
    return colorLuminance(bgColor) < factor;
  }

  /// Read cursor position on the terminal and return a [Pos] record
  Future<Pos?> get cursorPosition async {
    return withRawModeAsync<Pos?>(() async {
      _b.stdout.write(ansi.Cursor.requestPosition);

      final event = await pollTimeout<CursorPositionEvent>();
      return (event is CursorPositionEvent) ? (row: event.x, col: event.y) : null;
    });
  }

  /// EnvNoColor will return true if the terminal is not supposed to have colors
  /// based on the environment variables.
  ///
  /// If `NO_COLOR` environment variable is set, this will return true, ignoring
  /// `CLICOLOR/CLICOLOR_FORCE`.  If `CLICOLOR=="0"`, it will be true only if
  /// `CLICOLOR_FORCE` is also "0" or is unset.
  ///
  /// reference
  ///    NO_COLOR - https://no-color.org/
  ///    CLICOLOR https://bixense.com/clicolors/
  bool envNoColor() {
    if (_b.env.containsKey('NO_COLOR')) return true;
    if (_b.env['CLICOLOR'] != null || isColorForced) return false;
    return !hasOutputTerminal;
  }

  /// Returns true if the terminal is forced to support colors
  ///
  /// `CLICOLOR_FORCE` environment variable is set
  bool get isColorForced => _b.env['CLICOLOR_FORCE'] != null;

  /// Returns the color profile based on environment variables inspection.
  ///
  /// `ProfileEnum.noColor` if `NO_COLOR` environment variable is set
  ///
  /// `ProfileEnum.ansi16` if `CLICOLOR_FORCE` is set.
  ///
  /// `ProfileEnum.trueColor` or `ProfileEnum.ansi256` depending on TERM and
  /// TERMENV environment variables
  ProfileEnum envColorProfile() {
    if (envNoColor()) return ProfileEnum.noColor;
    final cp = colorProfile();
    if (isColorForced && cp == ProfileEnum.noColor) {
      return ProfileEnum.ansi16;
    }

    return cp;
  }

  /// Returns the width of the current console window in characters.
  ///
  /// If the terminal is not attached to a TTY, returns 80.
  /// Will honor the value of COLUMNS environment variable if set over the
  /// reported value.
  int get terminalColumns {
    final envCols = int.tryParse(_b.env['COLUMNS'] ?? '');
    if (hasOutputTerminal) {
      return envCols ?? (_b.stdout.terminalColumns == 0 ? _defaultColumns : _b.stdout.terminalColumns);
    }
    return envCols ?? _defaultColumns;
  }

  /// Returns the height of the current console window in characters.
  ///
  /// If the terminal is not attached to a TTY, returns 25.
  /// Will honor the value of LINES environment variable if set over the
  /// reported value.
  int get terminalLines {
    final envRows = int.tryParse(_b.env['LINES'] ?? '');
    if (hasOutputTerminal) {
      return envRows ?? (_b.stdout.terminalLines == 0 ? _defaultRows : _b.stdout.terminalLines);
    }
    return envRows ?? _defaultRows;
  }

  /// Poll for events without blocking
  ///
  /// Synchronously checks event queue and returns immediately. Returns [NoneEvent]
  /// if queue is empty.
  ///
  /// Type parameter [T] filters events by type. For example, `poll<KeyEvent>()`
  /// returns first KeyEvent or NoneEvent if none available.
  ///
  /// Throws [StateError] if called on piped/redirected input (when !hasTerminal).
  /// Use [stdinStream] for piped input instead.
  ///
  /// Contrast with [read] which blocks until event arrives.
  ///
  /// Example:
  /// ```dart
  /// final event = term.poll<KeyEvent>();
  /// if (event is KeyEvent) {
  ///   // Handle key press
  /// }
  /// // Continue with render loop immediately
  /// ```
  Event poll<T extends Event>() {
    if (!hasTerminal) {
      throw StateError('poll() requires interactive terminal. Use stdinStream for piped input.');
    }
    return _eventQueue!.dequeue<T>() ?? const NoneEvent();
  }

  /// Waits for event using per-waiter notification. Returns immediately when
  /// matching event arrives or [NoneEvent] if timeout reached.
  ///
  /// Type parameter [T] filters events by type. For example, `pollTimeout<KeyEvent>()`
  /// waits for first KeyEvent or timeout.
  ///
  /// The [timeout] parameter specifies maximum wait time in milliseconds (default 500ms).
  ///
  /// Throws [StateError] if called on piped/redirected input (when !hasTerminal).
  /// Use [stdinStream] for piped input instead.
  ///
  /// Essential for query-response patterns where terminal sends async response:
  /// ```dart
  /// term.write(ansi.Term.querySyncUpdate);
  /// final event = await term.pollTimeout<QuerySyncUpdateEvent>(timeout: 500);
  /// if (event is QuerySyncUpdateEvent) {
  ///   // Handle response
  /// }
  /// ```
  Future<Event> pollTimeout<T extends Event>({int timeout = defaultQueryTimeout}) async {
    if (!hasTerminal) {
      throw StateError('pollTimeout() requires interactive terminal. Use stdinStream for piped input.');
    }
    final event = await _eventQueue!.awaitEvent<T>(timeout: Duration(milliseconds: timeout));
    return event ?? const NoneEvent();
  }

  /// Read event, blocking until one arrives
  ///
  /// Asynchronously waits for event to become available in queue. Blocks current
  /// task indefinitely until matching event arrives. Recommended for CLI apps
  /// waiting for user input.
  ///
  /// Type parameter [T] filters events by type. For example, `read<KeyEvent>()`
  /// waits for and returns first KeyEvent.
  ///
  /// Throws [StateError] if called on piped/redirected input (when !hasTerminal).
  /// Use [stdinStream] for piped input instead.
  ///
  /// Throws [TermDisposed] if the terminal is disposed while waiting.
  ///
  /// Contrast with [poll] which is synchronous and returns immediately (non-blocking).
  ///
  /// Example:
  /// ```dart
  /// final event = await term.read<KeyEvent>();
  /// if (event.code.name == KeyCodeName.enter) {
  ///   // Handle enter key
  /// }
  /// ```
  ///
  /// Note: Will block indefinitely if no input arrives. Consider using [pollTimeout]
  /// if you need timeout behavior.
  Future<Event> read<T extends Event>() async {
    if (!hasTerminal) {
      throw StateError('read() requires interactive terminal. Use stdinStream for piped input.');
    }
    final event = await _eventQueue!.awaitEvent<T>();
    return event ?? const NoneEvent();
  }

  /// Raw stdin stream for piped/redirected input.
  ///
  /// Exposes the raw byte stream from stdin without event parsing. Use this instead
  /// of [poll]/[read] for piped or redirected input scenarios.
  ///
  /// Check [hasTerminal] to detect input mode:
  /// - `hasTerminal == true`: Interactive terminal, use [poll]/[read] for events
  /// - `hasTerminal == false`: Piped/redirected, use [stdinStream] for raw bytes
  ///
  /// Compose with transformers for different processing patterns:
  ///
  /// **Line-by-line streaming** (efficient, recommended):
  /// ```dart
  /// await for (final line in term.stdinStream
  ///     .transform(utf8.decoder)
  ///     .transform(LineSplitter())) {
  ///   processLine(line);  // Process each line as it arrives
  /// }
  /// ```
  ///
  /// **Collect all input** (simple but loads into memory):
  /// ```dart
  /// final lines = await term.stdinStream
  ///     .transform(utf8.decoder)
  ///     .transform(LineSplitter())
  ///     .toList();
  /// ```
  ///
  /// **Custom chunk processing**:
  /// ```dart
  /// await for (final chunk in term.stdinStream.transform(utf8.decoder)) {
  ///   processChunk(chunk);  // Process text chunks as they arrive
  /// }
  /// ```
  ///
  /// **Adaptive input handling**:
  /// ```dart
  /// if (term.hasTerminal) {
  ///   // Interactive: use event-based input
  ///   final event = await term.read<KeyEvent>();
  /// } else {
  ///   // Piped: use stream-based input
  ///   await for (final line in term.stdinStream
  ///       .transform(utf8.decoder)
  ///       .transform(LineSplitter())) {
  ///     processLine(line);
  ///   }
  /// }
  /// ```
  ///
  /// WARNING: Avoid loading entire piped input into memory with `.toList()` or
  /// similar operations on large inputs. Prefer streaming patterns that process
  /// data incrementally.
  Stream<List<int>> get stdinStream => _b.stdin;

  /// Broadcast stream of parsed terminal events.
  ///
  /// Provides push-based event delivery for subscribers. Events are emitted
  /// as they are parsed from stdin. Multiple subscribers supported.
  ///
  /// Coexists with [poll]/[read] - both receive same events from same source.
  /// Use this stream for reactive/push-based patterns; use poll/read for
  /// pull-based patterns.
  ///
  /// Throws [StateError] if called on piped/redirected input (when !hasTerminal).
  ///
  /// Example:
  /// ```dart
  /// terminal.events.listen((event) {
  ///   if (event is KeyEvent) {
  ///     print('Key pressed: ${event.code.char}');
  ///   }
  /// });
  /// ```
  Stream<Event> get events {
    if (_eventBroadcastController == null) {
      throw StateError('events requires interactive terminal. Use stdinStream for piped input.');
    }
    return _eventBroadcastController!.stream;
  }

  /// Enables raw mode and executes the provided function.
  /// On return sets raw mode back to its previous value
  T withRawMode<T>(T Function() fn) {
    final original = _setRawMode(true);
    try {
      return fn();
    } finally {
      _setRawMode(original);
    }
  }

  /// Enables raw mode and executes the provided asynchronous function.
  /// On return sets raw mode back to its previous value
  Future<T> withRawModeAsync<T>(Future<T> Function() fn) async {
    final original = _setRawMode(true);
    return fn().whenComplete(() => _setRawMode(original));
  }

  /// Resolves the current terminal profile checking different environment variables.
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

  /// Returns the terminal foreground color.
  ///
  /// Will try to resolve using OSC10 if available, if not will try to resolve
  /// using COLORFGBG environment variable if available, if not will default to
  /// Ansi color 7
  Future<Color?> get foregroundColor async {
    final result = await queryOSCStatus(10);
    return result ?? _parseFGBG(_fgIdx);
  }

  /// Returns the terminal background color.
  ///
  /// Will try to resolve using OSC11 if available, if not will try to resolve
  /// using COLORFGBG environment variable if available, if can not be determined
  /// will return null
  Future<Color?> get backgroundColor async {
    final result = await queryOSCStatus(11);
    return result ?? _parseFGBG(_bgIdx);
  }

  /// Reads text from the input stream until ENTER or ESC is pressed.
  /// Basic line editing is supported, including backspace and delete.
  /// Returns null if user cancels with ESC.
  Future<String?> readLine([String initBuffer = '']) async {
    return (await Readline.create(this, initBuffer)).read();
  }

  /// Probe terminal capabilities.
  ///
  /// Runs sequential queries to detect terminal capabilities. Returns [TermInfo]
  /// with detected capabilities.
  ///
  /// Parameters:
  /// - [skip]: Queries to skip (default: none)
  /// - [timeout]: Timeout in milliseconds for each query (default: 500)
  ///
  /// Throws [StateError] if terminal is non-interactive (!hasTerminal).
  ///
  /// Example:
  /// ```dart
  /// final info = await term.probe();
  /// if (info.syncUpdate case Supported(:final value)) {
  ///   print('Sync updates: $value');
  /// }
  /// ```
  Future<TermInfo> probe({
    Set<ProbeQuery> skip = const {},
    int timeout = 500,
  }) => probeTerminal(this, skip: skip, timeout: timeout);

  /// Flushes the stdout and stderr streams, then exits the program with the given
  /// status code.
  ///
  /// This returns a Future that will never complete, since the program will have
  /// exited already. This is useful to prevent Future chains from proceeding
  /// after you've decided to exit.
  Future<void> flushThenExit(int status) {
    return Future.wait<void>([_b.stdout.close(), stderr.close()]).then<void>((_) => exit(status));
  }

  /// Dispose of resources used by TermLib.
  ///
  /// Cancels event subscription and disposes event queue and broadcast controller.
  /// Pending `read`/`pollTimeout` futures complete with [TermDisposed].
  /// Call this when done using TermLib to prevent resource leaks.
  Future<void> dispose() async {
    await _eventSubscription?.cancel();
    await _eventQueue?.dispose();
    await _eventBroadcastController?.close();
    _eventQueue = null;
    _eventSubscription = null;
    _eventBroadcastController = null;
  }

  /// Handles parsed events: enqueues to EventQueue and broadcasts to subscribers.
  void _onEventParsed(Event event) {
    _eventQueue!.enqueue(event);
    _eventBroadcastController?.add(event);
  }

  /// Forwards parser errors as [EngineErrorEvent] without tearing down the
  /// subscription.
  void _onParserError(Object error, StackTrace stack) {
    _onEventParsed(EngineErrorEvent(const [], message: error.toString()));
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
