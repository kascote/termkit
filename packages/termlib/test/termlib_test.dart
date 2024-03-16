import 'package:termlib/termlib.dart';
import 'package:test/test.dart';

import 'termlib_mock.dart';

void main() {
  final stdoutMock = MockStdout();
  final term = TermLib(stdoutAdapter: stdoutMock);
  group('TermLib tests >', () {
    test(
      'foregroundColor should return the foreground color',
      () {
        expect(term.foregroundColor, Ansi16Color(4));
      },
      skip: 'need to implement mock',
    );

    test(
      'backgroundColor should return the background color',
      () {
        expect(term.backgroundColor, Ansi256Color(243));
      },
      skip: 'need to implement mock',
    );

    test(
      'termStatusReport should return the terminal status report',
      () {
        expect(term.queryOSCStatus(10), 'rgb:1000/A000/B000');
        expect(term.queryOSCStatus(11), 'rgb:1100/C000/D000');
        expect(term.queryOSCStatus(99), isNull);
      },
      skip: 'need to implement mock',
    );

    test('isTty should return true if the terminal is attached to a TTY', () {
      stdoutMock.clearCallStack();
      expect(term.isInteractive, isTrue);
      expect(stdoutMock.callStack[0], 'hasTerminal');
    });

    test('hasDarkBackground should return true if the terminal has a dark background', () async {
      expect(await term.isBackgroundDark(), isTrue);
    });
  });

  group('noColor >', () {
    test('envNoColor should return true if NO_COLOR is set', () {
      final tl = TermLib(stdoutAdapter: stdoutMock, env: {'NO_COLOR': '1'});
      expect(tl.envNoColor(), isTrue);
    });

    test('envNoColor should return true if CLICOLOR is set is is not forced', () {
      final tl = TermLib(stdoutAdapter: stdoutMock, env: {'CLICOLOR': '0'});
      expect(tl.envNoColor(), isTrue);
    });

    test('envNoColor should return false if CLICOLOR is set and CLICOLOR_FORCE is set too', () {
      final tl = TermLib(
        stdoutAdapter: stdoutMock,
        env: {
          'CLICOLOR': '0',
          'CLICOLOR_FORCE': '1',
        },
      );
      expect(tl.envNoColor(), isFalse);
    });

    test('envNoColor should return true if NO_COLOR is set and CLICOLOR_FORCE is set too', () {
      final tl = TermLib(
        stdoutAdapter: stdoutMock,
        env: {
          'NO_COLOR': '0',
          'CLICOLOR_FORCE': '1',
        },
      );
      expect(tl.envNoColor(), isTrue);
    });
  });

  group('envColorProfile >', () {
    test('envColorProfile should return NoColor if NO_COLOR environment is set', () {
      final tl = TermLib(stdoutAdapter: stdoutMock, env: {'NO_COLOR': '1'});
      expect(tl.envColorProfile(), ProfileEnum.noColor);
    });
    test('envColorProfile should return ansi16 environment set to NoColor but CLICOLOR_FORCE is set', () {
      final tl = TermLib(stdoutAdapter: stdoutMock, env: {'CLICOLOR_FORCE': '1'});
      expect(tl.envColorProfile(), ProfileEnum.ansi16);
    });
  });
}
