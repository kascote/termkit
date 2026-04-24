/// Structured fuzz harness (Phase 5): grammar-driven sequence generation.
///
/// Generates programs = concatenations of N sequences drawn from CSI / OSC /
/// DCS / textBlock / ESC-O grammars. Each generated sequence is tagged
/// `wellFormed` — when every sequence in the program is well-formed, the
/// parser is expected to end in ground state after flush with zero
/// `ErrorEvent`s. Malformed variants are still fuzzed for crash-only oracle.
///
/// Invariants (Phase 7) applied — `runOnce` enforces:
///   * no throw from advance / nextEvent / drainEvents
///   * eventCount <= input.length
///   * sequenceByteCount cap (PLAN expects fuzzer to surface unterminated
///     OSC/DCS → engine cap added as follow-up)
///   * no NoneEvent leaks
///
/// Plus, this harness:
///   * well-formed program, fed as a single chunk (hasMore=false), →
///     state == ground AND errorEventCount == 0. The single-chunk scope
///     sidesteps chunk-boundary ambiguity (ESC+hasMore=false mid-sequence
///     is a legitimate engine choice and not the oracle we want here).
///   * under the *random* schedule: crash-only + determinism only.
///   * replays every `.bin` under `crashes/` first (regression guard)
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

import 'package:termparser/src/engine/engine.dart' show State;
import 'package:test/test.dart';

import '../_support/harness.dart';
import '../_support/schedule.dart';

final String _fuzzMode = Platform.environment['FUZZ_MODE'] ?? '';
final int _fuzzIter =
    int.tryParse(Platform.environment['FUZZ_ITER'] ?? '') ?? 10000;
final int _fuzzSecs = int.tryParse(Platform.environment['FUZZ_SECS'] ?? '') ?? 0;
final int _fuzzSeed =
    int.tryParse(Platform.environment['FUZZ_SEED'] ?? '') ?? 0xC0FFEE;

const int _maxBytesPerProgram = 4096;
const int _maxSeqsPerProgram = 8;

void main() {
  final crashesDir = defaultCrashesDir();

  group('structured fuzz', () {
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
      'grammar programs + chunking + hasMore '
      '(${_fuzzSecs > 0 ? "${_fuzzSecs}s" : "$_fuzzIter iters"})',
      () {
        final rng = Random(_fuzzSeed);
        final timeBudget = _fuzzSecs > 0;
        final deadline =
            timeBudget ? DateTime.now().add(Duration(seconds: _fuzzSecs)) : null;
        final iterCap = timeBudget ? 1 << 30 : _fuzzIter;

        var iters = 0;
        while (iters < iterCap) {
          if (timeBudget && !DateTime.now().isBefore(deadline!)) break;
          iters++;

          final prog = _genProgram(rng);
          final bytes = prog.bytes;
          final schedule = randomSchedule(rng, bytes);

          // Random schedule: crash-only oracle.
          final outcome = runOnce(bytes, schedule);
          if (outcome is FuzzCrash) {
            final key = dumpCrash(crashesDir, bytes, schedule, outcome);
            fail('crash @ iter $iters seed=$_fuzzSeed key=$key '
                'inv=${outcome.invariant} err=${outcome.error}');
          }

          // Single-chunk schedule: well-formed → ground + no ErrorEvent.
          if (prog.allWellFormed) {
            final single = FuzzSchedule.single(bytes.length);
            final singleOutcome = runOnce(bytes, single);
            if (singleOutcome is FuzzCrash) {
              final key = dumpCrash(crashesDir, bytes, single, singleOutcome);
              fail('single-chunk crash @ iter $iters key=$key '
                  'inv=${singleOutcome.invariant} err=${singleOutcome.error}');
            }
            final ok = singleOutcome as FuzzOk;
            if (ok.finalState != State.ground) {
              final crash = FuzzCrash(
                StateError(
                    'well-formed program did not return to ground: ${ok.finalState}'),
                StackTrace.current,
                'wellformed_ground',
              );
              final key = dumpCrash(crashesDir, bytes, single, crash);
              fail('non-ground @ iter $iters key=$key state=${ok.finalState}');
            }
            if (ok.errorEventCount > 0) {
              final crash = FuzzCrash(
                StateError(
                    'well-formed program produced ${ok.errorEventCount} ErrorEvent(s)'),
                StackTrace.current,
                'wellformed_errors',
              );
              final key = dumpCrash(crashesDir, bytes, single, crash);
              fail('errors on well-formed @ iter $iters key=$key');
            }
          }

          // Determinism: two fresh parsers, identical input → identical events.
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
        printOnFailure('structured fuzz: $iters iters, seed=$_fuzzSeed');
      },
      timeout: const Timeout(Duration(hours: 1)),
    );
  });
}

// ---- program assembly ----------------------------------------------------

class _Seq {
  final List<int> bytes;
  final bool wellFormed;
  const _Seq(this.bytes, {required this.wellFormed});
}

class _Program {
  final Uint8List bytes;
  final bool allWellFormed;
  const _Program(this.bytes, {required this.allWellFormed});
}

_Program _genProgram(Random rng) {
  final count = 1 + rng.nextInt(_maxSeqsPerProgram);
  final buf = <int>[];
  var allWellFormed = true;
  for (var i = 0; i < count; i++) {
    final r = rng.nextInt(100);
    final seq = switch (r) {
      < 35 => _genCsi(rng),
      < 60 => _genOsc(rng),
      < 75 => _genDcs(rng),
      < 90 => _genTextBlock(rng),
      _ => _genEscO(rng),
    };
    if (buf.length + seq.bytes.length > _maxBytesPerProgram) break;
    buf.addAll(seq.bytes);
    if (!seq.wellFormed) allWellFormed = false;
  }
  return _Program(Uint8List.fromList(buf), allWellFormed: allWellFormed);
}

// ---- grammars ------------------------------------------------------------

/// CSI: `ESC [ [<private>]? (<param>(;<param>)*)? (<intermediate>)* <final>`
/// Params may be empty, int, or int with `:`-separated subparams.
/// Final usually in 0x40..0x7e; sometimes invalid / mid-sequence ESC.
_Seq _genCsi(Random rng) {
  final buf = <int>[0x1b, 0x5b]; // ESC [
  var wellFormed = true;

  // 40% private marker '?' '<' '>' '='
  if (rng.nextInt(100) < 40) {
    buf.add(const [0x3f, 0x3c, 0x3e, 0x3d][rng.nextInt(4)]);
  }

  final nParams = rng.nextInt(41); // 0..40
  var firstParamIs200or201 = false;
  for (var i = 0; i < nParams; i++) {
    if (i > 0) buf.add(0x3b); // ;
    final pKind = rng.nextInt(4);
    switch (pKind) {
      case 0: // empty
        break;
      case 1: // plain int
        final v = rng.nextInt(65536);
        if (i == 0 && (v == 200 || v == 201)) firstParamIs200or201 = true;
        _appendInt(buf, v);
      case 2: // int with 1..4 ':'-subparams
        final v = rng.nextInt(65536);
        if (i == 0 && (v == 200 || v == 201)) firstParamIs200or201 = true;
        _appendInt(buf, v);
        final subN = 1 + rng.nextInt(4);
        for (var k = 0; k < subN; k++) {
          buf.add(0x3a);
          _appendInt(buf, rng.nextInt(256));
        }
      case 3: // trailing-empty subparam (e.g. "5:")
        final v = rng.nextInt(256);
        if (i == 0 && (v == 200 || v == 201)) firstParamIs200or201 = true;
        _appendInt(buf, v);
        buf.add(0x3a);
    }
  }

  // 0..4 intermediates (0x20..0x2f)
  final nInter = rng.nextInt(5);
  for (var i = 0; i < nInter; i++) {
    buf.add(0x20 + rng.nextInt(0x30 - 0x20));
  }

  final r = rng.nextInt(100);
  int fin;
  if (r < 85) {
    fin = 0x40 + rng.nextInt(0x7e - 0x40 + 1);
  } else if (r < 95) {
    // ESC mid-sequence — triggers engine error path
    buf.add(0x1b);
    return _Seq(buf, wellFormed: false);
  } else {
    // invalid final byte (< 0x40) — cancels to ground, no event
    fin = 0x01;
    wellFormed = false;
  }

  // If first param is 200/201 and final is '~', we'd enter/exit textBlock —
  // reserve that path for _genTextBlock. Re-roll final to 'm'.
  if (firstParamIs200or201 && fin == 0x7e) fin = 0x6d;

  buf.add(fin);
  return _Seq(buf, wellFormed: wellFormed);
}

/// OSC: `ESC ] <number> ';' <payload> <terminator>`
/// Terminator: ST (ESC \) | BEL (unsupported here → unterminated) | none | wrong.
_Seq _genOsc(Random rng) {
  final buf = <int>[0x1b, 0x5d]; // ESC ]

  // OSC number — weighted toward real codes, occasionally random / non-numeric.
  final r0 = rng.nextInt(100);
  if (r0 < 70) {
    const real = [0, 7, 8, 9, 10, 11, 52, 66, 133, 1337, 3008, 5522];
    _appendInt(buf, real[rng.nextInt(real.length)]);
  } else if (r0 < 90) {
    _appendInt(buf, rng.nextInt(65536));
  } else {
    // Non-digit first byte cancels the OSC in _advanceOscEntryState → ground.
    buf.add(0x41 + rng.nextInt(26));
    return _Seq(buf, wellFormed: false);
  }

  buf.add(0x3b); // ;

  // payload
  final pKind = rng.nextInt(100);
  if (pKind < 40) {
    final n = rng.nextInt(64);
    for (var i = 0; i < n; i++) {
      buf.add(0x20 + rng.nextInt(95));
    }
  } else if (pKind < 70) {
    const alpha =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=';
    final n = rng.nextInt(64);
    for (var i = 0; i < n; i++) {
      buf.add(alpha.codeUnitAt(rng.nextInt(alpha.length)));
    }
  } else if (pKind < 90) {
    final n = rng.nextInt(32);
    for (var i = 0; i < n; i++) {
      _appendUtf8(buf, rng.nextInt(0x10000));
    }
  } else {
    final n = rng.nextInt(64);
    for (var i = 0; i < n; i++) {
      var b = rng.nextInt(256);
      // 0x1b in payload would transition oscParameter → oscFinal early;
      // allowed but treat as unterminated unless followed by '\'.
      if (b == 0x1b) b = 0x20;
      buf.add(b);
    }
  }

  // terminator
  final tKind = rng.nextInt(100);
  if (tKind < 70) {
    // ST: ESC \
    buf..add(0x1b)..add(0x5c);
    return _Seq(buf, wellFormed: true);
  } else if (tKind < 85) {
    // BEL — engine treats as payload byte; OSC stays open
    buf.add(0x07);
    return _Seq(buf, wellFormed: false);
  } else if (tKind < 95) {
    // wrong terminator: ESC + non-'\'
    buf..add(0x1b)..add(0x58);
    // _advanceOscFinalState drops to ground silently, no event → clean state.
    return _Seq(buf, wellFormed: true);
  } else {
    // no terminator → OSC stuck open
    return _Seq(buf, wellFormed: false);
  }
}

/// DCS narrow shape (what the engine accepts without erroring):
///   `ESC P <private>? <final 0x28..0x7e> <data> ESC \`
///
/// dcsEntry accepts `<=>?` as private markers, then any byte in 0x28..0x7e
/// transitions to textBlock (engine has a decimal-vs-hex quirk: the case
/// `>= 40 && <= 0x7E` is 0x28..0x7e, *not* 0x40..0x7e). It does NOT accept
/// numeric params or `;` separators. Broader shapes are still fuzzed but
/// tagged malformed so the ground/no-error oracle doesn't fire on them.
_Seq _genDcs(Random rng) {
  final buf = <int>[0x1b, 0x50]; // ESC P
  final narrow = rng.nextInt(100) < 50;

  if (narrow) {
    if (rng.nextBool()) {
      buf.add(const [0x3c, 0x3d, 0x3e, 0x3f][rng.nextInt(4)]);
    }
    buf.add(0x28 + rng.nextInt(0x7e - 0x28 + 1));
    final n = rng.nextInt(256);
    for (var i = 0; i < n; i++) {
      var b = rng.nextInt(256);
      if (b == 0x1b) b = 0x20;
      buf.add(b);
    }
    buf
      ..add(0x1b)
      ..add(0x5c);
    return _Seq(buf, wellFormed: true);
  }

  // broad: numeric params + intermediates + mixed bytes. crash-only oracle.
  if (rng.nextBool()) {
    buf.add(const [0x3c, 0x3d, 0x3e, 0x3f][rng.nextInt(4)]);
  }
  final nParams = rng.nextInt(5);
  for (var i = 0; i < nParams; i++) {
    if (i > 0) buf.add(0x3b);
    _appendInt(buf, rng.nextInt(256));
  }
  final nInter = rng.nextInt(3);
  for (var i = 0; i < nInter; i++) {
    buf.add(0x20 + rng.nextInt(0x30 - 0x20));
  }
  buf.add(0x40 + rng.nextInt(0x7e - 0x40 + 1));
  final n = rng.nextInt(256);
  for (var i = 0; i < n; i++) {
    var b = rng.nextInt(256);
    if (b == 0x1b) b = 0x20;
    buf.add(b);
  }
  if (rng.nextInt(100) < 85) {
    buf
      ..add(0x1b)
      ..add(0x5c);
  }
  return _Seq(buf, wellFormed: false);
}

/// TextBlock (bracketed paste): `ESC [ 200 ~ <payload> ESC [ 201 ~`
/// Variants: nested inner 200, mismatched close (299~), unterminated.
_Seq _genTextBlock(Random rng) {
  final buf = <int>[0x1b, 0x5b, 0x32, 0x30, 0x30, 0x7e]; // ESC [ 200 ~

  // payload — printable, embedded CSI like `ESC [ 2 D` (engine treats as
  // literal paste content), and random non-ESC bytes. Raw ESC is excluded:
  // an ESC followed by certain next bytes (e.g. `[ ESC`) pushes the engine
  // into csiEntry where the *next* ESC triggers an ErrorEvent — a separate
  // malformed case we don't want fused into "well-formed paste".
  final n = rng.nextInt(256);
  for (var i = 0; i < n; i++) {
    final r = rng.nextInt(100);
    if (r < 70) {
      buf.add(0x20 + rng.nextInt(95));
    } else if (r < 90) {
      buf.addAll(const [0x1b, 0x5b, 0x32, 0x44]);
    } else {
      var b = rng.nextInt(256);
      if (b == 0x1b) b = 0x20;
      buf.add(b);
    }
  }

  final mode = rng.nextInt(100);
  if (mode < 55) {
    // normal close
    buf.addAll(const [0x1b, 0x5b, 0x32, 0x30, 0x31, 0x7e]);
    return _Seq(buf, wellFormed: true);
  } else if (mode < 70) {
    // inner 200 (becomes literal content), then outer close
    buf
      ..addAll(const [0x1b, 0x5b, 0x32, 0x30, 0x30, 0x7e])
      ..addAll(const [0x1b, 0x5b, 0x32, 0x30, 0x31, 0x7e]);
    return _Seq(buf, wellFormed: true);
  } else if (mode < 85) {
    // mismatched close — engine dispatches CSI 299~, clears _inTextBlock, ground
    buf.addAll(const [0x1b, 0x5b, 0x32, 0x39, 0x39, 0x7e]);
    return _Seq(buf, wellFormed: true);
  } else {
    // unterminated
    return _Seq(buf, wellFormed: false);
  }
}

/// `ESC O <char>` — targeted F1..F4 (P/Q/R/S) plus some other printable follows.
_Seq _genEscO(Random rng) {
  final r = rng.nextInt(100);
  final fin = r < 70
      ? 'PQRS'.codeUnitAt(rng.nextInt(4))
      : 0x20 + rng.nextInt(95);
  return _Seq([0x1b, 0x4f, fin], wellFormed: true);
}

// ---- helpers -------------------------------------------------------------

void _appendInt(List<int> buf, int n) {
  final s = n.toString();
  for (var i = 0; i < s.length; i++) {
    buf.add(s.codeUnitAt(i));
  }
}

void _appendUtf8(List<int> buf, int cp) {
  if (cp < 0x80) {
    buf.add(cp);
  } else if (cp < 0x800) {
    buf
      ..add(0xc0 | (cp >> 6))
      ..add(0x80 | (cp & 0x3f));
  } else {
    buf
      ..add(0xe0 | (cp >> 12))
      ..add(0x80 | ((cp >> 6) & 0x3f))
      ..add(0x80 | (cp & 0x3f));
  }
}
