///
abstract class Provider {
  ///
  void provideChar(String char);

  ///
  void provideESCSequence(String char);

  ///
  void provideCSISequence(List<String> parameters, int ignoredParameterCount, String char, {List<int>? block});

  ///
  void provideOscSequence(List<String> parameters, int ignoredParameterCount, String char, {List<int>? block});
}
