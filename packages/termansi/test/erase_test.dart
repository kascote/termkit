import 'package:termansi/termansi.dart';
import 'package:test/test.dart';

void main() {
  group('Erase screen sequences >', () {
    test('screenFromCursor produces correct sequence', () {
      expect(Erase.screenFromCursor, equals('\x1b[0J'));
    });

    test('screenToCursor produces correct sequence', () {
      expect(Erase.screenToCursor, equals('\x1b[1J'));
    });

    test('screenAll produces correct sequence', () {
      expect(Erase.screenAll, equals('\x1b[2J'));
    });

    test('screenSaved produces correct sequence', () {
      expect(Erase.screenSaved, equals('\x1b[3J'));
    });
  });

  group('Erase line sequences >', () {
    test('lineFromCursor produces correct sequence', () {
      expect(Erase.lineFromCursor, equals('\x1b[0K'));
    });

    test('lineToCursor produces correct sequence', () {
      expect(Erase.lineToCursor, equals('\x1b[1K'));
    });

    test('lineAll produces correct sequence', () {
      expect(Erase.lineAll, equals('\x1b[2K'));
    });

    test('lineSaved produces correct sequence', () {
      expect(Erase.lineSaved, equals('\x1b[3K'));
    });
  });

  group('Erase.clear >', () {
    test('clear combines screenAll and home', () {
      expect(Erase.clear, equals('\x1b[2J\x1b[H'));
    });

    test('clear contains screenAll sequence', () {
      expect(Erase.clear, contains('\x1b[2J'));
    });

    test('clear contains home sequence', () {
      expect(Erase.clear, contains('\x1b[H'));
    });
  });

  group('Erase sequence patterns >', () {
    test('all screen erase sequences use J command', () {
      expect(Erase.screenFromCursor, contains('J'));
      expect(Erase.screenToCursor, contains('J'));
      expect(Erase.screenAll, contains('J'));
      expect(Erase.screenSaved, contains('J'));
    });

    test('all line erase sequences use K command', () {
      expect(Erase.lineFromCursor, contains('K'));
      expect(Erase.lineToCursor, contains('K'));
      expect(Erase.lineAll, contains('K'));
      expect(Erase.lineSaved, contains('K'));
    });

    test('all erase sequences start with CSI', () {
      expect(Erase.screenFromCursor, startsWith('\x1b['));
      expect(Erase.lineFromCursor, startsWith('\x1b['));
      expect(Erase.screenAll, startsWith('\x1b['));
    });
  });
}
