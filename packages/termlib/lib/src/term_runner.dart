import 'dart:async';
import 'dart:io';

import 'package:meta/meta.dart';
import 'package:termlib/termlib.dart';

/// Error handler callback type.
///
/// Called after terminal state is restored but before exit.
/// Returns exit code to use.
typedef ErrorHandler =
    FutureOr<int> Function(
      TermLib term,
      Object error,
      StackTrace stack,
    );

/// Exit callback type for testing. Replaces `flushThenExit`.
typedef ExitCallback = Future<void> Function(TermLib term, int exitCode);

/// App runner function type. Returns exit code.
typedef AppRunner = FutureOr<int> Function(TermLib term);

/// Cleanup callback type. Called before exit on all paths (normal, error, signal).
typedef CleanupCallback = FutureOr<void> Function(TermLib term);

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

  /// Set terminal title
  final String? title;

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

  StreamSubscription<ProcessSignal>? _sigintSub;
  StreamSubscription<ProcessSignal>? _sigtermSub;
  bool _disposed = false;

  /// Configure terminal features
  TermRunner({
    this.alternateScreen = false,
    this.rawMode = false,
    this.hideCursor = false,
    this.mouseEvents = false,
    this.keyboardEnhancement = false,
    this.title,
    this.profile,
    this.defaultErrorCode = 1,
    this.showError = true,
    this.onError,
    this.onCleanup,
    @visibleForTesting this.exitCallback,
  });

  /// Build and configure terminal
  TermLib build() {
    final term = TermLib(profile: profile);
    if (alternateScreen) term.enableAlternateScreen();
    if (rawMode) term.enableRawMode();
    if (hideCursor) term.cursorHide();
    if (mouseEvents) term.enableMouseEvents();
    if (keyboardEnhancement) term.enableKeyboardEnhancement();
    if (title != null) term.setTerminalTitle(title!);
    return term;
  }

  /// Restore terminal output state (sync, just writes to stdout)
  void _restoreTerminalState(TermLib term) {
    if (keyboardEnhancement) term.disableKeyboardEnhancement();
    if (mouseEvents) term.disableMouseEvents();
    if (hideCursor) term.cursorShow();
    if (rawMode) term.disableRawMode();
    if (alternateScreen) term.disableAlternateScreen();
  }

  /// Restore terminal state and dispose (async)
  Future<void> _restoreTerminal(TermLib term) async {
    _restoreTerminalState(term);
    await term.dispose();
  }

  Future<void> _exit(TermLib term, int exitCode) async {
    if (exitCallback != null) {
      await exitCallback!(term, exitCode);
    } else {
      await term.flushThenExit(exitCode);
    }
  }

  /// Clean up terminal state and exit
  Future<void> dispose(TermLib term, int exitCode) async {
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

  void _setupSignalHandlers(TermLib term) {
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

  Future<void> _runCleanupAndExit(TermLib term, int code) async {
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
    final term = build();

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
