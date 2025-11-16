import 'package:meta/meta.dart';

import '../extensions/int_extension.dart';
import '../extensions/list_extension.dart';
import 'event_base.dart';
import 'shared.dart';

const _blankArray = <int>[];

/// Type of engine error
enum EngineErrorType {
  /// Malformed escape sequence
  malformedSequence,

  /// Unsupported escape sequence
  unsupportedSequence,

  /// Invalid parameter value
  invalidParameter,

  /// Unexpected escape character
  unexpectedEscape,
}

/// Error event dispatched when the engine cannot parse a sequence.
/// This is for structural errors (malformed sequences, invalid state transitions).
@immutable
final class EngineErrorEvent extends ErrorEvent {
  /// The parameters of the sequence.
  final List<String> params;

  /// The character if there is one
  final String char;

  /// The block content if there is one
  final List<int> block;

  /// Error message describing what went wrong
  final String message;

  /// Type of error that occurred
  final EngineErrorType type;

  /// Raw bytes that caused the error (full sequence bytes accumulated)
  final List<int> rawBytes;

  /// Parser state when error occurred
  final String stateAtError;

  /// The specific byte that triggered the error
  final int? failingByte;

  /// Parameters collected before error occurred
  final List<String> partialParameters;

  /// Constructs a new instance of [EngineErrorEvent].
  const EngineErrorEvent(
    this.params, {
    this.char = '',
    this.block = _blankArray,
    this.message = '',
    this.type = EngineErrorType.malformedSequence,
    this.rawBytes = _blankArray,
    this.stateAtError = '',
    this.failingByte,
    this.partialParameters = const [],
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EngineErrorEvent &&
          runtimeType == other.runtimeType &&
          listEquals(params, other.params) &&
          char == other.char &&
          listEquals(block, other.block) &&
          message == other.message &&
          type == other.type &&
          listEquals(rawBytes, other.rawBytes) &&
          stateAtError == other.stateAtError &&
          failingByte == other.failingByte &&
          listEquals(partialParameters, other.partialParameters);

  @override
  int get hashCode => Object.hash(
    Object.hashAll(params),
    char,
    Object.hashAll(block),
    message,
    type,
    Object.hashAll(rawBytes),
    stateAtError,
    failingByte,
    Object.hashAll(partialParameters),
  );

  @override
  String toString() {
    final buffer = StringBuffer()..write('Engine error: $message');

    // Add sequence bytes as hex dump if available
    if (rawBytes.isNotEmpty) {
      buffer
        ..write('\n  Sequence: ')
        ..write(rawBytes.toHexString())
        ..write(' (');
      for (final b in rawBytes) {
        if (b.isPrintable) {
          buffer.write(String.fromCharCode(b));
        } else if (b == 0x1B) {
          buffer.write('ESC');
        } else {
          buffer.write('.');
        }
        buffer.write(' ');
      }
      buffer.write(')');
    }

    if (partialParameters.isNotEmpty) {
      buffer.write('\n  Partial params: [${partialParameters.map((p) => '"$p"').join(', ')}]');
    }

    return buffer.toString();
  }
}
