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

    test('should support callable style', () {
      final s = Style('');
      expect(s('hello world'), equals('hello world'));
    });

    test('should setup foreground color', () {
      final s = Style('Hello World', profile: ProfileEnum.ansi16)..fg(Ansi16Color(1));
      expect(s.toString(), equals('\x1B[31mHello World\x1B[0m'));
    });

    test('should setup background color', () {
      final s = Style('Hello World', profile: ProfileEnum.ansi16)..bg(Ansi16Color(1));
      expect(s.toString(), equals('\x1B[41mHello World\x1B[0m'));
    });

    test('should setup faint mode', () {
      final s = Style('Hello World')..faint();
      expect(s.toString(), equals('\x1B[2mHello World\x1B[0m'));
    });

    test('should setup italic mode', () {
      final s = Style('Hello World')..italic();
      expect(s.toString(), equals('\x1B[3mHello World\x1B[0m'));
    });

    test('should setup underline mode', () {
      final s = Style('Hello World')..underline();
      expect(s.toString(), equals('\x1B[4mHello World\x1B[0m'));
    });

    test('should setup blink mode', () {
      final s = Style('Hello World')..blink();
      expect(s.toString(), equals('\x1B[5mHello World\x1B[0m'));
    });

    test('should setup Reverse mode', () {
      final s = Style('Hello World')..reverse();
      expect(s.toString(), equals('\x1B[7mHello World\x1B[0m'));
    });

    test('should setup CrossOut mode', () {
      final s = Style('Hello World')..crossout();
      expect(s.toString(), equals('\x1B[9mHello World\x1B[0m'));
    });

    test('should setup Overline mode', () {
      final s = Style('Hello World')..overline();
      expect(s.toString(), equals('\x1B[53mHello World\x1B[0m'));
    });

    test('should be able to setup all modes at the same time', () {
      final s = Style('Hello World', profile: ProfileEnum.ansi16)
        ..fg(Ansi16Color(7))
        ..bg(Ansi16Color(4))
        ..bold()
        ..faint()
        ..italic()
        ..underline()
        ..blink()
        ..reverse()
        ..crossout()
        ..overline();
      expect(s.toString(), equals('\x1B[37;44;1;2;3;4;5;7;9;53mHello World\x1B[0m'));
    });

    test('should be able to apply text styles', () {
      final s = Style('Hello World')
        ..apply(TextStyle.bold)
        ..apply(TextStyle.italic)
        ..apply(TextStyle.underline)
        ..apply(TextStyle.overline);
      expect(s.toString(), equals('\x1B[1;3;4;53mHello World\x1B[0m'));
    });
  });

  group('Style with Profile >', () {
    test('should no render codes when use NoColor profile', () {
      final s = Style('Hello World', profile: ProfileEnum.noColor)
        ..fg(Ansi16Color(7))
        ..bg(Ansi16Color(4));
      expect(s.toString(), equals('Hello World'));
    });

    test('should use rgb colors', () {
      final s = Style('Hello World', profile: ProfileEnum.trueColor)
        ..fg(TrueColor(10, 11, 12))
        ..bg(TrueColor.fromString('#ABCDEF'));
      expect(s.toString(), equals('\x1B[38;2;10;11;12;48;2;171;205;239mHello World\x1B[0m'));
    });
  });

  group('Underline >', () {
    test('single - should set underline sequence', () {
      final s = Style('Hello World', profile: ProfileEnum.trueColor)..underline();
      expect(s.toString(), equals('\x1B[4mHello World\x1B[0m'));
    });

    test('single - should set underline color if specified', () {
      final s = Style('Hello World', profile: ProfileEnum.trueColor)..underline(TrueColor(1, 2, 3));
      expect(s.toString(), equals('\x1B[58;2;1;2;3;4mHello World\x1B[0m'));
    });

    test('double - should set underline sequence', () {
      final s = Style('Hello World', profile: ProfileEnum.trueColor)..doubleUnderline();
      expect(s.toString(), equals('\x1B[4:2mHello World\x1B[0m'));
    });

    test('double - should set underline color if specified', () {
      final s = Style('Hello World', profile: ProfileEnum.trueColor)..doubleUnderline(TrueColor(1, 2, 3));
      expect(s.toString(), equals('\x1B[58;2;1;2;3;4:2mHello World\x1B[0m'));
    });

    test('curly - should set underline sequence', () {
      final s = Style('Hello World', profile: ProfileEnum.trueColor)..curlyUnderline();
      expect(s.toString(), equals('\x1B[4:3mHello World\x1B[0m'));
    });

    test('curly - should set underline color if specified', () {
      final s = Style('Hello World', profile: ProfileEnum.trueColor)..curlyUnderline(TrueColor(1, 2, 3));
      expect(s.toString(), equals('\x1B[58;2;1;2;3;4:3mHello World\x1B[0m'));
    });

    test('dotted - should set underline sequence', () {
      final s = Style('Hello World', profile: ProfileEnum.trueColor)..dottedUnderline();
      expect(s.toString(), equals('\x1B[4:4mHello World\x1B[0m'));
    });

    test('dotted - should set underline color if specified', () {
      final s = Style('Hello World', profile: ProfileEnum.trueColor)..dottedUnderline(TrueColor(1, 2, 3));
      expect(s.toString(), equals('\x1B[58;2;1;2;3;4:4mHello World\x1B[0m'));
    });

    test('dashed - should set underline sequence', () {
      final s = Style('Hello World', profile: ProfileEnum.trueColor)..dashedUnderline();
      expect(s.toString(), equals('\x1B[4:5mHello World\x1B[0m'));
    });

    test('dashed - should set underline color if specified', () {
      final s = Style('Hello World', profile: ProfileEnum.trueColor)..dashedUnderline(TrueColor(1, 2, 3));
      expect(s.toString(), equals('\x1B[58;2;1;2;3;4:5mHello World\x1B[0m'));
    });

    test('set underline color', () {
      final s = Style('Hello World', profile: ProfileEnum.trueColor)..underlineColor(TrueColor(1, 2, 3));
      expect(s.toString(), equals('\x1B[58;2;1;2;3mHello World\x1B[0m'));
    });
  });
}
