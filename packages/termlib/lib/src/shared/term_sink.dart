import 'dart:io' show Stdout, stdout;

/// Narrow output surface termlib calls on stdout.
///
/// Backed by real `Stdout` via [TermSink.io] or an in-memory buffer via
/// [TermSink.buffer] for tests.
abstract class TermSink {
  /// Wrap real stdout (defaults to `dart:io` `stdout`).
  factory TermSink.io([Stdout? out]) => _IoSink(out);

  /// In-memory sink. Tests read captured output via `BufferTermSink.output`.
  factory TermSink.buffer({
    int columns = 80,
    int rows = 24,
    bool hasTerminal = true,
  }) => BufferTermSink(
    columns: columns,
    rows: rows,
    hasTerminal: hasTerminal,
  );

  /// Write object's string representation.
  void write(Object s);

  /// Flush pending output. No-op for buffers. Does not close the sink.
  Future<void> flush();

  /// Close underlying sink. No-op for buffers.
  Future<void> close();

  /// True if the sink is connected to an interactive terminal.
  bool get hasTerminal;

  /// Current column count.
  int get terminalColumns;

  /// Current row count.
  int get terminalLines;
}

class _IoSink implements TermSink {
  _IoSink([Stdout? out]) : _out = out ?? stdout;

  final Stdout _out;

  @override
  void write(Object s) => _out.write(s);

  @override
  Future<void> flush() => _out.flush();

  @override
  Future<void> close() => _out.close();

  @override
  bool get hasTerminal => _out.hasTerminal;

  @override
  int get terminalColumns => _out.terminalColumns;

  @override
  int get terminalLines => _out.terminalLines;
}

/// In-memory [TermSink] for tests. Records every [write] into [output].
class BufferTermSink implements TermSink {
  /// Build an in-memory sink with the given terminal dimensions and tty flag.
  BufferTermSink({
    this._columns = 80,
    this._rows = 24,
    this._hasTerminal = true,
  });

  final StringBuffer _buf = StringBuffer();
  int _columns;
  int _rows;
  bool _hasTerminal;

  /// All captured output so far.
  String get output => _buf.toString();

  /// Reset captured output.
  void clearOutput() => _buf.clear();

  /// Set column count (for resize tests).
  // ignore: avoid_setters_without_getters
  set columns(int value) => _columns = value;

  /// Set row count (for resize tests).
  // ignore: avoid_setters_without_getters
  set rows(int value) => _rows = value;

  /// Set tty flag (for piped-vs-interactive tests).
  // ignore: avoid_setters_without_getters
  set hasTty(bool value) => _hasTerminal = value;

  @override
  void write(Object s) => _buf.write(s);

  @override
  Future<void> flush() async {}

  @override
  Future<void> close() async {}

  @override
  bool get hasTerminal => _hasTerminal;

  @override
  int get terminalColumns => _columns;

  @override
  int get terminalLines => _rows;
}
