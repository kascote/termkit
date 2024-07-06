import 'package:termlib/termlib.dart';
import 'package:termparser/termparser_events.dart';
import 'package:test/test.dart';

import './shared.dart';
import 'termlib_mock.dart';

void main() {
  group('TermLib tests >', () {
    test('isInteractive should return true if the terminal is attached to a TTY', () async {
      await mockedTest((out, _, __) {
        final term = TermLib();
        expect(term.isInteractive, isTrue);
        expect(out.callStack[0], 'hasTerminal');
      });
    });

    test('isNotInteractive should return false if the terminal is attached to a TTY', () async {
      await mockedTest((out, _, __) {
        final term = TermLib();
        expect(term.isNotInteractive, isFalse);
        expect(out.callStack[0], 'hasTerminal');
      });
    });

    test('foregroundColor should return the foreground color', () async {
      await mockedTest(
        (out, _, tos) async {
          final term = TermLib();
          expect(await term.foregroundColor, TrueColor(0xc7, 0xc7, 0xc7));
          expect(out.output, '\x1B]10;?\x1B\\');
          expect(tos.callStack[0], 'enableRawMode');
          expect(tos.callStack[1], 'disableRawMode');
        },
        stdin: MockStdin(streamString(r'π]10;rgb:c7f1/c7f1/c7f1π\\')),
      );
    });

    test('foregroundColor must try to parse COLORFGBG if is set and is unable to determine color', () async {
      await mockedTest(
        (out, _, tos) async {
          final term = TermLib();
          expect(await term.foregroundColor, Ansi16Color(9));
          expect(out.output, '\x1B]10;?\x1B\\');
          expect(tos.callStack[0], 'enableRawMode');
          expect(tos.callStack[1], 'disableRawMode');
        },
        stdin: MockStdin(streamString('')),
        env: {'COLORFGBG': '9;0'},
      );
    });

    test('foregroundColor must return null if unable to determine the color', () async {
      await mockedTest(
        (out, _, tos) async {
          final term = TermLib();
          expect(await term.foregroundColor, null);
          expect(out.output, '\x1B]10;?\x1B\\');
          expect(tos.callStack[0], 'enableRawMode');
          expect(tos.callStack[1], 'disableRawMode');
        },
        stdin: MockStdin(streamString('')),
      );
    });
    test('foregroundColor must return null if unable to parse COLORFGBG', () async {
      await mockedTest(
        (out, _, tos) async {
          final term = TermLib();
          expect(await term.foregroundColor, null);
          expect(out.output, '\x1B]10;?\x1B\\');
          expect(tos.callStack[0], 'enableRawMode');
          expect(tos.callStack[1], 'disableRawMode');
        },
        stdin: MockStdin(streamString('')),
        env: {'COLORFGBG': 'bananas'},
      );
    });

    test('backgroundColor should return the background color', () async {
      await mockedTest(
        (out, _, tos) async {
          final term = TermLib();
          expect(await term.backgroundColor, TrueColor(0xab, 0xcd, 0xef));
          expect(tos.callStack[0], 'enableRawMode');
          expect(tos.callStack[1], 'disableRawMode');
        },
        stdin: MockStdin(streamString(r'π]11;rgb:abf1/cdf1/eff1π\\')),
      );
    });

    test('backgroundColor should return the background based on environment', () async {
      await mockedTest(
        (out, _, tos) async {
          final term = TermLib();
          expect(await term.backgroundColor, Ansi16Color(11));
          expect(tos.callStack[0], 'enableRawMode');
          expect(tos.callStack[1], 'disableRawMode');
        },
        env: {'COLORFGBG': '7;11'},
        stdin: MockStdin(streamString('bananas')),
      );
    });

    test('backgroundColor should return null if is unable to resolve it', () async {
      await mockedTest(
        (out, _, tos) async {
          final term = TermLib();
          expect(await term.backgroundColor, null);
          expect(tos.callStack[0], 'enableRawMode');
          expect(tos.callStack[1], 'disableRawMode');
        },
        stdin: MockStdin(streamString('bananas')),
      );
    });

    test('enableRawMode must call enableRawMode on TermOs', () async {
      await mockedTest((_, __, tos) {
        TermLib().enableRawMode();
        expect(tos.callStack[0], 'enableRawMode');
      });
    });

    test('disableRawMode must call disableRawMode on TermOs', () async {
      await mockedTest((_, __, tos) {
        TermLib().disableRawMode();
        expect(tos.callStack[0], 'disableRawMode');
      });
    });

    test('style must return a new Style with the terminal profile setup', () async {
      await mockedTest((_, __, tos) {
        final term = TermLib(profile: ProfileEnum.ansi16);
        final style = term.style();
        expect(style, isA<Style>());
        expect(style.profile, ProfileEnum.ansi16);
      });
    });

    test('newLine must return the correct sequence depending on the rawMode setup', () async {
      await mockedTest((_, __, tos) {
        final term = TermLib();
        expect(term.newLine, '\n');
        term.enableRawMode();
        expect(term.newLine, '\r\n');
        term.disableRawMode();
        expect(term.newLine, '\n');
      });
    });

    test('write must send the object to the stdout', () async {
      await mockedTest((out, _, __) {
        TermLib().write('hello world');
        expect(out.output, 'hello world');
      });
    });

    test('writeLn must send the object to the stdout followed by a new line', () async {
      await mockedTest((out, _, __) {
        final term = TermLib()..writeln('hello world');
        expect(out.output, 'hello world\n');

        out.clearOutput();
        term
          ..enableRawMode()
          ..writeln('hello world');
        expect(out.output, 'hello world\r\n');
      });
    });

    test('writeAt must write the text at the expected position', () async {
      await mockedTest((out, _, __) {
        TermLib().writeAt(10, 11, 'hello world');
        expect(out.output, '\x1B[10;11Hhello world');
      });
    });

    test('isBackgroundDark check the dark threshold', () async {
      await mockedTest(
        (out, _, tos) async {
          final term = TermLib();
          expect(await term.isBackgroundDark(), false);
          expect(tos.callStack[0], 'enableRawMode');
          expect(tos.callStack[1], 'disableRawMode');
        },
        stdin: MockStdin(streamString(r'π]10;rgb:abf1/cdf1/eff1π\\')),
      );
    });

    test('cursorPosition return cursor position on screen', () async {
      await mockedTest(
        (out, _, tos) async {
          final term = TermLib();
          final pos = await term.cursorPosition;
          expect(pos, (row: 10, col: 11));
          expect(tos.callStack[0], 'enableRawMode');
          expect(tos.callStack[1], 'disableRawMode');
        },
        stdin: MockStdin(streamString(r'π[10;11Rπ\\')),
      );
    });

    test('envNoColor must return true if NO_COLOR is set', () async {
      await mockedTest(
        (_, __, ___) {
          final term = TermLib();
          expect(term.envNoColor(), isTrue);
        },
        env: {'NO_COLOR': 'anything'},
      );
    });

    test('envNoColor must return false if CLICOLOR is set', () async {
      await mockedTest(
        (_, __, ___) {
          final term = TermLib();
          expect(term.envNoColor(), isFalse);
        },
        env: {'CLICOLOR': 'anything'},
      );
    });

    test('envNoColor must return false CLICOLOR_FORCE is set', () async {
      await mockedTest(
        (_, __, ___) {
          final term = TermLib();
          expect(term.envNoColor(), isFalse);
        },
        env: {'CLICOLOR_FORCE': 'anything'},
      );
    });

    test('envNoColor must return true if terminal is not interactive', () async {
      final stdOut = MockStdout()..hasTerminal = false;
      await mockedTest(
        (_, __, ___) {
          final term = TermLib();
          expect(term.envNoColor(), isTrue);
        },
        stdout: stdOut,
      );
    });

    test('envColorProfile must return noColor if NO_COLOR is set', () async {
      await mockedTest(
        (_, __, ___) {
          final term = TermLib();
          expect(term.envColorProfile(), ProfileEnum.noColor);
        },
        env: {'NO_COLOR': 'anything'},
      );
    });

    test('envColorProfile must return ansi16 can no detect from ENV but is forced', () async {
      await mockedTest(
        (_, __, ___) {
          final term = TermLib();
          expect(term.envColorProfile(), ProfileEnum.ansi16);
        },
        env: {'CLICOLOR_FORCE': 'anything'},
      );
    });

    test('envColorProfile must return noColor if terminal is not interactive', () async {
      final stdOut = MockStdout()..hasTerminal = false;
      await mockedTest(
        (_, __, ___) {
          final term = TermLib();
          expect(term.envColorProfile(), ProfileEnum.noColor);
        },
        stdout: stdOut,
      );
    });

    test('envColorProfile must return noColor if unable to detect from environment', () async {
      await mockedTest(
        (_, __, ___) {
          final term = TermLib();
          expect(term.envColorProfile(), ProfileEnum.noColor);
        },
        env: {},
      );
    });

    test('envColorProfile must return trueColor GOOGLE_CLOUD_SHELL is set to true', () async {
      await mockedTest(
        (_, __, ___) {
          final term = TermLib();
          expect(term.envColorProfile(), ProfileEnum.trueColor);
        },
        env: {'GOOGLE_CLOUD_SHELL': 'true'},
      );
    });

    test('envColorProfile must return trueColor for supported COLORTERM', () async {
      await mockedTest(
        (_, __, ___) => expect(TermLib().envColorProfile(), ProfileEnum.trueColor),
        env: {'COLORTERM': 'truecolor'},
      );
      await mockedTest(
        (_, __, ___) => expect(TermLib().envColorProfile(), ProfileEnum.trueColor),
        env: {'COLORTERM': '24bit'},
      );
    });

    test('envColorProfile must return ansi256 for supported COLORTERM', () async {
      await mockedTest(
        (_, __, ___) => expect(TermLib().envColorProfile(), ProfileEnum.ansi256),
        env: {'COLORTERM': '256color'},
      );
      await mockedTest(
        (_, __, ___) => expect(TermLib().envColorProfile(), ProfileEnum.ansi256),
        env: {'COLORTERM': 'yes'},
      );
      await mockedTest(
        (_, __, ___) => expect(TermLib().envColorProfile(), ProfileEnum.ansi256),
        env: {'COLORTERM': 'true'},
      );
    });

    test('envColorProfile must return color for supported TERM', () async {
      await mockedTest(
        (_, __, ___) => expect(TermLib().envColorProfile(), ProfileEnum.trueColor),
        env: {'TERM': 'kitty'},
      );
      await mockedTest(
        (_, __, ___) => expect(TermLib().envColorProfile(), ProfileEnum.trueColor),
        env: {'TERM': 'xterm-kitty'},
      );
      await mockedTest(
        (_, __, ___) => expect(TermLib().envColorProfile(), ProfileEnum.trueColor),
        env: {'TERM': 'wezterm'},
      );
      await mockedTest(
        (_, __, ___) => expect(TermLib().envColorProfile(), ProfileEnum.trueColor),
        env: {'TERM': 'alacritty'},
      );
      await mockedTest(
        (_, __, ___) => expect(TermLib().envColorProfile(), ProfileEnum.trueColor),
        env: {'TERM': 'contour'},
      );
      await mockedTest(
        (_, __, ___) => expect(TermLib().envColorProfile(), ProfileEnum.ansi16),
        env: {'TERM': 'linux'},
      );
      await mockedTest(
        (_, __, ___) => expect(TermLib().envColorProfile(), ProfileEnum.ansi256),
        env: {'TERM': 'banana-256color'},
      );
      await mockedTest(
        (_, __, ___) => expect(TermLib().envColorProfile(), ProfileEnum.ansi16),
        env: {'TERM': 'banana-color'},
      );
      await mockedTest(
        (_, __, ___) => expect(TermLib().envColorProfile(), ProfileEnum.ansi16),
        env: {'TERM': 'banana-ansi'},
      );
    });

    test('terminalColumns must return 80 if the terminal is not interactive', () async {
      final stdOut = MockStdout()..hasTerminal = false;
      await mockedTest((_, __, ___) => expect(TermLib().terminalColumns, 80), stdout: stdOut);
    });

    test('terminalColumns must honor COLUMNS env variables if set and is not interactive', () async {
      final stdOut = MockStdout()
        ..setTermColumns(999)
        ..hasTerminal = false;
      await mockedTest(
        (_, __, ___) => expect(TermLib().terminalColumns, 222),
        stdout: stdOut,
        env: {'COLUMNS': '222'},
      );
    });

    test('terminalColumns must honor COLUMNS env variables if set and is interactive', () async {
      final stdOut = MockStdout()
        ..setTermColumns(999)
        ..hasTerminal = true;
      await mockedTest(
        (_, __, ___) => expect(TermLib().terminalColumns, 221),
        stdout: stdOut,
        env: {'COLUMNS': '221'},
      );
    });

    test('terminalColumns must return the terminal columns', () async {
      await mockedTest(
        (_, __, ___) => expect(TermLib().terminalColumns, 999),
        stdout: MockStdout()..setTermColumns(999),
      );
    });

    test('terminalColumns must return default value if termnalColumns is 0', () async {
      await mockedTest(
        (_, __, ___) => expect(TermLib().terminalColumns, 80),
        stdout: MockStdout()..setTermColumns(0),
      );
    });

    test('terminalLines must return 25 if the terminal is not interactive', () async {
      final stdOut = MockStdout()..hasTerminal = false;
      await mockedTest(
        (_, __, ___) => expect(TermLib().terminalLines, 25),
        stdout: stdOut,
      );
    });

    test('terminalLines must honor LINES env variable if set and is not interactive', () async {
      final stdOut = MockStdout()
        ..setTermLines(999)
        ..hasTerminal = false;
      await mockedTest(
        (_, __, ___) => expect(TermLib().terminalLines, 222),
        stdout: stdOut,
        env: {'LINES': '222'},
      );
    });

    test('terminalLines must honor LINES env variables if set and is interactive', () async {
      final stdOut = MockStdout()
        ..setTermLines(999)
        ..hasTerminal = true;
      await mockedTest(
        (_, __, ___) => expect(TermLib().terminalLines, 221),
        stdout: stdOut,
        env: {'LINES': '221'},
      );
    });

    test('terminalLines must return the terminal lines', () async {
      await mockedTest(
        (_, __, ___) => expect(TermLib().terminalLines, 999),
        stdout: MockStdout()..setTermLines(999),
      );
    });

    test('terminalLines must return default value if termnalColumns is 0', () async {
      await mockedTest(
        (_, __, ___) => expect(TermLib().terminalLines, 25),
        stdout: MockStdout()..setTermLines(0),
      );
    });

    test('withRawMode must enable/disable raw mode while executing the callback', () async {
      var ran = false;
      await mockedTest(
        (_, __, tos) async {
          TermLib().withRawMode(() => ran = true);
          expect(tos.callStack[0], 'enableRawMode');
          expect(tos.callStack[1], 'disableRawMode');
          expect(ran, true);
        },
      );
    });

    test('withRawModeAsync must enable/disable raw mode while execute callback', () async {
      var ran = false;
      await mockedTest(
        (_, __, tos) async {
          await TermLib().withRawModeAsync(() async => ran = true);
          expect(tos.callStack[0], 'enableRawMode');
          expect(tos.callStack[1], 'disableRawMode');
          expect(ran, true);
        },
      );
    });

    test('queryKeyboardCapabilities must return event with data', () async {
      await mockedTest(
        (out, __, tos) async {
          final term = TermLib();
          final caps = await term.queryKeyboardCapabilities();
          expect(caps, isA<KeyboardEnhancementFlagsEvent>());
          expect(out.buf.toString(), '\x1B[?u');
          expect(tos.callStack[0], 'enableRawMode');
          expect(tos.callStack[1], 'disableRawMode');
        },
        stdin: MockStdin(streamString('π[?0u')),
      );
    });

    test('setKeyboardFlags must send the flag to the terminal', () async {
      await mockedTest(
        (out, __, tos) async {
          TermLib().setKeyboardFlags(const KeyboardEnhancementFlagsEvent(1));
          expect(out.buf.toString(), '\x1B[=1;1u');
        },
      );
    });

    test('pushKeyboardFlags must send the flag to the terminal', () async {
      await mockedTest(
        (out, __, tos) async {
          TermLib().pushKeyboardFlags(const KeyboardEnhancementFlagsEvent(3));
          expect(out.buf.toString(), '\x1B[>3u');
        },
      );
    });

    test('enableKeyboardEnhancement must send base modes', () async {
      await mockedTest(
        (out, __, tos) async {
          TermLib().enableKeyboardEnhancement();
          expect(out.buf.toString(), '\x1B[=15;1u');
        },
      );
    });

    test('enableKeyboardEnhancementFull must send all modes', () async {
      await mockedTest(
        (out, __, tos) async {
          TermLib().enableKeyboardEnhancementFull();
          expect(out.buf.toString(), '\x1B[=31;1u');
        },
      );
    });

    test('disableKeyboardEnhancement must reset the flags', () async {
      await mockedTest(
        (out, __, tos) async {
          TermLib().disableKeyboardEnhancement();
          expect(out.buf.toString(), '\x1B[=0;1u');
        },
      );
    });

    test('popKeyboardFlags must send the command to pop N flags', () async {
      await mockedTest(
        (out, __, tos) async {
          TermLib().popKeyboardFlags(3);
          expect(out.buf.toString(), '\x1B[<3u');
        },
      );
    });

    test(
      'readLine must read input until ENTER',
      () async {
        await mockedTest(
          (out, _, tos) async {
            final term = TermLib();
            final line = await term.readLine();
            expect(line, 'hello world');
            expect(out.buf.toString(), 'hello world');
            expect(tos.callStack[0], 'enableRawMode');
            expect(tos.callStack[1], 'disableRawMode');
          },
          stdin: MockStdin(streamString('hello world\n')),
        );
      },
      skip: true,
    );

    test(
      'readLine must return empty if kit ESC is pressed',
      () async {
        await mockedTest(
          (out, _, tos) async {
            final term = TermLib();
            final line = await term.readLine();
            expect(line, '');
            expect(out.buf.toString(), '');
            expect(tos.callStack[0], 'enableRawMode');
            expect(tos.callStack[1], 'disableRawMode');
          },
          stdin: MockStdin(streamString('hello world\x1B')),
        );
      },
      skip: true,
    );

    test(
      'readLine must support initialize the buffer with some text',
      () async {
        await mockedTest(
          (out, _, tos) async {
            final term = TermLib();
            final line = await term.readLine('bananas');
            expect(line, 'bananas hello world');
            expect(out.buf.toString(), 'bananas hello world');
            expect(tos.callStack[0], 'enableRawMode');
            expect(tos.callStack[1], 'disableRawMode');
          },
          stdin: MockStdin(streamString(' hello world\n')),
        );
      },
      skip: true,
    );
  });
}
