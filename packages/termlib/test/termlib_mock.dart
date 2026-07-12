import 'dart:io' show Stdout;

import 'package:termlib/src/ffi/termos.dart';
import 'package:termlib/termlib.dart';

/// Captures raw-mode FFI calls for test assertions.
class TermOsMock implements TermOs {
  /// Chronological list of invoked methods for each test.
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

/// Minimal Stdout mock used by `IOOverrides.runZoned` to redirect stderr in
/// tests that verify error output.
class MockStderr implements Stdout {
  MockStderr(this._buffer);
  final StringBuffer _buffer;

  @override
  void write(Object? object) => _buffer.write(object);

  @override
  void writeln([Object? object = '']) => _buffer.writeln(object);

  @override
  // complains
  // ignore: strict_raw_type
  void writeAll(Iterable objects, [String sep = '']) => _buffer.writeAll(objects, sep);

  @override
  void writeCharCode(int charCode) => _buffer.writeCharCode(charCode);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// `Stdout` mock that records `flush()` calls; used to verify `_IoSink.flush`
/// forwards to the real `Stdout.flush` rather than closing or exiting.
class FlushTrackingStdout implements Stdout {
  int flushCount = 0;

  @override
  Future<void> flush() async => flushCount++;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// `BufferTermSink` that records `flush()` calls alongside the no-op buffer
/// behavior, so tests can assert `Term.flush` forwards to the backend sink.
class FlushTrackingBufferSink extends BufferTermSink {
  int flushCount = 0;

  @override
  Future<void> flush() async {
    flushCount++;
    await super.flush();
  }
}
