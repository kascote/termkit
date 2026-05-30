import 'package:termlib/termlib.dart';
import 'package:termparser/termparser_events.dart';
import 'package:test/test.dart';

import 'shared.dart';

void main() {
  group('Term extension >', () {
    test('hyperlink', () async {
      await mockedTest((term, out, _) async {
        term.hyperlink('https://example.com', 'example');
        expect(out.output, equals('\x1B]8;;https://example.com\x1B\\example\x1B]8;;\x1B\\'));
      });
    });

    test('notify', () async {
      await mockedTest((term, out, _) async {
        term.notify('title', 'message');
        expect(out.output, equals('\x1B]777;notify;title;message\x1B\\'));
      });
    });

    test('enableAlternateScreen', () async {
      await mockedTest((term, out, _) async {
        term.enableAlternateScreen();
        expect(out.output, equals('\x1B[?1049h'));
      });
    });

    test('disableAlternateScreen', () async {
      await mockedTest((term, out, _) async {
        term.disableAlternateScreen();
        expect(out.output, equals('\x1B[?1049l'));
      });
    });

    test('setTerminalTitle', () async {
      await mockedTest((term, out, _) async {
        term.setTerminalTitle('Terminal Title');
        expect(out.output, equals('\x1B]0;Terminal Title\x07'));
      });
    });

    test('enableMouseEvents', () async {
      await mockedTest((term, out, _) async {
        term.enableMouseEvents();
        expect(out.output, equals('\x1B[?1000;1003;1006h'));
      });
    });

    test('disableMouseEvents', () async {
      await mockedTest((term, out, _) async {
        term.disableMouseEvents();
        expect(out.output, equals('\x1B[?1000;1003;1006l'));
      });
    });

    test('startFocusTracking', () async {
      await mockedTest((term, out, _) async {
        term.startFocusTracking();
        expect(out.output, equals('\x1B[?1004h'));
      });
    });

    test('endFocusTracking', () async {
      await mockedTest((term, out, _) async {
        term.endFocusTracking();
        expect(out.output, equals('\x1B[?1004l'));
      });
    });

    test('enableLineWrapping', () async {
      await mockedTest((term, out, _) async {
        term.enableLineWrapping();
        expect(out.output, equals('\x1B[?7h'));
      });
    });

    test('disableLineWrapping', () async {
      await mockedTest((term, out, _) async {
        term.disableLineWrapping();
        expect(out.output, equals('\x1B[?7l'));
      });
    });

    test('scrollUp', () async {
      await mockedTest((term, out, _) async {
        term.scrollUp(1);
        expect(out.output, equals('\x1B[1S'));
      });
    });

    test('scrollDown', () async {
      await mockedTest((term, out, _) async {
        term.scrollDown(1);
        expect(out.output, equals('\x1B[1T'));
      });
    });

    test('startSyncUpdate', () async {
      await mockedTest((term, out, _) async {
        term.startSyncUpdate();
        expect(out.output, equals('\x1B[?2026h'));
      });
    });

    test('endSyncUpdate', () async {
      await mockedTest((term, out, _) async {
        term.endSyncUpdate();
        expect(out.output, equals('\x1B[?2026l'));
      });
    });

    test('softReset', () async {
      await mockedTest((term, out, _) async {
        term.softReset();
        expect(out.output, equals('\x1B[!p'));
      });
    });

    test('querySyncUpdate', () async {
      await mockedTest(
        (term, out, tos) async {
          final status = await term.querySyncUpdate();
          expect(status, isA<QuerySyncUpdateEvent>());
          expect(out.output, equals('\x1B[?2026\$p'));
          expect(tos.callStack[0], 'enableRawMode');
          expect(tos.callStack[1], 'disableRawMode');
        },
        stdin: streamString('\x1B[?2026;2\$y'),
      );
    });

    test('queryTerminalVersion', () async {
      await mockedTest((term, out, _) async {
        await term.queryTerminalVersion();
        expect(out.output, equals('\x1B[>0q'));
      });
    });

    test('queryOSCStatus', () async {
      await mockedTest((term, out, _) async {
        await term.queryOSCStatus(11);
        expect(out.output, equals('\x1B]11;?\x1B\\'));
      });
    });

    test('queryKeyboardEnhancementSupport', () async {
      await mockedTest((term, out, _) async {
        await term.queryKeyboardEnhancementSupport();
        expect(out.output, equals('\x1B[?u'));
      });
    });

    test('queryPrimaryDeviceAttributes', () async {
      await mockedTest((term, out, _) async {
        await term.queryPrimaryDeviceAttributes();
        expect(out.output, equals('\x1B[c'));
      });
    });

    test('queryWindowSizeInPixels', () async {
      await mockedTest(
        (term, out, tos) async {
          final status = await term.queryWindowSizeInPixels();
          expect(status, isA<QueryTerminalWindowSizeEvent>());
          expect(out.output, equals('\x1B[14t'));
          expect(tos.callStack[0], 'enableRawMode');
          expect(tos.callStack[1], 'disableRawMode');
        },
        stdin: streamString('\x1B[4;2394;4301t'),
      );
    });

    test('clipboardSet', () async {
      await mockedTest((term, out, _) {
        term.clipboardSet(Clipboard.primary, 'bananas');
        expect(out.output, equals('\x1B]52;p;YmFuYW5hcw==\x1B\\'));
      });
    });

    test('clipboardClear', () async {
      await mockedTest((term, out, _) {
        term.clipboardClear(Clipboard.primary);
        expect(out.output, equals('\x1B]52;p;!\x1B\\'));
      });
    });

    test('queryClipboard', () async {
      await mockedTest(
        (term, out, _) async {
          final status = await term.queryClipboard(Clipboard.primary);
          expect(out.output, equals('\x1B]52;p;?\x1B\\'));
          expect(status, isA<ClipboardCopyEvent>());
          expect(status?.text, 'bananas');
        },
        stdin: streamString('\x1B]52;p;YmFuYW5hcw==\x1B\\'),
      );
    });

    test('enableInBandResize', () async {
      await mockedTest((term, out, _) async {
        term.enableInBandResize();
        expect(out.output, equals('\x1B[?2048h'));
      });
    });

    test('disableInBandResize', () async {
      await mockedTest((term, out, _) async {
        term.disableInBandResize();
        expect(out.output, equals('\x1B[?2048l'));
      });
    });

    test('queryInBandResize', () async {
      await mockedTest(
        (term, out, tos) async {
          final status = await term.queryInBandResize();
          expect(status, isA<QueryWindowResizeEvent>());
          expect(out.output, equals('\x1B[?2048\$p'));
          expect(tos.callStack[0], 'enableRawMode');
          expect(tos.callStack[1], 'disableRawMode');
        },
        stdin: streamString('\x1B[?2048;1\$y'),
      );
    });
  });
}
