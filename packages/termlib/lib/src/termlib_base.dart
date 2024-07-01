import 'dart:async';
import 'dart:io' show Platform, Stdout, exit, stderr, stdin, stdout;

import 'package:termansi/termansi.dart' as ansi;
import 'package:termparser/termparser.dart';
import 'package:termparser/termparser_events.dart';

import '../color_util.dart';
import './colors.dart';
import './extensions/term.dart';
import './ffi/termos.dart';
import './readline.dart';
import './style.dart';
import 'shared/terminal_overrides.dart';

/// Send additional control codes to have mouse motion codes in default zellij
/// configuration.
bool zellijMouseMotionQuirk = false;

/// Type similar to Platform.environment, used for dependency injection
typedef EnvironmentData = Map<String, String>;

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

final _bStream = stdin.asBroadcastStream();

/// Terminal library
class TermLib {
  late TermOs _termOs;
  late Stdout _stdout;
  late EnvironmentData _env;
  bool _isRawMode = false;
  Stream<List<int>>? _mockStdin;

  /// The current terminal profile to use.
  /// The profile is resolved when the [TermLib] instance is created.
  /// It will use the value returned by the [envColorProfile] function.
  late ProfileEnum profile;

  /// Initialize the Terminal
  ///
  /// If no [profile] is provided, it will use the value returned by the
  /// [envColorProfile] function. That means that the default profile will be
  /// resolved based on the environment settings.
  TermLib({ProfileEnum? profile}) {
    final overrides = TerminalOverrides.current;
    _stdout = overrides?.stdout ?? stdout;
    _env = overrides?.environmentData ?? Platform.environment;
    _termOs = overrides?.termOs ?? TermOs();
    this.profile = profile ?? envColorProfile();
  }

  Stream<List<int>> get _broadcastStream {
    final overrides = TerminalOverrides.current;
    if (overrides?.stdin != null && _mockStdin == null) {
      _mockStdin = overrides!.stdin.asBroadcastStream();
    }
    return _mockStdin ?? _bStream;
  }

  /// Returns true if the terminal is attached to an interactive terminal session.
  /// (aka has an standard output connected to a terminal)
  bool get isInteractive => _stdout.hasTerminal;

  /// Returns true if the terminal is not attached to an interactive terminal session.
  bool get isNotInteractive => !_stdout.hasTerminal;

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
  Style style([String content = '']) => Style(content, profile: profile);

  /// Returns the current newline string honoring the raw mode.
  String get newLine => _isRawMode ? '\r\n' : '\n';

  /// Write the Object's string representation to the terminal.
  void write(Object s) => _stdout.write(s);

  /// Writes the specified object followed by a line break to the standard output.
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
  ///
  /// The factor is a number between 0 and 1, where 0 will return true if the
  /// background is full black, and 1 will return true if the background is
  /// full white.
  Future<bool> isBackgroundDark({double factor = 0.5}) async {
    final color = await backgroundColor;
    final bgColor = color.convert(ProfileEnum.trueColor) as TrueColor;
    return colorLuminance(bgColor) < factor;
  }

  /// Read cursor position on the terminal and return a [Pos] record
  Future<Pos?> get cursorPosition async {
    return withRawModeAsync<Pos?>(() async {
      _stdout.write(ansi.Cursor.requestPosition);

      final event = await readEvent<CursorPositionEvent>();
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
    if (_env.containsKey('NO_COLOR')) return true;
    if (_env['CLICOLOR'] != null || isColorForced) return false;
    return isNotInteractive;
  }

  /// Returns true if the terminal is forced to support colors
  ///
  /// `CLICOLOR_FORCE` environment variable is set
  bool get isColorForced => _env['CLICOLOR_FORCE'] != null;

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
  int get windowWidth => isInteractive ? _stdout.terminalColumns : 80;

  /// Returns the height of the current console window in characters.
  ///
  /// If the terminal is not attached to a TTY, returns 25.
  int get windowHeight => isInteractive ? _stdout.terminalLines : 25;

  /// Read events from the standard input [stdin]
  /// The type parameter [T] is the type of event to read. It should be a subclass
  /// of [Event] or [Event] itself to read all the events.
  ///
  /// By default will wait for events for 100 milliseconds, but you can change that
  /// using the [timeout] parameter.
  ///
  /// If the [rawKeys] parameter is set to true, it will return [RawKeyEvent] events
  /// for each key press. This is useful for debugging propouses.
  ///
  /// If the timeout is reached, it will return a [NoneEvent] instance.
  Future<Event> readEvent<T extends Event>({int timeout = 100, bool rawKeys = false}) async {
    final timeoutDuration = Duration(milliseconds: timeout);
    final completer = Completer<Event>();
    final parser = Parser();
    StreamSubscription<Event> subscription;

    final eventTransformer = StreamTransformer<List<int>, Event>.fromHandlers(
      handleData: (data, syncSink) {
        if (rawKeys) return syncSink.add(RawKeyEvent(data));

        parser.advance(data);

        while (parser.moveNext()) {
          syncSink.add(parser.current);
        }
      },
    );

    late Timer timer;

    subscription = _broadcastStream.transform(eventTransformer).skipWhile((evt) => evt is! T).listen(null);
    subscription
      ..onDone(() async {
        await subscription.cancel();
        timer.cancel();
        completer.complete(const NoneEvent());
      })
      // ignore: avoid_types_on_closure_parameters
      ..onError((Object e) async {
        await subscription.cancel();
        timer.cancel();
        completer.completeError(e);
      });

    timer = Timer(timeoutDuration, () async {
      await subscription.cancel();
      completer.complete(const NoneEvent());
    });

    subscription.onData((event) async {
      await subscription.cancel();
      timer.cancel();
      completer.complete(event);
    });

    return completer.future;
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
    if (isNotInteractive) return ProfileEnum.noColor;

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

  /// Returns the terminal foreground color.
  ///
  /// Will try to resolve using OSC10 if available, if not will try to resolve
  /// using COLORFGBG environment variable if available, if not will default to
  /// Ansi color 7
  Future<Color> get foregroundColor async {
    final result = await queryOSCStatus(10);
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
  Future<Color> get backgroundColor async {
    final result = await queryOSCStatus(11);
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

  /// Reads text from the input stream until ENTER or ESC is pressed.
  /// Basic line editing is supported, including backspace and delete.
  Future<String> readLine([String initBuffer = '']) async {
    return (await Readline.create(this, initBuffer)).read();
  }

  /// Flushes the stdout and stderr streams, then exits the program with the given
  /// status code.
  ///
  /// This returns a Future that will never complete, since the program will have
  /// exited already. This is useful to prevent Future chains from proceeding
  /// after you've decided to exit.
  Future<void> flushThenExit(int status) {
    return Future.wait<void>([_stdout.close(), stderr.close()]).then<void>((_) => exit(status));
  }

  bool _setRawMode(bool value) {
    final original = _isRawMode;
    _isRawMode = value;
    if (value) {
      _termOs.enableRawMode();
    } else {
      _termOs.disableRawMode();
    }
    return original;
  }
}
