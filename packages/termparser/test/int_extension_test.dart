import 'package:termparser/src/extensions/int_extension.dart';
import 'package:test/test.dart';

void main() {
  group('IntUtils extension >', () {
    group('saturatingMul >', () {
      test('normal multiplication', () {
        expect(10.saturatingMul(5), 50);
        expect(100.saturatingMul(2), 200);
        expect(0.saturatingMul(100), 0);
      });

      test('saturates at max int32', () {
        const maxInt = 0x7FFFFFFF;
        expect(maxInt.saturatingMul(2), maxInt);
        expect(1000000.saturatingMul(10000), maxInt);
      });

      test('large values', () {
        expect(0x3FFFFFFF.saturatingMul(2), 0x7FFFFFFE);
        expect(0x40000000.saturatingMul(2), 0x7FFFFFFF);
      });
    });

    group('saturatingAdd >', () {
      test('normal addition', () {
        expect(10.saturatingAdd(5), 15);
        expect(100.saturatingAdd(200), 300);
        expect(0.saturatingAdd(0), 0);
      });

      test('saturates at max int32', () {
        const maxInt = 0x7FFFFFFF;
        expect(maxInt.saturatingAdd(1), maxInt);
        expect(maxInt.saturatingAdd(100), maxInt);
        expect(0x7FFFFFFE.saturatingAdd(1), 0x7FFFFFFF);
      });

      test('large values', () {
        expect(0x7FFFFFFE.saturatingAdd(1), 0x7FFFFFFF);
        expect(0x7FFFFFFD.saturatingAdd(2), 0x7FFFFFFF);
      });
    });

    group('saturatingSub >', () {
      test('normal subtraction', () {
        expect(10.saturatingSub(5), 5);
        expect(100.saturatingSub(50), 50);
        expect(0.saturatingSub(0), 0);
      });

      test('saturates at 0', () {
        expect(5.saturatingSub(10), 0);
        expect(0.saturatingSub(1), 0);
        expect(100.saturatingSub(200), 0);
      });

      test('edge cases', () {
        expect(1.saturatingSub(1), 0);
        expect(1.saturatingSub(2), 0);
        expect(2.saturatingSub(1), 1);
      });
    });

    group('toHexString >', () {
      test('basic values with default padding', () {
        expect(0.toHexString(), '00');
        expect(1.toHexString(), '01');
        expect(10.toHexString(), '0a');
        expect(15.toHexString(), '0f');
        expect(16.toHexString(), '10');
        expect(255.toHexString(), 'ff');
      });

      test('with custom padding', () {
        expect(1.toHexString(padding: 4), '0001');
        expect(255.toHexString(padding: 4), '00ff');
        expect(0x1234.toHexString(padding: 4), '1234');
      });

      test('no padding', () {
        expect(0.toHexString(padding: 0), '0');
        expect(15.toHexString(padding: 0), 'f');
        expect(255.toHexString(padding: 0), 'ff');
      });

      test('common byte values', () {
        expect(0x1B.toHexString(), '1b');
        expect(0x5B.toHexString(), '5b');
        expect(0x41.toHexString(), '41');
      });
    });

    group('isSet >', () {
      test('single bit', () {
        expect(0x01.isSet(0x01), isTrue);
        expect(0x02.isSet(0x02), isTrue);
        expect(0x04.isSet(0x04), isTrue);
        expect(0x08.isSet(0x08), isTrue);
      });

      test('multiple bits', () {
        expect(0x0F.isSet(0x0F), isTrue);
        expect(0xFF.isSet(0xFF), isTrue);
        expect(0x0F.isSet(0x03), isTrue);
        expect(0x0F.isSet(0x05), isTrue);
      });

      test('bit not set', () {
        expect(0x01.isSet(0x02), isFalse);
        expect(0x0F.isSet(0x10), isFalse);
        expect(0x00.isSet(0x01), isFalse);
      });

      test('partial match is false', () {
        expect(0x03.isSet(0x07), isFalse); // has 0x03 but not full 0x07
        expect(0x05.isSet(0x0F), isFalse); // has some bits but not all
      });
    });

    group('isPrintable >', () {
      test('printable ASCII range (0x20-0x7E)', () {
        expect(0x20.isPrintable, isTrue); // space
        expect(0x41.isPrintable, isTrue); // 'A'
        expect(0x61.isPrintable, isTrue); // 'a'
        expect(0x7E.isPrintable, isTrue); // '~'
      });

      test('non-printable ASCII control characters', () {
        expect(0x00.isPrintable, isFalse); // NUL
        expect(0x1B.isPrintable, isFalse); // ESC
        expect(0x1F.isPrintable, isFalse); // before space
        expect(0x7F.isPrintable, isFalse); // DEL
      });

      test('Latin-1 printable range (0xA1-0xFF)', () {
        expect(0xA1.isPrintable, isTrue); // ¡
        expect(0xC0.isPrintable, isTrue); // À
        expect(0xFF.isPrintable, isTrue); // ÿ
      });

      test('soft hyphen is not printable', () {
        expect(0xAD.isPrintable, isFalse);
      });

      test('Latin-1 non-printable (0x80-0xA0)', () {
        expect(0x80.isPrintable, isFalse);
        expect(0x9F.isPrintable, isFalse);
        expect(0xA0.isPrintable, isFalse); // non-breaking space
      });

      test('beyond Latin-1', () {
        expect(0x100.isPrintable, isFalse);
        expect(0x1000.isPrintable, isFalse);
      });
    });
  });
}
