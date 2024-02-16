/// Interface for providing characters to the parser
abstract class Provider {
  /// Provide a character to the parser
  void provideChar(String char);

  /// Provide an escape sequence to the parser
  void provideESCSequence(String char);

  /// Provide a control sequence to the parser
  void provideCSISequence(List<String> parameters, int ignoredParameterCount, String char, {List<int>? block});

  /// Provide an operating system command sequence to the parser
  void provideOscSequence(List<String> parameters, int ignoredParameterCount, String char, {List<int>? block});
}
