import '../events/error_event.dart';
import '../parsers/char_parser.dart';
import '../parsers/csi_parser.dart';
import '../parsers/dcs_parser.dart';
import '../parsers/esc_parser.dart';
import '../parsers/osc_parser.dart';
import './event_queue.dart';
import './parameter_accumulator.dart';
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

  /// Possible UTF-8 sequence and we're collecting UTF-8 code points.
  utf8,
}

/// VT500-series ANSI escape sequence state machine engine.
///
/// Processes input bytes one at a time through state transitions.
/// Emits parsed sequences via the Provider interface.
///
/// Engine handles structural validation - detecting malformed sequences,
/// invalid state transitions, and unexpected bytes. When errors occur,
/// it emits [EngineErrorEvent] with full context for debugging.
class Engine {
  final _params = ParameterAccumulator();
  final _utf8 = Utf8Decoder();
  State _state = State.ground;
  bool _inTextBlock = false;
  bool _escO = false;

  /// Accumulates all bytes of the current sequence being processed (cleared on ground state).
  ///
  /// Serves two purposes:
  /// 1. **Error Reporting**: Provides full raw byte sequence context in [EngineErrorEvent]
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
    // Clear on ground for UTF-8 and sequence bytes tracking
    if (newState == State.ground) {
      _utf8.reset();
      _sequenceBytes.clear();
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

  void _handleError(EventQueue queue, String message, EngineErrorType type) {
    final errorEvent = EngineErrorEvent(
      const [],
      message: message,
      type: type,
      rawBytes: List.from(_sequenceBytes),
      stateAtError: _state.toString(),
      partialParameters: _params.getParameters(),
    );
    queue.add(errorEvent);
    _setState(State.ground);
  }

  bool _handlePossibleEsc(EventQueue queue, int byte, {bool hasMore = false}) {
    if (byte != 0x1b) {
      return false;
    }

    switch ((_state, hasMore)) {
      // More input means possible Esc sequence, just switch state and wait
      case (State.ground, true):
        _setState(State.escape);
      // No more input means Esc key, dispatch it
      case (State.ground, false):
        _provideChar(queue, '\x1b');
      // More input means possible Esc sequence, dispatch the previous Esc char
      case (State.escape, true):
        _provideChar(queue, '\x1b');
      // No more input means Esc key, dispatch the previous & current Esc char
      case (State.escape, false):
        _provideChar(queue, '\x1b');
        _provideChar(queue, '\x1b');
        _setState(State.ground);
      case (State.oscParameter, true):
        _setState(State.oscFinal);
        return false;

      case (State.textBlock, true):
        _setState(State.textBlockFinal);
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
        _provideChar(queue, '\x1b');
        _setState(State.ground);
    }

    return true;
  }

  void _provideChar(EventQueue queue, String char) {
    final event = parseChar(char, escO: _escO);
    if (event != null) queue.add(event);
    _escO = false;
  }

  void _provideESCSequence(EventQueue queue, String char) {
    if (char == 'O') {
      // Exception: Esc O is followed by single character (P-S) representing F1-F4 keys
      _escO = true;
    } else {
      final event = parseESCSequence(char);
      if (event != null) queue.add(event);
      _escO = false;
    }
  }

  void _provideCSISequence(EventQueue queue, List<String> parameters, int ignoredParameterCount, String char) {
    final event = parseCSISequence(parameters, ignoredParameterCount, char);
    queue.add(event);
    _escO = false;
  }

  void _provideOscSequence(EventQueue queue, List<String> parameters, int ignoredParameterCount, String char) {
    final event = parseOscSequence(parameters, ignoredParameterCount, char);
    queue.add(event);
    _escO = false;
  }

  void _provideDcsSequence(
    EventQueue queue,
    List<String> parameters,
    int ignoredParameterCount,
    String char,
    List<int> sequenceBytes,
  ) {
    final event = parseDcsSequence(parameters, ignoredParameterCount, char, sequenceBytes);
    queue.add(event);
    _escO = false;
  }

  bool _handlePossibleUtf8CodePoints(EventQueue queue, int byte) {
    if (byte & 0x80 == 0) {
      _provideChar(queue, String.fromCharCode(byte));
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

  void _advanceGroundState(EventQueue queue, int byte) {
    if (_handlePossibleUtf8CodePoints(queue, byte)) return;

    return switch (byte) {
      // Execute
      (>= 0x00 && <= 0x17) || 0x19 || (>= 0x1C && <= 0x1F) => _provideChar(queue, String.fromCharCode(byte)),
      // get char
      >= 0x20 && <= 0x7F => _provideChar(queue, String.fromCharCode(byte)),
      _ => {},
    };
  }

  void _advanceEscapeState(EventQueue queue, int byte) {
    switch (byte) {
      case 0x1b:
        _handleError(queue, 'Unexpected Esc byte in Advance State', EngineErrorType.unexpectedEscape);
      // Intermediate bytes to collect
      case >= 0x20 && <= 0x2F:
        _setState(State.escapeIntermediate);

      // DCS
      case 0x50:
        _setState(State.dcsEntry);

      // Escape followed by '[' (0x5B) -> CSI sequence start
      case 0x5B:
        _setState(State.csiEntry);

      // Escape followed by ']' (0x5D) -> OSC sequence start
      case 0x5D:
        _setState(State.oscEntry);

      // Escape sequence final character
      case (>= 0x30 && <= 0x4F) || (>= 0x51 && <= 0x57) || 0x59 || 0x5A || 0x5C || (>= 0x60 && <= 0x7E):
        _provideESCSequence(queue, String.fromCharCode(byte));
        _setState(State.ground);

      // Execute
      case (>= 0x00 && <= 0x17) || 0x19 || (>= 0x1C && <= 0x1F):
        _provideChar(queue, String.fromCharCode(byte));

      // Does it mean we should ignore the whole sequence?
      // Ignore
      case 0x7F:
        {}

      // Other bytes are considered as invalid -> cancel whatever we have
      default:
        _setState(State.ground);
    }
  }

  void _advanceEscapeIntermediateState(EventQueue queue, int byte) {
    switch (byte) {
      case 0x1b:
        _handleError(queue, 'Unexpected Esc byte in ESC Intermediate', EngineErrorType.unexpectedEscape);

      // Intermediate bytes to collect
      case >= 0x20 && <= 0x2F:
        {}

      // Escape followed by '[' (0x5B)
      //   -> CSI sequence start
      case 0x5B:
        _setState(State.csiEntry);

      // Escape sequence final character
      case (>= 0x30 && <= 0x5A) || (>= 0x5C && <= 0x7E):
        _provideESCSequence(queue, String.fromCharCode(byte));
        _setState(State.ground);

      // Execute
      case (>= 0x00 && <= 0x17) || 0x19 || (>= 0x1C && <= 0x1F):
        _provideChar(queue, String.fromCharCode(byte));

      // Does it mean we should ignore the whole sequence?
      // Ignore
      case 0x7F:
        {}

      // Other bytes are considered as invalid -> cancel whatever we have
      default:
        _setState(State.ground);
    }
  }

  void _advanceCsiEntryState(EventQueue queue, int byte) {
    switch (byte) {
      case 0x1b:
        _handleError(queue, 'Unexpected Esc byte in CSI Entry state', EngineErrorType.unexpectedEscape);

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
          queue,
          _params.getParameters(),
          _params.getIgnoredCount(),
          String.fromCharCode(byte),
        );

        _setState(State.ground);

      // Execute
      case (>= 0x00 && <= 0x17) || 0x19 || (>= 0x1C && <= 0x1F):
        _provideChar(queue, String.fromCharCode(byte));

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

  void _advanceCsiIgnoreState(EventQueue queue, int byte) {
    switch (byte) {
      case 0x1b:
        _handleError(queue, 'Unexpected Esc byte in CSI Ignore', EngineErrorType.unexpectedEscape);

      // Execute
      case (>= 0x00 && <= 0x17) || 0x19 || (>= 0x1C && <= 0x1F):
        _provideChar(queue, String.fromCharCode(byte));

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

  void _advanceCsiParameterState(EventQueue queue, int byte) {
    switch (byte) {
      case 0x1b:
        _handleError(queue, 'Unexpected Esc byte in CSI Param', EngineErrorType.unexpectedEscape);

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
          _inTextBlock = true;
          _setState(State.textBlock);
        } else if (_inTextBlock && _params[0] == '201') {
          // End of bracketed paste - extract content from _sequenceBytes
          final event = parseBracketedPaste(_sequenceBytes);
          queue.add(event);
          _inTextBlock = false;
          _setState(State.ground);
        } else {
          _provideCSISequence(
            queue,
            _params.getParameters(),
            _params.getIgnoredCount(),
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
            queue,
            _params.getParameters(),
            _params.getIgnoredCount(),
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
        _provideChar(queue, String.fromCharCode(byte));

      // Does it mean we should ignore the whole sequence?
      // Ignore
      case 0x7F:
        {}

      // Other bytes are considered as invalid -> cancel whatever we have
      default:
        _setState(State.ground);
    }
  }

  void _advanceCsiIntermediateState(EventQueue queue, int byte) {
    switch (byte) {
      case 0x1b:
        _handleError(queue, 'Unexpected Esc byte in CSI intermediate', EngineErrorType.unexpectedEscape);

      // Intermediates to collect
      case (>= 0x20 && <= 0x2F):
        {}

      // CSI sequence final character
      //   -> dispatch CSI sequence
      case (>= 0x40 && <= 0x7E):
        _provideCSISequence(
          queue,
          _params.getParameters(),
          _params.getIgnoredCount(),
          String.fromCharCode(byte),
        );

        _setState(State.ground);
      // Execute
      case (>= 0x00 && <= 0x17) || 0x19 || (>= 0x1C && <= 0x1F):
        _provideChar(queue, String.fromCharCode(byte));

      // Does it mean we should ignore the whole sequence?
      // Ignore
      case 0x7F:
        {}

      // Other bytes are considered as invalid -> cancel whatever we have
      default:
        _setState(State.ground);
    }
  }

  void _advanceTextBlockState(EventQueue queue, int byte) {
    switch (byte) {
      // block finish with a escape sequence
      case 0x1b:
        _setState(State.textBlockFinal);

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

  void _advanceTextBlockFinalState(EventQueue queue, int byte) {
    switch (byte) {
      case 0x1b:
        {}

      // '\' final ST sequence
      case 0x5c:
        _provideDcsSequence(
          queue,
          _params.getParameters(),
          _params.getIgnoredCount(),
          '',
          _sequenceBytes,
        );
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

  void _advanceOscEntryState(EventQueue queue, int byte) {
    switch (byte) {
      case 0x1b:
        _handleError(queue, 'Unexpected Esc byte in OSC', EngineErrorType.unexpectedEscape);

      // Semicolon = parameter delimiter
      case 0x3B:
        _params.store();
        _setState(State.oscParameter);

      case >= 0x30 && <= 0x39:
        _params.add(byte);
        _setState(State.oscParameter);

      // Other bytes are considered as invalid -> cancel whatever we have
      default:
        _setState(State.ground);
    }
  }

  void _advanceOscParameterState(EventQueue queue, int byte) {
    switch (byte) {
      // '0' ..= '9' = parameter value
      case >= 0x30 && <= 0x39:
        _params.add(byte);

      // ';' = parameter delimiter
      case 0x3B:
        _params.store();

      // '/' || ':' => '~'
      case 0x2F || (>= 0x3A && <= 0x7E):
        _params.add(byte);

      // default:
      //   _setState(State.oscBlock);
    }
  }

  void _advanceOscFinalState(EventQueue queue, int byte) {
    switch (byte) {
      // ignore this ESC, is the final sequence ESC \
      case 0x1b:
        {}

      // '\'
      case 0x5C:
        _params.store();
        _provideOscSequence(
          queue,
          _params.getParameters(),
          _params.getIgnoredCount(),
          '',
        );

        _setState(State.ground);

      // Other bytes are considered as invalid -> cancel whatever we have
      default:
        _setState(State.ground);
    }
  }

  void _advanceDcsEntryState(EventQueue queue, int byte) {
    switch (byte) {
      case 0x1b:
        _handleError(queue, 'Unexpected Esc byte in DCS entry', EngineErrorType.unexpectedEscape);

      // <=>?
      case >= 0x3C && <= 0x3F:
        _params
          ..add(byte)
          ..store();

      case >= 40 && <= 0x7E:
        _params
          ..add(byte)
          ..store();
        _setState(State.textBlock);

      case (>= 0x00 && <= 0x17) || 0x19 || (>= 0x1C && <= 0x1F):
        {}

      case (>= 0x20 && <= 0x2F):
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

  void _advanceUtf8State(EventQueue queue, int byte) {
    if (byte & 0xC0 != 0x80) {
      _setState(State.ground);
      return;
    }
    _utf8.addByte(byte);

    if (_utf8.isComplete()) {
      final data = _utf8.getCodePoint();
      _provideChar(queue, data);
      _setState(State.ground);
    }
  }

  /// Advance the state machine with a single input byte.
  ///
  /// Processes the byte through state transitions and emits parsed sequences
  /// via the [queue]. Tracks sequence bytes for error reporting.
  ///
  /// The [hasMore] parameter indicates if more input is immediately available,
  /// which helps distinguish between ESC key press and ESC sequence start.
  void advance(EventQueue queue, int byte, {bool hasMore = false}) {
    final byteValue = byte & 0xFF;
    // Accumulate bytes when not in ground state (building a sequence)
    if (_state != State.ground) {
      _sequenceBytes.add(byteValue);
    }

    // print('advance: $state $byte/${byte.toHexString()} ${byte.isPrintable ? String.fromCharCode(byte) : ''} $hasMore');
    if (_handlePossibleEsc(queue, byteValue, hasMore: hasMore)) {
      return;
    }

    return switch (_state) {
      State.ground => _advanceGroundState(queue, byteValue),
      State.escape => _advanceEscapeState(queue, byteValue),
      State.escapeIntermediate => _advanceEscapeIntermediateState(queue, byteValue),
      State.csiEntry => _advanceCsiEntryState(queue, byteValue),
      State.csiIgnore => _advanceCsiIgnoreState(queue, byteValue),
      State.csiParameter => _advanceCsiParameterState(queue, byteValue),
      State.csiIntermediate => _advanceCsiIntermediateState(queue, byteValue),
      State.textBlock => _advanceTextBlockState(queue, byteValue),
      State.textBlockFinal => _advanceTextBlockFinalState(queue, byteValue),
      State.oscEntry => _advanceOscEntryState(queue, byteValue),
      State.oscParameter => _advanceOscParameterState(queue, byteValue),
      State.oscFinal => _advanceOscFinalState(queue, byteValue),
      State.dcsEntry => _advanceDcsEntryState(queue, byteValue),
      State.utf8 => _advanceUtf8State(queue, byteValue),
    };
  }
}
