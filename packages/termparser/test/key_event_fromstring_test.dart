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
        expect(event.code.char, 'B');
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
        expect(event.code.char, 'A');
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
        expect(event.code.char, 'A');
        expect(event.modifiers.has(KeyModifiers.ctrl), isTrue);
        expect(event.modifiers.has(KeyModifiers.shift), isTrue);
      });

      test('parses shift+rightAlt+b', () {
        final event = KeyEvent.fromString('shift+rightAlt+b');
        expect(event.code.char, 'B');
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

    group('plus and minus keys', () {
      test('parses plus as char', () {
        final event = KeyEvent.fromString('plus');
        expect(event.code.kind, KeyCodeKind.char);
        expect(event.code.char, '+');
        expect(event.modifiers.value, 0);
      });

      test('parses minus as char', () {
        final event = KeyEvent.fromString('minus');
        expect(event.code.kind, KeyCodeKind.char);
        expect(event.code.char, '-');
        expect(event.modifiers.value, 0);
      });

      test('parses ctrl+plus', () {
        final event = KeyEvent.fromString('ctrl+plus');
        expect(event.code.kind, KeyCodeKind.char);
        expect(event.code.char, '+');
        expect(event.modifiers, KeyModifiers.ctrl);
      });

      test('parses ctrl+minus', () {
        final event = KeyEvent.fromString('ctrl+minus');
        expect(event.code.kind, KeyCodeKind.char);
        expect(event.code.char, '-');
        expect(event.modifiers, KeyModifiers.ctrl);
      });

      test('parses shift+plus', () {
        final event = KeyEvent.fromString('shift+plus');
        expect(event.code.char, '+'); // not a letter, no uppercase
        expect(event.modifiers, KeyModifiers.shift);
      });

      test('parses ctrl+shift+plus', () {
        final event = KeyEvent.fromString('ctrl+shift+plus');
        expect(event.code.char, '+');
        expect(event.modifiers.has(KeyModifiers.ctrl), isTrue);
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

  group('KeyEvent.toSpec', () {
    group('single characters', () {
      test('char key', () {
        expect(KeyEvent.fromString('a').toSpec(), 'a');
        expect(KeyEvent.fromString('Z').toSpec(), 'Z');
        expect(KeyEvent.fromString('5').toSpec(), '5');
        expect(KeyEvent.fromString('!').toSpec(), '!');
      });

      test('space char becomes space', () {
        expect(KeyEvent.fromString(' ').toSpec(), 'space');
        expect(KeyEvent.fromString('space').toSpec(), 'space');
      });
    });

    group('named keys', () {
      test('named keys use enum name', () {
        expect(KeyEvent.fromString('enter').toSpec(), 'enter');
        expect(KeyEvent.fromString('escape').toSpec(), 'escape');
        expect(KeyEvent.fromString('backSpace').toSpec(), 'backSpace');
        expect(KeyEvent.fromString('f1').toSpec(), 'f1');
        expect(KeyEvent.fromString('f12').toSpec(), 'f12');
        expect(KeyEvent.fromString('up').toSpec(), 'up');
        expect(KeyEvent.fromString('pageUp').toSpec(), 'pageUp');
      });

      test('media keys', () {
        expect(KeyEvent.fromString('play').toSpec(), 'play');
        expect(KeyEvent.fromString('playPause').toSpec(), 'playPause');
        expect(KeyEvent.fromString('raiseVolume').toSpec(), 'raiseVolume');
      });
    });

    group('modifier keys normalize to generic', () {
      test('leftCtrl becomes ctrl', () {
        expect(KeyEvent.fromString('leftCtrl').toSpec(), 'ctrl');
      });

      test('rightCtrl becomes ctrl', () {
        expect(KeyEvent.fromString('rightCtrl').toSpec(), 'ctrl');
      });

      test('leftShift becomes shift', () {
        expect(KeyEvent.fromString('leftShift').toSpec(), 'shift');
      });

      test('rightAlt becomes alt', () {
        expect(KeyEvent.fromString('rightAlt').toSpec(), 'alt');
      });

      test('leftSuper becomes super', () {
        expect(KeyEvent.fromString('leftSuper').toSpec(), 'super');
      });

      test('rightHyper becomes hyper', () {
        expect(KeyEvent.fromString('rightHyper').toSpec(), 'hyper');
      });

      test('leftMeta becomes meta', () {
        expect(KeyEvent.fromString('leftMeta').toSpec(), 'meta');
      });
    });

    group('with modifiers', () {
      test('single modifier', () {
        expect(KeyEvent.fromString('ctrl+a').toSpec(), 'ctrl+a');
        expect(KeyEvent.fromString('shift+enter').toSpec(), 'shift+enter');
        expect(KeyEvent.fromString('alt+f1').toSpec(), 'alt+f1');
      });

      test('multiple modifiers in canonical order', () {
        expect(KeyEvent.fromString('ctrl+shift+a').toSpec(), 'ctrl+shift+a');
        expect(KeyEvent.fromString('shift+ctrl+a').toSpec(), 'ctrl+shift+a');
        expect(KeyEvent.fromString('alt+ctrl+a').toSpec(), 'ctrl+alt+a');
        expect(KeyEvent.fromString('meta+hyper+super+shift+alt+ctrl+a').toSpec(), 'ctrl+alt+shift+super+hyper+meta+a');
      });

      test('specific modifiers normalize in output', () {
        expect(KeyEvent.fromString('leftCtrl+a').toSpec(), 'ctrl+a');
        expect(KeyEvent.fromString('rightShift+b').toSpec(), 'shift+b');
      });

      test('modifier + space', () {
        expect(KeyEvent.fromString('ctrl+space').toSpec(), 'ctrl+space');
      });
    });

    group('roundtrip', () {
      test('fromString then toSpec is idempotent', () {
        final specs = [
          'a',
          'A',
          'space',
          'enter',
          'backSpace',
          'f12',
          'ctrl+a',
          'alt+enter',
          'ctrl+shift+delete',
          'ctrl+alt+shift+super+hyper+meta+f1',
        ];
        for (final spec in specs) {
          expect(KeyEvent.fromString(spec).toSpec(), spec);
        }
      });

      test('shift+letter round trips correctly', () {
        // shift+a → KeyCode.char('A') internally → toSpec → 'shift+a'
        expect(KeyEvent.fromString('shift+a').toSpec(), 'shift+a');
        expect(KeyEvent.fromString('shift+z').toSpec(), 'shift+z');
        expect(KeyEvent.fromString('ctrl+shift+x').toSpec(), 'ctrl+shift+x');
      });

      test('shift+digit keeps digit unchanged', () {
        expect(KeyEvent.fromString('shift+1').toSpec(), 'shift+1');
        expect(KeyEvent.fromString('shift+9').toSpec(), 'shift+9');
      });

      test('plus and minus roundtrip', () {
        expect(KeyEvent.fromString('plus').toSpec(), 'plus');
        expect(KeyEvent.fromString('minus').toSpec(), 'minus');
        expect(KeyEvent.fromString('ctrl+plus').toSpec(), 'ctrl+plus');
        expect(KeyEvent.fromString('ctrl+minus').toSpec(), 'ctrl+minus');
        expect(KeyEvent.fromString('ctrl+shift+plus').toSpec(), 'ctrl+shift+plus');
      });

      test('camelCase named keys roundtrip', () {
        expect(KeyEvent.fromString('backSpace').toSpec(), 'backSpace');
        expect(KeyEvent.fromString('pageUp').toSpec(), 'pageUp');
        expect(KeyEvent.fromString('pageDown').toSpec(), 'pageDown');
        expect(KeyEvent.fromString('backTab').toSpec(), 'backTab');
        expect(KeyEvent.fromString('keypadBegin').toSpec(), 'keypadBegin');
        expect(KeyEvent.fromString('ctrl+backSpace').toSpec(), 'ctrl+backSpace');
        expect(KeyEvent.fromString('shift+pageUp').toSpec(), 'shift+pageUp');
        expect(KeyEvent.fromString('ctrl+shift+pageDown').toSpec(), 'ctrl+shift+pageDown');
      });

      test('camelCase media keys roundtrip', () {
        expect(KeyEvent.fromString('playPause').toSpec(), 'playPause');
        expect(KeyEvent.fromString('trackNext').toSpec(), 'trackNext');
        expect(KeyEvent.fromString('trackPrevious').toSpec(), 'trackPrevious');
        expect(KeyEvent.fromString('raiseVolume').toSpec(), 'raiseVolume');
        expect(KeyEvent.fromString('lowerVolume').toSpec(), 'lowerVolume');
        expect(KeyEvent.fromString('muteVolume').toSpec(), 'muteVolume');
        expect(KeyEvent.fromString('fastForward').toSpec(), 'fastForward');
      });
    });
  });
}
