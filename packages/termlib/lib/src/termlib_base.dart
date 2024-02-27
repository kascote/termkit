import 'dart:async';
import 'dart:io' show Platform, Stdout, exit, stderr, stdin, stdout;

import 'package:termansi/termansi.dart' as ansi;
import 'package:termparser/termparser.dart';

import './colors.dart';
import './ffi/termos.dart';
import './profile.dart';
import 'shared/color_util.dart';

/// Type similar to Platform.environment, used for dependency injection
typedef EnvironmentData = Map<String, String>;

/// Record that represent a coordinate position
typedef Pos = ({int row, int col});

final _broadcastStream = stdin.asBroadcastStream();

/// Terminal library
class TermLib {
  late TermOs _termOs;
  late Stdout _stdout;
  late EnvironmentData _env;
  bool _isRawMode = false;

  /// The current terminal profile to use.
  ///
  /// The profile is resolved when the [TermLib] instance is created.
  /// It will use the value returned by the [envColorProfile] function.
  late Profile profile;

  /// The singleton instance of [TermLib].
  TermLib({Stdout? stdoutAdapter, EnvironmentData? env, ProfileEnum? profile}) {
    _stdout = stdoutAdapter ?? stdout;
    _env = env ?? Platform.environment;
    _termOs = TermOs(); // terminalAdapter ?? termAdapter(stdoutAdapter: stdoutAdapter, env: env);
    this.profile = Profile(profile: profile ?? envColorProfile());
  }

  /// Returns true if the terminal is attached to an TTY
  bool get isTty => _stdout.hasTerminal;

  /// Enables or disables raw mode.
  ///
  /// There are a series of flags applied to a UNIX-like terminal that together
  /// constitute 'raw mode'. These flags turn off echoing of character input,
  /// processing of input signals like Ctrl+C, and output processing, as well as
  /// buffering of input until a full line is entered.
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
  bool get rawMode => _isRawMode;
  set rawMode(bool value) {
    _isRawMode = value;
    if (value) {
      _termOs.enableRawMode();
    } else {
      _termOs.disableRawMode();
    }
  }

  /// Returns the current newline string.
  String get newLine => _isRawMode ? '\r\n' : '\n';

  /// Write the Object's string representation to the terminal.
  void write(Object s) => _stdout.write(s);

  /// Writes the specified object followed by a line break to the standard output.
  ///
  /// The function will check if the terminal is in raw mode and if so will replace
  /// the `\n` with `\r\n` to ensure the correct results.
  void writeln(Object s) {
    var text = s.toString();
    if (_isRawMode) {
      text = text.replaceAll('\n', '\r\n');
    }
    _stdout.write('$text$newLine');
  }

  /// Write a string to the terminal at the specified position.
  void writeAt(int row, int col, Object s) {
    _stdout
      ..write(ansi.Cursor.moveTo(row, col))
      ..write(s);
  }

  /// Returns true or false depending if the background is dark or not
  Future<bool> isBackgroundDark() async {
    final color = await backgroundColor();
    final bgColor = Profile(profile: ProfileEnum.trueColor).convert(color);
    return colorLuminance(bgColor as TrueColor) < 0.5;
  }

  /// Read cursor position on the terminal and return a [Pos] record
  Future<Pos?> get cursorPosition async {
    return withRawModeAsync<Pos?>(() async {
      _stdout.write(ansi.Cursor.requestPosition);

      final event = await readEvent();
      if (event is CursorPositionEvent) {
        return (row: event.x, col: event.y);
      }

      return null;
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
    if (_env.containsKey('NO_COLOR')) return true;
    if (_env['CLICOLOR'] == '0' && !isColorForced()) return true;
    return false;
  }

  /// Returns true if the terminal is forced to support colors
  ///
  /// `CLICOLOR_FORCE` environment variable is set to a value different from '0'
  bool isColorForced() {
    final forced = _env['CLICOLOR_FORCE'];
    if (forced != null && forced != '0') return true;
    return false;
  }

  /// Returns the color profile based on environment variables inspection.
  ///
  /// `ProfileEnum.noColor` if `NO_COLOR` environment variable is set
  /// `ProfileEnum.ansi16` if `CLICOLOR_FORCE` is set.
  /// `ProfileEnum.trueColor` or `ProfileEnum.ansi256` depending on TERM and
  /// TERMENV environment variables
  ProfileEnum envColorProfile() {
    if (envNoColor()) return ProfileEnum.noColor;
    final cp = colorProfile();
    if (isColorForced() && cp == ProfileEnum.noColor) {
      return ProfileEnum.ansi16;
    }

    return cp;
  }

  /// Returns the width of the current console window in characters.
  ///
  /// If the terminal is not attached to a TTY, returns 80.
  int get windowWidth => isTty ? _stdout.terminalColumns : 80;

  /// Returns the height of the current console window in characters.
  ///
  /// If the terminal is not attached to a TTY, returns 25.
  int get windowHeight => isTty ? _stdout.terminalLines : 25;

  /// Read events from the standard input [stdin]
  Future<Event> readEvent({int timeout = 100}) async {
    final timeoutDuration = Duration(milliseconds: timeout);
    final completer = Completer<Event>();
    final sequence = <int>[];
    final parser = Parser();
    StreamSubscription<List<int>>? subscription;

    final timer = Timer(timeoutDuration, () async {
      await subscription!.cancel();
      completer.complete(const NoneEvent());
    });

    subscription = _broadcastStream.listen(
      (event) async {
        sequence.addAll(event);
        await subscription!.cancel();
        timer.cancel();
        parser.advance(sequence);
        completer.complete(parser.moveNext() ? parser.current : const NoneEvent());
      },
      onError: completer.completeError,
      cancelOnError: true,
    );

    return completer.future;
  }

  /// Read raw keys from the standard input [stdin]
  Future<List<int>> readRawKeys({int timeout = 100}) async {
    final timeoutDuration = Duration(milliseconds: timeout);
    final completer = Completer<List<int>>();
    final sequence = <int>[];
    StreamSubscription<List<int>>? subscription;

    final timer = Timer(timeoutDuration, () async {
      await subscription!.cancel();
      completer.complete([]);
    });

    subscription = _broadcastStream.listen(
      (event) async {
        sequence.addAll(event);
        await subscription!.cancel();
        timer.cancel();
        completer.complete(sequence);
      },
      onError: completer.completeError,
      cancelOnError: true,
    );

    return completer.future;
  }

  /// Enables raw mode and executes the provided asynchronous function.
  /// on return sets raw mode back to its previous value
  T withRawMode<T>(T Function() fn) {
    final prevRawMode = _isRawMode;
    rawMode = true;
    try {
      return fn();
    } finally {
      rawMode = prevRawMode;
    }
  }

  /// Enables raw mode and executes the provided asynchronous function.
  /// on return sets raw mode back to its previous value
  Future<T> withRawModeAsync<T>(Future<T> Function() fn) async {
    final prevRawMode = _isRawMode;
    rawMode = true;
    try {
      return await fn();
    } finally {
      rawMode = prevRawMode;
    }
  }

  /// Request terminal capabilities
  Future<KeyboardEnhancementFlags?> requestCapabilities() async {
    return withRawModeAsync<KeyboardEnhancementFlags?>(() async {
      _stdout.write(ansi.Sup.requestKeyboardCapabilities);

      final event = await readEvent();
      if (event is KeyboardEnhancementFlags) return event;

      return null;
    });
  }

  /// Set terminal capabilities
  void setCapabilities(KeyboardEnhancementFlags flags) =>
      _stdout.write(ansi.Sup.setKeyboardCapabilities(flags.flags, flags.mode));

  /// Push terminal capabilities
  void pushCapabilities(KeyboardEnhancementFlags flags) =>
      _stdout.write(ansi.Sup.pushKeyboardCapabilities(flags.flags));

  /// Pop terminal capabilities
  void popCapabilities([int entries = 1]) => _stdout.write(ansi.Sup.popKeyboardCapabilities(entries));

  /// Resolves the current profile checking different environment variables.
  ProfileEnum colorProfile() {
    // if isTty return ProfileEnum.noColor;

    if (_env['GOOGLE_CLOUD_SHELL'] == 'true') {
      return ProfileEnum.trueColor;
    }

    final envTerm = _env['TERM'] ?? '';

    switch (_env['COLORTERM']) {
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

  /// Returns the current terminal status report.
  Future<TrueColor?> termStatusReport(int status) async {
    return withRawModeAsync<TrueColor?>(() async {
      _stdout.write(ansi.Sup.queryOSCColors(status));

      final event = await readEvent();
      if (event is ColorQueryEvent) {
        return TrueColor(event.r, event.g, event.b);
      }
      return null;
    });
  }

  /// Returns the terminal foreground color.
  ///
  /// Will try to resolve using OSC10 if available, if not will try to resolve
  /// using COLORFGBG environment variable if available, if not will default to
  /// Ansi color 7
  Future<Color?> foregroundColor() async {
    final result = await termStatusReport(10);
    if (result != null) return result;

    final envColorFgBg = _env['COLORFGBG'];
    if (envColorFgBg != null) {
      final colorFg = envColorFgBg.split(';')[0].trim();
      if (colorFg.isNotEmpty) {
        final color = int.tryParse(colorFg);
        if (color != null) return Ansi16Color(color);
      }
    }

    return Ansi16Color(7);
  }

  /// Returns the terminal background color.
  ///
  /// Will try to resolve using OSC11 if available, if not will try to resolve
  /// using COLORFGBG environment variable if available, if not will default to
  /// Ansi color 0
  Future<Color> backgroundColor() async {
    final result = await termStatusReport(11);
    if (result != null) return result;

    final envColorFgBg = _env['COLORFGBG'];
    if (envColorFgBg != null && envColorFgBg.contains(';')) {
      final colorBg = envColorFgBg.split(';')[1].trim();
      if (colorBg.isNotEmpty) {
        final color = int.tryParse(colorBg);
        if (color != null) return Ansi16Color(color);
      }
    }

    return Ansi16Color(0);
  }

  /// Flushes the stdout and stderr streams, then exits the program with the given
  /// status code.
  ///
  /// This returns a Future that will never complete, since the program will have
  /// exited already. This is useful to prevent Future chains from proceeding
  /// after you've decided to exit.
  Future<void> flushThenExit(int status) {
    return Future.wait<void>([stdout.close(), stderr.close()]).then<void>((_) => exit(status));
  }
}
