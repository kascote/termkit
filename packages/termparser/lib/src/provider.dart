///
abstract class Provider {
  ///
  void provideChar(String char);

  ///
  void provideESCSequence(String char);

  ///
  void provideCSISequence(List<int> parameters, int ignoredParameterCount, String char);
}
