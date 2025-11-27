import 'package:termlib/termlib.dart';
import 'package:test/test.dart';

void main() {
  group('Color make >', () {
    test('empty string', () {
      expect(Color.fromString(''), Color.noColor);
    });

    test('from x11 name', () {
      expect(Color.fromString('papayaWhip'), Color.fromRGBComponent(0xff, 0xef, 0xd5));
    });

    test('from 16 base color', () {
      expect(Color.ansi(1), Color.red);
    });

    test('from 256 base color', () {
      expect(Color.indexed(230).value, 230);
    });

    test('from hex string', () {
      expect(Color.fromString('#fafbfc'), Color.fromRGBComponent(0xfa, 0xfb, 0xfc));
    });

    test('fromInt auto-detects color kind', () {
      // ANSI range (0-15)
      expect(Color.fromInt(0), Color.ansi(0));
      expect(Color.fromInt(15), Color.ansi(15));
      expect(Color.fromInt(1).kind, ColorKind.ansi);

      // Indexed range (16-255)
      expect(Color.fromInt(16), Color.indexed(16));
      expect(Color.fromInt(255), Color.indexed(255));
      expect(Color.fromInt(128).kind, ColorKind.indexed);

      // RGB range (256+)
      expect(Color.fromInt(256), Color.fromRGB(256));
      expect(Color.fromInt(0xFF0000), Color.fromRGB(0xFF0000));
      expect(Color.fromInt(0xFFFFFF).kind, ColorKind.rgb);
    });

    test('fromInt throws on negative', () {
      expect(() => Color.fromInt(-1), throwsArgumentError);
    });

    test('return default color if invalid value', () {
      expect(() => Color.fromString('foobar'), throwsA(isA<FormatException>()));
      expect(() => Color.fromString('#foobar'), throwsA(isA<FormatException>()));
      expect(() => Color.fromString('foobar'), throwsA(isA<FormatException>()));
    });
  });

  group('NoColor >', () {
    test('sequence should return an empty string', () {
      expect(Color.noColor.sequence(), '');
    });

    test('toString should return an empty string', () {
      expect(Color.noColor.toString(), 'Color(0, noColor)');
    });

    test('equatable', () {
      expect(Color.noColor, Color.noColor);
    });
  });

  group('Ansi16Color >', () {
    test('should throw ArgumentError for invalid color value', () {
      expect(() => Color.ansi(16), throwsArgumentError);
    });

    test('sequence should return the correct ANSI sequence for foreground color', () {
      expect(Color.ansi(0).sequence(), '30');
      expect(Color.ansi(7).sequence(), '37');
    });

    test('sequence should return the correct ANSI sequence for background color', () {
      expect(Color.ansi(0).sequence(background: true), '40');
      expect(Color.ansi(14).sequence(background: true), '106');
    });

    test('toString should return the debug data', () {
      expect(Color.ansi(0).toString(), 'Color(0, ansi)');
      expect(Color.ansi(14).toString(), 'Color(14, ansi)');
    });

    test('equatable', () {
      expect(Color.ansi(0), Color.black);
      expect(Color.ansi(0), isNot(Color.ansi(1)));
    });

    test('reset fg', () {
      expect(Color.reset.sequence(), '39');
    });

    test('reset bg', () {
      expect(Color.reset.sequence(background: true), '49');
    });
  });

  group('Ansi256Color >', () {
    test('should throw ArgumentError for invalid color value', () {
      expect(() => Color.indexed(-1), throwsArgumentError);
      expect(() => Color.indexed(256), throwsArgumentError);
    });

    test('sequence should return the correct ANSI sequence for foreground color', () {
      expect(Color.indexed(0).sequence(), '38;5;0');
      expect(Color.indexed(255).sequence(), '38;5;255');
    });

    test('sequence should return the correct ANSI sequence for background color', () {
      expect(Color.indexed(0).sequence(background: true), '48;5;0');
      expect(Color.indexed(255).sequence(background: true), '48;5;255');
    });

    test('toString should return the debug data', () {
      expect(Color.indexed(0).toString(), 'Color(0, indexed)');
      expect(Color.indexed(255).toString(), 'Color(255, indexed)');
    });

    test('indexedToAnsi on graycale should return the correct value', () {
      expect(Color.indexed(232).convert(ColorKind.ansi), Color.black);
      expect(Color.indexed(236).convert(ColorKind.ansi), Color.black);
      expect(Color.indexed(237).convert(ColorKind.ansi), Color.gray);
      expect(Color.indexed(249).convert(ColorKind.ansi), Color.gray);
      expect(Color.indexed(250).convert(ColorKind.ansi), Color.white);
      expect(Color.indexed(255).convert(ColorKind.ansi), Color.white);
    });

    test('indexedToAnsi on colors', () {
      expect(Color.indexed(196).convert(ColorKind.ansi), Color.brightRed);
      expect(Color.indexed(21).convert(ColorKind.ansi), Color.brightBlue); // RGB(0,0,255)
      expect(Color.indexed(22).convert(ColorKind.ansi), Color.green);
      expect(Color.indexed(46).convert(ColorKind.ansi), Color.brightGreen);
      expect(Color.indexed(82).convert(ColorKind.ansi), Color.brightGreen); // RGB(95,255,0) lime
    });

    test('equatable', () {
      expect(Color.indexed(0), Color.indexed(0));
      expect(Color.indexed(0), isNot(Color.indexed(1)));
    });
  });

  group('TrueColor >', () {
    test('sequence should return the correct ANSI sequence for foreground color', () {
      expect(Color.fromRGBComponent(255, 0, 0).sequence(), '38;2;255;0;0');
    });

    test('sequence should return the correct ANSI sequence for background color', () {
      expect(Color.fromRGBComponent(0, 255, 0).sequence(background: true), '48;2;0;255;0');
    });

    test('toString should return the debug data', () {
      expect(Color.fromRGBComponent(0, 0, 255).toString(), 'Color(255, rgb)');
    });

    test('should create TrueColor from hex string', () {
      final color = Color.fromString('#ff00ff');
      expect(color, isNotNull);
      expect(color.sequence(), '38;2;255;0;255');
    });

    test('should create TrueColor from short hex string', () {
      final color = Color.fromString('#f0f');
      expect(color, isNotNull);
      expect(color.sequence(), '38;2;255;0;255');
    });

    test('should create TrueColor from short hex string without #', () {
      final color = Color.fromString('f0f');
      expect(color, isNotNull);
      expect(color.sequence(), '38;2;255;0;255');
    });

    test('should create TrueColor from hex string without #', () {
      final color = Color.fromString('ff00ff');
      expect(color, isNotNull);
      expect(color.sequence(), '38;2;255;0;255');
    });

    test('should throw ColorFormatException for invalid hex string', () {
      expect(() => Color.fromString('#ff00ff00'), throwsA(isA<FormatException>()));
      expect(() => Color.fromString('#ff00'), throwsA(isA<FormatException>()));
    });

    test('toAnsi16 should return the correct value', () {
      expect(Color.fromRGBComponent(0, 0, 0).rgbToAnsiColor(), Color.black);
      expect(Color.fromRGBComponent(0x00, 0xff, 0xff).rgbToAnsiColor(), Color.brightCyan);
      expect(Color.fromRGBComponent(0x88, 0x00, 0x00).rgbToAnsiColor(), Color.red);
    });

    test('toAnsi256 shoul return the correct value', () {
      expect(Color.fromRGBComponent(0, 0, 0).rgbToIndexedColor(), Color.indexed(16));
      expect(Color.fromRGBComponent(0x00, 0xff, 0xff).rgbToIndexedColor(), Color.indexed(51));
      expect(Color.fromRGBComponent(0xff, 0x00, 0x00).rgbToIndexedColor(), Color.indexed(196));
      expect(Color.fromRGBComponent(0xdd, 0xdd, 0xdd).rgbToIndexedColor(), Color.indexed(253));
      expect(Color.fromRGBComponent(0xfe, 0xfe, 0xfe).rgbToIndexedColor(), Color.indexed(231));
    });

    test('equatable', () {
      expect(Color.fromRGBComponent(0, 1, 2), Color.fromRGBComponent(0, 1, 2));
      expect(Color.fromRGBComponent(0, 0, 0), isNot(Color.fromRGBComponent(0, 0, 1)));
    });
  });

  group('Color convert >', () {
    test('to NoColor', () {
      expect(Color.noColor.convert(ColorKind.noColor), Color.noColor);
      expect(Color.ansi(0).convert(ColorKind.noColor), Color.noColor);
      expect(Color.indexed(0).convert(ColorKind.noColor), Color.noColor);
      expect(Color.fromRGBComponent(0, 0, 0).convert(ColorKind.noColor), Color.noColor);
    });

    test('to ansi16', () {
      expect(Color.noColor.convert(ColorKind.ansi), Color.noColor);
      expect(Color.ansi(0).convert(ColorKind.ansi), Color.black);
      expect(Color.indexed(0).convert(ColorKind.ansi), Color.black);
      expect(Color.fromRGBComponent(1, 2, 3).convert(ColorKind.ansi), Color.black);
    });

    test('to ansi256', () {
      expect(Color.noColor.convert(ColorKind.indexed), Color.noColor);
      expect(Color.ansi(0).convert(ColorKind.indexed), Color.ansi(0));
      expect(Color.indexed(0).convert(ColorKind.indexed), Color.indexed(0));
      expect(Color.fromRGBComponent(0, 0, 0).convert(ColorKind.indexed), Color.indexed(16));
    });

    test('to TrueColor', () {
      expect(Color.noColor.convert(ColorKind.rgb), Color.noColor);
      expect(Color.ansi(13).convert(ColorKind.rgb), Color.ansi(13));
      expect(Color.indexed(230).convert(ColorKind.rgb), Color.indexed(230));
      expect(Color.fromRGBComponent(1, 2, 3).convert(ColorKind.rgb), Color.fromRGBComponent(1, 2, 3));
    });
  });

  group('Color base colors >', () {
    test('should return the correct color for base color', () {
      expect(Color.black, Color.ansi(0));
      expect(Color.red, Color.ansi(1));
      expect(Color.green, Color.ansi(2));
      expect(Color.yellow, Color.ansi(3));
      expect(Color.blue, Color.ansi(4));
      expect(Color.magenta, Color.ansi(5));
      expect(Color.cyan, Color.ansi(6));
      expect(Color.gray, Color.ansi(7));
      expect(Color.darkGray, Color.ansi(8));
      expect(Color.brightRed, Color.ansi(9));
      expect(Color.brightGreen, Color.ansi(10));
      expect(Color.brightYellow, Color.ansi(11));
      expect(Color.brightBlue, Color.ansi(12));
      expect(Color.brightMagenta, Color.ansi(13));
      expect(Color.brightCyan, Color.ansi(14));
      expect(Color.white, Color.ansi(15));
    });
  });
}
