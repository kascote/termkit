import 'package:termlib/termlib.dart';
import 'package:test/test.dart';

import 'termlib_mock.dart';

void main() {
  final stdoutMock = MockStdout();
  final term = TermLib(stdoutAdapter: stdoutMock);

  group('Cursor >', () {
    setUp(stdoutMock.clearOutput);

    test('should generate eraseDown', () {
      term.eraseDown();
      expect(stdoutMock.buf.toString(), equals('\x1b[0J'));
    });

    test('should generate eraseUp', () {
      term.eraseUp();
      expect(stdoutMock.buf.toString(), equals('\x1b[1J'));
    });

    test('should generate eraseScreen', () {
      term.eraseScreen();
      expect(stdoutMock.buf.toString(), equals('\x1b[2J'));
    });

    test('should generate eraseLineFromCursor', () {
      term.eraseLineFromCursor();
      expect(stdoutMock.buf.toString(), equals('\x1b[0K'));
    });

    test('should generate eraseLineToCursor', () {
      term.eraseLineToCursor();
      expect(stdoutMock.buf.toString(), equals('\x1b[1K'));
    });

    test('should generate eraseLine', () {
      term.eraseLine();
      expect(stdoutMock.buf.toString(), equals('\x1b[2K'));
    });

    test('should generate eraseLineSaved', () {
      term.eraseLineSaved();
      expect(stdoutMock.buf.toString(), equals('\x1b[3K'));
    });

    test('should generate eraseSaved', () {
      term.eraseSaved();
      expect(stdoutMock.buf.toString(), equals('\x1b[3J'));
    });

    test('should generate eraseClear', () {
      term.eraseClear();
      expect(stdoutMock.buf.toString(), equals('\x1b[2J\x1b[H'));
    });
  });
}
