/// Stream fuzz harness (Phase 4): random bytes, random chunking, random hasMore.
///
/// Invariants applied (Phase 7 — see `_support/invariants.dart`):
///   * `runOnce`: no throw, eventCount <= input.length, sequenceByteCount cap,
///     no NoneEvent leaks
///   * harness-level: determinism + replay of `crashes/`
///   * (well-formed → ground does not apply: random bytes have no oracle)
///
/// The generative loop is OPT-IN: skipped under a plain `dart test` / `make test`
/// (keeps the default suite fast). It runs only when FUZZ_ITER or FUZZ_SECS is
/// set in the env, i.e. via `make fuzz` / `make fuzz-time`.
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
import '../_support/invariants.dart';
import '../_support/schedule.dart';

final String _fuzzMode = Platform.environment['FUZZ_MODE'] ?? '';
final int _fuzzIter =
    int.tryParse(Platform.environment['FUZZ_ITER'] ?? '') ?? 10000;
final int _fuzzSecs = int.tryParse(Platform.environment['FUZZ_SECS'] ?? '') ?? 0;

/// The heavy generative loop is opt-in: a plain `dart test` / `make test` skips
/// it (kept fast — `replay crashes/` + corpus remain as regression guards). It
/// runs only when a fuzz knob is set, i.e. via `make fuzz` / `make fuzz-time`.
final bool _fuzzEnabled =
    Platform.environment.containsKey('FUZZ_ITER') ||
    Platform.environment.containsKey('FUZZ_SECS');

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

Future<void> main() async {
  final crashesDir = await defaultCrashesDir();

  group('stream fuzz', () {
    test('replay crashes/ (regression guard)', () => replayCrashes(crashesDir));

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

          assertNoCrash(
            runOnce(bytes, schedule),
            bytes,
            schedule,
            crashesDir: crashesDir,
            iter: iters,
            seed: _fuzzSeed,
          );
          assertDeterminism(
            bytes,
            schedule,
            crashesDir: crashesDir,
            iter: iters,
          );
        }
        printOnFailure('stream fuzz: $iters iters, seed=$_fuzzSeed');
      },
      timeout: const Timeout(Duration(hours: 1)),
      skip: _fuzzEnabled ? false : 'opt-in: run via `make fuzz` (set FUZZ_ITER/FUZZ_SECS)',
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
