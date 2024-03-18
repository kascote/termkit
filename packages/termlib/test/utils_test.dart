import 'package:termlib/src/shared/int_extension.dart';
import 'package:termlib/src/shared/string_extension.dart';
import 'package:test/test.dart';

void main() {
  group('String extension >', () {
    test('dumpHex strings', () {
      expect(''.dumpHex(), equals(''));
      expect('a\x1bbc'.dumpHex(), equals('a0x1bbc'));
    });
    test('dumpHex hex strings', () {
      expect(''.dumpHex(onlyHex: true), equals(''));
      expect('a\x1bbc'.dumpHex(onlyHex: true), equals('0x61:0x1b:0x62:0x63:'));
    });
  });

  group('Int extension >', () {
    test('dumpHex strings', () {
      expect(28.toHexString(), equals('1c'));
    });

    test('saturatingSub', () {
      expect(0.saturatingSub(1), equals(0));
      expect(1.saturatingSub(1), equals(0));
      expect(1.saturatingSub(2), equals(0));
      expect(2.saturatingSub(1), equals(1));
    });

    test('isSet', () {
      expect(0.isSet(1), isFalse);
      expect(1.isSet(1), isTrue);
      expect(2.isSet(1), isFalse);
      expect(3.isSet(1), isTrue);
    });

    test('isNotSet', () {
      expect(0.isNotSet(1), isTrue);
      expect(1.isNotSet(1), isFalse);
      expect(2.isNotSet(1), isTrue);
      expect(3.isNotSet(1), isFalse);
    });
  });
}
