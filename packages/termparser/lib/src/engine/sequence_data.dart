import 'package:meta/meta.dart';
import 'package:termparser/src/extensions/list_extension.dart';

import 'parameters.dart';

/// Base class for all sequence data emitted by the Engine.
///
/// The Engine parses ANSI escape sequences and emits SequenceData objects
/// representing the structural content. The Parser translates these into
/// semantic Events.
sealed class SequenceData {
  const SequenceData();
}

/// Single character data (both single-byte and UTF-8 multi-byte chars).
@immutable
final class CharData extends SequenceData {
  /// The character.
  final String char;

  /// Whether this char was preceded by ESC O (SS3).
  final bool escO;

  /// Create character data.
  const CharData(this.char, {required this.escO});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CharData && other.char == char && other.escO == escO;
  }

  @override
  int get hashCode => Object.hash(char, escO);

  @override
  String toString() => 'CharData($char, escO: $escO)';
}

/// ESC sequence data (ESC followed by a single character).
@immutable
final class EscSequenceData extends SequenceData {
  /// The character following ESC.
  final String char;

  /// Create ESC sequence data.
  const EscSequenceData(this.char);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EscSequenceData && other.char == char;
  }

  @override
  int get hashCode => char.hashCode;

  @override
  String toString() => 'EscSequenceData($char)';
}

/// CSI sequence data (ESC [ ... final).
@immutable
final class CsiSequenceData extends SequenceData {
  /// The parameters.
  final Parameters params;

  /// The final character.
  final String finalChar;

  /// Create CSI sequence data.
  const CsiSequenceData(this.params, this.finalChar);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CsiSequenceData && other.params == params && other.finalChar == finalChar;
  }

  @override
  int get hashCode => Object.hash(params, finalChar);

  @override
  String toString() => 'CsiSequenceData($params, $finalChar)';
}

/// OSC sequence data (ESC ] ... ST).
@immutable
final class OscSequenceData extends SequenceData {
  /// The parameters.
  final Parameters params;

  /// Create OSC sequence data.
  const OscSequenceData(this.params);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OscSequenceData && other.params == params;
  }

  @override
  int get hashCode => params.hashCode;

  @override
  String toString() => 'OscSequenceData($params)';
}

/// DCS sequence data (ESC P ... ST).
///
/// Content is opaque - no parsing performed by Engine.
@immutable
final class DcsSequenceData extends SequenceData {
  /// The parameters.
  final Parameters params;

  /// The raw content bytes (opaque).
  final List<int> contentBytes;

  /// Create DCS sequence data.
  const DcsSequenceData(this.params, this.contentBytes);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! DcsSequenceData) return false;
    if (other.params != params) return false;
    if (other.contentBytes.length != contentBytes.length) return false;
    for (var i = 0; i < contentBytes.length; i++) {
      if (other.contentBytes[i] != contentBytes[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode {
    var hash = params.hashCode;
    for (final byte in contentBytes) {
      hash = hash ^ byte.hashCode;
    }
    return hash;
  }

  @override
  String toString() => 'DcsSequenceData($params, ${contentBytes.length} bytes)';
}

/// Text block sequence data (bracketed paste: CSI 200~ ... CSI 201~).
///
/// Content is opaque - no parsing performed by Engine.
@immutable
final class TextBlockSequenceData extends SequenceData {
  /// The start sequence parameters.
  final Parameters startParams;

  /// The start sequence final character.
  final String startFinal;

  /// The end sequence parameters.
  final Parameters endParams;

  /// The end sequence final character.
  final String endFinal;

  /// The raw content bytes (opaque).
  final List<int> contentBytes;

  /// Create text block sequence data.
  const TextBlockSequenceData(
    this.startParams,
    this.startFinal,
    this.endParams,
    this.endFinal,
    this.contentBytes,
  );

  /// Create a copy with updated fields.
  ///
  /// Used internally by Engine to build complete TextBlockSequenceData
  /// from initial incomplete state.
  TextBlockSequenceData copyWith({
    Parameters? endParams,
    String? endFinal,
    List<int>? contentBytes,
  }) {
    return TextBlockSequenceData(
      startParams,
      startFinal,
      endParams ?? this.endParams,
      endFinal ?? this.endFinal,
      contentBytes ?? this.contentBytes,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! TextBlockSequenceData) return false;
    if (other.startParams != startParams) return false;
    if (other.startFinal != startFinal) return false;
    if (other.endParams != endParams) return false;
    if (other.endFinal != endFinal) return false;
    if (other.contentBytes.length != contentBytes.length) return false;
    for (var i = 0; i < contentBytes.length; i++) {
      if (other.contentBytes[i] != contentBytes[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode {
    var hash = Object.hash(startParams, startFinal, endParams, endFinal);
    for (final byte in contentBytes) {
      hash = hash ^ byte.hashCode;
    }
    return hash;
  }

  @override
  String toString() =>
      'TextBlockSequenceData($startParams$startFinal...$endParams$endFinal, ${contentBytes.length} bytes)';
}

/// Error sequence data (structural parsing errors).
@immutable
final class ErrorSequenceData extends SequenceData {
  /// The error message.
  final String message;

  /// Optional error type classification (e.g., 'unexpectedEscape').
  final String? type;

  /// Engine state when error occurred.
  final String state;

  /// Raw bytes of the malformed sequence.
  final List<int> rawBytes;

  /// Partial parameters parsed before error.
  final List<String> partialParameters;

  /// Create error sequence data.
  const ErrorSequenceData(
    this.message, {
    required this.state,
    required this.rawBytes,
    required this.partialParameters,
    this.type,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ErrorSequenceData) return false;
    if (other.message != message) return false;
    if (other.type != type) return false;
    if (other.state != state) return false;
    if (other.rawBytes.length != rawBytes.length) return false;
    for (var i = 0; i < rawBytes.length; i++) {
      if (other.rawBytes[i] != rawBytes[i]) return false;
    }
    if (other.partialParameters.length != partialParameters.length) return false;
    for (var i = 0; i < partialParameters.length; i++) {
      if (other.partialParameters[i] != partialParameters[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode {
    var hash = Object.hash(message, type, state);
    for (final byte in rawBytes) {
      hash = hash ^ byte.hashCode;
    }
    for (final param in partialParameters) {
      hash = hash ^ param.hashCode;
    }
    return hash;
  }

  @override
  String toString() =>
      '''
ErrorSequenceData:
  message: $message,
  type: $type,
  state: $state,
  params: [${partialParameters.join(', ')}]
  bytes: [${rawBytes.toHexString()}](${rawBytes.length})''';
}
