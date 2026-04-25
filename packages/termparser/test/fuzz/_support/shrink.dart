/// Naive crash shrinker (Phase 8).
///
/// Reads a crash `.bin` produced by `dumpCrash`, halves it as far as it
/// still crashes, then drops one byte at a time until no progress. Writes
/// a `<origSha1>.min.bin` + `.min.txt` sibling next to the input.
///
/// Crash criterion: `runOnce` under a single-chunk schedule returns
/// `FuzzCrash`. This matches `replayCrashes` (the regression-guard
/// semantics). Crashes that only reproduce under a specific chunk schedule
/// are out of scope for this shrinker.
///
/// Usage:
///   `dart run test/fuzz/_support/shrink.dart --file=test/fuzz/crashes/<sha1>.bin`
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'harness.dart';

void main(List<String> argv) {
  String? path;
  for (final a in argv) {
    if (a.startsWith('--file=')) path = a.substring('--file='.length);
  }
  if (path == null || path.isEmpty) {
    stderr.writeln(
      'usage: dart run test/fuzz/_support/shrink.dart --file=<path-to.bin>',
    );
    exit(64);
  }

  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('error: file not found: $path');
    exit(66);
  }

  final original = Uint8List.fromList(file.readAsBytesSync());
  if (original.isEmpty) {
    stderr.writeln('error: empty input — nothing to shrink');
    exit(65);
  }

  final initial = _crashOf(original);
  if (initial == null) {
    stderr.writeln(
      'error: input does not crash under single-chunk runOnce.\n'
      '       (the underlying bug may be fixed, or the crash required a\n'
      '       specific chunk schedule that this shrinker does not replay)',
    );
    exit(70);
  }

  stdout.writeln(
    'shrink: starting bytes=${original.length} '
    'inv=${initial.invariant ?? '-'} err=${initial.error}',
  );

  var current = original;
  var crash = initial;

  // ---- halve loop -------------------------------------------------------
  // Repeatedly try keeping just the left half or just the right half. Stop
  // when neither half preserves the crash.
  while (current.length > 1) {
    final mid = current.length ~/ 2;
    final left = Uint8List.sublistView(current, 0, mid);
    final right = Uint8List.sublistView(current, mid);

    final lc = _crashOf(left);
    if (lc != null) {
      current = Uint8List.fromList(left);
      crash = lc;
      stdout.writeln('  halve  → ${current.length} (left)');
      continue;
    }
    final rc = _crashOf(right);
    if (rc != null) {
      current = Uint8List.fromList(right);
      crash = rc;
      stdout.writeln('  halve  → ${current.length} (right)');
      continue;
    }
    break;
  }

  // ---- drop-1 sweeps ----------------------------------------------------
  // Linear pass: try removing each byte; if the crash persists, accept and
  // restart the sweep. Stop when a full pass yields no progress.
  var changed = true;
  while (changed) {
    changed = false;
    for (var i = 0; i < current.length; i++) {
      final candidate = Uint8List(current.length - 1)
        ..setRange(0, i, current)
        ..setRange(i, current.length - 1, current, i + 1);
      final c = _crashOf(candidate);
      if (c != null) {
        current = candidate;
        crash = c;
        changed = true;
        stdout.writeln('  drop-1 @ $i → ${current.length}');
        break;
      }
    }
  }

  // ---- write minimized sibling -----------------------------------------
  final origKey = sha1.convert(original).toString();
  final minKey = sha1.convert(current).toString();
  final removed = original.length - current.length;

  if (removed == 0) {
    stdout.writeln('shrink: no reduction possible (already minimal at ${current.length} bytes)');
    return;
  }

  final dir = file.parent;
  final binPath = '${dir.path}/$origKey.min.bin';
  final txtPath = '${dir.path}/$origKey.min.txt';
  File(binPath).writeAsBytesSync(current);
  final buf = StringBuffer()
    ..writeln('original-sha1:   $origKey')
    ..writeln('minimized-sha1:  $minKey')
    ..writeln('original-bytes:  ${original.length}')
    ..writeln('minimized-bytes: ${current.length}')
    ..writeln('removed-bytes:   $removed')
    ..writeln('schedule:        single-chunk hasMore=false')
    ..writeln('invariant:       ${crash.invariant ?? '-'}')
    ..writeln('error:           ${crash.error}')
    ..writeln('hex:             ${_hex(current)}');
  File(txtPath).writeAsStringSync(buf.toString());

  stdout
    ..writeln('shrink: ${original.length} → ${current.length} bytes ($removed removed)')
    ..writeln('  wrote $binPath')
    ..writeln('  wrote $txtPath');
}

/// Single-chunk crash check. Returns the [FuzzCrash] on failure, or `null`
/// if the input runs clean.
FuzzCrash? _crashOf(Uint8List bytes) {
  final outcome = runOnce(bytes, FuzzSchedule.single(bytes.length));
  return outcome is FuzzCrash ? outcome : null;
}

String _hex(Uint8List bytes) {
  final sb = StringBuffer();
  for (var i = 0; i < bytes.length; i++) {
    if (i > 0) sb.write(' ');
    final h = bytes[i].toRadixString(16).padLeft(2, '0');
    sb.write(h);
  }
  return sb.toString();
}
