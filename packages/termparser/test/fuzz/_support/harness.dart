/// Fuzz harness: run-loop, invariants, crash dumper, hang guard.
///
/// Used by stream/structured/utf8 harnesses under `test/fuzz/harnesses/`.
/// Public API:
///   * [runOnce]        — sync single iteration, returns [FuzzOutcome]
///   * [runOnceIsolated] — same but wrapped in isolate + hard timeout
///   * [dumpCrash]      — persist failing input to `crashes/<sha1>.{bin,txt}`
///   * [defaultCrashesDir], [defaultCorpusDir]
library;

import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:termparser/src/engine/engine.dart' show State;
import 'package:termparser/termparser.dart';
import 'package:termparser/termparser_events.dart';

/// Hard cap on in-progress sequence byte accumulation. Exceeding → invariant fail.
/// See PLAN.md resolved decision: fuzzer drives engine to add this cap.
const int fuzzMaxSequenceBytes = 4096;

/// Default per-iteration hang timeout.
const Duration fuzzHangTimeout = Duration(milliseconds: 500);

/// Chunking + hasMore schedule for one fuzz iteration.
class FuzzSchedule {
  /// Size of each chunk fed to `parser.advance`.
  final List<int> chunkSizes;

  /// `hasMore` flag per chunk (aligned with [chunkSizes]).
  final List<bool> hasMore;

  const FuzzSchedule(this.chunkSizes, this.hasMore);

  /// Whole-buffer, single-shot, hasMore=false — baseline determinism case.
  factory FuzzSchedule.single(int totalBytes) =>
      FuzzSchedule([totalBytes], const [false]);

  Map<String, dynamic> toJson() => {'chunks': chunkSizes, 'hasMore': hasMore};
}

/// Outcome of a single fuzz iteration.
sealed class FuzzOutcome {
  const FuzzOutcome();
}

/// Clean run. Holds summary stats for oracle checks across iterations.
final class FuzzOk extends FuzzOutcome {
  final int eventCount;
  final int errorEventCount;
  final State finalState;
  const FuzzOk(this.eventCount, this.errorEventCount, this.finalState);
}

/// Failed iteration: thrown exception or invariant violation.
final class FuzzCrash extends FuzzOutcome {
  final Object error;
  final StackTrace stack;

  /// Invariant tag (e.g. `sequenceByteCount_cap`). Null if a raw exception.
  final String? invariant;
  const FuzzCrash(this.error, this.stack, [this.invariant]);
}

/// Synchronously drive one fuzz iteration through [Parser] and check invariants.
///
/// Invariants (see PLAN.md Phase 7):
///   * no throw from advance/nextEvent/drainEvents
///   * eventCount ≤ input.length (loose bound)
///   * sequenceByteCount ≤ [fuzzMaxSequenceBytes] (driver for engine cap)
///   * no `NoneEvent` leaks to public queue
/// Per-harness invariants (known-good sequence → ground state, determinism)
/// are applied at call sites, not here.
FuzzOutcome runOnce(Uint8List bytes, FuzzSchedule schedule) {
  try {
    final parser = Parser();
    var offset = 0;

    for (var i = 0; i < schedule.chunkSizes.length && offset < bytes.length; i++) {
      final size = schedule.chunkSizes[i];
      final end = (offset + size).clamp(0, bytes.length);
      final hasMore = i < schedule.hasMore.length && schedule.hasMore[i];
      parser.advance(bytes.sublist(offset, end), hasMore: hasMore);
      offset = end;

      final used = parser.engine.sequenceByteCount;
      if (used > fuzzMaxSequenceBytes) {
        return FuzzCrash(
          StateError('sequenceByteCount=$used > $fuzzMaxSequenceBytes'),
          StackTrace.current,
          'sequenceByteCount_cap',
        );
      }
    }

    // Drain any trailing bytes if the schedule ran out before the input did.
    if (offset < bytes.length) {
      parser.advance(bytes.sublist(offset));
    }

    var eventCount = 0;
    var errorCount = 0;
    while (parser.hasEvents) {
      final ev = parser.nextEvent();
      if (ev == null) break;
      if (ev is NoneEvent) {
        return FuzzCrash(
          StateError('NoneEvent leaked to public queue'),
          StackTrace.current,
          'no_none_leak',
        );
      }
      if (ev is ErrorEvent) errorCount++;
      eventCount++;
    }

    if (eventCount > bytes.length) {
      return FuzzCrash(
        StateError('events=$eventCount > input=${bytes.length}'),
        StackTrace.current,
        'event_bound',
      );
    }

    return FuzzOk(eventCount, errorCount, parser.engine.currentState);
  } on Object catch (e, s) {
    return FuzzCrash(e, s);
  }
}

/// Isolate-wrapped variant with a hard [timeout]. Use when chasing a suspected hang.
///
/// Slower (spawns an isolate per call) — fast-path iterations should use [runOnce].
Future<FuzzOutcome> runOnceIsolated(
  Uint8List bytes,
  FuzzSchedule schedule, {
  Duration timeout = fuzzHangTimeout,
}) async {
  final result = ReceivePort();
  final err = ReceivePort();
  final exit = ReceivePort();
  final completer = Completer<FuzzOutcome>();

  late Isolate isolate;
  try {
    isolate = await Isolate.spawn<_IsoArgs>(
      _isolateEntry,
      _IsoArgs(result.sendPort, bytes, schedule.chunkSizes, schedule.hasMore),
      onError: err.sendPort,
      onExit: exit.sendPort,
    );
  } on Object catch (e, s) {
    result.close();
    err.close();
    exit.close();
    return FuzzCrash(e, s, 'isolate_spawn');
  }

  result.listen((msg) {
    if (!completer.isCompleted) completer.complete(_decodeMsg(msg));
  });
  err.listen((msg) {
    if (completer.isCompleted) return;
    final list = msg is List ? msg : [msg, ''];
    final errObj = list.isNotEmpty ? (list[0] as Object? ?? 'isolate error') : 'isolate error';
    final stackStr = list.length > 1 ? '${list[1]}' : '';
    completer.complete(FuzzCrash(errObj, StackTrace.fromString(stackStr), 'isolate_error'));
  });

  final hang = Timer(timeout, () {
    if (!completer.isCompleted) {
      isolate.kill(priority: Isolate.immediate);
      completer.complete(FuzzCrash(
        TimeoutException('fuzz iter exceeded $timeout'),
        StackTrace.current,
        'hang_timeout',
      ));
    }
  });

  try {
    return await completer.future;
  } finally {
    hang.cancel();
    result.close();
    err.close();
    exit.close();
  }
}

class _IsoArgs {
  final SendPort port;
  final Uint8List bytes;
  final List<int> chunks;
  final List<bool> hasMore;
  _IsoArgs(this.port, this.bytes, this.chunks, this.hasMore);
}

void _isolateEntry(_IsoArgs a) {
  final outcome = runOnce(a.bytes, FuzzSchedule(a.chunks, a.hasMore));
  a.port.send(_encodeMsg(outcome));
}

// FuzzOutcome isn't directly sendable across isolates (contains StackTrace), so
// we encode as a plain list and decode on the main side.
List<Object?> _encodeMsg(FuzzOutcome o) => switch (o) {
      FuzzOk(:final eventCount, :final errorEventCount, :final finalState) => [
          'ok',
          eventCount,
          errorEventCount,
          finalState.index,
        ],
      FuzzCrash(:final error, :final stack, :final invariant) => [
          'crash',
          error.toString(),
          stack.toString(),
          invariant,
        ],
    };

FuzzOutcome _decodeMsg(Object? msg) {
  final list = msg! as List;
  switch (list[0] as String) {
    case 'ok':
      return FuzzOk(
        list[1] as int,
        list[2] as int,
        State.values[list[3] as int],
      );
    case 'crash':
      return FuzzCrash(
        list[1]! as String,
        StackTrace.fromString(list[2]! as String),
        list[3] as String?,
      );
  }
  throw StateError('unknown msg: $msg');
}

/// Persist a failing input to `<crashesDir>/<sha1>.bin` + `.txt`.
/// Returns the sha1 key. Creates the directory if missing.
String dumpCrash(
  Directory crashesDir,
  Uint8List bytes,
  FuzzSchedule schedule,
  FuzzCrash crash,
) {
  if (!crashesDir.existsSync()) crashesDir.createSync(recursive: true);
  final key = sha1.convert(bytes).toString();
  File('${crashesDir.path}/$key.bin').writeAsBytesSync(bytes);

  final buf = StringBuffer()
    ..writeln('sha1:        $key')
    ..writeln('bytes:       ${bytes.length}')
    ..writeln('invariant:   ${crash.invariant ?? '-'}')
    ..writeln('error:       ${crash.error}')
    ..writeln('chunkSizes:  ${schedule.chunkSizes}')
    ..writeln('hasMore:     ${schedule.hasMore}')
    ..writeln('--- stack ---')
    ..writeln(crash.stack);
  File('${crashesDir.path}/$key.txt').writeAsStringSync(buf.toString());
  return key;
}

/// The termparser package root, resolved independent of the current working
/// directory.
///
/// Anchored on the package's own `lib/` via the package config, so fuzz tests
/// pass whether run from the package dir (`dart test`) or the workspace root
/// (`dart test packages/termparser`). Falls back to CWD if resolution fails.
Future<Directory> _packageRoot() async {
  final libUri = await Isolate.resolvePackageUri(
    Uri.parse('package:termparser/termparser.dart'),
  );
  // libUri = <pkg>/lib/termparser.dart -> <pkg>/
  return libUri == null ? Directory.current : Directory.fromUri(libUri.resolve('../'));
}

/// `packages/termparser/test/fuzz/crashes/`, resolved relative to package root.
Future<Directory> defaultCrashesDir() async =>
    Directory.fromUri((await _packageRoot()).uri.resolve('test/fuzz/crashes/'));

/// `packages/termparser/test/fuzz/corpus/`, resolved relative to package root.
Future<Directory> defaultCorpusDir() async =>
    Directory.fromUri((await _packageRoot()).uri.resolve('test/fuzz/corpus/'));
