// What does a `widthString` call cost at the String seam — the seam callers
// actually use — and what would each fast-path candidate change?
//
// The older `benchmark_width.dart` compares cluster-fold variants over
// pre-computed `Characters`, which excludes the String → Characters conversion
// and the grapheme-break machinery. For a caller measuring one cell symbol per
// buffer write (kiko's hot path), that excluded part IS most of the cost, so
// this file measures whole calls from a plain String.
//
// Candidates measured against the current implementation:
//   ascii-scan   A code-unit pre-scan: when every unit is printable ASCII
//                (0x20-0x7E) the width is the length; otherwise fall through
//                to the current cluster path unchanged.
//   +vs16-guard  ascii-scan, plus the cluster path only runs the VS16
//                `contains` check on clusters longer than one code unit.
//   scalar-scan  A wider pre-scan: when every code unit is a BMP scalar whose
//                table width is non-zero (no surrogates, no combining marks,
//                no ZWJ/VS — those are all width 0), sum table widths without
//                cluster iteration. Covers pure-CJK strings, not just ASCII.
//                Semantics caveat: prepend-class clusters (e.g. U+0600) would
//                be summed per codepoint; acceptable-for-terminals is part of
//                what this benchmark is meant to inform.
//   memo-hit     A pre-warmed HashMap lookup, for comparison with the session
//                cache idea this work replaces.
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

const _asciiStart = 0x20;
const _asciiEnd = 0x7F; // exclusive; 0x7F is DEL

/// Candidate: printable-ASCII code-unit pre-scan, current path as fallback.
int widthAsciiScan(String value, {bool cjk = false}) {
  var i = 0;
  for (; i < value.length; i++) {
    final cu = value.codeUnitAt(i);
    if (cu < _asciiStart || cu >= _asciiEnd) break;
  }
  if (i == value.length) return value.length;
  return widthChars(value.characters, cjk: cjk);
}

/// Cluster fold as currently shipped, but the VS16 check only runs on
/// clusters longer than one code unit (a single unit cannot carry VS16).
int _clusterFoldGuarded(Characters value, {bool cjk = false}) {
  var width = 0;
  for (final char in value) {
    if (char.length > 1 && char.contains('\uFE0F')) {
      width += 2;
      continue;
    }
    final cu = char.codeUnitAt(0);
    final cp = (cu >= 0xD800 && cu <= 0xDBFF && char.length > 1)
        ? 0x10000 + ((cu - 0xD800) << 10) + (char.codeUnitAt(1) - 0xDC00)
        : cu;
    width += widthCp(cp, cjk: cjk);
  }
  return width;
}

/// Candidate: ascii-scan plus the guarded cluster fold as fallback.
int widthAsciiScanGuarded(String value, {bool cjk = false}) {
  var i = 0;
  for (; i < value.length; i++) {
    final cu = value.codeUnitAt(i);
    if (cu < _asciiStart || cu >= _asciiEnd) break;
  }
  if (i == value.length) return value.length;
  return _clusterFoldGuarded(value.characters, cjk: cjk);
}

/// Candidate: BMP-scalar pre-scan — sum table widths per code unit while every
/// unit is a non-surrogate scalar of non-zero width; any surrogate, combining
/// mark, ZWJ or variation selector (all width 0) bails to the cluster path.
int widthScalarScan(String value, {bool cjk = false}) {
  var width = 0;
  for (var i = 0; i < value.length; i++) {
    final cu = value.codeUnitAt(i);
    if (cu >= _asciiStart && cu < _asciiEnd) {
      width += 1;
      continue;
    }
    if (cu >= 0xD800 && cu <= 0xDFFF) return widthChars(value.characters, cjk: cjk);
    final w = widthCp(cu, cjk: cjk);
    if (w == 0) return widthChars(value.characters, cjk: cjk);
    width += w;
  }
  return width;
}

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
  // Every candidate must agree with the current implementation before any
  // timing is worth reading. `scalar-scan` is allowed to disagree only where
  // its documented caveat applies (none of these cases).
  var ok = true;
  for (final c in _cases) {
    final current = widthString(c.text);
    for (final (name, fn) in [
      ('ascii-scan', widthAsciiScan),
      ('ascii-scan+guard', widthAsciiScanGuarded),
      ('scalar-scan', widthScalarScan),
    ]) {
      final got = fn(c.text);
      if (got != current) {
        stdout.writeln('MISMATCH $name(${c.name}): $got != current $current');
        ok = false;
      }
    }
  }
  stdout.writeln(ok ? 'verification: all candidates match current\n' : '\nverification FAILED\n');

  for (final c in _cases) {
    _WidthBenchmark('current', c.text, widthString, caseName: c.name).report();
    _WidthBenchmark('ascii-scan', c.text, widthAsciiScan, caseName: c.name).report();
    _WidthBenchmark('ascii-scan+guard', c.text, widthAsciiScanGuarded, caseName: c.name).report();
    _WidthBenchmark('scalar-scan', c.text, widthScalarScan, caseName: c.name).report();
    _MemoHitBenchmark(c.text, caseName: c.name).report();
    stdout.writeln();
  }
}
