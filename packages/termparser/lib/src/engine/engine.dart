import 'package:meta/meta.dart';

import './parameter_accumulator.dart';
import './parameters.dart';
import './sequence_data.dart';
import './utf8_decoder.dart';

/// A parser engine state.
///
/// All these variant names come from the
/// [A parser for DEC’s ANSI-compatible video terminals](https://vt100.net/emu/dec_ansi_parser)
/// description.
enum State {
  /// Initial state.
  ground,

  /// Escape sequence started.
  ///
  /// `Esc` received with a flag that there's more data available.
  escape,

  /// Escape sequence and we're collecting intermediates.
  ///
  /// # Notes
  ///
  /// This implementation doesn't collect intermediates. It just handles the state
  /// to distinguish between (im)proper sequences.
  escapeIntermediate,

  /// CSI sequence started.
  ///
  /// `Esc` followed by the `[` received.
  csiEntry,

  /// CSI sequence should be consumed, but not dispatched.
  csiIgnore,

  /// CSI sequence and we're collecting parameters.
  csiParameter,

  /// CSI sequence and we're collecting intermediates.
  ///
  /// # Notes
  ///
  /// This implementation doesn't collect intermediates. It just handles the state
  /// to distinguish between (im)proper sequences.
  csiIntermediate,

  /// Text block sequence
  ///
  /// used for bracketed paste mode for example
  textBlock,

  /// Text block final sequence
  textBlockFinal,

  /// OSC sequence block
  ///
  /// used for operating system command
  oscEntry,

  /// OSC sequence and we're collecting parameters.
  oscParameter,

  /// OSC final sequence
  oscFinal,

  /// DCS entry state
  dcsEntry,

  /// DCS header abandoned (colon, per DEC's dcs_ignore).
  ///
  /// Bytes are dropped until an anywhere-rule (ESC) exits; no hook, no
  /// dispatch.
  dcsIgnore,

  /// SOS/PM/APC string body (DEC's `sos_pm_apc_string`).
  ///
  /// `Esc` followed by `X`, `^`, or `_`. Every byte of the string is swallowed
  /// — no accumulation, no dispatch — until an anywhere-rule exit.
  sosPmApcString,

  /// SOS/PM/APC string final sequence.
  ///
  /// Mirrors [oscFinal]/[textBlockFinal]: reached after `Esc` inside
  /// [sosPmApcString], waiting to see whether the next byte is `\` (ST,
  /// terminates with no emission) or something else (cancel).
  sosPmApcStringFinal,

  /// Possible UTF-8 sequence and we're collecting UTF-8 code points.
  utf8,
}

/// VT500-series ANSI escape sequence state machine engine.
///
/// Processes input bytes one at a time through state transitions.
/// Emits SequenceData when complete sequences are parsed.
///
/// Engine handles structural validation - detecting malformed sequences,
/// invalid state transitions, and unexpected bytes. When errors occur,
/// it emits ErrorSequenceData with full context for debugging.
class Engine {
  final _params = ParameterAccumulator();
  final _utf8 = Utf8Decoder();
  State _state = State.ground;
  bool _inTextBlock = false;
  bool _escO = false;
  SequenceData? _emit;

  /// Incomplete TextBlockSequenceData being built during bracketed paste parsing.
  ///
  /// Holds intermediate state with placeholder values for endParams (''), endFinal (''),
  /// and contentBytes ([]) until the closing sequence (CSI 201~) is encountered.
  /// Only the completed instance is emitted via _emit.
  TextBlockSequenceData? _textBlockInProgress;

  /// Accumulates all bytes of the current sequence being processed (cleared on ground state).
  ///
  /// Serves two purposes:
  /// 1. **Error Reporting**: Provides full raw byte sequence context in ErrorSequenceData
  ///    when parsing errors occur.
  /// 2. **Content Extraction**: For textBlock sequences (DCS and bracketed paste),
  ///    parsers extract opaque content directly from this buffer using known offsets,
  ///    avoiding the 30-parameter limit and preserving embedded escape sequences.
  final List<int> _sequenceBytes = [];

  /// Read-only access to current state
  State get currentState => _state;

  /// Check if engine is in intermediate state
  bool get isIntermediateState => _state != State.ground;

  /// Get human-readable name of current state
  String get currentStateName => _state.toString().split('.').last;

  /// Get defensive copy of current sequence bytes
  List<int> get currentSequenceBytes => List.from(_sequenceBytes);

  /// Get collected parameters so far
  List<String> get collectedParameters => _params.getParameters();

  /// Byte count of the current in-progress sequence (for fuzz invariants).
  @visibleForTesting
  int get sequenceByteCount => _sequenceBytes.length;

  /// Number of accumulated parameters in the current sequence (for fuzz invariants).
  @visibleForTesting
  int get paramCount => _params.getCount();

  /// Whether the engine is currently inside a bracketed-paste text block (for fuzz invariants).
  @visibleForTesting
  bool get inTextBlock => _inTextBlock;

  /// Get full engine state dump for debugging
  String debugInfo() {
    final buffer = StringBuffer()
      ..writeln('Engine Debug Info:')
      ..writeln('  State: $currentStateName')
      ..writeln('  In Text Block: $_inTextBlock')
      ..writeln('  Parameters: ${_params.getParameters()}')
      ..writeln('  Parameter Count: ${_params.getCount()}')
      ..writeln('  Sequence Bytes: ${_sequenceBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
    return buffer.toString();
  }

  /// Creates a new instance of sequence parser engine.
  Engine();

  void _setState(State newState) {
    // Clear on ground for UTF-8 and sequence bytes tracking.
    // Also clear _inTextBlock: bracketed paste can only span ESC[200~..ESC[201~,
    // so any path back to ground (e.g. textBlockFinal seeing ESC \ and dispatching
    // as DCS) abandons the paste. Leaving _inTextBlock=true would make a later
    // CSI 201~ re-enter the paste-close branch with a freshly cleared
    // _sequenceBytes, causing sublist(5, len-6) to RangeError (fuzz F5).
    if (newState == State.ground) {
      _utf8.reset();
      _sequenceBytes.clear();
      _inTextBlock = false;
    }
    // Clear params on entry to new sequence types (not on ground)
    // This preserves params after sequence completes for debugging
    else if ((newState == State.escape ||
            newState == State.csiEntry ||
            newState == State.oscEntry ||
            newState == State.dcsEntry) &&
        !_inTextBlock) {
      _params.clear();
    }
    _state = newState;
  }

  void _handleError(String message, {String? type}) {
    _emit = ErrorSequenceData(
      message,
      state: _state.toString(),
      rawBytes: List<int>.from(_sequenceBytes),
      partialParameters: _params.getParameters(),
      type: type,
    );
    _setState(State.ground);
  }

  bool _handlePossibleEsc(int byte, {bool hasMore = false}) {
    if (byte != 0x1b) {
      return false;
    }

    switch ((_state, hasMore)) {
      // More input means possible Esc sequence, just switch state and wait
      case (State.ground, true):
        _setState(State.escape);
      // No more input means Esc key, dispatch it
      case (State.ground, false):
        _provideChar('\x1b');
      // More input means possible Esc sequence, dispatch the previous Esc char
      case (State.escape, true):
        _provideChar('\x1b');
      // No more input means Esc key, dispatch the previous & current Esc char
      case (State.escape, false):
        _provideChar('\x1b');
        _provideChar('\x1b');
        _setState(State.ground);
      case (State.oscParameter, true):
        _setState(State.oscFinal);
        return false;

      case (State.textBlock, true):
        _setState(State.textBlockFinal);
        return false;

      case (State.sosPmApcString, true):
        _setState(State.sosPmApcStringFinal);
        return false;

      // CSI states should handle ESC themselves
      case (State.csiEntry, _):
        return false;

      // Discard any state
      // More input means possible Esc sequence
      case (_, true):
        _setState(State.escape);
      // Discard any state
      // No more input means Esc key, dispatch it
      case (_, false):
        _provideChar('\x1b');
        _setState(State.ground);
    }

    return true;
  }

  void _provideChar(String char) {
    _emit = CharData(char, escO: _escO);
    _escO = false;
  }

  /// DEC's anywhere rule for CAN (0x18) and SUB (0x1A): abandon whatever
  /// sequence or string is in flight — no dispatch, no error — and execute
  /// the control byte, which for this input-side engine means delivering it
  /// as character data exactly like a lone CAN/SUB in ground state.
  void _cancelAndDeliver(int byte) {
    _provideChar(String.fromCharCode(byte));
    _setState(State.ground);
  }

  void _provideESCSequence(String char) {
    if (char == 'O') {
      // Exception: Esc O is followed by single character (P-S) representing F1-F4 keys
      _escO = true;
    } else {
      _emit = EscSequenceData(char);
      _escO = false;
    }
  }

  void _provideCSISequence(Parameters params, String char) {
    _emit = CsiSequenceData(params, char);
    _escO = false;
  }

  void _provideOscSequence(Parameters params) {
    _emit = OscSequenceData(params);
    _escO = false;
  }

  void _provideDcsSequence(Parameters params, List<int> contentBytes) {
    _emit = DcsSequenceData(params, List.from(contentBytes)); // Copy to avoid clearing
    _escO = false;
  }

  bool _handlePossibleUtf8CodePoints(int byte) {
    if (byte & 0x80 == 0) {
      _provideChar(String.fromCharCode(byte));
      return true;
    } else if (byte & 0xe0 == 0xc0) {
      _utf8.start2Byte(byte);
      _setState(State.utf8);
      return true;
    } else if (byte & 0xf0 == 0xe0) {
      _utf8.start3Byte(byte);
      _setState(State.utf8);
      return true;
    } else if (byte & 0xf8 == 0xf0) {
      _utf8.start4Byte(byte);
      _setState(State.utf8);
      return true;
    } else {
      return false;
    }
  }

  void _advanceGroundState(int byte) {
    if (_handlePossibleUtf8CodePoints(byte)) return;

    return switch (byte) {
      // Execute
      (>= 0x00 && <= 0x17) || 0x19 || (>= 0x1C && <= 0x1F) => _provideChar(String.fromCharCode(byte)),
      // get char
      >= 0x20 && <= 0x7F => _provideChar(String.fromCharCode(byte)),
      _ => {},
    };
  }

  void _advanceEscapeState(int byte) {
    switch (byte) {
      case 0x1b:
        _handleError('Unexpected Esc byte in Advance State', type: 'unexpectedEscape');
      // Intermediate bytes to collect
      case >= 0x20 && <= 0x2F:
        _setState(State.escapeIntermediate);

      // DCS
      case 0x50:
        _setState(State.dcsEntry);

      // SOS/PM/APC string introducer (X, ^, _) -> swallow the string body.
      case 0x58 || 0x5E || 0x5F:
        _setState(State.sosPmApcString);

      // Escape followed by '[' (0x5B) -> CSI sequence start
      case 0x5B:
        _setState(State.csiEntry);

      // Escape followed by ']' (0x5D) -> OSC sequence start
      case 0x5D:
        _setState(State.oscEntry);

      // Escape sequence final character
      case (>= 0x30 && <= 0x4F) || (>= 0x51 && <= 0x57) || 0x59 || 0x5A || 0x5C || (>= 0x60 && <= 0x7E):
        _provideESCSequence(String.fromCharCode(byte));
        _setState(State.ground);

      // Execute
      case (>= 0x00 && <= 0x17) || 0x19 || (>= 0x1C && <= 0x1F):
        _provideChar(String.fromCharCode(byte));

      // CAN/SUB: anywhere rule. Cancel the escape sequence and deliver the
      // control byte, same as ground.
      case 0x18 || 0x1A:
        _cancelAndDeliver(byte);

      // Does it mean we should ignore the whole sequence?
      // Ignore
      case 0x7F:
        {}

      // Other bytes are considered as invalid -> cancel whatever we have
      default:
        _setState(State.ground);
    }
  }

  void _advanceEscapeIntermediateState(int byte) {
    switch (byte) {
      case 0x1b:
        _handleError('Unexpected Esc byte in ESC Intermediate', type: 'unexpectedEscape');

      // Intermediate bytes to collect
      case >= 0x20 && <= 0x2F:
        {}

      // Escape followed by '[' (0x5B)
      //   -> CSI sequence start
      case 0x5B:
        _setState(State.csiEntry);

      // Escape sequence final character
      case (>= 0x30 && <= 0x5A) || (>= 0x5C && <= 0x7E):
        _provideESCSequence(String.fromCharCode(byte));
        _setState(State.ground);

      // Execute
      case (>= 0x00 && <= 0x17) || 0x19 || (>= 0x1C && <= 0x1F):
        _provideChar(String.fromCharCode(byte));

      // CAN/SUB: anywhere rule. Cancel the escape sequence and deliver the
      // control byte, same as ground.
      case 0x18 || 0x1A:
        _cancelAndDeliver(byte);

      // Does it mean we should ignore the whole sequence?
      // Ignore
      case 0x7F:
        {}

      // Other bytes are considered as invalid -> cancel whatever we have
      default:
        _setState(State.ground);
    }
  }

  void _advanceCsiEntryState(int byte) {
    switch (byte) {
      case 0x1b:
        _handleError('Unexpected Esc byte in CSI Entry state', type: 'unexpectedEscape');

      // '0' ..= '9' = parameter value
      case >= 0x30 && <= 0x39:
        _params.add(byte);
        _setState(State.csiParameter);

      // ';' = parameter delimiter
      case 0x3B:
        _params.store();
        _setState(State.csiParameter);

      // ':' sequence delimiter
      case 0x3A:
        _setState(State.csiIgnore);

      // CSI sequence final character
      //   -> dispatch CSI sequence
      case >= 0x40 && <= 0x7E:
        _params.store();
        _provideCSISequence(
          Parameters.from(_params),
          String.fromCharCode(byte),
        );

        _setState(State.ground);

      // Execute
      case (>= 0x00 && <= 0x17) || 0x19 || (>= 0x1C && <= 0x1F):
        _provideChar(String.fromCharCode(byte));

      // CAN/SUB: anywhere rule. Cancel the CSI sequence and deliver the
      // control byte instead of storing it as a parameter.
      case 0x18 || 0x1A:
        _cancelAndDeliver(byte);

      // Does it mean we should ignore the whole sequence?
      // Ignore
      case 0x7F:
        {}

      // Collect rest as parameters
      default:
        _params
          ..add(byte)
          ..store();
    }
  }

  void _advanceCsiIgnoreState(int byte) {
    switch (byte) {
      case 0x1b:
        _handleError('Unexpected Esc byte in CSI Ignore', type: 'unexpectedEscape');

      // Execute
      case (>= 0x00 && <= 0x17) || 0x19 || (>= 0x1C && <= 0x1F):
        _provideChar(String.fromCharCode(byte));

      // CAN/SUB: anywhere rule. Cancel the consumed sequence and deliver the
      // control byte.
      case 0x18 || 0x1A:
        _cancelAndDeliver(byte);

      // Does it mean we should ignore the whole sequence?
      // Ignore
      case (>= 0x20 && <= 0x3F) || 0x7F:
        {}

      case (>= 0x40 && <= 0x7E):
        _setState(State.ground);

      // Other bytes are considered as invalid -> cancel whatever we have
      default:
        _setState(State.ground);
    }
  }

  void _advanceCsiParameterState(int byte) {
    switch (byte) {
      case 0x1b:
        _handleError('Unexpected Esc byte in CSI Param', type: 'unexpectedEscape');

      // '0' ..= '9' = parameter value
      case (>= 0x30 && <= 0x39):
        _params.add(byte);

      // ':' sequence delimiter
      case 0x3A:
        _params.add(byte);

      // ';' parameter delimiter
      case 0x3B:
        _params.store();

      // `~`
      case 0x7E:
        _params.store();
        if (_params[0] == '200' && !_inTextBlock) {
          // Start of bracketed paste - create incomplete TextBlockSequenceData
          // Placeholder values for endParams, endFinal, contentBytes will be filled later
          _textBlockInProgress = TextBlockSequenceData(
            Parameters.from(_params),
            String.fromCharCode(byte),
            // placeholders values here until the end
            Parameters.empty(),
            '',
            const [],
          );
          _inTextBlock = true;
          _setState(State.textBlock);
        } else if (_inTextBlock && _params[0] == '201') {
          // End of bracketed paste - complete TextBlockSequenceData
          // End sequence is 6 bytes: ESC [ 2 0 1 ~
          final contentEnd = _sequenceBytes.length - 6;
          // start of content is CSI [ 200~ (6 bytes), but ESC was consumed earlier
          // for that we use 5
          final contentBytes = _sequenceBytes.sublist(5, contentEnd);
          _emit = _textBlockInProgress!.copyWith(
            endParams: Parameters.from(_params),
            endFinal: String.fromCharCode(byte),
            contentBytes: contentBytes,
          );
          _inTextBlock = false;
          _textBlockInProgress = null;
          _setState(State.ground);
        } else {
          _provideCSISequence(
            Parameters.from(_params),
            String.fromCharCode(byte),
          );
          _inTextBlock = false;
          _setState(State.ground);
        }

      // CSI sequence final character
      //   -> dispatch CSI sequence
      case (>= 0x40 && <= 0x7D):
        _params.store();
        if (!_inTextBlock || (_inTextBlock && _params[_params.getCount() - 1] == '201')) {
          _provideCSISequence(
            Parameters.from(_params),
            String.fromCharCode(byte),
          );
          _setState(State.ground);
        } else {
          // In textBlock but not end marker - return to textBlock to continue accumulating
          _setState(State.textBlock);
        }

      // Intermediates to collect
      case (>= 0x20 && <= 0x2F):
        _params.store();
        _setState(State.csiIntermediate);

      // Ignore
      case (>= 0x3C && <= 0x3F):
        _setState(State.csiIgnore);

      // Execute
      case (>= 0x00 && <= 0x17) || 0x19 || (>= 0x1C && <= 0x1F):
        _provideChar(String.fromCharCode(byte));

      // CAN/SUB: anywhere rule. Cancel the CSI sequence (including an
      // in-progress bracketed-paste close marker) and deliver the control
      // byte.
      case 0x18 || 0x1A:
        _cancelAndDeliver(byte);

      // Does it mean we should ignore the whole sequence?
      // Ignore
      case 0x7F:
        {}

      // Other bytes are considered as invalid -> cancel whatever we have
      default:
        _setState(State.ground);
    }
  }

  void _advanceCsiIntermediateState(int byte) {
    switch (byte) {
      case 0x1b:
        _handleError('Unexpected Esc byte in CSI intermediate', type: 'unexpectedEscape');

      // Intermediates to collect
      case (>= 0x20 && <= 0x2F):
        {}

      // Parameter byte after an intermediate: malformed. DEC consumes the
      // remainder of the sequence in csi_ignore rather than dispatching it.
      case (>= 0x30 && <= 0x3F):
        _setState(State.csiIgnore);

      // CSI sequence final character
      //   -> dispatch CSI sequence
      case (>= 0x40 && <= 0x7E):
        _provideCSISequence(
          Parameters.from(_params),
          String.fromCharCode(byte),
        );

        _setState(State.ground);
      // Execute
      case (>= 0x00 && <= 0x17) || 0x19 || (>= 0x1C && <= 0x1F):
        _provideChar(String.fromCharCode(byte));

      // CAN/SUB: anywhere rule. Cancel the CSI sequence and deliver the
      // control byte.
      case 0x18 || 0x1A:
        _cancelAndDeliver(byte);

      // Does it mean we should ignore the whole sequence?
      // Ignore
      case 0x7F:
        {}

      // Other bytes are considered as invalid -> cancel whatever we have
      default:
        _setState(State.ground);
    }
  }

  void _advanceTextBlockState(int byte) {
    switch (byte) {
      // block finish with a escape sequence
      case 0x1b:
        _setState(State.textBlockFinal);

      // CAN/SUB: anywhere rule for DCS passthrough (DEC: unhook + execute +
      // ground, no dispatch of the abandoned string). Bracketed paste is a
      // non-DEC extension whose only terminator is CSI 201~, and pasted
      // content may legitimately contain these bytes, so leave paste
      // accumulation alone: fall through to the default arm, same as any
      // other content byte.
      case 0x18 || 0x1A when !_inTextBlock:
        _cancelAndDeliver(byte);

      // Content bytes accumulate in _sequenceBytes (via advance() method)
      // This state handles opaque content for:
      // - Bracketed paste: CSI 200~ [content] ESC CSI 201~
      // - DCS sequences: ESC P>| [content] ESC \
      // Content is NOT parsed here - stays as raw bytes until end marker.
      // Parser functions extract content from _sequenceBytes using known offsets.
      default:
        {}
    }
  }

  void _advanceTextBlockFinalState(int byte) {
    switch (byte) {
      case 0x1b:
        {}

      // '\' final ST sequence
      case 0x5c:
        _provideDcsSequence(Parameters.from(_params), _sequenceBytes);
        _setState(State.ground);

      // bracketed paste finish with a CSI sequence
      case 0x5b:
        // Clear params for the new CSI sequence (end marker)
        if (_inTextBlock) _params.clear();
        _setState(State.csiEntry);

      // cancel the sequence?, or return to block mode and continue capturing?
      // this way we could accept escape characters inside the block
      default:
        _setState(State.ground);
    }
  }

  void _advanceOscEntryState(int byte) {
    switch (byte) {
      case 0x1b:
        _handleError('Unexpected Esc byte in OSC', type: 'unexpectedEscape');

      // Semicolon = parameter delimiter
      case 0x3B:
        _params.store();
        _setState(State.oscParameter);

      case >= 0x30 && <= 0x39:
        _params.add(byte);
        _setState(State.oscParameter);

      // CAN/SUB: anywhere rule. Cancel the OSC string and deliver the
      // control byte.
      case 0x18 || 0x1A:
        _cancelAndDeliver(byte);

      // Other bytes are considered as invalid -> cancel whatever we have
      default:
        _setState(State.ground);
    }
  }

  void _advanceOscParameterState(int byte) {
    switch (byte) {
      // '0' ..= '9' = parameter value
      case >= 0x30 && <= 0x39:
        _params.add(byte);

      // ';' = parameter delimiter
      case 0x3B:
        _params.store();

      // SP ..= '/' || ':' => '~'
      case (>= 0x20 && <= 0x2F) || (>= 0x3A && <= 0x7E):
        _params.add(byte);

      // CAN/SUB: anywhere rule. Cancel the OSC string (no dispatch) and
      // deliver the control byte, same as ground.
      case 0x18 || 0x1A:
        _cancelAndDeliver(byte);

      // default:
      //   _setState(State.oscBlock);
    }
  }

  void _advanceOscFinalState(int byte) {
    switch (byte) {
      // ignore this ESC, is the final sequence ESC \
      case 0x1b:
        {}

      // '\'
      case 0x5C:
        _params.store();
        _provideOscSequence(Parameters.from(_params));

        _setState(State.ground);

      // CAN/SUB: anywhere rule. Cancel the OSC string and deliver the
      // control byte.
      case 0x18 || 0x1A:
        _cancelAndDeliver(byte);

      // Other bytes are considered as invalid -> cancel whatever we have
      default:
        _setState(State.ground);
    }
  }

  void _advanceDcsEntryState(int byte) {
    switch (byte) {
      case 0x1b:
        _handleError('Unexpected Esc byte in DCS entry', type: 'unexpectedEscape');

      // <=>?
      case >= 0x3C && <= 0x3F:
        _params
          ..add(byte)
          ..store();

      // '0' ..= '9' = parameter value; extend the pending parameter.
      case >= 0x30 && <= 0x39:
        _params.add(byte);

      // ';' = parameter delimiter.
      case 0x3B:
        _params.store();

      // ':' - DEC abandons the header here (dcs_ignore): no hook, no dispatch.
      case 0x3A:
        _setState(State.dcsIgnore);

      // DCS sequence final character (0x40-0x7E) -> hook the passthrough.
      // The final byte is the dispatch selector, not a parameter value
      // (mirrors CSI, whose final char never lands in params); only flush
      // a parameter that was actually accumulating.
      case >= 0x40 && <= 0x7E:
        if (_params.hasPendingParameter) _params.store();
        _setState(State.textBlock);

      case (>= 0x00 && <= 0x17) || 0x19 || (>= 0x1C && <= 0x1F):
        {}

      // CAN/SUB: anywhere rule. Cancel the DCS header (no hook, no dispatch)
      // and deliver the control byte.
      case 0x18 || 0x1A:
        _cancelAndDeliver(byte);

      // Intermediates: flush a pending parameter as its own entry, then
      // collect the intermediate bytes as a fresh pending value.
      case (>= 0x20 && <= 0x2F):
        if (_params.hasPendingParameter) _params.store();
        _params.add(byte);

      // Does it mean we should ignore the whole sequence?
      // Ignore
      case 0x7F:
        {}

      // Other bytes are considered as invalid -> cancel whatever we have
      default:
        {}
    }
  }

  void _advanceDcsIgnoreState(int byte) {
    switch (byte) {
      // CAN/SUB: anywhere rule, even from the abandoned dcs_ignore header.
      // Cancel and deliver the control byte.
      case 0x18 || 0x1A:
        _cancelAndDeliver(byte);

      // DEC dcs_ignore: every other byte 0x00-0x7F is dropped; the only
      // other way out is the generic ESC anywhere-rule handled in
      // _handlePossibleEsc.
      default:
        {}
    }
  }

  void _advanceSosPmApcStringState(int byte) {
    switch (byte) {
      // CAN/SUB: anywhere rule. Cancel the string and deliver the control
      // byte.
      case 0x18 || 0x1A:
        _cancelAndDeliver(byte);

      // DEC's sos_pm_apc_string row drops every other byte outright — C0
      // executes (00-17,19,1C-1F) included, unlike ground/escape/CSI where
      // those bytes execute. Printables and 7F are ignored too. Nothing is
      // accumulated: this state is a pure swallow, upgradeable later to
      // capture content (e.g. kitty graphics) without changing the shape of
      // the ignore path.
      default:
        {}
    }
  }

  void _advanceSosPmApcStringFinalState(int byte) {
    switch (byte) {
      // ignore this ESC, is the final sequence ESC \
      case 0x1b:
        {}

      // '\' final ST sequence: terminate with no emission (the string body
      // was never captured).
      case 0x5c:
        _setState(State.ground);

      // CAN/SUB: anywhere rule. Cancel the string and deliver the control
      // byte.
      case 0x18 || 0x1A:
        _cancelAndDeliver(byte);

      // Other bytes are considered as invalid -> cancel whatever we have
      default:
        _setState(State.ground);
    }
  }

  void _advanceUtf8State(int byte) {
    if (byte & 0xC0 != 0x80) {
      _setState(State.ground);
      return;
    }
    _utf8.addByte(byte);

    if (_utf8.isComplete()) {
      final data = _utf8.getCodePoint();
      // BOM (EF BB BF) decodes to "" — drop it; no KeyEvent makes sense for it.
      if (data.isNotEmpty) _provideChar(data);
      _setState(State.ground);
    }
  }

  /// Advance the state machine with a single input byte.
  ///
  /// Processes the byte through state transitions and returns SequenceData
  /// when a complete sequence is parsed. Returns null while building sequence.
  ///
  /// The [hasMore] parameter indicates if more input is immediately available,
  /// which helps distinguish between ESC key press and ESC sequence start.
  SequenceData? advance(int byte, {bool hasMore = false}) {
    final byteValue = byte & 0xFF;
    // Accumulate bytes when not in ground state (building a sequence).
    // SOS/PM/APC string states are excluded: the string body is swallowed,
    // never captured, so accumulating here would just be unbounded growth
    // from a hostile unterminated stream for no benefit.
    if (_state != State.ground && _state != State.sosPmApcString && _state != State.sosPmApcStringFinal) {
      _sequenceBytes.add(byteValue);
    }

    if (_handlePossibleEsc(byteValue, hasMore: hasMore)) {
      final result = _emit;
      _emit = null;
      return result;
    }

    final _ = switch (_state) {
      State.ground => _advanceGroundState(byteValue),
      State.escape => _advanceEscapeState(byteValue),
      State.escapeIntermediate => _advanceEscapeIntermediateState(byteValue),
      State.csiEntry => _advanceCsiEntryState(byteValue),
      State.csiIgnore => _advanceCsiIgnoreState(byteValue),
      State.csiParameter => _advanceCsiParameterState(byteValue),
      State.csiIntermediate => _advanceCsiIntermediateState(byteValue),
      State.textBlock => _advanceTextBlockState(byteValue),
      State.textBlockFinal => _advanceTextBlockFinalState(byteValue),
      State.oscEntry => _advanceOscEntryState(byteValue),
      State.oscParameter => _advanceOscParameterState(byteValue),
      State.oscFinal => _advanceOscFinalState(byteValue),
      State.dcsEntry => _advanceDcsEntryState(byteValue),
      State.dcsIgnore => _advanceDcsIgnoreState(byteValue),
      State.sosPmApcString => _advanceSosPmApcStringState(byteValue),
      State.sosPmApcStringFinal => _advanceSosPmApcStringFinalState(byteValue),
      State.utf8 => _advanceUtf8State(byteValue),
    };

    final result = _emit;
    _emit = null;
    return result;
  }
}
