## 0.3.0

- feature: `widthString` gained a scalar-scan fast path — code-unit widths are
  summed straight from the table while every unit is a BMP scalar of non-zero
  width; the first surrogate or zero-width unit (combining marks, ZWJ,
  variation selectors, controls) falls back to the grapheme-cluster path.
  One ASCII char drops from ~225 to ~48 ns/call, a 40-char ASCII line from
  ~5.0 to ~0.3 µs, a 12-char CJK line from ~6.4 to ~0.5 µs; strings the scan
  cannot answer pay a few percent for the wasted scan. Divergence: a
  prepend-class cluster (e.g. U+0600 + digit) is summed per codepoint on the
  fast path, matching what terminals draw, while the cluster path counts only
  its first codepoint.
- chore: the `widthChars` cluster fold is a plain loop now; the outdated
  `benchmark_width.dart` was removed (`benchmark_width_string.dart` is the
  width benchmark).
- breaking change: emoji width policy narrowed — the table forces width 2 only
  for `Emoji_Presentation` codepoints. Text-presentation-default symbols such
  as U+2602 umbrella now measure 1 (previously 2); an emoji presentation
  selector (VS16) still makes them 2. Flags and other emoji-presentation
  characters are unchanged.
- feature: the text presentation selector VS15 (U+FE0E) is honored — a cluster
  carrying it measures 1. Terminals that ignore VS15 draw the glyph wider than
  measured; that is their deficiency.
- fix: a lone variation selector now measures 0 (a bare VS16 measured 2).
- fix: `EmojiDataUCD.find` binary-searched overlapping ranges and missed 46
  covered codepoints (U+1F484 lipstick, U+1F48B kiss mark and the
  U+1F493-1F497 hearts among them), which shipped with the emoji bit unset;
  `isEmojiCp` now answers true for them. `EmojiDataUCD` stores rows per
  property and gained `findProp(property, cp)`.
- chore: update unicode data to 17.0.0. Unicode 17 removed non-emoji symbols
  (e.g. U+2605 black star) from `Extended_Pictographic`, so `isEmojiCp` no
  longer reports them. The generated table grows ~2.7% (157.6 KB to 161.9 KB).

## 0.2.0

- fix: include RIS emojis as double width
- feature: refactor generator and added smoke tests
- feature: improve tests for ucd parsers
- chore: update unicode data to 16.0.0
- fix: correct width for some ambiguous characters
- fix: emoji-ambiguous characters widths
- fix: improve performance of width calculation
- Added new function `widthChars` that use the Characters package.
- Updated `widthString` string to use `widthChars` function.

## 0.1.0

- Initial version.
