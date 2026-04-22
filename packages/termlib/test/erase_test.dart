import 'package:termlib/termlib.dart';
import 'package:test/test.dart';

import 'shared.dart';

void main() {
  group('Cursor >', () {
    test('should generate eraseDown', () async {
      await mockedTest((term, out, _) async {
        term.eraseDown();
        expect(out.output, equals('\x1b[0J'));
      });
    });

    test('should generate eraseUp', () async {
      await mockedTest((term, out, _) async {
        term.eraseUp();
        expect(out.output, equals('\x1b[1J'));
      });
    });

    test('should generate eraseScreen', () async {
      await mockedTest((term, out, _) async {
        term.eraseScreen();
        expect(out.output, equals('\x1b[2J'));
      });
    });

    test('should generate eraseLineFromCursor', () async {
      await mockedTest((term, out, _) async {
        term.eraseLineFromCursor();
        expect(out.output, equals('\x1b[0K'));
      });
    });

    test('should generate eraseLineToCursor', () async {
      await mockedTest((term, out, _) async {
        term.eraseLineToCursor();
        expect(out.output, equals('\x1b[1K'));
      });
    });

    test('should generate eraseLine', () async {
      await mockedTest((term, out, _) async {
        term.eraseLine();
        expect(out.output, equals('\x1b[2K'));
      });
    });

    test('should generate eraseLineSaved', () async {
      await mockedTest((term, out, _) async {
        term.eraseLineSaved();
        expect(out.output, equals('\x1b[3K'));
      });
    });

    test('should generate eraseSaved', () async {
      await mockedTest((term, out, _) async {
        term.eraseSaved();
        expect(out.output, equals('\x1b[3J'));
      });
    });

    test('should generate eraseClear (clear screen and move cursor to home position)', () async {
      await mockedTest((term, out, _) async {
        term.eraseClear();
        expect(out.output, equals('\x1b[2J\x1b[H'));
      });
    });
  });
}
