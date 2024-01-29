import 'package:termlib/src/colors.dart';
import 'package:termlib/src/profile.dart';
import 'package:test/test.dart';

void main() {
  group('Profile > default profile >', () {
    final profile = Profile();
    test('must return NoColor if can not resolve a color', () {
      expect(profile.getColor(''), const NoColor());
    });

    test('must return Ansi256Color', () {
      final c = profile.getColor('1');
      expect(c, isA<Ansi256Color>());
      expect((c as Ansi256Color).code, 1);
    });

    test('must return Ansi256Color', () {
      final c = profile.getColor('230');
      expect(c, isA<Ansi256Color>());
      expect((c as Ansi256Color).code, 230);
    });

    test('must return Ansi256, default profile is Ansi256', () {
      final c = profile.getColor('#ffffff');
      expect(c, isA<Ansi256Color>());
      expect((c as Ansi256Color).code, 63);
    });
  });

  group('Profile > noColor profile >', () {
    final profile = Profile(profile: ProfileEnum.noColor);
    test('must return noColor from ansi16', () {
      expect(profile.getColor('1'), isA<NoColor>());
    });

    test('must return noColor from Ansi256Color', () {
      expect(profile.getColor('230'), isA<NoColor>());
    });

    test('must return noColor from TrueColor', () {
      expect(profile.getColor('#ffffff'), isA<NoColor>());
    });
  });

  group('Profile > Ansi16 profile >', () {
    final profile = Profile(profile: ProfileEnum.ansi16);
    test('must return ansi16 from ansi16', () {
      final c = profile.getColor('1');
      expect(c, isA<Ansi16Color>());
      expect((c as Ansi16Color).code, 1);
    });

    test('must return ansi16 from Ansi256Color', () {
      final c = profile.getColor('230');
      expect(c, isA<Ansi16Color>());
      expect((c as Ansi16Color).code, 15);
    });

    test('must return ansi16 from TrueColor', () {
      final c = profile.getColor('#ffffff');
      expect(c, isA<Ansi16Color>());
      expect((c as Ansi16Color).code, 12);
    });
  });

  group('Profile > trueColor profile >', () {
    final profile = Profile(profile: ProfileEnum.trueColor)..clearColorCache();

    test('must return TrueColor from ansi 16 code', () {
      final c = profile.getColor('1');
      expect(c, isA<TrueColor>());
      expect((c as TrueColor).hex, '#800000');
    });

    test('must return TrueColor from ansi 256 code', () {
      final c = profile.getColor('230');
      expect(c, isA<TrueColor>());
      expect((c as TrueColor).hex, '#ffffd7');
    });

    test('must return TrueColor from TrueColor code', () {
      final c = profile.getColor('#ffffff');
      expect(c, isA<TrueColor>());
      expect((c as TrueColor).hex, '#ffffff');
    });
  });
}
