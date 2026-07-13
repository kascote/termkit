import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform, ProcessSignal, exit, stderr;

import 'package:meta/meta.dart';
import 'package:termansi/termansi.dart' as ansi;
import 'package:termparser/termparser.dart';
import 'package:termparser/termparser_events.dart';

import './colors.dart';
import './event_queue.dart';
import './extensions/types.dart';
import './probe/probe.dart';
import './probe/probe_collector.dart';
import './probe/query_result.dart';
import './probe/term_info.dart';
import './readline.dart';
import './shared/color_util.dart';
import './shared/term_backend.dart';
import './style.dart';

export './event_queue.dart' show QueueOverflowEvent, TermDisposed, TerminalNotInteractive;
export './shared/term_backend.dart' show EnvironmentData, TermBackend;
export './shared/term_sink.dart' show BufferTermSink, TermSink;

part './extensions/cursor.dart';
part './extensions/erase.dart';
part './extensions/term.dart';
part './term_modes.dart';

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
  /// or inspect captured stdout, and for the documented raw-bytes recipe
  /// (`term.backend.stdin.map(RawKeyEvent.new)`).
  TermBackend get backend => _b;

  /// True if stdout is connected to an interactive terminal.
  bool get hasOutputTerminal => _b.stdout.hasTerminal;

  /// Returns a [Style] object for the current profile.
  Style style({
    Color? fg,
    Color? bg,
    bool bold = false,
    bool faint = false,
    bool italic = false,
    bool blink = false,
    bool reverse = false,
    bool crossOut = false,
    bool overline = false,
    Underline underline = Underline.none,
    Color? underlineColor,
  }) {
    return Style(
      fg: fg,
      bg: bg,
      bold: bold,
      faint: faint,
      italic: italic,
      blink: blink,
      reverse: reverse,
      crossOut: crossOut,
      overline: overline,
      underline: underline,
      underlineColor: underlineColor,
      profile: profile,
    );
  }

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

  /// Flush pending stdout without closing it or exiting the process.
  Future<void> flush() => _b.stdout.flush();

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

  /// Live mode state — source of truth for save/restore. Every tracked
  /// enableX`/`disableX` toggle swaps this cell
  TermModes _modes = TermModes.initial;
  EventQueue? _eventQueue;
  StreamSubscription<Event>? _eventSubscription;
  StreamController<Event>? _eventBroadcastController;

  /// SIGWINCH watcher installed by [enableResizeEvents] as a fallback for
  /// terminals not known to support in-band resize reporting. Null when no
  /// watcher is installed.
  StreamSubscription<ProcessSignal>? _resizeSignalSubscription;

  /// Active batch-probe tap, installed only for the duration of a probe by
  /// [runProbeBatch]. When set, [_onEventParsed] offers each parsed event to it
  /// first; consumed probe replies bypass the queue
  ProbeCollector? _probeCollector;

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
  String get newLine => _modes.rawMode ? '\r\n' : '\n';

  @override
  String get _newLine => newLine;

  @override
  void writeln(Object s) {
    var text = s.toString();
    if (_modes.rawMode) {
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

  /// Run [fn] with the named terminal modes applied, restoring each to the
  /// state it had at scope entry once [fn] completes (normally or with error).
  ///
  /// Each mode param is three-state:
  ///
  /// - `null`  → **not managed**: untouched, inherits whatever the outer scope
  ///   set. An inner scope never clobbers an outer scope's settings.
  /// - `true`  → ensure **on** for the duration, restore prior tracked value.
  /// - `false` → ensure **off** for the duration, restore prior tracked value.
  ///
  /// [keyboardEnhancement] carries the same three states via
  /// [KeyboardEnhancement] (`null` = not managed). When managed it is applied
  /// and restored through the kitty push/pop stack rather than cell-replay: the
  /// terminal restores the prior flags itself, which is correct even when the
  /// prior value was never known (§3.7).
  ///
  /// **Serial-only.** Scopes must be strictly **nested or sequential** — never
  /// two `withModes` calls concurrently pending (each with an `await` in
  /// flight). The tracked state is a single mutable cell; interleaved
  /// save/restore is no longer LIFO and leaves the wrong final state. This is
  /// not a new constraint — two pending scopes already mean two flows driving
  /// one physical terminal (the classic termios save/restore assumption). It is
  /// documented, not guarded: a correct nesting-vs-interleaving guard needs
  /// `Zone` tracking the library deliberately avoids.
  Future<T> withModes<T>(
    Future<T> Function() fn, {
    bool? rawMode,
    bool? alternateScreen,
    bool? mouseEvents,
    KeyboardEnhancement? keyboardEnhancement,
    bool? bracketedPaste,
    bool? inBandResize,
    bool? lineWrapping,
    bool? cursorVisible,
  }) async {
    // Restore actions run in reverse (LIFO) on exit. Built incrementally as
    // each mode is applied, so a mid-apply failure still restores the modes
    // that were already applied (partial-apply restore).
    final restores = <void Function()>[];

    void manage(TerminalMode mode, void Function() enable, void Function() disable, {bool? want = false}) {
      if (want == null) return;
      final prior = _modes.isEnabled(mode);
      (want ? enable : disable)();
      restores.add(prior ? enable : disable);
    }

    try {
      // Apply loop sits inside the try so a throwing toggle still triggers the
      // finally and restores whatever was applied before it.
      manage(TerminalMode.rawMode, enableRawMode, disableRawMode, want: rawMode);
      manage(TerminalMode.alternateScreen, enableAlternateScreen, disableAlternateScreen, want: alternateScreen);
      manage(TerminalMode.mouseEvents, enableMouseEvents, disableMouseEvents, want: mouseEvents);
      manage(TerminalMode.bracketedPaste, enableBracketedPaste, disableBracketedPaste, want: bracketedPaste);
      manage(TerminalMode.inBandResize, enableInBandResize, disableInBandResize, want: inBandResize);
      manage(TerminalMode.lineWrapping, enableLineWrapping, disableLineWrapping, want: lineWrapping);
      manage(TerminalMode.cursorVisible, cursorShow, cursorHide, want: cursorVisible);

      if (keyboardEnhancement != null) {
        final priorFlags = _modes.keyboardFlags;
        pushKeyboardFlags(keyboardEnhancement.flags);
        restores.add(() {
          // The terminal restores the prior flags from its own stack; pop is
          // untracked, so reset the cell to the value captured at entry.
          popKeyboardFlags();
          _modes = _modes.withKeyboardFlags(priorFlags);
        });
      }

      return await fn();
    } finally {
      for (final restore in restores.reversed) {
        restore();
      }
    }
  }

  /// The current live tracked mode state. Internal — the only seam `TermRunner`
  /// needs to snapshot at build time and later restore to (the restore itself
  /// is its own concern, driven through the public toggle methods).
  @internal
  TermModes get modes => _modes;

  /// Read a line from the terminal with basic editing. Returns null on ESC.
  Future<String?> readLine([ReadlineOptions options = const ReadlineOptions()]) {
    return Readline(this, options).read();
  }

  /// The most recent [probe] result, or null if [probe] was never called.
  ///
  /// Cached so capability-dependent helpers can rely on a single probe instead
  /// of re-querying the terminal on every call.
  TermInfo? get termInfo => _termInfo;
  TermInfo? _termInfo;

  /// Probe terminal capabilities. The result is cached in [termInfo] and seeds
  /// the live tracked mode state ([_seedModesFromProbe]) so subsequent
  /// `withModes` save/restore starts from the terminal's actual state rather
  /// than assumed defaults.
  Future<TermInfo> probe({
    Set<ProbeQuery> skip = const {},
    int deadline = 500,
  }) async {
    final info = await probeTerminal(this, skip: skip, deadline: deadline);
    _termInfo = info;
    _seedModesFromProbe(info);
    return info;
  }

  /// Runs one batched probe: installs [collector] as the event tap, writes the
  /// whole [batch] of query escapes at once, then waits for either the DA1 fence
  /// (early-exit via [ProbeCollector.done]) or the batch [deadline].
  ///
  /// The tap is installed **before** the write so no fast reply is missed, and
  /// removed in `finally` so any post-deadline straggler becomes an ordinary
  /// queue event.
  @internal
  Future<void> runProbeBatch(String batch, ProbeCollector collector, Duration deadline) async {
    _probeCollector = collector;
    try {
      write(batch);
      await collector.done.timeout(deadline, onTimeout: () {});
    } finally {
      _probeCollector = null;
    }
  }

  /// Seeds [_modes] from a fresh [TermInfo].
  ///
  /// Seed mode M ⟺ M has a probe query **and** that query returned a definite
  /// state (`enabled`/`disabled`; for keyboard: any flags). `unknown` /
  /// `Unavailable` results are not seeded — those modes keep their current
  /// (default) tracked value. `syncUpdate` is deliberately not a mode (§3.5).
  void _seedModesFromProbe(TermInfo info) {
    bool? definite(QueryResult<Object> r, bool Function(Object) isEnabled, bool Function(Object) isDisabled) {
      return switch (r) {
        Supported(:final value) when isEnabled(value) => true,
        Supported(:final value) when isDisabled(value) => false,
        _ => null,
      };
    }

    _modes = _modes.copyWith(
      bracketedPaste: definite(
        info.bracketedPaste,
        (v) => v == BracketedPasteStatus.enabled,
        (v) => v == BracketedPasteStatus.disabled,
      ),
      inBandResize: definite(
        info.inBandResize,
        (v) => v == InBandResizeStatus.enabled,
        (v) => v == InBandResizeStatus.disabled,
      ),
      unicodeCore: definite(
        info.unicodeCore,
        (v) => v == UnicodeCoreStatus.enabled,
        (v) => v == UnicodeCoreStatus.disabled,
      ),
    );

    // Keyboard enhancement seeds the flags value directly: a definite
    // result is any reported KeyboardFlags, even all-zero (which tracks as
    // disabled). withKeyboardFlags is used because copyWith treats a null
    // keyboardFlags as "leave unchanged".
    if (info.keyboardCapabilities case Supported(:final value)) {
      _modes = _modes.withKeyboardFlags(_keyboardFlagsToEvent(value));
    }
  }

  /// Converts probe [KeyboardFlags] into the [KeyboardEnhancementFlagsEvent]
  /// value tracked by [TermModes].
  KeyboardEnhancementFlagsEvent _keyboardFlagsToEvent(KeyboardFlags f) {
    var bits = 0;
    if (f.disambiguateEscapeCodes) bits |= KeyboardEnhancementFlagsEvent.disambiguateEscapeCodes;
    if (f.reportEventTypes) bits |= KeyboardEnhancementFlagsEvent.reportEventTypes;
    if (f.reportAlternateKeys) bits |= KeyboardEnhancementFlagsEvent.reportAlternateKeys;
    if (f.reportAllKeysAsEscapeCodes) bits |= KeyboardEnhancementFlagsEvent.reportAllKeysAsEscapeCodes;
    if (f.reportAssociatedText) bits |= KeyboardEnhancementFlagsEvent.reportAssociatedText;
    return KeyboardEnhancementFlagsEvent(bits);
  }

  /// Dispose event plumbing. Pending [awaitEvent]/[nextEvent] futures
  /// complete with [TermDisposed].
  ///
  /// Also cancels the SIGWINCH watcher installed by [enableResizeEvents], if
  /// any — a backstop for callers that tear down via [dispose] without first
  /// calling [disableResizeEvents].
  @override
  Future<void> dispose() async {
    await _eventSubscription?.cancel();
    await _resizeSignalSubscription?.cancel();
    await _eventQueue?.dispose();
    await _eventBroadcastController?.close();
    _eventQueue = null;
    _eventSubscription = null;
    _resizeSignalSubscription = null;
    _eventBroadcastController = null;
  }

  void _onEventParsed(Event event) {
    final collector = _probeCollector;
    if (collector != null && collector.offer(event)) {
      _eventBroadcastController?.add(event); // parity: probe replies still broadcast
      return; // consumed by the probe tap: do not enqueue
    }
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
    final original = _modes.rawMode;
    _modes = _modes.copyWith(rawMode: value);
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
