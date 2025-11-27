import 'dart:async';
import 'dart:convert';
import 'dart:io' show IOSink, Stdin, Stdout, systemEncoding;

import 'package:termlib/src/ffi/termos.dart';

class TermOsMock implements TermOs {
  List<String> callStack = [];

  void clearCallStack() => callStack.clear();

  int setWindowHeight(int height) {
    callStack.add('setWindowHeight($height)');
    return height;
  }

  int setWindowWidth(int width) {
    callStack.add('setWindowWidth($width)');
    return width;
  }

  @override
  void enableRawMode() => callStack.add('enableRawMode');

  @override
  void disableRawMode() => callStack.add('disableRawMode');
}

// class TermMock extends TermLib {
//   late ProfileEnum _colorProfile;

//   TermMock({ProfileEnum? colorProfile}) {
//     _colorProfile = colorProfile ?? ProfileEnum.ansi256;
//   }

//   @override
//   Future<Color> get backgroundColor => Future.value(Ansi256Color(243));

//   Color foregroundColor() => Ansi16Color(4);

//   ProfileEnum colorProfile() => _colorProfile;

//   String? termStatusReport(int status) {
//     if (status == 10) return 'rgb:1000/A000/B000';
//     if (status == 11) return 'rgb:1100/C000/D000';

//     return null;
//   }
// }

///
// https://github.com/filiph/linkcheck/blob/8ab5f5b516701f98c18cb2f16a73e5f93ebf7f12/test/e2e_test.dart#L218
class MockStdout implements Stdout {
  ///
  StringBuffer buf = StringBuffer();
  int _terminalColumns = 80;
  int _terminalLines = 24;

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

  ///
  // ignore: use_setters_to_change_properties
  void setTermColumns(int value) {
    _terminalColumns = value;
  }

  ///
  // ignore: use_setters_to_change_properties
  void setTermLines(int value) {
    _terminalLines = value;
  }

  @override
  final Encoding encoding = const Utf8Codec();

  @override
  String get lineTerminator => '';
  @override
  set lineTerminator(String value) {}

  @override
  Never get done => throw UnimplementedError();

  @override
  set encoding(Encoding encoding) {
    throw UnimplementedError();
  }

  var _hasTerminal = true;
  @override
  bool get hasTerminal {
    callStack.add('hasTerminal');
    return _hasTerminal;
  }

  set hasTerminal(bool value) => _hasTerminal = value;

  @override
  IOSink get nonBlocking {
    throw UnimplementedError();
  }

  @override
  bool get supportsAnsiEscapes => false;

  @override
  int get terminalColumns {
    callStack.add('terminalColumns');
    return _terminalColumns;
  }

  @override
  int get terminalLines {
    callStack.add('terminalLines');
    return _terminalLines;
  }

  @override
  void add(List<int> data) {
    throw UnimplementedError();
    //    _sink.add(data);
  }

  @override
  Never addError(Object error, [StackTrace? stackTrace]) {
    //
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

///
class _StdStream extends Stream<List<int>> {
  final Stream<List<int>> _stream;

  _StdStream(this._stream);

  ///
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return _stream.listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }
}

class MockStdin extends _StdStream implements Stdin {
  MockStdin(super._stream);

  @override
  bool get echoMode => true;
  @override
  set echoMode(bool value) {}

  @override
  bool echoNewlineMode = true;

  @override
  bool lineMode = true;

  var _hasTerminal = true;
  @override
  bool get hasTerminal => _hasTerminal;
  set hasTerminal(bool value) => _hasTerminal = value;

  @override
  int readByteSync() => throw UnimplementedError();

  @override
  String? readLineSync({Encoding encoding = systemEncoding, bool retainNewlines = false}) {
    throw UnimplementedError();
  }

  @override
  bool get supportsAnsiEscapes => throw UnimplementedError();
}

/// Mock stderr that captures output to a StringBuffer
class MockStderr implements Stdout {
  MockStderr(this._buffer);
  final StringBuffer _buffer;

  @override
  void write(Object? object) => _buffer.write(object);

  @override
  void writeln([Object? object = '']) => _buffer.writeln(object);

  @override
  //
  // ignore: strict_raw_type
  void writeAll(Iterable objects, [String sep = '']) => _buffer.writeAll(objects, sep);

  @override
  void writeCharCode(int charCode) => _buffer.writeCharCode(charCode);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
