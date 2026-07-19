// EmojiDataUCD lookup soundness: emoji-data.txt lists one row per
// (range, property) and a codepoint can carry several properties, so ranges
// in the file overlap. A binary search over the flattened row list can miss
// a covering range outright; on the Unicode 16 data that shipped 46
// codepoints (lipstick, kiss mark, the hearts) with the emoji bit unset.
// These tests pin the fixed behavior: find() and findProp() must see every
// covered codepoint.
import 'dart:io';

import 'package:termunicode/term_ucd.dart';
import 'package:test/test.dart';

// Overlapping ranges shaped like the real file: a broad Emoji range with
// narrower rows of other properties inside it, plus a row that only exists
// under one property.
const overlappingFixture = '''
1F400..1F4FF;Emoji;# E1.0 BROAD RANGE
1F480..1F48F;Emoji_Presentation;# E1.0 INNER RANGE
1F484;Extended_Pictographic;# E1.0 SINGLE INSIDE
1F600;Emoji;# E1.0 LONE ROW
2602;Emoji;# E0.7 UMBRELLA
2602;Extended_Pictographic;# E0.7 UMBRELLA
''';

void main() {
  group('EmojiDataUCD soundness', () {
    late File tempFile;
    late EmojiDataUCD emojiData;

    setUp(() async {
      tempFile = File('${Directory.systemTemp.path}/emoji_sound_${DateTime.now().millisecondsSinceEpoch}.txt');
      await tempFile.writeAsString(overlappingFixture);
      emojiData = EmojiDataUCD(tempFile.path);
      await emojiData.parse();
    });

    tearDown(() async {
      if (tempFile.existsSync()) {
        await tempFile.delete();
      }
    });

    test('find sees every covered codepoint despite overlaps', () {
      for (var cp = 0x1F400; cp <= 0x1F4FF; cp++) {
        expect(emojiData.find(cp), isNotNull, reason: 'U+${cp.toRadixString(16)}');
      }
      expect(emojiData.find(0x1F600), isNotNull);
      expect(emojiData.find(0x2602), isNotNull);
      expect(emojiData.find(0x1F3FF), isNull);
      expect(emojiData.find(0x1F500), isNull);
    });

    test('findProp answers per property', () {
      expect(emojiData.findProp('Emoji', 0x1F484), isNotNull);
      expect(emojiData.findProp('Emoji_Presentation', 0x1F484), isNotNull);
      expect(emojiData.findProp('Extended_Pictographic', 0x1F484), isNotNull);

      expect(emojiData.findProp('Emoji', 0x1F410), isNotNull);
      expect(emojiData.findProp('Emoji_Presentation', 0x1F410), isNull);

      expect(emojiData.findProp('Emoji_Presentation', 0x1F600), isNull);
      expect(emojiData.findProp('Unknown_Property', 0x1F484), isNull);
    });

    test('properties lists names in file order', () {
      expect(
        emojiData.properties,
        ['Emoji', 'Emoji_Presentation', 'Extended_Pictographic'],
      );
    });
  });

  group('full emoji-data audit', () {
    final dataFile = File('data/emoji-data.txt');

    test(
      'find and findProp cover every codepoint in the file',
      skip: dataFile.existsSync() ? null : 'data/emoji-data.txt not downloaded (run tool/generator.dart)',
      () async {
        final ucd = EmojiDataUCD(dataFile.path);
        await ucd.parse();

        final truth = <String, List<bool>>{};
        for (final item in ucd.codePoints) {
          final perProp = truth[item.property] ??= List<bool>.filled(0x110000, false);
          for (var cp = item.start; cp <= item.end; cp++) {
            perProp[cp] = true;
          }
        }

        for (var cp = 0; cp < 0x110000; cp++) {
          final covered = truth.values.any((perProp) => perProp[cp]);
          expect(
            ucd.find(cp) != null,
            covered,
            reason: 'find(U+${cp.toRadixString(16).toUpperCase()})',
          );
          for (final MapEntry(key: property, value: perProp) in truth.entries) {
            expect(
              ucd.findProp(property, cp) != null,
              perProp[cp],
              reason: 'findProp($property, U+${cp.toRadixString(16).toUpperCase()})',
            );
          }
        }
      },
    );
  });
}
