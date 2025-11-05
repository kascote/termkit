import 'dart:io';

import 'package:termunicode/term_ucd.dart';
import 'package:test/test.dart';

const hangulTestData = '''
# Hangul Syllable Type Test Data
# Format: codepoint;property;# comment

# Leading Jamo (L)
1100..1112;L;# Lo [19] HANGUL CHOSEONG KIYEOK..HANGUL CHOSEONG HIEUH
115F;L;# Lo       HANGUL CHOSEONG FILLER
A960..A97C;L;# Lo [29] HANGUL CHOSEONG TIKEUT-MIEUM..HANGUL CHOSEONG SSANGYEORINHIEUH

# Vowel Jamo (V)
1161..1175;V;# Lo [21] HANGUL JUNGSEONG A..HANGUL JUNGSEONG I
D7B0..D7C6;V;# Lo [23] HANGUL JUNGSEONG O-YEO..HANGUL JUNGSEONG ARAEA-E

# Trailing Jamo (T)
11A8..11C2;T;# Lo [27] HANGUL JONGSEONG KIYEOK..HANGUL JONGSEONG HIEUH
D7CB..D7FB;T;# Lo [49] HANGUL JONGSEONG NIEUN-RIEUL..HANGUL JONGSEONG PHIEUPH-THIEUTH

# LV syllables (syllables without trailing consonants)
AC00;LV;# Lo       HANGUL SYLLABLE GA
AC1C;LV;# Lo       HANGUL SYLLABLE GAE
AC38;LV;# Lo       HANGUL SYLLABLE GYA

# LVT syllables (complete syllables)
AC01;LVT;# Lo       HANGUL SYLLABLE GAG
AC02;LVT;# Lo       HANGUL SYLLABLE GAGG
AC1D;LVT;# Lo       HANGUL SYLLABLE GAEG
''';

void main() {
  group('HangulSyllableType', () {
    late File tempFile;
    late HangulSyllableTypeUCD hangul;

    setUp(() async {
      tempFile = File('${Directory.systemTemp.path}/hangul_test_${DateTime.now().millisecondsSinceEpoch}.txt');
      await tempFile.writeAsString(hangulTestData);
      hangul = HangulSyllableTypeUCD(tempFile.path);
      await hangul.parse();
    });

    tearDown(() async {
      if (tempFile.existsSync()) {
        await tempFile.delete();
      }
    });

    test('parse file correctly', () {
      expect(hangul.codePoints.length, greaterThan(0));
    });

    test('find Leading Jamo (L)', () {
      final item = hangul.find(0x1100); // HANGUL CHOSEONG KIYEOK
      expect(item.property, 'L');
      expect(item.start, 0x1100);
      expect(item.end, 0x1112);
      expect(item.category, 'Lo');
    });

    test('find Hangul Choseong Filler', () {
      final item = hangul.find(0x115F); // HANGUL CHOSEONG FILLER
      expect(item.property, 'L');
      expect(item.start, 0x115F);
    });

    test('find Vowel Jamo (V)', () {
      final item = hangul.find(0x1161); // HANGUL JUNGSEONG A
      expect(item.property, 'V');
      expect(item.start, 0x1161);
      expect(item.end, 0x1175);
    });

    test('find Trailing Jamo (T)', () {
      final item = hangul.find(0x11A8); // HANGUL JONGSEONG KIYEOK
      expect(item.property, 'T');
      expect(item.start, 0x11A8);
      expect(item.end, 0x11C2);
    });

    test('find LV syllable', () {
      final item = hangul.find(0xAC00); // HANGUL SYLLABLE GA
      expect(item.property, 'LV');
      expect(item.start, 0xAC00);
    });

    test('find LVT syllable', () {
      final item = hangul.find(0xAC01); // HANGUL SYLLABLE GAG
      expect(item.property, 'LVT');
      expect(item.start, 0xAC01);
    });

    test('find character in L range', () {
      final item = hangul.find(0x1105); // HANGUL CHOSEONG RIEUL (in range)
      expect(item.property, 'L');
      expect(item.start, 0x1100);
      expect(item.end, 0x1112);
    });

    test('find character in V range', () {
      final item = hangul.find(0x1170); // HANGUL JUNGSEONG U (in range)
      expect(item.property, 'V');
      expect(item.start, 0x1161);
      expect(item.end, 0x1175);
    });

    test('find character in T range', () {
      final item = hangul.find(0x11B0); // HANGUL JONGSEONG RIEUL (in range)
      expect(item.property, 'T');
      expect(item.start, 0x11A8);
      expect(item.end, 0x11C2);
    });

    test('missing codepoint returns default NA', () {
      final item = hangul.find(0x0041); // Not a Hangul character
      expect(item.property, 'NA');
      expect(item.category, 'not applicable');
    });

    test('find extended Jamo L', () {
      final item = hangul.find(0xA960); // HANGUL CHOSEONG TIKEUT-MIEUM
      expect(item.property, 'L');
      expect(item.start, 0xA960);
      expect(item.end, 0xA97C);
    });

    test('find extended Jamo V', () {
      final item = hangul.find(0xD7B0); // HANGUL JUNGSEONG O-YEO
      expect(item.property, 'V');
      expect(item.start, 0xD7B0);
      expect(item.end, 0xD7C6);
    });

    test('find extended Jamo T', () {
      final item = hangul.find(0xD7CB); // HANGUL JONGSEONG NIEUN-RIEUL
      expect(item.property, 'T');
      expect(item.start, 0xD7CB);
      expect(item.end, 0xD7FB);
    });

    test('toString format', () {
      final item = hangul.find(0x1100);
      expect(item.toString(), contains('0x1100'));
      expect(item.toString(), contains('L'));
      expect(item.toString(), contains('Lo'));
    });

    test('sorted codepoints', () {
      for (var i = 1; i < hangul.codePoints.length; i++) {
        final prev = hangul.codePoints[i - 1];
        final curr = hangul.codePoints[i];
        expect(prev.start, lessThanOrEqualTo(curr.start));
      }
    });

    test('all properties are represented', () {
      final properties = <String>{};
      for (final item in hangul.codePoints) {
        properties.add(item.property);
      }
      expect(properties, containsAll(['L', 'V', 'T', 'LV', 'LVT']));
    });

    test('category extraction from comment', () {
      final item = hangul.find(0x1100);
      expect(item.category, 'Lo');
    });

    test('throws UcdException on invalid codepoint', () async {
      final badFile = File('${Directory.systemTemp.path}/hangul_bad_${DateTime.now().millisecondsSinceEpoch}.txt');
      await badFile.writeAsString('INVALID;L;# Bad hex\n');

      final badHangul = HangulSyllableTypeUCD(badFile.path);
      expect(() async => badHangul.parse(), throwsA(isA<UcdException>()));

      if (badFile.existsSync()) {
        await badFile.delete();
      }
    });

    test('throws UcdException on malformed range', () async {
      final badFile = File(
        '${Directory.systemTemp.path}/hangul_bad_range_${DateTime.now().millisecondsSinceEpoch}.txt',
      );
      await badFile.writeAsString('XXXX..YYYY;V;# Invalid range\n');

      final badHangul = HangulSyllableTypeUCD(badFile.path);
      expect(() async => badHangul.parse(), throwsA(isA<UcdException>()));

      if (badFile.existsSync()) {
        await badFile.delete();
      }
    });
  });
}
