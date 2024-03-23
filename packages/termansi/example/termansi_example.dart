import 'dart:io';

import 'package:termansi/termansi.dart';

void main() {
  stdout
    ..write('${Color.yellow} TermAnsi ${Color.reset}')
    ..write('${Color.color256Bg(120)}${Color.black} TermAnsi ${Color.reset} ')
    ..writeln('${Color.trueColorBg(220, 98, 217)}${Color.white} TermAnsi ${Color.reset}')
    ..write('Cursor Block: ${Cursor.setCursorStyle(CursorStyle.steadyBlock)}');

  sleep(const Duration(seconds: 3));
  stdout
    ..write('${Erase.lineAll}${Cursor.moveToColumn(0)}')
    ..write('Cursor Blinking Block: ${Cursor.setCursorStyle(CursorStyle.blinkingBlock)}');

  sleep(const Duration(seconds: 3));
  stdout
    ..write('${Erase.lineAll}${Cursor.moveToColumn(0)}')
    ..write('Cursor Blinking Bar: ${Cursor.setCursorStyle(CursorStyle.blinkingBar)}');

  sleep(const Duration(seconds: 3));
  stdout
    ..write('${Erase.lineAll}${Cursor.moveToColumn(0)}')
    ..write('Cursor Blinking Underscore: ${Cursor.setCursorStyle(CursorStyle.blinkingUnderScore)}');

  sleep(const Duration(seconds: 3));
  stdout
    ..write('${Erase.lineAll}${Cursor.moveToColumn(0)}')
    ..write('Cursor Steady Bar: ${Cursor.setCursorStyle(CursorStyle.steadyBar)}');

  sleep(const Duration(seconds: 3));
  stdout
    ..write('${Erase.lineAll}${Cursor.moveToColumn(0)}')
    ..write('Move Cursor: ${Cursor.setCursorStyle(CursorStyle.steadyBlock)}');

  const cursorPath = [
    Cursor.moveRight,
    Cursor.moveUp,
    Cursor.moveLeft,
    Cursor.moveDown,
  ];

  for (final path in cursorPath) {
    for (var i = 0; i < 3; i++) {
      stdout.write(path(1));
      sleep(const Duration(milliseconds: 300));
    }
  }

  stdout
    ..writeln()
    ..writeln(Term.hyperLink('https://github.com/kascote/termkit', 'TermKit'))
    ..writeln(Term.notify('TermKit', 'Hello from TermAnsi'));
}
