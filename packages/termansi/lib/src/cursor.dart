import './escape_codes.dart';

/// Enumeration representing different cursor styles.
enum CursorStyle {
  /// Default cursor shape configured by the user.
  defaultUserShape,

  /// A blinking block cursor shape (■).
  blinkingBlock,

  /// A non blinking block cursor shape (inverse of `BlinkingBlock`).
  steadyBlock,

  /// A blinking underscore cursor shape(_).
  blinkingUnderScore,

  /// A non blinking underscore cursor shape (inverse of `BlinkingUnderScore`).
  steadyUnderScore,

  /// A blinking cursor bar shape (|)
  blinkingBar,

  /// A steady cursor bar shape (inverse of `BlinkingBar`).
  steadyBar,
}

/// Cursor movement sequences.
abstract class Cursor {
  /// Moves to home position (1,1)
  static const String home = '${CSI}H';

  /// Moves the cursor to the given position (row, column)
  ///
  /// The value is 1 based, meaning 1 is the topmost row or leftmost column.
  /// Values < 1 are treated as 1 by the terminal.
  static String moveTo(int y, int x) {
    assert(y >= 1, 'y should be >= 1 (1-based), got $y');
    assert(x >= 1, 'x should be >= 1 (1-based), got $x');
    return '$CSI$y;${x}H';
  }

  /// Moves the cursor down the given number of lines.
  ///
  /// If no value is given, it will move down by 1 line.
  static String moveToNextLine([int n = 1]) {
    assert(n >= 1, 'n should be >= 1, got $n');
    return '$CSI${n}E';
  }

  /// Moves the cursor up the given number of lines.
  ///
  /// If no value is given, it will move up by 1 line.
  static String moveToPrevLine([int n = 1]) {
    assert(n >= 1, 'n should be >= 1, got $n');
    return '$CSI${n}F';
  }

  /// Moves the cursor to the given column on the current row.
  ///
  /// The value is 1 based, meaning 1 is the leftmost column.
  /// Values < 1 are treated as 1 by the terminal.
  static String moveToColumn(int n) {
    assert(n >= 1, 'n should be >= 1 (1-based), got $n');
    return '$CSI${n}G';
  }

  /// Moves the cursor to the given row on the current column.
  ///
  /// The value is 1 based, meaning 1 is the topmost row.
  /// Values < 1 are treated as 1 by the terminal.
  static String moveToRow(int n) {
    assert(n >= 1, 'n should be >= 1 (1-based), got $n');
    return '$CSI${n}d';
  }

  /// Moves the cursor up [n] cells.
  ///
  /// If no value is given, it will move up by 1 cell.
  static String moveUp([int n = 1]) {
    assert(n >= 1, 'n should be >= 1, got $n');
    return '$CSI${n}A';
  }

  /// Moves the cursor right [n] cells.
  ///
  /// If no value is given, it will move right by 1 cell.
  static String moveRight([int n = 1]) {
    assert(n >= 1, 'n should be >= 1, got $n');
    return '$CSI${n}C';
  }

  /// Moves the cursor down [n] cells.
  ///
  /// If no value is given, it will move down by 1 cell.
  static String moveDown([int n = 1]) {
    assert(n >= 1, 'n should be >= 1, got $n');
    return '$CSI${n}B';
  }

  /// Moves the cursor left [n] cells.
  ///
  /// If no value is given, it will move left by 1 cell.
  static String moveLeft([int n = 1]) {
    assert(n >= 1, 'n should be >= 1, got $n');
    return '$CSI${n}D';
  }

  /// Request cursor position
  ///
  /// Will report back as `ESC[{row};{column}R`
  /// The value is 1 based, meaning 1 is the topmost row or leftmost column.
  static const String requestPosition = '${CSI}6n';

  /// Saves the current cursor position.
  static const String savePosition = '${ESC}7';

  /// Restores the cursor position.
  static const String restorePosition = '${ESC}8';

  /// Hides the cursor.
  static const String hide = '$CSI?25l';

  /// Shows the cursor.
  static const String show = '$CSI?25h';

  /// Enables blinking of the terminal cursor.
  ///
  /// Some terminal emulators do not support this, could use [setCursorStyle] instead.
  static const String enableBlinking = '$CSI?12h';

  /// Disables blinking of the terminal cursor.
  static const String disableBlinking = '$CSI?12l';

  /// Sets the cursor style.
  static String setCursorStyle(CursorStyle style) => '$CSI${style.index} q';
}
