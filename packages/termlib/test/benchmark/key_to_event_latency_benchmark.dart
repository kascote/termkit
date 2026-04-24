import 'dart:async';
import 'dart:io';

import 'package:termparser/termparser.dart';
import 'package:termparser/termparser_events.dart';

import 'benchmark_stats.dart';
import 'benchmark_writer.dart';

/// End-to-end latency: raw bytes on a stream → parsed `Event` delivered to
/// a listener. Covers the parser hot path plus one microtask of scheduling.
void main() async {
  stdout
    ..writeln('Key → Event Latency Benchmark')
    ..writeln('=' * 80)
    ..writeln('Dart VM: ${Platform.version}')
    ..writeln('OS: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}')
    ..writeln();

  final results = <String, BenchmarkStats>{};

  results['Single ASCII key (a)'] = await _benchmark(
    label: 'Single ASCII key (a)',
    bytes: [0x61],
    expect: (e) => e is KeyEvent,
  );
  results['Ctrl modifier (ctrl+c)'] = await _benchmark(
    label: 'Ctrl modifier (ctrl+c)',
    bytes: [0x03],
    expect: (e) => e is KeyEvent,
  );
  results['Arrow up (ESC [ A)'] = await _benchmark(
    label: 'Arrow up (ESC [ A)',
    bytes: [0x1b, 0x5b, 0x41],
    expect: (e) => e is KeyEvent,
  );
  // CPR response: ESC [ 5 ; 10 R  -> CursorPositionEvent(row=5, col=10)
  results['Cursor position reply'] = await _benchmark(
    label: 'Cursor position reply',
    bytes: [0x1b, 0x5b, 0x35, 0x3b, 0x31, 0x30, 0x52],
    expect: (e) => e is CursorPositionEvent,
  );

  stdout
    ..writeln()
    ..writeln('=' * 80)
    ..writeln('SUMMARY (μs per byte-group → Event)')
    ..writeln('=' * 80);

  for (final entry in results.entries) {
    stdout
      ..writeln(entry.value.format(scenario: entry.key, targetMicros: 1000))
      ..writeln();
  }

  await BenchmarkWriter('test/benchmark/key_to_event_latency.csv').append(results);
}

Future<BenchmarkStats> _benchmark({
  required String label,
  required List<int> bytes,
  required bool Function(Event) expect,
}) async {
  stdout.writeln('Running: $label...');

  const warmup = 200;
  const iterations = 2000;

  final samples = <int>[];

  // Build pipeline once; reuse across iterations. Per-iteration overhead:
  // one `add`, one listener dispatch, one Completer.
  final controller = StreamController<List<int>>();
  Completer<void>? pending;
  Event? last;
  final sub = controller.stream.transform(eventTransformer()).listen((e) {
    last = e;
    final p = pending;
    if (p != null && !p.isCompleted) p.complete();
  });

  Future<void> roundTrip() async {
    pending = Completer<void>();
    last = null;
    controller.add(bytes);
    await pending!.future;
    if (last == null || !expect(last!)) {
      throw StateError('$label: unexpected event $last');
    }
  }

  for (var i = 0; i < warmup; i++) {
    await roundTrip();
  }

  final sw = Stopwatch();
  for (var i = 0; i < iterations; i++) {
    pending = Completer<void>();
    last = null;
    sw
      ..reset()
      ..start();
    controller.add(bytes);
    await pending!.future;
    sw.stop();
    if (last == null || !expect(last!)) {
      throw StateError('$label: unexpected event $last');
    }
    samples.add(sw.elapsedMicroseconds);
  }

  await sub.cancel();
  await controller.close();

  return BenchmarkStats.calculate(samples);
}
