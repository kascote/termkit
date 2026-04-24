/// Phase 3 corpus test: replays Ghostty-style seeds through the parser.
///
/// Invariants per file:
///   * no throw (applies to every file, known-good or not)
///   * parser ends in `ground` state after hasMore=false flush
///   * no `ErrorEvent` emitted — only for known-good files (malformed/invalid
///     seeds are skipped from the ErrorEvent check)
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:termparser/src/engine/engine.dart' show State;
import 'package:test/test.dart';

import '_support/harness.dart';

/// Substrings in a filename that mark it as an *intentionally malformed* seed.
/// These files are expected to produce `ErrorEvent`s (or NoneEvent via internals);
/// we only verify no throw + parser still returns to ground.
const _malformedMarkers = {
  'invalid',
  'malformed',
  'incomplete',
  'truncated',
};

bool _isMalformed(String basename) =>
    _malformedMarkers.any(basename.contains);

/// Seeds skipped pending Phase 3.5 fixes. Key = path relative to corpus root.
/// Value = finding ID to look up in PLAN.md.
const Map<String, String> _skipForFinding = <String, String>{};

void main() {
  final corpusDir = defaultCorpusDir();
  if (!corpusDir.existsSync()) {
    // Fail loudly — Phase 3 requires seeds to be present.
    throw StateError('corpus dir missing: ${corpusDir.path}');
  }

  final files = corpusDir
      .listSync(recursive: true)
      .whereType<File>()
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  group('corpus seeds', () {
    for (final f in files) {
      final rel = f.path.replaceFirst('${corpusDir.path}/', '');
      final basename = rel.split('/').last;
      final malformed = _isMalformed(basename);

      final skipFinding = _skipForFinding[rel];
      test(rel, skip: skipFinding == null ? null : 'Phase 3.5 $skipFinding', () {
        final bytes = Uint8List.fromList(f.readAsBytesSync());
        final outcome = runOnce(bytes, FuzzSchedule.single(bytes.length));

        if (outcome is FuzzCrash) {
          fail(
            'crash: invariant=${outcome.invariant} error=${outcome.error}\n'
            'bytes(${bytes.length})=${bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}',
          );
        }
        final ok = outcome as FuzzOk;

        if (!malformed) {
          expect(
            ok.finalState,
            State.ground,
            reason: 'known-good seed did not return to ground after flush',
          );
          expect(
            ok.errorEventCount,
            0,
            reason: 'known-good seed produced ${ok.errorEventCount} ErrorEvent(s)',
          );
        }
      });
    }
  });
}
