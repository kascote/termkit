import './escape_codes.dart';

/// Erase sequences.
abstract class Erase {
  /// Erase from cursor to end of the screen
  static const String screenFromCursor = '${CSI}0J';

  /// Erase from cursor to beginning of screen
  static const String screenToCursor = '${CSI}1J';

  /// Erase entire screen
  static const String screenAll = '${CSI}2J';

  /// Erase saved lines
  static const String screenSaved = '${CSI}3J';

  /// Erase from cursor to end of line
  static const String lineFromCursor = '${CSI}0K';

  /// Erase from cursor to beginning of line
  static const String lineToCursor = '${CSI}1K';

  /// Erase entire line
  static const String lineAll = '${CSI}2K';

  /// Erase saved lines
  static const String lineSaved = '${CSI}3K';

  /// Erase the screen and moves the cursor the top left position
  static const String clear = '${CSI}2J${CSI}H';
}
