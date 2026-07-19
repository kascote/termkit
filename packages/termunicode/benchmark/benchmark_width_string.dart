// What does a `widthString` call cost at the String seam — the seam callers
// actually use?
//
// Three implementations are timed per case:
//   current       The shipped `widthString`: a code-unit pre-scan that sums
//                 table widths directly, bailing to the grapheme-cluster path
//                 on the first surrogate or zero-width unit.
//   cluster-only  `widthClusterOnly`, the pre-fast-path implementation: every
//                 call goes through `Characters` and the grapheme-cluster
//                 fold, with no scan shortcut. This is the baseline the scan
//                 is measured against — the gap between `current` and
//                 `cluster-only` is what the scan saves.
//   memo-hit      A pre-warmed HashMap lookup, to put the scan's savings next
//                 to what a session cache would have cost to maintain.
//
// Each `run()` makes [kReps] calls; the emitter divides the harness score so
// the printed number is nanoseconds per call.
//
// Run:  dart run benchmark/benchmark_width_string.dart

import 'dart:io';

import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:characters/characters.dart';
import 'package:termunicode/termunicode.dart';

const int kReps = 2000;

/// The pre-fast-path implementation: always folds over grapheme clusters.
int widthClusterOnly(String value, {bool cjk = false}) => widthChars(value.characters, cjk: cjk);

class _Case {
  const _Case(this.name, this.text);
  final String name;
  final String text;
}

const _cases = [
  _Case('ascii-char', 'a'),
  _Case('cjk-char', '你'),
  _Case('emoji-cluster', '👨‍👩‍👧‍👦'),
  _Case('ascii-40', 'the quick brown fox jumps over lazy dog'),
  _Case('cjk-12', '你好世界こんにちは水曜日'),
  _Case('mixed-40', 'Ada 田中太郎 ✅ Active 🚀 warp-drive engine'),
  _Case('vs16-symbols', '▶️◀️↔️♠️♥️'),
];

/// Prints the harness score as nanoseconds per single call.
class _PerCallEmitter implements ScoreEmitter {
  const _PerCallEmitter();

  @override
  void emit(String testName, double value) {
    final nsPerCall = value * 1000 / kReps;
    stdout.writeln('${testName.padRight(34)} ${nsPerCall.toStringAsFixed(1).padLeft(9)} ns/call');
  }
}

class _WidthBenchmark extends BenchmarkBase {
  _WidthBenchmark(String impl, this.text, this.fn, {String? caseName})
    : super('$impl/${caseName ?? text}', emitter: const _PerCallEmitter());

  final String text;
  final int Function(String) fn;

  @override
  void run() {
    var sink = 0;
    for (var i = 0; i < kReps; i++) {
      sink += fn(text);
    }
    if (sink < 0) throw StateError('unreachable');
  }
}

class _MemoHitBenchmark extends BenchmarkBase {
  _MemoHitBenchmark(this.text, {required String caseName})
    : super('memo-hit/$caseName', emitter: const _PerCallEmitter());

  final String text;
  final Map<String, int> memo = {};

  @override
  void setup() => memo[text] = widthString(text);

  @override
  void run() {
    var sink = 0;
    for (var i = 0; i < kReps; i++) {
      sink += memo[text] ?? widthString(text);
    }
    if (sink < 0) throw StateError('unreachable');
  }
}

void main() {
  // cluster-only must agree with current before any timing is worth reading.
  // None of these cases contain prepend-class characters, so the two must
  // match exactly.
  var ok = true;
  for (final c in _cases) {
    final current = widthString(c.text);
    final got = widthClusterOnly(c.text);
    if (got != current) {
      stdout.writeln('MISMATCH cluster-only(${c.name}): $got != current $current');
      ok = false;
    }
  }
  stdout.writeln(ok ? 'verification: cluster-only matches current\n' : '\nverification FAILED\n');

  for (final c in _cases) {
    _WidthBenchmark('current', c.text, widthString, caseName: c.name).report();
    _WidthBenchmark('cluster-only', c.text, widthClusterOnly, caseName: c.name).report();
    _MemoHitBenchmark(c.text, caseName: c.name).report();
    stdout.writeln();
  }
}
