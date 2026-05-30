import 'dart:io';

import 'package:termlib/src/event_queue.dart';
import 'package:termparser/termparser_events.dart';

import 'benchmark_stats.dart';
import 'benchmark_writer.dart';

void main() async {
  stdout
    ..writeln('EventQueue Throughput Benchmark')
    ..writeln('=' * 80)
    ..writeln('Dart VM: ${Platform.version}')
    ..writeln('OS: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}')
    ..writeln();

  final results = <String, BenchmarkStats>{};

  results['Pairwise enqueue+dequeue'] = _benchmarkPairwise();
  results['Burst drain (100)'] = _benchmarkBurst(100);
  results['Burst drain (1000)'] = _benchmarkBurst(1000);
  results['Type-filtered drain (skip mouse)'] = _benchmarkTypeFilteredDrain();

  stdout
    ..writeln()
    ..writeln('=' * 80)
    ..writeln('SUMMARY (ns per event)')
    ..writeln('=' * 80);

  for (final entry in results.entries) {
    _printNsStats(entry.key, entry.value);
  }

  await BenchmarkWriter('test/benchmark/throughput.csv').append(results);
}

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
    ..writeln('  Throughput: ${_throughput(s)} events/sec')
    ..writeln();
}

String _throughput(BenchmarkStats stats) {
  if (stats.mean <= 0) return 'n/a';
  return (1e9 / stats.mean).toStringAsFixed(0);
}

final int _swFreq = Stopwatch().frequency;

/// Convert stopwatch ticks to nanoseconds.
int _ticksToNs(int ticks) => (ticks * 1000000000) ~/ _swFreq;

/// Time a burst of N enqueue+dequeue cycles; report per-event nanoseconds.
BenchmarkStats _benchmarkPairwise() {
  stdout.writeln('Running: Pairwise enqueue+dequeue...');
  final queue = EventQueue();
  final key = KeyEvent.fromString('a');

  const inner = 10000;
  for (var w = 0; w < 10; w++) {
    for (var i = 0; i < inner; i++) {
      queue
        ..enqueue(key)
        ..dequeue<KeyEvent>();
    }
  }

  final samples = <int>[];
  final sw = Stopwatch();
  const iterations = 200;
  for (var i = 0; i < iterations; i++) {
    sw
      ..reset()
      ..start();
    for (var j = 0; j < inner; j++) {
      queue
        ..enqueue(key)
        ..dequeue<KeyEvent>();
    }
    sw.stop();
    samples.add(_ticksToNs(sw.elapsedTicks) ~/ inner);
  }
  return BenchmarkStats.calculate(samples);
}

/// Time N enqueues followed by N dequeues (FIFO drain). Per-event nanoseconds.
BenchmarkStats _benchmarkBurst(int n) {
  stdout.writeln('Running: Burst drain ($n)...');
  final queue = EventQueue();
  final key = KeyEvent.fromString('b');

  for (var w = 0; w < 50; w++) {
    for (var i = 0; i < n; i++) {
      queue.enqueue(key);
    }
    while (queue.dequeue<KeyEvent>() != null) {}
  }

  final samples = <int>[];
  final sw = Stopwatch();
  const iterations = 500;
  for (var i = 0; i < iterations; i++) {
    sw
      ..reset()
      ..start();
    for (var j = 0; j < n; j++) {
      queue.enqueue(key);
    }
    while (queue.dequeue<KeyEvent>() != null) {}
    sw.stop();
    // 2n operations total (n enqueue + n dequeue); report per-op ns.
    samples.add(_ticksToNs(sw.elapsedTicks) ~/ (2 * n));
  }
  return BenchmarkStats.calculate(samples);
}

/// Interleave matching + non-matching events and drain only the matching type.
/// Exercises the O(n) scan inside `dequeue<T>`.
BenchmarkStats _benchmarkTypeFilteredDrain() {
  stdout.writeln('Running: Type-filtered drain...');
  final queue = EventQueue(coalesceMotion: false);
  final key = KeyEvent.fromString('c');
  const mouse = MouseEvent(1, 1, MouseButton(MouseButtonKind.left, MouseButtonAction.down));

  const n = 500;
  for (var w = 0; w < 20; w++) {
    for (var i = 0; i < n; i++) {
      queue
        ..enqueue(mouse)
        ..enqueue(key);
    }
    while (queue.dequeue<Event>() != null) {}
  }

  final samples = <int>[];
  final sw = Stopwatch();
  const iterations = 200;
  for (var i = 0; i < iterations; i++) {
    for (var j = 0; j < n; j++) {
      queue
        ..enqueue(mouse)
        ..enqueue(key);
    }
    sw
      ..reset()
      ..start();
    var drained = 0;
    while (queue.dequeue<KeyEvent>() != null) {
      drained++;
    }
    sw.stop();
    if (drained != n) throw StateError('expected $n KeyEvents, got $drained');
    samples.add(_ticksToNs(sw.elapsedTicks) ~/ n);
    while (queue.dequeue<Event>() != null) {}
  }
  return BenchmarkStats.calculate(samples);
}
