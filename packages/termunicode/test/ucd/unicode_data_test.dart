import 'dart:io';

import 'package:termunicode/term_ucd.dart';
import 'package:test/test.dart';

const unicodeDataTestData = '''
# UnicodeData.txt Test Data
# Format: codepoint;name;category;ccc;bidi;decomp;decimal;digit;numeric;mirrored;old;iso;upper;lower;title
0041;LATIN CAPITAL LETTER A;Lu;0;L;;;;;N;;;;0061;
0061;LATIN SMALL LETTER A;Ll;0;L;;;;;N;;;0041;;0041
0030;DIGIT ZERO;Nd;0;EN;;0;0;0;N;;;;;
221E;INFINITY;Sm;0;ON;;;;;N;;;;;
0300;COMBINING GRAVE ACCENT;Mn;230;NSM;;;;;N;;;;;
0020;SPACE;Zs;0;WS;;;;;N;;;;;
0000;NULL;Cc;0;BN;;;;;N;NULL;;;;
FEFF;ZERO WIDTH NO-BREAK SPACE;Cf;0;BN;;;;;N;;;;;
E000;PRIVATE USE AREA FIRST;Co;0;L;;;;;N;;;;;
3400;<CJK Ideograph Extension A, First>;Lo;0;L;;;;;N;;;;;
4DB5;<CJK Ideograph Extension A, Last>;Lo;0;L;;;;;N;;;;;
AC00;HANGUL SYLLABLE GA;Lo;0;L;;;;;N;;;;;
''';

void main() {
  group('UnicodeData', () {
    late File tempFile;
    late UnicodeDataUCD unicodeData;

    setUp(() async {
      tempFile = File('${Directory.systemTemp.path}/unicode_test_${DateTime.now().millisecondsSinceEpoch}.txt');
      await tempFile.writeAsString(unicodeDataTestData);
      unicodeData = UnicodeDataUCD(tempFile.path);
      await unicodeData.parse();
    });

    tearDown(() async {
      if (tempFile.existsSync()) {
        await tempFile.delete();
      }
    });

    test('parse file correctly', () {
      expect(unicodeData.codePoints.length, greaterThan(0));
    });

    test('find uppercase letter', () {
      final item = unicodeData.find(0x0041); // LATIN CAPITAL LETTER A
      expect(item, isNotNull);
      expect(item!.name, 'LATIN CAPITAL LETTER A');
      expect(item.category, 'Lu');
      expect(item.canonicalCombiningClass, '0');
      expect(item.bidiClass, 'L');
      expect(item.simpleLowercaseMapping, '0061');
    });

    test('find lowercase letter', () {
      final item = unicodeData.find(0x0061); // LATIN SMALL LETTER A
      expect(item, isNotNull);
      expect(item!.name, 'LATIN SMALL LETTER A');
      expect(item.category, 'Ll');
      expect(item.simpleUppercaseMapping, '0041');
      expect(item.simpleTitlecaseMapping, '0041');
    });

    test('find digit', () {
      final item = unicodeData.find(0x0030); // DIGIT ZERO
      expect(item, isNotNull);
      expect(item!.name, 'DIGIT ZERO');
      expect(item.category, 'Nd');
      expect(item.decimalDigitValue, '0');
      expect(item.digitValue, '0');
      expect(item.numericValue, '0');
    });

    test('find math symbol', () {
      final item = unicodeData.find(0x221E); // INFINITY
      expect(item, isNotNull);
      expect(item!.name, 'INFINITY');
      expect(item.category, 'Sm');
      expect(item.bidiClass, 'ON');
    });

    test('find combining mark', () {
      final item = unicodeData.find(0x0300); // COMBINING GRAVE ACCENT
      expect(item, isNotNull);
      expect(item!.name, 'COMBINING GRAVE ACCENT');
      expect(item.category, 'Mn');
      expect(item.canonicalCombiningClass, '230');
      expect(item.bidiClass, 'NSM');
    });

    test('find space', () {
      final item = unicodeData.find(0x0020); // SPACE
      expect(item, isNotNull);
      expect(item!.name, 'SPACE');
      expect(item.category, 'Zs');
    });

    test('find control character', () {
      final item = unicodeData.find(0x0000); // NULL
      expect(item, isNotNull);
      expect(item!.name, 'NULL');
      expect(item.category, 'Cc');
      expect(item.unicode1Name, 'NULL');
    });

    test('find format character', () {
      final item = unicodeData.find(0xFEFF); // ZERO WIDTH NO-BREAK SPACE
      expect(item, isNotNull);
      expect(item!.name, 'ZERO WIDTH NO-BREAK SPACE');
      expect(item.category, 'Cf');
    });

    test('find private use character', () {
      final item = unicodeData.find(0xE000); // PRIVATE USE AREA
      expect(item, isNotNull);
      expect(item!.name, 'PRIVATE USE AREA FIRST');
      expect(item.category, 'Co');
    });

    test('find CJK ideograph range', () {
      final item = unicodeData.find(0x3500); // In CJK Extension A range
      expect(item, isNotNull);
      expect(item!.start, 0x3400);
      expect(item.end, 0x4DB5);
      expect(item.category, 'Lo');
    });

    test('find Hangul syllable', () {
      final item = unicodeData.find(0xAC00); // HANGUL SYLLABLE GA
      expect(item, isNotNull);
      expect(item!.name, 'HANGUL SYLLABLE GA');
      expect(item.category, 'Lo');
    });

    test('non-character U+FFFE', () {
      final item = unicodeData.find(0xFFFE);
      expect(item, isNotNull);
      expect(item!.name, 'Non Character');
      expect(item.category, 'non-character');
    });

    test('non-character U+FFFF', () {
      final item = unicodeData.find(0xFFFF);
      expect(item, isNotNull);
      expect(item!.name, 'Non Character');
      expect(item.category, 'non-character');
    });

    test('non-character U+FDD0', () {
      final item = unicodeData.find(0xFDD0);
      expect(item, isNotNull);
      expect(item!.name, 'Non Character');
      expect(item.category, 'non-character');
    });

    test('non-character U+1FFFF', () {
      final item = unicodeData.find(0x1FFFF);
      expect(item, isNotNull);
      expect(item!.name, 'Non Character');
      expect(item.category, 'non-character');
    });

    test('non-character U+10FFFF', () {
      final item = unicodeData.find(0x10FFFF);
      expect(item, isNotNull);
      expect(item!.name, 'Non Character');
      expect(item.category, 'non-character');
    });

    test('missing codepoint returns null', () {
      final item = unicodeData.find(0x0001); // Not in test data
      expect(item, isNull);
    });

    test('toString format', () {
      final item = unicodeData.find(0x0041);
      expect(item, isNotNull);
      expect(item!.toString(), contains('0x41'));
      expect(item.toString(), contains('LATIN CAPITAL LETTER A'));
      expect(item.toString(), contains('Lu'));
    });

    test('all fields populated', () {
      final item = unicodeData.find(0x0041);
      expect(item, isNotNull);
      expect(item!.name, isNotEmpty);
      expect(item.category, isNotEmpty);
      expect(item.canonicalCombiningClass, isNotNull);
      expect(item.bidiClass, isNotNull);
      expect(item.decomposition, isNotNull);
      expect(item.decimalDigitValue, isNotNull);
      expect(item.digitValue, isNotNull);
      expect(item.numericValue, isNotNull);
      expect(item.mirrored, isNotNull);
      expect(item.unicode1Name, isNotNull);
      expect(item.isoComment, isNotNull);
      expect(item.simpleUppercaseMapping, isNotNull);
      expect(item.simpleLowercaseMapping, isNotNull);
      expect(item.simpleTitlecaseMapping, isNotNull);
    });

    test('sorted codepoints', () {
      for (var i = 1; i < unicodeData.codePoints.length; i++) {
        final prev = unicodeData.codePoints[i - 1];
        final curr = unicodeData.codePoints[i];
        expect(prev.start, lessThanOrEqualTo(curr.start));
      }
    });

    test('throws UcdException on invalid codepoint format', () async {
      final badFile = File('${Directory.systemTemp.path}/unicode_bad_${DateTime.now().millisecondsSinceEpoch}.txt');
      await badFile.writeAsString('ZZZZ;TEST;Lu;0;L;;;;;N;;;;;\n');

      final badUnicode = UnicodeDataUCD(badFile.path);
      expect(() async => badUnicode.parse(), throwsA(isA<UcdException>()));

      if (badFile.existsSync()) {
        await badFile.delete();
      }
    });

    test('throws UcdException on malformed hex value', () async {
      final badFile = File('${Directory.systemTemp.path}/unicode_bad_hex_${DateTime.now().millisecondsSinceEpoch}.txt');
      await badFile.writeAsString('GGGG;NAME;Lu;0;L;;;;;N;;;;;\n');

      final badUnicode = UnicodeDataUCD(badFile.path);
      expect(() async => badUnicode.parse(), throwsA(isA<UcdException>()));

      if (badFile.existsSync()) {
        await badFile.delete();
      }
    });
  });
}
