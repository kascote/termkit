import 'dart:async';
import 'dart:io';

import 'package:termlib/src/event_queue.dart';
import 'package:termlib/src/shared/terminal_overrides.dart';
import 'package:termlib/termlib.dart';
import 'package:termparser/termparser_events.dart';

import '../shared.dart';
import '../termlib_mock.dart';
import 'benchmark_stats.dart';

void main() async {
  stdout
    ..writeln('Poll Latency Benchmark')
    ..writeln('=' * 80)
    ..writeln('Dart VM: ${Platform.version}')
    ..writeln('OS: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}')
    ..writeln();

  final results = <String, BenchmarkStats>{};

  results['Hot path (event ready)'] = await _benchmarkHotPath();
  results['Empty queue (miss)'] = await _benchmarkEmptyQueue();
  results['Type filtering (skip 2 events)'] = await _benchmarkTypeFiltering();
  results['Deep type filtering (skip 50 events)'] = await _benchmarkDeepTypeFiltering();
  results['Mid-queue search (500 events)'] = await _benchmarkMidQueueSearch();
  results['Worst case search (1000 events)'] = await _benchmarkWorstCaseSearch();

  stdout
    ..writeln()
    ..writeln('=' * 80)
    ..writeln('SUMMARY')
    ..writeln('=' * 80);

  for (final entry in results.entries) {
    final scenario = entry.key;
    final stats = entry.value;
    final target = _getTarget(scenario);
    stdout
      ..writeln(stats.format(scenario: scenario, targetMicros: target))
      ..writeln();
  }

  final allPassed = results.entries.every((entry) {
    final target = _getTarget(entry.key);
    return entry.value.p99 < target;
  });

  if (allPassed) {
    stdout.writeln('✅ All scenarios pass target <1ms');
  } else {
    stdout.writeln('❌ Some scenarios failed to meet target');
    exit(1);
  }

  await _saveResults(results);
}

int _getTarget(String scenario) {
  switch (scenario) {
    case 'Hot path (event ready)':
      return 100;
    case 'Empty queue (miss)':
      return 50;
    case 'Type filtering (skip 2 events)':
      return 200;
    case 'Deep type filtering (skip 50 events)':
      return 500;
    case 'Mid-queue search (500 events)':
      return 1000;
    case 'Worst case search (1000 events)':
      return 2000;
    default:
      return 5000;
  }
}

Future<BenchmarkStats> _benchmarkHotPath() async {
  stdout.writeln('Running: Hot path (event ready)...');

  return await TerminalOverrides.runZoned(
    () async {
      final queue = TerminalOverrides.current!.eventQueue!;
      final term = TermLib();

      const warmupIterations = 100;
      for (var i = 0; i < warmupIterations; i++) {
        queue.enqueue(KeyEvent.fromString('a'));
        term.poll<KeyEvent>();
      }

      final samples = <int>[];
      final stopwatch = Stopwatch();
      const measurementIterations = 1000;

      for (var i = 0; i < measurementIterations; i++) {
        queue.enqueue(KeyEvent.fromString('a'));

        stopwatch.start();
        term.poll<KeyEvent>();
        stopwatch.stop();

        samples.add(stopwatch.elapsedMicroseconds);
        stopwatch.reset();
      }

      await term.dispose();
      return BenchmarkStats.calculate(samples);
    },
    stdout: MockStdout(),
    stdin: MockStdin(streamString('')),
    eventQueue: EventQueue(),
    hasTerminal: true,
  );
}

Future<BenchmarkStats> _benchmarkEmptyQueue() async {
  stdout.writeln('Running: Empty queue (miss)...');

  return await TerminalOverrides.runZoned(
    () async {
      final term = TermLib();

      const warmupIterations = 100;
      for (var i = 0; i < warmupIterations; i++) {
        term.poll<KeyEvent>();
      }

      final samples = <int>[];
      final stopwatch = Stopwatch();
      const measurementIterations = 1000;

      for (var i = 0; i < measurementIterations; i++) {
        stopwatch.start();
        term.poll<KeyEvent>();
        stopwatch.stop();

        samples.add(stopwatch.elapsedMicroseconds);
        stopwatch.reset();
      }

      await term.dispose();
      return BenchmarkStats.calculate(samples);
    },
    stdout: MockStdout(),
    stdin: MockStdin(streamString('')),
    eventQueue: EventQueue(),
    hasTerminal: true,
  );
}

Future<BenchmarkStats> _benchmarkTypeFiltering() async {
  stdout.writeln('Running: Type filtering (skip non-matching)...');

  return await TerminalOverrides.runZoned(
    () async {
      final queue = TerminalOverrides.current!.eventQueue!;
      final term = TermLib();

      const warmupIterations = 100;
      for (var i = 0; i < warmupIterations; i++) {
        queue
          ..enqueue(
            const MouseEvent(
              1,
              1,
              MouseButton(MouseButtonKind.left, MouseButtonAction.down),
            ),
          )
          ..enqueue(
            const MouseEvent(
              2,
              2,
              MouseButton(MouseButtonKind.right, MouseButtonAction.up),
            ),
          )
          ..enqueue(KeyEvent.fromString('x'));
        term.poll<KeyEvent>();
      }

      final samples = <int>[];
      final stopwatch = Stopwatch();
      const measurementIterations = 1000;

      for (var i = 0; i < measurementIterations; i++) {
        queue
          ..enqueue(
            const MouseEvent(
              1,
              1,
              MouseButton(MouseButtonKind.left, MouseButtonAction.down),
            ),
          )
          ..enqueue(
            const MouseEvent(
              2,
              2,
              MouseButton(MouseButtonKind.right, MouseButtonAction.up),
            ),
          )
          ..enqueue(KeyEvent.fromString('x'));

        stopwatch.start();
        term.poll<KeyEvent>();
        stopwatch.stop();

        samples.add(stopwatch.elapsedMicroseconds);
        stopwatch.reset();
      }

      await term.dispose();
      return BenchmarkStats.calculate(samples);
    },
    stdout: MockStdout(),
    stdin: MockStdin(streamString('')),
    eventQueue: EventQueue(),
    hasTerminal: true,
  );
}

Future<BenchmarkStats> _benchmarkDeepTypeFiltering() async {
  stdout.writeln('Running: Deep type filtering (skip 50 events)...');

  return await TerminalOverrides.runZoned(
    () async {
      final queue = TerminalOverrides.current!.eventQueue!;
      final term = TermLib();

      const warmupIterations = 100;
      for (var i = 0; i < warmupIterations; i++) {
        for (var j = 0; j < 50; j++) {
          queue.enqueue(
            const MouseEvent(
              1,
              1,
              MouseButton(MouseButtonKind.left, MouseButtonAction.down),
            ),
          );
        }
        queue.enqueue(KeyEvent.fromString('x'));
        term.poll<KeyEvent>();
      }

      final samples = <int>[];
      final stopwatch = Stopwatch();
      const measurementIterations = 1000;

      for (var i = 0; i < measurementIterations; i++) {
        for (var j = 0; j < 50; j++) {
          queue.enqueue(
            const MouseEvent(
              1,
              1,
              MouseButton(MouseButtonKind.left, MouseButtonAction.down),
            ),
          );
        }
        queue.enqueue(KeyEvent.fromString('x'));

        stopwatch.start();
        term.poll<KeyEvent>();
        stopwatch.stop();

        samples.add(stopwatch.elapsedMicroseconds);
        stopwatch.reset();
      }

      await term.dispose();
      return BenchmarkStats.calculate(samples);
    },
    stdout: MockStdout(),
    stdin: MockStdin(streamString('')),
    eventQueue: EventQueue(),
    hasTerminal: true,
  );
}

Future<BenchmarkStats> _benchmarkMidQueueSearch() async {
  stdout.writeln('Running: Mid-queue search (500 events)...');

  return await TerminalOverrides.runZoned(
    () async {
      final queue = TerminalOverrides.current!.eventQueue!;
      final term = TermLib();

      const warmupIterations = 100;
      for (var i = 0; i < warmupIterations; i++) {
        for (var j = 0; j < 250; j++) {
          queue.enqueue(
            const MouseEvent(
              1,
              1,
              MouseButton(MouseButtonKind.left, MouseButtonAction.down),
            ),
          );
        }
        queue.enqueue(KeyEvent.fromString('k'));
        for (var j = 0; j < 249; j++) {
          queue.enqueue(
            const MouseEvent(
              2,
              2,
              MouseButton(MouseButtonKind.right, MouseButtonAction.up),
            ),
          );
        }
        queue.enqueue(const FocusEvent());

        term.poll<KeyEvent>();
        term.poll<FocusEvent>();
      }

      final samples = <int>[];
      final stopwatch = Stopwatch();
      const measurementIterations = 1000;

      for (var i = 0; i < measurementIterations; i++) {
        for (var j = 0; j < 250; j++) {
          queue.enqueue(
            const MouseEvent(
              1,
              1,
              MouseButton(MouseButtonKind.left, MouseButtonAction.down),
            ),
          );
        }
        queue.enqueue(KeyEvent.fromString('k'));
        for (var j = 0; j < 249; j++) {
          queue.enqueue(
            const MouseEvent(
              2,
              2,
              MouseButton(MouseButtonKind.right, MouseButtonAction.up),
            ),
          );
        }
        queue.enqueue(const FocusEvent());

        stopwatch.start();
        term.poll<KeyEvent>();
        stopwatch.stop();
        samples.add(stopwatch.elapsedMicroseconds);
        stopwatch.reset();

        stopwatch.start();
        term.poll<FocusEvent>();
        stopwatch.stop();
        samples.add(stopwatch.elapsedMicroseconds);
        stopwatch.reset();
      }

      await term.dispose();
      return BenchmarkStats.calculate(samples);
    },
    stdout: MockStdout(),
    stdin: MockStdin(streamString('')),
    eventQueue: EventQueue(),
    hasTerminal: true,
  );
}

Future<BenchmarkStats> _benchmarkWorstCaseSearch() async {
  stdout.writeln('Running: Worst case search (1000 events)...');

  return await TerminalOverrides.runZoned(
    () async {
      final queue = TerminalOverrides.current!.eventQueue!;
      final term = TermLib();

      const warmupIterations = 100;
      for (var i = 0; i < warmupIterations; i++) {
        for (var j = 0; j < 999; j++) {
          queue.enqueue(
            const MouseEvent(
              1,
              1,
              MouseButton(MouseButtonKind.left, MouseButtonAction.down),
            ),
          );
        }
        queue.enqueue(KeyEvent.fromString('k'));
        term.poll<KeyEvent>();
      }

      final samples = <int>[];
      final stopwatch = Stopwatch();
      const measurementIterations = 1000;

      for (var i = 0; i < measurementIterations; i++) {
        for (var j = 0; j < 999; j++) {
          queue.enqueue(
            const MouseEvent(
              1,
              1,
              MouseButton(MouseButtonKind.left, MouseButtonAction.down),
            ),
          );
        }
        queue.enqueue(KeyEvent.fromString('k'));

        stopwatch.start();
        term.poll<KeyEvent>();
        stopwatch.stop();

        samples.add(stopwatch.elapsedMicroseconds);
        stopwatch.reset();
      }

      await term.dispose();
      return BenchmarkStats.calculate(samples);
    },
    stdout: MockStdout(),
    stdin: MockStdin(streamString('')),
    eventQueue: EventQueue(),
    hasTerminal: true,
  );
}

Future<void> _saveResults(Map<String, BenchmarkStats> results) async {
  final timestamp = DateTime.now().toIso8601String();
  final file = File('test/benchmark/results.csv');

  final exists = file.existsSync();
  final sink = file.openWrite(mode: FileMode.append);

  if (!exists) {
    sink.writeln('timestamp,scenario,${BenchmarkStats.csvHeader()}');
  }

  for (final entry in results.entries) {
    sink.writeln('$timestamp,${entry.key},${entry.value.toCsv()}');
  }

  await sink.flush();
  await sink.close();

  stdout.writeln('Results appended to: ${file.path}');
}
