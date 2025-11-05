import 'dart:async';
import 'dart:convert';

import 'package:termunicode/term_ucd.dart';
import 'package:test/test.dart';

const ucdFile = '''
# Comments should be skipped
# rune;  bool;  uint; int; float; runes; # Y
0..0005; Y;     0;    2;      -5.25 ;  0 1   2 3   4 5;
6..0007; Yes  ; 6;    1;     -4.25  ;  0006 0007;
8;       T ;    8 ;   0 ;-3.25  ;;# T
9;       True  ;9  ;  -1;-2.25  ;  0009;

# more comments to be ignored
@Part0

A;       N;   10  ;   -2;  -1.25; ;# N
B;       No;   11 ;   -3;  -0.25;
C;        False;12;   -4;   0.75;
D;        ;13;-5;1.75;

@Part1   # Another part.
# We test part comments get removed by not commenting the next line.
E..10FFFF; F;   14  ; -6;   2.75;

# A legacy rune range.
3400;<CJK Ideograph Extension A, First>; 13312; -7; 3.75;
4DB5;<CJK Ideograph Extension A, Last>; 13312; -7; 3.75;
''';

Stream<String> linesStream(String multilineString) async* {
  final lines = const LineSplitter().convert(multilineString);

  for (final line in lines) {
    yield line;
  }
}

final ranges = <({int start, int end})>[
  (start: 0x00, end: 0x05),
  (start: 0x06, end: 0x07),
  (start: 0x08, end: 0x08),
  (start: 0x09, end: 0x09),
  (start: 0x0A, end: 0x0A),
  (start: 0x0B, end: 0x0B),
  (start: 0x0C, end: 0x0C),
  (start: 0x0D, end: 0x0D),
  (start: 0x0E, end: 0x10FFFF),
  (start: 0x3400, end: 0x4DB5),
];

void main() {
  group('ucd parser', () {
    test('parse file', () async {
      final parts = [
        ['Part0', ''],
        ['Part1', 'Another part.'],
      ];

      var idx = -1;

      final p = UcdParser.parseStream(
        linesStream(ucdFile),
        (row) {
          idx++;
          // stdout.writeln('OUT ${row.line}:idx$idx - ${row.fields} - ERROR: ${row.error}');
          final range = ranges[idx];
          expect(row.rangeStart, range.start, reason: '$idx:Range Start ${row.rangeStart} != ${range.start}');
          expect(row.rangeEnd, range.end, reason: '$idx:Range End ${row.rangeEnd} != ${range.end}');

          if ((row.rangeStart == row.rangeEnd) && (row.getRune(0) != row.rangeStart)) {
            throw Exception('$idx:rune(0) != rangeStart');
          }

          if ((row.rangeStart < 9) && (!row.getBool(1))) {
            throw Exception('$idx:bool(1) != true');
          }

          if (row.getRune(4) >= 0 || row.error.isEmpty) {
            throw Exception('$idx:getRune(${row.getString(4)}) must return error');
          }

          row.error = '';

          if (row.getUint(2) != row.rangeStart) {
            throw Exception('$idx:getUint(2) ${row.getUint(2)} != ${row.rangeStart}');
          }

          final tmpi = row.getInt(3);
          if (tmpi != (2 - idx)) {
            throw Exception('$idx:getInt(3) ${row.getInt(3)} != ${2 - idx}');
          }

          final tmpf = row.getFloat(4);
          if (tmpf != (-5.25 + idx)) {
            throw Exception('$idx:getFloat(4) ${row.getFloat(4)} != ${-5.25 + idx}');
          }

          final tmpr = row.getRunes(5);
          if (tmpr.isEmpty) {
            if (row.getString(5).isNotEmpty) {
              throw Exception('$idx:getRunes(5) ${row.getString(5)} is not empty');
            }
          } else {
            if (tmpr[0] != row.rangeStart && tmpr[tmpr.length - 1] != row.rangeEnd) {
              throw Exception(
                '$idx:getRunes(5) ${tmpr[0]} != ${row.rangeStart} || ${tmpr[tmpr.length - 1]} != ${row.rangeEnd}',
              );
            }
          }

          if (row.comment.isNotEmpty && row.getString(1) != row.comment) {
            throw Exception('$idx:comment ${row.comment} must ${row.getString(1)}');
          }
        },
        onPart: (row) {
          if (parts.isEmpty) throw Exception('onPart called multiple times');
          final part = parts.removeAt(0);
          expect(row.fields[0], part[0]);
          expect(row.comment, part[1]);
        },
      );

      await p.parse();
    });

    test('error field - invalid boolean', () async {
      const testData = '0041;InvalidBool;# Test\n';
      var errorSet = false;

      final parser = UcdParser.parseStream(
        linesStream(testData),
        (row) {
          final result = row.getBool(1);
          expect(result, false); // Returns false on error
          expect(row.error, isNotEmpty);
          expect(row.error, contains('invalid boolean value'));
          errorSet = true;
        },
      );

      await parser.parse();
      expect(errorSet, true);
    });

    test('error field - invalid unsigned integer', () async {
      const testData = '0041;NotANumber;# Test\n';
      var errorSet = false;

      final parser = UcdParser.parseStream(
        linesStream(testData),
        (row) {
          final result = row.getUint(1);
          expect(result, -1); // Returns -1 on error
          expect(row.error, isNotEmpty);
          expect(row.error, contains('invalid unsigned integer value'));
          errorSet = true;
        },
      );

      await parser.parse();
      expect(errorSet, true);
    });

    test('error field - negative value for unsigned integer', () async {
      const testData = '0041;-123;# Test\n';
      var errorSet = false;

      final parser = UcdParser.parseStream(
        linesStream(testData),
        (row) {
          final result = row.getUint(1);
          expect(result, -1); // Returns -1 on error
          expect(row.error, isNotEmpty);
          expect(row.error, contains('invalid unsigned integer value'));
          errorSet = true;
        },
      );

      await parser.parse();
      expect(errorSet, true);
    });

    test('error field - invalid integer', () async {
      const testData = '0041;NotAnInt;# Test\n';
      var errorSet = false;

      final parser = UcdParser.parseStream(
        linesStream(testData),
        (row) {
          final result = row.getInt(1);
          expect(result, -1); // Returns -1 on error
          expect(row.error, isNotEmpty);
          expect(row.error, contains('invalid integer value'));
          errorSet = true;
        },
      );

      await parser.parse();
      expect(errorSet, true);
    });

    test('error field - invalid float', () async {
      const testData = '0041;NotAFloat;# Test\n';
      var errorSet = false;

      final parser = UcdParser.parseStream(
        linesStream(testData),
        (row) {
          final result = row.getFloat(1);
          expect(result, -1); // Returns -1 on error
          expect(row.error, isNotEmpty);
          expect(row.error, contains('invalid float value'));
          errorSet = true;
        },
      );

      await parser.parse();
      expect(errorSet, true);
    });

    test('error field - invalid rune format', () async {
      const testData = 'ZZZZ;Name;# Test\n';
      var errorSet = false;

      final parser = UcdParser.parseStream(
        linesStream(testData),
        (row) {
          row.getRange(0);
          expect(row.rangeStart, -1); // Returns -1 on error
          expect(row.error, isNotEmpty);
          expect(row.error, contains('failed to parse rune'));
          errorSet = true;
        },
      );

      await parser.parse();
      expect(errorSet, true);
    });

    test('error field - invalid rune with U+ prefix', () async {
      const testData = 'U+GGGG;Name;# Test\n';
      var errorSet = false;

      final parser = UcdParser.parseStream(
        linesStream(testData),
        (row) {
          final result = row.getRune(0);
          expect(result, -1); // Returns -1 on error
          expect(row.error, isNotEmpty);
          expect(row.error, contains('failed to parse rune'));
          errorSet = true;
        },
      );

      await parser.parse();
      expect(errorSet, true);
    });

    test('error field - valid rune with U+ prefix', () async {
      const testData = 'U+0041;Name;# Test\n';
      var errorSet = false;

      final parser = UcdParser.parseStream(
        linesStream(testData),
        (row) {
          final result = row.getRune(0);
          expect(result, 0x0041); // Should parse correctly
          expect(row.error, isEmpty);
          errorSet = true;
        },
      );

      await parser.parse();
      expect(errorSet, true);
    });

    test('error field - error can be cleared', () async {
      const testData = '0041;NotANumber;123;# Test\n';
      var errorCleared = false;

      final parser = UcdParser.parseStream(
        linesStream(testData),
        (row) {
          // First, cause an error
          row.getUint(1);
          expect(row.error, isNotEmpty);

          // Clear the error
          row.error = '';
          expect(row.error, isEmpty);

          // Try a valid operation
          final validResult = row.getUint(2);
          expect(validResult, 123);
          expect(row.error, isEmpty);
          errorCleared = true;
        },
      );

      await parser.parse();
      expect(errorCleared, true);
    });

    test('error field - multiple errors overwrite', () async {
      const testData = '0041;NotANumber;NotAFloat;# Test\n';
      var tested = false;

      final parser = UcdParser.parseStream(
        linesStream(testData),
        (row) {
          // First error
          row.getUint(1);
          final firstError = row.error;
          expect(firstError, contains('invalid unsigned integer value'));

          // Second error overwrites
          row.getFloat(2);
          final secondError = row.error;
          expect(secondError, contains('invalid float value'));
          expect(secondError, isNot(equals(firstError)));
          tested = true;
        },
      );

      await parser.parse();
      expect(tested, true);
    });

    test('error field - getRunes with invalid rune', () async {
      const testData = '0041;0042 ZZZZ 0044;# Test\n';
      var errorSet = false;

      final parser = UcdParser.parseStream(
        linesStream(testData),
        (row) {
          final result = row.getRunes(1);
          // Should still return a list, but with -1 for invalid values
          expect(result.length, 3);
          expect(result[0], 0x0042); // Valid
          expect(result[1], -1); // Invalid
          expect(result[2], 0x0044); // Valid
          expect(row.error, isNotEmpty);
          expect(row.error, contains('failed to parse rune'));
          errorSet = true;
        },
      );

      await parser.parse();
      expect(errorSet, true);
    });
  });
}
