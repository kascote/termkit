import 'dart:convert';

import 'package:termparser/termparser.dart';
import 'package:termparser/termparser_events.dart';
import 'package:test/test.dart';

/// Helper to convert test sequences to byte arrays.
/// Use π (pi) to represent ESC (0x1B) for readability.
/// Example: keySequence('π[H') → [0x1B, 0x5B, 0x48]
List<int> keySequence(String seq) {
  final buffer = seq.replaceAll('π', '\x1b');
  return utf8.encode(buffer);
}

void main() {
  group('Parser >', () {
    test('char', () {
      final parser = Parser()..advance([0x61]);
      expect(parser.hasEvents, true);
    });

    test('Ž', () {
      final parser = Parser()..advance(keySequence('Ž'));
      expect(parser.hasEvents, true);
      expect(parser.nextEvent(), equals(const KeyEvent(KeyCode.char('Ž'))));
    });

    test('esc sequence', () {
      final parser = Parser()..advance([0x1B], hasMore: true);
      expect(parser.hasEvents, false);
      parser.advance([0x61]);
      expect(parser.hasEvents, true);
    });

    test('esc sequence with uppercase O', () {
      final parser = Parser()..advance([0x1B], hasMore: true);
      expect(parser.hasEvents, false);
      parser.advance([0x4F]);
      expect(parser.hasEvents, false);
    });

    test('esc sequence with uppercase O followed by a char', () {
      final parser = Parser()..advance([0x1B], hasMore: true);
      expect(parser.hasEvents, false);
      parser.advance([0x4F], hasMore: true); // O
      expect(parser.hasEvents, false);
      parser.advance([0x50]); // P
      expect(parser.hasEvents, true);
      expect(parser.nextEvent(), isNotNull);
      expect(parser.hasEvents, false);
    });

    test('πOR', () {
      final parser = Parser()..advance(keySequence('πOR'));
      expect(parser.hasEvents, true);
      expect(
        parser.nextEvent(),
        equals(const KeyEvent(KeyCode.named(KeyCodeName.f3))),
      );
    });

    test('πc', () {
      final parser = Parser()..advance(keySequence('πc'));
      expect(parser.hasEvents, true);
      expect(
        parser.nextEvent(),
        equals(const KeyEvent(KeyCode.char('c'), modifiers: KeyModifiers(KeyModifiers.alt))),
      );
    });

    test('πH', () {
      final parser = Parser()..advance(keySequence('πH'));
      expect(parser.hasEvents, true);
      expect(
        parser.nextEvent(),
        equals(
          const KeyEvent(
            KeyCode.char('H'), // must have shift included? is an uppercase
            modifiers: KeyModifiers(KeyModifiers.alt),
          ),
        ),
      );
    });

    test('tab / ctrl-i', () {
      final parser = Parser()..advance([0x09]);
      expect(parser.hasEvents, true);
      expect(
        parser.nextEvent(),
        equals(const KeyEvent(KeyCode.named(KeyCodeName.tab))),
      );
    });

    test('ctrl-h', () {
      final parser = Parser()..advance([0x08]);
      expect(parser.hasEvents, true);
      expect(
        parser.nextEvent(),
        equals(const KeyEvent(KeyCode.named(KeyCodeName.backSpace))),
      );
    });
  });

  group('CSI > ', () {
    test('sequence', () {
      final parser = Parser()..advance([0x1B], hasMore: true);
      expect(parser.hasEvents, false);
      parser.advance([0x5B], hasMore: true); // [
      expect(parser.hasEvents, false);
      parser.advance([0x44]); // D
      expect(parser.hasEvents, true);
    });

    test('ESC [1;3:2H', () {
      final parser = Parser()..advance([0x1B, 0x5B, 0x31, 0x3b, 0x32, 0x3a, 0x33, 0x48]);
      expect(parser.hasEvents, true);
      expect(
        parser.nextEvent(),
        const KeyEvent(
          KeyCode.named(KeyCodeName.home),
          modifiers: KeyModifiers(KeyModifiers.shift),
          eventType: KeyEventType.keyRelease,
        ),
      );
    });

    test('ESC [H', () {
      final parser = Parser()..advance([0x1B, 0x5B, 0x48]);
      expect(parser.hasEvents, true);
      expect(
        parser.nextEvent(),
        const KeyEvent(KeyCode.named(KeyCodeName.home)),
      );
    });

    test('ESC [< 35 ; 86 ; 18 M', () {
      final parser = Parser()..advance(keySequence('π[<35;86;18M'));
      expect(parser.hasEvents, true);
      expect(
        parser.nextEvent(),
        MouseEvent(86, 18, MouseButton.moved(MouseButtonKind.none)),
      );
    });

    test('ESC [< 32 ; 86 ; 18 M (drag)', () {
      final parser = Parser()..advance(keySequence('π[<32;86;18M'));
      expect(parser.hasEvents, true);
      expect(
        parser.nextEvent(),
        MouseEvent(86, 18, MouseButton.moved(MouseButtonKind.left)),
      );
    });

    test('ESC [< 24 ; 86 ; 18 M', () {
      final parser = Parser()..advance(keySequence('π[<24;86;18M'));
      expect(parser.hasEvents, true);
      expect(
        parser.nextEvent(),
        MouseEvent(
          86,
          18,
          MouseButton.down(MouseButtonKind.left),
          modifiers: const KeyModifiers(KeyModifiers.ctrl | KeyModifiers.alt),
        ),
      );
    });

    test('π[<0;20;10;m', () {
      final parser = Parser()..advance(keySequence('π[<0;20;10;m'));
      expect(parser.hasEvents, true);
      expect(
        parser.nextEvent(),
        MouseEvent(20, 10, MouseButton.up(MouseButtonKind.left)),
      );
    });

    test('π[<0;20;10m', () {
      final parser = Parser()..advance(keySequence('π[<0;20;10m'));
      expect(parser.hasEvents, true);
      expect(
        parser.nextEvent(),
        MouseEvent(20, 10, MouseButton.up(MouseButtonKind.left)),
      );
    });

    test('π[<53;20;10m', () {
      final parser = Parser()..advance(keySequence('π[<51;20;10m'));
      expect(parser.hasEvents, true);
      expect(
        parser.nextEvent(),
        MouseEvent(20, 10, MouseButton.moved(), modifiers: const KeyModifiers(KeyModifiers.ctrl)),
      );
    });

    test('ESC [I', () {
      final parser = Parser()..advance(keySequence('π[I'));
      expect(parser.hasEvents, true);
      expect(parser.nextEvent(), const FocusEvent());
    });

    test('ESC [O', () {
      final parser = Parser()..advance(keySequence('π[O'));
      expect(parser.hasEvents, true);
      expect(parser.nextEvent(), const FocusEvent(hasFocus: false));
    });

    test('ESC [ ? 1 u', () {
      final parser = Parser()..advance(keySequence('π[?1u'));
      expect(parser.hasEvents, true);
      expect(
        parser.nextEvent(),
        equals(const KeyboardEnhancementFlagsEvent(KeyboardEnhancementFlagsEvent.disambiguateEscapeCodes)),
      );
    });

    test('ESC [ 97 u', () {
      final parser = Parser()..advance(keySequence('π[97u'));
      expect(parser.hasEvents, true);
      expect(parser.nextEvent(), equals(const KeyEvent(KeyCode.char('a'))));
    });

    test('ESC [ 97 : 65 ; 2 u', () {
      final parser = Parser()..advance(keySequence('π[97:65;2u'));
      expect(parser.hasEvents, true);
      expect(
        parser.nextEvent(),
        equals(const KeyEvent(KeyCode.char('A'), modifiers: KeyModifiers(KeyModifiers.shift))),
      );
    });

    test('.[97;7u', () {
      final parser = Parser()..advance(keySequence('π[97;7u'));
      expect(parser.hasEvents, true);
      expect(
        parser.nextEvent(),
        equals(const KeyEvent(KeyCode.char('a'), modifiers: KeyModifiers(KeyModifiers.ctrl | KeyModifiers.alt))),
      );
    });

    test('.[13u', () {
      final parser = Parser()..advance(keySequence('π[13u'));
      expect(parser.hasEvents, true);
      expect(
        parser.nextEvent(),
        equals(const KeyEvent(KeyCode.named(KeyCodeName.enter))),
      );
    });

    test('.[27u', () {
      final parser = Parser()..advance(keySequence('π[27u'));
      expect(parser.hasEvents, true);
      expect(
        parser.nextEvent(),
        equals(const KeyEvent(KeyCode.named(KeyCodeName.escape))),
      );
    });

    test('.[57358u', () {
      final parser = Parser()..advance(keySequence('π[57358u'));
      expect(parser.hasEvents, true);
      expect(
        parser.nextEvent(),
        equals(const KeyEvent(KeyCode.named(KeyCodeName.capsLock))),
      );
    });

    test('.[57376u', () {
      final parser = Parser()..advance(keySequence('π[57376u'));
      expect(parser.hasEvents, true);
      expect(
        parser.nextEvent(),
        equals(const KeyEvent(KeyCode.named(KeyCodeName.f13))),
      );
    });

    test('.[57428u', () {
      final parser = Parser()..advance(keySequence('π[57428u'));
      expect(parser.hasEvents, true);
      expect(
        parser.nextEvent(),
        equals(const KeyEvent(KeyCode.media(MediaKeyCode.play))),
      );
    });

    test('.[57441u', () {
      final parser = Parser()..advance(keySequence('π[57441u'));
      expect(parser.hasEvents, true);
      expect(
        parser.nextEvent(),
        equals(
          const KeyEvent(
            KeyCode.modifier(ModifierKey.leftShift),
            modifiers: KeyModifiers(KeyModifiers.shift),
          ),
        ),
      );
    });

    test('.[57441u - modifierKeys', () {
      final parser = Parser()..advance(keySequence('π[57441u'));
      expect(parser.hasEvents, true);
      final event = parser.nextEvent()! as KeyEvent;
      expect(event.modifierKeys, contains(ModifierKey.leftShift));
      expect(event.modifierKeys.length, equals(1));
    });

    test('.[57448u - rightCtrl modifierKeys', () {
      final parser = Parser()..advance(keySequence('π[57448u'));
      expect(parser.hasEvents, true);
      final event = parser.nextEvent()! as KeyEvent;
      expect(event.modifierKeys, contains(ModifierKey.rightCtrl));
      expect(event.modifierKeys.length, equals(1));
    });

    test('.[97u - no modifierKeys for regular key', () {
      final parser = Parser()..advance(keySequence('π[97u'));
      expect(parser.hasEvents, true);
      final event = parser.nextEvent()! as KeyEvent;
      expect(event.modifierKeys, isEmpty);
    });

    test('wildcard matching - equality ignores modifierKeys', () {
      // Two KeyEvents with different modifierKeys should be equal
      const event1 = KeyEvent(
        KeyCode.char('a'),
        modifiers: KeyModifiers(KeyModifiers.ctrl),
        modifierKeys: {ModifierKey.leftCtrl},
      );
      const event2 = KeyEvent(
        KeyCode.char('a'),
        modifiers: KeyModifiers(KeyModifiers.ctrl),
        modifierKeys: {ModifierKey.rightCtrl},
      );
      const event3 = KeyEvent(
        KeyCode.char('a'),
        modifiers: KeyModifiers(KeyModifiers.ctrl),
      );

      expect(event1, equals(event2));
      expect(event1, equals(event3));
      expect(event2, equals(event3));
      expect(event1.hashCode, equals(event2.hashCode));
      expect(event1.hashCode, equals(event3.hashCode));
    });

    test('copyWith preserves and updates fields', () {
      const event = KeyEvent(
        KeyCode.char('a'),
        modifiers: KeyModifiers(KeyModifiers.ctrl),
        modifierKeys: {ModifierKey.leftCtrl},
      );

      final updated = event.copyWith(
        modifierKeys: const {ModifierKey.rightCtrl},
      );

      expect(updated.code, equals(event.code));
      expect(updated.modifiers, equals(event.modifiers));
      expect(updated.modifierKeys, contains(ModifierKey.rightCtrl));
      expect(updated.modifierKeys, isNot(contains(ModifierKey.leftCtrl)));
    });

    test('.[57399u', () {
      final parser = Parser()..advance(keySequence('π[57399u'));
      expect(parser.hasEvents, true);
      expect(
        parser.nextEvent(),
        equals(KeyEvent(const KeyCode.char('0'), eventState: KeyEventState.keypad())),
      );
    });

    test('.[57419u', () {
      final parser = Parser()..advance(keySequence('π[57419u'));
      expect(parser.hasEvents, true);
      expect(
        parser.nextEvent(),
        equals(KeyEvent(const KeyCode.named(KeyCodeName.up), eventState: KeyEventState.keypad())),
      );
    });

    test('.[97;1u', () {
      final parser = Parser()..advance(keySequence('π[97;1u'));
      expect(parser.hasEvents, true);
      expect(
        parser.nextEvent(),
        equals(const KeyEvent(KeyCode.char('a'))),
      );
    });

    test('.[97;1:1u', () {
      final parser = Parser()..advance(keySequence('π[97;1:1u'));
      expect(parser.hasEvents, true);
      expect(
        parser.nextEvent(),
        equals(const KeyEvent(KeyCode.char('a'))),
      );
    });

    test('.[97;5:1u', () {
      final parser = Parser()..advance(keySequence('π[97;5:1u'));
      expect(parser.hasEvents, true);
      expect(
        parser.nextEvent(),
        equals(const KeyEvent(KeyCode.char('a'), modifiers: KeyModifiers(KeyModifiers.ctrl))),
      );
    });

    test('π[100;5u', () {
      final parser = Parser()..advance(keySequence('π[100;5u'));
      expect(parser.hasEvents, true);
      expect(
        parser.nextEvent(),
        equals(const KeyEvent(KeyCode.char('d'), modifiers: KeyModifiers(KeyModifiers.ctrl))),
      );
    });

    test('.[97;1:2u', () {
      final parser = Parser()..advance(keySequence('π[97;1:2u'));
      expect(parser.hasEvents, true);
      expect(
        parser.nextEvent(),
        equals(const KeyEvent(KeyCode.char('a'), eventType: KeyEventType.keyRepeat)),
      );
    });

    test('.[97;1:3u', () {
      final parser = Parser()..advance(keySequence('π[97;1:3u'));
      expect(parser.hasEvents, true);
      expect(
        parser.nextEvent(),
        equals(const KeyEvent(KeyCode.char('a'), eventType: KeyEventType.keyRelease)),
      );
    });

    test('.[57449u', () {
      final parser = Parser()..advance(keySequence('π[57449u'));
      expect(parser.hasEvents, true);
      expect(
        parser.nextEvent(),
        equals(
          const KeyEvent(
            KeyCode.modifier(ModifierKey.rightAlt),
            modifiers: KeyModifiers(KeyModifiers.alt),
          ),
        ),
      );
    });

    test('.[57449;3:3u', () {
      final parser = Parser()..advance(keySequence('π[57449;3:3u'));
      expect(parser.hasEvents, true);
      expect(
        parser.nextEvent(),
        equals(
          const KeyEvent(
            KeyCode.modifier(ModifierKey.rightAlt),
            modifiers: KeyModifiers(KeyModifiers.alt),
            eventType: KeyEventType.keyRelease,
          ),
        ),
      );
    });

    test('.[57448;16:2u', () {
      final parser = Parser()..advance(keySequence('π[57448;16:2u'));
      expect(parser.hasEvents, true);
      expect(
        parser.nextEvent(),
        equals(
          const KeyEvent(
            KeyCode.modifier(ModifierKey.rightCtrl),
            modifiers: KeyModifiers(KeyModifiers.shift | KeyModifiers.alt | KeyModifiers.ctrl | KeyModifiers.superKey),
            eventType: KeyEventType.keyRepeat,
          ),
        ),
      );
    });

    test('.[57450u', () {
      final parser = Parser()..advance(keySequence('π[57450u'));
      expect(parser.hasEvents, true);
      expect(
        parser.nextEvent(),
        equals(
          const KeyEvent(
            KeyCode.modifier(ModifierKey.rightSuper),
            modifiers: KeyModifiers(KeyModifiers.superKey),
          ),
        ),
      );
    });

    test('.[57451u', () {
      final parser = Parser()..advance(keySequence('π[57451u'));
      expect(parser.hasEvents, true);
      expect(
        parser.nextEvent(),
        equals(
          const KeyEvent(
            KeyCode.modifier(ModifierKey.rightHyper),
            modifiers: KeyModifiers(KeyModifiers.hyper),
          ),
        ),
      );
    });

    test('.[97;65u', () {
      final parser = Parser()..advance(keySequence('π[97;65u'));
      expect(parser.hasEvents, true);
      expect(
        parser.nextEvent(),
        equals(KeyEvent(const KeyCode.char('a'), eventState: KeyEventState.capsLock())),
      );
    });

    test('.[49;129u', () {
      final parser = Parser()..advance(keySequence('π[49;129u'));
      expect(parser.hasEvents, true);
      expect(
        parser.nextEvent(),
        equals(KeyEvent(const KeyCode.char('1'), eventState: KeyEventState.numLock())),
      );
    });

    test('.[57:40;4u', () {
      final parser = Parser()..advance(keySequence('π[57:40;4u'));
      expect(parser.hasEvents, true);
      expect(
        parser.nextEvent(),
        equals(const KeyEvent(KeyCode.char('('), modifiers: KeyModifiers(KeyModifiers.alt | KeyModifiers.shift))),
      );
    });

    test('.[127u', () {
      final parser = Parser()..advance(keySequence('π[127u'));
      expect(parser.hasEvents, true);
      expect(
        parser.nextEvent(),
        equals(const KeyEvent(KeyCode.named(KeyCodeName.backSpace))),
      );
    });

    test('.[127;1:3u', () {
      final parser = Parser()..advance(keySequence('π[127;1:3u'));
      expect(parser.hasEvents, true);
      expect(
        parser.nextEvent(),
        equals(const KeyEvent(KeyCode.named(KeyCodeName.backSpace), eventType: KeyEventType.keyRelease)),
      );
    });

    test('.[127::8;2u', () {
      final parser = Parser()..advance(keySequence('π[127::8;2u'));
      expect(parser.hasEvents, true);
      expect(
        parser.nextEvent(),
        equals(
          const KeyEvent(
            KeyCode.named(KeyCodeName.backSpace, baseLayoutKey: 8),
            modifiers: KeyModifiers(KeyModifiers.shift),
          ),
        ),
      );
    });

    test('.[;1:3B', () {
      final parser = Parser()..advance(keySequence('π[;1:3B'));
      expect(parser.hasEvents, true);
      expect(
        parser.nextEvent(),
        equals(const KeyEvent(KeyCode.named(KeyCodeName.down), eventType: KeyEventType.keyRelease)),
      );
    });

    test('.[1;1:3B', () {
      final parser = Parser()..advance(keySequence('π[1;1:3B'));
      expect(parser.hasEvents, true);
      expect(
        parser.nextEvent(),
        equals(const KeyEvent(KeyCode.named(KeyCodeName.down), eventType: KeyEventType.keyRelease)),
      );
    });

    test('.[27;9u', () {
      final parser = Parser()..advance(keySequence('π[27;9u'));
      expect(parser.hasEvents, true);
      expect(
        parser.nextEvent(),
        equals(const KeyEvent(KeyCode.named(KeyCodeName.escape), modifiers: KeyModifiers(KeyModifiers.superKey))),
      );
    });

    test('.[?65;4;6;18;22c', () {
      final parser = Parser()..advance(keySequence('π[?65;4;6;18;22c'));
      expect(parser.hasEvents, true);
      expect(
        parser.nextEvent(),
        equals(
          const PrimaryDeviceAttributesEvent(DeviceAttributeType.vt500, [
            DeviceAttributeParams.sixelGraphics,
            DeviceAttributeParams.selectiveErase,
            DeviceAttributeParams.userWindows,
            DeviceAttributeParams.ansiColor,
          ]),
        ),
      );
    });

    test('π[10;20R', () {
      final parser = Parser()..advance(keySequence('π[10;20R'));
      expect(parser.hasEvents, true);
      expect(
        parser.nextEvent(),
        equals(const CursorPositionEvent(10, 20)),
      );
    });

    test(r'π[?2026;2$y', () {
      final parser = Parser()..advance(keySequence(r'π[?2026;2$y'));
      expect(parser.hasEvents, true);
      expect(
        parser.nextEvent(),
        equals(QuerySyncUpdateEvent(2)),
      );
    });
  });

  group('CSI ~ >', () {
    test('π[3~', () {
      final parser = Parser()..advance(keySequence('π[3~'));
      expect(parser.hasEvents, true);
      expect(
        parser.nextEvent(),
        equals(const KeyEvent(KeyCode.named(KeyCodeName.delete))),
      );
    });

    test('π[5;1:3~', () {
      final parser = Parser()..advance(keySequence('π[5;1:3~'));
      expect(parser.hasEvents, true);
      expect(
        parser.nextEvent(),
        equals(const KeyEvent(KeyCode.named(KeyCodeName.pageUp), eventType: KeyEventType.keyRelease)),
      );
    });

    test('π[6;5:3~', () {
      final parser = Parser()..advance(keySequence('π[6;5:3~'));
      expect(parser.hasEvents, true);
      expect(
        parser.nextEvent(),
        equals(
          const KeyEvent(
            KeyCode.named(KeyCodeName.pageDown),
            modifiers: KeyModifiers(KeyModifiers.ctrl),
            eventType: KeyEventType.keyRelease,
          ),
        ),
      );
    });
  });

  group('parse OSC', () {
    test('11 - 2 chars', () {
      final parser = Parser()..advance(keySequence(r'π]11;rgb:ff/ff/ffπ\\'));
      expect(parser.hasEvents, true);
      expect(
        parser.nextEvent(),
        equals(const ColorQueryEvent(255, 255, 255)),
      );
    });

    test('11 - 4 chars', () {
      final parser = Parser()..advance(keySequence(r'π]11;rgb:abff/bcff/cdffπ\\'));
      expect(parser.hasEvents, true);
      expect(
        parser.nextEvent(),
        equals(const ColorQueryEvent(171, 188, 205)), // ab/bc/cd
      );
    });

    test('52 - clipboard query', () {
      final parser = Parser()..advance(keySequence(r'π]52;c;SG9sYQ==π\\'));
      expect(parser.hasEvents, true);
      expect(
        parser.nextEvent(),
        equals(const ClipboardCopyEvent(ClipboardSource.clipboard, 'Hola')),
      );
    });

    test('52 - clipboard query empty', () {
      final parser = Parser()..advance(keySequence(r'π]52;c;π\\'));
      expect(parser.hasEvents, true);
      expect(
        parser.nextEvent(),
        equals(const ClipboardCopyEvent(ClipboardSource.clipboard, '')),
      );
    });
  });

  group('bracketed paste >', () {
    test('test paste', () {
      final parser = Parser()..advance(keySequence('π[200~where is Carmen San Diego Ž🩷 π[201~'));
      expect(parser.hasEvents, true);
      expect(
        parser.nextEvent(),
        equals(const PasteEvent('where is Carmen San Diego Ž🩷 ')),
      );
    });

    test('without finish mark', () {
      final parser = Parser()..advance(keySequence('π[200~o'));
      expect(parser.hasEvents, false);
    });

    test('with escape code without finish mark', () {
      final parser = Parser()..advance(keySequence('π[200~oπ[2j'));
      expect(parser.hasEvents, false);
    });

    test('with escape codes', () {
      final parser = Parser()..advance(keySequence('π[200~oπ[2Dπ[201~'));
      expect(parser.hasEvents, true);
      final event = parser.nextEvent();
      expect(event, isA<PasteEvent>());
      // Verify embedded ANSI sequence is preserved as literal characters
      expect((event! as PasteEvent).text, equals('o\x1b[2D'));
    });

    test('large paste without truncation', () {
      const largeContent = '''
void main() {
\t// Test function with UTF-8: 🎨 ✓ café
\tprint("Hello\\nWorld");
\tfor (var i = 0; i < 10; i++) {
\t\tif (i % 2 == 0) continue;
\t}
}''';
      final sequence = keySequence('π[200~$largeContentπ[201~');
      final parser = Parser()..advance(sequence);
      expect(parser.hasEvents, true);
      final event = parser.nextEvent()! as PasteEvent;
      expect(event.text.length, greaterThan(30));
      expect(event.text, equals(largeContent));
    });

    test('UTF-8 multibyte chars in paste', () {
      final parser = Parser()..advance(keySequence('π[200~añc🩷π[201~'));
      expect(parser.hasEvents, true);
      final event = parser.nextEvent()! as PasteEvent;
      expect(event.text, equals('añc🩷'));
    });

    test('paste with multiple lines', () {
      // Paste content containing newlines
      final parser = Parser()..advance(keySequence('π[200~line1\nline2\rline3π[201~'));
      expect(parser.hasEvents, true);
      final event = parser.nextEvent()! as PasteEvent;
      expect(event.text, equals('line1\nline2\rline3'));
    });
  });

  group('parse DCS', () {
    test('text block', () {
      const longName = 'Very Long Terminal Name That Exceeds Thirty Characters v1.2.3-build456';
      final parser = Parser()..advance(keySequence('πP>|$longNameπ\\\\'));
      expect(parser.hasEvents, true);
      final event = parser.nextEvent()! as NameAndVersionEvent;
      expect(event.value, equals(longName));
    });
  });
}
