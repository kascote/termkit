import 'dart:io';

import 'package:termunicode/term_ucd.dart';
import 'package:test/test.dart';

const eawTestData = '''
# East Asian Width Test Data
# Format: codepoint;property;#comment

# Neutral (narrow) characters
0041;N;# LATIN CAPITAL LETTER A
0061;N;# LATIN SMALL LETTER A

# Fullwidth characters
3000;F;# IDEOGRAPHIC SPACE
FF01;F;# FULLWIDTH EXCLAMATION MARK

# Halfwidth characters
FF61;H;# HALFWIDTH IDEOGRAPHIC FULL STOP
FF65;H;# HALFWIDTH KATAKANA MIDDLE DOT

# Wide characters
4E00;W;# CJK UNIFIED IDEOGRAPH-4E00
AC00;W;# HANGUL SYLLABLE GA

# Ambiguous characters
00A1;A;# INVERTED EXCLAMATION MARK
00BF;A;# INVERTED QUESTION MARK

# Ranges
0030..0039;Na;# DIGIT ZERO..DIGIT NINE
''';

void main() {
  group('EastAsianWidth', () {
    late File tempFile;
    late EastAsianWidthUCD eaw;

    setUp(() async {
      tempFile = File('${Directory.systemTemp.path}/eaw_test_${DateTime.now().millisecondsSinceEpoch}.txt');
      await tempFile.writeAsString(eawTestData);
      eaw = EastAsianWidthUCD(tempFile.path);
      await eaw.parse();
    });

    tearDown(() async {
      if (tempFile.existsSync()) {
        await tempFile.delete();
      }
    });

    test('parse file correctly', () {
      expect(eaw.codePoints.length, greaterThan(0));
    });

    test('find neutral character', () {
      final item = eaw.find(0x0041); // LATIN CAPITAL LETTER A
      expect(item.property, 'N');
      expect(item.start, 0x0041);
    });

    test('find fullwidth character', () {
      final item = eaw.find(0x3000); // IDEOGRAPHIC SPACE
      expect(item.property, 'F');
      expect(item.start, 0x3000);
    });

    test('find halfwidth character', () {
      final item = eaw.find(0xFF61); // HALFWIDTH IDEOGRAPHIC FULL STOP
      expect(item.property, 'H');
      expect(item.start, 0xFF61);
    });

    test('find wide character', () {
      final item = eaw.find(0x4E00); // CJK UNIFIED IDEOGRAPH
      expect(item.property, 'W');
      expect(item.start, 0x4E00);
    });

    test('find ambiguous character', () {
      final item = eaw.find(0x00A1); // INVERTED EXCLAMATION MARK
      expect(item.property, 'A');
      expect(item.start, 0x00A1);
    });

    test('find character in range', () {
      final item = eaw.find(0x0035); // DIGIT FIVE
      expect(item.property, 'Na');
      expect(item.start, 0x0030);
      expect(item.end, 0x0039);
    });

    test('missing codepoint returns default N', () {
      final item = eaw.find(0x0001); // Missing codepoint
      expect(item.property, 'N');
      expect(item.category, 'missing');
    });

    test('special case - CJK Unified Ideographs Extension A (U+3400..U+4DBF)', () {
      final item = eaw.find(0x3500); // In CJK Extension A range
      expect(item.property, 'W');
      expect(item.category, 'CJK ideograph');
    });

    test('special case - CJK Unified Ideographs (U+4E00..U+9FFF)', () {
      final item = eaw.find(0x5000); // In CJK range
      expect(item.property, 'W');
      expect(item.category, 'CJK ideograph');
    });

    test('special case - CJK Compatibility Ideographs (U+F900..U+FAFF)', () {
      final item = eaw.find(0xF950); // In CJK Compatibility range
      expect(item.property, 'W');
      expect(item.category, 'CJK ideograph');
    });

    test('special case - Plane 2 (U+20000..U+2FFFD)', () {
      final item = eaw.find(0x20001); // In Plane 2
      expect(item.property, 'W');
      expect(item.category, 'CJK ideograph');
    });

    test('special case - Plane 3 (U+30000..U+3FFFD)', () {
      final item = eaw.find(0x30001); // In Plane 3
      expect(item.property, 'W');
      expect(item.category, 'CJK ideograph');
    });

    test('extract category from comment', () {
      final item = eaw.find(0x0041); // LATIN CAPITAL LETTER A
      expect(item.category, 'LA');
    });

    test('toString format', () {
      final item = eaw.find(0x0041);
      expect(item.toString(), contains('0x41'));
      expect(item.toString(), contains('N'));
    });

    test('throws UcdException on invalid codepoint', () async {
      final badFile = File('${Directory.systemTemp.path}/eaw_bad_${DateTime.now().millisecondsSinceEpoch}.txt');
      await badFile.writeAsString('INVALID;N;# Bad codepoint\n');

      final badEaw = EastAsianWidthUCD(badFile.path);
      expect(() async => badEaw.parse(), throwsA(isA<UcdException>()));

      if (badFile.existsSync()) {
        await badFile.delete();
      }
    });

    test('throws UcdException on malformed hex', () async {
      final badFile = File('${Directory.systemTemp.path}/eaw_bad_hex_${DateTime.now().millisecondsSinceEpoch}.txt');
      await badFile.writeAsString('GGGG;N;# Malformed hex\n');

      final badEaw = EastAsianWidthUCD(badFile.path);
      expect(() async => badEaw.parse(), throwsA(isA<UcdException>()));

      if (badFile.existsSync()) {
        await badFile.delete();
      }
    });
  });
}
