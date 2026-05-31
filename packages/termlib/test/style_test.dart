import 'package:termlib/termlib.dart';
import 'package:test/test.dart';

void main() {
  group('Style >', () {
    test('renders plain text when no styles', () {
      const s = Style();
      expect(s('hello world'), equals('hello world'));
    });

    test('renders an empty string', () {
      const s = Style();
      expect(s(''), isEmpty);
    });

    test('is self-closing by default', () {
      final s = Style(fg: Color.ansi(1), profile: ProfileEnum.ansi16);
      expect(s('Hello World'), equals('\x1B[31mHello World\x1B[0m'));
    });

    test('omits the reset when reset: false (open for composition)', () {
      final s = Style(fg: Color.ansi(1), profile: ProfileEnum.ansi16);
      expect(s('Hello World', reset: false), equals('\x1B[31mHello World'));
    });

    test('renders plain text (no reset) when nothing is styled', () {
      const s = Style();
      expect(s('Hello World'), equals('Hello World'));
    });

    test('sets up foreground color', () {
      final s = Style(fg: Color.ansi(1), profile: ProfileEnum.ansi16);
      expect(s('Hello World', reset: false), equals('\x1B[31mHello World'));
    });

    test('sets up background color', () {
      final s = Style(bg: Color.ansi(1), profile: ProfileEnum.ansi16);
      expect(s('Hello World', reset: false), equals('\x1B[41mHello World'));
    });

    test('sets up faint mode', () {
      const s = Style(faint: true);
      expect(s('Hello World', reset: false), equals('\x1B[2mHello World'));
    });

    test('sets up italic mode', () {
      const s = Style(italic: true);
      expect(s('Hello World', reset: false), equals('\x1B[3mHello World'));
    });

    test('sets up underline mode', () {
      const s = Style(underline: Underline.single);
      expect(s('Hello World', reset: false), equals('\x1B[4mHello World'));
    });

    test('sets up blink mode', () {
      const s = Style(blink: true);
      expect(s('Hello World', reset: false), equals('\x1B[5mHello World'));
    });

    test('sets up reverse mode', () {
      const s = Style(reverse: true);
      expect(s('Hello World', reset: false), equals('\x1B[7mHello World'));
    });

    test('sets up crossOut mode', () {
      const s = Style(crossOut: true);
      expect(s('Hello World', reset: false), equals('\x1B[9mHello World'));
    });

    test('sets up overline mode', () {
      const s = Style(overline: true);
      expect(s('Hello World', reset: false), equals('\x1B[53mHello World'));
    });

    test('sets up all modes at the same time', () {
      final s = Style(
        fg: Color.ansi(7),
        bg: Color.ansi(4),
        bold: true,
        faint: true,
        italic: true,
        underline: Underline.single,
        blink: true,
        reverse: true,
        crossOut: true,
        overline: true,
        profile: ProfileEnum.ansi16,
      );
      expect(s('Hello World', reset: false), equals('\x1B[37;44;1;2;3;4;5;7;9;53mHello World'));
    });

    test('applies text styles', () {
      final s = const Style()
          .apply(TextStyle.bold)
          .apply(TextStyle.italic)
          .apply(TextStyle.underline)
          .apply(TextStyle.overline);
      expect(s('Hello World', reset: false), equals('\x1B[1;3;4;53mHello World'));
    });

    test('appends a reset at the end of styled text', () {
      const s = Style(italic: true);
      expect(s('Hello World'), equals('\x1B[3mHello World\x1B[0m'));
    });

    test('emits no reset for empty styled text', () {
      const s = Style(bold: true);
      expect(s(''), isEmpty);
    });
  });

  group('Style copyWith >', () {
    test('derives a variant without mutating the source', () {
      final base = Style(fg: Color.ansi(1), profile: ProfileEnum.ansi16);
      final bolded = base.copyWith(bold: true);
      expect(base('x', reset: false), equals('\x1B[31mx'));
      expect(bolded('x', reset: false), equals('\x1B[31;1mx'));
    });

    test('replaces a color', () {
      final base = Style(fg: Color.ansi(1), profile: ProfileEnum.ansi16);
      final blue = base.copyWith(fg: Color.ansi(4));
      expect(blue('x', reset: false), equals('\x1B[34mx'));
    });
  });

  group('Style equality >', () {
    test('two styles with the same fields are equal', () {
      final a = Style(fg: Color.ansi(1), bold: true);
      final b = Style(fg: Color.ansi(1), bold: true);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('differing fields are not equal', () {
      final a = Style(fg: Color.ansi(1));
      final b = Style(fg: Color.ansi(2));
      expect(a, isNot(equals(b)));
    });

    test('copyWith no-op equals the source', () {
      final a = Style(fg: Color.ansi(1), italic: true);
      expect(a.copyWith(), equals(a));
    });
  });

  group('Style with Profile >', () {
    test('renders no codes and no reset in the noColor profile', () {
      final s = Style(fg: Color.ansi(7), bg: Color.ansi(4), profile: ProfileEnum.noColor);
      expect(s('Hello World'), equals('Hello World'));
    });

    test('uses rgb colors', () {
      final s = Style(
        fg: Color.fromRGBComponent(10, 11, 12),
        bg: Color.fromString('#ABCDEF'),
        profile: ProfileEnum.trueColor,
      );
      expect(s('Hello World', reset: false), equals('\x1B[38;2;10;11;12;48;2;171;205;239mHello World'));
    });
  });

  group('Underline >', () {
    test('single - sets underline sequence', () {
      const s = Style(underline: Underline.single, profile: ProfileEnum.trueColor);
      expect(s('Hello World', reset: false), equals('\x1B[4mHello World'));
    });

    test('single - sets underline color if specified', () {
      final s = Style(
        underline: Underline.single,
        underlineColor: Color.fromRGBComponent(1, 2, 3),
        profile: ProfileEnum.trueColor,
      );
      expect(s('Hello World', reset: false), equals('\x1B[58;2;1;2;3;4mHello World'));
    });

    test('double - sets underline sequence', () {
      const s = Style(underline: Underline.double, profile: ProfileEnum.trueColor);
      expect(s('Hello World', reset: false), equals('\x1B[4:2mHello World'));
    });

    test('double - sets underline color if specified', () {
      final s = Style(
        underline: Underline.double,
        underlineColor: Color.fromRGBComponent(1, 2, 3),
        profile: ProfileEnum.trueColor,
      );
      expect(s('Hello World', reset: false), equals('\x1B[58;2;1;2;3;4:2mHello World'));
    });

    test('curly - sets underline sequence', () {
      const s = Style(underline: Underline.curly, profile: ProfileEnum.trueColor);
      expect(s('Hello World', reset: false), equals('\x1B[4:3mHello World'));
    });

    test('curly - sets underline color if specified', () {
      final s = Style(
        underline: Underline.curly,
        underlineColor: Color.fromRGBComponent(1, 2, 3),
        profile: ProfileEnum.trueColor,
      );
      expect(s('Hello World', reset: false), equals('\x1B[58;2;1;2;3;4:3mHello World'));
    });

    test('dotted - sets underline sequence', () {
      const s = Style(underline: Underline.dotted, profile: ProfileEnum.trueColor);
      expect(s('Hello World', reset: false), equals('\x1B[4:4mHello World'));
    });

    test('dotted - sets underline color if specified', () {
      final s = Style(
        underline: Underline.dotted,
        underlineColor: Color.fromRGBComponent(1, 2, 3),
        profile: ProfileEnum.trueColor,
      );
      expect(s('Hello World', reset: false), equals('\x1B[58;2;1;2;3;4:4mHello World'));
    });

    test('dashed - sets underline sequence', () {
      const s = Style(underline: Underline.dashed, profile: ProfileEnum.trueColor);
      expect(s('Hello World', reset: false), equals('\x1B[4:5mHello World'));
    });

    test('dashed - sets underline color if specified', () {
      final s = Style(
        underline: Underline.dashed,
        underlineColor: Color.fromRGBComponent(1, 2, 3),
        profile: ProfileEnum.trueColor,
      );
      expect(s('Hello World', reset: false), equals('\x1B[58;2;1;2;3;4:5mHello World'));
    });

    test('sets underline color alone', () {
      final s = Style(underlineColor: Color.fromRGBComponent(1, 2, 3), profile: ProfileEnum.trueColor);
      expect(s('Hello World', reset: false), equals('\x1B[58;2;1;2;3mHello World'));
    });
  });

  group('Reset colors >', () {
    test('sets default foreground color', () {
      const s = Style(fg: Color.reset);
      expect(s('Hello World', reset: false), equals('\x1B[39mHello World'));
    });

    test('sets default background color', () {
      const s = Style(bg: Color.reset);
      expect(s('Hello World', reset: false), equals('\x1B[49mHello World'));
    });
  });
}
