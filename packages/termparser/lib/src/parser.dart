import 'engine.dart';
import 'events.dart';
import 'parsers.dart' as parsers;
import 'provider.dart';

/// we want <C-?> as <C-?>.
bool ctrlQuestionMarkQuirk = false;

/// in this case we want "return", not "enter". and instead of <C-j>
/// mapped to "enter", we want <C-j> to have <C-j>/<C-k> for vim
/// style navigation.
bool rawModeReturnQuirk = false;

/// The ANSI escape sequence parser
///
/// This class implements the ANSI escape sequence parser allowing to parse
/// data coming from the terminal (stdin) and dispatching events based on the
/// input.
///
/// Data is feed to the parser using the [advance] method and later can check
/// if there is available events using the [moveNext] method. If there are
/// events available, they can be retrieved using the [current] property.
///
/// ```dart
///   final parser = Parser();
///   // ESC [ 20 ; 10 R
///   parser.advance([0x1B, 0x5B, 0x32, 0x30, 0x3B, 0x31, 0x30, 0x52]);
///   assert(parser.moveNext(), 'move next');
///   assert(parser.current == const CursorPositionEvent(20, 10), 'retrieve event');
///   assert(parser.moveNext() == false, 'no more events');
/// ```
///
final class Parser implements Iterator<Event> {
  final Engine _engine;
  final _SequenceProvider _provider;

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
  bool moveNext() => _provider.moveNext();

  @override
  Event get current => _provider.current;
}

class _SequenceProvider implements Provider, Iterator<Event> {
  bool _escO = false;
  final List<Event> _sequences = [];
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
  void provideCSISequence(List<String> parameters, int ignoredParameterCount, String char) {
    final seq = parsers.parseCSISequence(parameters, ignoredParameterCount, char);
    _sequences.add(seq);
    _escO = false;
  }

  @override
  void provideOscSequence(List<String> parameters, int ignoredParameterCount, String char) {
    final seq = parsers.parseOscSequence(parameters, ignoredParameterCount, char);
    _sequences.add(seq);
    _escO = false;
  }

  @override
  void provideDcsSequence(List<String> parameters, int ignoredParameterCount, String char) {
    final seq = parsers.parseDcsSequence(parameters, ignoredParameterCount, char);
    _sequences.add(seq);
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
  Event get current {
    if (_index < 0 || _index >= _sequences.length) throw StateError('No current sequence');
    return _sequences[_index];
  }
}
