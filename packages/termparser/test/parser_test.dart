import 'dart:convert';

import 'package:termparser/termparser.dart';
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
        MouseEvent(86, 18, MouseButtonEvent.moved(MouseButton.none)),
      );
    });

    test('ESC [< 32 ; 86 ; 18 M (drag)', () {
      final parser = Parser()..advance(keySequence('π[<32;86;18M'));
      expect(parser.moveNext(), true);
      expect(
        parser.current,
        MouseEvent(86, 18, MouseButtonEvent.moved(MouseButton.left)),
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
          MouseButtonEvent.down(MouseButton.left),
          modifiers: const KeyModifiers(KeyModifiers.ctrl | KeyModifiers.alt),
        ),
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
      expect(parser.current, equals(const KeyboardEnhancementFlags(KeyboardEnhancementFlags.disambiguateEscapeCodes)));
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
  });

  group('CSI ~ >', () {
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
}
