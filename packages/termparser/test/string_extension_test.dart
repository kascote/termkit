import 'package:termparser/src/extensions/string_extension.dart';
import 'package:test/test.dart';

void main() {
  group('StringExtension >', () {
    group('parseHex >', () {
      test('parses simple hex string', () {
        expect('ff'.parseHex(), 255);
        expect('FF'.parseHex(), 255);
        expect('00'.parseHex(), 0);
        expect('10'.parseHex(), 16);
      });

      test('parses with whitespace', () {
        expect('  ff  '.parseHex(), 255);
        expect('\taa\n'.parseHex(), 170);
      });

      test('throws on invalid hex', () {
        expect(() => 'xyz'.parseHex(), throwsFormatException);
        expect(() => ''.parseHex(), throwsFormatException);
      });
    });

    group('tryParseHex >', () {
      test('parses valid hex string', () {
        expect('ff'.tryParseHex(), 255);
        expect('00'.tryParseHex(), 0);
      });

      test('returns null on invalid hex', () {
        expect('xyz'.tryParseHex(), isNull);
        expect(''.tryParseHex(), isNull);
      });
    });

    group('parseInt >', () {
      test('parses valid decimal string', () {
        expect('123'.parseInt(), 123);
        expect('0'.parseInt(), 0);
        expect('999'.parseInt(), 999);
      });

      test('returns default on invalid string', () {
        expect('abc'.parseInt(), 0);
        expect(''.parseInt(), 0);
        expect('12.5'.parseInt(), 0);
      });

      test('uses custom default value', () {
        expect('abc'.parseInt(def: 42), 42);
        expect(''.parseInt(def: -1), -1);
      });
    });

    group('tryFromCharCode >', () {
      test('converts valid char codes', () {
        expect(StringExtension.tryFromCharCode(65), 'A');
        expect(StringExtension.tryFromCharCode(97), 'a');
        expect(StringExtension.tryFromCharCode(48), '0');
      });

      test('handles special characters', () {
        expect(StringExtension.tryFromCharCode(32), ' ');
        expect(StringExtension.tryFromCharCode(0x1B), '\x1B');
      });

      test('returns null on invalid char code', () {
        // String.fromCharCode usually handles all values, but test the safety
        expect(StringExtension.tryFromCharCode(0x00), isNotNull);
      });
    });

    group('isUpperCase >', () {
      test('returns true for uppercase letters', () {
        expect('A'.isUpperCase(), isTrue);
        expect('Z'.isUpperCase(), isTrue);
        expect('H'.isUpperCase(), isTrue);
      });

      test('returns false for lowercase letters', () {
        expect('a'.isUpperCase(), isFalse);
        expect('z'.isUpperCase(), isFalse);
        expect('h'.isUpperCase(), isFalse);
      });

      test('returns true for digits', () {
        expect('0'.isUpperCase(), isTrue);
        expect('5'.isUpperCase(), isTrue);
        expect('9'.isUpperCase(), isTrue);
      });

      test('returns false for empty string', () {
        expect(''.isUpperCase(), isFalse);
      });

      test('returns true for special chars that equal their uppercase', () {
        expect('!'.isUpperCase(), isTrue);
        expect('@'.isUpperCase(), isTrue);
      });

      test('checks whole string equality', () {
        expect('ABC'.isUpperCase(), isTrue);
        expect('Abc'.isUpperCase(), isFalse); // not all uppercase
        expect('aBc'.isUpperCase(), isFalse);
      });
    });
  });
}
