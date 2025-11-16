import 'dart:convert';

import '../engine/parameters.dart';
import '../events/event_base.dart';
import '../events/internal_events.dart';
import '../events/response_events.dart';

/// Parse a Device Control String sequence from raw sequence bytes.
///
/// Extracts content between ESC P + intermediates and ESC \ terminator.
Event parseDcsSequence(Parameters params, String char, List<int> sequenceBytes) {
  return switch (params.values) {
    ['>', '|', ...] => _parseDCSBlock(sequenceBytes, params),
    _ => const NoneEvent(),
  };
}

/// Parse DCS block content from sequence bytes.
///
/// Note: ESC is not in sequenceBytes, so sequence starts with 'P'.
/// Calculates offset based on P (1 byte) + intermediates length,
/// extracts until ESC \ (2 bytes from end).
Event _parseDCSBlock(List<int> sequenceBytes, Parameters params) {
  final start = 1 + params.values.length;
  final end = sequenceBytes.length - 2;
  final content = sequenceBytes.sublist(start, end);
  final text = utf8.decode(content, allowMalformed: true);
  return NameAndVersionEvent(text);
}
