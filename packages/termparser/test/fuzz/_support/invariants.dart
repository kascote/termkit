/// Shared Phase 7 invariant helpers used by every fuzz harness.
///
/// `runOnce` (in `harness.dart`) already enforces the per-iteration invariants
/// that don't need a test-framework `fail()`:
///   * no throw from advance / nextEvent / drainEvents
///   * eventCount <= input.length
///   * sequenceByteCount <= fuzzMaxSequenceBytes
///   * no `NoneEvent` leaks
///
/// This file adds the harness-level oracles that need `package:test` to
/// produce nice failure messages and to dump crash artefacts:
///   * [replayCrashes]            — regression guard over crashes/*.bin
///   * [assertNoCrash]            — dump + fail on any [FuzzCrash]
///   * [assertDeterminism]        — same bytes + schedule → equal events
///   * [assertWellFormedGround]   — well-formed input → ground + 0 ErrorEvent
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:termparser/src/engine/engine.dart' show State;
import 'package:test/test.dart';

import 'harness.dart';
import 'schedule.dart';

/// Replay every `.bin` under [crashesDir] through `runOnce` (single-chunk).
/// Fails on the first crash. No-op when the directory is missing.
void replayCrashes(Directory crashesDir) {
  if (!crashesDir.existsSync()) return;
  final bins = crashesDir.listSync().whereType<File>().where((f) => f.path.endsWith('.bin')).toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final f in bins) {
    final bytes = Uint8List.fromList(f.readAsBytesSync());
    final outcome = runOnce(bytes, FuzzSchedule.single(bytes.length));
    if (outcome is FuzzCrash) {
      fail(
        'replay ${f.uri.pathSegments.last}: '
        'inv=${outcome.invariant} err=${outcome.error}',
      );
    }
  }
}

/// If [outcome] is a [FuzzCrash], dump it under [crashesDir] and `fail`.
/// [tag] is prefixed onto the failure message (e.g. `crash`, `single-chunk`).
void assertNoCrash(
  FuzzOutcome outcome,
  Uint8List bytes,
  FuzzSchedule schedule, {
  required Directory crashesDir,
  required int iter,
  required int seed,
  String tag = 'crash',
}) {
  if (outcome is! FuzzCrash) return;
  final key = dumpCrash(crashesDir, bytes, schedule, outcome);
  fail(
    '$tag @ iter $iter seed=$seed key=$key '
    'inv=${outcome.invariant} err=${outcome.error}',
  );
}

/// Determinism oracle (Phase 7): two fresh parsers fed identical bytes under
/// identical schedule must emit identical event lists and end in identical
/// states. Mismatches dump a crash artefact tagged `determinism`.
void assertDeterminism(
  Uint8List bytes,
  FuzzSchedule schedule, {
  required Directory crashesDir,
  required int iter,
}) {
  final fp1 = fingerprint(bytes, schedule);
  final fp2 = fingerprint(bytes, schedule);
  if (fp1 == fp2) return;
  final crash = FuzzCrash(
    StateError('nondeterministic: first=$fp1 second=$fp2'),
    StackTrace.current,
    'determinism',
  );
  final key = dumpCrash(crashesDir, bytes, schedule, crash);
  fail('nondeterministic @ iter $iter key=$key');
}

/// Well-formed → ground oracle (Phase 7): feed [bytes] as a single chunk
/// (`hasMore=false`) and assert the parser ends in [State.ground] with zero
/// `ErrorEvent`s. Single-chunk avoids the legitimate ESC-at-boundary
/// ambiguity introduced by random schedules.
///
/// Returns silently when input is well-formed and lands in ground; otherwise
/// dumps and `fail`s. Crashes from `runOnce` are forwarded via [assertNoCrash].
void assertWellFormedGround(
  Uint8List bytes, {
  required Directory crashesDir,
  required int iter,
  required int seed,
  String label = 'well-formed',
}) {
  final schedule = FuzzSchedule.single(bytes.length);
  final outcome = runOnce(bytes, schedule);
  assertNoCrash(
    outcome,
    bytes,
    schedule,
    crashesDir: crashesDir,
    iter: iter,
    seed: seed,
    tag: '$label single-chunk',
  );
  final ok = outcome as FuzzOk;
  if (ok.finalState != State.ground) {
    final crash = FuzzCrash(
      StateError('$label did not return to ground: ${ok.finalState}'),
      StackTrace.current,
      'wellformed_ground',
    );
    final key = dumpCrash(crashesDir, bytes, schedule, crash);
    fail('$label non-ground @ iter $iter key=$key state=${ok.finalState}');
  }
  if (ok.errorEventCount > 0) {
    final crash = FuzzCrash(
      StateError('$label produced ${ok.errorEventCount} ErrorEvent(s)'),
      StackTrace.current,
      'wellformed_errors',
    );
    final key = dumpCrash(crashesDir, bytes, schedule, crash);
    fail('$label produced errors @ iter $iter key=$key');
  }
}
