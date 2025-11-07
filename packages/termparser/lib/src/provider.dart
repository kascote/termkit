import 'events.dart';

/// Interface for providing characters to the parser
abstract class Provider {
  /// Provide a character to the parser
  void provideChar(String char);

  /// Provide an escape sequence to the parser
  void provideESCSequence(String char);

  /// Provide a control sequence to the parser
  void provideCSISequence(List<String> parameters, int ignoredParameterCount, String char);

  /// Provide an operating system command sequence to the parser
  void provideOscSequence(List<String> parameters, int ignoredParameterCount, String char);

  /// Provide an operating system command sequence to the parser
  void provideDcsSequence(List<String> parameters, int ignoredParameterCount, String char);

  /// Add an event directly to the provider (for error events)
  void addEvent(Event event);
}
