import 'package:termlib/termlib.dart';
import 'package:test/test.dart';

void main() {
  group('Style >', () {
    test('should return the text if no styles', () {
      final s = Style('hello world');
      expect(s.toString(), equals('hello world'));
    });

    test('should return an empty string', () {
      final s = Style('');
      expect(s.toString(), isEmpty);
    });

    test('should setup foreground color', () {
      final s = Style('Hello World', profile: ProfileEnum.ansi16)..setFg(Ansi16Color(1));
      expect(s.toString(), equals('\x1B[31mHello World\x1B[0m'));
    });

    test('should setup background color', () {
      final s = Style('Hello World', profile: ProfileEnum.ansi16)..setBg(Ansi16Color(1));
      expect(s.toString(), equals('\x1B[41mHello World\x1B[0m'));
    });

    test('should setup faint mode', () {
      final s = Style('Hello World')..setFaint();
      expect(s.toString(), equals('\x1B[2mHello World\x1B[0m'));
    });

    test('should setup italic mode', () {
      final s = Style('Hello World')..setItalic();
      expect(s.toString(), equals('\x1B[3mHello World\x1B[0m'));
    });

    test('should setup underline mode', () {
      final s = Style('Hello World')..setUnderline();
      expect(s.toString(), equals('\x1B[4mHello World\x1B[0m'));
    });

    test('should setup blink mode', () {
      final s = Style('Hello World')..setBlink();
      expect(s.toString(), equals('\x1B[5mHello World\x1B[0m'));
    });

    test('should setup Reverse mode', () {
      final s = Style('Hello World')..setReverse();
      expect(s.toString(), equals('\x1B[7mHello World\x1B[0m'));
    });

    test('should setup CrossOut mode', () {
      final s = Style('Hello World')..setCrossOut();
      expect(s.toString(), equals('\x1B[9mHello World\x1B[0m'));
    });

    test('should setup Overline mode', () {
      final s = Style('Hello World')..setOverline();
      expect(s.toString(), equals('\x1B[53mHello World\x1B[0m'));
    });

    test('should be able to setup all modes at the same time', () {
      final s = Style('Hello World', profile: ProfileEnum.ansi16)
        ..setFg(Ansi16Color(7))
        ..setBg(Ansi16Color(4))
        ..setBold()
        ..setFaint()
        ..setItalic()
        ..setUnderline()
        ..setBlink()
        ..setReverse()
        ..setCrossOut()
        ..setOverline();
      expect(s.toString(), equals('\x1B[37;44;1;2;3;4;5;7;9;53mHello World\x1B[0m'));
    });
  });

  group('Style with Profile >', () {
    test('should no render codes when use NoColor profile', () {
      final s = Style('Hello World', profile: ProfileEnum.noColor)
        ..setFg(Ansi16Color(7))
        ..setBg(Ansi16Color(4));
      expect(s.toString(), equals('Hello World'));
    });

    test('should use rgb colors', () {
      final s = Style('Hello World', profile: ProfileEnum.trueColor)
        ..setFg(TrueColor(10, 11, 12))
        ..setBg(TrueColor.fromString('#ABCDEF'));
      expect(s.toString(), equals('\x1B[38;2;10;11;12;48;2;171;205;239mHello World\x1B[0m'));
    });
  });
}
