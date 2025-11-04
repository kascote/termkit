import 'package:characters/characters.dart';

import './table.dart';

const _asciiPrintableStart = 0x20;
const _asciiPrintableEnd = 0x7F;
const _asciiControlEnd = 0xA0;
const int _maxCodePoints = 0x10FFFF;

int _getCPData(int codePoint) {
  return stage3[stage2[stage1[codePoint >> 8] + (codePoint & 0xff)]];
}

/// Retrieve the encoded value for a given code point.
int _getValue(int codePoint, {bool cjk = false}) {
  if (codePoint < _asciiPrintableEnd) {
    // U+0020 to U+007F (exclusive) are single-width ASCII codepoints
    if (codePoint >= _asciiPrintableStart) return 1;
    // U+0000 *is* a control code, but it's special-cased
    if (codePoint == 0) return 0;
    // U+0001 to U+0020 (exclusive) are control codes
    return 0;
  } else if (codePoint >= _asciiControlEnd) {
    final value = _getCPData(codePoint);
    // if value is 3, means that is a ambiguous character
    // in a cjk context will be `wide` if not is `normal`
    if (value == 3) return cjk ? 2 : 1;
    return value;
  } else {
    // U+007F to U+00A0 (exclusive) are control codes
    return 0;
  }
}

/// Returns the Unicode version of the data.
String unicodeVersion() => unicodeUCD;

/// Returns the width of a given code point.
///
/// If [cjk] is true, means that is working in a Chinese, Japanese, Korean
/// context, on that case `ambiguous` characters are treated as `wide`.
int widthCp(int codePoint, {bool cjk = false}) {
  if (codePoint < 0 || codePoint > _maxCodePoints) {
    throw ArgumentError.value(codePoint, 'codePoint', 'Must be 0-0x10FFFF');
  }
  return _getValue(codePoint, cjk: cjk) & 0x3;
}

/// Returns the terminal display width of a given string.
///
/// If [cjk] is true, means that is working in a Chinese, Japanese, Korean
/// context, on that case `ambiguous` characters are treated as `wide`.
///
/// For string literals or variables, use this function.
/// If you're already working with [Characters], use [widthChars]
/// to avoid an unnecessary conversion.
int widthString(String value, {bool cjk = false}) {
  if (value.isEmpty) return 0;
  return widthChars(value.characters, cjk: cjk);
}

/// Returns the display width of a given character.
///
/// If [cjk] is true, means that is working in a Chinese, Japanese, Korean
/// context, on that case `ambiguous` characters are treated as `wide`.
///
/// The rationale to use Characters is that it can handle grapheme clusters and
/// surrogate pairs. We only take the first rune to calculate the width,
/// assuming that all other codepoints work as variations of the first one, but
/// not modify the final width.
int widthChars(Characters value, {bool cjk = false}) {
  if (value.isEmpty) return 0;
  return value.fold(0, (width, char) => width + widthCp(char.runes.first, cjk: cjk));
}

/// Check if a given code point is an emoji.
bool isEmojiCp(int codePoint) => _getCPData(codePoint) & 0x4 == 0x4;

/// Check if the first character in the string is an emoji.
bool isEmojiChar(String value) => value.isNotEmpty && isEmojiCp(value.runes.first);

/// Check if a given code point is non-printable.
///
/// Non-printable characters are those in this categories:
/// - `Cc` (Other, Control)
/// - `Cf` (Other, Format)
/// - `Cs` (Other, Surrogate)
/// - `Cn` (Other, Not Assigned)
/// - `Co` (Other, Private Use)
/// - `Zl` (Separator, Line)
/// - `Zp` (Separator, Paragraph)
///
bool isNonPrintableCp(int codePoint) => _getCPData(codePoint) & 0x8 == 0x8;

/// Check if the first character in the string is non-printable one.
/// Non-printable characters are those in this categories:
/// - `Cc` (Other, Control)
/// - `Cf` (Other, Format)
/// - `Cs` (Other, Surrogate)
/// - `Cn` (Other, Not Assigned)
/// - `Co` (Other, Private Use)
/// - `Zl` (Separator, Line)
/// - `Zp` (Separator, Paragraph)
///
/// ref: https://www.unicode.org/reports/tr44/#GC_Values_Table
bool isNonPrintableChar(String value) => value.isNotEmpty && isNonPrintableCp(value.runes.first);

/// Check if a given code point is a non-character.
///
/// For a reference what is considered a nonCharacters check this reference
/// https://www.unicode.org/faq/private_use.html#noncharacters
bool isNonCharCp(int codePoint) => _getCPData(codePoint) & 0x10 == 0x10;

/// Check if the first character in the string is a non-character one.
///
/// For a reference what is considered a nonCharacters check this reference
/// https://www.unicode.org/faq/private_use.html#noncharacters
bool isNonChar(String value) => value.isNotEmpty && isNonCharCp(value.runes.first);

/// Check if a given code point is in the private space.
///
/// Private use characters are those in this categories:
/// - `Co` (Other, Private Use)
///
/// ref: https://www.unicode.org/reports/tr44/#GC_Values_Table
bool isPrivateCp(int codePoint) => _getCPData(codePoint) & 0x20 == 0x20;

/// Check if the first character in the string is in the private space.
///
/// Private use characters are those in this categories:
/// - `Co` (Other, Private Use)
///
/// ref: https://www.unicode.org/reports/tr44/#GC_Values_Table
bool isPrivateChar(String value) => value.isNotEmpty && isPrivateCp(value.runes.first);
