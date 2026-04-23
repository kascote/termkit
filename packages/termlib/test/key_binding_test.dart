import 'package:termlib/termlib.dart';
import 'package:termparser/termparser_events.dart';
import 'package:test/test.dart';

enum _TestAction { quit, save, move, none }

void main() {
  group('KeyBinding', () {
    test('bind + resolve on single spec', () {
      final kb = KeyBinding<_TestAction>()..map(['ctrl+s'], _TestAction.save);
      final ev = KeyEvent.fromString('ctrl+s');
      expect(kb.resolve(ev), _TestAction.save);
    });

    test('alias: multiple specs map to same action', () {
      final kb = KeyBinding<_TestAction>()..map(['ctrl+q', 'escape'], _TestAction.quit);
      expect(kb.resolve(KeyEvent.fromString('ctrl+q')), _TestAction.quit);
      expect(kb.resolve(KeyEvent.fromString('escape')), _TestAction.quit);
    });

    test('unmapped key resolves to null', () {
      final kb = KeyBinding<_TestAction>()..map(['ctrl+s'], _TestAction.save);
      expect(kb.resolve(KeyEvent.fromString('ctrl+x')), isNull);
    });

    test('non-keyPress events are ignored', () {
      final kb = KeyBinding<_TestAction>()..map(['ctrl+s'], _TestAction.save);
      final press = KeyEvent.fromString('ctrl+s');
      final repeat = press.copyWith(eventType: KeyEventType.keyRepeat);
      final release = press.copyWith(eventType: KeyEventType.keyRelease);
      expect(kb.resolve(press), _TestAction.save);
      expect(kb.resolve(repeat), isNull);
      expect(kb.resolve(release), isNull);
    });

    test('invalid spec throws InvalidKeySpecException on map', () {
      final kb = KeyBinding<_TestAction>();
      expect(
        () => kb.map(['totally-not-a-key'], _TestAction.none),
        throwsA(isA<InvalidKeySpecException>()),
      );
    });

    test('isValidKey returns false for invalid, true for valid', () {
      expect(KeyBinding.isValidKey('ctrl+a'), isTrue);
      expect(KeyBinding.isValidKey('enter'), isTrue);
      expect(KeyBinding.isValidKey('not+a+real+key'), isFalse);
    });

    test('validateKey throws on invalid, returns normally on valid', () {
      expect(() => KeyBinding.validateKey('ctrl+a'), returnsNormally);
      expect(
        () => KeyBinding.validateKey('nope'),
        throwsA(isA<InvalidKeySpecException>()),
      );
    });

    test('keysFor returns all specs bound to an action', () {
      final kb = KeyBinding<_TestAction>()
        ..map(['ctrl+q', 'escape'], _TestAction.quit)
        ..map(['ctrl+s'], _TestAction.save);
      expect(kb.keysFor(_TestAction.quit), containsAll(['ctrl+q', 'escape']));
      expect(kb.keysFor(_TestAction.save), ['ctrl+s']);
      expect(kb.keysFor(_TestAction.move), isEmpty);
    });

    test('toGroupedMap inverts bindings', () {
      final kb = KeyBinding<_TestAction>()
        ..map(['ctrl+q', 'escape'], _TestAction.quit)
        ..map(['ctrl+s'], _TestAction.save);
      final grouped = kb.toGroupedMap();
      expect(grouped[_TestAction.quit], containsAll(['ctrl+q', 'escape']));
      expect(grouped[_TestAction.save], ['ctrl+s']);
      expect(grouped.containsKey(_TestAction.move), isFalse);
    });

    test('remove drops a single spec', () {
      final kb = KeyBinding<_TestAction>()
        ..map(['ctrl+q', 'escape'], _TestAction.quit)
        ..remove('escape');
      expect(kb.resolve(KeyEvent.fromString('ctrl+q')), _TestAction.quit);
      expect(kb.resolve(KeyEvent.fromString('escape')), isNull);
    });

    test('unbind drops all specs for an action', () {
      final kb = KeyBinding<_TestAction>()
        ..map(['ctrl+q', 'escape'], _TestAction.quit)
        ..map(['ctrl+s'], _TestAction.save)
        ..unbind(_TestAction.quit);
      expect(kb.resolve(KeyEvent.fromString('ctrl+q')), isNull);
      expect(kb.resolve(KeyEvent.fromString('escape')), isNull);
      expect(kb.resolve(KeyEvent.fromString('ctrl+s')), _TestAction.save);
    });

    test('clear empties all bindings', () {
      final kb = KeyBinding<_TestAction>()
        ..map(['ctrl+s'], _TestAction.save)
        ..clear();
      expect(kb.resolve(KeyEvent.fromString('ctrl+s')), isNull);
      expect(kb.toGroupedMap(), isEmpty);
    });

    test('addAll merges bindings, later overrides earlier on conflict', () {
      final base = KeyBinding<_TestAction>()..map(['ctrl+s'], _TestAction.save);
      final overlay = KeyBinding<_TestAction>()..map(['ctrl+s'], _TestAction.move);
      base.addAll(overlay);
      expect(base.resolve(KeyEvent.fromString('ctrl+s')), _TestAction.move);
    });

    test('copy produces independent binding', () {
      final original = KeyBinding<_TestAction>()..map(['ctrl+s'], _TestAction.save);
      final dup = original.copy()..map(['ctrl+s'], _TestAction.move);
      expect(original.resolve(KeyEvent.fromString('ctrl+s')), _TestAction.save);
      expect(dup.resolve(KeyEvent.fromString('ctrl+s')), _TestAction.move);
    });

    test('map silently overrides existing binding', () {
      final kb = KeyBinding<_TestAction>()
        ..map(['ctrl+s'], _TestAction.save)
        ..map(['ctrl+s'], _TestAction.move);
      expect(kb.resolve(KeyEvent.fromString('ctrl+s')), _TestAction.move);
    });

    test('empty binding always returns null', () {
      final kb = KeyBinding<_TestAction>();
      expect(kb.resolve(KeyEvent.fromString('ctrl+a')), isNull);
      expect(kb.resolve(KeyEvent.fromString('enter')), isNull);
    });
  });

  group('KeyBinding — spec coverage', () {
    test('named keys: enter, escape, backSpace, delete, home, end', () {
      final kb = KeyBinding<_TestAction>()
        ..map(['enter'], _TestAction.save)
        ..map(['escape'], _TestAction.quit)
        ..map(['backSpace'], _TestAction.move)
        ..map(['delete'], _TestAction.none)
        ..map(['home', 'end'], _TestAction.move);
      expect(kb.resolve(KeyEvent.fromString('enter')), _TestAction.save);
      expect(kb.resolve(KeyEvent.fromString('escape')), _TestAction.quit);
      expect(kb.resolve(KeyEvent.fromString('backSpace')), _TestAction.move);
      expect(kb.resolve(KeyEvent.fromString('delete')), _TestAction.none);
      expect(kb.resolve(KeyEvent.fromString('home')), _TestAction.move);
      expect(kb.resolve(KeyEvent.fromString('end')), _TestAction.move);
    });

    test('arrow keys', () {
      final kb = KeyBinding<_TestAction>()..map(['left', 'right', 'up', 'down'], _TestAction.move);
      for (final spec in ['left', 'right', 'up', 'down']) {
        expect(kb.resolve(KeyEvent.fromString(spec)), _TestAction.move, reason: spec);
      }
    });

    test('function keys', () {
      final kb = KeyBinding<_TestAction>()
        ..map(['f1'], _TestAction.save)
        ..map(['ctrl+f5'], _TestAction.move);
      expect(kb.resolve(KeyEvent.fromString('f1')), _TestAction.save);
      expect(kb.resolve(KeyEvent.fromString('ctrl+f5')), _TestAction.move);
    });

    test('multi-modifier specs', () {
      final kb = KeyBinding<_TestAction>()
        ..map(['shift+ctrl+enter'], _TestAction.save)
        ..map(['alt+ctrl+x'], _TestAction.move);
      expect(kb.resolve(KeyEvent.fromString('shift+ctrl+enter')), _TestAction.save);
      expect(kb.resolve(KeyEvent.fromString('alt+ctrl+x')), _TestAction.move);
    });

    test('special char specs: space, plus, minus', () {
      final kb = KeyBinding<_TestAction>()
        ..map(['space'], _TestAction.save)
        ..map(['plus'], _TestAction.move)
        ..map(['minus'], _TestAction.none);
      expect(kb.resolve(KeyEvent.fromString('space')), _TestAction.save);
      expect(kb.resolve(KeyEvent.fromString('plus')), _TestAction.move);
      expect(kb.resolve(KeyEvent.fromString('minus')), _TestAction.none);
    });

    test('spec names are case-insensitive on parse', () {
      final kb = KeyBinding<_TestAction>()..map(['Enter', 'CTRL+a'], _TestAction.save);
      expect(kb.resolve(KeyEvent.fromString('enter')), _TestAction.save);
      expect(kb.resolve(KeyEvent.fromString('ctrl+a')), _TestAction.save);
    });

    test('resolve ignores baseLayoutKey / keyPad / capsLock on incoming event', () {
      // Key bindings use toSpec() which deliberately strips these fields.
      // This is what lets a single 'backSpace' binding match both keypad and
      // main-block variants — previously readline duplicated entries for this.
      final kb = KeyBinding<_TestAction>()..map(['backSpace'], _TestAction.move);
      const mainBlock = KeyEvent(KeyCode.named(KeyCodeName.backSpace));
      const withBaseLayout = KeyEvent(KeyCode.named(KeyCodeName.backSpace, baseLayoutKey: 8));
      expect(kb.resolve(mainBlock), _TestAction.move);
      expect(kb.resolve(withBaseLayout), _TestAction.move);
    });

    test('shift+letter spec resolves against uppercase char event', () {
      // KeyEvent.fromString('shift+a') normalizes to uppercase 'A'.
      // A raw KeyEvent for uppercase 'A' with shift modifier must match.
      final kb = KeyBinding<_TestAction>()..map(['shift+a'], _TestAction.save);
      const ev = KeyEvent(KeyCode.char('A'), modifiers: KeyModifiers.shift);
      expect(kb.resolve(ev), _TestAction.save);
    });

    test('invalid modifier spec throws InvalidKeySpecException', () {
      final kb = KeyBinding<_TestAction>();
      expect(
        () => kb.map(['bogus+a'], _TestAction.save),
        throwsA(isA<InvalidKeySpecException>()),
      );
    });

    test('InvalidKeySpecException preserves the offending key', () {
      try {
        KeyBinding.validateKey('totally-not-a-key');
        fail('expected throw');
      } on InvalidKeySpecException catch (e) {
        expect(e.key, 'totally-not-a-key');
        expect(e.toString(), contains('totally-not-a-key'));
      }
    });
  });
}
