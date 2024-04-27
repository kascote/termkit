import 'dart:io';

import 'package:termunicode/termunicode.dart';

void main() async {
  const str1 = '你好 世界';
  const str2 = 'ｈｅｌｌｏ';
  const str3 = 'hello 🌎';
  const str4 = 'Hola \x1bmundo\x1b';
  final str5 = str4.runes
      .fold(
        StringBuffer(),
        (sb, rune) => isNonPrintableCp(rune) ? (sb..write('')) : (sb..write(String.fromCharCode(rune))),
      )
      .toString();

  stdout
    ..writeln(' 123456789012345 ')
    ..writeln('|${centerString(str1, 15)}| => len: ${widthString(str1)}')
    ..writeln('|${centerString(str2, 15)}| => len: ${widthString(str2)}')
    ..writeln('|${centerString(str3, 15)}| => len: ${widthString(str3)}')
    ..writeln('|${centerString(str5, 15)}| => len: ${widthString(str5)}')
    ..writeln('\nversion: ${unicodeVersion()}');
}

String centerString(String str, int width) {
  final strWidth = widthString(str);
  final pad = (width - strWidth) ~/ 2;
  return ' ' * pad + str + ' ' * (width - strWidth - pad);
}
