import 'dart:convert';

import '../events.dart';

/// Parse a Device Control String sequence from raw sequence bytes.
///
/// Extracts content between ESC P + intermediates and ESC \ terminator.
Event parseDcsSequence(List<String> parameters, int ignoredParameterCount, String char, List<int> sequenceBytes) {
  return switch (parameters) {
    ['>', '|', ...] => _parseDCSBlock(sequenceBytes, parameters),
    _ => const NoneEvent(),
  };
}

/// Parse DCS block content from sequence bytes.
///
/// Note: ESC is not in sequenceBytes, so sequence starts with 'P'.
/// Calculates offset based on P (1 byte) + intermediates length,
/// extracts until ESC \ (2 bytes from end).
Event _parseDCSBlock(List<int> sequenceBytes, List<String> intermediates) {
  final start = 1 + intermediates.length;
  final end = sequenceBytes.length - 2;
  final content = sequenceBytes.sublist(start, end);
  final text = utf8.decode(content, allowMalformed: true);
  return NameAndVersionEvent(text);
}
