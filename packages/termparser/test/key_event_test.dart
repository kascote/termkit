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
        baseLayoutKey: 65,
      );

      expect(updated.kind, KeyCodeKind.named);
      expect(updated.name, KeyCodeName.enter);
      expect(updated.char, 'b');
      expect(updated.baseLayoutKey, 65);
    });
  });

  group('KeyModifiers >', () {
    test('debugInfo', () {
      final mods = KeyModifiers.shift | KeyModifiers.ctrl;
      final str = mods.debugInfo();
      expect(str, contains('KeyModifiers'));
      expect(str, contains('shift'));
      expect(str, contains('ctrl'));
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
      );
      final updated = event.copyWith(
        modifiers: KeyModifiers.shift,
      );

      expect(updated.modifiers, KeyModifiers.shift);
    });
  });

  group('ModifierKey helpers >', () {
    test('leftHyper and rightHyper', () {
      const event1 = KeyEvent(
        KeyCode.char('a'),
        modifiers: KeyModifiers.hyper,
      );

      const event2 = KeyEvent(
        KeyCode.char('a'),
        modifiers: KeyModifiers.hyper,
      );

      expect(event1.modifiers.value, KeyModifiers.hyper);
      expect(event2.modifiers.value, KeyModifiers.hyper);
      expect(event1, equals(event2));
    });

    test('leftMeta and rightMeta', () {
      const event1 = KeyEvent(
        KeyCode.char('a'),
        modifiers: KeyModifiers.meta,
      );

      const event2 = KeyEvent(
        KeyCode.char('a'),
        modifiers: KeyModifiers.meta,
      );

      expect(event1.modifiers.value, KeyModifiers.meta);
      expect(event2.modifiers.value, KeyModifiers.meta);
      expect(event1, equals(event2));
    });

    test('none modifier key', () {
      const event = KeyEvent(
        KeyCode.char('a'),
      );

      expect(event.modifiers.value, KeyModifiers.none);
    });
  });
}
