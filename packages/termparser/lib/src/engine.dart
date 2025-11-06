// ignore_for_file: public_member_api_docs

import 'dart:convert';

import './provider.dart';

const _maxParameters = 30;
const _defaultParameterValue = '0';
const _maxUtf8CodePoints = 4;

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

/// Helper class to accumulate parameters from escape sequences
class _ParameterAccumulator {
  final _parameters = List<String>.filled(_maxParameters, _defaultParameterValue);
  int _parametersCount = 0;
  final List<int> _parameter = [];
  int _ignoredParametersCount = 0;

  _ParameterAccumulator() {
    _parameters.fillRange(0, _parameters.length, _defaultParameterValue);
  }

  /// Store current parameter and move to next
  void store() {
    if (_parametersCount < _maxParameters) {
      final param = utf8.decode(_parameter, allowMalformed: true);
      _parameters[_parametersCount] = param.isEmpty ? _defaultParameterValue : param;
      _parametersCount++;
    } else {
      _ignoredParametersCount++;
    }
    _parameter.clear();
  }

  /// Clear all parameters
  void clear() {
    _parametersCount = 0;
    _parameter.clear();
    _ignoredParametersCount = 0;
  }

  /// Add byte to current parameter
  void add(int byte) {
    _parameter.add(byte);
  }

  /// Get stored parameters
  List<String> getParameters() => _parameters.sublist(0, _parametersCount);

  /// Get count of stored parameters
  int getCount() => _parametersCount;

  /// Get count of ignored parameters
  int getIgnoredCount() => _ignoredParametersCount;

  /// Access parameter at index
  String operator [](int index) => _parameters[index];
}

/// Helper class to decode UTF-8 sequences
class _Utf8Decoder {
  final _utf8Points = List<int>.filled(_maxUtf8CodePoints, 0);
  int _utf8PointsCount = 0;
  int _utf8PointsExpectedCount = 0;

  _Utf8Decoder() {
    _utf8Points.fillRange(0, _utf8Points.length, 0);
  }

  /// Add byte to UTF-8 sequence
  void addByte(int byte) {
    _utf8Points[_utf8PointsCount] = byte;
    _utf8PointsCount++;
  }

  /// Check if UTF-8 sequence is complete
  bool isComplete() => _utf8PointsCount == _utf8PointsExpectedCount;

  /// Get decoded codepoint
  String getCodePoint() {
    return utf8.decode(_utf8Points.sublist(0, _utf8PointsCount));
  }

  /// Reset decoder
  void reset() {
    _utf8PointsCount = 0;
    _utf8PointsExpectedCount = 0;
  }

  /// Start 2-byte UTF-8 sequence
  void start2Byte(int firstByte) {
    _utf8PointsCount = 1;
    _utf8Points[0] = firstByte;
    _utf8PointsExpectedCount = 2;
  }

  /// Start 3-byte UTF-8 sequence
  void start3Byte(int firstByte) {
    _utf8PointsCount = 1;
    _utf8Points[0] = firstByte;
    _utf8PointsExpectedCount = 3;
  }

  /// Start 4-byte UTF-8 sequence
  void start4Byte(int firstByte) {
    _utf8PointsCount = 1;
    _utf8Points[0] = firstByte;
    _utf8PointsExpectedCount = 4;
  }
}

///
class Engine {
  final _params = _ParameterAccumulator();
  final _utf8 = _Utf8Decoder();
  State _state = State.ground;
  bool _inTextBlock = false;

  /// Read-only access to current state (for testing/debugging)
  State get currentState => _state;

  /// Check if engine is in intermediate state (for testing/debugging)
  bool get isIntermediateState => _state != State.ground;

  Engine();

  void _setState(State newState) {
    if (newState == State.ground) {
      _params.clear();
      _utf8.reset();
    }
    _state = newState;
  }

  void storeParameter() {
    _params.store();
  }

  bool handlePossibleEsc(Provider provider, int byte, {bool more = false}) {
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

  bool handlePossibleUtf8CodePoints(Provider provider, int byte) {
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

  void advanceGroundState(Provider provider, int byte) {
    if (handlePossibleUtf8CodePoints(provider, byte)) return;

    return switch (byte) {
      0x1b => throw Exception('Unexpected Esc byte in ground state'),
      // Execute
      (>= 0x00 && <= 0x17) || 0x19 || (>= 0x1C && <= 0x1F) => provider.provideChar(String.fromCharCode(byte)),
      // get char
      >= 0x20 && <= 0x7F => provider.provideChar(String.fromCharCode(byte)),
      _ => {},
    };
  }

  void advanceEscapeState(Provider provider, int byte) {
    switch (byte) {
      case 0x1b:
        throw Exception('Unexpected Esc byte in Advance State');
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

  void advanceEscapeIntermediateState(Provider provider, int byte) {
    switch (byte) {
      case 0x1b:
        throw Exception('Unexpected Esc byte in ESC Intermediate');

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

  void advanceCsiEntryState(Provider provider, int byte) {
    switch (byte) {
      case 0x1b:
        throw Exception('Unexpected Esc byte in CSI Entry state');

      // '0' ..= '9' = parameter value
      case >= 0x30 && <= 0x39:
        _params.add(byte);
        _setState(State.csiParameter);

      // ';' = parameter delimiter
      case 0x3B:
        storeParameter();
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
        _params.add(byte);
        storeParameter();
    }
  }

  void advanceCsiIgnoreState(Provider provider, int byte) {
    switch (byte) {
      case 0x1b:
        throw Exception('Unexpected Esc byte in CSI Ignore');

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

  void advanceCsiParameterState(Provider provider, int byte) {
    switch (byte) {
      case 0x1b:
        throw Exception('Unexpected Esc byte in CSI Param');

      // '0' ..= '9' = parameter value
      case (>= 0x30 && <= 0x39):
        _params.add(byte);

      // ':' sequence delimiter
      case 0x3A:
        _params.add(byte);

      // ';' parameter delimiter
      case 0x3B:
        storeParameter();

      // `~`
      case 0x7E:
        storeParameter();
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
        storeParameter();
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
        storeParameter();
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

  void advanceCsiIntermediateState(Provider provider, int byte) {
    switch (byte) {
      case 0x1b:
        throw Exception('Unexpected Esc byte in CSI intermediate');

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

  void advanceTextBlockState(Provider provider, int byte) {
    switch (byte) {
      // block finish with a escape sequence
      case 0x1b:
        _setState(State.textBlockFinal);

      // Other bytes are considered as valid
      default:
        _params.add(byte);
    }
  }

  void advanceTextBlockFinalState(Provider provider, int byte) {
    switch (byte) {
      case 0x1b:
        {}

      // '\' final ST sequence
      case 0x5c:
        storeParameter();
        provider.provideDcsSequence(
          _params.getParameters(),
          _params.getIgnoredCount(),
          '',
        );
        _setState(State.ground);

      // bracketed paste finish with a CSI sequence
      case 0x5b:
        storeParameter();
        _setState(State.csiEntry);

      // cancel the sequence?, or return to block mode and continue capturing?
      // this way we could accept escape characters inside the block
      default:
        _setState(State.ground);
    }
  }

  void advanceCsiXtermMouseState(Provider provider, int byte) {
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
        storeParameter();
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

  void advanceOscEntryState(Provider provider, int byte) {
    switch (byte) {
      case 0x1b:
        throw Exception('Unexpected Esc byte in OSC');

      // Semicolon = parameter delimiter
      case 0x3B:
        storeParameter();
        _setState(State.oscParameter);

      case >= 0x30 && <= 0x39:
        _params.add(byte);
        _setState(State.oscParameter);

      // Other bytes are considered as invalid -> cancel whatever we have
      default:
        _setState(State.ground);
    }
  }

  void advanceOscParameterState(Provider provider, int byte) {
    switch (byte) {
      // '0' ..= '9' = parameter value
      case >= 0x30 && <= 0x39:
        _params.add(byte);

      // ';' = parameter delimiter
      case 0x3B:
        storeParameter();

      // '/' || ':' => '~'
      case 0x2F || (>= 0x3A && <= 0x7E):
        _params.add(byte);

      // default:
      //   _setState(State.oscBlock);
    }
  }

  void advanceOscFinalState(Provider provider, int byte) {
    switch (byte) {
      // ignore this ESC, is the final sequence ESC \
      case 0x1b:
        {}

      // '\'
      case 0x5C:
        storeParameter();
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

  void advanceDcsEntryState(Provider provider, int byte) {
    switch (byte) {
      case 0x1b:
        throw Exception('Unexpected Esc byte in DCS entry');

      // <=>?
      case >= 0x3C && <= 0x3F:
        _params.add(byte);
        storeParameter();

      case >= 40 && <= 0x7E:
        _params.add(byte);
        storeParameter();
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

  void advanceUtf8State(Provider provider, int byte) {
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

  void advance(Provider provider, int byte, {bool more = false}) {
    // print('advance: $state $byte/${byte.toHexString()} ${byte.isPrintable ? String.fromCharCode(byte) : ''} $more');
    if (handlePossibleEsc(provider, byte, more: more)) {
      return;
    }

    return switch (_state) {
      State.ground => advanceGroundState(provider, byte),
      State.escape => advanceEscapeState(provider, byte),
      State.escapeIntermediate => advanceEscapeIntermediateState(provider, byte),
      State.csiEntry => advanceCsiEntryState(provider, byte),
      State.csiIgnore => advanceCsiIgnoreState(provider, byte),
      State.csiParameter => advanceCsiParameterState(provider, byte),
      State.csiIntermediate => advanceCsiIntermediateState(provider, byte),
      State.textBlock => advanceTextBlockState(provider, byte),
      State.textBlockFinal => advanceTextBlockFinalState(provider, byte),
      State.oscEntry => advanceOscEntryState(provider, byte),
      State.oscParameter => advanceOscParameterState(provider, byte),
      State.oscFinal => advanceOscFinalState(provider, byte),
      State.dcsEntry => advanceDcsEntryState(provider, byte),
      State.utf8 => advanceUtf8State(provider, byte),
    };
  }
}
