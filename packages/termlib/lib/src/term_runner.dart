import 'dart:async';
import 'dart:io';

import 'package:meta/meta.dart';
import 'package:termlib/termlib.dart';
import 'package:termparser/termparser_events.dart' show KeyboardEnhancementFlagsEvent;

import 'termlib_base.dart' show TermModes;

/// Error handler callback type.
///
/// Called after terminal state is restored but before exit.
/// Returns exit code to use.
typedef ErrorHandler =
    FutureOr<int> Function(
      InteractiveTerm term,
      Object error,
      StackTrace stack,
    );

/// Exit callback type for testing. Replaces `flushThenExit`.
typedef ExitCallback = Future<void> Function(InteractiveTerm term, int exitCode);

/// App runner function type. Returns exit code.
typedef AppRunner = FutureOr<int> Function(InteractiveTerm term);

/// Cleanup callback type. Called before exit on all paths (normal, error, signal).
typedef CleanupCallback = FutureOr<void> Function(InteractiveTerm term);

const _baseError = 128;
const int _sigInt = _baseError + 2;
const int _sigTerm = _baseError + 15;

/// Helper for setting up and tearing down terminal state.
///
/// Provides automatic cleanup on normal exit, errors, and signals (SIGINT/SIGTERM).
///
/// Example:
/// ```dart
/// final exitCode = await TermRunner(
///   alternateScreen: true,
///   rawMode: true,
///   hideCursor: true,
/// ).run((term) async {
///   // ... use terminal ...
///   return 0;
/// });
/// ```
class TermRunner {
  /// Enable alternate screen buffer
  final bool alternateScreen;

  /// Enable raw mode (no line buffering, no echo)
  final bool rawMode;

  /// Hide cursor
  final bool hideCursor;

  /// Enable mouse events
  final bool mouseEvents;

  /// Enable Kitty keyboard enhancement protocol
  final bool keyboardEnhancement;

  /// Enable bracketed paste mode
  final bool bracketedPaste;

  /// Enable in-band window resize reporting
  final bool inBandResize;

  /// Disable line wrapping (DECAWM) for the app. Terminals start wrapped; a
  /// full-screen app that positions every line itself wants this off. Restored
  /// to its prior (on) state on exit.
  final bool lineWrapping;

  /// Set terminal title
  final String? title;

  /// Probe the terminal before snapshotting, so the build-time snapshot
  /// reflects modes the parent process left on (otherwise they're assumed off
  /// and the §4 best-effort drift applies). Defaults to **true**: only
  /// `TermRunner` can seed its own snapshot — the term is created here and not
  /// exposed until the run callback, which is after the snapshot. Opt out with
  /// `probe: false` to skip the startup round-trips entirely.
  final bool probe;

  /// Which queries to run when [probe] is true. Defaults to
  /// [seedableProbeQueries] — exactly the queries that feed live mode state.
  /// Probe queries run sequentially, each waiting up to [probeTimeout], so the
  /// default keeps worst-case startup latency bounded. Widen it to also
  /// populate [InteractiveTerm.termInfo] with extra capability info.
  final Set<ProbeQuery> probeQueries;

  /// Per-query timeout (ms) for [probe]. Bounds the worst-case startup hang on
  /// a terminal that ignores the queries to `probeQueries.length * probeTimeout`.
  final int probeTimeout;

  /// Force specific color profile
  final ProfileEnum? profile;

  /// Default exit code on unhandled error
  final int defaultErrorCode;

  /// Show error to stderr (default: true)
  final bool showError;

  /// Custom error handler. Called after terminal restored.
  final ErrorHandler? onError;

  /// Cleanup callback. Called before exit on all paths (normal, error, signal).
  final CleanupCallback? onCleanup;

  /// Exit callback for testing. If null, uses `flushThenExit`.
  @visibleForTesting
  final ExitCallback? exitCallback;

  /// Backend override for testing. If null, uses [TermBackend.io].
  @visibleForTesting
  final TermBackend? backend;

  StreamSubscription<ProcessSignal>? _sigintSub;
  StreamSubscription<ProcessSignal>? _sigtermSub;
  bool _disposed = false;

  /// Mode state captured at [build] (after any probe seeding), restored on
  /// every exit path. Null until [build] runs.
  TermModes? _snapshot;

  /// Configure terminal features
  TermRunner({
    this.alternateScreen = false,
    this.rawMode = false,
    this.hideCursor = false,
    this.mouseEvents = false,
    this.keyboardEnhancement = false,
    this.bracketedPaste = false,
    this.inBandResize = false,
    this.lineWrapping = false,
    this.title,
    this.probe = true,
    this.probeQueries = seedableProbeQueries,
    this.probeTimeout = 500,
    this.profile,
    this.defaultErrorCode = 1,
    this.showError = true,
    this.onError,
    this.onCleanup,
    @visibleForTesting this.exitCallback,
    @visibleForTesting this.backend,
  });

  /// Build and configure terminal. Requires an interactive tty.
  ///
  /// Async because, when [probe] is true, it queries the terminal before
  /// snapshotting so the snapshot reflects modes inherited from the parent.
  Future<InteractiveTerm> build() async {
    final term = Term.open(backend: backend, profile: profile);
    if (term is! InteractiveTerm) {
      throw const TerminalNotInteractive('TermRunner requires an interactive terminal (tty stdin).');
    }
    // Seed live mode state from the terminal first, so the snapshot below is
    // the real entry state rather than assumed defaults.
    if (probe) {
      await term.probe(
        skip: ProbeQuery.values.toSet().difference(probeQueries),
        timeout: probeTimeout,
      );
    }
    // Snapshot the entry state (reflecting any probe seeding) so every exit
    // path can restore exactly what was here before we touched anything.
    _snapshot = term.modes;
    if (alternateScreen) term.enableAlternateScreen();
    if (rawMode) term.enableRawMode();
    if (hideCursor) term.cursorHide();
    if (mouseEvents) term.enableMouseEvents();
    if (keyboardEnhancement) term.enableKeyboardEnhancement();
    if (bracketedPaste) term.enableBracketedPaste();
    if (inBandResize) term.enableInBandResize();
    if (lineWrapping) term.disableLineWrapping();
    if (title != null) term.setTerminalTitle(title!);
    return term;
  }

  /// Restore terminal output state (sync, just writes to stdout). Drives every
  /// mode back to the [build]-time snapshot — sane even on a signal mid-way
  /// through a nested scope, whose own `finally` won't run.
  void _restoreTerminalState(InteractiveTerm term) {
    final snapshot = _snapshot;
    if (snapshot != null) _restoreModes(term, snapshot);
  }

  /// Drives every tracked mode back to the state captured in [target] via the
  /// public toggle methods (so the escapes are emitted and the term's tracked
  /// state stays in sync). A mode already matching [target] is left untouched
  /// (no escape). This is `TermRunner`'s snapshot-restore policy — it needs no
  /// private terminal state, only the [InteractiveTerm.modes] getter.
  void _restoreModes(InteractiveTerm term, TermModes target) {
    final cur = term.modes;
    void sync(TerminalMode mode, void Function() enable, void Function() disable) {
      if (cur.isEnabled(mode) == target.isEnabled(mode)) return;
      (target.isEnabled(mode) ? enable : disable)();
    }

    sync(TerminalMode.alternateScreen, term.enableAlternateScreen, term.disableAlternateScreen);
    sync(TerminalMode.mouseEvents, term.enableMouseEvents, term.disableMouseEvents);
    sync(TerminalMode.bracketedPaste, term.enableBracketedPaste, term.disableBracketedPaste);
    sync(TerminalMode.inBandResize, term.enableInBandResize, term.disableInBandResize);
    sync(TerminalMode.unicodeCore, term.enableUnicodeCore, term.disableUnicodeCore);
    sync(TerminalMode.lineWrapping, term.enableLineWrapping, term.disableLineWrapping);
    sync(TerminalMode.cursorVisible, term.cursorShow, term.cursorHide);
    sync(TerminalMode.rawMode, term.enableRawMode, term.disableRawMode);

    // Keyboard enhancement is a flags value, not a bit. Restore via
    // setKeyboardFlags (a null snapshot = enhancement never managed = off).
    if (cur.keyboardFlags != target.keyboardFlags) {
      term.setKeyboardFlags(target.keyboardFlags ?? const KeyboardEnhancementFlagsEvent(0));
    }
  }

  /// Restore terminal state and dispose (async)
  Future<void> _restoreTerminal(InteractiveTerm term) async {
    _restoreTerminalState(term);
    await term.dispose();
  }

  Future<void> _exit(InteractiveTerm term, int exitCode) async {
    if (exitCallback != null) {
      await exitCallback!(term, exitCode);
    } else {
      await term.flushThenExit(exitCode);
    }
  }

  /// Clean up terminal state and exit
  Future<void> dispose(InteractiveTerm term, int exitCode) async {
    if (_disposed) return;
    _disposed = true;

    await _cancelSignalHandlers();
    await _restoreTerminal(term);
    try {
      if (onCleanup != null) {
        await onCleanup!(term);
      }
    } on Object catch (e) {
      stderr.writeln('Cleanup error: $e');
    }
    await _exit(term, exitCode);
  }

  void _setupSignalHandlers(InteractiveTerm term) {
    void handleSignal(ProcessSignal signal) {
      if (_disposed) return;
      _disposed = true;

      // Restore terminal immediately (sync)
      _restoreTerminalState(term);

      // Signal exit code: 128 + signal number
      final code = signal == ProcessSignal.sigint ? _sigInt : _sigTerm;

      // Run cleanup then exit
      unawaited(_runCleanupAndExit(term, code));
    }

    _sigintSub = ProcessSignal.sigint.watch().listen(handleSignal);

    // SIGTERM not available on Windows
    if (!Platform.isWindows) {
      _sigtermSub = ProcessSignal.sigterm.watch().listen(handleSignal);
    }
  }

  Future<void> _runCleanupAndExit(InteractiveTerm term, int code) async {
    try {
      if (onCleanup != null) {
        await onCleanup!(term);
      }
    } on Object catch (e) {
      stderr.writeln('Cleanup error: $e');
    }
    await term.dispose();
    await _exit(term, code);
  }

  Future<void> _cancelSignalHandlers() async {
    await _sigintSub?.cancel();
    await _sigtermSub?.cancel();
    _sigintSub = null;
    _sigtermSub = null;
  }

  /// Run code with automatic cleanup.
  ///
  /// Returns exit code from [fn], error handler, or signal.
  /// Always calls `flushThenExit` with the exit code.
  Future<int> run(AppRunner fn) async {
    final term = await build();

    _setupSignalHandlers(term);

    try {
      final result = await fn(term);

      await dispose(term, result);
      return result;
    } on Object catch (e, stack) {
      // Restore terminal before showing error
      await _cancelSignalHandlers();
      await _restoreTerminal(term);
      _disposed = true;

      if (showError) {
        stderr
          ..writeln('Error: $e')
          ..writeln(stack);
      }

      try {
        if (onCleanup != null) {
          await onCleanup!(term);
        }
      } on Object catch (cleanupError) {
        stderr.writeln('Cleanup error: $cleanupError');
      }

      final exitCode = onError != null ? await onError!(term, e, stack) : defaultErrorCode;

      await _exit(term, exitCode);
      return exitCode;
    }
  }
}
