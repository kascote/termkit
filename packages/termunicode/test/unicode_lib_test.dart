import 'package:termunicode/termunicode.dart';
import 'package:test/test.dart';

void main() {
  test('string length', () {
    expect(widthString('ｈｅｌｌｏ'), 10);
    expect(widthString('ｈｅｌｌｏ', cjk: true), 10);
    expect(widthString('\x00\x00\x01\x01'), 0);
    expect(widthString('\x00\x00\x01\x01', cjk: true), 0);
    expect(widthString(''), 0);
    expect(widthString('', cjk: true), 0);
    expect(widthString('\u2081\u2082\u2083\u2084'), 4);
    expect(widthString('\u2081\u2082\u2083\u2084', cjk: true), 8);
  });

  test('emoji', () {
    expect(widthString('👩'), 2); // Woman
    expect(isEmojiChar('👩'), true);
    expect(isEmojiChar(''), false);
    expect(widthString('🔬'), 2); // Microscope
    expect(isEmojiChar('🔬'), true);
    expect(widthString('👩‍🔬'), 2); // Woman scientist
    expect(isEmojiChar('👩‍🔬'), true);
    expect(widthString('🏕️'), 2); // in range data
    expect(widthString('🏈'), 2); // standalone range
  });

  test('char width', () {
    expect(widthString('ｈ'), 2);
    expect(widthString('ｈ', cjk: true), 2);
    expect(widthString('\x00'), 0);
    expect(widthString('\x00', cjk: true), 0);
    expect(widthString('\x01'), 0);
    expect(widthString('\x01', cjk: true), 0);
    expect(widthString('\u2081'), 1);
    expect(widthString('\u2081', cjk: true), 2);

    expect(widthString('\x0A'), 0);
    expect(widthString('\x0A', cjk: true), 0);
    expect(widthString('w'), 1);
    expect(widthString('w', cjk: true), 1);
    expect(widthString('\xAD'), 1);
    expect(widthString('\xAD', cjk: true), 1);
    expect(widthString('\u1160'), 0);
    expect(widthString('\u1160', cjk: true), 0);
    expect(widthString('\xA1'), 1);
    expect(widthString('\xA1', cjk: true), 2);
    expect(widthString('\u{300}'), 0);
    expect(widthString('\u{300}', cjk: true), 0);
  });

  test('unicode 12', () {
    expect(widthString('\u{1F971}'), 2);
  });

  test('default ignorable', () {
    expect(widthString('\u{E0000}'), 0);
    expect(widthString('\u{1160}'), 0);
    expect(widthString('\u{3164}'), 0);
    expect(widthString('\u{FFA0}'), 0);
  });

  test('jamo', () {
    expect(widthString('\u{1100}'), 2);
    expect(widthString('\u{A97C}'), 2);
    // Special case: U+115F HANGUL CHOSEONG FILLER
    expect(widthString('\u{115F}'), 2);
    expect(widthString('\u{1160}'), 0);
    expect(widthString('\u{D7C6}'), 0);
    expect(widthString('\u{11A8}'), 0);
    expect(widthString('\u{D7FB}'), 0);
  });

  test('prepended concatenation marks', () {
    expect(widthString('\u{0600}'), 1);
    expect(widthString('\u{070F}'), 1);
    expect(widthString('\u{08E2}'), 1);
    expect(widthString('\u{110BD}'), 1);
  });

  test('interlinear annotation chars', () {
    expect(widthString('\u{FFF9}'), 1);
    expect(widthString('\u{FFFA}'), 1);
    expect(widthString('\u{FFFB}'), 1);
  });

  test('hieroglyph format controls', () {
    expect(widthString('\u{13430}'), 1);
    expect(widthString('\u{13436}'), 1);
    expect(widthString('\u{1343C}'), 1);
  });

  test('isNonPrintable', () {
    expect(isNonPrintableChar('\x00'), true);
    expect(isNonPrintableCp(0x0), true);
    expect(isNonPrintableCp(0x2028), true);
    expect(isNonPrintableCp(0xDC00), true);
    expect(isNonPrintableCp(0x110BD), true);
    expect(isNonPrintableCp(0xE0001), true);
    expect(isNonPrintableCp(0x0200C), true);
  });

  test('isNonPrintable edge cases', () {
    // Control chars (Cc)
    expect(isNonPrintableCp(0x00), true); // NULL
    expect(isNonPrintableCp(0x1F), true); // Unit separator
    expect(isNonPrintableCp(0x7F), true); // DELETE
    expect(isNonPrintableCp(0x9F), true); // Application program command

    // Format chars (Cf)
    expect(isNonPrintableCp(0x00AD), true); // Soft hyphen
    expect(isNonPrintableCp(0x200B), true); // Zero-width space
    expect(isNonPrintableCp(0x200C), true); // Zero-width non-joiner
    expect(isNonPrintableCp(0x200D), true); // Zero-width joiner (ZWJ)
    expect(isNonPrintableCp(0xFEFF), true); // Zero-width no-break space

    // Surrogates (Cs)
    expect(isNonPrintableCp(0xD800), true); // High surrogate start
    expect(isNonPrintableCp(0xDBFF), true); // High surrogate end
    expect(isNonPrintableCp(0xDC00), true); // Low surrogate start
    expect(isNonPrintableCp(0xDFFF), true); // Low surrogate end

    // Line/Paragraph separators (Zl, Zp)
    expect(isNonPrintableCp(0x2028), true); // Line separator
    expect(isNonPrintableCp(0x2029), true); // Paragraph separator

    // Printable chars should be false
    expect(isNonPrintableCp(0x20), false); // Space
    expect(isNonPrintableCp(0x41), false); // 'A'
    expect(isNonPrintableCp(0x4E00), false); // CJK ideograph
  });

  test('isNonChar', () {
    expect(isNonChar('\uFDD0'), true);
    expect(isNonCharCp(0xFDDA), true);
    expect(isNonCharCp(0x5FFFE), true);
    expect(isNonCharCp(0x9FFFF), true);
    expect(isNonCharCp(0x10FFFF), true);
  });

  test('isNonChar edge cases', () {
    // FDD0..FDEF range (32 noncharacters)
    expect(isNonCharCp(0xFDD0), true); // First in range
    expect(isNonCharCp(0xFDD5), true); // Middle
    expect(isNonCharCp(0xFDEF), true); // Last in range

    // End of each plane (FFFE, FFFF)
    expect(isNonCharCp(0xFFFE), true); // BMP
    expect(isNonCharCp(0xFFFF), true); // BMP
    expect(isNonCharCp(0x1FFFE), true); // Plane 1
    expect(isNonCharCp(0x1FFFF), true); // Plane 1
    expect(isNonCharCp(0x2FFFE), true); // Plane 2
    expect(isNonCharCp(0x10FFFE), true); // Plane 16
    expect(isNonCharCp(0x10FFFF), true); // Plane 16

    // Regular chars should be false
    expect(isNonCharCp(0xFDCF), false); // Just before range
    expect(isNonCharCp(0xFDF0), false); // Just after range
    expect(isNonCharCp(0xFFFD), false); // Replacement char (not nonchar)
    expect(isNonCharCp(0x41), false); // 'A'
  });

  test('isPrivate', () {
    expect(isPrivateChar('\uE000'), true);
    expect(isPrivateCp(0xF8FF), true);
    expect(isPrivateCp(0xF0000), true);
    expect(isPrivateCp(0xF1234), true);
    expect(isPrivateCp(0xFFFFD), true);
    expect(isPrivateCp(0x10FFFD), true);
  });

  test('isPrivate edge cases', () {
    // BMP Private Use Area (E000..F8FF)
    expect(isPrivateCp(0xE000), true); // Start
    expect(isPrivateCp(0xE500), true); // Middle
    expect(isPrivateCp(0xF8FF), true); // End

    // Plane 15 PUA (F0000..FFFFD)
    expect(isPrivateCp(0xF0000), true); // Start
    expect(isPrivateCp(0xF5000), true); // Middle
    expect(isPrivateCp(0xFFFFD), true); // End

    // Plane 16 PUA (100000..10FFFD)
    expect(isPrivateCp(0x100000), true); // Start
    expect(isPrivateCp(0x105000), true); // Middle
    expect(isPrivateCp(0x10FFFD), true); // End

    // Non-private chars should be false
    expect(isPrivateCp(0xDFFF), false); // Just before BMP PUA
    expect(isPrivateCp(0xF900), false); // Just after BMP PUA
    expect(isPrivateCp(0xEFFFF), false); // Just before Plane 15 PUA
    expect(isPrivateCp(0xFFFFE), false); // Noncharacter (not private)
    expect(isPrivateCp(0x41), false); // 'A'
  });

  test('emoji detection edge cases', () {
    // Regional indicators
    expect(isEmojiCp(0x1F1E6), true); // Regional indicator A
    expect(isEmojiCp(0x1F1FF), true); // Regional indicator Z

    // Skin tone modifiers
    expect(isEmojiCp(0x1F3FB), true); // Light skin tone
    expect(isEmojiCp(0x1F3FC), true); // Medium-light skin tone
    expect(isEmojiCp(0x1F3FD), true); // Medium skin tone
    expect(isEmojiCp(0x1F3FE), true); // Medium-dark skin tone
    expect(isEmojiCp(0x1F3FF), true); // Dark skin tone

    // Common emojis
    expect(isEmojiCp(0x1F600), true); // Grinning face
    expect(isEmojiCp(0x1F44D), true); // Thumbs up
    expect(isEmojiCp(0x2764), true); // Heavy black heart (❤)

    // ZWJ is marked as emoji (used in emoji sequences)
    expect(isEmojiCp(0x200D), true); // Zero-width joiner

    // Variation selector-16 (emoji presentation)
    expect(isEmojiCp(0xFE0F), true); // Variation selector-16

    // Regular chars are not emojis
    expect(isEmojiCp(0x41), false); // 'A'
    expect(isEmojiCp(0x4E00), false); // CJK ideograph
    expect(isEmojiCp(0x20), false); // Space
  });

  test('ambiguous characters', () {
    // ▶ (U+25B6) BLACK RIGHT-POINTING TRIANGLE - ambiguous AND emoji
    expect(widthString('\u25B6'), 1); // non-CJK: ambiguous = 1
    expect(widthString('\u25B6', cjk: true), 2); // CJK: ambiguous = 2
    expect(isEmojiCp(0x25B6), true); // is emoji

    // ▼ (U+25BC) BLACK DOWN-POINTING TRIANGLE - ambiguous but NOT emoji
    expect(widthString('\u25BC'), 1); // non-CJK: ambiguous = 1
    expect(widthString('\u25BC', cjk: true), 2); // CJK: ambiguous = 2
    expect(isEmojiCp(0x25BC), false); // not emoji

    // ◀ (U+25C0) BLACK LEFT-POINTING TRIANGLE - ambiguous AND emoji
    expect(widthString('\u25C0'), 1);
    expect(widthString('\u25C0', cjk: true), 2);
    expect(isEmojiCp(0x25C0), true);

    // ◆ (U+25C6) BLACK DIAMOND - ambiguous but NOT emoji
    expect(widthString('\u25C6'), 1);
    expect(widthString('\u25C6', cjk: true), 2);
    expect(isEmojiCp(0x25C6), false);

    // ☆ (U+2606) WHITE STAR - ambiguous but NOT emoji
    expect(widthString('\u2606'), 1);
    expect(widthString('\u2606', cjk: true), 2);
    expect(isEmojiCp(0x2606), false);

    // ★ (U+2605) BLACK STAR - ambiguous AND emoji
    expect(widthString('\u2605'), 1);
    expect(widthString('\u2605', cjk: true), 2);
    expect(isEmojiCp(0x2605), true);

    // → (U+2192) RIGHTWARDS ARROW - ambiguous but NOT emoji
    expect(widthString('\u2192'), 1);
    expect(widthString('\u2192', cjk: true), 2);
    expect(isEmojiCp(0x2192), false);

    // ○ (U+25CB) WHITE CIRCLE - ambiguous but NOT emoji
    expect(widthString('\u25CB'), 1);
    expect(widthString('\u25CB', cjk: true), 2);
    expect(isEmojiCp(0x25CB), false);
  });

  test('emoji string detection', () {
    // Single emojis
    expect(isEmojiChar('😀'), true);
    expect(isEmojiChar('👍'), true);
    expect(isEmojiChar('❤'), true);

    // ZWJ sequences (first char is emoji)
    expect(isEmojiChar('👨‍👩‍👧‍👦'), true); // Family
    expect(isEmojiChar('👩‍🔬'), true); // Woman scientist

    // Regional indicator pairs
    expect(isEmojiChar('🇺🇸'), true);

    // Empty string
    expect(isEmojiChar(''), false);

    // Non-emoji strings
    expect(isEmojiChar('A'), false);
    expect(isEmojiChar('hello'), false);
    expect(isEmojiChar(' '), false);
  });

  test('property function string variants handle empty', () {
    expect(isEmojiChar(''), false);
    expect(isNonPrintableChar(''), false);
    expect(isNonChar(''), false);
    expect(isPrivateChar(''), false);
  });
}
