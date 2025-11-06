import '../events.dart';

/// Parse a Device Control String sequence
Event parseDcsSequence(List<String> parameters, int ignoredParameterCount, String char) {
  return switch (parameters) {
    ['>', '|', ...] => _parseDCSBlock(parameters),
    _ => const NoneEvent(),
  };
}

Event _parseDCSBlock(List<String> parameters) {
  if (parameters.length < 2) return const NoneEvent();
  return NameAndVersionEvent(parameters[2]);
}
