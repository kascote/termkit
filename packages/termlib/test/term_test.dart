import 'package:termlib/termlib.dart';
import 'package:test/test.dart';

import 'termlib_mock.dart';

void main() {
  final stdoutMock = MockStdout();
  final term = TermLib(stdoutAdapter: stdoutMock);

  group('Term extension >', () {
    setUp(stdoutMock.clearOutput);

    test('hyperlink', () {
      term.hyperlink('https://example.com', 'example');
      expect(stdoutMock.buf.toString(), equals('\x1B]8;;https://example.com\x1B\\example\x1B]8;;\x1B\\'));
    });

    test('notify', () {
      term.notify('title', 'message');
      expect(stdoutMock.buf.toString(), equals('\x1B]777;notify;title;message\x1B\\'));
    });

    test('enableAlternateScreen', () {
      term.enableAlternateScreen();
      expect(stdoutMock.buf.toString(), equals('\x1B[?1049h'));
    });

    test('disableAlternateScreen', () {
      term.disableAlternateScreen();
      expect(stdoutMock.buf.toString(), equals('\x1B[?1049l'));
    });

    test('setTerminalTitle', () {
      term.setTerminalTitle('Terminal Title');
      expect(stdoutMock.buf.toString(), equals('\x1B]0;Terminal Title\x07'));
    });

    test('enableMouseEvents', () {
      term.enableMouseEvents();
      expect(stdoutMock.buf.toString(), equals('\x1B[?1000;1003;1006h'));
    });

    test('disableMouseEvents', () {
      term.disableMouseEvents();
      expect(stdoutMock.buf.toString(), equals('\x1B[?1000;1003;1006l'));
    });

    test('startFocusTracking', () {
      term.startFocusTracking();
      expect(stdoutMock.buf.toString(), equals('\x1B[?1004h'));
    });

    test('endFocusTracking', () {
      term.endFocusTracking();
      expect(stdoutMock.buf.toString(), equals('\x1B[?1004l'));
    });

    test('enableLineWrapping', () {
      term.enableLineWrapping();
      expect(stdoutMock.buf.toString(), equals('\x1B[?7h'));
    });

    test('disableLineWrapping', () {
      term.disableLineWrapping();
      expect(stdoutMock.buf.toString(), equals('\x1B[?7l'));
    });

    test('scrollUp', () {
      term.scrollUp(1);
      expect(stdoutMock.buf.toString(), equals('\x1B[1S'));
    });

    test('scrollDown', () {
      term.scrollDown(1);
      expect(stdoutMock.buf.toString(), equals('\x1B[1T'));
    });

    test('startSyncUpdate', () {
      term.startSyncUpdate();
      expect(stdoutMock.buf.toString(), equals('\x1B[?2026h'));
    });

    test('endSyncUpdate', () {
      term.endSyncUpdate();
      expect(stdoutMock.buf.toString(), equals('\x1B[?2026l'));
    });

    test('querySyncUpdate', () async {
      await term.querySyncUpdate();
      expect(stdoutMock.buf.toString(), equals('\x1B[?2026\$p'));
    });

    test('queryTerminalVersion', () async {
      await term.queryTerminalVersion();
      expect(stdoutMock.buf.toString(), equals('\x1B[>0q'));
    });

    test('queryOSCStatus', () async {
      await term.queryOSCStatus(11);
      expect(stdoutMock.buf.toString(), equals('\x1B]11;?\x1B\\'));
    });

    test('queryKeyboardEnhancementSupport', () async {
      await term.queryKeyboardEnhancementSupport();
      expect(stdoutMock.buf.toString(), equals('\x1B[?u\x1B[c'));
    });

    test('queryPrimaryDeviceAttributes', () async {
      await term.queryPrimaryDeviceAttributes();
      expect(stdoutMock.buf.toString(), equals('\x1B[c'));
    });
  });
}
