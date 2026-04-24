/// Stream fuzz harness (Phase 4): random bytes, random chunking, random hasMore.
///
/// Invariants (Phase 7) applied — `runOnce` enforces:
///   * no throw from advance / nextEvent / drainEvents
///   * eventCount <= input.length
///   * sequenceByteCount cap
///   * no NoneEvent leaks
///
/// Plus, this harness:
///   * determinism — same bytes + same schedule → equal event lists
///   * replays every `.bin` under `crashes/` first (regression guard)
///
/// Run knobs (shell env vars — `dart test` does not forward `-D` defines):
///   FUZZ_ITER   int     iter count (default 10000; ignored in time mode)
///   FUZZ_SECS   int     time budget in seconds (overrides FUZZ_ITER when > 0)
///   FUZZ_MODE   string  'replay' → skip generation, only replay crashes/
///   FUZZ_SEED   int     RNG seed (default 0xC0FFEE, change to broaden coverage)
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:glados/glados.dart';

import '../_support/harness.dart';
import '../_support/schedule.dart';

final String _fuzzMode = Platform.environment['FUZZ_MODE'] ?? '';
final int _fuzzIter =
    int.tryParse(Platform.environment['FUZZ_ITER'] ?? '') ?? 10000;
final int _fuzzSecs = int.tryParse(Platform.environment['FUZZ_SECS'] ?? '') ?? 0;
final int _fuzzSeed =
    int.tryParse(Platform.environment['FUZZ_SEED'] ?? '') ?? 0xC0FFEE;

const _maxBytes = 4096;

/// Glados-style generator (Phase 8 will leverage the shrink path).
/// Drives raw bytes biased toward control / ESC / CSI-C1 / high-half.
final Generator<Uint8List> biasedBytesGen = any.simple(
  generate: (random, _) => _genBytes(random, _maxBytes),
  shrink: (bytes) sync* {
    if (bytes.isEmpty) return;
    yield Uint8List.fromList(bytes.sublist(0, bytes.length ~/ 2));
    yield Uint8List.fromList(bytes.sublist(0, bytes.length - 1));
  },
);

void main() {
  final crashesDir = defaultCrashesDir();

  group('stream fuzz', () {
    test('replay crashes/ (regression guard)', () {
      if (!crashesDir.existsSync()) return;
      final bins = crashesDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.bin'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
      for (final f in bins) {
        final bytes = Uint8List.fromList(f.readAsBytesSync());
        final outcome = runOnce(bytes, FuzzSchedule.single(bytes.length));
        if (outcome is FuzzCrash) {
          fail('replay ${f.uri.pathSegments.last}: '
              'inv=${outcome.invariant} err=${outcome.error}');
        }
      }
    });

    if (_fuzzMode == 'replay') return;

    test(
      'random bytes + chunking + hasMore (${_fuzzSecs > 0 ? "${_fuzzSecs}s" : "$_fuzzIter iters"})',
      () {
        final rng = Random(_fuzzSeed);
        final timeBudget = _fuzzSecs > 0;
        final deadline = timeBudget
            ? DateTime.now().add(Duration(seconds: _fuzzSecs))
            : null;
        final iterCap = timeBudget ? 1 << 30 : _fuzzIter;

        var iters = 0;
        while (iters < iterCap) {
          if (timeBudget && !DateTime.now().isBefore(deadline!)) break;
          iters++;

          final bytes = biasedBytesGen(rng, _maxBytes).value;
          final schedule = randomSchedule(rng, bytes);

          final outcome = runOnce(bytes, schedule);
          if (outcome is FuzzCrash) {
            final key = dumpCrash(crashesDir, bytes, schedule, outcome);
            fail('crash @ iter $iters seed=$_fuzzSeed key=$key '
                'inv=${outcome.invariant} err=${outcome.error}');
          }

          // Determinism: two fresh parsers, identical bytes + schedule → same events.
          final fp1 = fingerprint(bytes, schedule);
          final fp2 = fingerprint(bytes, schedule);
          if (fp1 != fp2) {
            final crash = FuzzCrash(
              StateError('nondeterministic: first=$fp1 second=$fp2'),
              StackTrace.current,
              'determinism',
            );
            final key = dumpCrash(crashesDir, bytes, schedule, crash);
            fail('nondeterministic @ iter $iters key=$key');
          }
        }
        printOnFailure('stream fuzz: $iters iters, seed=$_fuzzSeed');
      },
      timeout: const Timeout(Duration(hours: 1)),
    );
  });
}

// ---- generators ----------------------------------------------------------

Uint8List _genBytes(Random rng, int maxLen) {
  final len = rng.nextInt(maxLen + 1);
  final out = Uint8List(len);
  for (var i = 0; i < len; i++) {
    out[i] = _weightedByte(rng);
  }
  return out;
}

/// Byte distribution tuned to hit parser state transitions hard:
///   20% ESC (0x1b)         — drives ground → escape flips
///   05% CSI-C1 (0x9b)      — single-byte CSI entry
///   25% other C0 controls  — 0x00..0x1f minus ESC
///   05% DEL (0x7f)
///   20% high half          — 0x80..0xff (C1 + UTF-8 lead/continuation)
///   25% printable ASCII    — 0x20..0x7e
int _weightedByte(Random rng) {
  final r = rng.nextInt(100);
  if (r < 20) return 0x1b;
  if (r < 25) return 0x9b;
  if (r < 50) {
    final c = rng.nextInt(32);
    return c == 0x1b ? 0x00 : c;
  }
  if (r < 55) return 0x7f;
  if (r < 75) return 0x80 + rng.nextInt(128);
  return 0x20 + rng.nextInt(95);
}

// ---- chunk-schedule + fingerprint live in _support/schedule.dart -------
