import 'dart:io';

import 'package:termunicode/term_ucd.dart';
import 'package:test/test.dart';

const emojiTestData = '''
# Emoji Data Test File
# Format: codepoint;property;# comment with version

# Emoji property
1F600;Emoji;# E1.0 GRINNING FACE
1F601;Emoji;# E1.0 BEAMING FACE WITH SMILING EYES

# Emoji_Presentation property
1F3A8;Emoji_Presentation;# E0.6 ARTIST PALETTE
1F3AD;Emoji_Presentation;# E0.6 PERFORMING ARTS

# Emoji_Modifier property
1F3FB;Emoji_Modifier;# E1.0 EMOJI MODIFIER FITZPATRICK TYPE-1-2
1F3FC;Emoji_Modifier;# E2.0 EMOJI MODIFIER FITZPATRICK TYPE-3

# Emoji_Modifier_Base property
1F466;Emoji_Modifier_Base;# E0.6 BOY
1F467;Emoji_Modifier_Base;# E0.6 GIRL

# Emoji_Component property
0023;Emoji_Component;# E0.0 NUMBER SIGN
002A;Emoji_Component;# E0.0 ASTERISK

# Extended_Pictographic property
1FA00;Extended_Pictographic;# E12.0 NEUTRAL CHESS KING
1FA6F;Extended_Pictographic;# E13.1 YO-YO

# Range
1F910..1F918;Emoji;# E3.0 ZIPPER-MOUTH FACE..SIGN OF THE HORNS

# No version comment
1F300;Emoji;# CYCLONE
''';

void main() {
  group('EmojiData', () {
    late File tempFile;
    late EmojiDataUCD emojiData;

    setUp(() async {
      tempFile = File('${Directory.systemTemp.path}/emoji_test_${DateTime.now().millisecondsSinceEpoch}.txt');
      await tempFile.writeAsString(emojiTestData);
      emojiData = EmojiDataUCD(tempFile.path);
      await emojiData.parse();
    });

    tearDown(() async {
      if (tempFile.existsSync()) {
        await tempFile.delete();
      }
    });

    test('parse file correctly', () {
      expect(emojiData.codePoints.length, greaterThan(0));
    });

    test('find Emoji property', () {
      final item = emojiData.find(0x1F600); // GRINNING FACE
      expect(item, isNotNull);
      expect(item!.property, 'Emoji');
      expect(item.version, 1.0);
      expect(item.start, 0x1F600);
    });

    test('find Emoji_Presentation property', () {
      final item = emojiData.find(0x1F3A8); // ARTIST PALETTE
      expect(item, isNotNull);
      expect(item!.property, 'Emoji_Presentation');
      expect(item.version, 0.6);
    });

    test('find Emoji_Modifier property', () {
      final item = emojiData.find(0x1F3FB); // FITZPATRICK TYPE-1-2
      expect(item, isNotNull);
      expect(item!.property, 'Emoji_Modifier');
      expect(item.version, 1.0);
    });

    test('find Emoji_Modifier_Base property', () {
      final item = emojiData.find(0x1F466); // BOY
      expect(item, isNotNull);
      expect(item!.property, 'Emoji_Modifier_Base');
      expect(item.version, 0.6);
    });

    test('find Emoji_Component property', () {
      final item = emojiData.find(0x0023); // NUMBER SIGN
      expect(item, isNotNull);
      expect(item!.property, 'Emoji_Component');
      expect(item.version, 0.0);
    });

    test('find Extended_Pictographic property', () {
      final item = emojiData.find(0x1FA00); // NEUTRAL CHESS KING
      expect(item, isNotNull);
      expect(item!.property, 'Extended_Pictographic');
      expect(item.version, 12.0);
    });

    test('find character in range', () {
      final item = emojiData.find(0x1F915); // FACE WITH HEAD-BANDAGE (in range)
      expect(item, isNotNull);
      expect(item!.property, 'Emoji');
      expect(item.version, 3.0);
      expect(item.start, 0x1F910);
      expect(item.end, 0x1F918);
    });

    test('parse version from comment E12.0', () {
      final item = emojiData.find(0x1FA00); // NEUTRAL CHESS KING
      expect(item, isNotNull);
      expect(item!.version, 12.0);
    });

    test('parse version from comment E13.1', () {
      final item = emojiData.find(0x1FA6F); // YO-YO
      expect(item, isNotNull);
      expect(item!.version, 13.1);
    });

    test('parse version from comment E2.0', () {
      final item = emojiData.find(0x1F3FC); // FITZPATRICK TYPE-3
      expect(item, isNotNull);
      expect(item!.version, 2.0);
    });

    test('no version in comment defaults to 0.0', () {
      final item = emojiData.find(0x1F300); // CYCLONE
      expect(item, isNotNull);
      expect(item!.version, 0.0);
    });

    test('missing codepoint returns null', () {
      final item = emojiData.find(0x0001); // Not an emoji
      expect(item, isNull);
    });

    test('sorted codepoints', () {
      for (var i = 1; i < emojiData.codePoints.length; i++) {
        final prev = emojiData.codePoints[i - 1];
        final curr = emojiData.codePoints[i];
        expect(prev.start, lessThanOrEqualTo(curr.start));
      }
    });

    test('throws UcdException on invalid codepoint', () async {
      final badFile = File('${Directory.systemTemp.path}/emoji_bad_${DateTime.now().millisecondsSinceEpoch}.txt');
      await badFile.writeAsString('ZZZZZ;Emoji;# Invalid hex\n');

      final badEmoji = EmojiDataUCD(badFile.path);
      expect(() async => badEmoji.parse(), throwsA(isA<UcdException>()));

      if (badFile.existsSync()) {
        await badFile.delete();
      }
    });

    test('throws UcdException on malformed range', () async {
      final badFile = File('${Directory.systemTemp.path}/emoji_bad_range_${DateTime.now().millisecondsSinceEpoch}.txt');
      await badFile.writeAsString('XXXX..YYYY;Emoji;# Bad range\n');

      final badEmoji = EmojiDataUCD(badFile.path);
      expect(() async => badEmoji.parse(), throwsA(isA<UcdException>()));

      if (badFile.existsSync()) {
        await badFile.delete();
      }
    });
  });
}
