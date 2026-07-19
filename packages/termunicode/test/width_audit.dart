// Width-semantics audit: 28 probes of `widthString` behavior at the String
// seam, from the 2026-07-19 review. Prints DIFF lines where behavior
// diverges from the expected answer; since the emoji width policy landed
// (Emoji_Presentation-only override, VS15 honored, lone selectors zero)
// every probe is expected to print ok. Not a `_test.dart` on purpose: the
// settled probes graduate into regression tests as they get covered.
//
// Run from this package:  dart run test/width_audit.dart
import 'dart:io';

import 'package:characters/characters.dart';
import 'package:termunicode/termunicode.dart';

void check(String label, String s, int expected, {bool cjk = false, String? note}) {
  final got = widthString(s, cjk: cjk);
  final cps = s.runes.map((r) => 'U+${r.toRadixString(16).toUpperCase().padLeft(4, '0')}').join(' ');
  final mark = got == expected ? 'ok  ' : 'DIFF';
  stdout.writeln(
    '$mark $label: got=$got expected=$expected  [$cps]${note == null ? '' : '  // $note'}',
  );
}

void main() {
  stdout.writeln('--- the user-reported benchmark case ---');
  check('VS16 symbols x5', '▶️◀️↔️♠️♥️', 10);
  check('play button bare', '▶', 1, note: 'EAW ambiguous, non-cjk -> 1');
  check('play button bare cjk', '▶', 2, cjk: true);
  check('play button +VS16', '▶️', 2);

  stdout.writeln('--- ASCII / control ---');
  check('single a', 'a', 1);
  check('space', ' ', 1);
  check('empty', '', 0);
  check('newline', '\n', 0);
  check('tab', '\t', 0);
  check('DEL 0x7F', '\x7f', 0);
  check('hello world', 'Hello World', 11);

  stdout.writeln('--- emoji clusters (first-codepoint decode path) ---');
  check('flag AR', '🇦🇷', 2, note: 'two regional indicators, one cluster');
  check('single RI', '🇦', 2, note: 'lone regional indicator');
  check('ZWJ family', '👨‍👩‍👧‍👦', 2);
  check('thumbs skin tone', '👍🏽', 2);
  check('keycap 1', '1️⃣', 2, note: 'digit + VS16 + enclosing keycap');
  check('bare VS16', '️', 0, note: 'lone variation selector, no base -> 0');

  stdout.writeln('--- VS15 text presentation ---');
  check('umbrella bare', '☂', 1, note: 'Emoji but not Emoji_Presentation, EAW N -> 1');
  check('umbrella +VS15', '☂︎', 1, note: 'VS15 requests text presentation');
  check('umbrella +VS16', '☂️', 2);
  check('watch bare', '⌚', 2, note: 'U+231A Emoji_Presentation -> wide is right');

  stdout.writeln('--- combining / decomposed ---');
  check('e + combining acute', 'é', 1);
  check('lone combining acute', '́', 0);
  check('hangul decomposed', '한', 2, note: 'L+V+T jamo = one syllable');

  stdout.writeln('--- CJK / ambiguous ---');
  check('ni hao', '你好', 4);
  check('inverted excl', '¡', 1);
  check('inverted excl cjk', '¡', 2, cjk: true);

  stdout.writeln('--- widthCp / widthChars consistency ---');
  final probe = ['a', '你', '▶️', '🇦🇷', '👨‍👩‍👧‍👦'];
  for (final s in probe) {
    final viaString = widthString(s);
    final viaChars = widthChars(s.characters);
    if (viaString != viaChars) {
      stdout.writeln('DIFF widthString($s)=$viaString != widthChars=$viaChars');
    }
  }
  stdout.writeln('consistency probes done');
}
