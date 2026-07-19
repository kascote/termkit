import 'dart:convert';

import '../engine/parameters.dart';
import '../events/event_base.dart';
import '../events/response_events.dart';

/// Parse a Device Control String sequence from raw sequence bytes.
///
/// Extracts content between ESC P + intermediates and ESC \ terminator.
Event? parseDcsSequence(Parameters params, String char, List<int> sequenceBytes) {
  return switch (params.values) {
    // XTVERSION reply: DCS > | text ST. The '|' hook byte ends dcs_entry and
    // is never itself a parameter value, so only the '>' private marker
    // survives into params; _parseDCSBlock confirms the hook byte itself is
    // '|' before treating this as an XTVERSION block.
    ['>', ...] => _parseDCSBlock(sequenceBytes),
    _ => null,
  };
}

/// Parse an XTVERSION DCS block content from sequence bytes.
///
/// Note: ESC is not in sequenceBytes, so sequence starts with 'P'. The
/// header (private marker / params / intermediates) always precedes the
/// hook byte (0x40-0x7E) that ends dcs_entry and starts the opaque content.
/// Digits can merge multiple bytes into a single accumulated parameter, so
/// the header's byte length is no longer derivable from params.values.length
/// - the hook byte is located directly instead. It's always findable: header
/// bytes before it (markers, digits, ';', intermediates) are all < 0x40, so
/// the first byte >= 0x40 at/after index 1 is the hook.
///
/// Only '>' survives into params (the hook byte is the dispatch selector,
/// never a parameter value), so a '>'-prefixed DCS reply with a different
/// hook byte would otherwise be misclassified as XTVERSION; this confirms
/// the located hook byte is actually '|' (0x7C) before parsing, returning
/// null (unrecognised DCS) otherwise. Content runs from just after the hook
/// until ESC \ (2 bytes from the end).
Event? _parseDCSBlock(List<int> sequenceBytes) {
  final hookIndex = sequenceBytes.indexWhere((b) => b >= 0x40 && b <= 0x7E, 1);
  if (hookIndex == -1 || sequenceBytes[hookIndex] != 0x7C) return null;
  final start = hookIndex + 1;
  final end = sequenceBytes.length - 2;
  final content = sequenceBytes.sublist(start, end);
  final text = utf8.decode(content, allowMalformed: true);
  return NameAndVersionEvent(text);
}
