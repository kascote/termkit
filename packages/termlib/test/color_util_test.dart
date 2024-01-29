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
}
