/// Structured fuzz harness (Phase 5): grammar-driven sequence generation.
///
/// Generates programs = concatenations of N sequences drawn from CSI / OSC /
/// DCS / textBlock / ESC-O grammars. Each generated sequence is tagged
/// `wellFormed` — when every sequence in the program is well-formed, the
/// parser is expected to end in ground state after flush with zero
/// `ErrorEvent`s. Malformed variants are still fuzzed for crash-only oracle.
///
/// Invariants applied (Phase 7 — see `_support/invariants.dart`):
///   * `runOnce`: no throw, eventCount <= input.length, sequenceByteCount cap,
///     no NoneEvent leaks
///   * harness-level: determinism + replay of `crashes/`
///   * well-formed → ground (single-chunk schedule only — random schedule
///     legitimately splits on ESC+hasMore=false, which is not the oracle we
///     want here)
///   * DCS shape oracle: each generated hook/abandon DCS sub-sequence is
///     replayed in isolation through a fresh `Engine` (bypassing `Parser`)
///     to check whether it produced a `DcsSequenceData` — see
///     `_assertDcsShapeOutcome` for why the Parser/Event level can't observe
///     this
///
/// The generative loop is OPT-IN: skipped under a plain `dart test` / `make test`.
/// It runs only when FUZZ_ITER or FUZZ_SECS is set, i.e. via `make fuzz` / `make fuzz-time`.
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

import 'package:termparser/src/engine/engine.dart' show Engine, State;
import 'package:termparser/src/engine/sequence_data.dart' show DcsSequenceData;
import 'package:test/test.dart';

import '../_support/harness.dart';
import '../_support/invariants.dart';
import '../_support/schedule.dart';

final String _fuzzMode = Platform.environment['FUZZ_MODE'] ?? '';
final int _fuzzIter = int.tryParse(Platform.environment['FUZZ_ITER'] ?? '') ?? 10000;
final int _fuzzSecs = int.tryParse(Platform.environment['FUZZ_SECS'] ?? '') ?? 0;

/// The heavy generative loop is opt-in: a plain `dart test` / `make test` skips
/// it (kept fast — `replay crashes/` + corpus remain as regression guards). It
/// runs only when a fuzz knob is set, i.e. via `make fuzz` / `make fuzz-time`.
final bool _fuzzEnabled =
    Platform.environment.containsKey('FUZZ_ITER') || Platform.environment.containsKey('FUZZ_SECS');
final int _fuzzSeed = int.tryParse(Platform.environment['FUZZ_SEED'] ?? '') ?? 0xC0FFEE;

const int _maxBytesPerProgram = 4096;
const int _maxSeqsPerProgram = 8;

Future<void> main() async {
  final crashesDir = await defaultCrashesDir();

  group('structured fuzz', () {
    test('replay crashes/ (regression guard)', () => replayCrashes(crashesDir));

    if (_fuzzMode == 'replay') return;

    test(
      'grammar programs + chunking + hasMore '
      '(${_fuzzSecs > 0 ? "${_fuzzSecs}s" : "$_fuzzIter iters"})',
      () {
        final rng = Random(_fuzzSeed);
        final timeBudget = _fuzzSecs > 0;
        final deadline = timeBudget ? DateTime.now().add(Duration(seconds: _fuzzSecs)) : null;
        final iterCap = timeBudget ? 1 << 30 : _fuzzIter;

        var iters = 0;
        while (iters < iterCap) {
          if (timeBudget && !DateTime.now().isBefore(deadline!)) break;
          iters++;

          final prog = _genProgram(rng);
          final bytes = prog.bytes;
          final schedule = randomSchedule(rng, bytes);

          // Random schedule: crash-only oracle.
          assertNoCrash(
            runOnce(bytes, schedule),
            bytes,
            schedule,
            crashesDir: crashesDir,
            iter: iters,
            seed: _fuzzSeed,
          );

          // Single-chunk schedule: well-formed → ground + no ErrorEvent.
          if (prog.allWellFormed) {
            assertWellFormedGround(
              bytes,
              crashesDir: crashesDir,
              iter: iters,
              seed: _fuzzSeed,
              label: 'well-formed program',
            );
          }

          // Per-shape DCS dispatch oracle: each hook/abandon sub-sequence
          // generated this iteration is replayed in isolation and checked
          // against its expected DcsSequenceData outcome.
          for (final check in prog.dcsChecks) {
            _assertDcsShapeOutcome(
              check,
              crashesDir: crashesDir,
              iter: iters,
              seed: _fuzzSeed,
            );
          }

          assertDeterminism(
            bytes,
            schedule,
            crashesDir: crashesDir,
            iter: iters,
          );
        }
        printOnFailure('structured fuzz: $iters iters, seed=$_fuzzSeed');
      },
      timeout: const Timeout(Duration(hours: 1)),
      skip: _fuzzEnabled ? false : 'opt-in: run via `make fuzz` (set FUZZ_ITER/FUZZ_SECS)',
    );
  });
}

// ---- program assembly ----------------------------------------------------

/// Which DEC DCS header shape a generated `_Seq` took, for sequences
/// produced by [_genDcs]. `null` (the default on [_Seq]) means "not a DCS
/// sequence with a known shape to assert on" (e.g. CSI/OSC/textBlock/ESC-O,
/// or a deliberately-unterminated DCS malformed variant).
enum _DcsShape {
  /// Header ends in a real hook byte (0x40-0x7E): must dispatch exactly one
  /// `DcsSequenceData` at ST.
  hook,

  /// Header is abandoned by a ':' before any hook byte, landing in
  /// `dcsIgnore`: must dispatch zero `DcsSequenceData`.
  abandon,
}

class _Seq {
  final List<int> bytes;
  final bool wellFormed;
  final _DcsShape? dcsShape;
  const _Seq(this.bytes, {required this.wellFormed, this.dcsShape});
}

/// A DCS sub-sequence pulled out of a generated program, paired with the
/// shape it was generated as, for the per-shape dispatch oracle.
class _DcsCheck {
  final Uint8List bytes;
  final _DcsShape shape;
  const _DcsCheck(this.bytes, this.shape);
}

class _Program {
  final Uint8List bytes;
  final bool allWellFormed;
  final List<_DcsCheck> dcsChecks;
  const _Program(this.bytes, {required this.allWellFormed, this.dcsChecks = const []});
}

_Program _genProgram(Random rng) {
  final count = 1 + rng.nextInt(_maxSeqsPerProgram);
  final buf = <int>[];
  var allWellFormed = true;
  final dcsChecks = <_DcsCheck>[];
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
    final shape = seq.dcsShape;
    if (shape != null) {
      dcsChecks.add(_DcsCheck(Uint8List.fromList(seq.bytes), shape));
    }
  }
  return _Program(Uint8List.fromList(buf), allWellFormed: allWellFormed, dcsChecks: dcsChecks);
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
    const alpha = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=';
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
      // 0x1b/0x18/0x1a in payload are anywhere-rule bytes (ESC starts a new
      // top-level sequence early; CAN/SUB cancel the OSC outright via
      // _cancelAndDeliver) — any of them mid-payload snaps the engine back to
      // ground while this loop keeps appending bytes meant to be OSC
      // content, corrupting the well-formed assumption for everything after.
      if (b == 0x1b || b == 0x18 || b == 0x1a) b = 0x20;
      buf.add(b);
    }
  }

  // terminator
  final tKind = rng.nextInt(100);
  if (tKind < 70) {
    // ST: ESC \
    buf
      ..add(0x1b)
      ..add(0x5c);
    return _Seq(buf, wellFormed: true);
  } else if (tKind < 85) {
    // BEL — engine treats as payload byte; OSC stays open
    buf.add(0x07);
    return _Seq(buf, wellFormed: false);
  } else if (tKind < 95) {
    // wrong terminator: ESC + non-'\'
    buf
      ..add(0x1b)
      ..add(0x58);
    // _advanceOscFinalState drops to ground silently, no event → clean state.
    return _Seq(buf, wellFormed: true);
  } else {
    // no terminator → OSC stuck open
    return _Seq(buf, wellFormed: false);
  }
}

/// DCS: `ESC P <header> <hook 0x40..0x7e> <content> ESC \`, where
/// `<header>` is zero or more tokens drawn from digit runs (multi-digit
/// parameters), `;` delimiters, private markers (0x3C-0x3F), and
/// intermediates (0x20-0x2F), in any combination — matching dcsEntry's
/// current DEC-shaped grammar: digits extend a pending parameter, `;`
/// stores it, private markers store immediately, intermediates flush the
/// pending parameter then start collecting themselves, and only a byte in
/// 0x40-0x7E hooks the opaque passthrough (dispatching `DcsSequenceData` at
/// ST). A `:` anywhere in the header instead abandons it into `dcsIgnore` —
/// no hook, no dispatch, every following byte dropped until ST/anywhere-rule.
///
/// Three shapes are generated:
///   * `hook`    (55%) — well-formed header, then a real hook byte, then
///     opaque content, then ST. Tagged [_DcsShape.hook]: must dispatch
///     exactly one `DcsSequenceData`.
///   * `abandon` (30%) — well-formed header, then `:` (abandoning into
///     `dcsIgnore`), then inert filler, then ST. Tagged [_DcsShape.abandon]:
///     the header never hooks, so this must dispatch zero
///     `DcsSequenceData` even though it's well-formed input worth fuzzing.
///   * unterminated (15%) — header, optional `:`, optional hook + content,
///     but no ST: left open for the concatenation-level crash-only oracle.
///     Untagged (`dcsShape: null`): it never reaches ST, so there's no
///     dispatch outcome to assert.
_Seq _genDcs(Random rng) {
  final buf = <int>[0x1b, 0x50]; // ESC P
  final r = rng.nextInt(100);

  if (r < 55) {
    _appendDcsHeader(rng, buf);
    buf.add(0x40 + rng.nextInt(0x7e - 0x40 + 1)); // hook byte
    _appendDcsContent(rng, buf);
    buf
      ..add(0x1b)
      ..add(0x5c);
    return _Seq(buf, wellFormed: true, dcsShape: _DcsShape.hook);
  }

  if (r < 85) {
    _appendDcsHeader(rng, buf);
    buf.add(0x3a); // ':' abandons the header into dcsIgnore
    // dcsIgnore drops every byte 0x00-0x7F outright — except ESC/CAN/SUB,
    // which are anywhere-rule bytes that exit it early. A stray ESC here
    // would hand the *rest* of this filler (plus the deliberate ST appended
    // below) to a fresh top-level escape sequence instead, which can easily
    // reassemble into an unrelated real DCS hook — a false dispatch for
    // this shape. Keep the filler clear of all three so dcsIgnore is the
    // only thing consuming it, all the way to the ST below.
    final n = rng.nextInt(64);
    for (var i = 0; i < n; i++) {
      var b = rng.nextInt(0x80);
      if (b == 0x1b || b == 0x18 || b == 0x1a) b = 0x20;
      buf.add(b);
    }
    buf
      ..add(0x1b)
      ..add(0x5c);
    return _Seq(buf, wellFormed: true, dcsShape: _DcsShape.abandon);
  }

  // unterminated: header, maybe an abandon ':', maybe a hook + content, but
  // deliberately no ST — crash-only oracle (no ground/dispatch assertion).
  _appendDcsHeader(rng, buf);
  if (rng.nextBool()) buf.add(0x3a);
  if (rng.nextBool()) {
    buf.add(0x40 + rng.nextInt(0x7e - 0x40 + 1));
    _appendDcsContent(rng, buf);
  }
  return _Seq(buf, wellFormed: false);
}

/// Appends a DCS header: 0-7 tokens, each a digit run (extends/starts a
/// parameter), `;` (stores it), a private marker (0x3C-0x3F, stored
/// immediately), or an intermediate (0x20-0x2F, flush-then-collect). All
/// token bytes are < 0x40, so none of them can accidentally land on a hook
/// byte or the anywhere-rule bytes (ESC/CAN/SUB).
void _appendDcsHeader(Random rng, List<int> buf) {
  final nTokens = rng.nextInt(8);
  for (var i = 0; i < nTokens; i++) {
    switch (rng.nextInt(4)) {
      case 0: // digit run
        final len = 1 + rng.nextInt(4);
        for (var k = 0; k < len; k++) {
          buf.add(0x30 + rng.nextInt(10));
        }
      case 1: // ';' delimiter
        buf.add(0x3b);
      case 2: // private marker
        buf.add(const [0x3c, 0x3d, 0x3e, 0x3f][rng.nextInt(4)]);
      case 3: // intermediate
        buf.add(0x20 + rng.nextInt(0x30 - 0x20));
    }
  }
}

/// Appends opaque DCS passthrough content, filtered the same way as the
/// header: ESC/CAN/SUB are anywhere-rule bytes (ESC ends the string via ST
/// or cancels it; CAN/SUB unhook-and-cancel outright, since plain DCS
/// passthrough — unlike bracketed paste's `_inTextBlock`-guarded swallow —
/// has no exemption for them), so any of them mid-content would end the
/// string early while this loop keeps appending bytes meant to land inside
/// it.
void _appendDcsContent(Random rng, List<int> buf) {
  final n = rng.nextInt(256);
  for (var i = 0; i < n; i++) {
    var b = rng.nextInt(256);
    if (b == 0x1b || b == 0x18 || b == 0x1a) b = 0x20;
    buf.add(b);
  }
}

/// Drives `check.bytes` through a fresh [Engine] directly — not through
/// `Parser` — and asserts the dispatch outcome matches `check.shape`.
///
/// `Parser`'s DCS translator (`parseDcsSequence`) only turns a
/// `DcsSequenceData` into a consumer-facing `Event` for the one shape it
/// recognises (XTVERSION replies); every other well-formed DCS hook
/// translates to no `Event` at all. That means the shared `FuzzOutcome`
/// (`eventCount`/`errorEventCount`/`finalState`, all read off `Parser`)
/// genuinely cannot see whether the engine hooked — the signal is dropped
/// a layer below where `runOnce` observes. Reading `Engine.advance()`'s
/// per-byte return value directly, replicating `Parser.advance()`'s own
/// `hasMore` bookkeeping for a single full-buffer chunk, is the only way to
/// observe it; hence this bypasses `harness.dart`'s `runOnce`/`FuzzOutcome`
/// machinery for this one check instead of extending it.
void _assertDcsShapeOutcome(
  _DcsCheck check, {
  required Directory crashesDir,
  required int iter,
  required int seed,
}) {
  final engine = Engine();
  var dispatches = 0;
  for (var i = 0; i < check.bytes.length; i++) {
    final data = engine.advance(check.bytes[i], hasMore: i < check.bytes.length - 1);
    if (data is DcsSequenceData) dispatches++;
  }

  final expectDispatch = check.shape == _DcsShape.hook;
  final actualDispatch = expectDispatch ? dispatches == 1 : dispatches == 0;
  if (actualDispatch && engine.currentState == State.ground) return;

  final schedule = FuzzSchedule.single(check.bytes.length);
  final crash = FuzzCrash(
    StateError(
      'dcs ${check.shape.name}: expected dispatch=$expectDispatch (1 DcsSequenceData) '
      'got dispatches=$dispatches finalState=${engine.currentState}',
    ),
    StackTrace.current,
    'dcs_shape_${check.shape.name}',
  );
  final key = dumpCrash(crashesDir, check.bytes, schedule, crash);
  fail(
    'dcs ${check.shape.name} @ iter $iter seed=$seed key=$key '
    'dispatches=$dispatches state=${engine.currentState}',
  );
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
  final fin = r < 70 ? 'PQRS'.codeUnitAt(rng.nextInt(4)) : 0x20 + rng.nextInt(95);
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
    // ESC/CAN/SUB embedded raw are anywhere-rule bytes: ESC opens a fresh
    // top-level sequence, CAN/SUB cancel whatever's open via
    // _cancelAndDeliver. Either snaps the engine back to ground mid-payload,
    // corrupting the well-formed assumption for every byte appended after —
    // see the matching substitution in the raw-bytes payload branch above.
    buf.add(cp == 0x1b || cp == 0x18 || cp == 0x1a ? 0x20 : cp);
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
