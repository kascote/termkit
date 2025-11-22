import 'package:termlib/termlib.dart';
import 'package:test/test.dart';

import 'shared.dart';

void main() {
  group('Cursor >', () {
    test('should generate eraseDown', () async {
      await mockedTest(
        (out, _, _) async {
          TermLib().eraseDown();
          expect(out.buf.toString(), equals('\x1b[0J'));
        },
      );
    });

    test('should generate eraseUp', () async {
      await mockedTest(
        (out, _, _) async {
          TermLib().eraseUp();
          expect(out.buf.toString(), equals('\x1b[1J'));
        },
      );
    });

    test('should generate eraseScreen', () async {
      await mockedTest(
        (out, _, _) async {
          TermLib().eraseScreen();
          expect(out.buf.toString(), equals('\x1b[2J'));
        },
      );
    });

    test('should generate eraseLineFromCursor', () async {
      await mockedTest(
        (out, _, _) async {
          TermLib().eraseLineFromCursor();
          expect(out.buf.toString(), equals('\x1b[0K'));
        },
      );
    });

    test('should generate eraseLineToCursor', () async {
      await mockedTest(
        (out, _, _) async {
          TermLib().eraseLineToCursor();
          expect(out.buf.toString(), equals('\x1b[1K'));
        },
      );
    });

    test('should generate eraseLine', () async {
      await mockedTest(
        (out, _, _) async {
          TermLib().eraseLine();
          expect(out.buf.toString(), equals('\x1b[2K'));
        },
      );
    });

    test('should generate eraseLineSaved', () async {
      await mockedTest(
        (out, _, _) async {
          TermLib().eraseLineSaved();
          expect(out.buf.toString(), equals('\x1b[3K'));
        },
      );
    });

    test('should generate eraseSaved', () async {
      await mockedTest(
        (out, _, _) async {
          TermLib().eraseSaved();
          expect(out.buf.toString(), equals('\x1b[3J'));
        },
      );
    });

    test('should generate eraseClear (clear screen and move cursor to home position)', () async {
      await mockedTest(
        (out, _, _) async {
          TermLib().eraseClear();
          expect(out.buf.toString(), equals('\x1b[2J\x1b[H'));
        },
      );
    });
  });
}
