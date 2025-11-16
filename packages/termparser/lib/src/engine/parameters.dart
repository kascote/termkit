import 'package:meta/meta.dart';

import 'parameter_accumulator.dart';

/// Immutable snapshot of parameters from an escape sequence.
///
/// This class provides a simple, immutable view of parameters parsed from
/// ANSI escape sequences. For full List functionality, use [values] directly.
@immutable
class Parameters {
  /// The parameter values as a list of strings.
  final List<String> values;

  /// Create Parameters with given values.
  const Parameters(this.values);

  /// Create Parameters from a [ParameterAccumulator].
  factory Parameters.from(ParameterAccumulator accumulator) {
    return Parameters(accumulator.getParameters());
  }

  /// Create empty Parameters (no values).
  factory Parameters.empty() => const Parameters([]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Parameters) return false;
    if (values.length != other.values.length) return false;
    for (var i = 0; i < values.length; i++) {
      if (values[i] != other.values[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode {
    var hash = 0;
    for (final value in values) {
      hash = hash ^ value.hashCode;
    }
    return hash;
  }

  @override
  String toString() => 'Parameters($values)';
}
