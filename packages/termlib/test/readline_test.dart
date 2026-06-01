import 'package:characters/characters.dart';
import 'package:termlib/termlib.dart';
import 'package:termparser/termparser_events.dart';
import 'package:test/test.dart';

import 'shared.dart';

/// Build a char KeyEvent (one codepoint, as the parser emits).
KeyEvent ch(String c) => KeyEvent(KeyCode.char(c));

/// Build a named KeyEvent.
KeyEvent named(KeyCodeName n) => KeyEvent(KeyCode.named(n));

final enter = KeyEvent.fromString('enter');
final esc = KeyEvent.fromString('escape');
final left = KeyEvent.fromString('left');
final home = KeyEvent.fromString('home');
final end = KeyEvent.fromString('end');
final backspace = KeyEvent.fromString('backSpace');
final del = KeyEvent.fromString('delete');
final ctrlU = KeyEvent.fromString('ctrl+u');
final ctrlK = KeyEvent.fromString('ctrl+k');

/// Type each char of [s] as a separate KeyEvent.
List<KeyEvent> type(String s) => s.split('').map(ch).toList();

/// Run readLine driven by [events]. A start [CursorPositionEvent] is prepended
/// automatically so readline's cursor query resolves immediately. Returns the
/// result and captured output.
Future<({String? result, String output})> run(
  List<Event> events, {
  ReadlineOptions options = const ReadlineOptions(),
  int columns = 80,
  int rows = 24,
}) async {
  final out = BufferTermSink(columns: columns, rows: rows);
  final all = <Event>[const CursorPositionEvent(1, 1), ...events];
  String? result;
  await mockedTest(
    (term, stdout, tos) async {
      result = await term.readLine(options);
    },
    stdout: out,
    eventSource: Stream<Event>.fromIterable(all),
    columns: columns,
    rows: rows,
  );
  return (result: result, output: out.output);
}

void main() {
  group('Readline - basic', () {
    test('types until enter', () async {
      final r = await run([...type('hello'), enter]);
      expect(r.result, 'hello');
    });

    test('escape cancels and returns null', () async {
      final r = await run([...type('hello'), esc]);
      expect(r.result, isNull);
    });

    test('empty input returns empty string', () async {
      final r = await run([enter]);
      expect(r.result, '');
    });
  });

  group('Readline - insert semantics', () {
    test('typing mid-text inserts, not overwrites', () async {
      // type "ac", move left, type "b" -> "abc"
      final r = await run([...type('ac'), left, ch('b'), enter]);
      expect(r.result, 'abc');
    });

    test('home then type prepends', () async {
      final r = await run([...type('bcd'), home, ch('a'), enter]);
      expect(r.result, 'abcd');
    });

    test('end moves cursor to end', () async {
      final r = await run([...type('bcd'), home, end, ch('e'), enter]);
      expect(r.result, 'bcde');
    });
  });

  group('Readline - delete operations', () {
    test('backspace removes grapheme before cursor', () async {
      final r = await run([...type('abc'), backspace, enter]);
      expect(r.result, 'ab');
    });

    test('delete removes grapheme at cursor', () async {
      final r = await run([...type('abc'), home, del, enter]);
      expect(r.result, 'bc');
    });

    test('ctrl+u clears from cursor to start', () async {
      final r = await run([...type('abcdef'), left, left, ctrlU, enter]);
      expect(r.result, 'ef');
    });

    test('ctrl+k clears from cursor to end', () async {
      final r = await run([...type('abcdef'), left, left, ctrlK, enter]);
      expect(r.result, 'abcd');
    });
  });

  group('Readline - maxLength', () {
    test('blocks input at cap (silent)', () async {
      final r = await run([...type('abcde'), enter], options: const ReadlineOptions(maxLength: 3));
      expect(r.result, 'abc');
    });

    test('backspace then re-insert works at cap', () async {
      final r = await run(
        [...type('abc'), ch('d'), backspace, ch('X'), enter],
        options: const ReadlineOptions(maxLength: 3),
      );
      expect(r.result, 'abX');
    });

    test('initBuffer truncated to maxLength', () async {
      final r = await run([enter], options: const ReadlineOptions(initBuffer: 'abcdef', maxLength: 3));
      expect(r.result, 'abc');
    });
  });

  group('Readline - grapheme correctness', () {
    test('combining mark merges into one cluster across events', () async {
      // 'a' then U+0301 (combining acute) arrive as separate KeyEvents.
      final r = await run([ch('a'), ch('́'), enter]);
      expect(r.result, 'á');
      expect(r.result!.characters.length, 1);
    });

    test('combining mark accepted at maxLength cap (merges, count unchanged)', () async {
      final r = await run([ch('a'), ch('́'), enter], options: const ReadlineOptions(maxLength: 1));
      expect(r.result, 'á');
    });

    test('backspace removes a whole multi-codepoint cluster', () async {
      final r = await run([ch('a'), ch('́'), backspace, enter]);
      expect(r.result, '');
    });

    test('wide CJK counts as one grapheme for maxLength', () async {
      final r = await run([ch('中'), ch('文'), ch('字'), enter], options: const ReadlineOptions(maxLength: 2));
      expect(r.result, '中文');
    });

    test('cursor lands after augmented cluster (left/insert)', () async {
      // type "xy", left, then a then combining mark -> "xáy"
      final r = await run([...type('xy'), left, ch('a'), ch('́'), enter]);
      expect(r.result, 'xáy');
    });
  });

  group('Readline - initBuffer normalization', () {
    test('cuts at first newline', () async {
      final r = await run([enter], options: const ReadlineOptions(initBuffer: 'first\nsecond'));
      expect(r.result, 'first');
      expect(r.result, isNot(contains('\n')));
    });

    test('cuts at carriage return', () async {
      final r = await run([enter], options: const ReadlineOptions(initBuffer: 'first\r\nsecond'));
      expect(r.result, 'first');
    });
  });

  group('Readline - paste', () {
    test('inserts pasted text without submitting', () async {
      final r = await run([const PasteEvent('hello'), ch('!'), enter]);
      expect(r.result, 'hello!');
    });

    test('truncates paste at first newline, no auto-submit', () async {
      final r = await run([const PasteEvent('foo\nbar'), enter]);
      expect(r.result, 'foo');
    });

    test('paste over maxLength truncates to cap', () async {
      final r = await run([const PasteEvent('abcdef'), enter], options: const ReadlineOptions(maxLength: 3));
      expect(r.result, 'abc');
    });
  });

  group('Readline - tab and non-printable', () {
    test('tab inserts tabWidth spaces', () async {
      final r = await run([named(KeyCodeName.tab), enter], options: const ReadlineOptions(tabWidth: 2));
      expect(r.result, '  ');
    });

    test('tab respects maxLength', () async {
      final r = await run(
        [...type('ab'), named(KeyCodeName.tab), enter],
        options: const ReadlineOptions(maxLength: 4),
      );
      expect(r.result, 'ab  ');
    });

    test('non-printable named keys are ignored', () async {
      final r = await run([ch('a'), named(KeyCodeName.f1), named(KeyCodeName.insert), ch('b'), enter]);
      expect(r.result, 'ab');
    });
  });

  group('Readline - rendering modes', () {
    test('wrap mode renders continuation rows', () async {
      // 15 chars in a 10-wide terminal -> a second visual row.
      final r = await run(
        [...type('abcdefghijklmno'), enter],
        options: const ReadlineOptions(wrap: true),
        columns: 10,
      );
      expect(r.result, 'abcdefghijklmno');
      // second row positioned at column 1 (no prompt).
      expect(r.output, contains('\x1b[2;1H'));
    });

    test('scroll mode stays on a single row', () async {
      final r = await run(
        [...type('abcdefghijklmno'), enter],
        columns: 10,
      );
      expect(r.result, 'abcdefghijklmno');
      // never moves to a second row.
      expect(r.output, isNot(contains('\x1b[2;')));
    });
  });

  group('Readline - terminal modes', () {
    test('manages autowrap; bracketed paste off by default (unprobed terminal)', () async {
      final r = await run([...type('hi'), enter]);
      expect(r.result, 'hi');
      // autowrap is always managed by the widget.
      expect(r.output, contains('\x1b[?7l')); // disable line wrap
      expect(r.output, contains('\x1b[?7h')); // restore line wrap
      // a terminal that was never probed is treated as unsupported.
      expect(r.output, isNot(contains('\x1b[?2004h')));
      expect(r.output, isNot(contains('\x1b[?2004l')));
    });

    test('enables bracketed paste when the option forces it on', () async {
      final r = await run([...type('hi'), enter], options: const ReadlineOptions(bracketedPaste: true));
      expect(r.output, contains('\x1b[?2004h')); // enable bracketed paste
      expect(r.output, contains('\x1b[?2004l')); // disable bracketed paste on exit
    });

    test('enables in-band resize when the option forces it on', () async {
      final r = await run([...type('hi'), enter], options: const ReadlineOptions(inBandResize: true));
      expect(r.output, contains('\x1b[?2048h')); // enable in-band resize
      expect(r.output, contains('\x1b[?2048l')); // disable in-band resize on exit
    });

    test('reflows on a WindowResizeEvent without a keypress', () async {
      // Drive a resize between two renders; the widget repaints on the event.
      final r = await run([...type('hi'), const WindowResizeEvent(24, 40), enter]);
      expect(r.result, 'hi');
    });

    test('relies on a prior probe (TermInfo) to enable bracketed paste', () async {
      final out = BufferTermSink();
      await mockedTest(
        (term, _, _) async {
          // Probe only bracketed paste; seed a "supported" DECRPM reply.
          final probeFuture = term.probe(
            skip: {
              ProbeQuery.deviceAttrs,
              ProbeQuery.terminalVersion,
              ProbeQuery.foregroundColor,
              ProbeQuery.backgroundColor,
              ProbeQuery.syncUpdate,
              ProbeQuery.keyboardCapabilities,
              ProbeQuery.windowSizePixels,
              ProbeQuery.unicodeCore,
              ProbeQuery.colorScheme,
              ProbeQuery.inBandResize,
            },
            timeout: 50,
          );
          await probeFuture;
          expect(term.termInfo?.bracketedPaste, isA<Supported<BracketedPasteStatus>>());

          await term.readLine();
        },
        stdout: out,
        eventSource: Stream<Event>.fromIterable(<Event>[
          QueryBracketedPasteEvent(1),
          const CursorPositionEvent(1, 1),
          ...type('hi'),
          enter,
        ]),
      );
      // readLine picked up support from the cached probe — no re-query.
      expect(out.output, contains('\x1b[?2004h'));
    });

    test('paste event still handled even on the fallback path', () async {
      // A PasteEvent that arrives is always honored; only the enable/disable
      // escape emission is gated on support.
      final r = await run([const PasteEvent('xyz'), enter]);
      expect(r.result, 'xyz');
    });

    test('a completely full line puts the cursor on the next row start', () async {
      // 10 chars in a 10-wide terminal fills row 1 exactly.
      final r = await run([...type('0123456789'), enter], options: const ReadlineOptions(wrap: true), columns: 10);
      expect(r.result, '0123456789');
      // cursor parked at row 2 col 1, not row 1 col 11.
      expect(r.output, contains('\x1b[2;1H'));
    });
  });

  group('Readline - prompt', () {
    test('prompt is not part of the returned value', () async {
      final r = await run(
        [...type('hi'), enter],
        options: const ReadlineOptions(prompt: '> '),
      );
      expect(r.result, 'hi');
    });

    test('styled prompt is closed with a reset so color does not bleed', () async {
      final promptStyle = Style(fg: Color.fromString('green'), profile: ProfileEnum.ansi16);
      final r = await run(
        [...type('hi'), enter],
        options: ReadlineOptions(prompt: '> ', promptStyle: promptStyle),
      );
      // the prompt's SGR is emitted and immediately followed by a reset.
      expect(r.output, contains('m> \x1b[0m'));
    });

    test('noColor prompt emits no SGR and no reset', () async {
      final promptStyle = Style(fg: Color.fromString('green'), profile: ProfileEnum.noColor);
      final r = await run(
        [...type('hi'), enter],
        options: ReadlineOptions(prompt: '> ', promptStyle: promptStyle),
      );
      expect(r.result, 'hi');
      expect(r.output, isNot(contains('\x1b[0m')));
    });
  });
}
