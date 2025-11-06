import 'dart:convert';

import '../events.dart';
import '../events_types.dart';
import 'parser_base.dart';

/// Parse an Operating System Command sequence
Event parseOscSequence(List<String> parameters, int ignoredParameterCount, String char) {
  return switch (parameters) {
    ['10', ...] => _parserColorSequence(parameters),
    ['11', ...] => _parserColorSequence(parameters),
    ['52', ...] => _parseClipboardSequence(parameters),
    _ => const NoneEvent(),
  };
}

Event _parserColorSequence(List<String> parameters) {
  if (parameters.length < 2) return const NoneEvent();
  final buffer = parameters[1];
  // has malformed data
  if (buffer.length < 12 || buffer.contains('�') || !buffer.startsWith('rgb:')) {
    return ParserErrorEvent(parameters);
  }

  final parts = buffer.substring(4).split('/');

  if (parts.length != 3) return const NoneEvent();

  final r = tryParseInt(parts[0]);
  final g = tryParseInt(parts[1]);
  final b = tryParseInt(parts[2]);

  if (r == null || g == null || b == null) return const NoneEvent();

  return ColorQueryEvent(r, g, b);
}

Event _parseClipboardSequence(List<String> parameters) {
  final encoded = parameters.elementAtOrNull(2);
  if (encoded == null) return const NoneEvent();

  final result = switch (encoded) {
    '' || '0' => '',
    _ => utf8.decode(base64Decode(encoded), allowMalformed: true),
  };
  final source = switch (parameters[1]) {
    'c' => ClipboardSource.clipboard,
    'p' => ClipboardSource.primary,
    'q' => ClipboardSource.secondary,
    's' => ClipboardSource.selection,
    '0' || '1' || '2' || '3' || '4' || '5' || '6' || '7' => ClipboardSource.cutBuffer,
    _ => ClipboardSource.unknown,
  };

  return ClipboardCopyEvent(source, result);
}
