import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import 'package:termunicode/term_ucd.dart';

import 'constants.dart';
import 'downloader.dart';

///
class Tables {
  /// EastAsianWidth UCD file
  late final EastAsianWidthUCD eaw;

  /// UnicodeData UCD file
  late final UnicodeDataUCD uniData;

  /// EmojiData UCD file
  late final EmojiDataUCD emoji;

  /// DerivedCodeProps UCD file
  late final DerivedCodePropsUCD dcp;

  /// HangulSyllableType UCD file
  late final HangulSyllableTypeUCD hst;

  final _tables = <String, List<int>>{
    'stage1': [],
    'stage2': [],
    'stage3': [],
  };

  /// Get the generated tables
  Map<String, List<int>> get tables => _tables;

  /// Download UCD files and generate the lookup tables
  Future<void> generate() async {
    await downloadFiles(saveTo: destinationDirectory);

    eaw = EastAsianWidthUCD(path.join(destinationDirectory, EastAsianWidthUCD.fileName));
    uniData = UnicodeDataUCD(path.join(destinationDirectory, UnicodeDataUCD.fileName));
    emoji = EmojiDataUCD(path.join(destinationDirectory, EmojiDataUCD.fileName));
    dcp = DerivedCodePropsUCD(path.join(destinationDirectory, DerivedCodePropsUCD.fileName));
    hst = HangulSyllableTypeUCD(path.join(destinationDirectory, HangulSyllableTypeUCD.fileName));

    await eaw.parse();
    await uniData.parse();
    await emoji.parse();
    await dcp.parse();
    await hst.parse();

    final block = <int>[];
    final blockLut = <String, int>{};

    for (var cp = 0; cp <= maxCodePoints; cp++) {
      final cpData = getCPData(cp);

      var stage3Idx = _tables['stage3']!.indexOf(cpData);
      if (stage3Idx == -1) {
        _tables['stage3']!.add(cpData);
        stage3Idx = _tables['stage3']!.length - 1;
      }

      block.add(stage3Idx);

      if (block.length == blockSize || cp == maxCodePoints) {
        final hash = hashArray(block);
        var startIdx = blockLut[hash];

        if (startIdx == null) {
          startIdx = _tables['stage2']!.length;
          _tables['stage2']!.addAll(block);
          blockLut[hash] = startIdx;
        }

        _tables['stage1']!.add(startIdx);
        block.clear();
      }
    }

    _validateTables();
  }

  /// Smoke test validation - verify known codepoints have expected properties
  void _validateTables() {
    // Bit masks for property extraction
    const widthMask = 0x3; // bits 0-1
    const emojiMask = 0x4; // bit 2
    const nonPrintMask = 0x8; // bit 3
    const nonCharMask = 0x10; // bit 4
    const privateMask = 0x20; // bit 5

    // U+0000 NULL - control char, width 0, non-printable
    final nullData = getCPData(0x00);
    if ((nullData & widthMask) != 0) {
      throw Exception('U+0000 NULL: expected width 0, got ${nullData & widthMask}');
    }
    if ((nullData & nonPrintMask) == 0) {
      throw Exception('U+0000 NULL: expected non-printable bit set');
    }

    // U+0041 'A' - ASCII letter, width 1
    final asciiData = getCPData(0x41);
    if ((asciiData & widthMask) != 1) {
      throw Exception('U+0041 A: expected width 1, got ${asciiData & widthMask}');
    }

    // U+001B ESC - control char, width 0, non-printable
    final escData = getCPData(0x1B);
    if ((escData & widthMask) != 0) {
      throw Exception('U+001B ESC: expected width 0, got ${escData & widthMask}');
    }
    if ((escData & nonPrintMask) == 0) {
      throw Exception('U+001B ESC: expected non-printable bit set');
    }

    // U+0300 - combining grave accent, zero width
    final combiningData = getCPData(0x0300);
    if ((combiningData & widthMask) != 0) {
      throw Exception('U+0300 combining accent: expected width 0, got ${combiningData & widthMask}');
    }

    // U+4E00 '一' - CJK ideograph, width 2
    final cjkData = getCPData(0x4E00);
    if ((cjkData & widthMask) != 2) {
      throw Exception('U+4E00 CJK: expected width 2, got ${cjkData & widthMask}');
    }

    // U+1F600 😀 - emoji, width 2, emoji bit set
    final emojiData = getCPData(0x1F600);
    if ((emojiData & emojiMask) == 0) {
      throw Exception('U+1F600 emoji: expected emoji bit set');
    }
    if ((emojiData & widthMask) != 2) {
      throw Exception('U+1F600 emoji: expected width 2, got ${emojiData & widthMask}');
    }

    // U+E000 - private use area, private bit set
    final privateData = getCPData(0xE000);
    if ((privateData & privateMask) == 0) {
      throw Exception('U+E000 private use: expected private bit set');
    }

    // U+FFFE - non-character, non-char bit set
    final nonCharData = getCPData(0xFFFE);
    if ((nonCharData & nonCharMask) == 0) {
      throw Exception('U+FFFE: expected non-character bit set');
    }

    // U+00A1 '¡' - ambiguous width char, should encode as 3 (ambiguous)
    // which means width 1 normally, 2 in CJK context
    final ambiguousData = getCPData(0xA1);
    if ((ambiguousData & widthMask) != 3) {
      throw Exception('U+00A1 ambiguous: expected width encoding 3, got ${ambiguousData & widthMask}');
    }
  }

  /// Get the data for a code point.
  int getCPData(int cp) {
    var isEmoji = false;
    var nonPrintable = false;
    var charWidth = getCharWidth(cp);

    final data = uniData.find(cp);
    if (data != null && nonPrintableCategories.contains(data.category)) nonPrintable = true;

    // Emoji UCD has definitions for some lower code points, they are excluded
    if (cp >= 0x40) {
      final emo = emoji.find(cp);
      if (emo != null) {
        isEmoji = true;
        // Regional Indicator Symbols are Narrow in EAW table, but they are
        // Wide. There are more cases that EAW table doesn't matches Emoji
        // if (emo.start >= 0x1F1E6 && emo.end <= 0x1F1FF) charWidth = 2;
        // all RIS (Regional Indicator Symbols) have Emoji property set and
        // there are a couple more Emojis that are Narrow in EAW table
        if (emo.property == 'Emoji') charWidth = 2;
      }
    }

    /*

   char width ----------------------+--+
   emoji      -------------------+  |  |
   non printable -------------+  |  |  |
   non char      ----------+  |  |  |  |
   private       -------+  |  |  |  |  |
                        |  |  |  |  |  |
   */
    final bits = [0, 0, 0, 0, 0, 0, 0, 0];

    if (data != null && data.category == 'Co') bits[2] = 1;
    if (data != null && data.category == 'non-character') bits[3] = 1;
    if (data != null && nonPrintable) bits[4] = 1;
    if (isEmoji) bits[5] = 1;
    bits[6] = charWidth & 0x2 == 0x2 ? 1 : 0;
    bits[7] = charWidth & 0x1 == 0x1 ? 1 : 0;

    return bits.fold(0, (acc, bit) => (acc << 1) | bit);
  }

  /// Determine char width for a code point.
  int getCharWidth(int cp) {
    var charWidth = 0;

    final eawChar = eaw.find(cp);
    charWidth = switch (eawChar.property) {
      'N' || 'H' || 'Na' => 1, // N: Neutral, H: HalfWidth, Na: Narrow
      'W' || 'F' => 2, // W: Wide, F: FullWidth
      'A' => 3, // A: Ambiguous
      _ => throw Exception('Unknown East Asian Width: ${eawChar.property}'),
    };

    final data = uniData.find(cp);
    if (data != null) {
      if (zeroCharacterWidth.contains(data.category)) charWidth = 0;
    }

    // `Default_Ignorable_Code_Point`s also have 0 width:
    // https://www.unicode.org/faq/unsup_char.html#3
    // https://www.unicode.org/versions/Unicode15.1.0/ch05.pdf#G40095
    // taken from unicode-rs https://github.com/unicode-rs
    if (dcp.findProp('Default_Ignorable_Code_Point', cp) != null) charWidth = 0;

    // Treat `Hangul_Syllable_Type`s of `Vowel_Jamo` and `Trailing_Jamo`
    // as zero-width. This matches the behavior of glibc `wcwidth`.
    //
    // Decomposed Hangul characters consist of 3 parts: a `Leading_Jamo`,
    // a `Vowel_Jamo`, and an optional `Trailing_Jamo`. Together these combine
    // into a single wide grapheme. So we treat vowel and trailing jamo as
    // 0-width, such that only the width of the leading jamo is counted
    // and the resulting grapheme has width 2.
    //
    // (See the Unicode Standard sections 3.12 and 18.6 for more on Hangul)
    // taken from unicode-rs https://github.com/unicode-rs
    final hstChar = hst.find(cp);
    if (['V', 'T'].contains(hstChar.property)) charWidth = 0;

    // Special case: U+115F HANGUL CHOSEONG FILLER.
    // U+115F is a `Default_Ignorable_Code_Point`, and therefore would normally have
    // zero width. However, the expected usage is to combine it with vowel or trailing jamo
    // (which are considered 0-width on their own) to form a composed Hangul syllable with
    // width 2. Therefore, we treat it as having width 2.
    // taken from unicode-rs https://github.com/unicode-rs
    if (cp == 0x115f) charWidth = 2;

    // The soft hyphen (`U+00AD`) is single-width. (https://archive.is/fCT3c)
    // taken from unicode-rs https://github.com/unicode-rs
    if (cp == 0x00ad) charWidth = 1;

    return charWidth;
  }
}

/// Generate a hash from a list of integers.
String hashArray(List<int> integers) {
  final byteData = Uint8List.fromList(integers.expand((i) => [i >> 24, i >> 16, i >> 8, i & 0xFF]).toList());
  final hash = sha256.convert(byteData);
  return hash.toString();
}
