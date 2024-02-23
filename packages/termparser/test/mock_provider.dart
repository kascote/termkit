// ignore_for_file: public_member_api_docs

import 'dart:convert';

import 'package:termparser/src/provider.dart';

class MockProvider extends Provider {
  final List<List<String>> params = [];
  final List<String> _chars = [];
  final List<int> _block = [];

  List<String> get chars => _chars;
  String get block => utf8.decode(_block, allowMalformed: true);

  @override
  void provideChar(String char) => _chars.add(char);

  @override
  void provideESCSequence(String char) => _chars.add(char);

  @override
  void provideCSISequence(List<String> parameters, int ignoredParameterCount, String char, {List<int>? block}) {
    params.add(parameters);
    if (char.isNotEmpty) chars.add(char);
    if (block != null) _block.addAll(block);
  }

  @override
  void provideOscSequence(List<String> parameters, int ignoredParameterCount, String char, {List<int>? block}) {
    params.add(parameters);
    if (char.isNotEmpty) chars.add(char);
    if (block != null) _block.addAll(block);
  }

  @override
  void provideDcsSequence(List<String> parameters, int ignoredParameterCount, String char, {List<int>? block}) {
    params.add(parameters);
    if (char.isNotEmpty) chars.add(char);
    if (block != null) _block.addAll(block);
  }
}
