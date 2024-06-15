import 'package:termlib/termlib.dart';
import 'package:termparser/termparser_events.dart';
import 'package:test/test.dart';

import 'shared.dart';
import 'termlib_mock.dart';

void main() {
  group('Term extension >', () {
    test('hyperlink', () async {
      await mockedTest((out, _, __) async {
        TermLib().hyperlink('https://example.com', 'example');
        expect(out.buf.toString(), equals('\x1B]8;;https://example.com\x1B\\example\x1B]8;;\x1B\\'));
      });
    });

    test('notify', () async {
      await mockedTest((out, _, __) async {
        TermLib().notify('title', 'message');
        expect(out.buf.toString(), equals('\x1B]777;notify;title;message\x1B\\'));
      });
    });

    test('enableAlternateScreen', () async {
      await mockedTest((out, _, __) async {
        TermLib().enableAlternateScreen();
        expect(out.buf.toString(), equals('\x1B[?1049h'));
      });
    });

    test('disableAlternateScreen', () async {
      await mockedTest((out, _, __) async {
        TermLib().disableAlternateScreen();
        expect(out.buf.toString(), equals('\x1B[?1049l'));
      });
    });

    test('setTerminalTitle', () async {
      await mockedTest((out, _, __) async {
        TermLib().setTerminalTitle('Terminal Title');
        expect(out.buf.toString(), equals('\x1B]0;Terminal Title\x07'));
      });
    });

    test('enableMouseEvents', () async {
      await mockedTest((out, _, __) async {
        TermLib().enableMouseEvents();
        expect(out.buf.toString(), equals('\x1B[?1000;1003;1006h'));
      });
    });

    test('disableMouseEvents', () async {
      await mockedTest((out, _, __) async {
        TermLib().disableMouseEvents();
        expect(out.buf.toString(), equals('\x1B[?1000;1003;1006l'));
      });
    });

    test('startFocusTracking', () async {
      await mockedTest((out, _, __) async {
        TermLib().startFocusTracking();
        expect(out.buf.toString(), equals('\x1B[?1004h'));
      });
    });

    test('endFocusTracking', () async {
      await mockedTest((out, _, __) async {
        TermLib().endFocusTracking();
        expect(out.buf.toString(), equals('\x1B[?1004l'));
      });
    });

    test('enableLineWrapping', () async {
      await mockedTest((out, _, __) async {
        TermLib().enableLineWrapping();
        expect(out.buf.toString(), equals('\x1B[?7h'));
      });
    });

    test('disableLineWrapping', () async {
      await mockedTest((out, _, __) async {
        TermLib().disableLineWrapping();
        expect(out.buf.toString(), equals('\x1B[?7l'));
      });
    });

    test('scrollUp', () async {
      await mockedTest((out, _, __) async {
        TermLib().scrollUp(1);
        expect(out.buf.toString(), equals('\x1B[1S'));
      });
    });

    test('scrollDown', () async {
      await mockedTest((out, _, __) async {
        TermLib().scrollDown(1);
        expect(out.buf.toString(), equals('\x1B[1T'));
      });
    });

    test('startSyncUpdate', () async {
      await mockedTest((out, _, __) async {
        TermLib().startSyncUpdate();
        expect(out.buf.toString(), equals('\x1B[?2026h'));
      });
    });

    test('endSyncUpdate', () async {
      await mockedTest((out, _, tos) async {
        TermLib().endSyncUpdate();
        expect(out.buf.toString(), equals('\x1B[?2026l'));
      });
    });

    test('softReset', () async {
      await mockedTest((out, _, tos) async {
        TermLib().softReset();
        expect(out.buf.toString(), equals('\x1B[!p'));
      });
    });

    test('querySyncUpdate', () async {
      await mockedTest(
        (out, _, tos) async {
          final term = TermLib();
          final status = await term.querySyncUpdate();
          expect(status, isA<SyncUpdateStatus>());
          expect(out.buf.toString(), equals('\x1B[?2026\$p'));
          expect(tos.callStack[0], 'enableRawMode');
          expect(tos.callStack[1], 'disableRawMode');
        },
        stdin: MockStdin(streamString('\x1B[?2026;2\$y')),
      );
    });

    test('queryTerminalVersion', () async {
      await mockedTest((out, _, __) async {
        await TermLib().queryTerminalVersion();
        expect(out.buf.toString(), equals('\x1B[>0q'));
      });
    });

    test('queryOSCStatus', () async {
      await mockedTest((out, _, __) async {
        await TermLib().queryOSCStatus(11);
        expect(out.buf.toString(), equals('\x1B]11;?\x1B\\'));
      });
    });

    test('queryKeyboardEnhancementSupport', () async {
      await mockedTest((out, _, __) async {
        await TermLib().queryKeyboardEnhancementSupport();
        expect(out.buf.toString(), equals('\x1B[?u'));
      });
    });

    test('queryPrimaryDeviceAttributes', () async {
      await mockedTest((out, _, __) async {
        await TermLib().queryPrimaryDeviceAttributes();
        expect(out.buf.toString(), equals('\x1B[c'));
      });
    });

    test('queryWindowSizeInPixels', () async {
      await mockedTest(
        (out, _, tos) async {
          final term = TermLib();
          final status = await term.queryWindowSizeInPixels();
          expect(status, isA<QueryTerminalWindowSizeEvent>());
          expect(out.buf.toString(), equals('\x1B[14t'));
          expect(tos.callStack[0], 'enableRawMode');
          expect(tos.callStack[1], 'disableRawMode');
        },
        stdin: MockStdin(streamString('\x1B[4;2394;4301t')),
      );
    });

    test('clipboardSet', () async {
      await mockedTest((out, _, __) {
        TermLib().clipboardSet(Clipboard.primary, 'bananas');
        expect(out.buf.toString(), equals('\x1B]52;p;YmFuYW5hcw==\x1B\\'));
      });
    });

    test('clipboardClear', () async {
      await mockedTest((out, _, __) {
        TermLib().clipboardClear(Clipboard.primary);
        expect(out.buf.toString(), equals('\x1B]52;p;!\x1B\\'));
      });
    });

    test('queryClipboard', () async {
      await mockedTest(
        (out, _, __) async {
          final term = TermLib();
          final status = await term.queryClipboard(Clipboard.primary);
          expect(out.buf.toString(), equals('\x1B]52;p;?\x1B\\'));
          expect(status, isA<ClipboardCopyEvent>());
          expect(status?.text, 'bananas');
        },
        stdin: MockStdin(streamString('\x1B]52;p;YmFuYW5hcw==\x1B\\')),
      );
    });
  });
}
