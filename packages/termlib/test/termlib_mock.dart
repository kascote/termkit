import 'dart:convert';
import 'dart:io' show IOSink, Stdout;

import 'package:termlib/termlib.dart';

class TermMock {
  late ProfileEnum _colorProfile;

  TermMock({ProfileEnum? colorProfile}) {
    _colorProfile = colorProfile ?? ProfileEnum.ansi256;
  }

  Color backgroundColor() => Ansi256Color(243);

  Color foregroundColor() => Ansi16Color(4);

  ProfileEnum colorProfile() => _colorProfile;

  String? termStatusReport(int status) {
    if (status == 10) return 'rgb:1000/A000/B000';
    if (status == 11) return 'rgb:1100/C000/D000';

    return null;
  }
}

///
// https://github.com/filiph/linkcheck/blob/8ab5f5b516701f98c18cb2f16a73e5f93ebf7f12/test/e2e_test.dart#L218
class MockStdout implements Stdout {
  ///
  StringBuffer buf = StringBuffer();

  ///
  List<String> callStack = [];

  ///
  String get output => buf.toString();

  ///
  void clearOutput() {
    buf.clear();
  }

  void clearCallStack() {
    callStack.clear();
  }

  @override
  final Encoding encoding = const Utf8Codec();

  ///
  MockStdout();

  @override
  Never get done => throw UnimplementedError();

  @override
  set encoding(Encoding encoding) {
    throw UnimplementedError();
  }

  @override
  bool get hasTerminal {
    callStack.add('hasTerminal');
    return true;
  }

  @override
  IOSink get nonBlocking {
    throw UnimplementedError();
  }

  @override
  bool get supportsAnsiEscapes => false;

  @override
  int get terminalColumns {
    callStack.add('terminalColumns');
    return 80;
  }

  @override
  int get terminalLines {
    callStack.add('terminalLines');
    return 40;
  }

  @override
  void add(List<int> data) {
    throw UnimplementedError();
//    _sink.add(data);
  }

  @override
  Never addError(Object error, [StackTrace? stackTrace]) {
    // ignore: only_throw_errors
    throw error;
  }

  @override
  Never addStream(Stream<List<int>> stream) => throw UnimplementedError();

  @override
  Future<void> close() async {
//    await _sink.close();
//    await _controller.close();
  }

  @override
  Never flush() => throw UnimplementedError();

  @override
  void write(Object? object) {
    final string = '$object';
    buf.write(string);
  }

  @override
  void writeAll(Iterable<dynamic> objects, [String sep = '']) {
    final iterator = objects.iterator;
    if (!iterator.moveNext()) return;
    if (sep.isEmpty) {
      do {
        write(iterator.current);
      } while (iterator.moveNext());
    } else {
      write(iterator.current);
      while (iterator.moveNext()) {
        write(sep);
        write(iterator.current);
      }
    }
  }

  @override
  void writeCharCode(int charCode) {
    write(String.fromCharCode(charCode));
  }

  @override
  void writeln([Object? object]) {
    object ??= '';
    write(object);
    write('\n');
  }
}
