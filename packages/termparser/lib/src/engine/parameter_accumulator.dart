import 'dart:convert';
import 'dart:typed_data';

const _maxParameters = 30;
const _maxParameterBytes = 32; // Max bytes per parameter (e.g., "24:49", "rgb:ff/ff/ff")
const _defaultParameterValue = '0';

/// Helper class to accumulate parameters from escape sequences
class ParameterAccumulator {
  final _parameters = List<String>.filled(_maxParameters, _defaultParameterValue);
  int _parametersCount = 0;
  final Uint8List _parameter = Uint8List(_maxParameterBytes);
  int _parameterLength = 0;
  int _ignoredParametersCount = 0;

  /// Create a new ParameterAccumulator
  ParameterAccumulator() {
    _parameters.fillRange(0, _parameters.length, _defaultParameterValue);
  }

  /// Store current parameter and move to next
  void store() {
    if (_parametersCount < _maxParameters) {
      final param = utf8.decode(_parameter.sublist(0, _parameterLength), allowMalformed: true);
      _parameters[_parametersCount] = param.isEmpty ? _defaultParameterValue : param;
      _parametersCount++;
    } else {
      _ignoredParametersCount++;
    }
    _parameterLength = 0;
  }

  /// Clear all parameters
  void clear() {
    _parametersCount = 0;
    _parameterLength = 0;
    _ignoredParametersCount = 0;
  }

  /// Add byte to current parameter
  void add(int byte) {
    if (_parameterLength < _maxParameterBytes) {
      _parameter[_parameterLength++] = byte;
    }
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
