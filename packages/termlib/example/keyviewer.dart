import 'dart:io';

import 'package:termlib/termlib.dart';

void main() {
  final t = TermLib();
  final sequence = <int>[];

  t
    ..write('Press any key to see its representation.\n')
    ..write('Press ESC to exit.\n');

  while (true) {
    while (true) {
      final key = t.withRawMode<int?>(readKey);
      if (key == null) break;
      sequence.add(key);
    }
    if (sequence.isEmpty) continue;

    t
      ..write('Sequence: ')
      ..write(sequence.map((e) => e.toRadixString(16)).join(':'))
      ..write('..')
      ..write(sequence.map(controlsToAscii).join())
      ..write('\n');

    if (sequence.length == 1 && sequence[0] == 0x1b) break;
    sequence.clear();
  }
}

int? readKey() {
  final codeUnit = stdin.readByteSync();
  return (codeUnit == -1) ? null : codeUnit;
}

String controlsToAscii(int byte) {
  if (byte == 0) return 'ↀ';
  if (byte == 0x08) return '↤';
  if (byte == 0x09) return '⇥';
  if (byte == 0x0a) return '⇁';
  if (byte == 0x0b) return '↧';
  if (byte == 0x0c) return '⇊';
  if (byte == 0x0d) return '↲';
  if (byte == 0x0e) return '⇷';
  if (byte == 0x0f) return '⇸';
  if (byte == 0x1b) return '␛';
  if (byte == 0x1c) return '➊';
  if (byte == 0x1d) return '❷';
  if (byte == 0x1e) return '❸';
  if (byte == 0x1f) return '❹';
  if (byte == 0x7f) return '←';
  return String.fromCharCode(byte);
}
