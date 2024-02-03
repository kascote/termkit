// ignore_for_file: public_member_api_docs

import 'package:termparser/src/provider.dart';

class MockCharProvider extends Provider {
  final List<String> _chars = [];

  @override
  void provideChar(String char) {
    _chars.add(char);
  }

  List<String> get chars => _chars;

  @override
  void provideESCSequence(String char) {}

  @override
  void provideCSISequence(List<int> parameters, int ignoredParameterCount, String char) {}
}

class MockCsiProvider extends Provider {
  final List<List<int>> params = [];
  final List<String> chars = [];

  @override
  void provideChar(String char) {
    chars.add(char);
  }

  @override
  void provideESCSequence(String char) {}

  @override
  void provideCSISequence(List<int> parameters, int ignoredParameterCount, String char) {
    params.add(parameters);
    if (char.isNotEmpty) chars.add(char);
  }

  @override
  String toString() {
    return '${chars.join()}  - ${params.join()}';
  }
}

class MockEscProvider extends Provider {
  final List<String> _chars = [];

  List<String> get chars => _chars;

  @override
  void provideChar(String char) {}

  @override
  void provideESCSequence(String char) {
    _chars.add(char);
  }

  @override
  void provideCSISequence(List<int> parameters, int ignoredParameterCount, String char) {}
}

class MockProvider extends Provider {
  final List<List<int>> params = [];
  final List<String> _chars = [];

  List<String> get chars => _chars;

  @override
  void provideChar(String char) => _chars.add(char);

  @override
  void provideESCSequence(String char) => _chars.add(char);

  @override
  void provideCSISequence(List<int> parameters, int ignoredParameterCount, String char) {
    params.add(parameters);
    if (char.isNotEmpty) chars.add(char);
  }
}
