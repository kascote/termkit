import 'package:termansi/termansi.dart' as ansi;
import 'package:termlib/termlib.dart';
import 'package:termparser/termparser_events.dart';
import 'package:test/test.dart';

import 'termlib_mock.dart';

void main() {
  final stdoutMock = MockStdout();
  final term = TermLib(stdoutAdapter: stdoutMock);
  group('Cursor >', () {
    setUp(stdoutMock.clearOutput);

    test('should move the cursor to a position', () {
      term.moveTo(5, 7);
      expect(stdoutMock.buf.toString(), equals('\x1b[5;7H'));
    });

    test('should move the cursor to the next line', () {
      term.moveToNextLine();
      expect(stdoutMock.buf.toString(), equals('\x1b[1E'));
      stdoutMock.clearOutput();
      term.moveToNextLine(12);
      expect(stdoutMock.buf.toString(), equals('\x1b[12E'));
    });

    test('should move the cursor to the previous line', () {
      term.moveToPrevLine();
      expect(stdoutMock.buf.toString(), equals('\x1b[1F'));
      stdoutMock.clearOutput();
      term.moveToPrevLine(13);
      expect(stdoutMock.buf.toString(), equals('\x1b[13F'));
    });

    test('should move the cursor to the given column', () {
      term.moveToColumn(5);
      expect(stdoutMock.buf.toString(), equals('\x1b[5G'));
    });

    test('should move the cursor to the given row', () {
      term.moveToRow(5);
      expect(stdoutMock.buf.toString(), equals('\x1b[5d'));
    });

    test('should move the cursor up', () {
      term.moveUp();
      expect(stdoutMock.buf.toString(), equals('\x1b[1A'));
      stdoutMock.clearOutput();
      term.moveUp(12);
      expect(stdoutMock.buf.toString(), equals('\x1b[12A'));
    });

    test('should move the cursor right', () {
      term.moveRight();
      expect(stdoutMock.buf.toString(), equals('\x1b[1C'));
      stdoutMock.clearOutput();
      term.moveRight(12);
      expect(stdoutMock.buf.toString(), equals('\x1b[12C'));
    });

    test('should move the cursor down', () {
      term.moveDown();
      expect(stdoutMock.buf.toString(), equals('\x1b[1B'));
      stdoutMock.clearOutput();
      term.moveDown(12);
      expect(stdoutMock.buf.toString(), equals('\x1b[12B'));
    });

    test('should move the cursor left', () {
      term.moveLeft();
      expect(stdoutMock.buf.toString(), equals('\x1b[1D'));
      stdoutMock.clearOutput();
      term.moveLeft(12);
      expect(stdoutMock.buf.toString(), equals('\x1b[12D'));
    });

    test('should save the cursor position', () {
      term.savePosition();
      expect(stdoutMock.buf.toString(), equals('\x1b7'));
    });

    test('should restore the cursor position', () {
      term.restorePosition();
      expect(stdoutMock.buf.toString(), equals('\x1b8'));
    });

    test('should hide the cursor', () {
      term.cursorHide();
      expect(stdoutMock.buf.toString(), equals('\x1b[?25l'));
    });

    test('should show the cursor', () {
      term.cursorShow();
      expect(stdoutMock.buf.toString(), equals('\x1b[?25h'));
    });

    test('should enable blinking of the terminal cursor', () {
      term.enableBlinking();
      expect(stdoutMock.buf.toString(), equals('\x1b[?12h'));
    });

    test('should disable blinking of the terminal cursor', () {
      term.disableBlinking();
      expect(stdoutMock.buf.toString(), equals('\x1b[?12l'));
    });

    test('should set the cursor style', () {
      term.setCursorStyle(ansi.CursorStyle.defaultUserShape);
      expect(stdoutMock.buf.toString(), equals('\x1b[0 q'));
      stdoutMock.clearOutput();
      term.setCursorStyle(ansi.CursorStyle.blinkingBlock);
      expect(stdoutMock.buf.toString(), equals('\x1b[1 q'));
      stdoutMock.clearOutput();
      term.setCursorStyle(ansi.CursorStyle.steadyBlock);
      expect(stdoutMock.buf.toString(), equals('\x1b[2 q'));
      stdoutMock.clearOutput();
      term.setCursorStyle(ansi.CursorStyle.blinkingUnderScore);
      expect(stdoutMock.buf.toString(), equals('\x1b[3 q'));
      stdoutMock.clearOutput();
      term.setCursorStyle(ansi.CursorStyle.steadyUnderScore);
      expect(stdoutMock.buf.toString(), equals('\x1b[4 q'));
      stdoutMock.clearOutput();
      term.setCursorStyle(ansi.CursorStyle.blinkingBar);
      expect(stdoutMock.buf.toString(), equals('\x1b[5 q'));
      stdoutMock.clearOutput();
      term.setCursorStyle(ansi.CursorStyle.steadyBar);
      expect(stdoutMock.buf.toString(), equals('\x1b[6 q'));
    });
  });

  test(
    'cursor position',
    () async {
      final ev = await term.cursorPosition;
      expect(ev, equals(const CursorPositionEvent(0, 0)));
    },
    skip: 'implement event mockup',
  );
}
