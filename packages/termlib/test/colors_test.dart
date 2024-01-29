import 'package:termlib/src/colors.dart';
import 'package:test/test.dart';

void main() {
  group('NoColor', () {
    test('sequence should return an empty string', () {
      expect(const NoColor().sequence(), '');
    });

    test('toString should return an empty string', () {
      expect(const NoColor().toString(), '');
    });
  });

  group('Ansi16Color', () {
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

    test('toString should return the correct hex value', () {
      expect(Ansi16Color(0).toString(), '0');
      expect(Ansi16Color(14).toString(), '14');
    });

    test('equatable', () {
      expect(Ansi16Color(0), Ansi16Color(0));
      expect(Ansi16Color(0), isNot(Ansi16Color(1)));
    });
  });

  group('Ansi256Color', () {
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

    test('equatable', () {
      expect(Ansi256Color(0), Ansi256Color(0));
      expect(Ansi256Color(0), isNot(Ansi256Color(1)));
    });
  });

  group('TrueColor', () {
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

    test('equatable', () {
      expect(TrueColor(0, 0, 0), TrueColor(0, 0, 0));
      expect(TrueColor(0, 0, 0), isNot(TrueColor(0, 0, 1)));
    });
  });
}
