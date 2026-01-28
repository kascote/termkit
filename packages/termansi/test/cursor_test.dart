import 'package:termansi/termansi.dart';
import 'package:test/test.dart';

void main() {
  group('Cursor constants >', () {
    test('home produces correct sequence', () {
      expect(Cursor.home, equals('\x1b[H'));
    });

    test('savePosition produces correct sequence', () {
      expect(Cursor.savePosition, equals('\x1b7'));
    });

    test('restorePosition produces correct sequence', () {
      expect(Cursor.restorePosition, equals('\x1b8'));
    });

    test('hide produces correct sequence', () {
      expect(Cursor.hide, equals('\x1b[?25l'));
    });

    test('show produces correct sequence', () {
      expect(Cursor.show, equals('\x1b[?25h'));
    });

    test('enableBlinking produces correct sequence', () {
      expect(Cursor.enableBlinking, equals('\x1b[?12h'));
    });

    test('disableBlinking produces correct sequence', () {
      expect(Cursor.disableBlinking, equals('\x1b[?12l'));
    });

    test('requestPosition produces correct sequence', () {
      expect(Cursor.requestPosition, equals('\x1b[6n'));
    });
  });

  group('Cursor.moveTo >', () {
    test('generates correct position sequences', () {
      expect(Cursor.moveTo(1, 1), equals('\x1b[1;1H'));
      expect(Cursor.moveTo(5, 7), equals('\x1b[5;7H'));
      expect(Cursor.moveTo(10, 20), equals('\x1b[10;20H'));
      expect(Cursor.moveTo(999, 999), equals('\x1b[999;999H'));
    });

    test('assertions fire for invalid Y position', () {
      expect(() => Cursor.moveTo(0, 1), throwsA(isA<AssertionError>()));
      expect(() => Cursor.moveTo(-5, 10), throwsA(isA<AssertionError>()));
    });

    test('assertions fire for invalid X position', () {
      expect(() => Cursor.moveTo(1, 0), throwsA(isA<AssertionError>()));
      expect(() => Cursor.moveTo(10, -5), throwsA(isA<AssertionError>()));
    });
  });

  group('Cursor.moveToColumn >', () {
    test('generates correct column sequences', () {
      expect(Cursor.moveToColumn(1), equals('\x1b[1G'));
      expect(Cursor.moveToColumn(5), equals('\x1b[5G'));
      expect(Cursor.moveToColumn(20), equals('\x1b[20G'));
      expect(Cursor.moveToColumn(80), equals('\x1b[80G'));
    });

    test('assertions fire for invalid column', () {
      expect(() => Cursor.moveToColumn(0), throwsA(isA<AssertionError>()));
      expect(() => Cursor.moveToColumn(-5), throwsA(isA<AssertionError>()));
    });
  });

  group('Cursor.moveToRow >', () {
    test('generates correct row sequences', () {
      expect(Cursor.moveToRow(1), equals('\x1b[1d'));
      expect(Cursor.moveToRow(5), equals('\x1b[5d'));
      expect(Cursor.moveToRow(20), equals('\x1b[20d'));
      expect(Cursor.moveToRow(100), equals('\x1b[100d'));
    });

    test('assertions fire for invalid row', () {
      expect(() => Cursor.moveToRow(0), throwsA(isA<AssertionError>()));
      expect(() => Cursor.moveToRow(-5), throwsA(isA<AssertionError>()));
    });
  });

  group('Cursor.moveUp >', () {
    test('generates correct sequences with default', () {
      expect(Cursor.moveUp(), equals('\x1b[1A'));
    });

    test('generates correct sequences with parameter', () {
      expect(Cursor.moveUp(), equals('\x1b[1A'));
      expect(Cursor.moveUp(5), equals('\x1b[5A'));
      expect(Cursor.moveUp(12), equals('\x1b[12A'));
    });

    test('assertions fire for invalid values', () {
      expect(() => Cursor.moveUp(0), throwsA(isA<AssertionError>()));
      expect(() => Cursor.moveUp(-5), throwsA(isA<AssertionError>()));
    });
  });

  group('Cursor.moveDown >', () {
    test('generates correct sequences with default', () {
      expect(Cursor.moveDown(), equals('\x1b[1B'));
    });

    test('generates correct sequences with parameter', () {
      expect(Cursor.moveDown(), equals('\x1b[1B'));
      expect(Cursor.moveDown(5), equals('\x1b[5B'));
      expect(Cursor.moveDown(12), equals('\x1b[12B'));
    });

    test('assertions fire for invalid values', () {
      expect(() => Cursor.moveDown(0), throwsA(isA<AssertionError>()));
      expect(() => Cursor.moveDown(-5), throwsA(isA<AssertionError>()));
    });
  });

  group('Cursor.moveRight >', () {
    test('generates correct sequences with default', () {
      expect(Cursor.moveRight(), equals('\x1b[1C'));
    });

    test('generates correct sequences with parameter', () {
      expect(Cursor.moveRight(), equals('\x1b[1C'));
      expect(Cursor.moveRight(5), equals('\x1b[5C'));
      expect(Cursor.moveRight(12), equals('\x1b[12C'));
    });

    test('assertions fire for invalid values', () {
      expect(() => Cursor.moveRight(0), throwsA(isA<AssertionError>()));
      expect(() => Cursor.moveRight(-5), throwsA(isA<AssertionError>()));
    });
  });

  group('Cursor.moveLeft >', () {
    test('generates correct sequences with default', () {
      expect(Cursor.moveLeft(), equals('\x1b[1D'));
    });

    test('generates correct sequences with parameter', () {
      expect(Cursor.moveLeft(), equals('\x1b[1D'));
      expect(Cursor.moveLeft(5), equals('\x1b[5D'));
      expect(Cursor.moveLeft(12), equals('\x1b[12D'));
    });

    test('assertions fire for invalid values', () {
      expect(() => Cursor.moveLeft(0), throwsA(isA<AssertionError>()));
      expect(() => Cursor.moveLeft(-5), throwsA(isA<AssertionError>()));
    });
  });

  group('Cursor.moveToNextLine >', () {
    test('generates correct sequences with default', () {
      expect(Cursor.moveToNextLine(), equals('\x1b[1E'));
    });

    test('generates correct sequences with parameter', () {
      expect(Cursor.moveToNextLine(), equals('\x1b[1E'));
      expect(Cursor.moveToNextLine(5), equals('\x1b[5E'));
      expect(Cursor.moveToNextLine(12), equals('\x1b[12E'));
    });

    test('assertions fire for invalid values', () {
      expect(() => Cursor.moveToNextLine(0), throwsA(isA<AssertionError>()));
      expect(() => Cursor.moveToNextLine(-5), throwsA(isA<AssertionError>()));
    });
  });

  group('Cursor.moveToPrevLine >', () {
    test('generates correct sequences with default', () {
      expect(Cursor.moveToPrevLine(), equals('\x1b[1F'));
    });

    test('generates correct sequences with parameter', () {
      expect(Cursor.moveToPrevLine(), equals('\x1b[1F'));
      expect(Cursor.moveToPrevLine(5), equals('\x1b[5F'));
      expect(Cursor.moveToPrevLine(13), equals('\x1b[13F'));
    });

    test('assertions fire for invalid values', () {
      expect(() => Cursor.moveToPrevLine(0), throwsA(isA<AssertionError>()));
      expect(() => Cursor.moveToPrevLine(-5), throwsA(isA<AssertionError>()));
    });
  });

  group('Cursor.setCursorStyle >', () {
    test('generates correct sequences for each style', () {
      expect(Cursor.setCursorStyle(CursorStyle.defaultUserShape), equals('\x1b[0 q'));
      expect(Cursor.setCursorStyle(CursorStyle.blinkingBlock), equals('\x1b[1 q'));
      expect(Cursor.setCursorStyle(CursorStyle.steadyBlock), equals('\x1b[2 q'));
      expect(Cursor.setCursorStyle(CursorStyle.blinkingUnderScore), equals('\x1b[3 q'));
      expect(Cursor.setCursorStyle(CursorStyle.steadyUnderScore), equals('\x1b[4 q'));
      expect(Cursor.setCursorStyle(CursorStyle.blinkingBar), equals('\x1b[5 q'));
      expect(Cursor.setCursorStyle(CursorStyle.steadyBar), equals('\x1b[6 q'));
    });
  });

  group('CursorStyle enum >', () {
    test('has correct number of styles', () {
      expect(CursorStyle.values.length, equals(7));
    });

    test('enum indices match ANSI codes', () {
      expect(CursorStyle.defaultUserShape.index, equals(0));
      expect(CursorStyle.blinkingBlock.index, equals(1));
      expect(CursorStyle.steadyBlock.index, equals(2));
      expect(CursorStyle.blinkingUnderScore.index, equals(3));
      expect(CursorStyle.steadyUnderScore.index, equals(4));
      expect(CursorStyle.blinkingBar.index, equals(5));
      expect(CursorStyle.steadyBar.index, equals(6));
    });
  });
}
