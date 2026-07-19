/// Conformance test: termparser Engine vs the DEC ANSI parser oracle.
///
/// Ground truth is the state machine from vt100.net/emu/dec_ansi_parser,
/// extracted to specs/dec_ansi/dec_ansi_parser.json (see the .md there).
/// The Engine is an input-side (terminal -> application) parser, so it
/// deviates from the terminal-side DEC machine on purpose in known places.
///
/// This test pins BOTH sides of that line:
///  - every (state, byte) cell that should match DEC is checked against the
///    oracle, and
///  - every deviating cell must match the entry in [deviations], which names
///    the reason.
/// Any drift - a DEC-conformant cell breaking, or a deviation silently
/// changing behaviour - fails the test.
library;

import 'package:termparser/src/engine/engine.dart';
import 'package:termparser/src/engine/parameters.dart';
import 'package:termparser/src/engine/sequence_data.dart';
import 'package:test/test.dart';

import 'dec_ansi_oracle.dart';

/// Why a cell deviates from the DEC machine.
enum Why {
  /// Input side: a lone ESC may be the ESC key; ESC ESC delivers the first
  /// ESC as a character instead of restarting the sequence.
  escKeyDisambiguation,

  /// ESC O is the SS3 key prefix (F1-F4 arrive as ESC O P..S); the engine
  /// flags it instead of dispatching an escape sequence.
  ss3KeyPrefix,

  /// SOS/PM/APC strings are not supported; ESC X, ESC ^, ESC _ are dropped.
  noSosPmApc,

  /// CAN/SUB cancel the sequence but the control byte itself is swallowed
  /// (DEC executes it, e.g. SUB displays the error character).
  cancelSwallowed,

  /// CAN/SUB inside a DCS/OSC string are ignored entirely instead of
  /// cancelling the string (DEC: unhook/osc_end + execute + ground).
  cancelIgnoredInString,

  /// ESC while CSI is empty is reported as a structural error
  /// (ErrorSequenceData) instead of silently restarting the escape.
  csiEntryEscError,

  /// A byte outside the DEC grammar for this position is stored as a
  /// parameter (private markers, intermediates and CAN/SUB in csiEntry).
  storedAsParam,

  /// Colon accepted as an ISO 8613-6 subparameter separator (modern SGR,
  /// kitty keyboard protocol). DEC sends the sequence to csi_ignore.
  colonSubparam,

  /// ESC intermediate then '[' re-enters CSI; DEC dispatches the escape
  /// sequence with final '['.
  extraCsiTransition,

  /// The DCS header states (dcs_param/dcs_intermediate) are flattened:
  /// header bytes (intermediates, digits, ';', private markers) all
  /// accumulate into params while the engine stays in dcsEntry, instead of
  /// DEC's separate dcs_param/dcs_intermediate states.
  dcsHeaderFlattened,

  /// The string dispatches at the ESC \ pair, so ESC moves to a *Final
  /// state; DEC ends the string at the ESC itself (exit action fires there).
  stPairDeferred,
}

/// Expected engine behaviour where it deviates from the DEC machine.
class Deviation {
  /// Expected engine state after the probe byte.
  final State state;

  /// Expected emission type, or null for no emission.
  final Type? emission;

  /// The documented reason.
  final Why why;

  const Deviation(this.state, this.emission, this.why);
}

/// DEC state -> acceptable engine states (termparser splits some DEC states).
const stateMap = <String, Set<State>>{
  'ground': {State.ground},
  'escape': {State.escape},
  'escape_intermediate': {State.escapeIntermediate},
  'csi_entry': {State.csiEntry},
  'csi_param': {State.csiParameter},
  'csi_intermediate': {State.csiIntermediate},
  'csi_ignore': {State.csiIgnore},
  'dcs_entry': {State.dcsEntry},
  'dcs_ignore': {State.dcsIgnore},
  'dcs_passthrough': {State.textBlock, State.textBlockFinal},
  'osc_string': {State.oscEntry, State.oscParameter, State.oscFinal},
};

/// Byte prefix that drives a fresh Engine into each DEC state.
const statePrefix = <String, List<int>>{
  'ground': [],
  'escape': [0x1B],
  'escape_intermediate': [0x1B, 0x20],
  'csi_entry': [0x1B, 0x5B],
  'csi_param': [0x1B, 0x5B, 0x31],
  'csi_intermediate': [0x1B, 0x5B, 0x31, 0x20],
  'csi_ignore': [0x1B, 0x5B, 0x3A],
  'dcs_entry': [0x1B, 0x50],
  'dcs_passthrough': [0x1B, 0x50, 0x71],
  'osc_string': [0x1B, 0x5D, 0x30],
};

/// Engine state each prefix must land in (sanity check of the harness).
const prefixLandsIn = <String, State>{
  'ground': State.ground,
  'escape': State.escape,
  'escape_intermediate': State.escapeIntermediate,
  'csi_entry': State.csiEntry,
  'csi_param': State.csiParameter,
  'csi_intermediate': State.csiIntermediate,
  'csi_ignore': State.csiIgnore,
  'dcs_entry': State.dcsEntry,
  'dcs_passthrough': State.textBlock,
  'osc_string': State.oscParameter,
};

Map<int, Deviation> _bytes(List<int> bytes, Deviation d) => {for (final b in bytes) b: d};

Map<int, Deviation> _range(int lo, int hi, Deviation d) => {for (var b = lo; b <= hi; b++) b: d};

/// The deviation registry: (DEC state -> byte -> expected engine behaviour).
///
/// Every cell NOT listed here must match the oracle exactly (state via
/// [stateMap], emission kind via the oracle's action).
final deviations = <String, Map<int, Deviation>>{
  'ground': {},
  'escape': {
    ..._bytes([0x18, 0x1A], const Deviation(State.ground, null, Why.cancelSwallowed)),
    0x1B: const Deviation(State.escape, CharData, Why.escKeyDisambiguation),
    0x4F: const Deviation(State.ground, null, Why.ss3KeyPrefix),
    ..._bytes([0x58, 0x5E, 0x5F], const Deviation(State.ground, null, Why.noSosPmApc)),
  },
  'escape_intermediate': {
    ..._bytes([0x18, 0x1A], const Deviation(State.ground, null, Why.cancelSwallowed)),
    0x4F: const Deviation(State.ground, null, Why.ss3KeyPrefix),
    0x5B: const Deviation(State.csiEntry, null, Why.extraCsiTransition),
  },
  'csi_entry': {
    ..._bytes([0x18, 0x1A], const Deviation(State.csiEntry, null, Why.storedAsParam)),
    0x1B: const Deviation(State.ground, ErrorSequenceData, Why.csiEntryEscError),
    ..._range(0x20, 0x2F, const Deviation(State.csiEntry, null, Why.storedAsParam)),
    ..._range(0x3C, 0x3F, const Deviation(State.csiEntry, null, Why.storedAsParam)),
  },
  'csi_param': {
    ..._bytes([0x18, 0x1A], const Deviation(State.ground, null, Why.cancelSwallowed)),
    0x3A: const Deviation(State.csiParameter, null, Why.colonSubparam),
  },
  'csi_intermediate': {
    ..._bytes([0x18, 0x1A], const Deviation(State.ground, null, Why.cancelSwallowed)),
  },
  'csi_ignore': {
    ..._bytes([0x18, 0x1A], const Deviation(State.ground, null, Why.cancelSwallowed)),
  },
  'dcs_entry': {
    ..._bytes([0x18, 0x1A], const Deviation(State.dcsEntry, null, Why.cancelIgnoredInString)),
    // Intermediates (DEC: dcs_intermediate) and digits/';' (DEC: dcs_param)
    // all stay flattened in dcsEntry rather than moving to their own DEC
    // state. Byte 0x3A (colon) is NOT here: it lands in a real dcsIgnore
    // state matching DEC's dcs_ignore exactly, so it needs no deviation.
    ..._range(0x20, 0x2F, const Deviation(State.dcsEntry, null, Why.dcsHeaderFlattened)),
    ..._range(0x30, 0x39, const Deviation(State.dcsEntry, null, Why.dcsHeaderFlattened)),
    0x3B: const Deviation(State.dcsEntry, null, Why.dcsHeaderFlattened),
    ..._range(0x3C, 0x3F, const Deviation(State.dcsEntry, null, Why.dcsHeaderFlattened)),
  },
  'dcs_passthrough': {
    ..._bytes([0x18, 0x1A], const Deviation(State.textBlock, null, Why.cancelIgnoredInString)),
    0x1B: const Deviation(State.textBlockFinal, null, Why.stPairDeferred),
  },
  'osc_string': {
    ..._bytes([0x18, 0x1A], const Deviation(State.oscParameter, null, Why.cancelIgnoredInString)),
    0x1B: const Deviation(State.oscFinal, null, Why.stPairDeferred),
  },
};

/// Expected emission type for an oracle action name, or null.
Type? emissionFor(String action) {
  if (action.startsWith('print') || action.startsWith('execute')) return CharData;
  if (action.startsWith('esc_dispatch')) return EscSequenceData;
  if (action.startsWith('csi_dispatch')) return CsiSequenceData;
  return null;
}

List<SequenceData> feed(Engine engine, List<int> bytes, {bool trailingHasMore = true}) {
  final out = <SequenceData>[];
  for (var i = 0; i < bytes.length; i++) {
    final hasMore = i < bytes.length - 1 || trailingHasMore;
    final r = engine.advance(bytes[i], hasMore: hasMore);
    if (r != null) out.add(r);
  }
  return out;
}

void main() {
  final oracle = DecAnsiMachine.load();

  group('oracle self-check', () {
    test('covers all 14 states x 256 bytes deterministically', () {
      expect(oracle.states, hasLength(14));
      for (final state in oracle.states) {
        for (var b = 0; b < 0x100; b++) {
          expect(() => oracle.resolve(state, b), returnsNormally, reason: '$state has no rule for byte $b');
        }
      }
    });

    test('agrees with the spec on a known trace (CSI 3 m)', () {
      var state = 'ground';
      final actions = <String>[];
      for (final b in [0x1B, 0x5B, 0x33, 0x6D]) {
        final s = oracle.step(state, b);
        actions.addAll(s.actions);
        state = s.next;
      }
      expect(state, 'ground');
      expect(actions, ['clear', 'clear', 'param(0x33)', 'csi_dispatch(0x6D)']);
    });
  });

  group('per-cell conformance (bytes 0x00-0x7F)', () {
    for (final decState in statePrefix.keys) {
      test(decState, () {
        final mismatches = <String>[];
        for (var byte = 0x00; byte <= 0x7F; byte++) {
          final engine = Engine();
          for (final p in statePrefix[decState]!) {
            engine.advance(p, hasMore: true);
          }
          expect(
            engine.currentState,
            prefixLandsIn[decState],
            reason: 'harness bug: prefix for $decState landed in ${engine.currentState}',
          );

          final emission = engine.advance(byte, hasMore: true);
          final actual = engine.currentState;
          final hex = '0x${byte.toRadixString(16).padLeft(2, '0').toUpperCase()}';

          final deviation = deviations[decState]![byte];
          if (deviation != null) {
            if (actual != deviation.state || emission.runtimeType != (deviation.emission ?? Null)) {
              mismatches.add(
                '$hex: deviation ${deviation.why.name} expected '
                '(${deviation.state}, ${deviation.emission}) '
                'got ($actual, ${emission?.runtimeType})',
              );
            }
            continue;
          }

          // DEC-conformant cell: compare against the oracle.
          final step = oracle.step(decState, byte);
          final okStates = stateMap[step.next];
          if (okStates == null) {
            mismatches.add('$hex: oracle went to unmapped state ${step.next}; add a deviation entry');
            continue;
          }
          if (!okStates.contains(actual)) {
            mismatches.add('$hex: oracle -> ${step.next}, engine -> $actual');
          }
          final dispatch = step.actions.map(emissionFor).firstWhere((t) => t != null, orElse: () => null);
          if (emission.runtimeType != (dispatch ?? Null)) {
            mismatches.add(
              '$hex: oracle actions ${step.actions} imply $dispatch, engine emitted ${emission?.runtimeType}',
            );
            continue;
          }
          // Payload spot-checks for byte-carrying emissions.
          final char = String.fromCharCode(byte);
          if (emission is CharData && emission.char != char) {
            mismatches.add('$hex: CharData(${emission.char}) != $char');
          } else if (emission is EscSequenceData && emission.char != char) {
            mismatches.add('$hex: EscSequenceData(${emission.char}) != $char');
          } else if (emission is CsiSequenceData && emission.finalChar != char) {
            mismatches.add('$hex: CsiSequenceData final ${emission.finalChar} != $char');
          }
        }
        expect(mismatches, isEmpty, reason: 'cells out of contract:\n  ${mismatches.join('\n  ')}');
      });
    }
  });

  group('8-bit bytes: UTF-8 replaces the GR/C1 rules', () {
    test('raw C1 controls are not honoured (no 8-bit CSI/DCS/OSC/ST)', () {
      // DEC anywhere: 9B -> csi_entry, 90 -> dcs_entry, 9D -> osc_string.
      // The engine treats lone 0x80-0xBF as stray UTF-8 continuation: dropped.
      for (final c1 in [0x9B, 0x90, 0x9D, 0x9C, 0x84]) {
        final engine = Engine();
        final emission = engine.advance(c1, hasMore: true);
        expect(emission, isNull, reason: 'C1 0x${c1.toRadixString(16)} should be dropped');
        expect(engine.currentState, State.ground);
      }
    });

    test('UTF-8 lead byte enters utf8 state and decodes (no GR = GL folding)', () {
      // DEC folds A0-FF onto 20-7F (0xC3 0xB1 would print "C" "1");
      // the engine decodes them as UTF-8: 0xC3 0xB1 = 'ñ'.
      final engine = Engine();
      expect(engine.advance(0xC3, hasMore: true), isNull);
      expect(engine.currentState, State.utf8);
      expect(engine.advance(0xB1, hasMore: true), const CharData('ñ', escO: false));
      expect(engine.currentState, State.ground);
    });
  });

  group('trace conformance (real-world sequences)', () {
    test('CSI 1;2m dispatches like the oracle', () {
      final bytes = [0x1B, 0x5B, 0x31, 0x3B, 0x32, 0x6D];
      final results = feed(Engine(), bytes);
      expect(results, [
        const CsiSequenceData(Parameters(['1', '2']), 'm'),
      ]);
      // Oracle cross-check: same stream ends in one csi_dispatch of 'm'.
      var state = 'ground';
      final dispatches = <String>[];
      for (final b in bytes) {
        final s = oracle.step(state, b);
        dispatches.addAll(s.actions.where((a) => a.startsWith('csi_dispatch')));
        state = s.next;
      }
      expect(dispatches, ['csi_dispatch(0x6D)']);
    });

    test('kitty CSI 97:65;2u parses here, is ignored by DEC (colon subparams)', () {
      final bytes = [0x1B, 0x5B, 0x39, 0x37, 0x3A, 0x36, 0x35, 0x3B, 0x32, 0x75];
      final results = feed(Engine(), bytes);
      expect(results, [
        const CsiSequenceData(Parameters(['97:65', '2']), 'u'),
      ]);
      var state = 'ground';
      var decDispatched = false;
      for (final b in bytes) {
        final s = oracle.step(state, b);
        decDispatched |= s.actions.any((a) => a.startsWith('csi_dispatch'));
        state = s.next;
      }
      expect(decDispatched, isFalse, reason: 'DEC consumes the sequence in csi_ignore');
    });

    test('SGR mouse CSI <0;10;20M keeps the private marker as a parameter', () {
      final bytes = [0x1B, 0x5B, 0x3C, 0x30, 0x3B, 0x31, 0x30, 0x3B, 0x32, 0x30, 0x4D];
      final results = feed(Engine(), bytes);
      expect(results, [
        const CsiSequenceData(Parameters(['<', '0', '10', '20']), 'M'),
      ]);
    });

    test('OSC 11 colour reply via ESC backslash', () {
      final bytes = [
        0x1B, 0x5D, 0x31, 0x31, 0x3B, // ESC ] 1 1 ;
        ...'rgb:ffff/eeee/dddd'.codeUnits,
        0x1B, 0x5C, // ST
      ];
      final results = feed(Engine(), bytes);
      expect(results, [
        const OscSequenceData(Parameters(['11', 'rgb:ffff/eeee/dddd'])),
      ]);
    });

    test(r'DECRPSS reply ESC P 1 $ r ... ESC backslash hooks and dispatches once', () {
      final bytes = [
        0x1B, 0x50, 0x31, 0x24, 0x72, // ESC P 1 $ r
        0x36, 0x35, 0x3B, 0x31, 0x22, 0x70, // 65;1"p
        0x1B, 0x5C, // ST
      ];
      final results = feed(Engine(), bytes);
      expect(results, hasLength(1));
      final dcs = results.single as DcsSequenceData;
      // '1' accumulates as a parameter; '$' flushes it and starts a fresh
      // pending value as its own entry; 'r' (the hook byte) is the dispatch
      // selector and never lands in params.
      expect(dcs.params, const Parameters(['1', r'$']));
      // Content is the raw sequence bytes; the parser layer slices by offset.
      expect(dcs.contentBytes, isNotEmpty);
    });

    test('bracketed paste block carries content opaquely', () {
      final bytes = [
        0x1B, 0x5B, 0x32, 0x30, 0x30, 0x7E, // CSI 200~
        ...'hi'.codeUnits,
        0x1B, 0x5B, 0x32, 0x30, 0x31, 0x7E, // CSI 201~
      ];
      final results = feed(Engine(), bytes);
      expect(results, hasLength(1));
      final block = results.single as TextBlockSequenceData;
      expect(String.fromCharCodes(block.contentBytes), 'hi');
    });

    test('lone ESC with hasMore:false is the ESC key (input-side extension)', () {
      final engine = Engine();
      expect(engine.advance(0x1B), const CharData('\x1b', escO: false));
      expect(engine.currentState, State.ground);
    });

    test('CAN inside CSI cancels but is swallowed (DEC would execute it)', () {
      final results = feed(Engine(), [0x1B, 0x5B, 0x33, 0x18, 0x41], trailingHasMore: false);
      // DEC: execute(0x18) then print('A'); engine: only the 'A' survives.
      expect(results, [const CharData('A', escO: false)]);
    });

    test('SS3 key: ESC O P arrives as CharData P with escO', () {
      final results = feed(Engine(), [0x1B, 0x4F, 0x50], trailingHasMore: false);
      expect(results, [const CharData('P', escO: true)]);
    });
  });
}
