import '../events.dart';
import '../provider.dart';
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
  final List<int> _sequenceBytes = [];

  /// Read-only access to current state (for testing/debugging)
  State get currentState => _state;

  /// Check if engine is in intermediate state (for testing/debugging)
  bool get isIntermediateState => _state != State.ground;

  /// Get human-readable name of current state (for debugging)
  String get currentStateName => _state.toString().split('.').last;

  /// Get defensive copy of current sequence bytes (for debugging)
  List<int> get currentSequenceBytes => List.from(_sequenceBytes);

  /// Get collected parameters so far (for debugging)
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
    if (newState == State.ground) {
      _params.clear();
      _utf8.reset();
      _sequenceBytes.clear();
    }
    _state = newState;
  }

  void _handleError(Provider provider, String message, EngineErrorType type) {
    final errorEvent = EngineErrorEvent(
      [],
      message: message,
      type: type,
      rawBytes: List.from(_sequenceBytes),
      stateAtError: _state.toString(),
      partialParameters: _params.getParameters(),
    );
    provider.addEvent(errorEvent);
    _setState(State.ground);
  }

  bool _handlePossibleEsc(Provider provider, int byte, {bool more = false}) {
    if (byte != 0x1b) {
      return false;
    }

    switch ((_state, more)) {
      // More input means possible Esc sequence, just switch state and wait
      case (State.ground, true):
        _setState(State.escape);
      // No more input means Esc key, dispatch it
      case (State.ground, false):
        provider.provideChar('\x1b');
      // More input means possible Esc sequence, dispatch the previous Esc char
      case (State.escape, true):
        provider.provideChar('\x1b');
      // No more input means Esc key, dispatch the previous & current Esc char
      case (State.escape, false):
        provider.provideChar('\x1b');
        provider.provideChar('\x1b');
        _setState(State.ground);
      case (State.oscParameter, true):
        _setState(State.oscFinal);
        return false;

      case (State.textBlock, true):
        _setState(State.textBlockFinal);
        return false;

      // Discard any state
      // More input means possible Esc sequence
      case (_, true):
        _setState(State.escape);
      // Discard any state
      // No more input means Esc key, dispatch it
      case (_, false):
        provider.provideChar('\x1b');
        _setState(State.ground);
    }

    return true;
  }

  bool _handlePossibleUtf8CodePoints(Provider provider, int byte) {
    if (byte & 0x80 == 0) {
      provider.provideChar(String.fromCharCode(byte));
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

  void _advanceGroundState(Provider provider, int byte) {
    if (_handlePossibleUtf8CodePoints(provider, byte)) return;

    return switch (byte) {
      0x1b => _handleError(provider, 'Unexpected Esc byte in ground state', EngineErrorType.unexpectedEscape),
      // Execute
      (>= 0x00 && <= 0x17) || 0x19 || (>= 0x1C && <= 0x1F) => provider.provideChar(String.fromCharCode(byte)),
      // get char
      >= 0x20 && <= 0x7F => provider.provideChar(String.fromCharCode(byte)),
      _ => {},
    };
  }

  void _advanceEscapeState(Provider provider, int byte) {
    switch (byte) {
      case 0x1b:
        _handleError(provider, 'Unexpected Esc byte in Advance State', EngineErrorType.unexpectedEscape);
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
        provider.provideESCSequence(String.fromCharCode(byte));
        _setState(State.ground);

      // Execute
      case (>= 0x00 && <= 0x17) || 0x19 || (>= 0x1C && <= 0x1F):
        provider.provideChar(String.fromCharCode(byte));

      // Does it mean we should ignore the whole sequence?
      // Ignore
      case 0x7F:
        {}

      // Other bytes are considered as invalid -> cancel whatever we have
      default:
        _setState(State.ground);
    }
  }

  void _advanceEscapeIntermediateState(Provider provider, int byte) {
    switch (byte) {
      case 0x1b:
        _handleError(provider, 'Unexpected Esc byte in ESC Intermediate', EngineErrorType.unexpectedEscape);

      // Intermediate bytes to collect
      case >= 0x20 && <= 0x2F:
        {}

      // Escape followed by '[' (0x5B)
      //   -> CSI sequence start
      case 0x5B:
        _setState(State.csiEntry);

      // Escape sequence final character
      case (>= 0x30 && <= 0x5A) || (>= 0x5C && <= 0x7E):
        provider.provideESCSequence(String.fromCharCode(byte));
        _setState(State.ground);

      // Execute
      case (>= 0x00 && <= 0x17) || 0x19 || (>= 0x1C && <= 0x1F):
        provider.provideChar(String.fromCharCode(byte));

      // Does it mean we should ignore the whole sequence?
      // Ignore
      case 0x7F:
        {}

      // Other bytes are considered as invalid -> cancel whatever we have
      default:
        _setState(State.ground);
    }
  }

  void _advanceCsiEntryState(Provider provider, int byte) {
    switch (byte) {
      case 0x1b:
        _handleError(provider, 'Unexpected Esc byte in CSI Entry state', EngineErrorType.unexpectedEscape);

      // '0' ..= '9' = parameter value
      case >= 0x30 && <= 0x39:
        _params.add(byte);
        _setState(State.csiParameter);

      // ';' = parameter delimiter
      case 0x3B:
        _params.store();
        _setState(State.csiParameter);

      // '<' SGR Mouse
      case 0x3C:
        _setState(State.csiParameter);

      // ':' sequence delimiter
      case 0x3A:
        _setState(State.csiIgnore);

      // CSI sequence final character
      //   -> dispatch CSI sequence
      case >= 0x40 && <= 0x7E:
        provider.provideCSISequence(
          _params.getParameters(),
          _params.getIgnoredCount(),
          String.fromCharCode(byte),
        );

        _setState(State.ground);

      // Execute
      case (>= 0x00 && <= 0x17) || 0x19 || (>= 0x1C && <= 0x1F):
        provider.provideChar(String.fromCharCode(byte));

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

  void _advanceCsiIgnoreState(Provider provider, int byte) {
    switch (byte) {
      case 0x1b:
        _handleError(provider, 'Unexpected Esc byte in CSI Ignore', EngineErrorType.unexpectedEscape);

      // Execute
      case (>= 0x00 && <= 0x17) || 0x19 || (>= 0x1C && <= 0x1F):
        provider.provideChar(String.fromCharCode(byte));

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

  void _advanceCsiParameterState(Provider provider, int byte) {
    switch (byte) {
      case 0x1b:
        _handleError(provider, 'Unexpected Esc byte in CSI Param', EngineErrorType.unexpectedEscape);

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
        } else {
          provider.provideCSISequence(
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
          provider.provideCSISequence(
            _params.getParameters(),
            _params.getIgnoredCount(),
            String.fromCharCode(byte),
          );
        }

        _setState(State.ground);

      // Intermediates to collect
      case (>= 0x20 && <= 0x2F):
        _params.store();
        _setState(State.csiIntermediate);

      // Ignore
      case (>= 0x3C && <= 0x3F):
        _setState(State.csiIgnore);

      // Execute
      case (>= 0x00 && <= 0x17) || 0x19 || (>= 0x1C && <= 0x1F):
        provider.provideChar(String.fromCharCode(byte));

      // Does it mean we should ignore the whole sequence?
      // Ignore
      case 0x7F:
        {}

      // Other bytes are considered as invalid -> cancel whatever we have
      default:
        _setState(State.ground);
    }
  }

  void _advanceCsiIntermediateState(Provider provider, int byte) {
    switch (byte) {
      case 0x1b:
        _handleError(provider, 'Unexpected Esc byte in CSI intermediate', EngineErrorType.unexpectedEscape);

      // Intermediates to collect
      case (>= 0x20 && <= 0x2F):
        {}

      // CSI sequence final character
      //   -> dispatch CSI sequence
      case (>= 0x40 && <= 0x7E):
        provider.provideCSISequence(
          _params.getParameters(),
          _params.getIgnoredCount(),
          String.fromCharCode(byte),
        );

        _setState(State.ground);
      // Execute
      case (>= 0x00 && <= 0x17) || 0x19 || (>= 0x1C && <= 0x1F):
        provider.provideChar(String.fromCharCode(byte));

      // Does it mean we should ignore the whole sequence?
      // Ignore
      case 0x7F:
        {}

      // Other bytes are considered as invalid -> cancel whatever we have
      default:
        _setState(State.ground);
    }
  }

  void _advanceTextBlockState(Provider provider, int byte) {
    switch (byte) {
      // block finish with a escape sequence
      case 0x1b:
        _setState(State.textBlockFinal);

      // Other bytes are considered as valid
      default:
        _params.add(byte);
    }
  }

  void _advanceTextBlockFinalState(Provider provider, int byte) {
    switch (byte) {
      case 0x1b:
        {}

      // '\' final ST sequence
      case 0x5c:
        _params.store();
        provider.provideDcsSequence(
          _params.getParameters(),
          _params.getIgnoredCount(),
          '',
        );
        _setState(State.ground);

      // bracketed paste finish with a CSI sequence
      case 0x5b:
        _params.store();
        _setState(State.csiEntry);

      // cancel the sequence?, or return to block mode and continue capturing?
      // this way we could accept escape characters inside the block
      default:
        _setState(State.ground);
    }
  }

  void _advanceCsiXtermMouseState(Provider provider, int byte) {
    switch (byte) {
      case 0x1b:
        provider.provideCSISequence(
          _params.getParameters(),
          _params.getIgnoredCount(),
          'M',
        );
        _setState(State.ground);

      default:
        _params.add(byte);
        _params.store();
    }

    // ESC [ M Cb Cx Cy are only 6 characters, 3 of which are params
    if (_params.getCount() == 3) {
      provider.provideCSISequence(
        _params.getParameters(),
        _params.getIgnoredCount(),
        'M',
      );
      _setState(State.ground);
    }
  }

  void _advanceOscEntryState(Provider provider, int byte) {
    switch (byte) {
      case 0x1b:
        _handleError(provider, 'Unexpected Esc byte in OSC', EngineErrorType.unexpectedEscape);

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

  void _advanceOscParameterState(Provider provider, int byte) {
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

  void _advanceOscFinalState(Provider provider, int byte) {
    switch (byte) {
      // ignore this ESC, is the final sequence ESC \
      case 0x1b:
        {}

      // '\'
      case 0x5C:
        _params.store();
        provider.provideOscSequence(
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

  void _advanceDcsEntryState(Provider provider, int byte) {
    switch (byte) {
      case 0x1b:
        _handleError(provider, 'Unexpected Esc byte in DCS entry', EngineErrorType.unexpectedEscape);

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

  void _advanceUtf8State(Provider provider, int byte) {
    if (byte & 0xC0 != 0x80) {
      _setState(State.ground);
      return;
    }
    _utf8.addByte(byte);

    if (_utf8.isComplete()) {
      final data = _utf8.getCodePoint();
      provider.provideChar(data);
      _setState(State.ground);
    }
  }

  /// Advance the state machine with a single input byte.
  ///
  /// Processes the byte through state transitions and emits parsed sequences
  /// via the [provider]. Tracks sequence bytes for error reporting.
  ///
  /// The [more] parameter indicates if more input is immediately available,
  /// which helps distinguish between ESC key press and ESC sequence start.
  void advance(Provider provider, int byte, {bool more = false}) {
    // Accumulate bytes when not in ground state (building a sequence)
    // Skip textBlock state to avoid accumulating large paste content
    if (_state != State.ground && _state != State.textBlock) {
      _sequenceBytes.add(byte);
    }

    // print('advance: $state $byte/${byte.toHexString()} ${byte.isPrintable ? String.fromCharCode(byte) : ''} $more');
    if (_handlePossibleEsc(provider, byte, more: more)) {
      return;
    }

    return switch (_state) {
      State.ground => _advanceGroundState(provider, byte),
      State.escape => _advanceEscapeState(provider, byte),
      State.escapeIntermediate => _advanceEscapeIntermediateState(provider, byte),
      State.csiEntry => _advanceCsiEntryState(provider, byte),
      State.csiIgnore => _advanceCsiIgnoreState(provider, byte),
      State.csiParameter => _advanceCsiParameterState(provider, byte),
      State.csiIntermediate => _advanceCsiIntermediateState(provider, byte),
      State.textBlock => _advanceTextBlockState(provider, byte),
      State.textBlockFinal => _advanceTextBlockFinalState(provider, byte),
      State.oscEntry => _advanceOscEntryState(provider, byte),
      State.oscParameter => _advanceOscParameterState(provider, byte),
      State.oscFinal => _advanceOscFinalState(provider, byte),
      State.dcsEntry => _advanceDcsEntryState(provider, byte),
      State.utf8 => _advanceUtf8State(provider, byte),
    };
  }
}
