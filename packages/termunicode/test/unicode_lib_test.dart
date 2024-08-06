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

  test('isNonChar', () {
    expect(isNonChar('\uFDD0'), true);
    expect(isNonCharCp(0xFDDA), true);
    expect(isNonCharCp(0x5FFFE), true);
    expect(isNonCharCp(0x9FFFF), true);
    expect(isNonCharCp(0x10FFFF), true);
  });

  test('isPrivate', () {
    expect(isPrivateChar('\uE000'), true);
    expect(isPrivateCp(0xF8FF), true);
    expect(isPrivateCp(0xF0000), true);
    expect(isPrivateCp(0xF1234), true);
    expect(isPrivateCp(0xFFFFD), true);
    expect(isPrivateCp(0x10FFFD), true);
  });
}
