import 'package:termansi/termansi.dart';
import 'package:test/test.dart';

void main() {
  group('Color constants >', () {
    group('foreground colors >', () {
      test('basic colors produce correct sequences', () {
        expect(Color.black, equals('\x1b[30m'));
        expect(Color.red, equals('\x1b[31m'));
        expect(Color.green, equals('\x1b[32m'));
        expect(Color.yellow, equals('\x1b[33m'));
        expect(Color.blue, equals('\x1b[34m'));
        expect(Color.magenta, equals('\x1b[35m'));
        expect(Color.cyan, equals('\x1b[36m'));
        expect(Color.white, equals('\x1b[37m'));
      });

      test('bright colors produce correct sequences', () {
        expect(Color.brightBlack, equals('\x1b[90m'));
        expect(Color.brightRed, equals('\x1b[91m'));
        expect(Color.brightGreen, equals('\x1b[92m'));
        expect(Color.brightYellow, equals('\x1b[93m'));
        expect(Color.brightBlue, equals('\x1b[94m'));
        expect(Color.brightMagenta, equals('\x1b[95m'));
        expect(Color.brightCyan, equals('\x1b[96m'));
        expect(Color.brightWhite, equals('\x1b[97m'));
      });
    });

    group('background colors >', () {
      test('basic backgrounds produce correct sequences', () {
        expect(Color.blackBg, equals('\x1b[40m'));
        expect(Color.redBg, equals('\x1b[41m'));
        expect(Color.greenBg, equals('\x1b[42m'));
        expect(Color.yellowBg, equals('\x1b[43m'));
        expect(Color.blueBg, equals('\x1b[44m'));
        expect(Color.magentaBg, equals('\x1b[45m'));
        expect(Color.cyanBg, equals('\x1b[46m'));
        expect(Color.whiteBg, equals('\x1b[47m'));
      });

      test('bright backgrounds produce correct sequences', () {
        expect(Color.brightBlackBg, equals('\x1b[100m'));
        expect(Color.brightRedBg, equals('\x1b[101m'));
        expect(Color.brightGreenBg, equals('\x1b[102m'));
        expect(Color.brightYellowBg, equals('\x1b[103m'));
        expect(Color.brightBlueBg, equals('\x1b[104m'));
        expect(Color.brightMagentaBg, equals('\x1b[105m'));
        expect(Color.brightCyanBg, equals('\x1b[106m'));
        expect(Color.brightWhiteBg, equals('\x1b[107m'));
      });
    });

    group('reset sequences >', () {
      test('reset produces correct sequence', () {
        expect(Color.reset, equals('\x1b[0m'));
      });

      test('default colors produce correct sequences', () {
        expect(Color.defaultFg, equals('\x1b[39m'));
        expect(Color.defaultBg, equals('\x1b[49m'));
      });

      test('reset underline color produces correct sequence', () {
        expect(Color.resetUnderlineColor, equals('\x1b[59m'));
      });
    });
  });

  group('Color.color256Fg >', () {
    test('generates correct sequence for valid colors', () {
      expect(Color.color256Fg(0), equals('\x1b[38;5;0m'));
      expect(Color.color256Fg(1), equals('\x1b[38;5;1m'));
      expect(Color.color256Fg(42), equals('\x1b[38;5;42m'));
      expect(Color.color256Fg(128), equals('\x1b[38;5;128m'));
      expect(Color.color256Fg(255), equals('\x1b[38;5;255m'));
    });

    test('assertions fire for out-of-range values', () {
      expect(() => Color.color256Fg(-1), throwsA(isA<AssertionError>()));
      expect(() => Color.color256Fg(256), throwsA(isA<AssertionError>()));
      expect(() => Color.color256Fg(-100), throwsA(isA<AssertionError>()));
      expect(() => Color.color256Fg(1000), throwsA(isA<AssertionError>()));
    });
  });

  group('Color.color256Bg >', () {
    test('generates correct sequence for valid colors', () {
      expect(Color.color256Bg(0), equals('\x1b[48;5;0m'));
      expect(Color.color256Bg(1), equals('\x1b[48;5;1m'));
      expect(Color.color256Bg(42), equals('\x1b[48;5;42m'));
      expect(Color.color256Bg(128), equals('\x1b[48;5;128m'));
      expect(Color.color256Bg(255), equals('\x1b[48;5;255m'));
    });

    test('assertions fire for out-of-range values', () {
      expect(() => Color.color256Bg(-1), throwsA(isA<AssertionError>()));
      expect(() => Color.color256Bg(256), throwsA(isA<AssertionError>()));
    });
  });

  group('Color.trueColorFg >', () {
    test('generates correct RGB sequence', () {
      expect(Color.trueColorFg(0, 0, 0), equals('\x1b[38;2;0;0;0m'));
      expect(Color.trueColorFg(255, 255, 255), equals('\x1b[38;2;255;255;255m'));
      expect(Color.trueColorFg(255, 128, 64), equals('\x1b[38;2;255;128;64m'));
      expect(Color.trueColorFg(1, 2, 3), equals('\x1b[38;2;1;2;3m'));
    });

    test('assertions fire for invalid R value', () {
      expect(() => Color.trueColorFg(-1, 0, 0), throwsA(isA<AssertionError>()));
      expect(() => Color.trueColorFg(256, 0, 0), throwsA(isA<AssertionError>()));
    });

    test('assertions fire for invalid G value', () {
      expect(() => Color.trueColorFg(0, -1, 0), throwsA(isA<AssertionError>()));
      expect(() => Color.trueColorFg(0, 256, 0), throwsA(isA<AssertionError>()));
    });

    test('assertions fire for invalid B value', () {
      expect(() => Color.trueColorFg(0, 0, -1), throwsA(isA<AssertionError>()));
      expect(() => Color.trueColorFg(0, 0, 256), throwsA(isA<AssertionError>()));
    });
  });

  group('Color.trueColorBg >', () {
    test('generates correct RGB sequence', () {
      expect(Color.trueColorBg(0, 0, 0), equals('\x1b[48;2;0;0;0m'));
      expect(Color.trueColorBg(255, 255, 255), equals('\x1b[48;2;255;255;255m'));
      expect(Color.trueColorBg(255, 128, 64), equals('\x1b[48;2;255;128;64m'));
      expect(Color.trueColorBg(1, 2, 3), equals('\x1b[48;2;1;2;3m'));
    });

    test('assertions fire for invalid R value', () {
      expect(() => Color.trueColorBg(-1, 0, 0), throwsA(isA<AssertionError>()));
      expect(() => Color.trueColorBg(256, 0, 0), throwsA(isA<AssertionError>()));
    });

    test('assertions fire for invalid G value', () {
      expect(() => Color.trueColorBg(0, -1, 0), throwsA(isA<AssertionError>()));
      expect(() => Color.trueColorBg(0, 256, 0), throwsA(isA<AssertionError>()));
    });

    test('assertions fire for invalid B value', () {
      expect(() => Color.trueColorBg(0, 0, -1), throwsA(isA<AssertionError>()));
      expect(() => Color.trueColorBg(0, 0, 256), throwsA(isA<AssertionError>()));
    });
  });

  group('Color.underlineColor256 >', () {
    test('generates correct sequence for valid colors', () {
      expect(Color.underlineColor256(0), equals('\x1b[58;5;0m'));
      expect(Color.underlineColor256(42), equals('\x1b[58;5;42m'));
      expect(Color.underlineColor256(255), equals('\x1b[58;5;255m'));
    });

    test('assertions fire for out-of-range values', () {
      expect(() => Color.underlineColor256(-1), throwsA(isA<AssertionError>()));
      expect(() => Color.underlineColor256(256), throwsA(isA<AssertionError>()));
    });
  });

  group('Color.underlineTrueColor >', () {
    test('generates correct RGB sequence', () {
      expect(Color.underlineTrueColor(0, 0, 0), equals('\x1b[58;2;0;0;0m'));
      expect(Color.underlineTrueColor(255, 255, 255), equals('\x1b[58;2;255;255;255m'));
      expect(Color.underlineTrueColor(255, 0, 0), equals('\x1b[58;2;255;0;0m'));
    });

    test('assertions fire for invalid R value', () {
      expect(() => Color.underlineTrueColor(-1, 0, 0), throwsA(isA<AssertionError>()));
      expect(() => Color.underlineTrueColor(256, 0, 0), throwsA(isA<AssertionError>()));
    });

    test('assertions fire for invalid G value', () {
      expect(() => Color.underlineTrueColor(0, -1, 0), throwsA(isA<AssertionError>()));
      expect(() => Color.underlineTrueColor(0, 256, 0), throwsA(isA<AssertionError>()));
    });

    test('assertions fire for invalid B value', () {
      expect(() => Color.underlineTrueColor(0, 0, -1), throwsA(isA<AssertionError>()));
      expect(() => Color.underlineTrueColor(0, 0, 256), throwsA(isA<AssertionError>()));
    });
  });
}
