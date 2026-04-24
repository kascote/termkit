/// Shared chunk-schedule + fingerprint helpers for fuzz harnesses.
///
/// Pulled out of the stream harness so the structured/utf8 harnesses can
/// apply the same chunking distribution and determinism check (Phase 7).
library;

import 'dart:math';
import 'dart:typed_data';

import 'package:termparser/termparser.dart';

import 'harness.dart';

/// Chunk-size distribution: 60% 1-byte, 30% 2..8, 10% 9..512.
/// `hasMore` random per chunk, forced `false` on the last chunk so trailing
/// ESC flushes as a key (matches real-world end-of-input semantics).
/// 20% of chunks end just before the next ESC — stresses ESC-at-boundary.
FuzzSchedule randomSchedule(Random rng, Uint8List bytes) {
  final chunks = <int>[];
  final hasMore = <bool>[];
  var pos = 0;
  while (pos < bytes.length) {
    final remaining = bytes.length - pos;
    final r = rng.nextInt(100);
    var size = r < 60
        ? 1
        : r < 90
            ? 2 + rng.nextInt(7)
            : 9 + rng.nextInt(504);
    if (size > remaining) size = remaining;

    // ESC-at-boundary flip: truncate chunk just before an ESC inside it, so
    // the *next* chunk starts with ESC. Targets escape-lead chunk edges.
    if (rng.nextInt(100) < 20) {
      for (var i = 1; i < size; i++) {
        if (bytes[pos + i] == 0x1b) {
          size = i;
          break;
        }
      }
    }

    chunks.add(size);
    hasMore.add(rng.nextBool());
    pos += size;
  }
  if (hasMore.isNotEmpty) hasMore[hasMore.length - 1] = false;
  return FuzzSchedule(chunks, hasMore);
}

/// Drive [bytes] through a fresh [Parser] under [schedule] and produce a
/// stable string of all emitted events + terminal state. Used for the
/// determinism invariant — two identical runs must produce identical strings.
String fingerprint(Uint8List bytes, FuzzSchedule schedule) {
  final parser = Parser();
  var pos = 0;
  for (var i = 0; i < schedule.chunkSizes.length && pos < bytes.length; i++) {
    final end = (pos + schedule.chunkSizes[i]).clamp(0, bytes.length);
    final hm = i < schedule.hasMore.length && schedule.hasMore[i];
    parser.advance(bytes.sublist(pos, end), hasMore: hm);
    pos = end;
  }
  if (pos < bytes.length) parser.advance(bytes.sublist(pos));

  final buf = StringBuffer();
  while (parser.hasEvents) {
    final ev = parser.nextEvent();
    if (ev == null) break;
    buf
      ..write(ev.runtimeType)
      ..write('|')
      ..write(ev)
      ..write('\n');
  }
  buf
    ..write('state=')
    ..write(parser.engine.currentState);
  return buf.toString();
}
