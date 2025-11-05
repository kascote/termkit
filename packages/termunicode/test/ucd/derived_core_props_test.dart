import 'dart:io';

import 'package:termunicode/term_ucd.dart';
import 'package:test/test.dart';

const derivedPropsTestData = '''
# Derived Core Properties Test Data
# Format: codepoint;property;breaker;# comment

# Default_Ignorable_Code_Point property
00AD;Default_Ignorable_Code_Point;;# Cf SOFT HYPHEN
034F;Default_Ignorable_Code_Point;;# Mn COMBINING GRAPHEME JOINER
061C;Default_Ignorable_Code_Point;;# Cf ARABIC LETTER MARK

# Alphabetic property
0041..005A;Alphabetic;;# Lu [26] LATIN CAPITAL LETTER A..LATIN CAPITAL LETTER Z
0061..007A;Alphabetic;;# Ll [26] LATIN SMALL LETTER A..LATIN SMALL LETTER Z

# Lowercase property
0061..007A;Lowercase;;# Ll [26] LATIN SMALL LETTER A..LATIN SMALL LETTER Z

# Uppercase property
0041..005A;Uppercase;;# Lu [26] LATIN CAPITAL LETTER A..LATIN CAPITAL LETTER Z

# Math property
002B;Math;;# Sm PLUS SIGN
003D;Math;;# Sm EQUALS SIGN
221E;Math;;# Sm INFINITY

# ID_Start property
0041..005A;ID_Start;;# Lu [26] LATIN CAPITAL LETTER A..LATIN CAPITAL LETTER Z
0061..007A;ID_Start;;# Ll [26] LATIN SMALL LETTER A..LATIN SMALL LETTER Z

# ID_Continue property
0030..0039;ID_Continue;;# Nd [10] DIGIT ZERO..DIGIT NINE
0041..005A;ID_Continue;;# Lu [26] LATIN CAPITAL LETTER A..LATIN CAPITAL LETTER Z

# Grapheme_Extend property
0300..036F;Grapheme_Extend;;# Mn [112] COMBINING GRAVE ACCENT..COMBINING LATIN SMALL LETTER X

# XID_Start property
0041;XID_Start;;# Lu LATIN CAPITAL LETTER A

# XID_Continue property
0030;XID_Continue;;# Nd DIGIT ZERO
''';

void main() {
  group('DerivedCoreProps', () {
    late File tempFile;
    late DerivedCodePropsUCD props;

    setUp(() async {
      tempFile = File('${Directory.systemTemp.path}/dcp_test_${DateTime.now().millisecondsSinceEpoch}.txt');
      await tempFile.writeAsString(derivedPropsTestData);
      props = DerivedCodePropsUCD(tempFile.path);
      await props.parse();
    });

    tearDown(() async {
      if (tempFile.existsSync()) {
        await tempFile.delete();
      }
    });

    test('parse file correctly', () {
      expect(props.codePoints.length, 0); // DerivedCodePropsUCD doesn't use codePoints list
    });

    test('find Default_Ignorable_Code_Point property', () {
      final item = props.findProp('Default_Ignorable_Code_Point', 0x00AD);
      expect(item, isNotNull);
      expect(item!.property, 'Default_Ignorable_Code_Point');
      expect(item.start, 0x00AD);
      expect(item.category, 'Cf');
    });

    test('find Alphabetic property in range', () {
      final item = props.findProp('Alphabetic', 0x0041); // LATIN CAPITAL LETTER A
      expect(item, isNotNull);
      expect(item!.property, 'Alphabetic');
      expect(item.start, 0x0041);
      expect(item.end, 0x005A);
    });

    test('find lowercase character', () {
      final item = props.findProp('Lowercase', 0x0061); // LATIN SMALL LETTER A
      expect(item, isNotNull);
      expect(item!.property, 'Lowercase');
      expect(item.start, 0x0061);
      expect(item.end, 0x007A);
    });

    test('find uppercase character', () {
      final item = props.findProp('Uppercase', 0x0041); // LATIN CAPITAL LETTER A
      expect(item, isNotNull);
      expect(item!.property, 'Uppercase');
      expect(item.start, 0x0041);
      expect(item.end, 0x005A);
    });

    test('find Math property', () {
      final item = props.findProp('Math', 0x002B); // PLUS SIGN
      expect(item, isNotNull);
      expect(item!.property, 'Math');
      expect(item.category, 'Sm');
    });

    test('find ID_Start property', () {
      final item = props.findProp('ID_Start', 0x0041); // LATIN CAPITAL LETTER A
      expect(item, isNotNull);
      expect(item!.property, 'ID_Start');
    });

    test('find ID_Continue property', () {
      final item = props.findProp('ID_Continue', 0x0030); // DIGIT ZERO
      expect(item, isNotNull);
      expect(item!.property, 'ID_Continue');
      expect(item.start, 0x0030);
      expect(item.end, 0x0039);
    });

    test('find Grapheme_Extend property', () {
      final item = props.findProp('Grapheme_Extend', 0x0300); // COMBINING GRAVE ACCENT
      expect(item, isNotNull);
      expect(item!.property, 'Grapheme_Extend');
      expect(item.category, 'Mn');
    });

    test('find XID_Start property', () {
      final item = props.findProp('XID_Start', 0x0041);
      expect(item, isNotNull);
      expect(item!.property, 'XID_Start');
    });

    test('find XID_Continue property', () {
      final item = props.findProp('XID_Continue', 0x0030);
      expect(item, isNotNull);
      expect(item!.property, 'XID_Continue');
    });

    test('missing property returns null', () {
      final item = props.findProp('NonExistentProperty', 0x0041);
      expect(item, isNull);
    });

    test('codepoint not in property returns null', () {
      final item = props.findProp('Math', 0x0041); // A is not Math
      expect(item, isNull);
    });

    test('extract category from comment', () {
      final item = props.findProp('Default_Ignorable_Code_Point', 0x00AD);
      expect(item, isNotNull);
      expect(item!.category, 'Cf');
    });

    test('toString format', () {
      final item = props.findProp('Math', 0x002B);
      expect(item, isNotNull);
      expect(item!.toString(), contains('0x2b'));
      expect(item.toString(), contains('Math'));
      expect(item.toString(), contains('Sm'));
    });

    test('character in middle of range', () {
      final item = props.findProp('Alphabetic', 0x004D); // LATIN CAPITAL LETTER M
      expect(item, isNotNull);
      expect(item!.property, 'Alphabetic');
      expect(item.start, 0x0041);
      expect(item.end, 0x005A);
    });

    test('throws UcdException on invalid codepoint', () async {
      final badFile = File('${Directory.systemTemp.path}/dcp_bad_${DateTime.now().millisecondsSinceEpoch}.txt');
      await badFile.writeAsString('XYZ123;Alphabetic;;# Invalid\n');

      final badProps = DerivedCodePropsUCD(badFile.path);
      expect(() async => badProps.parse(), throwsA(isA<UcdException>()));

      if (badFile.existsSync()) {
        await badFile.delete();
      }
    });

    test('throws UcdException on non-hex codepoint', () async {
      final badFile = File('${Directory.systemTemp.path}/dcp_nonhex_${DateTime.now().millisecondsSinceEpoch}.txt');
      await badFile.writeAsString('QQQQ;Math;;# Non-hex\n');

      final badProps = DerivedCodePropsUCD(badFile.path);
      expect(() async => badProps.parse(), throwsA(isA<UcdException>()));

      if (badFile.existsSync()) {
        await badFile.delete();
      }
    });
  });
}
