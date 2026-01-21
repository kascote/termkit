import 'dart:io';

import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:characters/characters.dart';
import 'package:termunicode/termunicode.dart';

// Test strings with various character types
final List<String> testStrings = [
  'Hello World', // ASCII
  '你好世界こんにちは', // CJK
  '🏔️🏕️🏈🌍🎉', // Emoji
  '▶️◀️↔️♠️♥️', // Ambiguous with VS16
  'Hello 🌎 World 你好 🎉 Test', // Mixed
  'A' * 1000, // Long ASCII
  '🏔️' * 100, // Long emoji
];

// Pre-compute Characters to avoid measuring that overhead
final List<Characters> testCharacters = testStrings.map((s) => s.characters).toList();

// Option 1: Current implementation (runes.first)
int widthOption1(Characters value, {bool cjk = false}) {
  if (value.isEmpty) return 0;
  return value.fold(0, (width, char) => width + widthCp(char.runes.first, cjk: cjk));
}

// Option 2: Contains check + runes.first
int widthOption2(Characters value, {bool cjk = false}) {
  if (value.isEmpty) return 0;
  return value.fold(0, (width, char) {
    if (char.contains('\uFE0F')) return width + 2;
    return width + widthCp(char.runes.first, cjk: cjk);
  });
}

// Option 3: Code units decoding (no Runes object)
int widthOption3(Characters value, {bool cjk = false}) {
  if (value.isEmpty) return 0;
  return value.fold(0, (width, char) {
    if (char.contains('\uFE0F')) return width + 2;

    final cu = char.codeUnitAt(0);
    final cp = (cu >= 0xD800 && cu <= 0xDBFF && char.length > 1)
        ? 0x10000 + ((cu - 0xD800) << 10) + (char.codeUnitAt(1) - 0xDC00)
        : cu;

    return width + widthCp(cp, cjk: cjk);
  });
}

// Option 4: Cache runes toList
int widthOption4(Characters value, {bool cjk = false}) {
  if (value.isEmpty) return 0;
  return value.fold(0, (width, char) {
    final runes = char.runes.toList();
    if (runes.contains(0xFE0F)) return width + 2;
    return width + widthCp(runes.first, cjk: cjk);
  });
}

// Option 5: Iterator instead of .first
int widthOption5(Characters value, {bool cjk = false}) {
  if (value.isEmpty) return 0;
  return value.fold(0, (width, char) {
    if (char.contains('\uFE0F')) return width + 2;
    final iter = char.runes.iterator..moveNext();
    return width + widthCp(iter.current, cjk: cjk);
  });
}

class Option1Benchmark extends BenchmarkBase {
  Option1Benchmark() : super('Option1_runes_first');

  @override
  void run() {
    testCharacters.forEach(widthOption1);
  }
}

class Option2Benchmark extends BenchmarkBase {
  Option2Benchmark() : super('Option2_contains_runes');

  @override
  void run() {
    testCharacters.forEach(widthOption2);
  }
}

class Option3Benchmark extends BenchmarkBase {
  Option3Benchmark() : super('Option3_code_units');

  @override
  void run() {
    testCharacters.forEach(widthOption3);
  }
}

class Option4Benchmark extends BenchmarkBase {
  Option4Benchmark() : super('Option4_runes_toList');

  @override
  void run() {
    testCharacters.forEach(widthOption4);
  }
}

class Option5Benchmark extends BenchmarkBase {
  Option5Benchmark() : super('Option5_runes_iterator');

  @override
  void run() {
    testCharacters.forEach(widthOption5);
  }
}

void main() {
  stdout.writeln('Test strings:');
  for (final s in testStrings) {
    stdout.writeln('  "${s.length > 30 ? '${s.substring(0, 30)}...' : s}" (${s.characters.length} graphemes)');
  }
  stdout.writeln();

  // Run benchmarks (reports µs per run)
  Option1Benchmark().report();
  Option2Benchmark().report();
  Option3Benchmark().report();
  Option4Benchmark().report();
  Option5Benchmark().report();

  // Verify correctness
  stdout.writeln('\nVerification (O1=current, O2-O5=with VS16 fix):');
  for (final s in testStrings.take(5)) {
    final c = s.characters;
    final r1 = widthOption1(c);
    final r2 = widthOption2(c);
    final r3 = widthOption3(c);
    final r4 = widthOption4(c);
    final r5 = widthOption5(c);
    final allMatch = r2 == r3 && r3 == r4 && r4 == r5;
    final status = allMatch ? (r1 == r2 ? '✓' : '⚠ O1 wrong') : '✗ mismatch';
    stdout.writeln('  "$s": O1=$r1, O2=$r2, O3=$r3, O4=$r4, O5=$r5 $status');
  }
}
