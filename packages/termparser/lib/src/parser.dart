import 'engine.dart';
import 'parsers.dart' as parsers;
import 'provider.dart';
import 'sequences.dart';

/// The ANSI escape sequence parser
class Parser implements Iterator<Sequence> {
  final Engine _engine;
  final _SequenceProvider _provider;
  int _index = -1;

  ///
  Parser()
      : _engine = Engine(),
        _provider = _SequenceProvider();

  /// Advances parser state machine with additional input data.
  ///
  /// [buffer] - input data (stdin in raw mode, etc.)
  /// [more] - more input data available right now
  void advance(List<int> buffer, {bool more = false}) {
    for (var i = 0; i < buffer.length; i++) {
      _engine.advance(_provider, buffer[i], more: i < buffer.length - 1 || more);
    }
  }

  @override
  bool moveNext() {
    return _provider.moveNext();
    // if (_provider._sequences.isEmpty) return false;
    // if (_index == _provider._sequences.length - 1) return false;
    // _index++;
    // return _index < _provider._sequences.length;
  }

  @override
  Sequence get current {
    return _provider.current;
    // if (_index < 0 || _index >= _provider._sequences.length) throw StateError('No current sequence');
    // return _provider._sequences[_index];
  }
}

class _SequenceProvider implements Provider, Iterator<Sequence> {
  bool _escO = false;
  final List<Sequence> _sequences = [];
  int _index = -1;

  @override
  void provideChar(String char) {
    final seq = parsers.parseChar(char, escO: _escO);
    if (seq != null) _sequences.add(seq);
    _escO = false;
  }

  @override
  void provideESCSequence(String char) {
    if (char == 'O') {
      // Exception
      // Esc O - dispatched as an escape sequence followed by single character (P-S) representing
      // F1-F4 keys. We store Esc O flag only which is then used in the dispatch_char method.
      _escO = true;
    } else {
      final seq = parsers.parseESCSequence(char);
      if (seq != null) _sequences.add(seq);
      _escO = false;
    }
  }

  @override
  void provideCSISequence(List<String> parameters, int ignoredParameterCount, String char, {List<int>? block}) {
    final seq = parsers.parseCSISequence(parameters, ignoredParameterCount, char, block: block);
    // TODO(nelson): this will return a NoneSequence where the other methods will not add the sequence
    // we needs to define the behavior
    _sequences.add(seq);
    _escO = false;
  }

  @override
  void provideOscSequence(List<String> parameters, int ignoredParameterCount, String char, {List<int>? block}) {
    final seq = parsers.parseOscSequence(parameters, ignoredParameterCount, char, block: block);
    if (seq != null) _sequences.add(seq);
    _escO = false;
  }

  @override
  bool moveNext() {
    if (_sequences.isEmpty) return false;
    if (_index == _sequences.length - 1) return false;
    _index++;
    return _index < _sequences.length;
  }

  @override
  Sequence get current {
    if (_index < 0 || _index >= _sequences.length) throw StateError('No current sequence');
    return _sequences[_index];
  }
}
