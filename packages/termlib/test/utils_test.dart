import 'package:termlib/src/shared/string_extension.dart';
import 'package:test/test.dart';

void main() {
  group('Utils >', () {
    test('dumpHex strings', () {
      expect(''.dumpHex(), equals(''));
      expect('a\x1bbc'.dumpHex(), equals('a0x1bbc'));
    });
    test('dumpHex hex strings', () {
      expect(''.dumpHex(onlyHex: true), equals(''));
      expect('a\x1bbc'.dumpHex(onlyHex: true), equals('0x61:0x1b:0x62:0x63:'));
    });
  });
}
