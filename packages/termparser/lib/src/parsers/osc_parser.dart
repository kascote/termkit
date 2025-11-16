import 'dart:convert';

import '../engine/parameters.dart';
import '../events/event_base.dart';
import '../events/internal_events.dart';
import '../events/response_events.dart';
import 'parser_base.dart';

/// Parse an Operating System Command sequence
Event parseOscSequence(Parameters params, String char) {
  return switch (params.values) {
    ['10', ...] => _parserColorSequence(params),
    ['11', ...] => _parserColorSequence(params),
    ['52', ...] => _parseClipboardSequence(params),
    _ => const NoneEvent(),
  };
}

Event _parserColorSequence(Parameters params) {
  if (params.values.length < 2) return const NoneEvent();
  final buffer = params.values[1];
  // has malformed data
  if (buffer.length < 12 || buffer.contains('�') || !buffer.startsWith('rgb:')) {
    return const NoneEvent();
  }

  final parts = buffer.substring(4).split('/');

  if (parts.length != 3) return const NoneEvent();

  final r = tryParseInt(parts[0]);
  final g = tryParseInt(parts[1]);
  final b = tryParseInt(parts[2]);

  if (r == null || g == null || b == null) return const NoneEvent();

  return ColorQueryEvent(r, g, b);
}

Event _parseClipboardSequence(Parameters params) {
  final encoded = params.values.elementAtOrNull(2);
  if (encoded == null) return const NoneEvent();

  final result = switch (encoded) {
    '' || '0' => '',
    _ => utf8.decode(base64Decode(encoded), allowMalformed: true),
  };
  final source = switch (params.values[1]) {
    'c' => ClipboardSource.clipboard,
    'p' => ClipboardSource.primary,
    'q' => ClipboardSource.secondary,
    's' => ClipboardSource.selection,
    '0' || '1' || '2' || '3' || '4' || '5' || '6' || '7' => ClipboardSource.cutBuffer,
    _ => ClipboardSource.unknown,
  };

  return ClipboardCopyEvent(source, result);
}
