import 'dart:math' as math;

class BenchmarkStats {
  BenchmarkStats({
    required this.samples,
    required this.min,
    required this.max,
    required this.mean,
    required this.median,
    required this.p95,
    required this.p99,
    required this.stdDev,
  });

  factory BenchmarkStats.calculate(List<int> samples) {
    if (samples.isEmpty) {
      throw ArgumentError('Cannot calculate stats from empty samples');
    }

    final sorted = List<int>.from(samples)..sort();
    final count = sorted.length;

    final min = sorted.first;
    final max = sorted.last;

    final sum = sorted.reduce((a, b) => a + b);
    final mean = sum / count;

    final median = count.isOdd ? sorted[count ~/ 2].toDouble() : (sorted[count ~/ 2 - 1] + sorted[count ~/ 2]) / 2.0;

    final p95Index = ((count - 1) * 0.95).ceil();
    final p95 = sorted[p95Index];

    final p99Index = ((count - 1) * 0.99).ceil();
    final p99 = sorted[p99Index];

    final variance = sorted.map((x) => math.pow(x - mean, 2)).reduce((a, b) => a + b) / count;
    final stdDev = math.sqrt(variance);

    return BenchmarkStats(
      samples: count,
      min: min,
      max: max,
      mean: mean,
      median: median.toInt(),
      p95: p95,
      p99: p99,
      stdDev: stdDev,
    );
  }

  final int samples;
  final int min;
  final int max;
  final double mean;
  final int median;
  final int p95;
  final int p99;
  final double stdDev;

  String format({required String scenario, required int targetMicros}) {
    final buffer = StringBuffer()
      ..writeln('Scenario: $scenario')
      ..writeln('  Samples: $samples')
      ..writeln('  Min:     ${_formatMicros(min)}')
      ..writeln('  Max:     ${_formatMicros(max)}')
      ..writeln('  Mean:    ${_formatMicros(mean.toInt())}')
      ..writeln('  Median:  ${_formatMicros(median)}')
      ..writeln('  P95:     ${_formatMicros(p95)}')
      ..writeln('  P99:     ${_formatMicros(p99)}')
      ..writeln('  StdDev:  ${_formatMicros(stdDev.toInt())}');

    final passed = p99 < targetMicros;
    final status = passed ? '✅ PASS' : '❌ FAIL';
    buffer.writeln('  Target:  < ${_formatMicros(targetMicros)}  $status');

    return buffer.toString();
  }

  String _formatMicros(int micros) {
    return '$micros μs';
  }

  String toCsv() {
    return '$samples,$min,$max,$mean,$median,$p95,$p99,$stdDev';
  }

  static String csvHeader() {
    return 'samples,min,max,mean,median,p95,p99,stddev';
  }
}
