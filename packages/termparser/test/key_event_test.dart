import 'package:termparser/termparser_events.dart';
import 'package:test/test.dart';

void main() {
  group('KeyCode >', () {
    test('toString', () {
      const code = KeyCode.char('a');
      final str = code.toString();
      expect(str, contains('KeyCode'));
      expect(str, contains('char'));
    });

    test('copyWith - all parameters', () {
      const code = KeyCode.char('a');
      final updated = code.copyWith(
        kind: KeyCodeKind.named,
        name: KeyCodeName.enter,
        char: 'b',
        media: MediaKeyCode.play,
        modifierKey: ModifierKey.leftShift,
        baseLayoutKey: 65,
      );

      expect(updated.kind, KeyCodeKind.named);
      expect(updated.name, KeyCodeName.enter);
      expect(updated.char, 'b');
      expect(updated.media, MediaKeyCode.play);
      expect(updated.modifierKey, ModifierKey.leftShift);
      expect(updated.baseLayoutKey, 65);
    });
  });

  group('KeyModifiers >', () {
    test('toString', () {
      const mods = KeyModifiers(KeyModifiers.shift | KeyModifiers.ctrl);
      final str = mods.toString();
      expect(str, contains('KeyModifiers'));
      expect(str, contains('shift'));
      expect(str, contains('ctrl'));
    });
  });

  group('KeyEventState >', () {
    test('isKeypad getter', () {
      final state = KeyEventState.keypad();
      expect(state.isKeypad, isTrue);
      expect(state.isCapsLock, isFalse);
      expect(state.isNumLock, isFalse);
    });

    test('isCapsLock getter', () {
      final state = KeyEventState.capsLock();
      expect(state.isKeypad, isFalse);
      expect(state.isCapsLock, isTrue);
      expect(state.isNumLock, isFalse);
    });

    test('isNumLock getter', () {
      final state = KeyEventState.numLock();
      expect(state.isKeypad, isFalse);
      expect(state.isCapsLock, isFalse);
      expect(state.isNumLock, isTrue);
    });

    test('toString with none', () {
      final state = KeyEventState.none();
      final str = state.toString();
      expect(str, contains('KeyEventState'));
      expect(str, contains('none'));
    });

    test('toString with states', () {
      final state = KeyEventState.keypad();
      final str = state.toString();
      expect(str, contains('KeyEventState'));
      expect(str, contains('isKeypad'));
    });
  });

  group('KeyEvent >', () {
    test('toString', () {
      const event = KeyEvent(KeyCode.char('a'));
      final str = event.toString();
      expect(str, contains('KeyEvent'));
      expect(str, contains('code'));
    });

    test('copyWith with modifierKeys', () {
      const event = KeyEvent(
        KeyCode.char('a'),
        modifierKeys: {ModifierKey.leftShift},
      );
      final updated = event.copyWith(
        modifierKeys: const {ModifierKey.rightShift},
      );

      expect(updated.modifierKeys, contains(ModifierKey.rightShift));
      expect(updated.modifierKeys, isNot(contains(ModifierKey.leftShift)));
    });
  });

  group('ModifierKey helpers >', () {
    test('leftHyper and rightHyper', () {
      const event1 = KeyEvent(
        KeyCode.char('a'),
        modifiers: KeyModifiers(KeyModifiers.hyper),
        modifierKeys: {ModifierKey.leftHyper},
      );

      const event2 = KeyEvent(
        KeyCode.char('a'),
        modifiers: KeyModifiers(KeyModifiers.hyper),
        modifierKeys: {ModifierKey.rightHyper},
      );

      expect(event1.modifiers.value, KeyModifiers.hyper);
      expect(event2.modifiers.value, KeyModifiers.hyper);
      expect(event1, equals(event2)); // Equality ignores modifierKeys
    });

    test('leftMeta and rightMeta', () {
      const event1 = KeyEvent(
        KeyCode.char('a'),
        modifiers: KeyModifiers(KeyModifiers.meta),
        modifierKeys: {ModifierKey.leftMeta},
      );

      const event2 = KeyEvent(
        KeyCode.char('a'),
        modifiers: KeyModifiers(KeyModifiers.meta),
        modifierKeys: {ModifierKey.rightMeta},
      );

      expect(event1.modifiers.value, KeyModifiers.meta);
      expect(event2.modifiers.value, KeyModifiers.meta);
      expect(event1, equals(event2));
    });

    test('isoLevel3Shift and isoLevel5Shift', () {
      const event1 = KeyEvent(
        KeyCode.char('a'),
        modifierKeys: {ModifierKey.isoLevel3Shift},
      );

      const event2 = KeyEvent(
        KeyCode.char('a'),
        modifierKeys: {ModifierKey.isoLevel5Shift},
      );

      // These modifiers don't map to standard modifiers
      expect(event1.modifiers.value, 0);
      expect(event2.modifiers.value, 0);
    });

    test('none modifier key', () {
      const event = KeyEvent(
        KeyCode.char('a'),
        modifierKeys: {ModifierKey.none},
      );

      expect(event.modifiers.value, 0);
    });
  });
}
