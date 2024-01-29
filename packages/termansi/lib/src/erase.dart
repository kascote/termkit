import './escape_codes.dart';

/// Erase sequences.
abstract class Erase {
  /// Erase from cursor to end of the screen
  static String screenFromCursor() => '${CSI}0J';

  /// erase from cursor to beginning of screen
  static String screenToCursor() => '${CSI}1J';

  /// erase entire screen
  static String screenAll() => '${CSI}2J';

  /// erase saved lines
  static String screenSaved() => '${CSI}3J';

  /// erase from cursor to end of line
  static String lineFromCursor() => '${CSI}0K';

  /// erase from cursor to beginning of line
  static String lineToCursor() => '${CSI}1K';

  /// erase entire line
  static String lineAll() => '${CSI}2K';

  /// erase saved lines
  static String lineSaved() => '${CSI}3K';

  /// erase the screen and moves the cursor the top left position
  static String clear() => '${CSI}2J${CSI}H';
}
