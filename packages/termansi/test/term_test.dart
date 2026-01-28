import 'package:termansi/termansi.dart';
import 'package:test/test.dart';

void main() {
  group('Term.hyperLink >', () {
    test('generates correct OSC 8 sequence', () {
      final result = Term.hyperLink('https://example.com', 'Example');
      expect(result, equals('\x1b]8;;https://example.com\x1b\\Example\x1b]8;;\x1b\\'));
    });

    test('wraps link text correctly', () {
      final result = Term.hyperLink('https://github.com', 'GitHub');
      expect(result, contains('GitHub'));
    });
  });

  group('Term.notify >', () {
    test('generates correct notification sequence', () {
      final result = Term.notify('Title', 'Message');
      expect(result, equals('\x1b]777;notify;Title;Message\x1b\\'));
    });

    test('includes title and message', () {
      final result = Term.notify('Hello', 'World');
      expect(result, contains('Hello'));
      expect(result, contains('World'));
    });
  });

  group('Term.setTerminalTitle >', () {
    test('generates correct sequence', () {
      expect(Term.setTerminalTitle('My Terminal'), equals('\x1b]0;My Terminal\x07'));
    });

    test('uses BEL terminator', () {
      expect(Term.setTerminalTitle('test'), endsWith('\x07'));
    });
  });

  group('Term.clipboard >', () {
    test('generates correct sequence with operation and data', () {
      expect(Term.clipboard('c', 'data'), equals('\x1b]52;c;data\x1b\\'));
    });

    test('query clipboard with ?', () {
      expect(Term.clipboard('c', '?'), equals('\x1b]52;c;?\x1b\\'));
    });

    test('supports different operations', () {
      expect(Term.clipboard('p', 'data'), contains(';p;'));
      expect(Term.clipboard('s', 'data'), contains(';s;'));
    });
  });

  group('Term keyboard capabilities >', () {
    test('requestKeyboardCapabilities produces correct sequence', () {
      expect(Term.requestKeyboardCapabilities, equals('\x1b[?u'));
    });

    group('setKeyboardCapabilities >', () {
      test('generates correct sequence with default mode', () {
        expect(Term.setKeyboardCapabilities(1), equals('\x1b[=1;1u'));
      });

      test('generates correct sequence with custom mode', () {
        expect(Term.setKeyboardCapabilities(5, 2), equals('\x1b[=5;2u'));
      });

      test('assertions fire for negative flags', () {
        expect(
          () => Term.setKeyboardCapabilities(-1),
          throwsA(isA<AssertionError>()),
        );
      });

      test('assertions fire for negative mode', () {
        expect(
          () => Term.setKeyboardCapabilities(1, -1),
          throwsA(isA<AssertionError>()),
        );
      });
    });

    group('pushKeyboardCapabilities >', () {
      test('generates correct sequence', () {
        expect(Term.pushKeyboardCapabilities(1), equals('\x1b[>1u'));
        expect(Term.pushKeyboardCapabilities(5), equals('\x1b[>5u'));
      });

      test('assertions fire for negative flags', () {
        expect(
          () => Term.pushKeyboardCapabilities(-1),
          throwsA(isA<AssertionError>()),
        );
      });
    });

    group('popKeyboardCapabilities >', () {
      test('generates correct sequence with default', () {
        expect(Term.popKeyboardCapabilities(), equals('\x1b[<1u'));
      });

      test('generates correct sequence with custom entries', () {
        expect(Term.popKeyboardCapabilities(3), equals('\x1b[<3u'));
      });

      test('assertions fire for invalid entries', () {
        expect(
          () => Term.popKeyboardCapabilities(0),
          throwsA(isA<AssertionError>()),
        );
        expect(
          () => Term.popKeyboardCapabilities(-1),
          throwsA(isA<AssertionError>()),
        );
      });
    });
  });

  group('Term alternate screen >', () {
    test('enableAlternateScreen produces correct sequence', () {
      expect(Term.enableAlternateScreen, equals('\x1b[?1049h'));
    });

    test('disableAlternateScreen produces correct sequence', () {
      expect(Term.disableAlternateScreen, equals('\x1b[?1049l'));
    });
  });

  group('Term line wrapping >', () {
    test('enableLineWrapping produces correct sequence', () {
      expect(Term.enableLineWrapping, equals('\x1b[?7h'));
    });

    test('disableLineWrapping produces correct sequence', () {
      expect(Term.disableLineWrapping, equals('\x1b[?7l'));
    });
  });

  group('Term.queryOSCColors >', () {
    test('generates correct sequence', () {
      expect(Term.queryOSCColors(10), equals('\x1b]10;?\x1b\\'));
      expect(Term.queryOSCColors(11), equals('\x1b]11;?\x1b\\'));
    });

    test('assertions fire for negative code', () {
      expect(() => Term.queryOSCColors(-1), throwsA(isA<AssertionError>()));
    });
  });

  group('Term scroll >', () {
    group('scrollUp >', () {
      test('generates correct sequence', () {
        expect(Term.scrollUp(1), equals('\x1b[1S'));
        expect(Term.scrollUp(5), equals('\x1b[5S'));
      });

      test('assertions fire for invalid rows', () {
        expect(() => Term.scrollUp(0), throwsA(isA<AssertionError>()));
        expect(() => Term.scrollUp(-5), throwsA(isA<AssertionError>()));
      });
    });

    group('scrollDown >', () {
      test('generates correct sequence', () {
        expect(Term.scrollDown(1), equals('\x1b[1T'));
        expect(Term.scrollDown(5), equals('\x1b[5T'));
      });

      test('assertions fire for invalid rows', () {
        expect(() => Term.scrollDown(0), throwsA(isA<AssertionError>()));
        expect(() => Term.scrollDown(-5), throwsA(isA<AssertionError>()));
      });
    });
  });

  group('Term sync update >', () {
    test('querySyncUpdate produces correct sequence', () {
      expect(Term.querySyncUpdate, equals('\x1b[?2026\$p'));
    });

    test('enableSyncUpdate produces correct sequence', () {
      expect(Term.enableSyncUpdate, equals('\x1b[?2026h'));
    });

    test('disableSyncUpdate produces correct sequence', () {
      expect(Term.disableSyncUpdate, equals('\x1b[?2026l'));
    });
  });

  group('Term focus tracking >', () {
    test('enableFocusTracking produces correct sequence', () {
      expect(Term.enableFocusTracking, equals('\x1b[?1004h'));
    });

    test('disableFocusTracking produces correct sequence', () {
      expect(Term.disableFocusTracking, equals('\x1b[?1004l'));
    });
  });

  group('Term mouse events >', () {
    test('enableMouseEvents produces correct sequence', () {
      expect(Term.enableMouseEvents, equals('\x1b[?1000;1003;1006h'));
    });

    test('disableMouseEvents produces correct sequence', () {
      expect(Term.disableMouseEvents, equals('\x1b[?1000;1003;1006l'));
    });

    test('enableMousePixelEvents produces correct sequence', () {
      expect(Term.enableMousePixelEvents, equals('\x1b[?1000;1003;1016h'));
    });

    test('disableMousePixelsEvents produces correct sequence', () {
      expect(Term.disableMousePixelsEvents, equals('\x1b[?1000;1003;1016l'));
    });

    test('disable uses lowercase l not h', () {
      expect(Term.disableMousePixelsEvents, endsWith('l'));
      expect(Term.disableMousePixelsEvents, isNot(endsWith('h')));
    });
  });

  group('Term.setWindowSize >', () {
    test('generates correct sequence', () {
      expect(Term.setWindowSize(24, 80), equals('\x1b[8;24;80t'));
      expect(Term.setWindowSize(50, 120), equals('\x1b[8;50;120t'));
    });

    test('assertions fire for invalid rows', () {
      expect(() => Term.setWindowSize(0, 80), throwsA(isA<AssertionError>()));
      expect(() => Term.setWindowSize(-5, 80), throwsA(isA<AssertionError>()));
    });

    test('assertions fire for invalid cols', () {
      expect(() => Term.setWindowSize(24, 0), throwsA(isA<AssertionError>()));
      expect(() => Term.setWindowSize(24, -5), throwsA(isA<AssertionError>()));
    });
  });

  group('Term window control >', () {
    test('minimizeWindow produces correct sequence', () {
      expect(Term.minimizeWindow, equals('\x1b[2t'));
    });

    test('maximizeWindow produces correct sequence', () {
      expect(Term.maximizeWindow, equals('\x1b[1t'));
    });

    test('queryWindowSizePixels produces correct sequence', () {
      expect(Term.queryWindowSizePixels, equals('\x1b[14t'));
    });
  });

  group('Term queries >', () {
    test('requestTermVersion produces correct sequence', () {
      expect(Term.requestTermVersion, equals('\x1b[>0q'));
    });

    test('queryKeyboardEnhancementSupport produces correct sequence', () {
      expect(Term.queryKeyboardEnhancementSupport, equals('\x1b[?u'));
    });

    test('queryPrimaryDeviceAttributes produces correct sequence', () {
      expect(Term.queryPrimaryDeviceAttributes, equals('\x1b[c'));
    });
  });

  group('Term Unicode Core >', () {
    test('enableUnicodeCore produces correct sequence', () {
      expect(Term.enableUnicodeCore, equals('\x1b[?2027h'));
    });

    test('disableUnicodeCore produces correct sequence', () {
      expect(Term.disableUnicodeCore, equals('\x1b[?2027l'));
    });

    test('queryUnicodeCore produces correct sequence', () {
      expect(Term.queryUnicodeCore, equals('\x1b[?2027\$p'));
    });
  });

  group('Term bracketed paste >', () {
    test('enableBracketedPaste produces correct sequence', () {
      expect(Term.enableBracketedPaste, equals('\x1b[?2004h'));
    });

    test('disableBracketedPaste produces correct sequence', () {
      expect(Term.disableBracketedPaste, equals('\x1b[?2004l'));
    });
  });

  group('Term.softTerminalReset >', () {
    test('produces correct sequence', () {
      expect(Term.softTerminalReset, equals('\x1b[!p'));
    });
  });

  group('Term in-band resize >', () {
    test('queryInBandResize produces correct sequence', () {
      expect(Term.queryInBandResize, equals('\x1b[?2048\$p'));
    });

    test('enableInBandResize produces correct sequence', () {
      expect(Term.enableInBandResize, equals('\x1b[?2048h'));
    });

    test('disableInBandResize produces correct sequence', () {
      expect(Term.disableInBandResize, equals('\x1b[?2048l'));
    });
  });

  group('Term progress bar >', () {
    test('clearProgress produces correct sequence', () {
      expect(Term.clearProgress, equals('\x1b]9;4;0;0\x07'));
    });

    group('setProgress >', () {
      test('generates correct sequence for normal state', () {
        expect(Term.setProgress(ProgressState.normal, 50), equals('\x1b]9;4;1;50\x07'));
      });

      test('generates correct sequence for all states', () {
        expect(Term.setProgress(ProgressState.hidden), equals('\x1b]9;4;0;0\x07'));
        expect(Term.setProgress(ProgressState.normal, 25), equals('\x1b]9;4;1;25\x07'));
        expect(Term.setProgress(ProgressState.error, 75), equals('\x1b]9;4;2;75\x07'));
        expect(Term.setProgress(ProgressState.indeterminate), equals('\x1b]9;4;3;0\x07'));
        expect(Term.setProgress(ProgressState.warning, 100), equals('\x1b]9;4;4;100\x07'));
      });

      test('default progress is 0', () {
        expect(Term.setProgress(ProgressState.normal), equals('\x1b]9;4;1;0\x07'));
      });

      test('assertions fire for progress below 0', () {
        expect(
          () => Term.setProgress(ProgressState.normal, -1),
          throwsA(isA<AssertionError>()),
        );
      });

      test('assertions fire for progress above 100', () {
        expect(
          () => Term.setProgress(ProgressState.normal, 101),
          throwsA(isA<AssertionError>()),
        );
      });
    });

    group('ProgressState >', () {
      test('has correct values', () {
        expect(ProgressState.hidden.value, equals(0));
        expect(ProgressState.normal.value, equals(1));
        expect(ProgressState.error.value, equals(2));
        expect(ProgressState.indeterminate.value, equals(3));
        expect(ProgressState.warning.value, equals(4));
      });
    });
  });
}
