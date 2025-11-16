import 'dart:convert';

import 'package:termparser/src/engine/engine.dart';
import 'package:termparser/src/engine/sequence_data.dart';
import 'package:test/test.dart';

/// Helper to advance Engine with list of bytes
List<SequenceData> listAdvance(Engine engine, List<int> input, {bool hasMore = false}) {
  final results = <SequenceData>[];
  for (var i = 0; i < input.length; i++) {
    final result = engine.advance(input[i], hasMore: (i < (input.length - 1)) || hasMore);
    if (result != null) results.add(result);
  }
  return results;
}

/// Helper to advance Engine with string input
List<SequenceData> stringAdvance(Engine engine, String input, {bool hasMore = false}) {
  final bytes = utf8.encode(input);
  return listAdvance(engine, bytes, hasMore: hasMore);
}

void main() {
  group('Engine ESC >', () {
    test('char - no more input dispatches ESC immediately', () {
      final eng = Engine();

      // No more input means that the Esc character should be dispatched immediately
      final result = eng.advance(0x1b);
      if (result == null) throw Exception('Expected CharData, got null');
      expect(result, isA<CharData>());
      expect((result as CharData).char, '\x1b');
      expect(result.escO, false);
    });

    test('char - hasMore waits in escape state', () {
      final eng = Engine();

      // There's more input so the machine should wait before dispatching Esc character
      final result = eng.advance(0x1b, hasMore: true);
      expect(result, isNull); // waiting in escape state, no emission yet
      expect(eng.currentState, State.escape);
    });

    test('char - postponed ESC dispatch on second ESC', () {
      final eng = Engine();

      // First ESC with hasMore - waits
      var result = eng.advance(0x1b, hasMore: true);
      expect(result, isNull);

      // Another Esc character, but no more input, machine should dispatch the postponed Esc
      // character and then go back to escape state
      result = eng.advance(0x1b);
      if (result == null) throw Exception('Expected CharData, got null');
      expect(result, isA<CharData>());
      expect((result as CharData).char, '\x1b');

      // Now we're in escape state again, advance with no more input to dispatch second ESC
      result = eng.advance(0x1b);
      if (result == null) throw Exception('Expected CharData, got null');
      expect(result, isA<CharData>());
      expect((result as CharData).char, '\x1b');
    });

    test('without intermediates', () {
      final eng = Engine();

      const input = '\x1B0\x1B~';
      final results = stringAdvance(eng, input);

      expect(results.length, 2);
      expect(results[0], isA<EscSequenceData>());
      expect((results[0] as EscSequenceData).char, '0');
      expect(results[1], isA<EscSequenceData>());
      expect((results[1] as EscSequenceData).char, '~');
    });

    test('W', () {
      final eng = Engine();

      const input = '\x1BW';
      final results = stringAdvance(eng, input);

      expect(results.length, 1);
      expect(results[0], isA<EscSequenceData>());
      expect((results[0] as EscSequenceData).char, 'W');
    });

    test('OR - sets escO flag on CharData', () {
      final eng = Engine();

      final results = stringAdvance(eng, '\x1BOR');

      // ESC O is special - sets _escO flag, R becomes CharData with escO=true
      expect(results.length, 1);
      expect(results[0], isA<CharData>());
      final char = results[0] as CharData;
      expect(char.char, 'R');
      expect(char.escO, true); // This is what makes it special for parser to interpret as F3
    });

    test('ctrl-a', () {
      final eng = Engine();

      final results = stringAdvance(eng, '\x01');

      expect(results.length, 1);
      expect(results[0], isA<CharData>());
      expect((results[0] as CharData).char, '\x01');
    });

    test('ctrl-i', () {
      final eng = Engine();

      final results = stringAdvance(eng, '\x09');

      expect(results.length, 1);
      expect(results[0], isA<CharData>());
      expect((results[0] as CharData).char, '\x09');
    });

    test('ctrl-h', () {
      final eng = Engine();

      final results = stringAdvance(eng, '\x08');

      expect(results.length, 1);
      expect(results[0], isA<CharData>());
      expect((results[0] as CharData).char, '\x08');
    });
  });

  group('Engine CSI >', () {
    test('esc in CSI - generates error', () {
      final eng = Engine();

      final results = stringAdvance(eng, '\x1b[\x1b');

      // ESC [ ESC -> error is generated, state reset
      expect(results.length, 1);
      expect(results[0], isA<ErrorSequenceData>());
      final error = results[0] as ErrorSequenceData;
      expect(error.message, contains('Unexpected Esc'));
      expect(error.type, 'unexpectedEscape');
    });

    test('with ignore - no emission', () {
      final eng = Engine();

      final results = stringAdvance(eng, '\x1b[\x7f');

      expect(results, isEmpty);
    });

    test('without parameters - default param added', () {
      final eng = Engine();

      final results = stringAdvance(eng, '\x1b[m');

      expect(eng.collectedParameters.length, 1);
      expect(eng.collectedParameters, <String>['0']);
      expect(results.length, 1);
      expect(results[0], isA<CsiSequenceData>());
      final csi = results[0] as CsiSequenceData;
      expect(csi.params.values, <String>['0']);
      expect(csi.finalChar, 'm');
    });

    test('with two default parameters', () {
      final eng = Engine();

      final results = stringAdvance(eng, '\x1b[;m');

      expect(eng.collectedParameters.length, 2);
      expect(eng.collectedParameters, <String>['0', '0']);
      expect(results.length, 1);
      expect(results[0], isA<CsiSequenceData>());
      final csi = results[0] as CsiSequenceData;
      expect(csi.params.values, <String>['0', '0']);
      expect(csi.finalChar, 'm');
    });

    test('with parameters and sequence', () {
      final eng = Engine();

      final results = stringAdvance(eng, '\x1b[0:1;2:3;4:u');

      expect(eng.collectedParameters, <String>['0:1', '2:3', '4:']);
      expect(results.length, 1);
      expect(results[0], isA<CsiSequenceData>());
      final csi = results[0] as CsiSequenceData;
      expect(csi.params.values, <String>['0:1', '2:3', '4:']);
      expect(csi.finalChar, 'u');
    });

    test('with color space', () {
      final eng = Engine();

      final results = stringAdvance(eng, '\x1b[38:2::0:0:0m');

      expect(eng.collectedParameters, <String>['38:2::0:0:0']);
      expect(results.length, 1);
      expect(results[0], isA<CsiSequenceData>());
      final csi = results[0] as CsiSequenceData;
      expect(csi.params.values, <String>['38:2::0:0:0']);
      expect(csi.finalChar, 'm');
    });

    test('with trailing semicolon', () {
      final eng = Engine();

      final results = stringAdvance(eng, '\x1b[123;m');

      expect(eng.collectedParameters, <String>['123', '0']);
      expect(results.length, 1);
      expect(results[0], isA<CsiSequenceData>());
      final csi = results[0] as CsiSequenceData;
      expect(csi.params.values, <String>['123', '0']);
      expect(csi.finalChar, 'm');
    });

    test('max parameters', () {
      final eng = Engine();

      const input = '\x1b[1;2;3;4;5;6;7;8;9;10;11;12;13;14;15;16;17;18;19;20;21;22;23;24;25;26;27;28;29;30;31m';
      final results = stringAdvance(eng, input);

      // dart format off
      expect(eng.collectedParameters, <String>[
        '1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12', '13', '14', '15', '16', '17', '18', '19',
        '20', '21', '22', '23', '24', '25', '26', '27', '28', '29', '30',
      ]);
      // dart format on
      expect(results.length, 1);
      expect(results[0], isA<CsiSequenceData>());
      final csi = results[0] as CsiSequenceData;
      expect(csi.params.values.length, 30);
      expect(csi.finalChar, 'm');
    });

    test('with ignore in parameter state', () {
      final eng = Engine();

      final results = stringAdvance(eng, '\x1B[;1\x3Cc');

      expect(results, isEmpty);
    });

    test(r'?2026;2$y', () {
      final eng = Engine();

      final results = stringAdvance(eng, '\x1b[?2026;2\$y');

      expect(results.length, 1);
      expect(results[0], isA<CsiSequenceData>());
      final csi = results[0] as CsiSequenceData;
      // '?' is parsed as separate parameter
      expect(csi.params.values, <String>['?', '2026', '2']);
      expect(csi.finalChar, 'y');
    });
  });

  group('Engine CSI Bracketed Paste >', () {
    test('text - returns TextBlockSequenceData', () {
      final eng = Engine();

      const startPasteSeq = [0x1b, 0x5b, 0x32, 0x30, 0x30, 0x7E]; // ESC [ 2 0 0 ~
      const endPasteSeq = [0x1b, 0x5b, 0x32, 0x30, 0x31, 0x7E]; // ESC [ 2 0 1 ~

      final results = listAdvance(eng, [...startPasteSeq, 0x61, 0xc3, 0xb1, 0x63, ...endPasteSeq]);
      expect(results.length, 1);
      expect(results[0], isA<TextBlockSequenceData>());
      final textBlock = results[0] as TextBlockSequenceData;
      expect(textBlock.startParams.values, <String>['200']);
      expect(textBlock.startFinal, '~');
      expect(textBlock.endParams.values, <String>['201']);
      expect(textBlock.endFinal, '~');
      expect(textBlock.contentBytes, [0x61, 0xc3, 0xb1, 0x63]); // 'añc' in UTF-8
    });

    test('with control codes', () {
      final eng = Engine();

      final results = stringAdvance(eng, '\x1b[200~o\x1b[2D\x1b[201~');
      expect(results.length, 1);
      expect(results[0], isA<TextBlockSequenceData>());
    });

    test('paste content IS accumulated in sequence bytes', () {
      final eng = Engine();

      const startPasteSeq = [0x1b, 0x5b, 0x32, 0x30, 0x30, 0x7E]; // ESC [ 2 0 0 ~
      const pasteContent = [0x61, 0x62, 0x63, 0x64, 0x65]; // "abcde"

      listAdvance(eng, startPasteSeq);
      expect(eng.currentState, State.textBlock);

      final bytesBeforePaste = eng.currentSequenceBytes.length;
      listAdvance(eng, pasteContent);

      expect(eng.currentSequenceBytes.length, bytesBeforePaste + pasteContent.length);
    });
  });

  group('Engine CSI Mouse >', () {
    test('csi sgr mouse', () {
      final eng = Engine();

      final results = stringAdvance(eng, '\x1b[<35;1;2m');

      expect(results.length, 1);
      expect(results[0], isA<CsiSequenceData>());
      final csi = results[0] as CsiSequenceData;
      // '<' is parsed as separate parameter
      expect(csi.params.values, <String>['<', '35', '1', '2']);
      expect(csi.finalChar, 'm');
    });

    test('csi sgr mouse M', () {
      final eng = Engine();

      final results = stringAdvance(eng, '\x1b[<35;1;2M');

      expect(results.length, 1);
      expect(results[0], isA<CsiSequenceData>());
      final csi = results[0] as CsiSequenceData;
      // '<' is parsed as separate parameter
      expect(csi.params.values, <String>['<', '35', '1', '2']);
      expect(csi.finalChar, 'M');
    });
  });

  group('Engine CSI Focus >', () {
    test('csi focus in', () {
      final eng = Engine();

      final results = stringAdvance(eng, '\x1b[I');

      expect(results.length, 1);
      expect(results[0], isA<CsiSequenceData>());
      final csi = results[0] as CsiSequenceData;
      expect(csi.finalChar, 'I');
    });
  });

  group('Engine CSI keyboard enhancement >', () {
    test('csi ? 1 u', () {
      final eng = Engine();

      final results = stringAdvance(eng, '\x1b[?1u');

      expect(results.length, 1);
      expect(results[0], isA<CsiSequenceData>());
      final csi = results[0] as CsiSequenceData;
      // '?' is parsed as separate parameter
      expect(csi.params.values, <String>['?', '1']);
      expect(csi.finalChar, 'u');
    });

    test('.[97u', () {
      final eng = Engine();

      final results = stringAdvance(eng, '\x1b[97u');
      expect(results.length, 1);
      expect(results[0], isA<CsiSequenceData>());
      final csi = results[0] as CsiSequenceData;
      expect(csi.params.values, <String>['97']);
      expect(csi.finalChar, 'u');
    });

    test('.[97:65;2u', () {
      final eng = Engine();

      final results = stringAdvance(eng, '\x1b[97:65;2u');

      expect(results.length, 1);
      expect(results[0], isA<CsiSequenceData>());
      final csi = results[0] as CsiSequenceData;
      expect(csi.params.values, <String>['97:65', '2']);
      expect(csi.finalChar, 'u');
    });

    test('.[127u', () {
      final eng = Engine();

      final results = stringAdvance(eng, '\x1b[127u');

      expect(results.length, 1);
      expect(results[0], isA<CsiSequenceData>());
      final csi = results[0] as CsiSequenceData;
      expect(csi.params.values, <String>['127']);
      expect(csi.finalChar, 'u');
    });

    test('.[127;1:3u', () {
      final eng = Engine();

      final results = stringAdvance(eng, '\x1b[127;1:3u');

      expect(results.length, 1);
      expect(results[0], isA<CsiSequenceData>());
      final csi = results[0] as CsiSequenceData;
      expect(csi.params.values, <String>['127', '1:3']);
      expect(csi.finalChar, 'u');
    });

    test('.[127::8;2u', () {
      final eng = Engine();

      final results = stringAdvance(eng, '\x1b[127::8;2u');

      expect(results.length, 1);
      expect(results[0], isA<CsiSequenceData>());
      final csi = results[0] as CsiSequenceData;
      expect(csi.params.values, <String>['127::8', '2']);
      expect(csi.finalChar, 'u');
    });

    test('.[6;5:3~', () {
      final eng = Engine();

      final results = stringAdvance(eng, '\x1b[6;5:3~');

      expect(results.length, 1);
      expect(results[0], isA<CsiSequenceData>());
      final csi = results[0] as CsiSequenceData;
      expect(csi.params.values, <String>['6', '5:3']);
      expect(csi.finalChar, '~');
    });
  });

  group('Engine OSC >', () {
    test('1', () {
      final eng = Engine();

      final results = stringAdvance(eng, '\x1b]11;rgb:11/22/33\x1b\\');
      expect(eng.collectedParameters, <String>['11', 'rgb:11/22/33']);
      expect(results.length, 1);
      expect(results[0], isA<OscSequenceData>());
      final osc = results[0] as OscSequenceData;
      expect(osc.params.values, <String>['11', 'rgb:11/22/33']);
    });
  });

  group('Engine UTF8 >', () {
    test('parse utf8 characters', () {
      final eng = Engine();

      var results = stringAdvance(eng, 'a');
      expect(results.length, 1);
      expect(results[0], isA<CharData>());
      expect((results[0] as CharData).char, 'a');

      results = listAdvance(eng, [0xc3, 0xb1]);
      expect(results.length, 1);
      expect(results[0], isA<CharData>());
      expect((results[0] as CharData).char, 'ñ');

      results = listAdvance(eng, [0xe2, 0x81, 0xa1]);
      expect(results.length, 1);
      expect(results[0], isA<CharData>());
      expect((results[0] as CharData).char, '\u2061');

      results = listAdvance(eng, [0xf0, 0x90, 0x8c, 0xbc]);
      expect(results.length, 1);
      expect(results[0], isA<CharData>());
      expect((results[0] as CharData).char, '𐌼');
    });

    test('Ž', () {
      final eng = Engine();

      final results = stringAdvance(eng, 'Ž');
      expect(results.length, 1);
      expect(results[0], isA<CharData>());
      expect((results[0] as CharData).char, 'Ž');
    });
  });

  group('Engine DCS >', () {
    test('πP>|term v1', () {
      final eng = Engine();

      final results = stringAdvance(eng, '\x1bP>|term v1\x1b\x5c');

      expect(results.length, 1);
      expect(results[0], isA<DcsSequenceData>());
      final dcs = results[0] as DcsSequenceData;
      // DCS params are parsed as separate values
      expect(dcs.params.values.isNotEmpty, true);
      // contentBytes contains all raw bytes from the sequence
      // The Parser layer extracts meaning from these bytes
      // For this short DCS sequence, we just verify we got DcsSequenceData
    });
  });

  group('Engine Debug >', () {
    test('isIntermediateState in ground', () {
      final eng = Engine();
      expect(eng.isIntermediateState, false);
    });

    test('isIntermediateState in escape', () {
      final eng = Engine()..advance(0x1b, hasMore: true);
      expect(eng.isIntermediateState, true);
    });

    test('currentStateName', () {
      final eng = Engine();
      expect(eng.currentStateName, 'ground');
      eng.advance(0x1b, hasMore: true);
      expect(eng.currentStateName, 'escape');
    });

    test('debugInfo contains state', () {
      final eng = Engine();
      final info = eng.debugInfo();
      expect(info, contains('State'));
      expect(info, contains('ground'));
    });
  });

  group('Engine Escape Intermediate >', () {
    test('ESC with intermediate byte', () {
      final eng = Engine();
      // ESC followed by intermediate byte (0x20-0x2F)
      listAdvance(eng, [0x1b, 0x20], hasMore: true);
      expect(eng.currentStateName, 'escapeIntermediate');
    });

    test('control chars in escape intermediate', () {
      final eng = Engine();
      // ESC, intermediate, then control char
      final results = listAdvance(eng, [0x1b, 0x20, 0x01]);
      expect(results.length, 1);
      expect(results[0], isA<CharData>());
    });
  });

  group('Engine Ground State Characters >', () {
    test('control characters 0x00-0x17', () {
      final eng = Engine();
      // Test control character in range (e.g., 0x01)
      final results = listAdvance(eng, [0x01]);
      expect(results.length, 1);
      expect(results[0], isA<CharData>());
    });

    test('control character 0x19', () {
      final eng = Engine();
      final results = listAdvance(eng, [0x19]);
      expect(results.length, 1);
      expect(results[0], isA<CharData>());
    });

    test('printable ASCII characters', () {
      final eng = Engine();
      // Test printable char (e.g., space 0x20)
      final results = listAdvance(eng, [0x20]);
      expect(results.length, 1);
      expect(results[0], isA<CharData>());
      expect((results[0] as CharData).char, ' ');
    });
  });
}
