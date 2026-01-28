import 'package:termansi/termansi.dart';
import 'package:test/test.dart';

void main() {
  group('Escape sequence constants >', () {
    test('ESC is correct', () {
      expect(ESC, equals('\x1b'));
    });

    test('CSI is correct', () {
      expect(CSI, equals('\x1b['));
    });

    test('OSC is correct', () {
      expect(OSC, equals('\x1b]'));
    });

    test('BEL is correct', () {
      expect(BEL, equals('\x07'));
    });

    test('ST (String Terminator) is correct', () {
      expect(ST, equals('\x1b\\'));
    });
  });

  group('Escape sequence relationships >', () {
    test('CSI starts with ESC', () {
      expect(CSI, startsWith(ESC));
    });

    test('OSC starts with ESC', () {
      expect(OSC, startsWith(ESC));
    });

    test('ST starts with ESC', () {
      expect(ST, startsWith(ESC));
    });

    test('CSI is ESC followed by [', () {
      expect(CSI, equals('$ESC['));
    });

    test('OSC is ESC followed by ]', () {
      expect(OSC, equals('$ESC]'));
    });

    test(r'ST is ESC followed by \', () {
      expect(ST, equals('$ESC\\'));
    });
  });

  group('Escape sequence usage >', () {
    test('CSI is used in cursor sequences', () {
      expect(Cursor.home, startsWith(CSI));
      expect(Cursor.moveUp(), startsWith(CSI));
    });

    test('CSI is used in color sequences', () {
      expect(Color.red, startsWith(CSI));
      expect(Color.reset, startsWith(CSI));
    });

    test('CSI is used in text style sequences', () {
      expect(Text.bold, startsWith(CSI));
      expect(Text.italic, startsWith(CSI));
    });

    test('OSC is used in terminal sequences', () {
      expect(Term.setTerminalTitle('test'), startsWith(OSC));
      expect(Term.clipboard('c', 'data'), startsWith(OSC));
    });

    test('ST is used as OSC terminator', () {
      expect(Term.hyperLink('url', 'text'), contains(ST));
      expect(Term.clipboard('c', 'data'), endsWith(ST));
    });

    test('BEL is used as alternative terminator', () {
      expect(Term.setTerminalTitle('test'), endsWith(BEL));
    });
  });

  group('Escape sequence properties >', () {
    test('ESC is single character', () {
      expect(ESC.length, equals(1));
    });

    test('CSI is two characters', () {
      expect(CSI.length, equals(2));
    });

    test('OSC is two characters', () {
      expect(OSC.length, equals(2));
    });

    test('BEL is single character', () {
      expect(BEL.length, equals(1));
    });

    test('ST is two characters', () {
      expect(ST.length, equals(2));
    });

    test('all constants are non-empty', () {
      expect(ESC, isNotEmpty);
      expect(CSI, isNotEmpty);
      expect(OSC, isNotEmpty);
      expect(BEL, isNotEmpty);
      expect(ST, isNotEmpty);
    });
  });
}
