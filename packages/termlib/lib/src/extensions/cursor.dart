import 'package:termansi/termansi.dart' as ansi;
import 'package:termparser/termparser_events.dart';

import '../probe/raw_queries.dart';
import '../termlib_base.dart';
import 'term.dart';

/// Cursor handling functions
extension CursorUtils on InteractiveTerm {
  /// Moves the cursor to the given position (row, column)
  ///
  /// The top-left corner of the screen is (1, 1).
  void moveTo(int row, int col) => write(ansi.Cursor.moveTo(row, col));

  /// Moves the cursor down the given number of lines.
  void moveToNextLine([int n = 1]) => write(ansi.Cursor.moveToNextLine(n));

  /// Moves the cursor up the given number of lines.
  void moveToPrevLine([int n = 1]) => write(ansi.Cursor.moveToPrevLine(n));

  /// Moves the cursor to the given column on the current row.
  /// The value is 0 based, meaning 0 is the leftmost column.
  void moveToColumn(int n) => write(ansi.Cursor.moveToColumn(n));

  /// Moves the cursor to the given row on the current column.
  /// The value is 0 based, meaning 0 is the topmost row.
  void moveToRow(int n) => write(ansi.Cursor.moveToRow(n));

  /// Moves the cursor up [n] cells.
  void moveUp([int n = 1]) => write(ansi.Cursor.moveUp(n));

  /// Moves the cursor right [n] cells.
  void moveRight([int n = 1]) => write(ansi.Cursor.moveRight(n));

  /// Moves the cursor down [n] cells.
  void moveDown([int n = 1]) => write(ansi.Cursor.moveDown(n));

  /// Moves the cursor left [n] cells.
  void moveLeft([int n = 1]) => write(ansi.Cursor.moveLeft(n));

  /// Saves the current cursor position.
  void savePosition() => write(ansi.Cursor.savePosition);

  /// Restores the cursor position.
  void restorePosition() => write(ansi.Cursor.restorePosition);

  /// Queries the current cursor position.
  Future<CursorPositionEvent?> queryCursorPosition({int timeout = defaultQueryTimeout}) async {
    return withRawModeAsync<CursorPositionEvent?>(() => rawQueryCursorPosition(timeout));
  }

  /// Hides the cursor.
  void cursorHide() => write(ansi.Cursor.hide);

  /// Shows the cursor.
  void cursorShow() => write(ansi.Cursor.show);

  /// Enables blinking of the terminal cursor.
  ///
  /// Some terminal emulators do not support this, could use [setCursorStyle] instead.
  void enableBlinking() => write(ansi.Cursor.enableBlinking);

  /// Disables blinking of the terminal cursor.
  void disableBlinking() => write(ansi.Cursor.disableBlinking);

  /// Sets the cursor style.
  void setCursorStyle(ansi.CursorStyle style) => write(ansi.Cursor.setCursorStyle(style));

  /// Moves the cursor to the top-left corner of the screen.
  void moveHome() => write(ansi.Cursor.home);

  /// Write [s] at ([row], [col]).
  void writeAt(int row, int col, Object s) => write('${ansi.Cursor.moveTo(row, col)}$s');
}
