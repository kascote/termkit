import 'dart:io';

import 'package:termlib/src/event_queue.dart';
import 'package:termparser/termparser_events.dart';

import 'benchmark_stats.dart';
import 'benchmark_writer.dart';

/// Compare `EventQueue` enqueue behavior with and without `coalesceMotion`.
/// Floods the queue with high-rate event types (mouse motion, window resize)
/// and reports per-event enqueue latency plus the resulting queue length.
void main() async {
  stdout
    ..writeln('EventQueue Coalesce Benchmark')
    ..writeln('=' * 80)
    ..writeln('Dart VM: ${Platform.version}')
    ..writeln('OS: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}')
    ..writeln();

  final results = <String, BenchmarkStats>{};

  const n = 5000;

  results['Mouse motion flood (coalesce=on, n=$n)'] = _mouseMotion(
    n: n,
    coalesce: true,
  );
  results['Mouse motion flood (coalesce=off, n=$n)'] = _mouseMotion(
    n: n,
    coalesce: false,
  );
  results['Window resize flood (coalesce=on, n=$n)'] = _windowResize(
    n: n,
    coalesce: true,
  );
  results['Window resize flood (coalesce=off, n=$n)'] = _windowResize(
    n: n,
    coalesce: false,
  );

  stdout
    ..writeln()
    ..writeln('=' * 80)
    ..writeln('SUMMARY (ns per enqueue)')
    ..writeln('=' * 80);

  for (final entry in results.entries) {
    _printNsStats(entry.key, entry.value);
  }

  await BenchmarkWriter('test/benchmark/coalesce.csv').append(results);
}

final int _swFreq = Stopwatch().frequency;
int _ticksToNs(int ticks) => (ticks * 1000000000) ~/ _swFreq;

void _printNsStats(String scenario, BenchmarkStats s) {
  stdout
    ..writeln('Scenario: $scenario')
    ..writeln('  Samples: ${s.samples}')
    ..writeln('  Min:     ${s.min} ns')
    ..writeln('  Max:     ${s.max} ns')
    ..writeln('  Mean:    ${s.mean.toStringAsFixed(1)} ns')
    ..writeln('  Median:  ${s.median} ns')
    ..writeln('  P95:     ${s.p95} ns')
    ..writeln('  P99:     ${s.p99} ns')
    ..writeln('  StdDev:  ${s.stdDev.toStringAsFixed(1)} ns')
    ..writeln();
}

/// n moved-mouse samples, same button state. Measures per-event enqueue ns
/// and prints the final queue length to confirm coalesce behavior.
BenchmarkStats _mouseMotion({required int n, required bool coalesce}) {
  stdout.writeln('Running: Mouse motion flood (coalesce=$coalesce, n=$n)...');
  const iterations = 200;
  const mouse = MouseEvent(
    1,
    1,
    MouseButton(MouseButtonKind.left, MouseButtonAction.moved),
  );

  // Warmup
  for (var w = 0; w < 20; w++) {
    final q = EventQueue(coalesceMotion: coalesce);
    for (var i = 0; i < n; i++) {
      q.enqueue(mouse);
    }
  }

  final samples = <int>[];
  final sw = Stopwatch();
  int? lastLen;
  for (var i = 0; i < iterations; i++) {
    final q = EventQueue(coalesceMotion: coalesce);
    sw
      ..reset()
      ..start();
    for (var j = 0; j < n; j++) {
      q.enqueue(mouse);
    }
    sw.stop();
    samples.add(_ticksToNs(sw.elapsedTicks) ~/ n);
    lastLen = q.length;
  }
  stdout.writeln('  final queue length: $lastLen');
  return BenchmarkStats.calculate(samples);
}

BenchmarkStats _windowResize({required int n, required bool coalesce}) {
  stdout.writeln('Running: Window resize flood (coalesce=$coalesce, n=$n)...');
  const iterations = 200;

  for (var w = 0; w < 20; w++) {
    final q = EventQueue(coalesceMotion: coalesce);
    for (var i = 0; i < n; i++) {
      q.enqueue(WindowResizeEvent(80 + (i & 31), 24 + (i & 15)));
    }
  }

  final samples = <int>[];
  final sw = Stopwatch();
  int? lastLen;
  for (var i = 0; i < iterations; i++) {
    final q = EventQueue(coalesceMotion: coalesce);
    sw
      ..reset()
      ..start();
    for (var j = 0; j < n; j++) {
      q.enqueue(WindowResizeEvent(80 + (j & 31), 24 + (j & 15)));
    }
    sw.stop();
    samples.add(_ticksToNs(sw.elapsedTicks) ~/ n);
    lastLen = q.length;
  }
  stdout.writeln('  final queue length: $lastLen');
  return BenchmarkStats.calculate(samples);
}
