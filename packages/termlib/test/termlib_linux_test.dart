import 'package:termlib/termlib.dart';
import 'package:test/test.dart';

import 'termlib_mock.dart';

void main() {
  final stdoutMock = MockStdout();

  group('colorProfile >', () {
    test('should return TrueColor if GOOGLE_CLOUD_SHELL is set', () {
      final tu = TermLib(stdoutAdapter: stdoutMock, env: {'GOOGLE_CLOUD_SHELL': 'true'});
      expect(tu.colorProfile(), ProfileEnum.trueColor);
    });

    test('should return TrueColor if COLORTERM is set to "truecolor"', () {
      final tu = TermLib(stdoutAdapter: stdoutMock, env: {'COLORTERM': 'truecolor'});
      expect(tu.colorProfile(), ProfileEnum.trueColor);
    });

    test('should return TrueColor if COLORTERM is set to "24bit"', () {
      final tu = TermLib(stdoutAdapter: stdoutMock, env: {'COLORTERM': '24bit'});
      expect(tu.colorProfile(), ProfileEnum.trueColor);
    });

    test('should return ansi256 if COLORTERM is set to "256color"', () {
      final tu = TermLib(stdoutAdapter: stdoutMock, env: {'COLORTERM': '256color'});
      expect(tu.colorProfile(), ProfileEnum.ansi256);
    });

    test('should return ansi256 if COLORTERM is set to "yes"', () {
      final tu = TermLib(stdoutAdapter: stdoutMock, env: {'COLORTERM': 'yes'});
      expect(tu.colorProfile(), ProfileEnum.ansi256);
    });

    test('should return ansi256 if COLORTERM is set to "true"', () {
      final tu = TermLib(stdoutAdapter: stdoutMock, env: {'COLORTERM': 'true'});
      expect(tu.colorProfile(), ProfileEnum.ansi256);
    });

    test('should return trueColor if TERM is set to "kitty"', () {
      final tu = TermLib(stdoutAdapter: stdoutMock, env: {'TERM': 'kitty'});
      expect(tu.colorProfile(), ProfileEnum.trueColor);
    });

    test('should return trueColor if TERM is set to "wezterm"', () {
      final tu = TermLib(stdoutAdapter: stdoutMock, env: {'TERM': 'wezterm'});
      expect(tu.colorProfile(), ProfileEnum.trueColor);
    });

    test('should return trueColor if TERM is set to "alacritty"', () {
      final tu = TermLib(stdoutAdapter: stdoutMock, env: {'TERM': 'alacritty'});
      expect(tu.colorProfile(), ProfileEnum.trueColor);
    });

    test('should return ansi16 if TERM is set to "linux"', () {
      final tu = TermLib(stdoutAdapter: stdoutMock, env: {'TERM': 'linux'});
      expect(tu.colorProfile(), ProfileEnum.ansi16);
    });

    test('should return ansi256 if TERM is contains "256color"', () {
      final tu = TermLib(stdoutAdapter: stdoutMock, env: {'TERM': 'xterm-256colors'});
      expect(tu.colorProfile(), ProfileEnum.ansi256);
    });

    test('should return ansi16 if TERM is contains "color"', () {
      final tu = TermLib(stdoutAdapter: stdoutMock, env: {'TERM': 'xterm-color'});
      expect(tu.colorProfile(), ProfileEnum.ansi16);
    });

    test('should return ansi16 if TERM is contains "ansi"', () {
      final tu = TermLib(stdoutAdapter: stdoutMock, env: {'TERM': 'xterm-ansi'});
      expect(tu.colorProfile(), ProfileEnum.ansi16);
    });
  });
}
