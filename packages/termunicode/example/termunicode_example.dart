import 'dart:io';

import 'package:termunicode/termunicode.dart';

void main() async {
  final withEsc = 'Hola \x1bmundo\x1b'
      .runes
      .fold(
        StringBuffer(),
        (sb, rune) => isNonPrintableCp(rune) ? (sb..write('')) : (sb..write(String.fromCharCode(rune))),
      )
      .toString();

  final strs = [
    '你好 世界',
    'ｈｅｌｌｏ',
    'hello 🌎',
    'hello 👋🏻',
    'hello 👩‍🔬',
    withEsc,
    'コンニチハ',
    '🇦🇷🇰🇷🇿🇲',
  ];

  stdout.writeln(' 123456789012345 ');
  for (final str in strs) {
    stdout.writeln('|${centerString(str, 15)}| => len: ${widthString(str)}');
  }
  stdout.writeln('\nversion: ${unicodeVersion()}');
}

String centerString(String str, int width) {
  final strWidth = widthString(str);
  final pad = (width - strWidth) ~/ 2;
  return ' ' * pad + str + ' ' * (width - strWidth - pad);
}
