import 'package:termansi/termansi.dart' as ansi;
import 'package:termlib/termlib.dart';
import 'package:test/test.dart';

import 'shared.dart';

void main() {
  group('Cursor >', () {
    test('should move the cursor to a position', () async {
      await mockedTest((term, out, _) async {
        term.moveTo(5, 7);
        expect(out.output, equals('\x1b[5;7H'));
      });
    });

    test('should move the cursor to the next line', () async {
      await mockedTest((term, out, _) async {
        term.moveToNextLine();
        expect(out.output, equals('\x1b[1E'));
        out.clearOutput();
        term.moveToNextLine(12);
        expect(out.output, equals('\x1b[12E'));
      });
    });

    test('should move the cursor to the previous line', () async {
      await mockedTest((term, out, _) async {
        term.moveToPrevLine();
        expect(out.output, equals('\x1b[1F'));
        out.clearOutput();
        term.moveToPrevLine(13);
        expect(out.output, equals('\x1b[13F'));
      });
    });

    test('should move the cursor to the given column', () async {
      await mockedTest((term, out, _) async {
        term.moveToColumn(5);
        expect(out.output, equals('\x1b[5G'));
      });
    });

    test('should move the cursor to the given row', () async {
      await mockedTest((term, out, _) async {
        term.moveToRow(5);
        expect(out.output, equals('\x1b[5d'));
      });
    });

    test('should move the cursor up', () async {
      await mockedTest((term, out, _) async {
        term.moveUp();
        expect(out.output, equals('\x1b[1A'));
        out.clearOutput();
        term.moveUp(12);
        expect(out.output, equals('\x1b[12A'));
      });
    });

    test('should move the cursor right', () async {
      await mockedTest((term, out, _) async {
        term.moveRight();
        expect(out.output, equals('\x1b[1C'));
        out.clearOutput();
        term.moveRight(12);
        expect(out.output, equals('\x1b[12C'));
      });
    });

    test('should move the cursor down', () async {
      await mockedTest((term, out, _) async {
        term.moveDown();
        expect(out.output, equals('\x1b[1B'));
        out.clearOutput();
        term.moveDown(12);
        expect(out.output, equals('\x1b[12B'));
      });
    });

    test('should move the cursor left', () async {
      await mockedTest((term, out, _) async {
        term.moveLeft();
        expect(out.output, equals('\x1b[1D'));
        out.clearOutput();
        term.moveLeft(12);
        expect(out.output, equals('\x1b[12D'));
      });
    });

    test('should save the cursor position', () async {
      await mockedTest((term, out, _) async {
        term.savePosition();
        expect(out.output, equals('\x1b7'));
      });
    });

    test('should restore the cursor position', () async {
      await mockedTest((term, out, _) async {
        term.restorePosition();
        expect(out.output, equals('\x1b8'));
      });
    });

    test('should hide the cursor', () async {
      await mockedTest((term, out, _) async {
        term.cursorHide();
        expect(out.output, equals('\x1b[?25l'));
      });
    });

    test('should show the cursor', () async {
      await mockedTest((term, out, _) async {
        term.cursorShow();
        expect(out.output, equals('\x1b[?25h'));
      });
    });

    test('should enable blinking of the terminal cursor', () async {
      await mockedTest((term, out, _) async {
        term.enableBlinking();
        expect(out.output, equals('\x1b[?12h'));
      });
    });

    test('should disable blinking of the terminal cursor', () async {
      await mockedTest((term, out, _) async {
        term.disableBlinking();
        expect(out.output, equals('\x1b[?12l'));
      });
    });

    test('should move the cursor to home position', () async {
      await mockedTest((term, out, _) async {
        term.moveHome();
        expect(out.output, equals('\x1B[H'));
      });
    });

    test('should set the cursor style', () async {
      await mockedTest((term, out, _) async {
        term.setCursorStyle(ansi.CursorStyle.defaultUserShape);
        expect(out.output, equals('\x1b[0 q'));
        out.clearOutput();
        term.setCursorStyle(ansi.CursorStyle.blinkingBlock);
        expect(out.output, equals('\x1b[1 q'));
        out.clearOutput();
        term.setCursorStyle(ansi.CursorStyle.steadyBlock);
        expect(out.output, equals('\x1b[2 q'));
        out.clearOutput();
        term.setCursorStyle(ansi.CursorStyle.blinkingUnderScore);
        expect(out.output, equals('\x1b[3 q'));
        out.clearOutput();
        term.setCursorStyle(ansi.CursorStyle.steadyUnderScore);
        expect(out.output, equals('\x1b[4 q'));
        out.clearOutput();
        term.setCursorStyle(ansi.CursorStyle.blinkingBar);
        expect(out.output, equals('\x1b[5 q'));
        out.clearOutput();
        term.setCursorStyle(ansi.CursorStyle.steadyBar);
        expect(out.output, equals('\x1b[6 q'));
      });
    });
  });
}
