# Overview

Dart library for Unicode character properties in terminal applications. Provides character width calculation, emoji detection, and printable character checks using a 3-stage table lookup.

### Regenerate Unicode tables

```bash
dart run tool/generator.dart
```

Downloads UCD files from unicode.org to `data/` dir and overwrites `lib/src/table.dart`.

## Architecture

### Two-Library Export Pattern

- `lib/termunicode.dart`: Main library. Character inspection utilities (width, emoji, printable checks). This is what consumers use.
- `lib/term_ucd.dart`: UCD parser library. Only needed for table generation. Exports parsers for EastAsianWidth, EmojiData, UnicodeData, DerivedCoreProps, HangulSyllableType.

### 3-Stage Table Lookup

Fast character property retrieval via `lib/src/table.dart`:

- `stage1`: Maps codepoint upper bits to stage2 offset
- `stage2`: Maps to stage3 index
- `stage3`: Encoded property bits

Lookup: `stage3[stage2[stage1[cp >> 8] + (cp & 0xff)]]`

### Property Encoding (lib/src/unicode_lib.dart:119-137)

Single byte per codepoint in stage3:

```
Bits 0-1: width (0=zero, 1=narrow, 2=wide, 3=ambiguous)
Bit 2: emoji
Bit 3: non-printable
Bit 4: non-character
Bit 5: private-use
```

### CJK Context Handling

`cjk` param on width functions treats ambiguous chars (value=3) as wide(2) instead of narrow(1).

### Table Generation (tool/)

Downloads UCD files from unicode.org to `data/`, overwrites `lib/src/table.dart`. Split by concern:

- `tool/constants.dart`: Shared constants (Unicode version, URLs, paths)
- `tool/downloader.dart`: UCD file downloading from unicode.org
- `tool/table_builder.dart`: 3-stage table construction, property encoding
- `tool/emitter.dart`: Code generation to `lib/src/table.dart`
- `tool/generator.dart`: Orchestration entry point

Process:

1. Downloads 5 UCD files from unicode.org
2. Parses each with specialized parsers from `lib/term_ucd.dart`
3. Computes property byte for all codepoints 0-0x10FFFF
4. Deduplicates stage2/stage3 blocks via SHA256 hashing
5. Emits `lib/src/table.dart` with Uint16List/Uint8List

### Special Cases in Width Calculation

- Emoji property → force width=2 (overrides EAW table for Regional Indicators)
- Default_Ignorable_Code_Point → width=0
- Hangul Vowel_Jamo/Trailing_Jamo → width=0 (combined graphemes use Leading_Jamo width)
- U+115F (HANGUL CHOSEONG FILLER) → width=2 despite being default-ignorable
- U+00AD (soft hyphen) → width=1
- Control chars (Cc, Mn, Me categories) → width=0
