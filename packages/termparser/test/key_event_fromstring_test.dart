import 'package:termparser/src/events/key_event.dart';
import 'package:termparser/src/events/key_support.dart';
import 'package:test/test.dart';

void main() {
  group('KeyEvent.fromString', () {
    group('single characters', () {
      test('parses single lowercase char', () {
        final event = KeyEvent.fromString('a');
        expect(event.code.kind, KeyCodeKind.char);
        expect(event.code.char, 'a');
        expect(event.modifiers.value, 0);
        expect(event.eventType, KeyEventType.keyPress);
      });

      test('parses single uppercase char', () {
        final event = KeyEvent.fromString('A');
        expect(event.code.kind, KeyCodeKind.char);
        expect(event.code.char, 'A');
        expect(event.modifiers.value, 0);
        expect(event.eventType, KeyEventType.keyPress);
      });

      test('parses single digit', () {
        final event = KeyEvent.fromString('5');
        expect(event.code.kind, KeyCodeKind.char);
        expect(event.code.char, '5');
        expect(event.modifiers.value, 0);
        expect(event.eventType, KeyEventType.keyPress);
      });

      test('parses special char', () {
        final event = KeyEvent.fromString('!');
        expect(event.code.kind, KeyCodeKind.char);
        expect(event.code.char, '!');
        expect(event.modifiers.value, 0);
        expect(event.eventType, KeyEventType.keyPress);
      });
    });

    group('named keys', () {
      test('parses enter', () {
        final event = KeyEvent.fromString('enter');
        expect(event.code.kind, KeyCodeKind.named);
        expect(event.code.name, KeyCodeName.enter);
        expect(event.modifiers.value, 0);
        expect(event.eventType, KeyEventType.keyPress);
      });

      test('parses escape', () {
        final event = KeyEvent.fromString('escape');
        expect(event.code.kind, KeyCodeKind.named);
        expect(event.code.name, KeyCodeName.escape);
        expect(event.modifiers.value, 0);
        expect(event.eventType, KeyEventType.keyPress);
      });

      test('parses f1', () {
        final event = KeyEvent.fromString('f1');
        expect(event.code.kind, KeyCodeKind.named);
        expect(event.code.name, KeyCodeName.f1);
        expect(event.modifiers.value, 0);
        expect(event.eventType, KeyEventType.keyPress);
      });

      test('parses f12', () {
        final event = KeyEvent.fromString('f12');
        expect(event.code.kind, KeyCodeKind.named);
        expect(event.code.name, KeyCodeName.f12);
        expect(event.modifiers.value, 0);
        expect(event.eventType, KeyEventType.keyPress);
      });

      test('parses arrow keys', () {
        final up = KeyEvent.fromString('up');
        expect(up.code.name, KeyCodeName.up);
        expect(up.modifiers.value, 0);
        expect(up.eventType, KeyEventType.keyPress);

        final down = KeyEvent.fromString('down');
        expect(down.code.name, KeyCodeName.down);
        expect(down.modifiers.value, 0);
        expect(down.eventType, KeyEventType.keyPress);

        final left = KeyEvent.fromString('left');
        expect(left.code.name, KeyCodeName.left);
        expect(left.modifiers.value, 0);
        expect(left.eventType, KeyEventType.keyPress);

        final right = KeyEvent.fromString('right');
        expect(right.code.name, KeyCodeName.right);
        expect(right.modifiers.value, 0);
        expect(right.eventType, KeyEventType.keyPress);
      });

      test('parses home/end', () {
        final home = KeyEvent.fromString('home');
        expect(home.code.name, KeyCodeName.home);
        expect(home.modifiers.value, 0);
        expect(home.eventType, KeyEventType.keyPress);

        final end = KeyEvent.fromString('end');
        expect(end.code.name, KeyCodeName.end);
        expect(end.modifiers.value, 0);
        expect(end.eventType, KeyEventType.keyPress);
      });

      test('parses pageup/pagedown', () {
        final pageUp = KeyEvent.fromString('pageup');
        expect(pageUp.code.name, KeyCodeName.pageUp);
        expect(pageUp.modifiers.value, 0);
        expect(pageUp.eventType, KeyEventType.keyPress);

        final pageDown = KeyEvent.fromString('pagedown');
        expect(pageDown.code.name, KeyCodeName.pageDown);
        expect(pageDown.modifiers.value, 0);
        expect(pageDown.eventType, KeyEventType.keyPress);
      });

      test('parses delete', () {
        final del = KeyEvent.fromString('delete');
        expect(del.code.name, KeyCodeName.delete);
        expect(del.modifiers.value, 0);
        expect(del.eventType, KeyEventType.keyPress);
      });

      test('parses insert', () {
        final ins = KeyEvent.fromString('insert');
        expect(ins.code.name, KeyCodeName.insert);
        expect(ins.modifiers.value, 0);
        expect(ins.eventType, KeyEventType.keyPress);
      });

      test('parses tab', () {
        final tab = KeyEvent.fromString('tab');
        expect(tab.code.name, KeyCodeName.tab);
        expect(tab.modifiers.value, 0);
        expect(tab.eventType, KeyEventType.keyPress);
      });

      test('parses backspace', () {
        final backspace = KeyEvent.fromString('backspace');
        expect(backspace.code.name, KeyCodeName.backSpace);
        expect(backspace.modifiers.value, 0);
        expect(backspace.eventType, KeyEventType.keyPress);
      });

      test('is case insensitive', () {
        final lower = KeyEvent.fromString('enter');
        final upper = KeyEvent.fromString('ENTER');
        final mixed = KeyEvent.fromString('EnTeR');

        expect(lower.code.name, KeyCodeName.enter);
        expect(upper.code.name, KeyCodeName.enter);
        expect(mixed.code.name, KeyCodeName.enter);
      });
    });

    group('media keys', () {
      test('parses play', () {
        final event = KeyEvent.fromString('play');
        expect(event.code.kind, KeyCodeKind.named);
        expect(event.code.name, KeyCodeName.play);
        expect(event.modifiers.value, 0);
        expect(event.eventType, KeyEventType.keyPress);
      });

      test('parses pause', () {
        final event = KeyEvent.fromString('pause');
        expect(event.code.kind, KeyCodeKind.named);
        expect(event.code.name, KeyCodeName.pause);
        expect(event.modifiers.value, 0);
        expect(event.eventType, KeyEventType.keyPress);
      });

      test('parses playpause', () {
        final event = KeyEvent.fromString('playpause');
        expect(event.code.kind, KeyCodeKind.named);
        expect(event.code.name, KeyCodeName.playPause);
        expect(event.modifiers.value, 0);
        expect(event.eventType, KeyEventType.keyPress);
      });

      test('parses raiseVolume', () {
        final event = KeyEvent.fromString('raiseVolume');
        expect(event.code.kind, KeyCodeKind.named);
        expect(event.code.name, KeyCodeName.raiseVolume);
        expect(event.modifiers.value, 0);
        expect(event.eventType, KeyEventType.keyPress);
      });

      test('parses lowerVolume', () {
        final event = KeyEvent.fromString('lowerVolume');
        expect(event.code.kind, KeyCodeKind.named);
        expect(event.code.name, KeyCodeName.lowerVolume);
        expect(event.modifiers.value, 0);
        expect(event.eventType, KeyEventType.keyPress);
      });

      test('parses muteVolume', () {
        final event = KeyEvent.fromString('muteVolume');
        expect(event.code.kind, KeyCodeKind.named);
        expect(event.code.name, KeyCodeName.muteVolume);
        expect(event.modifiers.value, 0);
        expect(event.eventType, KeyEventType.keyPress);
      });

      test('parses stop', () {
        final event = KeyEvent.fromString('stop');
        expect(event.code.kind, KeyCodeKind.named);
        expect(event.code.name, KeyCodeName.stop);
        expect(event.modifiers.value, 0);
        expect(event.eventType, KeyEventType.keyPress);
      });

      test('parses trackNext', () {
        final event = KeyEvent.fromString('trackNext');
        expect(event.code.kind, KeyCodeKind.named);
        expect(event.code.name, KeyCodeName.trackNext);
        expect(event.modifiers.value, 0);
        expect(event.eventType, KeyEventType.keyPress);
      });
    });

    group('modifier keys standalone', () {
      test('parses leftCtrl', () {
        final event = KeyEvent.fromString('leftCtrl');
        expect(event.code.kind, KeyCodeKind.named);
        expect(event.code.name, KeyCodeName.leftCtrl);
        expect(event.modifiers.value, KeyModifiers.ctrl);
        expect(event.eventType, KeyEventType.keyPress);
      });

      test('parses rightShift', () {
        final event = KeyEvent.fromString('rightShift');
        expect(event.code.kind, KeyCodeKind.named);
        expect(event.code.name, KeyCodeName.rightShift);
        expect(event.modifiers.value, KeyModifiers.shift);
        expect(event.eventType, KeyEventType.keyPress);
      });

      test('parses leftAlt', () {
        final event = KeyEvent.fromString('leftAlt');
        expect(event.code.kind, KeyCodeKind.named);
        expect(event.code.name, KeyCodeName.leftAlt);
        expect(event.modifiers.value, KeyModifiers.alt);
        expect(event.eventType, KeyEventType.keyPress);
      });

      test('parses rightSuper', () {
        final event = KeyEvent.fromString('rightSuper');
        expect(event.code.kind, KeyCodeKind.named);
        expect(event.code.name, KeyCodeName.rightSuper);
        expect(event.modifiers.value, KeyModifiers.superKey);
        expect(event.eventType, KeyEventType.keyPress);
      });
    });

    group('generic modifiers', () {
      test('parses ctrl+a', () {
        final event = KeyEvent.fromString('ctrl+a');
        expect(event.code.kind, KeyCodeKind.char);
        expect(event.code.char, 'a');
        expect(event.modifiers, KeyModifiers.ctrl);
      });

      test('parses shift+b', () {
        final event = KeyEvent.fromString('shift+b');
        expect(event.code.char, 'b');
        expect(event.modifiers, KeyModifiers.shift);
      });

      test('parses alt+c', () {
        final event = KeyEvent.fromString('alt+c');
        expect(event.code.char, 'c');
        expect(event.modifiers, KeyModifiers.alt);
      });

      test('parses super+d', () {
        final event = KeyEvent.fromString('super+d');
        expect(event.code.char, 'd');
        expect(event.modifiers, KeyModifiers.superKey);
      });

      test('parses hyper+e', () {
        final event = KeyEvent.fromString('hyper+e');
        expect(event.code.char, 'e');
        expect(event.modifiers, KeyModifiers.hyper);
      });

      test('parses meta+f', () {
        final event = KeyEvent.fromString('meta+f');
        expect(event.code.char, 'f');
        expect(event.modifiers, KeyModifiers.meta);
      });

      test('parses leftHyper+g', () {
        final event = KeyEvent.fromString('leftHyper+g');
        expect(event.code.char, 'g');
        expect(event.modifiers, KeyModifiers.hyper);
      });

      test('parses rightHyper+h', () {
        final event = KeyEvent.fromString('rightHyper+h');
        expect(event.code.char, 'h');
        expect(event.modifiers, KeyModifiers.hyper);
      });

      test('parses leftMeta+i', () {
        final event = KeyEvent.fromString('leftMeta+i');
        expect(event.code.char, 'i');
        expect(event.modifiers, KeyModifiers.meta);
      });

      test('parses rightMeta+j', () {
        final event = KeyEvent.fromString('rightMeta+j');
        expect(event.code.char, 'j');
        expect(event.modifiers, KeyModifiers.meta);
      });
    });

    group('multiple modifiers', () {
      test('parses ctrl+shift+a', () {
        final event = KeyEvent.fromString('ctrl+shift+a');
        expect(event.code.char, 'a');
        expect(event.modifiers.has(KeyModifiers.ctrl), isTrue);
        expect(event.modifiers.has(KeyModifiers.shift), isTrue);
        expect(event.modifiers.value, KeyModifiers.ctrl | KeyModifiers.shift);
      });

      test('parses shift+alt+enter', () {
        final event = KeyEvent.fromString('shift+alt+enter');
        expect(event.code.kind, KeyCodeKind.named);
        expect(event.code.name, KeyCodeName.enter);
        expect(event.modifiers.has(KeyModifiers.shift), isTrue);
        expect(event.modifiers.has(KeyModifiers.alt), isTrue);
      });

      test('parses ctrl+alt+delete', () {
        final event = KeyEvent.fromString('ctrl+alt+delete');
        expect(event.code.name, KeyCodeName.delete);
        expect(event.modifiers.has(KeyModifiers.ctrl), isTrue);
        expect(event.modifiers.has(KeyModifiers.alt), isTrue);
      });

      test('parses three generic modifiers', () {
        final event = KeyEvent.fromString('ctrl+shift+alt+f1');
        expect(event.code.name, KeyCodeName.f1);
        expect(event.modifiers.value, KeyModifiers.ctrl | KeyModifiers.shift | KeyModifiers.alt);
      });
    });

    group('mixed generic and specific modifiers', () {
      test('parses leftCtrl+shift+a', () {
        final event = KeyEvent.fromString('leftCtrl+shift+a');
        expect(event.code.char, 'a');
        expect(event.modifiers.has(KeyModifiers.ctrl), isTrue);
        expect(event.modifiers.has(KeyModifiers.shift), isTrue);
      });

      test('parses shift+rightAlt+b', () {
        final event = KeyEvent.fromString('shift+rightAlt+b');
        expect(event.code.char, 'b');
        expect(event.modifiers.has(KeyModifiers.shift), isTrue);
        expect(event.modifiers.has(KeyModifiers.alt), isTrue);
      });

      test('parses leftShift+rightCtrl+f1', () {
        final event = KeyEvent.fromString('leftShift+rightCtrl+f1');
        expect(event.code.name, KeyCodeName.f1);
        expect(event.modifiers.has(KeyModifiers.shift), isTrue);
        expect(event.modifiers.has(KeyModifiers.ctrl), isTrue);
      });
    });

    group('media keys with modifiers', () {
      test('parses ctrl+raiseVolume', () {
        final event = KeyEvent.fromString('ctrl+raiseVolume');
        expect(event.code.kind, KeyCodeKind.named);
        expect(event.code.name, KeyCodeName.raiseVolume);
        expect(event.modifiers.has(KeyModifiers.ctrl), isTrue);
      });

      test('parses shift+play', () {
        final event = KeyEvent.fromString('shift+play');
        expect(event.code.name, KeyCodeName.play);
        expect(event.modifiers.has(KeyModifiers.shift), isTrue);
      });
    });

    group('edge cases', () {
      test('throws on empty string', () {
        expect(() => KeyEvent.fromString(''), throwsArgumentError);
      });

      test('throws on unknown key', () {
        expect(() => KeyEvent.fromString('unknown+a'), throwsArgumentError);
      });

      test('throws on unknown key', () {
        expect(() => KeyEvent.fromString('unknownkey'), throwsArgumentError);
      });

      test('throws on multichar unknown key', () {
        expect(() => KeyEvent.fromString('ctrl+unknownkey'), throwsArgumentError);
      });

      test('handles whitespace in single char', () {
        final space = KeyEvent.fromString(' ');
        expect(space.code.kind, KeyCodeKind.char);
        expect(space.code.char, ' ');
      });
    });

    group('equality and wildcard matching', () {
      test('generic and specific produce same events', () {
        final generic = KeyEvent.fromString('ctrl+a');
        final specific = KeyEvent.fromString('leftCtrl+a');
        expect(generic, equals(specific));
      });

      test('wildcard matching works as expected', () {
        final generic = KeyEvent.fromString('ctrl+a');
        final leftSpecific = KeyEvent.fromString('leftCtrl+a');
        final rightSpecific = KeyEvent.fromString('rightCtrl+a');
        final moreSpecificity = KeyEvent.fromString('leftCtrl+rightShift+a');
        final lessSpecificity = KeyEvent.fromString('ctrl+shift+a');

        // All should be equal since modifierKeys is not compared
        expect(generic, equals(leftSpecific));
        expect(generic, equals(rightSpecific));
        expect(leftSpecific, equals(rightSpecific));
        expect(moreSpecificity, equals(lessSpecificity));
      });

      test('different keys are not equal', () {
        final eventA = KeyEvent.fromString('ctrl+a');
        final eventB = KeyEvent.fromString('ctrl+b');

        expect(eventA, isNot(equals(eventB)));
      });

      test('different modifiers are not equal', () {
        final ctrl = KeyEvent.fromString('ctrl+a');
        final shift = KeyEvent.fromString('shift+a');

        expect(ctrl, isNot(equals(shift)));
      });
    });
  });
}
