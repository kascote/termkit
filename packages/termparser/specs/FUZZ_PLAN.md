# termparser fuzz stress test plan

## Context

Build a fuzz stress test suite for `packages/termparser`. Inspired by Ghostty's `test/fuzz-libghostty/` (AFL++ + Zig). Dart has no AFL equivalent — use `package:glados` for property-based generation + shrinking, wrapped in a custom run-loop.

Reference: <https://github.com/ghostty-org/ghostty/tree/main/test/fuzz-libghostty>

## Resolved decisions

- Oracles: **crash-only + invariants**, no round-trip (termparser is parse-only, no serializer)
- Crashes persisted to `crashes/`, **gitignored** (not committed)
- Internal state: **exposed** via `@visibleForTesting` getters on `Engine` + `Parser`
- Chunk size distribution: weighted **60% 1-byte / 30% 2–8 / 10% 9–512**
  - 1-byte maxes state-machine stress; larger chunks catch bulk-copy / accumulator boundary bugs
- Layout: inline in `packages/termparser/test/fuzz/`
- SDK bump to latest if glados requires
- Determinism invariant: same bytes + schedule → equal event lists (full-pipeline, no partial branches)
- Per-iter hang timeout: **500ms** (tune if CI flake)
- Two harnesses: **stream** (random bytes, random chunking, random `hasMore`) + **structured** (grammar-based per sequence family). One unified underfits; three Ghostty-style overkill without SIMD path.
- `eventCount ≤ input.length`: **loose bound**, keep as-is
- `_sequenceBytes` cap: **4KB invariant asserted in fuzz** — fuzzer will find unterminated OSC/DCS, engine cap added as follow-up

## Phases

- [x] **Phase 1 — scaffolding**
  - [x] add `glados` + `crypto` (sha1) to `packages/termparser/pubspec.yaml` dev_deps; bump SDK if required
  - [x] dirs: `test/fuzz/{harnesses,corpus,crashes,_support}/`  *(crashes/ gitignored)*
  - [x] `_support/harness.dart`: run-loop, crash-dumper (`<sha1>.bin` + `.txt` with hasMore+chunk schedule+stack), per-iter isolate-wrapped hang guard (default 500ms/iter). *glados adapter TODO until Phase 4 generators land.*
  - [x] Makefile targets in `packages/termparser/Makefile`:
    - `fuzz` (iter-bounded, default ITER=10000)
    - `fuzz-time` (time-bounded, default SECS=60)
    - `fuzz-replay` (crashes/ only)
    - `fuzz-corpus` (corpus/ only)
    - `fuzz-shrink FILE=...` *(`_support/shrink.dart` TODO in Phase 8)*

- [x] **Phase 2 — expose internal state for invariants**
  - [x] `@visibleForTesting` getters on `Engine`: `currentState` (already public), `sequenceByteCount`, `paramCount`, `inTextBlock`
  - [x] `Parser.engine` getter, gated `@visibleForTesting`

- [x] **Phase 3 — corpus**
  - [x] port Ghostty seeds verbatim into `test/fuzz/corpus/` — **34 files** across `parser/`, `osc/`, `stream/` subdirs (category preserved for the test to gate known-good vs intentionally malformed)
    - parser-initial: `04-c0-controls`, `05-esc-cursor-save-restore`, `09-csi-cursor-move`, `13-csi-sgr-basic`, `14-csi-sgr-256`, `15-csi-sgr-rgb`, `16-csi-decset`, `20-csi-intermediate`
    - osc-initial (all 20): OSC 52/66/133/3008/1337/5522 variants + `19-single-byte`, `20-invalid-osc-num`
    - stream-initial: `11-utf8-multibyte`, `12-malformed-utf8`, `13-incomplete-csi`, `19-many-params`, `20-csi-subparams`, `16-c1-controls`
  - [x] `corpus_test.dart`: every file → no throw, no `ErrorEvent` for known-good, known-good seed returns to `ground` after flush. 26 pass, 8 skipped pending Phase 3.5 (see F1/F2).
  - [ ] Dart-specific seeds added during Phases 4–6

- [x] **Phase 3.5 — findings from corpus (debug + fix)**

  Findings surfaced by `corpus_test.dart` before Phase 4 even ran. Each finding
  is tracked with a stable ID. Corpus tests for affected seeds are marked
  `skip: '<Fn>'` until resolved; un-skip as part of the fix.

  - [x] **F1 — NoneEvent leaks to public queue on unhandled CSI finals** *(resolved)*
    - Fix: termlib-style — parser functions return `Event?`, `null` = no event;
      `Parser._handleSequence` drops null. 24 `return const NoneEvent()` sites
      across 5 parser files → `return null`. `NoneEvent` class retained
      (still used by existing InternalEvent tests) but is no longer a sentinel.
    - Result: 7 corpus tests un-skipped, 577 tests pass, termlib unaffected.

  - [x] **F2 — parser throws `FormatException` on malformed UTF-8** *(resolved)*
    - Root cause: `lib/src/engine/utf8_decoder.dart:27` was the only
      `utf8.decode` in termparser without `allowMalformed: true`.
      Bytes `c0 af` (overlong encoding of `/`) reach the accumulator via
      the 2-byte start path, then strict decode throws on the overlong sequence.
    - Fix: one-line — add `allowMalformed: true` so malformed bytes become
      U+FFFD, matching the other 4 decode sites.
    - Result: corpus test un-skipped, **578 tests pass, 0 skipped**; termlib unaffected.

- [x] **Phase 4 — stream harness** (`harnesses/stream_fuzz_test.dart`)
  - [x] glados generator: `Uint8List` len 0..4096, byte weights biased to control bytes (0x00–0x1f, 0x7f, 0x1b, 0x9b) + high bytes
  - [x] chunk schedule: weighted 60/30/10
  - [x] `hasMore` schedule: random bool per chunk; ESC-at-chunk-boundary flip cases targeted
  - [x] applies invariants enforced by `runOnce` (no throw, eventCount bound, sequenceByteCount cap, no NoneEvent leaks) + determinism (two parsers, same input/schedule → equal event lists). Known-good→ground deferred to Phase 5/structured (random bytes can't satisfy it).
  - [x] knobs switched from `--define` to shell env vars (`dart test` doesn't forward `-D`); Makefile updated.

- [x] **Phase 4.5 — findings from stream fuzz (debug + fix)**

  - [x] **F3 — `int.parse` throws `FormatException` on non-numeric CSI param** *(resolved)*
    - Root cause: 3 `int.parse` sites under `lib/src/parsers/` could throw on
      input the engine legitimately stashes into `Parameters.values`:
      - `csi_parser.dart:163` `_parseSpecialKeyCode` — first param.
        csiEntry's default branch accepts any unhandled byte (incl. high-bit /
        multibyte) and stores it as the first param.
      - `csi_parser.dart:148` `_parseDeviceParams` — sub-params. csiParameter
        accepts `:` alongside digits, producing values like `5:0`.
      - `key_parser.dart:123-124` `modifierAndKindParse` — same `:` issue:
        `split[0]` is empty for inputs like `; :`, called from both
        `_parseSpecialKeyCode` and `_parseKeyboardEnhancedMode`.
    - Fix: switch all three to `int.tryParse(...)`; bail to `null` event on
      `_parseSpecialKeyCode`, fall through to `unknown` device attribute on
      `_parseDeviceParams`, propagate `null` into already-nullable tuple on
      `modifierAndKindParse`. `modifierAndKindParse`'s declared return type
      `(int?, int?)` already supports null — call sites already handle it.
    - Regression tests: 3 minimal reproducers in `parsers_test.dart` group
      `non-numeric CSI params do not throw >` covering all three sites.
    - Result: 583 tests pass; `make fuzz-replay` + `make fuzz ITER=10000`
      both green at default seed; stale `.bin`/`.txt` removed from `crashes/`.

- [x] **Phase 5 — structured harness** (`harnesses/structured_fuzz_test.dart`)
  - [x] CSI grammar: `ESC [` + 0..40 params (ints, empty, `:`-subparams) + 0..4 intermediates + final (0x40–0x7e incl. invalid). Reserves 200/201 + `~` for textBlock.
  - [x] OSC grammar: `ESC ]` + number (real codes / random / non-digit) + `;` + payload (printable / base64-ish / UTF-8 / random) + terminator (ST / wrong-ESC / BEL / none). BEL is tagged malformed because the engine does not accept it as OSC terminator.
  - [x] DCS grammar — **narrow well-formed** (`ESC P <private>? <final 0x28..0x7e> <data> ESC \`) 50%, **broad malformed** (numeric params + intermediates) 50%. Engine's `>= 40 && <= 0x7E` case is decimal 40 = 0x28, so intermediates overlap and numeric params are not accepted.
  - [x] textBlock (bracketed paste): `CSI 200~` + payload + `CSI 201~`, plus nested / unterminated / mismatched. Raw `ESC` excluded from random-byte payload (would fuse into unintended csiEntry error path).
  - [x] ESC-O sequences (F1–F4) targeted, plus other printable finals.
  - [x] Shared chunk-schedule + fingerprint helpers extracted to `_support/schedule.dart`; stream harness migrated.
  - [x] Well-formed oracle uses a **single-chunk** schedule (ESC+`hasMore=false` boundaries are a legitimate engine choice and shouldn't fire this oracle); random schedule still enforces crash + determinism.

- [x] **Phase 5.5 — findings from structured fuzz (debug + fix)**

  - [x] **F4 — `base64Decode` throws on malformed OSC 52 clipboard payload** *(resolved)*
    - Root cause: `_parseClipboardSequence` in `osc_parser.dart` passes `encoded` directly to `base64Decode`, which raises `FormatException` on any non-alphabet char.
    - Fix: wrap in `try` / `on FormatException` → return `null` (drop sequence).
    - Regression test: `parsers_test.dart` `osc_parser >` group.

  - [x] **F5 — `_inTextBlock` leaks past DCS-termination, `sublist` RangeError** *(resolved)*
    - Root cause: `_advanceTextBlockFinalState(0x5c)` dispatches DCS and transitions to ground but never resets `_inTextBlock`. A later `CSI 201~` re-enters the paste-close branch with a freshly cleared `_sequenceBytes`, so `sublist(5, len-6)` goes out of range.
    - Fix: clear `_inTextBlock` in `_setState` whenever transitioning to `ground`. Safe because all legit close paths already reset the flag explicitly.
    - Regression test: `parsers_test.dart` `osc_parser >` group (co-located with F4).

  - [x] **F6 — UTF-8 BOM (`EF BB BF`) decode returns empty, `ctrlOrKey` crashes** *(resolved)*
    - Root cause: Dart's `utf8.decode` silently strips a leading BOM and returns `""`. `Utf8Decoder.getCodePoint` forwarded this empty string to `parseChar` → `ctrlOrKey('')` → `''.codeUnitAt(0)` → `RangeError`.
    - Fix: drop empty decodes at the emission site (`_advanceUtf8State` skips `_provideChar` when `getCodePoint` returns `""`). BOM has no sensible `KeyEvent` representation — synthesising a fake `﻿` char would be inventing semantics the platform decoder deliberately omits.
    - Regression test: `parser_test.dart` `Parser >` group — BOM parses without throw and emits no event.

  - [x] **F7 — DCS generator too loose (test-side), wellformed_errors** *(resolved)*
    - Not an engine bug. My DCS generator produced numeric params + intermediates; engine treats them as cancellation / textBlock content, eventually producing ErrorEvent on a downstream ESC.
    - Fix: split DCS generator into narrow well-formed shape (engine's actual accept grammar) and broad malformed shape tagged `wellFormed: false`.

  - [x] **F8 — textBlock random-byte ESC fuses into csiEntry ErrorEvent (test-side)** *(resolved)*
    - Not an engine bug. Random-byte payload in paste could include `0x1b`; combined with downstream `[` + another ESC, engine entered csiEntry then raised `Unexpected Esc byte in CSI Entry state`.
    - Fix: strip `0x1b` from the random-byte payload branch of `_genTextBlock`. The explicit "embedded CSI" branch (`ESC [ 2 D`) still exercises the literal-content path.

  - Burn-in: 60s (~400k iters) at seed 0xC0FFEE + 15s per seed across 7 alt seeds → all green. Full test suite 588 tests pass.

- [x] **Phase 6 — UTF-8 patterns** (`harnesses/utf8_fuzz_test.dart`, explicit seeds + mutation)
  - [x] overlong encodings (`C0 80`, `C0 AF`, `E0 80 80`, `F0 80 80 80`)
  - [x] multibyte truncated / split across `advance()` boundaries — every
    iteration runs the input under a per-byte schedule so every multibyte
    split lands at a chunk edge
  - [x] invalid continuation bytes (`C2 41`, lone `80`/`BF`, 5-byte lead, FE/FF)
  - [x] surrogate-half UTF-8 (`ED A0 80` / `ED B0 80` / max forms)
  - [x] 4-byte near `0x10FFFF` (`F4 8F BF BF`, `F4 90 80 80`, `F5 80 80 80`)
  - [x] multibyte interrupted mid-stream by ESC/CSI (ESC / CSI splice mutators
    plus explicit seeds)
  - [x] BOM regression seed (F6) included
  - [x] Mutators: bit flip, byte replace, drop, insert (UTF-8-flavoured byte),
    ESC/CSI splice, slice duplicate. 0..3 ops per seed, 1..3 seeds per program.
  - [x] Determinism oracle on random schedule; no-throw + invariant oracle on
    both per-byte and random schedules.
  - [x] Burn-in: default seed 10000 / 20000 iters + 30s time-bounded + 5
    alternate numeric seeds × 5000 iters → all green. Full suite **591 tests**
    pass (588 → 591 from this phase's 3 tests).

- [x] **Phase 7 — invariants** (shared, applied by all harnesses)
  - [x] no throw from `advance` / `nextEvent` / `drainEvents` *(in `runOnce`)*
  - [x] `eventCount ≤ input.length` (sanity bound) *(in `runOnce`)*
  - [x] `sequenceByteCount` bounded (4KB cap assertion) *(in `runOnce`)*
  - [x] after complete known sequence + sentinel → `currentState == ground`
    *(`assertWellFormedGround` — structured harness on every well-formed
    program, utf8 harness on the three well-formed seeds)*
  - [x] no `NoneEvent` leaks to public queue *(in `runOnce`)*
  - [x] determinism: two parsers fed identical bytes + schedule → equal event
    lists *(`assertDeterminism` — applied by stream / structured / utf8
    harnesses)*
  - [x] Consolidated harness-level oracles into `_support/invariants.dart`
    (`replayCrashes`, `assertNoCrash`, `assertDeterminism`,
    `assertWellFormedGround`); all three harnesses migrated. 591-test
    suite + `make fuzz ITER=5000` + `make fuzz-replay` green.

- [x] **Phase 8 — crash corpus + triage**
  - [x] failing iter → write `crashes/<sha1>.bin` + `.txt` (schedules, stack)
    *(`dumpCrash` in `_support/harness.dart`, called from `assertNoCrash` /
    `assertDeterminism` / `assertWellFormedGround`)*
  - [x] every run replays `crashes/` first (regression guard)
    *(`replayCrashes` in `_support/invariants.dart`; `replay crashes/` test
    in each of the 3 harnesses)*
  - [x] naive shrinker: halve → drop-1-byte → keep failing, write minimized sibling
    *(`_support/shrink.dart`; halve loop then drop-1 sweeps; writes
    `<origSha1>.min.bin` + `.min.txt` next to the input. Crash criterion:
    single-chunk `runOnce` → `FuzzCrash`, matches `replayCrashes`. Verified
    end-to-end: 5002B unterminated CSI → 4098B (just over 4096-cap); double-
    crash 10007B → halved to 5004B then drop-1 to 4098B; clean input → exit 70.)*
  - [x] glados shrinkers handle generator side automatically
    *(`biasedBytesGen` in `harnesses/stream_fuzz_test.dart` exposes a
    `shrink` lambda — half + drop-last)*

## Unresolved questions

*(all resolved — see decisions above)*
