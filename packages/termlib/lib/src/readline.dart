import 'package:termlib/termlib.dart';
import 'package:termparser/termparser_events.dart';

enum _Action {
  enter,
  escape,
  backSpace,
  clearBOL,
  clearEOL,
  delete,
  moveLeft,
  moveRight,
  home,
  end,
}

final _keyBinding = KeyBinding<_Action>()
  ..map(['enter', 'ctrl+m'], _Action.enter)
  ..map(['escape'], _Action.escape)
  ..map(['backSpace', 'ctrl+h'], _Action.backSpace)
  ..map(['ctrl+u'], _Action.clearBOL)
  ..map(['ctrl+k'], _Action.clearEOL)
  ..map(['delete', 'ctrl+d'], _Action.delete)
  ..map(['left', 'ctrl+b'], _Action.moveLeft)
  ..map(['right', 'ctrl+f'], _Action.moveRight)
  ..map(['home', 'ctrl+a'], _Action.home)
  ..map(['end', 'ctrl+e'], _Action.end);

/// Readline class
class Readline {
  /// Readline buffer
  List<String> buffer = [];

  /// Position in the buffer index
  int bufferIndex = 0;

  /// Terminal handle.
  final InteractiveTerm term;

  /// Initial cursor position
  final Pos cursor;

  Readline._(this.term, this.cursor, this.buffer);

  /// Readline constructor
  static Future<Readline> create(InteractiveTerm t, [String initBuffer = '']) async {
    final pos = await t.cursorPosition;
    final buf = initBuffer.split('');

    final r = Readline._(t, pos ?? (col: buf.length, row: 0), buf);
    r.bufferIndex = r.buffer.length;

    return r;
  }

  /// Starts reading from the keyboard
  Future<String?> read() async => term.withRawModeAsync<String?>(_read);

  Future<String?> _read() async {
    var readingChars = true;

    if (buffer.isNotEmpty) term.writeAt(cursor.row, cursor.col, buffer.join());

    while (readingChars) {
      final key = await term.awaitEvent<KeyEvent>(timeout: const Duration(seconds: 60));
      if (key == null) continue;
      if (key.eventType != KeyEventType.keyPress) continue;

      final action = _keyBinding.resolve(key);

      switch (action) {
        case _Action.enter:
          readingChars = false;
        case _Action.escape:
          buffer = [];
          readingChars = false;
          return null;
        case _Action.backSpace:
          if (bufferIndex > 0) {
            term.moveLeft();
            bufferIndex--;
            buffer.removeAt(bufferIndex);
            term
              ..writeAt(cursor.row, cursor.col + bufferIndex, '${buffer.sublist(bufferIndex, buffer.length).join()} ')
              ..moveTo(cursor.row, cursor.col + bufferIndex);
          }
        case _Action.clearBOL:
          final origLength = buffer.length;
          buffer = buffer.sublist(bufferIndex, buffer.length);
          bufferIndex = 0;
          term.writeAt(cursor.row, cursor.col, buffer.join());
          term.write(' ' * (origLength - buffer.length));
          term.moveTo(cursor.row, cursor.col);
        case _Action.clearEOL:
          term
            ..savePosition()
            ..writeAt(cursor.row, cursor.col + bufferIndex, ' ' * (buffer.length - bufferIndex))
            ..restorePosition();
          buffer = buffer.sublist(0, bufferIndex);
        case _Action.delete:
          if (bufferIndex < buffer.length) {
            buffer.removeAt(bufferIndex);
            term
              ..savePosition()
              ..writeAt(cursor.row, cursor.col + bufferIndex, buffer.sublist(bufferIndex, buffer.length).join())
              ..write(' ')
              ..restorePosition();
          }
        case _Action.moveLeft:
          if (bufferIndex > 0) {
            bufferIndex--;
            term.moveLeft();
          }
        case _Action.moveRight:
          if (bufferIndex < buffer.length) {
            bufferIndex++;
            term.moveRight();
          }
        case _Action.home:
          if (bufferIndex > 0) {
            term.moveLeft(bufferIndex);
            bufferIndex = 0;
          }
        case _Action.end:
          if (bufferIndex < buffer.length) {
            term.moveRight(buffer.length - bufferIndex);
            bufferIndex = buffer.length;
          }
        case null:
          term.writeAt(cursor.row, cursor.col + bufferIndex, key.code.char);
          if (bufferIndex < buffer.length) {
            buffer[bufferIndex] = key.code.char;
          } else {
            buffer.add(key.code.char);
          }
          bufferIndex++;
      }
    }

    return buffer.join();
  }
}
