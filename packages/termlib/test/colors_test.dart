import 'package:termlib/termlib.dart';
import 'package:test/test.dart';

void main() {
  group('Color make >', () {
    test('empty string', () {
      expect(Color(''), const NoColor());
    });

    test('from x11 name', () {
      expect(Color('papayaWhip'), TrueColor(0xff, 0xef, 0xd5));
    });

    test('from 16 base color', () {
      expect(Color('1'), Ansi16Color(1));
    });

    test('from 256 base color', () {
      expect(Color('230'), Ansi256Color(230));
    });

    test('from hex string', () {
      expect(Color('#fafbfc'), TrueColor(0xfa, 0xfb, 0xfc));
    });

    test('return NoColor if invalid value', () {
      expect(Color('foobar'), const NoColor());
    });

    test('return default color if invalid value', () {
      final defaultColor = Ansi16Color(7);
      expect(Color('foobar', defaultColor: defaultColor), defaultColor);
    });
  });

  group('NoColor >', () {
    test('sequence should return an empty string', () {
      expect(const NoColor().sequence(), '');
    });

    test('toString should return an empty string', () {
      expect(const NoColor().toString(), '');
    });

    test('equatable', () {
      expect(const NoColor(), const NoColor());
    });
  });

  group('Ansi16Color >', () {
    test('should throw ArgumentError for invalid color value', () {
      expect(() => Ansi16Color(-1), throwsArgumentError);
      expect(() => Ansi16Color(16), throwsArgumentError);
    });

    test('sequence should return the correct ANSI sequence for foreground color', () {
      expect(Ansi16Color(0).sequence(), '30');
      expect(Ansi16Color(7).sequence(), '37');
    });

    test('sequence should return the correct ANSI sequence for background color', () {
      expect(Ansi16Color(0).sequence(background: true), '40');
      expect(Ansi16Color(14).sequence(background: true), '106');
    });

    test('toString should return the correct value', () {
      expect(Ansi16Color(0).toString(), '0');
      expect(Ansi16Color(14).toString(), '14');
    });

    test('equatable', () {
      expect(Ansi16Color(0), Ansi16Color(0));
      expect(Ansi16Color(0), isNot(Ansi16Color(1)));
    });
  });

  group('Ansi256Color >', () {
    test('should throw ArgumentError for invalid color value', () {
      expect(() => Ansi256Color(-1), throwsArgumentError);
      expect(() => Ansi256Color(256), throwsArgumentError);
    });

    test('sequence should return the correct ANSI sequence for foreground color', () {
      expect(Ansi256Color(0).sequence(), '38;5;0');
      expect(Ansi256Color(255).sequence(), '38;5;255');
    });

    test('sequence should return the correct ANSI sequence for background color', () {
      expect(Ansi256Color(0).sequence(background: true), '48;5;0');
      expect(Ansi256Color(255).sequence(background: true), '48;5;255');
    });

    test('toString should return the correct hex value', () {
      expect(Ansi256Color(0).toString(), '0');
      expect(Ansi256Color(255).toString(), '255');
    });

    test('toAnsi16Color on graycale should return the correct value', () {
      expect(Ansi256Color(235).toAnsi16Color(), Ansi16Color(0));
      expect(Ansi256Color(245).toAnsi16Color(), Ansi16Color(7));
      expect(Ansi256Color(252).toAnsi16Color(), Ansi16Color(15));
      expect(Ansi256Color(196).toAnsi16Color(), Ansi16Color(9));
    });

    test('toTrueColor should return the correct value', () {
      expect(Ansi256Color(0).toTrueColor(), TrueColor(0, 0, 0));
      expect(Ansi256Color(255).toTrueColor(), TrueColor(0xee, 0xee, 0xee));
    });

    test('equatable', () {
      expect(Ansi256Color(0), Ansi256Color(0));
      expect(Ansi256Color(0), isNot(Ansi256Color(1)));
    });
  });

  group('TrueColor >', () {
    test('sequence should return the correct ANSI sequence for foreground color', () {
      expect(TrueColor(255, 0, 0).sequence(), '38;2;255;0;0');
    });

    test('sequence should return the correct ANSI sequence for background color', () {
      expect(TrueColor(0, 255, 0).sequence(background: true), '48;2;0;255;0');
    });

    test('toString should return the correct hex value', () {
      expect(TrueColor(0, 0, 255).toString(), '#0000ff');
    });

    test('should create TrueColor from hex string', () {
      final color = TrueColor.fromString('#ff00ff');
      expect(color, isNotNull);
      expect(color.sequence(), '38;2;255;0;255');
    });

    test('should create TrueColor from short hex string', () {
      final color = TrueColor.fromString('#f0f');
      expect(color, isNotNull);
      expect(color.sequence(), '38;2;255;0;255');
    });

    test('should create TrueColor from short hex string without #', () {
      final color = TrueColor.fromString('f0f');
      expect(color, isNotNull);
      expect(color.sequence(), '38;2;255;0;255');
    });

    test('should create TrueColor from hex string without #', () {
      final color = TrueColor.fromString('ff00ff');
      expect(color, isNotNull);
      expect(color.sequence(), '38;2;255;0;255');
    });

    test('should throw ArgumentError for invalid hex string', () {
      expect(() => TrueColor.fromString('#ff00ff00'), throwsArgumentError);
      expect(() => TrueColor.fromString('#ff00'), throwsArgumentError);
    });

    test('toAnsi16 should return the correct value', () {
      expect(TrueColor(0, 0, 0).toAnsi16Color(), Ansi16Color(0));
      expect(TrueColor(0x00, 0xff, 0xff).toAnsi16Color(), Ansi16Color(14));
      expect(TrueColor(0x88, 0x00, 0x00).toAnsi16Color(), Ansi16Color(1));
    });

    test('toAnsi256 shoul return the correct value', () {
      expect(TrueColor(0, 0, 0).toAnsi256Color(), Ansi256Color(16));
      expect(TrueColor(0x00, 0xff, 0xff).toAnsi256Color(), Ansi256Color(51));
      expect(TrueColor(0xff, 0x00, 0x00).toAnsi256Color(), Ansi256Color(196));
      expect(TrueColor(0xdd, 0xdd, 0xdd).toAnsi256Color(), Ansi256Color(253));
      expect(TrueColor(0xfe, 0xfe, 0xfe).toAnsi256Color(), Ansi256Color(231));
    });

    test('equatable', () {
      expect(TrueColor(0, 1, 2), TrueColor(0, 1, 2));
      expect(TrueColor(0, 0, 0), isNot(TrueColor(0, 0, 1)));
    });
  });

  group('Color convert >', () {
    test('to NoColor', () {
      expect(const NoColor().convert(ProfileEnum.noColor), const NoColor());
      expect(Ansi16Color(0).convert(ProfileEnum.noColor), const NoColor());
      expect(Ansi256Color(0).convert(ProfileEnum.noColor), const NoColor());
      expect(TrueColor(0, 0, 0).convert(ProfileEnum.noColor), const NoColor());
    });

    test('to ansi16', () {
      expect(const NoColor().convert(ProfileEnum.ansi16), const NoColor());
      expect(Ansi16Color(0).convert(ProfileEnum.ansi16), Ansi16Color(0));
      expect(Ansi256Color(0).convert(ProfileEnum.ansi16), Ansi16Color(0));
      expect(TrueColor(1, 2, 3).convert(ProfileEnum.ansi16), Ansi16Color(0));
    });

    test('to ansi256', () {
      expect(const NoColor().convert(ProfileEnum.ansi256), const NoColor());
      expect(Ansi16Color(0).convert(ProfileEnum.ansi256), Ansi256Color(0));
      expect(Ansi256Color(0).convert(ProfileEnum.ansi256), Ansi256Color(0));
      expect(TrueColor(0, 0, 0).convert(ProfileEnum.ansi256), Ansi256Color(16));
    });

    test('to TrueColor', () {
      expect(const NoColor().convert(ProfileEnum.trueColor), const NoColor());
      expect(Ansi16Color(13).convert(ProfileEnum.trueColor), TrueColor(0xff, 0, 0xff));
      expect(Ansi256Color(230).convert(ProfileEnum.trueColor), TrueColor(0xff, 0xff, 0xd7));
      expect(TrueColor(1, 2, 3).convert(ProfileEnum.trueColor), TrueColor(1, 2, 3));
    });
  });

  group('Color base colors >', () {
    test('should return the correct color for base color', () {
      expect(Color.black, Ansi16Color(0));
      expect(Color.red, Ansi16Color(1));
      expect(Color.green, Ansi16Color(2));
      expect(Color.yellow, Ansi16Color(3));
      expect(Color.blue, Ansi16Color(4));
      expect(Color.magenta, Ansi16Color(5));
      expect(Color.cyan, Ansi16Color(6));
      expect(Color.white, Ansi16Color(7));
      expect(Color.brightBlack, Ansi16Color(8));
      expect(Color.brightRed, Ansi16Color(9));
      expect(Color.brightGreen, Ansi16Color(10));
      expect(Color.brightYellow, Ansi16Color(11));
      expect(Color.brightBlue, Ansi16Color(12));
      expect(Color.brightMagenta, Ansi16Color(13));
      expect(Color.brightCyan, Ansi16Color(14));
      expect(Color.brightWhite, Ansi16Color(15));
    });
  });
}
