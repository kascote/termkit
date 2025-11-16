import 'package:termparser/src/engine/parameters.dart';
import 'package:termparser/src/engine/sequence_data.dart';
import 'package:test/test.dart';

void main() {
  group('SequenceData >', () {
    group('CharData >', () {
      test('creates with char and escO flag', () {
        const data = CharData('a', escO: false);
        expect(data.char, 'a');
        expect(data.escO, false);
      });

      test('escO flag set for ESC O sequences', () {
        const data = CharData('R', escO: true);
        expect(data.char, 'R');
        expect(data.escO, true);
      });

      test('equality - identical objects', () {
        const data1 = CharData('a', escO: false);
        const data2 = CharData('a', escO: false);
        expect(data1, equals(data2));
      });

      test('equality - different char', () {
        const data1 = CharData('a', escO: false);
        const data2 = CharData('b', escO: false);
        expect(data1, isNot(equals(data2)));
      });

      test('equality - different escO', () {
        const data1 = CharData('R', escO: false);
        const data2 = CharData('R', escO: true);
        expect(data1, isNot(equals(data2)));
      });

      test('hashCode - consistent', () {
        const data = CharData('a', escO: false);
        expect(data.hashCode, equals(data.hashCode));
      });

      test('toString contains char and escO', () {
        const data = CharData('x', escO: true);
        final str = data.toString();
        expect(str, contains('x'));
        expect(str, contains('escO'));
      });
    });

    group('EscSequenceData >', () {
      test('creates with char', () {
        const data = EscSequenceData('W');
        expect(data.char, 'W');
      });

      test('equality - identical objects', () {
        const data1 = EscSequenceData('W');
        const data2 = EscSequenceData('W');
        expect(data1, equals(data2));
      });

      test('equality - different char', () {
        const data1 = EscSequenceData('W');
        const data2 = EscSequenceData('H');
        expect(data1, isNot(equals(data2)));
      });

      test('hashCode - consistent', () {
        const data = EscSequenceData('W');
        expect(data.hashCode, equals(data.hashCode));
      });

      test('toString contains char', () {
        const data = EscSequenceData('W');
        final str = data.toString();
        expect(str, contains('W'));
      });
    });

    group('CsiSequenceData >', () {
      test('creates with params and finalChar', () {
        const params = Parameters(['1', '2']);
        const data = CsiSequenceData(params, 'm');
        expect(data.params, params);
        expect(data.finalChar, 'm');
      });

      test('equality - identical objects', () {
        const params = Parameters(['1', '2']);
        const data1 = CsiSequenceData(params, 'm');
        const data2 = CsiSequenceData(params, 'm');
        expect(data1, equals(data2));
      });

      test('equality - different finalChar', () {
        const params = Parameters(['1', '2']);
        const data1 = CsiSequenceData(params, 'm');
        const data2 = CsiSequenceData(params, 'H');
        expect(data1, isNot(equals(data2)));
      });

      test('equality - different params', () {
        const data1 = CsiSequenceData(Parameters(['1', '2']), 'm');
        const data2 = CsiSequenceData(Parameters(['3', '4']), 'm');
        expect(data1, isNot(equals(data2)));
      });

      test('hashCode - consistent', () {
        const data = CsiSequenceData(Parameters(['1', '2']), 'm');
        expect(data.hashCode, equals(data.hashCode));
      });

      test('toString contains params and finalChar', () {
        const data = CsiSequenceData(Parameters(['1', '2']), 'm');
        final str = data.toString();
        expect(str, contains('m'));
      });
    });

    group('OscSequenceData >', () {
      test('creates with params', () {
        const params = Parameters(['11', 'rgb:11/22/33']);
        const data = OscSequenceData(params);
        expect(data.params, params);
      });

      test('equality - identical objects', () {
        const params = Parameters(['11', 'rgb:11/22/33']);
        const data1 = OscSequenceData(params);
        const data2 = OscSequenceData(params);
        expect(data1, equals(data2));
      });

      test('equality - different params', () {
        const data1 = OscSequenceData(Parameters(['11', 'rgb:11/22/33']));
        const data2 = OscSequenceData(Parameters(['10', 'rgb:ff/ff/ff']));
        expect(data1, isNot(equals(data2)));
      });

      test('hashCode - consistent', () {
        const data = OscSequenceData(Parameters(['11', 'rgb:11/22/33']));
        expect(data.hashCode, equals(data.hashCode));
      });

      test('toString contains params', () {
        const data = OscSequenceData(Parameters(['11', 'rgb:11/22/33']));
        final str = data.toString();
        expect(str, isNotEmpty);
      });
    });

    group('DcsSequenceData >', () {
      test('creates with params and contentBytes', () {
        const params = Parameters(['>', '|']);
        final contentBytes = [0x50, 0x3e, 0x7c, 0x74];
        final data = DcsSequenceData(params, contentBytes);
        expect(data.params, params);
        expect(data.contentBytes, contentBytes);
      });

      test('equality - identical objects', () {
        const params = Parameters(['>', '|']);
        final contentBytes = [0x50, 0x3e];
        final data1 = DcsSequenceData(params, contentBytes);
        final data2 = DcsSequenceData(params, contentBytes);
        expect(data1, equals(data2));
      });

      test('equality - different contentBytes', () {
        const params = Parameters(['>', '|']);
        const data1 = DcsSequenceData(params, [0x50]);
        const data2 = DcsSequenceData(params, [0x51]);
        expect(data1, isNot(equals(data2)));
      });

      test('hashCode - consistent', () {
        const params = Parameters(['>', '|']);
        const data = DcsSequenceData(params, [0x50, 0x3e]);
        expect(data.hashCode, equals(data.hashCode));
      });

      test('toString contains byte count', () {
        const params = Parameters(['>', '|']);
        const data = DcsSequenceData(params, [0x50, 0x3e, 0x7c]);
        final str = data.toString();
        expect(str, contains('3'));
        expect(str, contains('bytes'));
      });
    });

    group('TextBlockSequenceData >', () {
      test('creates with start/end params and contentBytes', () {
        const startParams = Parameters(['200']);
        const endParams = Parameters(['201']);
        final contentBytes = [0x61, 0x62, 0x63];
        final data = TextBlockSequenceData(startParams, '~', endParams, '~', contentBytes);
        expect(data.startParams, startParams);
        expect(data.startFinal, '~');
        expect(data.endParams, endParams);
        expect(data.endFinal, '~');
        expect(data.contentBytes, contentBytes);
      });

      test('equality - identical objects', () {
        const startParams = Parameters(['200']);
        const endParams = Parameters(['201']);
        final contentBytes = [0x61];
        final data1 = TextBlockSequenceData(startParams, '~', endParams, '~', contentBytes);
        final data2 = TextBlockSequenceData(startParams, '~', endParams, '~', contentBytes);
        expect(data1, equals(data2));
      });

      test('equality - different contentBytes', () {
        const startParams = Parameters(['200']);
        const endParams = Parameters(['201']);
        const data1 = TextBlockSequenceData(startParams, '~', endParams, '~', [0x61]);
        const data2 = TextBlockSequenceData(startParams, '~', endParams, '~', [0x62]);
        expect(data1, isNot(equals(data2)));
      });

      test('copyWith updates endParams', () {
        const startParams = Parameters(['200']);
        const endParams = Parameters(['201']);
        const data = TextBlockSequenceData(startParams, '~', Parameters([]), '', []);
        final updated = data.copyWith(endParams: endParams, endFinal: '~', contentBytes: [0x61]);
        expect(updated.endParams, endParams);
        expect(updated.endFinal, '~');
        expect(updated.contentBytes, [0x61]);
      });

      test('copyWith preserves original when no params provided', () {
        const startParams = Parameters(['200']);
        const endParams = Parameters(['201']);
        const data = TextBlockSequenceData(startParams, '~', endParams, '}', [0x61, 0x62]);
        final updated = data.copyWith();
        expect(updated.endParams, endParams);
        expect(updated.endFinal, '}');
        expect(updated.contentBytes, [0x61, 0x62]);
      });

      test('hashCode - consistent', () {
        const startParams = Parameters(['200']);
        const endParams = Parameters(['201']);
        const data = TextBlockSequenceData(startParams, '~', endParams, '~', [0x61]);
        expect(data.hashCode, equals(data.hashCode));
      });

      test('toString contains byte count', () {
        const startParams = Parameters(['200']);
        const endParams = Parameters(['201']);
        const data = TextBlockSequenceData(startParams, '~', endParams, '~', [0x61, 0x62]);
        final str = data.toString();
        expect(str, contains('2'));
        expect(str, contains('bytes'));
      });
    });

    group('ErrorSequenceData >', () {
      test('creates with all fields', () {
        const data = ErrorSequenceData(
          'Unexpected Esc',
          state: 'csiEntry',
          rawBytes: [0x1b],
          partialParameters: ['1', '2'],
          type: 'unexpectedEscape',
        );
        expect(data.message, 'Unexpected Esc');
        expect(data.state, 'csiEntry');
        expect(data.rawBytes, [0x1b]);
        expect(data.partialParameters, ['1', '2']);
        expect(data.type, 'unexpectedEscape');
      });

      test('creates with minimal fields', () {
        const data = ErrorSequenceData(
          'Error',
          state: 'ground',
          rawBytes: [],
          partialParameters: [],
        );
        expect(data.message, 'Error');
        expect(data.state, 'ground');
        expect(data.type, isNull);
      });

      test('equality - identical objects', () {
        const data1 = ErrorSequenceData(
          'Error',
          state: 'ground',
          rawBytes: [0x1b],
          partialParameters: [],
        );
        const data2 = ErrorSequenceData(
          'Error',
          state: 'ground',
          rawBytes: [0x1b],
          partialParameters: [],
        );
        expect(data1, equals(data2));
      });

      test('equality - different message', () {
        const data1 = ErrorSequenceData(
          'Error1',
          state: 'ground',
          rawBytes: [],
          partialParameters: [],
        );
        const data2 = ErrorSequenceData(
          'Error2',
          state: 'ground',
          rawBytes: [],
          partialParameters: [],
        );
        expect(data1, isNot(equals(data2)));
      });

      test('equality - different rawBytes', () {
        const data1 = ErrorSequenceData(
          'Error',
          state: 'ground',
          rawBytes: [0x1b, 0x5b],
          partialParameters: [],
        );
        const data2 = ErrorSequenceData(
          'Error',
          state: 'ground',
          rawBytes: [0x1b, 0x5d],
          partialParameters: [],
        );
        expect(data1, isNot(equals(data2)));
      });

      test('equality - different partialParameters', () {
        const data1 = ErrorSequenceData(
          'Error',
          state: 'ground',
          rawBytes: [],
          partialParameters: ['1', '2'],
        );
        const data2 = ErrorSequenceData(
          'Error',
          state: 'ground',
          rawBytes: [],
          partialParameters: ['1', '3'],
        );
        expect(data1, isNot(equals(data2)));
      });

      test('hashCode - consistent', () {
        const data = ErrorSequenceData(
          'Error',
          state: 'ground',
          rawBytes: [0x1b],
          partialParameters: ['1'],
        );
        expect(data.hashCode, equals(data.hashCode));
      });

      test('toString contains message and byte count', () {
        const data = ErrorSequenceData(
          'Test Error',
          state: 'ground',
          rawBytes: [0x1b, 0x5b],
          partialParameters: ['1'],
        );
        final str = data.toString();
        expect(str, contains('Test Error'));
        expect(str, contains('2'));
        expect(str, contains('bytes'));
        expect(str, contains('1'));
        expect(str, contains('params'));
      });
    });

    group('Pattern matching >', () {
      test('can switch on SequenceData type', () {
        const sequences = <SequenceData>[
          CharData('a', escO: false),
          EscSequenceData('W'),
          CsiSequenceData(Parameters(['1']), 'm'),
          OscSequenceData(Parameters(['11'])),
          DcsSequenceData(Parameters([]), []),
          TextBlockSequenceData(
            Parameters(['200']),
            '~',
            Parameters(['201']),
            '~',
            [],
          ),
          ErrorSequenceData('Error', state: 'ground', rawBytes: [], partialParameters: []),
        ];

        final types = <String>[];
        for (final seq in sequences) {
          final type = switch (seq) {
            CharData() => 'char',
            EscSequenceData() => 'esc',
            CsiSequenceData() => 'csi',
            OscSequenceData() => 'osc',
            DcsSequenceData() => 'dcs',
            TextBlockSequenceData() => 'textBlock',
            ErrorSequenceData() => 'error',
          };
          types.add(type);
        }

        expect(types, ['char', 'esc', 'csi', 'osc', 'dcs', 'textBlock', 'error']);
      });
    });
  });
}
