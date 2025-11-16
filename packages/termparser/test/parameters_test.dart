import 'package:termparser/src/engine/parameter_accumulator.dart';
import 'package:termparser/src/engine/parameters.dart';
import 'package:test/test.dart';

void main() {
  group('Parameters >', () {
    test('creates with values list', () {
      const params = Parameters(['1', '2', '3']);
      expect(params.values, ['1', '2', '3']);
    });

    test('creates with empty values', () {
      const params = Parameters([]);
      expect(params.values, isEmpty);
    });

    test('creates from ParameterAccumulator', () {
      final accumulator = ParameterAccumulator()
        ..add(0x31) // '1'
        ..store()
        ..add(0x32) // '2'
        ..store();

      final params = Parameters.from(accumulator);
      expect(params.values, ['1', '2']);
    });

    test('equality - identical values', () {
      const params1 = Parameters(['1', '2']);
      const params2 = Parameters(['1', '2']);
      expect(params1, equals(params2));
    });

    test('equality - different values', () {
      const params1 = Parameters(['1', '2']);
      const params2 = Parameters(['1', '3']);
      expect(params1, isNot(equals(params2)));
    });

    test('equality - different lengths', () {
      const params1 = Parameters(['1', '2']);
      const params2 = Parameters(['1']);
      expect(params1, isNot(equals(params2)));
    });

    test('equality - empty vs non-empty', () {
      const params1 = Parameters([]);
      const params2 = Parameters(['1']);
      expect(params1, isNot(equals(params2)));
    });

    test('hashCode - consistent', () {
      const params = Parameters(['1', '2']);
      expect(params.hashCode, equals(params.hashCode));
    });

    test('hashCode - equal objects have same hashCode', () {
      const params1 = Parameters(['1', '2']);
      const params2 = Parameters(['1', '2']);
      expect(params1.hashCode, equals(params2.hashCode));
    });

    test('values list is accessible', () {
      const params = Parameters(['a', 'b', 'c']);
      expect(params.values.length, 3);
      expect(params.values[0], 'a');
      expect(params.values[1], 'b');
      expect(params.values[2], 'c');
    });

    test('can iterate over values', () {
      const params = Parameters(['1', '2', '3']);
      final collected = <String>['b'];
      params.values.forEach(collected.add);
    });

    test('from() with empty accumulator', () {
      final accumulator = ParameterAccumulator();
      final params = Parameters.from(accumulator);
      expect(params.values, isEmpty);
    });

    test('from() with partial accumulator', () {
      final accumulator = ParameterAccumulator()
        ..add(0x31) // '1'
        ..store()
        ..add(0x32) // '2'
        ..store()
        ..add(0x33); // '3' - not stored yet

      final params = Parameters.from(accumulator);
      expect(params.values, ['1', '2']); // Only stored params
    });

    test('from() with complex CSI parameters', () {
      final accumulator = ParameterAccumulator()
        // Simulate parsing "97:65;2"
        ..add(0x39) // '9'
        ..add(0x37) // '7'
        ..add(0x3a) // ':'
        ..add(0x36) // '6'
        ..add(0x35) // '5'
        ..store()
        ..add(0x32) // '2'
        ..store();

      final params = Parameters.from(accumulator);
      expect(params.values, ['97:65', '2']);
    });

    test('from() with default parameters', () {
      final accumulator = ParameterAccumulator()
        // Simulate parsing ";;" (three default params)
        // Empty store() creates default '0' parameter
        ..store()
        ..store()
        ..store();

      final params = Parameters.from(accumulator);
      expect(params.values, ['0', '0', '0']);
    });

    test('toString includes values', () {
      const params = Parameters(['1', '2']);
      final str = params.toString();
      expect(str, contains('1'));
      expect(str, contains('2'));
    });
  });

  group('ParameterAccumulator >', () {
    test('getIgnoredCount tracks parameters beyond max limit', () {
      final accumulator = ParameterAccumulator();

      // Add 32 parameters (max is 30)
      for (var i = 0; i < 32; i++) {
        accumulator
          ..add(0x31) // '1'
          ..store();
      }

      expect(accumulator.getCount(), 30);
      expect(accumulator.getIgnoredCount(), 2);
    });
  });
}
