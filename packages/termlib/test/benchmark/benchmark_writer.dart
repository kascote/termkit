import 'dart:io';

import 'benchmark_stats.dart';

/// Append benchmark runs to a per-benchmark CSV.
///
/// Each row carries: timestamp, git SHA, platform, dart version, scenario,
/// followed by the [BenchmarkStats] columns.
class BenchmarkWriter {
  BenchmarkWriter(this.path);

  final String path;

  String get _sha {
    try {
      final r = Process.runSync('git', ['rev-parse', '--short', 'HEAD']);
      if (r.exitCode != 0) return 'unknown';
      return (r.stdout as String).trim();
    } on Object {
      return 'unknown';
    }
  }

  String get _platform => '${Platform.operatingSystem}-${Platform.version.split(' ').first}';

  Future<void> append(Map<String, BenchmarkStats> results) async {
    final file = File(path);
    final exists = file.existsSync();
    final sink = file.openWrite(mode: FileMode.append);
    try {
      if (!exists) {
        sink.writeln('timestamp,sha,platform,scenario,${BenchmarkStats.csvHeader()}');
      }
      final ts = DateTime.now().toIso8601String();
      final sha = _sha;
      final platform = _platform;
      for (final entry in results.entries) {
        sink.writeln('$ts,$sha,$platform,${entry.key},${entry.value.toCsv()}');
      }
    } finally {
      await sink.flush();
      await sink.close();
    }
    stdout.writeln('Results appended to: $path');
  }
}
