import 'package:termansi/termansi.dart' as ansi;
import 'package:termlib/termlib.dart';
import 'package:test/test.dart';

import 'shared.dart';

void main() {
  group('Cursor >', () {
    test('should move the cursor to a position', () async {
      await mockedTest(
        (out, _, __) async {
          TermLib().moveTo(5, 7);
          expect(out.buf.toString(), equals('\x1b[5;7H'));
        },
      );
    });

    test('should move the cursor to the next line', () async {
      await mockedTest(
        (out, _, __) async {
          TermLib().moveToNextLine();
          expect(out.buf.toString(), equals('\x1b[1E'));
          out.clearOutput();
          TermLib().moveToNextLine(12);
          expect(out.buf.toString(), equals('\x1b[12E'));
        },
      );
    });

    test('should move the cursor to the previous line', () async {
      await mockedTest(
        (out, _, __) async {
          TermLib().moveToPrevLine();
          expect(out.buf.toString(), equals('\x1b[1F'));
          out.clearOutput();
          TermLib().moveToPrevLine(13);
          expect(out.buf.toString(), equals('\x1b[13F'));
        },
      );
    });

    test('should move the cursor to the given column', () async {
      await mockedTest(
        (out, _, __) async {
          TermLib().moveToColumn(5);
          expect(out.buf.toString(), equals('\x1b[5G'));
        },
      );
    });

    test('should move the cursor to the given row', () async {
      await mockedTest(
        (out, _, __) async {
          TermLib().moveToRow(5);
          expect(out.buf.toString(), equals('\x1b[5d'));
        },
      );
    });

    test('should move the cursor up', () async {
      await mockedTest(
        (out, _, __) async {
          TermLib().moveUp();
          expect(out.buf.toString(), equals('\x1b[1A'));
          out.clearOutput();
          TermLib().moveUp(12);
          expect(out.buf.toString(), equals('\x1b[12A'));
        },
      );
    });

    test('should move the cursor right', () async {
      await mockedTest(
        (out, _, __) async {
          TermLib().moveRight();
          expect(out.buf.toString(), equals('\x1b[1C'));
          out.clearOutput();
          TermLib().moveRight(12);
          expect(out.buf.toString(), equals('\x1b[12C'));
        },
      );
    });

    test('should move the cursor down', () async {
      await mockedTest(
        (out, _, __) async {
          TermLib().moveDown();
          expect(out.buf.toString(), equals('\x1b[1B'));
          out.clearOutput();
          TermLib().moveDown(12);
          expect(out.buf.toString(), equals('\x1b[12B'));
        },
      );
    });

    test('should move the cursor left', () async {
      await mockedTest(
        (out, _, __) async {
          TermLib().moveLeft();
          expect(out.buf.toString(), equals('\x1b[1D'));
          out.clearOutput();
          TermLib().moveLeft(12);
          expect(out.buf.toString(), equals('\x1b[12D'));
        },
      );
    });

    test('should save the cursor position', () async {
      await mockedTest(
        (out, _, __) async {
          TermLib().savePosition();
          expect(out.buf.toString(), equals('\x1b7'));
        },
      );
    });

    test('should restore the cursor position', () async {
      await mockedTest(
        (out, _, __) async {
          TermLib().restorePosition();
          expect(out.buf.toString(), equals('\x1b8'));
        },
      );
    });

    test('should hide the cursor', () async {
      await mockedTest(
        (out, _, __) async {
          TermLib().cursorHide();
          expect(out.buf.toString(), equals('\x1b[?25l'));
        },
      );
    });

    test('should show the cursor', () async {
      await mockedTest(
        (out, _, __) async {
          TermLib().cursorShow();
          expect(out.buf.toString(), equals('\x1b[?25h'));
        },
      );
    });

    test('should enable blinking of the terminal cursor', () async {
      await mockedTest(
        (out, _, __) async {
          TermLib().enableBlinking();
          expect(out.buf.toString(), equals('\x1b[?12h'));
        },
      );
    });

    test('should disable blinking of the terminal cursor', () async {
      await mockedTest(
        (out, _, __) async {
          TermLib().disableBlinking();
          expect(out.buf.toString(), equals('\x1b[?12l'));
        },
      );
    });

    test('should move the cursor to home position', () async {
      await mockedTest(
        (out, _, __) async {
          TermLib().moveHome();
          expect(out.buf.toString(), equals('\x1B[H'));
        },
      );
    });

    test('should set the cursor style', () async {
      await mockedTest(
        (out, _, __) async {
          TermLib().setCursorStyle(ansi.CursorStyle.defaultUserShape);
          expect(out.buf.toString(), equals('\x1b[0 q'));
          out.clearOutput();
          TermLib().setCursorStyle(ansi.CursorStyle.blinkingBlock);
          expect(out.buf.toString(), equals('\x1b[1 q'));
          out.clearOutput();
          TermLib().setCursorStyle(ansi.CursorStyle.steadyBlock);
          expect(out.buf.toString(), equals('\x1b[2 q'));
          out.clearOutput();
          TermLib().setCursorStyle(ansi.CursorStyle.blinkingUnderScore);
          expect(out.buf.toString(), equals('\x1b[3 q'));
          out.clearOutput();
          TermLib().setCursorStyle(ansi.CursorStyle.steadyUnderScore);
          expect(out.buf.toString(), equals('\x1b[4 q'));
          out.clearOutput();
          TermLib().setCursorStyle(ansi.CursorStyle.blinkingBar);
          expect(out.buf.toString(), equals('\x1b[5 q'));
          out.clearOutput();
          TermLib().setCursorStyle(ansi.CursorStyle.steadyBar);
          expect(out.buf.toString(), equals('\x1b[6 q'));
        },
      );
    });
  });
}
