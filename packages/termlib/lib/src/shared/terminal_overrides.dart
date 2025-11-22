import 'dart:async';
import 'dart:io' as dart_io;

import 'package:termlib/src/ffi/termos.dart';
import 'package:termlib/termlib.dart';

//
// ignore: specify_nonobvious_property_types
const _asyncRunZoned = runZoned;

/// Provides dependency injection for terminal I/O operations.
///
/// This class enables testing and custom terminal implementations by allowing
/// you to override stdin, stdout, environment variables, and OS-level
/// terminal operations.
///
/// borrowed from https://github.com/felangel/mason/blob/master/packages/mason_logger/lib/src/terminal_overrides.dart
///
/// ## Testing Example
///
/// ```dart
/// test('terminal writes to stdout', () {
///   final mockStdout = MockStdout();
///
///   TerminalOverrides.runZoned(
///     () {
///       final term = TermLib();
///       term.write('Hello');
///       expect(mockStdout.writes, contains('Hello'));
///     },
///     stdout: mockStdout,
///   );
/// });
/// ```
///
/// ## Custom Terminal Example
///
/// ```dart
/// // Implement a terminal that logs all output
/// TerminalOverrides.runZoned(
///   () {
///     final term = TermLib();
///     // All output now goes to loggingStdout
///   },
///   stdout: loggingStdout,
///   stdin: customStdin,
/// );
/// ```
///
/// See also:
/// - [runZoned] for creating override contexts
/// - Test files in `test/` directory for more examples
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
  }) {
    final overrides = _TerminalOverridesScope(termOs, environmentData, stdout, stdin);
    return dart_io.IOOverrides.runZoned(
      () => _asyncRunZoned(body, zoneValues: {_token: overrides}),
      stdout: () => overrides.stdout,
      stdin: () => overrides.stdin,
    );
  }

  ///
  TermOs get termOs => TermOs();

  ///
  EnvironmentData get environmentData => dart_io.Platform.environment;

  ///
  dart_io.Stdout get stdout => dart_io.stdout;

  ///
  dart_io.Stdin get stdin => dart_io.stdin;
}

class _TerminalOverridesScope extends TerminalOverrides {
  _TerminalOverridesScope(this._termOs, this._environmentData, this._stdout, this._stdin);

  final TerminalOverrides? _previous = TerminalOverrides.current;
  final TermOs? _termOs;
  final EnvironmentData? _environmentData;
  final dart_io.Stdout? _stdout;
  final dart_io.Stdin? _stdin;

  @override
  TermOs get termOs => _termOs ?? _previous?.termOs ?? super.termOs;

  @override
  EnvironmentData get environmentData => _environmentData ?? _previous?.environmentData ?? super.environmentData;

  @override
  dart_io.Stdout get stdout => _stdout ?? _previous?.stdout ?? super.stdout;

  @override
  dart_io.Stdin get stdin => _stdin ?? _previous?.stdin ?? super.stdin;
}
