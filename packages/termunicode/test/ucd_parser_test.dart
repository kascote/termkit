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
  });
}
