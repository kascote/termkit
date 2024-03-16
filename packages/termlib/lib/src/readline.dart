import 'package:termlib/termlib.dart';
import 'package:termparser/termparser_events.dart';

final _keyMapping = {
  const KeyEvent(KeyCode(name: KeyCodeName.escape)): 'escape',
  const KeyEvent(KeyCode(char: 'm'), modifiers: KeyModifiers(KeyModifiers.ctrl)): 'enter',
  const KeyEvent(KeyCode(name: KeyCodeName.enter)): 'enter',
  const KeyEvent(KeyCode(name: KeyCodeName.backSpace, baseLayoutKey: 8)): 'backSpace',
  const KeyEvent(KeyCode(name: KeyCodeName.backSpace)): 'backSpace',
  const KeyEvent(KeyCode(char: 'h'), modifiers: KeyModifiers(KeyModifiers.ctrl)): 'backSpace',
  const KeyEvent(KeyCode(char: 'u'), modifiers: KeyModifiers(KeyModifiers.ctrl)): 'clearBOL',
  const KeyEvent(KeyCode(name: KeyCodeName.delete)): 'delete',
  const KeyEvent(KeyCode(char: 'd'), modifiers: KeyModifiers(KeyModifiers.ctrl)): 'delete',
  const KeyEvent(KeyCode(char: 'k'), modifiers: KeyModifiers(KeyModifiers.ctrl)): 'clearEOL',
  const KeyEvent(KeyCode(name: KeyCodeName.left)): 'moveLeft',
  const KeyEvent(KeyCode(char: 'b'), modifiers: KeyModifiers(KeyModifiers.ctrl)): 'moveLeft',
  const KeyEvent(KeyCode(name: KeyCodeName.right)): 'moveRight',
  const KeyEvent(KeyCode(char: 'f'), modifiers: KeyModifiers(KeyModifiers.ctrl)): 'moveRight',
  const KeyEvent(KeyCode(name: KeyCodeName.home)): 'home',
  const KeyEvent(KeyCode(char: 'a'), modifiers: KeyModifiers(KeyModifiers.ctrl)): 'home',
  const KeyEvent(KeyCode(name: KeyCodeName.end)): 'end',
  const KeyEvent(KeyCode(char: 'e'), modifiers: KeyModifiers(KeyModifiers.ctrl)): 'end',
};

/// Readline class
class Readline {
  /// Readline buffer
  List<String> buffer = [];

  /// Position in the buffer index
  int bufferIndex = 0;

  /// TermLib instance
  final TermLib term;

  /// Initial cursor position
  final Pos cursor;

  Readline._(this.term, this.cursor, this.buffer);

  /// Readline constructor
  static Future<Readline> create(TermLib t, [String initBuffer = '']) async {
    final pos = await t.cursorPosition;
    final buf = initBuffer.split('');

    final r = Readline._(t, pos ?? (col: buf.length, row: 0), buf);
    r.bufferIndex = r.buffer.length;

    return r;
  }

  /// Starts reading from the keyboard
  Future<String> read() async => term.withRawModeAsync<String>(_read);

  Future<String> _read() async {
    var readingChars = true;

    if (buffer.isNotEmpty) term.writeAt(cursor.row, cursor.col, buffer.join());

    while (readingChars) {
      final key = await term.readEvent<KeyEvent>();
      if (key is! KeyEvent) continue;
      if (key.eventType != KeyEventType.keyPress) continue;

      final keyCode = _keyMapping[key] ?? 'none';

      switch (keyCode) {
        case 'enter':
          readingChars = false;
        case 'escape':
          buffer = [];
          readingChars = false;
          throw ArgumentError('Escape key pressed');
        case 'backSpace':
          if (bufferIndex > 0) {
            term
              ..writeAt(cursor.row, cursor.col + bufferIndex - 1, ' ')
              ..moveLeft();
            bufferIndex--;
            buffer.removeAt(bufferIndex);
            term
              ..writeAt(cursor.row, cursor.col + bufferIndex, '${buffer.sublist(bufferIndex, buffer.length).join()} ')
              ..moveTo(cursor.row, cursor.col + bufferIndex);
          }
        case 'clearBOL':
          final origLength = buffer.length;
          buffer = buffer.sublist(bufferIndex, buffer.length);
          bufferIndex = 0;
          term.writeAt(cursor.row, cursor.col, buffer.join());
          term.write(' ' * (origLength - buffer.length));
          term.moveTo(cursor.row, cursor.col);
        case 'clearEOL':
          term
            ..savePosition()
            ..writeAt(cursor.row, cursor.col + bufferIndex, ' ' * (buffer.length - bufferIndex))
            ..restorePosition();
          buffer = buffer.sublist(0, bufferIndex);
        case 'delete':
          if (bufferIndex < buffer.length) {
            buffer.removeAt(bufferIndex);
            term
              ..savePosition()
              ..writeAt(cursor.row, cursor.col + bufferIndex, buffer.sublist(bufferIndex, buffer.length).join())
              ..write(' ')
              ..restorePosition();
          }
        case 'moveLeft':
          if (bufferIndex > 0) {
            bufferIndex--;
            term.moveLeft();
          }
        case 'moveRight':
          if (bufferIndex < buffer.length) {
            bufferIndex++;
            term.moveRight();
          }
        case 'home':
          if (bufferIndex > 0) {
            term.moveLeft(bufferIndex);
            bufferIndex = 0;
          }
        case 'end':
          if (bufferIndex < buffer.length) {
            term.moveRight(buffer.length - bufferIndex);
            bufferIndex = buffer.length;
          }
        default:
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
