import 'package:termparser/src/engine/engine.dart';
import 'package:termparser/src/engine/event_queue.dart';
import 'package:termparser/src/events.dart';
import 'package:termparser/src/events_types.dart';
import 'package:test/test.dart';

void main() {
  void listAdvance(Engine engine, EventQueue queue, List<int> input, {bool hasMore = false}) {
    for (var i = 0; i < input.length; i++) {
      engine.advance(queue, input[i], hasMore: (i < (input.length - 1)) || hasMore);
    }
  }

  void stringAdvance(Engine engine, EventQueue queue, String input, {bool hasMore = false}) {
    final x = input.split('');
    for (var i = 0; i < input.length; i++) {
      engine.advance(queue, x[i].codeUnitAt(0), hasMore: (i < (input.length - 1)) || hasMore);
    }
  }

  group('ESC >', () {
    test('char', () {
      final eng = Engine();
      final queue = EventQueue();

      // No more input means that the Esc character should be dispatched immediately
      eng.advance(queue, 0x1b);
      expect(queue.hasEvents, true);
      expect(queue.count, 1);
      queue.drain(); // clear

      // There's more input so the machine should wait before dispatching Esc character
      eng.advance(queue, 0x1b, hasMore: true);
      expect(queue.count, 0); // waiting in escape state, no event yet

      // Another Esc character, but no more input, machine should dispatch the postponed Esc
      // character and the new one too.
      eng.advance(queue, 0x1b);
      expect(queue.count, 2); // postponed Esc + current Esc
      final ev1 = queue.poll();
      if (ev1 is! KeyEvent) {
        fail('Expected KeyEvent');
      }
      expect(ev1.code.name, KeyCodeName.escape);
      final ev2 = queue.poll();
      if (ev2 is! KeyEvent) {
        fail('Expected KeyEvent');
      }
      expect(ev2.code.name, KeyCodeName.escape);
    });

    test('without intermediates', () {
      final eng = Engine();
      final queue = EventQueue();

      const input = '\x1B0\x1B~';
      stringAdvance(eng, queue, input);

      expect(queue.count, 2);
      final events = queue.drain();
      expect((events[0] as KeyEvent).code.char, '0');
      expect((events[1] as KeyEvent).code.char, '~');
    });

    test('W', () {
      final eng = Engine();
      final queue = EventQueue();

      const input = '\x1BW';
      stringAdvance(eng, queue, input);

      expect(queue.count, 1);
      final event = queue.poll();
      if (event is! KeyEvent) {
        fail('Expected KeyEvent');
      }
      expect(event.code.char, 'W');
    });

    test('OR', () {
      final eng = Engine();
      final queue = EventQueue();

      stringAdvance(eng, queue, '\x1BOR');

      // ESC O is special - sets _escO flag, R becomes F3 key
      expect(queue.count, 1);
      final event = queue.poll();
      if (event is! KeyEvent) {
        fail('Expected KeyEvent');
      }
      expect(event.code.name, KeyCodeName.f3);
    });

    test('ctrl-a', () {
      final eng = Engine();
      final queue = EventQueue();

      stringAdvance(eng, queue, '\x01');

      expect(queue.count, 1);
      final event = queue.poll();
      if (event is! KeyEvent) {
        fail('Expected KeyEvent');
      }
      expect(event.code.char, 'a');
      expect(event.modifiers.has(KeyModifiers.ctrl), true);
    });

    test('ctrl-i', () {
      final eng = Engine();
      final queue = EventQueue();

      stringAdvance(eng, queue, '\x09');

      expect(queue.count, 1);
      final event = queue.poll();
      if (event is! KeyEvent) {
        fail('Expected KeyEvent');
      }
      expect(event.code.name, KeyCodeName.tab);
    });

    test('ctrl-h', () {
      final eng = Engine();
      final queue = EventQueue();

      stringAdvance(eng, queue, '\x08');

      expect(queue.count, 1);
      final event = queue.poll();
      if (event is! KeyEvent) {
        fail('Expected KeyEvent');
      }
      expect(event.code.name, KeyCodeName.backSpace);
    });
  });

  group('CSI >', () {
    test('esc', () {
      final eng = Engine();
      final queue = EventQueue();

      stringAdvance(eng, queue, '\x1b[\x1b');

      // ESC [ ESC -> error is generated, state reset, ESC byte consumed
      expect(queue.count, 1);
      expect(queue.poll(), isA<EngineErrorEvent>());
    });

    test('with ignore', () {
      final eng = Engine();
      final queue = EventQueue();

      stringAdvance(eng, queue, '\x1b[\x7f');

      expect(queue.hasEvents, false);
    });

    test('without parameters', () {
      final eng = Engine();
      final queue = EventQueue();

      stringAdvance(eng, queue, '\x1b[m');

      expect(eng.collectedParameters.length, 1);
      expect(eng.collectedParameters, <String>['0']);
      expect(queue.count, 1);
      expect(queue.poll(), isA<Event>());
    });

    test('with two default parameters', () {
      final eng = Engine();
      final queue = EventQueue();

      stringAdvance(eng, queue, '\x1b[;m');

      expect(eng.collectedParameters.length, 2);
      expect(eng.collectedParameters, <String>['0', '0']);
      expect(queue.count, 1);
      expect(queue.poll(), isA<Event>());
    });

    test('with parameters and sequence', () {
      final eng = Engine();
      final queue = EventQueue();

      stringAdvance(eng, queue, '\x1b[0:1;2:3;4:u');

      expect(eng.collectedParameters, <String>['0:1', '2:3', '4:']);
      // expect(queue.count, 1);
      // expect(queue.poll(), isA<NoneEvent>());
    });

    test('with color space', () {
      final eng = Engine();
      final queue = EventQueue();

      stringAdvance(eng, queue, '\x1b[38:2::0:0:0m');

      expect(eng.collectedParameters, <String>['38:2::0:0:0']);
      expect(queue.count, 1);
      expect(queue.poll(), isA<NoneEvent>());
    });

    test('with trailing semicolon', () {
      final eng = Engine();
      final queue = EventQueue();

      stringAdvance(eng, queue, '\x1b[123;m');

      expect(eng.collectedParameters, <String>['123', '0']);
      expect(queue.count, 1);
      expect(queue.poll(), isA<NoneEvent>());
    });

    test('max parameters', () {
      final eng = Engine();
      final queue = EventQueue();

      const input = '\x1b[1;2;3;4;5;6;7;8;9;10;11;12;13;14;15;16;17;18;19;20;21;22;23;24;25;26;27;28;29;30;31m';
      stringAdvance(eng, queue, input);

      // dart format off
      expect(eng.collectedParameters, <String>[
        '1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12', '13', '14', '15', '16', '17', '18', '19',
        '20', '21', '22', '23', '24', '25', '26', '27', '28', '29', '30',
      ]);
      // dart format on
      expect(queue.count, 1);
      expect(queue.poll(), isA<NoneEvent>());
    });

    test('with ignore', () {
      final eng = Engine();
      final queue = EventQueue();

      stringAdvance(eng, queue, '\x1B[;1\x3Cc');

      expect(queue.hasEvents, false);
    });

    test(r'?2026;2$y', () {
      final eng = Engine();
      final queue = EventQueue();

      stringAdvance(eng, queue, '\x1b[?2026;2\$y');

      expect(queue.count, 1);
      final event = queue.poll();
      if (event is! QuerySyncUpdateEvent) {
        fail('Expected QuerySyncUpdateEvent');
      }
      expect(event.code, 2);
      expect(event.status, DECRPMStatus.disabled);
    });
  });

  group('CSI Bracketed Paste >', () {
    test('text', () {
      final eng = Engine();
      final queue = EventQueue();

      const startPasteSeq = [0x1b, 0x5b, 0x32, 0x30, 0x30, 0x7E]; // ESC [ 2 0 0 ~
      const endPasteSeq = [0x1b, 0x5b, 0x32, 0x30, 0x31, 0x7E]; // ESC [ 2 0 1 ~

      listAdvance(eng, queue, [...startPasteSeq, 0x61, 0xc3, 0xb1, 0x63, ...endPasteSeq]);
      expect(queue.count, 1);
      final event = queue.poll();
      if (event is PasteEvent) {
        expect(event.text, 'añc');
      } else {
        fail('Expected PasteEvent');
      }
    });

    test('with control codes', () {
      final eng = Engine();
      final queue = EventQueue();

      stringAdvance(eng, queue, '\x1b[200~o\x1b[2D\x1b[201~');
      expect(queue.count, 1);
      final event = queue.poll();
      expect(event, isA<PasteEvent>());
    });

    test('paste content not accumulated in sequence bytes', () {
      final eng = Engine();
      final queue = EventQueue();

      const startPasteSeq = [0x1b, 0x5b, 0x32, 0x30, 0x30, 0x7E]; // ESC [ 2 0 0 ~
      const pasteContent = [0x61, 0x62, 0x63, 0x64, 0x65]; // "abcde"

      listAdvance(eng, queue, startPasteSeq);
      expect(eng.currentState.toString().contains('textBlock'), true);

      final bytesBeforePaste = eng.currentSequenceBytes.length;
      listAdvance(eng, queue, pasteContent);

      // Sequence bytes should NOT have grown with paste content
      expect(eng.currentSequenceBytes.length, bytesBeforePaste);
    });
  });

  group('CSI Mouse >', () {
    test('csi sgr mouse', () {
      final eng = Engine();
      final queue = EventQueue();

      stringAdvance(eng, queue, '\x1b[<35;1;2m');

      expect(queue.count, 1);
      final event = queue.poll();
      if (event is! MouseEvent) {
        fail('Expected MouseEvent');
      }
      expect(event.button.action, MouseButtonAction.moved);
      expect(event.button.button, MouseButtonKind.none);
      expect(event.x, 1);
      expect(event.y, 2);
      expect(event.modifiers.value, 0);
    });

    test('csi sgr mouse M', () {
      final eng = Engine();
      final queue = EventQueue();

      stringAdvance(eng, queue, '\x1b[<35;1;2M');

      expect(queue.count, 1);
      final event = queue.poll();
      if (event is! MouseEvent) {
        fail('Expected MouseEvent');
      }
      expect(event.button.action, MouseButtonAction.moved);
      expect(event.button.button, MouseButtonKind.none);
      expect(event.x, 1);
      expect(event.y, 2);
      expect(event.modifiers.value, 0);
    });
  });

  group('CSI Focus >', () {
    test('csi focus in', () {
      final eng = Engine();
      final queue = EventQueue();

      stringAdvance(eng, queue, '\x1b[I');

      expect(queue.count, 1);
      expect(queue.poll(), isA<FocusEvent>());
    });
  });

  group('CSI keyboard enhancement >', () {
    test('csi ? 1 u', () {
      final eng = Engine();
      final queue = EventQueue();

      stringAdvance(eng, queue, '\x1b[?1u');

      expect(queue.count, 1);
      expect(queue.poll(), isA<KeyboardEnhancementFlagsEvent>());
    });

    test('.[97u', () {
      final eng = Engine();
      final queue = EventQueue();

      stringAdvance(eng, queue, '\x1b[97u');
      expect(queue.count, 1);
      expect(queue.poll(), isA<KeyEvent>());
    });

    test('.[97:65;2u', () {
      final eng = Engine();
      final queue = EventQueue();

      stringAdvance(eng, queue, '\x1b[97:65;2u');

      expect(queue.count, 1);
      expect(queue.poll(), isA<KeyEvent>());
    });

    test('.[127u', () {
      final eng = Engine();
      final queue = EventQueue();

      stringAdvance(eng, queue, '\x1b[127u');

      expect(queue.count, 1);
      expect(queue.poll(), isA<KeyEvent>());
    });

    test('.[127;1:3u', () {
      final eng = Engine();
      final queue = EventQueue();

      stringAdvance(eng, queue, '\x1b[127;1:3u');

      expect(queue.count, 1);
      expect(queue.poll(), isA<KeyEvent>());
    });

    test('.[127::8;2u', () {
      final eng = Engine();
      final queue = EventQueue();

      stringAdvance(eng, queue, '\x1b[127::8;2u');

      expect(queue.count, 1);
      expect(queue.poll(), isA<KeyEvent>());
    });

    test('.[6;5:3~', () {
      final eng = Engine();
      final queue = EventQueue();

      stringAdvance(eng, queue, '\x1b[6;5:3~');

      expect(queue.count, 1);
      expect(queue.poll(), isA<KeyEvent>());
    });
  });

  group('OSC', () {
    test('1', () {
      final eng = Engine();
      final queue = EventQueue();

      stringAdvance(eng, queue, '\x1b]11;rgb:11/22/33\x1b\\');
      expect(eng.collectedParameters, <String>['11', 'rgb:11/22/33']);
      expect(queue.count, 1);
      expect(queue.poll(), isA<ColorQueryEvent>());
    });
  });

  group('UTF8 >', () {
    test('parse utf8 characters', () {
      final eng = Engine();
      final queue = EventQueue();

      stringAdvance(eng, queue, 'a');
      expect(queue.count, 1);
      final e1 = queue.poll();
      if (e1 is! KeyEvent) {
        fail('Expected KeyEvent');
      }
      expect(e1.code.char, 'a');

      listAdvance(eng, queue, [0xc3, 0xb1]);
      expect(queue.count, 1);
      final e2 = queue.poll();
      if (e2 is! KeyEvent) {
        fail('Expected KeyEvent');
      }
      expect(e2.code.char, 'ñ');

      listAdvance(eng, queue, [0xe2, 0x81, 0xa1]);
      expect(queue.count, 1);
      final e3 = queue.poll();
      if (e3 is! KeyEvent) {
        fail('Expected KeyEvent');
      }
      expect(e3.code.char, '\u2061');

      listAdvance(eng, queue, [0xf0, 0x90, 0x8c, 0xbc]);
      expect(queue.count, 1);
      final e4 = queue.poll();
      if (e4 is! KeyEvent) {
        fail('Expected KeyEvent');
      }
      expect(e4.code.char, '𐌼');
    });

    test('Ž', () {
      final eng = Engine();
      final queue = EventQueue();

      stringAdvance(eng, queue, 'Ž');
      expect(queue.count, 1);
      final event = queue.poll();
      if (event is! KeyEvent) {
        fail('Expected KeyEvent');
      }
      expect(event.code.char, 'Ž');
    });
  });

  group('DCS >', () {
    test('πP>|term v1', () {
      final eng = Engine();
      final queue = EventQueue();

      stringAdvance(eng, queue, '\x1bP>|term v1\x1b\x5c');

      expect(queue.count, 1);
      expect(queue.poll(), isA<NameAndVersionEvent>());
    });
  });
}
