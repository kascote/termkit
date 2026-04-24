/// UTF-8 fuzz harness (Phase 6): explicit seeds + mutation.
///
/// Targets the UTF-8 decoder paths in the engine. Every iteration picks a
/// hand-curated seed (overlong, truncated, bad continuation, surrogate, near
/// U+10FFFF, ESC/CSI mid-sequence), applies 0..3 mutations, and runs it
/// through `runOnce` under both a per-byte schedule (worst-case for chunk
/// boundaries inside a multibyte sequence) and a random chunk schedule.
///
/// Invariants (Phase 7) applied — `runOnce` enforces:
///   * no throw from advance / nextEvent / drainEvents
///   * eventCount <= input.length
///   * sequenceByteCount cap
///   * no NoneEvent leaks
///
/// Plus, this harness:
///   * every seed runs as-is on every iteration before mutation (regression
///     guard against the explicit pattern set)
///   * per-byte schedule + random schedule both must produce identical events
///     (determinism is the strongest oracle here — there is no well-formed
///     program shape for malformed UTF-8)
///   * replays every `.bin` under `crashes/` first
///
/// Run knobs (shell env vars):
///   FUZZ_ITER   int     iter count (default 10000)
///   FUZZ_SECS   int     time budget in seconds (overrides FUZZ_ITER when > 0)
///   FUZZ_MODE   string  'replay' → skip generation, only replay crashes/
///   FUZZ_SEED   int     RNG seed (default 0xC0FFEE)
library;

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:test/test.dart';

import '../_support/harness.dart';
import '../_support/schedule.dart';

final String _fuzzMode = Platform.environment['FUZZ_MODE'] ?? '';
final int _fuzzIter =
    int.tryParse(Platform.environment['FUZZ_ITER'] ?? '') ?? 10000;
final int _fuzzSecs = int.tryParse(Platform.environment['FUZZ_SECS'] ?? '') ?? 0;
final int _fuzzSeed =
    int.tryParse(Platform.environment['FUZZ_SEED'] ?? '') ?? 0xC0FFEE;

const int _maxBytes = 4096;

void main() {
  final crashesDir = defaultCrashesDir();

  group('utf8 fuzz', () {
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

    test('explicit seeds (no mutation)', () {
      for (var i = 0; i < _utf8Seeds.length; i++) {
        final seed = _utf8Seeds[i];
        final bytes = Uint8List.fromList(seed.bytes);
        for (final schedule in _seedSchedules(bytes)) {
          final outcome = runOnce(bytes, schedule);
          if (outcome is FuzzCrash) {
            fail('seed[$i] (${seed.label}) crashed under '
                'chunks=${schedule.chunkSizes} hasMore=${schedule.hasMore}: '
                'inv=${outcome.invariant} err=${outcome.error}');
          }
        }
      }
    });

    if (_fuzzMode == 'replay') return;

    test(
      'mutated UTF-8 patterns '
      '(${_fuzzSecs > 0 ? "${_fuzzSecs}s" : "$_fuzzIter iters"})',
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

          final bytes = _genMutatedInput(rng);

          final perByte = _perByteSchedule(bytes);
          final random = randomSchedule(rng, bytes);

          for (final schedule in [perByte, random]) {
            final outcome = runOnce(bytes, schedule);
            if (outcome is FuzzCrash) {
              final key = dumpCrash(crashesDir, bytes, schedule, outcome);
              fail('crash @ iter $iters seed=$_fuzzSeed key=$key '
                  'inv=${outcome.invariant} err=${outcome.error}');
            }
          }

          // Determinism: same bytes + same schedule → equal event lists.
          final fp1 = fingerprint(bytes, random);
          final fp2 = fingerprint(bytes, random);
          if (fp1 != fp2) {
            final crash = FuzzCrash(
              StateError('nondeterministic: first=$fp1 second=$fp2'),
              StackTrace.current,
              'determinism',
            );
            final key = dumpCrash(crashesDir, bytes, random, crash);
            fail('nondeterministic @ iter $iters key=$key');
          }
        }
        printOnFailure('utf8 fuzz: $iters iters, seed=$_fuzzSeed');
      },
      timeout: const Timeout(Duration(hours: 1)),
    );
  });
}

// ---- explicit seed catalogue ---------------------------------------------

class _Seed {
  final String label;
  final List<int> bytes;
  const _Seed(this.label, this.bytes);
}

/// Hand-curated UTF-8 problem patterns. Categories:
///   * overlong (forbidden shorter forms)
///   * truncated (multibyte cut short, no continuation byte)
///   * invalid continuation (lead byte followed by ASCII / wrong high bits)
///   * surrogate halves encoded as UTF-8 (D800..DFFF, illegal)
///   * near U+10FFFF boundary (max codepoint and just past it)
///   * multibyte interrupted by ESC / CSI mid-sequence
///   * BOM (Dart's utf8.decode strips it → empty string, F6 regression)
const List<_Seed> _utf8Seeds = [
  // ---- overlong --------------------------------------------------------
  _Seed('overlong NUL (C0 80)', [0xc0, 0x80]),
  _Seed('overlong slash (C0 AF)', [0xc0, 0xaf]),
  _Seed('overlong 3-byte (E0 80 80)', [0xe0, 0x80, 0x80]),
  _Seed('overlong 4-byte (F0 80 80 80)', [0xf0, 0x80, 0x80, 0x80]),

  // ---- truncated -------------------------------------------------------
  _Seed('lead-only 2-byte (C2)', [0xc2]),
  _Seed('lead-only 3-byte (E0)', [0xe0]),
  _Seed('lead-only 4-byte (F0)', [0xf0]),
  _Seed('truncated 3-byte (E0 A0)', [0xe0, 0xa0]),
  _Seed('truncated 4-byte (F0 90 80)', [0xf0, 0x90, 0x80]),

  // ---- invalid continuation -------------------------------------------
  _Seed('C2 then ASCII (C2 41)', [0xc2, 0x41]),
  _Seed('E0 A0 then ASCII (E0 A0 41)', [0xe0, 0xa0, 0x41]),
  _Seed('F0 90 80 then ASCII (F0 90 80 41)', [0xf0, 0x90, 0x80, 0x41]),
  _Seed('lone continuation (80)', [0x80]),
  _Seed('lone continuation (BF)', [0xbf]),
  _Seed('5-byte lead (FB BF BF BF BF)',
      [0xfb, 0xbf, 0xbf, 0xbf, 0xbf]),
  _Seed('FE/FF (FE FF)', [0xfe, 0xff]),

  // ---- surrogate halves -----------------------------------------------
  _Seed('high surrogate (ED A0 80 = U+D800)', [0xed, 0xa0, 0x80]),
  _Seed('low surrogate (ED B0 80 = U+DC00)', [0xed, 0xb0, 0x80]),
  _Seed('high surrogate max (ED AF BF = U+DBFF)',
      [0xed, 0xaf, 0xbf]),
  _Seed('low surrogate max (ED BF BF = U+DFFF)',
      [0xed, 0xbf, 0xbf]),

  // ---- near U+10FFFF ---------------------------------------------------
  _Seed('U+10FFFF (F4 8F BF BF)', [0xf4, 0x8f, 0xbf, 0xbf]),
  _Seed('just over U+10FFFF (F4 90 80 80)',
      [0xf4, 0x90, 0x80, 0x80]),
  _Seed('F5 prefix (F5 80 80 80)', [0xf5, 0x80, 0x80, 0x80]),

  // ---- ESC/CSI interrupting multibyte ---------------------------------
  // ESC after lead byte: engine in utf8 state sees ESC, hasMore=false flushes
  // ESC key path; with hasMore=true pushes to escape state. Either way the
  // multibyte sequence is abandoned. Pair with a CSI close to make sure
  // both halves run on a non-ground state.
  _Seed('ESC after C2', [0xc2, 0x1b]),
  _Seed('ESC after E0 A0', [0xe0, 0xa0, 0x1b]),
  _Seed('ESC + [ A after F0 90 80', [0xf0, 0x90, 0x80, 0x1b, 0x5b, 0x41]),
  _Seed('CSI then 2-byte UTF-8 lead', [0x1b, 0x5b, 0x41, 0xc3]),
  _Seed('mid-multibyte CSI splice',
      [0xe4, 0xb8, 0x1b, 0x5b, 0x41, 0xad]),

  // ---- BOM (F6 regression) --------------------------------------------
  _Seed('BOM only (EF BB BF)', [0xef, 0xbb, 0xbf]),
  _Seed('BOM + ASCII', [0xef, 0xbb, 0xbf, 0x41]),

  // ---- well-formed multibyte (non-malformed control) ------------------
  _Seed('é (C3 A9)', [0xc3, 0xa9]),
  _Seed('中 (E4 B8 AD)', [0xe4, 0xb8, 0xad]),
  _Seed('😀 (F0 9F 98 80)', [0xf0, 0x9f, 0x98, 0x80]),
];

/// For seed regression: try single-chunk, per-byte, and 2-byte chunks.
List<FuzzSchedule> _seedSchedules(Uint8List bytes) {
  if (bytes.isEmpty) return [const FuzzSchedule([], [])];
  final perByte = FuzzSchedule(
    List<int>.filled(bytes.length, 1),
    List<bool>.generate(bytes.length, (i) => i < bytes.length - 1),
  );
  final twoByte = <int>[];
  final twoByteMore = <bool>[];
  for (var i = 0; i < bytes.length; i += 2) {
    final size = (i + 2 <= bytes.length) ? 2 : bytes.length - i;
    twoByte.add(size);
    twoByteMore.add(i + size < bytes.length);
  }
  return [
    FuzzSchedule.single(bytes.length),
    perByte,
    FuzzSchedule(twoByte, twoByteMore),
  ];
}

// ---- mutation ------------------------------------------------------------

/// Build an input by picking 1..3 seeds, applying 0..3 mutations to each,
/// and concatenating with optional ASCII filler / ESC noise between them.
Uint8List _genMutatedInput(Random rng) {
  final out = <int>[];
  final nSeeds = 1 + rng.nextInt(3);
  for (var i = 0; i < nSeeds; i++) {
    final seed = _utf8Seeds[rng.nextInt(_utf8Seeds.length)];
    final mutated = _mutate(rng, seed.bytes);
    if (out.length + mutated.length > _maxBytes) break;
    out.addAll(mutated);

    // Inter-seed filler: short ASCII, optional ESC[A, or empty.
    final f = rng.nextInt(100);
    if (f < 30 && out.length < _maxBytes - 4) {
      out.addAll(const [0x1b, 0x5b, 0x41]); // CSI A — return-to-ground probe
    } else if (f < 60 && out.length < _maxBytes - 1) {
      out.add(0x20 + rng.nextInt(95));
    }
  }
  return Uint8List.fromList(out);
}

/// Mutators stack: bit flip, byte flip, drop, insert, splice ESC/CSI, double.
/// Each call applies 0..3 of these in random order. Mutations may make a
/// "valid" seed invalid or vice versa — both shapes are interesting for fuzz.
List<int> _mutate(Random rng, List<int> seed) {
  final buf = List<int>.from(seed);
  final n = rng.nextInt(4);
  for (var i = 0; i < n; i++) {
    if (buf.isEmpty && rng.nextInt(100) < 50) {
      buf.add(rng.nextInt(256));
      continue;
    }
    final op = rng.nextInt(6);
    switch (op) {
      case 0: // bit flip
        if (buf.isEmpty) break;
        final idx = rng.nextInt(buf.length);
        buf[idx] = buf[idx] ^ (1 << rng.nextInt(8));
      case 1: // byte replace
        if (buf.isEmpty) break;
        final idx = rng.nextInt(buf.length);
        buf[idx] = rng.nextInt(256);
      case 2: // drop byte
        if (buf.isEmpty) break;
        buf.removeAt(rng.nextInt(buf.length));
      case 3: // insert byte
        final idx = rng.nextInt(buf.length + 1);
        buf.insert(idx, _utf8FlavoredByte(rng));
      case 4: // splice ESC or CSI
        final idx = rng.nextInt(buf.length + 1);
        final splice = rng.nextBool()
            ? const [0x1b]
            : const [0x1b, 0x5b, 0x41];
        buf.insertAll(idx, splice);
      case 5: // duplicate a slice
        if (buf.isEmpty) break;
        final start = rng.nextInt(buf.length);
        final end = start + 1 + rng.nextInt(buf.length - start);
        buf.insertAll(end, buf.sublist(start, end));
    }
    if (buf.length > _maxBytes) {
      buf.removeRange(_maxBytes, buf.length);
    }
  }
  return buf;
}

/// Byte distribution biased toward UTF-8 lead/continuation territory:
///   25% 2-byte lead (0xc0..0xdf)
///   20% 3-byte lead (0xe0..0xef)
///   15% 4-byte lead (0xf0..0xf7)
///   25% continuation (0x80..0xbf)
///   05% ESC (0x1b)
///   10% printable ASCII
int _utf8FlavoredByte(Random rng) {
  final r = rng.nextInt(100);
  if (r < 25) return 0xc0 + rng.nextInt(0x20);
  if (r < 45) return 0xe0 + rng.nextInt(0x10);
  if (r < 60) return 0xf0 + rng.nextInt(0x08);
  if (r < 85) return 0x80 + rng.nextInt(0x40);
  if (r < 90) return 0x1b;
  return 0x20 + rng.nextInt(95);
}

// ---- per-byte schedule ---------------------------------------------------

/// Feed every byte as its own chunk. `hasMore=true` for all but the last —
/// the trailing-ESC-as-key path is exercised by other harnesses; here we
/// want every multibyte split to land at a chunk boundary.
FuzzSchedule _perByteSchedule(Uint8List bytes) {
  if (bytes.isEmpty) return const FuzzSchedule([], []);
  return FuzzSchedule(
    List<int>.filled(bytes.length, 1),
    List<bool>.generate(bytes.length, (i) => i < bytes.length - 1),
  );
}
