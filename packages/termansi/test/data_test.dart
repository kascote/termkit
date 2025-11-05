import 'package:termansi/termansi.dart';
import 'package:test/test.dart';

void main() {
  group('ansiHex data >', () {
    test('has exactly 256 entries', () {
      expect(ansiHex, hasLength(256));
    });

    test('all entries are integers', () {
      for (var i = 0; i < ansiHex.length; i++) {
        final color = ansiHex[i];
        expect(color, isA<int>(), reason: 'Entry at index $i should be int');
        expect(color, greaterThanOrEqualTo(0));
        expect(color, lessThanOrEqualTo(0xFFFFFF));
      }
    });

    test('first entry is black', () {
      expect(ansiHex[0], equals(0x000000));
    });

    test('last entry exists and is valid', () {
      expect(ansiHex[255], isA<int>());
    });

    test('standard colors (0-15) are present', () {
      // Basic 16 colors should be at indices 0-15
      expect(ansiHex.length, greaterThanOrEqualTo(16));
      for (var i = 0; i < 16; i++) {
        expect(ansiHex[i], isA<int>());
      }
    });

    test('grayscale ramp (232-255) exists', () {
      // 256-color palette has grayscale at 232-255
      for (var i = 232; i < 256; i++) {
        expect(ansiHex[i], isA<int>());
      }
    });

    test('no duplicate entries in standard colors', () {
      final first16 = ansiHex.take(16).toSet();
      expect(first16.length, equals(16), reason: 'First 16 colors should be unique');
    });
  });

  group('x11Colors data >', () {
    test('is not empty', () {
      expect(x11Colors, isNotEmpty);
    });

    test('has reasonable number of colors', () {
      // X11 has approximately 140+ named colors
      expect(x11Colors.length, greaterThan(100));
    });

    test('all values are valid integers', () {
      x11Colors.forEach((name, color) {
        expect(color, isA<int>(), reason: 'Value for $name should be int');
        expect(color, greaterThanOrEqualTo(0));
        expect(color, lessThanOrEqualTo(0xFFFFFF));
      });
    });

    test('all keys are non-empty strings', () {
      x11Colors.forEach((name, color) {
        expect(name, isNotEmpty, reason: 'Empty color name found');
      });
    });

    test('contains expected standard color names', () {
      expect(x11Colors, containsPair('red', anything));
      expect(x11Colors, containsPair('green', anything));
      expect(x11Colors, containsPair('blue', anything));
      expect(x11Colors, containsPair('white', anything));
      expect(x11Colors, containsPair('black', anything));
    });

    test('contains common extended color names', () {
      expect(x11Colors, containsPair('aliceBlue', anything));
      expect(x11Colors, containsPair('antiqueWhite', anything));
      expect(x11Colors, containsPair('cornflowerBlue', anything));
    });

    test('red is actually red', () {
      final red = x11Colors['red'];
      expect(red, equals(0xFF0000));
    });

    test('white is actually white', () {
      final white = x11Colors['white'];
      expect(white, equals(0xFFFFFF));
    });

    test('black is actually black', () {
      final black = x11Colors['black'];
      expect(black, equals(0x000000));
    });

    test('no duplicate color values in common colors', () {
      final commonColors = ['red', 'green', 'blue', 'yellow', 'cyan', 'magenta'];
      final values = commonColors.map((name) => x11Colors[name]).where((color) => color != null).toSet();
      expect(values.length, equals(commonColors.length));
    });

    test('color names use camelCase', () {
      // X11 colors use camelCase like 'aliceBlue', 'antiqueWhite'
      expect(x11Colors, containsPair('aliceBlue', anything));
      expect(x11Colors, containsPair('blanchedAlmond', anything));
    });
  });

  group('Data integrity >', () {
    test('ansiHex and x11Colors are independent', () {
      // Just verify both exist and are separate data structures
      expect(ansiHex, isA<List<int>>());
      expect(x11Colors, isA<Map<String, int>>());
    });

    test('ansiHex can be indexed by 256-color codes', () {
      // Should be able to use any valid 256-color code (0-255)
      expect(() => ansiHex[0], returnsNormally);
      expect(() => ansiHex[127], returnsNormally);
      expect(() => ansiHex[255], returnsNormally);
    });

    test('x11Colors can be queried by name', () {
      expect(x11Colors['red'], isNotNull);
      expect(x11Colors['nonexistentcolor'], isNull);
    });
  });
}
