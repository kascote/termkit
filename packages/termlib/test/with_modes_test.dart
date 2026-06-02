import 'package:termlib/termlib.dart';
import 'package:test/test.dart';

import 'shared.dart';

// Bracketed paste is the stand-in for the output-observable bool modes: every
// `bool?` param shares the same `manage` logic, so exercising the full matrix
// on one mode covers them all.
const pasteOn = '\x1b[?2004h';
const pasteOff = '\x1b[?2004l';
const wrapOn = '\x1b[?7h';
const wrapOff = '\x1b[?7l';

void main() {
  group('withModes - param × prior matrix (bracketedPaste)', () {
    test('true / prior off → enable on entry, disable (restore) on exit', () async {
      await mockedTest((term, out, _) async {
        out.clearOutput();
        late String entry;
        late bool during;
        await term.withModes(() async {
          entry = out.output;
          during = term.modes.bracketedPaste;
        }, bracketedPaste: true);

        expect(entry, pasteOn, reason: 'enabled on entry');
        expect(during, isTrue);
        expect(out.output.substring(entry.length), pasteOff, reason: 'restored to prior off');
        expect(term.modes.bracketedPaste, isFalse);
      });
    });

    test('true / prior on → enable on entry, restore ON on exit (never disables)', () async {
      await mockedTest((term, out, _) async {
        term.enableBracketedPaste();
        out.clearOutput();
        late bool during;
        await term.withModes(() async {
          during = term.modes.bracketedPaste;
        }, bracketedPaste: true);

        expect(during, isTrue);
        expect(term.modes.bracketedPaste, isTrue);
        expect(out.output, isNot(contains(pasteOff)), reason: 'prior on → no disable on exit');
      });
    });

    test('false / prior on → disable on entry, restore ON on exit (good citizen)', () async {
      await mockedTest((term, out, _) async {
        term.enableBracketedPaste();
        out.clearOutput();
        late String entry;
        late bool during;
        await term.withModes(() async {
          entry = out.output;
          during = term.modes.bracketedPaste;
        }, bracketedPaste: false);

        expect(entry, pasteOff, reason: 'disabled on entry');
        expect(during, isFalse);
        expect(out.output.substring(entry.length), pasteOn, reason: 'restored to prior on');
        expect(term.modes.bracketedPaste, isTrue);
      });
    });

    test('false / prior off → disable on entry, disable (restore) on exit', () async {
      await mockedTest((term, out, _) async {
        out.clearOutput();
        await term.withModes(() async {}, bracketedPaste: false);
        expect(out.output, '$pasteOff$pasteOff');
        expect(term.modes.bracketedPaste, isFalse);
      });
    });

    test('null / prior off → untouched: no escape, stays off', () async {
      await mockedTest((term, out, _) async {
        out.clearOutput();
        late bool during;
        await term.withModes(() async {
          during = term.modes.bracketedPaste;
        });
        expect(during, isFalse);
        expect(out.output, isEmpty);
        expect(term.modes.bracketedPaste, isFalse);
      });
    });

    test('null / prior on → untouched: no escape, stays on', () async {
      await mockedTest((term, out, _) async {
        term.enableBracketedPaste();
        out.clearOutput();
        late bool during;
        await term.withModes(() async {
          during = term.modes.bracketedPaste;
        });
        expect(during, isTrue);
        expect(out.output, isEmpty);
        expect(term.modes.bracketedPaste, isTrue);
      });
    });
  });

  group('withModes - rawMode (termios callStack)', () {
    test('true / prior off → enable on entry, disable on exit', () async {
      await mockedTest((term, _, tos) async {
        await term.withModes(() async {
          expect(term.modes.rawMode, isTrue);
        }, rawMode: true);
        expect(tos.callStack, ['enableRawMode', 'disableRawMode']);
        expect(term.modes.rawMode, isFalse);
      });
    });

    test('true / prior on → restore stays raw (no disable)', () async {
      await mockedTest((term, _, tos) async {
        term.enableRawMode();
        tos.callStack.clear();
        await term.withModes(() async {}, rawMode: true);
        // entry re-enables, exit restores to prior on (enable) — never disables.
        expect(tos.callStack, ['enableRawMode', 'enableRawMode']);
        expect(tos.callStack, isNot(contains('disableRawMode')));
        expect(term.modes.rawMode, isTrue);
      });
    });
  });

  group('withModes - restore on exception', () {
    test('finally restores prior state even when fn throws', () async {
      await mockedTest((term, out, _) async {
        out.clearOutput();
        await expectLater(
          term.withModes(() async => throw StateError('boom'), bracketedPaste: true),
          throwsA(isA<StateError>()),
        );
        expect(out.output, '$pasteOn$pasteOff', reason: 'enabled then restored despite throw');
        expect(term.modes.bracketedPaste, isFalse);
      });
    });
  });

  group('withModes - nested scopes do not clobber', () {
    test('inner scope leaves an outer-managed mode untouched', () async {
      await mockedTest((term, out, _) async {
        out.clearOutput();
        late bool pasteDuringInner;
        late bool wrapAfterInner;

        await term.withModes(() async {
          // inner manages only lineWrapping; bracketedPaste left null.
          await term.withModes(() async {
            pasteDuringInner = term.modes.bracketedPaste;
          }, lineWrapping: false);

          // outer's paste survived the inner scope...
          expect(term.modes.bracketedPaste, isTrue);
          // ...and inner restored wrapping to the outer/default on.
          wrapAfterInner = term.modes.lineWrapping;
        }, bracketedPaste: true);

        expect(pasteDuringInner, isTrue, reason: 'inner inherits outer paste');
        expect(wrapAfterInner, isTrue, reason: 'inner restored wrap on exit');
        // After outer: paste restored off, wrap back on.
        expect(term.modes.bracketedPaste, isFalse);
        expect(term.modes.lineWrapping, isTrue);
        // Escape order: paste on, wrap off, wrap on, paste off.
        expect(out.output, '$pasteOn$wrapOff$wrapOn$pasteOff');
      });
    });
  });

  group('withModes - keyboardEnhancement (push/pop)', () {
    test('managed → push on entry, pop on exit; cell tracks pushed flags', () async {
      await mockedTest((term, out, _) async {
        out.clearOutput();
        late int duringFlags;
        await term.withModes(() async {
          duringFlags = term.modes.keyboardFlags!.flags;
        }, keyboardEnhancement: KeyboardEnhancement.basic);

        expect(duringFlags, 15, reason: 'basic flags pushed');
        expect(out.output, '\x1b[>15u\x1b[<1u', reason: 'push then pop');
        expect(term.modes.keyboardFlags, isNull, reason: 'restored to prior (unmanaged)');
      });
    });

    test('null → not managed: no push/pop', () async {
      await mockedTest((term, out, _) async {
        out.clearOutput();
        await term.withModes(() async {});
        expect(out.output, isEmpty);
        expect(term.modes.keyboardFlags, isNull);
      });
    });

    test('prior flags present → restored to prior value on exit', () async {
      await mockedTest((term, out, _) async {
        term.enableKeyboardEnhancement(); // basic = 15
        out.clearOutput();
        await term.withModes(() async {
          expect(term.modes.keyboardFlags!.flags, 31, reason: 'full pushed over basic');
        }, keyboardEnhancement: KeyboardEnhancement.full);

        expect(out.output, '\x1b[>31u\x1b[<1u');
        expect(term.modes.keyboardFlags?.flags, 15, reason: 'cell reset to prior basic');
      });
    });
  });
}
