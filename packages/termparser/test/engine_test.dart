import 'package:termparser/termparser.dart';
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

    test('csi bracketed paste', () {
      final eng = Engine();
      final cp = MockProvider();

      const startPasteSeq = [0x1b, 0x5b, 0x32, 0x30, 0x30, 0x7E]; // ESC [ 2 0 0 ~
      const endPasteSeq = [0x1b, 0x5b, 0x32, 0x30, 0x31, 0x7E]; // ESC [ 2 0 1 ~

      listAdvance(eng, cp, [...startPasteSeq, 0x61, 0xc3, 0xb1, 0x63, ...endPasteSeq]);
      expect(cp.block, 'añc');
      expect(cp.chars.length, 1);
      expect(cp.chars[0], '~');
      expect(cp.params[0], <String>['200', '201']);
    });

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

    test('csi focus in', () {
      final eng = Engine();
      final cp = MockProvider();

      stringAdvance(eng, cp, '\x1b[I');

      expect(cp.params.length, 1);
      expect(cp.chars.length, 1);
      expect(cp.chars[0], 'I');
    });

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
  });

  group('OSC', () {
    test('1', () {
      final eng = Engine();
      final cp = MockProvider();

      stringAdvance(eng, cp, '\x1b]11;rgb:11/22/33\x1b\\');
      expect(cp.params.length, 1);
      expect(cp.params[0], ['11']);
      expect(cp.block, 'rgb:11/22/33');
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
  });
}
