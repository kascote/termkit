import 'package:termparser/src/engine.dart';
import 'package:termparser/src/provider.dart';
import 'package:test/test.dart';

import 'mock_provider.dart';

void main() {
  void listAdvance(Engine engine, Provider provider, List<int> input, {bool more = false}) {
    for (var i = 0; i < input.length; i++) {
      engine.advance(provider, input[i], more: (i < (input.length - 1)) || more);
    }
  }

  void stringAdvance(Engine engine, Provider provider, String input, {bool more = false}) {
    final x = input.split('');
    for (var i = 0; i < input.length; i++) {
      engine.advance(provider, x[i].codeUnitAt(0), more: (i < (input.length - 1)) || more);
    }
  }

  group('ESC >', () {
    test('char', () {
      final eng = Engine();
      final cp = MockProvider();

      // No more input means that the Esc character should be dispatched immediately
      eng.advance(cp, 0x1b);
      expect(cp.chars, ['\x1b']);

      // There's more input so the machine should wait before dispatching Esc character
      eng.advance(cp, 0x1b, more: true);
      expect(cp.chars, ['\x1b']);

      // Another Esc character, but no more input, machine should dispatch the postponed Esc
      // character and the new one too.
      eng.advance(cp, 0x1b);
      expect(cp.chars, ['\x1b', '\x1b', '\x1b']);
    });

    test('without intermediates', () {
      final eng = Engine();
      final cp = MockProvider();

      const input = '\x1B0\x1B~';
      stringAdvance(eng, cp, input);

      expect(cp.chars.length, 2);
      expect(cp.chars[0], '0');
      expect(cp.chars[1], '~');
    });

    test('W', () {
      final eng = Engine();
      final cp = MockProvider();

      const input = '\x1BW';
      stringAdvance(eng, cp, input);

      expect(cp.chars.length, 1);
      expect(cp.chars[0], 'W');
    });

    test('OR', () {
      final eng = Engine();
      final cp = MockProvider();

      stringAdvance(eng, cp, '\x1BOR');

      expect(cp.params.length, 0);
      expect(cp.chars.length, 2);
      expect(cp.chars, ['O', 'R']);
    });

    test('ctrl-a', () {
      final eng = Engine();
      final cp = MockProvider();

      stringAdvance(eng, cp, '\x01');

      expect(cp.params.length, 0);
      expect(cp.chars.length, 1);
      expect(cp.chars[0], '\x01');
    });
    test('ctrl-i', () {
      final eng = Engine();
      final cp = MockProvider();

      stringAdvance(eng, cp, '\x09');

      expect(cp.params.length, 0);
      expect(cp.chars.length, 1);
      expect(cp.chars[0], '\x09');
    });

    test('ctrl-h', () {
      final eng = Engine();
      final cp = MockProvider();

      stringAdvance(eng, cp, '\x0b');

      expect(cp.params.length, 0);
      expect(cp.chars.length, 1);
      expect(cp.chars[0], '\x0b');
    });
  });

  group('CSI >', () {
    test('esc', () {
      final eng = Engine();
      final cp = MockProvider();

      stringAdvance(eng, cp, '\x1b[\x1b');

      expect(cp.params.length, 0);
      expect(cp.chars.length, 1);
      expect(cp.chars[0], '\x1b');
    });

    test('with ignore', () {
      final eng = Engine();
      final cp = MockProvider();

      stringAdvance(eng, cp, '\x1b[\x7f');

      expect(cp.params.length, 0);
      expect(cp.chars.length, 0);
    });

    test('without parameters', () {
      final eng = Engine();
      final cp = MockProvider();

      stringAdvance(eng, cp, '\x1b[m');

      expect(cp.params.length, 1);
      expect(cp.params[0], <String>[]);
      expect(cp.chars.length, 1);
      expect(cp.chars[0], 'm');
    });

    test('with two default parameters', () {
      final eng = Engine();
      final cp = MockProvider();

      stringAdvance(eng, cp, '\x1b[;m');

      expect(cp.params.length, 1);
      expect(cp.params[0], <String>['0', '0']); // default parameters values
      expect(cp.chars.length, 1);
      expect(cp.chars[0], 'm');
    });

    test('with parameters and sequence', () {
      final eng = Engine();
      final cp = MockProvider();

      stringAdvance(eng, cp, '\x1b[0:1;2:3;4:m');

      expect(cp.params.length, 1);
      expect(cp.params[0], <String>['0:1', '2:3', '4:']);
      expect(cp.chars.length, 1);
      expect(cp.chars[0], 'm');
    });

    test('with color space', () {
      final eng = Engine();
      final cp = MockProvider();

      stringAdvance(eng, cp, '\x1b[38:2::0:0:0m');

      expect(cp.params.length, 1);
      expect(cp.params[0], <String>['38:2::0:0:0']);
      expect(cp.chars.length, 1);
      expect(cp.chars[0], 'm');
    });

    test('with trailing semicolon', () {
      final eng = Engine();
      final cp = MockProvider();

      stringAdvance(eng, cp, '\x1b[123;m');

      expect(cp.params.length, 1);
      expect(cp.params[0], <String>['123', '0']);
      expect(cp.chars.length, 1);
      expect(cp.chars[0], 'm');
    });

    test('max parameters', () {
      final eng = Engine();
      final cp = MockProvider();

      const input = '\x1b[1;2;3;4;5;6;7;8;9;10;11;12;13;14;15;16;17;18;19;20;21;22;23;24;25;26;27;28;29;30;31m';
      stringAdvance(eng, cp, input);

      expect(cp.params.length, 1);
      expect(cp.params[0], <String>[
        '1',
        '2',
        '3',
        '4',
        '5',
        '6',
        '7',
        '8',
        '9',
        '10',
        '11',
        '12',
        '13',
        '14',
        '15',
        '16',
        '17',
        '18',
        '19',
        '20',
        '21',
        '22',
        '23',
        '24',
        '25',
        '26',
        '27',
        '28',
        '29',
        '30',
      ]); //
      expect(cp.chars.length, 1);
      expect(cp.chars[0], 'm');
    });

    test('with ignore', () {
      final eng = Engine();
      final cp = MockProvider();

      stringAdvance(eng, cp, '\x1B[;1\x3Cc');

      expect(cp.params.length, 0);
      expect(cp.chars.length, 0);
    });

    test(r'?2026;2$y', () {
      final eng = Engine();
      final cp = MockProvider();

      stringAdvance(eng, cp, '\x1b[?2026;2\$y');

      expect(cp.params.length, 1);
      expect(cp.params[0], <String>['?', '2026', '2']);
      expect(cp.chars.length, 1);
      expect(cp.chars[0], 'y');
    });
  });

  group('CSI Bracketed Paste >', () {
    test('text', () {
      final eng = Engine();
      final cp = MockProvider();

      const startPasteSeq = [0x1b, 0x5b, 0x32, 0x30, 0x30, 0x7E]; // ESC [ 2 0 0 ~
      const endPasteSeq = [0x1b, 0x5b, 0x32, 0x30, 0x31, 0x7E]; // ESC [ 2 0 1 ~

      listAdvance(eng, cp, [...startPasteSeq, 0x61, 0xc3, 0xb1, 0x63, ...endPasteSeq]);
      expect(cp.chars.length, 1);
      expect(cp.chars[0], '~');
      expect(cp.params[0], <String>['200', 'añc', '201']);
    });

    test('with control codes', () {
      final eng = Engine();
      final cp = MockProvider();

      stringAdvance(eng, cp, '\x1b[200~o\x1b[2D\x1b[201~');
      expect(cp.params[0], ['201']);
      expect(cp.chars[0], '~');
    });
  });

  group('CSI Mouse >', () {
    test('csi sgr mouse', () {
      final eng = Engine();
      final cp = MockProvider();

      stringAdvance(eng, cp, '\x1b[<35;1;2m');

      expect(cp.params.length, 1);
      expect(cp.params[0], <String>['35', '1', '2']);
      expect(cp.chars.length, 1);
      expect(cp.chars[0], 'm');
    });

    test('csi sgr mouse', () {
      final eng = Engine();
      final cp = MockProvider();

      stringAdvance(eng, cp, '\x1b[<35;1;2M');

      expect(cp.params.length, 1);
      expect(cp.params[0], <String>['35', '1', '2']);
      expect(cp.chars.length, 1);
      expect(cp.chars[0], 'M');
    });
  });

  group('CSI Focus >', () {
    test('csi focus in', () {
      final eng = Engine();
      final cp = MockProvider();

      stringAdvance(eng, cp, '\x1b[I');

      expect(cp.params.length, 1);
      expect(cp.chars.length, 1);
      expect(cp.chars[0], 'I');
    });
  });

  group('CSI keyboard enhancement >', () {
    test('csi ? 1 u', () {
      final eng = Engine();
      final cp = MockProvider();

      stringAdvance(eng, cp, '\x1b[?1u');

      expect(cp.params.length, 1);
      expect(cp.params[0], ['?', '1']);
      expect(cp.chars.length, 1);
      expect(cp.chars[0], 'u');
    });

    test('.[97u', () {
      final eng = Engine();
      final cp = MockProvider();

      stringAdvance(eng, cp, '\x1b[97u');
      expect(cp.params.length, 1);
      expect(cp.params[0], ['97']);
      expect(cp.chars.length, 1);
      expect(cp.chars[0], 'u');
    });

    test('.[97:65;2u', () {
      final eng = Engine();
      final cp = MockProvider();

      stringAdvance(eng, cp, '\x1b[97:65;2u');

      expect(cp.params.length, 1);
      expect(cp.params[0], ['97:65', '2']);
      expect(cp.chars.length, 1);
      expect(cp.chars[0], 'u');
    });

    test('.[127u', () {
      final eng = Engine();
      final cp = MockProvider();

      stringAdvance(eng, cp, '\x1b[127u');

      expect(cp.params.length, 1);
      expect(cp.params[0], ['127']);
      expect(cp.chars.length, 1);
      expect(cp.chars[0], 'u');
    });

    test('.[127;1:3u', () {
      final eng = Engine();
      final cp = MockProvider();

      stringAdvance(eng, cp, '\x1b[127;1:3u');

      expect(cp.params.length, 1);
      expect(cp.params[0], ['127', '1:3']);
      expect(cp.chars.length, 1);
      expect(cp.chars[0], 'u');
    });

    test('.[127::8;2u', () {
      final eng = Engine();
      final cp = MockProvider();

      stringAdvance(eng, cp, '\x1b[127::8;2u');

      expect(cp.params.length, 1);
      expect(cp.params[0], ['127::8', '2']);
      expect(cp.chars.length, 1);
      expect(cp.chars[0], 'u');
    });

    test('.[6;5:3~', () {
      final eng = Engine();
      final cp = MockProvider();

      stringAdvance(eng, cp, '\x1b[6;5:3~');

      expect(cp.params.length, 1);
      expect(cp.params[0], ['6', '5:3']);
      expect(cp.chars.length, 1);
      expect(cp.chars[0], '~');
    });
  });

  group('OSC', () {
    test('1', () {
      final eng = Engine();
      final cp = MockProvider();

      stringAdvance(eng, cp, '\x1b]11;rgb:11/22/33\x1b\\');
      expect(cp.params.length, 1);
      expect(cp.params[0], ['11', 'rgb:11/22/33']);
    });
  });

  group('UTF8 >', () {
    test('parse utf8 characters', () {
      final eng = Engine();
      final cp = MockProvider();

      stringAdvance(eng, cp, 'a');
      expect(cp.chars.length, 1);
      expect(cp.chars[0], 'a');

      listAdvance(eng, cp, [0xc3, 0xb1]);
      expect(cp.chars.length, 2);
      expect(cp.chars[1], 'ñ');

      listAdvance(eng, cp, [0xe2, 0x81, 0xa1]);
      expect(cp.chars.length, 3);
      expect(cp.chars[2], '\u2061');

      listAdvance(eng, cp, [0xf0, 0x90, 0x8c, 0xbc]);
      expect(cp.chars.length, 4);
      expect(cp.chars[3], '𐌼');
    });

    test('Ž', () {
      final eng = Engine();
      final cp = MockProvider();

      stringAdvance(eng, cp, 'Ž');
      expect(cp.params.length, 0);
      expect(cp.chars.length, 1);
      expect(cp.chars[0], 'Ž');
    });
  });

  group('DCS >', () {
    test('πP>|term v1', () {
      final eng = Engine();
      final cp = MockProvider();

      stringAdvance(eng, cp, '\x1bP>|term v1\x1b\x5c');

      expect(cp.params.length, 1);
      expect(cp.params[0], ['>', '|', 'term v1']);
      expect(cp.chars.length, 0);
    });
  });
}
