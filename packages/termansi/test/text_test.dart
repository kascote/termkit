import 'package:termansi/termansi.dart';
import 'package:test/test.dart';

void main() {
  group('Text style constants >', () {
    group('basic styles >', () {
      test('bold produces correct sequence', () {
        expect(Text.bold, equals('\x1b[1m'));
      });

      test('dim produces correct sequence', () {
        expect(Text.dim, equals('\x1b[2m'));
      });

      test('italic produces correct sequence', () {
        expect(Text.italic, equals('\x1b[3m'));
      });

      test('underline produces correct sequence', () {
        expect(Text.underline, equals('\x1b[4m'));
      });

      test('blink produces correct sequence', () {
        expect(Text.blink, equals('\x1b[5m'));
      });

      test('invert produces correct sequence', () {
        expect(Text.invert, equals('\x1b[7m'));
      });

      test('hidden produces correct sequence', () {
        expect(Text.hidden, equals('\x1b[8m'));
      });

      test('strikeThrough produces correct sequence', () {
        expect(Text.strikeThrough, equals('\x1b[9m'));
      });

      test('overline produces correct sequence', () {
        expect(Text.overline, equals('\x1b[53m'));
      });
    });

    group('underline styles >', () {
      test('doubleUnderline produces correct sequence', () {
        expect(Text.doubleUnderline, equals('\x1b[4:2m'));
      });

      test('curlyUnderline produces correct sequence', () {
        expect(Text.curlyUnderline, equals('\x1b[4:3m'));
      });

      test('dottedUnderline produces correct sequence', () {
        expect(Text.dottedUnderline, equals('\x1b[4:4m'));
      });

      test('dashedUnderline produces correct sequence', () {
        expect(Text.dashedUnderline, equals('\x1b[4:5m'));
      });
    });

    group('reset sequences >', () {
      test('reset produces correct sequence', () {
        expect(Text.reset, equals('\x1b[0m'));
      });

      test('resetBold produces correct sequence', () {
        expect(Text.resetBold, equals('\x1b[22m'));
      });

      test('resetDim produces correct sequence', () {
        expect(Text.resetDim, equals('\x1b[22m'));
      });

      test('resetItalic produces correct sequence', () {
        expect(Text.resetItalic, equals('\x1b[23m'));
      });

      test('resetUnderline produces correct sequence', () {
        expect(Text.resetUnderline, equals('\x1b[24m'));
      });

      test('resetUnderlineStyle produces correct sequence', () {
        expect(Text.resetUnderlineStyle, equals('\x1b[4:0m'));
      });

      test('resetBlink produces correct sequence', () {
        expect(Text.resetBlink, equals('\x1b[25m'));
      });

      test('resetInvert produces correct sequence', () {
        expect(Text.resetInvert, equals('\x1b[27m'));
      });

      test('resetHidden produces correct sequence', () {
        expect(Text.resetHidden, equals('\x1b[28m'));
      });

      test('resetStrikeThrough produces correct sequence', () {
        expect(Text.resetStrikeThrough, equals('\x1b[29m'));
      });

      test('resetOverline produces correct sequence', () {
        expect(Text.resetOverline, equals('\x1b[55m'));
      });
    });
  });

  group('Text reset behavior >', () {
    test('resetBold and resetDim produce same sequence', () {
      expect(Text.resetBold, equals(Text.resetDim));
      expect(Text.resetBold, equals('\x1b[22m'));
    });

    test('resetUnderlineStyle resets all underline variants', () {
      // All underline styles should be reset by the same sequence
      expect(Text.resetUnderlineStyle, equals('\x1b[4:0m'));
    });
  });

  group('Text sequence patterns >', () {
    test('all style sequences start with CSI', () {
      expect(Text.bold, startsWith('\x1b['));
      expect(Text.italic, startsWith('\x1b['));
      expect(Text.underline, startsWith('\x1b['));
      expect(Text.blink, startsWith('\x1b['));
    });

    test('all style sequences end with m', () {
      expect(Text.bold, endsWith('m'));
      expect(Text.italic, endsWith('m'));
      expect(Text.underline, endsWith('m'));
      expect(Text.reset, endsWith('m'));
    });

    test('all reset sequences start with CSI', () {
      expect(Text.resetBold, startsWith('\x1b['));
      expect(Text.resetItalic, startsWith('\x1b['));
      expect(Text.resetUnderline, startsWith('\x1b['));
    });
  });
}
