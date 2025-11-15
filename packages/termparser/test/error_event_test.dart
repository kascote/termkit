import 'package:termparser/termparser_events.dart';
import 'package:test/test.dart';

void main() {
  group('EngineErrorEvent >', () {
    test('constructor with defaults', () {
      const event = EngineErrorEvent([]);
      expect(event.params, isEmpty);
      expect(event.char, isEmpty);
      expect(event.block, isEmpty);
      expect(event.message, isEmpty);
      expect(event.type, EngineErrorType.malformedSequence);
      expect(event.rawBytes, isEmpty);
      expect(event.stateAtError, isEmpty);
      expect(event.failingByte, isNull);
      expect(event.partialParameters, isEmpty);
    });

    test('constructor with all parameters', () {
      const event = EngineErrorEvent(
        ['1', '2'],
        char: 'A',
        block: [0x41, 0x42],
        message: 'test error',
        type: EngineErrorType.invalidParameter,
        rawBytes: [0x1B, 0x5B],
        stateAtError: 'csiParameter',
        failingByte: 0x5B,
        partialParameters: ['1'],
      );

      expect(event.params, ['1', '2']);
      expect(event.char, 'A');
      expect(event.block, [0x41, 0x42]);
      expect(event.message, 'test error');
      expect(event.type, EngineErrorType.invalidParameter);
      expect(event.rawBytes, [0x1B, 0x5B]);
      expect(event.stateAtError, 'csiParameter');
      expect(event.failingByte, 0x5B);
      expect(event.partialParameters, ['1']);
    });

    test('equality - identical events', () {
      const event1 = EngineErrorEvent(
        ['1', '2'],
        char: 'A',
        message: 'error',
        type: EngineErrorType.invalidParameter,
      );
      const event2 = EngineErrorEvent(
        ['1', '2'],
        char: 'A',
        message: 'error',
        type: EngineErrorType.invalidParameter,
      );

      expect(event1, equals(event2));
      expect(event1.hashCode, equals(event2.hashCode));
    });

    test('equality - different params', () {
      const event1 = EngineErrorEvent(['1']);
      const event2 = EngineErrorEvent(['2']);

      expect(event1, isNot(equals(event2)));
    });

    test('equality - different char', () {
      const event1 = EngineErrorEvent([], char: 'A');
      const event2 = EngineErrorEvent([], char: 'B');

      expect(event1, isNot(equals(event2)));
    });

    test('equality - different message', () {
      const event1 = EngineErrorEvent([], message: 'error1');
      const event2 = EngineErrorEvent([], message: 'error2');

      expect(event1, isNot(equals(event2)));
    });

    test('equality - different type', () {
      const event1 = EngineErrorEvent([], type: EngineErrorType.unsupportedSequence);
      const event2 = EngineErrorEvent([], type: EngineErrorType.invalidParameter);

      expect(event1, isNot(equals(event2)));
    });

    test('equality - different rawBytes', () {
      const event1 = EngineErrorEvent([], rawBytes: [0x1B]);
      const event2 = EngineErrorEvent([], rawBytes: [0x5B]);

      expect(event1, isNot(equals(event2)));
    });

    test('equality - different stateAtError', () {
      const event1 = EngineErrorEvent([], stateAtError: 'ground');
      const event2 = EngineErrorEvent([], stateAtError: 'escape');

      expect(event1, isNot(equals(event2)));
    });

    test('equality - different failingByte', () {
      const event1 = EngineErrorEvent([], failingByte: 0x1B);
      const event2 = EngineErrorEvent([], failingByte: 0x5B);

      expect(event1, isNot(equals(event2)));
    });

    test('equality - different partialParameters', () {
      const event1 = EngineErrorEvent([], partialParameters: ['1']);
      const event2 = EngineErrorEvent([], partialParameters: ['2']);

      expect(event1, isNot(equals(event2)));
    });

    test('toString - basic message', () {
      const event = EngineErrorEvent([], message: 'test error');
      final str = event.toString();

      expect(str, contains('Engine error: test error'));
    });

    test('toString - with rawBytes', () {
      const event = EngineErrorEvent(
        [],
        message: 'test error',
        rawBytes: [0x1B, 0x5B, 0x41],
      );
      final str = event.toString();

      expect(str, contains('Engine error: test error'));
      expect(str, contains('Sequence:'));
      expect(str, contains('1b'));
      expect(str, contains('5b'));
      expect(str, contains('41'));
    });

    test('toString - with rawBytes containing ESC', () {
      const event = EngineErrorEvent(
        [],
        message: 'test error',
        rawBytes: [0x1B, 0x5B],
      );
      final str = event.toString();

      expect(str, contains('ESC'));
    });

    test('toString - with rawBytes containing printable chars', () {
      const event = EngineErrorEvent(
        [],
        message: 'test error',
        rawBytes: [0x41, 0x42, 0x43], // ABC
      );
      final str = event.toString();

      expect(str, contains('A'));
      expect(str, contains('B'));
      expect(str, contains('C'));
    });

    test('toString - with rawBytes containing non-printable chars', () {
      const event = EngineErrorEvent(
        [],
        message: 'test error',
        rawBytes: [0x00, 0x01, 0x02],
      );
      final str = event.toString();

      expect(str, contains('Sequence:'));
      expect(str, contains('.'));
    });

    test('toString - with partialParameters', () {
      const event = EngineErrorEvent(
        [],
        message: 'test error',
        partialParameters: ['1', '2', '3'],
      );
      final str = event.toString();

      expect(str, contains('Partial params:'));
      expect(str, contains('"1"'));
      expect(str, contains('"2"'));
      expect(str, contains('"3"'));
    });

    test('toString - complex case with all fields', () {
      const event = EngineErrorEvent(
        ['1', '2'],
        message: 'complex error',
        rawBytes: [0x1B, 0x5B, 0x31, 0x3B],
        partialParameters: ['1', '2'],
      );
      final str = event.toString();

      expect(str, contains('Engine error: complex error'));
      expect(str, contains('Sequence:'));
      expect(str, contains('Partial params:'));
    });

    test('hashCode - consistent', () {
      const event = EngineErrorEvent(['1', '2'], message: 'error');

      expect(event.hashCode, equals(event.hashCode));
    });

    test('hashCode - equal objects have same hashCode', () {
      const event1 = EngineErrorEvent(['1'], message: 'error');
      const event2 = EngineErrorEvent(['1'], message: 'error');

      expect(event1.hashCode, equals(event2.hashCode));
    });

    test('is ErrorEvent', () {
      const event = EngineErrorEvent([]);
      expect(event, isA<ErrorEvent>());
    });

    test('all error types', () {
      expect(EngineErrorType.values, contains(EngineErrorType.malformedSequence));
      expect(EngineErrorType.values, contains(EngineErrorType.unsupportedSequence));
      expect(EngineErrorType.values, contains(EngineErrorType.invalidParameter));
      expect(EngineErrorType.values, contains(EngineErrorType.unexpectedEscape));
    });
  });
}
