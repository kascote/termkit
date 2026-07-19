/// Dart port of the DEC ANSI parser oracle (specs/dec_ansi/dec_ansi_oracle.py).
///
/// Loads the state machine extracted from vt100.net/emu/dec_ansi_parser
/// (specs/dec_ansi/dec_ansi_parser.json) and exposes the same semantics:
/// per-byte resolution and the full observable step (exit action, transition
/// action, entry action, next state). The conformance test drives this next
/// to the termparser Engine and compares, cell by cell.
library;

import 'dart:convert';
import 'dart:io';

/// One resolved rule: the action fired by a byte and the target state.
///
/// `to` is null for an internal event (the state does not change and no
/// entry/exit actions fire).
typedef DecRule = ({String? action, String? to});

/// The observable result of feeding one byte: ordered actions plus new state.
///
/// Actions that carry the input byte are rendered as `action(0xNN)`; entry and
/// exit actions appear as bare names.
typedef DecStep = ({List<String> actions, String next});

/// The DEC ANSI parser state machine, loaded from the extracted JSON spec.
class DecAnsiMachine {
  /// State names in spec order.
  final List<String> states = [];

  final Map<int, DecRule> _anywhere = {};
  final Map<String, Map<int, DecRule>> _local = {};
  final Map<String, String?> _entry = {};
  final Map<String, String?> _exit = {};

  /// Loads the machine from `specs/dec_ansi/dec_ansi_parser.json`.
  ///
  /// Resolves the path from the package root (where `dart test` runs) with a
  /// workspace-root fallback.
  factory DecAnsiMachine.load() {
    final candidates = [
      'specs/dec_ansi/dec_ansi_parser.json',
      'packages/termparser/specs/dec_ansi/dec_ansi_parser.json',
    ];
    final path = candidates.firstWhere(
      (p) => File(p).existsSync(),
      orElse: () => throw StateError('dec_ansi_parser.json not found; run tests from the termparser package root'),
    );
    final spec = jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
    return DecAnsiMachine._(spec);
  }

  DecAnsiMachine._(Map<String, dynamic> spec) {
    for (final t in spec['anywhere'] as List<dynamic>) {
      final rule = t as Map<String, dynamic>;
      for (final b in _parseSet(rule['on'] as String)) {
        assert(!_anywhere.containsKey(b), 'anywhere overlap at $b');
        _anywhere[b] = (action: rule['action'] as String?, to: rule['to'] as String?);
      }
    }
    final stateSpecs = spec['states'] as Map<String, dynamic>;
    for (final entry in stateSpecs.entries) {
      final name = entry.key;
      final st = entry.value as Map<String, dynamic>;
      states.add(name);
      _entry[name] = st['entry'] as String?;
      _exit[name] = st['exit'] as String?;
      final table = _local[name] = {};
      for (final ev in (st['on'] as List<dynamic>? ?? <dynamic>[])) {
        final rule = ev as Map<String, dynamic>;
        for (final b in _parseSet(rule['on'] as String)) {
          _addRule(table, name, b, (action: rule['action'] as String?, to: null));
        }
      }
      for (final tr in (st['transitions'] as List<dynamic>? ?? <dynamic>[])) {
        final rule = tr as Map<String, dynamic>;
        for (final b in _parseSet(rule['on'] as String)) {
          _addRule(table, name, b, (action: rule['action'] as String?, to: rule['to'] as String?));
        }
      }
    }
  }

  void _addRule(Map<int, DecRule> table, String state, int byte, DecRule rule) {
    assert(!table.containsKey(byte), '$state: duplicate rule for byte $byte');
    assert(!_anywhere.containsKey(byte), '$state: byte $byte overlaps an anywhere rule');
    table[byte] = rule;
  }

  static List<int> _parseSet(String setSpec) {
    final out = <int>[];
    for (final part in setSpec.split(',')) {
      if (part.contains('-')) {
        final ends = part.split('-');
        final lo = int.parse(ends[0], radix: 16);
        final hi = int.parse(ends[1], radix: 16);
        for (var b = lo; b <= hi; b++) {
          out.add(b);
        }
      } else {
        out.add(int.parse(part, radix: 16));
      }
    }
    return out;
  }

  /// Resolves (state, byte) to its rule.
  ///
  /// Anywhere rules win; GR bytes A0-FF resolve like their GL twin (byte-0x80).
  /// Throws [StateError] if no rule matches (the verify test proves it never
  /// does).
  DecRule resolve(String state, int byte) {
    final anywhere = _anywhere[byte];
    if (anywhere != null) return anywhere;
    final key = byte >= 0xA0 ? byte - 0x80 : byte;
    final rule = _local[state]?[key];
    if (rule == null) {
      throw StateError('$state: no rule for byte 0x${byte.toRadixString(16)}');
    }
    return rule;
  }

  /// Full observable semantics for one byte: ordered actions and next state.
  DecStep step(String state, int byte) {
    final rule = resolve(state, byte);
    final to = rule.to;
    if (to == null) {
      final action = rule.action;
      return (actions: [if (action != null) _withByte(action, byte)], next: state);
    }
    return (
      actions: [
        if (_exit[state] != null) _exit[state]!,
        if (rule.action != null) _withByte(rule.action!, byte),
        if (_entry[to] != null) _entry[to]!,
      ],
      next: to,
    );
  }

  static String _withByte(String action, int byte) =>
      '$action(0x${byte.toRadixString(16).padLeft(2, '0').toUpperCase()})';
}
