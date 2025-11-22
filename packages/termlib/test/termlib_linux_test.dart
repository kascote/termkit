import 'package:termlib/termlib.dart';
import 'package:test/test.dart';

import './shared.dart';

void main() {
  group('colorProfile >', () {
    test('should return TrueColor if GOOGLE_CLOUD_SHELL is set', () async {
      await mockedTest(
        (_, _, _) {
          final tu = TermLib();
          expect(tu.colorProfile(), ProfileEnum.trueColor);
        },
        env: {'GOOGLE_CLOUD_SHELL': 'true'},
      );
    });

    test('should return TrueColor if COLORTERM is set to "truecolor"', () async {
      await mockedTest(
        (_, _, _) {
          final tu = TermLib();
          expect(tu.colorProfile(), ProfileEnum.trueColor);
        },
        env: {'COLORTERM': 'truecolor'},
      );
    });

    test('should return TrueColor if COLORTERM is set to "24bit"', () async {
      await mockedTest(
        (_, _, _) {
          final tu = TermLib();
          expect(tu.colorProfile(), ProfileEnum.trueColor);
        },
        env: {'COLORTERM': '24bit'},
      );
    });

    test('should return ansi256 if COLORTERM is set to "256color"', () async {
      await mockedTest(
        (_, _, _) {
          final tu = TermLib();
          expect(tu.colorProfile(), ProfileEnum.ansi256);
        },
        env: {'COLORTERM': '256color'},
      );
    });

    test('should return ansi256 if COLORTERM is set to "yes"', () async {
      await mockedTest(
        (_, _, _) {
          final tu = TermLib();
          expect(tu.colorProfile(), ProfileEnum.ansi256);
        },
        env: {'COLORTERM': 'yes'},
      );
    });

    test('should return ansi256 if COLORTERM is set to "true"', () async {
      await mockedTest(
        (_, _, _) {
          final tu = TermLib();
          expect(tu.colorProfile(), ProfileEnum.ansi256);
        },
        env: {'COLORTERM': 'true'},
      );
    });

    test('should return trueColor if TERM is set to "kitty"', () async {
      await mockedTest(
        (_, _, _) {
          final tu = TermLib();
          expect(tu.colorProfile(), ProfileEnum.trueColor);
        },
        env: {'TERM': 'kitty'},
      );
    });

    test('should return trueColor if TERM is set to "wezterm"', () async {
      await mockedTest(
        (_, _, _) {
          final tu = TermLib();
          expect(tu.colorProfile(), ProfileEnum.trueColor);
        },
        env: {'TERM': 'wezterm'},
      );
    });

    test('should return trueColor if TERM is set to "alacritty"', () async {
      await mockedTest(
        (_, _, _) {
          final tu = TermLib();
          expect(tu.colorProfile(), ProfileEnum.trueColor);
        },
        env: {'TERM': 'alacritty'},
      );
    });

    test('should return ansi16 if TERM is set to "linux"', () async {
      await mockedTest(
        (_, _, _) {
          final tu = TermLib();
          expect(tu.colorProfile(), ProfileEnum.ansi16);
        },
        env: {'TERM': 'linux'},
      );
    });

    test('should return ansi256 if TERM is contains "256color"', () async {
      await mockedTest(
        (_, _, _) {
          final tu = TermLib();
          expect(tu.colorProfile(), ProfileEnum.ansi256);
        },
        env: {'TERM': 'xterm-256colors'},
      );
    });

    test('should return ansi16 if TERM is contains "color"', () async {
      await mockedTest(
        (_, _, _) {
          final tu = TermLib();
          expect(tu.colorProfile(), ProfileEnum.ansi16);
        },
        env: {'TERM': 'xterm-color'},
      );
    });

    test('should return ansi16 if TERM is contains "ansi"', () async {
      await mockedTest(
        (_, _, _) {
          final tu = TermLib();
          expect(tu.colorProfile(), ProfileEnum.ansi16);
        },
        env: {'TERM': 'xterm-ansi'},
      );
    });
  });
}
