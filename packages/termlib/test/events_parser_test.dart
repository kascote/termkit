import 'dart:convert';

import 'package:termlib/src/key_handler/events_parser.dart';
import 'package:termlib/termlib.dart';
import 'package:test/test.dart';

List<int> keySequence(String seq) {
  final buffer = seq.replaceAll('π', '\x1b');
  return utf8.encode(buffer);
}

void main() {
  final t = TermLib();

  group('parse utf8', () {
    test(
      'unicode',
      () {
        final ev = parseEvent(t, keySequence('Ž'));
        expect(ev, equals(KeyEvent(const KeyCode(char: 'Ž'), modifiers: const KeyModifiers(KeyModifiers.shift))));
      },
    );
  });

  group('keys', () {
    test('escape', () {
      final ev = parseEvent(t, keySequence('π'));
      expect(ev, equals(KeyEvent(const KeyCode(name: KeyCodeName.escape))));
    });

    test('alt', () {
      final ev = parseEvent(t, keySequence('πc'));
      expect(ev, equals(KeyEvent(const KeyCode(char: 'c'), modifiers: const KeyModifiers(KeyModifiers.alt))));
    });

    test('alt shift', () {
      final ev = parseEvent(t, keySequence('πH'));
      expect(
        ev,
        equals(
          KeyEvent(
            const KeyCode(char: 'H'),
            modifiers: const KeyModifiers(KeyModifiers.alt | KeyModifiers.shift),
          ),
        ),
      );
    });

    test('alt ctrl', () {
      final ev = parseEvent(t, [0x1b, 0x14]);
      expect(
        ev,
        equals(
          KeyEvent(
            const KeyCode(char: 't'),
            modifiers: const KeyModifiers(KeyModifiers.alt | KeyModifiers.ctrl),
          ),
        ),
      );
    });

    test('tab', () {
      final ev = parseEvent(t, [0x9]);
      expect(ev, equals(KeyEvent(const KeyCode(name: KeyCodeName.tab))));
    });
  });

  // 0x1b, 0x5b .... 0x7e
  group('event parser CSI [', () {
    test('escape', () {
      final ev = parseEvent(t, keySequence('π'));
      expect(ev, equals(KeyEvent(const KeyCode(name: KeyCodeName.escape))));
    });

    test('home', () {
      final ev = parseEvent(t, keySequence('π[1~'));
      expect(ev, equals(KeyEvent(const KeyCode(name: KeyCodeName.home))));
    });

    test('π[2D', () {
      final ev = parseEvent(t, keySequence('π[2D'));
      expect(
        ev,
        equals(
          KeyEvent(
            const KeyCode(name: KeyCodeName.left),
            modifiers: const KeyModifiers(KeyModifiers.shift),
          ),
        ),
      );
    });

    test('H', () {
      final ev = parseEvent(t, keySequence('π[H'));
      expect(ev, equals(KeyEvent(const KeyCode(name: KeyCodeName.home))));
    });

    test('1;3H', () {
      final ev = parseEvent(t, keySequence('π[1;3H'));
      expect(
        ev,
        equals(
          KeyEvent(
            const KeyCode(name: KeyCodeName.home),
            modifiers: const KeyModifiers(KeyModifiers.alt),
          ),
        ),
      );
    });

    // keyPress
    test('1;3;1H', () {
      final ev = parseEvent(t, keySequence('π[1;3H'));
      expect(
        ev,
        equals(
          KeyEvent(
            const KeyCode(name: KeyCodeName.home),
            modifiers: const KeyModifiers(KeyModifiers.alt),
          ),
        ),
      );
    });

    test('1;3:2H', () {
      final ev = parseEvent(t, keySequence('π[1;3:2H'));
      expect(
        ev,
        equals(
          KeyEvent(
            const KeyCode(name: KeyCodeName.home),
            modifiers: const KeyModifiers(KeyModifiers.alt),
            eventType: KeyEventType.keyRepeat,
          ),
        ),
      );
    });

    test('1;3:3H', () {
      final ev = parseEvent(t, keySequence('π[1;3:3H'));
      expect(
        ev,
        equals(
          KeyEvent(
            const KeyCode(name: KeyCodeName.home),
            modifiers: const KeyModifiers(KeyModifiers.alt),
            eventType: KeyEventType.keyRelease,
          ),
        ),
      );
    });

    test('del', () {
      final ev = parseEvent(t, keySequence('π[3~'));
      expect(ev, equals(KeyEvent(const KeyCode(name: KeyCodeName.delete))));
    });

    test('3;2~', () {
      final ev = parseEvent(t, keySequence('π[3;2~'));
      expect(
        ev,
        equals(
          KeyEvent(const KeyCode(name: KeyCodeName.delete), modifiers: const KeyModifiers(KeyModifiers.shift)),
        ),
      );
    });

    test('3;3~', () {
      final ev = parseEvent(t, keySequence('π[3;3~'));
      expect(
        ev,
        equals(
          KeyEvent(const KeyCode(name: KeyCodeName.delete), modifiers: const KeyModifiers(KeyModifiers.alt)),
        ),
      );
    });

    test('5;1:3~', () {
      final ev = parseEvent(t, keySequence('π[5;1:3~'));
      expect(
        ev,
        equals(
          KeyEvent(const KeyCode(name: KeyCodeName.pageUp), eventType: KeyEventType.keyRelease),
        ),
      );
    });

    test('6;5:3~', () {
      final ev = parseEvent(t, keySequence('π[6;5:3~'));
      expect(
        ev,
        equals(
          KeyEvent(
            const KeyCode(name: KeyCodeName.pageDown),
            modifiers: const KeyModifiers(KeyModifiers.ctrl),
            eventType: KeyEventType.keyRelease,
          ),
        ),
      );
    });
  });

  group('cursor', () {
    test('CSI cursor position', () {
      final ev = parseEvent(t, keySequence('π[20;10R'));
      expect(ev, equals(const CursorPositionEvent(10, 20)));
    });
  });

  group('CSI normal mouse', () {
    test('CSI mouse down', () {
      final ev = parseEvent(t, [0x1b, 0x5b, 0x4d, 0x30, 0x60, 0x70]);
      expect(
        ev,
        equals(
          MouseEvent(
            64,
            80,
            MouseEventKind.down(MouseButton.left),
            modifiers: const KeyModifiers(KeyModifiers.ctrl),
          ),
        ),
      );
    });
  });

  group('CSI SGR mouse', () {
    test('.[<0;20;10;M', () {
      final ev = parseEvent(t, keySequence('π[<0;20;10;M'));
      expect(ev, MouseEvent(20, 10, MouseEventKind.down(MouseButton.left)));
    });

    test('.[<0;20;10M', () {
      final ev = parseEvent(t, keySequence('π[<0;20;10M'));
      expect(ev, MouseEvent(20, 10, MouseEventKind.down(MouseButton.left)));
    });

    test('.[<0;20;10;m', () {
      final ev = parseEvent(t, keySequence('π[<0;20;10;m'));
      expect(ev, MouseEvent(20, 10, MouseEventKind.up(MouseButton.left)));
    });

    test('.[<0;20;10m', () {
      final ev = parseEvent(t, keySequence('π[<0;20;10m'));
      expect(ev, MouseEvent(20, 10, MouseEventKind.up(MouseButton.left)));
    });

    test('.[<53;20;10m', () {
      final ev = parseEvent(t, keySequence('π[<51;20;10m'));
      expect(ev, MouseEvent(20, 10, MouseEventKind.moved(), modifiers: const KeyModifiers(KeyModifiers.ctrl)));
    });
  });

  group('focus events', () {
    test('CSI I', () {
      final ev = parseEvent(t, keySequence('π[I'));
      expect(ev, equals(const FocusEvent()));
    });

    test('CSI O', () {
      final ev = parseEvent(t, keySequence('π[O'));
      expect(ev, equals(const FocusEvent(hasFocus: false)));
    });
  });

  group('Keyboard Enhancement Flags', () {
    test('test flags', () {
      final ev = parseEvent(t, keySequence('π[?1u'));
      expect(ev, equals(const KeyboardEnhancementFlags(KeyboardEnhancementFlags.disambiguateEscapeCodes)));
    });

    test('test flags 2', () {
      final ev = parseEvent(t, keySequence('π[?4u'));
      expect(ev, equals(const KeyboardEnhancementFlags(KeyboardEnhancementFlags.reportAlternateKeys)));
    });

    test('test flags 3', () {
      final ev = parseEvent(t, keySequence('π[?10u'));
      expect(
        ev,
        equals(
          const KeyboardEnhancementFlags(
            KeyboardEnhancementFlags.reportAllKeysAsEscapeCodes | KeyboardEnhancementFlags.reportEventTypes,
          ),
        ),
      );
    });
  });

  group('Bracketed Paste', () {
    test('test paste', () {
      // final ev = parseEvent(t, keySequence('π[200~where is Carmen San Diego Ž π[201~'));
      final ev = parseEvent(t, keySequence('π[200~where is Carmen San Diego Ž🩷 π[201~'));
      expect(ev, equals(const PasteEvent('where is Carmen San Diego Ž🩷 ')));
    });

    test('without finish mark', () {
      final ev = parseEvent(t, keySequence('π[200~o'));
      expect(ev, isA<ParserErrorEvent>());
    });

    test('brackets paste with escape code', () {
      final ev = parseEvent(t, keySequence('π[200~oπ[2D'));
      expect(ev, isA<ParserErrorEvent>());
    });

    test('brackets paste with escape code', () {
      final ev = parseEvent(t, keySequence('π[200~oπ[2Dπ[201~'));
      expect(ev, equals(PasteEvent(keySequence('oπ[2D').map(String.fromCharCode).join())));
    });
  });

  group('parse CSI U', () {
    test('.[97u', () {
      final ev = parseEvent(t, keySequence('π[97u'));
      expect(ev, equals(KeyEvent(const KeyCode(char: 'a'))));
    });

    test('.[97;2u', () {
      final ev = parseEvent(t, keySequence('π[97:65;2u'));
      expect(ev, equals(KeyEvent(const KeyCode(char: 'A'), modifiers: const KeyModifiers(KeyModifiers.shift))));
    });

    test('.[97;7u', () {
      final ev = parseEvent(t, keySequence('π[97;7u'));
      const mod = KeyModifiers(KeyModifiers.ctrl | KeyModifiers.alt);
      expect(ev, equals(KeyEvent(const KeyCode(char: 'a'), modifiers: mod)));
    });

    test('.[13u', () {
      final ev = parseEvent(t, keySequence('π[13u'));
      expect(ev, equals(KeyEvent(const KeyCode(name: KeyCodeName.enter))));
    });

    test('.[27u', () {
      final ev = parseEvent(t, keySequence('π[27u'));
      expect(ev, equals(KeyEvent(const KeyCode(name: KeyCodeName.escape))));
    });

    test('.[57358u', () {
      final ev = parseEvent(t, keySequence('π[57358u'));
      expect(ev, equals(KeyEvent(const KeyCode(name: KeyCodeName.capsLock))));
    });

    test('.[57376u', () {
      final ev = parseEvent(t, keySequence('π[57376u'));
      expect(ev, equals(KeyEvent(const KeyCode(name: KeyCodeName.f13))));
    });

    test('.[57428u', () {
      final ev = parseEvent(t, keySequence('π[57428u'));
      expect(ev, equals(KeyEvent(const KeyCode(media: MediaKeyCode.play))));
    });

    test('.[57441u', () {
      final ev = parseEvent(t, keySequence('π[57441u'));
      expect(
        ev,
        equals(
          KeyEvent(
            const KeyCode(modifiers: ModifierKeyCode.leftShift),
            modifiers: const KeyModifiers(KeyModifiers.shift),
          ),
        ),
      );
    });

    test('.[57399u', () {
      final ev = parseEvent(t, keySequence('π[57399u'));
      expect(
        ev,
        equals(
          KeyEvent(
            const KeyCode(char: '0'),
            eventState: KeyEventState.keypad(),
          ),
        ),
      );
    });

    test('.[57419u', () {
      final ev = parseEvent(t, keySequence('π[57419u'));
      expect(
        ev,
        equals(
          KeyEvent(
            const KeyCode(name: KeyCodeName.up),
            eventState: KeyEventState.keypad(),
          ),
        ),
      );
    });

    test('.[97;1u', () {
      final ev = parseEvent(t, keySequence('π[97;1u'));
      expect(ev, equals(KeyEvent(const KeyCode(char: 'a'))));
    });

    test('.[97;1:1u', () {
      final ev = parseEvent(t, keySequence('π[97;1:1u'));
      expect(ev, equals(KeyEvent(const KeyCode(char: 'a'))));
    });

    test('.[97;5:1u', () {
      final ev = parseEvent(t, keySequence('π[97;5:1u'));
      expect(ev, equals(KeyEvent(const KeyCode(char: 'a'), modifiers: const KeyModifiers(KeyModifiers.ctrl))));
    });

    test('.[97;1:2u', () {
      final ev = parseEvent(t, keySequence('π[97;1:2u'));
      expect(ev, equals(KeyEvent(const KeyCode(char: 'a'), eventType: KeyEventType.keyRepeat)));
    });

    test('.[97;1:3u', () {
      final ev = parseEvent(t, keySequence('π[97;1:3u'));
      expect(ev, equals(KeyEvent(const KeyCode(char: 'a'), eventType: KeyEventType.keyRelease)));
    });

    test('.[57449u', () {
      final ev = parseEvent(t, keySequence('π[57449u'));
      expect(
        ev,
        equals(
          KeyEvent(
            const KeyCode(modifiers: ModifierKeyCode.rightAlt),
            modifiers: const KeyModifiers(KeyModifiers.alt),
          ),
        ),
      );
    });

    test('.[57449;3:3u', () {
      final ev = parseEvent(t, keySequence('π[57449;3:3u'));
      expect(
        ev,
        equals(
          KeyEvent(
            const KeyCode(modifiers: ModifierKeyCode.rightAlt),
            modifiers: const KeyModifiers(KeyModifiers.alt),
            eventType: KeyEventType.keyRelease,
          ),
        ),
      );
    });

    test('.[57448;16:2u', () {
      final ev = parseEvent(t, keySequence('π[57448;16:2u'));
      expect(
        ev,
        equals(
          KeyEvent(
            const KeyCode(modifiers: ModifierKeyCode.rightControl),
            modifiers:
                const KeyModifiers(KeyModifiers.shift | KeyModifiers.alt | KeyModifiers.ctrl | KeyModifiers.superKey),
            eventType: KeyEventType.keyRepeat,
          ),
        ),
      );
    });

    test('.[57450u', () {
      final ev = parseEvent(t, keySequence('π[57450u'));
      expect(
        ev,
        equals(
          KeyEvent(
            const KeyCode(modifiers: ModifierKeyCode.rightSuper),
            modifiers: const KeyModifiers(KeyModifiers.superKey),
          ),
        ),
      );
    });

    test('.[57451u', () {
      final ev = parseEvent(t, keySequence('π[57451u'));
      expect(
        ev,
        equals(
          KeyEvent(
            const KeyCode(modifiers: ModifierKeyCode.rightHyper),
            modifiers: const KeyModifiers(KeyModifiers.hyper),
          ),
        ),
      );
    });

    test('.[57452u', () {
      final ev = parseEvent(t, keySequence('π[57452u'));
      expect(
        ev,
        equals(
          KeyEvent(
            const KeyCode(modifiers: ModifierKeyCode.rightMeta),
            modifiers: const KeyModifiers(KeyModifiers.meta),
          ),
        ),
      );
    });

    test('.[97;9u', () {
      final ev = parseEvent(t, keySequence('π[97;9u'));
      expect(ev, equals(KeyEvent(const KeyCode(char: 'a'), modifiers: const KeyModifiers(KeyModifiers.superKey))));
    });

    test('.[97;17u', () {
      final ev = parseEvent(t, keySequence('π[97;17u'));
      expect(ev, equals(KeyEvent(const KeyCode(char: 'a'), modifiers: const KeyModifiers(KeyModifiers.hyper))));
    });

    test('.[97;33u', () {
      final ev = parseEvent(t, keySequence('π[97;33u'));
      expect(
        ev,
        equals(
          KeyEvent(const KeyCode(char: 'a'), modifiers: const KeyModifiers(KeyModifiers.meta)),
        ),
      );
    });

    test('.[97;65u', () {
      final ev = parseEvent(t, keySequence('π[97;65u'));
      expect(ev, equals(KeyEvent(const KeyCode(char: 'a'), eventState: KeyEventState.capsLock())));
    });

    test('.[49;129u', () {
      final ev = parseEvent(t, keySequence('π[49;129u'));
      expect(ev, equals(KeyEvent(const KeyCode(char: '1'), eventState: KeyEventState.numLock())));
    });

    test(
      '.[57:40;4u',
      () {
        final ev = parseEvent(t, keySequence('π[57:40;4u'));
        expect(
          ev,
          equals(
            KeyEvent(
              const KeyCode(char: '('),
              modifiers: const KeyModifiers(KeyModifiers.alt | KeyModifiers.shift),
            ),
          ),
        );
      },
    );

    test(
      '.[45:95;4u',
      () {
        final ev = parseEvent(t, keySequence('π[45:95;4u'));
        expect(
          ev,
          equals(
            KeyEvent(
              const KeyCode(char: '_'),
              modifiers: const KeyModifiers(KeyModifiers.alt | KeyModifiers.shift),
            ),
          ),
        );
      },
    );

    test('.[;1:3B', () {
      final ev = parseEvent(t, keySequence('π[;1:3B'));
      expect(ev, equals(KeyEvent(const KeyCode(name: KeyCodeName.down), eventType: KeyEventType.keyRelease)));
    });

    test('.[1;1:3B', () {
      final ev = parseEvent(t, keySequence('π[1;1:3B'));
      expect(ev, equals(KeyEvent(const KeyCode(name: KeyCodeName.down), eventType: KeyEventType.keyRelease)));
    });

    test('.[27;9u', () {
      final ev = parseEvent(t, keySequence('π[27;9u'));
      expect(
        ev,
        equals(
          KeyEvent(
            const KeyCode(name: KeyCodeName.escape),
            modifiers: const KeyModifiers(KeyModifiers.superKey),
          ),
        ),
      );
    });
  });

  group('parse OSC', () {
    test('OSC 11', () {
      final ev = parseEvent(t, keySequence(r'π]11;rgb:ff/ff/ffπ\\'));
      expect(
        ev,
        equals(const ColorQueryEvent(255, 255, 255)),
      );
    });

    test('OSC 11 2', () {
      final ev = parseEvent(t, keySequence(r'π]11;rgb:abff/bcff/cdffπ\\'));
      expect(
        ev,
        equals(const ColorQueryEvent(171, 188, 205)), // ab/bc/cd
      );
    });
  });
}
