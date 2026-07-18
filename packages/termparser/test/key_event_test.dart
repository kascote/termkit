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

    test('text defaults to null', () {
      const event = KeyEvent(KeyCode.char('a'));
      expect(event.text, isNull);
    });

    test('copyWith with text', () {
      const event = KeyEvent(KeyCode.char('a'));
      final updated = event.copyWith(text: 'a');
      expect(updated.text, 'a');
    });

    test('equality and hashCode consider text', () {
      const withText = KeyEvent(KeyCode.char('a'), text: 'a');
      const withoutText = KeyEvent(KeyCode.char('a'));
      const sameText = KeyEvent(KeyCode.char('a'), text: 'a');

      expect(withText, isNot(equals(withoutText)));
      expect(withText, equals(sameText));
      expect(withText.hashCode, equals(sameText.hashCode));
    });

    test('toString includes text', () {
      const event = KeyEvent(KeyCode.char('a'), text: 'a');
      expect(event.toString(), contains('text: a'));
    });
  });

  group('KeyEvent.toSpec folding >', () {
    test('shifted letter folds by case when the parser knows it is produced', () {
      const event = KeyEvent(KeyCode.char('A', shiftProduced: true), modifiers: KeyModifiers.shift);
      expect(event.toSpec(), 'A');
    });

    test('shifted letter folds by case even when degraded (no alternate key)', () {
      // No shiftProduced flag here — the parser only saw the base char 'a'
      // and the shift modifier bit. Letters still fold: case is safe to
      // infer regardless of layout.
      const event = KeyEvent(KeyCode.char('a'), modifiers: KeyModifiers.shift);
      expect(event.toSpec(), 'A');
    });

    test('shifted symbol folds when the alternate key confirms the production', () {
      const event = KeyEvent(KeyCode.char('!', shiftProduced: true), modifiers: KeyModifiers.shift);
      expect(event.toSpec(), '!');
    });

    test('shifted symbol degraded keeps the explicit modifier', () {
      // Base char '1' plus a shift bit, no alternate key: the produced
      // symbol ('!' on US, something else elsewhere) is unknowable, so
      // folding would guess. The spec stays explicit.
      const event = KeyEvent(KeyCode.char('1'), modifiers: KeyModifiers.shift);
      expect(event.toSpec(), 'shift+1');
    });

    test('AZERTY-style digit production folds like any other confirmed shift', () {
      // On AZERTY, the unshifted key sends '&'; the parser substitutes the
      // shifted key '1' into char and marks it produced.
      const event = KeyEvent(KeyCode.char('1', shiftProduced: true), modifiers: KeyModifiers.shift);
      expect(event.toSpec(), '1');
    });

    test('named keys never fold shift', () {
      const event = KeyEvent(KeyCode.named(KeyCodeName.tab), modifiers: KeyModifiers.shift);
      expect(event.toSpec(), 'shift+tab');
    });
  });

  group('KeyEvent.toBaseLayoutSpec >', () {
    test('substitutes the base layout character', () {
      // Ctrl+Я on a Cyrillic layout: base layout key is 'z' (0x7A).
      const event = KeyEvent(KeyCode.char('я', baseLayoutKey: 0x7A), modifiers: KeyModifiers.ctrl);
      expect(event.toBaseLayoutSpec(), 'ctrl+z');
    });

    test('applies shift folding to the substituted character', () {
      final event = KeyEvent(
        const KeyCode.char('Я', baseLayoutKey: 0x7A),
        modifiers: KeyModifiers.ctrl | KeyModifiers.shift,
      );
      expect(event.toBaseLayoutSpec(), 'ctrl+Z');
    });

    test('returns null when no base layout key was reported', () {
      const event = KeyEvent(KeyCode.char('a'));
      expect(event.toBaseLayoutSpec(), isNull);
    });

    test('returns null for named keys', () {
      const event = KeyEvent(KeyCode.named(KeyCodeName.f1, baseLayoutKey: 0x7A));
      expect(event.toBaseLayoutSpec(), isNull);
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
