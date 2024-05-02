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
    ..writeln('Text Attributes:')
    ..writeln(' ${Text.bold}Bold${Text.resetBold}')
    ..writeln(' ${Text.dim}Dim${Text.resetDim}')
    ..writeln(' ${Text.italic}Italic${Text.resetItalic}')
    ..writeln(' ${Text.underline}Underline${Text.resetUnderline}')
    ..writeln(' ${Text.doubleUnderline}Double Underline${Text.resetDoubleUnderline}')
    ..writeln(' ${Text.curlyUnderline}Curly Underline${Text.resetCurlyUnderline}')
    ..writeln(' ${Text.dottedUnderline}Dotted Underline${Text.resetDottedUnderline}')
    ..writeln(' ${Text.dashedUnderline}Dashed Underline${Text.resetDashedUnderline}')
    ..writeln()
    ..writeln(
        ' ${Text.doubleUnderline}${Color.underlineColor256(120)}Double Underline Color${Text.resetDashedUnderline}${Color.resetUnderlineColor}')
    ..writeln(
        ' ${Text.curlyUnderline}${Color.underlineTrueColor(255, 0, 0)}Curly Underline Color${Text.resetCurlyUnderline}${Color.resetUnderlineColor}')
    ..writeln()
    ..writeln(Term.hyperLink('https://github.com/kascote/termkit', 'Link to project'))
    ..writeln(Term.notify('TermKit', 'Hello from TermAnsi'));
}
