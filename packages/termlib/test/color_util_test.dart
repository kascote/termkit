import 'package:termlib/color_util.dart';
import 'package:termlib/src/colors.dart';
import 'package:termlib/src/shared/color_util.dart';
import 'package:test/test.dart';

void main() {
  group('oscColor', () {
    test('must return null if can not parse the sequence', () {
      final c = oscColor('some:1111/1211/1311');
      expect(c, isNull);
    });

    test('convert a osc10 sequence to TrueColor color', () {
      final c = oscColor('rgb:1111/ab12/d1d1');
      expect(c, isA<TrueColor>());
      expect(c!.hex, equals('#11abd1'));
    });
  });

  group('findClosestAnsiIndex', () {
    test('must return the closest ANSI color', () {
      final c = findClosestAnsiIndex(128, 128, 128);
      expect(c, equals(63));
    });
  });

  group('colorLerp', () {
    test('must return the correct color', () {
      final lerp = colorLerp(TrueColor(255, 0, 0), TrueColor(0, 255, 0));
      expect(lerp(0.5), TrueColor(0x80, 0x80, 0));
    });
  });

  group('rgbToHsv', () {
    test('must return the correct color', () {
      final hsv1 = rgbToHsv(TrueColor(100, 100, 80));
      expect(hsv1, equals((h: 60.00000000000003, s: 20.0, v: 39.21568627450981)));

      final hsv2 = rgbToHsv(TrueColor(100, 200, 80));
      expect(hsv2, equals((h: 109.99999999999997, s: 60.0, v: 78.43137254901961)));

      final hsv3 = rgbToHsv(TrueColor(100, 100, 120));
      expect(hsv3, equals((h: 240.00000000000003, s: 16.666666666666664, v: 47.05882352941176)));

      final hsv4 = rgbToHsv(TrueColor(200, 200, 20));
      expect(hsv4, equals((h: 59.999999999999986, s: 89.99999999999999, v: 78.43137254901961)));
    });
  });

  group('calculateRedMeanDistance', () {
    test('', () {
      final x = calculateRedMeanDistance(TrueColor(0, 0, 0), TrueColor(255, 255, 255));
      expect(x, equals(303078.1932290478));
    });
  });
}
