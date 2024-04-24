import 'dart:convert';

import 'package:termparser/src/engine.dart';
import 'package:termparser/termparser.dart';
import 'package:termparser/termparser_events.dart';
import 'package:test/test.dart';

List<int> keySequence(String seq) {
  final buffer = seq.replaceAll('π', '\x1b');
  return utf8.encode(buffer);
}

void main() {
  group('Parser >', () {
    test('char', () {
      final parser = Parser()..advance([0x61]);
      expect(parser.moveNext(), true);
    });

    test('Ž', () {
      final parser = Parser()..advance(keySequence('Ž'));
      expect(parser.moveNext(), true);
      expect(parser.current, equals(const KeyEvent(KeyCode(char: 'Ž'))));
    });

    test('esc sequence', () {
      final parser = Parser()..advance([0x1B], more: true);
      expect(parser.moveNext(), false);
      parser.advance([0x61]);
      expect(parser.moveNext(), true);
    });

    test('esc sequence with uppercase O', () {
      final parser = Parser()..advance([0x1B], more: true);
      expect(parser.moveNext(), false);
      parser.advance([0x4F]);
      expect(parser.moveNext(), false);
    });

    test('esc sequence with uppercase O followed by a char', () {
      final parser = Parser()..advance([0x1B], more: true);
      expect(parser.moveNext(), false);
      parser.advance([0x4F], more: true); // O
      expect(parser.moveNext(), false);
      parser.advance([0x50]); // P
      expect(parser.moveNext(), true);
      expect(parser.moveNext(), false);
    });

    test('πOR', () {
      final parser = Parser()..advance(keySequence('πOR'));
      expect(parser.moveNext(), true);
      expect(
        parser.current,
        equals(const KeyEvent(KeyCode(name: KeyCodeName.f3))),
      );
    });

    test('πc', () {
      final parser = Parser()..advance(keySequence('πc'));
      expect(parser.moveNext(), true);
      expect(
        parser.current,
        equals(const KeyEvent(KeyCode(char: 'c'), modifiers: KeyModifiers(KeyModifiers.alt))),
      );
    });

    test('πH', () {
      final parser = Parser()..advance(keySequence('πH'));
      expect(parser.moveNext(), true);
      expect(
        parser.current,
        equals(
          const KeyEvent(
            KeyCode(char: 'H'), // must have shift included? is an uppercase
            modifiers: KeyModifiers(KeyModifiers.alt),
          ),
        ),
      );
    });

    test('tab / ctrl-i', () {
      final parser = Parser()..advance([0x09]);
      expect(parser.moveNext(), true);
      expect(
        parser.current,
        equals(const KeyEvent(KeyCode(name: KeyCodeName.tab))),
      );
    });

    test('ctrl-h', () {
      final parser = Parser()..advance([0x08]);
      expect(parser.moveNext(), true);
      expect(
        parser.current,
        equals(const KeyEvent(KeyCode(char: 'h'), modifiers: KeyModifiers(KeyModifiers.ctrl))),
      );
    });
  });

  group('CSI > ', () {
    test('sequence', () {
      final parser = Parser()..advance([0x1B], more: true);
      expect(parser.moveNext(), false);
      parser.advance([0x5B], more: true); // [
      expect(parser.moveNext(), false);
      parser.advance([0x44]); // D
      expect(parser.moveNext(), true);
    });

    test('ESC [1;3:2H', () {
      final parser = Parser()..advance([0x1B, 0x5B, 0x31, 0x3b, 0x32, 0x3a, 0x33, 0x48]);
      expect(parser.moveNext(), true);
      expect(
        parser.current,
        const KeyEvent(
          KeyCode(name: KeyCodeName.home),
          modifiers: KeyModifiers(KeyModifiers.shift),
          eventType: KeyEventType.keyRelease,
        ),
      );
    });

    test('ESC [H', () {
      final parser = Parser()..advance([0x1B, 0x5B, 0x48]);
      expect(parser.moveNext(), true);
      expect(
        parser.current,
        const KeyEvent(KeyCode(name: KeyCodeName.home)),
      );
    });

    test('ESC [< 35 ; 86 ; 18 M', () {
      final parser = Parser()..advance(keySequence('π[<35;86;18M'));
      expect(parser.moveNext(), true);
      expect(
        parser.current,
        MouseEvent(86, 18, MouseButton.moved(MouseButtonKind.none)),
      );
    });

    test('ESC [< 32 ; 86 ; 18 M (drag)', () {
      final parser = Parser()..advance(keySequence('π[<32;86;18M'));
      expect(parser.moveNext(), true);
      expect(
        parser.current,
        MouseEvent(86, 18, MouseButton.moved(MouseButtonKind.left)),
      );
    });

    test('ESC [< 24 ; 86 ; 18 M', () {
      final parser = Parser()..advance(keySequence('π[<24;86;18M'));
      expect(parser.moveNext(), true);
      expect(
        parser.current,
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
      expect(parser.moveNext(), true);
      expect(
        parser.current,
        MouseEvent(20, 10, MouseButton.up(MouseButtonKind.left)),
      );
    });

    test('π[<0;20;10m', () {
      final parser = Parser()..advance(keySequence('π[<0;20;10m'));
      expect(parser.moveNext(), true);
      expect(
        parser.current,
        MouseEvent(20, 10, MouseButton.up(MouseButtonKind.left)),
      );
    });

    test('π[<53;20;10m', () {
      final parser = Parser()..advance(keySequence('π[<51;20;10m'));
      expect(parser.moveNext(), true);
      expect(
        parser.current,
        MouseEvent(20, 10, MouseButton.moved(), modifiers: const KeyModifiers(KeyModifiers.ctrl)),
      );
    });

    test('ESC [I', () {
      final parser = Parser()..advance(keySequence('π[I'));
      expect(parser.moveNext(), true);
      expect(parser.current, const FocusEvent());
    });

    test('ESC [O', () {
      final parser = Parser()..advance(keySequence('π[O'));
      expect(parser.moveNext(), true);
      expect(parser.current, const FocusEvent(hasFocus: false));
    });

    test('ESC [ ? 1 u', () {
      final parser = Parser()..advance(keySequence('π[?1u'));
      expect(parser.moveNext(), true);
      expect(
        parser.current,
        equals(const KeyboardEnhancementFlagsEvent(KeyboardEnhancementFlagsEvent.disambiguateEscapeCodes)),
      );
    });

    test('ESC [ 97 u', () {
      final parser = Parser()..advance(keySequence('π[97u'));
      expect(parser.moveNext(), true);
      expect(parser.current, equals(const KeyEvent(KeyCode(char: 'a'))));
    });

    test('ESC [ 97 : 65 ; 2 u', () {
      final parser = Parser()..advance(keySequence('π[97:65;2u'));
      expect(parser.moveNext(), true);
      expect(
        parser.current,
        equals(const KeyEvent(KeyCode(char: 'A'), modifiers: KeyModifiers(KeyModifiers.shift))),
      );
    });

    test('.[97;7u', () {
      final parser = Parser()..advance(keySequence('π[97;7u'));
      expect(parser.moveNext(), true);
      expect(
        parser.current,
        equals(const KeyEvent(KeyCode(char: 'a'), modifiers: KeyModifiers(KeyModifiers.ctrl | KeyModifiers.alt))),
      );
    });

    test('.[13u', () {
      final parser = Parser()..advance(keySequence('π[13u'));
      expect(parser.moveNext(), true);
      expect(
        parser.current,
        equals(const KeyEvent(KeyCode(name: KeyCodeName.enter))),
      );
    });

    test('.[27u', () {
      final parser = Parser()..advance(keySequence('π[27u'));
      expect(parser.moveNext(), true);
      expect(
        parser.current,
        equals(const KeyEvent(KeyCode(name: KeyCodeName.escape))),
      );
    });

    test('.[57358u', () {
      final parser = Parser()..advance(keySequence('π[57358u'));
      expect(parser.moveNext(), true);
      expect(
        parser.current,
        equals(const KeyEvent(KeyCode(name: KeyCodeName.capsLock))),
      );
    });

    test('.[57376u', () {
      final parser = Parser()..advance(keySequence('π[57376u'));
      expect(parser.moveNext(), true);
      expect(
        parser.current,
        equals(const KeyEvent(KeyCode(name: KeyCodeName.f13))),
      );
    });

    test('.[57428u', () {
      final parser = Parser()..advance(keySequence('π[57428u'));
      expect(parser.moveNext(), true);
      expect(
        parser.current,
        equals(const KeyEvent(KeyCode(media: MediaKeyCode.play))),
      );
    });

    test('.[57441u', () {
      final parser = Parser()..advance(keySequence('π[57441u'));
      expect(parser.moveNext(), true);
      expect(
        parser.current,
        equals(
          const KeyEvent(
            KeyCode(modifiers: ModifierKeyCode.leftShift),
            modifiers: KeyModifiers(KeyModifiers.shift),
          ),
        ),
      );
    });

    test('.[57399u', () {
      final parser = Parser()..advance(keySequence('π[57399u'));
      expect(parser.moveNext(), true);
      expect(
        parser.current,
        equals(KeyEvent(const KeyCode(char: '0'), eventState: KeyEventState.keypad())),
      );
    });

    test('.[57419u', () {
      final parser = Parser()..advance(keySequence('π[57419u'));
      expect(parser.moveNext(), true);
      expect(
        parser.current,
        equals(KeyEvent(const KeyCode(name: KeyCodeName.up), eventState: KeyEventState.keypad())),
      );
    });

    test('.[97;1u', () {
      final parser = Parser()..advance(keySequence('π[97;1u'));
      expect(parser.moveNext(), true);
      expect(
        parser.current,
        equals(const KeyEvent(KeyCode(char: 'a'))),
      );
    });

    test('.[97;1:1u', () {
      final parser = Parser()..advance(keySequence('π[97;1:1u'));
      expect(parser.moveNext(), true);
      expect(
        parser.current,
        equals(const KeyEvent(KeyCode(char: 'a'))),
      );
    });

    test('.[97;5:1u', () {
      final parser = Parser()..advance(keySequence('π[97;5:1u'));
      expect(parser.moveNext(), true);
      expect(
        parser.current,
        equals(const KeyEvent(KeyCode(char: 'a'), modifiers: KeyModifiers(KeyModifiers.ctrl))),
      );
    });

    test('π[100;5u', () {
      final parser = Parser()..advance(keySequence('π[100;5u'));
      expect(parser.moveNext(), true);
      expect(
        parser.current,
        equals(const KeyEvent(KeyCode(char: 'd'), modifiers: KeyModifiers(KeyModifiers.ctrl))),
      );
    });

    test('.[97;1:2u', () {
      final parser = Parser()..advance(keySequence('π[97;1:2u'));
      expect(parser.moveNext(), true);
      expect(
        parser.current,
        equals(const KeyEvent(KeyCode(char: 'a'), eventType: KeyEventType.keyRepeat)),
      );
    });

    test('.[97;1:3u', () {
      final parser = Parser()..advance(keySequence('π[97;1:3u'));
      expect(parser.moveNext(), true);
      expect(
        parser.current,
        equals(const KeyEvent(KeyCode(char: 'a'), eventType: KeyEventType.keyRelease)),
      );
    });

    test('.[57449u', () {
      final parser = Parser()..advance(keySequence('π[57449u'));
      expect(parser.moveNext(), true);
      expect(
        parser.current,
        equals(
          const KeyEvent(
            KeyCode(modifiers: ModifierKeyCode.rightAlt),
            modifiers: KeyModifiers(KeyModifiers.alt),
          ),
        ),
      );
    });

    test('.[57449;3:3u', () {
      final parser = Parser()..advance(keySequence('π[57449;3:3u'));
      expect(parser.moveNext(), true);
      expect(
        parser.current,
        equals(
          const KeyEvent(
            KeyCode(modifiers: ModifierKeyCode.rightAlt),
            modifiers: KeyModifiers(KeyModifiers.alt),
            eventType: KeyEventType.keyRelease,
          ),
        ),
      );
    });

    test('.[57448;16:2u', () {
      final parser = Parser()..advance(keySequence('π[57448;16:2u'));
      expect(parser.moveNext(), true);
      expect(
        parser.current,
        equals(
          const KeyEvent(
            KeyCode(modifiers: ModifierKeyCode.rightControl),
            modifiers: KeyModifiers(KeyModifiers.shift | KeyModifiers.alt | KeyModifiers.ctrl | KeyModifiers.superKey),
            eventType: KeyEventType.keyRepeat,
          ),
        ),
      );
    });

    test('.[57450u', () {
      final parser = Parser()..advance(keySequence('π[57450u'));
      expect(parser.moveNext(), true);
      expect(
        parser.current,
        equals(
          const KeyEvent(
            KeyCode(modifiers: ModifierKeyCode.rightSuper),
            modifiers: KeyModifiers(KeyModifiers.superKey),
          ),
        ),
      );
    });

    test('.[57451u', () {
      final parser = Parser()..advance(keySequence('π[57451u'));
      expect(parser.moveNext(), true);
      expect(
        parser.current,
        equals(
          const KeyEvent(
            KeyCode(modifiers: ModifierKeyCode.rightHyper),
            modifiers: KeyModifiers(KeyModifiers.hyper),
          ),
        ),
      );
    });

    test('.[97;65u', () {
      final parser = Parser()..advance(keySequence('π[97;65u'));
      expect(parser.moveNext(), true);
      expect(
        parser.current,
        equals(KeyEvent(const KeyCode(char: 'a'), eventState: KeyEventState.capsLock())),
      );
    });

    test('.[49;129u', () {
      final parser = Parser()..advance(keySequence('π[49;129u'));
      expect(parser.moveNext(), true);
      expect(
        parser.current,
        equals(KeyEvent(const KeyCode(char: '1'), eventState: KeyEventState.numLock())),
      );
    });

    test('.[57:40;4u', () {
      final parser = Parser()..advance(keySequence('π[57:40;4u'));
      expect(parser.moveNext(), true);
      expect(
        parser.current,
        equals(const KeyEvent(KeyCode(char: '('), modifiers: KeyModifiers(KeyModifiers.alt | KeyModifiers.shift))),
      );
    });

    test('.[127u', () {
      final parser = Parser()..advance(keySequence('π[127u'));
      expect(parser.moveNext(), true);
      expect(
        parser.current,
        equals(const KeyEvent(KeyCode(name: KeyCodeName.backSpace))),
      );
    });

    test('.[127;1:3u', () {
      final parser = Parser()..advance(keySequence('π[127;1:3u'));
      expect(parser.moveNext(), true);
      expect(
        parser.current,
        equals(const KeyEvent(KeyCode(name: KeyCodeName.backSpace), eventType: KeyEventType.keyRelease)),
      );
    });

    test('.[127::8;2u', () {
      final parser = Parser()..advance(keySequence('π[127::8;2u'));
      expect(parser.moveNext(), true);
      expect(
        parser.current,
        equals(
          const KeyEvent(
            KeyCode(name: KeyCodeName.backSpace, baseLayoutKey: 8),
            modifiers: KeyModifiers(KeyModifiers.shift),
          ),
        ),
      );
    });

    test('.[;1:3B', () {
      final parser = Parser()..advance(keySequence('π[;1:3B'));
      expect(parser.moveNext(), true);
      expect(
        parser.current,
        equals(const KeyEvent(KeyCode(name: KeyCodeName.down), eventType: KeyEventType.keyRelease)),
      );
    });

    test('.[1;1:3B', () {
      final parser = Parser()..advance(keySequence('π[1;1:3B'));
      expect(parser.moveNext(), true);
      expect(
        parser.current,
        equals(const KeyEvent(KeyCode(name: KeyCodeName.down), eventType: KeyEventType.keyRelease)),
      );
    });

    test('.[27;9u', () {
      final parser = Parser()..advance(keySequence('π[27;9u'));
      expect(parser.moveNext(), true);
      expect(
        parser.current,
        equals(const KeyEvent(KeyCode(name: KeyCodeName.escape), modifiers: KeyModifiers(KeyModifiers.superKey))),
      );
    });

    test('.[?65;4;6;18;22c', () {
      final parser = Parser()..advance(keySequence('π[?65;4;6;18;22c'));
      expect(parser.moveNext(), true);
      expect(
        parser.current,
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
      expect(parser.moveNext(), true);
      expect(
        parser.current,
        equals(const CursorPositionEvent(10, 20)),
      );
    });

    test(r'π[?2026;2$y', () {
      final parser = Parser()..advance(keySequence(r'π[?2026;2$y'));
      expect(parser.moveNext(), true);
      expect(
        parser.current,
        equals(const QuerySyncUpdateEvent(SyncUpdateStatus.disabled)),
      );
    });
  });

  group('CSI ~ >', () {
    test('π[3~', () {
      final parser = Parser()..advance(keySequence('π[3~'));
      expect(parser.moveNext(), true);
      expect(
        parser.current,
        equals(const KeyEvent(KeyCode(name: KeyCodeName.delete))),
      );
    });

    test('π[5;1:3~', () {
      final parser = Parser()..advance(keySequence('π[5;1:3~'));
      expect(parser.moveNext(), true);
      expect(
        parser.current,
        equals(const KeyEvent(KeyCode(name: KeyCodeName.pageUp), eventType: KeyEventType.keyRelease)),
      );
    });

    test('π[6;5:3~', () {
      final parser = Parser()..advance(keySequence('π[6;5:3~'));
      expect(parser.moveNext(), true);
      expect(
        parser.current,
        equals(
          const KeyEvent(
            KeyCode(name: KeyCodeName.pageDown),
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
      expect(parser.moveNext(), true);
      expect(
        parser.current,
        equals(const ColorQueryEvent(255, 255, 255)),
      );
    });

    test('11 - 4 chars', () {
      final parser = Parser()..advance(keySequence(r'π]11;rgb:abff/bcff/cdffπ\\'));
      expect(parser.moveNext(), true);
      expect(
        parser.current,
        equals(const ColorQueryEvent(171, 188, 205)), // ab/bc/cd
      );
    });
  });

  group('bracketed paste >', () {
    test('test paste', () {
      final parser = Parser()..advance(keySequence('π[200~where is Carmen San Diego Ž🩷 π[201~'));
      expect(parser.moveNext(), true);
      expect(
        parser.current,
        equals(const PasteEvent('where is Carmen San Diego Ž🩷 ')),
      );
    });

    test('without finish mark', () {
      final parser = Parser()..advance(keySequence('π[200~o'));
      expect(parser.moveNext(), false);
    });

    test('with escape code without finish mark', () {
      final parser = Parser()..advance(keySequence('π[200~oπ[2j'));
      expect(parser.moveNext(), false);
    });

    test('with escape codes', () {
      final parser = Parser()..advance(keySequence('π[200~oπ[2Dπ[201~'));
      expect(parser.moveNext(), true);
      expect(parser.current, isA<NoneEvent>());
    });
  });

  group('parse DCS', () {
    test('text block', () {
      final parser = Parser()..advance(keySequence(r'πP>|term v1-234π\\'));
      expect(parser.moveNext(), true);
      expect(parser.current, equals(const NameAndVersionEvent('term v1-234')));
    });
  });

  group('special cases?', () {
    test('<C-j> is mapped to <enter>', () {
      final parser = Parser()..advance([0x0a]);
      expect(parser.moveNext(), true);
      expect(parser.current, const KeyEvent(KeyCode(name: KeyCodeName.enter)));
    });

    test('<C-j> is mapped to <C-j>', () {
      rawModeReturnQuirk = true;
      final parser = Parser()..advance([0x0a]);
      expect(parser.moveNext(), true);
      expect(parser.current, const KeyEvent(KeyCode(char: 'j'), modifiers: KeyModifiers(KeyModifiers.ctrl)));
    });

    test('<C-?> is mapped to <C-7> by default (why?)', () {
      final parser = Parser()..advance([0x1f]);
      expect(parser.moveNext(), true);
      expect(
        parser.current,
        const KeyEvent(KeyCode(char: '7'), modifiers: KeyModifiers(KeyModifiers.ctrl)),
      );
    });

    test('<C-?> is mapped properly with quirk active', () {
      ctrlQuestionMarkQuirk = true;
      final parser = Parser()..advance([0x1f]);
      expect(parser.moveNext(), true);
      expect(
        parser.current,
        const KeyEvent(KeyCode(char: '?'), modifiers: KeyModifiers(KeyModifiers.ctrl)),
      );
    });

    tearDown(() {
      rawModeReturnQuirk = false;
      ctrlQuestionMarkQuirk = false;
    });
  });
}
